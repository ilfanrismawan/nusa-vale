class_name RideState
extends State

## Menumpang kendaraan (GDD 10): sepeda, sapu terbang, kendaraan lanjutan.
## Kecepatan = Player.speed x VehicleData.speed_multiplier tanpa menahan lari.
## Sapu terbang melayang dan melintasi air/jurang pendek (Vehicles.fly_move); turun hanya di darat.
## Tidak ada alat, serangan, lompat, atau roll selama menumpang; tombol Alat = turun.
## Tampilan: animasi karakter berlayer yang sudah memuat kendaraannya (VehicleData.rider_*_animation,
## mis. bicycle_idle/bicycle_run, broomstick), atau visual_scene terpisah bila tidak ada.
## Kendaraan "diparkir" saat masuk ruangan (PlayerData.riding_vehicle_id tetap) dan otomatis
## dinaiki lagi begitu pemain keluar ke area luar. Dibuat ToolController saat _ready.

var idle_state: State
var vehicle: VehicleData
var vehicle_item_id := ""
## true sebelum keluar state = kendaraan diparkir (dinaiki lagi di area luar berikutnya).
var parking := false
var _visual: VehicleVisual
var _shadow: Node2D
var _sprite_home := Vector2.ZERO
var _time := 0.0
var _moving := false
## 0 = di tanah, 1 = di ketinggian penuh (naik saat menaiki, turun pelan saat turun).
var _rise := 1.0
var _landing := false

## Lama naik ke ketinggian penuh / turun ke tanah (detik), hanya untuk kendaraan melayang.
const TAKEOFF_TIME := 0.35
const LAND_TIME := 0.25
## Saat terbang tinggi, penunggang digambar di atas tajuk pohon dan atap (z_index relatif).
## Bayangan tetap ikut y-sort di tanah. Di bawah item yang dipegang (10) dan garis bidik (9).
const FLY_Z_INDEX := 6
## Ketinggian (0..1) mulai digambar di atas pohon/atap.
const FLY_Z_RISE := 0.6
## Jejak kilau di belakang sapu (piksel 1x1, warna emas/krem -> transparan).
const SPARKLE_COLOR_A := Color(1.0, 0.93, 0.6, 1.0)
const SPARKLE_COLOR_B := Color(0.75, 0.9, 1.0, 1.0)
const SPARKLE_LIFETIME := 0.7

var _sprite_z := 0
var _sparkles: CPUParticles2D

func _init() -> void:
	animation_name = &"Idle"

## Siapkan kendaraan sebelum change_state(ride_state).
func start(item: ItemData) -> void:
	vehicle = item.vehicle
	vehicle_item_id = item.item_id
	_moving = false
	animation_name = _rider_animation(false)

## Animasi karakter untuk diam/bergerak; Idle/Walk bila kendaraan tidak punya animasi sendiri.
func _rider_animation(moving: bool) -> StringName:
	var anim := vehicle.rider_move_animation if moving else vehicle.rider_idle_animation
	if anim.is_empty():
		return &"Walk" if moving else &"Idle"
	return anim

func is_flying() -> bool:
	return vehicle != null and (vehicle.crosses_water or vehicle.crosses_gaps)

func enter() -> void:
	parking = false
	_time = 0.0
	_landing = false
	_rise = 0.0 if vehicle.hover_height > 0.0 else 1.0
	animation_controller.release_pose()
	super.enter()
	var sprite := animation_controller.sprite
	_sprite_home = sprite.position
	_sprite_z = sprite.z_index
	if is_flying():
		_sparkles = _make_sparkles()
		player.add_child(_sparkles)
	sprite.visible = not vehicle.hide_rider
	if vehicle.visual_scene != null:
		_visual = vehicle.visual_scene.instantiate() as VehicleVisual
		if _visual != null:
			_visual.name = "VehicleVisual"
			player.add_child(_visual)
	# Bayangan tetap pemain; kendaraan melayang mengangkatnya lewat lift.
	_shadow = player.ground_shadow
	player.data.riding_vehicle_id = vehicle_item_id
	_update_visual(false)
	Juice.play(vehicle.mount_sound, player.global_position, -10.0)
	CombatJuice.dust(player.global_position + Player.FEET_OFFSET, -player.facing_direction)

