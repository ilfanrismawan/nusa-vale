class_name PlayerData
extends RefCounted

## Data milik satu pemain: tas, stamina, halaman hotbar, penampilan.
## GameState menyimpan satu PlayerData per pemain (co-op lokal 1-4 pemain);
## API lama GameState.add_item/remove_item/stamina/... meneruskan ke pemain yang sedang beraksi.
## Uang, ladang, dan flag dunia tetap bersama (lihat GameState).

signal stamina_changed(current: int, maximum: int)
signal hp_changed(current: int, maximum: int)
## Aksi ditolak karena stamina tidak cukup (HUD: bar stamina berkedip dan bergetar).
signal stamina_exhausted
signal appearance_changed(appearance: CharacterAppearance)

const MAX_STAMINA: int = 100
## HP dasar per pemain (GDD 8.1). Terpisah dari stamina; pulih penuh saat tidur.
const MAX_HP: int = 100
## Ukuran array inventory pemain; inventory peti sementara memakai configure_storage.
const INVENTORY_SIZE := 36
## Level tas: 0=Tas Kecil(12), 1=Ransel(24), 2=Ransel Besar(36)
const BAG_SIZES := [12, 24, 36]
const STARTER_TOOLS := ["axe_wood", "hoe_wood", "shovel_wood", "watering_can_wood", "sickle_wood", "pickaxe_wood", "fishing_rod_wood"]

## 0 = P1. Sama dengan index di GameState.players.
var index: int = 0

const DAYA_IDS := ["harvest", "forest", "balai"]
var consumed_daya: Array[String] = []
var max_stamina: int:
	# Bonus rumah milik rumah tangga (GDD 4.12).
	get: return MAX_STAMINA + consumed_daya.size() * 10 + HouseManager.stamina_bonus_total

var story_flags: Dictionary = {}
var completed_events: Dictionary = {}
var romances: Dictionary = {}
var story_mail: Dictionary = {}
## Per-character household: npc, mode, ceremony_day, celebrated, last_help_day.
var household: Dictionary = {}

func has_story_flags(required: Variant) -> bool:
	if not (required is Array or required is PackedStringArray):
		return false
	for flag in required:
		if not bool(story_flags.get(str(flag), false)):
			return false
	return true

func social_progress() -> Dictionary:
	return {
		"flags": story_flags.duplicate(true),
		"events": completed_events.duplicate(true),
		"romances": romances.duplicate(true),
		"mail": story_mail.duplicate(true),
		"household": household.duplicate(true)
	}

