extends RefCounted

## Pesona senjata Menara Penyihir (GDD "Menara Penyihir", Altar Enchant). Status per pemain di
## PlayerData.enchants {item_id senjata: id pesona}; semua senjata dengan item_id sama ikut
## terpesona. Dipakai lewat preload (tanpa class_name):
##   const Enchanting = preload("res://scripts/system/enchanting.gd")

const DIR := "res://resources/witch/enchants/"
const IDS: Array[String] = ["ember", "frost", "shadow", "fairy", "dark_fire"]

static var _cache: Dictionary = {}


static func load_enchant(id: String) -> Resource:
	if not id in IDS:
		return null
	if not _cache.has(id):
		_cache[id] = load(DIR + id + ".tres")
	return _cache[id]


static func all() -> Array[Resource]:
	var result: Array[Resource] = []
	for id in IDS:
		var enchant := load_enchant(id)
		if enchant != null:
			result.append(enchant)
	return result


## Senjata yang bisa dipesona: pedang, busur, tongkat sihir.
static func can_enchant(item: ItemData) -> bool:
	return item != null and item.equipment_slot == ItemData.EquipmentSlot.WEAPON and Combat.style_for(item) != null


static func of(data: PlayerData, item: ItemData) -> Resource:
	if data == null or item == null:
		return null
	return load_enchant(str(data.enchants.get(item.item_id, "")))


static func set_enchant(data: PlayerData, item_id: String, id: String) -> void:
	data.enchants[item_id] = id


## WeaponTierFx untuk serangan: fx tier senjata, efek status ditimpa pesona bila ada.
static func fx_for(data: PlayerData, weapon: ItemData) -> WeaponTierFx:
	var base := WeaponTierFx.for_item(weapon)
	var enchant := of(data, weapon)
	if enchant == null:
		return base
	var key := "%s|%s" % [weapon.item_id, enchant.get("id")]
	if not _cache.has(key):
		_cache[key] = enchant.apply_to(base)
	return _cache[key]


static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 256:
		return false
	for key in value:
		if not key is String or key.is_empty() or key.length() > 64 or not value[key] is String:
			return false
	return true


## Save lama (sebelum v28) tanpa kunci "enchants" = belum ada senjata terpesona.
static func load_save(data: PlayerData, saved: Dictionary) -> void:
	data.enchants.clear()
	var value: Variant = saved.get("enchants", {})
	if not valid_save(value):
		return
	for item_id in value:
		if String(value[item_id]) in IDS:
			data.enchants[item_id] = String(value[item_id])
