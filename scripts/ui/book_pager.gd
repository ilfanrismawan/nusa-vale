extends HBoxContainer
@export_range(16, 16) var text_font_size := 16
@export var text_font: Font
@export var nearest_textures := false
## Pagination of scene-authored content; hidden rows do not consume container space.
@export var content_path: NodePath
@export_range(1, 30) var page_size := 4
@export var turn_pages := false
@export var paper_path: NodePath
var _turning := false
var _turn_tween: Tween
var _turn_leaf: TextureRect
var _turn_progress := 0.0
var current_page := 0
var _content: Node

func _ready() -> void:
	for path: String in ["Previous", "Page", "Next"]:
		var control := get_node(path) as Control
		if text_font_size > 0:
			control.add_theme_font_size_override("font_size", 16)
		if text_font != null:
			control.add_theme_font_override("font", text_font)
		if nearest_textures:
			control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_content = get_node(content_path)
	$Previous.pressed.connect(_change.bind(-1))
	$Next.pressed.connect(_change.bind(1))
	if turn_pages:
		$Previous.text = "‹"
		$Previous.tooltip_text = "Lembar sebelumnya"
		$Next.text = "›"
		$Next.tooltip_text = "Lembar berikutnya"
	refresh()

func refresh() -> void:
	if not is_instance_valid(_content): return
	var count := _content.get_child_count()
	var pages := maxi(1, ceili(float(count) / page_size))
	current_page = clampi(current_page, 0, pages - 1)
	for index in count:
		var child := _content.get_child(index) as CanvasItem
		if child != null: child.visible = index / page_size == current_page
	$Page.text = ("Lembar %d / %d" if turn_pages else "%d / %d") % [current_page + 1, pages]
	$Previous.disabled = _turning or current_page == 0
	$Next.disabled = _turning or current_page >= pages - 1

func _change(direction: int) -> void:
	if _turning or not is_instance_valid(_content):
		return
	var pages := maxi(1, ceili(float(_content.get_child_count()) / page_size))
	var destination := clampi(current_page + direction, 0, pages - 1)
	if destination == current_page:
		return
	if not turn_pages or not _content is Control:
		current_page = destination
		refresh()
		return
	_turning = true
	refresh()
	var paper := get_node_or_null(paper_path) as Control
	if paper == null:
		current_page = destination
		_turning = false
		refresh()
		return
	var source := paper.get_node("RightSheet" if direction > 0 else "LeftSheet") as TextureRect
	var landing := paper.get_node("LeftSheet" if direction > 0 else "RightSheet") as TextureRect
	var design := paper.get_parent() as Control
	var blocker := Control.new()
	blocker.name = "PageTurnInputBlocker"
	blocker.size = design.size
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	design.add_child(blocker)
	_turn_leaf = TextureRect.new()
	_turn_leaf.name = "TurningPaperLeaf"
	_turn_leaf.texture = _capture_sheet(source, false)
	_turn_leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_turn_leaf.stretch_mode = TextureRect.STRETCH_SCALE
	_turn_leaf.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_turn_leaf.position = source.position
	_turn_leaf.size = source.size
	# Both pages share the same hinge at the centre of the binding.
	var hinge := (source.position.x + source.size.x + landing.position.x) * 0.5 if direction < 0 else (landing.position.x + landing.size.x + source.position.x) * 0.5
	_turn_leaf.pivot_offset = Vector2(hinge - source.position.x, source.size.y * 0.5)
	_turn_leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(_turn_leaf)
	_set_turn_progress(0.0)
	_turn_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turn_tween.tween_method(_set_turn_progress, 0.0, 0.5, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _turn_tween.finished
	current_page = destination
	refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	# The reverse side is pre-mirrored so its text reads correctly after crossing the spine.
	_turn_leaf.texture = _capture_sheet(landing, true)
	_turn_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turn_tween.tween_method(_set_turn_progress, 0.5, 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _turn_tween.finished
	_turn_leaf.queue_free()
	_turn_leaf = null
	blocker.queue_free()
	_turning = false
	refresh()

func _set_turn_progress(value: float) -> void:
	_turn_progress = value
	if not is_instance_valid(_turn_leaf):
		return
	# A single sheet rotates through 180 degrees, from the right over the left (or back).
	var projection := cos(value * PI)
	_turn_leaf.scale.x = projection if absf(projection) > 0.002 else 0.002
	var light := 0.72 + 0.28 * absf(projection)
	_turn_leaf.modulate = Color(light, light, light, 1.0)

func _capture_sheet(sheet: TextureRect, mirror: bool) -> Texture2D:
	var image: Image
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		var frame := sheet.get_viewport().get_texture().get_image()
		var transform := sheet.get_global_transform_with_canvas()
		var start := transform * Vector2.ZERO
		var end := transform * sheet.size
		var region := Rect2i(Vector2i(start.round()), Vector2i((end - start).round()))
		region = region.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
		if region.has_area():
			image = frame.get_region(region)
	if image == null:
		image = sheet.texture.get_image()
	if mirror:
		image.flip_x()
	return ImageTexture.create_from_image(image)

func reveal(index: int) -> void:
	current_page = maxi(0, index) / page_size
	refresh()
