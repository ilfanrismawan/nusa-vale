class_name Enemy
extends CharacterBody2D

## Musuh: bisa diserang, melukai pemain yang menyentuhnya, lalu mati dan menjatuhkan item.
## Data dari EnemyData (resources/enemies). AI: Behavior Tree (GDD 8.2-B, pohonnya di EnemyBrain)
## dengan kerucut pandang + cahaya, pendengaran, status waspada (tenang, curiga, aggro, mengepung,
## mundur), token serang bergiliran, feint, dan panggilan bantuan.
## Soulslike (GDD 8.2-A): poise tersembunyi; pecah atau kena parry = terhuyung (STAGGER),
## menerima damage lebih besar, dan bisa diriposte (pukulan kritis).

signal died(enemy: Enemy)
signal state_changed(state: AiState)
signal alert_changed(alert: Alert)

## Aksi/animasi yang sedang dijalankan. Nilai baru selalu ditambah di akhir.
enum AiState { IDLE, PATROL, CHASE, WINDUP, ATTACK, RECOVER, HURT, RETURN, STAGGER, FLANK, INVESTIGATE, RETREAT, FEINT }
## Status kesadaran (GDD 8.2-B3).
enum Alert { CALM, SUSPICIOUS, AGGRO, FLANK, RETREAT }

const HIT_INVULNERABLE := 0.2
const CONTACT_COOLDOWN := 0.8
const KNOCKBACK_DECAY := 10.0
## Baris sheet musuh: bawah, atas, kanan, kiri.
const DIRECTIONS := ["down", "up", "right", "left"]
## Jarak dianggap sudah sampai di titik patroli/asal.
const ARRIVE_DISTANCE := 3.0
## Warna kedip saat ancang-ancang menyerang.
const WINDUP_TINT := Color(1.8, 0.75, 0.75)
## Warna kedip saat terhuyung.
const STAGGER_TINT := Color(1.6, 1.5, 0.6)
## Lama lompat mundur setelah feint.
const FEINT_HOP_TIME := 0.18
## Kecepatan berjalan waspada saat memeriksa suara (x patrol_speed).
const INVESTIGATE_SPEED_SCALE := 1.4
const LOOK_DIRECTIONS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
## Warna kerucut pandang debug per status waspada.
const ALERT_COLORS := {
	Alert.CALM: Color(0.4, 1.0, 0.5, 0.12),
	Alert.SUSPICIOUS: Color(1.0, 0.85, 0.3, 0.18),
	Alert.AGGRO: Color(1.0, 0.3, 0.3, 0.18),
	Alert.FLANK: Color(1.0, 0.5, 0.2, 0.18),
	Alert.RETREAT: Color(0.4, 0.6, 1.0, 0.18),
}

var data: EnemyData
var hp := 1
## false = AI berhenti (musuh target diam; juga dipakai tes).
var ai_enabled := true
var ai_state := AiState.IDLE
var target: Player
## Titik asal: pusat patroli dan tempat pulang.
var home := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _contact: Area2D
var _invulnerable := 0.0
var _knockback := Vector2.ZERO
var _dead := false
var _touching: Array[Player] = []
var _contact_timer := 0.0
var _facing := "down"
var _state_time := 0.0
var _patrol_point := Vector2.ZERO
var _attack_dir := Vector2.DOWN
var _attack_landed := false
var _windup_tween: Tween
## Efek status dari senjata tier tinggi (GDD 8.2, v3.3): terbakar, dingin, api gelap.
var _burn_left := 0.0
var _burn_timer := 0.0
var _burn_damage := 0
var _burn_interval := 0.5
var _burn_fx: WeaponTierFx
var _chill_left := 0.0
var _chill_scale := 1.0
var _chill_fx: WeaponTierFx
var _status_defense := 1.0
var _status_vfx := 0.0
var poise := 20.0
var _poise_rest := 0.0
var _stagger_time := 1.0
var alert := Alert.CALM
var brain: BehaviorTree
## Mundur sudah dipakai dan musuh kini nekat (serangan lebih cepat).
var desperate := false
var help_called := false
var _move := Vector2.ZERO
var _face_dir := Vector2.DOWN
var _perceive_timer := 0.0
var _since_seen := 0.0
var _last_seen := Vector2.ZERO
var _suspicious := false
var _suspicion_point := Vector2.ZERO
var _investigate_left := 0.0
var _look_timer := 0.0
var _returning := false
var _retreat_left := 0.0
var _ticket_rest := 0.0
## Arah mengitari pemain (1 / -1), dipilih acak supaya kelompok menyebar.
var _circle_side := 1.0
var _debug_drawn := false

static func spawn(p_data: EnemyData, parent: Node, world_pos: Vector2) -> Enemy:
	if p_data == null or parent == null:
		return null
	var enemy := Enemy.new()
	enemy.data = p_data
	enemy.name = "Enemy_%s" % p_data.id
	enemy.home = world_pos
	parent.add_child(enemy)
	enemy.global_position = world_pos
	return enemy

