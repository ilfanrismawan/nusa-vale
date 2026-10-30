shader_type canvas_item;
// Kaca cair (liquid glass): latar dunia diburamkan, dibengkokkan di tepi seperti lensa,
// diberi kilau atas, bingkai terang, bayangan, dan pendar saat dipilih.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 rect_size = vec2(120.0, 120.0);
uniform float padding = 14.0;
uniform float corner_radius = 999.0;
uniform float blur : hint_range(0.0, 6.0) = 2.6;
uniform float refraction : hint_range(0.0, 0.6) = 0.18;
uniform float brightness : hint_range(0.5, 2.0) = 1.12;
uniform vec4 tint : source_color = vec4(0.80, 0.90, 1.0, 0.20);
uniform float highlight : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.80);
uniform float rim_width = 1.6;
uniform vec2 light_dir = vec2(-0.35, -1.0);
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.32;
uniform vec2 shadow_offset = vec2(0.0, 6.0);
uniform float shadow_softness = 12.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.55, 0.85);

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = max(rect_size * 0.5 - vec2(padding), vec2(1.0));
	vec2 p = (UV - 0.5) * rect_size;
	float r = min(corner_radius, min(half_size.x, half_size.y));
	float d = sd_box(p, half_size, r);
	float aa = max(fwidth(d), 0.001);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float short_side = min(half_size.x, half_size.y);
	float depth = clamp(-d / short_side, 0.0, 1.0);
	vec2 n = normalize(p + vec2(0.0001));
	float bend = pow(1.0 - depth, 2.5) * refraction * short_side;
	vec2 suv = SCREEN_UV - n * bend * SCREEN_PIXEL_SIZE;
	vec3 scene = textureLod(screen_texture, suv, blur).rgb * brightness;
	vec3 glass = mix(scene, tint.rgb, tint.a);
	float top = clamp((p.y + half_size.y) / (half_size.y * 2.0), 0.0, 1.0);
	glass += vec3(highlight * smoothstep(0.55, 0.0, top));
	float rim = 1.0 - smoothstep(0.0, rim_width, -d);
	float lit = 0.55 + 0.45 * dot(n, -normalize(light_dir));
	glass = mix(glass, rim_color.rgb, clamp(rim * rim_color.a * lit, 0.0, 1.0));
	glass = mix(glass, glow_color.rgb, glow * rim * 0.7);
	float sd = sd_box(p - shadow_offset, half_size, r);
	float shadow = shadow_alpha * (1.0 - smoothstep(-shadow_softness * 0.3, shadow_softness, sd));
	float halo = d > 0.0 ? clamp(glow * glow_color.a * exp(-d / (padding * 0.45 + 0.001)), 0.0, 1.0) : 0.0;
	// Pendar dan bayangan harus habis sebelum tepi node; kalau tidak, ujungnya terpotong
	// lurus dan tampak seperti kotak di sekeliling kaca bundar (terlihat saat hover).
	float fade = 1.0 - smoothstep(padding * 0.55, padding * 0.95, d);
	vec2 edge = rect_size * 0.5 - abs(p);
	fade *= smoothstep(0.0, 2.0, min(edge.x, edge.y));
	halo *= fade;
	shadow *= fade;
	float alpha = halo + shadow * (1.0 - halo);
	vec3 outside = alpha > 0.0 ? glow_color.rgb * halo / alpha : vec3(0.0);
	COLOR = mix(vec4(outside, alpha), vec4(glass, 1.0), inside);
}
