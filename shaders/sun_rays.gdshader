shader_type canvas_item;
render_mode blend_add, unshaded;

// Berkas sinar matahari dari atas layar untuk area luar. Dipasang per layar pemain
// oleh weather_view.gd jika area punya SkyFX; warna, sudut, dan kekuatan diatur dari jam.
uniform vec4 ray_color : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.12;
// Kemiringan berkas (negatif = ke kiri).
uniform float angle = 0.35;
uniform float density = 9.0;
uniform float speed = 0.05;
// Seberapa jauh berkas turun dari atas layar.
uniform float reach : hint_range(0.1, 1.0) = 0.75;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	float x = UV.x - UV.y * angle;
	float rays = noise1(x * density + TIME * speed) * noise1(x * density * 2.7 - TIME * speed * 1.6);
	rays = smoothstep(0.15, 0.6, rays);
	float fade = 1.0 - smoothstep(0.0, reach, UV.y);
	COLOR = vec4(ray_color.rgb * rays * fade * intensity, 1.0);
}
