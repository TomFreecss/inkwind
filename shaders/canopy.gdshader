// Tree foliage: lumpy spheres with three painted tones that lean and rustle in the wind.
// INSTANCE_CUSTOM.x = per-tree tint 0..1.
shader_type spatial;
render_mode world_vertex_coords, diffuse_toon, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 color_light : source_color = vec3(0.93, 0.4, 0.16);
uniform vec3 color_mid : source_color = vec3(0.76, 0.17, 0.11);
uniform vec3 color_dark : source_color = vec3(0.42, 0.07, 0.13);
uniform float fluff : hint_range(0.0, 0.6) = 0.22;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;

	// Leafy lumps: push the sphere surface in and out.
	float lump = fbm(VERTEX.xz * 1.9 + VERTEX.y * 1.3);
	VERTEX += NORMAL * (lump - 0.45) * fluff * 2.0;

	// Whole crown leans with the gusts...
	float gust = wind_gust(origin.xz, TIME);
	float lean = (0.05 + gust * 0.22) * wind_strength;
	float wobble = sin(TIME * 1.6 + origin.x * 0.7 + origin.z * 0.5);
	VERTEX.xz += wind_dir() * lean * (1.0 + 0.35 * wobble);
	// ...and the surface rustles.
	VERTEX += NORMAL * sin(TIME * 5.5 + dot(VERTEX, vec3(3.1, 2.7, 3.7))) * 0.018 * (0.4 + gust);

	v_world = VERTEX;
	v_normal = NORMAL;
	v_tint = INSTANCE_CUSTOM.x;
}

void fragment() {
	float keep = player_porthole(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX);
	if (keep < hash21(FRAGCOORD.xy)) {
		discard;
	}

	// Big painted patches of the three tones; tops lean lighter, undersides darker.
	float n = fbm(v_world.xz * 0.9 + v_world.y * 0.7);
	float tone = n + (v_normal.y - 0.5) * 0.2;
	vec3 col = mix(color_dark, color_mid, smoothstep(0.38, 0.5, tone));
	col = mix(col, color_light, smoothstep(0.58, 0.72, tone));
	col *= 0.82 + v_tint * 0.3;

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
