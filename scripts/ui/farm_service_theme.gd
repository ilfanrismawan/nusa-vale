class_name FarmServiceTheme
extends RefCounted

const PAPER := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const BANNER := preload("res://assets/farm_rpg/ui/Banner.png")
const DIALOG := preload("res://assets/farm_rpg/ui/dialogue box.png")
const FONT := preload("res://resources/ui/readable_font.tres")
const INK := Color("50321f")
const LAYER := 70
const BLACKSMITH_LAYERS := [
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Skins/2.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Eyes/Brown.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Clothers/T-shirt Gray.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Clothers/Blacksmith apron.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Hair/Black.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Acc/Beard/Black.png"),
	preload("res://assets/farm_rpg/Character/NPC'S/Blacksmith/Portrait - PNG and Aseprite/Arm/2.png")
]

static func blacksmith_portrait() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(80, 80)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for texture in BLACKSMITH_LAYERS:
		var layer := TextureRect.new()
		layer.texture = portrait(texture)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root

static func portrait(texture: Texture2D) -> Texture2D:
	if texture == null or texture is AtlasTexture or texture.get_width() < 128:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 64, 64)
	return atlas

static func texture_style(texture: Texture2D, rect: Rect2, border: int, padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = rect
	style.set_texture_margin_all(border)
	style.set_content_margin_all(padding)
	return style

static func frame() -> StyleBoxTexture:
	return texture_style(PAPER, Rect2(0, 64, 48, 48), 5, 12)

static func dialogue() -> StyleBoxTexture:
	return texture_style(DIALOG, Rect2(0, 0, 48, 48), 5, 12)

static func ribbon(dark: bool = false) -> StyleBoxTexture:
	return texture_style(BANNER, Rect2(5, 145 if dark else 113, 38, 15), 5, 8)

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	for type in ["Label", "Button", "OptionButton", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", type, INK)
	theme.set_stylebox("panel", "PanelContainer", frame())
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, ribbon())
		theme.set_stylebox("hover", type, ribbon(true))
		theme.set_stylebox("pressed", type, ribbon(true))
		var disabled := ribbon()
		disabled.modulate_color = Color(0.8, 0.8, 0.8, 0.6)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_color("font_hover_color", type, Color("fff1d4"))
		theme.set_color("font_pressed_color", type, Color("fff1d4"))
		theme.set_color("font_disabled_color", type, Color("8f7c66"))
		theme.set_constant("icon_max_width", type, 24)
		var focus := dialogue()
		focus.draw_center = false
		theme.set_stylebox("focus", type, focus)
	theme.set_stylebox("normal", "LineEdit", frame())
	theme.set_stylebox("focus", "LineEdit", dialogue())
	return theme

static func mount(layer: CanvasLayer, control: Control, design_size: Vector2) -> void:
	control.reparent(layer, false)
	control.theme = make_theme()
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var weak_control: WeakRef = weakref(control)
	var fit := func():
		var fitted: Control = weak_control.get_ref()
		if not is_instance_valid(fitted) or not fitted.is_inside_tree(): return
		fitted.size = design_size.max(fitted.get_combined_minimum_size())
		var view := fitted.get_viewport().get_visible_rect().size
		fitted.scale = Vector2.ONE * minf(1, minf((view.x - 24) / fitted.size.x, (view.y - 24) / fitted.size.y))
		fitted.position = ((view - fitted.size * fitted.scale) / 2).floor()
	control.get_viewport().size_changed.connect(fit)
	var weak_view: WeakRef = weakref(control.get_viewport())
	control.tree_exiting.connect(func():
		var view: Viewport = weak_view.get_ref()
		if is_instance_valid(view) and view.size_changed.is_connected(fit):
			view.size_changed.disconnect(fit), CONNECT_ONE_SHOT)
	await control.get_tree().process_frame
	fit.call()
