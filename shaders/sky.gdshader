// Procedural sky: single-scattering Rayleigh + Mie (compact Nishita) with ozone (Chappuis)
// absorption, analytic (Chapman) sun paths and a cheap multiple-scattering term; sun disc, stars at
// night, and the explosion's glow scattered in the atmosphere (shared with the aerial perspective).
// scripts/world/environment_ctl.gd has a CPU twin of scatter() (haze colours). KEEP IN SYNC.
shader_type sky;
render_mode use_debanding;

#include "res://shaders/atmos.gdshaderinc"

global uniform float g_flash;          // global scattered flash 0..N
global uniform float g_night;

uniform vec3 sun_dir = vec3(0.0, 0.5, -0.8);
uniform float sun_intensity = 22.0;
uniform vec3 moon_dir = vec3(0.3, 0.4, -0.8);
uniform float exposure_bias = 1.0;
uniform float turbidity = 1.0;     // scales Mie
uniform float star_intensity = 0.0;
uniform vec3 ground_color = vec3(0.35, 0.30, 0.25);
uniform float ms_strength = 0.03;  // multiple scattering (sky-lit air)
uniform float ozone = 1.0;         // ozone column (1 = ~300 DU)

const float R_E = 6360e3;
const float R_A = 6420e3;
const vec3 BETA_R = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const float BETA_M = 21e-6;
// ozone absorption (Chappuis band: absorbs orange-red, keeps the twilight zenith blue)
const vec3 BETA_O = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const float H_R = 7994.0;
const float H_M = 1200.0;
const float R_OZ = 6385e3;         // ozone layer (tent profile peaking at 25 km, 15 km half width)
const float OZ_COL = 15000.0;      // its vertical column (m of peak density)
const vec3 MS_TINT = vec3(0.6, 0.8, 1.0);
const vec3 MS_TINT_LOW = vec3(0.35, 0.6, 1.0);

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

// Chapman function (Schueler's approximation) for an upward ray.
float ch_up(float X, float mu) {
	float c = sqrt(0.5 * PI * X);
	return c / ((c - 1.0) * mu + 1.0);
}

// Density-weighted path length (m) of an exponential layer from radius r towards cos(zenith) mu.
float chapman_od(float r, float mu, float H) {
	float e = exp(-(r - R_E) / H);
	if (mu >= 0.0) {
		return H * e * ch_up(r / H, mu);
	}
	float r0 = r * sqrt(max(1.0 - mu * mu, 0.0));
	if (r0 < R_E) {
		return 1e7;   // the Earth is in the way
	}
	return H * (2.0 * exp(-(r0 - R_E) / H) * sqrt(0.5 * PI * r0 / H) - e * ch_up(r / H, -mu));
}

// Optical depth from p to the top of the atmosphere along L.
vec3 light_tau(vec3 p, vec3 L, float bm) {
	float r = length(p);
	float mu = dot(p, L) / r;
	float rr = min(r / R_OZ, 0.999);
	float od_o = OZ_COL / sqrt(max(1.0 - rr * rr * (1.0 - mu * mu), 0.0081));
	return BETA_R * chapman_od(r, mu, H_R) + bm * 1.1 * chapman_od(r, mu, H_M) + ozone * BETA_O * od_o;
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
	float mu = dot(rd, L);
	float pr = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float g = 0.76;
	float pm = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
	float bm = BETA_M * turbidity;
	// multiple scattering: the air is also lit by the blue sky, itself lit by the sun above the
	// dense layers (approximated by the sun's transmittance at 12 km)
	vec3 t_hi = exp(-light_tau(vec3(0.0, R_E + 12000.0, 0.0), L, bm));
	// (at twilight the light reaching the low air is the blue upper sky, not the reddened sun)
	vec3 tint = mix(MS_TINT_LOW, MS_TINT, smoothstep(0.05, 0.4, L.y));
	vec3 ms = ms_strength * t_hi * tint * clamp(L.y * 4.0 + 0.6, 0.0, 1.0);
	vec3 tau_v = vec3(0.0);
	vec3 sum_r = vec3(0.0);
	vec3 sum_m = vec3(0.0);
	vec3 sum_ms = vec3(0.0);
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
		float d_o = max(0.0, 1.0 - abs(h - 25000.0) / 15000.0) * seg;
		vec3 dtau = BETA_R * dr + bm * 1.1 * dm + ozone * BETA_O * d_o;
		vec3 tv = exp(-(tau_v + 0.5 * dtau));
		vec3 att = tv * exp(-light_tau(p, L, bm));
		sum_r += dr * att;
		sum_m += dm * att;
		sum_ms += (BETA_R * dr + bm * dm) * tv;
		tau_v += dtau;
	}
	return intensity * (sum_r * BETA_R * pr + sum_m * bm * pm + sum_ms * ms);
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
	vec3 col = vec3(0.0);
	if (L.y > -0.2) {
		col = scatter(rd_s, L, sun_intensity);
	}
	float y = max(rd.y, 0.0);
	// night sky: moonlit scattering, airglow (brighter toward the horizon) and stars
	if (g_night > 0.0) {
		vec3 M = normalize(moon_dir);
		col += scatter(rd_s, M, 0.012) * g_night;
		col += vec3(0.0010, 0.0014, 0.0026) * (1.0 + 1.5 * exp(-y * 8.0)) * g_night;
		if (rd.y > 0.0) {
			col += stars(rd) * star_intensity * smoothstep(0.0, 0.12, rd.y) * 0.02;
		}
		float md = dot(rd, M);
		col += vec3(0.9, 0.9, 0.85) * smoothstep(0.99996, 0.99999, md) * 0.6 * g_night;
	}
	// horizon haze: blend into the colour the aerial perspective fades distant terrain into
	// (EnvironmentCtl derives it from this sky, so the blend only removes the seam at the horizon)
	float hz = exp(-y * 40.0) * 0.85;
	col = mix(col, atm_haze_color(rd_s), hz);
	// sun disc, attenuated along the same path as the sky
	if (!AT_CUBEMAP_PASS && L.y > -0.02) {
		float sd = dot(rd, L);
		float disc = smoothstep(0.999955, 0.99999, sd);
		if (disc > 0.0) {
			vec3 sun_tr = exp(-light_tau(vec3(0.0, R_E + 30.0, 0.0), L, BETA_M * turbidity));
			col += disc * sun_tr * 4000.0 * step(-0.02, rd.y);
		}
	}
	// below the horizon: dim ground colour (mostly hidden by terrain)
	if (rd.y < 0.0) {
		col *= mix(1.0, 0.75, smoothstep(0.0, -0.2, rd.y));
	}
	// explosion glow scattered by the air around the fireball (normalised to the ball's radiance)
	vec3 flash_col = vec3(0.9, 0.93, 1.0);
	if (g_fireball_color.w > 0.0) {
		if (!AT_CUBEMAP_PASS) {
			col += atm_fireball_glow(POSITION, rd, 1.0);
		}
		// the whole-sky flash is the same light scattered again: half its colour, half sky blue
		flash_col = mix(flash_col, atm_fireball_tint(POSITION), 0.5);
	}
	col += g_flash * flash_col * 0.4;
	COLOR = col * exposure_bias;
}
