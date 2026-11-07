// Expanding blast front as a pure REFRACTION of what lies behind it (no alpha rim, no lines).
// The compressed layer (index excess dn = 1.3e-5 x overpressure in psi, Gladstone-Dale) bends
// rays that graze it, so the background shifts outward in a soft band just inside the projected
// limb. The deflection scales with the front's optical thickness and is faded out when that
// thickness is below a few pixels: a weak or distant front is an occasional shimmer across the
// horizon / terrain edges and is invisible against a uniform sky, as in reality.
// Large yields in humid air add a soft condensation band (never a hairline).
// Drawn BEFORE the explosion volume (render_priority -2): the screen texture holds the opaque
// scene only, so drawing over the cloud would paint the background over it.
// The mesh is a sphere scaled to 1.02 x radius; everything is computed analytically per pixel.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, fog_disabled, shadows_disabled;

#include "res://shaders/atmos.gdshaderinc"

global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 centre = vec3(0.0);  // burst point (world)
uniform float radius = 100.0;     // slant radius of the front (m)
uniform float p_psi = 1.0;        // peak overpressure at the front
uniform float thick = 5.0;        // optical thickness of the compressed layer (m)
uniform float amp = 1.0;          // art scale (0.2 for HE, sub-kt and underwater bursts)
uniform float ground_y = 0.0;     // local y of the ground (the shell is a dome above it)
uniform float stem_h = 0.0;       // Mach stem height (local, 0 = none): stronger near the ground
uniform float condensation = 0.0; // 0..1 visible condensation band (large yields, humid air)
uniform float cond_w = 50.0;      // condensation band width (m)
uniform float max_px = 6.0;       // cap of the background shift (pixels)

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 oc = centre - cam;
	// the front has passed the camera: nothing grazes it any more
	if (dot(oc, oc) <= radius * radius) {
		discard;
	}
	vec3 fw = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(fw - cam);
	float tc = dot(oc, rd);
	if (tc <= 0.0) {
		discard;
	}
	vec3 pt = cam + rd * tc;          // closest approach of the ray to the centre
	vec3 perp = pt - centre;
	float b = length(perp);
	float s = radius - b;             // metres inside the projected limb
	float d = max(thick, 0.05);
	float s_max = max(d * 6.0, condensation > 0.0 ? cond_w * 5.0 : 0.0);
	if (s <= 0.0 || s > s_max) {
		discard;
	}
	// dome above the ground; soft at the ground line
	float yl = pt.y - centre.y - ground_y;
	float above = smoothstep(0.0, max(d, 1.0), yl);
	if (above <= 0.0) {
		discard;
	}
	// terrain in front of the shell hides it
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_t = length(vp.xyz);
	float t_entry = tc - sqrt(max(radius * radius - b * b, 0.0));
	if (scene_t < t_entry) {
		discard;
	}
	float px_per_rad = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	float d_px = d / tc * px_per_rad;

	// --- refraction
	float x = s / d;
	float prof = x * x * exp(2.0 - 2.0 * x);           // 0 at the limb, peak 1 at s = d, soft tail
	float stem = stem_h > 0.0 ? 1.0 - smoothstep(0.0, stem_h, yl) : 0.0;
	float dn = 1.3e-5 * p_psi;
	float defl = dn * sqrt(2.0 * radius / d) * prof * amp * (1.0 + stem);
	// a front thinner than a few pixels averages out to nothing (no hairlines)
	defl *= smoothstep(0.75, 3.0, d_px);
	// a nearby background barely moves; the sky moves by the full deflection
	float par = clamp((scene_t - tc) / max(scene_t, 1.0), 0.0, 1.0);
	float disp_px = min(defl * px_per_rad * par, max_px);
	// screen direction of 'outward' at this point
	vec4 c0 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(pt, 1.0));
	vec4 c1 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(pt + perp / max(b, 1e-3) * d, 1.0));
	vec2 u0 = c0.xy / c0.w;
	vec2 u1 = c1.xy / c1.w;
	vec2 dpx = (u1 - u0) * VIEWPORT_SIZE;
	vec2 dir = dpx / max(length(dpx), 1e-6);
	vec2 off = dir * disp_px / VIEWPORT_SIZE;
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	float a_ref = clamp(disp_px * 1.5, 0.0, 1.0);

	// --- soft condensation band (big humid-air fronts only)
	float ca = 0.0;
	vec3 ccol = vec3(0.0);
	if (condensation > 0.0) {
		float xc = s / max(cond_w, 1.0);
		float band = xc * xc * exp(2.0 - 2.0 * xc);
		ca = condensation * band * 0.3 * smoothstep(0.5, 2.0, cond_w / tc * px_per_rad);
		vec3 L = normalize(g_sun_dir);
		float lit = 0.6 + 0.4 * clamp(dot(normalize(perp), L) * 0.5 + 0.5, 0.0, 1.0);
		ccol = vec3(0.95, 0.96, 1.0) * (g_sun_light.rgb * lit + g_ambient.rgb * g_ambient.w);
		ccol += g_fireball_color.rgb * g_fireball_color.w * 0.01;
		vec4 fog = atm_fog(cam, pt);
		ccol = mix(ccol * g_exposure, fog.rgb, fog.a);
	}
	float a = max(a_ref, ca) * above;
	if (a < 0.002) {
		discard;
	}
	ALBEDO = mix(bg, ccol, clamp(ca / max(max(a_ref, ca), 1e-4), 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 1.0);
}
