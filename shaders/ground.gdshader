// Painted ground: meadow, dirt path and pond blended from a one-pixel-per-tile mask.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"

// R = path, G = tall grass, B = water. One texel per tile, linear filtered.
uniform sampler2D tile_mask : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(40.0, 28.0);

uniform vec3 grass_dark : source_color = vec3(0.13, 0.27, 0.1);
uniform vec3 grass_light : source_color = vec3(0.33, 0.47, 0.16);
uniform vec3 dirt_dark : source_color = vec3(0.55, 0.42, 0.29);
uniform vec3 dirt_light : source_color = vec3(0.76, 0.62, 0.43);
uniform vec3 water_deep : source_color = vec3(0.15, 0.37, 0.5);
uniform vec3 water_shallow : source_color = vec3(0.38, 0.64, 0.67);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = v_world.xz;

	// Wobble the lookup so tile borders look brushed in by hand, not ruled.
	vec2 wobble = vec2(fbm(wp * 0.8), fbm(wp * 0.8 + 43.0)) - 0.5;
	vec4 mask = texture(tile_mask, (wp + wobble * 0.6) / map_size);

	// Meadow: big patches of colour plus directional brush streaks.
	float patch = fbm(wp * 0.11);
	vec3 col = mix(grass_dark, grass_light, patch);
	col *= 0.9 + fbm(wp * vec2(1.6, 5.0)) * 0.2;
	col = mix(col, grass_dark * 0.75, mask.g * 0.6);

	// Dirt path.
	vec3 dirt = mix(dirt_dark, dirt_light, fbm(wp * 0.6 + 7.0));
	dirt *= 0.93 + fbm(wp * vec2(4.0, 1.2)) * 0.14;
	col = mix(col, dirt, smoothstep(0.4, 0.54, mask.r));

	// Pond: muddy bank, then water with drifting highlight strokes.
	float water = smoothstep(0.42, 0.58, mask.b);
	float bank = smoothstep(0.15, 0.42, mask.b);
	col = mix(col, dirt_dark * 0.8, bank);
	vec3 wcol = mix(water_deep, water_shallow, fbm(wp * 0.35 + vec2(TIME * 0.05, 0.0)));
	float glint = smoothstep(0.7, 0.78, value_noise(vec2(wp.x * 0.8 + TIME * 0.25, wp.y * 4.0)));
	wcol = mix(wcol, vec3(0.92, 0.97, 1.0), glint * 0.6);
	col = mix(col, wcol, water);

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
