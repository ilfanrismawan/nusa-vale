class_name PlayerSkills
extends RefCounted

## Progres Role & EXP milik satu pemain (GDD 13, co-op: tiap pemain punya sendiri).
## EXP bertambah langsung saat beraksi; level baru (dan perk-nya) aktif saat tidur,
## lalu cabang A/B di Lv5 dan Lv10 dipilih di layar rekap. Disimpan di save sebagai "skills".

signal changed

## role_id -> total EXP.
var points: Dictionary = {}
## role_id -> level aktif (naik saat tidur).
var levels: Dictionary = {}
## "role_id:level" -> "a" / "b".
var choices: Dictionary = {}
## Token Talenta (Universal Skill Point): ditukar dengan satu level di role pilihan.
var tokens: int = 0
## EXP pecahan yang belum genap 1 (tidak disimpan).
var _remainder: Dictionary = {}
## Level siap-naik yang sudah diumumkan, supaya notifikasi tidak berulang.
var _announced: Dictionary = {}
var _stats: Dictionary = {}
var _stats_dirty := true


func reset() -> void:
	points.clear()
	levels.clear()
	choices.clear()
	tokens = 0
	_remainder.clear()
	_announced.clear()
	_mark_dirty()


func get_points(role_id: StringName) -> int:
	return int(points.get(String(role_id), 0))

## Level yang sudah aktif.
func level(role_id: StringName) -> int:
	return int(levels.get(String(role_id), 0))

## Level menurut EXP (bisa lebih tinggi dari level aktif sampai pemain tidur).
func earned_level(role_id: StringName) -> int:
	return SkillSystem.level_for_points(get_points(role_id))

func ready_to_level(role_id: StringName) -> bool:
	return earned_level(role_id) > level(role_id)

## Tambah EXP. Mengembalikan level baru yang baru saja dicapai (0 bila belum naik).
func add_points(role_id: StringName, amount: float) -> int:
	if SkillSystem.role(role_id) == null or amount <= 0.0 or not is_finite(amount):
		return 0
	var key := String(role_id)
	var cap := SkillSystem.max_points()
	var before := earned_level(role_id)
	var total := minf(float(_remainder.get(key, 0.0)) + amount, float(cap))
	var whole := floori(total)
	_remainder[key] = total - whole
	if whole <= 0:
		return 0
	points[key] = mini(cap, get_points(role_id) + whole)
	var after := earned_level(role_id)
	if after > before and int(_announced.get(key, 0)) < after:
		_announced[key] = after
		changed.emit()
		return after
	changed.emit()
	return 0

## Naikkan level aktif ke level EXP (dipanggil saat hari berganti).
## Mengembalikan [{role_id, from, to}].
func apply_levels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for role in SkillSystem.roles():
		var key := String(role.role_id)
		var from := level(role.role_id)
		var to := earned_level(role.role_id)
		if to > from:
			levels[key] = to
			out.append({"role_id": role.role_id, "from": from, "to": to})
	_announced.clear()
	if not out.is_empty():
		_mark_dirty()
	return out

func choice(role_id: StringName, at_level: int) -> String:
	return str(choices.get("%s:%d" % [role_id, at_level], ""))

## Cabang A/B yang levelnya sudah aktif tetapi belum dipilih: [{role_id, level}].
func pending_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for role in SkillSystem.roles():
		for at_level in SkillSystem.RULES.choice_levels:
			if level(role.role_id) >= at_level and role.has_choice(at_level) and choice(role.role_id, at_level).is_empty() \
						and (role.branch_available(at_level, "a") or role.branch_available(at_level, "b")):
				out.append({"role_id": role.role_id, "level": at_level})
	return out

func choose(role_id: StringName, at_level: int, branch: String) -> bool:
	var role := SkillSystem.role(role_id)
	if role == null or not branch in ["a", "b"] or level(role_id) < at_level or not role.has_choice(at_level):
		return false
	if not choice(role_id, at_level).is_empty() or not role.branch_available(at_level, branch):
		return false
	choices["%s:%d" % [role_id, at_level]] = branch
	_mark_dirty()
	return true

## Tukar satu Token Talenta dengan EXP sampai ambang level berikutnya (aktif setelah tidur).
func use_token(role_id: StringName) -> bool:
	if tokens <= 0 or SkillSystem.role(role_id) == null:
		return false
	var next := earned_level(role_id) + 1
	if next > SkillSystem.MAX_LEVEL:
		return false
	tokens -= 1
	points[String(role_id)] = SkillSystem.points_for_level(next)
	_announced[String(role_id)] = next
	changed.emit()
	return true

func is_active(role: RoleData, perk: RolePerk) -> bool:
	if perk == null or perk.coming_soon or level(role.role_id) < perk.level:
		return false
	return perk.branch.is_empty() or choice(role.role_id, perk.level) == perk.branch

## Jumlah nilai stat dari semua perk aktif.
func stat(key: StringName) -> float:
	if _stats_dirty:
		_stats.clear()
		for role in SkillSystem.roles():
			for perk in role.perks:
				if not is_active(role, perk):
					continue
				for effect in perk.effects:
					_stats[effect] = float(_stats.get(effect, 0.0)) + float(perk.effects[effect])
		_stats_dirty = false
	return float(_stats.get(key, 0.0))

func _mark_dirty() -> void:
	_stats_dirty = true
	changed.emit()


# ── Save ────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {"points": points.duplicate(), "levels": levels.duplicate(), "choices": choices.duplicate(), "tokens": tokens}

## Save lama tanpa "skills": semua role Lv0. Nilai rusak diabaikan.
func load_dict(value: Variant) -> void:
	reset()
	if not value is Dictionary:
		return
	var saved_points: Variant = value.get("points", {})
	var saved_levels: Variant = value.get("levels", {})
	var saved_choices: Variant = value.get("choices", {})
	for role in SkillSystem.roles():
		var key := String(role.role_id)
		if saved_points is Dictionary and _is_count(saved_points.get(key)):
			points[key] = clampi(int(saved_points[key]), 0, SkillSystem.max_points())
		var earned := earned_level(role.role_id)
		if saved_levels is Dictionary and _is_count(saved_levels.get(key)):
			levels[key] = clampi(int(saved_levels[key]), 0, earned)
		if not saved_choices is Dictionary:
			continue
		for at_level in SkillSystem.RULES.choice_levels:
			var picked: Variant = saved_choices.get("%s:%d" % [key, at_level], "")
			if picked is String and picked in ["a", "b"] and level(role.role_id) >= at_level and role.has_choice(at_level):
				choices["%s:%d" % [key, at_level]] = picked
	var saved_tokens: Variant = value.get("tokens", 0)
	tokens = clampi(int(saved_tokens), 0, 999) if _is_count(saved_tokens) else 0
	_mark_dirty()

static func _is_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0
