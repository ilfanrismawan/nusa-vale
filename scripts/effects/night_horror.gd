extends CanvasLayer

## Per-player atmosphere; interiors and sleeping players remain quiet.
var player: Player
var intensity := 0.0
var _veil: ColorRect
var _material: ShaderMaterial
var _audio: AudioStreamPlayer
var _shadow: ShadowDrawing
var _event_timer := 18.0
var _rng := RandomNumberGenerator.new()

class ShadowDrawing extends Node2D:
	var life := 0.0
	var location := Vector2.ZERO
	func _process(delta: float) -> void:
		life = maxf(0.0, life - delta)
		queue_redraw()
	func _draw() -> void:
		if life <= 0.0:
			return
		var alpha := minf(life, 0.7) * 0.7
		draw_circle(location + Vector2(0, -18), 7, Color(0.015, 0.025, 0.03, alpha))
		draw_colored_polygon(PackedVector2Array([location + Vector2(-5, -13), location + Vector2(5, -13), location + Vector2(12, 15), location + Vector2(-12, 15)]), Color(0.015, 0.025, 0.03, alpha))

func _ready() -> void:
	layer = 2
	_rng.randomize()
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.18, 0.72, length((uv - vec2(0.5)) * vec2(1.1, 1.0)));
	float fog = sin(uv.x * 14.0 + uv.y * 8.0 + TIME * 0.22) * sin(uv.y * 17.0 - TIME * 0.17);
	float pulse = 0.97 + sin(TIME * 0.8) * 0.03;
	COLOR = vec4(mix(vec3(0.11, 0.18, 0.20), vec3(0.015, 0.02, 0.04), edge), intensity * pulse * (edge * 0.48 + (fog + 1.0) * 0.055));
}
"""
	_material.shader = shader
	_veil.material = _material
	add_child(_veil)
	_shadow = ShadowDrawing.new()
	add_child(_shadow)
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_audio.stream = _make_ambience()
	add_child(_audio)

func outdoor_intensity() -> float:
	if not is_instance_valid(player) or Coop.is_sleeping(player) or DayCycle.is_sleep_transition or DayCycle._is_passing_out:
		return 0.0
	var world := player.world_root()
	if not is_instance_valid(world):
		return 0.0
	var path := world.scene_file_path.to_lower()
	if "/interior/" in path or path.ends_with("/interior.tscn"):
		return 0.0
	return DayCycle.night_intensity()

func _process(delta: float) -> void:
	if _veil == null:
		return
	var target := outdoor_intensity()
	intensity = move_toward(intensity, target, delta * 0.6)
	_material.set_shader_parameter("intensity", intensity)
	_veil.visible = intensity > 0.001
	_audio.volume_db = lerpf(-45.0, -23.0, intensity)
	if target > 0.0 and not _audio.playing:
		_audio.play()
	elif target == 0.0:
		_audio.stop()
		_shadow.life = 0.0
		_event_timer = 18.0
	if target < 0.7:
		return
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = _rng.randf_range(22.0, 42.0)
		var size := get_viewport().get_visible_rect().size
		_shadow.location = Vector2(size.x * (0.12 if _rng.randf() < 0.5 else 0.88), size.y * _rng.randf_range(0.25, 0.7))
		_shadow.life = 1.6

func _make_ambience() -> AudioStreamWAV:
	# Seamless low wind/drone, generated once; no sharp jumps or loud stingers.
	const RATE := 11025
	const SECONDS := 8
	var samples := PackedByteArray()
	samples.resize(RATE * SECONDS * 2)
	for i in RATE * SECONDS:
		var t := float(i) / RATE
		var wind := sin(TAU * 63.0 * t + sin(TAU * 0.25 * t) * 2.0) * 0.24
		wind += sin(TAU * 91.0 * t) * (0.12 + 0.08 * sin(TAU * 0.125 * t))
		wind += sin(TAU * 177.0 * t + sin(TAU * 0.5 * t)) * 0.06
		samples.encode_s16(i * 2, int(wind * 16000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE * SECONDS
	return stream
