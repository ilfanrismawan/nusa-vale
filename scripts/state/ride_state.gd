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
	animation_controller.release_pose()
	super.enter()
	var sprite := animation_controller.sprite
	_sprite_home = sprite.position
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
		lift = vehicle.hover_height + sin(_time * 4.0) * vehicle.hover_bob
	var offset := Vector2(0, -lift)
	if is_instance_valid(_visual):
		_visual.set_facing(player.facing_direction)
		_visual.set_moving(moving)
		# Kendaraan sejajar dengan sprite penunggang (sprite pemain digeser ke atas, kaki = titik badan).
		_visual.position = offset + animation_controller.sprite.offset
		offset += _visual.rider_offset()
	animation_controller.sprite.position = _sprite_home + offset
	if is_instance_valid(_shadow):
		_shadow.lift = lift

## Turun dari kendaraan. false bila tidak bisa (sapu masih di atas air).
func dismount() -> bool:
	if is_flying() and Vehicles.blocked_at(player, player.global_position, false, false):
		Notify.say("Tidak bisa turun di atas air.")
		return false
	transitioned.emit(idle_state)
	return true

func exit() -> void:
	var sprite := animation_controller.sprite
	sprite.position = _sprite_home
	sprite.visible = true
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
