extends PanelContainer

## Tab "Keahlian" di buku inventori (GDD 13): level role, EXP, pohon perk, pilihan cabang A/B,
## dan Token Talenta. Gaya sama dengan inventory_crafting.gd.

const FONT = preload("res://assets/fonts/m5x7.ttf")
const INK := Color("50321f")
const MUTED := Color("8e785e")
const GREEN := Color("356444")
const GOLD := Color("9a6a12")
var inventory_ui: CanvasLayer
var _role: RoleData
var _role_buttons: Array[Button] = []
var _icon: TextureRect
var _title: Label
var _progress: ProgressBar
var _exp_label: Label
var _hint: Label
var _perks: VBoxContainer
var _tokens: Label
var _token_button: Button
var _team: Label
var _bound: PlayerSkills

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	theme = ui_theme
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var canvas := Control.new()
	add_child(canvas)
	var catalog := _paper(canvas, Rect2(0, 0, 150, 248), Color("ecd1a0"))
	var detail := _paper(canvas, Rect2(160, 0, 260, 248), Color("f3dfb8"))
	var heading := _label("KEAHLIAN", 20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(catalog, heading, Rect2(6, 4, 138, 22))
	var roles := SkillSystem.roles()
	for i in roles.size():
		var button := _button("")
		button.toggle_mode = true
		button.icon = roles[i].icon
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_select_role.bind(roles[i]))
		_place(catalog, button, Rect2(8, 28 + i * 23, 134, 21))
		_role_buttons.append(button)
	_tokens = _label("", 13)
	_place(catalog, _tokens, Rect2(10, 192, 132, 16))
	_team = _label("", 11)
	_team.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_team.max_lines_visible = 2
	_place(catalog, _team, Rect2(10, 210, 132, 34))
	var hero := _paper(detail, Rect2(8, 8, 244, 58), Color("dfba7d"))
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hero, _icon, Rect2(6, 6, 32, 32))
	_title = _label("", 18)
	_place(hero, _title, Rect2(44, 2, 196, 20))
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _style(Color("fff0ce"), Color("b5874f")))
	_progress.add_theme_stylebox_override("fill", _style(Color("51774a"), Color("426b43")))
	_place(hero, _progress, Rect2(44, 24, 194, 10))
	_exp_label = _label("", 12)
	_place(hero, _exp_label, Rect2(44, 36, 196, 16))
	_hint = _label("", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.max_lines_visible = 2
	_place(detail, _hint, Rect2(10, 68, 240, 28))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(detail, scroll, Rect2(8, 98, 246, 116))
	_perks = VBoxContainer.new()
	_perks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_perks.add_theme_constant_override("separation", 2)
	scroll.add_child(_perks)
	_token_button = _button("Pakai Token Talenta", true)
	_token_button.tooltip_text = "Tukar 1 Token Talenta dengan EXP sampai level berikutnya. Level aktif setelah tidur."
	_token_button.pressed.connect(_use_token)
	_place(detail, _token_button, Rect2(8, 218, 244, 24))
	_role = roles[0] if not roles.is_empty() else null
	refresh()

func _data() -> PlayerData:
	return inventory_ui.data if inventory_ui != null and inventory_ui.get("data") != null else GameState.current

func _bind(skills: PlayerSkills) -> void:
	if _bound == skills:
		return
	if _bound != null and _bound.changed.is_connected(refresh):
		_bound.changed.disconnect(refresh)
	_bound = skills
	if _bound != null:
		_bound.changed.connect(refresh)

func _select_role(role: RoleData) -> void:
	_role = role
	refresh()

func refresh() -> void:
	if not visible or not is_instance_valid(_perks) or _role == null:
		return
	var data := _data()
	if data == null:
		return
	var skills := data.skills
	_bind(skills)
	var roles := SkillSystem.roles()
	for i in _role_buttons.size():
		var role := roles[i]
		var mark := " ▲" if skills.ready_to_level(role.role_id) else (" !" if _has_pending(skills, role) else "")
		_role_buttons[i].text = "%s  Lv %d%s" % [role.title, skills.level(role.role_id), mark]
		_role_buttons[i].set_pressed_no_signal(role == _role)
	_tokens.text = "Token Talenta: %d" % skills.tokens
	_team.text = _team_text(data)
	_icon.texture = _role.icon
	var current := skills.level(_role.role_id)
	var earned := skills.earned_level(_role.role_id)
	_title.text = "%s  Lv %d" % [_role.title, current]
	var points := skills.get_points(_role.role_id)
	if earned >= SkillSystem.MAX_LEVEL:
		_progress.max_value = 1
		_progress.value = 1
		_exp_label.text = "%d EXP · Maksimal" % points + (" (tidur untuk naik)" if current < earned else "")
	else:
		var low := SkillSystem.points_for_level(earned)
		var high := SkillSystem.points_for_level(earned + 1)
		_progress.max_value = high - low
		_progress.value = points - low
		_exp_label.text = "%d / %d EXP" % [points, high] + ("  ·  Lv %d siap, tidur dulu" % earned if current < earned else "")
	_hint.text = _role.exp_hint
	_token_button.disabled = skills.tokens <= 0 or earned >= SkillSystem.MAX_LEVEL
	_fill_perks(skills)

func _fill_perks(skills: PlayerSkills) -> void:
	for child in _perks.get_children():
		_perks.remove_child(child)
		child.queue_free()
	var current := skills.level(_role.role_id)
	for at_level in range(1, SkillSystem.MAX_LEVEL + 1):
		if _role.has_choice(at_level):
			var picked := skills.choice(_role.role_id, at_level)
			var head := _label("Lv %d · Pilih satu cabang" % at_level, 13)
			head.add_theme_color_override("font_color", GOLD if current >= at_level and picked.is_empty() else INK)
			_perks.add_child(head)
			for branch in ["a", "b"]:
				for perk in _role.perks_at(at_level, branch):
					_perks.add_child(_perk_row(perk, branch.to_upper() + ". ", current >= at_level and (picked == branch), current >= at_level and picked.is_empty() and _role.branch_available(at_level, branch) and perk == _role.perks_at(at_level, branch)[0], at_level, branch))
		for perk in _role.perks_at(at_level, ""):
			_perks.add_child(_perk_row(perk, "Lv %d · " % at_level, current >= at_level, false, at_level, ""))

func _perk_row(perk: RolePerk, prefix: String, active: bool, can_pick: bool, at_level: int, branch: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var text := _label("%s%s%s\n%s" % [prefix, perk.title, " (Segera hadir)" if perk.coming_soon else "", perk.description], 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 160
	if perk.coming_soon:
		text.add_theme_color_override("font_color", MUTED)
	elif active:
		text.add_theme_color_override("font_color", GREEN)
	row.add_child(text)
	if can_pick:
		var pick := _button("Pilih")
		pick.add_theme_font_size_override("font_size", 16)
		pick.custom_minimum_size = Vector2(44, 20)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.pressed.connect(_choose.bind(at_level, branch))
		row.add_child(pick)
	elif active and not perk.coming_soon:
		var mark := _label("✓", 14)
		mark.add_theme_color_override("font_color", GREEN)
		row.add_child(mark)
	return row

func _choose(at_level: int, branch: String) -> void:
	var data := _data()
	if data != null and data.skills.choose(_role.role_id, at_level, branch):
		Notify.say("%s Lv %d: %s dipilih." % [_role.title, at_level, _role.branch_title(at_level, branch)])
	refresh()

func _use_token() -> void:
	var data := _data()
	if data != null and data.skills.use_token(_role.role_id):
		Notify.say("Token Talenta dipakai: %s siap naik ke Lv %d. Tidur untuk naik level." % [_role.title, data.skills.earned_level(_role.role_id)])
	refresh()

func _has_pending(skills: PlayerSkills, role: RoleData) -> bool:
	for row in skills.pending_choices():
		if row.role_id == role.role_id:
			return true
	return false

## Ringkasan rekan co-op: role tertinggi tiap pemain lain.
func _team_text(data: PlayerData) -> String:
	var parts: PackedStringArray = []
	for other in GameState.players:
		if other == null or other == data:
			continue
		var best: RoleData = null
		for role in SkillSystem.roles():
			if best == null or other.skills.level(role.role_id) > other.skills.level(best.role_id):
				best = role
		var who := other.player_name if not other.player_name.strip_edges().is_empty() else "P%d" % (other.index + 1)
		parts.append("%s: %s Lv %d" % [who, best.title, other.skills.level(best.role_id)] if best != null else who)
	return "Rekan: " + ", ".join(parts) if not parts.is_empty() else ""

func _place(parent: Control, child: Control, rect: Rect2) -> void:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(2)
	return style

func _paper(parent: Control, rect: Rect2, fill: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(fill, Color("b5874f")))
	_place(parent, panel, rect)
	return panel

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_pressed_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("8e785e"))
	button.add_theme_stylebox_override("normal", _style(Color("51774a") if primary else Color("eed5a6"), Color("916334")))
	button.add_theme_stylebox_override("hover", _style(Color("668e55") if primary else Color("ffe8b7"), Color("9e6a32")))
	button.add_theme_stylebox_override("pressed", _style(Color("426b43") if primary else Color("dcb374"), Color("674527")))
	button.add_theme_stylebox_override("disabled", _style(Color("d6c2a3"), Color("b19a78")))
	var focus := _style(Color.TRANSPARENT, Color("fff1cf"))
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button
