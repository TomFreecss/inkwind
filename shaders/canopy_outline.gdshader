// Pencil outline for tree foliage: the crown drawn again, slightly inflated and
// inside out, in one flat ink colour. Runs as the foliage material's next pass.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_front, shadows_disabled;

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/canopy_shape.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.2, 0.12, 0.09);
/// Line thickness in metres.
uniform float width : hint_range(0.0, 0.15) = 0.04;
/// These three must match the foliage material.
uniform float fluff : hint_range(0.0, 0.6) = 0.22;
uniform bool see_through = true;
uniform bool fades_in_battle = false;

varying float v_fade;

void vertex() {
	v_fade = fades_in_battle ? battle_fade(MODEL_MATRIX[3].xyz) : 0.0;
	VERTEX = canopy_shape(VERTEX, NORMAL, MODEL_MATRIX[3].xyz, fluff) + NORMAL * width;
}

void fragment() {
	float dither = hash21(FRAGCOORD.xy);
	if (v_fade > dither) {
		discard;
	}
	if (see_through && player_porthole(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX) < dither) {
		discard;
	}
	ALBEDO = ink;
}
