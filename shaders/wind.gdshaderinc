// Wind shared by everything that moves: grass, flowers, canopies, leaves, cloth.
// The three globals live in Project Settings > Shader Globals.

#include "res://shaders/noise.gdshaderinc"

global uniform vec2 wind_direction;
global uniform float wind_strength;
global uniform vec3 player_position;
// A battle tramples a clearing in the grass. Radius 0 = no clearing.
global uniform vec3 clearing_center;
global uniform float clearing_radius;
// 1 in daylight, lower at night. Unlit things (leaves, cloth, wind streaks)
// multiply their colour by it so they dim with everything else.
global uniform float day_brightness;

// How far a grass tip leans, in blade lengths, at full gust.
const float GRASS_SWAY = 0.38;

vec2 wind_dir() {
	return normalize(wind_direction + vec2(0.0001, 0.0));
}

// 0..1: how flattened the ground cover is by the battle clearing at this spot.
// The edge is ragged so it reads as trampled grass, not a compass circle.
float clearing_amount(vec2 world_xz) {
	if (clearing_radius < 0.01) {
		return 0.0;
	}
	float dist = length(world_xz - clearing_center.xz) + (value_noise(world_xz * 1.7) - 0.5) * 0.5;
	return 1.0 - smoothstep(clearing_radius * 0.72, clearing_radius, dist);
}

// Gust intensity 0..1 at a world XZ position: wide bands rolling downwind.
float wind_gust(vec2 world_xz, float time) {
	vec2 p = world_xz - wind_dir() * time * 3.2;
	float broad = value_noise(p * 0.07);
	float detail = value_noise(p * 0.23 + 31.7);
	return smoothstep(0.3, 0.85, broad * 0.75 + detail * 0.35);
}

// Horizontal lean (in blade lengths) for anything rooted at `root`:
// steady lean + gusts + flutter, plus being pushed aside by the player.
vec2 grass_bend(vec3 root, float rnd, float time, out float gust) {
	gust = wind_gust(root.xz, time);
	vec2 dir = wind_dir();
	vec2 side = vec2(-dir.y, dir.x);
	float flutter = sin(time * (2.4 + rnd * 1.8) + rnd * 40.0 + root.x * 0.9 + root.z * 1.3);
	vec2 bend = dir * (0.16 + gust * 0.85) * wind_strength + side * flutter * (0.05 + gust * 0.1);
	bend *= GRASS_SWAY;

	vec2 away = root.xz - player_position.xz;
	float dist = length(away);
	float push = 1.0 - smoothstep(0.2, 1.15, dist);
	bend += (away / max(dist, 0.001)) * push * 0.75;

	// A battle clearing combs everything outwards from its centre.
	vec2 from_center = root.xz - clearing_center.xz;
	bend += (from_center / max(length(from_center), 0.001)) * clearing_amount(root.xz) * 0.8;
	return bend;
}

// 1 = keep, 0 = cut away. Opens a porthole in whatever stands between the
// camera and the player, so trees never hide the character.
float player_porthole(vec3 view_vertex, mat4 view_matrix, mat4 projection) {
	// Orthographic projection means we are in the sun's shadow pass: never cut.
	if (projection[3][3] != 0.0) {
		return 1.0;
	}
	// During a battle the window widens and centres on the fight instead.
	vec3 focus = player_position;
	float size = 1.0;
	if (clearing_radius > 0.01) {
		focus = clearing_center;
		size = 2.4;
	}
	vec3 pv = (view_matrix * vec4(focus + vec3(0.0, 0.7, 0.0), 1.0)).xyz;
	if (view_vertex.z < pv.z + 0.6) {
		return 1.0; // behind the focus point
	}
	vec2 d = view_vertex.xy / -view_vertex.z - pv.xy / -pv.z;
	return smoothstep(0.055 * size, 0.12 * size, length(d));
}
