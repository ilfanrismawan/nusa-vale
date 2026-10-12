shader_type canvas_item;

#include "res://scripts/effects/soil_detail.gdshaderinc"

varying vec2 soil_position;
varying vec4 vertex_tint;

void vertex() {
	soil_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_tint = COLOR;
}

void fragment() {
	COLOR = detail_soil(texture(TEXTURE, UV), soil_position) * vertex_tint;
}
