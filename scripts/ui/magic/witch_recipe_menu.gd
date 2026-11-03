extends CanvasLayer

## Daftar resep stasiun Menara Penyihir (kuali/meja jimat). Pilih resep -> sinyal chosen.
## Mouse: klik baris. Gamepad/keyboard: atas/bawah + A. B/Esc tutup.

signal chosen(recipe: CraftingRecipe)

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

var player: Player
var catalog: CraftingCatalog
var title := "Resep"
var subtitle := ""
## Opsional: judul baris pengganti nama item hasil (mis. nama pesona di Altar Enchant).
var row_titles: PackedStringArray = []

var _rows: Array[PanelContainer] = []
var _index := 0
var _closed := false


func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Coop.set_menu_open(player, true)
	_select(0)


func _input_owner() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()


func _build() -> void:
	var root := Control.new()
	root.theme = ServiceTheme.make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.45)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and Coop.accepts_event(player, event):
			close())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	box.add_child(head)
	if not subtitle.is_empty():
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 13)
		box.add_child(sub)
	var data := player.data if is_instance_valid(player) else GameState.p1()
	for recipe in catalog.recipes:
		_rows.append(_row(box, recipe, data))
	var foot := Label.new()
	foot.text = "Klik / A: racik · B / Esc: tutup"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 12)
	box.add_child(foot)


func _row(parent: Control, recipe: CraftingRecipe, data: PlayerData) -> PanelContainer:
	var output := GameState._resolve_item(recipe.output_item_id)
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.28, 0.55, 0.0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", style)
	parent.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var icon := TextureRect.new()
	icon.texture = output.icon if output != null else null
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name_label := Label.new()
	name_label.text = output.display_name if output != null else recipe.output_item_id
	if _rows.size() < row_titles.size():
		name_label.text = row_titles[_rows.size()]
	name_label.add_theme_font_size_override("font_size", 16)
	text.add_child(name_label)
	var parts: PackedStringArray = []
	var have_all := true
	for id in recipe.ingredients:
		var item := GameState._resolve_item(String(id))
		var need: int = recipe.ingredients[id]
		var have := data.get_item_count(String(id))
		have_all = have_all and have >= need
		parts.append("%s %d/%d" % [item.display_name if item != null else id, have, need])
	var ing := Label.new()
	ing.text = " → ".join(parts)
	ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ing.add_theme_font_size_override("font_size", 12)
	ing.add_theme_color_override("font_color", ServiceTheme.INK if have_all else Color(0.6, 0.25, 0.2))
	text.add_child(ing)
	var note: String = str(recipe.get("note")) if recipe.get("note") != null else str(recipe.get_meta("note", ""))
	if not note.is_empty():
		var note_label := Label.new()
		note_label.text = note
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.add_theme_font_size_override("font_size", 12)
		note_label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.5))
		text.add_child(note_label)
	var index := _rows.size()
	row.mouse_entered.connect(func() -> void: _select(index))
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Coop.accepts_event(player, event):
			_choose(index))
	return row


func _select(index: int) -> void:
	if _rows.is_empty():
		return
	_index = clampi(index, 0, _rows.size() - 1)
	for i in _rows.size():
		var style := _rows[i].get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color.a = 0.28 if i == _index else 0.0


func _choose(index: int) -> void:
	if _closed or index < 0 or index >= catalog.recipes.size():
		return
	var recipe := catalog.recipes[index]
	close()
	chosen.emit.call_deferred(recipe)


func _input(event: InputEvent) -> void:
	if _closed or not Coop.accepts_event(player, event):
		return
	var input := _input_owner()
	if input.is_event(event, &"ui_cancel"):
		close()
	elif input.is_event(event, &"move_down"):
		_select(_index + 1)
	elif input.is_event(event, &"move_up"):
		_select(_index - 1)
	elif not input.uses_mouse() and (input.is_event(event, &"ui_accept") or input.is_event(event, &"interact")):
		_choose(_index)
	else:
		return
	get_viewport().set_input_as_handled()


func close() -> void:
	if _closed:
		return
	_closed = true
	set_process_input(false)
	Coop.set_menu_open(player, false)
	queue_free()


func _exit_tree() -> void:
	if not _closed:
		Coop.set_menu_open(player, false)
