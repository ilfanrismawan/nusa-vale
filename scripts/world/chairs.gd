@tool
extends Sprite2D

enum Facing { UP, DOWN, LEFT, RIGHT }

@export_group("Seat Setup")
## Pick an artwork preset; each direction has its own seating and collision data.
@export var definition: SeatDefinition:
	set(value):
		definition = value
		if is_node_ready():
			apply_facing()
@export_enum("Atas", "Bawah", "Kiri", "Kanan") var facing: int = Facing.DOWN:
	set(value):
		if is_instance_valid(occupant):
			return
		if not Engine.is_editor_hint() and is_node_ready() and placement_uid > 0 and not _restoring_record:
			return
		facing = clampi(value, 0, 3)
		if is_node_ready():
			apply_facing()

@export_group("Custom Alignment (without preset)")

var sit_direction := Vector2.DOWN
## Align the sitting artwork without moving the ground/Y-sort anchor.
@export var sit_visual_offset := Vector2(0, -6)
## Top strip of a rear-facing seat that must cover the seated lower body.
## Zero leaves ordinary chairs unchanged.
@export_range(0.0, 64.0, 1.0) var backrest_height: float = 0.0

var _seat_backrest: Sprite2D

@onready var seat_point: Marker2D = $SeatPoint
@onready var solid: StaticBody2D = $StaticBody2D

var occupant: Player
var placement_uid: int = 0
var _restoring_record := false


func apply_facing() -> void:
	sit_direction = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][facing]
	if definition == null:
		return
	var pose := definition.pose_for(facing)
	if pose == null:
		# No sideways bench artwork: retain a supported pose rather than rotating pixels.
		facing = definition.next_facing(facing)
		return
	texture = definition.texture
	region_enabled = true
	region_rect = pose.region
	offset = pose.sprite_offset
	seat_point.position = pose.seat_position
	sit_visual_offset = pose.visual_offset
	backrest_height = pose.backrest_height
	var collider := solid.get_node("CollisionShape2D") as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = pose.collision_size
	collider.shape = shape
	collider.position = pose.collision_position


func rotate_seat() -> void:
	if is_instance_valid(occupant) or (not Engine.is_editor_hint() and placement_uid > 0):
		return
	facing = definition.next_facing(facing) if definition != null else (facing + 1) % 4


func refresh() -> void:
	if placement_uid <= 0 or Engine.is_editor_hint():
		return
	var record := StructureManager.record_for(placement_uid)
	if not record.is_empty() and facing != int(record.get("facing", 1)):
		_restoring_record = true
		facing = int(record.get("facing", 1))
		_restoring_record = false


func show_seated_backrest(actor: Player) -> void:
	clear_seated_backrest()
	if backrest_height <= 0.0 or not region_enabled:
		return
	var strip_height := minf(backrest_height, region_rect.size.y)
	_seat_backrest = Sprite2D.new()
	_seat_backrest.name = "SeatedBackrest"
	_seat_backrest.texture = texture
	_seat_backrest.region_enabled = true
	_seat_backrest.region_rect = Rect2(region_rect.position, Vector2(region_rect.size.x, strip_height))
	_seat_backrest.centered = centered
	_seat_backrest.offset = offset
	if centered:
		_seat_backrest.offset.y -= (region_rect.size.y - strip_height) * 0.5
	_seat_backrest.texture_filter = texture_filter
	# Draw after the player's sprite, in the same world Y-sort group.
	actor.add_child(_seat_backrest)
	_seat_backrest.global_transform = global_transform


func clear_seated_backrest() -> void:
	if is_instance_valid(_seat_backrest):
		_seat_backrest.hide()
		_seat_backrest.queue_free()
	_seat_backrest = null

func _ready() -> void:
	set_meta("player_interaction", true)
	apply_facing()


func interact(actor: Player) -> void:
	if is_instance_valid(occupant):	
		return	
	if placement_uid > 0 and actor.input.uses_mouse() and Input.is_key_pressed(KEY_SHIFT):
		Notify.say(StructureManager.pickup_furniture(actor, placement_uid).message)
		return
		
	var current = actor.state_machine.current_state
	if not(
		current is IdleState
		or current is MoveState
		or current is RunState
	):
		return
		
	actor.begin_sitting(
		self,
		seat_point.global_position,
		sit_direction
	)
	if actor.seated_chair == self:
		occupant = actor
	