static func valid_social_progress(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["flags", "events", "romances"]:
		var entries: Variant = value.get(key, {})
		if not entries is Dictionary or entries.size() > 2048:
			return false
		for id in entries:
			if not id is String or id.is_empty() or id.length() > 256:
				return false
			if key == "romances":
				if not entries[id] is String or entries[id] not in ["dating", "married"]:
					return false
			elif not entries[id] is bool:
				return false
	if not NPCHousehold.valid_home(value.get("household", {})):
		return false
	var mail: Variant = value.get("mail", {})
	if not mail is Dictionary or mail.size() > 256:
		return false
	for id in mail:
		if not id is String or not mail[id] is Dictionary:
			return false
		var letter: Dictionary = mail[id]
		for field in ["subject", "body", "npc"]:
			if not letter.get(field) is String:
				return false
		var day: Variant = letter.get("arrival_day")
		if not (day is int or day is float) or not is_finite(float(day)) or float(day) != floorf(float(day)) or day < 1 or day > 1000000:
			return false
		if not letter.get("read") is bool:
			return false
		if not NPCHousehold.valid_rewards(letter):
			return false
		var flags: Variant = letter.get("sets_flags", [])
		if not flags is Array or flags.size() > 256:
			return false
		for flag in flags:
			if not flag is String or flag.is_empty():
				return false
	return true

func load_social_progress(value: Variant) -> void:
	household.clear()
	story_mail.clear()
	story_flags.clear()
	completed_events.clear()
	romances.clear()
	if not valid_social_progress(value):
		return
	story_flags = value.get("flags", {}).duplicate(true)
	completed_events = value.get("events", {}).duplicate(true)
	romances = value.get("romances", {}).duplicate(true)
	story_mail = value.get("mail", {}).duplicate(true)
	household = value.get("household", {}).duplicate(true)

func load_daya(value: Variant) -> void:
	consumed_daya.clear()
	if value is Array:
		for id in value:
			if id is String and id in DAYA_IDS and not consumed_daya.has(id):
				consumed_daya.append(id)

var stamina: int = MAX_STAMINA:
	set(value):
		stamina = clampi(value, 0, max_stamina)
		stamina_changed.emit(stamina, max_stamina)

var max_hp: int:
	get: return MAX_HP + roundi(skills.stat(&"max_hp")) if skills != null else MAX_HP

var hp: int = MAX_HP:
	set(value):
		hp = clampi(value, 0, max_hp)
		hp_changed.emit(hp, max_hp)

var watering_water: int = 20
## One order per player, held by the blacksmith until explicitly collected.
var tool_order: Dictionary = {}
var learned_recipes: Array[String] = []
var friendships: Dictionary = {}

func load_friendships(value: Variant) -> void:
	friendships = value.duplicate(true) if NPCSocialService.valid_save(value) else {}

var active_food_effects: Array[Dictionary] = []
var _food_cost_remainder := 0.0

func load_recipes(value: Variant) -> void:
	learned_recipes.clear()
	if value is Array:
		for id in value:
			if id is String and CookingManager.get_recipe(id) != null and not learned_recipes.has(id):
				learned_recipes.append(id)

var bag_level: int = 0
## Only temporary chest inventories use this override; player bags keep BAG_SIZES.
var _storage_capacity: int = 0
var hotbar_page: int = 0
var inventory: Array = []
## Senjata tidak lagi dipakai di slot equipment: pemain memegangnya dari hotbar (Phase 4B-1).
const EQUIPMENT_KEYS: Array[String] = ["helmet", "armor", "leggings", "boots", "necklace", "ring", "accessory"]
var equipment: Dictionary = empty_equipment()
var appearance: CharacterAppearance = CharacterAppearance.new()
## Id tetap karakter co-op di save ini (save v21). Kosong untuk P1.
var character_id: String = ""
## Nama yang diketik saat Game Baru (ditampilkan di menu slot save). Kosong = belum diberi nama.
var player_name: String = ""
## Role & EXP pemain ini (GDD 13).
var skills: PlayerSkills = PlayerSkills.new()
var birthday_season: String = ""
var birthday_day: int = 0
var pet_id: String = ""
var pet_name: String = ""
## Kendaraan yang sedang dinaiki/diparkir (GDD 10). Runtime saja, tidak disimpan:
## setelah load pemain mulai berjalan kaki.
var riding_vehicle_id: String = ""

## Jumlah slot yang aktif/terlihat saat ini
var bag_size: int:
	get: return _storage_capacity if _storage_capacity > 0 else BAG_SIZES[clampi(bag_level, 0, BAG_SIZES.size() - 1)]

func configure_storage(capacity: int) -> void:
	assert(index == -1, "Storage capacity is reserved for temporary chest inventories.")
	_storage_capacity = clampi(capacity, 1, 240)
	inventory.resize(_storage_capacity)


func _init(p_index: int = 0) -> void:
	index = p_index
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = null


## Isi awal pemain baru: tas kosong + alat kayu + bibit.
func reset_to_starter() -> void:
	story_mail.clear()
	household.clear()
	story_flags.clear()
	completed_events.clear()
	romances.clear()
	friendships.clear()
	clear_food_effects()
	consumed_daya.clear()
	tool_order.clear()
	learned_recipes.clear()
	skills.reset()
	equipment = empty_equipment()
	equipment["armor"] = GameState._resolve_item("armor_wood")
	stamina = MAX_STAMINA
	hp = MAX_HP
	watering_water = 20
	bag_level = 0
	hotbar_page = 0
	for i in INVENTORY_SIZE:
		inventory[i] = null
	setup_tools()
	add_item_silent("sword_wood", 1)
	add_item_silent("seed_strawberry", 5)
	add_item_silent("seed_carrot", 3)
	_changed()


func set_appearance(new_appearance: CharacterAppearance) -> void:
	appearance = new_appearance.duplicate() if new_appearance != null else CharacterAppearance.new()
	appearance_changed.emit(appearance)


# ── Stamina ─────────────────────────────────────────────────────────

func spend_stamina(amount: int) -> bool:
	if amount < 0:
		return false
	var exact_cost := amount * food_stamina_cost_multiplier() * SkillSystem.stamina_mult(self) + _food_cost_remainder
	var cost := floori(exact_cost)
	if stamina < cost:
		stamina_exhausted.emit()
		return false
	stamina -= cost
	_food_cost_remainder = exact_cost - cost
	return true

func clear_food_effects() -> void:
	active_food_effects.clear()
	_food_cost_remainder = 0.0

func apply_food_effect(effect: FoodEffectData) -> void:
	if effect == null or not effect.is_valid_effect():
		return
	for active in active_food_effects:
		var previous: FoodEffectData = active.effect
		if previous.id != effect.id:
			continue
		if effect.stacking == FoodEffectData.Stacking.REPLACE:
			active.remaining = effect.duration_seconds
			active.elapsed = 0.0
			active.stacks = 1
		else:
			active.remaining = maxf(float(active.remaining), effect.duration_seconds)
			active.stacks = mini(int(active.stacks) + 1, effect.max_stacks) if effect.stacking == FoodEffectData.Stacking.STACK else 1
		active.effect = effect.duplicate()
		return
	active_food_effects.append({"effect": effect.duplicate(), "remaining": effect.duration_seconds, "elapsed": 0.0, "stacks": 1})

func food_movement_multiplier() -> float:
	var multiplier := 1.0
	for active in active_food_effects:
		var effect: FoodEffectData = active.effect
		multiplier *= pow(effect.movement_multiplier, int(active.stacks))
	return multiplier

func food_stamina_cost_multiplier() -> float:
	var multiplier := 1.0
	for active in active_food_effects:
		var effect: FoodEffectData = active.effect
		multiplier *= pow(effect.stamina_cost_multiplier, int(active.stacks))
	return multiplier

func advance_food_effects(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for index in range(active_food_effects.size() - 1, -1, -1):
		var active := active_food_effects[index]
		var effect: FoodEffectData = active.effect
		var elapsed := float(active.elapsed) + minf(delta, float(active.remaining))
		var ticks := floori((elapsed + 0.000001) / effect.tick_interval)
		active.elapsed = maxf(0.0, elapsed - ticks * effect.tick_interval)
		if ticks > 0 and effect.stamina_per_tick != 0:
			stamina += effect.stamina_per_tick * ticks * int(active.stacks)
		if ticks > 0 and effect.hp_per_tick != 0 and hp > 0:
			hp += effect.hp_per_tick * ticks * int(active.stacks)
		active.remaining = maxf(0.0, float(active.remaining) - delta)
		if active.remaining <= 0.0:
			active_food_effects.remove_at(index)

func restore_stamina(amount: int = -1) -> void:
	stamina = mini(max_stamina, stamina + (max_stamina if amount < 0 else amount))


# ── HP ──────────────────────────────────────────────────────────────

## Kurangi HP; mengembalikan HP tersisa. amount sudah dikurangi DEF (lihat Combat).
func damage_hp(amount: int) -> int:
	hp -= maxi(0, amount)
	return hp

## amount < 0 = pulih penuh.
func restore_hp(amount: int = -1) -> void:
	hp = mini(max_hp, hp + (max_hp if amount < 0 else amount))

func is_defeated() -> bool:
	return hp <= 0


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
		var kind: String = tid.trim_suffix("_wood")
		var held: String = str(tool_order.get("old", ""))
		if not tool_order.is_empty() and (held == kind or held.begins_with(kind + "_")):
			continue
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
	if remaining < amount and item.category in [ItemData.Category.FISH, ItemData.Category.FORAGE, ItemData.Category.CROP, ItemData.Category.MATERIAL]:
		DiscoveryManager.discover("item_" + item.item_id)
	return remaining

## unit_override > 0: harga per unit dari pemanggil (mis. ShopUI setelah diskon Merchant).
func buy_item(item_id: String, amount: int = 1, unit_override: int = 0) -> bool:
	if amount <= 0:
		return false
	var item: ItemData = GameState._resolve_item(item_id)
	if item == null:
		return false
	var unit_price: int = item.buy_price
	if unit_price <= 0 and GameState.SHOP_PRICES.has(item_id):
		unit_price = GameState.SHOP_PRICES[item_id]
	if unit_override > 0:
		unit_price = unit_override
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
	if amount <= 0:
		return false
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


## Swap through the source slot, so replacing equipment also works with a full bag.
func equip_from_slot(slot: int) -> bool:
	if slot < 0 or slot >= bag_size or inventory[slot] == null:
		return false
	var item: ItemData = inventory[slot]["item"]
	var key := equipment_key(item)
	if key.is_empty() or int(inventory[slot]["count"]) != 1:
		return false
	var previous: ItemData = equipment[key]
	inventory[slot] = {"item": previous, "count": 1} if previous != null else null
	equipment[key] = item
	_changed()
	return true

func unequip(key: String) -> bool:
	if not equipment.has(key) or equipment[key] == null:
		return false
	var empty := find_empty_slot()
	if empty < 0:
		return false
	inventory[empty] = {"item": equipment[key], "count": 1}
	equipment[key] = null
	_changed()
	return true

static func equipment_key(item: ItemData) -> String:
	if item == null or item.stackable or item.max_stack != 1:
		return ""
	match item.equipment_slot:
		ItemData.EquipmentSlot.ARMOR: return "armor"
		ItemData.EquipmentSlot.HELMET: return "helmet"
		ItemData.EquipmentSlot.LEGGINGS: return "leggings"
		ItemData.EquipmentSlot.BOOTS: return "boots"
		ItemData.EquipmentSlot.NECKLACE: return "necklace"
		ItemData.EquipmentSlot.RING: return "ring"
		ItemData.EquipmentSlot.ACCESSORY: return "accessory"
	return ""

func equipment_stats() -> Vector2i:
	var stats := Vector2i.ZERO
	for item in equipment.values():
		if item is ItemData:
			stats += Vector2i(item.attack_bonus, item.defense_bonus)
	return stats

func serialize_equipment() -> Dictionary:
	var result := {}
	for key in equipment:
		if equipment[key] != null:
			result[key] = equipment[key].item_id
	return result

static func empty_equipment() -> Dictionary:
	var result := {}
	for key in EQUIPMENT_KEYS:
		result[key] = null
	return result

## Save lama hanya punya weapon/armor; slot lain otomatis kosong.
## Senjata yang dulu dipakai di slot "weapon" dipindah ke tas (save v13 ke bawah).
func load_equipment(saved: Variant) -> void:
	equipment = empty_equipment()
	if not saved is Dictionary:
		return
	var old_weapon: Variant = saved.get("weapon", "")
	if old_weapon is String and not old_weapon.is_empty() and ResourceLoader.exists("res://resources/item_data/%s.tres" % old_weapon):
		var weapon := GameState._resolve_item(old_weapon)
		if weapon != null and weapon.equipment_slot == ItemData.EquipmentSlot.WEAPON and not has_item(old_weapon):
			add_item_silent(weapon, 1)
	for key in equipment:
		var id: Variant = saved.get(key, "")
		if not id is String or id.is_empty() or not ResourceLoader.exists("res://resources/item_data/%s.tres" % id):
			continue
		var item := GameState._resolve_item(id)
		if equipment_key(item) == key:
			equipment[key] = item


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
	for i in inventory.size():
		inventory[i] = null
	if not entries is Array:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var item_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 1))
		var slot_id: int = int(entry.get("slot", -1))
		if item_id.is_empty() or slot_id < 0 or slot_id >= inventory.size() or count <= 0:
			continue
		var item: ItemData = GameState._resolve_item(item_id)
		if item == null:
			push_warning("Item tidak ditemukan saat load: %s" % item_id)
			continue
		inventory[slot_id] = {"item": item, "count": mini(count, item.max_stack)}

