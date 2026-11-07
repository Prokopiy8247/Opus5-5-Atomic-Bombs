// Volumetric explosion renderer: raymarches an analytic SDF field (fireball, mushroom head
// (dome + vortex torus), stem/column, ground skirt/base surge, condensation rings, ice cap)
// displaced by tileable 3D noise. Driven entirely by uniforms computed from the explosion's
// age by scripts/fx/explosion.gd -> deterministic, scrubbable, slow-motion safe.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled, shadows_disabled;

#include "res://shaders/atmos.gdshaderinc"

global uniform float g_quality;
global uniform vec4 g_ambient;      // rgb sky ambient, w scale
global uniform vec4 g_sun_light;    // rgb sun colour * energy

uniform sampler3D noise_a : filter_linear_mipmap, repeat_enable;   // low-frequency simplex fbm
uniform sampler3D noise_b : filter_linear_mipmap, repeat_enable;   // billowy inverted cellular fbm
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec3 origin_world;          // ground zero (terrain surface) in world space
uniform vec3 box_min;               // proxy bounds in local metres
uniform vec3 box_max;
uniform float age = 0.0;
uniform float seed = 0.0;
uniform float base_steps = 64.0;

// --- fireball
uniform vec4 fb = vec4(0.0);                         // centre xyz (local), radius
uniform vec4 fb_look = vec4(5000.0, 1.0, 0.25, 1.0); // temperature K, emission scale, noise amp (rel), opacity
uniform vec4 fb_shape = vec4(1.0, 0.0, 6.0, 0.0);    // y-squash, rapatronic mottling 0..1, noise scale, smoke skin 0..1
uniform vec4 fb_tint = vec4(1.0, 1.0, 1.0, 0.0);     // additive glow tint (Trinity violet), w = strength
uniform float fb_cut_y = -1e9;                       // flat underside cut by the reflected shock (local y)

// --- mushroom head
uniform vec4 head = vec4(0.0, -1e6, 0.0, 0.0);        // centre xyz, horizontal radius
uniform vec4 head_shape = vec4(100.0, 0.0, 1.0, 0.0); // half thickness, torus amount 0..1, density, roll angle
uniform vec4 head_col_a = vec4(0.45, 0.25, 0.15, 0.0); // early colour (rgb), w = mix to colour b
uniform vec4 head_col_b = vec4(0.85, 0.85, 0.85, 0.0); // late colour, w = dark base amount
uniform vec4 head_heat = vec4(0.0);                    // core temperature K, glow strength, glow radius rel, noise cell rel
uniform vec4 head_detail = vec4(0.32, 0.6, 0.8, 0.0);  // noise amp rel, billow sharpness, erosion, unused

// --- stem / column
uniform vec4 stem = vec4(0.0);                       // bottom y, top y, radius, density
uniform vec4 stem_shape = vec4(2.0, 0.25, 0.0, 0.0); // base flare (mult), waist 0..1, hollow wall rel (0 = solid), rise speed
uniform vec4 stem_col = vec4(0.5, 0.42, 0.35, 2.5);  // rgb, w = noise vertical stretch
uniform float stem_cone = 0.0;                       // >0: widens with height (ejecta cone / geyser)
uniform float stem_top_flare = 0.0;                  // trumpet flare of the top of attached stems (rel. radius)
uniform float fb_grad = 0.0;                         // 1 = conventional flame: hot core, cooler orange rim, smoke below 1800 K
uniform float head_lobes = 0.0;                      // 0..1: build compact heads from 3 seeded lobes (no ball silhouette)
uniform float col_detail = 0.0;                      // 0..1: sharper, finer edges of ejecta columns (no out-of-focus look)
uniform float stem_twist = 0.0;                      // helical twist of the stem texture (rad per stem radius of height)
uniform float stem_wobble = 0.0;                     // slow lateral meander of attached stems (rel. to the stem radius)
uniform float skirt_front = 0.0;                     // 1 = base surge: tallest at the rolling front, not at the cloud foot
uniform vec3 dome_col = vec3(-1.0);                  // soil dome colour (< 0: ground colour); Baker: white spray dome
uniform vec4 stem_wake = vec4(1.0e9, 0.0, 0.0, 1.0); // dust front y, wake bottom y, wake density rel, dust ramp

// --- ground skirt / base surge
uniform vec4 skirt = vec4(0.0);                      // outer radius, height, density, inner radius rel
uniform vec4 skirt_col = vec4(0.6, 0.52, 0.42, 0.0);

// --- condensation rings (y, radius, thickness, opacity) and ice cap / pileus shells
uniform vec4 rings[4];
uniform vec4 ice = vec4(0.0);        // centre y, radius, half height, opacity
uniform vec4 ice2 = vec4(0.0);

uniform vec3 ground_col = vec3(0.55, 0.47, 0.38);
uniform vec4 dome_u = vec4(0.0);        // soil heave (Sedan / camouflets): radius, height, crack amount, unused
uniform vec3 wind = vec3(0.0);          // horizontal drift velocity (m/s) at wind_h; shear below it
uniform float wind_h = 1000.0;
uniform float churn = 0.0;              // noise advection (cells / s): boiling, evolving surfaces
uniform int debug_mode = 0;

