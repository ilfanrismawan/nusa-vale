shader_type canvas_item;

#include "res://scripts/effects/water_detail.gdshaderinc"

varying vec2 water_position;
varying vec4 vertex_tint;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_tint = COLOR;
}

void fragment() {
	COLOR = detail_water(texture(TEXTURE, UV), water_position, TIME) * vertex_tint;
}
