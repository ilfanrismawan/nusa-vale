@tool
class_name BuildingSign
extends Node2D
## Artwork lives in the scene. These exports preserve existing placed sign presets.
enum Mount { WALL, HANGING, POSTS }
var _pending: Dictionary = {}
var _nodes_ready := false
var _layout_pending := false

@export var use_preset_overrides := true

@export var auto_layout := true:
	set(value):
		auto_layout = value
		_schedule_layout()
@export var caption := "Sekolah":
	set(value):
		caption = value
		_change("caption", value)
@export var mount: Mount = Mount.WALL:
	set(value):
		mount = value
		_schedule_layout()
@export_range(32, 192, 1) var minimum_width: int = 56:
	set(value):
		minimum_width = value
		_change("width", value)
@export_range(8, 24, 1) var font_size: int = 16:
	set(value):
		font_size = value
		_change("font_size", value)
@export var icon: Texture2D:
	set(value):
		icon = value
		_change("icon", value)
@export_range(12, 32, 1) var minimum_height: int = 20:
	set(value):
		minimum_height = value
		_change("height", value)
@export var wood_color := Color("7d452b"):
	set(value):
		wood_color = value
		_change("wood_color", value)
@export var text_color := Color("ffe6aa"):
	set(value):
		text_color = value
		_change("text_color", value)

func _ready() -> void:
	_nodes_ready = true
	%Content.minimum_size_changed.connect(_schedule_layout)
	_apply_pending()
	_schedule_layout()

func _change(key: String, value: Variant) -> void:
	_pending[key] = value
	if _nodes_ready:
		_apply_pending()
	_schedule_layout()

func _apply_pending() -> void:
	if not use_preset_overrides:
		_pending.clear()
		return
	for key: String in _pending:
		var value: Variant = _pending[key]
		match key:
			"caption": %Caption.text = str(value)
			"width": %Board.custom_minimum_size.x = float(value)
			"height": %Board.custom_minimum_size.y = float(value)
			"font_size": %Caption.add_theme_font_size_override("font_size", int(value))
			"icon":
				%Icon.texture = value as Texture2D
				%Icon.visible = value != null
			"wood_color":
				var panel := %Frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
				panel.bg_color = value
				%Frame.add_theme_stylebox_override("panel", panel)
				%BottomGrain.color = (value as Color).darkened(0.25)
			"text_color": %Caption.add_theme_color_override("font_color", value)
	_pending.clear()

func _schedule_layout() -> void:
	if not _nodes_ready or _layout_pending:
		return
	_layout_pending = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_pending = false
	if not is_inside_tree():
		return
	%Posts.visible = mount == Mount.POSTS
	%Hanging.visible = mount == Mount.HANGING
	if not auto_layout:
		return
	var board := %Board as Control
	board.size = board.custom_minimum_size.max(%Content.get_combined_minimum_size()).ceil()
	var mounting_point: Marker2D = %PostMount if mount == Mount.POSTS else %WallMount
	board.position = mounting_point.position - board.size * 0.5
	for post: ColorRect in [%LeftPost, %RightPost]:
		post.offset_bottom = %Ground.position.y - board.position.y - board.size.y

func board_rect() -> Rect2:
	var board := get_node_or_null("Board") as Control
	return board.get_rect() if board != null else Rect2()
