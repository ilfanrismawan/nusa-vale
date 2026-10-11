class_name PlayerData
extends RefCounted

## Data milik satu pemain: tas, stamina, halaman hotbar, penampilan.
## GameState menyimpan satu PlayerData per pemain (co-op lokal 1-4 pemain);
## API lama GameState.add_item/remove_item/stamina/... meneruskan ke pemain yang sedang beraksi.
## Uang, ladang, dan flag dunia tetap bersama (lihat GameState).

signal stamina_changed(current: int, maximum: int)
signal appearance_changed(appearance: CharacterAppearance)

const MAX_STAMINA: int = 100
## Ukuran maksimal absolut array inventory (tidak pernah berubah)
const INVENTORY_SIZE := 36
## Level tas: 0=Tas Kecil(12), 1=Ransel(24), 2=Ransel Besar(36)
const BAG_SIZES := [12, 24, 36]
const STARTER_TOOLS := ["axe_wood", "hoe_wood", "shovel_wood", "watering_can_wood", "sickle_wood", "pickaxe_wood", "fishing_rod_wood"]

## 0 = P1. Sama dengan index di GameState.players.
var index: int = 0

var stamina: int = MAX_STAMINA:
	set(value):
		stamina = value
		stamina_changed.emit(stamina, MAX_STAMINA)

var bag_level: int = 0
var hotbar_page: int = 0
var inventory: Array = []
var appearance: CharacterAppearance = CharacterAppearance.new()

## Jumlah slot yang aktif/terlihat saat ini
var bag_size: int:
	get: return BAG_SIZES[clampi(bag_level, 0, BAG_SIZES.size() - 1)]


func _init(p_index: int = 0) -> void:
	index = p_index
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = null


## Isi awal pemain baru: tas kosong + alat kayu + bibit.
func reset_to_starter() -> void:
	stamina = MAX_STAMINA
	bag_level = 0
	hotbar_page = 0
	for i in INVENTORY_SIZE:
		inventory[i] = null
	setup_tools()
	add_item_silent("seed_strawberry", 5)
	add_item_silent("seed_carrot", 3)
	_changed()


func set_appearance(new_appearance: CharacterAppearance) -> void:
	appearance = new_appearance.duplicate() if new_appearance != null else CharacterAppearance.new()
	appearance_changed.emit(appearance)


# ── Stamina ─────────────────────────────────────────────────────────

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true

func restore_stamina(amount: int = MAX_STAMINA) -> void:
	stamina = mini(MAX_STAMINA, stamina + amount)


# ── Alat awal ───────────────────────────────────────────────────────

func setup_tools() -> void:
	for i in range(STARTER_TOOLS.size()):
		var tid: String = STARTER_TOOLS[i]
		var item: ItemData = GameState._resolve_item(tid)
		if item != null:
			inventory[i] = {"item": item, "count": 1}
		else:
			push_warning("[PlayerData] Gagal me-resolve tool: %s" % tid)

func ensure_starter_tools() -> void:
	var changed := false
	for tid in STARTER_TOOLS:
		if not has_item(tid, 1):
			var item: ItemData = GameState._resolve_item(tid)
			if item != null:
				var empty_slot := find_empty_slot()
				if empty_slot != -1:
					inventory[empty_slot] = {"item": item, "count": 1}
					changed = true
					print("[PlayerData] ensure_starter_tools: menambahkan '%s' ke slot %d" % [item.display_name, empty_slot])
	if changed:
		_changed()


# ── Tas ─────────────────────────────────────────────────────────────

