# Per-bomb explosion profiles: art parameters layered on top of the physics (ExplosionProfile).
# Keys are read by scripts/fx/explosion_profile.gd and scripts/fx/explosion.gd via prof.a(key, default).
# Sizes not listed here come from BlastPhysics formulas (yield + burst type); measured values from
# data/research_values.json (fireball, cloud top, cap, crater) are merged in tools/gen_bombs.py.
# Revision: art-director review cycle 1 (docs/reviews/cycle1_art_review.json).

SOOT = [0.05, 0.045, 0.04]
DIRT = [0.26, 0.21, 0.16]
DUST = [0.40, 0.35, 0.29]
WATER = [0.86, 0.88, 0.90]

PROFILES = {
    # 1. Mk 82: sharp flash, small black-grey dirt crown, fan of fragments, 7 m crater; lumpy drifting thermal (no stem)
    "mk82": dict(
        tod_hist="noon", explosive="aluminized", fb_duration_s=0.5, fb_temp_peak=3300.0, emission=220.0,
        fireball_noise=0.35, fireball_noise_scale=3.0,
        col_height=26.0, col_radius=4.5, col_cone=5.0, col_rise=0.35, col_delay=0.02, col_fall=0.8, col_fall_time=1.5,
        col_density=1.3, col_flare=1.6, col_waist=-0.2, col_cap_r=11.0, cap_aspect=0.7, cap_rise=230.0,
        cap_grow_time=120.0, cap_late_grow=2.5, cap_fade=70.0, cap_hold_peak=True, whiten_s=60.0,
        cap_appear=0.7, cap_center_k=0.72, head_density=0.75,
        head_noise_amp=0.75, head_noise_scale=0.45, billow_sharp=0.8, torus=0.0,
        head_color_early=SOOT, head_color_late=[0.20, 0.18, 0.16], stem_color=[0.20, 0.16, 0.12],
        skirt_color=[0.36, 0.29, 0.21], surge_start=0.03, surge_r=20.0, surge_h0=2.0, surge_h1=6.0, surge_tau=1.5,
        surge_density=0.7, crater=True, crater_time=0.25,
        debris_count=500, debris_speed=55.0, debris_size=0.22, debris_cone=60.0, debris_hot=0.0,
        debris_color=[0.12, 0.10, 0.08], wilson=0.0, dust_wall=0.6, wind=[1.50, -0.50], churn=4.0,
    ),
    # 2. Mk 84: orange ball, black-brown soot column/crown, dust ring, visible shock ring on dry ground
    "mk84": dict(
        tod_hist="noon", explosive="aluminized", fb_duration_s=0.9, fb_temp_peak=3300.0, emission=220.0,
        fireball_noise=0.35, fireball_noise_scale=3.0,
        col_height=48.0, col_radius=8.0, col_cone=4.5, col_rise=0.6, col_delay=0.03, col_fall=1.2, col_fall_time=2.2,
        col_density=1.3, col_flare=1.8, col_waist=-0.2, col_cap_r=22.0, cap_aspect=0.7, cap_rise=380.0,
        cap_grow_time=120.0, cap_late_grow=2.3, cap_fade=90.0, cap_hold_peak=True, whiten_s=80.0,
        cap_appear=1.0, cap_center_k=0.72, head_density=0.8,
        head_noise_amp=0.75, head_noise_scale=0.45, billow_sharp=0.8, torus=0.0,
        head_color_early=SOOT, head_color_late=[0.22, 0.19, 0.16], stem_color=[0.18, 0.14, 0.10],
        skirt_color=[0.40, 0.33, 0.25], surge_start=0.04, surge_r=38.0, surge_h0=3.0, surge_h1=10.0, surge_tau=2.0,
        surge_density=0.75, crater=True, crater_time=0.35,
        debris_count=900, debris_speed=80.0, debris_size=0.3, debris_cone=60.0, debris_hot=0.0,
        debris_color=[0.12, 0.10, 0.08], wilson=0.0, dust_wall=1.0, wind=[1.50, -0.50], churn=4.0,
    ),
    # 3. Tallboy: no fireball; spall ring + ground heave, geyser of soil jets and smoke, camouflet crater, tremor
    "tallboy": dict(
        tod_hist="noon", emission=200.0, dome_r=18.0, dome_h=4.0, dome_time=0.25, dome_burst=0.35,
        col_height=210.0, col_radius=14.0, col_cone=3.2, col_rise=1.4, col_delay=0.32, col_spread=0.6, col_fall=2.6,
        col_fall_time=5.0, col_cap_r=60.0, cap_aspect=0.55, cap_late_grow=1.4, cap_grow_time=60.0, cap_rise=60.0,
        cap_fade=45.0, cap_hold_peak=False, head_density=0.6, head_noise_amp=0.7, col_density=1.1, col_flare=2.2, col_waist=-0.3, whiten_s=60.0, torus=0.0,
        head_color_early=[0.22, 0.18, 0.14], head_color_late=[0.36, 0.32, 0.28], stem_color=[0.22, 0.17, 0.13],
        skirt_color=[0.40, 0.34, 0.27], surge_start=0.03, surge_r=60.0, surge_h0=3.0, surge_h1=12.0, surge_tau=0.6,
        surge_density=0.6, crater=True, crater_time=1.5, debris_count=3500, debris_speed=75.0, debris_size=0.45,
        debris_cone=28.0, debris_delay=0.32, debris_color=[0.18, 0.15, 0.12], wilson=0.0, dust_wall=0.3,
        wind=[1.00, -0.50], churn=2.0,
    ),
    # 4. Grand Slam: deeper and wider, squat crown with big dark jets, dull orange vent flash, volcano-like venting
    "grand_slam": dict(
        tod_hist="noon", emission=350.0, dome_r=20.0, dome_h=7.0, dome_time=0.3, dome_burst=0.35,
        vent_glow=1.0, vent_time=0.30, vent_duration=0.35, vent_radius=12.0, vent_height=8.0,
        col_height=220.0, col_radius=28.0, col_cone=3.0, col_rise=1.6, col_delay=0.38, col_spread=0.7, col_fall=3.0,
        col_fall_time=6.0, col_cap_r=80.0, cap_aspect=0.6, cap_late_grow=1.3, cap_grow_time=80.0, cap_rise=120.0,
        cap_fade=60.0, cap_hold_peak=False, head_density=0.65, col_density=1.2, col_flare=2.6, col_waist=-0.3, col_fade=120.0,
        whiten_s=150.0, torus=0.0, head_noise_amp=0.5,
        head_color_early=[0.20, 0.16, 0.13], head_color_late=[0.36, 0.31, 0.26], stem_color=[0.18, 0.15, 0.12],
        skirt_color=[0.40, 0.34, 0.27], surge_start=0.04, surge_r=75.0, surge_h0=6.0, surge_h1=18.0, surge_tau=0.8,
        surge_density=0.55, crater=True, crater_time=2.0, debris_count=5000, debris_speed=95.0, debris_size=0.6,
        debris_cone=32.0, debris_delay=0.38, debris_color=[0.17, 0.14, 0.11], wilson=0.0, dust_wall=0.35,
        wind=[1.25, -0.50], churn=2.0,
    ),
    # 5. MOAB: low broad pancake of bright orange flame (~2.4 s) + much black smoke, mini-mushroom, wave ring
    "moab": dict(
        tod_hist="noon", explosive="aluminized", fb_duration_s=2.4, fb_temp_peak=3800.0, fireball_squash=0.5,
        emission=260.0, fireball_noise=0.4, fireball_noise_scale=3.5, rise_k=130.0,
        cap_radius_m=420.0, cap_half_m=260.0, t_stab_s=150.0, stem_radius_m=120.0,
        head_color_early=SOOT, head_color_late=[0.20, 0.19, 0.18], stem_color=[0.16, 0.14, 0.12],
        skirt_color=[0.40, 0.34, 0.27], dark_base=0.5, torus=0.8, head_noise_amp=0.55, billow_sharp=0.75,
        skirt=1.0, skirt_max_r=500.0, crater=False, debris_count=600, debris_speed=60.0, debris_size=0.35,
        debris_cone=60.0, debris_color=[0.14, 0.12, 0.10], wilson=0.0, stem_delay=0.6, stem_speed_rel=0.8,
        dust_wall=1.0, core_glow=1.0, wind=[1.50, -1.00], churn=3.0,
    ),
    # 6. Davy Crockett (Little Feller I): white flash, ~17 m ball, dirty small cap drifting NNW
    "davy_crockett": dict(
        tod_hist="dawn", t_stab_s=200.0, stem_radius_m=45.0, torus=0.3, stem_waist=0.1,
        head_color_early=[0.34, 0.19, 0.10], head_color_late=[0.48, 0.41, 0.33], stem_color=[0.42, 0.36, 0.28],
        core_cool_s=1.0, core_glow=0.3, crater=True, crater_time=0.6, debris_count=1200, debris_speed=60.0,
        debris_size=0.3, debris_cone=55.0, debris_color=[0.16, 0.13, 0.10], wilson=0.0, skirt=1.0, dust_wall=1.0,
        wind=[-1.35, -3.25], churn=2.0,
    ),
    # 7. Father of All Bombs: a huge rolling orange fireball ~110 m for 8-9 s, little dust, start of a mushroom
    "foab": dict(
        tod_hist="noon", emission=1500.0, fb_temp_peak=3000.0, fireball_noise=0.5, fireball_noise_scale=2.4,
        rise_k=60.0, rise_delay=6.0,
        cap_radius_m=220.0, cap_half_m=150.0, t_stab_s=110.0, stem_radius_m=55.0,
        head_color_early=[0.05, 0.045, 0.04], head_color_late=[0.12, 0.11, 0.10], whiten_time=5.0,
        stem_color=[0.14, 0.12, 0.10], dark_base=0.4, torus=0.9, skirt=0.4, skirt_max_r=350.0, crater=False,
        debris_count=200, debris_speed=40.0, debris_size=0.3, debris_color=[0.14, 0.12, 0.10], wilson=0.0,
        stem_delay=4.0, stem_density=0.4, dust_wall=0.6, wind=[1.00, -1.00], churn=2.5,
    ),
    # 8. B61-12 (0.3 kt): bright white ~38 m ball, small clean red-brown cap, separate thin dust column
    "b61_12": dict(
        tod_hist="noon", head_color_early=[0.48, 0.23, 0.13], head_color_late=[0.70, 0.68, 0.65], whiten_time=1.5,
        dark_base=0.5, head_noise_amp=0.5, billow_sharp=1.0, torus=0.5, core_cool_s=1.0, core_glow=0.3, skin=1.0,
        stem_detached=True, stem_detached_frac=0.4, stem_radius_m=40.0, stem_color=[0.50, 0.42, 0.32],
        stem_density=0.6, skirt=0.25, wilson=0.8, wilson_duration=0.6, crater=False, dust_wall=0.5,
        wind=[1.00, -1.50], churn=1.5,
    ),
    # 9. Grable: low burst at 160 m: Mach stem, precursor, ragged dusty front, thick near-black dust stem, NE shear
    "grable": dict(
        tod_hist="dawn", precursor=True, head_color_early=[0.34, 0.15, 0.07], head_color_late=[0.55, 0.45, 0.36],
        core_glow=0.5, core_radius=0.22, core_cool_s=13.0, stem_color=[0.13, 0.10, 0.07], stem_density=2.5,
        stem_stretch=1.0, stem_flare=2.4, skirt=1.4, skirt_height=1.6, skirt_color=[0.52, 0.48, 0.42],
        dust_color=[0.52, 0.46, 0.38], dust_wall=1.5, wilson=0.6, crater=False, wind=[3.00, -3.00], churn=1.5,
    ),
    # 10. Little Boy: airburst at 600 m: flash, ~190 m ball, condensation, dark boiling cloud, NW drift
    "little_boy": dict(
        tod_hist="noon", head_color_early=[0.20, 0.11, 0.13], head_color_late=[0.84, 0.82, 0.80], whiten_time=1.0,
        stem_color=[0.30, 0.28, 0.27], stem_density=0.55, skirt=1.5, skirt_height=2.5, skirt_max_r=3000.0,
        skirt_color=[0.16, 0.13, 0.11], dust_color=[0.24, 0.20, 0.17], wilson=1.0, crater=False,
        core_glow=0.6, dark_base=0.7, wind=[-2.00, -2.00], churn=1.5,
    ),
    # 11. Trinity: tower 30 m at dawn: violet-green-white progression, early popcorn skirt, red-brown cloud, trinitite
    "trinity": dict(
        tod_hist="dawn", fireball_tint=[0.55, 0.35, 0.95, 0.5], tint_time=4.0, skirt_early=True, mottle_t2=6.0,
        head_color_early=[0.40, 0.18, 0.09], head_color_late=[0.62, 0.50, 0.42], stem_color=[0.36, 0.27, 0.19],
        skirt=1.3, skirt_height=1.3, trinitite=1.0, crater=True, crater_time=1.0, debris_count=1500,
        debris_speed=70.0, debris_color=[0.16, 0.13, 0.10], wilson=0.0, dust_wall=1.3, core_glow=0.6,
        whiten_time=0.9, wind=[2.00, -2.50], churn=1.5,
    ),
    # 12. Baker: no ball: spray dome, Wilson hemisphere ~1.6 km, hollow 1.8 km column, base surge to 5 km, waves
    "baker": dict(
        tod_hist="noon", humid_site=True, emission=200.0, pond_radius_m=4200.0,
        col_height=1800.0, col_radius=300.0, col_wall=0.3, col_rise=7.0, col_spread=0.15, col_delay=0.02,
        col_fall=14.0, col_fall_time=22.0, col_cap_r=820.0, cap_aspect=0.55, cap_late_grow=0.5,
        cap_grow_time=40.0, cap_rise=900.0, col_density=1.0, col_flare=1.2, col_waist=-0.1,
        whiten_s=1.0, torus=0.0, head_color_early=WATER, head_color_late=[0.80, 0.81, 0.82],
        stem_color=[0.90, 0.92, 0.94], skirt_color=[0.88, 0.89, 0.90],
        surge_start=10.0, surge_r=2500.0, surge_h0=270.0, surge_h1=550.0, surge_tau=70.0, surge_inner=0.55,
        wilson=1.6, wilson_force=True, wilson_start=0.4, wilson_duration=1.6, wilson_flatten=0.9,
        crater=False, debris_count=0, dust_wall=0.0, head_noise_amp=0.4, wind=[1.50, -1.00], churn=1.0,
    ),
    # 13. Sedan: ground dome, venting flash, base surge, dust column without a true cap, 370 x 98 m crater
    "sedan": dict(
        tod_hist="noon", emission=400.0, dome_r=115.0, dome_h=90.0, dome_time=3.0, dome_burst=3.3,
        vent_glow=1.0, vent_time=3.1, vent_duration=1.2, vent_radius=70.0, vent_height=90.0,
        col_height=3700.0, col_radius=420.0, col_cone=1.2, col_rise=28.0, col_spread=0.6, col_delay=3.0,
        col_cap_r=450.0, cap_aspect=0.5, cap_late_grow=0.35, cap_grow_time=60.0, col_density=1.0,
        col_flare=2.0, col_waist=0.05, whiten_s=400.0, torus=0.0, head_noise_amp=0.5, head_noise_scale=0.9,
        head_color_early=[0.17, 0.14, 0.11], head_color_late=[0.30, 0.27, 0.23], stem_color=[0.17, 0.14, 0.11],
        skirt_color=[0.40, 0.35, 0.29], surge_start=4.0, surge_r=4000.0, surge_h0=150.0, surge_h1=420.0,
        surge_tau=45.0, surge_inner=0.3,
        crater=True, crater_time=6.0,
        debris_count=5000, debris_speed=140.0, debris_size=3.0, debris_cone=35.0, debris_color=[0.20, 0.17, 0.13],
        wilson=0.0, dust_wall=0.0, wind=[1.50, -1.50], churn=1.0,
    ),
    # 14. Ivy King: blinding white ~0.65 km ball, cloud to ~23 km piercing the tropopause, NOx brown
    "ivy_king": dict(
        tod_hist="noon", humid_site=True, head_color_early=[0.30, 0.13, 0.06], head_color_late=[0.86, 0.85, 0.85],
        whiten_time=0.5, stem_color=[0.72, 0.70, 0.68], stem_density=0.35, skirt=0.25, wilson=1.0, crater=False,
        cap_d_keys=[[20.0, 1800.0], [60.0, 3400.0], [240.0, 12000.0], [600.0, 27000.0]],
        ice_cap={"t_on": 0.08, "dur": 0.3, "opacity": 0.7}, rings=1, core_cool_s=40.0, wind=[1.50, -1.00],
    ),
    # 15. B83 (conceptual): surface megaton burst: dark dirty stem, huge crater, brown cloud (never white)
    "b83": dict(
        tod_hist="noon", head_color_early=[0.28, 0.15, 0.08], head_color_late=[0.38, 0.31, 0.25], whiten_time=2.0,
        stem_color=[0.16, 0.12, 0.09], stem_density=1.8, stem_flare=2.6, dark_base=0.8, skirt=1.3,
        cap_d_keys=[[60.0, 6000.0], [240.0, 20000.0], [600.0, 35000.0]],
        crater=True, crater_time=8.0, debris_count=3500, debris_speed=180.0, debris_size=4.0,
        debris_color=[0.16, 0.13, 0.10], dust_wall=1.3, rings=1, wind=[2.50, -1.50],
    ),
    # 16. RDS-37: high airburst, giant white ball, stacked condensation discs, thin dark stem, bell skirt
    "rds37": dict(
        tod_hist="dawn", head_color_early=[0.36, 0.14, 0.07], head_color_late=[0.84, 0.83, 0.82],
        stem_color=[0.30, 0.27, 0.25], stem_density=0.45, stem_radius_m=1300.0, skirt=0.3, wilson=0.8, crater=False,
        ring_list=[[2.0, 8.0, 2600.0, 2600.0, 120.0], [3.0, 8.0, 3600.0, 2800.0, 120.0], [40.0, 160.0, 6500.0, 5200.0, 200.0]],
        tier2={"t_on": 0.10, "dur": 0.6, "opacity": 0.45, "radius_m": 9000.0, "height_rel": 0.45, "half_m": 1500.0},
        whiten_time=0.4, core_cool_s=45.0, wind=[1.50, -1.00],
    ),
    # 17. Ivy Mike: gigantic surface burst, ~5.2 km ball, very wide cap, water curtain at the base, reef crater
    "ivy_mike": dict(
        tod_hist="dawn", humid_site=True, fireball_scale=0.84, head_color_early=[0.40, 0.22, 0.12],
        head_color_late=[0.82, 0.80, 0.79], stem_color=[0.50, 0.45, 0.40], stem_density=1.1, skirt=1.2,
        skirt_color=[0.86, 0.87, 0.88],
        cap_d_keys=[[30.0, 7000.0], [60.0, 9000.0], [156.0, 20000.0], [342.0, 40000.0], [600.0, 61000.0], [1800.0, 100000.0]],
        top_keys=[[60.0, 13000.0], [90.0, 17000.0], [156.0, 31000.0], [210.0, 33000.0], [360.0, 37000.0]],
        crater=True, crater_time=12.0, debris_count=2500, debris_speed=250.0, debris_size=10.0,
        debris_color=[0.30, 0.28, 0.25], dust_wall=1.0, rings=3, ring_t0=0.02,
        ice_cap={"t_on": 0.05, "dur": 0.4, "opacity": 0.8}, overshoot=0.08, whiten_time=0.4, core_cool_s=80.0,
        wind=[2.00, -1.00],
    ),
    # 18. Castle Bravo: condensation rings and ice caps, crimson sky, dark 7 km stem (pre-dawn)
    "castle_bravo": dict(
        tod_hist="dawn", humid_site=True, head_color_early=[0.42, 0.20, 0.10], head_color_late=[0.80, 0.78, 0.77],
        stem_color=[0.30, 0.25, 0.21], stem_density=1.2, stem_radius_m=3500.0, skirt=1.2,
        skirt_color=[0.85, 0.85, 0.86],
        ring_list=[[15.0, 40.0, 3500.0, 5000.0, 150.0], [18.0, 40.0, 5000.0, 6000.0, 150.0],
                   [22.0, 45.0, 8500.0, 7000.0, 180.0], [60.0, 90.0, 9700.0, 7000.0, 200.0]],
        cap_d_keys=[[45.0, 9000.0], [60.0, 11600.0], [120.0, 24000.0], [240.0, 44000.0], [522.0, 100000.0], [600.0, 113000.0]],
        top_keys=[[60.0, 14300.0], [120.0, 25000.0], [180.0, 31000.0], [240.0, 34000.0], [300.0, 34700.0], [420.0, 39000.0]],
        crater=True, crater_time=12.0, debris_count=2500, debris_speed=260.0, debris_size=12.0,
        debris_color=[0.30, 0.28, 0.25], dust_wall=1.0, wilson=0.0,
        ice_cap={"t_on": 0.04, "dur": 0.45, "opacity": 0.85},
        tier2={"t_on": 0.12, "dur": 0.7, "opacity": 0.5, "radius_m": 30000.0, "height_rel": 0.5, "half_m": 3000.0},
        overshoot=0.08, whiten_time=0.4, crimson=1.0, core_cool_s=90.0, wind=[2.00, -1.50],
    ),
    # 19. Test 219: Tsar class airburst at 3.75 km, ball pushed up by the reflected shock, polar night, snow
    "test219": dict(
        tod_hist="night", head_color_early=[0.44, 0.26, 0.15], head_color_late=[0.88, 0.88, 0.89],
        stem_color=[0.70, 0.70, 0.72], stem_density=0.4, skirt=0.5, skirt_color=[0.92, 0.93, 0.95],
        crater=False, rings=0, wilson=0.0, reflect_cut_t=6.5,
        cap_d_keys=[[40.0, 13000.0], [60.0, 16000.0], [300.0, 50000.0], [600.0, 72000.0]],
        ice_cap={"t_on": 0.05, "dur": 0.4, "opacity": 0.8},
        tier2={"t_on": 0.15, "dur": 0.9, "opacity": 0.5, "radius_m": 38000.0, "height_rel": 0.62, "half_m": 3500.0},
        overshoot=0.1, whiten_time=0.35, core_cool_s=120.0, wind=[3.00, -1.50],
    ),
    # 20. Tsar Bomba: ~8 km ball pushed off the ground, flash to the horizon, two-tier 95/70 km cap, shock in the sky
    "tsar": dict(
        tod_hist="dawn", fireball_squash=1.0, reflect_cut_t=6.5, head_color_early=[0.46, 0.27, 0.16],
        head_color_late=[0.90, 0.90, 0.91], stem_color=[0.74, 0.74, 0.76], stem_density=0.35, skirt=0.5,
        skirt_color=[0.92, 0.93, 0.95], crater=False, rings=0, wilson=0.0, cap_keep=True, cap_radius_m=35000.0,
        cap_d_keys=[[40.0, 16000.0], [120.0, 32000.0], [360.0, 60000.0], [600.0, 70000.0]],
        ice_cap={"t_on": 0.05, "dur": 0.4, "opacity": 0.8},
        tier2={"t_on": 0.25, "dur": 1.2, "opacity": 0.6, "radius_m": 47500.0, "height_rel": 0.64, "half_m": 4000.0},
        overshoot=0.12, whiten_time=0.35, core_cool_s=150.0, wind=[3.00, -1.50],
    ),
}


