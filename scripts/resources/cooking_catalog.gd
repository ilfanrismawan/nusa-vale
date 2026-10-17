class_name CookingCatalog
extends Resource

@export var recipes: RecipeDatabase
@export var equipment: Array[CookingEquipmentData] = []
@export var object_scenes: Array[PackedScene] = []
@export var pantry_items: Array[ItemData] = []
@export var food_effects: Array[FoodEffectData] = []
