class_name CharacterCreatorUI
extends CanvasLayer

## Layar kustomisasi karakter, dibangun lewat kode (pola sama dengan ShopUI).
## Dipakai saat New Game (tanpa tombol Batal) dan dari lemari di rumah.
## Hasil disimpan ke GameState lewat set_appearance() saat "Selesai".

signal finished(appearance: CharacterAppearance)
signal cancelled

const CATALOG: CharacterCatalog = preload("res://resources/character/character_catalog.tres")
const FONT := preload("res://assets/fonts/m5x7.ttf")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/inventory/Banner.png")

const COLOR_TEXT := Color(0.36, 0.2, 0.15)
const COLOR_TEXT_LIGHT := Color(0.97, 0.88, 0.78)
const PREVIEW_SCALE := 4.0
## Urutan putar preview: depan, kanan, belakang, kiri.
const DIRECTIONS: Array[String] = ["down", "right", "up", "left"]

const COLOR_NAMES := {
	"black": "Hitam",
	"blue": "Biru",
	"brown": "Cokelat",
	"green": "Hijau",
	"navy": "Biru Tua",
	"yellow": "Kuning",
	"blonde": "Pirang",
	"ginger": "Jingga",
	"pink": "Merah Muda",
	"purple": "Ungu",
	"red": "Merah",
}

## Baris pilihan. kind "part" memilih CharacterPart, kind "color" memilih warna dari part di `part_field`.
const ROWS := [
	{"label": "Kulit", "kind": "part", "field": "skin", "layer": CharacterPart.Layer.SKIN, "optional": false},
	{"label": "Mata", "kind": "part", "field": "eyes", "layer": CharacterPart.Layer.EYES, "optional": false},
	{"label": "Warna Mata", "kind": "color", "field": "eye_color", "part_field": "eyes"},
	{"label": "Rambut", "kind": "part", "field": "hair", "layer": CharacterPart.Layer.HAIR, "optional": false},
	{"label": "Warna Rambut", "kind": "color", "field": "hair_color", "part_field": "hair"},
	{"label": "Baju", "kind": "part", "field": "outfit", "layer": CharacterPart.Layer.OUTFIT, "optional": false},
	{"label": "Warna Baju", "kind": "color", "field": "outfit_color", "part_field": "outfit"},
	{"label": "Wajah", "kind": "part", "field": "face", "layer": CharacterPart.Layer.FACE, "optional": true},
	{"label": "Topi", "kind": "part", "field": "head", "layer": CharacterPart.Layer.HEAD, "optional": true},
	{"label": "Warna Topi", "kind": "color", "field": "head_color", "part_field": "head"},
	{"label": "Celana", "kind": "part", "field": "pants", "layer": CharacterPart.Layer.PANTS, "optional": true},
]

## Tampilkan tombol Batal dan izinkan Esc. false saat New Game.
@export var allow_cancel: bool = true
## Pause game selama layar terbuka (dari lemari). false di Main Menu.
@export var pause_game: bool = true
## Tampilkan kolom nama (Game Baru). Nama tampil di menu slot save.
@export var ask_name: bool = false

const NAME_MAX_LENGTH := 16

var appearance: CharacterAppearance
## Pemain yang mengganti penampilan (lemari co-op). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()
var _preview: AnimatedSprite2D
var _direction_index := 0
var _value_labels: Dictionary = {}
var _row_nodes: Dictionary = {}
var _name_edit: LineEdit
var _animation_picker: OptionButton
var _preview_action := "walk"

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	appearance = CATALOG.sanitize(data.appearance)
	_build_ui()
	_refresh()
	if pause_game:
		Coop.set_menu_open(player, true)

# ── Membangun UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", COLOR_TEXT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.theme = ui_theme
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(0, 64, 48, 48), 8, 12))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Penampilan Karakter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	if ask_name:
		box.add_child(_build_name_row())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)
	body.add_child(_build_preview_column())
	body.add_child(_build_options_grid())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	buttons.add_child(_make_button("Acak", _randomize))
	if allow_cancel:
		buttons.add_child(_make_button("Batal", _cancel))
	buttons.add_child(_make_button("Selesai", _confirm))

func _build_name_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Nama"
	row.add_child(label)
	_name_edit = LineEdit.new()
	_name_edit.text = data.player_name
	_name_edit.placeholder_text = SaveManager.DEFAULT_PLAYER_NAME
	_name_edit.max_length = NAME_MAX_LENGTH
	_name_edit.custom_minimum_size = Vector2(160, 0)
	row.add_child(_name_edit)
	return row

func _build_preview_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 9, 18, 18), 4, 4))
	column.add_child(frame)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(32, 32) * PREVIEW_SCALE
	frame.add_child(holder)

	_preview = AnimatedSprite2D.new()
	_preview.scale = Vector2.ONE * PREVIEW_SCALE
	_preview.position = holder.custom_minimum_size / 2.0
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_preview)

	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	turn.add_child(_make_button("<", _turn.bind(-1)))
	var turn_label := Label.new()
	turn_label.text = "Putar"
	turn.add_child(turn_label)
	turn.add_child(_make_button(">", _turn.bind(1)))
	column.add_child(turn)
	_animation_picker = OptionButton.new()
	_animation_picker.custom_minimum_size.x = 128
	_animation_picker.add_item("Animasi: walk")
	_animation_picker.set_item_metadata(0, "walk")
	var actions: PackedStringArray = ["walk"]
	var template := CharacterSpriteBuilder.get_template(CATALOG)
	for anim in template.get_animation_names():
		var action := String(anim).trim_suffix("_down").trim_suffix("_right").trim_suffix("_up")
		if not actions.has(action):
			actions.append(action)
	for sheet in CATALOG.sheets:
		if not sheet.animation_name.is_empty() and not actions.has(String(sheet.animation_name)):
			actions.append(String(sheet.animation_name))
	for i in range(1, actions.size()):
		_animation_picker.add_item("Animasi: " + actions[i])
		_animation_picker.set_item_metadata(i, actions[i])
	_animation_picker.item_selected.connect(func(index: int):
		_preview_action = _animation_picker.get_item_metadata(index)
		_refresh_preview())
	column.add_child(_animation_picker)
	# Preview aksi sekali putar diulang hanya di layar kustomisasi.
	_preview.animation_finished.connect(func(): _preview.play())
	return column

