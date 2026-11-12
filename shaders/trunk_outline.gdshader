// Pencil outline for tree trunks: the trunk drawn again, slightly inflated and
// inside out, in one flat ink colour. Runs as the trunk material's next pass.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.2, 0.12, 0.09);
/// Line thickness in metres.
uniform float width : hint_range(0.0, 0.15) = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	float keep = player_porthole(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX);
	if (keep < hash21(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = ink;
}
