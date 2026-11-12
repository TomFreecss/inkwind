// Flower heads floating at grass-tip height; they sway exactly like the grass.
// INSTANCE_CUSTOM.rgb = colour (linear), INSTANCE_CUSTOM.a = random 0..1.
shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

varying vec3 v_color;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float gust;
	vec2 bend = grass_bend(vec3(origin.x, 0.0, origin.z), INSTANCE_CUSTOM.a, TIME, gust);
	VERTEX.xz += bend * origin.y;
	VERTEX.y -= dot(bend, bend) * origin.y * 0.45;
	VERTEX.y -= origin.y * 0.75 * clearing_amount(origin.xz);
	v_color = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
