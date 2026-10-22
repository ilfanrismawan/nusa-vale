shader_type canvas_item;

// Lantai kayu yang sudah lama dipakai: noda dan kotoran halus per blok piksel.
// Pasang di material TileMapLayer lantai; atur kekuatan lewat Shader Parameters.
uniform vec4 grime_color : source_color = vec4(0.3, 0.17, 0.12, 1.0);
// Ukuran blok noise dalam piksel dunia (2 = tetap terasa pixel art).
uniform float block_size = 2.0;
uniform float grime_strength : hint_range(0.0, 0.5) = 0.1;
uniform float stain_strength : hint_range(0.0, 0.5) = 0.16;
// Besar noda (makin besar makin lebar).
uniform float stain_scale = 28.0;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	vec2 cell = floor(world_pos / block_size) * block_size;
	float speck = step(0.6, hash(cell)) * hash(cell + 7.0);
	float stain = smoothstep(0.55, 0.85, noise(cell / stain_scale));
	float amount = clamp(grime_strength * speck + stain_strength * stain, 0.0, 0.6);
	c.rgb = mix(c.rgb, c.rgb * grime_color.rgb * 2.2, amount);
	COLOR = c;
}
