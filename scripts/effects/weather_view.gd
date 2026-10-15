extends CanvasLayer

var player: Node
var _rain: RainDrawing

class RainDrawing extends Node2D:
	var elapsed := 0.0
	func _process(delta: float) -> void:
		if not visible:
			return
		elapsed += delta
		queue_redraw()
	func _draw() -> void:
		var bounds := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, bounds), Color(0.08, 0.12, 0.22, 0.25))
		for i in 64:
			var start := Vector2(fmod(i * 97.0 + elapsed * 24.0, bounds.x), fmod(i * 43.0 + elapsed * 165.0, bounds.y + 24.0) - 12.0)
			draw_line(start, start + Vector2(3, 12), Color(0.7, 0.84, 1, 0.5), 1)

func _ready() -> void:
	layer = 1
	_rain = RainDrawing.new()
	add_child(_rain)
	GameState.weather.changed.connect(_update)
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	if _rain == null or not is_instance_valid(player):
		return
	var world: Node = player.world_root()
	var indoor := not is_instance_valid(world) or "/interior/" in world.scene_file_path or world.scene_file_path.ends_with("/interior.tscn")
	_rain.visible = GameState.weather.is_raining() and not indoor
