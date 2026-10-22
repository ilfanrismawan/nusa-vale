class_name JumpState
extends State

## Lompat (GDD 4.3, seperti Story of Seasons: Grand Bazaar). Tekan lagi di udara = lompat ganda.
## Pakai alat sambil memegang benih di udara = benih ditebar ke petak cangkul di sekitar tempat
## mendarat (3x3). Lompat hanya visual: badan naik-turun di atas bayangan, tabrakan tetap sama.
## Tidak memakai stamina. Belum ada sheet animasi lompat: sprite jalan diangkat + bayangan.
## Dibuat ToolController saat _ready; dimulai lewat Player.try_jump().

const JUMP_TIME := 0.42
const JUMP_HEIGHT := 9.0
const DOUBLE_TIME := 0.4
const DOUBLE_HEIGHT := 8.0

var idle_state: State
## Ketinggian badan sekarang (piksel).
var height := 0.0
var double_used := false
## Benih yang ditebar saat mendarat (null = tidak menebar).
var scatter_item: ItemData
var _time := 0.0
var _duration := JUMP_TIME
var _start_height := 0.0
var _peak := JUMP_HEIGHT
var _sprite_home := Vector2.ZERO
var _shadow: JumpShadow

func _init() -> void:
	animation_name = &"Walk"

func enter() -> void:
	_time = 0.0
	_duration = JUMP_TIME
	_start_height = 0.0
	_peak = JUMP_HEIGHT
	height = 0.0
	double_used = false
	scatter_item = null
	animation_controller.release_pose()
	super.enter()
	animation_controller.sprite.speed_scale = 1.6
	_sprite_home = animation_controller.sprite.position
	if not is_instance_valid(_shadow):
		_shadow = JumpShadow.new()
		_shadow.name = "JumpShadow"
		_shadow.position = Player.FEET_OFFSET
		_shadow.z_index = -1
		player.add_child(_shadow)
	_shadow.visible = true
	_shadow.lift = 0.0
	Juice.play(&"swish", player.global_position, -12.0)
	CombatJuice.dust(player.global_position + Player.FEET_OFFSET, -player.facing_direction)

## Lompat ganda: busur baru dimulai dari ketinggian sekarang. false bila sudah dipakai.
func double_jump() -> bool:
	if double_used:
		return false
	double_used = true
	_start_height = height
	_time = 0.0
	_duration = DOUBLE_TIME
	_peak = DOUBLE_HEIGHT
	Juice.play(&"swish", player.global_position, -9.0)
	CombatJuice.dust(player.global_position + Player.FEET_OFFSET + Vector2(0, -height), Vector2.DOWN)
	return true

## Dipanggil ToolController saat pakai alat di udara sambil memegang benih.
func queue_scatter(item: ItemData) -> void:
	scatter_item = item

func physics_update(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _duration, 0.0, 1.0)
	height = lerpf(_start_height, 0.0, t) + 4.0 * _peak * t * (1.0 - t)
	var input_vector := player.get_input_vector()
	if input_vector != Vector2.ZERO:
		player.update_facing_direction(input_vector)
	var run_node := player.state_machine.get_node_or_null("RunState") as MoveState
	var multiplier := run_node.speed_multiplier if run_node != null and player.input.pressed(&"run") else 1.0
	player.velocity = input_vector * player.speed * multiplier * player.data.food_movement_multiplier() * player.combat_speed_scale()
	player.move_and_slide()
	animation_controller.sprite.position = _sprite_home + Vector2(0, -height)
	if is_instance_valid(_shadow):
		_shadow.lift = height
	if t >= 1.0:
		_land()

func _land() -> void:
	CombatJuice.dust(player.global_position + Player.FEET_OFFSET, player.facing_direction)
	if scatter_item != null:
		player.tool_controller.scatter_seeds(scatter_item)
		scatter_item = null
	transitioned.emit(idle_state)

func exit() -> void:
	var sprite := animation_controller.sprite
	sprite.position = _sprite_home
	sprite.speed_scale = 1.0
	height = 0.0
	scatter_item = null
	if is_instance_valid(_shadow):
		_shadow.visible = false


## Bayangan oval di kaki; mengecil saat badan makin tinggi.
class JumpShadow extends Node2D:
	var lift := 0.0:
		set(value):
			lift = value
			queue_redraw()

	func _draw() -> void:
		var scale_by := clampf(1.0 - lift / 30.0, 0.55, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 6.0 * scale_by, Color(0, 0, 0, 0.28 * scale_by))
