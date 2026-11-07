// Ground dust raised by the blast.
// mode 0: the dust ring swept up by the front - an open cylinder at the front radius with a
//         ragged, rolling top (height noise on periodic world-space coordinates: no atan seam).
//         Its tangent (silhouette) edges fade out, so it never stacks into vertical glass walls.
// mode 1: fragment-impact puffs (MultiMesh of camera-facing quads; INSTANCE_CUSTOM =
//         birth time, size, rise, seed) - small tan puffs where casing fragments hit the ground.
// Both are drawn twice: part 0 = the half behind ground zero (before the explosion volume),
// part 1 = the half in front of it (after the volume), so the cloud occludes correctly.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;

uniform sampler3D noise_b : filter_linear_mipmap, repeat_enable;
uniform sampler3D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform int mode = 0;
uniform float part = 1.0;        // 1 = near half (camera side of ground zero), 0 = far half
uniform vec3 centre = vec3(0.0); // ground zero (world)
uniform float radius = 100.0;    // ring radius (m)
uniform float height = 20.0;     // mean dust height (m)
uniform float mesh_h = 40.0;     // mesh height incl. the ragged top and 2 m below the ground
uniform float opacity = 1.0;
uniform float age = 0.0;
uniform vec3 dust_col = vec3(0.62, 0.55, 0.46);
uniform float ragged = 0.5;      // jaggedness of the top (precursor = 1)
uniform float lean = 0.0;        // the top trails back toward ground zero by lean x radius
uniform float seed = 0.0;
uniform float puff_life = 3.0;

varying vec3 v_world;
varying float v_h;               // ring: metres above the local ground
varying vec2 v_uv;               // puff: quad coordinates -1..1
varying float v_a;               // puff: opacity envelope
varying float v_size;            // puff: current size (m)
varying float v_seed;
varying float v_x;               // puff: normalized age

