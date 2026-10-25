class_name SkillSystem
extends RefCounted

## Aturan Role & EXP bersama (GDD 13): data role, EXP, dan efek perk yang dibaca sistem lain.
## Progres tiap pemain ada di PlayerData.skills (PlayerSkills); data di resources/skills/.
##
## Kunci stat perk (RolePerk.effects), nilai dijumlah antar perk aktif:
## Farmer    farm_tool_stamina (potongan stamina cangkul/penyiram/sabit), soil_keep_wet (peluang),
##           crop_growth (peluang +1 hari tumbuh), harvest_double, water_save, season_survive
## Forager   forage_double, wood_extra, axe_tree_damage (+pengali), weed_fiber, tree_growth, tree_replant, dig_rare
## Fisher    fish_zone, bite_speed, cast_range (petak), perfect_window (+pengali), fish_double,
##           fish_calm, fish_sell, rare_fish (+pengali), ice_fishing
## Combat    attack, combat_stamina, parry_window (detik), riposte_bonus, attack_speed, low_hp_damage,
##           max_hp, iframes (detik), poise_damage, kill_heal, damage_reduction, stagger_immune
## Miner     pickaxe_stamina, pickaxe_power, coal_double, gem_double, ore_double, smelt_speed, stairs_chance
## Merchant  shop_discount, shop_sell, bulk_seed_discount, facility_discount
## Balai Nadi (bonus sayap) tool_upgrade_discount (biaya uang upgrade alat), geode_chance (+pengali geoda)
## Economist ship_bonus, faint_penalty, balai_discount, daily_interest, faint_farm_free, shared_prosperity, shipping_pickups

const RULES: SkillRules = preload("res://resources/skills/skill_rules.tres")
const ROLE_DIR := "res://resources/skills/roles/%s.tres"
const ROLE_IDS: Array[StringName] = [&"farmer", &"forager", &"fisher", &"combat", &"miner", &"merchant", &"economist"]
const MAX_LEVEL := 10
## Pemain di bawah HP ini (bagian HP maks) mendapat bonus low_hp_damage (Berserker).
const LOW_HP_RATIO := 0.4

static var _roles: Array[RoleData] = []


static func roles() -> Array[RoleData]:
	if _roles.is_empty():
		for id in ROLE_IDS:
			var entry := load(ROLE_DIR % id) as RoleData
			if entry != null:
				_roles.append(entry)
			else:
				push_warning("SkillSystem: role %s tidak ditemukan." % id)
	return _roles

static func role(role_id: StringName) -> RoleData:
	for item in roles():
		if item.role_id == role_id:
			return item
	return null

static func level_for_points(value: int) -> int:
	var result := 0
	for threshold in RULES.level_exp:
		if value < threshold:
			break
		result += 1
	return mini(result, MAX_LEVEL)

## Total EXP untuk mencapai level ini (0 untuk Lv0).
static func points_for_level(at_level: int) -> int:
	if at_level <= 0:
		return 0
	return RULES.level_exp[clampi(at_level, 1, RULES.level_exp.size()) - 1]

static func max_points() -> int:
	return points_for_level(MAX_LEVEL)

static func _data(data: PlayerData) -> PlayerData:
	return data if data != null else GameState.current


# ── EXP ─────────────────────────────────────────────────────────────

## Tambah EXP role ke pemain (null = pemain yang sedang beraksi).
static func gain(data: PlayerData, role_id: StringName, amount: float) -> void:
	data = _data(data)
	if data == null or data.skills == null or amount <= 0.0:
		return
	var reached := data.skills.add_points(role_id, amount)
	if reached > 0:
		var item := role(role_id)
		Notify.say("%s%s siap naik ke Lv %d! Tidur untuk membuka keahlian baru." % [_who(data), item.title if item != null else String(role_id), reached])

## "P2: " saat co-op supaya jelas pemain mana yang naik level.
static func _who(data: PlayerData) -> String:
	if GameState.players.size() <= 1:
		return ""
	return "%s: " % (data.player_name if not data.player_name.strip_edges().is_empty() else "P%d" % (data.index + 1))