func physics_update(delta: float) -> void:
	if vehicle == null or not player.data.has_item(vehicle_item_id):
		# Kendaraan dibuang/dijual/dipindah ke peti: turun di tempat.
		transitioned.emit(idle_state)
		return
	_time += delta
	if _landing:
		# Mendarat pelan: tidak bergerak, badan turun ke bayangan, lalu turun dari kendaraan.
		player.velocity = Vector2.ZERO
		_rise = move_toward(_rise, 0.0, delta / LAND_TIME)
		_update_visual(false)
		if _rise <= 0.0:
			_landing = false
			CombatJuice.dust(player.global_position + Player.FEET_OFFSET, player.facing_direction)
			transitioned.emit(idle_state)
		return
	_rise = move_toward(_rise, 1.0, delta / TAKEOFF_TIME)
	var input_vector := player.get_input_vector()
	if input_vector != Vector2.ZERO:
		player.update_facing_direction(input_vector)
	var velocity := input_vector * player.speed * vehicle.speed_multiplier * player.data.food_movement_multiplier()
	if is_flying():
		player.velocity = Vector2.ZERO
		Vehicles.fly_move(player, velocity * delta, vehicle)
	else:
		player.velocity = velocity
		player.move_and_slide()
	var moving := input_vector != Vector2.ZERO
	if moving != _moving:
		_moving = moving
		animation_controller.play(_rider_animation(moving))
	_update_visual(moving)

func _update_visual(moving: bool) -> void:
	var lift := 0.0
	if vehicle.hover_height > 0.0:
		var eased := smoothstep(0.0, 1.0, _rise)
		lift = vehicle.hover_height * eased + sin(_time * 4.0) * vehicle.hover_bob * eased
	var offset := Vector2(0, -lift)
	if is_instance_valid(_visual):
		_visual.set_facing(player.facing_direction)
		_visual.set_moving(moving)
		# Kendaraan sejajar dengan sprite penunggang (sprite pemain digeser ke atas, kaki = titik badan).
		_visual.position = offset + animation_controller.sprite.offset
		offset += _visual.rider_offset()
	animation_controller.sprite.position = _sprite_home + offset
	var high := is_flying() and _rise >= FLY_Z_RISE and not _landing
	animation_controller.sprite.z_index = FLY_Z_INDEX if high else _sprite_z
	if is_instance_valid(_sparkles):
		var dir := player.facing_direction
		# Ekor sapu: kebalikan arah hadap, sedikit di bawah badan penunggang.
		_sparkles.position = Vector2(-dir.x * 9.0, -lift - 4.0 - dir.y * 4.0)
		_sparkles.z_index = FLY_Z_INDEX - 1 if high else 0
		_sparkles.direction = -dir if dir != Vector2.ZERO else Vector2.UP
		_sparkles.emitting = moving and high
	if is_instance_valid(_shadow):
		_shadow.lift = lift

## Turun dari kendaraan. false bila tidak bisa (sapu masih di atas air).
func dismount() -> bool:
	if _landing:
		return true
	if is_flying() and Vehicles.blocked_at(player, player.global_position, false, false):
		Notify.say("Tidak bisa turun di atas air.")
		return false
	if vehicle != null and vehicle.hover_height > 0.0 and not parking:
		_landing = true
		return true
	transitioned.emit(idle_state)
	return true

func exit() -> void:
	_landing = false
	var sprite := animation_controller.sprite
	sprite.position = _sprite_home
	sprite.visible = true
	sprite.z_index = _sprite_z
	if is_instance_valid(_sparkles):
		# Biarkan kilau terakhir memudar dulu, baru dihapus.
		var sparkles := _sparkles
		sparkles.emitting = false
		player.get_tree().create_timer(SPARKLE_LIFETIME + 0.1).timeout.connect(func() -> void:
			if is_instance_valid(sparkles):
				sparkles.queue_free())
	_sparkles = null
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null
	if is_instance_valid(_shadow):
		_shadow.lift = 0.0
	if not parking:
		player.data.riding_vehicle_id = ""
	parking = false
	if vehicle != null:
		Juice.play(vehicle.mount_sound, player.global_position, -12.0)

func _make_sparkles() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "BroomSparkles"
	particles.amount = 18
	particles.lifetime = SPARKLE_LIFETIME
	particles.local_coords = false
	particles.emitting = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 2.0
	particles.spread = 35.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0
	particles.gravity = Vector2(0, 6)
	particles.damping_min = 4.0
	particles.damping_max = 8.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	var tint := Gradient.new()
	tint.set_color(0, SPARKLE_COLOR_A)
	tint.set_color(1, SPARKLE_COLOR_B)
	particles.color_initial_ramp = tint
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.add_point(0.6, Color(1, 1, 1, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	return particles
