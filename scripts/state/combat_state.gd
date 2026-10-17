class_name CombatState
extends State

## Serangan dengan senjata yang dipegang di hotbar (pedang, busur, tongkat sihir).
## Dibuat ToolController saat _ready; dimulai lewat start() lalu change_state().

var idle_state: State
var weapon: ItemData
var style: WeaponStyle
var aim := Vector2.DOWN
## Anak panah yang sudah diambil dari tas untuk tembakan ini (null untuk pedang/tongkat).
var arrow: ItemData
## Urutan pukulan dalam combo (0 = pertama). Diatur ToolController.
var combo_step := 0
## Klik kiri saat serangan berjalan: sambung pukulan berikutnya begitu animasi selesai.
var combo_queued := false
var _performed := false
var _hit_frame := 0

func start(p_weapon: ItemData, p_style: WeaponStyle, p_aim: Vector2, p_arrow: ItemData = null, p_combo_step: int = 0) -> void:
	weapon = p_weapon
	style = p_style
	aim = p_aim.normalized() if p_aim.length() > 0.01 else player.facing_direction
	arrow = p_arrow
	combo_step = p_combo_step
	combo_queued = false
	animation_name = style.animation_name

func is_finisher() -> bool:
	return style != null and style.is_finisher(combo_step)

func enter() -> void:
	_performed = false
	player.velocity = Vector2.ZERO
	player.update_facing_direction(aim, true)
	var from_aim_pose := animation_controller.release_pose()
	super.enter()
	var sprite := animation_controller.sprite
	sprite.speed_scale = style.speed_scale * style.combo_speed_at(combo_step)
	var frames := sprite.sprite_frames.get_frame_count(sprite.animation) if sprite.sprite_frames != null else 1
	_hit_frame = clampi(int(frames * style.hit_frame_ratio), 0, maxi(0, frames - 1))
	# Tali busur sudah ditarik saat membidik: lanjutkan dari pose itu, langsung lepas.
	if from_aim_pose and style.aim_pose_frame >= 0:
		sprite.set_frame_and_progress(mini(style.aim_pose_frame, _hit_frame), 0.0)
	Juice.play(style.swing_feedback, player.global_position)
	animation_controller.frame_changed.connect(_on_frame_changed)
	animation_controller.animated_finished.connect(_on_animation_finished)

func exit() -> void:
	animation_controller.sprite.speed_scale = 1.0
	if animation_controller.frame_changed.is_connected(_on_frame_changed):
		animation_controller.frame_changed.disconnect(_on_frame_changed)
	if animation_controller.animated_finished.is_connected(_on_animation_finished):
		animation_controller.animated_finished.disconnect(_on_animation_finished)
	# Serangan terputus (pemain tumbang, pindah area): panah yang sudah diambil kembali ke tas.
	if not _performed and arrow != null:
		player.data.add_item(arrow, 1)
	arrow = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO

func _on_frame_changed(frame: int) -> void:
	if frame >= _hit_frame:
		_perform()

func _on_animation_finished() -> void:
	_perform()
	var chain := combo_queued
	transitioned.emit(idle_state)
	player.tool_controller.on_attack_finished(chain)

func _perform() -> void:
	if _performed:
		return
	_performed = true
	player.bind_context()
	var base := weapon.attack_bonus + (arrow.attack_bonus if arrow != null else 0)
	var attack := maxi(1, roundi(base * style.combo_damage_at(combo_step)))
	if is_finisher() and not style.finisher_feedback.is_empty():
		Juice.play(style.finisher_feedback, player.global_position + Player.FEET_OFFSET + aim * style.melee_reach)
	if combo_step > 0:
		CombatJuice.combo_text(player, combo_step + 1, is_finisher())
	if is_finisher():
		CombatJuice.zoom_punch(player)
	if style.melee_radius > 0.0:
		_melee(attack)
	else:
		_shoot(attack)
	arrow = null

## Tebasan jarak dekat: lingkaran di depan kaki pemain, searah bidikan.
func _melee(attack: int) -> void:
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return
	var center := player.global_position + Player.FEET_OFFSET + aim * style.melee_reach
	var shape := CircleShape2D.new()
	shape.radius = style.melee_radius * (style.finisher_radius_scale if is_finisher() else 1.0)
	CombatJuice.slash(player, aim, style.melee_reach, shape.radius, is_finisher())
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	var hit := {}
	for result in space.intersect_shape(query, 32):
		var target := Combat.find_damageable(result.get("collider") as Node)
		if target == null or hit.has(target):
			continue
		hit[target] = true
		var push := style.knockback * (style.finisher_knockback_scale if is_finisher() else 1.0)
		CombatJuice.heavy_hit = is_finisher()
		var landed: bool = target.take_hit(attack, player, aim * push)
		CombatJuice.heavy_hit = false
		if landed and not style.hit_feedback.is_empty():
			Juice.play(style.hit_feedback, (target as Node2D).global_position if target is Node2D else center)

func _shoot(attack: int) -> void:
	var texture := style.projectile_texture
	if arrow != null and arrow.icon != null:
		texture = arrow.icon
	var count := style.finisher_projectiles if is_finisher() else 1
	var size := style.finisher_projectile_scale if is_finisher() else 1.0
	var spread := deg_to_rad(style.finisher_spread_deg)
	for i in count:
		var dir := aim.rotated(spread * (i - (count - 1) * 0.5))
		var projectile := CombatProjectile.launch(player, player.global_position + dir * 8.0, dir, attack, style, texture, size)
		if projectile != null and is_finisher():
			projectile.knockback_scale = style.finisher_knockback_scale
			projectile.heavy = true