# ---------------------------------------------------------------------------------------------
# Revision: art-director review cycle 2 (docs/reviews/cycle2_art_review.json). Per-bomb overrides
# merged over the cycle-1 values above; site_humidity = historical site humidity used by default
# (Pacific shots, Hiroshima), fb_fade_s / head_appear_s = explicit fireball-to-cloud windows (s).
CYCLE2 = {
    "mk82": dict(cap_late_grow=5.0, head_density=0.45, head_color_early=[0.09, 0.085, 0.08],
                 head_color_late=[0.27, 0.25, 0.23], whiten_s=25.0, cap_fade=40.0, col_cone=2.0, col_flare=1.2,
                 col_density=1.0, emission=700.0, fb_temp_peak=3700.0, fireball_noise=0.5,
                 fireball_noise_scale=1.4, col_delay=0.08),
    "mk84": dict(col_delay=0.2, col_radius=6.0, col_cone=1.5, col_height=55.0, cap_appear=0.3,
                 head_color_late=[0.46, 0.41, 0.35], whiten_s=20.0, emission=800.0, fb_temp_peak=3600.0,
                 fireball_noise=0.5, fireball_noise_scale=1.4, cap_late_grow=5.0, head_density=0.5, cap_fade=60.0),
    "tallboy": dict(cap_rise=150.0, cap_late_grow=1.0, cap_aspect=0.85, head_noise_amp=0.85,
                    head_color_late=[0.44, 0.39, 0.33], col_height=110.0, col_rise=2.8, col_cap_r=40.0,
                    col_radius=10.0, surge_start=1.5, site_humidity=0.6),
    "grand_slam": dict(cap_rise=260.0, cap_late_grow=0.9, cap_aspect=0.85, head_color_late=[0.48, 0.42, 0.35],
                       head_color_early=[0.44, 0.42, 0.39], stem_color=[0.13, 0.10, 0.08], col_cap_r=65.0,
                       head_noise_amp=0.85, site_humidity=0.6),
    "moab": dict(head_color_early=[0.30, 0.27, 0.24], head_color_late=[0.74, 0.72, 0.69], whiten_time=0.02,
                 dark_base=0.7, stem_color=[0.45, 0.39, 0.31], rise_k=35.0, rise_delay=2.0, emission=350.0,
                 fireball_squash=0.3, fireball_noise=0.3, fireball_noise_scale=6.0, site_humidity=0.6),
    "davy_crockett": dict(tod_hist="noon", head_color_early=[0.66, 0.62, 0.57], head_color_late=[0.78, 0.76, 0.73],
                          whiten_time=0.05, dark_base=0.6, stem_color=[0.42, 0.36, 0.28], site_humidity=0.25),
    "b61_12": dict(head_noise_amp=0.7, billow_sharp=1.6, head_noise_scale=0.35, cap_aspect_max=0.5),
    "grable": dict(tod_hist="noon", stem_flare=1.7, site_humidity=0.25),
    "little_boy": dict(head_color_early=[0.62, 0.55, 0.55], head_color_late=[0.88, 0.87, 0.86], whiten_time=0.12,
                       dark_base=0.7, core_radius=0.25, core_glow=0.8, core_cool_s=20.0, site_humidity=0.8,
                       wilson_duration=0.7, skirt_height=1.1, skirt_max_r=2200.0),
    "trinity": dict(core_glow=1.5, core_radius=0.6, core_cool_s=30.0, head_noise_amp=0.55, billow_sharp=1.4,
                    head_color_early=[0.42, 0.17, 0.07], roll=0.6, tint_time=1.0, site_humidity=0.45),
    "baker": dict(site_humidity=0.85, cap_appear=3.0, col_rise=5.5),
    "sedan": dict(col_rise=60.0, col_cone=0.25, col_flare=1.3, cap_aspect=0.9, head_noise_scale=0.3,
                  head_noise_amp=0.8, vent_radius=45.0, col_delay=3.4, debris_count=150, site_humidity=0.25, jet_amount=0.15),
    "ivy_king": dict(core_glow=1.4, core_cool_s=90.0, core_radius=0.35, wilson_force=True, site_humidity=0.8),
    "b83": dict(head_noise_amp=0.55, billow_sharp=1.0, head_color_early=[0.26, 0.18, 0.12],
                head_color_late=[0.36, 0.33, 0.30], whiten_time=1.0),
    "rds37": dict(reflect_cut_t=2.5, skirt=0.9, skirt_color=[0.50, 0.43, 0.35], skirt_height=1.5,
                  stem_color=[0.20, 0.16, 0.13], stem_density=0.9, stem_flare=3.0, wilson_force=True),
    "ivy_mike": dict(fireball_noise=0.05, fireball_noise_scale=3.5, mottle_t2=5.0, fb_fade_s=[15.0, 45.0],
                     head_appear_s=[6.0, 25.0], core_cool_s=45.0, site_humidity=0.85),
    "castle_bravo": dict(fb_fade_s=[20.0, 60.0], head_appear_s=[8.0, 30.0], core_cool_s=55.0, site_humidity=0.85,
                         fireball_noise=0.05, fireball_noise_scale=3.5),
    "test219": dict(head_appear_s=[6.0, 25.0], fb_fade_s=[20.0, 55.0], core_cool_s=40.0, fireball_noise=0.05,
                    fireball_noise_scale=3.5,
                    top_keys=[[15.0, 9000.0], [40.0, 25000.0], [90.0, 35000.0], [300.0, 50000.0], [540.0, 53000.0]]),
    "tsar": dict(fireball_noise=0.05, fireball_noise_scale=3.0, head_appear_s=[8.0, 30.0], fb_fade_s=[20.0, 60.0],
                 core_cool_s=60.0, core_radius=0.25, stem_delay=12.0,
                 top_keys=[[18.0, 10500.0], [40.0, 30000.0], [120.0, 42000.0], [480.0, 67000.0], [700.0, 64000.0]],
                 tier2={"t_on": 0.35, "dur": 0.5, "opacity": 0.6, "radius_m": 47500.0, "height_rel": 0.92, "half_m": 2500.0}),
}
# Castle Bravo: early climb keyframes before the measured ones
_bravo = PROFILES.get("castle_bravo", {})
if "top_keys" in _bravo:
    CYCLE2["castle_bravo"]["top_keys"] = [[10.0, 3500.0], [20.0, 7000.0], [40.0, 11000.0]] + [k for k in _bravo["top_keys"] if k[0] > 40.0]