func swap_slots(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= bag_size or to_slot < 0 or to_slot >= bag_size:
		return false
	if from_slot == to_slot:
		return false

	var temp = inventory[from_slot]
	inventory[from_slot] = inventory[to_slot]
	inventory[to_slot] = temp

	_changed()
	var from_name = inventory[from_slot]["item"].display_name if inventory[from_slot] != null else "kosong"
	var to_name = inventory[to_slot]["item"].display_name if inventory[to_slot] != null else "kosong"
	print("[PlayerData P%d] Swap slot %d (%s) <-> slot %d (%s)" % [index + 1, from_slot, from_name, to_slot, to_name])
	return true

func add_item_silent(item_or_id: Variant, amount: int = 1) -> void:
	var item: ItemData = GameState._resolve_item(item_or_id)
	if item == null or amount <= 0:
		return
	_store(item, amount)

## Tambah item ke slot inventory (mendukung ItemData atau String item_id). Mengembalikan sisa yang tidak muat.
func add_item(item_or_id: Variant, amount: int = 1) -> int:
	var item: ItemData = GameState._resolve_item(item_or_id)
	if item == null or amount <= 0:
		return amount
	var remaining := _store(item, amount)
	_changed()
	print("Inventory P%d: Dapat %s x%d" % [index + 1, item.display_name, amount - remaining])
	return remaining

func _store(item: ItemData, amount: int) -> int:
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
		var empty_slot := find_empty_slot()
		if empty_slot == -1:
			break
		var stack := mini(remaining, item.max_stack)
		inventory[empty_slot] = {"item": item, "count": stack}
		remaining -= stack
	return remaining

func buy_item(item_id: String, amount: int = 1) -> bool:
	var item: ItemData = GameState._resolve_item(item_id)
	if item == null:
		return false
	var unit_price: int = item.buy_price
	if unit_price <= 0 and GameState.SHOP_PRICES.has(item_id):
		unit_price = GameState.SHOP_PRICES[item_id]
	if unit_price <= 0:
		return false
	var cost: int = unit_price * amount
	if not GameState.spend_money(cost):
		Notify.say("Uang tidak cukup!")
		return false
	var leftover := add_item(item, amount)
	if leftover > 0:
		GameState.add_money(unit_price * leftover) # refund sisa yang tidak muat
		return leftover < amount
	return true

## Hapus item di slot tertentu
func remove_item_at(slot: int, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if slot < 0 or slot >= bag_size:
		return false
	if slot >= inventory.size() or inventory[slot] == null:
		return false

	var current_count: int = inventory[slot]["count"]
	if amount > current_count:
		return false

	inventory[slot]["count"] = current_count - amount
	if inventory[slot]["count"] == 0:
		inventory[slot] = null

	_changed()
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
	_changed()
	return true

func replace_tool(old_tool_id: String, new_tool_id: String) -> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot == null:
			continue
		var item: ItemData = slot["item"]
		if item == null or item.item_id != old_tool_id:
			continue
		var new_item: ItemData = GameState._resolve_item(new_tool_id)
		if new_item == null:
			push_error("Tool baru tidak ditemukan: %s" % new_tool_id)
			return false
		inventory[i] = {"item": new_item, "count": 1}
		_changed()
		return true
	return false

## Cek apakah ada item sebanyak jumlah tertentu
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

## Hitung total item berdasarkan item_id (hanya slot aktif)
func get_item_count(item_id: String) -> int:
	var total := 0
	for i in bag_size:
		var slot = inventory[i]
		if slot != null and slot["item"].item_id == item_id:
			total += slot["count"]
	return total

func find_empty_slot() -> int:
	for i in bag_size:
		if inventory[i] == null:
			return i
	return -1

func get_hotbar_item(slot: int) -> ItemData:
	if slot < 0 or slot >= inventory.size() or inventory[slot] == null:
		return null
	return inventory[slot]["item"]

func get_hotbar_count(slot: int) -> int:
	if slot < 0 or slot >= inventory.size() or inventory[slot] == null:
		return 0
	return inventory[slot]["count"]

## Upgrade tas ke level berikutnya
func upgrade_bag() -> bool:
	if bag_level >= BAG_SIZES.size() - 1:
		Notify.say("Tas sudah di level maksimal!")
		return false
	bag_level += 1
	GameState.bag_upgraded.emit(bag_size)
	_changed()
	Notify.say("Tas di-upgrade! Sekarang %d slot tersedia." % bag_size)
	return true

## Menggeser view hotbar ke halaman selanjutnya (tanpa mengacak isi array tas)
func cycle_hotbar() -> void:
	var total_pages: int = ceili(float(bag_size) / 8.0)
	hotbar_page = (hotbar_page + 1) % total_pages
	_changed()

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
		inventory[i] = null

	# 3. Urutkan berdasarkan kategori lalu item_id
	filled.sort_custom(_compare_inventory_slots)

	# 4. Tempatkan kembali item yang sudah diurutkan dari slot 0
	for i in filled.size():
		inventory[i] = filled[i]

	_changed()

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

func _changed() -> void:
	GameState.inventory_changed.emit()


# ── Save ────────────────────────────────────────────────────────────

func serialize_inventory() -> Array:
	var result: Array = []
	for i in range(inventory.size()):
		var slot: Variant = inventory[i]
		if not slot is Dictionary or slot.get("item") == null:
			continue
		var item: ItemData = slot["item"]
		var count: int = int(slot.get("count", 1))
		if count <= 0:
			continue
		result.append({"slot": i, "id": item.item_id, "count": mini(count, item.max_stack)})
	return result

func load_inventory(entries: Variant) -> void:
	for i in INVENTORY_SIZE:
		inventory[i] = null
	if not entries is Array:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var item_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 1))
		var slot_id: int = int(entry.get("slot", -1))
		if item_id.is_empty() or slot_id < 0 or slot_id >= INVENTORY_SIZE or count <= 0:
			continue
		var item: ItemData = GameState._resolve_item(item_id)
		if item == null:
			push_warning("Item tidak ditemukan saat load: %s" % item_id)
			continue
		inventory[slot_id] = {"item": item, "count": mini(count, item.max_stack)}

## Data pemain P2-P4 di save (P1 tetap memakai key lama "player" dan "inventory").
func to_dict() -> Dictionary:
	return {
		"stamina": clampi(stamina, 0, MAX_STAMINA),
		"bag_level": bag_level,
		"appearance": appearance.to_dict(),
		"inventory": serialize_inventory(),
	}

func load_dict(data: Dictionary) -> void:
	stamina = clampi(int(data.get("stamina", MAX_STAMINA)), 0, MAX_STAMINA)
	bag_level = clampi(int(data.get("bag_level", 0)), 0, BAG_SIZES.size() - 1)
	hotbar_page = 0
	var look: Variant = data.get("appearance", {})
	set_appearance(CharacterAppearance.from_dict(look if look is Dictionary else {}))
	load_inventory(data.get("inventory", []))
