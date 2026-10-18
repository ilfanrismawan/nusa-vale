class_name CombatProjectile
extends Area2D

## Anak panah atau bola sihir. Mengenai target "damageable" pertama, lalu hilang (pierce = tembus);
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
## Soulslike (GDD 8.2-A): kikisan poise, tembus semua musuh di jalur, abaikan DEF (weapon art).
var poise_damage := -1.0
var pierce := false
var ignore_defense := false
var _pierced := {}
var _trail: Line2D
## Efek tier senjata (warna, ekor, partikel terbang, benturan). Diset sebelum launch() lewat
## launch(..., fx); null = efek dasar Kayu.
var fx: WeaponTierFx
## Dilepas dari bidikan penuh (klik kanan ditahan sampai berdenting): lebih terang dan ekor lebih panjang.
var charged := false
var _flight: CPUParticles2D
var _age := 0.0

static func launch(p_shooter: Node2D, origin: Vector2, p_direction: Vector2, p_attack: int, p_style: WeaponStyle, texture: Texture2D = null, p_size: float = 1.0, p_fx: WeaponTierFx = null, p_charged: bool = false) -> CombatProjectile:
	var projectile := CombatProjectile.new()
	projectile._size = p_size
	projectile.fx = p_fx if p_fx != null else WeaponTierFx.for_tier(0)
	projectile.charged = p_charged
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
	# Warna dan panjangnya mengikuti tier senjata; bidikan penuh = ekor lebih tebal.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_index = 4
	_trail.width = (3.0 if texture == null else 1.5) * _size * fx.trail_width_scale * (1.3 if charged else 1.0)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var tint := tint_color()
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.0))
	fade.add_point(0.6, Color(tint, 0.55))
	fade.set_color(fade.get_point_count() - 1, Color(tint.lightened(0.5), 0.85))
	_trail.gradient = fade
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.2))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper
	add_child(_trail)
	# Partikel yang ditinggalkan selama terbang (bara, serpih es, asap, debu peri).
	var rate := fx.flight_particles * (1.5 if charged else 1.0)
	if rate > 0.0:
		_flight = CPUParticles2D.new()
		_flight.texture = Juice._dot
		_flight.local_coords = false
		_flight.lifetime = fx.particle_lifetime()
		_flight.amount = maxi(2, roundi(rate * _flight.lifetime))
		_flight.direction = -direction
		_flight.spread = 35.0
		_flight.initial_velocity_min = 4.0
		_flight.initial_velocity_max = 18.0
		_flight.gravity = Vector2(0.0, fx.particle_gravity() * 0.4)
		_flight.scale_amount_min = 1.0
		_flight.scale_amount_max = float(fx.particle_size())
		var colors := Gradient.new()
		colors.set_color(0, fx.color)
		colors.set_color(1, fx.color_alt)
		_flight.color_initial_ramp = colors
		var fade_out := Gradient.new()
		fade_out.set_color(0, Color.WHITE)
		fade_out.set_color(1, Color(1, 1, 1, 0))
		_flight.color_ramp = fade_out
		_flight.z_index = 4
		_flight.emitting = true
		add_child(_flight)
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)

## Warna utama proyektil: panah memakai warna tier; bola sihir mencampur warna tongkat dengan tier.
func tint_color() -> Color:
	var base := style.projectile_color if style.projectile_texture == null else Color(1, 1, 1)
	if fx == null or fx.motif == WeaponTierFx.Motif.DUST:
		return base
	return base.lerp(fx.color, 0.75 if style.projectile_texture == null else 0.65)

func _draw() -> void:
	if style == null:
		return
	var pulse := 1.0 + 0.15 * sin(_age * 30.0)
	if fx != null and fx.halo_radius > 0.0:
		var halo := fx.glow if fx.glow.a > 0.0 else Color(tint_color(), 0.3)
		draw_circle(Vector2.ZERO, (fx.halo_radius + (2.0 if charged else 0.0)) * _size * pulse, Color(halo, halo.a * 0.55))
	if style.projectile_texture != null:
		return
	var tint := tint_color()
	draw_circle(Vector2.ZERO, 4.0 * _size * pulse, Color(tint, 0.35))
	draw_circle(Vector2.ZERO, 2.5 * _size, tint)
	draw_circle(Vector2(-1, -1) * _size, 1.0 * _size, Color.WHITE)
	# Tier tinggi: kilau bersilang berputar di tengah bola sihir.
	if fx != null and fx.aim_motes >= 3:
		var r := (3.0 + fx.muzzle_scale) * _size
		for i in 2:
			var dir := Vector2.from_angle(_age * 9.0 + PI * 0.5 * i)
			draw_line(-dir * r, dir * r, Color(fx.color_alt, 0.8), 1.0)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := style.projectile_speed * delta
	global_position += direction * step
	_travelled += step
	_age += delta
	queue_redraw()
	if _trail != null:
		_trail.add_point(global_position)
		while _trail.get_point_count() > trail_length():
			_trail.remove_point(0)
	if _travelled >= _max_distance:
		_finish()

## Jumlah titik ekor: dari tier, plus sedikit untuk bola sihir dan bidikan penuh.
func trail_length() -> int:
	var points := fx.trail_points if fx != null else 6
	if style.projectile_texture == null:
		points += 2
	return points + (4 if charged else 0)

func _on_hit(node: Node) -> void:
	if _done or node == shooter or node is Player or node is ItemPickup:
		return
	var target := Combat.find_damageable(node)
	if target != null:
		if _pierced.has(target):
			return
		_pierced[target] = true
		var landed := Combat.hit(target, attack, shooter, direction * style.knockback * knockback_scale, poise_damage, ignore_defense, false, heavy or charged, fx)
		if landed:
			if not style.hit_feedback.is_empty():
				Juice.play(style.hit_feedback, global_position)
			CombatJuice.tier_impact(global_position, fx, direction, heavy or charged)
		if pierce:
			CombatJuice.spark(global_position, modulate if modulate != Color.WHITE else tint_color(), 6)
		else:
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
	CombatJuice.spark(global_position, tint_color() if style.projectile_texture == null else Color(0.9, 0.8, 0.6).lerp(tint_color(), 0.5), 10 if heavy else 6)
	if _flight != null:
		_flight.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.08)
	if _flight != null:
		# Biarkan partikel terbang yang sudah keluar memudar dulu.
		tw.tween_interval(_flight.lifetime)
	tw.tween_callback(queue_free)
