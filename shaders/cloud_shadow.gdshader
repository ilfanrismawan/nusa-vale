shader_type canvas_item;
render_mode blend_mul, unshaded;

// Bayangan awan yang melintas di tanah. Dipasang oleh SkyFX (scripts/effects/sky_fx.gd);
// polanya memakai koordinat world, jadi diam di tanah saat kamera bergerak.
uniform sampler2D noise : repeat_enable, filter_linear;
// Banyaknya awan: 0 = langit bersih, 1 = hampir seluruhnya tertutup.
uniform float coverage : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.01, 0.5) = 0.14;
// Diatur SkyFX dari jam (0 saat malam).
uniform float darkness : hint_range(0.0, 1.0) = 0.25;
// Kecepatan angin dalam piksel per detik.
uniform vec2 wind = vec2(14.0, 5.0);
// Kecil = awan besar.
uniform float scale = 0.0016;
uniform vec4 shadow_color : source_color = vec4(0.55, 0.62, 0.78, 1.0);
// Tepi bayangan dibulatkan ke grid ini agar tetap pixel-art.
uniform float pixel_snap = 2.0;
// Bayangan mulai tampak dari world y fade_y.x dan penuh di fade_y.y
// (untuk scene yang punya langit di bagian atas, misalnya hill). x = y = 0 berarti tanpa fade.
uniform vec2 fade_y = vec2(0.0, 0.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 wp = floor(world_pos / pixel_snap) * pixel_snap;
	vec2 p = (wp + wind * TIME) * scale;
	float n = texture(noise, p).r * 0.65 + texture(noise, p * 2.3 + 0.37).r * 0.35;
	float t = 1.0 - coverage;
	float cloud = smoothstep(t, t + softness, n);
	if (fade_y.y > fade_y.x) {
		cloud *= smoothstep(fade_y.x, fade_y.y, wp.y);
	}
	COLOR = vec4(mix(vec3(1.0), shadow_color.rgb, cloud * darkness), 1.0);
}
