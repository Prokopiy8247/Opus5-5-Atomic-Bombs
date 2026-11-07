# Cycle-3 per-bomb overrides, group D (merged by tools/bomb_profiles.py).
# 13 Sedan, 14 Ivy King, 15 B83, 16 RDS-37 (docs/reviews/cycle3_art_review.json).
CYCLE3 = {
    # 13. Sedan: broad lumpy grey-brown dust tower with no cap (no shaft + knob), slow documented climb
    # (610 m ejecta apex at ~13 s, 3.7 km at ~5.5 min), late base surge, visible salmon vent glow.
    "sedan": dict(
        dome_r=170.0, dome_burst=3.0, emission=250.0, fireball_noise=0.5, fireball_noise_scale=2.5,
        vent_time=3.0, vent_duration=1.4, vent_radius=55.0, vent_height=110.0,
        col_top_keys=[[3.1, 0.0], [3.6, 110.0], [4.3, 190.0], [5.0, 250.0], [8.0, 450.0], [13.0, 610.0], [30.0, 1000.0], [60.0, 1600.0],
                      [120.0, 2500.0], [240.0, 3400.0], [330.0, 3700.0]],
        col_radius=480.0, col_spread=0.3, col_rise=30.0, col_flare=1.8, col_density=2.0,
        col_cap_r=750.0, cap_aspect=0.55, cap_late_grow=0.6, cap_grow_time=200.0, cap_center_k=0.78,
        head_lobes=0.85, head_noise_scale=1.0, head_noise_amp=0.4, erosion=0.4, head_density=1.4, jet_fade_s=[12.0, 25.0],
        head_color_early=[0.22, 0.18, 0.14], head_color_late=[0.25, 0.21, 0.17], whiten_s=1500.0,
        stem_color=[0.22, 0.18, 0.14],
        surge_start=12.0, surge_tau=150.0, surge_h0=100.0, surge_h1=350.0,
        debris_count=300, debris_size=6.0, debris_speed=120.0, debris_cone=55.0, debris_frac=1.0,
        debris_color=[0.62, 0.57, 0.48],
        wind=[3.5, -2.0], near_m=3500.0,
        frame_phase_s=[3.45, 10.0, 45.0, 150.0],
    ),
    # 14. Ivy King: short bright Wilson dome (0.5-5 s), early red-brown torus glowing orange underneath,
    # reddish stem, flatter late cap sheared by the upper wind, stays brown until ~4 min.
    "ivy_king": dict(
        wilson_dur_s=2.6, wilson_start=0.5, wilson_discs=0.3, wilson_opacity=0.55, wilson_flatten=0.5,
        fb_fade_s=[6.0, 15.0], head_appear_s=[4.0, 10.0], torus_x0=0.005, torus_dx=0.02, fireball_squash=0.88,
        core_radius=0.7, core_glow=3.0, core_cool_s=120.0, dark_base=-0.3,
        head_color_early=[0.16, 0.075, 0.045], head_color_late=[0.70, 0.66, 0.63], whiten_time=1.2,
        head_noise_amp=0.32, stem_color=[0.24, 0.12, 0.07], stem_density=1.1, stem_wake=0.15, stem_speed_rel=1.3,
        stem_radius_m=550.0, stem_top_flare=1.0,
        cap_aspect_keys=[[0.5, 0.75], [60.0, 0.65], [180.0, 0.45], [360.0, 0.32], [600.0, 0.28]],
        overshoot=0.1, wind=[8.0, -4.0],
    ),
    # 15. B83: surface megaton: hemisphere -> red-brown torus pulling a dark soil stem, no condensation
    # ring, dark dusty skirt, dirty brown cap (never white), flatter stabilised cap.
    "b83": dict(
        fb_fade_s=[10.0, 22.0], head_appear_s=[7.0, 20.0], stem_delay=6.0, stem_speed_rel=1.3, rings=0,
        skirt_color=[0.36, 0.29, 0.22], dust_color=[0.45, 0.37, 0.28], skirt_fade_s=[60.0, 240.0],
        debris_size=15.0, debris_speed=120.0, head_noise_amp=0.42,
        core_radius=0.6, core_glow=2.5, core_cool_s=70.0,
        head_color_early=[0.20, 0.12, 0.08], head_color_late=[0.40, 0.34, 0.27], whiten_time=2.5,
        cap_aspect_keys=[[0.5, 0.75], [60.0, 0.7], [240.0, 0.5], [600.0, 0.32]],
        wind=[7.0, -3.5],
    ),
    # 16. RDS-37: noon (no salmon dawn), Wilson dome + thin laminar stacked discs, thin dark stem,
    # translucent bell skirt at mid-stem, a thin stem ring, brown dust skirt, flat late cap.
    "rds37": dict(
        tod_hist="noon",
        wilson_hum_min=0.75, wilson_start=0.5, wilson_dur_s=2.8, wilson_flatten=0.35, wilson_discs=0.6,
        wilson_opacity=0.6,
        ring_list=[[1.5, 7.0, 900.0, 2400.0, 40.0], [2.0, 7.0, 1900.0, 3000.0, 40.0],
                   [2.6, 7.0, 3000.0, 2800.0, 45.0], [45.0, 70.0, 5500.0, 1300.0, 30.0]],
        tier2={"t_on": 0.08, "dur": 0.25, "opacity": 0.2, "radius_m": 3500.0, "height_rel": 0.2, "half_m": 1400.0},
        fb_fade_s=[10.0, 24.0], fb_cool_s=[8.0, 20.0], head_appear_s=[8.0, 22.0], stem_speed_rel=1.2,
        stem_color=[0.13, 0.10, 0.08], stem_density=1.2, stem_top_flare=1.0, head_noise_amp=0.22, stem_radius_m=900.0,
        skirt_color=[0.34, 0.28, 0.22], skirt_height=2.5, skirt_max_r=6000.0,
        core_radius=0.6, core_glow=2.5, core_cool_s=90.0, dark_base=-0.3, head_color_early=[0.20, 0.10, 0.06],
        head_color_late=[0.44, 0.45, 0.48], wind=[4.0, -2.0],
        cap_aspect_keys=[[0.5, 0.75], [60.0, 0.7], [240.0, 0.45], [600.0, 0.3]], cap_half_m=3500.0,
    ),
}
