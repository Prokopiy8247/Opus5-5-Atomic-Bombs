# Per-bomb explosion profiles: art parameters layered on top of the physics (ExplosionProfile).
# Keys are read by scripts/fx/explosion_profile.gd and scripts/fx/explosion.gd via prof.a(key, default).
# Sizes not listed here come from BlastPhysics formulas (yield + burst type).

SOOT = [0.07, 0.065, 0.06]
DIRT = [0.30, 0.24, 0.18]
DUST = [0.48, 0.42, 0.35]
WATER = [0.86, 0.88, 0.90]

PROFILES = {
    # 1. Mk 82: sharp flash, small black-grey dirt cloud, fan of fragments, 5-8 m crater
    "mk82": dict(
        explosive="aluminized", fireball_scale=1.6, emission=220.0, fireball_noise=0.35, fireball_noise_scale=3.0,
        cloud_top_m=90.0, cap_radius_m=22.0, cap_half_m=20.0, t_stab_s=25.0, stem_radius_m=12.0,
        head_color_early=SOOT, head_color_late=[0.32, 0.29, 0.26], stem_color=DIRT, skirt_color=DUST,
        dark_base=0.3, torus=0.0, head_noise_amp=0.7, head_noise_scale=0.8, billow_sharp=0.8, skirt=0.8, skirt_max_r=40.0,
        stem_density=0.55, stem_flare=2.6, stem_waist=-0.3,
        crater=True, crater_scale=1.5, crater_time=0.25, debris_count=1800, debris_speed=90.0, debris_size=0.18,
        debris_cone=75.0, debris_hot=0.8, wilson=0.4, stem_delay=0.05, stem_speed_rel=1.0, dust_wall=0.8,
    ),
    # 2. Mk 84: orange ball, black-brown column, dust ring, visible shock ring on dry ground
    "mk84": dict(
        explosive="aluminized", fireball_scale=2.4, emission=220.0, fireball_noise=0.35, fireball_noise_scale=3.0,
        cloud_top_m=260.0, cap_radius_m=55.0, cap_half_m=48.0, t_stab_s=45.0, stem_radius_m=26.0,
        head_color_early=[0.09, 0.07, 0.06], head_color_late=[0.30, 0.26, 0.22], stem_color=[0.22, 0.17, 0.12],
        skirt_color=DUST, dark_base=0.4, torus=0.1, head_noise_amp=0.65, head_noise_scale=0.8, billow_sharp=0.8,
        stem_density=0.7, stem_flare=2.4, stem_waist=-0.3,
        skirt=1.0, skirt_max_r=110.0, crater=True, crater_scale=2.0, crater_time=0.35,
        debris_count=2600, debris_speed=110.0, debris_size=0.3, debris_cone=70.0, debris_hot=0.7,
        wilson=0.5, stem_delay=0.05, stem_speed_rel=1.0, dust_wall=1.0,
    ),
    # 3. Tallboy: no fireball, ground heave, geyser of soil and smoke, camouflet crater, tremor
    "tallboy": dict(
        emission=200.0, dome_r=28.0, dome_h=5.0, dome_time=0.12, dome_burst=0.25,
        col_height=210.0, col_radius=14.0, col_cone=3.2, col_rise=1.4, col_spread=0.6, col_fall=2.6, col_fall_time=5.0,
        col_cap_r=50.0, cap_aspect=0.6, cap_late_grow=1.6, cap_grow_time=10.0, col_density=1.1,
        col_flare=2.2, col_waist=-0.3, whiten_s=40.0, torus=0.0,
        head_color_early=[0.25, 0.20, 0.15], head_color_late=[0.42, 0.37, 0.32], stem_color=[0.26, 0.20, 0.15],
        skirt_color=[0.45, 0.39, 0.32], surge_start=1.8, surge_r=160.0, surge_h0=12.0, surge_h1=28.0, surge_tau=6.0,
        crater=True, crater_r_m=15.0, crater_depth_m=9.0, crater_time=1.5,
        debris_count=4500, debris_speed=75.0, debris_size=0.45, debris_cone=28.0, wilson=0.0, dust_wall=0.3,
    ),
    # 4. Grand Slam: deeper and wider, volcano-like venting, moderate orange flash
    "grand_slam": dict(
        emission=220.0, dome_r=38.0, dome_h=8.0, dome_time=0.15, dome_burst=0.3,
        vent_glow=1.0, vent_time=0.18, vent_duration=0.8, vent_radius=22.0, vent_height=25.0,
        col_height=320.0, col_radius=20.0, col_cone=3.0, col_rise=1.8, col_spread=0.6, col_fall=3.4, col_fall_time=7.0,
        col_cap_r=75.0, cap_aspect=0.6, cap_late_grow=1.6, cap_grow_time=14.0, col_density=1.1,
        col_flare=2.4, col_waist=-0.3, col_fade=90.0, whiten_s=60.0, torus=0.0,
        head_color_early=[0.22, 0.17, 0.13], head_color_late=[0.40, 0.36, 0.33], stem_color=[0.22, 0.18, 0.15],
        skirt_color=[0.44, 0.38, 0.31], surge_start=2.2, surge_r=230.0, surge_h0=16.0, surge_h1=40.0, surge_tau=8.0,
        crater=True, crater_r_m=19.0, crater_depth_m=10.0, crater_time=2.0,
        debris_count=6000, debris_speed=95.0, debris_size=0.6, debris_cone=30.0, wilson=0.0, dust_wall=0.35,
    ),
    # 5. MOAB: bright orange flame + lots of black smoke, mini-mushroom, visible wave ring, condensation
    "moab": dict(
        explosive="aluminized", fireball_scale=2.6, emission=260.0, fireball_noise=0.4, fireball_noise_scale=3.5,
        cloud_top_m=1800.0, cap_radius_m=420.0, cap_half_m=260.0, t_stab_s=150.0, stem_radius_m=120.0,
        head_color_early=[0.06, 0.05, 0.05], head_color_late=[0.28, 0.26, 0.25], stem_color=[0.20, 0.17, 0.14],
        skirt_color=DUST, dark_base=0.5, torus=0.8, head_noise_amp=0.55, billow_sharp=0.75, skirt=1.0, skirt_max_r=500.0,
        crater=False, debris_count=1200, debris_speed=70.0, debris_size=0.35, debris_cone=60.0,
        wilson=1.0, stem_delay=0.4, stem_speed_rel=0.8, dust_wall=1.0, core_glow=1.0,
    ),
    # 6. Davy Crockett (Little Feller I): white flash, ~15 m ball, dirty small cap
    "davy_crockett": dict(
        cloud_top_m=1800.0, cap_radius_m=420.0, cap_half_m=300.0, t_stab_s=200.0, stem_radius_m=110.0,
        head_color_early=[0.36, 0.20, 0.10], head_color_late=[0.50, 0.42, 0.34], stem_color=[0.30, 0.23, 0.16],
        crater=True, crater_scale=0.6, crater_time=0.6, debris_count=2000, debris_speed=60.0, debris_size=0.3,
        debris_cone=55.0, wilson=0.3, skirt=1.0, dust_wall=1.0,
    ),
    # 7. Father of All Bombs: rolling orange fireball ~110 m for 8-9 s, little dust, start of a mushroom
    "foab": dict(
        emission=200.0, fireball_noise=0.5, fireball_noise_scale=2.4,
        cloud_top_m=1300.0, cap_radius_m=220.0, cap_half_m=150.0, t_stab_s=110.0, stem_radius_m=55.0,
        head_color_early=[0.10, 0.07, 0.05], head_color_late=[0.32, 0.29, 0.26], stem_color=[0.30, 0.26, 0.22],
        dark_base=0.4, torus=0.9, skirt=0.4, skirt_max_r=350.0, crater=False, debris_count=300,
        debris_speed=40.0, debris_size=0.3, wilson=0.6, stem_delay=2.0, stem_density=0.4, dust_wall=0.6,
    ),
    # 8. B61-12 (0.3 kt): bright white ~40 m ball, small clean 1.5-2 km cloud, Wilson dome
    "b61_12": dict(
        head_color_early=[0.40, 0.24, 0.14], head_color_late=[0.80, 0.78, 0.76], stem_color=[0.50, 0.44, 0.38],
        stem_density=0.25, skirt=0.25, wilson=1.3, wilson_duration=1.2, crater=False, dust_wall=0.5,
    ),
    # 9. Little Boy: airburst at 580 m, dark boiling cloud, condensation on the shock
    "little_boy": dict(
        head_color_early=[0.30, 0.15, 0.07], head_color_late=[0.46, 0.41, 0.37], stem_color=[0.34, 0.28, 0.22],
        stem_density=0.55, skirt=0.45, wilson=1.0, crater=False, core_glow=1.2, dark_base=0.7,
    ),
    # 10. Grable: low burst at 160 m: Mach stem, precursor, ragged dusty front, dark stem
    "grable": dict(
        fireball_scale=0.78, precursor=True, head_color_early=[0.34, 0.17, 0.08], head_color_late=[0.55, 0.45, 0.36],
        stem_color=[0.20, 0.15, 0.11], stem_density=1.2, stem_flare=2.4, skirt=1.4, skirt_height=1.6,
        skirt_color=[0.70, 0.66, 0.60], dust_color=[0.66, 0.60, 0.52], dust_wall=1.5, wilson=0.6,
        crater=False, core_glow=1.4,
    ),
    # 11. Trinity: tower 30 m at dawn: purple-green-white progression, dust skirt, red-brown 3-layer cloud, trinitite
    "trinity": dict(
        fireball_tint=[0.85, 0.75, 1.15, 0.45], tint_time=6.0, head_color_early=[0.40, 0.18, 0.09],
        head_color_late=[0.62, 0.50, 0.42], stem_color=[0.36, 0.27, 0.19], skirt=1.3, skirt_height=1.3,
        trinitite=1.0, crater=True, crater_r_m=40.0, crater_depth_m=2.0, crater_time=1.0,
        debris_count=1500, debris_speed=70.0, wilson=0.2, dust_wall=1.3, core_glow=1.3, whiten_time=0.9,
    ),
    # 12. Baker: no ball: spray dome, Wilson hemisphere ~1.6 km, hollow 1.8 km column, base surge to 5 km, waves
    "baker": dict(
        emission=200.0, pond_radius_m=4200.0,
        col_height=1800.0, col_radius=300.0, col_wall=0.3, col_rise=7.0, col_spread=0.15, col_delay=0.02,
        col_fall=14.0, col_fall_time=22.0, col_cap_r=820.0, cap_aspect=0.55, cap_late_grow=0.5,
        cap_grow_time=40.0, cap_rise=900.0, col_density=1.0, col_flare=1.2, col_waist=-0.1,
        whiten_s=1.0, torus=0.0, head_color_early=WATER, head_color_late=[0.80, 0.81, 0.82],
        stem_color=[0.90, 0.92, 0.94], skirt_color=[0.88, 0.89, 0.90],
        surge_start=10.0, surge_r=2500.0, surge_h0=270.0, surge_h1=550.0, surge_tau=70.0, surge_inner=0.55,
        wilson=1.6, wilson_start=0.4, wilson_duration=1.6, wilson_flatten=0.9,
        crater=False, debris_count=0, dust_wall=0.0, head_noise_amp=0.4,
    ),
    # 13. Sedan: ground dome, venting flash, base surge, dust column without a true cap, 390 x 100 m crater
    "sedan": dict(
        emission=400.0, dome_r=115.0, dome_h=90.0, dome_time=3.0, dome_burst=3.3,
        vent_glow=1.0, vent_time=3.1, vent_duration=1.2, vent_radius=70.0, vent_height=90.0,
        col_height=3700.0, col_radius=320.0, col_cone=1.2, col_rise=28.0, col_spread=0.6, col_delay=3.0,
        col_cap_r=950.0, cap_aspect=0.9, cap_late_grow=0.6, cap_grow_time=60.0, col_density=1.0,
        col_flare=2.0, col_waist=-0.2, whiten_s=400.0, torus=0.0,
        head_color_early=[0.30, 0.25, 0.20], head_color_late=[0.42, 0.37, 0.31], stem_color=[0.30, 0.25, 0.20],
        skirt_color=[0.44, 0.39, 0.33], surge_start=4.0, surge_r=4000.0, surge_h0=150.0, surge_h1=420.0,
        surge_tau=45.0, surge_inner=0.3,
        crater=True, crater_r_m=195.0, crater_depth_m=98.0, crater_time=6.0,
        debris_count=5000, debris_speed=140.0, debris_size=3.0, debris_cone=35.0, wilson=0.0, dust_wall=0.0,
    ),
    # 14. Ivy King: blinding white ~0.7 km ball, 20+ km cloud piercing the tropopause (Pacific, moist)
    "ivy_king": dict(
        head_color_early=[0.42, 0.24, 0.14], head_color_late=[0.86, 0.85, 0.85], stem_color=[0.72, 0.70, 0.68],
        stem_density=0.35, skirt=0.25, wilson=1.0, crater=False, ice_cap={"t_on": 0.08, "dur": 0.45, "opacity": 0.7},
        rings=1, whiten_time=0.35,
    ),
    # 15. B83 (conceptual): surface megaton burst: dark dirty stem, huge crater, brown cloud
    "b83": dict(
        head_color_early=[0.32, 0.18, 0.10], head_color_late=[0.55, 0.47, 0.40], stem_color=[0.24, 0.18, 0.13],
        stem_density=1.3, stem_flare=2.6, skirt=1.3, crater=True, crater_time=8.0, debris_count=3500,
        debris_speed=180.0, debris_size=4.0, dust_wall=1.3, rings=1, whiten_time=0.8,
    ),
    # 16. RDS-37: high airburst, giant white ball, condensation ring on the stem, transparent skirt
    "rds37": dict(
        head_color_early=[0.40, 0.24, 0.14], head_color_late=[0.84, 0.83, 0.82], stem_color=[0.62, 0.58, 0.54],
        stem_density=0.35, skirt=0.3, wilson=0.8, crater=False, rings=2,
        tier2={"t_on": 0.10, "dur": 0.6, "opacity": 0.45, "radius_m": 9000.0, "height_rel": 0.45, "half_m": 1500.0},
        whiten_time=0.4,
    ),
    # 17. Ivy Mike: gigantic surface burst, ~5 km ball, very wide cap, water curtain, crater in the reef
    "ivy_mike": dict(
        fireball_scale=0.84, head_color_early=[0.40, 0.22, 0.12], head_color_late=[0.82, 0.80, 0.79],
        stem_color=[0.50, 0.45, 0.40], stem_density=1.1, skirt=1.2, skirt_color=[0.86, 0.87, 0.88],
        crater=True, crater_r_m=950.0, crater_depth_m=50.0, crater_time=12.0, debris_count=2500,
        debris_speed=250.0, debris_size=10.0, dust_wall=1.0, rings=3, wilson=0.7,
        ice_cap={"t_on": 0.05, "dur": 0.5, "opacity": 0.8}, overshoot=0.08, whiten_time=0.4,
    ),
    # 18. Castle Bravo: condensation rings and ice caps, crimson sky, dark 7 km stem
    "castle_bravo": dict(
        head_color_early=[0.42, 0.20, 0.10], head_color_late=[0.80, 0.78, 0.77], stem_color=[0.30, 0.25, 0.21],
        stem_density=1.2, stem_radius_m=3500.0, skirt=1.2, skirt_color=[0.85, 0.85, 0.86],
        crater=True, crater_r_m=1000.0, crater_depth_m=76.0, crater_time=12.0, debris_count=2500,
        debris_speed=260.0, debris_size=12.0, dust_wall=1.0, rings=4, wilson=0.8,
        ice_cap={"t_on": 0.04, "dur": 0.55, "opacity": 0.85},
        tier2={"t_on": 0.12, "dur": 0.7, "opacity": 0.5, "radius_m": 30000.0, "height_rel": 0.5, "half_m": 3000.0},
        overshoot=0.08, whiten_time=0.4, crimson=1.0,
    ),
    # 19. Test 219: Tsar class airburst at 3.75 km, ball near the ground, winter scene
    "test219": dict(
        head_color_early=[0.44, 0.26, 0.15], head_color_late=[0.88, 0.88, 0.89], stem_color=[0.70, 0.70, 0.72],
        stem_density=0.4, skirt=0.5, skirt_color=[0.92, 0.93, 0.95], crater=False, rings=2, wilson=0.5,
        ice_cap={"t_on": 0.05, "dur": 0.5, "opacity": 0.8},
        tier2={"t_on": 0.15, "dur": 0.9, "opacity": 0.5, "radius_m": 38000.0, "height_rel": 0.62, "half_m": 3500.0},
        overshoot=0.1, whiten_time=0.35,
    ),
    # 20. Tsar Bomba: ~8 km ball, flash to the horizon, two-tier 95/70 km cap, shock visible in the sky
    "tsar": dict(
        fireball_squash=1.15, head_color_early=[0.46, 0.27, 0.16], head_color_late=[0.90, 0.90, 0.91],
        stem_color=[0.74, 0.74, 0.76], stem_density=0.35, skirt=0.5, skirt_color=[0.92, 0.93, 0.95],
        crater=False, rings=2, wilson=0.4,
        ice_cap={"t_on": 0.05, "dur": 0.5, "opacity": 0.8},
        tier2={"t_on": 0.15, "dur": 1.0, "opacity": 0.55, "radius_m": 47500.0, "height_rel": 0.64, "half_m": 4000.0},
        overshoot=0.12, whiten_time=0.35,
    ),
}