void vertex() {
	if (mode == 1) {
		vec3 base = MODEL_MATRIX[3].xyz;
		float x = (age - INSTANCE_CUSTOM.x) / max(puff_life, 0.1);
		float alive = (x > 0.0 && x < 1.0) ? 1.0 : 0.0;
		vec3 cam = CAMERA_POSITION_WORLD;
		float near = dot(base.xz - centre.xz, cam.xz - centre.xz) > 0.0 ? 1.0 : 0.0;
		if (abs(near - part) > 0.5) {
			alive = 0.0;
		}
		float xc = clamp(x, 0.0, 1.0);
		float s = INSTANCE_CUSTOM.y * (0.3 + 0.7 * (1.0 - exp(-xc * 7.0))) * (1.0 + 0.5 * xc);
		v_a = alive * smoothstep(0.0, 0.03, xc) * pow(1.0 - xc, 1.6);
		v_size = s;
		v_seed = INSTANCE_CUSTOM.w;
		v_x = xc;
		v_uv = VERTEX.xy * 2.0;
		vec3 c = base + vec3(0.0, s * 0.35 + INSTANCE_CUSTOM.z * sqrt(xc), 0.0);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		vec3 w = c + (right * VERTEX.x + up * VERTEX.y) * s * alive;
		v_world = w;
		v_h = 0.0;
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	} else {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float y01 = VERTEX.y + 0.5;
		// noise is looked up on the un-leaned front position (no diagonal shear of the pattern)
		v_uv = w.xz - centre.xz;
		// the dust sheet leans back over the ground behind the front (a rolling wave, not a wall)
		w.xz = centre.xz + (w.xz - centre.xz) * (1.0 - lean * clamp(y01 * mesh_h / max(height * 2.0, 0.1), 0.0, 1.0));
		// follow the terrain under the ring
		float g = t_height(w.xz);
		w.y = g - 2.0 + y01 * mesh_h;
		v_world = w;
		v_h = y01 * mesh_h - 2.0;
		v_a = 1.0;
		v_size = 1.0;
		v_seed = 0.0;
		v_x = 0.0;
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	}
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 L = normalize(g_sun_dir);
	float frag_d = length(VERTEX);
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_d = length(vp.xyz);
	float a = 0.0;
	float lit = 1.0;
	if (mode == 1) {
		// a spurt of dust: taller than wide early, spreading and thinning, lumpy outline
		vec2 uv = v_uv;
		float stretch = mix(0.75, 1.1, v_x);
		vec2 e = vec2(uv.x / stretch, uv.y);
		vec3 np = vec3(uv * 0.3 + v_seed, v_seed * 0.31 + v_x * 0.15);
		float n = texture(noise_b, np).r * 0.6 + texture(noise_a, np * 2.7 + 0.5).r * 0.4;
		float r = length(e) + (n - 0.5) * 0.9;
		a = smoothstep(1.0, 0.1, r) * (0.35 + 0.8 * smoothstep(0.3, 0.8, n)) * v_a * opacity;
		a *= clamp((scene_d - frag_d) / max(v_size * 0.35, 0.5), 0.0, 1.0);
		// self-shadowed fresh soil: darker than the sunlit flat ground around it
		lit = 0.4 + 0.25 * clamp(uv.y * 0.5 + 0.5, 0.0, 1.0) + 0.12 * n;
	} else {
		vec2 wp = v_world.xz - centre.xz;                 // metres from ground zero
		vec2 rad = wp / max(length(wp), 1e-3);
		vec2 to_cam = cam.xz - v_world.xz;
		float facing = dot(rad, to_cam / max(length(to_cam), 1e-3));
		// near/far halves are separate draws (after/before the volume)
		if ((part > 0.5) != (facing > 0.0)) {
			discard;
		}
		// grazing (tangent) parts of the open cylinder would pile up into vertical edges
		float sil = smoothstep(0.05, 0.45, abs(facing));
		float y = v_h;
		float cell = max(height * 2.2, 1.5);
		vec2 fp = v_uv;                                  // un-leaned front position (m from GZ)
		// ragged top: large lumps + jets, sampled on world xz (periodic around the ring)
		float n_big = texture(noise_a, vec3(fp / (cell * 10.0), seed)).r;
		float n_jet = texture(noise_b, vec3(fp / (cell * 3.0), seed + 0.37)).r;
		float top = height * (0.55 + 1.0 * smoothstep(0.25, 0.75, n_big));
		top += height * ragged * 0.9 * (smoothstep(0.45, 0.85, n_jet) - 0.3);
		top = max(top, height * 0.25);
		// rolling billows (large, soft): noise scrolls up/outward with time
		vec3 bp = vec3(fp / (cell * 6.0), (y - age * height * 1.5) / (cell * 3.0) + seed);
		float nb = texture(noise_b, bp).r * 0.75 + texture(noise_a, bp * 1.3 + 0.7).r * 0.25;
		float yf = y / max(top, 0.1);
		// dense at the foot, ragged billowing top (no detached blobs above the top)
		a = smoothstep(1.0, 0.3, yf + (nb - 0.5) * 0.45) * smoothstep(-0.05, 0.06, yf) * smoothstep(1.15, 0.85, yf);
		a *= (0.6 + 0.7 * smoothstep(0.2, 0.8, nb)) * opacity * sil;
		// soft against the terrain
		a *= clamp((scene_d - frag_d) / max(height * 0.4, 0.5), 0.0, 1.0);
		vec3 nrm = normalize(vec3(rad.x, 0.35, rad.y));
		lit = (0.62 + 0.3 * clamp(dot(nrm, L), -1.0, 1.0)) * (0.75 + 0.25 * clamp(yf, 0.0, 1.0)) * (0.82 + 0.25 * nb);
	}
	if (a < 0.003) {
		discard;
	}
	vec3 col = dust_col * (g_sun_light.rgb * lit * 0.75 + g_ambient.rgb * g_ambient.w * 0.65);
	col += g_fireball_color.rgb * g_fireball_color.w * 0.002 * dust_col;
	// same aerial-perspective weight as the explosion volume, so the dust matches the skirt
	vec4 fog = atm_fog(cam, v_world);
	col = mix(col * g_exposure, fog.rgb, fog.a * 0.65);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
