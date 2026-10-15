extends PanelContainer

const FONT = preload("res://resources/ui/readable_font.tres")
const CATALOG = preload("res://resources/character/character_catalog.tres")
## Slot yang bisa dipakai + ikon samar saat kosong (kunci = PlayerData.EQUIPMENT_KEYS).
const EMPTY_ICONS := {
	"weapon": preload("res://resources/icons/icon_sword_wood.tres"),
	"helmet": preload("res://resources/icons/icon_helmet_wood.tres"),
	"armor": preload("res://resources/icons/icon_armor_wood.tres"),
	"leggings": preload("res://resources/icons/icon_leggings_wood.tres"),
	"boots": preload("res://resources/icons/icon_boots_wood.tres"),
}
const Glyph = preload("res://scripts/ui/equipment_slot_glyph.gd")
var inventory_ui: CanvasLayer
var _available: VBoxContainer
var _stats: Label
var _message: Label
var _name: Label
var _portrait: TextureRect
var _preview_key := ""
var _entries: Array[Button] = []
var _remove_buttons: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color("50321f"))
	theme = ui_theme
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(420, 248)
	add_child(canvas)
	var frame := Panel.new()
	frame.position = Vector2(2, 8)
	frame.size = Vector2(228, 238)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _frame_style(Color("efdab0"), 3))
	canvas.add_child(frame)
	var inset := Panel.new()
	inset.position = Vector2(8, 14)
	inset.size = Vector2(216, 226)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_stylebox_override("panel", _frame_style(Color("f7e6c5"), 1))
	canvas.add_child(inset)
	for corner in [Vector2(4, 10), Vector2(218, 10), Vector2(4, 234), Vector2(218, 234)]:
		var rivet := Panel.new()
		rivet.position = corner
		rivet.size = Vector2(8, 8)
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rivet.add_theme_stylebox_override("panel", _frame_style(Color("c69a42"), 1))
		canvas.add_child(rivet)
	var plaque := Panel.new()
	plaque.position = Vector2(47, 0)
	plaque.size = Vector2(138, 26)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override("panel", _frame_style(Color("f2d59f"), 2))
	canvas.add_child(plaque)
	_label(canvas, "EQUIPMENT", Vector2(47, 3), Vector2(138, 20), 20, true)
	var portrait_bg := Panel.new()
	portrait_bg.position = Vector2(61, 39)
	portrait_bg.size = Vector2(110, 114)
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("e9d0a0")
	backdrop.set_corner_radius_all(44)
	portrait_bg.add_theme_stylebox_override("panel", backdrop)
	canvas.add_child(portrait_bg)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(64, 38)
	_portrait.size = Vector2(104, 112)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_portrait)
	_name = _label(canvas, "", Vector2(56, 146), Vector2(120, 18), 16, true)
	_stats = _label(canvas, "", Vector2(54, 164), Vector2(124, 18), 16, true)
	_slot(canvas, "helmet", "Helm", Vector2(16, 37), EMPTY_ICONS["helmet"])
	_slot(canvas, "armor", "Armor", Vector2(16, 82), EMPTY_ICONS["armor"])
	_slot(canvas, "leggings", "Celana Zirah", Vector2(16, 127), EMPTY_ICONS["leggings"])
	_slot(canvas, "boots", "Sepatu", Vector2(180, 37), EMPTY_ICONS["boots"])
	_slot(canvas, "necklace", "Kalung", Vector2(180, 82), null, "gem")
	_slot(canvas, "accessory", "Aksesori", Vector2(180, 127), null, "ring")
	_slot(canvas, "weapon", "Weapon", Vector2(30, 194), EMPTY_ICONS["weapon"])
	_slot(canvas, "ring", "Cincin", Vector2(74, 194), null, "ring")
	_slot(canvas, "shield", "Perisai", Vector2(118, 194), null, "shield")
	_slot(canvas, "locked", "Slot tambahan", Vector2(162, 194), null, "lock")
	var sidebar := Panel.new()
	sidebar.position = Vector2(240, 8)
	sidebar.size = Vector2(180, 238)
	sidebar.add_theme_stylebox_override("panel", _frame_style(Color("efd9b2"), 1))
	canvas.add_child(sidebar)
	var rows := VBoxContainer.new()
	rows.position = Vector2(10, 8)
	rows.size = Vector2(160, 222)
	rows.add_theme_constant_override("separation", 6)
	sidebar.add_child(rows)
	var title := Label.new()
	title.text = "PERLENGKAPAN TAS"
	title.add_theme_font_size_override("font_size", 18)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Klik slot terpasang untuk\nmelepas ke tas."
	rows.add_child(hint)
	rows.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	_available = VBoxContainer.new()
	_available.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_available)
	_message = Label.new()
	_message.custom_minimum_size.y = 42
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_message)
	refresh()

