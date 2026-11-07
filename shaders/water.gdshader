// Lagoon water: small wind waves + the explosion's outgoing ring wave train (scrubbable),
// fresnel sky reflection approximated with the haze colour, foam on crests.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/atmos.gdshaderinc"

global uniform float g_blast_age;
global uniform vec3 g_blast_center;

uniform float pond_radius = 4000.0;
uniform float wave_h0 = 29.0;      // crest height at 300 m (Baker first wave 94 ft)
uniform float wave_speed = 23.0;   // shallow-water speed sqrt(g*55 m)

varying vec3 v_world;
varying float v_foam;

float ring_wave(float r, float t) {
	if (t <= 0.0) {
		return 0.0;
	}
	float front = wave_speed * t + 120.0;
	float x = (r - front);
	float env = exp(-max(x, 0.0) / 30.0) * exp(min(x, 0.0) / 400.0);
	float amp = wave_h0 * clamp(300.0 / max(r, 150.0), 0.0, 2.0);
	return amp * env * cos(x / 60.0 * 6.2831);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = length(w.xz - g_blast_center.xz);
	float h = 0.0;
	h += 0.25 * sin(w.x * 0.05 + TIME * 0.8) * cos(w.z * 0.043 + TIME * 0.6);
	if (g_blast_age >= 0.0) {
		float t = g_blast_age - 3.0;
		h += ring_wave(r, t);
	}
	// fade out at the shore
	h *= smoothstep(pond_radius, pond_radius * 0.9, length(VERTEX.xz));
	VERTEX.y += h;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_foam = clamp(h / 8.0, 0.0, 1.0);
}

void fragment() {
	vec3 dx = dFdx(v_world);
	vec3 dy = dFdy(v_world);
	vec3 n = normalize(cross(dy, dx));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 deep = vec3(0.02, 0.10, 0.12);
	vec3 shallow = vec3(0.10, 0.32, 0.30);
	float shore = smoothstep(pond_radius * 0.75, pond_radius, length(v_world.xz - g_blast_center.xz));
	ALBEDO = mix(deep, shallow, shore * 0.6) + vec3(v_foam) * 0.7;
	ROUGHNESS = mix(0.06, 0.5, v_foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	FOG = atm_fog(CAMERA_POSITION_WORLD, v_world);
}
