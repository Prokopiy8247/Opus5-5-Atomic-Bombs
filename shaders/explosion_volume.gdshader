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
uniform vec4 fb_tint = vec4(1.0, 1.0, 1.0, 0.0);     // multiplicative tint (Trinity purple/green), w = strength

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

// --- ground skirt / base surge
uniform vec4 skirt = vec4(0.0);                      // outer radius, height, density, inner radius rel
uniform vec4 skirt_col = vec4(0.6, 0.52, 0.42, 0.0);

// --- condensation rings (y, radius, thickness, opacity) and ice cap / pileus shells
uniform vec4 rings[4];
uniform vec4 ice = vec4(0.0);        // centre y, radius, half height, opacity
uniform vec4 ice2 = vec4(0.0);

uniform vec3 ground_col = vec3(0.55, 0.47, 0.38);
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
	float rxz = length(q.xz);
	// mature mushroom: dome on top of a vortex torus, flat-ish underside
	float dome = sd_ellipsoid(q - vec3(0.0, H * 0.20, 0.0), vec3(R * 0.90, H * 0.80, R * 0.90));
	float a = R * 0.62;
	float b = H * 0.62;
	float tor = length(vec2((rxz - a) * 0.92, q.y + H * 0.25)) - b;
	float mush = smin(dome, tor, H * 0.30);
	// under-cut around the stem axis (the hollow under the cap)
	mush = max(mush, -(length(vec2(rxz, (q.y + H * 1.05) * 1.4)) - R * 0.30));
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
	return r;
}

float sdf_stem(vec3 p) {
	if (stem.z <= 0.0) {
		return 1e9;
	}
	float r = stem_radius_at(p.y);
	float d = length(p.xz) - r;
	if (stem_shape.z > 0.0) {
		float wall = r * stem_shape.z;
		d = abs(d + wall) - wall;
	}
	float dv = max(stem.x - p.y, p.y - stem.y);
	return max(d, dv);
}

float sdf_skirt(vec3 p) {
	if (skirt.x <= 0.0) {
		return 1e9;
	}
	float r = length(p.xz);
	float h = skirt.y;
	float R = skirt.x;
	// rolling front (torus) + a lower sheet that thickens toward the centre
	float tor = length(vec2((r - (R - h)) * 0.8, p.y - h * 0.5)) - h * 0.7;
	float inner = R * skirt.w;
	float hh = h * mix(0.9, 0.35, clamp(r / R, 0.0, 1.0));
	float sheet = max(max(p.y - hh, -p.y - h * 0.2), max(inner - r, r - (R - h)));
	return min(tor, sheet);
}