func _build_options_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		var label := Label.new()
		label.text = row["label"]
		label.custom_minimum_size = Vector2(84, 0)
		grid.add_child(label)

		var prev_button := _make_button("<", _cycle.bind(i, -1))
		grid.add_child(prev_button)

		var value_panel := PanelContainer.new()
		value_panel.add_theme_stylebox_override("panel", _style(TEX_BANNER, Rect2(5, 145, 38, 15), 5, 2))
		value_panel.custom_minimum_size = Vector2(118, 0)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
		value_panel.add_child(value)
		grid.add_child(value_panel)

		var next_button := _make_button(">", _cycle.bind(i, 1))
		grid.add_child(next_button)

		_value_labels[i] = value
		_row_nodes[i] = [label, prev_button, value_panel, next_button]
	return grid

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _style(tex: Texture2D, region: Rect2, tex_margin: int, content_margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = region
	sb.set_texture_margin_all(tex_margin)
	sb.set_content_margin_all(content_margin)
	return sb

# ── Pilihan ─────────────────────────────────────────────────────────

func _options_for(row: Dictionary) -> PackedStringArray:
	var options: PackedStringArray = []
	if row["kind"] == "part":
		if row["optional"]:
			options.append("")
		for part in CATALOG.get_parts(row["layer"]):
			options.append(part.id)
	else:
		var part := CATALOG.find_part(appearance.get(row["part_field"]))
		if part != null:
			options = part.colors
	return options

func _cycle(row_index: int, step: int) -> void:
	var row: Dictionary = ROWS[row_index]
	var options := _options_for(row)
	if options.is_empty():
		return
	var current: String = appearance.get(row["field"])
	var index := wrapi(options.find(current) + step, 0, options.size())
	appearance.set(row["field"], options[index])
	appearance = CATALOG.sanitize(appearance)
	_refresh()

func _randomize() -> void:
	for row in ROWS:
		if row["kind"] != "part":
			continue
		var options := _options_for(row)
		if not options.is_empty():
			appearance.set(row["field"], options[randi() % options.size()])
	appearance = CATALOG.sanitize(appearance)
	for row in ROWS:
		if row["kind"] == "color":
			var colors := _options_for(row)
			if not colors.is_empty():
				appearance.set(row["field"], colors[randi() % colors.size()])
	_refresh()

func _turn(step: int) -> void:
	_direction_index = wrapi(_direction_index + step, 0, DIRECTIONS.size())
	_play_preview()

func _refresh() -> void:
	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		var value: String = appearance.get(row["field"])
		var text := "Tidak ada"
		if row["field"] == "pants" and value.is_empty():
			text = "Bawaan Baju"
		if row["kind"] == "part":
			var part := CATALOG.find_part(value)
			if part != null:
				text = part.display_name
		elif not value.is_empty():
			text = COLOR_NAMES.get(value, value.capitalize())
		_value_labels[i].text = text
		# Baris warna disembunyikan jika part-nya tidak punya pilihan warna.
		var visible_row: bool = row["kind"] == "part" or not _options_for(row).is_empty()
		for node in _row_nodes[i]:
			node.visible = visible_row

	_refresh_preview()

func _refresh_preview() -> void:
	var animations: PackedStringArray = [_preview_action]
	for direction in DIRECTIONS:
		animations.append("%s_%s" % [_preview_action, direction])
	var result := CharacterSpriteBuilder.build(CATALOG, appearance, {}, animations)
	_preview.sprite_frames = result["frames"]
	_play_preview()

func _play_preview() -> void:
	if _preview.sprite_frames == null:
		return
	var direction := DIRECTIONS[_direction_index]
	_preview.flip_h = false
	var anim := "%s_%s" % [_preview_action, direction]
	if not _preview.sprite_frames.has_animation(anim) and direction == "left":
		anim = "%s_right" % _preview_action
		_preview.flip_h = true
	if not _preview.sprite_frames.has_animation(anim):
		anim = _preview_action
		_preview.flip_h = false
	if _preview.sprite_frames.has_animation(anim):
		var texture := _preview.sprite_frames.get_frame_texture(anim, 0)
		_preview.scale = Vector2.ONE * minf(PREVIEW_SCALE, 128.0 / maxf(texture.get_width(), texture.get_height()))
		_preview.play(anim)

# ── Selesai / Batal ─────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if allow_cancel and input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

func _confirm() -> void:
	if _name_edit != null:
		data.player_name = _name_edit.text.strip_edges()
	data.set_appearance(appearance)
	finished.emit(data.appearance)
	_close()

func _cancel() -> void:
	cancelled.emit()
	_close()

func _close() -> void:
	if pause_game:
		Coop.set_menu_open(player, false)
	queue_free()
