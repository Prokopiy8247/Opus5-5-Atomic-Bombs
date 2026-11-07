// Ballistic clods / fragments as an analytic particle system on a MultiMesh (low-poly jittered
// rock mesh): position is a closed-form function of the explosion age (scrubbable) with linear
// drag (terminal velocity ~ 10-30 m/s, larger for big blocks), a stop on the terrain (shared
// height function), then the clod settles into the ground and vanishes. Pieces that would be
// sub-pixel on screen are dropped instead of drawn as a salt-and-pepper star field.
// INSTANCE transform: basis = random orientation x per-axis size (m), origin = launch point.
// INSTANCE_CUSTOM: xyz = initial velocity (m/s), w = seed.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, skip_vertex_transform;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform float g_blast_age;

uniform float t_launch = 0.0;     // global delay
uniform float drag = 0.6;         // 1/s for a piece of the nominal size
uniform float size_ref = 1.0;     // nominal piece size (m)
uniform vec3 base_col = vec3(0.35, 0.29, 0.22);
uniform float hot = 0.0;          // incandescent fragments (0..1)
uniform float min_px = 0.9;       // pieces smaller than this on screen are not drawn

varying vec3 v_world;
varying float v_glow;
varying float v_shade;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec3 rot(vec3 v, vec3 ax, float c, float s) {
	return v * c + cross(ax, v) * s + ax * dot(ax, v) * (1.0 - c);
}

void vertex() {
	vec3 v0 = INSTANCE_CUSTOM.xyz;
	float seed = INSTANCE_CUSTOM.w;
	vec3 p0 = MODEL_MATRIX[3].xyz;                 // launch point (world)
	mat3 shape = mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz);
	float size = pow(max(abs(determinant(shape)), 1e-9), 1.0 / 3.0);
	float delay = t_launch + hash11(seed * 13.1) * 0.04;
	float t_raw = g_blast_age - delay;
	float t = max(t_raw, 0.0);
	// linear drag, stronger for small clods (terminal velocity grows ~ sqrt(size))
	float k = drag * clamp(sqrt(size_ref / max(size, 1e-3)), 0.6, 2.0) * (0.8 + 0.4 * hash11(seed * 7.7));
	float e = exp(-k * t);
	vec3 disp = v0 / k * (1.0 - e);
	float vt = 9.81 / k;
	disp.y -= vt * t - vt / k * (1.0 - e);
	vec3 pw = p0 + disp;
	float ground = t_height(pw.xz);
	float vy = (v0.y + vt) * e - vt;
	float below = ground - pw.y;
	// time since touchdown (the unclamped path keeps falling at ~vy below the surface)
	float t_since = below > 0.0 ? below / max(-vy, 1.0) : 0.0;
	if (below > 0.0) {
		pw.y = ground + size * 0.25;
	}
	// landed clods settle into the soil and disappear
	float keep = 1.0 - smoothstep(0.3, 1.2, t_since);
	// screen size: drop sub-pixel pieces (no uniform pepper specks)
	float dist = length(pw - CAMERA_POSITION_WORLD);
	float px = size / max(dist, 1.0) * abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	float vis = smoothstep(min_px * 0.7, min_px, px);
	float sc = (t_raw > 0.0 ? 1.0 : 0.0) * keep * vis;
	// tumble (frozen at touchdown)
	float t_fly = max(t - t_since, 0.0);
	float ang = t_fly * (2.0 + 6.0 * hash11(seed));
	vec3 ax = normalize(vec3(hash11(seed + 1.0) - 0.5, hash11(seed + 2.0) - 0.5, hash11(seed + 3.0) - 0.5) + 0.01);
	float c = cos(ang);
	float s = sin(ang);
	vec3 vl = rot(shape * VERTEX, ax, c, s) * sc;
	vec3 nw = normalize(rot(transpose(inverse(shape)) * NORMAL, ax, c, s));
	vec3 world = pw + vl;
	v_world = world;
	v_glow = hot * exp(-t / 0.08);
	// dust coating: the clods are as pale as the soil they came from on top, darker below
	v_shade = 0.75 + 0.25 * nw.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}

void fragment() {
	ALBEDO = base_col * v_shade;
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.45, 0.12) * v_glow * 30.0;
	FOG = atm_fog(CAMERA_POSITION_WORLD, v_world);
}
