// Tree trunk: flat toon colour, with the same see-through porthole as the canopy.
// INSTANCE_CUSTOM.x = random 0..1 for a little variety.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.27, 0.18, 0.15);

varying float v_rand;

void vertex() {
	v_rand = INSTANCE_CUSTOM.x;
}

void fragment() {
	float keep = player_porthole(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX);
	if (keep < hash21(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo * (0.8 + v_rand * 0.4);
	ROUGHNESS = 1.0;
}