for _k, _v in CYCLE2.items():
    PROFILES.setdefault(_k, {}).update(_v)

# cycle-2 review, severity-2 items (second batch)
CYCLE2B = {
    "moab": dict(stem_density=0.25, stem_radius_m=140.0, stem_flare=2.5, torus=0.3, head_noise_amp=0.7, billow_sharp=1.4),
    "davy_crockett": dict(skirt_height=0.35, core_glow=0.6, core_cool_s=1.0),
    "foab": dict(fireball_squash=0.6, fireball_noise_scale=4.0, head_color_late=[0.20, 0.18, 0.16], whiten_time=1.5,
                 billow_sharp=1.4, dust_wall=0.15, skirt=0.15, skirt_max_r=200.0, stem_density=0.15),
    "b61_12": dict(roll=0.8, stem_stretch=1.0, stem_color=[0.38, 0.32, 0.25], dust_wall=0.2, skirt=0.15,
                   dust_color=[0.50, 0.43, 0.34]),
    "grable": dict(ice_cap={"t_on": 0.25, "dur": 0.6, "opacity": 0.5, "r_rel": 1.05},
                   tier2={"t_on": 0.45, "dur": 0.8, "opacity": 0.4, "radius_m": 1600.0, "height_rel": 0.55, "half_m": 250.0},
                   roll=0.6, wind=[4.0, -4.0]),
    "ivy_king": dict(rings=0, ice_cap={"t_on": 0.08, "dur": 0.07, "opacity": 0.45, "r_rel": 0.8, "lift": 0.0},
                     stem_radius_m=800.0, stem_color=[0.42, 0.28, 0.20], stem_density=0.55, stem_flare=1.8,
                     wilson_start=0.5, wilson_duration=5.0, wilson_flatten=0.5, head_noise_amp=0.5, whiten_time=0.8),
    "rds37": dict(tier2={"t_on": 0.06, "dur": 0.2, "opacity": 0.3, "radius_m": 3000.0, "height_rel": 0.3, "half_m": 600.0},
                  ring_list=[[2.0, 8.0, 2600.0, 2600.0, 120.0], [3.0, 8.0, 3600.0, 2800.0, 120.0], [40.0, 60.0, 6500.0, 1600.0, 80.0]],
                  whiten_time=0.8, head_color_early=[0.32, 0.15, 0.09], head_color_late=[0.70, 0.72, 0.76], core_cool_s=60.0),
    "castle_bravo": dict(tier2={"t_on": 0.15, "dur": 0.25, "opacity": 0.5, "radius_m": 7500.0, "height_rel": 0.18, "half_m": 900.0},
                         ice_cap={"t_on": 0.05, "dur": 0.12, "opacity": 0.85}, stem_color=[0.20, 0.16, 0.13],
                         stem_density=1.6, core_glow=1.2, core_radius=0.25),
    "test219": dict(tier2={"t_on": 0.15, "dur": 0.9, "opacity": 0.5, "radius_m": 36000.0, "height_rel": 0.9, "half_m": 3000.0},
                    cap_d_keys=[[40.0, 13000.0], [60.0, 16000.0], [300.0, 45000.0], [600.0, 55000.0]]),
}
for _k, _v in CYCLE2B.items():
    PROFILES.setdefault(_k, {}).update(_v)

# ---------------------------------------------------------------------------------------------
# Revision: art-director review cycle 3 (docs/reviews/cycle3_art_review.json). Per-bomb-group override
# files tools/profiles_c3/group_*.py each define CYCLE3 = {bomb_id: {key: value}}; merged last.
import glob as _glob
import importlib.util as _ilu
import os as _os

for _f in sorted(_glob.glob(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "profiles_c3", "group_*.py"))):
    _spec = _ilu.spec_from_file_location(_os.path.splitext(_os.path.basename(_f))[0], _f)
    _mod = _ilu.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    for _k, _v in getattr(_mod, "CYCLE3", {}).items():
        PROFILES.setdefault(_k, {}).update(_v)
