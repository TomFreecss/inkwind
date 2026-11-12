// Tree foliage: lumpy spheres with three painted tones that lean and rustle in the wind.
// INSTANCE_CUSTOM.x = per-tree tint 0..1.
shader_type spatial;
render_mode world_vertex_coords, diffuse_toon, specular_disabled;

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/canopy_shape.gdshaderinc"

uniform vec3 color_light : source_color = vec3(0.98, 0.58, 0.3);
uniform vec3 color_mid : source_color = vec3(0.9, 0.34, 0.2);
uniform vec3 color_dark : source_color = vec3(0.68, 0.2, 0.2);
uniform float fluff : hint_range(0.0, 0.6) = 0.22;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_tint;

void vertex() {
	VERTEX = canopy_shape(VERTEX, NORMAL, MODEL_MATRIX[3].xyz, fluff);
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
