class_name Combat
extends RefCounted

## Aturan combat bersama (Phase 4B-1): rumus damage, gaya senjata, amunisi, target.
## Angka gaya senjata ada di resources/combat/<jenis>.tres (WeaponStyle).

## Target serangan pemain: node di grup ini yang punya take_hit(attack, source, knockback).
const DAMAGEABLE_GROUP := &"damageable"
const DEFEAT_RULES: DefeatRules = preload("res://resources/combat/defeat_rules.tres")
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