func _ready() -> void:
	add_to_group(Combat.DAMAGEABLE_GROUP)
	add_to_group(&"enemies")
	if data == null:
		push_warning("Enemy tanpa EnemyData")
		queue_free()
		return
	hp = data.max_hp
	poise = data.poise
	ai_enabled = data.ai_enabled
	if home == Vector2.ZERO:
		home = global_position
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	body_shape.shape = circle
	add_child(body_shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = data.sprite_offset
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	brain = EnemyBrain.build(self)
	_circle_side = 1.0 if randf() < 0.5 else -1.0
	_perceive_timer = randf() * Perception.RULES.perception_interval
	_enter(AiState.IDLE)
	_face(LOOK_DIRECTIONS[randi() % LOOK_DIRECTIONS.size()])

	_contact = Area2D.new()
	_contact.monitorable = false
	_contact.collision_mask = 0xFFFFFFFF
	var contact_shape := CollisionShape2D.new()
	var contact_circle := CircleShape2D.new()
	contact_circle.radius = data.body_radius + 3.0
	contact_shape.shape = contact_circle
	_contact.add_child(contact_shape)
	add_child(_contact)
	_contact.body_entered.connect(func(body: Node2D):
		if body is Player and not _touching.has(body):
			_touching.append(body)
			_contact_timer = 0.0)
	_contact.body_exited.connect(func(body: Node2D):
		if body is Player:
			_touching.erase(body))

## Satu animasi per arah (idle_down, walk_left, ...); sheet 1 baris dipakai untuk semua arah.
## Jumlah frame dihitung dari lebar gambar.
func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for entry in [["idle", "Idle.png", true], ["walk", "Walk.png", true], ["attack", "Attack.png", false], ["damage", "Damage.png", false], ["dead", "Dead.png", false]]:
		var path: String = data.sprite_folder.path_join(entry[1])
		var sheet: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		var columns := maxi(1, floori(float(sheet.get_width()) / data.frame_size.x)) if sheet != null else 0
		var rows := clampi(floori(float(sheet.get_height()) / data.frame_size.y), 1, DIRECTIONS.size()) if sheet != null else 0
		for d in DIRECTIONS.size():
			var anim := StringName("%s_%s" % [entry[0], DIRECTIONS[d]])
			frames.add_animation(anim)
			frames.set_animation_loop(anim, entry[2])
			frames.set_animation_speed(anim, data.animation_fps)
			var row := d if d < rows else 0
			for column in columns:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(Vector2(column * data.frame_size.x, row * data.frame_size.y), Vector2(data.frame_size))
				frames.add_frame(anim, atlas)
	return frames

func has_animation(action: String) -> bool:
	return _sprite.sprite_frames.get_frame_count(StringName("%s_down" % action)) > 0

## Memutar animasi `action` ke arah hadap. walk/attack tanpa gambar memakai idle.
func _play(action: String, restart: bool = false) -> void:
	if not has_animation(action):
		action = "idle"
	var anim := StringName("%s_%s" % [action, _facing])
	if _sprite.sprite_frames.get_frame_count(anim) == 0:
		return
	if _sprite.animation == anim and _sprite.is_playing() and not restart:
		return
	_sprite.play(anim)
	if restart:
		_sprite.set_frame_and_progress(0, 0.0)

func _current_action() -> String:
	return String(_sprite.animation).get_slice("_", 0)

## Ganti arah hadap; idle/jalan melanjutkan frame yang sama supaya langkah tidak tersendat.
func _face(direction: Vector2) -> void:
	if direction.length() < 0.01:
		return
	_face_dir = direction.normalized()
	var facing: String
	if absf(direction.x) > absf(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"
	if facing == _facing:
		return
	_facing = facing
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	var action := _current_action()
	_play(action, true)
	if action in ["idle", "walk"]:
		_sprite.set_frame_and_progress(frame, progress)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_update_status(delta)
	if _dead:
		return
	if ai_state != AiState.STAGGER:
		if _poise_rest > 0.0:
			_poise_rest -= delta
		else:
			poise = minf(data.poise, poise + data.poise_regen * delta)
	# Terhuyung tetap berakhir walau AI mati (musuh target diam).
	var move := _think(delta) if ai_enabled or ai_state == AiState.STAGGER else Vector2.ZERO
	velocity = move * status_speed_scale() + _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, minf(1.0, KNOCKBACK_DECAY * delta))
	if velocity.length() > 0.5:
		move_and_slide()
	if Perception.debug_draw or _debug_drawn:
		queue_redraw()
	if data.contact_damage and not _touching.is_empty() and _contact_active():
		_contact_timer -= delta
		if _contact_timer <= 0.0:
			_contact_timer = CONTACT_COOLDOWN
			for player: Player in _touching.duplicate():
				if is_instance_valid(player):
					_hit_player(player, (player.global_position - global_position).normalized())

#region AI

func _enter(state: AiState) -> void:
	ai_state = state
	_state_time = 0.0
	_stop_windup_tint()
	match state:
		AiState.IDLE:
			# Waktu diam dihitung naik dari angka negatif ke 0.
			_state_time = -randf_range(data.idle_time_min, maxf(data.idle_time_min, data.idle_time_max))
			_look_timer = randf_range(0.8, 1.6)
			_play("idle")
		AiState.PATROL:
			_patrol_point = home + Vector2.from_angle(randf() * TAU) * randf_range(data.patrol_radius * 0.3, data.patrol_radius)
			_play("walk")
		AiState.CHASE, AiState.RETURN, AiState.FLANK, AiState.INVESTIGATE, AiState.RETREAT:
			_play("walk")
		AiState.WINDUP, AiState.FEINT:
			# Feint sengaja terlihat sama dengan ancang-ancang sungguhan.
			_attack_dir = _direction_to_target()
			_face(_attack_dir)
			_play("idle")
			_start_windup_tint()
			CombatJuice.squash(_sprite, 0.18)
		AiState.ATTACK:
			_attack_landed = false
			if _swings():
				_play("attack", true)
			else:
				_play("walk", true)
				CombatJuice.squash(_sprite, 0.3)
		AiState.RECOVER:
			_play("idle")
		AiState.HURT:
			_play("damage" if has_animation("damage") else "idle", true)
		AiState.STAGGER:
			_play("damage" if has_animation("damage") else "idle", true)
			_start_windup_tint(STAGGER_TINT)
			CombatJuice.enemy_text(global_position + Vector2(0, -20), "Goyah!", Color(1.0, 0.9, 0.4))
	state_changed.emit(state)

## Sentuhan badan melukai pemain saat ini? Boss mematikannya saat melayang di udara.
func _contact_active() -> bool:
	return ai_state != AiState.STAGGER

func _swings() -> bool:
	return data.attack_style == EnemyData.AttackStyle.SWING and has_animation("attack")

## Satu langkah AI. Mengembalikan kecepatan gerak (tanpa knockback).
## Aksi yang sedang terkunci (ancang-ancang, serangan, tertegun, terhuyung) dijalankan di sini;
## selebihnya keputusan diambil Behavior Tree (EnemyBrain).
func _think(delta: float) -> Vector2:
	_state_time += delta
	_ticket_rest = maxf(0.0, _ticket_rest - delta)
	if target != null and not _target_valid(target):
		_lose_target(false)
	match ai_state:
		AiState.WINDUP:
			if _state_time >= data.attack_windup * _tempo():
				_enter(AiState.ATTACK)
			return Vector2.ZERO
		AiState.FEINT:
			# Ancang-ancang palsu, lalu melompat mundur tanpa menyerang.
			var fake := data.attack_windup * 0.7 * _tempo()
			if _state_time < fake:
				return Vector2.ZERO
			if _state_time < fake + FEINT_HOP_TIME:
				return -_attack_dir * data.chase_speed * 1.6
			_finish_attack()
			return Vector2.ZERO
		AiState.ATTACK:
			if _swings():
				return Vector2.ZERO
			if not _attack_landed and target != null and _target_distance() <= data.body_radius + 8.0:
				_attack_landed = true
				_hit_player(target, _attack_dir)
			if _state_time >= data.lunge_time:
				_enter(AiState.RECOVER)
				return Vector2.ZERO
			return _attack_dir * data.lunge_speed
		AiState.RECOVER:
			if _state_time >= data.attack_cooldown * _tempo():
				_finish_attack()
			return Vector2.ZERO
		AiState.HURT:
			if _state_time >= data.hurt_stun:
				_enter(AiState.CHASE if target != null else AiState.IDLE)
			return Vector2.ZERO
		AiState.STAGGER:
			if _state_time >= _stagger_time:
				poise = data.poise
				_enter(AiState.CHASE if target != null else AiState.IDLE)
			return Vector2.ZERO
	_perceive(delta)
	_move = Vector2.ZERO
	brain.tick(delta)
	return _move

## Serangan atau feint selesai: lepas token supaya kawan bergantian menyerang.
func _finish_attack() -> void:
	AttackTickets.release(self)
	_ticket_rest = Perception.RULES.ticket_rest
	_enter(AiState.CHASE if target != null else AiState.IDLE)

func _tempo() -> float:
	# Dingin: ancang-ancang dan jeda serangan ikut melambat (separuh dari perlambatan gerak).
	var chill := 1.0 + (1.0 - _chill_scale) * 0.5 if _chill_left > 0.0 else 1.0
	return (data.desperate_speed_scale if desperate else 1.0) * chill

## Jalan ke titik; sampai (atau tersangkut tembok) = kembali diam.
func _walk_to(point: Vector2, speed: float) -> Vector2:
	var offset := point - global_position
	if offset.length() <= ARRIVE_DISTANCE or _stuck():
		_enter(AiState.IDLE)
		return Vector2.ZERO
	var dir := offset.normalized()
	_face(dir)
	return dir * speed

func _stuck() -> bool:
	return _state_time > 0.5 and get_slide_collision_count() > 0 and get_real_velocity().length() < 1.0

func _target_valid(player: Player) -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and player.visible and not player.is_defeated and player.data.hp > 0

func _target_point(player: Player) -> Vector2:
	return player.global_position + Player.FEET_OFFSET

func _target_distance() -> float:
	return global_position.distance_to(_target_point(target)) if target != null else INF

func _direction_to_target() -> Vector2:
	if target == null:
		return _face_dir
	var offset := _target_point(target) - global_position
	return offset.normalized() if offset.length() > 0.01 else _face_dir

## Ayunan (SWING): damage di frame attack_hit_frame bila pemain masih di depan dan dalam jangkauan.
func _on_frame_changed() -> void:
	if ai_state != AiState.ATTACK or _attack_landed or _current_action() != "attack":
		return
	if _sprite.frame < data.attack_hit_frame:
		return
	_attack_landed = true
	if target != null and _target_distance() <= data.attack_range + 6.0 and _direction_to_target().dot(_attack_dir) > 0.2:
		_hit_player(target, _attack_dir)

func _hit_player(player: Player, direction: Vector2) -> void:
	player.take_hit(data.attack, self, direction * 14.0)

func _start_windup_tint(tint: Color = WINDUP_TINT) -> void:
	_windup_tween = create_tween().set_loops()
	_windup_tween.tween_property(_sprite, "self_modulate", tint, 0.08)
	_windup_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.08)

