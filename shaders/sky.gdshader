// Procedural sky: single-scattering Rayleigh + Mie (compact Nishita), sun disc, stars at night,
// and the explosion's glow scattered in the atmosphere (fireball direction / flash).
shader_type sky;
render_mode use_debanding;

global uniform vec4 g_fireball;        // xyz world pos, w radius
global uniform vec4 g_fireball_color;  // rgb colour, w luminous intensity (relative)
global uniform float g_flash;          // global scattered flash 0..N
global uniform float g_night;

uniform vec3 sun_dir = vec3(0.0, 0.5, -0.8);
uniform float sun_intensity = 22.0;
uniform vec3 moon_dir = vec3(0.3, 0.4, -0.8);
uniform float exposure_bias = 1.0;
uniform float turbidity = 1.0;     // scales Mie
uniform float star_intensity = 0.0;
uniform vec3 ground_color = vec3(0.35, 0.30, 0.25);

const float R_E = 6360e3;
const float R_A = 6420e3;
const vec3 BETA_R = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const float BETA_M = 21e-6;
const float H_R = 7994.0;
const float H_M = 1200.0;

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float d = b * b - c;
	if (d < 0.0) {
		return vec2(1e9, -1e9);
	}
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

vec3 scatter(vec3 rd, vec3 L, float intensity) {
	vec3 ro = vec3(0.0, R_E + 30.0, 0.0);
	vec2 ta = ray_sphere(ro, rd, R_A);
	float t_end = ta.y;
	vec2 tg = ray_sphere(ro, rd, R_E);
	if (tg.x > 0.0) {
		t_end = min(t_end, tg.x);
	}
	const int STEPS = 16;
	const int LSTEPS = 4;
	float od_r = 0.0;
	float od_m = 0.0;
	vec3 sum_r = vec3(0.0);
	vec3 sum_m = vec3(0.0);
	float mu = dot(rd, L);
	float pr = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float g = 0.76;
	float pm = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
	float bm = BETA_M * turbidity;
	float t_prev = 0.0;
	for (int i = 0; i < STEPS; i++) {
		float x1 = float(i + 1) / float(STEPS);
		float t_cur = t_end * x1 * x1 * x1;
		float seg = t_cur - t_prev;
		vec3 p = ro + rd * (0.5 * (t_prev + t_cur));
		t_prev = t_cur;
		float h = length(p) - R_E;
		float dr = exp(-h / H_R) * seg;
		float dm = exp(-h / H_M) * seg;
		od_r += dr;
		od_m += dm;
		vec2 tl = ray_sphere(p, L, R_A);
		float lseg = tl.y / float(LSTEPS);
		float lod_r = 0.0;
		float lod_m = 0.0;
		bool blocked = false;
		for (int j = 0; j < LSTEPS; j++) {
			vec3 q = p + L * (lseg * (float(j) + 0.5));
			float hq = length(q) - R_E;
			if (hq < 0.0) {
				blocked = true;
				break;
			}
			lod_r += exp(-hq / H_R) * lseg;
			lod_m += exp(-hq / H_M) * lseg;
		}
		if (!blocked) {
			vec3 tau = BETA_R * (od_r + lod_r) + bm * 1.1 * (od_m + lod_m);
			vec3 att = exp(-tau);
			sum_r += dr * att;
			sum_m += dm * att;
		}
	}
	return intensity * (sum_r * BETA_R * pr + sum_m * bm * pm);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 stars(vec3 rd) {
	vec3 col = vec3(0.0);
	for (int layer = 0; layer < 2; layer++) {
		float scale = layer == 0 ? 220.0 : 520.0;
		vec3 p = rd * scale;
		vec3 cell = floor(p);
		vec3 f = fract(p) - 0.5;
		float h = hash13(cell + float(layer) * 17.0);
		if (h > 0.985) {
			float b = (h - 0.985) / 0.015;
			float d = length(f);
			float tint = hash13(cell * 1.7);
			vec3 sc = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.86, 0.7), tint);
			col += sc * b * b * smoothstep(0.35, 0.0, d) * (layer == 0 ? 3.0 : 1.2);
		}
	}
	return col;
}

void sky() {
	vec3 rd = EYEDIR;
	vec3 L = normalize(sun_dir);
	vec3 rd_s = normalize(vec3(rd.x, max(rd.y, 0.0015), rd.z));
	vec3 col = scatter(rd_s, L, sun_intensity);
	// night sky: moonlit scattering + stars
	if (g_night > 0.0) {
		vec3 M = normalize(moon_dir);
		col += scatter(rd_s, M, 0.012) * g_night;
		col += vec3(0.0006, 0.0009, 0.0018) * g_night;
		if (rd.y > 0.0) {
			col += stars(rd) * star_intensity * smoothstep(0.0, 0.12, rd.y) * 0.02;
		}
		float md = dot(rd, M);
		col += vec3(0.9, 0.9, 0.85) * smoothstep(0.99996, 0.99999, md) * 0.6 * g_night;
	}
	// sun disc
	if (!AT_CUBEMAP_PASS) {
		float sd = dot(rd, L);
		float disc = smoothstep(0.999955, 0.99999, sd);
		vec3 sun_tr = exp(-BETA_R * 8000.0 * 1.0 / max(L.y + 0.04, 0.02) - BETA_M * 1200.0 / max(L.y + 0.04, 0.02));
		col += disc * sun_tr * 4000.0 * step(-0.02, rd.y);
	}
	// below the horizon: dim ground colour (mostly hidden by terrain)
	if (rd.y < 0.0) {
		col *= mix(1.0, 0.75, smoothstep(0.0, -0.2, rd.y));
	}
	// explosion glow scattered by the air around the fireball
	if (!AT_CUBEMAP_PASS && g_fireball_color.w > 0.0) {
		vec3 fd = normalize(g_fireball.xyz);
		float dist = length(g_fireball.xyz);
		float ang_r = g_fireball.w / max(dist, 1.0);
		float c = dot(rd, fd);
		float ang = acos(clamp(c, -1.0, 1.0));
		float halo = exp(-max(ang - ang_r, 0.0) / (ang_r * 2.0 + 0.02)) * 0.6 + exp(-ang / 0.35) * 0.25 + 0.06;
		col += g_fireball_color.rgb * g_fireball_color.w * halo * 0.02;
	}
	col += g_flash * vec3(0.9, 0.93, 1.0) * 0.4;
	COLOR = col * exposure_bias;
}
