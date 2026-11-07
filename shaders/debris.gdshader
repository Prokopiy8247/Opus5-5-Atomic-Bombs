// Ballistic debris / fragments / clods as an analytic particle system on a MultiMesh:
// position is a closed-form function of the explosion age (scrubbable), with quadratic-ish
// drag and a stop on the terrain (shared height function).
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform float g_blast_age;
global uniform vec3 g_blast_center;

uniform float t_launch = 0.0;     // global delay
uniform float drag = 0.15;        // 1/s
uniform float size_scale = 1.0;
uniform vec3 base_col = vec3(0.35, 0.29, 0.22);
uniform float hot = 0.0;          // incandescent fragments (0..1)
uniform float lifetime = 60.0;

varying vec3 v_world;
varying float v_glow;
varying float v_alive;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	// INSTANCE_CUSTOM: xyz = initial velocity (m/s), w = seed
	vec3 v0 = INSTANCE_CUSTOM.xyz;
	float seed = INSTANCE_CUSTOM.w;
	vec3 p0 = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz; // instance origin (start position)
	float delay = t_launch + hash11(seed * 13.1) * 0.05;
	float t = max(g_blast_age - delay, 0.0);
	float k = drag * (0.5 + hash11(seed * 7.7));
	// closed form with linear drag: x = v0/k (1 - e^-kt), y adds gravity terminal velocity
	float e = exp(-k * t);
	vec3 disp = v0 / k * (1.0 - e);
	float vt = 9.81 / k;
	disp.y -= vt * t - vt / k * (1.0 - e);
	vec3 pw = p0 + disp;
	float ground = t_height(pw.xz);
	bool landed = pw.y < ground;
	if (landed) {
		pw.y = ground + 0.2;
	}
	v_alive = (g_blast_age >= delay && g_blast_age < lifetime + delay) ? 1.0 : 0.0;
	// tumble
	float ang = t * (3.0 + 6.0 * hash11(seed)) * (landed ? 0.0 : 1.0);
	vec3 ax = normalize(vec3(hash11(seed + 1.0) - 0.5, hash11(seed + 2.0) - 0.5, hash11(seed + 3.0) - 0.5) + 0.01);
	float c = cos(ang);
	float s = sin(ang);
	float inst_scale = length(MODEL_MATRIX[0].xyz);
	vec3 vl = VERTEX * size_scale * inst_scale * (0.5 + hash11(seed * 3.3)) * v_alive;
	vl = vl * c + cross(ax, vl) * s + ax * dot(ax, vl) * (1.0 - c);
	vec3 world = pw + vl;
	v_world = world;
	v_glow = hot * exp(-t / 0.08);
	// write world-space position (MODEL_MATRIX contains only the instance translation)
	mat4 tr_only = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), MODEL_MATRIX[3]);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (v_alive < 0.5) {
		discard;
	}
	ALBEDO = base_col;
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.45, 0.12) * v_glow * 30.0;
	FOG = atm_fog(CAMERA_POSITION_WORLD, v_world);
}
