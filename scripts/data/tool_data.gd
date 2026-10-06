class_name ToolData
extends Resource

enum ToolType {
	AXE,
	HOE,
	PICKAXE,
	SHOVEL,
	WATERING_CAN,
	SICKLE
}

enum ToolTier {
	WOOD,
	COPPER,
	IRON,
	GOLD,
	PLATINUM,
	CRIMSON,
	FROST,
	SHADOW,
	FAIRY,
	OBSIDIAN
}

@export_category("Identity")
@export var tool_id: String = ""
@export var display_name: String = ""

@export var tool_type: ToolType
@export var tier: ToolTier = ToolTier.WOOD

@export_category("Stats")
@export var damage: int = 1
@export var stamina_cost: int = 6
@export var action_speed: float = 1.0
@export var area_size: int = 1

@export_category("Upgrade")
@export var upgrade_cost_money: int = 0
@export var required_items: Dictionary = {}

func can_upgrade() -> bool:
	return tier != ToolTier.OBSIDIAN
