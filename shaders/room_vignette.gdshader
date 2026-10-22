shader_type canvas_item;
render_mode unshaded;

// Gelap lembut di pinggir ruangan supaya fokus ke tengah toko.
uniform vec4 vignette_color : source_color = vec4(0.1, 0.04, 0.06, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.6;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.15;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float v = smoothstep(inner_radius, outer_radius, length(p));
	COLOR = vec4(vignette_color.rgb, v * strength);
}
