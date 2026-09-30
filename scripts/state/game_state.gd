extends Node

signal inventory_changed

const INVENTORY_SIZE := 20
var inventory: Array = []

func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = null

func add_item(item: ItemData, amount: int = 1) -> int:
	var remaining := amount
	
	if item.stackable:
		for i in INVENTORY_SIZE:
			if remaining <= 0:
				break
			if inventory[i] == null:
				continue
			if inventory[i]["item"].item_id != item.item_id:
				continue
			var can_add := mini(remaining, item.max_stack - inventory[i]["count"])
			inventory[i]["count"] += can_add
			remaining -= can_add
	while  remaining > 0:
		var empty_slot := _find_empty_slot()
		if empty_slot == -1:
			break
		var stack := mini(remaining, item.max_stack)
		inventory[empty_slot] = {"item": item, "count": stack}
		remaining -= stack
	
	inventory_changed.emit()
	return remaining

func remove_item_at(slot: int, amount: int = 1) -> bool:
	if inventory[slot] == null:
		return false
	inventory[slot]["count"] -= amount
	if inventory[slot]["count"] <= 0:
		inventory[slot] = null
	inventory_changed.emit()
	return true
	
	
func has_item(item_id: String, amount: int = 1) -> bool:
	var total := 0
	for slot in inventory:
		if slot != null and slot["item"].item_id == item_id:
			total += slot["count"]
	return total >= amount
	
func _find_empty_slot() -> int:
	for i in INVENTORY_SIZE:
		if inventory[i] == null:
			return i
	return -1
