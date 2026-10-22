shader_type canvas_item;
render_mode blend_add, unshaded;

// Berkas cahaya jendela yang jatuh ke lantai. Atur ukuran lewat ColorRect,
// warna dan kekuatan lewat Shader Parameters di Inspector.
uniform vec4 shaft_color : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.22;
// Lebar berkas di atas (dekat jendela) dibanding di bawah.
uniform float top_width : hint_range(0.1, 1.0) = 0.6;
// Kemiringan berkas (negatif = ke kiri).
uniform float slant : hint_range(-0.5, 0.5) = 0.15;
uniform float edge_softness : hint_range(0.01, 0.5) = 0.22;
uniform float shimmer_speed = 0.6;
uniform float shimmer_amount : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	vec2 uv = UV;
	float width = mix(top_width, 1.0, uv.y);
	float center = 0.5 - slant * 0.5 + slant * uv.y;
	float d = abs(uv.x - center) / (width * 0.5);
	float side = 1.0 - smoothstep(1.0 - edge_softness * 2.0, 1.0, d);
	float fade = smoothstep(0.0, 0.12, uv.y) * (1.0 - smoothstep(0.5, 1.0, uv.y));
	float streak = 1.0 - shimmer_amount + shimmer_amount * sin((uv.x - uv.y * slant) * 38.0 + TIME * shimmer_speed);
	COLOR = vec4(shaft_color.rgb * intensity * side * fade * streak, 1.0);
}
