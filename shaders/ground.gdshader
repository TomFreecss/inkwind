// Painted ground: meadow, dirt path, sandy beach and lake.
// Paths and tall grass come from a one-pixel-per-tile mask; the beach and the
// water come from a field holding the distance to the waterline.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/wind.gdshaderinc"

// R = path, G = tall grass. One texel per tile, linear filtered.
uniform sampler2D tile_mask : filter_linear, repeat_disable;
// Signed distance to the waterline in tiles: positive in the water.
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(40.0, 28.0);
// Tiles of sand between the waterline and the meadow.
uniform float beach_width = 0.8;

uniform vec3 grass_dark : source_color = vec3(0.36, 0.58, 0.22);
uniform vec3 grass_light : source_color = vec3(0.6, 0.77, 0.32);
uniform vec3 dirt_dark : source_color = vec3(0.74, 0.6, 0.42);
uniform vec3 dirt_light : source_color = vec3(0.89, 0.77, 0.55);
uniform vec3 sand_dry : source_color = vec3(0.94, 0.87, 0.68);
uniform vec3 sand_wet : source_color = vec3(0.74, 0.64, 0.47);
uniform vec3 water_shallow : source_color = vec3(0.62, 0.87, 0.84);
uniform vec3 water_mid : source_color = vec3(0.3, 0.68, 0.8);
uniform vec3 water_deep : source_color = vec3(0.17, 0.49, 0.72);
uniform vec3 foam_color : source_color = vec3(0.96, 0.98, 0.97);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Scattered brush dashes lying across the wind: wave crests. Each cell of a
// grid that drifts downwind may hold one tapered, slightly bowed stroke, which
// swells and fades on its own clock and comes back somewhere else.
// `flow` is (downwind, across the wind) in tiles; `cell` is the grid spacing.
float wave_dashes(vec2 flow, vec2 cell, float speed, float density, float seed) {
	vec2 p = vec2(flow.x - TIME * speed, flow.y) / cell;
	p.y += floor(p.x) * 0.37;  // stagger the rows so the strokes never line up
	vec2 id = floor(p) + seed;
	float clock = TIME * (0.1 + hash21(id) * 0.1) + hash21(id + 3.1);
	vec2 life = id + floor(clock) * 7.7;  // a different stroke each time round
	if (hash21(life + 11.0) > density) {
		return 0.0;
	}
	vec2 q = fract(p) - 0.5;
	q -= (vec2(hash21(life + 5.0), hash21(life + 9.0)) - 0.5) * vec2(0.5, 0.2);
	float along = q.y / (0.16 + hash21(life + 2.0) * 0.2);  // -1..1 from tip to tip
	float taper = 1.0 - along * along;
	if (taper <= 0.0) {
		return 0.0;
	}
	q.x += along * along * 0.12 - 0.06;  // bow it like a crest
	float thickness = 0.13 * taper;
	float stroke = 1.0 - smoothstep(thickness * 0.5, thickness, abs(q.x));
	return stroke * sin(fract(clock) * 3.14159);
}

