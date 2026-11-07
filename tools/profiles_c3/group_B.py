# Cycle-3 per-bomb overrides, group B (merged by tools/bomb_profiles.py).
# Bombs: 5 MOAB, 6 Davy Crockett (Little Feller I), 7 Father of All Bombs, 8 B61-12 (0.3 kt).
# Review: docs/reviews/cycle3_art_review.json (bombs 5-8). Physical sizes (fireball radius, cloud top,
# cap diameter) stay on the dossier values (data/research_values.json); keyframes below only shape the
# growth towards them.
CYCLE3 = {
    # 5. MOAB: low golden pancake of flame on the ground (140 x 40 m at 0.45 s, white core, orange rim,
    # brown-grey smoke blotches by 1.5 s), dust ring racing out, then a white/light-grey STEMLESS
    # cauliflower thermal ~as tall as wide at 8 s (sits on its dust skirt), rising to 1.5 km by 3 min.
    "moab": {
        # flame: golden body, white-hot core clipping, orange where it thins; skin <= 1.15 (above ~1.18 the
        # shader turns the soot teal: negative emission/albedo)
        "emission": 230.0, "fb_temp_peak": 4000.0, "fireball_squash": 0.38,
        # less blue in the flame emission: golden yellow / orange instead of AgX-bleached cream
        "fireball_tint": [0.0, 0.10, -0.12, 1.0], "tint_time": 3.0,
        "fireball_noise": 0.35, "fireball_noise_scale": 2.5, "skin": 1.15, "skin_start": 0.15,
        # smoke rises out of the flame from ~0.5 s (no grey sphere popping in at 2.5-3.4 s)
        "head_appear_rel": 0.2,
        # light grey-brown smoke + dust turning white-grey (aluminium oxide), darker grey lower lobe
        "head_color_early": [0.42, 0.38, 0.34], "head_color_late": [0.72, 0.68, 0.62], "dark_base": 0.85,
        # stemless lumpy thermal: no stalk, no mushroom roll-up, multi-lobed head
        "stem_density": 0.0, "torus": 0.1, "head_lobes": 1.0, "head_noise_amp": 0.55, "billow_sharp": 1.2,
        # growth: ~160 x 125 m at 8 s sitting on the ground, 1.5 km top / 0.5 km cap by 3 min (dossier)
        "rise_k": 20.0,
        "top_keys": [[2.0, 70.0], [4.0, 95.0], [8.0, 125.0], [15.0, 220.0], [30.0, 420.0], [60.0, 750.0], [180.0, 1500.0]],
        "cap_d_keys": [[2.0, 140.0], [4.0, 150.0], [8.0, 165.0], [15.0, 200.0], [30.0, 280.0], [60.0, 380.0], [180.0, 500.0]],
        # low ragged dust skirt ~1.5x the cloud width (250 m at 3 s), visible dust ring + shock shimmer
        "skirt_max_r": 140.0, "skirt_height": 1.5, "skirt_fade_s": [20.0, 90.0], "skirt_color": [0.52, 0.46, 0.38],
        "dust_wall": 1.0, "dust_wall_tau": 3.0, "dust_color": [0.80, 0.76, 0.70], "shock_refraction": 2.5,
        # one-frame humid-air condensation veil over the dome at ~0.03-0.2 s (section 6.3 'condensation';
        # longer/denser it reads as a glass or cotton dome)
        "wilson": 0.7, "wilson_hum_min": 0.8, "wilson_dur_s": 0.08, "wilson_start": 0.03,
        "wilson_flatten": 0.9, "wilson_opacity": 0.08,
        "debris_count": 250,
        "near_m": 1000.0,
    },
    # 6. Davy Crockett / Little Feller I: blinding flash, 17 m glowing hemisphere (to ~0.6 s), white
    # bell cloud on a bright dust band, then a tall column-like cauliflower cap (taller than wide) on a
    # thin wavy dusty stem; dirty cap (white above, tan below) drifting NNW, 1.8 km top by 3 min.
    "davy_crockett": {
        "torus": 0.0, "head_lobes": 1.0, "head_noise_amp": 0.5, "billow_sharp": 1.3,
        # h/R ~1.0-1.3 (taller than wide) for 2-90 s: the keys also set the lerp target cap_r*asp, hence > 1
        "cap_aspect_keys": [[1.0, 2.7], [2.0, 2.6], [5.0, 2.65], [10.0, 2.75], [20.0, 2.8], [40.0, 2.1], [90.0, 1.45], [180.0, 0.89], [360.0, 0.71]],
        "cap_half_m": 1500.0,
        "top_keys": [[1.0, 50.0], [2.0, 90.0], [5.0, 220.0], [10.0, 400.0], [20.0, 700.0], [40.0, 1000.0], [90.0, 1400.0], [180.0, 1800.0]],
        "cap_d_keys": [[2.0, 60.0], [5.0, 120.0], [10.0, 200.0], [20.0, 320.0], [40.0, 430.0], [90.0, 560.0], [180.0, 700.0]],
        # neck widening into the head, flared dusty foot (bell at 0.5-2 s), no early stalk
        "stem_top_flare": 2.0, "stem_flare": 3.0, "stem_waist": 0.35, "stem_cap_ratio": 0.5, "stem_wake": 0.2,
        "head_color_early": [0.80, 0.77, 0.72], "head_color_late": [0.74, 0.70, 0.64], "dark_base": 0.8,
        "stem_color": [0.66, 0.62, 0.56], "stem_fade_s": [120.0, 300.0],
        # glow lasts to ~0.6 s in the vortex core (the 18 t ball itself cools in tens of ms)
        "core_glow": 1.2, "core_cool_s": 1.4, "core_radius": 0.9, "head_appear_s": [0.15, 0.8],
        "head_noise_scale": 0.75,
        # bright dust band along the ground and a wide low skirt
        "skirt": 1.4, "skirt_height": 0.5, "skirt_max_r": 350.0, "skirt_color": [0.80, 0.75, 0.66],
        "dust_color": [0.85, 0.80, 0.72], "dust_wall_h_max": 5.0, "dust_wall_tau": 6.0,
        "whiteout_s": 0.15,
        "near_m": 2200.0,
    },
    # 7. Father of All Bombs: broad ground-hugging yellow-orange rolling flame dome (~120 x 70 m by
    # 0.25-1.5 s), orange-red with black soot rolls 1.5-5 s, short dark neck by ~5 s, flames out by
    # ~8 s, then a dark grey-black smoke ball rising to ~2 km; little dust (a lumpy collar).
    "foab": {
        "emission": 300.0, "fb_temp_peak": 3600.0, "fb_grow_s": 0.6, "skin": 1.15,
        "head_color_early": [0.09, 0.08, 0.07],
        "fireball_tint": [0.0, 0.10, -0.12, 1.0], "tint_time": 9.0,
        "fireball_noise_scale": 2.6,
        "torus": 0.5, "head_lobes": 0.7, "head_noise_amp": 0.5,
        # short opaque dark neck at 5-9 s, then the smoke ball rises alone (no pale glass stem)
        "stem_density": 0.6, "stem_color": [0.12, 0.10, 0.09], "stem_fade_s": [6.0, 10.0],
        "skirt": 0.4, "skirt_max_r": 110.0, "skirt_height": 1.6,
        "dust_wall": 0.4, "dust_wall_tau": 1.0,
        "near_m": 900.0,
    },
    # 8. B61-12 0.3 kt airburst at 150 m: white ball never touching the ground, orange -> dull red in
    # ~1 s, thin Wilson veil, compact lumpy dark red-brown (NO2) cloud ball (Able) with a separate
    # lumpy dust column with a wide boiling foot (Wasp); grey-white cap ~0.9 km at ~2 km after ~4 min.
    "b61_12": {
        "head_color_early": [0.12, 0.055, 0.03], "whiten_time": 1.2, "erosion": 0.4, "dark_base": 0.75,
        "head_noise_scale": 0.6, "billow_sharp": 1.2, "head_noise_amp": 0.55, "head_lobes": 0.6,
        "fireball_noise": 0.06, "skin": 1.0, "mottle_t2": 4.0,
        "stem_radius_m": 55.0, "stem_density": 0.45, "stem_flare": 3.0, "stem_waist": 0.2, "stem_speed_rel": 0.45, "stem_detached_frac": 0.28, "stem_color": [0.40, 0.34, 0.27], "stem_fade_s": [90.0, 240.0],
        "skirt": 0.35, "skirt_height": 1.3, "skirt_max_r": 300.0,
        "dust_wall": 0.35, "dust_wall_tau": 2.0,
        "wilson": 0.6, "wilson_hum_min": 0.8, "wilson_dur_s": 0.05, "wilson_start": 0.03, "wilson_flatten": 0.75, "wilson_opacity": 0.05, "wilson_thick": 0.15,
        "near_m": 2800.0,
    },
}