## EXP pecahan dari nilai uang (kiriman, transaksi toko, sumbangan).
static func gain_from_value(data: PlayerData, role_id: StringName, gold: float, gold_per_exp: float, cap: int = 0) -> void:
	if gold <= 0.0 or gold_per_exp <= 0.0:
		return
	var amount := gold / gold_per_exp
	if cap > 0:
		amount = minf(amount, float(cap))
	gain(data, role_id, amount)

static func scaled_exp(price: int, per_price: float, low: int, high: int) -> int:
	return clampi(roundi(price * per_price), low, high)


# ── Stat perk ───────────────────────────────────────────────────────

static func stat(data: PlayerData, key: StringName) -> float:
	data = _data(data)
	return (data.skills.stat(key) if data != null and data.skills != null else 0.0) + wing_bonus(key)

## Bonus permanen sayap Balai Nadi yang lengkap (GDD 4.9), berlaku untuk semua pemain.
static func wing_bonus(key: StringName) -> float:
	return GameState.balai_nadi.wing_stat(key) if GameState.balai_nadi != null else 0.0

static func has(data: PlayerData, key: StringName) -> bool:
	return stat(data, key) > 0.0

static func roll(data: PlayerData, key: StringName) -> bool:
	var chance := stat(data, key)
	return chance > 0.0 and randf() < chance

## Nilai terbesar di antara pemain sesi ini, untuk efek dunia bersama (ladang, gua, bunga kas).
static func household(key: StringName) -> float:
	var best := 0.0
	for data in GameState.players:
		if data != null and data.skills != null:
			best = maxf(best, data.skills.stat(key))
	return best + wing_bonus(key)

static func household_roll(key: StringName) -> bool:
	var chance := household(key)
	return chance > 0.0 and randf() < chance

## Shared Prosperity (Economist Lv10 B): aura co-op saat dimainkan bersama pemain lain.
static func shared_prosperity() -> bool:
	return GameState.players.size() > 1 and household(&"shared_prosperity") > 0.0


# ── Alat dan stamina ────────────────────────────────────────────────

## Stamina alat setelah perk: cangkul/penyiram/sabit (Farmer), beliung (Miner).
static func tool_cost(data: PlayerData, tool: ToolData, cost: int) -> int:
	if tool == null or cost <= 0:
		return cost
	var cut := 0.0
	match tool.tool_type:
		ToolData.ToolType.HOE, ToolData.ToolType.WATERING_CAN, ToolData.ToolType.SICKLE:
			cut = stat(data, &"farm_tool_stamina")
		ToolData.ToolType.PICKAXE:
			cut = stat(data, &"pickaxe_stamina")
	return maxi(1, roundi(cost * (1.0 - clampf(cut, 0.0, 0.9))))

## Pengali stamina harian untuk semua aksi (aura Shared Prosperity).
static func stamina_mult(_data_ref: PlayerData) -> float:
	return 0.9 if shared_prosperity() else 1.0

## Kekuatan pukulan kapak/beliung setelah perk.
static func tool_damage(data: PlayerData, tool: ToolData, damage: int) -> int:
	if tool == null:
		return damage
	match tool.tool_type:
		ToolData.ToolType.AXE:
			return roundi(damage * (1.0 + stat(data, &"axe_tree_damage")))
		ToolData.ToolType.PICKAXE:
			return damage + roundi(stat(data, &"pickaxe_power"))
	return damage

## Salinan RodData dengan perk Fisher (zona, gigitan, lemparan, ikan tenang, ganda, langka).
static func apply_rod(data: PlayerData, rod: RodData) -> RodData:
	if rod == null:
		return null
	var out := rod.duplicate() as RodData
	out.zone_mult *= 1.0 + stat(data, &"fish_zone")
	out.bite_time_mult *= maxf(0.2, 1.0 - stat(data, &"bite_speed"))
	out.max_cast_tiles += stat(data, &"cast_range")
	out.perfect_window = minf(0.5, out.perfect_window * (1.0 + stat(data, &"perfect_window")))
	out.fish_speed_mult *= maxf(0.3, 1.0 - stat(data, &"fish_calm"))
	out.double_catch_chance = minf(1.0, out.double_catch_chance + stat(data, &"fish_double"))
	out.rare_weight_mult *= 1.0 + stat(data, &"rare_fish")
	out.legendary_weight_mult *= 1.0 + stat(data, &"rare_fish")
	return out


