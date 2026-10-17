class_name Player
extends CharacterBody2D
signal sleep_ended

@export var speed: float = 25.0
@export var sit_hop_duration: float = 0.30
@export var sit_hop_height: float = 10.0

@onready var animation_controller: AnimationController = $AnimationController
@onready var state_machine: StateMachine = $StateMachine
@onready var base_layer_ground: TileMapLayer = get_node_or_null("../../BaseLayerGround")

@onready var hotbar_ui = $"../HotbarUi"
@onready var hud_ui = $"../HUD"
@onready var ui_inventory = $"../UIInventory"
@onready var settings_menu = $"../SettingsMenu"
@onready var tool_controller: ToolController = $ToolController

@onready var tile_cursor: CanvasItem = get_node_or_null("TileCursor")

var facing_direction := Vector2.DOWN
var character_visual: CharacterVisual

## Index pemain (0 = P1). Diisi CoopRoot lewat player_root.gd; solo selalu 0.
var player_index: int:
	get:
		var root := get_parent()
		if root != null and "player_index" in root:
			return root.player_index
		return 0
## Tas, stamina, dan penampilan pemain ini.
var data: PlayerData:
	get: return GameState.get_player(player_index) if Coop.active else GameState.p1()
## Aksi input milik pemain ini (co-op: "p2_move_left", dst.).
var input: PlayerInput:
	get: return Coop.get_input(player_index)

## Alasan input dikunci (menu terbuka, pindah area, tidur, kontroler lepas). Co-op saja;
## solo memakai pause tree seperti sebelumnya.
var _input_locks: Dictionary = {}
var _pending_item_gesture: StringName
var _pending_pickup_icon: Texture2D
var _pending_pickup_id := ""
var _carried_item_id := ""
var _preview_item_id := ""
var _pickup_visual: Sprite2D
var _pickup_visual_tween: Tween
var _footsteps := FootstepAudio.new()
var food_speed_remaining := 0.0
var food_speed_multiplier := 1.0

var seated_chair: Node2D
var _seated_sprite_home := Vector2.ZERO
var _position_before_sitting := Vector2.ZERO
var sit_transitioning := false

const INTERACTION_DISTANCE := 32.0

const FEET_OFFSET := Vector2(0, 8)
## Kebal sesaat setelah terkena serangan (GDD 8.1, i-frames).
const HIT_INVULNERABLE := 0.8
const KNOCKBACK_DECAY := 12.0
const DEBUG_ENEMY: EnemyData = preload("res://resources/enemies/slime_green.tres")

## true dari HP 0 sampai bangun di rumah (DefeatSequence).
var is_defeated := false
var _invulnerable := 0.0
var _knockback := Vector2.ZERO
var _blink_tween: Tween
var _aim_line: Line2D
const ACTION_DISTANCE := 16.0
const MAX_ACTION_DISTANCE := 28.0

func _ready() -> void:
	add_to_group("night_players")
	if DayCycle._is_passing_out:
		set_input_locked(&"pass_out", true)
	GameState.weather.attach_player.call_deferred(self)
	# UI masih belum _ready (saudara setelah body), jadi pemiliknya bisa diisi lebih dulu.
	for ui in [hotbar_ui, hud_ui, ui_inventory]:
		if ui != null and "player" in ui:
			ui.player = self
	hotbar_ui.show()
	hud_ui.show()

	hotbar_ui.slot_selected.connect(func(index: int): tool_controller.select_tool(index))
	tool_controller.tool_changed.connect(func(_a): hotbar_ui.highlight_slot(tool_controller.current_index))

	hotbar_ui.refresh.call_deferred()
	
	# Ganti sheet Josh dengan tampilan pilihan pemain (GameState.appearance).
	character_visual = CharacterVisual.new()
	character_visual.name = "CharacterVisual"
	add_child(character_visual)
	character_visual.setup(animation_controller.sprite, tool_controller)
	
	state_machine.initialize(self, animation_controller)
	
	# Co-op: posisi diatur CoopRoot.
	if GameState.has_spawn_point and not Coop.active:
		global_position = GameState.next_spawn_position
		GameState.has_spawn_point = false
		
func _process(delta: float) -> void:
	bind_context()
	_sync_carried_item()
	_flush_item_gesture()
	_update_held_item_position()
	_update_tile_cursor()
	_update_aim()
	_update_sweat(delta)
	_check_exhaustion()

