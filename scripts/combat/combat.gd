class_name Combat
extends RefCounted

## Aturan combat bersama (Phase 4B-1): rumus damage, gaya senjata, amunisi, target.
## Angka gaya senjata ada di resources/combat/<jenis>.tres (WeaponStyle).

## Target serangan pemain: node di grup ini yang punya take_hit(attack, source, knockback).
const DAMAGEABLE_GROUP := &"damageable"
## Pemain yang bisa dikejar dan diserang AI musuh.
const PLAYER_GROUP := &"combat_players"
const DEFEAT_RULES: DefeatRules = preload("res://resources/combat/defeat_rules.tres")
## Aturan soulslike (GDD 8.2-A): stamina tempur, roll, block/parry, poise.
const RULES: CombatRules = preload("res://resources/combat/combat_rules.tres")
const STYLES := {
	ItemData.WeaponType.SWORD: preload("res://resources/combat/sword.tres"),
	ItemData.WeaponType.BOW: preload("res://resources/combat/bow.tres"),
	ItemData.WeaponType.STAFF: preload("res://resources/combat/staff.tres"),
}

## GDD 8.1: damage = ATK - DEF, minimal 1 supaya setiap serangan tetap terasa.
static func damage_after_defense(attack: int, defense: int) -> int:
	return maxi(1, attack - maxi(0, defense))

## true untuk pedang, busur, dan tongkat sihir (bukan anak panah).
static func is_weapon(item: ItemData) -> bool:
	return item != null and STYLES.has(item.weapon_type)

static func style_for(item: ItemData) -> WeaponStyle:
	if not is_weapon(item):
		return null
	return STYLES[item.weapon_type]

## Anak panah terkuat di tas (ATK tertinggi), atau -1 bila tidak ada.
static func best_arrow_slot(data: PlayerData) -> int:
	var best := -1
	var best_attack := -1
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry == null:
			continue
		var item: ItemData = entry["item"]
		if item.weapon_type == ItemData.WeaponType.ARROW and item.attack_bonus > best_attack:
			best = slot
			best_attack = item.attack_bonus
	return best

## DEF pemain dari helm, zirah, celana, dan sepatu.
static func player_defense(data: PlayerData) -> int:
	return data.equipment_stats().y

static func is_damageable(node: Node) -> bool:
	return node != null and node.is_in_group(DAMAGEABLE_GROUP) and node.has_method("take_hit")

## Collider atau induknya yang bisa diserang.
static func find_damageable(node: Node) -> Node:
	while node != null:
		if is_damageable(node):
			return node
		if node is Player:
			return null
		node = node.get_parent()
	return null

## Beban perlengkapan (GDD 8.2-A2): berat per slot x pengali tier bahan (CombatRules).
static func equip_load(data: PlayerData) -> float:
	var total := 0.0
	for key in data.equipment:
		var item: Variant = data.equipment[key]
		if item is ItemData:
			total += float(RULES.slot_weight.get(key, 0.0)) * CombatRules.pick(RULES.tier_weight, int(item.equipment_tier), 1.0)
	return total

static func equip_load_ratio(data: PlayerData) -> float:
	return equip_load(data) / maxf(1.0, RULES.load_capacity)

## 0 = Fast Roll, 1 = Medium Roll, 2 = Heavy Fat-Roll.
static func roll_class(data: PlayerData) -> int:
	return RULES.roll_class(equip_load_ratio(data))

## Info tambahan pukulan pemain yang sedang diproses take_hit (pola sama dengan
## CombatJuice.heavy_hit): kikisan poise, abaikan DEF (weapon art), dan kritis (riposte).
static var hit_poise := -1.0
static var hit_ignores_defense := false
static var hit_critical := false

## Pukul target memakai take_hit(attack, source, knockback) biasa, plus info soulslike di atas.
static func hit(target: Node, attack: int, source: Node, knockback: Vector2, poise: float = -1.0, ignore_defense: bool = false, critical: bool = false, heavy: bool = false, fx: WeaponTierFx = null) -> bool:
	hit_poise = poise
	hit_ignores_defense = ignore_defense
	hit_critical = critical
	CombatJuice.heavy_hit = heavy or critical
	CombatJuice.hit_fx = fx
	var landed: bool = target.take_hit(attack, source, knockback)
	if landed and fx != null and fx.has_status():
		apply_tier_status(target, fx, attack, source)
	if landed and source is Player and target is Enemy:
		_combat_exp(source as Player, target as Enemy)
	hit_poise = -1.0
	hit_ignores_defense = false
	hit_critical = false
	CombatJuice.heavy_hit = false
	CombatJuice.hit_fx = null
	return landed

## Role Combat (GDD 13): EXP per pukulan masuk dan per musuh tumbang; Soulforged memulihkan.
static func _combat_exp(player: Player, enemy: Enemy) -> void:
	SkillSystem.gain(player.data, &"combat", SkillSystem.RULES.hit_exp)
	if not enemy.is_dead():
		return
	var rules := SkillSystem.RULES
	var reward := rules.boss_exp if enemy is Boss else SkillSystem.scaled_exp(enemy.data.max_hp if enemy.data != null else 0, rules.kill_exp_per_hp, rules.kill_exp_min, rules.kill_exp_max)
	SkillSystem.gain(player.data, &"combat", reward)
	var heal := roundi(SkillSystem.stat(player.data, &"kill_heal"))
	if heal > 0 and not player.is_defeated:
		player.data.restore_hp(heal)
		if player.combat != null:
			player.combat.restore(float(heal))
		CombatJuice.damage_number("+%d" % heal, player.global_position + Vector2(0, -18), Color(0.6, 1.0, 0.6))

## Efek status tier senjata (GDD 8.2, v3.3) setelah pukulan masuk. Terbakar/dingin/api gelap
## menempel di musuh (Enemy.apply_status); serap jiwa dan berkah peri memulihkan penyerangnya.
static func apply_tier_status(target: Node, fx: WeaponTierFx, attack: int, source: Node) -> void:
	match fx.status:
		WeaponTierFx.Status.BURN, WeaponTierFx.Status.CHILL, WeaponTierFx.Status.DARK_FIRE:
			if target.has_method("apply_status") and randf() < fx.status_chance:
				target.apply_status(fx, attack)
		WeaponTierFx.Status.LIFESTEAL:
			var player := source as Player
			if player != null and not player.is_defeated and player.data.hp < player.data.max_hp and randf() < fx.status_chance:
				var heal := maxi(1, roundi(attack * fx.lifesteal_ratio))
				player.data.restore_hp(heal)
				CombatJuice.damage_number("+%d" % heal, player.global_position + Vector2(0, -18), fx.color_alt.lerp(Color(0.6, 1.0, 0.6), 0.5))
		WeaponTierFx.Status.STAMINA:
			var player := source as Player
			if player != null and player.combat != null and randf() < fx.status_chance:
				player.combat.restore(float(fx.stamina_gain))