func _stop_windup_tint() -> void:
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	_windup_tween = null
	if _sprite != null:
		_sprite.self_modulate = Color.WHITE

#endregion

#region Persepsi

## Jarak pandang sekarang (aggro_radius dikali cahaya gua/malam).
func vision_range() -> float:
	return data.aggro_radius * Perception.light_scale(self)

## Arah hadap musuh (untuk kerucut pandang).
func facing_vector() -> Vector2:
	return _face_dir

func look_toward(point: Vector2) -> void:
	_face(point - global_position)

func can_see_point(point: Vector2) -> bool:
	var offset := point - global_position
	if offset.length() < 0.5:
		return true
	return absf(rad_to_deg(_face_dir.angle_to(offset))) <= data.vision_angle_deg * 0.5

## Penglihatan dicek berkala (Perception.RULES.perception_interval), bukan tiap frame.
func _perceive(delta: float) -> void:
	_perceive_timer -= delta
	if _perceive_timer > 0.0:
		return
	var interval := Perception.RULES.perception_interval
	_perceive_timer = interval
	if target != null:
		# Sudah bertarung: cukup garis pandang (tanpa kerucut) untuk terus melacak pemain.
		var point := _target_point(target)
		if Perception.line_of_sight(self, global_position, point, target):
			_since_seen = 0.0
			_last_seen = point
		else:
			_since_seen += interval
		return
	var glimpse := Vector2.INF
	var sight := vision_range()
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		var player := node as Player
		if not _target_valid(player):
			continue
		var point := _target_point(player)
		var distance := global_position.distance_to(point)
		if distance <= data.close_sense_radius:
			_spot(player)
			return
		if distance > sight * data.glimpse_range_scale or not can_see_point(point):
			continue
		if not Perception.line_of_sight(self, global_position, point, player):
			continue
		if distance <= sight:
			_spot(player)
			return
		glimpse = point
	if glimpse != Vector2.INF:
		_suspect(glimpse)

