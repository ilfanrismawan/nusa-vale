class_name CookingRecipeRow
extends VBoxContainer

signal action_pressed(recipe_id: String, learn: bool)

@export var equipment_badge_scene: PackedScene = preload("res://scenes/ui/cooking_equipment_badge.tscn")

@onready var recipe_icon: TextureRect = %RecipeIcon
@onready var equipment_icons: HFlowContainer = %EquipmentIcons

@onready var info_label: Label = %InfoLabel
@onready var ingredients_label: Label = %IngredientsLabel
@onready var action_button: Button = %ActionButton

var _reciped_id := ""
var _learn := false

func _ready() -> void:
	action_button.pressed.connect(func(): action_pressed.emit(_reciped_id, _learn))

func setup(recipe: RecipeData, data: PlayerData, available_equipment: Array[CookingEquipmentData] = []) -> void:
	_reciped_id = recipe.id
	recipe_icon.texture = recipe.display_icon()
	recipe_icon.tooltip_text = recipe.display_name
	for child in equipment_icons.get_children():
		equipment_icons.remove_child(child)
		child.queue_free()
	var item := recipe.result_item()
	if not recipe.is_valid_recipe():
		info_label.text = "%s · Data resep belum lengkap" % recipe.display_name
		action_button.disabled = true
		return

	info_label.text = "%s • %s" % [recipe.display_name, item.food_summary()]
	info_label.tooltip_text = item.description

	var text: PackedStringArray = []
	var enough := true
	for ingredient in recipe.ingredients:
		var count := data.get_item_count(ingredient)
		var required := int(recipe.ingredients[ingredient])
		text.append("%s %d/%d" % [GameState._resolve_item(ingredient).display_name, count, required])
		enough = enough and count >= required
	ingredients_label.text = " • ".join(text)
	var missing := recipe.missing_equipment(available_equipment)
	var equipment_names: PackedStringArray = []
	for required in recipe.required_equipment:
		equipment_names.append(required.item.display_name)
		var installed := false
		for equipment in available_equipment:
			if equipment != null and equipment.id == required.id:
				installed = true
				break
		var badge := equipment_badge_scene.instantiate()
		equipment_icons.add_child(badge)
		badge.setup(required, installed)
	if not equipment_names.is_empty():
		ingredients_label.text += "\nAlat: " + ", ".join(equipment_names)
	if not missing.is_empty():
		ingredients_label.text += "\nBelum tersedia: " + ", ".join(missing)

	action_button.icon = recipe.display_icon()
	if CookingManager.knows(data, recipe.id):
		_learn = false
		action_button.text = "Masak ×%d" % recipe.output_count
		action_button.disabled = not enough or not missing.is_empty()
	else:
		_learn = true
		action_button.text = "Beli buku resep • %d G" % recipe.book_price
		action_button.disabled = GameState.money < recipe.book_price
	
		
		
