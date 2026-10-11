uniform float water_detail_strength : hint_range(0.0, 1.0) = 0.7;
uniform float water_speed : hint_range(0.0, 2.0) = 0.65;
uniform float water_ripple_density : hint_range(0.0, 1.0) = 0.55;

float water_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 detail_water(vec4 base, vec2 world_position, float clock_time) {
	// Saturated blue water only: preserve banks, foam, transparency and winter ice.
	float blue = smoothstep(0.06, 0.18, base.b - max(base.r, base.g));
	float mask = blue * (1.0 - smoothstep(0.35, 0.55, base.r)) * base.a;
	vec2 pixel = floor(world_position);
	// Slow, stepped animation retains the original pixel-art cadence.
	float tick = floor(clock_time * water_speed * 6.0) / 6.0;
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
	vec3 detailed = clamp(base.rgb + water_detail_strength
		* (vec3(0.4, 0.85, 1.0) * depth + vec3(0.55, 0.85, 0.9) * (ripple + glint)),
		vec3(0.0), vec3(1.0));
	return vec4(mix(base.rgb, detailed, mask), base.a);
}
