class_name LockOn
extends Node2D

## Kunci target (lock-on) seperti game soulslike (GDD 8.2-A): R3 gamepad, Q / klik tengah
## keyboard saat memegang senjata. Serangan, tangkisan, dan roll diam mengarah ke target;
## pemain tetap menghadap target saat berjalan (strafe). Gamepad: dorong stik kanan untuk
## pindah ke musuh lain di arah itu. Lepas otomatis bila target mati atau terlalu jauh.
## Dibuat Player saat _ready.

## Jangkauan mencari target dan batas lepas (piksel).
const ACQUIRE_RANGE := 150.0
const RELEASE_RANGE := 200.0
const SWITCH_COOLDOWN := 0.3
const MARKER_COLOR := Color(1.0, 0.85, 0.35)

var player: Player
var target: Node2D
var _switch_cooldown := 0.0
var _pulse := 0.0

func _ready() -> void:
	top_level = true
	z_index = 30
	z_as_relative = false

## Tekan tombol lock-on: kunci musuh terdekat di depan, atau lepas bila sudah terkunci.
func toggle() -> void:
	if has_target():
		release()
		return
	target = _find_target(player.aim_vector(), null)
	if target != null:
		Juice.play(&"swish", player.global_position, -14.0)
	else:
		CombatJuice.float_text(player, "Tidak ada target", Color(0.8, 0.8, 0.85))

func release() -> void:
	target = null
	queue_redraw()

func has_target() -> bool:
	return is_instance_valid(target) and target.is_inside_tree() \
		and not (target.has_method("is_dead") and target.call("is_dead"))

## Arah dari kaki pemain ke target (Vector2.ZERO bila tidak terkunci).
func direction() -> Vector2:
	if not has_target():
		return Vector2.ZERO
	var offset := target.global_position - (player.global_position + Player.FEET_OFFSET * 0.5)
	return offset.normalized() if offset.length() > 1.0 else Vector2.ZERO

func _process(delta: float) -> void:
	if player == null:
		return
	if target != null and (not has_target() or not player.holds_weapon() or player.is_defeated \
			or target.global_position.distance_to(player.global_position) > RELEASE_RANGE \
			or target.get_world_2d() != player.get_world_2d()):
		release()
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)
	if has_target():
		var stick := player.input.right_stick()
		if stick != Vector2.ZERO and _switch_cooldown <= 0.0:
			var next := _find_target(stick.normalized(), target)
			if next != null:
				target = next
				_switch_cooldown = SWITCH_COOLDOWN
		var state := player.state_machine.current_state
		if state is IdleState or state is MoveState:
			player.update_facing_direction(direction(), true)
		global_position = target.global_position
	_pulse += delta
	queue_redraw()

## Musuh hidup terdekat dalam jangkauan, mengutamakan yang searah `toward`.
func _find_target(toward: Vector2, exclude: Node2D) -> Node2D:
	var feet := player.global_position + Player.FEET_OFFSET
	var best: Node2D
	var best_score := INF
	for candidate in player.get_tree().get_nodes_in_group(&"enemies"):
		var node := candidate as Node2D
		if node == null or node == exclude or not node.is_visible_in_tree():
			continue
		if node.has_method("is_dead") and node.call("is_dead"):
			continue
		if node.get_world_2d() != player.get_world_2d():
			continue
		var offset: Vector2 = node.global_position - feet
		var distance := offset.length()
		if distance > ACQUIRE_RANGE:
			continue
		var facing := offset.normalized().dot(toward) if distance > 1.0 else 1.0
		if exclude != null and facing < 0.3:
			continue
		# Jarak dihukum bila di belakang pemain / arah stik.
		var score := distance * (2.0 - facing)
		if score < best_score:
			best = node
			best_score = score
	return best

func _draw() -> void:
	if not has_target():
		return
	var bob := sin(_pulse * 6.0) * 1.5
	var top := Vector2(0, -22.0 + bob)
	var points := PackedVector2Array([top + Vector2(0, -4), top + Vector2(4, 0), top + Vector2(0, 4), top + Vector2(-4, 0), top + Vector2(0, -4)])
	draw_polyline(points, Color(0, 0, 0, 0.6), 3.0)
	draw_polyline(points, MARKER_COLOR, 1.5)
	draw_arc(Vector2(0, 2), 9.0, 0.0, TAU, 20, Color(MARKER_COLOR, 0.45), 1.0)