## Pemain ketahuan: aggro penuh.
func _spot(player: Player) -> void:
	var was_calm := target == null
	target = player
	_since_seen = 0.0
	_last_seen = _target_point(player)
	_suspicious = false
	_returning = false
	if was_calm:
		_set_alert(Alert.AGGRO)

## Ada yang mencurigakan di `point`: berjalan waspada ke sana.
func _suspect(point: Vector2) -> void:
	if target != null or _dead:
		return
	_suspicion_point = point
	_suspicious = true
	_investigate_left = data.investigate_time
	_returning = false
	_set_alert(Alert.SUSPICIOUS)

## Dipanggil Perception.noise. true bila musuh ini bereaksi.
func hear(point: Vector2, _maker: Node = null) -> bool:
	if _dead or not ai_enabled or target != null or ai_state == AiState.STAGGER:
		return false
	_suspect(point)
	look_toward(point)
	return true

## Dipanggil kawan yang mundur (Perception.call_for_help). true bila ikut menyerang.
func answer_help(player: Player, _caller: Enemy) -> bool:
	if _dead or not ai_enabled or target != null or not _target_valid(player):
		return false
	_spot(player)
	look_toward(_target_point(player))
	return true

## Kehilangan target. give_up = pemain kabur terlalu jauh (pulang); selain itu cari di posisi
## terakhir pemain terlihat.
func _lose_target(give_up: bool) -> void:
	AttackTickets.release(self)
	target = null
	if give_up:
		_suspicious = false
		_returning = true
		_set_alert(Alert.CALM)
	else:
		_suspect(_last_seen)

