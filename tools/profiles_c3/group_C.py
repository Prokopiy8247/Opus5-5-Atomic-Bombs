# Cycle-3 per-bomb overrides, group C (merged by tools/bomb_profiles.py).
# 9 Grable, 10 Little Boy, 11 Trinity, 12 Baker (docs/reviews/cycle3_art_review.json).
# Sizes/times: top_keys follow data/research_values.json key_timings (cloud top vs time); final cap
# diameters (cap_d_keys end points) are the dossier values; intermediate cap widths are look decisions.
CYCLE3 = {
    # 9. Grable: low dusty airburst. Reflected-shock flat bottom from 0.07 s, documented cloud-top curve
    # (4.1 km @1 min .. 9.7 km @7 min), broad flattened dark-brown cap with a glowing orange toroid over a
    # thick lumpy dark dust stem (no lollipop: cap ~3x the stem at 40 s, same tone as the stem), larger
    # convective cells on the ball, lingering tan dust skirt, ice collar under the late cap.
    "grable": dict(
        reflect_cut_t=0.07, fireball_noise_scale=5.0,
        top_keys=[[1.4, 400.0], [5.0, 694.0], [10.0, 1080.0], [20.0, 1820.0], [40.0, 3200.0], [60.0, 4100.0],
                  [120.0, 6100.0], [240.0, 8400.0], [360.0, 9600.0], [420.0, 9700.0], [540.0, 10000.0]],
        cap_d_keys=[[5.0, 390.0], [10.0, 560.0], [20.0, 900.0], [40.0, 1400.0], [60.0, 1800.0], [120.0, 2500.0],
                    [240.0, 3100.0], [420.0, 3500.0], [600.0, 3700.0]],
        cap_aspect_keys=[[0.1, 0.95], [5.0, 0.9], [15.0, 0.72], [40.0, 0.62], [120.0, 0.66], [420.0, 0.75]],
        torus=0.8, head_lobes=0.8,
        head_color_early=[0.16, 0.09, 0.05], head_color_late=[0.50, 0.47, 0.44], whiten_time=1.0, dark_base=0.7,
        core_glow=3.0, core_radius=0.7, core_cool_s=35.0,
        stem_color=[0.14, 0.10, 0.07], stem_density=3.5, stem_cap_ratio=0.34, stem_radius_m=700.0,
        stem_top_flare=0.0, stem_waist=0.1,
        skirt_color=[0.62, 0.57, 0.50], skirt_fade_s=[60.0, 500.0],
        dust_color=[0.45, 0.36, 0.26], dust_wall=1.2,
        ice_cap={"t_on": 0.25, "dur": 0.6, "opacity": 0.75, "r_rel": 0.9, "lift": -0.05},
        tier2={"t_on": 0.45, "dur": 0.8, "opacity": 0.6, "radius_m": 1300.0, "height_rel": 0.74, "half_m": 350.0},
        frame_phase_s=[0.3, 3.0, 15.0, 60.0],
    ),
    # 10. Little Boy: brief thin banded condensation veil (no grey 'moon egg'), documented slower rise
    # (1.6 km @18 s, 3.4 @42 s, 6.1 @90 s), fat light-grey stem like the Caron photo (never darker than
    # the cap's underside), lobed cap that flattens late, grey-violet cap with a red core and dark base
    # until ~1 min, low black-brown city layer, NW drift.
    "little_boy": dict(
        wilson_opacity=0.1, wilson_thick=0.4, wilson_discs=1.0, wilson_dur_s=0.5, wilson_flatten=0.5,
        fireball_noise_scale=5.0,
        top_keys=[[1.4, 880.0], [5.0, 1050.0], [10.0, 1300.0], [18.0, 1600.0], [42.0, 3400.0], [90.0, 6100.0],
                  [180.0, 9000.0], [600.0, 12500.0]],
        cap_d_keys=[[10.0, 600.0], [20.0, 850.0], [42.0, 1400.0], [90.0, 2300.0], [180.0, 3200.0], [360.0, 4100.0],
                    [600.0, 4500.0]],
        cap_aspect_keys=[[0.1, 0.95], [5.0, 0.9], [20.0, 0.72], [60.0, 0.62], [90.0, 0.6], [240.0, 0.5], [600.0, 0.45]],
        head_lobes=1.0, torus=0.7, head_noise_amp=0.45, wind=[-4.0, -3.0],
        stem_cap_ratio=0.36, stem_radius_m=850.0, stem_density=1.3, stem_color=[0.34, 0.33, 0.33], stem_stretch=1.0,
        stem_top_flare=0.0, stem_speed_rel=1.1,
        head_color_early=[0.38, 0.33, 0.37], head_color_late=[0.85, 0.84, 0.83], whiten_time=0.3,
        dark_base=1.0, core_cool_s=40.0, core_radius=0.4,
        skirt_height=6.0, skirt_color=[0.10, 0.08, 0.07], skirt_fade_s=[120.0, 700.0],
        frame_phase_s=[0.3, 3.0, 15.0, 60.0],
    ),
    # 11. Trinity: pre-dawn twilight (sun below the horizon, the fireball lights the scene), documented
    # slow rise (1.5 km at 26 s, 9.5 km at 10 min, 10.5 km only at 11-12 min -> stabilisation at ~11 min),
    # early vortex ring (~2-7 s), broad boiling red-brown ball over a short broad dark dust stem, dark
    # lumpy skirt, no swirl stroke.
    "trinity": dict(
        tod_hist="predawn",
        t_stab_s=660.0, torus_x0=0.003, torus_dx=0.008,
        top_keys=[[2.0, 330.0], [5.0, 560.0], [10.0, 850.0], [18.0, 1250.0], [26.0, 1500.0], [40.0, 1800.0],
                  [60.0, 2100.0], [120.0, 3300.0], [240.0, 5300.0], [360.0, 6900.0], [480.0, 8200.0],
                  [600.0, 9500.0], [700.0, 10500.0]],
        cap_d_keys=[[5.0, 640.0], [10.0, 800.0], [20.0, 1000.0], [40.0, 1350.0], [90.0, 1900.0], [180.0, 2700.0],
                    [360.0, 3700.0], [700.0, 4500.0]],
        cap_aspect_keys=[[0.1, 0.95], [5.0, 0.95], [20.0, 0.8], [60.0, 0.65], [240.0, 0.55], [700.0, 0.5]],
        stem_color=[0.12, 0.08, 0.05], stem_cap_ratio=0.33, stem_radius_m=450.0, stem_top_flare=0.4,
        stem_density=1.4, stem_fade_s=[100.0, 420.0],
        head_color_late=[0.45, 0.36, 0.30],
        dark_base=0.8, roll=0.3,
        skirt_color=[0.24, 0.19, 0.14], skirt_height=1.5, dust_color=[0.30, 0.24, 0.18],
        frame_phase_s=[0.3, 3.0, 15.0, 60.0],
    ),
    # 12. Baker: documented cloud-top curve (0.64 km column at 0.75 s, ~1.2-1.3 km at 5 s, 2.2-2.3 km at
    # 60 s, cap 1.6 km -> 2.6 km wide), ragged spray at 0.2 s and a ring of grey jets poking through the
    # milky Wilson dome (col_cone crown, faded by 12 s), lumpy light-grey cauliflower turning rain-laden
    # slate, slowly collapsing column (rain curtain to ~90 s), head rained out by ~2.5 min, flat Wilson
    # remnant sheet 2.5-20 s, review camera over the lagoon (no desert in view).
    "baker": dict(
        col_height=900.0, col_rise=2.0, cap_center_k=0.75, cap_aspect=0.45, col_cap_r=600.0, cap_late_grow=1.2,
        head_density=1.4, head_lobes=0.8, cap_appear=4.0,
        col_density=1.5, col_fall=30.0, col_fall_time=60.0, col_fade=60.0, cap_fade=45.0,
        col_cone=0.35, jet_amount=0.6, jet_fade_s=[5.0, 12.0],
        whiten_s=40.0, head_color_early=[0.78, 0.77, 0.74], head_color_late=[0.42, 0.45, 0.48],
        stem_color=[0.70, 0.71, 0.72], stem_stretch=2.5,
        ring_list=[[2.5, 12.0, 500.0, 1800.0, 70.0]],
        near_m=4500.0,
        frame_phase_s=[0.1, 3.0, 12.0, 90.0],
    ),
}