// The lake at `wp`, `depth` tiles in from the waterline as it stands right now
// (`shore` is the distance from its resting position). Everything moves with
// the same wind as the grass.
vec3 paint_water(vec2 wp, float shore, float depth) {
	vec2 dir = wind_dir();
	// x runs downwind, y across the wind.
	vec2 flow = vec2(dot(wp, dir), dot(wp, vec2(-dir.y, dir.x)));

	// Washes of colour from the shallows to the middle, with a slow drift so
	// the bands never sit still.
	float wash = depth + (fbm(wp * 0.45 + vec2(TIME * 0.03, 0.0)) - 0.5) * 0.7
			* smoothstep(0.2, 1.0, depth);
	vec3 col = mix(water_shallow, water_mid, smoothstep(0.05, 0.9, wash));
	col = mix(col, water_deep, smoothstep(0.8, 2.6, wash));

	// Soft swells of light and shade travelling downwind, in two layers moving
	// at different speeds.
	float swell = value_noise(vec2(flow.x * 2.4 - TIME * 0.9, flow.y * 0.6)) * 0.6
			+ value_noise(vec2(flow.x * 3.7 - TIME * 1.9, flow.y * 0.95 + 20.0)) * 0.4;
	col *= 0.88 + swell * 0.24;

	// White crests away from the shore, brighter where a gust is crossing the
	// lake: the same gusts that comb the grass.
	float crests = wave_dashes(flow, vec2(0.55, 1.5), 0.4, 0.55, 0.0)
			+ wave_dashes(flow, vec2(0.4, 1.0), 0.65, 0.4, 37.0);
	float open_water = smoothstep(0.25, 0.9, depth);
	col = mix(col, foam_color,
			min(crests, 1.0) * open_water * (0.45 + wind_gust(wp, TIME) * 0.55));

	// Thin wave lines that follow the outline of the shore and roll in to it.
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(fract(shore * 2.4 + TIME * 0.35) - 0.5));
	ring *= (1.0 - smoothstep(0.15, 0.95, shore)) * smoothstep(0.02, 0.15, depth);
	ring *= smoothstep(0.4, 0.7, value_noise(wp * 1.3 + vec2(0.0, TIME * 0.1)));
	col = mix(col, foam_color, ring * 0.5);

	// At the very edge the water is thin enough to show the sand through it,
	// and ends in a line of foam.
	col = mix(sand_wet, col, 0.35 + 0.65 * smoothstep(0.0, 0.4, depth));
	float edge_foam = 1.0 - smoothstep(0.05, 0.11, depth);
	edge_foam *= 0.65 + 0.35 * value_noise(wp * 6.0 + TIME * 0.3);
	return mix(col, foam_color, edge_foam);
}

void fragment() {
	vec2 wp = v_world.xz;

	// Wobble the lookups so borders look brushed in by hand, not ruled.
	vec2 wobble = vec2(fbm(wp * 0.8), fbm(wp * 0.8 + 43.0)) - 0.5;
	vec4 mask = texture(tile_mask, (wp + wobble * 0.6) / map_size);
	float shore = texture(shore_field, (wp + wobble * 0.3) / map_size).r;

	// Meadow: big patches of colour plus directional brush streaks.
	float patch = fbm(wp * 0.11);
	vec3 col = mix(grass_dark, grass_light, patch);
	col *= 0.9 + fbm(wp * vec2(1.6, 5.0)) * 0.2;
	col = mix(col, grass_dark * 0.75, mask.g * 0.6);

	// Dirt path.
	vec3 dirt = mix(dirt_dark, dirt_light, fbm(wp * 0.6 + 7.0));
	dirt *= 0.93 + fbm(wp * vec2(4.0, 1.2)) * 0.14;
	col = mix(col, dirt, smoothstep(0.4, 0.54, mask.r));

	// Beach and lake. `inland` is the distance in from the ragged line where
	// the turf stops; nothing here is needed out in the meadow.
	float inland = shore + beach_width + (fbm(wp * 2.1 + 11.0) - 0.5) * 0.3;
	if (inland > -0.15) {
		vec3 sand = mix(sand_dry * 0.9, sand_dry, fbm(wp * 0.7 + 3.0));
		sand *= 0.95 + value_noise(wp * 13.0) * 0.1;
		// A strip of shade under the overhanging turf.
		float turf_shade = smoothstep(-0.1, 0.05, inland) * (1.0 - smoothstep(0.05, 0.25, inland));
		sand *= mix(vec3(1.0), vec3(0.72, 0.7, 0.62), turf_shade);
		// Sand the water keeps reaching stays dark.
		sand = mix(sand, sand_wet, smoothstep(-0.26, -0.04, shore) * 0.85);
		col = mix(col, sand, smoothstep(-0.1, 0.1, inland));

		// The waterline breathes in and out, at a different moment along each
		// stretch of shore.
		float waterline = shore + sin(TIME * 0.8 + fbm(wp * 0.22) * 9.0) * 0.07;
		if (waterline > 0.0) {
			vec3 water = paint_water(wp, shore, waterline);
			col = mix(col, water, smoothstep(0.0, 0.025, waterline));
		}
	}

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
