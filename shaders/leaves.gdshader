// Whatever the season puts on the wind: leaves, petals or snowflakes.
// Stateless: every one's position is a pure function of TIME and its random
// seed (INSTANCE_CUSTOM), wrapped in a box around the player.
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;

#include "res://shaders/wind.gdshaderinc"

uniform vec3 box_size = vec3(38.0, 4.5, 30.0);
uniform vec3 color_a : source_color = vec3(0.86, 0.16, 0.1);
uniform vec3 color_b : source_color = vec3(0.98, 0.72, 0.18);
uniform float leaf_size = 0.2;
/// How many are in the air, 0..1.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
/// 0 = pointed leaf, 1 = round flake.
uniform float roundness : hint_range(0.0, 1.0) = 0.0;
/// How strongly the wind carries them: snow drifts far more slowly than leaves.
uniform float drift : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_color;

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	float phase = seed.x * 61.0;
	float speed = (1.8 + seed.x * 1.8) * wind_strength * drift;

	// Drift downwind with a lazy swirl, wrapping inside a box centred on the player.
	vec3 p = vec3(seed.y * box_size.x, 0.0, seed.w * box_size.z);
	p.xz += wind_dir() * speed * TIME;
	p.x += sin(TIME * 0.9 + phase) * 0.9;
	p.z += cos(TIME * 0.7 + phase * 1.3) * 0.9;
	vec2 half_box = box_size.xz * 0.5;
	p.xz = player_position.xz + mod(p.xz - player_position.xz + half_box, box_size.xz) - half_box;
	p.y = 0.45 + seed.z * box_size.y + sin(TIME * 1.3 + phase * 0.7) * 0.4;
	// The ones this season has no use for wait far below the ground.
	if (fract(seed.x * 13.7 + 0.31) >= amount) {
		p.y = -50.0;
	}

	// Tumble.
	float spin_a = TIME * (2.0 + seed.y * 3.0) + phase;
	float spin_b = TIME * (1.2 + seed.z * 2.0) + phase * 2.0;
	vec3 local = vec3(VERTEX.x, VERTEX.y, 0.0) * leaf_size * (0.7 + seed.w * 0.7);
	local = rot_y(rot_x(local, spin_a), spin_b);
	vec3 normal = rot_y(rot_x(vec3(0.0, 0.0, 1.0), spin_a), spin_b);

	// skip_vertex_transform: we hand back view-space values ourselves.
	VERTEX = (VIEW_MATRIX * vec4(p + local, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	v_color = mix(color_a, color_b, seed.z * seed.z) * (0.85 + seed.w * 0.3);
}

void fragment() {
	// Pointed-oval leaf silhouette with a darker midrib, rounding off into a
	// flake as `roundness` rises.
	vec2 q = UV * 2.0 - 1.0;
	float leaf_edge = (1.0 - q.y * q.y) * 0.6;
	float flake_edge = sqrt(max(0.7 - q.y * q.y, 0.0));
	if (abs(q.x) > mix(leaf_edge, flake_edge, roundness)) {
		discard;
	}
	ALBEDO = v_color * (0.8 + 0.2 * smoothstep(0.0, 0.25, abs(q.x))) * day_brightness;
}
