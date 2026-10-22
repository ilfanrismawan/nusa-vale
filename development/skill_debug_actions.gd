extends RefCounted
## Development-only mutations; never referenced by gameplay scripts.
static func valid(data: PlayerData, role_id: StringName) -> bool:
	return data != null and data.skills != null and SkillSystem.role(role_id) != null

static func add_exp(data: PlayerData, role_id: StringName, amount: int) -> void:
	if valid(data, role_id):
		SkillSystem.gain(data, role_id, clampi(amount, 1, SkillSystem.max_points()))

static func set_level(data: PlayerData, role_id: StringName, value: int, activate: bool) -> void:
	if not valid(data, role_id):
		return
	var saved := data.skills.to_dict()
	var key := String(role_id)
	var target := clampi(value, 0, SkillSystem.MAX_LEVEL)
	saved.points[key] = SkillSystem.points_for_level(target)
	saved.levels[key] = target if activate else mini(data.skills.level(role_id), target)
	for at_level in SkillSystem.RULES.choice_levels:
		if int(saved.levels[key]) < at_level:
			saved.choices.erase("%s:%d" % [key, at_level])
	data.skills.load_dict(saved)
	refresh_stats(data)

static func set_branch(data: PlayerData, role_id: StringName, at_level: int, branch: String) -> bool:
	if not valid(data, role_id):
		return false
	var role := SkillSystem.role(role_id)
	if not at_level in SkillSystem.RULES.choice_levels or not role.has_choice(at_level) or data.skills.level(role_id) < at_level:
		return false
	if branch != "" and (not branch in ["a", "b"] or not role.branch_available(at_level, branch)):
		return false
	var saved := data.skills.to_dict()
	saved.choices.erase("%s:%d" % [role_id, at_level])
	data.skills.load_dict(saved)
	if branch != "":
		data.skills.choose(role_id, at_level, branch)
	refresh_stats(data)
	return true

static func add_tokens(data: PlayerData, amount: int) -> void:
	if data == null or data.skills == null:
		return
	data.skills.tokens = clampi(data.skills.tokens + amount, 0, 999)
	data.skills.changed.emit()

static func refresh_stats(data: PlayerData) -> void:
	data.hp = mini(data.hp, data.max_hp)
	data.hp_changed.emit(data.hp, data.max_hp)
	data._changed()