float sdf_rings(vec3 p) {
	float d = 1e9;
	float r = length(p.xz);
	for (int i = 0; i < 4; i++) {
		if (rings[i].w > 0.0) {
			float dr = length(vec2((r - rings[i].y) * 0.35, (p.y - rings[i].x) * 1.2)) - rings[i].z;
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
	float shell = abs(e) - s.z * 0.07;
	return max(shell, -q.y - s.z * 0.1);
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
		d += clamp(-sdf_head(p) / (head_shape.x * 0.10), 0.0, 1.0) * head_shape.z;
	}
	if (stem.z > 0.0) {
		d += clamp(-sdf_stem(p) / (stem.z * 0.25), 0.0, 1.0) * stem.w;
	}
	if (fb.w > 0.0) {
		d += clamp(-sdf_fireball(p) / (fb.w * 0.3), 0.0, 1.0) * fb_look.w * 2.0;
	}
	if (skirt.x > 0.0) {
		d += clamp(-sdf_skirt(p) / (skirt.y * 0.4), 0.0, 1.0) * skirt.z;
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
	float amp = head_detail.x * min(R, H * 1.4);
	if (base > amp * 1.2) {
		return 0.0;
	}
	// rolling vortex: rotate lookups in the (radial, y) plane around the core ring
	float rxz = length(q.xz);
	vec2 dir = rxz > 1e-3 ? q.xz / rxz : vec2(1.0, 0.0);
	float a = R * 0.62;
	vec2 rc = vec2(rxz - a, q.y + H * 0.25);
	rc_out = rc;
	float roll = head_shape.w * smoothstep(0.0, a * 0.8, rxz) * head_shape.y;
	float cr = cos(roll);
	float sr = sin(roll);
	vec2 rr = vec2(cr * rc.x - sr * rc.y, sr * rc.x + cr * rc.y);
	vec3 qn = vec3(dir.x * (rr.x + a), rr.y - H * 0.25, dir.y * (rr.x + a));
	float cell = max(R, H) * head_heat.w;
	vec3 np = qn / cell + vec3(seed * 1.3, seed * 0.37, seed * 0.71);
	float warp = nlf(np * 0.13) - 0.5;
	float b1 = nbl(np * 0.32 + warp * 0.35);
	float b2 = nbl(np * 0.95 + 5.3);
	float b3 = nbl(np * 2.6 + 11.0);
	float sharp = head_detail.y;
	cauli = pow(b1, sharp) * 0.62 + pow(b2, sharp) * 0.28 + b3 * 0.10;
	float disp = (cauli - 0.42) * 1.35 + warp * 0.6;
	float dn = base - disp * amp;
	float edge = H * 0.03;
	float dens = smoothstep(edge, -edge * 3.0, dn);
	// gentle erosion of the thin outer fringe only (no speckles)
	dens *= 1.0 - head_detail.z * 0.5 * (1.0 - dens) * smoothstep(0.35, 0.65, 1.0 - b2);
	if (head_heat.y > 0.0) {
		float dc = length(rc) / max(H * head_heat.z, 1.0);
		float hot = exp(-dc * dc * 2.0) * clamp(head_heat.y / 300.0, 0.0, 1.0);
		dens *= 1.0 - 0.75 * hot;
	}
	dens = dens < 0.04 ? 0.0 : dens;
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
	if (base > amp) {
		return 0.0;
	}
	vec3 np = vec3(p.x, (p.y - age * stem_shape.w) / max(stem_col.w, 1.0), p.z) / (max(stem.z, 1.0) * 1.3) + vec3(seed * 0.21);
	float n = nbl(np * 0.6) * 0.65 + nbl(np * 1.7 + 3.0) * 0.35;
	float lf = nlf(np * 0.25 + 4.0);
	n_out = n;
	float dn = base - ((n - 0.45) * 0.9 + (lf - 0.5) * 0.7) * amp;
	float jetk = 1.0;
	if (stem_cone > 0.0) {
		// ejecta crown: radial jets of soil fanning out of the crater, ragged at the top
		float h01 = clamp((p.y - stem.x) / max(stem.y - stem.x, 1.0), 0.0, 1.0);
		float ang = atan(p.z, p.x);
		float jet = nbl(vec3(ang * 2.2 + seed, h01 * 0.9, seed * 0.3)) * 0.7 + nbl(vec3(ang * 5.1, h01 * 2.3 + 1.7, seed)) * 0.3;
		jet = smoothstep(0.35, 0.75, jet);
		dn -= (jet - 0.5) * r * 0.55 * h01;
		jetk = mix(0.35, 1.35, jet) * (1.0 - 0.6 * smoothstep(0.75, 1.0, h01) * (1.0 - n));
	}
	float dens = smoothstep(r * 0.04, -r * 0.3, dn) * jetk;
	return dens * stem.w;
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
	float n1 = nlf(nq);
	float n2 = nbl(nq * 2.3 + 3.1);
	float disp = (n1 - 0.5) * 2.0 * fb_look.z + (n2 - 0.5) * fb_look.z * 0.8;
	float mott = 0.0;
	if (fb_shape.y > 0.0) {
		mott = nbl(q * 2.2 + seed);
		disp += fb_shape.y * (mott - 0.5) * 0.10;
	}
	float dd = lq - 1.0 - disp;
	lq_out = lq;
	patch_out = nbl(nq * 1.3 + 7.7) * 0.6 + nbl(nq * 3.7 + 1.9) * 0.4;
	mott_out = mott;
	return smoothstep(0.02, -0.06, dd);
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
	dt = max(dt, scale_hint * 0.01);
	float dither = hash12(FRAGCOORD.xy + fract(age * 7.13) * 91.0);
	float t = t_enter + dt * dither;

	vec3 L = normalize(g_sun_dir);
	float mu = dot(rd, L);
	float phase = mix(hg(mu, 0.55), hg(mu, -0.2), 0.35) * 4.0 * PI;
	phase = mix(1.0, phase, 0.8);
	vec3 sun_c = g_sun_light.rgb;
	vec3 amb = g_ambient.rgb * g_ambient.w;
	vec3 fire_c = g_fireball_color.rgb * g_fireball_color.w;
	vec3 head_col = mix(head_col_a.rgb, head_col_b.rgb, head_col_a.w);

	vec3 acc = vec3(0.0);
	float T = 1.0;
	float first_hit = -1.0;
	int max_iter = int(steps) * 2 + 48;
	float sh_len = max(min(head.w, head_shape.x * 2.5), max(fb.w * 1.5, stem.z * 3.0)) + 1.0;
	for (int i = 0; i < 700; i++) {
		if (i >= max_iter || t > t_exit || T < 0.006) {
			break;
		}
		vec3 p = ro + rd * t;
		float sd = scene_sdf(p);
		float margin = scale_hint * 0.4;
		if (sd > margin) {
			t += max(sd - margin * 0.9, dt);
			continue;
		}
		// --- gather densities and materials
		float cauli;
		vec2 rc;
		float dh = head_density(p, cauli, rc);
		float sn;
		float ds = stem_density(p, sn);
		float kn;
		float dk = skirt_density(p, kn);
		float lq;
		float fpatch;
		float fmott;
		float df = fireball_density(p, lq, fpatch, fmott);
		// rings / shells
		float dr = 0.0;
		float rdd = sdf_rings(p);
		if (rdd < 900.0) {
			float n = nlf(p * 0.00035 + seed) * 0.6 + nbl(p * 0.0011 + seed) * 0.4;
			float op = max(max(rings[0].w, rings[1].w), max(rings[2].w, rings[3].w));
			dr = smoothstep(200.0, -400.0, rdd - (n - 0.5) * 900.0) * op * 0.22 * smoothstep(0.3, 0.6, n);
		}
		float di = 0.0;
		for (int k = 0; k < 2; k++) {
			vec4 sh = k == 0 ? ice : ice2;
			if (sh.w > 0.0) {
				float dsh = sdf_shell(p, sh);
				if (dsh < sh.z * 0.25) {
					float n = nlf(p / (sh.y * 0.5) + seed + float(k) * 3.0);
					di += smoothstep(sh.z * 0.04, -sh.z * 0.06, dsh - (n - 0.5) * sh.z * 0.2) * sh.w * 0.45;
				}
			}
		}
		float fbo = df * fb_look.w;
		float total = dh + ds + dk + fbo + dr + di;
		if (total > 0.002) {
			if (first_hit < 0.0) {
				first_hit = t;
			}
			// extinction coefficients scale with structure size (optically thick clouds)
			float kh = 22.0 / max(min(head.w, head_shape.x * 2.0), 1.0);
			float ks = 7.0 / max(stem.z, 1.0);
			float kk = 5.0 / max(skirt.y, 1.0);
			float kf = 14.0 / max(fb.w, 1.0);
			float kr = 1.0 / 700.0;
			float ki = 1.0 / max(ice.z, 300.0);
			float wsum = dh * kh + ds * ks + dk * kk + fbo * kf + dr * kr + di * ki;
			float trans = exp(-wsum * dt);
			vec3 c_head = head_col * (0.78 + 0.32 * cauli);
			float lowk = clamp(-rc.y / max(head_shape.x, 1.0), 0.0, 1.0) * head_col_b.w;
			c_head *= 1.0 - 0.45 * lowk;
			vec3 c_stem = stem_col.rgb * (0.8 + 0.35 * sn);
			vec3 c_skirt = skirt_col.rgb * (0.8 + 0.35 * kn) * 0.65;
			vec3 c_fb = mix(vec3(0.30, 0.13, 0.06), vec3(0.10, 0.07, 0.05), fb_shape.w);
			vec3 albedo = (c_head * dh * kh + c_stem * ds * ks + c_skirt * dk * kk + c_fb * fbo * kf + vec3(0.97) * (dr * kr + di * ki)) / max(wsum, 1e-9);

			// --- lighting
			// local self-shadow: one noisy tap toward the sun reveals the billows
			float c2;
			vec2 rc2;
			float s2;
			float hl = min(head.w, head_shape.x * 1.5);
			float dh_l = dh > 0.0 ? head_density(p + L * hl * 0.03, c2, rc2) : 0.0;
			float dh_l2 = dh > 0.0 ? head_density(p + L * hl * 0.08, c2, rc2) : 0.0;
			float ds_l = ds > 0.0 ? stem_density(p + L * stem.z * 0.15, s2) : 0.0;
			float od_local = (dh_l * 0.03 + dh_l2 * 0.05) * kh * hl + ds_l * ks * stem.z * 0.12;
			float od = 0.0;
			od += cheap_density(p + L * sh_len * 0.12) * 0.25;
			od += cheap_density(p + L * sh_len * 0.35) * 0.35;
			od += cheap_density(p + L * sh_len * 0.80) * 0.40;
			float od_far = od * sh_len * (dh > ds ? kh : ks) * 0.35;
			// macro shape shading from the analytic SDF gradient (keeps the big forms readable),
			// micro self-shadowing of the billows, long-range shadowing, multiple-scattering floor
			float macro = 1.0;
			if (dh > ds && head.w > 0.0) {
				vec3 q = p - head.xyz;
				float e = head_shape.x * 0.08;
				vec3 nrm = normalize(vec3(
					sdf_head_base(q + vec3(e, 0.0, 0.0)) - sdf_head_base(q - vec3(e, 0.0, 0.0)),
					sdf_head_base(q + vec3(0.0, e, 0.0)) - sdf_head_base(q - vec3(0.0, e, 0.0)),
					sdf_head_base(q + vec3(0.0, 0.0, e)) - sdf_head_base(q - vec3(0.0, 0.0, e))));
				macro = clamp(dot(nrm, L) * 0.55 + 0.45, 0.0, 1.0);
				macro = macro * macro;
			} else if (ds > 0.0) {
				vec2 nr = normalize(p.xz + vec2(1e-3));
				macro = clamp(dot(vec3(nr.x, 0.15, nr.y), L) * 0.55 + 0.5, 0.0, 1.0);
			}
			float micro = mix(1.0, exp(-od_local * 0.6), 0.65);
			float far_s = exp(-od_far);
			float t_sun = macro * micro * far_s;
			float sunlit = t_sun * mix(1.0, phase, 0.5) * 1.1 + 0.05 * exp(-od_far * 0.3) * (0.3 + 0.7 * macro);
			float od_up = cheap_density(p + vec3(0.0, sh_len * 0.3, 0.0));
			float dh_up = dh > 0.0 ? head_density(p + vec3(0.0, hl * 0.12, 0.0), c2, rc2) : 0.0;
			float ao = exp(-od_up * 1.4 - dh_up * 1.5) * 0.85 + 0.15;
			vec3 light = sun_c * sunlit + amb * ao * 0.6;
			float hgt = clamp(p.y / max(sh_len * 2.0, 1.0), 0.0, 1.0);
			light += ground_col * (sun_c * max(L.y, 0.0) * 0.18 + fire_c * 0.004) * (1.0 - hgt) * (1.0 - ao * 0.6);
			if (fb.w > 0.0 && fb_look.w > 0.0) {
				float dfb = max(length(p - fb.xyz) - fb.w * 0.7, 0.0);
				float fl = bb_lum(fb_look.x) * fb_look.y * fb_look.w;
				light += blackbody(fb_look.x) * fl * 0.03 * (fb.w * fb.w) / (dfb * dfb + fb.w * fb.w) * (1.0 - fbo);
			}
			// --- emission (planck radiance of opaque hot gas)
			vec3 emit = vec3(0.0);
			if (fbo > 0.0) {
				float tloc = fb_look.x * mix(0.82, 1.12, fpatch) * mix(1.1, 0.92, clamp(lq, 0.0, 1.0));
				vec3 bc = blackbody(tloc);
				if (fb_tint.w > 0.0) {
					bc = mix(bc, bc * fb_tint.rgb, fb_tint.w);
				}
				float lum = bb_lum(tloc) * fb_look.y;
				lum *= 1.0 + fb_shape.y * (0.7 * smoothstep(0.8, 1.0, lq) - 0.5 * (fmott - 0.5));
				lum *= 1.0 - fb_shape.w * smoothstep(0.35, 0.7, fpatch) * 0.85;
				emit += bc * lum * (fbo * kf) / max(wsum, 1e-9);
			}
			if (dh > 0.0 && head_heat.y > 0.0) {
				float dc = length(rc) / max(head_shape.x * head_heat.z, 1.0);
				float glow = exp(-dc * dc * 1.6) * (0.55 + 0.45 * smoothstep(0.2, 0.8, cauli));
				float tloc = mix(850.0, head_heat.x, glow);
				emit += blackbody(tloc) * bb_lum(tloc) * head_heat.y * glow * (dh * kh) / max(wsum, 1e-9);
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
		t += dt;
	}
	float alpha = 1.0 - T;
	if (alpha < 0.002) {
		discard;
	}
	float th = first_hit > 0.0 ? first_hit : (t_enter + t_exit) * 0.5;
	vec4 fog = atm_fog(cam, cam + rd * th);
	vec3 col = mix(acc * g_exposure, fog.rgb * alpha, debug_mode > 0 ? 0.0 : fog.a);
	ALBEDO = col;
	ALPHA = alpha;
}
