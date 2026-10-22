shader_type canvas_item;

// Layar horor malam (GDD 4.1). Nilai diatur dari scripts/effects/night_horror.gd;
// kekuatan tiap efek diatur di Inspector node NightHorror (grup "Layar").
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float intensity = 0.0;   // gelap malam di luar ruangan, 0..1
uniform float midnight = 0.0;    // 0 sebelum 00.00, naik ke 1 menjelang 05.00
uniform float fear = 0.0;        // rasa takut pemain, 0..1
uniform float beat = 0.0;        // 1 saat detak jantung, lalu meluruh
uniform float glitch = 0.0;      // 1 saat kejadian besar, lalu meluruh

uniform float fog_amount = 1.0;
uniform float desaturate_amount = 0.55;
uniform float grain_amount = 0.08;
uniform float aberration_px = 1.5;
uniform float red_pulse_amount = 0.5;
uniform float glitch_amount = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float g = glitch * glitch_amount;

	// Glitch: potongan horizontal bergeser.
	if (g > 0.0) {
		float row = floor(uv.y * 54.0);
		float n = hash(vec2(row, floor(TIME * 30.0)));
		if (n > 0.72) {
			uv.x += (n - 0.86) * 0.08 * g;
		}
	}

	// Chromatic aberration: tipis saat tengah malam, melebar saat takut / glitch.
	float split = aberration_px * (midnight * 0.35 + fear * 0.65) + g * 4.0;
	vec2 px = vec2(SCREEN_PIXEL_SIZE.x * split, 0.0);
	vec3 col;
	col.r = texture(screen_tex, uv + px).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - px).b;

	// Warna memudar setelah 00.00 (sedikit kebiruan).
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.9, 1.0, 1.06), desaturate_amount * midnight);

	// Film grain per piksel, berganti 24x per detik.
	float n = hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * vec2(17.0, 31.0));
	col += (n - 0.5) * grain_amount * clamp(midnight * 0.7 + fear * 0.6 + g, 0.0, 1.4);

	// Kabut + vinyet gelap (efek lama).
	vec2 v = UV;
	float edge = smoothstep(0.18, 0.72, length((v - vec2(0.5)) * vec2(1.1, 1.0)));
	float fog = sin(v.x * 14.0 + v.y * 8.0 + TIME * 0.22) * sin(v.y * 17.0 - TIME * 0.17);
	float pulse = 0.97 + sin(TIME * 0.8) * 0.03;
	vec3 veil = mix(vec3(0.11, 0.18, 0.20), vec3(0.015, 0.02, 0.04), edge);
	float veil_a = intensity * pulse * (edge * 0.48 + (fog + 1.0) * 0.055) * fog_amount;
	col = mix(col, veil, clamp(veil_a, 0.0, 1.0));

	// Denyut merah di tepi layar mengikuti detak jantung.
	float red_edge = smoothstep(0.32, 0.8, length((v - vec2(0.5)) * vec2(1.1, 1.0)));
	float red = red_pulse_amount * fear * (0.3 + beat * 0.7) * red_edge;
	col = mix(col, vec3(0.32, 0.0, 0.02), clamp(red, 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