# ── Hasil panen, tebang, tambang ────────────────────────────────────

## Tambahan barang dari pohon/batu yang hancur (Forager kayu, Miner bijih/batubara/permata).
static func extra_drops(data: PlayerData, group: StringName, item_id: String, base_count: int) -> int:
	var extra := 0
	if group == &"choppable":
		if roll(data, &"wood_extra"):
			extra += 1
	elif group == &"mineable":
		if item_id == "coal" and roll(data, &"coal_double"):
			extra += base_count
		elif item_id.ends_with("_ore") and roll(data, &"ore_double"):
			extra += base_count
		elif is_gem(item_id) and roll(data, &"gem_double"):
			extra += base_count
	return extra

static func is_gem(item_id: String) -> bool:
	var cave_data := load("res://resources/cave/cave_data.tres") as CaveData
	var ore := cave_data.ore(item_id) if cave_data != null else null
	return ore != null and ore.is_gem

## EXP saat pohon/batu hancur.
static func on_resource_broken(data: PlayerData, group: StringName, item_id: String) -> void:
	if group == &"choppable":
		gain(data, &"forager", RULES.tree_exp)
	elif group == &"mineable":
		var item := GameState._resolve_item(item_id) if not item_id.is_empty() else null
		gain(data, &"miner", scaled_exp(item.sell_price if item != null else 0, RULES.rock_exp_per_price, RULES.rock_exp_min, RULES.rock_exp_max))

## Hari tumbuh pohon tanam/liar (Forest Whisperer: 2x lebih cepat).
static func tree_grow_days(days: int) -> int:
	return maxi(1, ceili(days / 2.0)) if household(&"tree_growth") > 0.0 else days


# ── Harga ───────────────────────────────────────────────────────────

## Harga beli per unit di toko (Merchant: diskon, grosir bibit kelipatan 10).
static func buy_price(data: PlayerData, item: ItemData, amount: int, unit_price: int) -> int:
	if item == null or unit_price <= 0:
		return unit_price
	var cut := stat(data, &"shop_discount")
	if item.category == ItemData.Category.SEED and amount >= 10:
		cut += stat(data, &"bulk_seed_discount")
	return maxi(1, roundi(unit_price * (1.0 - clampf(cut, 0.0, 0.9))))

## Harga jual per unit. shipping = true untuk Shipping Bin, false untuk jual langsung di toko.
static func sell_price(data: PlayerData, item: ItemData, shipping: bool) -> int:
	if item == null or item.sell_price <= 0:
		return 0
	var bonus := 0.0
	if item.category == ItemData.Category.FISH:
		bonus += stat(data, &"fish_sell")
	if shipping:
		bonus += stat(data, &"ship_bonus")
		if shared_prosperity():
			bonus += 0.1
	else:
		bonus += stat(data, &"shop_sell")
	return roundi(item.sell_price * (1.0 + bonus))

## Biaya upgrade tas dan rumah (Merchant Lv6-9).
static func facility_price(data: PlayerData, price: int) -> int:
	return roundi(price * (1.0 - clampf(stat(data, &"facility_discount"), 0.0, 0.9)))

## Bahan proyek Balai Nadi setelah Village Treasurer (uang tidak berubah).
static func balai_requirement(item_id: String, amount: int) -> int:
	if item_id == "money":
		return amount
	return maxi(1, ceili(amount * (1.0 - clampf(household(&"balai_discount"), 0.0, 0.9))))


# ── Buku riset (jalur hybrid) ───────────────────────────────────────

## Baca buku riset dari hotbar: EXP langsung ke role buku itu. true bila buku terpakai.
static func read_book(data: PlayerData, slot: int) -> bool:
	data = _data(data)
	if data == null or slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return false
	var item: ItemData = data.inventory[slot]["item"]
	var target := role(StringName(item.skill_book_role))
	if target == null or item.skill_book_exp <= 0:
		return false
	if data.skills.get_points(target.role_id) >= max_points():
		Notify.say("Keahlian %s sudah maksimal." % target.title)
		return false
	data.remove_item_at(slot, 1)
	Notify.say("Membaca %s: +%d EXP %s." % [item.display_name, item.skill_book_exp, target.title])
	gain(data, target.role_id, item.skill_book_exp)
	return true
