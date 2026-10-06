extends Node

signal stamina_changed(current: int, maximum: int)
signal inventory_changed
signal money_changed(new_amount: int)
signal bag_upgraded(new_size: int)

var money: int = 100
var chopped_trees: Array[String] = []
var mined_rocks: Array[String] = []

const MAX_STAMINA: int = 100
var stamina: int = MAX_STAMINA

## Ukuran maksimal absolut array inventory (tidak pernah berubah)
const INVENTORY_SIZE := 36

## Level tas: 0=Tas Kecil(12), 1=Ransel(24), 2=Ransel Besar(36)
const BAG_SIZES := [12, 24, 36]
var bag_level: int = 0

## Jumlah slot yang aktif/terlihat saat ini
var bag_size: int:
	get: return BAG_SIZES[bag_level]

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
	bag_level = 0  # Mulai dari Tas Kecil (12 slot)

	for i in INVENTORY_SIZE:
		inventory[i] = null

	_setup_tools()
	_add_item_silent("seed_strawberry", 5)
	_add_item_silent("seed_carrot", 3)

	stamina_changed.emit(stamina, MAX_STAMINA)
	money_changed.emit(money)
	inventory_changed.emit()
	print("[GameState] new_game: state direset ke default.")

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
	var tool_ids := ["axe_wood", "hoe_wood", "shovel_wood", "watering_can_wood", "sickle_wood", "pickaxe_wood"]
	for i in range(tool_ids.size()):
		var tid = tool_ids[i]
		var item: ItemData = _resolve_item(tid)
		if item != null:
			inventory[i] = {"item": item, "count": 1}
			print("[GameState] Tool '%s' ditaruh di slot %d" % [item.display_name, i])
		else:
			push_warning("[GameState] Gagal me-resolve tool: %s" % tid)


func ensure_starter_tools() -> void:
	var tool_ids := ["axe_wood", "hoe_wood", "shovel_wood", "water_wood", "sickle_wood", "pickaxe_wood"]
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

func swap_slots(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= bag_size or to_slot < 0 or to_slot >= bag_size:
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

func _add_item_silent(item_or_id: Variant, amount: int = 1) -> void:
	var item: ItemData = _resolve_item(item_or_id)
	if item == null or amount <= 0:
		return
	var remaining := amount
	if item.stackable:
		for i in bag_size:
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
		
	if not item_or_id is String:
		return null
	
	var item_id: String = item_or_id
	
	if item_id.is_empty():
		return null
		
	var path: String = "res://resources/item_data/%s.tres" % item_or_id
	
	if not ResourceLoader.exists(path):
		push_error("ItemData tidak ditemukan: %s" % path)
		return null
	
	var resource: Resource = load(path) 
	
	if resource == null:
		push_error("Gagal load ItemData: %s" % path )
		return null
	
	if not resource is ItemData:
		push_error("Resource bukan ItemData: %s" % path)
		return null
	
	return resource as ItemData

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
	
	# 1. Coba stack ke slot yang sudah ada item sama (hanya dalam bag_size aktif)
	if item.stackable:
		for i in bag_size:
			if remaining <= 0:
				break
			if inventory[i] == null:
				continue
			if inventory[i]["item"].item_id != item.item_id:
				continue
			var can_add := mini(remaining, item.max_stack - inventory[i]["count"])
			inventory[i]["count"] += can_add
			remaining -= can_add

	# 2. Masukkan sisa ke slot kosong (hanya dalam bag_size aktif)
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
	for i in range(bag_size - 1, -1, -1):
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
	# Hitung hanya dari slot aktif (bag_size)
	for i in bag_size:
		var slot = inventory[i]
		if slot != null and slot["item"].item_id == item_id:
			total += slot["count"]
	return total

func _find_empty_slot() -> int:
	# Hanya cari slot kosong dalam bag_size aktif
	for i in bag_size:
		if inventory[i] == null:
			return i
	return -1


## Upgrade tas ke level berikutnya
func upgrade_bag() -> bool:
	if bag_level >= BAG_SIZES.size() - 1:
		Notify.say("Tas sudah di level maksimal!")
		return false
	bag_level += 1
	bag_upgraded.emit(bag_size)
	inventory_changed.emit()
	Notify.say("Tas di-upgrade! Sekarang %d slot tersedia." % bag_size)
	return true


var hotbar_page: int = 0


## Menggeser view hotbar ke halaman selanjutnya (tanpa mengacak isi array tas)
func cycle_hotbar() -> void:
	var total_pages: int = ceili(float(bag_size) / 8.0)
	hotbar_page = (hotbar_page + 1) % total_pages
	inventory_changed.emit()



## Gabungkan tumpukan dan sortir item — slot kosong ke belakang, dalam bag_size aktif
func sort_inventory() -> void:
	var active := bag_size

	# 1. Gabungkan stack item yang sama
	for i in range(active):
		if inventory[i] == null or inventory[i].get("item") == null:
			continue
		var item1: ItemData = inventory[i]["item"]

		for j in range(i + 1, active):
			if inventory[j] == null or inventory[j].get("item") == null:
				continue
			if inventory[j]["item"].item_id != item1.item_id:
				continue
			# Pindahkan sebanyak mungkin dari j ke i
			var space: int = item1.max_stack - inventory[i]["count"]
			if space > 0:
				var move: int = mini(space, inventory[j]["count"])
				inventory[i]["count"] += move
				inventory[j]["count"] -= move
				if inventory[j]["count"] <= 0:
					inventory[j] = null

	# 2. Kumpulkan semua item aktif ke array sementara, lalu susun kembali
	var filled: Array = []
	for i in range(active):
		if inventory[i] != null and inventory[i].get("item") != null:
			filled.append(inventory[i])
		inventory[i] = null  # bersihkan dulu

	# 3. Urutkan berdasarkan kategori lalu item_id
	filled.sort_custom(_compare_inventory_slots)

	# 4. Tempatkan kembali item yang sudah diurutkan dari slot 0
	for i in filled.size():
		inventory[i] = filled[i]

	inventory_changed.emit()

func _compare_inventory_slots(a, b) -> bool:
	if a == null or a.get("item") == null:
		return false
	if b == null or b.get("item") == null:
		return true

	var item_a: ItemData = a["item"]
	var item_b: ItemData = b["item"]

	# Alat (tools) selalu didahulukan
	var a_is_tool: bool = item_a.is_tool()
	var b_is_tool: bool = item_b.is_tool()
	if a_is_tool != b_is_tool:
		return a_is_tool

	# Lalu berdasarkan kategori (angka enum, urut naik)
	if item_a.category != item_b.category:
		return item_a.category < item_b.category

	# Lalu berdasarkan item_id alfabet
	if item_a.item_id != item_b.item_id:
		return item_a.item_id < item_b.item_id

	# Terakhir, terbanyak di depan
	return a["count"] > b["count"]
