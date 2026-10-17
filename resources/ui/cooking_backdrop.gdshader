shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 3.5;
uniform vec4 top_tint : source_color = vec4(0.0, 0.0, 0.0, 0.94);
uniform vec4 bottom_tint : source_color = vec4(0.28, 0.37, 0.26, 0.80);
void fragment() {
	vec4 scene = textureLod(screen_texture, SCREEN_UV, blur_amount);
	vec4 tint = mix(top_tint, bottom_tint, smoothstep(0.1, 1.0, UV.y));
	COLOR = vec4(mix(scene.rgb, tint.rgb, tint.a), 1.0);
}
