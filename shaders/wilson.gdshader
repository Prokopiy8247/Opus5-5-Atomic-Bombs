// Wilson condensation cloud: a thin white shell behind the shock front that forms in humid air
// during the rarefaction phase and evaporates within ~1-2 s. Thicker (more opaque) at the limb.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/atmos.gdshaderinc"

global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;

uniform sampler3D noise_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float opacity = 0.0;
uniform float radius = 100.0;
uniform float ground_y = 0.0;   // local ground level relative to the shell centre (metres)
uniform float seed = 0.0;
uniform float age = 0.0;
uniform float flatten = 1.0;

varying vec3 v_local;
varying vec3 v_world;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = abs(dot(n, v));
	float limb = pow(1.0 - facing, 1.5);
	vec3 np = v_local * 0.55 + vec3(seed, seed * 0.3, age * 0.05);
	float nz = texture(noise_b, np).r * 0.7 + texture(noise_b, np * 2.1 + 2.0).r * 0.3;
	// thin translucent shell, denser at the limb; soft billowy modulation, no hard holes
	float a = (0.18 + 0.82 * limb) * (0.55 + 0.45 * smoothstep(0.2, 0.8, nz)) * opacity;
	float above = smoothstep(-0.5, 2.0, v_local.y * radius - ground_y);
	a *= above;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	if (length(VERTEX) > length(vp.xyz) + 1.0) {
		discard;
	}
	if (a < 0.003) {
		discard;
	}
	vec3 L = normalize(g_sun_dir);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float lit = clamp(dot(wn, L) * 0.5 + 0.6, 0.15, 1.0);
	vec3 col = vec3(0.96, 0.97, 1.0) * (g_sun_light.rgb * lit + g_ambient.rgb * g_ambient.w * 0.9);
	col += g_fireball_color.rgb * g_fireball_color.w * 0.003;
	vec4 fog = atm_fog(CAMERA_POSITION_WORLD, v_world);
	col = mix(col, fog.rgb, fog.a);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.95);
}