func _set_alert(value: Alert) -> void:
	if alert == value:
		return
	var previous := alert
	alert = value
	match value:
		Alert.SUSPICIOUS:
			CombatJuice.enemy_text(global_position + Vector2(0, -22), "?", Color(1.0, 0.85, 0.3))
		Alert.AGGRO:
			if previous == Alert.CALM or previous == Alert.SUSPICIOUS:
				CombatJuice.enemy_text(global_position + Vector2(0, -22), "!", Color(1.0, 0.35, 0.3), true)
	alert_changed.emit(value)

#endregion

#region Behavior Tree

func bt_has_target(_bb = null) -> bool:
	if target == null:
		return false
	if _target_distance() > data.give_up_radius or global_position.distance_to(home) > data.give_up_radius:
		_lose_target(true)
		return false
	if data.memory_time > 0.0 and _since_seen > data.memory_time:
		_lose_target(false)
		return false
	return true

func bt_in_attack_range(_bb = null) -> bool:
	return target != null and _target_distance() <= data.attack_range

## Minta token serang. Baru selesai menyerang dan ada kawan yang menunggu = beri giliran.
func bt_take_ticket(_bb = null) -> bool:
	if target == null:
		return false
	if AttackTickets.holds(self, target):
		return true
	if _ticket_rest > 0.0 and _rivals_waiting():
		return false
	return AttackTickets.request(self, target)

func _rivals_waiting() -> bool:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other != null and other != self and other.target == target and not other.is_dead() and not AttackTickets.holds(other, target):
			return true
	return false

func bt_roll_feint(_bb = null) -> bool:
	return data.feint_chance > 0.0 and randf() < data.feint_chance

func bt_feint(_bb = null) -> int:
	_enter(AiState.FEINT)
	return BehaviorTree.SUCCESS

func bt_attack(_bb = null) -> int:
	_set_alert(Alert.AGGRO)
	_enter(AiState.WINDUP)
	return BehaviorTree.SUCCESS

func bt_chase(_bb = null) -> int:
	_set_alert(Alert.AGGRO)
	if ai_state != AiState.CHASE:
		_enter(AiState.CHASE)
	var dir := _direction_to_target()
	_face(dir)
	_move = dir * data.chase_speed
	return BehaviorTree.RUNNING

## Tanpa token: mengepung di luar jangkauan pemain, bergeser ke sisi/belakangnya, menjaga
## jarak dari kawan (GDD 8.2-B3 Flanking / Repositioning).
func bt_flank(bb: BehaviorTree.Blackboard = null) -> int:
	_set_alert(Alert.FLANK)
	if ai_state != AiState.FLANK:
		_enter(AiState.FLANK)
	var delta := bb.delta if bb != null else get_physics_process_delta_time()
	var center := _target_point(target)
	var offset := global_position - center
	var dir := offset.normalized() if offset.length() > 0.5 else Vector2.from_angle(randf() * TAU)
	var rules := Perception.RULES
	var facing := target.aim_vector()
	var step := rules.circle_speed * delta
	if facing.dot(dir) > -0.5:
		var side := signf(facing.cross(dir))
		dir = dir.rotated(step * (side if side != 0.0 else _circle_side))
	else:
		dir = dir.rotated(step * 0.3 * _circle_side)
	var ring := data.attack_range + rules.flank_extra_distance
	var to_goal := center + dir * ring - global_position
	var move := to_goal.normalized() * minf(data.chase_speed * 0.8, to_goal.length() * 6.0) if to_goal.length() > 1.0 else Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self or other.is_dead():
			continue
		var apart := global_position - other.global_position
		if apart.length() < rules.separation_radius and apart.length() > 0.01:
			move += apart.normalized() * data.chase_speed * 0.5 * (1.0 - apart.length() / rules.separation_radius)
	_face(center - global_position)
	_play("walk" if move.length() > 4.0 else "idle")
	_move = move
	return BehaviorTree.RUNNING

func bt_is_suspicious(_bb = null) -> bool:
	return _suspicious