## Stamina hampir habis: keringat menetes dari kepala sesekali.
const SWEAT_INTERVAL := 1.4
var _sweat_timer := 0.0
func _update_sweat(delta: float) -> void:
	if data.max_stamina <= 0 or data.stamina > data.max_stamina * 0.15 or is_defeated or not visible:
		_sweat_timer = 0.0
		return
	_sweat_timer -= delta
	if _sweat_timer <= 0.0:
		_sweat_timer = SWEAT_INTERVAL
		CombatJuice.sweat(self)
		# Karakter ikut berkedip pucat: tanda sebentar lagi pingsan.
		var body_sprite := animation_controller.sprite
		body_sprite.self_modulate = Color(1.5, 1.3, 1.0)
		create_tween().tween_property(body_sprite, "self_modulate", Color.WHITE, 0.35)

## Stamina habis sampai 0 = pingsan (keputusan 2026-10-17): animasi death, bangun di rumah.
## Dicek saat input bebas, jadi pingsan menunggu aksi/menu yang sedang berjalan selesai.
var _last_stamina := -1
func _check_exhaustion() -> void:
	if is_defeated or not _input_locks.is_empty() or DayCycle.is_sleep_transition or DayCycle._is_passing_out:
		return
	var now := data.stamina
	if now <= 0 and _last_stamina > 0:
		_die(true)
	_last_stamina = now

func _input(event: InputEvent) -> void:
	# HUD controls cover the viewport; handle world right-clicks before GUI routing.
	if event is InputEventMouseButton:
		_unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if sit_transitioning:
		if input.is_event(event, &"interact"):
			get_viewport().set_input_as_handled()
		return
	
	if is_instance_valid(seated_chair):
		if input.is_event(event, &"interact"):
			stand_up()
			get_viewport().set_input_as_handled()
		return

	if OS.is_debug_build() and _debug_combat_key(event):
		get_viewport().set_input_as_handled()
		return

	# Memegang senjata: klik kanan dipakai membidik, bukan interaksi.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and holds_weapon() and input.uses_mouse():
		return
		
	if is_input_locked() or not input.is_event(event, &"interact"):
		return
		
	bind_context()
	if _try_interact():
		get_viewport().set_input_as_handled()
	
func _physics_process(delta: float) -> void:
	food_speed_remaining = maxf(0.0, food_speed_remaining - delta)
	data.advance_food_effects(delta)
	bind_context()
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_apply_knockback(delta)
	
	if (
		_input_locks.has(&"sleep") 
		or _input_locks.has(&"sit")
		or animation_controller.item_gesture_playing
		):
			velocity = Vector2.ZERO
			return
		
	var previous_position := global_position
	state_machine.physics_update(delta)
	var moving := state_machine.current_state is MoveState
	_footsteps.update(self, global_position.distance_to(previous_position) if moving else 0.0, state_machine.current_state is RunState)

## Arahkan GameState (tas/stamina) dan FarmManager (tile) ke pemain dan area ini
## sebelum aksi diproses. Solo: GameState.current selalu P1, jadi tidak ada yang berubah.
func bind_context() -> void:
	if not Coop.active:
		return
	GameState.use_player(self)
	FarmManager.bind_world(world_root())

## Node world (scene area) tempat pemain ini berada.
func world_root() -> Node:
	if not Coop.has_root():
		return get_tree().current_scene
	var node: Node = get_parent()
	while node != null and node.get_parent() != null and not (node.get_parent() is SubViewport):
		node = node.get_parent()
	return node if node != null else get_tree().current_scene

## Dipanggil CoopRoot setelah pemain pindah area.
func refresh_world() -> void:
	GameState.weather.attach_player.call_deferred(self)
	base_layer_ground = get_node_or_null("../../BaseLayerGround")
	if base_layer_ground == null:
		base_layer_ground = world_root().get_node_or_null("BaseLayerGround") as TileMapLayer

func set_input_locked(reason: StringName, locked: bool) -> void:
	if locked:
		_input_locks[reason] = true
		velocity = Vector2.ZERO
	else:
		_input_locks.erase(reason)
	if reason == &"sleep":
		animation_controller.set_visual_override(&"sleep" if locked else &"")
		if not locked:
			sleep_ended.emit()

