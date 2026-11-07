// GPU twin of scripts/world/terrain_math.gd. KEEP IN SYNC.

const float EARTH_R_EFF = 8.5e6;
const float PLAYA_Y = -22.0;
const float BERM_TOP_Y = -2.4;

uint t_hash(int x, int y) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

float t_rnd(int x, int y) {
	return float(t_hash(x, y) & 0xFFFFFFu) / 16777215.0;
}

float t_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	int ix = int(i.x);
	int iy = int(i.y);
	float a = t_rnd(ix, iy);
	float b = t_rnd(ix + 1, iy);
	float c = t_rnd(ix, iy + 1);
	float d = t_rnd(ix + 1, iy + 1);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float t_fbm(vec2 p, int octaves) {
	float s = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		s += amp * t_value_noise(p);
		p = vec2(1.6 * p.x + 1.2 * p.y + 17.3, -1.2 * p.x + 1.6 * p.y + 9.1);
		amp *= 0.5;
	}
	return s;
}

float t_ridged(vec2 p, int octaves) {
	float s = 0.0;
	float amp = 0.5;
	float prev = 1.0;
	for (int i = 0; i < octaves; i++) {
		float n = 1.0 - abs(t_value_noise(p));
		n = n * n;
		s += amp * n * prev;
		prev = clamp(n * 1.6, 0.0, 1.0);
		p = vec2(1.6 * p.x + 1.2 * p.y + 31.7, -1.2 * p.x + 1.6 * p.y + 4.3);
		amp *= 0.5;
	}
	return s;
}

float t_mountain_mask(vec2 xz) {
	float r = length(xz);
	float fwd = -xz.y;
	float side = abs(xz.x) - 0.35 * max(fwd, 0.0) - 6000.0;
	float flank = clamp(side / 14000.0, 0.0, 1.0);
	float behind = clamp((-fwd - 4000.0) / 12000.0, 0.0, 1.0);
	float far_m = clamp((r - 235000.0) / 40000.0, 0.0, 1.0);
	float m = max(max(flank, behind), far_m);
	return m * m * (3.0 - 2.0 * m);
}

// octave_scale lets the fragment/vertex shader drop octaves with distance (LOD).
float t_height_flat_lod(vec2 xz, float lod) {
	float r = length(xz);
	int o1 = 5;
	int o2 = lod > 0.5 ? 0 : 3;
	float h = PLAYA_Y + 6.0 * t_fbm(xz * 0.00035, o1);
	if (o2 > 0) {
		h += 1.2 * t_fbm(xz * 0.004, o2);
	}
	float berm = clamp((520.0 - r) / 420.0, 0.0, 1.0);
	berm = berm * berm * (3.0 - 2.0 * berm);
	h = mix(h, BERM_TOP_Y - 0.0006 * r * r / 10.0, berm);
	float mm = t_mountain_mask(xz);
	if (mm > 0.0) {
		float rid = t_ridged(xz * 0.000045, 6);
		float hills = 0.5 + 0.5 * t_fbm(xz * 0.00012 + vec2(3.1, -7.7), 4);
		float amp = 2600.0 * clamp(r / 120000.0, 0.25, 1.0);
		h += mm * (rid * amp * (0.55 + 0.45 * hills));
	}
	return h;
}

float t_height_flat(vec2 xz) {
	return t_height_flat_lod(xz, 0.0);
}

float t_curvature_drop(vec2 xz) {
	return dot(xz, xz) / (2.0 * EARTH_R_EFF);
}

float t_height(vec2 xz) {
	return t_height_flat(xz) - t_curvature_drop(xz);
}
