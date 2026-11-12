// The wanderer's scarf: a strip anchored at the neck that always streams downwind.
// UV.x runs from the knot (0) to the loose end (1).
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.85, 0.12, 0.14);
uniform float length_m = 0.8;
uniform float width_m = 0.12;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec2 dir = wind_dir();
	vec3 forward = vec3(dir.x, 0.0, dir.y);
	vec3 side = vec3(-dir.y, 0.0, dir.x);
	float gust = wind_gust(anchor.xz, TIME);

	float s = UV.x;
	float along = s * length_m;
	vec3 wp = anchor + forward * along;
	wp += side * sin(s * 7.0 - TIME * (7.0 + gust * 5.0)) * 0.07 * s;
	// Droops in calm air, lifts in a gust.
	wp.y += -along * along * (0.55 - gust * 0.4) + cos(s * 5.0 - TIME * 6.0) * 0.03 * s;
	wp.y += (UV.y - 0.5) * width_m * (1.0 - s * 0.35);

	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(side, 0.0)).xyz);
}

void fragment() {
	ALBEDO = albedo * (0.85 + 0.15 * UV.y);
}
