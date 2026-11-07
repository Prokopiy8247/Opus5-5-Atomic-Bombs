# Cycle-3 per-bomb overrides, group A (merged by tools/bomb_profiles.py).
# Bombs 1-4 (Mk 82, Mk 84, Tallboy, Grand Slam). Cloud-top / width keyframes are fitted to the
# dossier (data/research_values.json key_timings) through the column-head rise model:
#   top(t) ~= col_height*cap_center_k + cap_rise*late + cap_aspect*r,
#   r = col_cap_r*(1 + cap_late_grow*late), late = sqrt((t - col_rise)/cap_grow_time).
CYCLE3 = {
    # 1. Mk 82: saturated orange flash ball with soot, black V-fan crown of soil jets (35 x 25 m),
    # fragment dust fan, then a lumpy black->grey-brown puff (60 m @5 s, 130 m @30 s, 200 m @60 s).
    "mk82": dict(
        emission=240.0, fb_temp_peak=3200.0, fireball_noise=0.6, skin_start=0.0,
        shock_refraction=2.5, dust_color=[0.78, 0.74, 0.68],
        col_height=24.0, col_cone=2.6, col_flare=1.0, col_density=1.2, col_fall=0.0, col_fade=0.9, jet_amount=0.6, col_rise=1.5,
        col_top_keys=[[0.08, 0.0], [0.15, 11.0], [0.3, 21.0], [0.5, 24.0], [600.0, 24.0]], stem_color=[0.08, 0.075, 0.07],
        stem_stretch=1.0,
        col_cap_r=10.0, cap_center_k=0.25, cap_aspect=0.45, cap_appear=2.5, cap_late_grow=9.2,
        cap_rise=368.0, cap_grow_time=240.0, head_lobes=1.0,
        head_color_late=[0.22, 0.21, 0.20], whiten_s=30.0,
        frag_puffs=80, frag_puff_life=3.0, ground_color=[0.40, 0.34, 0.27],
        wind=[1.8, -0.7], near_m=200.0, frame_phase_s=[0.1, 3.0, 20.0],
    ),
    # 2. Mk 84: long orange ball under a black cauliflower soot cap, a dark column ~60 m wide at 1 s
    # (no head-on-stalk), wide fragment fan, grey-tan dirty thermal (230 m @30 s, 330 m @60 s).
    "mk84": dict(
        emission=260.0, fb_temp_peak=2900.0, fb_duration_s=1.2, fireball_noise=0.7, fireball_noise_scale=1.8,
        skin_start=0.0, shock_refraction=2.5,
        col_radius=10.0, col_cone=2.2, col_height=50.0, col_density=1.6, col_flare=1.3,
        stem_color=[0.10, 0.09, 0.08], stem_stretch=1.0, col_fall=0.0, col_fade=1.3, jet_amount=0.5, col_delay=0.3, col_rise=1.5,
        col_top_keys=[[0.3, 0.0], [0.4, 20.7], [0.5, 33.3], [0.6, 40.9], [0.75, 47.1], [0.9, 50.0], [600.0, 50.0]],
        col_cap_r=24.0, cap_center_k=0.5, cap_aspect=0.5, cap_appear=0.35, cap_late_grow=6.0,
        cap_rise=487.0, cap_grow_time=240.0, head_lobes=1.0,
        head_color_late=[0.36, 0.32, 0.27], whiten_s=40.0, dark_base=0.7,
        head_noise_amp=0.9, billow_sharp=1.3, erosion=0.4,
        frag_puffs=150, frag_puff_r=250.0, frag_puff_life=3.5, ground_color=[0.40, 0.34, 0.27],
        dust_wall_h_max=5.0, dust_color=[0.55, 0.48, 0.38], surge_r=60.0,
        wind=[3.0, -1.2], near_m=450.0, frame_phase_s=[0.3, 3.0, 20.0],
    ),
    # 3. Tallboy: no fire; spall ring and heave, spiky dark soil geyser (jet_amount 0.3: no axis pillar),
    # head kept low inside the collapsing column (no lid on a stalk), low brown base surge, a flat dirty
    # brown-grey pall (~180 m @30 s, ~300 m @2 min).
    "tallboy": dict(
        stem_color=[0.15, 0.11, 0.075], stem_stretch=1.0,
        head_color_early=[0.20, 0.17, 0.13], head_color_late=[0.28, 0.24, 0.19], whiten_s=40.0, jet_amount=0.3, head_density=0.5,
        head_noise_amp=0.6,
        cap_appear=1.5, head_lobes=1.0, cap_center_k=0.5, cap_aspect=0.4, col_cap_r=40.0,
        cap_late_grow=2.6, cap_rise=280.0, cap_grow_time=240.0,
        surge_r=150.0, surge_h0=3.0, surge_h1=12.0, surge_tau=2.5, surge_density=0.35, col_fall_time=4.5,
        dome_h=6.0, dust_wall=1.0, dust_wall_tau=0.8,
        wind=[2.0, -1.0], near_m=700.0, frame_phase_s=[0.45, 1.5, 6.0, 20.0],
    ),
    # 4. Grand Slam: bigger, deeper: heave, dull vent glint, a 220 m brown-grey ejecta funnel whose grey top
    # (not lighter than the shaft: YouTube rule) sits inside the column, wide base surge, flat tan
    # drifting cloud (~330 m @30 s, ~390 m @60 s).
    "grand_slam": dict(
        col_radius=22.0, col_cone=2.2, col_flare=2.6, col_spread=0.5,
        stem_color=[0.15, 0.125, 0.10], stem_stretch=1.0,
        head_color_early=[0.24, 0.23, 0.22], head_color_late=[0.30, 0.25, 0.19], whiten_s=60.0, jet_amount=0.25, head_density=0.5, col_fall=3.0, col_fall_time=5.0,
        head_noise_amp=0.6,
        cap_appear=1.2, head_lobes=1.0, cap_center_k=0.7, cap_aspect=0.4, col_cap_r=65.0,
        cap_late_grow=1.6, cap_rise=383.0, cap_grow_time=240.0,
        surge_start=2.0, surge_r=200.0, surge_h0=6.0, surge_h1=15.0, surge_tau=3.0, surge_density=0.35,
        dust_wall=1.0, dust_wall_tau=0.8,
        wind=[2.0, -1.0], near_m=900.0, frame_phase_s=[0.45, 1.5, 6.0, 20.0],
    ),
}
