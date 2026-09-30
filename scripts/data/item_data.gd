class_name ItemData
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var description: String = ""
@export var stackable: bool = true
@export var max_stack: int = 99

@export var action_data: ActionData

func is_tool() -> bool:
	return action_data != null
