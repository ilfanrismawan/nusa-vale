extends CanvasLayer
## Layar akhir demo: muncul saat hari ke-29 dimulai di build demo.
## Game dijeda; tombol kembali ke menu utama. Teks diedit di node scene.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@export var design_size := Vector2(1280, 720)

@onready var _design: Control = $Design
@onready var _back: Button = %BackToMenu


func _ready() -> void:
	get_viewport().size_changed.connect(_resize)
	_resize()
	_back.pressed.connect(_on_back_pressed)
	get_tree().paused = true
	_back.grab_focus()


func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	_design.scale = Vector2.ONE * fit
	_design.position = (view - design_size * fit) * 0.5


func _on_back_pressed() -> void:
	get_tree().paused = false
	DayCycle.is_running = false
	queue_free()
	get_tree().change_scene_to_file(MAIN_MENU)
