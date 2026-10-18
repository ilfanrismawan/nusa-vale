class_name DodgeState
extends State

## Dodge roll (GDD 8.2-A2). Jarak, lama, dan i-frames tergantung beban perlengkapan
## (0 = Fast Roll, 1 = Medium, 2 = Heavy Fat-Roll; angka di CombatRules).
## Belum ada sheet animasi roll: badan berguling lewat putaran/pipihan sprite + bayangan jejak.
## Dibuat ToolController saat _ready; dimulai lewat start() lalu change_state().

var idle_state: State
var direction := Vector2.DOWN
var roll_class := 0
var _time := 0.0
var _duration := 0.3
var _speed := 0.0
var _ghost_timer := 0.0

func _init() -> void:
	animation_name = &"Run"

func start(p_direction: Vector2, p_roll_class: int) -> void:
	direction = p_direction.normalized() if p_direction.length() > 0.01 else Vector2.DOWN
	roll_class = p_roll_class
	var rules := Combat.RULES
	_duration = CombatRules.pick(rules.roll_time, roll_class, 0.35)
	# Kecepatan awal tinggi lalu melambat (ease-out kuadrat): jarak total = speed * durasi / 2.
	_speed = 2.0 * CombatRules.pick(rules.roll_distance, roll_class, 40.0) / maxf(0.05, _duration)

func enter() -> void:
	_time = 0.0
	_ghost_timer = 0.0
	animation_controller.release_pose()
	player.update_facing_direction(direction, true)
	super.enter()
	animation_controller.sprite.speed_scale = 2.0
	player.combat.begin_iframes(CombatRules.pick(Combat.RULES.roll_iframes, roll_class, 0.2))
	Juice.play(&"swish", player.global_position, -5.0 - roll_class * 2.0)
	CombatJuice.dust(player.global_position + Player.FEET_OFFSET, direction)

func exit() -> void:
	var sprite := animation_controller.sprite
	sprite.speed_scale = 1.0
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	player.velocity = Vector2.ZERO
	player.combat.on_roll_finished()

func physics_update(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _duration, 0.0, 1.0)
	player.velocity = direction * _speed * (1.0 - t)
	player.move_and_slide()
	_animate(t)
	_ghost_timer -= delta
	if _ghost_timer <= 0.0 and t < 0.8:
		_ghost_timer = 0.05
		CombatJuice.ghost(player)
	if t >= 1.0:
		if roll_class >= 2:
			CombatJuice.dust(player.global_position + Player.FEET_OFFSET, -direction)
		transitioned.emit(idle_state)

## Roll ke samping: badan berputar satu putaran. Roll ke atas/bawah: badan memipih dan memantul.
func _animate(t: float) -> void:
	var sprite := animation_controller.sprite
	var spin := clampf(t / 0.85, 0.0, 1.0)
	if absf(direction.x) >= absf(direction.y):
		sprite.rotation = TAU * spin * signf(direction.x)
		sprite.scale = Vector2.ONE
	else:
		sprite.rotation = 0.0
		var squash := sin(spin * PI)
		sprite.scale = Vector2(1.0 + 0.25 * squash, 1.0 - 0.35 * squash)
	if spin >= 1.0:
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE
