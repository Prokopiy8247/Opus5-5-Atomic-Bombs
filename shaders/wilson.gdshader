// Wilson condensation cloud: a thick, milky veil of droplets that forms behind the shock front in
// humid air during the rarefaction phase and evaporates within ~1-3 s (in growing holes and from
// the bottom up). Rendered analytically, without a raymarch: the view ray is intersected with a
// flattened thick shell (outer radius 1, inner 1 - thick, in units of `radius`), and the optical
// depth of each wall crossing is its length x one billowy noise lookup at its midpoint. So the
// whole dome is filled (no limb-only 'frosted glass'), the silhouette is lumpy and soft, and the
// veil is lit by the sun and glows around the fireball inside it.
// part 0 = far wall (drawn before the explosion volume), part 1 = near wall (drawn after it).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, fog_disabled, shadows_disabled;

#include "res://shaders/atmos.gdshaderinc"

global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;

uniform sampler3D noise_b : filter_linear_mipmap, repeat_enable;
uniform sampler3D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 centre = vec3(0.0); // shell centre (world)
uniform float radius = 100.0;    // outer horizontal radius (m)
uniform float flatten = 1.0;     // vertical / horizontal axis ratio
uniform float thick = 0.3;       // wall thickness (fraction of the radius)
uniform float tau = 1.0;         // optical depth across the wall (normal incidence, mean density)
uniform float evap = 0.0;        // 0..1 evaporation (holes grow, veil thins)
uniform float clear_y = -1.2;    // evaporated below this local height (fraction of the vertical radius)
uniform float discs = 0.0;       // 0 = smooth dome, 1 = stacked condensation discs
uniform float ground_y = 0.0;    // ground level relative to the centre (m)
uniform float part = 1.0;        // 1 = near wall, 0 = far wall
uniform float seed = 0.0;
uniform float age = 0.0;

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 fw = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(fw - cam);
	vec3 sc = vec3(radius, radius * flatten, radius);
	vec3 o = (cam - centre) / sc;
	vec3 dl = rd / sc;
	float qa = dot(dl, dl);
	float qb = dot(o, dl);
	float oo = dot(o, o);
	float disc_o = qb * qb - qa * (oo - 1.0);
	if (disc_o <= 0.0) {
		discard;
	}
	float sq_o = sqrt(disc_o);
	float t0 = (-qb - sq_o) / qa;
	float t3 = (-qb + sq_o) / qa;
	float ri = 1.0 - thick;
	float disc_i = qb * qb - qa * (oo - ri * ri);
	float t1 = 0.5 * (t0 + t3);
	float t2 = t1;
	if (disc_i > 0.0) {
		float sq_i = sqrt(disc_i);
		t1 = (-qb - sq_i) / qa;
		t2 = (-qb + sq_i) / qa;
	}
	float ta = part > 0.5 ? t0 : t2;
	float tb = part > 0.5 ? t1 : t3;
	ta = max(ta, 0.0);
	// opaque scene (terrain, water, bunker) and the ground plane clip the wall
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	tb = min(tb, length(vp.xyz));
	float gy = centre.y + ground_y;
	if (abs(rd.y) > 1e-6) {
		float tg = (gy - cam.y) / rd.y;
		if (rd.y < 0.0) {
			tb = min(tb, tg);
		} else {
			ta = max(ta, tg);
		}
	} else if (cam.y < gy) {
		discard;
	}
	float seg = tb - ta;
	if (seg <= 0.0) {
		discard;
	}
	vec3 mid = cam + rd * (ta + tb) * 0.5;
	vec3 q = (mid - centre) / sc;                    // unit-shell coordinates
	// billowy droplet density: big lumps + finer curds, slowly churning
	vec3 np = q * 1.15 + vec3(seed, seed * 0.37, age * 0.04);
	float n1 = texture(noise_b, np).r;
	float n2 = texture(noise_a, q * 2.6 + vec3(seed * 0.5, age * 0.03, 1.7)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	float dens = 0.35 + 1.0 * smoothstep(0.2, 0.8, n);
	// stacked discs (megaton humid layers)
	if (discs > 0.0) {
		float band = sin(q.y * 11.0 + (n2 - 0.5) * 4.0 + seed) * 0.5 + 0.5;
		dens *= mix(1.0, 0.15 + 1.6 * smoothstep(0.35, 0.85, band), discs);
	}
	// evaporation: holes open in the thin parts, then everything thins out
	dens *= smoothstep(evap - 0.05, evap + 0.35, n * 0.9 + 0.1) * (1.0 - 0.6 * evap);
	// clears from the bottom up (noisy edge)
	float qy = q.y + (n - 0.5) * 0.35;
	dens *= smoothstep(clear_y - 0.15, clear_y + 0.25, qy);
	// lumpy, soft silhouette: fade the outermost ~12 % of the impact parameter with noise
	float tmin = -qb / qa;
	float bimp = length(o + dl * tmin);
	dens *= smoothstep(1.0, 0.86, bimp + (n1 - 0.5) * 0.12);
	float sigma = tau / max(thick * radius, 1e-3);
	float od = sigma * seg * dens;
	float alpha = 1.0 - exp(-od);
	if (alpha < 0.003) {
		discard;
	}
	// --- lighting: sunlit droplets (soft terminator, silver lining toward the sun)
	vec3 L = normalize(g_sun_dir);
	vec3 nrm = normalize((mid - centre) / (sc * sc));
	float lit = 0.55 + 0.45 * smoothstep(-0.6, 0.8, dot(nrm, L));
	lit *= 0.85 + 0.3 * n;
	float fwd = pow(max(dot(rd, L), 0.0), 8.0);
	vec3 col = vec3(0.97, 0.98, 1.0) * (g_sun_light.rgb * (lit + fwd * 1.5) + g_ambient.rgb * g_ambient.w * 1.1);
	// lit from inside by the fireball: falloff with distance + a forward-scattered halo around it
	if (g_fireball_color.w > 0.0 && g_fireball.w > 0.0) {
		vec3 fb = g_fireball.xyz;
		float rf = g_fireball.w;
		float dd = length(mid - fb);
		vec3 fire = g_fireball_color.rgb * g_fireball_color.w;
		col += fire * 0.06 * (rf * rf) / (dd * dd + rf * rf);
		vec3 to_fb = fb - cam;
		float dfb = length(to_fb);
		float ang = length(cross(rd, to_fb / dfb));
		float ang_r = rf / dfb;
		col += fire * 0.12 * exp(-pow(ang / (ang_r * 2.2), 2.0)) * part;
	}
	vec4 fog = atm_fog(cam, mid);
	col = mix(col * g_exposure, fog.rgb, fog.a);
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.97);
}