## Berjalan waspada ke sumber gangguan, lalu menoleh kiri-kanan sebelum kembali tenang.
func bt_investigate(bb: BehaviorTree.Blackboard = null) -> int:
	var delta := bb.delta if bb != null else get_physics_process_delta_time()
	if ai_state != AiState.INVESTIGATE:
		_enter(AiState.INVESTIGATE)
	var offset := _suspicion_point - global_position
	if offset.length() > ARRIVE_DISTANCE * 2.0 and not _stuck():
		var dir := offset.normalized()
		_face(dir)
		_play("walk")
		_move = dir * data.patrol_speed * INVESTIGATE_SPEED_SCALE
		return BehaviorTree.RUNNING
	_play("idle")
	_investigate_left -= delta
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = 0.6
		_circle_side = -_circle_side
		_face(_face_dir.rotated(PI * 0.5 * _circle_side))
	if _investigate_left > 0.0:
		return BehaviorTree.RUNNING
	_suspicious = false
	_returning = global_position.distance_to(home) > data.patrol_radius + ARRIVE_DISTANCE
	_set_alert(Alert.CALM)
	_enter(AiState.IDLE)
	return BehaviorTree.SUCCESS

func bt_should_return(_bb = null) -> bool:
	return _returning

func bt_return_home(_bb = null) -> int:
	if ai_state != AiState.RETURN:
		_enter(AiState.RETURN)
	_move = _walk_to(home, data.chase_speed)
	if ai_state != AiState.RETURN:
		_returning = false
		return BehaviorTree.SUCCESS
	return BehaviorTree.RUNNING

## Diam, menoleh sesekali, lalu patroli acak di sekitar titik asal.
func bt_patrol(bb: BehaviorTree.Blackboard = null) -> int:
	_set_alert(Alert.CALM)
	match ai_state:
		AiState.PATROL:
			_move = _walk_to(_patrol_point, data.patrol_speed)
		AiState.IDLE:
			if _state_time >= 0.0 and data.patrol_radius > 0.0 and data.patrol_speed > 0.0:
				_enter(AiState.PATROL)
			elif _state_time >= 0.0:
				_enter(AiState.IDLE)
			else:
				_look_timer -= bb.delta if bb != null else get_physics_process_delta_time()
				if _look_timer <= 0.0:
					_look_timer = randf_range(1.0, 2.0)
					_face(LOOK_DIRECTIONS[randi() % LOOK_DIRECTIONS.size()])
		_:
			_enter(AiState.IDLE)
	return BehaviorTree.RUNNING

func bt_should_retreat(_bb = null) -> bool:
	return data.retreat_hp_ratio > 0.0 and target != null and hp <= data.max_hp * data.retreat_hp_ratio

## HP rendah: mundur ke belakang kawan terdekat (atau menjauh) sambil tetap menghadap pemain,
## memanggil bantuan sekali, lalu kembali bertarung dalam mode nekat (GDD 8.2-B3).
func bt_retreat(bb: BehaviorTree.Blackboard = null) -> int:
	if ai_state != AiState.RETREAT:
		_enter(AiState.RETREAT)
		_retreat_left = data.retreat_time
		AttackTickets.release(self)
		_set_alert(Alert.RETREAT)
		if data.calls_for_help and Perception.call_for_help(self, target) > 0:
			help_called = true
			CombatJuice.enemy_text(global_position + Vector2(0, -22), "!!", Color(1.0, 0.55, 0.3), true)
	_retreat_left -= bb.delta if bb != null else get_physics_process_delta_time()
	if _retreat_left <= 0.0:
		desperate = true
		_enter(AiState.CHASE)
		return BehaviorTree.SUCCESS
	var threat := _target_point(target)
	var away := (global_position - threat).normalized()
	var dir := away
	var ally := _nearest_ally()
	if ally != null:
		var cover := ally.global_position + (ally.global_position - threat).normalized() * 18.0
		if cover.distance_to(global_position) > ARRIVE_DISTANCE * 2.0:
			dir = (cover - global_position).normalized()
		else:
			dir = Vector2.ZERO
	_face(-away)
	_play("walk" if dir != Vector2.ZERO else "idle")
	_move = dir * data.chase_speed * 0.9
	return BehaviorTree.RUNNING

func bt_stop_retreat() -> void:
	if ai_state == AiState.RETREAT:
		_enter(AiState.IDLE)

func _nearest_ally() -> Enemy:
	var best: Enemy = null
	var best_distance := Perception.RULES.help_radius
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self or other.is_dead():
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best

## Jalur Behavior Tree yang sedang berjalan, mis. "root/combat/flank" (debug dan tes).
func brain_path() -> String:
	return brain.running_path() if brain != null else ""

#endregion

