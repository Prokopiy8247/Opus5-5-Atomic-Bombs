// Dust raised by the blast wave sweeping the ground: an open cylinder at the front radius with
// a billowing, noisy curtain that thins with height and leaves a lingering haze behind.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;

uniform sampler3D noise_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float radius = 100.0;
uniform float height = 20.0;
uniform float opacity = 1.0;
uniform float age = 0.0;
uniform vec3 dust_col = vec3(0.62, 0.55, 0.46);
uniform float ragged = 0.5;      // precursor raggedness
uniform float seed = 0.0;

varying vec3 v_local;
varying vec3 v_world;

uniform float base_y = 0.0;   // world y of the node origin minus half height (set by script)

void vertex() {
	v_local = VERTEX + vec3(0.0, 0.5, 0.0);   // y in 0..1
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// follow the terrain under the ring
	float g = t_height(w.xz);
	float y01 = v_local.y;
	w.y = g - 2.0 + y01 * height;
	v_world = w;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	// v_local: unit cylinder (radius 1, y in 0..1)
	float ang = atan(v_local.z, v_local.x);
	float y = clamp(v_local.y, 0.0, 1.0);
	float arc = ang * radius;     // metres along the front
	vec3 np = vec3(arc / (height * 2.5), (y * height - age * 2.0) / (height * 1.2), seed) * 0.35;
	float n = texture(noise_b, np).r * 0.6 + texture(noise_b, np * 2.7 + 1.3).r * 0.4;
	float top = 0.45 + 0.55 * n + ragged * (texture(noise_b, np * 0.3).r - 0.5);
	float a = smoothstep(top, top - 0.35, y) * smoothstep(0.0, 0.04, y);
	a *= (0.35 + 0.65 * n) * opacity;
	// soft against the terrain
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_d = length(vp.xyz);
	float frag_d = length(VERTEX);
	a *= clamp((scene_d - frag_d) / max(height * 0.5, 1.0), 0.0, 1.0);
	if (a < 0.003) {
		discard;
	}
	vec3 L = normalize(g_sun_dir);
	vec3 nrm = normalize(vec3(v_local.x, 0.001, v_local.z));
	float lit = clamp(dot(nrm, L) * 0.5 + 0.6, 0.2, 1.0) * (0.75 + 0.25 * y);
	vec3 col = dust_col * (g_sun_light.rgb * lit * 0.9 + g_ambient.rgb * g_ambient.w * 0.8);
	col += g_fireball_color.rgb * g_fireball_color.w * 0.002 * dust_col;
	vec4 fog = atm_fog(CAMERA_POSITION_WORLD, v_world);
	col = mix(col * g_exposure, fog.rgb, fog.a);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
