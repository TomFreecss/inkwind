// Pale brush-stroke ribbons that show which way the wind is blowing.
// Each instance is a subdivided strip; UV.x runs head (0) to tail (1).
// Stateless like the leaves: INSTANCE_CUSTOM holds four random seeds.
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;

#include "res://shaders/wind.gdshaderinc"

uniform vec2 area_center = vec2(20.0, 14.0);
uniform vec2 area_size = vec2(52.0, 40.0);
uniform vec3 color : source_color = vec3(1.0, 0.99, 0.93);
uniform float width = 0.06;

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	vec2 dir = wind_dir();
	vec2 side = vec2(-dir.y, dir.x);

	// Each streak lives for `period` seconds, then respawns somewhere else.
	float period = 5.0 + seed.x * 4.0;
	float clock = TIME / period + seed.y;
	float cycle = floor(clock);
	float life = fract(clock);
	vec2 spawn = vec2(hash21(vec2(cycle, seed.z * 91.0)), hash21(vec2(seed.w * 57.0, cycle)));
	vec2 start = area_center + (spawn - 0.5) * area_size;

	float travel = (9.0 + seed.x * 5.0) * wind_strength;
	float len = 2.5 + seed.z * 2.5;
	float along = life * travel - UV.x * len;

	vec2 xz = start + dir * along;
	xz += side * (sin(along * 0.55 + seed.w * 20.0) * 0.7 + sin(along * 1.3 + seed.x * 10.0) * 0.2);
	// Fly above head height so they never slice through the characters.
	float y = 1.9 + seed.w * 1.4 + sin(along * 0.8 + seed.y * 6.0) * 0.25;

	// Taper to nothing at both ends, and at birth and death.
	float w = sin(UV.x * PI) * sin(life * PI) * width;
	xz += side * (UV.y - 0.5) * w;

	VERTEX = (VIEW_MATRIX * vec4(xz.x, y, xz.y, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	ALBEDO = color * day_brightness;
}
