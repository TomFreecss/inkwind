// Full-screen "painted on paper" filter, applied to a ColorRect that covers the view.
//  1. Kuwahara filter: flattens detail into brush dabs while keeping edges crisp.
//  2. Wet edges: pigment pools darker where two colours meet.
//  3. Pencil hatching in the deepest shadows.
//  4. Paper grain, and a soft fade to bare paper in the corners.
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms brush;
/// Brush size in taps. Cost grows with the square: 3 = 64 samples, 4 = 100.
uniform int brush_radius : hint_range(1, 6) = 3;
/// Distance between taps, in pixels at 900p.
uniform float brush_spread : hint_range(0.5, 3.0) = 2.0;
/// How much the hand "shakes": bends straight edges slightly.
uniform float wobble : hint_range(0.0, 6.0) = 2.0;

group_uniforms pigment;
uniform float edge_darkening : hint_range(0.0, 1.5) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.22;

group_uniforms paper;
uniform vec3 paper_color : source_color = vec3(0.965, 0.94, 0.875);
uniform float paper_grain : hint_range(0.0, 1.0) = 0.4;
uniform float border_fade : hint_range(0.0, 1.0) = 0.55;
group_uniforms;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	// Keep the brush the same apparent size at any window resolution.
	float res_scale = (1.0 / px.y) / 900.0;
	vec2 ref_px = SCREEN_UV / px / res_scale; // pixel coordinates at 900p

	// 0. Hand wobble.
	vec2 shake = vec2(value_noise(ref_px * 0.018), value_noise(ref_px * 0.018 + 57.0)) - 0.5;
	vec2 uv = SCREEN_UV + shake * wobble * 2.0 * px * res_scale;

	// 1. Kuwahara: average four overlapping quadrants around the pixel and keep
	//    the one with the least colour variance.
	vec2 tap = px * res_scale * brush_spread;
	int r = brush_radius;
	float count = float((r + 1) * (r + 1));
	vec3 m0 = vec3(0.0);
	vec3 m1 = vec3(0.0);
	vec3 m2 = vec3(0.0);
	vec3 m3 = vec3(0.0);
	vec3 s0 = vec3(0.0);
	vec3 s1 = vec3(0.0);
	vec3 s2 = vec3(0.0);
	vec3 s3 = vec3(0.0);
	for (int j = -r; j <= 0; j++) {
		for (int i = -r; i <= 0; i++) {
			vec3 c = textureLod(screen_texture, uv + vec2(float(i), float(j)) * tap, 0.0).rgb;
			m0 += c;
			s0 += c * c;
		}
	}
	for (int j = -r; j <= 0; j++) {
		for (int i = 0; i <= r; i++) {
			vec3 c = textureLod(screen_texture, uv + vec2(float(i), float(j)) * tap, 0.0).rgb;
			m1 += c;
			s1 += c * c;
		}
	}
	for (int j = 0; j <= r; j++) {
		for (int i = -r; i <= 0; i++) {
			vec3 c = textureLod(screen_texture, uv + vec2(float(i), float(j)) * tap, 0.0).rgb;
			m2 += c;
			s2 += c * c;
		}
	}
	for (int j = 0; j <= r; j++) {
		for (int i = 0; i <= r; i++) {
			vec3 c = textureLod(screen_texture, uv + vec2(float(i), float(j)) * tap, 0.0).rgb;
			m3 += c;
			s3 += c * c;
		}
	}
	m0 /= count;
	m1 /= count;
	m2 /= count;
	m3 /= count;
	vec3 d0 = abs(s0 / count - m0 * m0);
	vec3 d1 = abs(s1 / count - m1 * m1);
	vec3 d2 = abs(s2 / count - m2 * m2);
	vec3 d3 = abs(s3 / count - m3 * m3);
	float v0 = d0.r + d0.g + d0.b;
	float v1 = d1.r + d1.g + d1.b;
	float v2 = d2.r + d2.g + d2.b;
	float v3 = d3.r + d3.g + d3.b;

	vec3 col = m0;
	float best = v0;
	if (v1 < best) {
		best = v1;
		col = m1;
	}
	if (v2 < best) {
		best = v2;
		col = m2;
	}
	if (v3 < best) {
		best = v3;
		col = m3;
	}

	// 2. Wet edges: where opposite quadrants disagree there is a colour boundary.
	float edge = length(m0 - m3) + length(m1 - m2);
	col *= 1.0 - edge_darkening * smoothstep(0.12, 0.7, edge);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// 3. Diagonal pencil strokes, only where the picture is dark.
	float stroke_coord = (ref_px.x + ref_px.y) * 0.22 + (value_noise(ref_px * 0.03) - 0.5) * 5.0;
	float stroke = 1.0 - smoothstep(0.0, 0.2, abs(fract(stroke_coord) - 0.5));
	col *= 1.0 - hatch_strength * stroke * (1.0 - smoothstep(0.15, 0.42, luma));

	// 4. Paper: pigment settles into the grain, more visibly in darker washes.
	float grain = fbm(ref_px * 0.11) * 0.7 + hash21(floor(ref_px * 0.5)) * 0.3;
	col *= 1.0 - paper_grain * (grain - 0.5) * (0.35 + 0.5 * (1.0 - luma));
	col *= mix(vec3(1.0), paper_color, 0.6);

	// Storybook border: the painting thins out to bare paper in the corners.
	vec2 centered = SCREEN_UV - 0.5;
	float rim = length(centered * vec2(1.0, 0.9)) + (fbm(SCREEN_UV * 7.0) - 0.5) * 0.14;
	float fade = smoothstep(0.52, 0.78, rim) * border_fade;
	col = mix(col, paper_color * (1.0 - paper_grain * (grain - 0.5) * 0.2), fade);

	COLOR = vec4(col, 1.0);
}
