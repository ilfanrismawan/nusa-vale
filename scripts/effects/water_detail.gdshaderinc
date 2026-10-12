uniform float water_detail_strength : hint_range(0.0, 1.0) = 0.7;
uniform float water_speed : hint_range(0.0, 2.0) = 0.65;
uniform float water_ripple_density : hint_range(0.0, 1.0) = 0.55;
uniform float water_clarity : hint_range(0.0, 1.0) = 0.62;
uniform float water_caustic_strength : hint_range(0.0, 1.0) = 0.55;
uniform float water_stone_density : hint_range(0.0, 1.0) = 0.42;

float water_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0)), blend.x), blend.y);
}

vec4 detail_water(vec4 base, vec2 world_position, float clock_time) {
	// Saturated blue water only: preserve banks, foam, transparency and winter ice.
	float blue = smoothstep(0.06, 0.18, base.b - max(base.r, base.g));
	float mask = blue * (1.0 - smoothstep(0.35, 0.55, base.r)) * base.a;
	vec2 pixel = floor(world_position);
	// Slow, stepped animation retains the original pixel-art cadence.
	float tick = floor(clock_time * water_speed * 6.0) / 6.0;
	// An opaque, blue-tinted riverbed suggests clear water even without a ground layer.
	// Only its apparent refraction moves; the stones remain anchored in world space.
	vec2 bed_pixel = floor(pixel + vec2(sin(pixel.y * 0.065 + tick),
		cos(pixel.x * 0.055 + tick * 0.8)) * 0.8);
	float bed_depth = water_noise(pixel / 64.0);
	float sand = floor(water_noise(bed_pixel / 5.0) * 5.0) / 5.0;
	vec3 bed = mix(vec3(0.16, 0.38, 0.43), vec3(0.38, 0.58, 0.56), sand);
	bed += (water_hash(bed_pixel) - 0.5) * 0.035;
	vec2 stone_cell = floor(bed_pixel / vec2(31.0, 27.0));
	vec2 stone_local = mod(bed_pixel, vec2(31.0, 27.0));
	float stone_seed = water_hash(stone_cell + 101.0);
	vec2 stone_center = vec2(8.0 + floor(water_hash(stone_cell + 13.0) * 14.0),
		7.0 + floor(water_hash(stone_cell + 47.0) * 12.0));
	vec2 stone_delta = stone_local - stone_center;
	vec2 stone_size = vec2(3.0 + floor(stone_seed * 4.0), 2.0 + floor(stone_seed * 3.0));
	float rock_shape = dot(stone_delta / stone_size, stone_delta / stone_size);
	float stone = (1.0 - step(1.0, rock_shape)) * step(stone_seed, water_stone_density);
	float rock_shade = floor(clamp(0.5 - stone_delta.y / (stone_size.y * 3.0), 0.0, 1.0) * 3.0) / 3.0;
	vec3 rock = mix(vec3(0.18, 0.33, 0.39), vec3(0.43, 0.57, 0.59), rock_shade);
	bed = mix(bed, rock, stone * 0.8);
	float clarity = water_clarity * mix(0.8, 0.42, bed_depth);
	vec3 clear_water = mix(base.rgb, bed, clarity);
	// Intersecting, quantized light bands simulate sunlight on the submerged bed.
	vec2 light_position = pixel + vec2(water_noise(pixel / 18.0) * 9.0);
	float light_a = sin(light_position.x * 0.22 + light_position.y * 0.12 + tick * 0.7);
	float light_b = sin(light_position.x * -0.13 + light_position.y * 0.25 - tick * 0.55);
	float caustic = step(0.89, light_a) * 0.055 + step(0.92, light_b) * 0.045;
	clear_water += vec3(0.55, 0.92, 1.0) * caustic * water_caustic_strength;
	float broad_wave = sin(pixel.x * 0.045 + pixel.y * 0.075 + tick * 0.7);
	float cross_wave = sin(pixel.x * 0.025 - pixel.y * 0.11 - tick * 0.5);
	float depth = floor((broad_wave + cross_wave) * 2.0) * 0.009;
	vec2 cell = floor(pixel / vec2(19.0, 11.0));
	float seed = water_hash(cell);
	vec2 local = mod(pixel, vec2(19.0, 11.0));
	float drift = floor(sin(tick + seed * 6.28318) * 2.0);
	vec2 origin = vec2(5.0 + floor(water_hash(cell + 17.0) * 7.0) + drift,
		3.0 + floor(water_hash(cell + 43.0) * 4.0));
	vec2 p = local - origin;
	float length = 2.0 + floor(water_hash(cell + 29.0) * 3.0);
	float line = float(p.y == 0.0 && abs(p.x) <= length);
	float echo = float(p.y == 2.0 && p.x >= -1.0 && p.x <= 1.0);
	float active = step(seed, water_ripple_density);
	float pulse = smoothstep(0.1, 0.8, 0.5 + 0.5 * sin(tick * 1.2 + seed * 6.28318));
	float ripple = active * pulse * (line * 0.11 + echo * 0.035);
	float glint = float(p.y == -1.0 && p.x == -1.0) * active
		* step(0.94, sin(tick * 0.8 + seed * 31.0)) * 0.16;
	vec3 detailed = clamp(clear_water + water_detail_strength
		* (vec3(0.4, 0.85, 1.0) * depth + vec3(0.55, 0.85, 0.9) * (ripple + glint)),
		vec3(0.0), vec3(1.0));
	return vec4(mix(base.rgb, detailed, mask), base.a);
}
