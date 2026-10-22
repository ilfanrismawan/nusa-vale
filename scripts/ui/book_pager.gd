extends HBoxContainer
## Pagination of scene-authored content; hidden rows do not consume container space.
@export var content_path: NodePath
@export_range(1, 30) var page_size := 4
var current_page := 0
var _content: Node

func _ready() -> void:
	_content = get_node(content_path)
	$Previous.pressed.connect(_change.bind(-1))
	$Next.pressed.connect(_change.bind(1))
	refresh()

func refresh() -> void:
	if not is_instance_valid(_content): return
	var count := _content.get_child_count()
	var pages := maxi(1, ceili(float(count) / page_size))
	current_page = clampi(current_page, 0, pages - 1)
	for index in count:
		var child := _content.get_child(index) as CanvasItem
		if child != null: child.visible = index / page_size == current_page
	$Page.text = "%d / %d" % [current_page + 1, pages]
	$Previous.disabled = current_page == 0
	$Next.disabled = current_page >= pages - 1

func _change(direction: int) -> void:
	current_page += direction
	refresh()

func reveal(index: int) -> void:
	current_page = maxi(0, index) / page_size
	refresh()
