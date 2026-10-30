extends Control

## Tata letak dialog co-op: tetap terbaca di setengah/seperempat layar.
@export var preferred_width := 552.0
@export var edge_margin := 24
@export var compact_edge_margin := 8
@export var compact_height := 480.0
@export var list_height := 176.0

var _card_style: StyleBox
var _font_sizes: Dictionary = {}

func _ready() -> void:
	_card_style = $Frame/Center/Card.get_theme_stylebox("panel").duplicate()
	get_viewport().size_changed.connect(reflow)
	reflow()

func reflow() -> void:
	if not is_node_ready():
		return
	var area := get_viewport().get_visible_rect().size
	var compact := area.y < compact_height
	var edge := compact_edge_margin if compact else edge_margin
	for side in ["left", "top", "right", "bottom"]:
		$Frame.add_theme_constant_override("margin_" + side, edge)
	var card: PanelContainer = $Frame/Center/Card
	card.custom_minimum_size.x = minf(preferred_width, maxf(0.0, area.x - edge * 2))
	var card_style := _card_style.duplicate()
	if compact:
		card_style.set_content_margin_all(10.0)
	card.add_theme_stylebox_override("panel", card_style)
	$Frame/Center/Card/Content.add_theme_constant_override("separation", 6 if compact else 14)
	for item in find_children("*", "Control", true, false):
		if item.is_in_group("coop_compact_hide"):
			item.visible = not compact
		if item is Label or item is Button:
			var id: int = item.get_instance_id()
			if not _font_sizes.has(id):
				_font_sizes[id] = item.get_theme_font_size("font_size")
			var base: int = _font_sizes[id]
			item.add_theme_font_size_override("font_size", mini(base, 22 if item.name == "Title" else 16) if compact else base)
	var scroll := get_node_or_null("Frame/Center/Card/Content/Scroll") as ScrollContainer
	if scroll != null:
		scroll.custom_minimum_size.y = clampf(area.y - 170.0, 44.0, 108.0) if compact else list_height
	var action := get_node_or_null("Frame/Center/Card/Content/Action") as Button
	if action != null:
		action.custom_minimum_size.y = 32.0 if compact else 44.0
