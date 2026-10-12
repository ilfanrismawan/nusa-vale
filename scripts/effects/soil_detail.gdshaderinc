uniform float soil_detail_strength : hint_range(0.0, 1.0) = 0.65;
uniform float soil_pebble_density : hint_range(0.0, 1.0) = 0.28;

float soil_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 detail_soil(vec4 base, vec2 world_position) {
	// Warm earth tones only; preserve vegetation, water, snow and dark outlines.
	float warm = smoothstep(0.025, 0.09, base.r - base.b);
	float earth = smoothstep(-0.01, 0.04, base.r - base.g);
	float lit = smoothstep(0.16, 0.32, base.r);
	float mask = warm * earth * lit * base.a;
	vec2 pixel = floor(world_position);
	float grain = soil_hash(pixel + 83.0);
	float grit = step(0.90, grain) * 0.045 - step(grain, 0.10) * 0.045;
	// Two scales of softly blended mottling avoid obvious square patches.
	vec2 patch_position = pixel / 29.0;
	vec2 cell = floor(patch_position);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(patch_position));
	float patch = mix(mix(soil_hash(cell), soil_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(soil_hash(cell + vec2(0.0, 1.0)), soil_hash(cell + vec2(1.0)), blend.x), blend.y);
	float mottling = (floor(patch * 5.0) / 5.0 - 0.4) * 0.075;
	vec2 pebble_cell = floor(pixel / 13.0);
	vec2 local = mod(pixel, 13.0);
	vec2 origin = vec2(3.0 + floor(soil_hash(pebble_cell + 13.0) * 6.0),
		3.0 + floor(soil_hash(pebble_cell + 47.0) * 6.0));
	vec2 p = local - origin;
	float present = step(soil_hash(pebble_cell + 91.0), soil_pebble_density);
	float pebble = float(p.y == 0.0 && p.x >= 0.0 && p.x <= 1.0);
	float shadow = float(p.y == 1.0 && p.x >= 0.0 && p.x <= 1.0);
	float detail = grit + mottling + present * (pebble * 0.095 - shadow * 0.065);
	vec3 textured = clamp(base.rgb + vec3(1.0, 0.82, 0.60) * detail * soil_detail_strength,
		vec3(0.0), vec3(1.0));
	return vec4(mix(base.rgb, textured, mask), base.a);
}
