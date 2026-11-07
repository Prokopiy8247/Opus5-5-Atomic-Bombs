# Cycle-3 per-bomb overrides, group E (merged by tools/bomb_profiles.py).
# Bombs: 17 Ivy Mike, 18 Castle Bravo, 19 Test No. 219, 20 Tsar Bomba.
# Review: docs/reviews/cycle3_art_review.json. Measured sizes/times (cap_d_keys, top_keys, fireball,
# crater) are left untouched; only looks, colours, visual transition timings and features change.
CYCLE3 = {
    # 17. Ivy Mike: no stacked rings (the auto rings + long ice cap made a 'Dagwood sandwich');
    # a brief Wilson flash over the dome (1-5 s) (thin late pileus sheets rendered as grainy CG discs: dropped),
    # a white cap over a dark red-brown dirty stem, spray curtain at the base, cooling fireball colour.
    "ivy_mike": dict(
        rings=0,
        ice_cap={"t_on": 0.08, "dur": 0.10, "opacity": 0.5, "r_rel": 0.95, "lift": 0.0},
        wilson=1.5, wilson_dur_s=4.0, wilson_start=2.0, wilson_flatten=0.55, wilson_hum_min=0.85,
        fb_cool_s=[12.0, 40.0], mottle_t2=8.0, fireball_brightness=1.6,
        stem_color=[0.30, 0.20, 0.14], stem_density=1.6, head_color_early=[0.72, 0.58, 0.50],
        whiten_time=0.10, dark_base=0.6,
        skirt_max_r=6000.0, skirt_height=2.5, skirt_fade_s=[60.0, 150.0],
        frame_phase_s=[1.0, 30.0, 60.0, 150.0, 500.0],
    ),
    # 18. Castle Bravo: thin stacked condensation discs that fade before the rising head crosses them
    # (no jumps), boiling yellow fireball held to ~60 s with a long-glowing core, trumpet-flared stem
    # top (no bulbous tip in the cap hollow). The flat tier2 lens and ring 4 read as a cotton donut / CD
    # around the stem in every variant tried (code has no hollow bell primitive yet): dropped.
    "castle_bravo": dict(
        ring_list=[[12.0, 16.0, 3200.0, 4500.0, 60.0], [16.0, 20.0, 5000.0, 5500.0, 60.0],
                   [20.0, 25.0, 8500.0, 7000.0, 70.0]],
        fb_fade_s=[28.0, 65.0], head_appear_s=[12.0, 40.0], core_cool_s=150.0, core_radius=0.6,
        core_glow=2.0, fireball_brightness=1.5,
        tier2={},
        stem_top_flare=1.5,
        skirt_max_r=7000.0, skirt_height=2.0, skirt_fade_s=[60.0, 180.0],
        frame_phase_s=[1.0, 30.0, 60.0, 150.0, 500.0],
    ),
    # 19. Test 219: a fireball phase framed on its own, colour cooling white->yellow->orange, a pale
    # thin stem inside a dark silhouette, an optically thick wide upper tier (72/55 km), snow-dust ring.
    "test219": dict(
        frame_phase_s=[1.0, 25.0, 60.0, 150.0, 500.0], near_m=60000.0,
        fb_cool_s=[5.0, 30.0], fireball_brightness=1.2, fb_fade_s=[28.0, 65.0], head_appear_s=[15.0, 40.0],
        core_cool_s=100.0, core_glow=1.4, core_radius=0.5,
        stem_color=[0.25, 0.26, 0.30], stem_density=0.22,
        tier2={"t_on": 0.28, "dur": 0.6, "opacity": 0.95, "radius_m": 36000.0, "height_rel": 0.92, "half_m": 1800.0},
        cap_aspect_keys=[[1.0, 0.75], [120.0, 0.75], [300.0, 0.40], [600.0, 0.28]],
        skirt=1.0, skirt_height=0.6, dust_wall=1.0,
    ),
    # 20. Tsar Bomba: fireball phase framed on its own, glowing red-orange toroidal dome at 40 s, the
    # shock wave visible in the (humid, overcast) sky, a broad grey stem, a sheared wide upper tier.
    "tsar": dict(
        frame_phase_s=[1.0, 25.0, 60.0, 150.0, 500.0], near_m=70000.0,
        fb_fade_s=[30.0, 70.0], core_cool_s=90.0, core_radius=0.5, core_glow=1.6,
        head_color_early=[0.55, 0.25, 0.12], fb_cool_s=[5.0, 40.0], fireball_brightness=2.0, whiten_time=0.15,
        stem_radius_m=6000.0, stem_color=[0.50, 0.50, 0.55], stem_density=0.2, stem_flare=1.4,
        tier2={"t_on": 0.35, "dur": 0.5, "opacity": 0.5, "radius_m": 47500.0, "height_rel": 0.92, "half_m": 3500.0},
        cap_aspect_keys=[[1.0, 0.75], [120.0, 0.75], [360.0, 0.40], [600.0, 0.30]],
        skirt_max_r=12000.0, site_humidity=0.7, shock_condensation=2.5,
    ),
}
