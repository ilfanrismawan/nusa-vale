class_name KitchenStation
extends Area2D

@export var menu_scene: PackedScene = preload("res://scenes/ui/cooking_ui.tscn")
@export var equipment_data: CookingEquipmentData
@export var installed_equipment: Array[CookingEquipmentData] = []

func _ready() -> void:
	set_meta("player_interaction", true)

func interact(player: Player) -> void:
	if player.is_input_locked():
		return
	var menu := menu_scene.instantiate()
	menu.player = player
	menu.equipment_data = equipment_data
	menu.available_equipment.assign(installed_equipment)
	if equipment_data != null and not menu.available_equipment.has(equipment_data):
		menu.available_equipment.append(equipment_data)
	Coop.ui_parent(player).add_child(menu)
