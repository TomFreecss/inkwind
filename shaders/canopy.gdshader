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
/// How finely the three tones are broken up: higher for smaller plants.
uniform float patch_scale : hint_range(0.2, 4.0) = 0.9;
/// Open a window in the foliage when it stands between the camera and the
/// wanderer. Turn off for low things, like bushes, that never hide them.
uniform bool see_through = true;
/// Fade away when standing between the camera and a battle. For low things:
/// the battle camera leans in low, and even a bush can get in its way.
uniform bool fades_in_battle = false;
/// How much of this is there at all, 0..1. Lets a season take things away
/// (berries off the bushes) and bring them back gradually.
uniform float shown : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_tint;
varying float v_fade;

void vertex() {
	v_fade = max(1.0 - shown, fades_in_battle ? battle_fade(MODEL_MATRIX[3].xyz) : 0.0);
	VERTEX = canopy_shape(VERTEX, NORMAL, MODEL_MATRIX[3].xyz, fluff);
	v_world = VERTEX;
	v_normal = NORMAL;
	v_tint = INSTANCE_CUSTOM.x;
}

void fragment() {
	float dither = hash21(FRAGCOORD.xy);
	if (v_fade > dither) {
		discard;
	}
	if (see_through && player_porthole(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX) < dither) {
		discard;
	}

	// Big painted patches of the three tones; tops lean lighter, undersides darker.
	float n = fbm(v_world.xz * patch_scale + v_world.y * 0.7);
	float tone = n + (v_normal.y - 0.5) * 0.2;
	vec3 col = mix(color_dark, color_mid, smoothstep(0.38, 0.5, tone));
	col = mix(col, color_light, smoothstep(0.58, 0.72, tone));
	col *= 0.82 + v_tint * 0.3;

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
