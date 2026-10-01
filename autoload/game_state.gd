extends Node

signal inventory_changed
signal money_changed(new_amount: int)
var money: int = 100

const INVENTORY_SIZE := 20
var inventory: Array = []

var next_spawn_position: Vector2 = Vector2.ZERO
var has_spawn_point: bool = false


func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = null
	
	# Starter items untuk demo / testing
	add_item("seed_strawberry", 5)
	add_item("strawberry", 3)

func _resolve_item(item_or_id: Variant) -> ItemData:
	if item_or_id is ItemData:
		return item_or_id
	if item_or_id is String and not item_or_id.is_empty():
		var path := "res://resources/item_data/%s.tres" % item_or_id
		if ResourceLoader.exists(path):
			return load(path)
		var item := ItemData.new()
		item.item_id = item_or_id
		item.display_name = item_or_id.capitalize()
		var icon_path := "res://resources/icons/icon_%s.tres" % item_or_id
		if ResourceLoader.exists(icon_path):
			item.icon = load(icon_path)
		return item
	return null

## Tambah item ke slot inventory (mendukung ItemData atau String item_id)
func add_item(item_or_id: Variant, amount: int = 1) -> int:
	var item: ItemData = _resolve_item(item_or_id)
	if item == null or amount <= 0:
		return amount
	
	var remaining := amount
	
	# 1. Coba stack ke slot yang sudah ada item sama
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

	# 2. Masukkan sisa ke slot kosong
	while remaining > 0:
		var empty_slot := _find_empty_slot()
		if empty_slot == -1:
			break
		var stack := mini(remaining, item.max_stack)
		inventory[empty_slot] = {"item": item, "count": stack}
		remaining -= stack

	inventory_changed.emit()
	print("Inventory: Dapat %s x%d" % [item.display_name, amount - remaining])
	return remaining

## Hapus item di slot tertentu
func remove_item_at(slot: int, amount: int = 1) -> bool:
	if slot < 0 or slot >= INVENTORY_SIZE or inventory[slot] == null:
		return false
	inventory[slot]["count"] -= amount
	if inventory[slot]["count"] <= 0:
		inventory[slot] = null
	inventory_changed.emit()
	return true

## Hapus item berdasarkan item_id
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	var remaining := amount
	for i in range(INVENTORY_SIZE - 1, -1, -1):
		if inventory[i] != null and inventory[i]["item"].item_id == item_id:
			var take := mini(remaining, inventory[i]["count"])
			inventory[i]["count"] -= take
			remaining -= take
			if inventory[i]["count"] <= 0:
				inventory[i] = null
			if remaining <= 0:
				break
	inventory_changed.emit()
	return true

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)
	
func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false
	
## Cek apakah ada item sebanyak jumlah tertentu
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

## Hitung total item berdasarkan item_id
func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in inventory:
		if slot != null and slot["item"].item_id == item_id:
			total += slot["count"]
	return total

func _find_empty_slot() -> int:
	for i in INVENTORY_SIZE:
		if inventory[i] == null:
			return i
	return -1
