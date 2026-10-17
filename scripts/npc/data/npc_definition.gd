class_name NPCDefinition
extends Resource


@export var id: StringName
@export var display_name: String
@export var age: int
@export var profession: String
@export var home_map: StringName
@export var personality: PackedStringArray
@export var romanceable: bool = false

@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D

@export var loved_items: PackedStringArray
@export var liked_items: PackedStringArray
@export var disliked_items: PackedStringArray

@export var default_schedule: Array[NPCScheduleEntry] = []
@export var rainy_schedule: Array[NPCScheduleEntry] = []
@export var sunday_schedule: Array[NPCScheduleEntry] = []
