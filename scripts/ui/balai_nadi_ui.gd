class_name BalaiNadiUI
extends CanvasLayer

const FONT = preload("res://resources/ui/readable_font.tres")
var player: Player
var project_id := "balai_nadi_restoration"
var _opened := false
var _rows: Dictionary = {}
var _status: Label
var _selector: OptionButton
var _requirements: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.08, 0.06, 0.03, 0.65)
	add_child(dimmer)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 350)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", Color("50321f"))
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efd9b2")
	style.border_color = Color("997039")
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	_label(content, "BALAI NADI", 28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wings := _label(content, "Sayap Alam: permintaan aktif\nSayap Karya • Sayap Niaga • Sayap Pengetahuan: direncanakan")
	wings.add_theme_font_size_override("font_size", 18)
	_selector = OptionButton.new()
	content.add_child(_selector)
	for project in GameState.balai_nadi.definitions:
		_selector.add_item(project.display_name)
		if project.project_id == project_id:
			_selector.select(_selector.item_count - 1)
	_selector.item_selected.connect(_select_project)
	var description := _label(content, GameState.balai_nadi.definition(project_id).description)
	description.name = "Description"
	description.custom_minimum_size.x = 510
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var requirements := VBoxContainer.new()
	_requirements = requirements
	requirements.name = "Requirements"
	requirements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(requirements)
	_status = _label(content, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := player.ui_inventory._make_menu_button("Tutup (Esc)") as Button
	close.pressed.connect(close_menu)
	content.add_child(close)
	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(func(_amount): _refresh())
	GameState.balai_nadi.state_changed.connect(_refresh)
	_opened = true
	Coop.set_menu_open(player, true)
	_build_rows(requirements)
	close.grab_focus()

func _label(parent: Node, text: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _select_project(index: int) -> void:
	project_id = GameState.balai_nadi.definitions[index].project_id
	var content := _selector.get_parent()
	content.get_node("Description").text = GameState.balai_nadi.definition(project_id).description
	_build_rows(_requirements)

func _build_rows(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	_rows.clear()
	var project := GameState.balai_nadi.definition(project_id)
	for item_id in project.requirements:
		var item := GameState._resolve_item(item_id) if item_id != "money" else null
		var row := VBoxContainer.new()
		parent.add_child(row)
		var heading := HBoxContainer.new()
		row.add_child(heading)
		var label := _label(heading, "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := player.ui_inventory._make_menu_button("Kontribusi") as Button
		if item != null:
			button.icon = item.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 18)
		button.pressed.connect(_contribute.bind(item_id))
		heading.add_child(button)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 10
		bar.show_percentage = false
		bar.max_value = project.requirements[item_id]
		row.add_child(bar)
		_rows[item_id] = {"label": label, "button": button, "bar": bar}
	_refresh()

func _refresh() -> void:
	if not _opened:
		return
	var manager := GameState.balai_nadi
	var project := manager.definition(project_id)
	for item_id in _rows:
		var row: Dictionary = _rows[item_id]
		var amount := manager.contributed(project_id, item_id)
		var left := manager.remaining(project_id, item_id)
		var available := manager.available_amount(player.data, item_id)
		var name_text: String = "Dana bersama" if item_id == "money" else GameState._resolve_item(item_id).display_name
		row.label.text = "%s  %d / %d\nSisa: %d   •   Tersedia: %d" % [name_text, amount, project.requirements[item_id], left, available]
		row.bar.value = amount
		row.button.disabled = left <= 0 or available <= 0 or manager.completed(project_id)
		row.button.text = "Terpenuhi" if left <= 0 else "Kontribusi %d" % mini(left, available)
	_status.text = "Tahap: %s\n%s" % [manager.restoration_stage(), project.completion_message if manager.completed(project_id) else "Kontribusi bertahap; bahan dan dana tersimpan otomatis."]

func _contribute(item_id: String) -> void:
	if _opened:
		GameState.balai_nadi.contribute(player.data, project_id, item_id)
		_refresh()

func _input(event: InputEvent) -> void:
	if not _opened or not Coop.accepts_event(player, event):
		return
	if player.input.is_event(event, &"ui_cancel") or player.input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		close_menu()
	elif event is InputEventMouseButton and not player.input.uses_mouse():
		get_viewport().set_input_as_handled()

func close_menu() -> void:
	if not _opened:
		return
	_opened = false
	set_process_input(false)
	hide()
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if _opened and is_instance_valid(player):
		Coop.set_menu_open(player, false)