func _frame_style(bg: Color, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("997039")
	style.set_border_width_all(border)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.24, 0.13, 0.06, 0.25)
	style.shadow_size = 2
	return style

func _label(parent: Control, text: String, pos: Vector2, dimensions: Vector2, font_size: int, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _atlas(path: String) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = load(path)
	icon.region = Rect2(0, 0, 16, 16)
	return icon

func _slot(parent: Control, key: String, title: String, pos: Vector2, icon: Texture2D, glyph: String = "") -> void:
	var button := Button.new()
	button.name = "Slot_" + key
	button.position = pos
	button.size = Vector2(36, 36)
	button.add_theme_stylebox_override("normal", _frame_style(Color("735530"), 2))
	button.add_theme_stylebox_override("hover", _frame_style(Color("9b783b"), 2))
	button.add_theme_stylebox_override("pressed", _frame_style(Color("537364"), 2))
	button.add_theme_stylebox_override("disabled", _frame_style(Color("b29b72"), 1))
	button.add_theme_stylebox_override("focus", _frame_style(Color(0, 0, 0, 0), 2))
	parent.add_child(button)
	var usable := EMPTY_ICONS.has(key)
	if icon != null:
		var picture := TextureRect.new()
		picture.name = "Icon"
		picture.position = Vector2(6, 6)
		picture.size = Vector2(24, 24)
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.modulate.a = 1.0 if usable else 0.45
		button.add_child(picture)
	else:
		var drawing := Glyph.new()
		drawing.kind = glyph
		drawing.position = Vector2(6, 6)
		drawing.size = Vector2(24, 24)
		drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(drawing)
	if usable:
		button.pressed.connect(_unequip.bind(key))
		_remove_buttons[key] = button
	else:
		button.disabled = true
		button.tooltip_text = title + " — terkunci, belum tersedia."
		_label(button, "x", Vector2(27, 22), Vector2(8, 12), 14, true)

func refresh() -> void:
	if not visible or not is_instance_valid(_available):
		return
	var data: PlayerData = inventory_ui.data
	for child in _available.get_children():
		_available.remove_child(child)
		child.queue_free()
	_entries.clear()
	var stats := data.equipment_stats()
	_stats.text = "ATK +%d   DEF +%d" % [stats.x, stats.y]
	_name.text = data.player_name if not data.player_name.is_empty() else "Petani P%d" % (data.index + 1)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var look_key := data.appearance.get_key()
	if _preview_key != look_key:
		_preview_key = look_key
		var result := CharacterSpriteBuilder.build(CATALOG, data.appearance, {}, PackedStringArray(["idle_down", "idle"]))
		var frames: SpriteFrames = result["frames"]
		var anim: StringName = &"idle_down" if frames.has_animation(&"idle_down") else &"idle"
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var image := frames.get_frame_texture(anim, 0).get_image()
			var bounds := image.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			if bounds.has_area():
				_portrait.texture = ImageTexture.create_from_image(image.get_region(bounds))
	for key in _remove_buttons:
		var item: ItemData = data.equipment[key]
		var button: Button = _remove_buttons[key]
		var icon: TextureRect = button.get_node("Icon")
		icon.texture = item.icon if item != null else EMPTY_ICONS[key]
		icon.modulate.a = 1.0 if item != null else 0.25
		button.disabled = item == null
		button.tooltip_text = "%s\nATK +%d / DEF +%d\nKlik untuk melepas ke tas." % [item.display_name, item.attack_bonus, item.defense_bonus] if item != null else "Slot kosong — pasang perlengkapan dari tas."
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry == null or PlayerData.equipment_key(entry["item"]).is_empty():
			continue
		var item: ItemData = entry["item"]
		var button: Button = inventory_ui._make_menu_button("Pasang " + item.display_name)
		button.icon = item.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 18)
		button.tooltip_text = "%s\nATK +%d / DEF +%d\n%s" % [item.display_name, item.attack_bonus, item.defense_bonus, item.description]
		button.pressed.connect(_equip.bind(slot))
		_available.add_child(button)
		_entries.append(button)
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "Belum ada equipment\ndi dalam tas."
		_available.add_child(empty)
	_message.text = "Weapon, helm, armor, celana\n& sepatu aktif. Slot lain terkunci."

func _equip(slot: int) -> void:
	if not inventory_ui.data.equip_from_slot(slot):
		_message.text = "Perlengkapan tidak dapat dipasang."

func _unequip(key: String) -> void:
	if not inventory_ui.data.unequip(key):
		_message.text = "Tas penuh. Kosongkan satu slot sebelum melepas equipment."