func is_input_locked() -> bool:
	return not _input_locks.is_empty() or animation_controller.item_gesture_playing

func play_item_gesture(pickup: bool = false, icon: Texture2D = null, item_id: String = "") -> void:
	_pending_item_gesture = &"pick_up" if pickup else &"item_drop"
	_pending_pickup_icon = icon if pickup else null
	_pending_pickup_id = item_id if pickup else ""
	_flush_item_gesture()

## Preview the selected hotbar item briefly above the player when scrolling tools.
func show_tool_preview(item: ItemData) -> void:
	if item != null and _carried_item_id == item.item_id and is_instance_valid(_pickup_visual):
		return
	_clear_pickup_visual()
	if item == null or item.icon == null:
		return
	_preview_item_id = item.item_id
	_show_static_item_visual(item.icon)
	animation_controller.set_carrying_item(true)
	_pickup_visual_tween = create_tween()
	_pickup_visual_tween.tween_interval(0.8)
	_pickup_visual_tween.tween_callback(_clear_pickup_visual)

func _flush_item_gesture() -> void:
	if _pending_item_gesture.is_empty() or is_input_locked() or get_tree().paused:
		return
	# Pickups can arrive during a tool hit. Finish that action before showing the gesture.
	if state_machine.current_state in [tool_controller.action_state, tool_controller.fishing_state, tool_controller.combat_state]:
		return
	animation_controller.set_direction(facing_direction)
	if animation_controller.play_item_gesture(_pending_item_gesture):
		_clear_pickup_visual()
		if _pending_item_gesture == &"pick_up" and _pending_pickup_icon != null:
			var held := tool_controller.current_item
			if held != null and held.is_tool():
				_pending_item_gesture = &""
				_pending_pickup_icon = null
				_pending_pickup_id = ""
				return
			for slot in data.bag_size:
				if data.inventory[slot] != null and data.inventory[slot]["item"].item_id == _pending_pickup_id:
					@warning_ignore("integer_division")
					data.hotbar_page = slot / 8
					tool_controller.select_tool(slot % 8, false)
					hotbar_ui.refresh()
					break
			_carried_item_id = _pending_pickup_id
			_show_pickup_visual(_pending_pickup_icon)
			animation_controller.set_carrying_item(true)
	_pending_item_gesture = &""
	_pending_pickup_icon = null
	_pending_pickup_id = ""

func _sync_carried_item() -> void:
	var visible_id := _carried_item_id if not _carried_item_id.is_empty() else _preview_item_id
	if visible_id.is_empty():
		return
	var held := tool_controller.current_item
	if held == null or held.item_id != visible_id or not data.has_item(visible_id):
		_clear_pickup_visual()

## Local to the collecting character, so it follows movement and its own co-op viewport.
func _show_pickup_visual(icon: Texture2D) -> void:
	_show_static_item_visual(icon)

func _show_static_item_visual(icon: Texture2D) -> void:
	# All callers share one visual; replacement removes the old node immediately.
	_dispose_item_visual()
	if icon == null:
		return
	_pickup_visual = Sprite2D.new()
	_pickup_visual.name = "HeldPickupItem"
	_pickup_visual.texture = icon
	_pickup_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bounds := Rect2(Vector2.ZERO, icon.get_size())
	var image := icon.get_image()
	if image != null and image.get_used_rect().has_area():
		bounds = Rect2(image.get_used_rect())
	_pickup_visual.scale = Vector2.ONE * minf(1.0, 16.0 / maxf(1.0, maxf(bounds.size.x, bounds.size.y)))
	_pickup_visual.offset = icon.get_size() * 0.5 - bounds.get_center()
	_pickup_visual.set_meta("visible_height", bounds.size.y * _pickup_visual.scale.y)
	_pickup_visual.z_index = 10
	add_child(_pickup_visual)
	_update_held_item_position()

