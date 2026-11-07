// Clipmap terrain: each level is an N x N grid snapped to 2*spacing, geomorphed at its rim,
// and discarding pixels already covered by the finer level. Height comes from the shared
// procedural function (terrain_common), plus blast deformations (crater, Sedan dome).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform vec3 g_blast_center;
global uniform float g_blast_age;
global uniform vec4 g_crater;       // radius, depth, rim height, progress 0..1
global uniform vec4 g_dome;         // radius, height, 0, 0
global uniform vec4 g_scorch;       // char radius, burn radius, glow 0..1, trinitite 0..1
global uniform vec4 g_scorch_color; // rgb tint of the char, unused w
global uniform vec4 g_shock;        // ground ring radius, strength, width, dust 0..1
global uniform vec4 g_cloud_pos;    // x, cap centre height, z, opacity
global uniform vec4 g_cloud_shape;  // cap radius, cap half-thickness, stem radius, stem top height
global uniform float g_snow;
global uniform vec4 g_water;        // x, z, radius, level

uniform float spacing = 1.0;
uniform vec2 level_center = vec2(0.0);
uniform float half_n = 64.0;
uniform float inner_half_extent = 0.0; // 0 for level 0
uniform vec2 inner_center = vec2(0.0);
uniform bool is_patch = false;
global uniform vec4 g_patch;   // high-resolution patch around ground zero: x, z, half extent, active

varying vec3 v_world;
varying float v_cloud_shadow;

float blast_deform(vec2 xz) {
	if (g_blast_age < 0.0) {
		return 0.0;
	}
	vec2 d = xz - g_blast_center.xz;
	float r = length(d);
	float off = 0.0;
	// crater (bowl + raised rim with ejecta)
	if (g_crater.x > 0.0) {
		float R = g_crater.x;
		float x = r / R;
		float bowl = -g_crater.y * (1.0 - x * x);
		bowl = x < 1.0 ? bowl : 0.0;
		float rim = g_crater.z * exp(-pow((x - 1.0) / 0.35, 2.0)) * (x > 0.6 ? 1.0 : 0.0);
		float ejecta = g_crater.z * 0.35 * exp(-max(x - 1.0, 0.0) * 1.6) * (x > 1.0 ? 1.0 : 0.0);
		off += (bowl + rim + ejecta) * g_crater.w;
	}
	// Sedan-type dome (heave)
	if (g_dome.x > 0.0) {
		float x = r / g_dome.x;
		off += g_dome.y * exp(-x * x * 2.2);
	}
	return off;
}

float full_height(vec2 xz) {
	float h = t_height(xz);
	// lagoon basin for the underwater shot
	if (g_water.z > 0.0) {
		float r = length(xz - g_water.xy);
		float k = smoothstep(g_water.z * 1.05, g_water.z * 0.8, r);
		float bed = g_water.w - 4.0 - 50.0 * smoothstep(g_water.z * 0.95, g_water.z * 0.3, r);
		h = mix(h, min(h, bed), k);
	}
	return h + blast_deform(xz);
}

