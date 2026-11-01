extends CanvasLayer

const SUN_RAYS_SHADER := preload("res://shaders/sun_rays.gdshader")
const RAY_INTENSITY := 0.12

var player: Node
var _rain: RainDrawing
var _rays: ColorRect
var _ray_material: ShaderMaterial

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
	_ray_material = ShaderMaterial.new()
	_ray_material.shader = SUN_RAYS_SHADER
	_rays = ColorRect.new()
	_rays.name = "SunRays"
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.material = _ray_material
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)
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
	_update_rays(SkyFX.of_world(world) if not indoor else null)

## Berkas sinar hanya di area yang punya SkyFX, siang hari, dan tidak hujan.
## Sudutnya ikut posisi matahari: pagi miring ke kanan, sore ke kiri.
func _update_rays(sky: SkyFX) -> void:
	var strength := 0.0
	if sky != null and not SkyFX.is_overcast():
		strength = SkyFX.sun_factor() * sky.ray_strength
	_rays.visible = strength > 0.0
	if not _rays.visible:
		return
	var golden := SkyFX.golden_factor()
	var h := DayCycle.hour + DayCycle.minute / 60.0
	_ray_material.set_shader_parameter("intensity", RAY_INTENSITY * strength * lerpf(0.6, 1.0, golden))
	_ray_material.set_shader_parameter("ray_color", Color(1.0, 0.93, 0.72).lerp(Color(1.0, 0.72, 0.42), golden))
	_ray_material.set_shader_parameter("angle", lerpf(0.45, -0.45, clampf((h - 6.0) / 12.0, 0.0, 1.0)))