## Data pemain P2-P4 di save (P1 tetap memakai key lama "player" dan "inventory").
func to_dict() -> Dictionary:
	return {
		"id": character_id,
		"name": player_name,
		"birthday_season": birthday_season,
		"birthday_day": birthday_day,
		"npc_progress": social_progress(),
		"pet_id": pet_id,
		"pet_name": pet_name,
		"stamina": clampi(stamina, 0, max_stamina),
		"hp": clampi(hp, 1, max_hp),
		"consumed_daya": consumed_daya.duplicate(),
		"bag_level": bag_level,
		"watering_water": watering_water,
		"tool_order": tool_order.duplicate(true),
		"learned_recipes": learned_recipes.duplicate(),
		"friendships": friendships.duplicate(true),
		"appearance": appearance.to_dict(),
		"inventory": serialize_inventory(),
		"equipment": serialize_equipment(),
		"skills": skills.to_dict(),
	}

func load_dict(data: Dictionary) -> void:
	riding_vehicle_id = ""
	load_social_progress(data.get("npc_progress", {}))
	load_friendships(data.get("friendships", {}))
	clear_food_effects()
	load_recipes(data.get("learned_recipes", []))
	load_tool_order(data.get("tool_order", {}))
	var saved_name: Variant = data.get("name", "")
	player_name = saved_name if saved_name is String else ""
	var saved_id: Variant = data.get("id", "")
	character_id = saved_id if saved_id is String else ""
	load_birthday(data)
	load_pet(data)
	watering_water = clampi(int(data.get("watering_water", 20)), 0, 350)
	load_daya(data.get("consumed_daya", []))
	skills.load_dict(data.get("skills", {}))
	stamina = clampi(int(data.get("stamina", MAX_STAMINA)), 0, max_stamina)
	hp = clampi(int(data.get("hp", MAX_HP)), 1, max_hp)
	bag_level = clampi(int(data.get("bag_level", 0)), 0, BAG_SIZES.size() - 1)
	hotbar_page = 0
	var look: Variant = data.get("appearance", {})
	set_appearance(CharacterAppearance.from_dict(look if look is Dictionary else {}))
	load_inventory(data.get("inventory", []))
	load_equipment(data.get("equipment", {}))

