class_name BossArena
extends Node2D

## Arena boss lantai gua (GDD 8.2-C1). Dibangun Cave di lantai BossData.floor_number selama boss
## itu belum pernah kalah. Bagian atas ruang (titik tiba, tangga naik, lift) aman; pemain yang
## melangkah melewati garis kabut memulai pertarungan:
## - Pintu kabut menutup di belakangnya (tembok tak tembus), boss bangun, bar HP besar muncul,
##   genderang perang berbunyi dan makin cepat tiap fase / saat murka.
## - Semua pemain di arena keluar atau tumbang = pertarungan diulang (boss pulih, kabut terbuka).
## - Boss kalah = kabut lenyap, hadiah pertama (uang + item) dan boss tercatat kalah di save.

signal fight_started
signal fight_reset
signal boss_defeated(data: BossData)

## Ketebalan tembok kabut (piksel).
@export_range(2.0, 32.0) var gate_thickness: float = 10.0
## Pemain dianggap masuk arena bila kakinya sejauh ini di bawah garis kabut.
@export_range(1.0, 32.0) var enter_margin: float = 6.0
## Arena kosong selama ini = pertarungan diulang.
@export_range(0.1, 10.0) var reset_delay: float = 1.0
## Posisi relatif boss dalam arena (0..1).
@export var boss_spawn_ratio: Vector2 = Vector2(0.5, 0.6)

var data: BossData
var boss: Boss
## Area arena di koordinat dunia (garis kabut = sisi atasnya).
var arena_rect := Rect2()
var fighting := false
var cleared := false
var _gate: StaticBody2D
var _fog: FogWall
var _bars: Array[BossHealthBar] = []
var _drum: AudioStreamPlayer
var _empty_time := 0.0

## rect dalam koordinat lokal `space` (biasanya Cave). Boss muncul di tengah agak ke bawah.
func setup(p_data: BossData, space: Node2D, rect: Rect2) -> void:
	data = p_data
	arena_rect = Rect2(space.to_global(rect.position), rect.size)
	boss = Boss.spawn_boss(data, get_parent(), arena_rect.position + arena_rect.size * boss_spawn_ratio.clamp(Vector2.ZERO, Vector2.ONE))
	if boss != null:
		boss.arena_rect = arena_rect
		boss.died.connect(_on_boss_died)
	_fog = FogWall.new()
	_fog.width = arena_rect.size.x
	add_child(_fog)
	_fog.global_position = arena_rect.position
	_drum = AudioStreamPlayer.new()
	_drum.bus = &"Music" if data.music != null and AudioServer.get_bus_index(&"Music") >= 0 else Juice.SFX_BUS
	_drum.finished.connect(func():
		if fighting:
			_drum.play())
	add_child(_drum)

func gate_y() -> float:
	return arena_rect.position.y

func is_gate_closed() -> bool:
	return _gate != null

func _physics_process(delta: float) -> void:
	if cleared or boss == null:
		return
	var inside := players_inside()
	if not fighting:
		if not inside.is_empty():
			start_fight(inside[0])
		return
	if inside.is_empty():
		_empty_time += delta
		if _empty_time >= reset_delay:
			reset_fight()
	else:
		_empty_time = 0.0
	_update_drum()

## Pemain hidup yang kakinya di dalam arena (di bawah garis kabut).
func players_inside() -> Array[Player]:
	var result: Array[Player] = []
	var inner := Rect2(arena_rect.position + Vector2(0, enter_margin), arena_rect.size - Vector2(0, enter_margin))
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		var player := node as Player
		if player == null or not player.is_inside_tree() or not player.visible or player.is_defeated or player.data.hp <= 0:
			continue
		if inner.has_point(player.global_position + Player.FEET_OFFSET):
			result.append(player)
	return result

func start_fight(player: Player) -> void:
	if fighting or cleared:
		return
	fighting = true
	_empty_time = 0.0
	_close_gate()
	boss.wake(player)
	var parents := {}
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		var parent := Coop.ui_parent(node as Player)
		if parent != null and not parents.has(parent):
			parents[parent] = true
			_bars.append(BossHealthBar.show_for(boss, parent))
	_drum.stream = data.music if data.music != null else SfxSynth.war_drum()
	_drum.volume_db = data.music_volume_db
	_drum.pitch_scale = 1.0
	_drum.play()
	if DiscoveryManager.discover("boss_%s" % data.id):
		Notify.say("Pintu kabut tertutup! Kalahkan %s untuk membukanya. Ikon merah = tidak bisa ditahan, menghindarlah." % data.title)
	fight_started.emit()

