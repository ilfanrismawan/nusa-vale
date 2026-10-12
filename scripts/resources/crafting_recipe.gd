class_name CraftingRecipe
extends Resource

@export var recipe_id: String = ""
@export var output_item_id: String = ""
@export_range(1, 99) var output_amount: int = 1
## Item ID -> amount consumed per batch. All materials come from the player's active bag.
@export var ingredients: Dictionary = {}
@export var group: String = "Equipment"
