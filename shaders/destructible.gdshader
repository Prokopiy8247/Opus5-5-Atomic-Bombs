// Destructible test-range objects (one MultiMesh per object type and map cell).
// Every animation is a pure function of the global uniform g_blast_age, so the destruction is
// scrubbable, pausable and deterministic (offline render, slow motion).
//
// INSTANCE_CUSTOM: x = shock arrival time (s), y = peak overpressure (psi; >= 999 means the
//                  object is engulfed by the fireball / crater), z = ignition time (s, < 0 never),
//                  w = floor(total thermal fluence, cal/cm2) + per-instance seed (0..1).
// Vertex data:     COLOR.rgb = albedo (sRGB), COLOR.a * 255 = part id,
//                  CUSTOM0 = piece pivot (model space) + piece random,
//                  CUSTOM1 = "lie flat" rotation axis (xyz) + angle (w),
//                  UV2 = piece half extents (x: side that rotates into the vertical, y: half thickness),
//                  UV = local pattern coordinates (glass: window id in UV.x).
// The object order of failure follows docs/02_PHYSICS_REFERENCE.md section 6.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/terrain_common.gdshaderinc"
#include "res://shaders/atmos.gdshaderinc"

global uniform float g_blast_age;
global uniform vec3 g_blast_center;
global uniform vec4 g_crater;       // radius, depth, rim height, progress 0..1
global uniform vec4 g_dome;         // radius, height, 0, 0

// object kinds (uniform per material)
const int K_WOOD = 0;
const int K_BRICK = 1;
const int K_TREE = 2;
const int K_JUNIPER = 3;
const int K_CAR = 4;
const int K_TRUCK = 5;
const int K_TANK = 6;
const int K_TOWER = 7;
const int K_POLE = 8;
const int K_WIRE = 9;
const int K_BRIDGE = 10;
const int K_BUNKER = 11;
const int K_HANGAR = 12;
const int K_AIRCRAFT = 13;
const int K_RAILCAR = 14;
const int K_STATIC = 15;

// part ids (per vertex)
const int P_BODY = 0;
const int P_GLASS = 1;
const int P_ROOF = 2;
const int P_WALL = 3;
const int P_LEAVES = 4;
const int P_TRUNK = 5;
const int P_WHEEL = 6;
const int P_FRAME = 7;
const int P_FOUND = 8;
const int P_DECK = 9;
const int P_PIER = 10;
const int P_EMBANK = 11;
const int P_TURRET = 12;
const int P_WING = 13;
const int P_CHIMNEY = 14;
const int P_STUMP = 15;
const int P_CLAD = 16;
const int P_DOOR = 17;
const int P_ROOT = 18;
const int P_GEAR = 19;
const int P_FIN = 20;
const int P_BOGIE = 21;
const int P_WIRE = 22;
const int P_SLAB = 23;
const int P_RAIL = 24;
const int P_GROUND = 25;
const int P_METAL = 26;

uniform int kind = 0;
uniform vec3 burst_pos = vec3(0.0, -10000.0, 0.0);
uniform float t2 = 0.1;               // time of the second thermal maximum (s)
uniform float imp = 1.0;              // blast impulse factor (positive phase relative to 15 kt)
uniform vec3 terrain_focus = vec3(0.0);
uniform float terrain_match = 1.0;    // 1: sit on the clipmap's LOD triangles, 0: exact height
uniform vec3 body_c = vec3(0.0, 0.8, 0.0);   // rigid-body centre at rest (model space)
uniform vec2 body_half = vec2(0.9, 2.3);     // rigid-body half width (x) / half length (z)
uniform float gear_h = 0.0;
uniform float tower_h = 40.0;
uniform float flash_tint_gain = 1.0;
uniform float fire_gain = 1.0;

varying vec3 v_col;
varying flat int v_part;
varying float v_face;
varying float v_char;
varying float v_burn;
varying float v_glass;
varying float v_seed;
varying float v_oblit;
varying float v_damage;
varying float v_dust;
varying vec3 v_local;
varying vec2 v_uv;

// ------------------------------------------------------------------ helpers

float sat(float x) {
	return clamp(x, 0.0, 1.0);
}

// Deterministic per-instance random numbers. Mirrored in range_objects.gd (rr()).
float rr(float seed, float k) {
	return fract(seed * (1.0 + 6.17 * k) + 0.31 * k);
}

float ease_out2(float x) {
	float u = 1.0 - sat(x);
	return 1.0 - u * u;
}

float ease_out3(float x) {
	float u = 1.0 - sat(x);
	return 1.0 - u * u * u;
}

// Toppling under a blast push plus gravity: starts with velocity a, accelerates, reaches 1 at
// x = 1 and then makes a small damped rebound (never a jump).
float topple(float x, float a) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x < 1.0) {
		return a * x + (1.0 - a) * x * x;
	}
	float b = x - 1.0;
	return 1.0 - 0.035 * sin(b * 9.0) * exp(-b * 5.0);
}

float dyn_q(float p) {
	return 2.5 * p * p / (7.0 * 14.7 + p);
}

// Fraction of the thermal energy radiated by x = t / t2 (same closed form as BlastPhysics).
float th_frac(float x) {
	if (x <= 0.0) {
		return 0.0;
	}
	float s2 = 1.41421356;
	float a = log((x * x - s2 * x + 1.0) / (x * x + s2 * x + 1.0)) / (2.0 * s2);
	float b = (atan(s2 * x + 1.0) + atan(s2 * x - 1.0)) / s2;
	return clamp((a + b) / (PI / s2), 0.0, 1.0);
}

