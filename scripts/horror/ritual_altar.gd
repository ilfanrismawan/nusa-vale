class_name RitualAltar
extends Area2D

## Altar Penunggu Area (GDD 4.1, Progres Horor Tahap 6). Satu per area: Hutan Dalam, Gunung, Gua.
## Ritual (00.00–04.59, Tingkat Gaib 3+, bukan Hanya Suasana, sekali berhasil per malam per area):
## 1. Interaksi dengan sesajen di tas (kemenyan + persembahan area) -> sesajen dipakai,
##    tiga titik kemenyan muncul di sekitar altar.
## 2. Nyalakan ketiga titik (interaksi) dalam light_seconds -> Penunggu bangkit.
## 3. Bertahan endure_seconds tanpa disentuh Penunggu. Penunggu yang terusir lebih cepat
##    (mis. tatapan Keris Pusaka) juga dihitung berhasil.
## Berhasil: reward_item + entri Catatan Gaib. Gagal (disentuh, waktu habis, subuh, pergi): tanpa
## denda selain sesajen yang terpakai; bisa diulang.

enum Phase { IDLE, LIGHTING, ENDURE }

@export var area_id: String = "hutan"
@export var penunggu_scene: PackedScene
@export var ghost_id: StringName = &"penunggu_hutan"
@export var display_name: String = "Penunggu Hutan Dalam"
## item_id -> jumlah yang dipakai saat ritual dimulai.
@export var offerings: Dictionary = {"kemenyan": 3, "bunga_kantil": 2}
@export var reward_item: String = "kayu_keramat"
@export var light_seconds: float = 90.0
@export var endure_seconds: float = 60.0
@export var point_radius: float = 56.0
@export_range(1, 4) var min_tier: int = 3

var phase: Phase = Phase.IDLE
var ritual_player: Player
var penunggu: NightStalker
var time_left := 0.0
var _points: Array[IncensePoint] = []


## Titik kemenyan ritual; dinyalakan dengan interaksi.
class IncensePoint extends Area2D:
	var altar: RitualAltar
	var lit := false
	var _t := 0.0

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 9.0
		shape.shape = circle
		add_child(shape)

	func interact(player: Player = null) -> void:
		if altar != null:
			altar.light_point(self, player)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# Tungku kecil; nyala api kecil + asap bila sudah dinyalakan.
		draw_rect(Rect2(-4, -2, 8, 4), Color(0.35, 0.28, 0.22))
		draw_rect(Rect2(-3, -4, 6, 2), Color(0.5, 0.4, 0.3))
		if lit:
			var flick := sin(_t * 12.0) * 0.6
			draw_circle(Vector2(0, -6), 2.2 + flick * 0.3, Color(2.4, 1.3, 0.4, 0.9))
			draw_circle(Vector2(sin(_t * 2.0) * 2.0, -12 - fmod(_t * 6.0, 6.0)), 2.0, Color(1.4, 1.4, 1.4, 0.25))
		else:
			draw_circle(Vector2(0, -5), 1.2, Color(0.2, 0.2, 0.2, 0.8))


func _ready() -> void:
	add_to_group(&"ritual_altar")
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, 16)
		shape.shape = rect
		add_child(shape)


func interact(player: Player = null) -> void:
	if player == null:
		return
	if phase != Phase.IDLE:
		Notify.say("Ritual sedang berlangsung." if phase == Phase.ENDURE else "Nyalakan ketiga titik kemenyan di sekitar altar.")
		return
	var reason := start_blocker()
	if not reason.is_empty():
		Notify.say(reason)
		return
	for id in offerings:
		if not player.data.has_item(id, int(offerings[id])):
			Notify.say("Altar ini meminta sesajen: %s." % offering_text())
			return
	for id in offerings:
		player.data.remove_item(id, int(offerings[id]))
	_begin(player)


## Alasan ritual belum bisa dimulai ("" = bisa).
func start_blocker() -> String:
	var horror := GameState.horror
	if horror == null or horror.difficulty().ambience_only:
		return "Altar ini sunyi."
	if horror.tier() < min_tier:
		return "Altar ini sunyi. Penunggunya belum terjaga."
	if DayCycle.hour >= 5 or DayCycle.night_intensity() < 0.7:
		return "Ritual hanya bisa dimulai lewat tengah malam."
	if horror.ritual_done_tonight(area_id):
		return "Penunggu tempat ini sudah ditenangkan malam ini."
	return ""


func offering_text() -> String:
	var parts: PackedStringArray = []
	for id in offerings:
		var item := GameState._resolve_item(id)
		parts.append("%d %s" % [int(offerings[id]), item.display_name if item != null else id])
	return ", ".join(parts)


