class_name CookingEquipmentData
extends Resource

@export var id: StringName
@export var item: ItemData
@export var icon: Texture2D
@export var recipe_tags: PackedStringArray = []

func display_icon() -> Texture2D:
	return icon if icon != null else (item.icon if item != null else null)

func supports(recipe: RecipeData) -> bool:
	if recipe == null:
		return false
	if recipe_tags.is_empty():
		return true
	for required in recipe.required_equipment:
		if required != null and required.id == id:
			return true
	if recipe.station_tags.is_empty():
		return recipe.required_equipment.is_empty()
	for tag in recipe.station_tags:
		if recipe_tags.has(tag):
			return true
	return false
