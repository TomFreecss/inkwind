// Flower heads floating at grass-tip height; they sway exactly like the grass.
// INSTANCE_CUSTOM.rgb = colour (linear), INSTANCE_CUSTOM.a = random 0..1.
shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

/// How many of the flowers are out, 0..1: all of them in spring, none in winter.
uniform float abundance : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_color;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	// Each flower has its own place in the queue; the late ones stay underground.
	if (fract(INSTANCE_CUSTOM.a * 7.31 + 0.137) >= abundance) {
		VERTEX = vec3(origin.x, -5.0, origin.z);
	}
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
