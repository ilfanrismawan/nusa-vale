extends Node

signal stamina_changed(current: int, maximum: int)
signal inventory_changed
signal money_changed(new_amount: int)

var money: int = 100
var chopped_trees: Array[String] = []
var mined_rocks: Array[String] = []

const MAX_STAMINA: int = 100
var stamina: int = MAX_STAMINA

const INVENTORY_SIZE := 20
var inventory: Array = []

var next_spawn_position: Vector2 = Vector2.ZERO
var has_spawn_point: bool = false

const SHOP_PRICES := {
	"seed_strawberry": 15,
	"seed_carrot": 25,
}

func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = null

func new_game() -> void:
	money = 100
	stamina = MAX_STAMINA
	chopped_trees.clear()
	mined_rocks.clear()
	has_spawn_point = false
	next_spawn_position = Vector2.ZERO

	for i in INVENTORY_SIZE:
		inventory[i] = null

	_setup_tools()
	_add_item_silent("seed_strawberry", 5)
	_add_item_silent("seed_carrot", 3)

	stamina_changed.emit(stamina, MAX_STAMINA)
	money_changed.emit(money)
	inventory_changed.emit()
	print("[GameState] new_game: state direset ke default.")

## Reset inventory + isi starter items (tanpa reset money/stamina/flags).
## @deprecated — gunakan new_game() untuk game baru, atau biarkan SaveManager
## yang mengisi state saat load. Dipertahankan untuk kompatibilitas.
func reset_game_state() -> void:
	for i in INVENTORY_SIZE:
		inventory[i] = null

	_setup_tools()
	_add_item_silent("seed_strawberry", 5)
	_add_item_silent("seed_carrot", 3)

	inventory_changed.emit()

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, MAX_STAMINA)
	return true

func restore_stamina(amount: int = MAX_STAMINA) -> void:
	stamina = mini(MAX_STAMINA, stamina + amount)
	stamina_changed.emit(stamina, MAX_STAMINA)

func _setup_tools() -> void:
	var tool_ids := ["axe", "hoe", "shovel", "water", "sickle", "pickaxe"]
	for i in range(tool_ids.size()):
		var tid = tool_ids[i]
		var item: ItemData = _resolve_item(tid)
		if item != null:
			inventory[i] = {"item": item, "count": 1}
			print("[GameState] Tool '%s' ditaruh di slot %d" % [item.display_name, i])
		else:
			push_warning("[GameState] Gagal me-resolve tool: %s" % tid)


## Pastikan seluruh starter tools ada di inventory (misal jika load save file lama)
func ensure_starter_tools() -> void:
	var tool_ids := ["axe", "hoe", "shovel", "water", "sickle", "pickaxe"]
	var changed := false
	for tid in tool_ids:
		if not has_item(tid, 1):
			var item = _resolve_item(tid)
			if item != null:
				var empty_slot := _find_empty_slot()
				if empty_slot != -1:
					inventory[empty_slot] = {"item": item, "count": 1}
					changed = true
					print("[GameState] ensure_starter_tools: menambahkan '%s' ke slot %d" % [item.display_name, empty_slot])
	if changed:
		inventory_changed.emit()


## Menukar (swap) posisi dua slot di inventory (memungkinkan atur posisi item tas & HUD)
func swap_slots(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= INVENTORY_SIZE or to_slot < 0 or to_slot >= INVENTORY_SIZE:
		return false
	if from_slot == to_slot:
		return false
	
	var temp = inventory[from_slot]
	inventory[from_slot] = inventory[to_slot]
	inventory[to_slot] = temp
	
	inventory_changed.emit()
	var from_name = inventory[from_slot]["item"].display_name if inventory[from_slot] != null else "kosong"
	var to_name = inventory[to_slot]["item"].display_name if inventory[to_slot] != null else "kosong"
	print("[GameState] Swap slot %d (%s) <-> slot %d (%s)" % [from_slot, from_name, to_slot, to_name])
	return true


## Tambah item tanpa emit signal (untuk digunakan saat inisialisasi)
func _add_item_silent(item_or_id: Variant, amount: int = 1) -> void:
	var item: ItemData = _resolve_item(item_or_id)
	if item == null or amount <= 0:
		return
	var remaining := amount
	if item.stackable:
		for i in INVENTORY_SIZE:
			if remaining <= 0:
				break
			if inventory[i] == null or inventory[i]["item"].item_id != item.item_id:
				continue
			var can_add := mini(remaining, item.max_stack - inventory[i]["count"])
			inventory[i]["count"] += can_add
			remaining -= can_add
	while remaining > 0:
		var empty_slot := _find_empty_slot()
		if empty_slot == -1:
			break
		var stack := mini(remaining, item.max_stack)
		inventory[empty_slot] = {"item": item, "count": stack}
		remaining -= stack


## Helper untuk hotbar: kembalikan ItemData di slot tertentu, atau null
func get_hotbar_item(slot: int) -> ItemData:
	if slot < 0 or slot >= inventory.size() or inventory[slot] == null:
		return null
	return inventory[slot]["item"]


## Helper untuk hotbar: kembalikan jumlah item di slot tertentu, atau 0
func get_hotbar_count(slot: int) -> int:
	if slot < 0 or slot >= inventory.size() or inventory[slot] == null:
		return 0
	return inventory[slot]["count"]



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

func buy_item(item_id: String, amount: int = 1) -> bool:
	var item: ItemData = _resolve_item(item_id)
	if item == null:
		return false
	var unit_price: int = item.buy_price
	if unit_price <= 0 and SHOP_PRICES.has(item_id):
		unit_price = SHOP_PRICES[item_id]
	if unit_price <= 0:
		return false
	var cost: int = unit_price * amount
	if not spend_money(cost):
		Notify.say("Uang tidak cukup!")
		return false
	var leftover := add_item(item, amount)
	if leftover > 0:
		add_money(unit_price * leftover) # refund sisa yang tidak muat
		return leftover < amount
	return true

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

func replace_tool(
	old_tool_id: String,
	new_tool_id: String
)	-> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		
		if slot == null:
			continue		
			
		var item: ItemData = slot["item"]
		
		if item == null:
			continue
		
		if item.item_id != old_tool_id:
			continue
		
		var new_item: ItemData = _resolve_item(new_tool_id)
		
		if new_item == null:
			push_error(
				"Tool baru tidak ditemukan: %s"
				% new_tool_id
			)
			return false
		
		inventory[i] = {
			"item": new_item,
			"count": 1
		}
		
		inventory_changed.emit()
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
