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
		var storm: bool = GameState.weather.is_storm()
		draw_rect(Rect2(Vector2.ZERO, bounds), Color(0.04, 0.06, 0.16, 0.40) if storm else Color(0.08, 0.12, 0.22, 0.25))
		var lines := 100 if storm else 64
		for i in lines:
			var start := Vector2(fmod(i * 97.0 + elapsed * 32.0, bounds.x), fmod(i * 43.0 + elapsed * 200.0, bounds.y + 24.0) - 12.0)
			draw_line(start, start + Vector2(4, 14), Color(0.75, 0.88, 1.0, 0.65) if storm else Color(0.7, 0.84, 1, 0.5), 1)
		if storm:
			var flash_phase := fmod(elapsed, 7.5)
			if flash_phase < 0.12:
				draw_rect(Rect2(Vector2.ZERO, bounds), Color(0.95, 0.98, 1.0, 0.65 * (1.0 - flash_phase / 0.12)))

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
