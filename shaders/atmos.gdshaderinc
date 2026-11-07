// Shared aerial perspective: exponential-height haze (Mie) + thin Rayleigh layer.
// Used by terrain, objects and the explosion volumes so that everything fades consistently.

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

// Returns vec4(fog colour, fog amount 0..1) for the segment camera -> point.
vec4 atm_fog(vec3 cam, vec3 p) {
	float od = atm_layer_od(cam, p, g_fog.x, g_fog.y) + atm_layer_od(cam, p, g_fog.z, 8000.0);
	float amount = 1.0 - exp(-od);
	vec3 v = normalize(p - cam);
	float mu = dot(v, normalize(g_sun_dir));
	float sun_k = pow(max(mu, 0.0), 6.0) * 0.8 + pow(max(mu, 0.0), 40.0) * 1.5;
	vec3 col = g_fog_color.rgb * g_fog_color.w + g_fog_sun.rgb * sun_k * g_fog_color.w;
	// the air around the explosion glows during the flash
	if (g_fireball_color.w > 0.0) {
		vec3 fd = normalize(g_fireball.xyz - cam);
		float c = max(dot(v, fd), 0.0);
		col += g_fireball_color.rgb * g_fireball_color.w * (0.01 + 0.05 * pow(c, 8.0)) * 0.05;
	}
	return vec4(col * g_exposure, amount);
}
