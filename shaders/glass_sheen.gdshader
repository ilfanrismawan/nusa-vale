shader_type canvas_item;

// Kilau diagonal yang lewat pelan di kaca terang (biru muda); rangka dan bata tidak terpengaruh.
// Pasang di material layer dinding kaca; atur lewat Shader Parameters di Inspector.
uniform vec4 sheen_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;
// Lebar pita kilau (0-1 dari satu periode).
uniform float band_width : hint_range(0.01, 0.5) = 0.08;
// Jarak antar pita dalam piksel dunia.
uniform float period = 260.0;
uniform float speed = 22.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float glass = smoothstep(0.08, 0.2, c.b - c.r) * smoothstep(0.6, 0.8, c.b);
	vec2 pixel = floor(world_pos);
	float phase = fract((pixel.x + pixel.y * 0.6 - TIME * speed) / period);
	float band = 1.0 - smoothstep(0.0, band_width, abs(phase - 0.5));
	c.rgb = mix(c.rgb, sheen_color.rgb, glass * band * strength);
	COLOR = c;
}
