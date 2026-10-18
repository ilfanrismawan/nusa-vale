class_name CookingShopOffer
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(1, 9999999) var price: int = 100
@export var materials: Dictionary[String, int] = {}
@export var required_flags: PackedStringArray = []
@export_multiline var locked_message := "Terkunci: pesan Upgrade Rumah (ruang dapur) ke Wira terlebih dahulu."
@export_multiline var purchase_message: String
@export var owned_flag: String
@export var grants_flags: PackedStringArray = []
@export var equipment: CookingEquipmentData
@export var kitchen_scene: PackedScene
@export var selection_group: StringName

func display_icon() -> Texture2D:
	return icon if icon != null else equipment.display_icon() if equipment != null else null

func is_valid() -> bool:
	if id.is_empty() or display_name.is_empty() or price <= 0 or owned_flag.is_empty():
		return false
	for item_id in materials:
		if materials[item_id] <= 0 or GameState._resolve_item(item_id) == null:
			return false
	return true
