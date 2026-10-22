class_name RoleData
extends Resource

## Satu role keahlian (GDD 13.2): Farmer, Forager, Fisher, Combat, Miner, Merchant, Economist.
## Level 1-10 per pemain; ambang EXP ada di SkillRules (resources/skills/skill_rules.tres).

@export var role_id: StringName = &""
## Nama Inggris (konvensi display_name).
@export var display_name: String = ""
## Nama Indonesia yang tampil di UI, mis. "Petani".
@export var title: String = ""
@export_multiline var exp_hint: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var perks: Array[RolePerk] = []

## Perk di level ini. branch "" = perk otomatis, "a"/"b" = cabang pilihan.
func perks_at(level: int, branch: String = "") -> Array[RolePerk]:
	var out: Array[RolePerk] = []
	for perk in perks:
		if perk != null and perk.level == level and perk.branch == branch:
			out.append(perk)
	return out

## true bila level ini punya cabang pilihan A/B.
func has_choice(level: int) -> bool:
	return not perks_at(level, "a").is_empty() and not perks_at(level, "b").is_empty()

## Judul cabang, mis. "Agronomist".
func branch_title(level: int, branch: String) -> String:
	var list := perks_at(level, branch)
	return list[0].title if not list.is_empty() else branch.to_upper()

## true bila cabang ini punya minimal satu perk yang sudah bisa dipakai (bukan "Segera hadir").
func branch_available(level: int, branch: String) -> bool:
	for perk in perks_at(level, branch):
		if not perk.coming_soon:
			return true
	return false
