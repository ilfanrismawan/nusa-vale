class_name Player
extends CharacterBody2D

@export var speed: float = 30.0

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

const INTERACTION_DISTANCE := 32.0

const FEET_OFFSET := Vector2(0, 8)
const ACTION_DISTANCE := 16.0
const MAX_ACTION_DISTANCE := 28.0

func _ready() -> void:
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
	if not is_input_locked() and input.just_pressed(&"interact"):
		_try_interact()
	_update_tile_cursor()
	
func _physics_process(delta: float) -> void:
	bind_context()
	state_machine.physics_update(delta)

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
	base_layer_ground = get_node_or_null("../../BaseLayerGround")
	if base_layer_ground == null:
		base_layer_ground = world_root().get_node_or_null("BaseLayerGround") as TileMapLayer

func set_input_locked(reason: StringName, locked: bool) -> void:
	if locked:
		_input_locks[reason] = true
		velocity = Vector2.ZERO
	else:
		_input_locks.erase(reason)

func is_input_locked() -> bool:
	return not _input_locks.is_empty()
	
func _try_interact() -> void:
	var target := _find_interactable()
	if target == null:
		return
		
	if target.has_method("interact")		:
		target.interact()

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
		
	if base_layer_ground == null:
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

func update_facing_direction(direction: Vector2) -> void:
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
	
	if dist_to_mouse <= MAX_ACTION_DISTANCE and dist_to_mouse > 4.0:
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
