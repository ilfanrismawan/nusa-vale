class_name CombatProjectile
extends Area2D

## Anak panah atau bola sihir. Mengenai target "damageable" pertama, lalu hilang;
## berhenti juga saat menabrak benda padat atau melewati jangkauan senjata.

var shooter: Node2D
var direction := Vector2.RIGHT
var attack := 1
var style: WeaponStyle
var _travelled := 0.0
var _max_distance := 128.0
var _done := false
var _size := 1.0
var knockback_scale := 1.0
## Pukulan finisher: angka damage dan hitstop lebih besar.
var heavy := false
var _trail: Line2D

static func launch(p_shooter: Node2D, origin: Vector2, p_direction: Vector2, p_attack: int, p_style: WeaponStyle, texture: Texture2D = null, p_size: float = 1.0) -> CombatProjectile:
	var projectile := CombatProjectile.new()
	projectile._size = p_size
	projectile.shooter = p_shooter
	projectile.direction = p_direction.normalized()
	projectile.attack = p_attack
	projectile.style = p_style
	projectile._max_distance = p_style.projectile_range_tiles * 16.0
	var parent: Node = p_shooter.get_parent() if p_shooter != null else null
	if p_shooter is Player:
		parent = (p_shooter as Player).world_root()
	if parent == null:
		return null
	parent.add_child(projectile)
	projectile.global_position = origin
	projectile.rotation = projectile.direction.angle()
	projectile._build(texture)
	return projectile

func _build(texture: Texture2D) -> void:
	z_index = 5
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0 * _size
	shape.shape = circle
	add_child(shape)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.rotation = deg_to_rad(style.projectile_texture_rotation_deg)
		sprite.scale = Vector2.ONE * 0.75 * _size
		add_child(sprite)
	# Ekor cahaya: Line2D di koordinat dunia mengikuti posisi terakhir proyektil.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_index = 4
	_trail.width = (3.0 if texture == null else 1.5) * _size
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var fade := Gradient.new()
	var tint := style.projectile_color if texture == null else Color(1, 1, 1)
	fade.set_color(0, Color(tint, 0.0))
	fade.set_color(1, Color(tint, 0.7))
	_trail.gradient = fade
	add_child(_trail)
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)

func _draw() -> void:
	if style == null or style.projectile_texture != null or get_child_count() > 1:
		return
	draw_circle(Vector2.ZERO, 4.0 * _size, Color(style.projectile_color, 0.35))
	draw_circle(Vector2.ZERO, 2.5 * _size, style.projectile_color)
	draw_circle(Vector2(-1, -1) * _size, 1.0 * _size, Color.WHITE)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := style.projectile_speed * delta
	global_position += direction * step
	_travelled += step
	if _trail != null:
		_trail.add_point(global_position)
		while _trail.get_point_count() > (8 if style.projectile_texture == null else 6):
			_trail.remove_point(0)
	if _travelled >= _max_distance:
		_finish()

func _on_hit(node: Node) -> void:
	if _done or node == shooter or node is Player or node is ItemPickup:
		return
	var target := Combat.find_damageable(node)
	if target != null:
		CombatJuice.heavy_hit = heavy
		var landed: bool = target.take_hit(attack, shooter, direction * style.knockback * knockback_scale)
		CombatJuice.heavy_hit = false
		if landed and not style.hit_feedback.is_empty():
			Juice.play(style.hit_feedback, global_position)
		_finish()
		return
	# Area lain (pintu, zona) dilewati; benda padat (tembok, pohon) menghentikan proyektil.
	if node is PhysicsBody2D or node is TileMapLayer:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	CombatJuice.spark(global_position, style.projectile_color if style.projectile_texture == null else Color(0.9, 0.8, 0.6), 10 if heavy else 6)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
