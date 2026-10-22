extends Control

@export var embedded := false
@export var design_size := Vector2(420, 224)
@export var node_scene: PackedScene = preload("res://scenes/ui/skill_tree_node.tscn")
@export var role_scene: PackedScene = preload("res://scenes/ui/skill_tree_role.tscn")
@export var connection_scene: PackedScene = preload("res://scenes/ui/skill_tree_connection.tscn")
@export var active_color := Color("dfb86c")
@export var locked_color := Color("767b72")
var inventory_ui: CanvasLayer
var player: Player
var _role: RoleData
var _page := 0
var _selected := ""
var _entries: Dictionary = {}
var _buttons: Dictionary = {}
var _bound: PlayerSkills
var _closed := false

func _data() -> PlayerData:
	if is_instance_valid(inventory_ui):
		return inventory_ui.data
	return player.data if is_instance_valid(player) else GameState.current

func _ready() -> void:
	if embedded:
		inventory_ui = get_parent().get_parent().get_parent()
		$Backdrop.hide()
		%Close.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Close.pressed.connect(close_menu)
	%Previous.pressed.connect(_change_page.bind(-1))
	%Next.pressed.connect(_change_page.bind(1))
	%Confirm.pressed.connect(_confirm)
	%UseToken.pressed.connect(_use_token)
	get_viewport().size_changed.connect(_resize)
	if is_instance_valid(inventory_ui):
		inventory_ui.visibility_changed.connect(_inventory_visibility_changed)
	var roles := SkillSystem.roles()
	for role in roles:
		var button := role_scene.instantiate() as Button
		%Roles.add_child(button)
		button.icon = role.icon
		button.text = role.title
		button.tooltip_text = role.title
		button.set_meta("role", role)
		button.pressed.connect(_select_role.bind(role))
	if not roles.is_empty():
		_select_role(roles[0])
	_resize()
	if not embedded:
		%Close.grab_focus()

func _resize() -> void:
	var view := size if embedded else get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _select_role(role: RoleData) -> void:
	_role = role
	_page = 0
	_selected = ""
	_build_tree()
	refresh()

func _change_page(direction: int) -> void:
	_page = posmod(_page + direction, ceili(float(SkillSystem.MAX_LEVEL) / 5.0))
	_selected = ""
	_build_tree()
	refresh()

func _build_tree() -> void:
	for parent in [%Nodes, %Lines]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_entries.clear()
	_buttons.clear()
	if _role == null:
		return
	var first := _page * 5 + 1
	for at_level in range(first, mini(first + 5, SkillSystem.MAX_LEVEL + 1)):
		for branch in ["", "a", "b"]:
			var perks := _role.perks_at(at_level, branch)
			if perks.is_empty():
				continue
			var key := "%d:%s" % [at_level, branch]
			var button := node_scene.instantiate() as Button
			%Nodes.add_child(button)
			var tier_spacing: float = %TierStep.position.x - %TierOrigin.position.x
			var branch_spacing: float = %BranchStep.position.y - %TierOrigin.position.y
			var offset := -branch_spacing if branch == "a" else branch_spacing if branch == "b" else 0.0
			button.position = perks[0].ui_position if perks[0].ui_position.x >= 0 and perks[0].ui_position.y >= 0 else %TierOrigin.position + Vector2((at_level - first) * tier_spacing, offset)
			button.get_node("Icon").texture = perks[0].ui_icon if perks[0].ui_icon != null else _role.icon
			button.get_node("Level").text = "Lv %d%s" % [at_level, " " + branch.to_upper() if not branch.is_empty() else ""]
			button.pressed.connect(_select_node.bind(key))
			button.focus_entered.connect(_select_node.bind(key))
			_entries[key] = {"level": at_level, "branch": branch, "perks": perks}
			_buttons[key] = button
	if _selected.is_empty() and not _entries.is_empty():
		_selected = _entries.keys()[0]
	_draw_connections()

func _draw_connections() -> void:
	for key in _entries:
		var entry: Dictionary = _entries[key]
		var previous := int(entry.level) - 1
		while previous > _page * 5:
			var found := false
			for source in _entries:
				if int(_entries[source].level) != previous:
					continue
				var line := connection_scene.instantiate() as Line2D
				line.default_color = locked_color * Color(1, 1, 1, 0.45)
				line.points = PackedVector2Array([_buttons[source].position + _buttons[source].size * 0.5, _buttons[key].position + _buttons[key].size * 0.5])
				%Lines.add_child(line)
				found = true
			if found:
				break
			previous -= 1

func _select_node(key: String) -> void:
	_selected = key
	refresh()