## Dipanggil serangan pemain. Mengembalikan true bila pukulan masuk.
func take_hit(attack: int, source: Node, knockback: Vector2 = Vector2.ZERO) -> bool:
	if _dead or _invulnerable > 0.0:
		return false
	_invulnerable = HIT_INVULNERABLE
	var critical := Combat.hit_critical
	var staggered := is_staggered()
	var damage := Combat.damage_after_defense(attack, 0 if Combat.hit_ignores_defense else defense())
	if staggered and not critical:
		damage = roundi(damage * Combat.RULES.staggered_damage_scale)
	hp = maxi(0, hp - damage)
	var heavy := CombatJuice.heavy_hit
	if critical:
		CombatJuice.enemy_text(global_position + Vector2(0, -26), "KRITIS!", Color(1.0, 0.4, 0.3), true)
	CombatJuice.damage_number(str(damage) + ("!" if heavy else ""), global_position + Vector2(0, -14), CombatJuice.HEAVY_COLOR if heavy else CombatJuice.HIT_COLOR, heavy)
	if not data.hit_feedback.is_empty():
		Juice.play(data.hit_feedback, global_position)
	CombatJuice.impact(damage, heavy)
	_knockback = knockback * 6.0 * (1.0 - data.knockback_resist)
	_flash()
	CombatJuice.squash(_sprite, 0.4 if heavy else 0.28)
	if hp <= 0:
		_die()
		return true
	# Senjata beradu terdengar musuh di sekitar (GDD 8.2-B2).
	Perception.noise(self, global_position, Perception.RULES.clash_noise_radius, source)
	# Dipukul dari jauh (panah/sihir) atau dari belakang pun langsung mengincar penyerangnya.
	var attacker := source as Player
	if _target_valid(attacker) and ai_enabled:
		_spot(attacker)
		look_toward(_target_point(attacker))
	elif _target_valid(attacker):
		target = attacker
	# Poise: pukulan biasa mengikis; habis = terhuyung. Riposte mengakhiri terhuyung.
	if critical:
		poise = data.poise
		if not ai_enabled:
			_enter(AiState.IDLE)
	elif staggered:
		return true
	else:
		poise -= Combat.hit_poise if Combat.hit_poise >= 0.0 else float(attack)
		_poise_rest = data.poise_regen_delay
		if poise <= 0.0:
			stagger(data.stagger_time)
			return true
	if ai_enabled:
		_enter(AiState.HURT)
	elif has_animation("damage"):
		_play("damage", true)
	return true

func is_dead() -> bool:
	return _dead

func _exit_tree() -> void:
	AttackTickets.release(self)

## Debug (Ctrl+F12): kerucut pandang berwarna status waspada dan lingkaran indra dekat.
func _draw() -> void:
	_debug_drawn = Perception.debug_draw
	if not Perception.debug_draw or _dead or data == null:
		return
	var color: Color = ALERT_COLORS.get(alert, Color(1, 1, 1, 0.15))
	var half := deg_to_rad(data.vision_angle_deg * 0.5)
	var reach := vision_range()
	var points := PackedVector2Array([Vector2.ZERO])
	var base := _face_dir.angle()
	for i in 13:
		points.append(Vector2.from_angle(base - half + half * 2.0 * i / 12.0) * reach)
	draw_colored_polygon(points, color)
	draw_arc(Vector2.ZERO, data.close_sense_radius, 0.0, TAU, 24, Color(color, 0.5), 1.0)

#region Soulslike

func is_staggered() -> bool:
	return ai_state == AiState.STAGGER and not _dead

## Terhuyung (poise pecah atau kena parry): berhenti, berkedip kuning, bisa diriposte.
func stagger(seconds: float) -> void:
	if _dead:
		return
	_stagger_time = seconds
	poise = 0.0
	AttackTickets.release(self)
	_enter(AiState.STAGGER)

## Pemain hanya bisa mem-parry serangan sungguhan (terjangan/ayunan), bukan sentuhan biasa.
func can_be_parried() -> bool:
	return not _dead and data.parryable and ai_state == AiState.ATTACK

func on_parried(by: Node) -> void:
	_attack_landed = true
	if by is Node2D:
		_knockback = (global_position - (by as Node2D).global_position).normalized() * 40.0
	stagger(Combat.RULES.parry_stagger_time)

## Kikisan poise pemain per serangan musuh ini.
func poise_damage_to_player() -> float:
	return data.poise_damage if data.poise_damage > 0.0 else data.attack * 1.5

#endregion

#region Efek status

## DEF saat ini (Api Gelap menurunkannya selama terbakar).
func defense() -> int:
	return roundi(data.defense * _status_defense)

## Pengali kecepatan gerak dari efek status (Dingin).
func status_speed_scale() -> float:
	return _chill_scale if _chill_left > 0.0 else 1.0

func is_burning() -> bool:
	return _burn_left > 0.0

func is_chilled() -> bool:
	return _chill_left > 0.0

