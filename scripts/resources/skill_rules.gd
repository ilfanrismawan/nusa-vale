class_name SkillRules
extends Resource

## Angka sistem Role & EXP (GDD 13). File: resources/skills/skill_rules.tres.

@export_group("Level")
## Total EXP untuk mencapai Lv1..Lv10.
@export var level_exp: PackedInt32Array = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]
## Level yang punya cabang pilihan A/B.
@export var choice_levels: PackedInt32Array = [5, 10]

@export_group("Farmer")
@export var hoe_exp: int = 1
@export var water_exp: int = 1
@export var plant_exp: int = 3
## EXP panen = harga jual hasil x pengali, dibatasi min/max.
@export var harvest_exp_per_price: float = 0.15
@export var harvest_exp_min: int = 4
@export var harvest_exp_max: int = 40

@export_group("Forager")
@export var forage_exp: int = 7
@export var tree_exp: int = 8
@export var weed_exp: int = 1
@export var dig_exp: int = 5
## Pengali bobot barang gali langka (bobot < 1) untuk Ancient Tracker.
@export var rare_dig_weight_mult: float = 4.0

@export_group("Fisher")
## EXP per tangkapan menurut rarity ikan (Umum..Legendaris).
@export var fish_exp: PackedInt32Array = [8, 12, 20, 35, 65]

@export_group("Combat")
@export var hit_exp: int = 1
@export var parry_exp: int = 4
## EXP bunuh = HP maks musuh x pengali, dibatasi min/max. Boss memakai boss_exp.
@export var kill_exp_per_hp: float = 0.35
@export var kill_exp_min: int = 3
@export var kill_exp_max: int = 65
@export var boss_exp: int = 200

@export_group("Miner")
## EXP batu pecah = harga jual hasil x pengali, dibatasi min/max.
@export var rock_exp_per_price: float = 0.2
@export var rock_exp_min: int = 3
@export var rock_exp_max: int = 35
@export var geode_exp: int = 6
## Peluang geoda/permata ganda untuk Geologist.
@export var geologist_double_chance: float = 0.5

@export_group("Merchant & Economist")
## G transaksi toko per 1 EXP Merchant.
@export var shop_gold_per_exp: float = 10.0
@export var shop_exp_max: int = 100
## G nilai kiriman Shipping Bin per 1 EXP Economist.
@export var ship_gold_per_exp: float = 15.0
## G nilai sumbangan Balai Nadi per 1 EXP Economist (barang dihitung dari harga jual).
@export var balai_gold_per_exp: float = 15.0
## Bunga harian Smart Investor: bagian uang bersama, dengan batas harian.
@export var interest_rate: float = 0.02
@export var interest_cap: int = 500

@export_group("Jalur hybrid")
## Token Talenta per paket Balai Nadi yang selesai (untuk penyumbang terakhir).
@export var balai_tokens: int = 1