void vertex() {
	vec2 grid = VERTEX.xz;
	vec2 xz0 = level_center + grid * spacing;
	float dist_edge = half_n - max(abs(grid.x), abs(grid.y));
	float morph = 1.0 - smoothstep(2.0, half_n * 0.3, dist_edge);
	vec2 odd = fract(grid * 0.5) * 2.0;
	vec2 xz = xz0 - odd * spacing * morph;
	float h = full_height(xz);
	VERTEX = vec3(xz.x, h, xz.y);
	v_world = VERTEX;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

// Coverage of a band |d| < hw box-filtered over the pixel footprint fw (in d units): stays exact
// when resolved and becomes a proportionally fainter line (never a full-width stripe) when not.
float band_cov(float d, float hw, float fw) {
	fw = max(fw, 1e-4);
	return clamp((min(d + 0.5 * fw, hw) - max(d - 0.5 * fw, -hw)) / fw, 0.0, 1.0);
}

float road_mask(vec2 xz) {
	// Main range road along the corridor and a few cross roads.
	float d1 = abs(xz.x - 340.0 + 0.02 * xz.y);
	float m = band_cov(d1, 3.5, fwidth(d1)) * step(xz.y, 200.0);
	float cross_period = 8000.0;
	float cy = abs(mod(xz.y + 1500.0, cross_period) - cross_period * 0.5);
	m = max(m, band_cov(cy, 3.0, min(fwidth(cy), 500.0)) * step(xz.y, -1500.0) * step(abs(xz.x), 30000.0));
	return m;
}

void fragment() {
	vec3 wp = v_world;
	vec2 xz = wp.xz;
	// discard where the finer level already draws
	if (inner_half_extent > 0.0) {
		vec2 q = abs(xz - inner_center);
		if (max(q.x, q.y) < inner_half_extent - spacing * 0.75) {
			discard;
		}
	}
	// the camera-centred clipmap yields to the fine patch around ground zero
	if (!is_patch && g_patch.w > 0.0) {
		vec2 qp = abs(xz - g_patch.xy);
		if (max(qp.x, qp.y) < g_patch.z - spacing * 0.75 && spacing > g_patch.w) {
			discard;
		}
	}
	float dist = length(wp - CAMERA_POSITION_WORLD);
	// Pixel footprint on the ground (major axis: the foreshortened depth direction at grazing
	// angles). Every procedural detail fades out by its own wavelength against it, a procedural
	// stand-in for anisotropic filtering: nothing aliases into horizontal streaks or stripes, and the
	// faded value is the detail's mean so near and far ground keep the same tone (no LOD seam).
	vec2 fwv = fwidth(xz);
	float fp = max(max(fwv.x, fwv.y), 1e-3);
	// albedo detail may be slightly under-sampled in depth (bushes read as short horizontal dashes,
	// as in real low-angle views) but never along the horizon: area footprint, capped by the major axis
	float fpa = min(1.6 * sqrt(max(fwv.x * fwv.y, 1e-6)), fp);
	// normal from the heights filtered over the footprint
	float eps = max(max(0.35, dist * 0.0012), fp * 0.5);
	float hc = full_height(xz);
	float hx = full_height(xz + vec2(eps, 0.0));
	float hz = full_height(xz + vec2(0.0, eps));
	vec3 n = normalize(vec3(hc - hx, eps, hc - hz));

	// close-range micro relief (sand ripples, pebbles): subtle, each octave fades once unresolved
	float f1 = (1.0 - smoothstep(0.2, 0.6, fp * 1.7)) * (1.0 - smoothstep(300.0, 900.0, dist));
	if (f1 > 0.0) {
		float f2 = 1.0 - smoothstep(0.2, 0.6, fp * 5.1);
		float e2 = 0.15;
		float d0 = vnoise(xz * 1.7) + 0.5 * f2 * vnoise(xz * 5.1);
		float dx = vnoise((xz + vec2(e2, 0.0)) * 1.7) + 0.5 * f2 * vnoise((xz + vec2(e2, 0.0)) * 5.1);
		float dz = vnoise((xz + vec2(0.0, e2)) * 1.7) + 0.5 * f2 * vnoise((xz + vec2(0.0, e2)) * 5.1);
		n = normalize(n + f1 * 0.1 * vec3(d0 - dx, 0.0, d0 - dz) / e2 * 0.15);
	}

	float slope = 1.0 - n.y;
	float hflat = t_height_flat(xz);
	float mm = t_mountain_mask(xz);
	// macro variation (octaves faded by the footprint: finest wavelengths ~2.2 km and ~200 m)
	float macro = t_fbm(xz * 0.00011 + vec2(5.2, 1.3), 4) * (1.0 - smoothstep(500.0, 2500.0, fp));
	float meso = t_fbm(xz * 0.0019 + vec2(-2.0, 7.0), 3) * (1.0 - smoothstep(40.0, 160.0, fpa));
	vec3 sand = vec3(0.60, 0.51, 0.40);
	vec3 playa = vec3(0.74, 0.69, 0.61);
	vec3 rock = vec3(0.36, 0.29, 0.23);
	vec3 rock_dark = vec3(0.22, 0.19, 0.17);
	vec3 scrub = vec3(0.33, 0.31, 0.24);
	// playa where the ground is low and flat (edge widened by the footprint); the bunker berm is
	// built from playa soil, so its crest does not cut a dark band against the pale playa beyond
	float fwh = fwidth(hflat);
	float playa_m = smoothstep(-21.0 + fwh, -24.5 - fwh, hflat) * (1.0 - mm);
	playa_m = max(playa_m, 0.5 * (1.0 - smoothstep(420.0, 700.0, length(xz))));
	vec3 col = mix(sand, playa, playa_m);
	col *= 0.86 + 0.22 * macro + 0.10 * meso;
	// mid-scale mottling (soil patches ~5-15 m), only where resolved
	float k1 = 1.0 - smoothstep(4.0, 12.0, fpa);
	float k2 = 1.0 - smoothstep(1.2, 4.0, fpa);
	col *= 1.0 + 0.10 * (vnoise(xz * 0.07 + vec2(7.1, 2.3)) - 0.5) * k1 + 0.08 * (vnoise(xz * 0.23 + vec2(1.7, 5.9)) - 0.5) * k2;
	// washes: broad, soft, broken lighter channels; filtered so they never become crisp
	// full-width "painted" stripes when seen edge-on
	float wf = abs(t_fbm(xz * 0.00052 + vec2(11.0, 3.0), 4));
	float wfw = fwidth(wf);
	float wash = (1.0 - smoothstep(0.0, 0.09 + wfw, wf)) * 0.09 / (0.09 + wfw);
	wash *= clamp(0.55 + meso * 1.5, 0.0, 1.0);
	col = mix(col, vec3(0.76, 0.70, 0.59), wash * 0.3 * (1.0 - mm));
	// scrub: broad patches (density) with speckles that fade into their mean once unresolved
	float dens_k = 1.0 - smoothstep(15.0, 60.0, fpa);
	float dens = mix(1.0, 0.35 + 1.3 * vnoise(xz * 0.013 + vec2(3.7, 1.9)), dens_k);
	float sp_fade = 1.0 - smoothstep(0.2, 0.6, fpa);
	float sp = smoothstep(0.66, 0.84, vnoise(xz * 0.45));
	// 0.144 = mean coverage of the speckle mask
	col = mix(col, scrub, clamp(mix(0.144, sp, sp_fade) * 0.45 * dens, 0.0, 1.0) * (1.0 - playa_m));
	// rock on mountains and slopes
	float rock_m = clamp(mm * 1.3, 0.0, 1.0) * smoothstep(0.02, 0.18, slope + 0.05 * meso);
	rock_m = max(rock_m, smoothstep(0.25, 0.45, slope));
	vec3 rk = mix(rock, rock_dark, clamp(0.5 + 0.8 * meso, 0.0, 1.0));
	col = mix(col, rk, rock_m);
	// roads (box-filtered: a sub-pixel road far away is a faint line, not a dark stripe)
	float road = road_mask(xz) * (1.0 - mm);
	col = mix(col, vec3(0.30, 0.28, 0.26), road * 0.8);
	// snow (Novaya Zemlya preset)
	float snow = g_snow * clamp(1.0 - slope * 1.6 + 0.3 * meso, 0.0, 1.0);
	col = mix(col, vec3(0.86, 0.89, 0.93), snow);

	float rough = mix(0.95, 0.75, snow);
	vec3 emis = vec3(0.0);
	// blast traces: scorch, trinitite, glowing ground
	if (g_blast_age >= 0.0) {
		float r = length(xz - g_blast_center.xz);
		if (g_scorch.y > 0.0) {
			float burn = 1.0 - smoothstep(g_scorch.x, g_scorch.y, r);
			float noise_edge = 0.85 + 0.3 * vnoise(xz / max(g_scorch.y, 1.0) * 9.0);
			burn = clamp(burn * noise_edge, 0.0, 1.0);
			col = mix(col, col * 0.55, burn * (1.0 - g_snow * 0.6));
			float char_m = 1.0 - smoothstep(g_scorch.x * 0.4, g_scorch.x, r);
			col = mix(col, g_scorch_color.rgb, char_m * 0.85);
			// trinitite: glassy green crust inside the inner zone
			float tri = g_scorch.w * (1.0 - smoothstep(g_scorch.x * 0.2, g_scorch.x * 0.75, r));
			col = mix(col, vec3(0.10, 0.22, 0.14), tri * (0.6 + 0.4 * vnoise(xz * 0.3)));
			rough = mix(rough, 0.25, tri);
			// incandescent ground right under the fireball
			float glow = g_scorch.z * (1.0 - smoothstep(0.0, g_scorch.x, r));
			emis += vec3(1.0, 0.35, 0.08) * glow * 6.0;
			// snow melts in the burn zone
			col = mix(col, col * 0.7, burn * g_snow * 0.5);
		}
		if (g_crater.x > 0.0) {
			float x = r / g_crater.x;
			float in_c = (1.0 - smoothstep(0.85, 1.05, x)) * g_crater.w;
			col = mix(col, vec3(0.30, 0.25, 0.20) * (0.8 + 0.4 * vnoise(xz * 0.2)), in_c * 0.75);
			// ejecta blanket
			float ej = smoothstep(0.9, 1.1, x) * exp(-max(x - 1.0, 0.0) * 1.2) * g_crater.w;
			col = mix(col, vec3(0.50, 0.42, 0.33), ej * 0.6);
		}
		// dust scoured by the shock front
		if (g_shock.y > 0.0) {
			float behind = smoothstep(g_shock.x, g_shock.x - g_shock.z * 4.0, r) * g_shock.w;
			col = mix(col, col * 0.88 + vec3(0.03, 0.025, 0.02), behind * 0.5);
		}
	}

	// cloud shadow (sun only, see light())
	float shadow = 0.0;
	if (g_cloud_pos.w > 0.0 && g_sun_dir.y > 0.02) {
		float hcap = g_cloud_pos.y;
		float s = (hcap - wp.y) / g_sun_dir.y;
		vec2 q = wp.xz + g_sun_dir.xz * s;
		float dcap = length(q - g_cloud_pos.xz);
		float cap_sh = 1.0 - smoothstep(g_cloud_shape.x * 0.75, g_cloud_shape.x * 1.08, dcap);
		// stem: closest approach of the sun ray to the vertical axis
		vec2 rel = g_cloud_pos.xz - wp.xz;
		vec2 ldir = normalize(g_sun_dir.xz + vec2(1e-5));
		float along = dot(rel, ldir);
		float perp = length(rel - ldir * along);
		float s_axis = along / max(length(g_sun_dir.xz), 1e-4);
		float h_at = wp.y + g_sun_dir.y * s_axis;
		float stem_sh = (1.0 - smoothstep(g_cloud_shape.z * 0.6, g_cloud_shape.z * 1.2, perp)) * step(0.0, along) * step(h_at, g_cloud_shape.w);
		shadow = clamp(max(cap_sh, stem_sh * 0.85) * g_cloud_pos.w, 0.0, 0.95);
	}
	v_cloud_shadow = shadow;

	// water (Baker lagoon): handled by a separate water mesh; darken wet shore
	if (g_water.z > 0.0) {
		float rw = length(xz - g_water.xy);
		float shore = smoothstep(g_water.z * 1.08, g_water.z, rw);
		col = mix(col, col * 0.55, shore);
	}

	FOG = vec4(0.0);
	ALBEDO = vec3(0.5);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = emis;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		att *= 1.0 - v_cloud_shadow;
	}
	// Wrap for soft terminators on dunes. A grazing sun also lights the grain tops and ripple
	// faces of sand far more than Lambert's N.L of the mean surface (particulate surfaces behave
	// closer to Lommel-Seeliger), so a low sun gets more wrap: warm sand at dawn, not a magenta
	// plane lit only by the blue sky.
	float low = LIGHT_IS_DIRECTIONAL ? 1.0 - smoothstep(0.03, 0.3, g_sun_dir.y) : 0.0;
	float w_off = mix(0.15, 0.25, low);
	float wrap = clamp((dot(NORMAL, LIGHT) + w_off) / (1.0 + w_off), 0.0, 1.0);
	DIFFUSE_LIGHT += mix(ndl, wrap, 0.3 + 0.2 * low) * att * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 24.0) * 0.04;
	SPECULAR_LIGHT += spec * att * LIGHT_COLOR * ndl;
}
