class_name RecipeData
extends Resource

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var ingredients: Dictionary[String, int] = {}
@export var book_price: int = 0
@export var output_item: ItemData
@export_range(1, 999) var output_count: int = 1
@export var station_tags: PackedStringArray = []
@export var required_equipment: Array[CookingEquipmentData] = []

func missing_equipment(available: Array[CookingEquipmentData]) -> PackedStringArray:
	var missing: PackedStringArray = []
	for required in required_equipment:
		if required == null:
			missing.append("Peralatan belum dikonfigurasi")
			continue
		var found := false
		for equipment in available:
			if equipment != null and equipment.id == required.id:
				found = true
				break
		if not found:
			missing.append(required.item.display_name if required.item != null else str(required.id))
	return missing

func result_item() -> ItemData:
	return output_item if output_item != null else GameState._resolve_item(id)

func display_icon() -> Texture2D:
	if icon != null:
		return icon
	var item := result_item()
	return item.icon if item != null else null

func is_valid_recipe() -> bool:
	for equipment in required_equipment:
		if equipment == null or equipment.id.is_empty() or equipment.item == null:
			return false
	if id.is_empty() or book_price < 0 or output_count < 1 or ingredients.is_empty() or result_item() == null:
		return false
	for ingredient in ingredients:
		if ingredients[ingredient] <= 0 or GameState._resolve_item(ingredient) == null:
			return false
	return true