## Tempelkan efek status tier senjata. Efek yang sama memperbarui durasi (yang terkuat dipakai).
func apply_status(fx: WeaponTierFx, attack: int) -> void:
	if _dead or fx == null:
		return
	var fresh := false
	match fx.status:
		WeaponTierFx.Status.BURN, WeaponTierFx.Status.DARK_FIRE:
			fresh = _burn_left <= 0.0
			var tick := maxi(1, roundi(attack * fx.burn_tick_ratio))
			if fresh or tick >= _burn_damage:
				_burn_damage = tick
				_burn_fx = fx
				_burn_interval = fx.burn_interval
				_status_defense = fx.defense_scale
			_burn_left = maxf(_burn_left, fx.status_duration)
			if fresh:
				_burn_timer = _burn_interval
		WeaponTierFx.Status.CHILL:
			fresh = _chill_left <= 0.0
			_chill_left = maxf(_chill_left, fx.status_duration)
			_chill_scale = minf(_chill_scale if not fresh else 1.0, fx.slow_scale)
			_chill_fx = fx
		_:
			return
	if fresh:
		CombatJuice.enemy_text(global_position + Vector2(0, -30), fx.status_name() + "!", fx.color)
		CombatJuice.motif_burst(global_position + Vector2(0, -6), fx, 8)
	_apply_status_tint()

func _update_status(delta: float) -> void:
	if _burn_left <= 0.0 and _chill_left <= 0.0:
		return
	if _chill_left > 0.0:
		_chill_left -= delta
		if _chill_left <= 0.0:
			_chill_left = 0.0
			_chill_scale = 1.0
			_apply_status_tint()
	if _burn_left > 0.0:
		_burn_left -= delta
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_burn_timer += _burn_interval
			_burn_tick()
			if _dead:
				return
		if _burn_left <= 0.0:
			_burn_left = 0.0
			_status_defense = 1.0
			_apply_status_tint()
	_status_vfx -= delta
	if _status_vfx <= 0.0:
		_status_vfx = 0.25
		var fx := _burn_fx if _burn_left > 0.0 else _chill_fx
		if fx != null:
			CombatJuice.motif_burst(global_position + Vector2(randf_range(-5.0, 5.0), -8.0), fx, 2)

## Satu tick terbakar: damage kecil tanpa i-frames, dorongan, atau menyela AI.
func _burn_tick() -> void:
	hp = maxi(0, hp - _burn_damage)
	var color := _burn_fx.color if _burn_fx != null else CombatJuice.HEAVY_COLOR
	CombatJuice.damage_number(str(_burn_damage), global_position + Vector2(randf_range(-6.0, 6.0), -12), color)
	if hp <= 0:
		_burn_left = 0.0
		_die()

## Warna tubuh selama efek: jingga saat terbakar, biru saat dingin.
func _apply_status_tint() -> void:
	var tint := Color.WHITE
	if _burn_left > 0.0 and _burn_fx != null:
		tint = Color.WHITE.lerp(_burn_fx.color, 0.35)
	elif _chill_left > 0.0 and _chill_fx != null:
		tint = Color.WHITE.lerp(_chill_fx.color, 0.45)
	modulate = Color(tint, modulate.a)

#endregion

func _flash() -> void:
	_sprite.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

func _on_animation_finished() -> void:
	if _dead:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
		return
	match _current_action():
		"damage":
			if not ai_enabled:
				_play("idle")
		"attack":
			if ai_state == AiState.ATTACK:
				_enter(AiState.RECOVER)

func _die() -> void:
	_dead = true
	AttackTickets.release(self)
	_stop_windup_tint()
	_touching.clear()
	remove_from_group(Combat.DAMAGEABLE_GROUP)
	collision_layer = 0
	_contact.set_deferred("monitoring", false)
	if not data.death_feedback.is_empty():
		Juice.play(data.death_feedback, global_position)
	CombatJuice.death_burst(global_position, _particle_color())
	CombatJuice.squash(_sprite, 0.5)
	_drop_loot()
	died.emit(self)
	if has_animation("dead"):
		_play("dead", true)
	else:
		_on_animation_finished()

## Warna partikel ledakan mati: ikut warna partikel suara-kena musuh ini.
func _particle_color() -> Color:
	var fb := Juice.get_feedback(data.hit_feedback) if not data.hit_feedback.is_empty() else null
	return fb.particle_color if fb != null and fb.particle_count > 0 else Color(0.95, 0.95, 0.9)

func _drop_loot() -> void:
	if data.drop_item_id.is_empty() or randf() > data.drop_chance:
		return
	var amount := randi_range(data.drop_min, maxi(data.drop_min, data.drop_max))
	var parent := get_parent()
	var spot := global_position
	var item_id := data.drop_item_id
	# Satu pickup per butir (maks. 6) supaya jarahan berhamburan; sisanya di pickup terakhir.
	var pieces := clampi(amount, 1, 6)
	for i in pieces:
		var count := 1 if i < pieces - 1 else amount - (pieces - 1)
		(func(): ItemPickup.spawn(parent, spot, item_id, count)).call_deferred()
