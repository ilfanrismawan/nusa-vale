extends CanvasLayer

const TOP_LEFT := 0
const TOP_RIGHT := 1
const BOTTOM_LEFT := 2
const BOTTOM_RIGHT := 3
const TOP_CENTER := 4

@export var card_scene: PackedScene = preload("res://scenes/ui/notification_card.tscn")
@export_range(1, 6) var maximum_visible := 3
## Pojok layar tempat toast muncul.
@export_enum("Top Left", "Top Right", "Bottom Left", "Bottom Right", "Top Center") var corner: int = TOP_RIGHT
## Lebar satu kartu (px, ukuran viewport 854x480).
@export var card_width := 200.0
## Jarak dari tepi layar: x = samping, y = atas/bawah (TOP_RIGHT default di bawah jam).
@export var screen_margin := Vector2(10, 140)
## Skala keseluruhan toast (1.0 = ukuran asli kartu).
@export_range(0.5, 2.0) var ui_scale := 1.0
@export_range(0.2, 0.75) var maximum_height_ratio := 0.4
@onready var _box: VBoxContainer = $Presentation/Messages

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout)
	_box.resized.connect(_layout)
	_box.minimum_size_changed.connect(_layout)
	_layout()

func say(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	while _box.get_child_count() >= maximum_visible:
		var oldest := _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()
	var card := card_scene.instantiate()
	_box.add_child(card)
	card.present(message)
	_layout.call_deferred()

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_box.size = Vector2(card_width, 0)
	var height := maxf(1.0, _box.get_combined_minimum_size().y)
	var fit := ui_scale * minf(1.0, minf(maxf(1.0, view.x - screen_margin.x * 2) / card_width, view.y * maximum_height_ratio / height))
	var width := card_width * fit
	var scaled_height := height * fit
	var pos := Vector2.ZERO
	match corner:
		TOP_LEFT:
			pos = Vector2(screen_margin.x, screen_margin.y)
		TOP_RIGHT:
			pos = Vector2(view.x - screen_margin.x - width, screen_margin.y)
		BOTTOM_LEFT:
			pos = Vector2(screen_margin.x, view.y - screen_margin.y - scaled_height)
		BOTTOM_RIGHT:
			pos = Vector2(view.x - screen_margin.x - width, view.y - screen_margin.y - scaled_height)
		TOP_CENTER:
			pos = Vector2((view.x - width) * 0.5, screen_margin.y)
	$Presentation.scale = Vector2.ONE * fit
	$Presentation.position = pos