func refresh() -> void:
	var data := _data()
	if data == null or _role == null:
		return
	var skills := data.skills
	if _bound != skills:
		if _bound != null and _bound.changed.is_connected(refresh):
			_bound.changed.disconnect(refresh)
		_bound = skills
		_bound.changed.connect(refresh)
	var current := skills.level(_role.role_id)
	var earned := skills.earned_level(_role.role_id)
	%RoleTitle.text = "%s · Lv %d" % [_role.title, current]
	%Owner.text = "%s · Token Talenta: %d" % [data.player_name if not data.player_name.is_empty() else "P%d" % (data.index + 1), skills.tokens]
	%Exp.text = "%d EXP · Lv %d siap, tidur untuk mengaktifkan" % [skills.get_points(_role.role_id), earned] if earned > current else "%d EXP · Level aktif %d" % [skills.get_points(_role.role_id), current]
	var low := SkillSystem.points_for_level(earned)
	var high := SkillSystem.points_for_level(mini(earned + 1, SkillSystem.MAX_LEVEL))
	%Progress.max_value = maxi(1, high - low)
	%Progress.value = skills.get_points(_role.role_id) - low if earned < SkillSystem.MAX_LEVEL else %Progress.max_value
	%Page.text = "Lv %d–%d  ·  %d / %d" % [_page * 5 + 1, mini(_page * 5 + 5, SkillSystem.MAX_LEVEL), _page + 1, ceili(float(SkillSystem.MAX_LEVEL) / 5.0)]
	%UseToken.disabled = skills.tokens <= 0 or earned >= SkillSystem.MAX_LEVEL
	for button in %Roles.get_children():
		button.set_pressed_no_signal(button.get_meta("role") == _role)
	for key in _entries:
		var entry: Dictionary = _entries[key]
		var active := false
		for perk in entry.perks:
			active = active or skills.is_active(_role, perk)
		_buttons[key].get_node("Icon").modulate = active_color if active else locked_color
		_buttons[key].get_node("State").text = "✓" if active else "◇" if current >= int(entry.level) else "·"
		_buttons[key].set_pressed_no_signal(key == _selected)
	_update_detail(skills)

func _update_detail(skills: PlayerSkills) -> void:
	%Confirm.disabled = true
	if not _entries.has(_selected):
		return
	var entry: Dictionary = _entries[_selected]
	var perks: Array = entry.perks
	var at_level := int(entry.level)
	var branch := str(entry.branch)
	%DetailIcon.texture = perks[0].ui_icon if perks[0].ui_icon != null else _role.icon
	%SkillTitle.text = _role.branch_title(at_level, branch) if not branch.is_empty() else perks[0].title
	var lines := PackedStringArray()
	for perk in perks:
		lines.append("%s\n%s%s" % [perk.title, perk.description, "\nSegera hadir — belum memberikan efek." if perk.coming_soon else ""])
	%Description.text = "\n\n".join(lines)
	var active_level := skills.level(_role.role_id)
	var picked := skills.choice(_role.role_id, at_level)
	var selectable := not branch.is_empty() and active_level >= at_level and picked.is_empty() and _role.branch_available(at_level, branch)
	%Confirm.disabled = not selectable
	%Confirm.text = "Pilih Cabang " + branch.to_upper() if selectable else "Cabang Terpilih" if not branch.is_empty() and picked == branch else "Aktif Otomatis" if branch.is_empty() and active_level >= at_level else "Belum Tersedia"
	%Requirement.text = "Memerlukan %s Lv %d aktif." % [_role.title, at_level]
	if not branch.is_empty() and not picked.is_empty():
		%Requirement.text += "\nCabang %s sudah dipilih. Pilihan ini permanen." % picked.to_upper()
	elif not branch.is_empty():
		%Requirement.text += "\nPilihan permanen: pilih satu cabang. Periksa manfaat sebelum konfirmasi."
	else:
		%Requirement.text += "\nTerbuka otomatis setelah level aktif, tanpa biaya token."
	%EarnHint.text = _role.exp_hint

func _confirm() -> void:
	if %Confirm.disabled or not _entries.has(_selected):
		return
	var entry: Dictionary = _entries[_selected]
	if _data().skills.choose(_role.role_id, entry.level, entry.branch):
		Notify.say("%s: %s dipilih." % [_role.title, _role.branch_title(entry.level, entry.branch)])
	refresh()

func _use_token() -> void:
	if _data().skills.use_token(_role.role_id):
		Notify.say("Token dipakai. Tidur untuk mengaktifkan kenaikan level %s." % _role.title)
	refresh()

func _input(event: InputEvent) -> void:
	if _closed or embedded or not is_visible_in_tree():
		return
	var input: PlayerInput = inventory_ui._owner_input() if is_instance_valid(inventory_ui) else player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel") or input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		close_menu()

func close_menu() -> void:
	if embedded:
		hide()
		return
	if _closed:
		return
	_closed = true
	hide()
	if is_instance_valid(inventory_ui) and inventory_ui.visible:
		var button: Control = inventory_ui._menu_buttons.get("Keahlian")
		if is_instance_valid(button):
			button.grab_focus()
	queue_free()

func _inventory_visibility_changed() -> void:
	if is_instance_valid(inventory_ui) and not inventory_ui.visible:
		close_menu()

func _exit_tree() -> void:
	if _bound != null and _bound.changed.is_connected(refresh):
		_bound.changed.disconnect(refresh)
