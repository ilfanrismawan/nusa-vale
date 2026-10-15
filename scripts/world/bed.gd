class_name Bed
extends Area2D

## Kasur. Solo: tekan Enter untuk tidur, hari berganti.
## Co-op: setiap pemain berbaring di sini (tekan lagi untuk bangun); hari baru dimulai
## setelah semua pemain berbaring.

var _players: Array[Player] = []
var _sleeping := false
## Local position of the pillow center. Keep this explicit when changing bed art.
@export var pillow_position := Vector2(-39, -2)
@export var sleep_rotation_degrees := -90.0
var _poses: Dictionary = {}

func _place_on_pillow(player: Player) -> void:
	if _poses.has(player):
		return
	var sprite := player.animation_controller.sprite
	player.release_carried_animal()
	player._clear_pickup_visual()
	_poses[player] = {"position": sprite.position, "rotation": sprite.rotation, "z_index": sprite.z_index}
	player.sleep_ended.connect(_restore_pose.bind(player), CONNECT_ONE_SHOT)
	player.set_input_locked(&"sleep", true)
	var texture := sprite.sprite_frames.get_frame_texture("sleep", 0)
	var bounds := texture.get_image().get_used_rect()
	var visible_center := Vector2(bounds.get_center()) - texture.get_size() * 0.5
	sprite.global_rotation = deg_to_rad(sleep_rotation_degrees)
	sprite.global_position = to_global(pillow_position) - visible_center.rotated(sprite.global_rotation) * sprite.global_scale
	sprite.z_index = 20

func _restore_pose(player: Player) -> void:
	if not is_instance_valid(player) or not _poses.has(player):
		return
	var pose: Dictionary = _poses[player]
	var sprite := player.animation_controller.sprite
	sprite.position = pose.position
	sprite.rotation = pose.rotation
	sprite.z_index = pose.z_index
	_poses.erase(player)
	player.set_input_locked(&"sleep", false)

func _exit_tree() -> void:
	for player in _poses.keys():
		_restore_pose(player)

func _ready() -> void:
	add_to_group("beds")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)
		
func _unhandled_input(event: InputEvent) -> void:
	if _sleeping:
		return
	if Coop.has_root():
		_coop_input(event)
		return
	if not _players.is_empty() and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_sleep()
		return
	if not _players.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var world_mouse: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if global_position.distance_to(world_mouse) <= 42.0:
			get_viewport().set_input_as_handled()
			_sleep()

func _coop_input(event: InputEvent) -> void:
	for p in _players:
		if not is_instance_valid(p) or not (p.input.is_event(event, &"ui_accept") or p.input.is_event(event, &"interact")):
			continue
		get_viewport().set_input_as_handled()
		var lying := not Coop.is_sleeping(p)
		var count := Coop.set_sleeping(p, lying)
		if lying:
			_place_on_pillow(p)
		else:
			_restore_pose(p)
		var total := Coop.player_count()
		if count >= total:
			_sleep()
		elif lying:
			Notify.say("P%d berbaring (%d/%d). Menunggu pemain lain di kasur..." % [p.player_index + 1, count, total])
		else:
			Notify.say("P%d bangun lagi (%d/%d)." % [p.player_index + 1, count, total])
		return

func _sleep() -> void:
	if DayCycle._is_passing_out or DayCycle.is_sleep_transition:
		return
	_sleeping = true
	DayCycle.is_sleep_transition = true
	for p in _players:
		if is_instance_valid(p):
			_place_on_pillow(p)
	var layer := CanvasLayer.new()
	layer.layer = 50
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	layer.add_child(fade)
	# Co-op: tirai menutupi semua layar sekaligus.
	var parent: Node = Coop.root if Coop.has_root() else get_tree().current_scene
	parent.add_child(layer)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(_new_day)
	tw.tween_interval(0.5)
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	tw.tween_callback(_end_sleep.bind(layer))

func _new_day() -> void:
	if Coop.has_root():
		for i in Coop.player_count():
			GameState.get_player(i).restore_stamina()
	else:
		GameState.restore_stamina()
	DayCycle.advance_day()
	SaveManager.save_game()
	Notify.say("Hari %d dimulai (Energi Pulih)" % DayCycle.current_day)
	
func _end_sleep(layer: CanvasLayer) -> void:
	layer.queue_free()
	for p in _poses.keys():
		_restore_pose(p)
	Coop.clear_sleeping()
	_sleeping = false
	DayCycle.is_sleep_transition = false
