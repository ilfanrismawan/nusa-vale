class_name ItemData
extends Resource

enum Category { ALL, SEED, CROP, TOOL, MATERIAL, FISH}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export_category("Pickup")

@export var category: Category = Category.MATERIAL
@export var item_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var description: String = ""
@export var stackable: bool = true
@export var max_stack: int = 99

@export var action_data: ActionData

@export var buy_price: int = 0  
@export var sell_price: int = 0   

@export var rarity: Rarity = Rarity.COMMON
@export var pickup_sound: AudioStream
@export var pickup_amount_text :=true
@export var magnet_radius := 48.0
@export var auto_pickup := false

func is_tool() -> bool:
	return action_data != null