// ------------------------------------------------------------------ helpers
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float sd_ellipsoid(vec3 p, vec3 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	return k0 * (k0 - 1.0) / max(k1, 1e-6);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 blackbody(float temp) {
	float t = clamp(temp, 800.0, 40000.0) / 100.0;
	float r = t <= 66.0 ? 1.0 : clamp(1.29293618606 * pow(t - 60.0, -0.1332047592), 0.0, 1.0);
	float g = t <= 66.0 ? clamp(0.39008157876 * log(t) - 0.63184144378, 0.0, 1.0) : clamp(1.12989086089 * pow(t - 60.0, -0.0755148492), 0.0, 1.0);
	float b = t >= 66.0 ? 1.0 : (t <= 19.0 ? 0.0 : clamp(0.54320678911 * log(t - 10.0) - 1.19625408914, 0.0, 1.0));
	return pow(vec3(r, g, b), vec3(2.2));
}

// visible radiance of a black body relative to 8000 K
float bb_lum(float temp) {
	float x = temp / 8000.0;
	return x * x * x * x * smoothstep(650.0, 1500.0, temp);
}

float nlf(vec3 p) {
	return texture(noise_a, p).r;
}

float nbl(vec3 p) {
	return texture(noise_b, p).r;
}

float hg(float mu, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// ------------------------------------------------------------------ analytic shapes
float sdf_fireball(vec3 p) {
	if (fb.w <= 0.0) {
		return 1e9;
	}
	vec3 q = p - fb.xyz;
	q.y /= fb_shape.x;
	return length(q) - fb.w;
}

float sdf_head_base(vec3 q) {
	float R = head.w;
	float H = head_shape.x;
	float tor_k = head_shape.y;
	float blob = sd_ellipsoid(q, vec3(R, H, R));
	if (head_lobes > 0.0) {
		// three seeded lobes: a lumpy, asymmetric silhouette instead of one ellipsoid ball
		float sa = seed * 2.399;
		vec3 o1 = vec3(cos(sa) * R * 0.42, H * 0.12, sin(sa) * R * 0.42);
		vec3 o2 = vec3(cos(sa + 2.3) * R * 0.38, -H * 0.18, sin(sa + 2.3) * R * 0.38);
		vec3 o3 = vec3(cos(sa + 4.2) * R * 0.30, H * 0.28, sin(sa + 4.2) * R * 0.30);
		float l1 = sd_ellipsoid(q - o1, vec3(R * 0.68, H * 0.78, R * 0.62));
		float l2 = sd_ellipsoid(q - o2, vec3(R * 0.62, H * 0.70, R * 0.66));
		float l3 = sd_ellipsoid(q - o3, vec3(R * 0.55, H * 0.72, R * 0.58));
		float lob = smin(smin(l1, l2, H * 0.25), l3, H * 0.25);
		blob = mix(blob, lob, head_lobes);
	}
	float rxz = length(q.xz);
	// mature mushroom: dome on top of a vortex torus, flat-ish underside
	float dome = sd_ellipsoid(q - vec3(0.0, H * 0.20, 0.0), vec3(R * 0.90, H * 0.80, R * 0.90));
	float a = R * 0.62;
	float b = H * 0.62;
	float tor = length(vec2((rxz - a) * 0.92, q.y + H * 0.25)) - b;
	float mush = smin(dome, tor, H * 0.30);
	// under-cut around the stem axis (the hollow under the cap)
	// (cycle 3: the old 0.30 R hollow was far wider than megaton stems and exposed the stem top
	// inside the cap - a 'pipe mouth' / phallic read)
	mush = max(mush, -(length(vec2(rxz, (q.y + H * 1.05) * 1.4)) - R * 0.12));
	return mix(blob, mush, tor_k);
}

float sdf_head(vec3 p) {
	if (head.w <= 0.0) {
		return 1e9;
	}
	return sdf_head_base(p - head.xyz);
}

float stem_radius_at(float y) {
	float h01 = clamp((y - stem.x) / max(stem.y - stem.x, 1.0), 0.0, 1.0);
	float r = stem.z * (1.0 + (stem_shape.x - 1.0) * exp(-h01 * 10.0));
	r *= 1.0 - stem_shape.y * sin(h01 * PI) * 0.5;
	r *= 1.0 + stem_cone * h01;
	r *= 1.0 + stem_top_flare * pow(smoothstep(0.65, 1.0, h01), 2.0);
	if (stem_wobble > 0.0 && stem_cone <= 0.0) {
		// stacked boluses along the stem (not a uniform pipe)
		r *= 1.0 + 0.8 * stem_wobble * (nlf(vec3(seed * 0.13, y / (3.5 * max(stem.z, 1.0)) - age * stem_shape.w * 0.002, seed * 0.29)) - 0.5) * smoothstep(0.05, 0.25, h01);
	}
	return r;
}

float sdf_stem(vec3 p) {
	if (stem.z <= 0.0) {
		return 1e9;
	}
	if (stem_wobble > 0.0) {
		// slow lateral meander: a wavy dusty stem instead of a straight pipe
		vec2 perp = normalize(vec2(-wind.z, wind.x) + vec2(1e-4, 0.0));
		p.xz += perp * stem.z * 1.2 * stem_wobble * (nlf(vec3(p.y / (8.0 * stem.z), age * 0.01, seed)) - 0.5) * 2.0;
	}
	float r = stem_radius_at(p.y);
	float d = length(p.xz) - r;
	if (stem_shape.z > 0.0) {
		float wall = r * stem_shape.z;
		d = abs(d + wall) - wall;
	}
	float top = stem_cone > 0.0 ? stem.x + (stem.y - stem.x) * 1.4 : stem.y;
	float dv = max(stem.x - p.y, p.y - top);
	return max(d, dv);
}

float sdf_skirt(vec3 p) {
	if (skirt.x <= 0.0) {
		return 1e9;
	}
	float r = length(p.xz);
	float h = skirt.y;
	float R = skirt.x;
	// height-field profile: a low sheet thickening toward a soft rolling front, no hard wall
	float x = r / max(R, 1.0);
	// highest at the cloud foot, tapering softly to the toe (cycle 3: the old rim peak gave trays and
	// hedges with vertical ends)
	float prof = mix(1.0, 0.3, smoothstep(0.15, 1.0, x)) * (1.0 - smoothstep(0.72, 1.25, x));
	if (skirt_front > 0.0) {
		prof = mix(prof, mix(0.45, 1.0, smoothstep(0.5, 0.95, x)) * (1.0 - smoothstep(0.95, 1.25, x)), skirt_front);
	}
	float hh = h * prof;
	float d = max(p.y - hh, -p.y - h * 0.15);
	// radial bound: beyond the toe there is nothing (the proxy box used to cut a thin noisy sheet
	// that ran out to infinity, leaving vertical 'walls' at the box faces)
	d = max(d, r - R * 1.3 - h * 0.5);
	float inner = R * skirt.w;
	d = max(d, (inner - r) * 0.5);
	return d;
}

float sdf_rings(vec3 p) {
	float d = 1e9;
	float r = length(p.xz);
	for (int i = 0; i < 4; i++) {
		if (rings[i].w > 0.0) {
			// flat condensation disc / collar (no hole): radius y, half thickness z
			float th = max(rings[i].z, rings[i].y * 0.012);
			float dr = max(r - rings[i].y, abs(p.y - rings[i].x) - th * (1.0 - 0.7 * smoothstep(0.4, 1.0, r / max(rings[i].y, 1.0))));
			d = min(d, dr);
		}
	}
	return d;
}

float sdf_shell(vec3 p, vec4 s) {
	if (s.w <= 0.0) {
		return 1e9;
	}
	vec3 q = p - vec3(0.0, s.x, 0.0);
	float e = sd_ellipsoid(q, vec3(s.y, s.z, s.y));
	// solid low-density lens (pileus / ice cap), open underneath like a bell
	return max(e, -q.y - s.z * 0.35);
}

// spherical-cap soil dome rising out of the ground (rendered here: the far terrain LOD cannot)
float sdf_dome(vec3 p) {
	if (dome_u.y <= 0.05) {
		return 1e9;
	}
	float R = dome_u.x;
	float h = dome_u.y;
	float rr = length(p.xz) / max(R, 1.0);
	// bell-shaped height field (a spherical cap read as a bowler hat)
	float d = (p.y - h * exp(-2.2 * rr * rr)) * 0.6;
	return max(d, -p.y);
}

float scene_sdf(vec3 p) {
	float d = sdf_fireball(p);
	d = min(d, sdf_head(p));
	d = min(d, sdf_stem(p));
	d = min(d, sdf_skirt(p));
	d = min(d, sdf_rings(p));
	d = min(d, sdf_shell(p, ice));
	d = min(d, sdf_shell(p, ice2));
	return d;
}

// cheap smooth density (no noise) for long shadow rays
float cheap_density(vec3 p) {
	float d = 0.0;
	if (head.w > 0.0) {
		d += clamp(-sdf_head(p) / (head_shape.x * 0.8), 0.0, 1.0) * head_shape.z;
	}
	if (stem.z > 0.0) {
		// soft top: the analytic top plane must not cast a knife-edge shadow band on a rising head
		float stop_c = stem_cone > 0.0 ? stem.x + (stem.y - stem.x) * 1.4 : stem.y;
		d += clamp(-sdf_stem(p) / (stem.z * 1.0), 0.0, 1.0) * stem.w * smoothstep(stop_c, stop_c - 0.35 * (stop_c - stem.x), p.y);
	}
	if (fb.w > 0.0) {
		d += clamp(-sdf_fireball(p) / (fb.w * 0.3), 0.0, 1.0) * fb_look.w * 2.0;
	}
	if (skirt.x > 0.0) {
		d += clamp(-sdf_skirt(p) / (skirt.y * 1.2), 0.0, 1.0) * skirt.z;
	}
	return d;
}

// ------------------------------------------------------------------ noisy fields
// Head density with cauliflower billows (3 octaves of inverted Worley + low-frequency warp).
float head_density(vec3 p, out float cauli, out vec2 rc_out) {
	cauli = 0.0;
	rc_out = vec2(0.0);
	if (head.w <= 0.0) {
		return 0.0;
	}
	vec3 q = p - head.xyz;
	float R = head.w;
	float H = head_shape.x;
	float base = sdf_head_base(q);
	float amp = head_detail.x * min(R, H * mix(1.8, 1.2, smoothstep(0.5, 1.0, head_shape.y)));
	if (base > amp * 1.2) {
		return 0.0;
	}
	// rolling vortex: rotate lookups in the (radial, y) plane around the core ring
	float rxz = length(q.xz);
	vec2 dir = rxz > 1e-3 ? q.xz / rxz : vec2(1.0, 0.0);
	float a = R * 0.62;
	vec2 rc = vec2(rxz - a, q.y + H * 0.25);
	rc_out = rc;
	// rigid rotation about the vortex ring (a radius-dependent angle smeared the cells into arcs)
	float roll = min(head_shape.w, 0.6) * head_shape.y * smoothstep(0.15 * R, 0.5 * R, rxz);
	float cr = cos(roll);
	float sr = sin(roll);
	vec2 rr = vec2(cr * rc.x - sr * rc.y, sr * rc.x + cr * rc.y);
	vec3 qn = vec3(dir.x * (rr.x + a), rr.y - H * 0.25, dir.y * (rr.x + a));
	// noise cell follows the cap THICKNESS: flat megaton caps keep cauliflower-sized lobes
	float cell = (0.6 * H + 0.12 * R) * head_heat.w;
	vec3 np = qn / cell + vec3(seed * 1.3, seed * 0.37, seed * 0.71) + vec3(0.3, -1.0, 0.2) * (age * churn);
	// Feature sizes (the billow volume holds 6/12/24 Worley cells per tile, the fbm 4..64): with
	// cell ~0.23 R the lookups below give big lobes ~0.35 R carrying their own sub-lobes (the
	// cauliflower hierarchy), secondary lobes ~0.13 R and fine texture that only shades.
	// (cycle 3: the old multipliers were 3x higher -> 0.04-0.12 R 'pom-pom' hair everywhere)
	float warp = nlf(np * 0.07) - 0.5;
	float b1 = nbl(np * 0.11 + warp * 0.22);
	float b2 = nbl(np * 0.30 + 5.3);
	float b3 = nbl(np * 0.85 + 11.0);
	float b4 = nbl(np * 2.1 + 17.0);
	float sharp = head_detail.y;
	cauli = pow(b1, sharp) * 0.50 + pow(b2, sharp) * 0.30 + b3 * 0.14 + b4 * 0.06;
	float shape_n = pow(b1, sharp) * 0.64 + pow(b2, sharp) * 0.30 + b3 * 0.06;
	float disp = (shape_n - 0.42) * 1.35 + warp * 0.6;
	float dn = base - disp * amp;
	float edge = H * 0.07;
	float dens = smoothstep(edge, -edge * 3.0, dn);
	// gentle erosion of the thin outer fringe only (no speckles)
	dens *= 1.0 - head_detail.z * 0.3 * (1.0 - dens) * smoothstep(0.35, 0.65, 1.0 - b2);
	if (head_heat.y > 0.0) {
		float dc = length(vec2(rc.x, rc.y + H * 0.25)) / max(H * head_heat.z, 1.0);
		float hot = exp(-dc * dc * 2.0) * clamp(head_heat.y / 300.0, 0.0, 1.0);
		dens *= 1.0 - 0.95 * hot;
	}
	if (fb.w > 0.0 && fb_look.w > 0.3) {
		// the young cloud grows out of the ball: do not bury the incandescent surface
		vec3 qf = (p - fb.xyz) / fb.w;
		qf.y /= fb_shape.x;
		dens *= mix(1.0, smoothstep(0.8, 1.15, length(qf)), clamp((fb_look.w - 0.3) / 0.5, 0.0, 1.0) * 0.85);
	}
	dens *= smoothstep(0.015, 0.08, dens);
	return dens * head_shape.z;
}

float stem_density(vec3 p, out float n_out) {
	n_out = 0.5;
	if (stem.z <= 0.0) {
		return 0.0;
	}
	float base = sdf_stem(p);
	float r = stem_radius_at(p.y);
	float amp = r * 0.6;
	if (base > r * 1.0) {
		return 0.0;
	}
	float env = smoothstep(r * 1.0, r * 0.7, base);
	vec3 pt = p;
	if (stem_twist != 0.0) {
		float ang = stem_twist * p.y / max(stem.z, 1.0);
		float ca = cos(ang);
		float sa = sin(ang);
		pt.xz = vec2(ca * p.x - sa * p.z, sa * p.x + ca * p.z);
	}
	vec3 np = vec3(pt.x, (pt.y - age * stem_shape.w) / max(stem_col.w, 1.0), pt.z) / (max(stem.z, 1.0) * 1.3) + vec3(seed * 0.21);
	float n = nbl(np * 0.6) * 0.65 + nbl(np * 1.7 + 3.0) * 0.35;
	if (col_detail > 0.0) {
		n = mix(n, n * 0.8 + nbl(np * 4.5 + 7.0) * 0.2, col_detail);
	}
	float lf = nlf(np * 0.25 + 4.0);
	n_out = n;
	float dn = base - ((n - 0.45) * 0.9 + (lf - 0.5) * 0.7) * amp;
	float jetk = 1.0;
	if (stem_cone > 0.0) {
		// ejecta crown: radial jets of soil fanning out of the crater, ragged at the top
		float h01 = clamp((p.y - stem.x) / max(stem.y - stem.x, 1.0), 0.0, 1.0);
		// periodic (cos, sin) lookups: no seam where atan() wraps
		float rx = length(p.xz);
		vec2 cs = rx > 1e-3 ? p.xz / rx : vec2(1.0, 0.0);
		float jet = nbl(vec3(cs.x * 0.55 + seed, cs.y * 0.55, h01 * 0.25 + rx / max(r, 1.0) * 0.08)) * 0.7
			+ nbl(vec3(cs.x * 1.3 + 4.1, cs.y * 1.3, h01 * 0.6 + 1.7 + seed)) * 0.3;
		// jet strength (column kinds pass it in stem_wake.z): spiky HE crowns 1, dense dust plumes ~0.15
		float jamt = stem_wake.x >= 1.0e8 ? stem_wake.z : 1.0;
		jet = mix(0.55, smoothstep(0.5, 0.78, jet), jamt);
		// on the axis blend to the azimuthal MEDIAN jet (blending to a high value made the axis core
		// the tallest, densest part of the crown: a lit pillar / spike)
		jet = mix(mix(0.55, 0.40, jamt), jet, smoothstep(0.05 * r, 0.45 * r, rx));
		dn -= (jet - 0.5) * r * 0.55 * h01;
		jetk = mix(0.1, 1.4, jet) * (1.0 - 0.6 * smoothstep(0.75, 1.0, h01) * (1.0 - n));
	}
	float dens = smoothstep(r * mix(0.1, 0.04, col_detail), -r * mix(0.35, 0.15, col_detail), dn) * jetk;
	if (stem_cone > 0.0) {
		// every jet has its own ragged top (no flat-topped frustum)
		float rx2 = length(p.xz);
		vec2 cs2 = rx2 > 1e-3 ? p.xz / rx2 : vec2(1.0, 0.0);
		float jt = nbl(vec3(cs2.x * 0.55 + seed, cs2.y * 0.55, 0.3));
		float jamt2 = stem_wake.x >= 1.0e8 ? stem_wake.z : 1.0;
		float top_j = stem.x + (stem.y - stem.x) * mix(0.92, 0.5 + 0.65 * smoothstep(0.35, 0.8, jt), jamt2) * (0.85 + 0.3 * lf);
		top_j = mix(stem.x + (stem.y - stem.x) * mix(0.92, 0.62, jamt2) * (0.85 + 0.3 * lf), top_j, smoothstep(0.05 * r, 0.45 * r, rx2));
		dens *= smoothstep(top_j + r * 0.2, top_j - r * 0.9, p.y);
	} else {
		// fade the top over ~3 radii with a noisy height (no flat-cut pipe tops)
		dens *= smoothstep(stem.y + r * 0.5, stem.y - r * 3.0 * (0.5 + 0.8 * lf), p.y);
	}
	if (stem_wake.x < 1.0e8) {
		// ground dust climbing up (ragged front) + the thinner wake chimney under the rising cap
		// (its bottom fades over ~3 radii: no flat-cut 'tombstone')
		float dust = stem_wake.w * smoothstep(stem_wake.x + r * 0.6, stem_wake.x - r * 1.4 * (0.5 + lf), p.y);
		float wk = stem_wake.z * smoothstep(stem_wake.y - r * 0.5, stem_wake.y + r * 3.0 * (0.6 + 0.8 * lf), p.y) * (0.55 + 0.9 * n);
		dens *= max(dust, wk);
	}
	return dens * stem.w * env;
}

float skirt_density(vec3 p, out float n_out) {
	n_out = 0.5;
	if (skirt.x <= 0.0) {
		return 0.0;
	}
	float base = sdf_skirt(p);
	float h = skirt.y;
	if (base > h * 0.9) {
		return 0.0;
	}
	vec3 np = p / (h * 2.4) + vec3(seed * 0.5, -age * 0.0015, seed);
	float n = nbl(np * 0.5) * 0.6 + nbl(np * 1.5 + 2.0) * 0.4;
	float lf = nlf(np * 0.12);
	n_out = n;
	float dn = base - ((n - 0.45) * 0.9 + (lf - 0.5) * 1.4) * h * 0.75;
	float dens = smoothstep(h * 0.04, -h * 0.25, dn) * smoothstep(-h * 0.05, h * 0.15, p.y + h * 0.1);
	return dens * skirt.z;
}

float fireball_density(vec3 p, out float lq_out, out float patch_out, out float mott_out) {
	lq_out = 2.0;
	patch_out = 0.5;
	mott_out = 0.0;
	if (fb.w <= 0.0) {
		return 0.0;
	}
	vec3 q = (p - fb.xyz) / fb.w;
	q.y /= fb_shape.x;
	float lq = length(q);
	if (lq > 1.0 + fb_look.z * 1.6 + 0.08) {
		return 0.0;
	}
	vec3 nq = q * fb_shape.z * 0.18 + vec3(seed, seed * 0.7, age * 0.02);
	// rotated lookups so lattice directions of different octaves never line up
	vec3 nr = mat3(vec3(0.80, 0.36, -0.48), vec3(-0.60, 0.48, -0.64), vec3(0.0, 0.80, 0.60)) * nq;
	float n1 = nlf(nq);
	float n2 = nbl(nr * 2.3 + 3.1);
	float disp = (n1 - 0.5) * 2.0 * fb_look.z + (n2 - 0.5) * fb_look.z * 0.5;
	float mott = 0.0;
	if (fb_shape.y > 0.0) {
		mott = nbl(q * 2.2 + seed);
		disp += fb_shape.y * (mott - 0.5) * 0.10;
	}
	float dd = lq - 1.0 - disp;
	dd = max(dd, (fb_cut_y - p.y) / max(fb.w, 1.0) + (n1 - 0.5) * 0.08);
	lq_out = lq;
	patch_out = nlf(nr * 0.9 + 7.7) * 0.6 + nbl(nr * 1.7 + 1.9) * 0.25 + n1 * 0.15;
	mott_out = mott;
	return smoothstep(0.05, -0.12, dd);
}

void vertex() {
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 frag_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(frag_w - cam);
	vec3 ro = cam - origin_world;

	vec3 inv = 1.0 / rd;
	vec3 t0 = (box_min - ro) * inv;
	vec3 t1 = (box_max - ro) * inv;
	vec3 tmin3 = min(t0, t1);
	vec3 tmax3 = max(t0, t1);
	float t_enter = max(max(max(tmin3.x, tmin3.y), tmin3.z), 0.0);
	float t_exit = min(min(tmax3.x, tmax3.y), tmax3.z);

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vpos = INV_PROJECTION_MATRIX * ndc;
	vpos.xyz /= vpos.w;
	float scene_t = length(vpos.xyz);
	t_exit = min(t_exit, scene_t);
	if (t_exit <= t_enter) {
		discard;
	}

	float seg = t_exit - t_enter;
	float steps = clamp(base_steps * g_quality, 16.0, 256.0);
	float dt = seg / steps;
	float scale_hint = max(max(min(head.w, head_shape.x * 2.0), fb.w), max(stem.z * 2.0, skirt.y * 2.0));
	// never step coarser than a quarter of the smallest active structure (no slicing/banding)
	float minf = 1e9;
	if (head.w > 0.0) { minf = min(minf, head_shape.x * 0.6); }
	if (stem.z > 0.0) { minf = min(minf, stem.z * 0.8); }
	if (fb.w > 0.0) { minf = min(minf, fb.w * 0.5); }
	if (skirt.x > 0.0) { minf = min(minf, skirt.y * 1.2); }
	dt = min(dt, minf * 0.25);
	dt = max(dt, scale_hint * 0.004);
	// interleaved gradient noise: an even, low-discrepancy step jitter (white noise gave salt-and-pepper
	// glitter in thin dust)
	vec2 fc = FRAGCOORD.xy + vec2(fract(age * 7.13) * 5.588);
	float dither = fract(52.9829189 * fract(dot(fc, vec2(0.06711056, 0.00583715))));
	float t = t_enter + dt * dither;

	vec3 L = normalize(g_sun_dir);
	float mu = dot(rd, L);
	float phase = mix(hg(mu, 0.55), hg(mu, -0.2), 0.35) * 4.0 * PI;
	phase = mix(1.0, phase, 0.8);
	vec3 sun_c = g_sun_light.rgb;
	vec3 amb = g_ambient.rgb * g_ambient.w;
	vec3 fire_c = g_fireball_color.rgb * g_fireball_color.w;
	float b_fb = 2.0;
	if (fb.w > 0.0) {
		vec3 oc = ro - fb.xyz;
		oc.y /= fb_shape.x;
		vec3 rds = normalize(vec3(rd.x, rd.y / fb_shape.x, rd.z));
		b_fb = length(cross(rds, oc)) / max(fb.w, 1.0);
	}
	// thinnest active condensation sheet: steps are kept below half of it near the sheets
	float th_min = 1e9;
	for (int i = 0; i < 4; i++) {
		if (rings[i].w > 0.0) {
			th_min = min(th_min, max(rings[i].z, rings[i].y * 0.012));
		}
	}
	vec3 head_col = mix(head_col_a.rgb, head_col_b.rgb, head_col_a.w);

	vec3 acc = vec3(0.0);
	float T = 1.0;
	float first_hit = -1.0;
	int max_iter = int(min(seg / dt, 520.0)) + 48;
	float sh_len = max(min(head.w, head_shape.x * 2.5), max(fb.w * 1.5, stem.z * 3.0)) + 1.0;
	for (int i = 0; i < 700; i++) {
		if (i >= max_iter || t > t_exit || T < 0.006) {
			break;
		}
		vec3 p0 = ro + rd * t;
		// wind: the stem and skirt shear with height (base stays put, upper part bends downwind);
		// the head, fireball, rings and caps drift RIGIDLY with the wind at the head's height
		vec3 p = p0;
		float hy = clamp(max(head.y, fb.y) / max(wind_h, 1.0), 0.0, 1.5);
		float wy = clamp(p0.y / max(wind_h, 1.0), 0.0, 1.5);
		if (head.w > 0.0 && stem.z > 0.0) {
			wy = mix(wy, hy, smoothstep(0.8 * stem.y, stem.y, p0.y));
		}
		p.xz -= wind.xz * age * wy;
		vec3 ph = p0;
		ph.xz -= wind.xz * age * clamp(max(head.y, fb.y) / max(wind_h, 1.0), 0.0, 1.5);
		float sd = min(min(sdf_fireball(ph), sdf_head(ph)), min(min(sdf_stem(p), sdf_skirt(p)),
			min(sdf_rings(ph), min(sdf_shell(ph, ice), sdf_shell(ph, ice2)))));
		float sdome = sdf_dome(p0);
		sd = min(sd, sdome);
		float margin = scale_hint * 0.4;
		if (sd > margin) {
			t += max(sd - margin * 0.9, dt);
			// re-snap to the per-pixel jittered grid so skips do not align all rays (banding)
			t = t_enter + (ceil((t - t_enter) / dt) + dither) * dt;
			continue;
		}
		// --- gather densities and materials
		float cauli;
		vec2 rc;
		float dh = head_density(ph, cauli, rc);
		float sn;
		float ds = stem_density(p, sn);
		float kn;
		float dk = skirt_density(p, kn);
		float lq;
		float fpatch;
		float fmott;
		float df = fireball_density(ph, lq, fpatch, fmott);
		// rings / shells
		float dr = 0.0;
		float rdd = sdf_rings(ph);
			if (rdd < 900.0) {
			// laminar sheets: noise stretched horizontally, it frays the RIM and thins the sheet
			// (cycle 3: isotropic displacement of 0.35 rr turned every disc into a cotton plank)
			vec3 lam = ph * vec3(0.00035, 0.004, 0.00035);
			float n = nlf(lam + seed) * 0.6 + nbl(ph * vec3(0.0011, 0.006, 0.0011) + seed) * 0.4;
			float op = max(max(rings[0].w, rings[1].w), max(rings[2].w, rings[3].w));
			float rr = max(max(rings[0].y, rings[1].y), max(rings[2].y, rings[3].y));
			float rim = length(ph.xz) / max(rr, 1.0);
			dr = smoothstep(rr * 0.004, -rr * 0.01, rdd - (n - 0.5) * rr * 0.03)
				* (1.0 - smoothstep(0.75 + 0.2 * n, 1.05, rim)) * op * (0.35 + 0.65 * smoothstep(0.3, 0.7, n));
		}
		float di = 0.0;
		float di_w = 0.0;   // extinction-weighted (each shell has its own optical scale)
		for (int k = 0; k < 2; k++) {
			vec4 sh = k == 0 ? ice : ice2;
			if (sh.w > 0.0) {
				vec3 psh = k == 1 ? p : ph;
				float dsh = sdf_shell(psh, sh);
				if (k == 1) {
					// second tier / bell skirt: a hollow open bell whose density fades toward the rim
					dsh = abs(dsh + sh.z * 0.25) - sh.z * 0.25;
				}
				if (dsh < sh.z * 0.4) {
					float n = nlf(ph / (sh.y * 0.5) + seed + float(k) * 3.0) * 0.6 + nbl(ph / max(sh.z * 0.8, 1.0) + float(k)) * 0.4;
					float dk_ = smoothstep(sh.z * 0.1, -sh.z * 0.3, dsh - (n - 0.5) * sh.z * 0.5) * sh.w * 0.3;
					if (k == 1) {
						dk_ *= 1.0 - smoothstep(0.6, 1.0, length(psh.xz) / max(sh.y, 1.0));
					}
					di += dk_;
					di_w += dk_ / max(sh.z, 5.0);
				}
			}
		}
		float fbo = df * fb_look.w;
		// soil dome: opaque, cracked
		float dd = 0.0;
		float dcrack = 0.0;
		if (sdome < dome_u.x * 0.05) {
			float cn = nlf(p0 / max(dome_u.x * 0.6, 1.0) + seed);
			dcrack = dome_u.z * (1.0 - smoothstep(0.0, 0.035, abs(cn - 0.5)));
			dd = smoothstep(dome_u.x * 0.01, -dome_u.x * 0.02, sdome - (nlf(p0 / max(dome_u.x * 0.5, 1.0)) - 0.5) * dome_u.y * 0.2);
			dd *= smoothstep(1.5 * dome_u.x, 1.1 * dome_u.x, length(p0.xz));
		}
		float total = dh + ds + dk + fbo + dr + di + dd;
		if (total > 0.002) {
			if (first_hit < 0.0) {
				first_hit = t;
			}
			// extinction coefficients scale with structure size (optically thick clouds)
			float kh = 22.0 / max(min(head.w, head_shape.x * 2.0), 1.0);
			float ks = 7.0 / max(stem.z, 1.0);
			float kk = 5.0 / max(skirt.y, 1.0);
			float kf = 14.0 / max(fb.w, 1.0);
			float kr = 1.0 / 600.0;
			float ki = 1.0 / max(ice.z, 300.0);
			float kd = 4.0 / max(dome_u.y * 0.1, 0.5);
			float wsum = dh * kh + ds * ks + dk * kk + fbo * kf + dr * kr + di_w + dd * kd;
			float trans = exp(-wsum * dt);
			vec3 c_head = head_col * (0.78 + 0.32 * cauli);
			float lowk = clamp(-rc.y / max(head_shape.x, 1.0), 0.0, 1.0) * head_col_b.w;
			c_head *= 1.0 - 0.45 * lowk;
			vec3 c_stem = stem_col.rgb * (0.8 + 0.35 * sn);
			vec3 c_skirt = skirt_col.rgb * (0.8 + 0.35 * kn) * 0.65;
			vec3 c_fb = mix(vec3(0.30, 0.13, 0.06), vec3(0.10, 0.07, 0.05), clamp(fb_shape.w, 0.0, 1.0));
			vec3 c_dome = (dome_col.x >= 0.0 ? dome_col : ground_col * vec3(0.62, 0.58, 0.52)) * (1.0 - 0.6 * dcrack);
			vec3 albedo = (c_head * dh * kh + c_stem * ds * ks + c_skirt * dk * kk + c_fb * fbo * kf + vec3(0.97) * (dr * kr + di_w) + c_dome * dd * kd) / max(wsum, 1e-9);

			// --- lighting
			// local self-shadow: one noisy tap toward the sun reveals the billows
			float c2;
			vec2 rc2;
			float s2;
			float hl = min(head.w, head_shape.x * 1.5);
			float dh_l = dh > 0.0 ? head_density(ph + L * hl * 0.03, c2, rc2) : 0.0;
			float dh_l2 = dh > 0.0 ? head_density(ph + L * hl * 0.08, c2, rc2) : 0.0;
			float ds_l = ds > 0.0 ? stem_density(p + L * stem.z * 0.15, s2) : 0.0;
			float od_local = (dh_l * 0.03 + dh_l2 * 0.05) * kh * hl + ds_l * ks * stem.z * 0.12;
			float od = 0.0;
			od += cheap_density(p + L * sh_len * 0.12) * 0.25;
			od += cheap_density(p + L * sh_len * 0.35) * 0.35;
			od += cheap_density(p + L * sh_len * 0.80) * 0.40;
			float wh = dh * kh;
			float wst = ds * ks;
			float kmix = (wh * kh + wst * ks) / max(wh + wst, 1e-9);
			float od_far = od * sh_len * (wh + wst > 0.0 ? kmix : kh) * 0.35;
			// macro shape shading from the analytic SDF gradients (keeps the big forms readable),
			// blended by density so the head/stem junction has no seam
			float macro_h = 1.0;
			float macro_s = 1.0;
			if (dh > 0.0 && head.w > 0.0) {
				vec3 q = ph - head.xyz;
				float e = head_shape.x * 0.08;
				vec3 nrm = normalize(vec3(
					sdf_head_base(q + vec3(e, 0.0, 0.0)) - sdf_head_base(q - vec3(e, 0.0, 0.0)),
					sdf_head_base(q + vec3(0.0, e, 0.0)) - sdf_head_base(q - vec3(0.0, e, 0.0)),
					sdf_head_base(q + vec3(0.0, 0.0, e)) - sdf_head_base(q - vec3(0.0, 0.0, e))));
				// soft terminator with a floor: forward/multiple scattering keeps shadow sides readable
				macro_h = 0.4 + 0.6 * smoothstep(-0.6, 0.9, dot(nrm, L));
			}
			if (ds > 0.0) {
				vec2 nr = normalize(p.xz + vec2(1e-3));
				macro_s = 0.45 + 0.55 * smoothstep(-0.6, 0.9, dot(vec3(nr.x, 0.15, nr.y), L));
			}
			float wother = max(wsum - wh - wst, 0.0);
			float macro = (macro_h * wh + macro_s * wst + 0.85 * wother) / max(wsum, 1e-9);
			float micro = mix(1.0, exp(-od_local * 0.6), 0.65);
			float far_s = exp(-od_far);
			float t_sun = macro * micro * far_s;
			float sunlit = t_sun * mix(1.0, phase, 0.5) * 1.1 + 0.2 * exp(-od_far * 0.15) * (0.4 + 0.6 * macro);
			float od_up = cheap_density(p + vec3(0.0, sh_len * 0.3, 0.0));
			float dh_up = dh > 0.0 ? head_density(ph + vec3(0.0, hl * 0.12, 0.0), c2, rc2) : 0.0;
			// sky light also arrives sideways: AO floor instead of black undersides
			float ao = exp(-od_up * 1.0 - dh_up * 1.2) * 0.65 + 0.35;
			vec3 light = sun_c * sunlit + amb * ao * 0.9;
			float hgt = clamp(p.y / max(sh_len * 2.0, 1.0), 0.0, 1.0);
			light += ground_col * (sun_c * max(L.y, 0.0) * 0.3 + fire_c * 0.004) * (1.0 - 0.6 * hgt) * (1.0 - ao * 0.4);
			if (fb.w > 0.0 && fb_look.w > 0.0) {
				float dfb = max(length(ph - fb.xyz) - fb.w * 0.7, 0.0);
				float fl = bb_lum(fb_look.x) * fb_look.y * fb_look.w;
				float ring_k = (dr * kr + di_w) / max(wsum, 1e-9);
				// condensation sheets are lit by the ball, but they scatter only part of it toward the camera
				// (1.0 made them glow like neon tubes at 5-40 s)
				light += blackbody(fb_look.x) * fl * mix(0.25, 0.4, ring_k) * (fb.w * fb.w) / (dfb * dfb + fb.w * fb.w) * (1.0 - fbo);
			}
			// --- emission (planck radiance of opaque hot gas)
			vec3 emit = vec3(0.0);
			if (fbo > 0.0) {
				// convective cells: hotter rising plumes, cooler sinking lanes; cooler limb once it radiates
				float cell_lo = fb_look.x < 3500.0 ? 0.92 : 0.86;
				float cell_hi = fb_look.x < 3500.0 ? 1.05 : 1.08;
				float tloc = fb_look.x * mix(cell_lo, cell_hi, smoothstep(0.15, 0.85, fpatch)) * mix(1.08, 0.86, smoothstep(0.4, 1.0, lq));
				if (fb_grad > 0.0) {
					tloc = fb_look.x * mix(0.93, 1.04, smoothstep(0.15, 0.85, fpatch)) * mix(1.30, 0.75, smoothstep(0.1, 1.0, b_fb));
				}
				vec3 bc = blackbody(tloc);
				// film-like saturation of the incandescent colours (AgX would bleach them to white)
				bc = mix(bc, pow(bc, vec3(1.7)), 0.2);
				if (fb_tint.w > 0.0) {
					// additive ionised-air glow (Trinity's violet/green early colours)
					bc += fb_tint.rgb * fb_tint.w * 0.6;
				}
				float lum = bb_lum(tloc) * fb_look.y;
				lum /= 1.0 + lum * g_exposure / 6.0;
				if (fb_grad > 0.0) {
					lum *= smoothstep(1500.0, 1900.0, tloc);
				}
				lum *= 1.0 + fb_shape.y * (0.7 * smoothstep(0.8, 1.0, lq) - 0.5 * (fmott - 0.5));
				lum *= 1.0 - clamp(fb_shape.w, 0.0, 1.0) * smoothstep(0.35, 0.7, fpatch) * 0.85;
				emit += bc * lum * (fbo * kf) / max(wsum, 1e-9);
			}
			if (dh > 0.0 && head_heat.y > 0.0) {
				float dc = length(vec2(rc.x, rc.y + head_shape.x * 0.25)) / max(head_shape.x * head_heat.z, 1.0);
				float glow = exp(-dc * dc * 1.6) * (0.55 + 0.45 * smoothstep(0.2, 0.8, cauli));
				float tloc = mix(850.0, head_heat.x, glow);
				emit += blackbody(tloc) * bb_lum(tloc) * head_heat.y * glow * (dh * kh) / max(wsum, 1e-9);
			}
			if (dd > 0.0 && dcrack > 0.0 && fb_look.w > 0.0) {
				emit += blackbody(1500.0) * bb_lum(1500.0) * fb_look.y * dcrack * (dd * kd) / max(wsum, 1e-9);
			}
			vec3 src = albedo * light + emit;
			if (debug_mode == 1) { src = vec3(t_sun, sunlit * 0.5, ao); }
			if (debug_mode == 2) { src = L * 0.5 + 0.5; }
			if (debug_mode == 3) { src = vec3(t_sun) * 0.25; }
			if (debug_mode == 5) { src = vec3(macro, micro, far_s) * 0.3; }
			if (debug_mode == 6) { src = light * 0.1; }
			if (debug_mode == 12) { src = vec3(length(sun_c * sunlit), length(amb * ao), length(blackbody(fb_look.x) * bb_lum(fb_look.x) * fb_look.y * fb_look.w * 0.03)) * 0.01; }
			if (debug_mode == 13) { src = vec3(length(emit), length(albedo), fbo) * 0.01; }
			if (debug_mode == 10) { src = vec3(fb_look.x / 10000.0, fb_look.y / 4000.0, fbo) * 0.02; }
			if (debug_mode == 11) { src = emit * 0.0001; }
			if (debug_mode == 7) { src = vec3(macro, 0.0, 1.0 - macro) * 0.3; }
			if (debug_mode == 8) { src = vec3(micro, 0.0, 1.0 - micro) * 0.3; }
			if (debug_mode == 9) { src = vec3(far_s, 0.0, 1.0 - far_s) * 0.3; }
			if (debug_mode == 4) { src = vec3(od_local, od_far, 0.0) * 0.05; }
			acc += T * src * (1.0 - trans);
			T *= trans;
		}
		t += (th_min < 1e8 && sdf_rings(ph) < 2.0 * th_min) ? min(dt, th_min * 0.5) : dt;
	}
	float alpha = 1.0 - T;
	if (alpha < 0.002) {
		discard;
	}
	float th = first_hit > 0.0 ? first_hit : (t_enter + t_exit) * 0.5;
	vec4 fog = atm_fog(cam, cam + rd * th);
	vec3 col = mix(acc * g_exposure, fog.rgb * alpha, debug_mode > 0 ? 0.0 : fog.a * 0.65);
	ALBEDO = col;
	ALPHA = alpha;
}