func load_pet(data: Dictionary) -> void:
	var saved_id: Variant = data.get("pet_id", "")
	var saved_name: Variant = data.get("pet_name", "")
	pet_id = saved_id.strip_edges() if saved_id is String else ""
	pet_name = saved_name.strip_edges() if saved_name is String and not pet_id.is_empty() else ""

func load_birthday(data: Dictionary) -> void:
	birthday_season = ""
	birthday_day = 0
	var season: Variant = data.get("birthday_season", "")
	var day: Variant = data.get("birthday_day", 0)
	if not season is String or not DayCycle.SEASONS.has(season):
		return
	if not (day is int or day is float) or not is_finite(float(day)):
		return
	if float(day) != floorf(float(day)) or day < 1 or day > DayCycle.DAYS_PER_SEASON:
		return
	birthday_season = season
	birthday_day = int(day)

func load_tool_order(value: Variant) -> void:
	tool_order.clear()
	if not value is Dictionary or value.is_empty():
		return
	var old: Variant = value.get("old", "")
	var next: Variant = value.get("next", "")
	var ready: Variant = value.get("ready_day", 0)
	if not old is String or not next is String or not (ready is int or ready is float):
		return
	if not is_finite(float(ready)) or ready < 1 or ready > 1000000:
		return
	var tiers: Array = ToolData.ToolTier.keys()
	for starter in STARTER_TOOLS:
		var kind: String = starter.trim_suffix("_wood")
		var normalized: String = old + "_wood" if old == kind else old
		if not normalized.begins_with(kind + "_"):
			continue
		var tier := tiers.find(normalized.trim_prefix(kind + "_").to_upper())
		if tier >= 0 and tier + 1 < tiers.size() and next == kind + "_" + str(tiers[tier + 1]).to_lower():
			tool_order = {"old": old, "next": next, "ready_day": int(ready)}
			return
