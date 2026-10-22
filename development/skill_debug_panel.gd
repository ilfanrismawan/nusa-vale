extends VBoxContainer

const Actions = preload("res://development/skill_debug_actions.gd")
var _player := OptionButton.new()
var _role := OptionButton.new()
var _amount := SpinBox.new()
var _level := SpinBox.new()
var _status := Label.new()
var _elapsed := 0.0

func _ready() -> void:
	var heading := Label.new()
	heading.text = "SKILL / ROLE / EXP / PERKS"
	add_child(heading)
	for index in GameState.players.size():
		_player.add_item("P%d" % (index + 1), index)
	add_child(_player)
	for role in SkillSystem.roles():
		_role.add_item(role.title)
	add_child(_role)
	_amount.min_value = 1
	_amount.max_value = SkillSystem.max_points()
	_amount.value = 100
	add_child(_amount)
	_button("Tambah EXP (aktif setelah tidur)", func(): Actions.add_exp(_data(), _id(), int(_amount.value)))
	_level.min_value = 0
	_level.max_value = SkillSystem.MAX_LEVEL
	_level.value = 5
	add_child(_level)
	_button("Set EXP ke level pilihan (tunggu tidur)", func(): Actions.set_level(_data(), _id(), int(_level.value), false))
	_button("Set level & perk langsung aktif", func(): Actions.set_level(_data(), _id(), int(_level.value), true))
	_button("Reset role pilihan ke Lv0", func(): Actions.set_level(_data(), _id(), 0, true))
	for at_level in SkillSystem.RULES.choice_levels:
		for branch in ["a", "b", ""]:
			_button("Perk Lv%d: %s" % [at_level, branch.to_upper() if branch != "" else "hapus pilihan"], _branch.bind(at_level, branch))
	_button("Tambah 10 Token Talenta", func(): Actions.add_tokens(_data(), 10))
	_button("Tukar 1 token ke role pilihan", func():
		if _data() != null:
			_data().skills.use_token(_id()))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 260
	add_child(_status)
	_update_status()

func _data() -> PlayerData:
	var index := _player.get_selected_id()
	return GameState.players[index] if index >= 0 and index < GameState.players.size() else null

func _id() -> StringName:
	return SkillSystem.roles()[_role.selected].role_id

func _button(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(func():
		action.call()
		_update_status())
	add_child(button)

func _branch(at_level: int, branch: String) -> void:
	if not Actions.set_branch(_data(), _id(), at_level, branch):
		Notify.say("[DEBUG] Aktifkan level perk dulu. Cabang Segera Hadir tidak dapat dipilih.")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25 and is_visible_in_tree():
		_elapsed = 0.0
		_update_status()

func _update_status() -> void:
	var data := _data()
	if data == null:
		_status.text = "Pemain belum tersedia."
		return
	var role := SkillSystem.role(_id())
	var skills := data.skills
	_status.text = "P%d | %s | EXP %d\nLevel aktif %d / EXP Lv%d | Token %d" % [data.index + 1, role.title, skills.get_points(_id()), skills.level(_id()), skills.earned_level(_id()), skills.tokens]
	for at_level in SkillSystem.RULES.choice_levels:
		_status.text += "\nLv%d: %s / %s | pilihan: %s" % [at_level, role.branch_title(at_level, "a"), role.branch_title(at_level, "b"), skills.choice(_id(), at_level)]
	for perk in role.perks:
		if skills.is_active(role, perk):
			_status.text += "\nAktif: %s" % perk.title