func _begin(player: Player) -> void:
	ritual_player = player
	phase = Phase.LIGHTING
	time_left = light_seconds
	for i in 3:
		var point := IncensePoint.new()
		point.altar = self
		point.position = Vector2.from_angle(-PI / 2.0 + i * TAU / 3.0) * point_radius
		add_child(point)
		_points.append(point)
	Notify.say("Sesajen diterima. Nyalakan tiga titik kemenyan di sekitar altar dalam %d detik." % roundi(light_seconds))


func light_point(point: IncensePoint, _player: Player) -> void:
	if phase != Phase.LIGHTING or point.lit:
		return
	point.lit = true
	if _points.all(func(p: IncensePoint) -> bool: return p.lit):
		_summon()
	else:
		Notify.say("Titik kemenyan menyala (%d/3)." % _points.filter(func(p: IncensePoint) -> bool: return p.lit).size())


func _summon() -> void:
	phase = Phase.ENDURE
	time_left = endure_seconds
	var horror := _night_horror()
	if horror != null and penunggu_scene != null:
		penunggu = horror.call("_spawn_scene", penunggu_scene) as NightStalker
	if penunggu == null:
		_finish(false, "Penunggu tidak bisa bangkit di sini.")
		return
	Notify.say("%s bangkit! Bertahan %d detik tanpa tersentuh." % [display_name, roundi(endure_seconds)])


func _night_horror() -> Node:
	if not is_instance_valid(ritual_player) or ritual_player.hud_ui == null:
		return null
	return ritual_player.hud_ui.get_node_or_null("NightHorror")


func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	if not is_instance_valid(ritual_player) or ritual_player.world_root() != _world():
		_finish(false, "")
		return
	if DayCycle.hour >= 5 and DayCycle.hour < 19:
		_finish(false, "Subuh tiba. Ritual gagal; sesajen hangus.")
		return
	time_left -= delta
	match phase:
		Phase.LIGHTING:
			if time_left <= 0.0:
				_finish(false, "Kemenyan tak sempat menyala semua. Ritual gagal; sesajen hangus.")
		Phase.ENDURE:
			if is_instance_valid(penunggu) and penunggu.has_meta(&"touched"):
				_finish(false, "%s menangkapmu. Ritual gagal; coba lagi malam lain." % display_name)
			elif not is_instance_valid(penunggu) or penunggu._leaving:
				_finish(true, "")
			elif time_left <= 0.0:
				penunggu.leave()
				_finish(true, "")


func _world() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root and not (node.get_parent() is SubViewport):
		node = node.get_parent()
	return node


func _finish(success: bool, message: String) -> void:
	if success:
		GameState.horror.mark_ritual(area_id)
		GameState.horror.record_survival(ghost_id, display_name, ritual_player.data if is_instance_valid(ritual_player) else null)
		var amount := 2 if GameState.horror.is_kliwon() else 1
		var left := ritual_player.data.add_item(reward_item, amount) if is_instance_valid(ritual_player) else amount
		var item := GameState._resolve_item(reward_item)
		var name_text := item.display_name if item != null else reward_item
		Notify.say("%s tenang kembali. Kamu menerima %d %s%s." % [display_name, amount, name_text, " (tas penuh, sebagian tertinggal)" if left > 0 else ""])
	else:
		if is_instance_valid(penunggu) and not penunggu._leaving:
			penunggu.leave()
		if not message.is_empty():
			Notify.say(message)
	for point in _points:
		if is_instance_valid(point):
			point.queue_free()
	_points.clear()
	penunggu = null
	ritual_player = null
	phase = Phase.IDLE
	queue_redraw()


func _draw() -> void:
	# Altar batu dengan tumpeng sesajen kecil (sementara, sampai ada sprite).
	draw_rect(Rect2(-14, -6, 28, 10), Color(0.32, 0.31, 0.3))
	draw_rect(Rect2(-12, -9, 24, 4), Color(0.45, 0.43, 0.4))
	draw_rect(Rect2(-14, 4, 28, 2), Color(0.18, 0.17, 0.16))
	draw_circle(Vector2(-6, -11), 2.0, Color(0.95, 0.9, 0.7))
	draw_circle(Vector2(5, -11), 2.0, Color(0.85, 0.35, 0.3))
	if phase != Phase.IDLE:
		draw_arc(Vector2.ZERO, point_radius, 0.0, TAU, 40, Color(1.8, 0.9, 0.5, 0.25), 1.0)
