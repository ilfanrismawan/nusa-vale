class_name VillageNPC
extends CharacterBody2D

## Komponen komprehensif untuk Warga Desa Nusa Vale.
## Mendukung:
## - Siklus Jadwal Harian (Schedule) berbasis jam DayCycle
## - Pergerakan Waypoint/Pathing dengan navigasi mulus & anti-stuck
## - Animasi 4 arah lengkap (Idle: down/up/side, Walk: down/up/side)
## - Dialog berpotret (NPCDialogUI) yang adaptif terhadap jadwal
## - Jeda cerdas saat diajak bicara pemain & lanjut jalan setelah selesai

@export var npc_id: String = ""
@export var npc_name: String = "Warga Desa"
@export var role_title: String = ""
@export var portrait: Texture2D
## Texture2D / AtlasTexture keyed by neutral, happy, angry, etc.
@export var portrait_expressions: Dictionary[String, Texture2D] = {}
@export var dialog_expressions: PackedStringArray = []
## Activity name -> expression, or Array of expressions matching dialogue lines.
@export var activity_expressions: Dictionary = {}
@export var walk_speed: float = 38.0
@export var dialog_lines: PackedStringArray = [
	"Halo! Selamat menikmati harimu di Nusa Vale."
]

## Array entri jadwal harian.
## Setiap Dictionary berisi:
## - hour: int (0..23)
## - minute: int (0..59, default 0)
## - target_pos: Vector2 (posisi tujuan)
## - path: Array[Vector2] (waypoint perantara, opsional)
## - facing: String ("down", "up", "side_left", "side_right")
## - activity: String (nama aktivitas)
## - dialog_lines: PackedStringArray (dialog kontekstual saat jam ini)
@export var schedule: Array[Dictionary] = []

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _players: Array[Player] = []
var _dialog_ui: NPCDialogUI

# State Navigasi & Jadwal
var _active_schedule_idx: int = -1
var _active_path: Array[Vector2] = []
var _target_pos: Vector2 = Vector2.ZERO
var _desired_facing: String = "down"
var _current_activity: String = ""
var _schedule_dialog_lines: PackedStringArray = []
var _is_walking: bool = false
var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Pastikan layer collision sesuai untuk karakter/NPC
	collision_layer = 1
	collision_mask = 1

	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Dengarkan detak jam DayCycle
	if DayCycle != null and DayCycle.has_signal("time_tick"):
		DayCycle.time_tick.connect(_on_time_tick)
		# Terapkan posisi jadwal awal sesuai jam saat ini tanpa harus menunggu detak jam
		_check_schedule_for_time(DayCycle.hour, DayCycle.minute, true)
	else:
		_play_facing_idle("down")

func _on_time_tick(hour: int, minute: int) -> void:
	_check_schedule_for_time(hour, minute, false)

func _check_schedule_for_time(hour: int, minute: int, initial_warp: bool = false) -> void:
	if schedule.is_empty():
		return

	# Urutkan secara kronologis untuk mencari jadwal aktif yang paling sesuai
	var matched_idx: int = -1
	var current_total_minutes: int = hour * 60 + minute

	for i in range(schedule.size()):
		var entry: Dictionary = schedule[i]
		var entry_hour: int = entry.get("hour", 6)
		var entry_minute: int = entry.get("minute", 0)
		var entry_total_minutes: int = entry_hour * 60 + entry_minute

		if entry_total_minutes <= current_total_minutes:
			matched_idx = i

	# Jika sebelum jadwal pertama hari itu (misal subuh), gunakan jadwal terakhir (malam/tidur)
	if matched_idx == -1 and not schedule.is_empty():
		matched_idx = schedule.size() - 1

	if matched_idx != -1 and (matched_idx != _active_schedule_idx or initial_warp):
		_apply_schedule(matched_idx, initial_warp)

func _apply_schedule(idx: int, warp_instant: bool) -> void:
	_active_schedule_idx = idx
	var entry: Dictionary = schedule[idx]

	_target_pos = entry.get("target_pos", global_position)
	_desired_facing = entry.get("facing", "down")
	_current_activity = entry.get("activity", "")
	_schedule_dialog_lines = entry.get("dialog_lines", PackedStringArray())

	var waypoints: Array = entry.get("path", [])
	_active_path.clear()

	if warp_instant:
		# Tempatkan langsung di posisi target
		global_position = _target_pos
		_is_walking = false
		_play_facing_idle(_desired_facing)
	else:
		# Bangun rute navigasi
		for wp in waypoints:
			if wp is Vector2:
				_active_path.append(wp)
		# Pastikan titik tujuan akhir ada di ujung rute
		if _active_path.is_empty() or _active_path[_active_path.size() - 1].distance_to(_target_pos) > 4.0:
			_active_path.append(_target_pos)

		_is_walking = not _active_path.is_empty()
		_stuck_timer = 0.0
		_last_pos = global_position

