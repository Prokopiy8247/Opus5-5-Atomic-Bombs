// Bunker viewing pane: thick laminated glass, slight green tint, dirt and smudges,
// interior reflections (from the reflection probe), procedural cracks and frost of shattering.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float crack = 0.0;          // 0..1 crack propagation
uniform float shatter = 0.0;        // 1 = blown out
uniform vec2 pane_size = vec2(4.0, 1.6);
uniform vec4 impact = vec4(0.3, 0.6, 0.7, 0.25); // two impact points in UV
uniform float dirt = 1.0;
uniform float seed = 0.0;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vn(p);
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

// distance to the nearest Voronoi edge (for crack networks)
float voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg;
	vec2 mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = h22(n + g + seed);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = h22(n + g + seed);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

float crack_lines(vec2 uv_m, vec2 c, float reach) {
	vec2 d = uv_m - c;
	float r = length(d);
	float a = atan(d.y, d.x);
	// radial cracks
	float rays = 14.0;
	float k = a / (2.0 * PI) * rays + fbm(vec2(r * 2.0, a * 3.0)) * 0.6;
	float radial = abs(fract(k) - 0.5) * 2.0 * r * (2.0 * PI / rays);
	float rad_line = 1.0 - smoothstep(0.0, 0.004 + 0.002 * r, radial);
	// concentric rings
	float ring_k = r * 7.0 + fbm(d * 6.0) * 0.8;
	float ring = abs(fract(ring_k) - 0.5) / 7.0;
	float ring_line = (1.0 - smoothstep(0.0, 0.003, ring)) * step(0.5, h21(floor(vec2(ring_k, k))));
	float m = max(rad_line, ring_line * 0.8);
	return m * (1.0 - smoothstep(reach * 0.85, reach, r));
}

void fragment() {
	vec2 uv_m = UV * pane_size; // metres
	// dirt: smudges, streaks from rain, dust at the bottom edge
	float smudge = fbm(uv_m * 1.3 + seed) ;
	float streak = fbm(vec2(uv_m.x * 9.0, uv_m.y * 0.4) + seed * 3.0);
	float bottom = smoothstep(0.35, 0.0, UV.y < 0.5 ? UV.y : 1.0) ;
	float edge_dust = 1.0 - smoothstep(0.0, 0.18, min(min(UV.x, 1.0 - UV.x) * pane_size.x, min(UV.y, 1.0 - UV.y) * pane_size.y));
	float d = clamp((smoothstep(0.45, 0.8, smudge) * 0.5 + smoothstep(0.55, 0.85, streak) * 0.25 + edge_dust * 0.6) * dirt, 0.0, 1.0);

	// cracks
	float cm = 0.0;
	if (crack > 0.0) {
		float reach = crack * 1.6 * max(pane_size.x, pane_size.y);
		cm = crack_lines(uv_m, impact.xy * pane_size, reach);
		cm = max(cm, crack_lines(uv_m, impact.zw * pane_size, reach * 0.8));
		float web = 1.0 - smoothstep(0.0, 0.012, voronoi_edge(uv_m * 3.0));
		float web_mask = smoothstep(0.5, 1.0, crack) * step(0.6, h21(floor(uv_m * 3.0)));
		cm = max(cm, web * web_mask * 0.7);
	}
	ALBEDO = mix(vec3(0.02, 0.025, 0.025), vec3(0.30, 0.29, 0.26), d);
	ROUGHNESS = mix(0.04, 0.6, d);
	METALLIC = 0.0;
	SPECULAR = 0.35;
	float a = 0.05 + d * 0.16;
	// crack lines catch light
	ALBEDO = mix(ALBEDO, vec3(0.85), cm);
	a = max(a, cm * 0.85);
	ALPHA = a * (1.0 - shatter);
	if (shatter > 0.5) {
		discard;
	}
}