func _update_held_item_position() -> void:
	if not is_instance_valid(_pickup_visual):
		return
	var sprite := animation_controller.sprite
	var animation := String(sprite.animation)
	var hand_y := -6.0
	if animation.begins_with("pick_up_"):
		var last_frame := maxi(1, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
		var progress := clampf((sprite.frame + sprite.frame_progress) / last_frame, 0.0, 1.0)
		hand_y = lerpf(3.0, -6.0, progress)
	elif animation.begins_with("carry_walk_") or animation.begins_with("carry_run_"):
		hand_y += float(sprite.frame % 2)
	var hand_x := signf(facing_direction.x)
	_pickup_visual.position = Vector2(hand_x, hand_y - float(_pickup_visual.get_meta("visible_height", 16.0)) * 0.5)

func _clear_pickup_visual() -> void:
	_carried_item_id = ""
	_preview_item_id = ""
	animation_controller.set_carrying_item(has_meta("carried_animal"))
	_dispose_item_visual()

func _dispose_item_visual() -> void:
	if _pickup_visual_tween != null and _pickup_visual_tween.is_valid():
		_pickup_visual_tween.kill()
	_pickup_visual_tween = null
	if is_instance_valid(_pickup_visual):
		_pickup_visual.hide()
		if _pickup_visual.get_parent() == self:
			remove_child(_pickup_visual)
		_pickup_visual.queue_free()
	_pickup_visual = null
	
func _try_interact() -> bool:
	var carried := get_meta("carried_animal") as Node if has_meta("carried_animal") else null
	if is_instance_valid(carried):
		carried.place_from_player(self)
		return true
	for bed in get_tree().get_nodes_in_group("beds"):
		if bed.get_world_2d() == get_world_2d() and bed.overlaps_body(self):
			if not Coop.has_root():
				if not bed._sleeping:
					bed._sleep()
				return true
	# Entrances remain interactable; interior exit triggers also travel on contact.
	var nearest_door: Area2D
	var door_distance := 40.0
	for candidate in get_tree().get_nodes_in_group("scene_door"):
		if not candidate is Area2D or candidate.get_world_2d() != get_world_2d():
			continue
		var shape := candidate.get_node_or_null("CollisionShape2D") as Node2D
		var center: Vector2 = shape.global_position if shape != null else candidate.global_position
		var offset := center - (global_position + FEET_OFFSET)
		if candidate.overlaps_body(self) or (offset.length() < door_distance and offset.dot(facing_direction) >= -1):
			nearest_door = candidate
			door_distance = offset.length()
	if nearest_door != null:
		nearest_door.interact(self)
		return true
	if StructureManager.interact_near(self):
		return true
	var target := _find_interactable()
	if target == null:
		return false
		
	if target.has_method("interact")		:
		if target is VillageNPC or target is BlacksmithNPC or target.has_meta("player_interaction"):
			target.interact(self)
		else:
			target.interact()
		return true
	return false

func release_carried_animal() -> void:
	var carried := get_meta("carried_animal") as Node if has_meta("carried_animal") else null
	if is_instance_valid(carried):
		carried.place_from_player(self)
	set_meta("carried_animal", null)

func _find_interactable() -> Node:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return null
	
	var origin := global_position + FEET_OFFSET
	var direction := facing_direction.normalized()
	var target_position := origin + (direction * INTERACTION_DISTANCE)
	var query := PhysicsPointQueryParameters2D.new()		
	
	query.position = target_position
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	
	var results := space_state.intersect_point(query, 16)
	
	for result in results:
		var collider = result.get("collider")
		if collider == null:
			continue
		
		if collider.has_method("interact"):
			return collider
		
		var parent: Node = collider.get_parent()
		
		if parent != null:
			if parent.has_method("interact"):
				return parent	
			
	return null
	
func _update_tile_cursor() -> void:
	if not is_instance_valid(tile_cursor):
		return
	if is_input_locked():
		tile_cursor.visible = false
		return
		
	if base_layer_ground == null or holds_weapon():
		tile_cursor.visible = false
		return
		
	var target_cell := get_target_cell()
	var cell_center_world := base_layer_ground.to_global(base_layer_ground.map_to_local(target_cell))
	tile_cursor.global_position = cell_center_world - Vector2(8,8)
	tile_cursor.visible = true
	
func get_input_vector() -> Vector2:
	if is_input_locked():
		return Vector2.ZERO
	return input.get_vector()

func update_facing_direction(direction: Vector2, force: bool = false) -> void:
	if (is_input_locked() or is_aiming()) and not force:
		return
	if direction == Vector2.ZERO:
		return
	
	var new_facing: Vector2
	if abs(direction.x) > abs(direction.y):
		new_facing = Vector2(sign(direction.x), 0)
	else:
		new_facing = Vector2(0, sign(direction.y))
	
	if new_facing == facing_direction:
		return
	
	facing_direction = new_facing
	animation_controller.set_direction(facing_direction)

func world_to_cell(world_position: Vector2) -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	return base_layer_ground.local_to_map(base_layer_ground.to_local(world_position))

func get_target_world_position() -> Vector2:
	if base_layer_ground == null:
		return global_position
	
	var cell := get_target_cell()
	
	return base_layer_ground.to_global(
		base_layer_ground.map_to_local(cell)
	)
	
func get_player_cell() -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	var foot_position: Vector2 = global_position + FEET_OFFSET
	return base_layer_ground.local_to_map(
		base_layer_ground.to_local(foot_position)
	)

func get_target_cell() -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	
	var aim: Variant = _mouse_world_position()
	if aim == null:
		return get_player_cell() + Vector2i(facing_direction)
	var mouse_world_pos: Vector2 = aim
	var foot_position := global_position + FEET_OFFSET
	var dist_to_mouse := foot_position.distance_to(mouse_world_pos)
	
	var reach := MAX_ACTION_DISTANCE
	if tool_controller != null and tool_controller.current_tool != null and tool_controller.current_tool.tool_data != null and not (tool_controller.current_item != null and tool_controller.current_item.placeable):
		reach = tool_controller.current_tool.tool_data.reach_tiles * 16.0
	if dist_to_mouse <= reach and dist_to_mouse > 4.0:
		var dir := (mouse_world_pos - foot_position).normalized()
		update_facing_direction(dir)
		return base_layer_ground.local_to_map(base_layer_ground.to_local(mouse_world_pos))
	
	return get_player_cell() + Vector2i(facing_direction)
	

## Posisi mouse di dunia untuk membidik, atau null bila pemain ini tidak memakai mouse
## (co-op: hanya P1; gamepad membidik ke arah hadap).
func _mouse_world_position() -> Variant:
	if not Coop.has_root():
		return get_global_mouse_position()
	if not input.uses_mouse():
		return null
	var view := Coop.view_of(self)
	if view == null:
		return null
	return view.get_canvas_transform().affine_inverse() * view.get_mouse_position()

func begin_sitting(
	chair: Node2D,
	seat_position: Vector2,
	direction: Vector2
) -> void:
	if sit_transitioning or is_instance_valid(seated_chair):
		return
	
	sit_transitioning = true
	seated_chair = chair
	_position_before_sitting = global_position
	
	set_input_locked(&"sit", true)
	velocity = Vector2.ZERO
	
	add_collision_exception_with(chair.solid)
	
	state_machine.change_state(
		state_machine.get_node("IdleState")
	)
	
	
	update_facing_direction(direction, true)
	animation_controller.sprite.speed_scale = 1.0
	
	animation_controller.set_visual_override(&"idle")
	
	_seated_sprite_home = animation_controller.sprite.position
	# Sort in front of the seat at ground level while aligning the artwork
	# independently with the cushion. Keep the normal world Z index.
	var ground_anchor := seat_position
	ground_anchor.y = maxf(ground_anchor.y, chair.global_position.y + 1.0)
	var visual_position: Vector2 = _seated_sprite_home + seat_position + chair.sit_visual_offset - ground_anchor
	await _hop_to(ground_anchor, sit_hop_height, visual_position)
	
	if not is_instance_valid(seated_chair):
		animation_controller.set_visual_override(&"")
		animation_controller.sprite.position = _seated_sprite_home
		set_input_locked(&"sit", false)
		sit_transitioning = false
		return
	
	animation_controller.set_visual_override(&"sit")
	seated_chair.show_seated_backrest(self)
	sit_transitioning = false
	
func stand_up() -> void:
	if sit_transitioning or not is_instance_valid(seated_chair):
		return
	
	sit_transitioning = true
	var chair = seated_chair
	chair.clear_seated_backrest()
	
	velocity = Vector2.ZERO
	
	animation_controller.set_visual_override(&"idle")
	
	await _hop_to(
		_position_before_sitting,
		sit_hop_height * 0.80,
		_seated_sprite_home
	)
	
	if is_instance_valid(chair):
		if is_instance_valid(chair.solid):
			remove_collision_exception_with(chair.solid)
		chair.occupant = null
	
	seated_chair = null
	
	animation_controller.set_visual_override(&"")
	animation_controller.play(&"Idle")
	set_input_locked(&"sit", false)
	
	sit_transitioning = false

func _hop_to(destination: Vector2, height: float, visual_destination: Vector2 = Vector2.INF) -> void:
	var player_root := get_parent() as Node2D
	var sprite := animation_controller.sprite
	
	var body_world_position := global_position
	player_root.global_position = body_world_position
	position = Vector2.ZERO
	
	var start_position := player_root.global_position
	var sprite_home := sprite.position
	var sprite_target := sprite_home if visual_destination == Vector2.INF else visual_destination
	
	var tween := create_tween()
	tween.set_process_mode(tween.TWEEN_PROCESS_PHYSICS)
	
	tween.tween_method(
		func(progress: float) -> void:
			player_root.global_position = start_position.lerp(destination, progress)
			
			var lift := 4.0 * height * progress * (1.0 - progress)
			sprite.position = sprite_home.lerp(sprite_target, progress) + Vector2(0, -lift), 0.0, 1.0, maxf(sit_hop_duration, 0.01)
	)
	
	await tween.finished
	
	player_root.global_position = destination
	sprite.position = sprite_target


# ── Combat (Phase 4B-1) ─────────────────────────────────────────────

## Senjata (pedang, busur, tongkat sihir) di slot hotbar yang dipilih.
func holds_weapon() -> bool:
	return tool_controller != null and Combat.is_weapon(tool_controller.current_item)

## Klik kanan ditahan sambil memegang senjata (hanya pemain yang memakai mouse).
func is_aiming() -> bool:
	return holds_weapon() and input.uses_mouse() and input.pressed(&"aim") and _input_locks.is_empty() and not is_defeated

## Arah serangan: ke mouse saat membidik, selain itu ke arah hadap.
func aim_vector() -> Vector2:
	if is_aiming():
		var mouse: Variant = _mouse_world_position()
		if mouse != null:
			var offset: Vector2 = mouse - (global_position + FEET_OFFSET * 0.5)
			if offset.length() > 2.0:
				return offset.normalized()
	return facing_direction

func _update_aim() -> void:
	if not is_aiming():
		if is_instance_valid(_aim_line):
			_aim_line.visible = false
		animation_controller.release_pose()
		return
	var dir := aim_vector()
	update_facing_direction(dir, true)
	_update_aim_pose()
	if not is_instance_valid(_aim_line):
		_aim_line = Line2D.new()
		_aim_line.name = "AimLine"
		_aim_line.width = 1.0
		_aim_line.default_color = Color(1, 1, 1, 0.45)
		_aim_line.z_index = 9
		add_child(_aim_line)
	var style := Combat.style_for(tool_controller.current_item)
	var length := style.melee_reach + style.melee_radius if style.melee_radius > 0.0 else style.projectile_range_tiles * 16.0
	var origin := FEET_OFFSET * 0.5
	_aim_line.points = PackedVector2Array([origin + dir * 6.0, origin + dir * length])
	_aim_line.visible = true

## Busur: selama membidik karakter menahan pose tali ditarik (WeaponStyle.aim_pose_frame).
func _update_aim_pose() -> void:
	var style := Combat.style_for(tool_controller.current_item)
	var state := state_machine.current_state
	if style == null or style.aim_pose_frame < 0 or not (state is IdleState or state is MoveState):
		animation_controller.release_pose()
		return
	animation_controller.hold_pose(style.animation_name, style.aim_pose_frame)

## Dipanggil musuh/proyektil. raw_attack dikurangi DEF perlengkapan. true = pukulan masuk.
func take_hit(raw_attack: int, _source: Node = null, knockback: Vector2 = Vector2.ZERO) -> bool:
	if is_defeated or _invulnerable > 0.0 or data.hp <= 0 or _input_locks.has(&"sleep"):
		return false
	bind_context()
	var damage := Combat.damage_after_defense(raw_attack, Combat.player_defense(data))
	data.damage_hp(damage)
	_invulnerable = HIT_INVULNERABLE
	_knockback = knockback * 6.0
	CombatJuice.damage_number("-%d" % damage, global_position + Vector2(0, -18), CombatJuice.HURT_COLOR)
	Juice.play(&"player_hurt", global_position)
	CombatJuice.player_hurt(self)
	CombatJuice.blood(global_position + Vector2(0, -6), knockback, clampi(damage, 6, 16))
	_blink()
	if data.hp <= 0:
		_die()
		return true
	var state := state_machine.current_state
	if (state is IdleState or state is MoveState) and _input_locks.is_empty():
		animation_controller.set_direction(facing_direction)
		animation_controller.play_item_gesture(&"damage")
	return true

func is_invulnerable() -> bool:
	return _invulnerable > 0.0 or is_defeated

func _apply_knockback(delta: float) -> void:
	if _knockback.length() < 0.5 or is_defeated:
		_knockback = Vector2.ZERO
		return
	var keep := velocity
	velocity = _knockback
	move_and_slide()
	velocity = keep
	_knockback = _knockback.lerp(Vector2.ZERO, minf(1.0, KNOCKBACK_DECAY * delta))

func _blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops(4)
	_blink_tween.tween_property(self, "modulate:a", 0.35, HIT_INVULNERABLE / 8.0)
	_blink_tween.tween_property(self, "modulate:a", 1.0, HIT_INVULNERABLE / 8.0)

func _die(exhausted: bool = false) -> void:
	is_defeated = true
	_knockback = Vector2.ZERO
	release_carried_animal()
	_clear_pickup_visual()
	state_machine.change_state(state_machine.get_node("IdleState"))
	set_input_locked(DefeatSequence.LOCK, true)
	animation_controller.set_visual_override(&"death")
	DefeatSequence.start(self, null, exhausted)

## Dipanggil DefeatSequence setelah pemain bangun di rumah.
func finish_defeat() -> void:
	is_defeated = false
	_invulnerable = HIT_INVULNERABLE * 2.0
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	modulate.a = 1.0
	set_input_locked(DefeatSequence.LOCK, false)
	animation_controller.set_visual_override(&"")

## Debug: pastikan senjata ada di tas lalu taruh di slot hotbar yang sedang dipilih dan pegang.
func _debug_hold_weapon(item_id: String) -> void:
	if not data.has_item(item_id):
		data.add_item(item_id, 1)
	var target := data.hotbar_page * 8 + tool_controller.current_index
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry != null and entry["item"].item_id == item_id:
			if slot != target:
				var other: Variant = data.inventory[target]
				data.inventory[target] = entry
				data.inventory[slot] = other
				GameState.inventory_changed.emit()
			break
	tool_controller.select_tool(tool_controller.current_index, false)

## Tombol uji (build debug): Ctrl+F7 = munculkan slime di depan, Ctrl+F8 = terima 20 damage,
## Ctrl+F9 = dapat pedang, busur, anak panah, dan tongkat sihir, Ctrl+F6 = pegang tongkat sihir
## (stamina penuh), Ctrl+F10 = pegang busur + 30 anak panah.
func _debug_combat_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed):
		return false
	if not input.uses_mouse():
		return false
	match event.keycode:
		KEY_F7:
			Enemy.spawn(DEBUG_ENEMY, world_root(), global_position + FEET_OFFSET + facing_direction * 32.0)
			Notify.say("[Debug] Slime muncul di depanmu.")
			return true
		KEY_F8:
			take_hit(20 + Combat.player_defense(data))
			return true
		KEY_F9:
			bind_context()
			for entry in [["sword_wood", 1], ["bow_wood", 1], ["arrow_wood", 30], ["staff_wood", 1]]:
				data.add_item(entry[0], entry[1])
			Notify.say("[Debug] Pedang, busur, 30 anak panah, dan tongkat sihir masuk ke tas.")
			return true
		KEY_F6:
			bind_context()
			_debug_hold_weapon("staff_wood")
			data.stamina = data.max_stamina
			Notify.say("[Debug] Tongkat sihir dipegang, stamina penuh. Tahan klik kanan untuk membidik.")
			return true
		KEY_F10:
			bind_context()
			_debug_hold_weapon("bow_wood")
			data.add_item("arrow_wood", 30)
			Notify.say("[Debug] Busur dipegang dan 30 anak panah masuk ke tas. Tahan klik kanan untuk membidik.")
			return true
	return false
