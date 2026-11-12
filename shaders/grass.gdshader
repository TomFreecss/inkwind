// One blade of grass, drawn tens of thousands of times through a MultiMesh.
// INSTANCE_CUSTOM.x = random 0..1, INSTANCE_CUSTOM.y = 1 for tall grass.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.12, 0.3, 0.1);
uniform vec3 tip_color : source_color = vec3(0.42, 0.66, 0.2);
uniform vec3 dry_tip_color : source_color = vec3(0.74, 0.74, 0.32);
uniform vec3 tall_base_color : source_color = vec3(0.06, 0.21, 0.12);
uniform vec3 tall_tip_color : source_color = vec3(0.34, 0.6, 0.24);
uniform vec3 seed_color : source_color = vec3(0.93, 0.88, 0.64);
uniform vec3 gust_color : source_color = vec3(0.97, 0.96, 0.72);

varying float v_height;
varying float v_gust;
varying float v_rand;
varying float v_tall;
varying vec2 v_root;

void vertex() {
	// world_vertex_coords: VERTEX is already in world space here.
	vec3 root = MODEL_MATRIX[3].xyz;
	float blade_len = length(MODEL_MATRIX[1].xyz);
	float h = UV.y; // 0 at the root, 1 at the tip

	float gust;
	vec2 bend = grass_bend(root, INSTANCE_CUSTOM.x, TIME, gust);
	float curve = h * h;
	VERTEX.xz += bend * curve * blade_len;
	VERTEX.y -= dot(bend, bend) * curve * blade_len * 0.45;
	// Trampled flat inside a battle clearing (the ground is at y = 0).
	VERTEX.y *= 1.0 - 0.8 * clearing_amount(root.xz);

	v_height = h;
	v_gust = gust;
	v_rand = INSTANCE_CUSTOM.x;
	v_tall = INSTANCE_CUSTOM.y;
	v_root = root.xz;
}

void fragment() {
	// Same patch noise as the ground, so dry and lush areas line up.
	float patch = fbm(v_root * 0.11);
	float dry = smoothstep(0.5, 0.75, patch + (v_rand - 0.5) * 0.25);

	vec3 base = mix(base_color, tall_base_color, v_tall);
	vec3 tip = mix(mix(tip_color, dry_tip_color, dry), tall_tip_color, v_tall);
	vec3 col = mix(base, tip, pow(v_height, 1.3));
	// Pale seed heads make tall grass readable as its own kind of tile.
	col = mix(col, seed_color, smoothstep(0.8, 1.0, v_height) * v_tall * 0.85);
	// Gusts flash the tips: the bright bands that roll across the field.
	col = mix(col, gust_color, v_gust * v_height * v_height * 0.5);
	col *= 0.9 + v_rand * 0.2;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	// Light every blade as if it were flat ground: no flicker, clean tree shadows.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