func _physics_process(delta: float) -> void:
	# Jika sedang berbicara dengan pemain, hentikan gerakan
	if is_instance_valid(_dialog_ui):
		velocity = Vector2.ZERO
		return

	if not _is_walking or _active_path.is_empty():
		velocity = Vector2.ZERO
		return

	var current_target: Vector2 = _active_path[0]
	var to_target: Vector2 = current_target - global_position
	var dist: float = to_target.length()

	# Jika sudah dekat dengan waypoint saat ini
	if dist <= 4.0:
		_active_path.pop_front()
		_stuck_timer = 0.0
		if _active_path.is_empty():
			# Tiba di tujuan akhir
			global_position = _target_pos
			_is_walking = false
			velocity = Vector2.ZERO
			_play_facing_idle(_desired_facing)
			return
		else:
			current_target = _active_path[0]
			to_target = current_target - global_position

	# Gerakkan ke arah waypoint
	var dir: Vector2 = to_target.normalized()
	velocity = dir * walk_speed
	move_and_slide()
	_update_walk_animation(dir)

	# Anti-stuck: jika posisi tidak berubah signifikan selama beberapa detik
	if global_position.distance_to(_last_pos) < 1.0:
		_stuck_timer += delta
		if _stuck_timer >= 5.0:
			# Lewati waypoint yang macet dan lompat sedikit
			_active_path.pop_front()
			_stuck_timer = 0.0
			if _active_path.is_empty():
				global_position = _target_pos
				_is_walking = false
				_play_facing_idle(_desired_facing)
	else:
		_stuck_timer = 0.0
		_last_pos = global_position

func _update_walk_animation(dir: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if abs(dir.x) > abs(dir.y):
		if sprite.sprite_frames.has_animation("walk_side"):
			sprite.play("walk_side")
		sprite.flip_h = dir.x < 0
	else:
		sprite.flip_h = false
		if dir.y > 0 and sprite.sprite_frames.has_animation("walk_down"):
			sprite.play("walk_down")
		elif dir.y <= 0 and sprite.sprite_frames.has_animation("walk_up"):
			sprite.play("walk_up")

func _play_facing_idle(facing: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	match facing:
		"up":
			sprite.flip_h = false
			if sprite.sprite_frames.has_animation("idle_up"):
				sprite.play("idle_up")
		"side_left":
			sprite.flip_h = true
			if sprite.sprite_frames.has_animation("idle_side"):
				sprite.play("idle_side")
		"side_right", "side":
			sprite.flip_h = false
			if sprite.sprite_frames.has_animation("idle_side"):
				sprite.play("idle_side")
		_: # down
			sprite.flip_h = false
			if sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_dialog_ui):
		return
	var player := PlayerInput.find_presser(event, _players)
	if player != null:
		get_viewport().set_input_as_handled()
		interact(player)

## Dipanggil via raycast player atau proximity key
func interact(player: Player = null) -> void:
	if is_instance_valid(_dialog_ui):
		return
	if player == null:
		player = Coop.current_player() if Coop.active else get_tree().get_first_node_in_group("player")

	_face_player(player)

	# Pilih dialog: prioritaskan dialog kontekstual jadwal saat ini
	var lines_to_use: PackedStringArray = dialog_lines
	if not _schedule_dialog_lines.is_empty():
		lines_to_use = _schedule_dialog_lines

	if lines_to_use.is_empty():
		return

	_dialog_ui = load("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
	_dialog_ui.player = player
	_dialog_ui.npc_name = npc_name
	_dialog_ui.social_npc_id = npc_id
	_dialog_ui.role_title = role_title
	_dialog_ui.portrait_texture = portrait
	_dialog_ui.portrait_expressions = portrait_expressions
	_dialog_ui.line_expressions = dialog_expressions if _schedule_dialog_lines.is_empty() else PackedStringArray()
	var expression: Variant = activity_expressions.get(_current_activity, "neutral")
	if expression is String:
		_dialog_ui.default_expression = expression
	elif expression is Array or expression is PackedStringArray:
		_dialog_ui.line_expressions = PackedStringArray(expression)
	_dialog_ui.lines = lines_to_use
	
	_dialog_ui.finished.connect(_on_dialog_finished)
	Coop.ui_parent(player).add_child(_dialog_ui)

func _on_dialog_finished() -> void:
	_dialog_ui = null
	# Jika tidak sedang berjalan, kembalikan arah hadap sesuai jadwal
	if not _is_walking:
		_play_facing_idle(_desired_facing)

func _face_player(player: Player) -> void:
	if sprite == null or not is_instance_valid(player):
		return
	if not (player is CharacterBody2D):
		return

	var dir: Vector2 = player.global_position - global_position
	if abs(dir.x) > abs(dir.y):
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_side"):
			sprite.play("idle_side")
		sprite.flip_h = dir.x < 0
	else:
		sprite.flip_h = false
		if sprite.sprite_frames != null:
			if dir.y > 0 and sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
			elif dir.y <= 0 and sprite.sprite_frames.has_animation("idle_up"):
				sprite.play("idle_up")