## Semua pemain keluar/tumbang: boss pulih penuh, kabut terbuka, boleh dicoba lagi.
func reset_fight() -> void:
	if not fighting:
		return
	fighting = false
	_open_gate()
	boss.reset_fight()
	_close_bars()
	_drum.stop()
	fight_reset.emit()

func _close_gate() -> void:
	if _gate != null:
		return
	_gate = StaticBody2D.new()
	_gate.name = "FogGate"
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(arena_rect.size.x, gate_thickness)
	shape.shape = box
	_gate.add_child(shape)
	add_child(_gate)
	_gate.global_position = Vector2(arena_rect.get_center().x, gate_y() - gate_thickness * 0.5)
	_fog.closed = true
	Juice.sfx(SfxSynth.whoosh(), -4.0, 0.0, -9.0)

func _open_gate() -> void:
	if _gate != null:
		_gate.queue_free()
		_gate = null
	_fog.closed = false

func _close_bars() -> void:
	for bar in _bars:
		if is_instance_valid(bar):
			bar.close()
	_bars.clear()

## Genderang makin cepat tiap fase dan saat boss murka.
func _update_drum() -> void:
	if not _drum.playing:
		return
	var wanted := 1.0 + 0.12 * (boss.phase - 1) + (0.1 if boss.enraged else 0.0)
	_drum.pitch_scale = move_toward(_drum.pitch_scale, wanted, 0.01)

func _on_boss_died(_enemy: Enemy) -> void:
	if cleared:
		return
	cleared = true
	fighting = false
	_open_gate()
	_fog.dissolve()
	_drum.stop()
	for i in 3:
		get_tree().create_timer(0.12 * i, false).timeout.connect(Juice.sfx.bind(SfxSynth.chime(), -10.0 - i, 0.0, float([0, 4, 7][i])))
	for bar in _bars:
		if is_instance_valid(bar):
			bar.victory(data.title)
	_bars.clear()
	var first := GameState.cave.mark_boss_defeated(data.floor_number)
	if first:
		_give_reward(boss.global_position)
	boss_defeated.emit(data)

## Hadiah pertama kali: uang bersama + item berhamburan di tempat boss kalah.
func _give_reward(at: Vector2) -> void:
	if data.reward_money > 0:
		GameState.add_money(data.reward_money)
	var parent := get_parent()
	for i in data.reward_items.size():
		var count := data.reward_counts[i] if i < data.reward_counts.size() else 1
		var spot := at + Vector2.from_angle(TAU * i / maxf(1.0, data.reward_items.size())) * 14.0
		var item_id := data.reward_items[i]
		(func(): ItemPickup.spawn(parent, spot, item_id, count)).call_deferred()
	Notify.say("%s ditaklukkan! Hadiah: %d G dan harta boss." % [data.title, data.reward_money])


## Dinding kabut di garis arena: tipis dan beriak saat terbuka, tebal saat tertutup.
class FogWall extends Node2D:
	const COLOR := Color(0.78, 0.74, 0.95)
	var width := 320.0
	var closed := false
	var _amount := 0.3
	var _time := 0.0
	var _gone := false

	func _ready() -> void:
		z_index = 4

	func dissolve() -> void:
		_gone = true

	func _process(delta: float) -> void:
		_time += delta
		var wanted := 0.0 if _gone else (1.0 if closed else 0.3)
		_amount = move_toward(_amount, wanted, delta * 1.5)
		if _gone and _amount <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var puffs := maxi(4, int(width / 10.0))
		for i in puffs:
			var x := (float(i) + 0.5) * width / puffs
			var wobble := sin(_time * 1.7 + i * 1.3)
			var y := -4.0 + wobble * 2.0 * _amount
			var radius := 5.0 + 4.0 * _amount + 1.5 * sin(_time * 2.3 + i)
			draw_circle(Vector2(x + cos(_time + i) * 2.0, y), radius, Color(COLOR, 0.12 + 0.35 * _amount))
			if _amount > 0.5:
				draw_circle(Vector2(x, y - 8.0 + wobble), radius * 0.7, Color(COLOR, 0.25 * _amount))
		draw_line(Vector2(0, 0), Vector2(width, 0), Color(1, 1, 1, 0.3 * _amount), 1.0)