mat3 rot_axis(vec3 u, float a) {
	float s = sin(a);
	float c = cos(a);
	float oc = 1.0 - c;
	return mat3(
		vec3(oc * u.x * u.x + c, oc * u.x * u.y + u.z * s, oc * u.z * u.x - u.y * s),
		vec3(oc * u.x * u.y - u.z * s, oc * u.y * u.y + c, oc * u.y * u.z + u.x * s),
		vec3(oc * u.z * u.x + u.y * s, oc * u.y * u.z - u.x * s, oc * u.z * u.z + c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

// ------------------------------------------------------------------ ground (matches terrain.gdshader)

float blast_deform(vec2 xz) {
	if (g_blast_age < 0.0) {
		return 0.0;
	}
	float r = length(xz - g_blast_center.xz);
	float off = 0.0;
	if (g_crater.x > 0.0) {
		float x = r / g_crater.x;
		float bowl = x < 1.0 ? -g_crater.y * (1.0 - x * x) : 0.0;
		float rim = g_crater.z * exp(-pow((x - 1.0) / 0.35, 2.0)) * (x > 0.6 ? 1.0 : 0.0);
		float ejecta = g_crater.z * 0.35 * exp(-max(x - 1.0, 0.0) * 1.6) * (x > 1.0 ? 1.0 : 0.0);
		off += (bowl + rim + ejecta) * g_crater.w;
	}
	if (g_dome.x > 0.0) {
		float x = r / g_dome.x;
		off += g_dome.y * exp(-x * x * 2.2);
	}
	return off;
}

float ground_exact(vec2 xz) {
	return t_height(xz) + blast_deform(xz);
}

// Height of the clipmap level with spacing s and centre c, interpolated on its triangles
// (diagonal i1-i2, exactly as the terrain grid mesh is triangulated).
float tri_interp_h(vec2 c, float s, vec2 xz) {
	vec2 g = (xz - c) / s;
	vec2 gi = floor(g);
	vec2 f = g - gi;
	float b = ground_exact(c + (gi + vec2(1.0, 0.0)) * s);
	float d = ground_exact(c + (gi + vec2(0.0, 1.0)) * s);
	if (f.x + f.y < 1.0) {
		float a = ground_exact(c + gi * s);
		return a + (b - a) * f.x + (d - a) * f.y;
	}
	float e = ground_exact(c + (gi + vec2(1.0, 1.0)) * s);
	return e + (d - e) * (1.0 - f.x) + (b - e) * (1.0 - f.y);
}

// The ground as the clipmap terrain actually draws it at xz (so nothing floats far away).
float rendered_ground(vec2 xz) {
	if (terrain_match < 0.5) {
		return ground_exact(xz);
	}
	float s = 1.0;
	vec2 c = vec2(0.0);
	for (int l = 0; l < 14; l++) {
		s = exp2(float(l));
		c = floor(terrain_focus.xz / (2.0 * s)) * (2.0 * s);
		vec2 q = abs(xz - c);
		if (max(q.x, q.y) < 62.5 * s || l == 13) {
			break;
		}
	}
	vec2 g = (xz - c) / s;
	float de = 64.0 - max(abs(g.x), abs(g.y));
	float morph = 1.0 - smoothstep(2.0, 19.2, de);
	float h = tri_interp_h(c, s, xz);
	if (morph > 0.001) {
		h = mix(h, tri_interp_h(c, 2.0 * s, xz), morph);
	}
	return h;
}

// ------------------------------------------------------------------ motion primitives

void hinge_rotate(inout vec3 v, inout vec3 n, vec3 hinge, vec3 axis, float ang) {
	mat3 R = rot_axis(axis, ang);
	v = hinge + R * (v - hinge);
	n = R * n;
}

// Racking collapse of a frame building: every point at height y above the floor moves downwind
// by y*sin(th) and drops to y*cos(th) (walls perpendicular to the push rotate about their sills,
// walls parallel to it fold as parallelograms).
void rack(inout vec3 v, inout vec3 n, float th, vec3 lpush, vec3 laxis, float base_y) {
	float y = v.y - base_y;
	if (y > 0.0) {
		v += lpush * (y * sin(th));
		v.y = base_y + y * cos(th);
		n = rot_axis(laxis, th) * n;
	}
}

// One rigid piece on a ballistic, drag-limited path that comes to rest lying flat on the ground.
void debris(inout vec3 v, inout vec3 n, vec3 pv, float pr, vec3 fax, float fang, vec2 ext,
		float tau, float S, float vy, float spread, float k_flip, float yaw_tot, float rest_extra,
		vec3 lpush, vec3 lside, vec3 inst_o, mat3 m3, float sc, float base_g) {
	vec3 dir = normalize(lpush + lside * spread * (pr * 2.0 - 1.0));
	vec3 land = pv + dir * S;
	vec3 land_w = inst_o + m3 * land;
	float g_land = (rendered_ground(land_w.xz) - inst_o.y) / sc;
	float y0 = pv.y + base_g;
	float y1 = g_land + ext.y + rest_extra;
	float g = 9.8 / sc;
	float drop = max(y0 - y1, 0.0);
	float T = max((vy + sqrt(vy * vy + 2.0 * g * drop)) / g, 0.3);
	float f = sat(tau / T);
	float A_tot = fang + k_flip * PI;
	float A = A_tot * f;
	vec3 P;
	float eh = ease_out2(f);
	P.xz = pv.xz + dir.xz * S * eh;
	float tt = min(tau, T);
	float yb = y0 + vy * tt - 0.5 * g * tt * tt;
	yb = tau >= T ? y1 : yb;
	float gnd = mix(base_g, g_land, eh);
	float ext_now = ext.x * abs(sin(fang - A)) + ext.y * abs(cos(fang - A));
	P.y = max(yb, gnd + ext_now + rest_extra * f);
	mat3 R = rot_y(yaw_tot * f) * rot_axis(fax, A);
	v = P + R * (v - pv);
	n = R * n;
}

// Leaves / foliage shredded off a branch: the clump drifts downwind and shrinks to nothing.
void strip_piece(inout vec3 v, vec3 pv, float f, float S, vec3 lpush) {
	float e = ease_out2(f);
	vec3 P = pv + lpush * S * e + vec3(0.0, 2.5 * e, 0.0);
	v = P + (v - pv) * (1.0 - e);
}

// A vehicle-like box pushed downwind while tumbling about the horizontal axis perpendicular to
// the push. The centre height follows the support function of the box, so it rolls over its
// edges and comes to rest flat on a side, the roof or the wheels.
void rigid_roll(inout vec3 v, inout vec3 n, float tau, float T, float S, float roll_tot,
		float hop_vy, float crush, vec3 lpush, vec3 laxis, vec3 inst_o, mat3 m3, float sc,
		float base_g) {
	float e = ease_out3(tau / T);
	float phi = roll_tot * e;
	float hh = body_c.y * crush;
	float hw = abs(lpush.x) * body_half.x + abs(lpush.z) * body_half.y;
	float hc = hh * abs(cos(phi)) + hw * abs(sin(phi));
	vec3 land_w = inst_o + m3 * (body_c + lpush * S);
	float g_land = (rendered_ground(land_w.xz) - inst_o.y) / sc;
	float hop = max(hop_vy * tau - 4.9 * tau * tau, 0.0);
	vec3 P = vec3(body_c.x, 0.0, body_c.z) + lpush * S * e;
	P.y = mix(base_g, g_land, e) + hc + hop;
	vec3 lv = v - body_c;
	lv.y *= crush;
	mat3 R = rot_axis(laxis, phi);
	v = P + R * lv;
	n = R * n;
}

bool flammable(int k, int part) {
	if (k == K_WOOD) {
		return part == P_WALL || part == P_ROOF || part == P_DOOR;
	}
	if (k == K_BRICK) {
		return part == P_ROOF || part == P_GLASS || part == P_DOOR;
	}
	if (k == K_TREE || k == K_JUNIPER) {
		return part == P_LEAVES || part == P_TRUNK;
	}
	if (k == K_CAR || k == K_TRUCK) {
		return part == P_WHEEL || part == P_GLASS || part == P_CLAD;
	}
	if (k == K_POLE) {
		return part == P_TRUNK || part == P_FRAME;
	}
	if (k == K_RAILCAR) {
		return part == P_BODY;
	}
	if (k == K_AIRCRAFT) {
		return part == P_WING || part == P_GLASS;
	}
	return false;
}

float char_amount(int k, int part, float Q) {
	vec2 c = vec2(10.0, 45.0);
	if (part == P_LEAVES) {
		c = vec2(4.0, 22.0);
	} else if (part == P_TRUNK || part == P_STUMP) {
		c = vec2(12.0, 60.0);
	} else if (part == P_GLASS) {
		c = vec2(60.0, 300.0);
	} else if (k == K_BUNKER || k == K_BRIDGE || k == K_STATIC || part == P_FOUND || (k == K_BRICK && part == P_WALL)) {
		c = vec2(35.0, 220.0);
	} else if (k == K_CAR || k == K_TRUCK || k == K_TANK || k == K_AIRCRAFT || k == K_RAILCAR || k == K_TOWER || k == K_HANGAR) {
		c = vec2(15.0, 90.0);
	}
	return smoothstep(c.x, c.y, Q);
}

// ------------------------------------------------------------------ vertex

void vertex() {
	vec4 ic = INSTANCE_CUSTOM;
	float arrival = ic.x;
	float psi = ic.y;
	float ign = ic.z;
	float fl = floor(ic.w);
	float seed = fract(ic.w);
	int part = int(COLOR.a * 255.0 + 0.5);
	vec3 pv = CUSTOM0.xyz;
	float pr = fract(CUSTOM0.w + seed * 7.13);
	vec3 fax = CUSTOM1.xyz;
	float fang = CUSTOM1.w;
	vec2 ext = UV2;

	mat3 m3 = mat3(MODEL_MATRIX);
	vec3 inst_o = MODEL_MATRIX[3].xyz;
	float sc = max(length(MODEL_MATRIX[1].xyz), 1e-4);
	vec3 to_b = burst_pos - inst_o;
	v_face = dot(normalize(m3 * NORMAL), normalize(to_b));
	v_col = pow(COLOR.rgb, vec3(2.2));
	v_part = part;
	v_seed = seed;
	v_local = VERTEX;
	v_uv = UV;
	v_damage = 0.0;
	v_dust = 0.0;
	v_oblit = 0.0;
	v_glass = 0.0;

	float age = g_blast_age;
	float tau = age - arrival;
	bool hit = age >= 0.0 && tau > 0.0;

	vec3 wd = inst_o - burst_pos;
	float hf = length(wd.xz) / max(length(wd), 1.0);
	float hfs = smoothstep(0.15, 0.75, hf);
	vec3 wpush = length(wd.xz) > 0.01 ? normalize(vec3(wd.x, 0.0, wd.z)) : vec3(1.0, 0.0, 0.0);
	vec3 lpush = transpose(m3) * wpush;
	lpush.y = 0.0;
	lpush = normalize(lpush + vec3(1e-6, 0.0, 0.0));
	vec3 laxis = normalize(cross(vec3(0.0, 1.0, 0.0), lpush));
	vec3 lside = laxis;

	vec3 v = VERTEX;
	vec3 n = NORMAL;
	bool absolute = false;   // true when v already contains the ground offset
	float base_g = 0.0;
	if (kind != K_WIRE) {
		base_g = (rendered_ground(inst_o.xz) - inst_o.y) / sc;
	}
	float q = dyn_q(psi);

	if (psi >= 999.0) {
		// engulfed by the fireball / inside the crater: flattened, vaporised remains
		if (hit) {
			float ob = sat(tau / 0.4);
			v.y = v.y * mix(1.0, 0.04, ob) - 0.3 * ob;
			v.xz *= mix(1.0, 1.25, ob);
			v_oblit = ob;
		}
	} else if (kind == K_WOOD) {
		float roof_thr = 2.0 + rr(seed, 1.0);
		float coll_thr = 2.9 + 1.1 * rr(seed, 2.0);
		float blow_thr = 4.8 + rr(seed, 3.0);
		if (hit && part != P_FOUND) {
			if (part == P_ROOF && psi >= roof_thr) {
				float S = (6.0 + 22.0 * sat((psi - roof_thr) / 3.0) + 80.0 * sat((psi - 8.0) / 25.0)) * imp * (0.25 + 0.75 * hfs);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, 2.0 + 3.0 * pr * hfs, 0.5, floor(pr * 2.0),
					(pr - 0.5) * 3.0, 0.06 * pr, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (psi >= blow_thr) {
				float S = (10.0 + 25.0 * sat((psi - blow_thr) / 5.0) + 90.0 * sat((psi - 10.0) / 30.0)) * imp * (0.15 + 0.85 * hfs);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, (1.0 + 3.0 * pr) * hfs, 0.6, floor(pr * 2.0),
					(pr - 0.5) * 2.5, 0.12 * pr, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (psi >= coll_thr) {
				float thm = mix(0.35, 1.35, sat((psi - coll_thr) / max(blow_thr - coll_thr, 0.1)));
				float f = topple(tau / 1.3, 0.45);
				rack(v, n, f * thm * hfs, lpush, laxis, 0.15);
				// vertical blast (beneath an air burst): crushed in place instead
				float crush = mix(1.0, 0.2, f * (1.0 - hfs));
				v.y = 0.15 + (v.y - 0.15) * crush;
			}
		}
	} else if (kind == K_BRICK) {
		float roof_thr = 3.0 + 0.6 * rr(seed, 1.0);
		float crum_thr = 5.0 + 2.0 * rr(seed, 2.0);
		if (hit && part != P_FOUND) {
			if (part == P_ROOF && psi >= roof_thr) {
				float S = (3.0 + 6.0 * sat((psi - roof_thr) / 3.0) + 40.0 * sat((psi - 10.0) / 30.0)) * imp * (0.25 + 0.75 * hfs);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, (1.0 + 1.5 * pr) * hfs, 0.5, 0.0,
					(pr - 0.5) * 1.5, 0.3 * pr, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (part != P_ROOF && psi >= crum_thr) {
				float S = (1.0 + 5.0 * sat((psi - crum_thr) / 6.0) + 25.0 * sat((psi - 15.0) / 40.0)) * imp * (0.3 + 0.7 * hfs);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, 0.3 + 1.2 * pr, 0.9, 0.0,
					(pr - 0.5) * 1.2, 0.9 * pr * pr, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (psi >= 1.7) {
				// cracked walls: a faint shudder, then still
				v += lpush * 0.03 * sat(psi / 5.0) * sin(tau * 30.0) * exp(-tau * 6.0) * sat(v.y / 6.0);
			}
		}
	} else if (kind == K_TREE || kind == K_JUNIPER) {
		bool juni = kind == K_JUNIPER;
		float strip = juni ? sat((psi - 3.0) / 4.0) : sat((psi - 1.2) / 1.3);
		float top_thr = juni ? 5.0 + 4.0 * rr(seed, 1.0) : 2.35 + 2.3 * rr(seed, 1.0);
		float snap_thr = juni ? 20.0 + 10.0 * rr(seed, 2.0) : 15.0 + 10.0 * rr(seed, 2.0);
		float crown_h = juni ? 1.7 : 7.2;
		float crown_r = juni ? 0.9 : 2.8;
		if (hit) {
			if (part == P_LEAVES) {
				float lp = fract(CUSTOM0.w + seed * 3.7);
				if (lp < strip) {
					strip_piece(v, pv, sat(tau / (0.6 + 0.6 * lp)), (8.0 + 25.0 * strip) * imp, lpush);
				} else {
					v = pv + (v - pv) * (1.0 - 0.45 * strip * ease_out2(tau / 0.5));
				}
			}
			float rest_r = mix(crown_r * 0.6, juni ? 0.35 : 0.5, strip);
			float thmax = acos(clamp(rest_r / crown_h, 0.0, 1.0));
			if (psi >= snap_thr && part != P_STUMP && part != P_ROOT) {
				float S = (10.0 + 1.2 * (psi - snap_thr)) * imp * hfs;
				debris(v, n, vec3(0.0, juni ? 0.0 : 1.2, 0.0), pr, laxis, PI * 0.5 * hfs, vec2(0.0, juni ? 0.4 : 0.6),
					tau, min(S, 120.0), 1.0 * hfs, 0.35, 0.0, (rr(seed, 3.0) - 0.5) * 1.5, 0.0,
					lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (psi >= top_thr && hfs > 0.2) {
				// uprooted: rotates about the downwind edge of the root plate, lands on its crown
				float a = topple(tau / (juni ? 1.1 : 1.7), 0.55) * thmax * hfs;
				hinge_rotate(v, n, lpush * (juni ? 0.45 : 0.9), laxis, a);
			} else {
				// permanent lean (roots giving way) plus a damped sway
				float lean_max = juni ? 0.25 : 0.42;
				float lean = lean_max * sat((psi - (juni ? 3.0 : 1.5)) / max(top_thr - (juni ? 3.0 : 1.5), 0.1)) * hfs;
				float sway = (juni ? 0.05 : 0.12) * sat(q / 2.0) * exp(-tau / 1.2) * sin(tau * (juni ? 7.0 : 4.5)) * hfs;
				float a = lean * ease_out3(tau / 0.8) + sway;
				if (v.y > 0.0) {
					hinge_rotate(v, n, vec3(0.0), laxis, a * sat(v.y / (juni ? 1.0 : 3.0)));
				}
			}
		}
	} else if (kind == K_CAR || kind == K_TRUCK) {
		float tthr = kind == K_CAR ? 4.5 + 1.5 * rr(seed, 1.0) : 5.0 + 2.0 * rr(seed, 1.0);
		if (hit && psi >= tthr) {
			float x = sat((psi - tthr) / 25.0);
			float nroll = (1.0 + floor(x * 3.0 + rr(seed, 2.0) * 1.2)) * step(0.3, hfs);
			float S = min((2.0 + 2.2 * (psi - tthr) + 30.0 * x) * imp * hfs, 150.0);
			float T = 0.9 + 0.35 * sqrt(S);
			float hop = 6.0 * sat((psi - 15.0) / 30.0) * hfs;
			float crush = mix(1.0, 0.62, sat((psi - 10.0) / 30.0) * (1.0 - 0.5 * hfs));
			rigid_roll(v, n, tau, T, S, nroll * PI * 0.5, hop, crush, lpush, laxis, inst_o, m3, sc, base_g);
			absolute = true;
		} else if (hit && psi >= 1.0) {
			float k = sat((psi - 1.0) / max(tthr - 1.0, 0.1));
			float a = 0.07 * k * exp(-tau / 0.6) * sin(tau * 9.0) * hfs;
			hinge_rotate(v, n, vec3(0.0), laxis, a);
			v += lpush * 0.6 * k * k * ease_out3(tau / 0.7) * imp * hfs;
		}
	} else if (kind == K_TANK) {
		float s_thr = 30.0 + 15.0 * rr(seed, 1.0);
		float r_thr = 70.0 + 40.0 * rr(seed, 2.0);
		if (hit && psi >= s_thr) {
			if (part == P_TURRET && psi >= r_thr) {
				float S = min((8.0 + 0.25 * (psi - r_thr)) * imp * (0.4 + 0.6 * hfs), 120.0);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, 3.0 + 3.0 * pr, 0.4, 1.0, (pr - 0.5) * 4.0, 0.0,
					lpush, lside, inst_o, m3, sc, base_g);
			} else {
				float roll = psi >= r_thr ? PI * 0.5 * step(0.4, hfs) : 0.0;
				float S = (0.08 * (psi - s_thr) + (psi >= r_thr ? 4.0 + 0.1 * (psi - r_thr) : 0.0)) * imp * hfs;
				S = min(S, 60.0);
				rigid_roll(v, n, tau, 1.0 + 0.3 * sqrt(S), S, roll, 0.0, 1.0, lpush, laxis, inst_o, m3, sc, base_g);
			}
			absolute = true;
		} else if (hit && psi >= 10.0) {
			v += lpush * 0.02 * sin(tau * 25.0) * exp(-tau * 5.0);
		}
	} else if (kind == K_TOWER) {
		float H = tower_h;
		float thr = 4.5 + 1.5 * rr(seed, 1.0);
		if (hit && psi >= thr && hfs > 0.15) {
			float hb = H * (0.12 + 0.28 * rr(seed, 2.0));
			float L = H - hb;
			float thf = acos(clamp(-hb / L, -1.0, 1.0));
			float T = 1.3 * sqrt(2.0 * L / 9.8);
			float a = topple(tau / T, 0.3) * thf;
			if (v.y > hb) {
				hinge_rotate(v, n, vec3(0.0, hb, 0.0), laxis, a);
			}
			// the stump bends a little as the top goes
			hinge_rotate(v, n, vec3(0.0), laxis, 0.07 * ease_out3(tau / T) * sat(VERTEX.y / max(hb, 1.0)));
		} else if (hit) {
			float sway = 0.03 * sat(q / 1.5) * exp(-tau / 2.0) * sin(tau * 2.4) * hfs;
			hinge_rotate(v, n, vec3(0.0), laxis, sway * sat(v.y / H));
		}
	} else if (kind == K_POLE) {
		float thr = 4.0 + 3.0 * seed;    // mirrored on the CPU (wires drop with their poles)
		if (hit && psi >= thr && hfs > 0.15) {
			float a = topple(tau / 1.9, 0.35) * 1.52 * hfs;
			hinge_rotate(v, n, lpush * 0.15, laxis, a);
		} else if (hit) {
			float sway = 0.05 * sat(q / 1.0) * exp(-tau / 1.5) * sin(tau * 3.5) * hfs;
			hinge_rotate(v, n, vec3(0.0), laxis, sway * sat(v.y / 10.0));
		}
	} else if (kind == K_WIRE) {
		// span from pole A (local x = 0) to pole B (x = 1); x is scaled to the span length
		vec3 xb = MODEL_MATRIX[0].xyz;
		float ca = rendered_ground(inst_o.xz) - inst_o.y;
		float cb = rendered_ground(inst_o.xz + xb.xz) - (inst_o.y + xb.y);
		float u = clamp(v.x, 0.0, 1.0);
		float corr = mix(ca, cb, u);
		if (hit && psi > 50.0) {
			// a pole went down: the line snaps and drops to the ground
			float f = sat(tau / 1.1);
			float yg = 0.04 - xb.y * u;     // ground along the chord (local), wires lie on it
			v.y = mix(v.y, yg + 0.04 * v.z, f * f);
		}
		v.y += corr;
		absolute = true;
	} else if (kind == K_BRIDGE) {
		if (part == P_DECK) {
			float thr = 10.0 + 8.0 * pr;
			if (hit && psi >= thr) {
				float S = min((1.5 + 0.3 * (psi - thr)) * imp * (0.3 + 0.7 * hfs), 30.0);
				debris(v, n, pv, pr, vec3(1.0, 0.0, 0.0), (pr - 0.5) * 0.5, ext, tau, S, 0.3, 0.15, 0.0,
					(pr - 0.5) * 0.4, 0.0, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			}
		} else if (part == P_PIER) {
			float thr = 35.0 + 25.0 * pr;
			if (hit && psi >= thr) {
				hinge_rotate(v, n, pv + lpush * 0.6, laxis, topple(tau / 1.6, 0.4) * 1.45 * hfs);
			}
		} else if (part == P_GROUND) {
			vec3 w = inst_o + m3 * v;
			v.y += (rendered_ground(w.xz) - inst_o.y) / sc;
			absolute = true;
		}
	} else if (kind == K_BUNKER) {
		float crack_thr = 100.0 + 60.0 * rr(seed, 1.0);
		float kill_thr = 220.0 + 60.0 * rr(seed, 2.0);
		if (hit && psi >= crack_thr) {
			v_damage = sat((psi - crack_thr) / 80.0) * 0.6 + 0.4;
		}
		if (hit && psi >= kill_thr && part == P_SLAB) {
			debris(v, n, pv, pr, vec3(1.0, 0.0, 0.0), (pr - 0.5) * 0.6, ext, tau, 2.0 + 0.02 * (psi - kill_thr), 0.5, 0.2, 0.0,
				(pr - 0.5) * 0.5, 0.0, lpush, lside, inst_o, m3, sc, base_g);
			absolute = true;
		}
	} else if (kind == K_HANGAR) {
		float frame_thr = 3.1 + 0.6 * rr(seed, 1.0);
		float flat_thr = 6.0 + 2.0 * rr(seed, 2.0);
		if (hit && part != P_FOUND) {
			float clad_thr = (part == P_DOOR ? 2.0 + 0.8 * pr : 1.5 + 1.0 * pr);
			if ((part == P_CLAD || part == P_DOOR) && psi >= clad_thr) {
				float S = min((10.0 + 15.0 * (psi - clad_thr)) * imp * (0.2 + 0.8 * hfs), 160.0);
				debris(v, n, pv, pr, fax, fang, ext, tau, S, (2.0 + 4.0 * pr) * hfs, 0.45, floor(pr * 2.0),
					(pr - 0.5) * 3.0, 0.05 * pr, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else if (psi >= frame_thr) {
				float thm = mix(0.35, 1.35, sat((psi - frame_thr) / max(flat_thr - frame_thr, 0.1)));
				float f = topple(tau / 1.6, 0.4);
				rack(v, n, f * thm * hfs, lpush, laxis, 0.3);
				float crush = mix(1.0, 0.15, f * (1.0 - hfs));
				v.y = 0.3 + (v.y - 0.3) * crush;
			}
		}
	} else if (kind == K_AIRCRAFT) {
		float thr_throw = 2.0 + rr(seed, 1.0);
		float thr_wreck = 3.0 + rr(seed, 2.0);
		if (hit && psi >= 1.0) {
			if (part == P_WING && psi >= thr_wreck) {
				// wings snap off and tumble on their own
				float S = min((12.0 + 22.0 * (psi - thr_wreck)) * imp * (0.2 + 0.8 * hfs), 220.0);
				debris(v, n, pv, pr, vec3(1.0, 0.0, 0.0), 0.0, ext, tau, S, (3.0 + 3.0 * pr) * hfs, 0.5, floor(pr * 2.0),
					(pr - 0.5) * 4.0, 0.0, lpush, lside, inst_o, m3, sc, base_g);
				absolute = true;
			} else {
				if (part == P_FIN && psi >= thr_wreck) {
					hinge_rotate(v, n, pv, vec3(0.0, 0.0, 1.0), -1.35 * ease_out3(tau / 0.8));
				}
				float S;
				float yaw;
				float hop = 0.0;
				float T;
				float drop = 0.0;
				if (psi >= thr_throw) {
					S = min((8.0 + 25.0 * (psi - thr_throw)) * imp * hfs, 250.0);
					yaw = (rr(seed, 3.0) - 0.5) * 5.0 * hfs;
					hop = (2.5 + 2.5 * sat(psi - 2.0)) * hfs;
					T = 1.4 + S / 25.0;
					drop = gear_h * sat((tau - 0.15) / (T * 0.6));
					if (part == P_GEAR) {
						v = pv + (v - pv) * (1.0 - sat((tau - 0.1) / 0.5));
					}
				} else {
					float k = sat(psi - 1.0);
					S = (0.5 + 4.0 * k) * imp * hfs;
					yaw = (rr(seed, 3.0) - 0.5) * 0.4 * k * hfs;
					T = 1.8;
				}
				float e = ease_out3(tau / T);
				vec3 land_w = inst_o + m3 * (body_c + lpush * S);
				float g_land = (rendered_ground(land_w.xz) - inst_o.y) / sc;
				float hp = max(hop * tau - 4.9 * tau * tau, 0.0);
				mat3 R = rot_y(yaw * e);
				vec3 P = vec3(body_c.x, 0.0, body_c.z) + lpush * S * e;
				P.y = mix(base_g, g_land, e) + body_c.y - drop + hp;
				v = P + R * (v - body_c);
				n = R * n;
				absolute = true;
			}
		}
	} else if (kind == K_RAILCAR) {
		float der_thr = 6.0 + 0.8 * rr(seed, 1.0);
		float over_thr = 6.8 + 1.4 * rr(seed, 2.0);
		float kill_thr = 9.0 + 1.5 * rr(seed, 3.0);
		if (hit && psi >= kill_thr && part == P_BOGIE) {
			float S = min((3.0 + 1.5 * (psi - kill_thr)) * imp * hfs, 80.0);
			debris(v, n, pv, pr, vec3(1.0, 0.0, 0.0), 0.0, ext, tau, S, 1.5 * hfs, 0.6, floor(pr * 2.0),
				(pr - 0.5) * 3.0, 0.0, lpush, lside, inst_o, m3, sc, base_g);
			absolute = true;
		} else if (hit && psi >= der_thr) {
			float roll = 0.1;
			float S = 0.6 + 0.6 * rr(seed, 4.0);
			float crush = 1.0;
			if (psi >= over_thr) {
				roll = PI * 0.5;
				S = 1.5 + 0.5 * (psi - over_thr);
			}
			if (psi >= kill_thr) {
				roll = PI * (0.5 + 0.5 * step(0.5, rr(seed, 5.0)));
				S = 5.0 + 2.0 * (psi - kill_thr);
				crush = 0.75;
			}
			S = min(S * imp * hfs, 100.0);
			rigid_roll(v, n, tau, 1.1 + 0.3 * sqrt(S), S, roll * step(0.3, hfs), 0.0, crush, lpush, laxis,
				inst_o, m3, sc, base_g);
			absolute = true;
		} else if (hit && psi >= 2.0) {
			float a = 0.025 * exp(-tau / 0.5) * sin(tau * 8.0) * hfs;
			hinge_rotate(v, n, vec3(0.0), laxis, a);
		}
	}

	if (!absolute) {
		v.y += base_g;
	}
	VERTEX = v;
	NORMAL = n;

	// ---- thermal: char, ignition, flames; glass; dust coat
	float Q = 0.0;
	if (age > 0.0) {
		Q = fl * th_frac(age / max(t2, 1e-4));
	}
	v_char = char_amount(kind, part, Q);
	v_burn = 0.0;
	if (ign >= 0.0 && age > ign && flammable(kind, part) && psi < 999.0) {
		float ti = age - ign;
		float b = smoothstep(0.0, 1.5, ti) * mix(1.0, 0.35, smoothstep(30.0, 300.0, ti));
		if (hit && psi > 1.5) {
			// the blast wind blows most flames out for a few seconds, the debris rekindles
			b *= 1.0 - 0.85 * smoothstep(0.0, 0.15, tau) * exp(-tau / 4.0);
		}
		if (part == P_LEAVES && hit) {
			b *= 1.0 - (kind == K_JUNIPER ? sat((psi - 3.0) / 4.0) : sat((psi - 1.2) / 1.3));
		}
		v_burn = b;
	}
	if (part == P_GLASS && hit) {
		float gthr = 0.5 + 0.8 * fract(UV.x + seed * 5.3);
		if (psi >= gthr) {
			v_glass = smoothstep(0.0, 0.04, tau);
		}
	}
	if (hit) {
		v_dust = 0.35 * sat(psi / 4.0) * smoothstep(0.0, 0.6, tau);
	}
}

// ------------------------------------------------------------------ fragment

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), u.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), u.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

const vec3 WOOD_PAL[6] = vec3[](vec3(0.86, 0.84, 0.78), vec3(0.83, 0.75, 0.55), vec3(0.62, 0.69, 0.74),
	vec3(0.64, 0.70, 0.56), vec3(0.58, 0.52, 0.45), vec3(0.80, 0.66, 0.60));
const vec3 CAR_PAL[7] = vec3[](vec3(0.06, 0.06, 0.07), vec3(0.18, 0.30, 0.22), vec3(0.42, 0.10, 0.10),
	vec3(0.85, 0.82, 0.70), vec3(0.45, 0.60, 0.72), vec3(0.50, 0.50, 0.52), vec3(0.75, 0.55, 0.25));

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 alb = v_col;
	float rough = 0.85;
	float metal = 0.0;
	float spec = 0.4;
	vec3 emis = vec3(0.0);
	int part = v_part;
	float age = g_blast_age;
	float s = v_seed;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float aa = 1.0 - smoothstep(30.0, 250.0, dist);   // fine patterns fade with distance

	// ---- per-instance variety and surface patterns
	if (kind == K_WOOD && (part == P_WALL)) {
		alb = pow(WOOD_PAL[int(s * 5.999)], vec3(2.2));
		float stripe = smoothstep(0.82, 0.95, fract(v_uv.y * 4.4));
		alb *= 1.0 - 0.18 * stripe * aa;
	} else if (part == P_ROOF) {
		float row = smoothstep(0.7, 0.95, fract(v_uv.y * 3.3));
		alb *= (0.85 + 0.3 * rr(s, 6.0)) * (1.0 - 0.25 * row * aa);
	} else if (kind == K_BRICK && part == P_WALL) {
		alb *= 0.8 + 0.35 * rr(s, 4.0);
		float course = smoothstep(0.86, 0.97, fract(v_uv.y * 6.0));
		alb = mix(alb, vec3(0.45, 0.42, 0.38), course * 0.5 * aa);
		alb *= 0.9 + 0.2 * vnoise3(v_local * 1.7) * aa;
	} else if ((kind == K_CAR) && part == P_BODY) {
		alb = pow(CAR_PAL[int(s * 6.999)], vec3(2.2));
		rough = 0.35;
		spec = 0.6;
	} else if (part == P_LEAVES) {
		alb *= vec3(0.85 + 0.3 * rr(s, 4.0), 0.9 + 0.2 * rr(s, 5.0), 0.8) * (0.75 + 0.5 * vnoise3(v_local * 2.3));
		rough = 0.9;
	} else if (part == P_METAL || kind == K_AIRCRAFT && part != P_GLASS || kind == K_HANGAR && part == P_CLAD) {
		metal = 0.6;
		rough = 0.45;
	} else if (part == P_FOUND || kind == K_BUNKER || part == P_PIER || part == P_DECK) {
		alb *= 0.85 + 0.25 * vnoise3(v_local * 0.6);
		rough = 0.95;
	} else if (part == P_GROUND || part == P_EMBANK) {
		alb *= 0.8 + 0.35 * vnoise3(wp * 0.35);
		rough = 1.0;
	}
	if (kind == K_RAILCAR && part == P_BODY) {
		alb *= 0.75 + 0.45 * rr(s, 4.0);
	}
	if (kind == K_TRUCK && (part == P_BODY || part == P_CLAD) || kind == K_TANK && part != P_WHEEL) {
		alb *= 0.85 + 0.3 * rr(s, 4.0);
		rough = 0.8;
	}
	if (kind == K_BUNKER && v_damage > 0.0) {
		float cr = smoothstep(0.55, 0.62, vnoise3(v_local * 2.5)) * v_damage;
		alb *= 1.0 - 0.7 * cr;
	}

	// ---- dust coat left by the shock front
	alb = mix(alb, vec3(0.42, 0.36, 0.29), v_dust * (part == P_GLASS ? 0.2 : 1.0));

	// ---- glass: dark and glossy, glints of the fireball; broken = dark empty frames
	vec3 vdir = normalize(wp - CAMERA_POSITION_WORLD);
	if (part == P_GLASS) {
		if (v_glass < 0.5) {
			alb = vec3(0.035, 0.04, 0.045);
			rough = 0.06;
			spec = 0.9;
			if (g_fireball_color.w > 0.0) {
				vec3 lf = normalize(g_fireball.xyz - wp);
				vec3 rf = reflect(vdir, nw);
				float gl = pow(max(dot(rf, lf), 0.0), 24.0);
				emis += g_fireball_color.rgb * gl * min(g_fireball_color.w * 0.3, 60.0);
			}
		} else {
			alb = vec3(0.012, 0.011, 0.01);
			rough = 1.0;
			spec = 0.05;
		}
	}

	// ---- thermal: scorched on the side that faced the fireball (shadowed sides keep their paint)
	float face = smoothstep(-0.1, 0.35, v_face);
	float chr = v_char * (part == P_LEAVES ? 0.6 + 0.4 * face : face);
	vec3 char_col = part == P_LEAVES ? vec3(0.09, 0.06, 0.03) : vec3(0.03, 0.026, 0.022);
	if (part == P_LEAVES) {
		// green -> brown -> black
		alb = mix(alb, vec3(0.20, 0.12, 0.05), smoothstep(0.0, 0.5, chr));
		alb = mix(alb, char_col, smoothstep(0.5, 1.0, chr));
	} else {
		alb = mix(alb, char_col, chr * 0.92);
	}
	rough = mix(rough, 1.0, chr);
	metal *= 1.0 - chr;

	// ---- flames: flickering tongues licking upward
	if (v_burn > 0.001) {
		vec3 fp = wp * 0.9 + vec3(0.0, -age * 2.6, 0.0) + s * 31.0;
		float n1 = vnoise3(fp);
		float n2 = vnoise3(fp * 2.3 + vec3(0.0, -age * 3.1, 0.0));
		float fl = smoothstep(0.35, 0.85, n1 * 0.65 + n2 * 0.45);
		float mask = part == P_GLASS ? 1.0 : (0.35 + 0.65 * face);
		vec3 fcol = mix(vec3(1.0, 0.28, 0.04), vec3(1.0, 0.62, 0.22), n2);
		emis += fcol * v_burn * fl * mask * 14.0 * fire_gain;
		alb *= 1.0 - 0.6 * v_burn;
	}

	// ---- fireball light: warm flash tint on the side facing the blast
	if (g_fireball_color.w > 0.0 && g_fireball.w > 0.0) {
		vec3 L = g_fireball.xyz - wp;
		float d = length(L);
		float ndl = max(dot(nw, L / max(d, 1e-3)), 0.0);
		float k = pow(g_fireball.w / max(d, g_fireball.w), 2.0);
		emis += alb * g_fireball_color.rgb * min(g_fireball_color.w * k * 0.5 * flash_tint_gain, 40.0) * ndl;
	}

	// ---- engulfed by the fireball: black glassy remains, glowing for a while
	if (v_oblit > 0.0) {
		alb = mix(alb, vec3(0.025, 0.02, 0.018), v_oblit);
		rough = mix(rough, 0.5, v_oblit);
		float tglow = max(age, 0.0);
		emis += vec3(1.0, 0.25, 0.05) * 5.0 * v_oblit * exp(-tglow / 25.0) * (0.6 + 0.4 * vnoise3(wp * 0.4));
	}

	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emis;
	FOG = atm_fog(CAMERA_POSITION_WORLD, wp);
}
