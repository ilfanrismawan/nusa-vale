shader_type canvas_item;

#include "res://scripts/effects/water_detail.gdshaderinc"
#include "res://scripts/effects/soil_detail.gdshaderinc"

// World coordinates keep the pattern continuous across tiles and camera movement.
varying vec2 ground_position;
varying vec4 vertex_tint;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.65;
uniform float tuft_density : hint_range(0.0, 1.0) = 0.58;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 pixel = floor(ground_position);
	// Exclude soil, water, outlines, and snow, including seasonal atlas swaps.
	float green = smoothstep(0.025, 0.09, base.g - max(base.r, base.b));
	float midtone = smoothstep(0.12, 0.25, base.g);
	float mask = green * midtone * base.a;
	vec2 cell = floor(pixel / 7.0);
	vec2 local = mod(pixel, 7.0);
	float seed = hash(cell);
	vec2 origin = vec2(1.0 + floor(hash(cell + 19.0) * 3.0), 3.0 + floor(hash(cell + 37.0) * 2.0));
	vec2 blade = local - origin;
	// Three short staggered blades with a darker root, all on the pixel grid.
	float tips = float((blade.x == 0.0 && blade.y >= -2.0 && blade.y <= 0.0)
		|| (blade.x == -1.0 && blade.y == -1.0)
		|| (blade.x == 1.0 && blade.y == -2.0));
	float roots = float(blade.y == 1.0 && abs(blade.x) <= 1.0);
	float patch = hash(floor(pixel / 35.0));
	float tuft = step(seed, tuft_density * mix(0.45, 1.0, patch));
	float grain = hash(pixel + 71.0);
	float fleck = step(0.96, grain) * 0.07 - step(grain, 0.035) * 0.05;
	float variation = (patch - 0.5) * 0.045;
	float detail = variation + fleck + tuft * (tips * 0.13 - roots * 0.085);
	vec3 grass = clamp(base.rgb + vec3(0.65, 1.0, 0.45) * detail * detail_strength, vec3(0.0), vec3(1.0));
	vec4 ground = vec4(mix(base.rgb, grass, mask), base.a);
	ground = detail_soil(ground, ground_position);
	COLOR = detail_water(ground, ground_position, TIME) * vertex_tint;
}
