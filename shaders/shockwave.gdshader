// Expanding blast front: refraction of the background through the thin compressed shell,
// a faint bright rim where the line of sight grazes it, and (low bursts) a Mach-stem band.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float strength = 1.0;     // 0..1 (from overpressure)
uniform float radius = 100.0;
uniform float age = 0.0;
uniform float ground_y = 0.0;     // local y of the ground (shell is clipped below)
uniform float stem_h = 0.0;       // Mach stem height (local, 0 = none)
uniform vec3 tint = vec3(1.0);
uniform float condensation = 0.0; // humid air: faint white in the shell
global uniform float g_exposure;

varying vec3 v_local;
varying vec3 v_world;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float graze = 1.0 - abs(dot(n, v));
	float rim = pow(graze, 10.0);
	// clip under the ground
	float above = smoothstep(-0.02, 0.01, v_local.y * radius - ground_y);
	// ragged front (precursor / dust) near the ground
	float stem = stem_h > 0.0 ? (1.0 - smoothstep(0.0, stem_h, v_local.y * radius - ground_y)) : 0.0;
	// depth test against opaque scene: hide where the shell is behind terrain
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_d = length(vp.xyz);
	float frag_d = length(VERTEX);
	if (frag_d > scene_d + 1.0) {
		discard;
	}
	vec2 off = n.xy * (rim * 0.006 + stem * 0.003) * strength;
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	// visible almost only through refraction: tiny brightening at the limb
	// visible only through refraction of what lies behind it (no tinted "glass dome")
	float a = (rim * 0.9 + stem * 0.6) * strength * above;
	vec3 col = bg + condensation * rim * rim * vec3(0.05) * g_exposure;
	ALBEDO = col * tint;
	ALPHA = clamp(a, 0.0, 1.0);
}
