// Shared aerial perspective: exponential-height haze (Mie) + thin Rayleigh layer.
// Used by terrain, objects, the explosion volumes and the sky so that everything fades consistently.

global uniform vec4 g_fog;        // x: haze extinction at the playa (1/m), y: haze scale height (m), z: rayleigh extinction, w: unused
global uniform vec4 g_fog_color;  // rgb: in-scattered haze colour (away from the sun), w: brightness
global uniform vec4 g_fog_sun;    // rgb: colour toward the sun (forward scattering), w: unused
global uniform vec3 g_sun_dir;
global uniform vec4 g_fireball;        // xyz world pos, w radius
global uniform vec4 g_fireball_color;  // rgb colour, w luminous intensity
// Camera exposure multiplier. Godot folds the exposure into lit shading but NOT into unshaded
// output or custom FOG colours, so those must be multiplied explicitly.
global uniform float g_exposure;

const float ATM_GROUND_Y = -22.0;
// Apparent (haze-attenuated) radiance of the fireball surface per unit of g_fireball_color.w,
// calibrated on the explosion volume for the megaton shots at their viewing distance.
const float ATM_FB_RADIANCE = 3.0;

// Optical depth of an exponential layer between two points (straight segment).
float atm_layer_od(vec3 a, vec3 b, float sigma0, float H) {
	float L = length(b - a);
	float ha = max(a.y - ATM_GROUND_Y, 0.0);
	float hb = max(b.y - ATM_GROUND_Y, 0.0);
	float dh = hb - ha;
	float ea = exp(-ha / H);
	if (abs(dh) < 1.0) {
		return sigma0 * ea * L;
	}
	float eb = exp(-hb / H);
	return sigma0 * L * H * (ea - eb) / dh;
}

// Relative humidity recovered from the haze scale height (EnvironmentCtl: lerp(2200, 1400, h)).
float atm_humidity() {
	return clamp((2200.0 - g_fog.y) / 800.0, 0.0, 1.0);
}

// Haze colour (not exposed) for a view direction: away-from-sun colour plus the forward lobe.
vec3 atm_haze_color(vec3 v) {
	float mu = max(dot(v, normalize(g_sun_dir)), 0.0);
	float sun_k = pow(mu, 6.0) * 0.8 + pow(mu, 40.0) * 1.5;
	return (g_fog_color.rgb + g_fog_sun.rgb * sun_k) * g_fog_color.w;
}

// Light of the fireball scattered by the air, seen from `cam` in direction `v` (radiance, not
// exposed). Normalised to the ball's own radiance: at the limb it is ~6-12 % of it (more in humid
// air) and it falls off over several ball radii, as in the Tsar / Ivy Mike / Bravo photographs.
// near_w weights the near-field part (the glowing air around the ball): 1 for the sky and for
// points at or beyond the fireball, 0 for points well in front of it.
vec3 atm_fireball_glow(vec3 cam, vec3 v, float near_w) {
	if (g_fireball_color.w <= 0.0 || g_fireball.w <= 0.0) {
		return vec3(0.0);
	}
	vec3 to = g_fireball.xyz - cam;
	float D = max(length(to), 1.0);
	vec3 fd = to / D;
	float ang_r = asin(clamp(g_fireball.w / D, 1e-5, 0.999));
	// angle between v and the ball centre (stable for tiny angles)
	float ang = 2.0 * asin(clamp(0.5 * length(v - fd), 0.0, 1.0));
	float x = max(ang - ang_r, 0.0) / ang_r;          // distance from the limb in ball radii
	float hum = atm_humidity();
	// near field: air around the ball lit by it (falls off within ~1 radius)
	float near_f = exp(-x / (0.55 + 0.35 * hum));
	// aureole: forward (Mie) scattering of the ball's light by the haze along the line of sight
	float aur = 1.0 / ((1.0 + x) * (1.0 + x));
	// broad glow of the whole sky around the ball
	float wide = exp(-ang / 0.45);
	// limb: ~4.5 % of the ball at 35 % humidity, ~9 % in humid air; ~1 % one radius out,
	// ~0.2 % three radii out (Tsar 1961 frame)
	float rel = near_w * 0.03 * (0.7 + 0.9 * hum) * near_f
			+ 0.012 * (0.6 + 1.2 * hum) * aur
			+ 0.001 * (0.5 + 1.5 * hum) * wide;
	// incandescence (sRGB-like Kelvin colour -> linear), reddened by the Rayleigh path to the ball;
	// g_fireball_color.w already carries the grey transmittance, so keep the luminance
	vec3 c = pow(max(g_fireball_color.rgb, vec3(0.0)), vec3(2.2));
	float od_r = atm_layer_od(cam, g_fireball.xyz, g_fog.z, 8000.0);
	vec3 tr = exp(-od_r * vec3(0.43, 1.0, 2.45));
	tr /= max(dot(tr, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
	return c * tr * (g_fireball_color.w * ATM_FB_RADIANCE * rel);
}

// Returns vec4(fog colour, fog amount 0..1) for the segment camera -> point.
vec4 atm_fog(vec3 cam, vec3 p) {
	float od = atm_layer_od(cam, p, g_fog.x, g_fog.y) + atm_layer_od(cam, p, g_fog.z, 8000.0);
	float amount = 1.0 - exp(-od);
	vec3 v = normalize(p - cam);
	vec3 col = atm_haze_color(v);
	// the air around the explosion glows: the aureole along the whole segment, and the near-field
	// glow only for points close to or beyond the fireball
	if (g_fireball_color.w > 0.0) {
		float dp = length(p - cam);
		float dfb = length(g_fireball.xyz - cam);
		float near_w = smoothstep(dfb - 4.0 * g_fireball.w, dfb - 0.5 * g_fireball.w, dp);
		col += atm_fireball_glow(cam, v, near_w);
	}
	return vec4(col * g_exposure, amount);
}
