# RESEARCH NOTES: Atomic Bombs

Compiled 2026-11-07 by the merge agent from the nine research parts in `docs/research_parts/`. Each part keeps its full tables, every URL and long stage-by-stage descriptions. This file is the **consolidated and de-conflicted** version that code, data and UI text should follow. Where this file and a research part disagree, **this file wins**; the cross-part conflicts that the merge resolved are listed in §0.4.

Format of every fact: **fact → source/URL → how it is used in the game**.
Status labels: **MEASURED** (instrument, survey, official record or direct photo/film evidence), **ESTIMATED** (scaling, formula, eyewitness estimate or single soft source), **DISPUTED → resolved** (sources disagree; the game value is the stated resolution), **CLAIMED** (asserted by one party only), **DESIGN** (no source exists; a game decision).
Scope: public historical, visual and effects data only (yield, burst geometry, fireball, cloud, crater, timings, outer dimensions, mass, paint). No weapon-design information was collected.

| Research part | Content |
|---|---|
| `research_parts/bombs_01_03.md` | Mk 82, Mk 84, Tallboy; TNT-equivalence of tritonal/Torpex; HE fireball, crater and cloud-rise data (OP 1172, Church 1969) |
| `research_parts/bombs_04_06.md` | Grand Slam, GBU-43/B MOAB, W54 / Little Feller I; BLU-82 backup |
| `research_parts/bombs_07_09.md` | "Father of All Bombs" (ATBIP), B61-12 at 0.3 kt, Little Boy |
| `research_parts/bombs_10_11.md` | Upshot-Knothole Grable, Trinity (Taylor/Mack radius-time table, DASA-1251 cloud curves) |
| `research_parts/bombs_12_13.md` | Crossroads Baker (wave and base-surge photogrammetry), Plowshare Sedan |
| `research_parts/bombs_14_16.md` | Ivy King, B83 (model), RDS-37 (VNIIEF 1997 official history) |
| `research_parts/bombs_17_18.md` | Ivy Mike, Castle Bravo (Castle Project 9.1 cloud photogrammetry) |
| `research_parts/bombs_19_20.md` | Test No. 219, Tsar Bomba |
| `research_parts/techniques_and_physics.md` | Part A: audit of every formula in `02_PHYSICS_REFERENCE.md` (A1–A10, unit-test values). Part B: Godot 4.7 recipes (B0–B12) with API checks |

---

## 0. Merge decisions (read first)

### 0.1 Final yield ladder: 20 bombs in strictly ascending yield

`data/bombs.json` (state at 06:48) contained two ties: Little Boy = Grable = 15 kt and Trinity = Baker = 21 kt. Both are removed below.

| Game order | id (refs folder) | Yield used | Dossier said | Change and reason |
|---|---|---|---|---|
| 1 | mk82 (`01_mk82`) | 0.10 t | ≈0.1 t | Confirmed: 87 kg tritonal × RE 1.15 = 100 kg |
| 2 | mk84 (`02_mk84`) | 0.50 t | ≈0.5 t | Confirmed: 429 kg × 1.15 = 493 kg |
| 3 | tallboy (`03_tallboy`) | 3.1 t | ≈3 t | Torpex D1 2,359 kg × RE 1.30 |
| 4 | grand_slam (`04_grand_slam`) | **5.6 t** | ≈6.6 t | Same RE 1.30 as Tallboy (4,300 kg × 1.30). The published "6.5 long tons" assumes RE ≈1.5; UI may say "≈5,6 т (опубликовано до 6,5 т)" |
| 5 | moab (`05_moab`) | 11 t | 11 t | Confirmed (8,500 kg H-6) |
| 6 | davy_crockett (`06_davy_crockett`) | 18 t | 18–20 t | 18 t (Sublette, Wikipedia). DOE/NV-209 says only "Low"; 20 t is the nominal W54 Mod 2 yield |
| 7 | foab (`07_foab`) | 44 t (claimed) | 44 t | Kept with the badge «заявлено, не подтверждено» |
| 8 | b61_12 (`08_b61_12`) | 0.3 kt | ≈0.3 kt | Non-official estimate; badge «условная модель» |
| **9** | **grable** (`10_grable`) | 15 kt | 15 kt | Official DOE value; no alternative estimate exists |
| **10** | **little_boy** (`09_little_boy`) | **16 kt** | 15 kt | DS02 (US–Japan dosimetry system 2002, adopted by RERF) value. Needed to break the tie with Grable; the fireball changes by 2.6 %. UI «≈16 кт (оценки 12–18 кт)» |
| 11 | trinity (`11_trinity`) | 21 kt | ≈21 kt | Official DOE value; UI adds "LANL 2021: 24.8 ± 2 kt" |
| 12 | baker (`12_baker`) | **23 kt** | 21–23 kt | Official 23 kt (DASA-1251, Wikipedia, NWA); 21 kt is an early caption figure |
| 13 | sedan (`13_sedan`) | 104 kt | 104 kt | Confirmed |
| 14 | ivy_king (`14_ivy_king`) | 500 kt | 500 (to 550) | "550 ± 20 kt" not found in any source; dropped |
| 15 | b83 (`15_b83`) | 1,200 kt | 1.2 Mt | Model (never detonated in the atmosphere) |
| 16 | rds37 (`16_rds37`) | 1,600 kt | 1.6 Mt | Confirmed (VNIIEF 1997 p. 235) |
| 17 | ivy_mike (`17_ivy_mike`) | 10,400 kt | 10.4 Mt | Confirmed |
| 18 | castle_bravo (`18_castle_bravo`) | 15,000 kt | 15 (±5) Mt | Fireball yield 14.8 ± 0.2 Mt; "±5" unsupported |
| 19 | test219 (`19_test219`) | 24,200 kt | 24.2 Mt | Official catalogue; US 1963 estimate 26 Mt, Western ≈20 Mt |
| 20 | tsar (`20_tsar_bomba`) | 50,000 kt | 50 Mt | Official; Western/early estimates 57–58 Mt in UI |

The refs folder numbers (`09_little_boy`, `10_grable`) are identifiers only; no folder was renamed. The only alternative to swapping 9 and 10 would be to quote Little Boy below 15 kt (e.g. the 1945 Penney 12 kt), which would cherry-pick an outdated estimate. **Recommendation: swap the display order of Grable and Little Boy and log it in `DECISIONS.md`.**

### 0.2 `data/bombs.json` action items (current file vs. research)

| id | Field | Now | Research value | Source |
|---|---|---|---|---|
| mk82 | burst_height_m | 1.0 | −0.7 (short-delay fuze, charge centre just below the surface; a pure contact fuze would be 0) | OP 1172, §2.1 |
| mk82 | charge_kg | 89 | 87 (89 in the Wikipedia infobox; 87 in the body text and Tritonal article) | §2.1 |
| mk84 | length_m | 3.84 | **3.28** | FAS, GlobalSecurity, USAF caption |
| mk84 | burst_height_m | 1.5 | −1.2 | §2.2 |
| grand_slam | yield_kt / charge_kg / length / mass / HOB | 0.0066 / 4200 / 7.7 / 10000 / −25 | **0.0056** / 4300 / 7.8 / 10160 / **−20** | §0.1, §2.4 |
| moab | burst_height_m | 6.0 | **2.0** | Business Insider estimate, 2003 video |
| moab | mass_kg | 9800 | 9850 | Wikipedia, AF Armament Museum |
| davy_crockett | burst_height_m | 3.0 | **0.9** | DOE/NV-209, DOE/NV-1200, DNA 6027F |
| b61_12 | burst_height_m / length_m | 100 / 3.6 | **150** / 3.66 | §2.8 |
| little_boy | yield_kt / burst_height_m / order | 15 / 580 / 9th | **16 / 600 / 10th** | DS02, RERF |
| grable | order | 10th | **9th** | §0.1 |
| baker | yield_kt | 21 | **23** | DASA-1251 |
| ivy_mike | burst_height_m | 10 | 5 (cosmetic; no published HOB) | §2.17 |
| all | blurb | — | use the RU/EN blurbs in §2 | §2 |

### 0.3 Replacement evaluation

No research part recommended replacing a bomb. The merge checked each weak point against the rule (20 bombs, strictly ascending yield; options BLU-82, Castle Yankee, Operation Snowball, Hardtack II Eddy/Quay):

- **FOAB (#7)** is the least documented (Russian claim only, no free imagery). The only option that fits its slot is Hardtack II Eddy (83 t, 18 t < 83 t < 300 t), but Eddy is a small Nevada airburst that would look like a smaller copy of the B61-12 model (#8). FOAB is the only thermobaric event, so it adds a distinct look. **Keep FOAB** with the «заявлено» badge; Eddy stays the fallback.
- **MOAB (#5)** is well documented (PD USAF video). The BLU-82's "6.8 t" is its mass; its TNT equivalent (≈5.7–6.8 t, ESTIMATED) would collide with Grand Slam (5.6 t). **Keep MOAB.**
- **B83 (#15)** and **B61-12 (#8)** never exploded, and **Test 219 (#19)** has no imagery. They are honest labelled models from the original dossier. Castle Yankee (13.5 Mt) cannot replace Test 219 because it would fall below Bravo (15 Mt). Operation Snowball (500 t) has no free slot: 300 t < 500 t < 15 kt would need a 21st bomb. **Keep all three** with their UI badges.
- **Conclusion: keep all 20 bombs.** Only the order of #9/#10 changes (§0.1).

### 0.4 Cross-part conflicts resolved by the merge

1. **Torpex RE.** Part 01–03 used RE 1.30; part 04 used ≈1.5. Both bombs use the same explosive, so the merge uses **1.30 for both**: Tallboy 3.1 t, Grand Slam 5.6 t.
2. **Little Boy/Grable tie.** Resolved with DS02 16 kt and a swapped order (§0.1).
3. **Time of the first thermal minimum, t_min.** Three formulas were in play: `02` gives 0.0022·W^0.5 s, the techniques part 3.5·W^0.4 ms (Glasstone & Dolan 1977 text) and part 10–11 0.0036·W^0.5 s. Measured values are Grable 13.3–14.9 ms at 15 kt, Upshot-Knothole Badger 16.8–19.2 ms at 23 kt (both DASA-1251) and Trinity ≈16 ms at 21 kt (LA-6300-H). **Merge: t_min = 4.5·W^0.4 ms** (DERIVED). It gives 13.3 / 15.2 / 15.8 ms at 15 / 21 / 23 kt, inside the Small & Brode band of 3.8·W^0.4 ms ± 35 %. This is ≤1 frame at kiloton yields and matters only for megatons (Tsar 0.34 s).
4. **Tsar "560 ms / 7 s" pulse timings are not measurements.** The NWA page (checked 2026-11-07) obtains them by scaling the 20 kt values (10 ms, 140 ms) by W^0.5; they are not Speedlight data. Status → ESTIMATED. Use the Glasstone & Dolan eq. 7.85.1 fit, t₂ = 0.0417·W^0.44 s: **Tsar 4.9 s, Test 219 3.5 s.** Part 19–20 had 6 s and 4.5 s (midpoints with the old formula).
5. **Cloud top ×0.82 for "dry mid-latitude" (techniques part).** Measured Nevada/New Mexico summer shots rose *higher* than the humid Miller values: Grable 9.7 km against 8.1 (×0.82 → 6.6), Trinity 10.5 km against 9.4 (→ 7.7), Little Feller I 1.8 km against ≈0.73 (→ 0.6). **Apply ×0.82 only to megaton yields at mid/high latitude (tropopause-limited); otherwise use the measured per-bomb overrides in §1.**
6. **Growth of megaton fireballs.** The techniques part fills the fireball after breakaway with an exponential of time constant t(R_max)/3 ≈ 3.3·t₂. That is too slow for the observed megaton fireballs: Bravo was ≈6 km wide at 3.5 s (photo, max ≈7 km), Mike ≈5.2 km by 3–5 s and Tsar ≈8 km within ≈6–10 s. **Use τ ≈ 1.2·t₂**; per-bomb keyframes override.
7. **B61-12 cloud.** Part 07–09 used 2.0 km above the burst, barely above Little Feller I's measured 1.8 km at 1/17 of the yield. **Merge: 2.4 km AGL** (ESTIMATED). Basis: Glasstone's 1 kt cloud of 2.7–3.5 km, mid-point 3.1 km × 0.3^0.25.
8. **B83 cloud.** Part 14–16 used 21 km, from the tropical Castle Nectar analogue. The game world is a mid-latitude desert, so the merge uses **top 19.5 km, base 11.5 km, cap Ø 30 km at 10 min**. Basis: G&D mid-latitude 1 Mt 19.8 km, and the Miller cap radius a(1.2 Mt) = 15 km.
9. **Trinity early radii.** `02` and the techniques check quoted "138 m @25 ms, 200 m @53 ms" from memory. G. I. Taylor's table (from Mack's frames) gives **130 m @25 ms and 175 m @53 ms**. The Sedov fit with E ≈ 0.75–0.8·W still matches (134 / 179 m).
10. **Blast arrival times quoted in the bomb parts** (Little Boy, Little Feller I, B83, Test 219, Tsar) came from the old `02` table, which is 5–15 % early. They are approximate. The physics module must compute arrival times with the DNA formula (§3).
11. **Fireball maximum-radius constant.** G&D 1977 gives ≈5,700 ft diameter for 1 Mt (≈55 m·W^0.4); Fletcher/G&D 1962 gives 61 m·W^0.4 (air) and 79 m·W^0.4 (contact). The formula in code uses 61/79 m with the megaton roll-off; the per-bomb values in §1 override it. Resolved per bomb: Ivy King 0.70 km (part had 0.65), RDS-37 1.1 km (1.0–1.05), Test 219 Ø 6.0 km (formula 6.3 km), B83 1.3 km (1.25).
12. **Cloud-rise time constant.** The tanh rise with τ_r = 165 s·(W/1000)^0.1 is anchored to the G&D 1 Mt table. Measured curves differ widely: Grable fits τ ≈ 135–185 s (the formula gives 109 s), Bravo ≈ 135 s (formula 216 s), Mike ≈ 150–180 s (209 s), while Trinity rose almost linearly with an inversion pause. **Use measured keyframes (§2) for Grable, Trinity, Baker, Little Boy, King, Mike and Bravo.** For the rest use the tanh formula with τ_r clamped to [150, 250] s.

---

## 1. Master table of game values

Times are from detonation. "AGL" means above the ground at ground zero. Fireball R is the radius of the luminous ball. "n/a" means there is no such feature.

| # (game order) | Bomb | Yield | Burst type, height | Fireball R_max @ t | t_min / t₂ | Cloud top @ t | Cap Ø (≈10 min) | Crater (Ø × depth) | Rec. view | UI tag |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Mk 82 | 0.10 t | conv. surface, −0.7 m | 7.5 m @ ≤0.01 s; bright 0.25 s | n/a | 290 m @ 2 min | puff ≈0.17 km | 7 × 2 m | 2 km | estimate (TNT eq.) |
| 2 | Mk 84 | 0.50 t | conv. surface, −1.2 m | 13 m @ ≤0.015 s; bright 0.4 s | n/a | 440 m @ 2 min | puff ≈0.26 km | 13 × 4 m | 3 km | estimate |
| 3 | Tallboy | 3.1 t (air blast ≈0.2 t) | conv. buried, −18 m | none (vent glint ≤0.2 s) | n/a | 300 m @ 2 min | n/a | 30 × 10 m | 4 km | estimate |
| 4 | Grand Slam | 5.6 t (air blast ≈0.4 t) | conv. buried, −20 m | none (vent glint ≤0.2 s) | n/a | ≈350 m dust @ 1–2 min | n/a | 38 × 10 m | 5 km | estimate |
| 5 | MOAB | 11 t | conv. air, +2 m | flat dome 140 × 40 m @ 0.4 s; flame ≈2 s | n/a | 1.5 km @ ≈3 min | 0.5 km | none (scoured disc) | 8 km | measured (official) |
| 6 | Little Feller I (W54) | 18 t | nuclear near-surface, 0.9 m | 17 m hemisphere @ ≈0.05 s | 0.9 ms / 7 ms | 1.8 km AGL @ ≈3 min | 0.7 km | ≈8 × 1.5 m | 8 km | measured |
| 7 | FOAB (ATBIP) | 44 t claimed | thermobaric, cloud centre 10 m | Ø 120 m × 70 m dome, 0.25–1.5 s; flames to ≈5 s | n/a | 2.0 km @ ≈3 min | 0.5 km | none | 10 km | claimed |
| 8 | B61-12 (0.3 kt) | 0.3 kt | nuclear air, 150 m | 38 m @ ≈0.2 s | 2.8 ms / 25 ms | 2.4 km AGL @ ≈4 min | 0.9 km | none | 12 km | conceptual model |
| 9 | Grable | 15 kt | nuclear low air, 160 m | 170 m @ 0.13 s → 180 m @ 1 s; flattened bottom | 14 ms / 130 ms (measured) | 9.7 km AGL @ 7 min (10.0 @ 9 min) | 3.5 km, sheared NE | none | 20 km | measured |
| 10 | Little Boy | 16 kt | nuclear air, 600 m | 190 m @ ≈1 s | 13.6 ms / 0.14 s | 12.5 km @ 10 min | 4.5 km | none | 20 km | measured (yield ±20 %) |
| 11 | Trinity | 21 kt | tower, 30 m | ≈300 m hemisphere @ 1–2 s | ≈16 ms (measured) / 0.16 s | 10.5 km AGL @ 11–12 min | 4.5 km | bowl 70 × 1.8 m in 350 m saucer; 600 m trinitite disc | 25 km | measured |
| 12 | Baker | 23 kt | underwater, −27 m (lagoon 55 m) | none (underwater glow ≈20 ms) | n/a | 2.3 km @ 60 s → 3.0 km max | head 2.6 km @ 60 s; base surge Ø 5.1 km | lagoon floor 1,000 × 550 × 7.6 m (invisible) | 25 km | measured |
| 13 | Sedan | 104 kt | buried, −194 m | none (venting glow 3–4.5 s) | n/a | 3.7 km AGL @ 5–6 min | dust tower 1.5–2 km; base surge Ø ≈8 km | 370 × 98 m (lip crest 390–400 m) | 35 km (best 8–15 km) | measured |
| 14 | Ivy King | 500 kt | nuclear air over water, 450 m | ≈0.70 km @ 5–6 s, flattened on the sea | 54 ms / 0.64 s | 23 km @ 8–10 min (8.5 km @ 1 min) | 27 km | none | 50 km | measured |
| 15 | B83 | 1.2 Mt | laydown surface, 0 m | 1.3 km hemisphere @ ≈9 s | 77 ms / 0.94 s | 19.5 km @ 8–10 min | 30 km | 300 × 75 m (lip 19 m) | 55 km | conceptual model |
| 16 | RDS-37 | 1.6 Mt | nuclear air, 1,550 m | 1.1 km @ ≈10 s, underside flattened | 86 ms / 1.07 s | 20 km (base 13 km) @ ≈8 min | 28 km @ 7 min | none | 60 km | measured |
| 17 | Ivy Mike | 10.4 Mt | surface, ≈5 m | Ø 5.2 km @ 3–5 s (Ø 4.5 km @ 1 s) | 0.18 s / 2.4 s | 37 km main top (41 km turret) @ 6–10 min | 61 km (100 km @ 30 min) | 1.9 km × 50 m (water) | 90 km | measured |
| 18 | Castle Bravo | 15 Mt | surface, 2 m | Ø 4.8 km @ 1 s → Ø 7 km @ 8–10 s | 0.21 s / 2.9 s | 35 km main @ 5 min; dome 39–40 km @ 6–8 min | 113 km | 2.0 km × 76 m (water) | 100 km | measured |
| 19 | Test No. 219 | 24.2 Mt | nuclear high air, 3,750 m | Ø 6.0 km @ ≈5–8 s | 0.26 s / 3.5 s | 53 km @ 8–10 min | 72 km upper / 55 km lower | none | 120 km | measured (look reconstructed) |
| 20 | Tsar Bomba | 50 Mt | nuclear high air, 4,000 m | Ø 8.0 km @ ≈6–10 s; never touches ground | 0.34 s / 4.9 s | 67 km peak @ 8–10 min → 64 km | 95 km upper / 70 km lower | none | 150 km | measured |

---

## 2. Per-bomb notes

Each section gives the key verified numbers (fact → value → status → source → use), the resolved disputes, a condensed visual key-frame list (the full version is in the research part), the UI blurbs and the reference images. URLs given once per section; the research parts list more.

### 2.1 Mk 82 (500-lb general-purpose bomb, USA) — game order 1

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Service | USA, Mk 80 series, 1950s–today; warhead of GBU-12 and GBU-38 JDAM | MEASURED | https://en.wikipedia.org/wiki/Mark_82_bomb ; https://www.globalsecurity.org/military/systems/munitions/mk82.htm | Info card |
| Size, mass | 2.21 m × Ø 0.273 m, 241 kg | MEASURED | Wikipedia; https://www.globalsecurity.org/military/systems/munitions/mk82-specs.htm | 3D model |
| Fill | 87 kg tritonal (infobox 89 kg) | MEASURED | Wikipedia; https://en.wikipedia.org/wiki/Tritonal | Info card |
| TNT equivalent | 0.10 t (RE 1.05–1.18 → 1.15) | DISPUTED → resolved | https://en.wikipedia.org/wiki/TNT_equivalent | yield_kt 0.0001 |
| Burst | Short-delay ground burst, charge centre −0.7 m (contact fuze would give only a 2–4 m crater) | MEASURED (fuze options) / ESTIMATED (depth) | GlobalSecurity; US Navy OP 1172 (1944) https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USN/USN%20Manuals%20and%20Reports/USN.Perf.Bombs.Project.v.Shore.Installations.1944-05-09.pdf | burst_height_m |
| Fireball | R 7.5 m (Ø 15 m) in ≤10 ms; bright 0.25 s; flame visible to 0.6 s | ESTIMATED (R = 1.6·W_kg^(1/3)) | Cooper/HSE fits in LA-14209-T https://www.osti.gov/servlets/purl/841586 ; photo check | Fireball layer |
| Shock arc | Thin refraction/condensation arc at 2–2.5 fireball radii (≈20–25 m) for 0–60 ms | MEASURED (photo) | `refs/01_mk82/mk82_explosion_saberstrike18_b.jpg` | Keep a visible shock shell even for the smallest bomb |
| Ejecta crown | 35 m wide × 25 m tall at ≈1 s, black-grey soil jets | MEASURED (photo, ±30 %) | Saber Strike 18 photos | Debris particles |
| Cloud | 130 m @ 30 s, 200 m @ 1 min, 290 m @ 2 min; width ≈0.6·H; no stem or cap | ESTIMATED from MEASURED TNT stacks | Church 1969, Sandia SC-RR-68-903 https://digital.library.unt.edu/ark:/67531/metadc1055670/m2/1/high_res_d/4798257.pdf | Cloud rise |
| Crater | Ø 7 m × 2 m, lip 0.3–0.5 m | ESTIMATED from MEASURED analogues | OP 1172 Table 3; Vietnam crater survey https://pmc.ncbi.nlm.nih.gov/articles/PMC7080274 | Crater mesh |
| Fragments | Dense to 150 m, sparse to 300 m | DISPUTED / ESTIMATED | Wikipedia Mk 84; forum EOD figures (weak) | Fragment-puff fan |
| Paint | Olive drab, yellow nose band (yellow = HE) | MEASURED | NAVEDTRA 14014 https://navyaviation.tpub.com/14014/css/14014_182.htm ; Kitty Hawk 1972 photo | Model colours |

**Resolved:** fireball Ø 15 m (dossier 15–25 m too large; `02` formula R = 1.0·m^(1/3) too small); cloud 290 m at 2 min (dossier "a few tens of metres"); crater 7 × 2 m.

**Key frames:** 0–10 ms white-yellow point flash (exposure dip 1–2 stops only), ball Ø 15 m in one frame → 10–60 ms yellow-orange ball (1,800–2,500 K) with black soot on one side, thin shock arc to 20–25 m, white dust skirt → 0.05–0.3 s black-grey crown of radial soil jets, fragment dust puffs to 100–150 m → 0.3–1 s crown 35 × 25 m, flame dies by 0.6 s → 1–30 s lumpy grey-black-brown puff, 60 m @ 5 s, 130 m @ 30 s → 2 min 290 m, dispersing. Sound: sharp crack, no long rumble.

**Blurb RU:** Mk 82 — стандартная американская 500-фунтовая (≈241 кг) авиабомба общего назначения: в строю с 1950-х годов до наших дней, она же — боевая часть управляемых GBU-12 и GBU-38 JDAM. Внутри около 87 кг тритонала (80 % тротила и 20 % алюминиевой пудры), это примерно 0,1 т в тротиловом эквиваленте. Самый слабый взрыв в коллекции и точка отсчёта для всех остальных.
**Blurb EN:** The Mk 82 is the standard US 500-lb (≈241 kg) general-purpose bomb, in service from the 1950s to this day and the warhead of guided weapons such as the GBU-12 and GBU-38 JDAM. It holds about 87 kg of tritonal (80% TNT, 20% aluminium powder), roughly 0.1 t of TNT equivalent. It is the weakest blast in the collection and the yardstick for all the others.

### 2.2 Mk 84 (2,000-lb general-purpose bomb, USA) — game order 2

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Service | USA, 1950s–today; >12,000 dropped in Desert Storm; body of GBU-10/24/31 | MEASURED | https://en.wikipedia.org/wiki/Mark_84_bomb ; https://www.globalsecurity.org/military/systems/munitions/mk84.htm | Info card |
| Length | **3.28 m** (Wikipedia 3.84 m rejected) | DISPUTED → resolved | FAS mirror https://gulflink.health.mil/al_muth/al_muth_refs/n58en036/mk84.htm ; https://www.globalsecurity.org/military/systems/munitions/mk84-specs.htm ; USAF caption | Model |
| Diameter, mass | 0.457 m, 925 kg | MEASURED | same | Model |
| Fill / TNT eq. | 429 kg tritonal → 0.5 t | MEASURED / resolved | same; RE as Mk 82 | yield |
| Burst | Short-delay ground burst, −1.2 m | ESTIMATED | OP 1172 | burst_height_m |
| Fireball | R 13 m (Ø 26 m); bright 0.4 s; flame to 1.0 s | ESTIMATED | R = 1.6·W_kg^(1/3); Vietnam 1972 photo | Fireball |
| Column at 1 s | 60 m wide × 50 m tall, black-brown cauliflower cap over the orange ball | MEASURED (photos) / ESTIMATED sizes | USMC 2007 photos (refs) | Smoke |
| Cloud | 230 m @ 30 s, 330 m @ 1 min, 440 m @ 2 min | ESTIMATED from MEASURED | Church 1969 (1,600-lb shots 450–498 m @ 2 min) | Cloud rise |
| Crater | Ø 13 m × 4 m, lip 0.5–1 m (Wikipedia "15 × 11 m" rejected: depth/width implausible for an apparent crater) | DISPUTED → resolved | OP 1172 (2,000-lb GP); Gaza ≥12 m craters https://pmc.ncbi.nlm.nih.gov/articles/PMC11466298/ | Crater mesh |
| Fragments | Lethal 120 m (Wikipedia); visible fan dense to 250 m, sparse to 500 m | DISPUTED | Wikipedia; USMC photo | Fragment fan |
| Paint | Olive drab, yellow nose band; training rounds blue band | MEASURED | NAVEDTRA 14014; Desert Storm photo | Model |

**Key frames:** 0–15 ms hard white-yellow flash (≈2 stops dip), Ø 26 m ball → 15–100 ms bright orange boiling ball; refraction shell and lifted dust ring pass ≈50 m @ 0.05 s, ≈100 m @ 0.15 s; brief white condensation shell in humid air → 0.1–0.5 s black-brown cauliflower cap rolls up from the ball; dark soil crown 50–70 m; fragment puffs to ≈250 m → 0.5–1 s flame dies inside a 60 × 50 m column, tan base ring to 60–80 m → 1–30 s dirty thermal, 100 m @ 5 s, 230 m @ 30 s → 2 min 440 m. Sound: deep heavy boom, short rumble.

**Blurb RU:** Mk 84 — самая тяжёлая бомба американской серии Mk 80: около 925 кг, из них 429 кг тритонала, то есть примерно 0,5 т в тротиловом эквиваленте. На её основе сделаны управляемые GBU-10, GBU-24 и GBU-31 JDAM, а только за «Бурю в пустыне» (1991) было сброшено больше 12 000 таких бомб. При подрыве с небольшим замедлением в мягком грунте она оставляет воронку 12–15 м в поперечнике.
**Blurb EN:** The Mk 84 is the heaviest member of the US Mk 80 family: about 925 kg, including 429 kg of tritonal, or roughly 0.5 t of TNT equivalent. It is the basis of the GBU-10, GBU-24 and GBU-31 JDAM guided bombs, and more than 12,000 were dropped in Desert Storm (1991) alone. With a short fuze delay in soft ground it leaves a crater 12–15 m across.

### 2.3 Tallboy (12,000-lb "earthquake bomb", UK) — game order 3

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Service | Barnes Wallis; 617 and 9 Sqn RAF, 1944–45; 854 dropped | MEASURED | https://en.wikipedia.org/wiki/Tallboy_(bomb) ; https://bombercommandmuseumarchives.ca/s,tallboy.html | Info card |
| Size, mass | 6.40 m × Ø 0.97 m (fin span 1.12 m), 5,400 kg | MEASURED | Wikipedia; BCM Canada; IWM captions | Model |
| Fill / TNT eq. | 2,359 kg Torpex D1 → **3.1 t** (RE 1.30; 3.5–3.8 t at the underwater-energy RE 1.5–1.6) | DISPUTED → resolved | https://en.wikipedia.org/wiki/Torpex ; TNT-equivalent RE table | yield; air-blast effective yield ≈0.2 t (buried) |
| Release / impact | From 18,000 ft; fall ≈37 s; impact ≈750 mph ≈335 m/s (GlobalSecurity's "3,600 ft/s" rejected) | MEASURED | Wikipedia; BCM Canada | Impact puff before detonation |
| Burst depth | −18 m (Saumur tunnel, 8/9 June 1944: burst ≈60 ft below the surface); camouflet principle | MEASURED (one event) | Wikipedia; https://en.wikipedia.org/wiki/Earthquake_bomb | burst_height_m −18; detonate 1.5 s after impact (DESIGN) |
| Crater | Ø 30 m × 10 m, lip 1.5–2 m ("80 ft deep" rejected: apparent crater cannot be 24 m deep at 30 m width) | Width MEASURED (≥2 sources); depth DISPUTED → resolved | IBCC Saumur recon https://ibccdigitalarchive.lincoln.ac.uk/items/show/16508 ; hmdb marker https://www.hmdb.org/m.asp?m=118208 | Crater mesh |
| Column | Spiky dark soil/smoke column 60–120 m by 2–3 s; Tirpitz hit: steam/smoke column ≈300 ft | MEASURED (photos, one account) | IWM C 4775; https://www.bombercommandmuseum.ca/bomber-command/sinking-of-the-battleship-tirpitz/ | Ejecta |
| Cloud | 180 m @ 30 s, 300 m @ 2 min | ESTIMATED | Church 1969 reduced for burial | Cloud |
| Paint | Dark olive/bronze-green body, light ring near nose, "TORPEX D1" stencil, long tail cone, 4 fins offset ≈5° | Shape MEASURED, colour undocumented | IWM CH 15363, CH 15380 | Model |
| 2020 Świnoujście | Unexploded Tallboy detonated during a deflagration attempt, 12 m under the canal waterline; tall water plume, no injuries | MEASURED (event) | https://www.twz.com/37064/watch-the-biggest-unexploded-world-war-two-bomb-ever-found-in-poland-blow-up | Blurb only |

**Key frames:** impact at 335 m/s, small soil jet, no explosion → t = 0 no flash; ground shock reaches surface in 10–20 ms, spall dust ring 40–60 m, camera shake → 0.05–0.4 s earth dome 3–6 m high, 30–40 m wide, radial cracks → 0.3–1 s dome ruptures into a geyser of dark brown soil and grey-white gas; big clods on ballistic arcs; at most a dull red glimmer in the vent → 1–3 s column 60–120 m, curtain fallback, brown base surge to 100–200 m → 3–10 s collapse, possible subsidence → 30 s–2 min brownish-grey cloud 180 → 300 m, no cap. Sound: tremor before the air sound; muffled thump, long debris rumble.

**Blurb RU:** Tallboy — британская 12 000-фунтовая (≈5,4 т) «сейсмическая» бомба конструктора Барнса Уоллиса с 2,4 т торпекса (≈3 т в тротиловом эквиваленте). Сброшенная с высоты около 5,5 км, она врезалась в землю на скорости около 1200 км/ч и взрывалась глубоко под поверхностью, обрушивая цели: так в 1944 году были завалены железнодорожный тоннель в Сомюре и потоплен линкор «Тирпиц». За войну сбросили 854 такие бомбы, а одна неразорвавшаяся сдетонировала под водой в польском Свиноуйсьце в 2020 году.
**Blurb EN:** Tallboy was Barnes Wallis's British 12,000-lb (≈5.4 t) "earthquake bomb", filled with 2.4 t of Torpex (about 3 t of TNT equivalent). Dropped from about 5.5 km, it struck the ground at roughly 1,200 km/h and exploded deep underground, bringing targets down from below: in 1944 it blocked the Saumur railway tunnel and sank the battleship Tirpitz. 854 were dropped during the war, and an unexploded one detonated underwater at Świnoujście, Poland, in 2020.

### 2.4 Grand Slam (22,000-lb, UK) — game order 4

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Service | 617 Sqn only; first test 13 Mar 1945 (Ashley Walk); first combat 14 Mar 1945, Bielefeld viaduct; 42 dropped (41 in another count); 99 built | MEASURED / minor DISPUTE | https://en.wikipedia.org/wiki/Grand_Slam_(bomb) ; https://bombercommandmuseumarchives.ca/s,grandslam.html | Info card |
| Length | 7.8 m (7.75 / 7.8 / 8.08 m in sources) | DISPUTED → resolved | same | Model |
| Diameter, mass | 1.17 m; 10,160 kg assembled (22,000 lb nominal) | MEASURED | same | Model |
| Fill / TNT eq. | 4,300 kg Torpex D1 → **5.6 t** at RE 1.30 (published "6.5 long tons" uses RE ≈1.5) | DISPUTED → resolved (merge §0.4.1) | Wikipedia; Torpex article | yield; air-blast effective ≈0.4 t (ESTIMATED, 5–10 % as Tallboy) |
| Impact | ≈320 m/s; penetration up to 40 m in earth (design) | 1 source | Wikipedia | Impact puff |
| Burst depth | −20 m (not recorded; fits a 38 m crater at scaled depth ≈1 m/kg^(1/3)) | ESTIMATED | derived | burst_height_m |
| Crater | Ø 38 m × 10 m (others: 40 × 21 m, 43 × 21 m) | DISPUTED → resolved | Wikipedia + BCM (38 × 10); https://www.geograph.org.uk/photo/4478063 , https://dambustersblog.com/category/grand-slam/ (130 × 70 ft) | Crater mesh |
| Appearance | Arnsberg 19 Mar 1945 photo: light-grey cauliflower earth/smoke cloud ≈120–150 m across with dark radial soil streaks; **no flame**. Ashley Walk witness: gas vented "like a volcano" for minutes. No source supports the dossier's "orange flash" | MEASURED (photo, witness) | https://commons.wikimedia.org/wiki/File:Grand_Slam_bomb_exploding_near_Arnsberg_viaduct_1945.jpg ; BCM | Earth-tone ejecta, vent puffs |
| Ejecta / dust | Column 150–250 m at 1–4 s; dust cloud ≈350 m | ESTIMATED | scaled | Cloud |
| Paint | Museum: deep bronze-green, pale-blue band + thin red ring at nose; wartime: darker fore body, lighter aft (B&W); test bomb black-and-white | MEASURED (photos) | RAF Museum CC0 photo; IWM CH 15369 | Model (museum scheme) |

**Key frames:** 7.8 m bomb falls near-vertically, spinning slowly; thud and dust puff at 320 m/s; optional 1–2 s delay (real Bielefeld delay ≈11 s) → t = 0 no light; seismic jolt, ripple ring in soil → 0–0.3 s dome 35–40 m wide, 5–8 m high → 0.3–1 s dome ruptures into dark-brown radial "fingers" and grey-white gas → 1–4 s column 150–250 m, cauliflower top ≈130 m across, clods to 150–200 m → 4–30 s collapse, light-brown/grey dust ≈350 m drifting → 30 s+ crater Ø 38 m visible; sporadic gas puffs. Palette: soil #6b5a45, dust #9a8f80, gas #d8d4cc. No thermal flash.

**Blurb RU:** Британская «сейсмическая» бомба Барнса Уоллиса массой 10 тонн — самая тяжёлая авиабомба Второй мировой. Она падала почти со скоростью звука, уходила глубоко в грунт и взрывалась под землёй: 4,3 т торпекса (≈5,5–6,5 т в тротиловом эквиваленте) выбивали опору из-под цели. 14 марта 1945 года первая боевая «Гранд Слэм» обрушила пролёты виадука в Билефельде; до конца войны их сбросили 41–42 штуки.
**Blurb EN:** Barnes Wallis's 10-tonne British "earthquake bomb", the heaviest bomb dropped in the Second World War. It fell at nearly the speed of sound, burrowed deep into the ground and exploded underneath its target: 4.3 t of Torpex (≈5.5–6.5 t of TNT) knocked the ground out from under it. On 14 March 1945 the first operational Grand Slam brought down spans of the Bielefeld viaduct; 41–42 were dropped before the war ended.

### 2.5 GBU-43/B MOAB (USA, 2003/2017) — game order 5

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| History | Live tests Eglin 11 Mar 2003 (tritonal fill, orange test paint) and 21 Nov 2003 (H-6); combat once, 13 Apr 2017, Achin, Afghanistan | MEASURED | https://en.wikipedia.org/wiki/GBU-43/B_MOAB ; https://afarmamentmuseum.com/artifact/gbu43/ | Info card |
| Size, mass | 9.19 m × Ø 1.03 m, 9,850 kg; grid-fin span 3.0 m deployed | MEASURED | same; https://www.airandspaceforces.com/weapons-platforms/gbu-43-moab | Model |
| Fill / yield | 8,500 kg H-6 → 11 t TNT (H-6 ≈1.35 × TNT → 11.5 t cross-check) | MEASURED / consistent | same | yield |
| Mechanism | Conventional HE air burst, **not** fuel-air (Scientific American wrong) | DISPUTED → resolved | Wikipedia; museum | HE palette with aluminium afterburn |
| Delivery | Extracted from an MC-130 on a parachute-pulled pallet; bomb free-falls with grid fins (no retarding chute) | MEASURED | Wikipedia; video | Delivery animation |
| Burst height | ≈2 m (proximity; "about 6 ft") | ESTIMATED (consistent with video) | https://www.businessinsider.in/Heres-why-the-mother-of-all-bombs-exploded-6-feet-above-its-target-in-Afghanistan/articleshow/58173415.cms | burst_height_m 2 |
| Fireball | Flat ground-hugging dome Ø 120–170 m × 30–45 m at ≈0.45 s (aspect ≈3.8:1) → game Ø 140 m × 40 m; flame ≈2 s | ESTIMATED (frame measurement of the PD video) | https://commons.wikimedia.org/wiki/File:GBU-43B_MOAB_2003_test_B-Roll_(Color).ogv | Fireball shape: flattened |
| Smoke colour | **White to light grey** (Al₂O₃ smoke + dust) after 2–3 s, darker grey lower lobes — **not** the black TNT palette in the dossier | MEASURED (video) | same | Cloud palette |
| Cloud | 7.6 s: cauliflower ≈95–135 m tall, 140–190 m wide; final top **1.5 km**, cap 0.5 km ("10,000 ft" is a press figure) | MEASURED (video) / DISPUTED → resolved | video; AP via search; reasoning in part 04 | Cloud |
| Crater | None (scorched, scoured disc 150–250 m) | MEASURED (imagery) | Alcis https://medium.com/alcis-stories/after-the-dust-settles-making-sense-of-the-non-sense-c97da619a20f (via search summary) | No crater |
| Visibility | Cloud seen from 20 mi (32 km) | MEASURED (Eglin caption) | Eglin caption via search | Blurb |
| Paint | Service-like dark olive-grey with yellow nose band; orange/black test scheme (11 Mar 2003) as an easter egg | MEASURED (photos) | https://commons.wikimedia.org/wiki/File:MOAB_bomb.jpg | Model |

**Key frames:** MC-130 extraction (optional) → t = 0 one frame of blue-white flash, large bloom → 0.03–0.15 s brilliant yellow-white hemisphere spreading sideways faster than up → 0.15–0.5 s flattens to 140 × 40 m, turbulent white-yellow core, orange edges, ground dust ring and brief condensation flash in humid air → 0.5–1.5 s orange-red with brown/dark-grey blotches; dust skirt to ≈250 m by 3 s → 1.5–3 s last orange glints; cloud turns white/light grey → 3–10 s stemless cauliflower thermal, ≈120 m tall at 8 s → 10 s–3 min lumpy stemless "mushroom", top 1.5 km, cap 0.5 km. Sound: sharp crack and long rolling rumble.

**Blurb RU:** GBU-43/B MOAB — управляемая авиабомба ВВС США массой 9,8 т с 8,5 т взрывчатки H-6 (≈11 т в тротиловом эквиваленте), самый мощный неядерный боеприпас, когда-либо применённый в бою. Её выталкивают из грузового отсека транспортника MC-130 на платформе с вытяжным парашютом, а взрывается она у самой земли и почти не оставляет воронки. Испытана во Флориде в 2003 году (облако видели за 30 км), в бою применена один раз — 13 апреля 2017 года против туннелей ИГИЛ в Афганистане.
**Blurb EN:** The GBU-43/B MOAB is a 9.8-tonne US guided bomb carrying 8.5 t of H-6 explosive (≈11 t of TNT), the most powerful non-nuclear weapon ever used in combat. It is pushed out of the cargo ramp of an MC-130 on a parachute-extracted pallet, explodes just above the ground and leaves almost no crater. It was tested in Florida in 2003 (the cloud was seen 20 miles away) and used in combat once, on 13 April 2017, against ISIS tunnels in Afghanistan.

### 2.6 W54 "Davy Crockett" / test Little Feller I (17 July 1962) — game order 6

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Date, place | 17 Jul 1962, 10:00 PDT; NTS Area 18, 1,578 m elevation; Operation Sunbeam; **last atmospheric test at the NTS**; Exercise Ivy Flats; observers RFK and Gen. Maxwell Taylor ≈3.5 km SW | MEASURED | DOE/NV-209 Rev 16 https://nnss.gov/wp-content/uploads/2023/08/DOE_NV-209_Rev16.pdf ; DOE/NV-1200 https://nnss.gov/wp-content/uploads/2023/04/DOENV_1200.pdf ; DNA 6027F https://www.govinfo.gov/content/pkg/GOVPUB-D15-PURL-gpo222775/pdf/GOVPUB-D15-PURL-gpo222775.pdf | Scene time 10:00, high desert |
| Yield | 18 t (DOE lists "Low"; 20 t nominal W54 Mod 2) | DISPUTED (minor) → 18 t | https://nuclearweaponarchive.org/Usa/Tests/Storax.html ; https://en.wikipedia.org/wiki/Little_Feller_(nuclear_tests) | yield |
| Burst height | **0.9 m (3 ft)**; the "20–40 ft" figures are the pre-shot plan / fuze option | DISPUTED → resolved (3 official documents) | DOE/NV-209 ("3"), DOE/NV-1200, DNA 6027F | burst_height_m 0.9 |
| Range | **2.85 km** from the M29 launcher on an M113 ("852 m" = feet/metres slip in DOE/NV-1200) | DISPUTED → resolved | DNA 6027F (2,853 m); https://www.brookings.edu/the-davy-crockett | Launch animation |
| Projectile | M388: 0.79 m × Ø 0.28 m, 34.5 kg, 4 fins on a piston rod | MEASURED | https://en.wikipedia.org/wiki/Davy_Crockett_(nuclear_device) ; https://archive.org/details/IvyFlatsFilmReport | Model |
| Fireball | R ≈17 m hemisphere (contact formula 16 m); film: white-out ≈0.17 s, glowing ball to ≈0.6 s | ESTIMATED / MEASURED (film timing) | `02` formulas; Ivy Flats film | Fireball |
| Early cloud | ≈1 s white bell-shaped glowing cloud on the ground with a bright horizontal dust band; 20–22 s cauliflower cap on a thin dusty wavy stem, wide low skirt; 40 s cap leaning NNW | MEASURED (film, DNA figs. 8-1, 8-2) | film; DNA 6027F | Cloud shape |
| Cloud top | 11,000 ft **MSL** → **1.8 km AGL** (dossier's 3.35 km was MSL); Little Feller II reached the same | MEASURED | DOE/NV-1200; DNA 6027F | Cloud override (the sub-kt formula under-predicts by ≈2.5×) |
| Cloud timing | ≈0.5 km @ 13 s, 0.7 km @ 20 s, 1.2 km @ 45 s, 1.8 km @ ≈3 min; cap Ø 0.7 km | ESTIMATED | derived | Rise keyframes |
| Weather | 29.7 °C; wind toward NNW ≈7 m/s | MEASURED | DNA 6027F | Drift |
| Crater | Ø ≈8 m × 1.5 m (measured in 1962 by Project 1.9, numbers not online) | ESTIMATED | https://www.osti.gov/biblio/7248878 | Crater mesh |
| Paint | Not documented; olive drab body, light-grey fins, bare piston rod | DESIGN | 1961 photo | Model |

**Key frames:** optional launch from 2.85 km, finned "watermelon" arcs ≈10–15 s → t = 0 blue-white point, frame white for ≈0.1–0.17 s → 6–50 ms hemisphere to R 17 m → 0.05–0.6 s yellow → orange-red; bright dust ring races out, road dust lights up as a line → 0.6–1.5 s white/grey bell-shaped boiling cloud 40–60 m tall, faint red-brown tint → 1.5–20 s lifts off; thin dusty stem, skirt 300–500 m wide; cap ≈0.7 km up at 20 s → 20 s–3 min leans and drifts NNW; top 1.8 km AGL, cap 0.7 km. The cloud is out of proportion to the tiny fireball: the signature look.

**Blurb RU:** 17 июля 1962 года на Невадском полигоне солдаты армии США выстрелили боевым ядерным снарядом M388 с боеголовкой W54 из безоткатного орудия «Дэви Крокетт», установленного на бронетранспортёре. «Атомный арбуз» массой около 34 кг пролетел 2,85 км и взорвался менее чем в метре над землёй с мощностью около 18 т в тротиловом эквиваленте; облако поднялось примерно на 1,8 км над пустыней. Испытание Little Feller I стало последним атмосферным ядерным взрывом на Невадском полигоне; за ним наблюдали Роберт Кеннеди и генерал Максвелл Тейлор.
**Blurb EN:** On 17 July 1962, US Army soldiers at the Nevada Test Site fired a live M388 projectile with a W54 warhead from a Davy Crockett recoilless gun mounted on an armoured personnel carrier. The 34 kg "atomic watermelon" flew 2.85 km and exploded less than a metre above the ground with a yield of about 18 tons of TNT; its cloud rose about 1.8 km above the desert. Little Feller I was the last atmospheric nuclear explosion at the Nevada Test Site, watched by Robert F. Kennedy and General Maxwell Taylor.

### 2.7 "Father of All Bombs" (ATBIP / АВБПМ, Russia, 2007) — game order 7

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Event | Test shown on Russian TV on 11 Sep 2007; site not named; only known test | CLAIMED | https://en.wikipedia.org/wiki/Father_of_All_Bombs ; https://www.rferl.org/a/1078635.html | Date "11.09.2007 (объявлено)" |
| Yield | 44 t TNT ("4× MOAB"), claimed; experts doubt it (Coyle: ≈15–17 t; Lange: "too small") | CLAIMED / DISPUTED | Wikipedia; https://wirednews.pages.dev/2007/10/did-russia-stage-the-father-of-all-bombs-hoax ; https://www.defencetalk.com/russian-bomb-claims-questionable-expert-says-13362 | 44 t + badge «заявлено, не подтверждено» |
| Mass | ≈7.1 t (UI «≈7–8 т»); the dossier's "6,350 kg" has **no source** — dropped | DISPUTED → resolved | Wikipedia; Mercopress; Wired | Info card |
| Damage radius | 300 m claimed (5 psi check: ≈250–300 m, consistent) | CLAIMED | ru.wikipedia comparison table | UI ring |
| Type, burst | Thermobaric / fuel-air; aerosol cloud near the ground → cloud centre 10 m | ESTIMATED | Wired (Burky); FAE references | burst_type THERMOBARIC |
| Dimensions, paint | Not published → DESIGN ≈5.5 m × Ø 1.4 m, stubby cylinder with skids and drogue pack; matt grey-green | DESIGN | Wired description; PD line drawing | Model labelled reconstruction |
| Fireball | Ø ≈120 m (100–160) × ≈70 m dome; bright 0–1.5 s, flames to ≈5 s, out by 8 s | ESTIMATED (CBU-72 cloud scaling; CCPS D = 5.8·M^(1/3) = 111 m) | militaryperiscope, euro-sd, JRC CCPS calculator | Fireball |
| Cloud | 2.0 km @ ≈3 min, cap 0.5 km | ESTIMATED (heat^(1/4) scaling from MOAB) | part 07 | Cloud |
| Crater | None (scorched disc ≈150 m) | ESTIMATED | — | No crater |

**Key frames:** grey bomb under one drogue, no aircraft in frame → 0–0.15 s dull pop at 10–20 m, pale aerosol pancake Ø ≈100 m, 10–15 m thick → 0.15–0.25 s whole pancake flashes yellow-white (no nuclear-style white-out; ≈2 stops) → 0.25–1.5 s broad, flattened rolling dome of flame tongues Ø 120 m × 70 m; tan dust ring races outward → 1.5–5 s orange → deep orange-red with thick black soot rolls; lifts into a short-stemmed torus → 5–8 s last flames inside a dark grey-black smoke ball; brown skirt Ø 400–600 m → 8 s–3 min top ≈2 km, cap 0.5 km. Long-positive-phase "push" sound. Palette: #FFF4C8 → #FFB030/#FF7A10 → smoke #2A2522/#4A4440 → dust #B59A78.

**Blurb RU:** 11 сентября 2007 г. российское ТВ показало испытание «авиационной вакуумной бомбы повышенной мощности». Заявлено около 7 т взрывчатки и 44 т в тротиловом эквиваленте — вчетверо больше американской MOAB. Независимо это не подтверждено: в смонтированном ролике бомба и самолёт ни разу не показаны в одном кадре.
**Blurb EN:** On 11 September 2007 Russian TV showed a test of an "aviation vacuum bomb of increased power". Russia claimed about 7 t of explosive and a 44-ton TNT equivalent, four times America's MOAB. None of this has been independently confirmed: in the heavily edited video the bomb and the bomber never appear in the same shot.

### 2.8 B61 Mod 12 at minimum yield (≈0.3 kt), never tested — game order 8

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Programme | B61-12 LEP; first production unit Nov 2021, last 18 Dec 2024 | MEASURED | https://www.energy.gov/node/4847912 ; NNSA fact sheets https://www.energy.gov/sites/prod/files/2020/06/f76/B61-12-20200622.pdf | Info card |
| Yields | Classified. Non-official 0.3 / 1.5 / 10 / 50 kt (inherited B61-4 settings) | ESTIMATED | https://fas.org/publication/b61-12/ ; https://nuclearweaponarchive.org/Usa/Weapons/B61.html | 0.3 kt; UI «оценка, официально засекречено» |
| Size, mass | ≈3.66 m (12 ft) × Ø 0.34 m, ≈374 kg (825 lb) | MEASURED (official approx.) | NNSA fact sheets | Model |
| Paint | Only documented look: flight-test livery, white/light-grey nose and tail, red-orange centre | MEASURED (test units) | https://commons.wikimedia.org/wiki/File:F-35_B61-12_trial.jpg | Model |
| Burst height | **150 m** (dossier 100 m): reproduces the scaled height of Teapot Wasp (1.2 kt at 232 m) and Tumbler-Snapper Able (1 kt at 242 m), so their photos apply | ESTIMATED (design choice with analogues) | https://www.osti.gov/servlets/purl/1839345 ; https://nuclearweaponarchive.org/Usa/Tests/Teapot.html | burst_height_m 150 |
| Fireball | R_max 38 m (dossier 40–55 m was the 1-kt range); t_min 2.8 ms, t₂ 25 ms, max size ≈0.2 s | ESTIMATED | `02`/techniques formulas | Fireball |
| Cloud | **2.4 km AGL** @ ≈4 min, cap 0.9 km; reddish-brown NO₂ ball; thin dust column that does **not** join the cap | ESTIMATED (merge §0.4.7) / look MEASURED on Able, Wasp | Able and Wasp photos | Cloud |
| Crater | None | ESTIMATED | — | Scorched/dusty disc |

**Key frames:** slim white/red-orange bomb falls nose-down under tail-kit control → 0–1 ms blue-white point, white-out → 1–3 ms brightness dip, orange-red shell Ø ≈35 m → ≈25 ms second peak, white sphere Ø 55–65 m; possible Wilson flicker → 0.05–0.2 s Ø ≈75 m, white → yellow, never touches the ground → 0.2–1 s orange-red, rising torus; low tan precursor dust skirt R 300–400 m; Mach-stem kink beyond ≈150 m ground range → 1–15 s compact reddish-brown cloud ball rising 30–40 m/s; thin dust column to 300–500 m, detached → 15 s–4 min cap to 2.4 km AGL, Ø 0.9 km, red-brown → grey-white. Palette: flash #F4F8FF → #FFE08A → #FF9A3C → #B5401E; cloud #7A3B22 → #8C8278 → #C9C4BC; dust #C8B28E.

**Blurb RU:** B61-12 — американская авиабомба с управляемым хвостовым блоком и выбираемой мощностью: длина ≈3,7 м, масса ≈374 кг, выпускалась в 2021–2024 гг. Официально мощности засекречены; по независимым оценкам минимальная — около 0,3 кт, максимальная — около 50 кт. Ни одна B61-12 никогда не взрывалась: здесь показана расчётная модель взрыва 0,3 кт, построенная по испытаниям 1950-х годов.
**Blurb EN:** The B61-12 is a US gravity bomb with a guided tail kit and selectable yield: about 3.7 m long, about 374 kg, produced in 2021–2024. Its yields are classified; independent estimates put the lowest setting near 0.3 kt and the highest near 50 kt. No B61-12 has ever been detonated, so this is a modelled 0.3 kt burst based on 1950s test data.

### 2.9 "Little Boy" (Hiroshima, 6 Aug 1945) — dossier #9, **game order 10**

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Release, fall | 08:15:17 JST from ≈9,450 m; fall 43–44 s → burst ≈08:16 | MEASURED / small DISPUTE | https://ahf.nuclearmuseum.org/ahf/key-documents/tibbets-hiroshima/ ; https://www.osti.gov/opennet/manhattan-project-history/Events/1945/hiroshima.htm | Fall 44 s |
| Burst height | **600 m** (DS02; 580 m = design fuze setting / DS86) | DISPUTED → resolved | https://www.rerf.or.jp/en/glossary/ds02-en/ ; DOE DS02 summary https://www.energy.gov/sites/default/files/2014/07/f17/New_Atomic_Bomb_Radiation_Dosimetry_System.pdf | burst_height_m 600 |
| Yield | Estimates 12–18 kt; LANL 1985 15 kt ± 20 %; **DS02 16 kt** | DISPUTED → **16 kt** (merge §0.1, needed for strict order) | https://en.wikipedia.org/wiki/Little_Boy ; RERF | yield 16 kt; UI «≈16 кт (оценки 12–18)» |
| Size, mass | 3.0 m × Ø 0.71 m, 4,400 kg | MEASURED | Wikipedia; https://prologue.blogs.archives.gov/2020/08/06/little-boy-the-first-atomic-bomb | Model |
| Paint | Not documented; B&W photos show a dark semi-gloss finish → dark olive-drab/gunmetal, white stencils | ESTIMATED | NARA/AEC photos | Model |
| Fireball | R_bw ≈100 m at ≈15 ms; t₂ 0.14 s; **R_max 190 m (Ø 380 m) at ≈1 s** (Hiroshima City: ">200 m radius at 1 s"; the "280 m" figure is Nagasaki's) | DISPUTED → resolved | Glasstone ch. 2; https://www.city.hiroshima.lg.jp/english/peace/1029920/1009857.html | Fireball |
| Shocks at Enola Gay | Two strong jolts (direct + ground-reflected) at 18.5 km slant; a "smaller third" only in the 509th narrative | DISPUTED → 2 | Caron oral history https://ahf.nuclearmuseum.org/voices/oral-histories/bob-carons-interview | Optional aircraft view |
| Cloud colours | White outside, purplish-black inside, fiery red core; low boiling dark layer spreading over the city "like bubbling molasses" | MEASURED (eyewitness) | Caron; 509th history | Palette |
| Cloud rise | 1.6 km @ 18 s, 3.4 @ 42 s, ≈4 @ 60 s, 6.1 @ 90 s (NARA caption "20,000 ft"), 9 @ 3 min, 12.5 km @ 10 min (optional overshoot 13.5 km at 6–8 min); cap 4.5 km | ESTIMATED (fits all observations) / DISPUTED (8–17 km in sources) | NARA 542192 caption; 509th; Ogawa et al. 2010 photo analysis; Romps et al. 2026 (≥11.3 km, via press https://www.sciencealert.com/?p=227041) | Rise keyframes |
| Black rain | From ≈20 min–1 h, heaviest 09:00–11:00, to the NW; heavy-rain oval 19 × 11 km | MEASURED (surveys) | https://pmc.ncbi.nlm.nih.gov/articles/PMC6937943 | Optional late phase |
| Firestorm | Fires within minutes, firestorm over ≈11 km² | MEASURED | DOE OpenNet | Optional; the tall pyrocumulus photo is hours later, **not** the 10-min cloud |
| Crater | None | MEASURED | — | — |

**Key frames:** −44 s dark olive bomb, box tail → 0–1 ms point flash, white-out ("pika") → 1–14 ms opaque shell to R ≈85 m, brightness dip → ≈15 ms breakaway → 0.14 s second maximum, brilliant white R ≈135 m, surface ≈7,700 °C → 0.2–3 s main heat pulse; shock reaches ground ≈1.2–1.5 s; Mach stem beyond ≈0.7 km; R 190 m at 1 s; white → yellow → orange → 1–10 s rising (50–80 m/s), roiling; brief Wilson shell in humid air; shock ring visible on haze → 10–60 s toroidal reddish-brown/purplish ball, red core; dark dust/smoke column drawn up; dark layer spreads over the city → 1–3 min white cauliflower cap, grey stem, black-brown base → 3–10 min cap flattens at 12.5 km, Ø 4.5 km.

**Blurb RU:** 6 августа 1945 г. в 8:15 бомбардировщик B-29 «Энола Гэй» сбросил «Малыша» на Хиросиму; примерно через 44 с бомба взорвалась на высоте около 600 м. Мощность — около 16 кт (оценки от 12 до 18 кт); через секунду огненный шар достиг почти 400 м в поперечнике, а облако за несколько минут поднялось примерно на 12 км. Пожары и «чёрный дождь» последовали в первые часы; к концу 1945 г. погибли около 140 000 человек.
**Blurb EN:** At 8:15 on 6 August 1945 the B-29 Enola Gay dropped Little Boy on Hiroshima; about 44 seconds later it exploded roughly 600 m above the city. The yield was about 16 kt (estimates range from 12 to 18 kt); within a second the fireball grew to nearly 400 m across, and within minutes the cloud rose to about 12 km. Fires and "black rain" followed within hours, and about 140,000 people had died by the end of 1945.

### 2.10 Upshot-Knothole "Grable" (25 May 1953) — dossier #10, **game order 9**

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Date, place | 25 May 1953, 08:30 PDT; Frenchman Flat (dry lake), 938 m elevation; sun ≈34° up in the E | MEASURED / COMPUTED | DNA 6014F https://www.govinfo.gov/content/pkg/GOVPUB-D15-PURL-gpo222768/pdf/GOVPUB-D15-PURL-gpo222768.pdf ; DASA-1251 extract https://archive.org/download/DnaEm1CapabilitiesOfNuclearWeapons/DASA%201251%20EXTRACT%20New%20Mexico%20and%20Nevada%20nuclear%20test%20neutron%20induced%20activity%20and%20fallout%20examples.pdf | Morning scene |
| Delivery | M65 280 mm "Atomic Annie" (≈77 t, 625 m/s), fired >10 km S of GZ; 19 s flight | MEASURED | https://nuclearweaponarchive.org/Usa/Tests/Upshotk.html ; NNSS fact sheet https://nnss.gov/wp-content/uploads/2023/04/DOENV_776.pdf | Gun prop |
| Shell | Ø 280 mm × 1.38 m, 364 kg; paint undocumented (olive drab DESIGN) | MEASURED | NWA; https://en.wikipedia.org/wiki/Upshot%E2%80%93Knothole_Grable | Model |
| Yield, HOB | 15 kt; **160 m (524 ft)** air burst (scaled 65 m/kt^(1/3): low) | MEASURED | DASA-1251; DNA 6014F | yield; HOB |
| Thermal timings | t_min **13.3–14.9 ms**; t₂ **122–138 ms** | MEASURED | DASA-1251 data sheet | t_min 14 ms, t₂ 130 ms |
| Fireball | R 170 m at t₂, ≈180 m by ≈1 s; early growth R ≈ 510·t^0.4 m | MEASURED / ESTIMATED | DASA-1251; EM-1 fireball paper | Fireball |
| Reflected shock | Shock hits ground at GZ ≈55 ms; reflected shock meets fireball bottom ≈0.07 s; bottom flattens by ≈0.10 s; fireball nearly touches ground, no contact fallout | MEASURED (photographic) | EM-1 "Fireball shape as a height-of-burst diagnostic"; photo `grable_reflected_shock.jpg` | Fireball shape |
| Precursor, Mach stem | Precursor confirmed (dust-laden front ahead of the main wave, heavy drag damage); Mach stem from ≈160 m ground range | MEASURED (qualitative) / ESTIMATED (geometry) | DNA 6014F §4.1.8; Glasstone §3.79–3.85 https://www.atomicarchive.com/resources/documents/effects/glasstone-dolan/chapter3.html | Precursor ON to r ≈1.5 km, dust wall 30–100 m |
| Cloud | Top 4.1 km @ 1 min, 6.1 @ 2, 7.4 @ 3, 8.4 @ 4, 9.1 @ 5, 9.6 @ 6, **9.7 km AGL @ 7 min**, 10.0 @ 9 min; bottom 6.1 km AGL; cap ≈3.5 km, sheared NE by 90–140 mph winds aloft; three ice caps and an "ice skirt" | MEASURED | DASA-1251 Fig. 105, Table 31; DRI report https://www.osti.gov/servlets/purl/1821223 ; NNSA photo UK-53-128 | Rise keyframes |
| Eyewitness | Fireball "not as colorful as in previous shots and dissipated very rapidly" | MEASURED | DRI 2020 (Bullock 1953) | Shorter, less saturated glow |
| Crater | None | MEASURED | DASA-1251 | — |

**Key frames:** 0–1 ms point flash 160 m up → 1–14 ms sphere 32 m @ 1 ms, 81 m @ 10 ms, darkens to opaque mottled orange-red at the minimum → 15–55 ms rebrightening; lakebed "popcorns", smoke screens fume → ≈55 ms shock reaches ground → 70–100 ms pale reflected-shock dome rises under the ball, flattens its bottom → 0.13 s white ball R ≈170 m almost touching the ground → 0.13–3 s Mach stem, ragged turbulent precursor dust wall 30–100 m high races to ≈1.5 km; smoke-rocket trails kink → 1–5 s yellow → orange, rising; less colourful, fades faster → 5–30 s orange-brown cap with glowing orange ring, thick dark-brown dust stem, white/grey ground skirt → 1–9 min 4.1 → 9.7 km, cap brown → white, sheared NE, three ice caps; dust storm over the flat.

**Blurb RU:** 25 мая 1953 года 280-мм пушка M65 «Atomic Annie» выстрелила ядерным снарядом мощностью 15 кт над пустыней Френчмен-Флэт в Неваде. Через 19 секунд снаряд взорвался в 160 м над землёй, более чем в 10 км от орудия; это единственный ядерный снаряд, когда-либо выпущенный из артиллерийской пушки. Низкий взрыв над раскалённой пустыней породил «предвестник» — пыльную ударную волну, которая обогнала основную и разбила технику сильнее, чем ожидали.
**Blurb EN:** On 25 May 1953 the 280 mm M65 "Atomic Annie" cannon fired a 15-kiloton nuclear shell over Frenchman Flat, Nevada. The shell burst 19 seconds later, 160 m above the ground and more than 10 km from the gun; it is the only nuclear shell ever fired from an artillery cannon. The low burst over hot desert produced a "precursor", a dust-laden shock front that outran the main blast wave and wrecked vehicles worse than expected.

### 2.11 "Trinity" ("Gadget", 16 July 1945) — game order 11

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time, light | **05:29:45 MWT**, pre-dawn: sun −7.5° (az. 58°, ENE), sunrise 06:07; broken cloud overhead after storms | MEASURED / COMPUTED | https://nuclearweaponarchive.org/Usa/Tests/Trinity.html ; https://www.lanl.gov/media/publications/national-security-science/0720-the-trinity-test ; NOAA algorithm | Night-to-dawn scene; cloud top lit pink-gold ≈20 min after |
| Site | Jornada del Muerto, 1,409 m elevation; 30.5 m steel tower with shed; tower vaporised | MEASURED | DASA-1251; https://en.wikipedia.org/wiki/Trinity_(nuclear_test) | Tower prop |
| Yield | **21 kt** official; LANL 2021 24.8 ± 2 kt (https://arxiv.org/abs/2103.06258); Hanson 2016 22.1 kt; Norman 2026 preprint 9.1 ± 4.5 kt (core fissions only, not reviewed); blast-gauge ≈10 kt reads low | DISPUTED → resolved | DOE OpenNet https://www.osti.gov/opennet/manhattan-project-history/Events/1945/trinity.htm ; LA-6300-H | yield 21 kt; UI note 24.8 |
| Device look | Bare, unpainted sphere ≈1.5 m with cables, in a sheet-metal shed; ≈4 t (one secondary source) | ESTIMATED | dossier; secondary | Model |
| Radius-time (Taylor table) | 0.10 ms 11 m; 0.65 ms 31 m (ground contact); 1.08 ms 39 m; 1.93 ms 49 m; 4.61 ms 67 m; 15 ms 106 m; **25 ms 130 m**; 34 ms 145 m; **53 ms 175 m**; 62 ms 185 m; Mack fit R = 564·(t + 0.0004)^0.4 m | MEASURED | G. I. Taylor 1950 (table https://www.phys.uconn.edu/~rozman/Courses/P2200_25F/downloads/trinity-test.data ); LA-6300-H §9 | Fireball keyframes (replaces 02's 138/200/218 m) |
| Early features | Spikes below the equator (rope-trick-like) 0.1–2 ms; blisters; bright lumpy ground **skirt** from ≈2 ms; smooth **Mach belt** 10–100 ms; rising "curtain" line 3–11 ms | MEASURED | LA-6300-H §9 (Mack) | All rendered (dossier's "not confirmed" removed) |
| Minimum, late size | Ball falls behind the shock at ≈16 ms (105 m); t₂ ≈0.16 s; R ≈**300 m** at 1–2 s (DOE: ≈600 m across at 2 s); rise begins at 2 s; neck and vortex ring at 3.5 s; top at 57 m/s to 1.5 km at ≈26 s | MEASURED | LA-6300-H; DOE OpenNet | Fireball/cloud keyframes |
| Colours | Violet/blue-white flash → white → yellow → orange-red → dull red → **violet-purple radioluminescent glow ≈30–35 s**; green mainly a welding-glass artefact | MEASURED (eyewitness) → sequence resolved | AHF eyewitnesses https://ahf.nuclearmuseum.org/ahf/key-documents/trinity-test-eyewitnesses/ ; Morrison, McMillan accounts | Palette |
| Cloud | DASA curve: 2.1 km @ 1 min, 3.3 @ 2, 5.3 @ 4, 6.9 @ 6, 8.2 @ 8, 9.5 @ 10, 10.1 @ 10.3 min → **10.5 km AGL @ 11–12 min**; base 1.8 km; cap 4.5 km; three layers (low dust sheet, mid layer at the 3.8 km AGL inversion, main cap); "14–17 km" (Warren, visual) rejected | DISPUTED → resolved | DASA-1251 Fig. 2; Groves memo https://www.pbs.org/wgbh/americanexperience/features/primary-resources/truman-bombtest/ ; NSA briefing book | Rise keyframes |
| Cloud extras | Hole punched in the overhead cloud deck; two fog rings above the column; red-brown → white | MEASURED (eyewitness) | R. C. Smith; McMillan | Effects |
| Crater | Nested features: inner bowl **Ø 70 m × 1.8 m**, shallow saucer **Ø 350 m × ≤2.5 m**, dark/green trinitite disc **Ø 600 m**; "5 ft × 30 ft" unsupported | DISPUTED → resolved | Groves memo (130 × 6 ft bowl); DASA-1251 (1,100 ft × 9.5 ft); 28 h aerial photo with scale bar | Crater layers |
| Sound | 27 s at 9.1 km (Farrell's "≈40 s" is the 16 km base-camp figure: Fermi ≈40 s, Morrison ≈45 s) | DISPUTED → physics | eyewitnesses | Physics module |

**Key frames:** pre-dawn blue-violet sky, tower with shed → 0–0.65 ms violet/blue-white point; scene from twilight to "brighter than midday"; ball 11 → 31 m, touches the ground; spikes, blisters → 1–11 ms smooth mottled hemisphere 37 → 67 m; rising curtain line; lumpy skirt and Mach belt from ≈2 ms → 11–30 ms 106 m @ 15 ms, 130 m @ 25 ms; dims to opaque orange-red at ≈16 ms → 30 ms–1 s dark NO₂ front behind the shock; second maximum ≈0.16 s; hemisphere grows to R ≈300 m by 1–2 s; overhead clouds lit red-orange, hole opens → 2–15 s rises, yellow → orange cauliflower; neck and vortex ring at 3.5 s; left-handed twisted stem; two fog rings → 15–35 s dull red, top 1.5 km at 26 s; violet glow ≈30–35 s → 1–12 min red-brown → white, 2.1 → 10.5 km, pause at the inversion, three layers.

**Blurb RU:** 16 июля 1945 года в 05:29 по местному времени, ещё до рассвета, в пустыне Нью-Мексико на 30-метровой стальной башне взорвали первое в истории ядерное устройство — «Gadget». Официальная мощность — 21 кт (анализ LANL 2021 года даёт 24,8 ± 2 кт). Вспышка на секунды осветила горы ярче дня, облако поднялось выше 10 км. Жар оплавил песок в зелёное стекло, которое назвали тринититом.
**Blurb EN:** On 16 July 1945 at 05:29 local time, before dawn, the first nuclear device in history, the "Gadget", was set off on a 30 m steel tower in the New Mexico desert. Its official yield is 21 kt; a 2021 Los Alamos re-analysis gives 24.8 ± 2 kt. For a few seconds the flash lit the mountains brighter than day, and the cloud rose more than 10 km. The heat fused the desert sand into green glass, later named trinitite.

### 2.12 Crossroads "Baker" (25 July 1946, Bikini lagoon) — game order 12

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time, weather | 08:35 local (24 Jul 21:35 GMT); sun 39° ENE; very humid, wind 2.5–3 m/s from SE, scattered cumulus | MEASURED / COMPUTED | DASA-1251 Baker sheet https://archive.org/download/DnaEm1CapabilitiesOfNuclearWeapons/DASA%201251%20Best%20fallout%20patterns%20EXTRACTS%20note%20Bikini%20distance%20scales%20for%20other%20Castle%20tests%20like%20Koon%20are%20massively%20in%20error.pdf ; Glasstone 1950 | Scene |
| Yield | **23 kt** (21 kt older captions) | DISPUTED → resolved | DASA-1251; https://en.wikipedia.org/wiki/Operation_Crossroads ; https://nuclearweaponarchive.org/Usa/Tests/Crossrd.html | yield 23 kt |
| Depth | Device −27 m under LSM-60; lagoon **55 m** deep (70 m: no source) | DISPUTED → resolved | DASA-1251; NPS https://npshistory.com/series/archeology/scrc/37/chap2.htm | burst −27 m, water 55 m |
| Device | Fat Man-type "Helen of Bikini" in a caisson, never visible; info-card model 3.25 × 1.52 m, 4,670 kg, mustard yellow with black seam sealant (by analogy) | MEASURED / ESTIMATED | https://en.wikipedia.org/wiki/Fat_Man | Info card only |
| Light | No fireball in air; underwater glow "through a ground-glass screen" for a few ms; glint at the spray-dome top | MEASURED (qualitative) | Glasstone & Dolan 1977 §2.64 https://www.fourmilab.ch/etexts/www/effects/eonw_2.pdf | No white-out or thermal pulse |
| Slick / crack / dome | Dark ring at ≈1,500 m/s then white "crack" disc; spray dome from ≈4 ms at ≈760 m/s | MEASURED | G&D 1977 §2.65–2.68 | Water surface FX |
| Wilson cloud | Hemisphere ≈1.6 km wide, ≈0.8 km tall; visible from 0.5 s, full at 1.2–1.5 s, clears from the sea upward by 3–3.5 s; remnant sheet at cumulus base fades by ≈15 s | MEASURED / timing DISPUTED → resolved | G&D §2.50; Wikipedia; NOL slides | Wilson veil |
| Column | Hollow, ≈600 m wide (shrinks to ≈450 m by 33 s), walls ≈90 m (inference), ≈1.8 km high inside the head; ≈1 million t of water (Glasstone; "2 Mt" includes spray and sand) | MEASURED / ESTIMATED | G&D 1977 §2.68; Glasstone 1950 §4.66 https://archive.org/download/DnaEm1CapabilitiesOfNuclearWeapons/Glasstone%20The%20Effects%20of%20Atomic%20Weapons%201950%20EXTRACT.pdf | Column mesh/volume |
| Top / head | Top 640 m @ 0.75 s, 1.04 km @ 2.5 s, 1.14 km @ 5 s, 1.4 km @ 10 s, 1.74–1.86 km @ 30 s, **2.32 km @ 60 s**, ≈3.0 km max; head Ø 1.5 km @ 5 s → 2.6 km @ 60 s; no stem, never a classic mushroom | MEASURED (DASA Fig. 5) | DASA-1251 | Keyframes |
| Collapse | Spike jets out of the column 3–15 s; from 12 s dark "mammillary" lobes and rain curtains; rain ring 0.6–0.9 km at 60–150 s | MEASURED | Glasstone 1950 §4.64, §4.69 | Falling lobes |
| Wave | 28.7 m **trough-to-crest** at 305 m, 11 s (crest ≈+14 m); H·R ≈ 8,730 m²; 14.3 m @ 610 m (23 s), 7.3 m @ 1.22 km (48 s), 4.0 m @ 2.44 km (101 s); >20 rings at 5 min | MEASURED | Glasstone 1950 §4.40–4.46 | Wave ring |
| Base surge | Starts 10–12 s at R ≈320–370 m; **R(t) = (3,600 + 3,700·t)/(90 + t) m** (10–200 s): 0.92 km @ 30 s, 1.44 @ 60 s, 2.14 @ 2 min, 2.49 @ 3 min, ≈2.6 km @ 4 min; height 130 m @ 10 s → 300 m @ 60 s → 550 m from 140 s; final Ø 5.1 km; lifts off ≈210 s; grey stratocumulus deck, rain ≈1 h | MEASURED | Glasstone 1950 Table 4.71; Strope report https://archive.org/download/DnaEm1CapabilitiesOfNuclearWeapons/Baker%20underwater%20nuclear%20explosion%20fallout%20pattern%20report%20by%20Walmer%20aka%20Jerry%20Strope.pdf | Base-surge ring (+U·t drift) |
| Crater (lagoon floor) | 1,000 × 550 m, 7.6 m deep; invisible from the surface | MEASURED | DASA-1251; NPS | Not rendered |
| Ships | Arkansas capsized at once; Saratoga, Nagato and others sank; 8–10 total | DISPUTED (count) | NWA; Wikipedia | UI "several" |

**Key frames:** (camera 25 km; sun 39° ENE) 0–20 ms faint blue-white glow under the water, no landscape flash → 4–100 ms dark slick ring at 1,500 m/s, white crack disc, white spray dome with a glint → 0.01–1 s hollow white-grey column punches through, top 640 m at 0.75 s, ragged crown → 0.5–3.5 s smooth milky Wilson hemisphere Ø 1.6 km hides the column, thins bottom-up → 3–10 s column 600 m wide with grey-brown sediment streaks, cauliflower head 1.5 km wide; sideways spike jets → 9–30 s first wave ring ±14 m at 305 m (11 s), wave train → 10–35 s dark lobes and rain curtains; brilliant white base surge born at 320–370 m, 37 m/s → 12–150 s head rains out, top 2.32 km at 60 s, ≈3 km max → 10–240 s base surge to Ø 5.1 km, 550 m tall, doughnut with clearing centre → 3.5–60 min lifts into a grey stratocumulus deck with rain shafts. No orange/red/brown fire colour at any stage.

**Blurb RU:** 25 июля 1946 года в лагуне атолла Бикини заряд типа «Толстяк» мощностью 23 кт взорвали на глубине 27 м под десантным кораблём LSM-60. Взрыв выбросил полый столб воды шириной около 600 м и высотой до ~1,8 км; на пару секунд его скрыло белое конденсационное облако Вильсона диаметром около 1,6 км. Волна высотой 29 м (от подошвы до гребня) и радиоактивная «базисная волна» водяного тумана накрыли флот-мишень. Затонули линкор «Арканзас», авианосец «Саратога» и ещё несколько кораблей.
**Blurb EN:** On 25 July 1946, in Bikini lagoon, a 23-kiloton Fat Man-type charge was fired 27 m underwater beneath the landing ship LSM-60. It threw up a hollow column of water about 600 m wide and up to ~1.8 km high, hidden for a couple of seconds by a white, mile-wide Wilson condensation cloud. A 29 m (trough-to-crest) wave and a radioactive "base surge" of mist swept the target fleet, sinking the battleship Arkansas, the carrier Saratoga and several other ships.

### 2.13 Plowshare "Sedan" (6 July 1962, NTS) — game order 13

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time, site | 17:00 GMT = 10:00 PDT; Yucca Flat Area 10, 1,316 m MSL; alluvium with ≈7 % water; sun 51° E; clear; cloud drifted N–NNE | MEASURED | PNE-213F https://www.osti.gov/servlets/purl/4728210 ; PNE-203F https://digital.library.unt.edu/ark:/67531/metadc714927/m2/1/high_res_d/metadc714927.pdf ; DNA 6029F https://www.sonicbomb.com/content/atomic/docs/dna/1961_DNA_6029F_PLOWSHARE_Gnome_and_Sedan.pdf | Scene |
| Yield, depth | 104 kt (thermonuclear, fission <30 %); **−194 m** (635 ft) | MEASURED | same; https://en.wikipedia.org/wiki/Sedan_(nuclear_test) | yield; burst −194 m |
| Device | Ø 0.43 × 0.965 m, 212 kg (158 kg in one source); never visible | MEASURED / mass DISPUTED → 212 kg | Wikipedia (Sublette) | Info card |
| Light | No fireball; incandescent gas glow through the cracks at venting, ≈1–2 s, salmon-orange | MEASURED (qualitative, film frames) | PNE-213F; DNA 6029F; refs 02–03 | Venting glow only |
| Ground motion | Shock at surface ≈0.24 s (spall ≈32 m/s); gas re-accelerates the surface from ≈1.3 s to ≈40 m/s by 2 s | MEASURED/derived | https://nuclearweaponarchive.org/Library/Effects/UndergroundEffects.html ; G&D §2.91–2.92 | Terrain deformation |
| Dome | ≈90 m high × 180–250 m wide at ≈3 s; vents 3.0–4.0 s | MEASURED | PNE-213F; DNA 6029F | Dome keyframes (8 m @ 0.5 s, 20 @ 1.0, 52 @ 2.0, 90 @ 3.0 s interpolated) |
| Ejecta | Column to ≈610 m (≈12–15 s); missiles to 1.7 km with splash craters up to ≈20 m | MEASURED / timing ESTIMATED | DNA 6029F; PNE-217P https://www.osti.gov/servlets/purl/4715158 | Ejecta fountain, cream-white streamers |
| Base surge | ≈4 km crosswind, 3.2 km upwind (circle ≈8 km wide); timing ESTIMATED (≈1 km @ 40–60 s, 2 km @ 1.5–2 min, 3 km @ 3 min, final @ 4–6 min) | MEASURED (extent) / ESTIMATED (timing) | DNA 6029F; Wikipedia; G&D Fig. 2.97 | Tan dust ring |
| Cloud | **3.7 km AGL** (12,000 ft) stopped by an inversion; "10,000 / 16,000 ft" plumes are MSL; UPI "15,000 ft" press; no cap; dust tower 1.5–2 km wide at 6 min | MEASURED / datum DISPUTED → resolved | PNE-203F; DNA 6029F | Cloud |
| Crater | Apparent Ø **370 m** at original ground (lip crest ≈390–400 m; "1,280 ft" = lip/rounded), depth **98 m**, lip 6–30 m, radial ejecta rays 0.5–1.7 km; ≈11 million t (12 million short tons) | MEASURED / DISPUTED → resolved | NRHP https://npgallery.nps.gov/NRHP/GetAsset/NRHP/94000183_text ; G&D Fig. 6.10; DOE/NV-712 | Crater mesh |
| Seismic | ML 4.75 | MEASURED | PNE-213F | Camera shake |

**Key frames:** (better at 8–15 km) 0–0.24 s nothing → 0.24–1.3 s ground jump: a 400–600 m disc of dust and bushes lifts into a thin tan haze → 1.3–3 s smooth pale-tan dome to 90 m × 215 m, radial cracks with dust → 3–4.5 s dome bursts; salmon-peach glow through the cracks for 1–2 s; spiky "bush" → 4–15 s dark grey-brown column with dozens of cream-white ballistic streamers, top ≈610 m; blocks to 1.7 km → 10–40 s fallback; beige-grey base surge born, 100–300 m tall, 30–50 m/s → 40 s–6 min surge to ≈4 km radius; grey-brown lumpy dust tower to 3.7 km AGL by 5–6 min, flattening under the inversion → afterwards pale-tan funnel crater 370 m × 98 m with hummocky lip and rays. No fireball, white-out or condensation cloud.

**Blurb RU:** 6 июля 1962 года на Невадском полигоне по программе мирных ядерных взрывов «Плаушер» термоядерный заряд мощностью 104 кт взорвали на глубине 194 м в пустынном грунте. За 3 секунды земля вспучилась куполом высотой около 90 м, затем сквозь трещины вырвались раскалённые газы, и в воздух взлетело около 11 млн тонн грунта. Осталась воронка «Седан» диаметром около 370–390 м и глубиной 98 м — крупнейший рукотворный кратер в США.
**Blurb EN:** On 6 July 1962, at the Nevada Test Site, the Plowshare peaceful-explosions programme fired a 104-kiloton thermonuclear charge buried 194 m deep in desert alluvium. Within 3 seconds the ground swelled into a dome about 90 m high, then glowing gases burst through and some 12 million short tons (≈11 million tonnes) of earth were hurled skyward. It left Sedan Crater, about 370-390 m across and 98 m deep: the largest man-made crater in the United States.

### 2.14 Ivy "King" (Mk 18, 16 Nov 1952) — game order 14

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Date, place | 16 Nov 1952 11:30 local (15 Nov 23:30 GMT); over reef/lagoon 610 m N of Runit, Enewetak; almost cloudless with a few low cumulus | MEASURED | DNA 6036F https://archive.org/stream/DTIC_ADA128082/DTIC_ADA128082_djvu.txt ; https://nuclearweaponarchive.org/Usa/Tests/Ivy.html | Midday tropical scene |
| Yield | 500 kt, largest US pure-fission explosion ("550 ± 20" not found) | MEASURED | DNA 6036F; NWA; https://en.wikipedia.org/wiki/Ivy_King | yield |
| Burst | Free-fall from a B-36H at 12.2 km; **451 m** (20 ft low); scaled 57 m/kt^(1/3) → strong Mach stem over water | MEASURED | DNA 6036F p. 204 | HOB 450 m |
| Bomb | Mk 18 (Mk 6-type casing): 3.25 m × Ø 1.52 m, 3,900 kg; paint undocumented → Mk 6 olive drab with yellow bands (DESIGN, labelled reconstruction) | MEASURED / DESIGN | https://nuclearweaponarchive.org/Usa/Weapons/Allbombs.html ; Mk 6 museum photo | Model |
| Fireball | **R ≈0.70 km** at 5–6 s (range 0.66–0.80 km); larger than the HOB, so the lower part flattens on the sea and glares; t_min 54 ms, t₂ 0.64 s | ESTIMATED (merge §0.4.11) | Glasstone ch. 2; techniques A2 | Fireball |
| Observers | Heat felt at once at 18 km (Parry Island); shock after ≈45 s, "like a nearby 90 mm gun" | MEASURED (eyewitness) | DNA 6036F p. 204 | Check for the physics module |
| Condensation | "Cloud-chamber effect clearly visible"; lit horizontal condensation layers; circular shock scar in the cumulus deck | MEASURED (observed, photo XX-42) | DNA 6036F; NNSA photo | Wilson dome/discs 0.5–5 s, R 1.2–2 km |
| Cloud | 8.5 km @ 1 min (photogrammetry); ≈20 km @ ≈4 min; **23 km** final (75–76 kft) @ 8–10 min; base 12 km; tropopause 17.7 km | MEASURED / DISPUTED → resolved (19.8/20.4 km are earlier-time figures) | Castle Project 9.1 p. 8 https://rminucleardocs.icaad.ngo/api/files/1610649231735rgo5hl67jkf.pdf ; Hubert & Machta 1953 https://rminucleardocs.icaad.ngo/en/entity/tlii5dtbfif?page=29 | Rise keyframes |
| Cap | **D(t) = 3.4 km·(t/1 min)^0.91**: 3.4 @ 1, 12 @ 4, 27 km @ 10 min | MEASURED (1 and 10 min) / interpolation | Castle 9.1 | Cap growth |
| Stem | Thin reddish-brown to grey spray/vapour stem (≈1/8 of cap width) | MEASURED (photos) | refs | Stem |
| Ground | No crater; brush fires on nearby islets, seawater 400 m inland on Runit | MEASURED | DNA 6036F pp. 204–205 | Optional |

**Key frames:** 11:30, high sun, turquoise reef → 0–50 ms blue-white flash, exposure crush → ≈50 ms dip, orange-red shell → 0.05–0.64 s second maximum, ball ≈1 km wide; lower edge hits the sea by ≈1 s: glaring contact patch, white spray and Mach ring → 0.5–5 s bright condensation dome and discs R 1.2–2 km; cumulus lit yellow; shock scar ring in the cumulus → 5–6 s max ≈1.4 km wide, flattened bottom, white → yellow-orange → 8–30 s rises ≈100 m/s, orange → red torus, red-brown top, thin reddish stem → 30–60 s orange glow inside a brown cap, 8.5 km / 3.4 km wide at 60 s → 1–4 min ≈20 km, cap 12 km, brown-grey → white-grey → 4–10 min 23 km, cap 27 km, streaks W/SE/SW.

**Blurb RU:** Ivy King — самый мощный взрыв бомбы деления (без термоядерной ступени) в истории США: 500 килотонн. 16 ноября 1952 года бомбардировщик B-36 сбросил бомбу Mk 18 над рифом атолла Эниветок, и она взорвалась на высоте около 450 м. Облако поднялось примерно до 23 км, а ударная волна дошла до наблюдателей в 18 км примерно через 45 секунд.
**Blurb EN:** Ivy King was the most powerful pure-fission explosion the United States ever set off: 500 kilotons. On 16 November 1952 a B-36 dropped a Mk 18 bomb over the reef of Enewetak Atoll, and it burst about 450 m up. The cloud climbed to about 23 km, and the blast reached observers 18 km away roughly 45 seconds later.

### 2.15 B83 (up to 1.2 Mt), modelled laydown surface burst — game order 15

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Service | LLNL; first production June 1983; ≈650 built; still in stockpile in 2026, slated for retirement | MEASURED | https://nuclearweaponarchive.org/Usa/Weapons/B83.html ; https://en.wikipedia.org/wiki/B83_nuclear_bomb ; CRS https://www.everycrsreport.com/files/2026-04-01_IF10519_f55adb1df8e4e3077ef804fdccba21979c3b7574.html | Info card |
| Testing | Never detonated in the atmosphere; first underground test 15 Dec 1984 | MEASURED | Hill AFB fact sheet; NWA | Badge «условная модель» |
| Yield | Variable, "low kt" to 1.2 Mt | MEASURED (public figure) | NWA; UCS fact sheet https://ucs-documents.s3.amazonaws.com/nuclear-weapons/b83-fact-sheet.pdf | 1,200 kt |
| Size, mass | 3.67 m × Ø 0.46 m, ≈1,100 kg (2,400–2,465 lb) | MEASURED | NWA; Hill; Allbombs | Model |
| Look | Slim white body, ogive nose ending in stepped frangible rings, two lugs, short tail with 4 swept fins; trainers/museum gloss white; 1983 test body red-orange | MEASURED (photos) | refs/15_b83 | Gloss white, small black stencils (dossier "undocumented" corrected) |
| Parachute | 14 m (46 ft) Kevlar-nylon ribbon canopy, three 4 ft pilot chutes; slows Mach 0.93 → ≈20 m/s | MEASURED | NWA (Sandia); Wikipedia | Delivery animation (colour DESIGN) |
| Burst | Laydown → contact surface burst, 0 m; delay 10–30 s (DESIGN, real delay not public) | DESIGN | — | HOB 0 |
| Fireball | Hemisphere R ≈1.3 km at ≈9 s; breakaway ≈750 m at ≈0.1 s; t_min 77 ms, t₂ 0.94 s | ESTIMATED | techniques A2 | Fireball |
| Cloud | **Top 19.5 km, base 11.5 km at 8–10 min**; ≈7.5 km @ 60 s, ≈15 km @ 3 min; cap Ø 6 km @ 1 min → ≈20 km @ 4 min → 30 km @ 10 min; thick dark-brown dirty stem 3–4 km, skirt ≈10 km | ESTIMATED (merge §0.4.8; Castle Nectar 1.69 Mt analogue measured: 21.9 km top, 7.6 km @ 1 min) | Castle 9.1 pp. 8, 27; G&D 9.96 | Cloud |
| Crater | Ø ≈300 m × 75 m, lip crest Ø 380 m, lip 19 m, ejecta blanket Ø ≈660 m (±30 %, dry soil) | ESTIMATED | Glasstone §6.09, §6.71, §6.74 https://www.atomicarchive.com/resources/documents/effects/glasstone-dolan/chapter6.html | Crater mesh |

**Key frames:** low aircraft, white bomb, 3 pilot chutes, 14 m ribbon canopy, bomb lands on its rings and lies under the collapsing canopy; delay → 0–0.1 s ground-level blue-white flash, hemispherical shock → ≈0.1 s dip, red-orange hemisphere ≈1.5 km → ≈1 s second maximum, blinding white dome ≈2 km; ground smokes; dense dust skirt → 1–10 s dome to ≈2.6 km wide at ≈9 s, yellow-white → orange, dark dust fringe; optional condensation dome 3–5 km in humid air → 10–60 s orange-red → brown torus lifts off; thick dark-brown afterwind stem; cap ≈7.5 km / 6 km wide at 60 s → 1–4 min ≈15 km, cap ≈20 km → 4–10 min top 19.5 km, cap 30 km, dirty grey-brown → aftermath crater 300 × 75 m. At 55 km: ground tremor first, then a long deep boom.

**Blurb RU:** B83 — самая мощная бомба, остававшаяся в арсенале США в 2020-х годах: мощность регулируется, максимум 1,2 мегатонны. В атмосфере её не взрывали ни разу (заряд испытывали только под землёй), поэтому здесь показана расчётная модель: бомба опускается на 14-метровом парашюте, ложится на землю и взрывается с задержкой. По формулам Гласстона такой наземный взрыв оставил бы воронку около 300 м в поперечнике.
**Blurb EN:** The B83 is the most powerful bomb still in the US arsenal in the 2020s, with a variable yield of up to 1.2 megatons. It has never been exploded in the atmosphere (its nuclear explosive was tested only underground), so this is a calculated model: the bomb descends on a 14-metre parachute, lies on the ground and detonates after a delay. Glasstone's scaling gives such a surface burst a crater roughly 300 m across.

### 2.16 RDS-37 (22 Nov 1955, Semipalatinsk) — game order 16

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Timing | Take-off 08:34; **release 09:47** (not the burst time); 20 Nov attempt aborted | MEASURED | «Ядерные испытания СССР», т. I (РФЯЦ-ВНИИЭФ, 1997), pp. 232–237 https://elib.biblioatom.ru/text/yadernye-ispytaniya-sssr_1997/p0_o/ | UI "сброс 09:47" |
| Weather | Solid two-layer overcast 1.5 km thick, top at 10 km; frozen feather-grass steppe; temperature inversion | MEASURED | VNIIEF account; Sakharov via https://blog.nuclearsecrecy.com/2014/01/31/sakharovs-turning-point-first-soviet-h-bomb-test/ | Overcast deck at 8.5–10 km; low winter sun ≤20° |
| Yield | 1.6 Mt (design ≈3 Mt, reduced) | MEASURED | VNIIEF 1997 p. 235 | yield |
| Burst | **1,550 m** (2,000 m: one secondary listing, rejected) | MEASURED → resolved | VNIIEF 1997 p. 234; https://ru.wikipedia.org/wiki/РДС-37 ; https://en.wikipedia.org/wiki/RDS-37 | HOB 1,550 m |
| Carrier | Tu-16A from 12 km; lacquer removed below, dark areas painted white; PG-4083 parachute | MEASURED | VNIIEF 1997 p. 234 | Delivery |
| Bomb | Ø 1.5 m × ≈6.0 m ("up to 7 m"), 5,570 kg; paint undocumented (dark olive-grey DESIGN) | single source / DISPUTED (length) | MilitaryRussia (archive.org copy) | Model labelled approximate |
| Crew observations | At 15 km: heat "stronger than the hottest sunny day"; flash 10–12 s; shock reached the aircraft 224 s after release | MEASURED | VNIIEF 1997 | Flash duration check |
| Fireball | R ≈**1.1 km** at ≈10 s (base ≈0.4–0.5 km above ground); deformation by the reflected shock observed; t_min 86 ms, t₂ 1.07 s | MEASURED (qualitative) / ESTIMATED (size) | VNIIEF 1997 p. 235 | Fireball; underside flattened from ≈2–4 s |
| Colour | Sakharov (≈30 km): blinding yellow-white sphere turning orange in a fraction of a second; huge swirling grey-blue cloud with crimson flashes | MEASURED (eyewitness) | Sakharov memoir | Palette |
| Condensation | "Large regions of condensation"; photo: translucent bell-shaped skirt around the stem (≈0.5 × cap width) and rings | MEASURED | VNIIEF; Wikipedia caption | Wilson dome 0.5–6 s (R 2–3 km); stem skirt 30–120 s |
| Sound | At 35 km: **double** sharp thunderclap; at ≈70 km: ≈3 min, long multiple rumble | MEASURED | VNIIEF 1997 p. 235 | Two cracks 0.5–1 s apart (gap ESTIMATED) |
| Inversion focusing | Damage in 59 settlements, 28,615 m² of glass, windows to ≈200 km; 2 killed (girl in Malye Akzhary; soldier at 36 km) | MEASURED | VNIIEF 1997 p. 237 | Anomalous far-field shock |
| Cloud | "13–14 km at 5–7 min" and "lower boundary 1200–1400 m" (unit slip for 12–14 km) → **base 13 km, top 20 km at ≈8 min**; cap Ø 28 km at 7 min; red-brown → grey-blue | DISPUTED → resolved | VNIIEF 1997; Russian mirror https://legion.wplus.net/others/rds37.shtml | Cloud |
| Dust | Huge long-lived dust column and billowing dust; merged with natural clouds into a lead-black storm cloud | MEASURED | VNIIEF 1997 p. 235 | Late phase |

**Key frames:** grey overcast, frozen steppe; Tu-16 release at 12 km; long parachute descent → 0–0.1 s flash lights the overcast from below, white-out → ≈0.09 s dip → 0.1–1.1 s yellow-white sphere turns orange, ≈1.5 km wide; cloud base glows → 0.5–6 s Wilson dome/discs R 2–3 km; reflected shock flattens the underside; dusty Mach ring and wide skirt on the steppe → ≈10 s max ≈2.2 km wide, base ≈0.5 km up; flash over by 10–12 s → 10–60 s orange-red torus; thin dark twisting dust stem; cap punches the overcast at 8.5–10 km → 30–120 s translucent bell skirt on the stem; rings at the cloud layers → ≈90 s at 35 km two sharp cracks → 2–8 min red-brown cap, top 20 km, base 13 km, 28 km wide at 7 min → 10–30 min lead-black storm cloud drifting (az. ≈70°).

**Blurb RU:** РДС-37 — первая советская двухступенчатая водородная бомба. 22 ноября 1955 года её сбросили с самолёта Ту-16 на парашюте над Семипалатинским полигоном, и на высоте 1550 м она взорвалась с мощностью 1,6 Мт (расчётная мощность около 3 Мт была намеренно снижена). Температурная инверсия отразила ударную волну обратно к земле: пострадали строения в 59 населённых пунктах, погибли два человека.
**Blurb EN:** RDS-37 was the first Soviet two-stage hydrogen bomb. On 22 November 1955 a Tu-16 dropped it by parachute over the Semipalatinsk test site, and it exploded 1,550 m up with 1.6 megatons (the planned ~3 Mt was deliberately reduced). A temperature inversion bent the shock wave back to the ground, damaging buildings in 59 settlements and killing two people.

### 2.17 Ivy "Mike" (1 Nov 1952, Enewetak) — game order 17

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time, light | 07:14:59.4 local (19:14:59.4 GMT, 31 Oct); sun +1.9°, az. 105° (just risen, ESE); scattered cumulus 0.6–2 km | MEASURED / COMPUTED | DNA 6036F; NWA Ivy; Munk & Day 2004 https://tos.org/oceanography/article/ivy-mike | Sunrise scene |
| Yield | 10.4 Mt (fireball yield 11 ± 1 Mt) | MEASURED | NWA; Castle 9.1 | yield |
| Burst | Surface burst in the shot cab on Elugelab (≈3 m above tide); no published HOB → **5 m** | MEASURED (type) / ESTIMATED | NWA; DNA 6036F | HOB 5 m |
| Device | "Sausage": ≈2.03 m × 6.20 m, 82 short tons (74 t) with cryogenic plant, bright unpainted metal; shot cab 26.8 × 14.0 × 18.6 m; 91 m tower; 2.7 km conduit to Boken. **Not a bomb** | MEASURED | NWA; Wikipedia https://en.wikipedia.org/wiki/Ivy_Mike ; photo | Silver cylinder in a building; UI must not say "bomb" |
| Lightning | Five lightning channels from the sea ≈1 km from GZ into the clouds within ≈10 ms; visible ≈5–75 ms | MEASURED (film) | Colvin et al. 1987 JGR https://doi.org/10.1029/JD092iD05p05696 | 5 bolts, 0.005–0.08 s |
| Fireball | Ø ≈4.5 km @ 1 s → **max Ø 5.2 km ("3¼ miles") at ≈3–5 s**; NNSA caption 3½ mi; Wikipedia 2.9–3.3 km radius is a calculator value | DISPUTED → resolved | Film *Operation Ivy* https://archive.org/details/OperationIVY1952 ; NNSA caption | Fireball keyframes |
| Observations | "Like the sun when half-risen"; heat felt at 48–56 km; sharp report then long broken rumble at ships ≈2.5 min | MEASURED (eyewitness) | DNA 6036F; https://time.com/4096424/ivy-mike-history/ | Sound tail |
| Cloud rise | 13 km @ 1 min (11.9 photogrammetry / 14.2 extrapolated), 17 km @ 1.5 min, ≈30 @ 2.5, 33 @ 3.5, 36 @ 5.5 min | MEASURED (preliminary) | Castle 9.1 Table 5.6; Urry memo https://rminucleardocs.icaad.ngo/api/files/1610677074762eb8phoyc5mc.pdf ; DNA 6036F | Rise keyframes |
| Ceiling | **Main top 37 km** (120,000 ft, sextant, constant for ≈1 h); 41 km (135,000 ft) = a single sharp turret sighting → optional; 30 km in the 1954 photogrammetric table | DISPUTED → resolved | Urry memo; NWA; Castle 9.1 | Main top 37 km, optional turret 41 km at 5–15 min |
| Cap | Underside ≈20 km; Ø 9 km @ 1 min → **61 km @ 10 min** → ≈100 km @ 30 min; "100 miles" only eventually (>1 h) | DISPUTED → resolved | Castle 9.1; DNA 6036F | Cap growth |
| Stem | ≈3.5 km @ 1 min, 7.5 km @ 10 min; lower cloud ≈32 km wide at 30 min; "numerous projecting fingers" at the ≈14 km junction | MEASURED (30 min) / ESTIMATED | DNA 6036F | Stem |
| Colours | Upper cloud "unusually white" with reddish-brown in the shadows; wide dirty stem; curtain of water at the base; large cloud-chamber effect | MEASURED (eyewitness + photo) | DNA 6036F; IvyMike2 photo | Palette, Wilson flash 1–4 s, spray ring 10–90 s |
| Crater | **Ø 1.9 km × 50 m**, water-filled; island gone; neighbouring islets swept; ≈1 m wave at Enewetak Island (up to 6 m per Wikipedia) | MEASURED | DNA 6036F; NWA | Crater |

**Key frames:** sunrise, low warm side light → 0–0.1 s total blue-white flash; five lightning bolts writhe from the sea → 0.1–1 s mottled white hemisphere on the sea, Ø 4.5 km at 1 s → 1–5 s max Ø 5.2 km, "half-risen sun"; huge Wilson cloud flashes around it; cumulus partly hides it → 5–15 s hover, then lift; yellow-orange → orange-red with dark veins → 10–90 s ring curtain of water at the base; dirty grey-brown stem 3–4 km; brilliant white sunlit cap lights the cumulus orange; 13 km at 60 s, 17 km at 90 s → 2.5–6 min 30 → 36 km; cap splashes against the stratosphere; reddish-brown in folds; pileus sheets → 6–10 min main top 37 km, optional turret 41 km; cap 61 km → 10–30 min cap ≈100 km; crater 1.9 km.

**Blurb RU:** Первый в мире термоядерный взрыв: это была 74-тонная установка в здании на островке Элугелаб (атолл Эниветок), а не бомба. 1 ноября 1952 года мощность 10,4 Мт дала огненный шар шириной около 5 км, а облако поднялось примерно на 37 км и за полчаса раскинулось почти на 100 км. Остров исчез — на его месте осталась подводная воронка диаметром 1,9 км и глубиной около 50 м.
**Blurb EN:** The world's first thermonuclear explosion came from a 74-tonne device housed in a building on Elugelab islet (Enewetak Atoll), not from a bomb. On 1 November 1952 its 10.4-megaton yield made a fireball about 5 km wide, and the cloud rose to roughly 37 km and spread nearly 100 km across within half an hour. The island vanished, leaving an underwater crater 1.9 km wide and about 50 m deep.

### 2.18 Castle "Bravo" (1 Mar 1954, Bikini) — game order 18

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time, light | 06:45 local (28 Feb 18:45 GMT); sun −8.1° (nautical twilight), sunrise 07:15; 4/8 cumulus 0.6–1.2 km, thin cirrostratus, pileus over the rising stem | MEASURED / COMPUTED | Kunkle & Ristvet DTRIAC SR-12-001 https://nsarchive.gwu.edu/sites/default/files/documents/s9j6zs-50hpr/43.pdf ; JTF-7 weather report https://minddfiles.nuclearsecrecy.com/0400173.pdf | Pre-dawn scene |
| Site | Site 20, ≈1-acre artificial islet on the reef, 0.9–1.1 km causeway to Namu; concrete cab; device ≈2 m above the surface | MEASURED | https://nuclearweaponarchive.org/Usa/Tests/Castle.html ; https://en.wikipedia.org/wiki/Castle_Bravo | HOB 2 m |
| Yield | 15 Mt (fireball yield 14.8 ± 0.2); predicted 6 Mt; "±5 Mt" unsupported | MEASURED | Castle 9.1; NWA | yield; UI "≈2.5× predicted" |
| Device | "Shrimp": 4.56 m × Ø 1.37 m, 10,659 kg, plain unpainted light metal | MEASURED | NWA; photo | Model |
| Fireball | **Ø ≈4.8 km @ 1 s, ≈6 km @ 3.5 s (photo), max ≈7 km at 8–10 s**, "seemed to cling to the earth" then sprang up; "7.2 km within 1 s" is too fast (7.2 km = max size) | DISPUTED → resolved | DTRIAC 2013; Wikipedia; physics | Fireball keyframes |
| Cloud top | 14.3 km @ 1 min, 25 @ 2, 31 @ 3, 34 @ 4, **34.7–35 km main top @ ≈5 min**; thunderhead dome 125 kft @ 5.8 min, **≈39–40 km @ 6–8 min** ("40 km at 6 min" = dome) | MEASURED | Castle 9.1 Fig. 5.1 | Keyframes |
| Cap | Underside 6.7 km @ 1 → 11 @ 2 → 16 @ 4 → 19 km @ 10 min; Ø 11.6 km @ 1 → 24 @ 2 → 44 @ 4 → 67 @ 6 → 100 @ ≈8.7 → **113 km @ 10 min** → ≈160 km @ 30 min (estimated) | MEASURED | Castle 9.1 | Cap growth |
| Stem | ≈4 km @ 1 min → 7–8 km @ 8–10 min; trumpet shape; anvil on the tropopause, virga-like fallout curtains | MEASURED | Castle 9.1 Fig. 6.3; DTRIAC | Stem |
| Auxiliary clouds | **4 condensation rings, 3 ice caps, 2 skirts, 3 bells**; rings at ≈3–4 km and ≈5 km (0.35–0.8 min), ice-cap undersides ≈6 and 7 km, widths 9–14 km (0.4–0.9 min), ice cap 3 Ø 14 → 20 km (1–1.6 min), ring 4 dragged 9 → 16 km (1–2.5 min), skirts at 5.5–8 km widening 7 → 15 km | MEASURED | Castle 9.1 §6.1, Figs. 6.2–6.4 | Signature look |
| Sky colour | Sky and cumulus crimson/orange while the fireball glows (0–≈2 min), then back to blue twilight; cloud top catches direct sun ≈9 min after the shot | MEASURED (photos, eyewitness) / COMPUTED | Oishi interview https://www.civilbeat.org/2015/03/bikini-atoll-the-day-the-sun-rose-in-the-west/ ; AHF https://ahf.nuclearmuseum.org/ahf/history/castle-bravo/ | Sky tint |
| Crater | **2.0 km × 76 m** (6,510 ft × 250 ft), on the reef, water-filled | MEASURED | NWA; Wikipedia; AHF | Crater |
| Fallout | White coral "snow" on Rongelap after ≈4–6 h; Lucky Dragon; >7,000 sq mi | MEASURED | DTRIAC; AHF | Blurb / optional |

**Key frames:** deep-blue twilight; tiny islet, causeway → 0–1 s whole sky white; hemisphere Ø 4.8 km at 1 s → 1–10 s Ø 6 km at 3.5 s, max ≈7 km; sky, sea and cumulus crimson-orange; pileus over the dome → 10–60 s fireball springs up, yellow core, orange outside; stacked flat white/orange-lit condensation rings and draped ice caps; smoke-rocket trails; 60 s: top 14.3 km, cap 11.6 km, stem ≈4 km → 1–2.5 min ice cap 3, ring 4 dragged up, skirts and bells; glow fades to dull red; sky back to dark blue → 2.5–5 min top 31 → 35 km; trumpet stem, anvil → 5–10 min dome to 39–40 km; anvil 100 km at 8.7 min, 113 km at 10 min; virga curtains; sunlit pink-gold rim on the top from ≈9 min → crater 2.0 km × 76 m.

**Blurb RU:** Самый мощный ядерный взрыв США: 1 марта 1954 года на рифе атолла Бикини устройство «Shrimp» дало 15 Мт — примерно в 2,5 раза больше расчётных 6 Мт. Огненный шар шириной около 7 км окрасил предрассветное небо в красно-оранжевый цвет, а облако за 10 минут поднялось почти на 40 км и раскинулось более чем на 100 км. Радиоактивные осадки накрыли атоллы Ронгелап и Утирик и японское рыболовное судно «Дайго Фукурю-мару».
**Blurb EN:** The largest US nuclear explosion: on 1 March 1954 the "Shrimp" device on a Bikini Atoll reef yielded 15 megatons, about 2.5 times the predicted 6 Mt. Its fireball, about 7 km wide, lit the pre-dawn sky red and orange, and within 10 minutes the cloud reached almost 40 km in height and over 100 km in width. Fallout contaminated Rongelap and Utirik atolls and the Japanese fishing boat Daigo Fukuryu Maru.

### 2.19 Soviet Test No. 219 (24 Dec 1962) — game order 19

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Date, time | **24 Dec 1962**, 11:11:42 UT = 14:11:42 MSK ("22 Dec" from one weak article; "12 Dec" on the NWA Tsar page is a typo) | MEASURED → resolved | https://nuclearweaponarchive.org/Russia/Sovatmtest.html ; Khalturin et al. 2005 https://scienceandglobalsecurity.org/archive/sgs13khalturin.pdf ; https://www.johnstonsarchive.net/nuclear/tests/multimegtests.html ; FRUS https://history.state.gov/historicaldocuments/frus1961-63v07-09mSupp/d172 | Date |
| Yield | 24.2 Mt official; US 1963 estimate 26 Mt; Western ≈20 Mt | MEASURED / DISPUTED | same | yield; second-largest explosion ever |
| Burst | Air burst **3,750 m** (US estimate 3,505 m) | MEASURED | Khalturin App. 4; Johnston | HOB |
| Delivery | **Air drop** (not ICBM); aircraft and parachute not published (Tu-95-class and a large parachute shown as plausible) | MEASURED (air drop) / ESTIMATED | Khalturin; https://en.wikipedia.org/wiki/1962_Soviet_nuclear_tests | Delivery labelled reconstruction |
| Location | Novaya Zemlya, Severny Island, Sukhoy Nos air-drop range (published coordinates are imprecise) | DISPUTED (coords) | as above | Same snowy range as the Tsar |
| Light | **Polar night**: sun −11.5° at the burst; that day's maximum −7.0° (never rose); cloud stays unlit | COMPUTED | NOAA algorithm | Night scene, deep-blue band low in the SW |
| Imagery | No photo, film or eyewitness account published | — | — | Look scaled from the Tsar Bomba and Dominic Bighorn/Housatonic |
| Bomb | Not published → generic Tsar-class streamlined body (≈8 m × 2 m), neutral grey | DESIGN | — | Model labelled reconstruction |
| Fireball | **Ø 6.0 km** (Tsar 8 km × (24.2/50)^0.4; formula 6.3 km); bottom ≈0.7–0.8 km above the snow, flattened; t_min 0.26 s, t₂ 3.5 s, visible glow ≈50 s | ESTIMATED | scaling; merge §0.4.4 | Fireball |
| Rise | Top ≈9 km @ 15 s; luminous dome ≈25 km @ 40 s | ESTIMATED | Tsar film narration scaled | Keyframes |
| Cloud | **≈53 km @ 8–10 min**; two-tier cap ≈72 / 55 km; thin pale stem of condensation and lifted snow, no dark dust; no Wilson cloud in −20 to −30 °C dry air | ESTIMATED | Tsar values scaled (W^0.22–0.25, W^(1/3)) | Cloud |
| Crater | None (glazed, snow-free circle) | MEASURED (by burst type) | — | — |

**Key frames:** black sky with stars, faint blue band in the SW, snow lit by starlight → 0 s blue-white flash turns the snow white, then orange; long hill shadows → 0–0.26 s shock sphere ≈3.5 km; dull orange-red minimum → 0.26–3.5 s rebrightening to blinding white, Ø 6 km → ≈3 s snow-dust ring kicked up below; ≈5–6 s reflected shock flattens the bottom → 5–30 s white → yellow (10 s) → yellow-orange (20 s), rising toroid; snow lit orange over 300+ km → ≈40 s dome top 25 km, thin pale stem → 50–90 s dull red → red-brown, then a dark silhouette against stars → 2–10 min unlit cloud to 53 km, two-tier cap 72/55 km (optional exposure boost).

**Blurb RU:** Испытание № 219 — 24 декабря 1962 года, Новая Земля: сброшенный с самолёта заряд взорвался на высоте 3 750 м с мощностью 24,2 мегатонны. Это второй по мощности взрыв в истории после «Царь-бомбы» — испытание 50-мегатонной конструкции на пониженной мощности. Взрыв прогремел в полярную ночь: солнце в тот день так и не поднялось над горизонтом.
**Blurb EN:** Test No. 219: on 24 December 1962 at Novaya Zemlya an air-dropped device burst 3,750 m up with a yield of 24.2 megatons. It is the second most powerful explosion in history after the Tsar Bomba, a reduced-yield test of a 50-megaton-class design. It went off in the polar night: that day the Sun never rose above the horizon.

### 2.20 Tsar Bomba (AN602, 30 Oct 1961) — game order 20

| Fact | Game value | Status | Source | Use in game |
|---|---|---|---|---|
| Time | 08:33:27.8 UT = **11:33 MSK** (seismic origin); release ≈11:30:20; fall **188 s** (189 s) | MEASURED | Johnston; NWA https://nuclearweaponarchive.org/Russia/TsarBomba.html ; Adamsky & Smirnov, CWIHP Bulletin 4 https://www.wilsoncenter.org/sites/default/files/media/documents/publication/CWIHP_Bulletin_4.pdf | Fall 188 s (may be time-compressed) |
| Place | Sukhoy Nos, field D-2, Severny Island, Novaya Zemlya (≈73.8°N 54.9°E) | MEASURED | NWA; Khalturin | Snowy mountains + Barents Sea |
| Light, weather | Sun **+2.3°** due south (local noon; max +2.5° that day); overcast deck below the burst plus a broken upper layer | COMPUTED / MEASURED | NOAA; Adamsky & Smirnov; Wellerstein https://thebulletin.org/2021/10/the-untold-story-of-the-worlds-biggest-nuclear-bomb/ | Low golden southern light |
| Yield | 50 Mt official; 57–58.6 Mt early/Western; design 100 Mt; ≈97 % fusion | MEASURED / DISPUTED → 50 Mt | Adamsky & Smirnov; Mikhailov catalogue; https://ru.wikipedia.org/wiki/АН602 | yield; UI «оценки до 58 Мт» |
| Carrier | Tu-95V No. 5800302, Maj. A. Durnovtsev; bomb-bay doors removed, bomb half outside; all anti-flash white incl. propellers; Tu-16 lab aircraft also white; Tu-95V ≈39–45 km away at the burst, shock caught it at 115 km | MEASURED | Adamsky & Smirnov; ru/en Wikipedia | Delivery |
| Burst | **4,000 m** above target (4,200 m ASL); others 3.5–4.5 km | MEASURED / minor DISPUTE | Adamsky & Smirnov; NWA; Khalturin | HOB |
| Bomb | **8.0 m × Ø 2.1 m, 26.5 t** (27 t / >20 t in other sources); parachute system: main canopy 1,600 m², ≈800 kg, descent 20–25 m/s; paint undocumented (museum casing bare silver-grey with black nose and tail) | MEASURED / minor DISPUTE | ru Wikipedia; Veselovsky 2011; NWA | Model |
| Fireball | **Ø 8.0 km** (radius 4.0 km); the **top** rose to ≈10.5 km altitude (bomber height) by ≈15–20 s: the ball was **not** 10.5 km tall; "4.6 km" is a formula value (radius/diameter mixed), not an observation | DISPUTED → resolved | Wikipedia (Richardt et al. 2013); NWA; Commons diagram history | Fireball |
| Ground contact | None: the reflected shock struck the underside (≈6–8 s), flattening it and pushing it up; bottom ≈0.3–0.5 km above the snow | DISPUTED (NWA wording) → resolved | Wikipedia; ru Wikipedia | Flat dished underside |
| Pulse timing | t_min ≈0.34 s, t₂ ≈4.9 s (G&D 7.85); NWA's "560 ms / 7 s" are W^0.5 scalings, not measurements; flash lasted >1 min | ESTIMATED (merge §0.4.4) | NWA page checked 2026-11-07 | Light curve |
| Rise | Luminous dome top ≈30 km @ 40 s (film narration); glowing cloud 15–20 km wide at 40–60 s; pale column to ≈10 km (single report) | MEASURED (narration) / DISPUTED | TWZ https://www.twz.com/35953/russia-releases-tsar-bomba-test-footage-of-the-most-powerful-nuclear-bomb-blast-ever ; Daily Sabah | Keyframes |
| Cloud | **67 km peak @ 8–10 min settling to 64 km** (64: Adamsky & Smirnov; 67: VNIIEF); two-tier cap **95 km upper / 70 km lower**; "base 40 km" = misread Pravda "40 km in diameter" → use as cap width at 2–3 min; visible from 800 km | DISPUTED → resolved | Adamsky & Smirnov; Veselovsky; ru Wikipedia (Chernyshev 2011) | Cloud |
| Far effects | Flash seen ≈1,000 km despite cloud; heat felt at 270 km; 3rd-degree burns to ≈100 km; Severny (55 km) buildings destroyed; windows broken to ≈780–900 km; pressure wave circled Earth 3 times (first 36 h 27 min); radio blackout ≈40 min | MEASURED (reports) | Adamsky & Smirnov; Khalturin; Wikipedia | Info card |
| Ground zero | No crater; levelled, "swept like a skating rink", snow melted, rocks with shiny melted edges | MEASURED (eyewitness) | Adamsky & Smirnov; ru Wikipedia | Aftermath |

**Key frames:** Arctic noon, sun 2° above the southern horizon, overcast below the burst; white Tu-95V; huge pale parachute for 188 s → 0 s blinding blue-white flash; overcast lit from inside ("sea of light") → 0–0.34 s shock sphere ≈5 km; dull orange-red minimum → 0.34–5 s rebrightening, Ø 8 km → ≈3 s white snow-dust ring races out → 6–8 s reflected shock flattens the underside → 8–20 s huge bright orange ball rising through a gap in the clouds; top at 10.5 km by 15–20 s; cloud deck blown out in a ring → 20–40 s red-orange toroid; pale column; dome top 30 km at 40 s, glowing cloud 15–20 km wide → 40–70 s fades to dull red, red-brown → 1–3 min top 40–45 km, cap ≈40 km, sunlit warm white-pink side → 3–10 min 67 km overshoot, two-tier cap 95/70 km, settling to 64 km.

**Blurb RU:** 30 октября 1961 года бомбардировщик Ту-95В сбросил над Новой Землёй 26-тонную бомбу АН602 на огромном парашюте; она взорвалась на высоте 4 км с мощностью около 50 мегатонн — это самый мощный взрыв в истории человечества. Огненный шар диаметром около 8 км не коснулся земли: его отбросила собственная отражённая ударная волна, а гриб поднялся на 64–67 км, в мезосферу. Вспышку видели почти за 1000 км, несмотря на облачность, а волна давления трижды обошла земной шар.
**Blurb EN:** On 30 October 1961 a Tu-95V bomber dropped the 26-tonne AN602 bomb over Novaya Zemlya on a huge parachute; it burst 4 km up with a yield of about 50 megatons, the most powerful explosion in human history. The roughly 8 km fireball never touched the ground, pushed back by its own reflected shock wave, and the mushroom cloud rose 64–67 km into the mesosphere. The flash was seen almost 1,000 km away despite cloud cover, and the pressure wave circled the globe three times.

---

## 3. Physics formulas: corrections to `02_PHYSICS_REFERENCE.md`

Full derivations, coefficient tables and checks are in `research_parts/techniques_and_physics.md` (A1–A10). W is in kilotons; all formulas are for `scripts/physics/blast_physics.gd`, evaluated on the CPU in double precision.

### 3.1 Corrections (fact → source → use)

| # | Item | `02` says | Use instead | Source / status |
|---|---|---|---|---|
| 1 | Surface-burst blast radii | ×0.8 of air | Pressure-dependent ratio surface/optimum-HOB: 0.55 (1 psi), 0.60 (3), 0.64 (5), 0.70 (10), 0.77 (20), 0.85 (50), 0.90 (100). 1 kt contact: 1.19 / 0.59 / 0.44 / 0.305 / 0.216 / 0.140 km at 1/3/5/10/20/50 psi | Fletcher 1963 eq. 2.5 (= G&D 1962); NUKEMAP within 4 %. FIT |
| 2 | Pressure below 1 psi | p ∝ 1/R | DNA 1-kt free-air standard: p [Pa] = 3.04·10¹¹/r³ + 1.13·10⁹/r² + 7.9·10⁶/(r·√ln(r/445.42 + 3·e^(−√(r/445.42)/3))), r = R/W^(1/3) (2W for surface). Old law is ×1.4 too high at 5·R₁ | DNA BLAST/WE via glasstone (MIT). FIT |
| 3 | Shock radius at 1 s | 1 kt 290 m, 1 Mt 1,150 m | Invert DNA arrival time: 1 kt 506 m, 15 kt 682 m, 1 Mt 1,280 m, 15 Mt 2,065 m, 50 Mt 2,584 m (1–100 ms columns of `02` are fine) | DNA. FIT |
| 4 | Sedov energy | 0.5·W, Trinity check with W | E = 0.5·W free air; **≈0.75–0.8·W** for tower/surface hemispheres (Trinity: 134/179 m vs measured 130/175 m at 25/53 ms) | DERIVED |
| 5 | t_min | 0.0022·W^0.5 s | **4.5·W^0.4 ms** (merge §0.4.3; measured Grable/Trinity/Badger). Techniques' 3.5·W^0.4 is the G&D text value, 25–35 % early vs these measurements | DERIVED from MEASURED |
| 6 | t₂ | 0.039·W^0.45 s | **0.0417·W^0.44 s** (HOB < 15 kft; above: 0.038·W^0.44·(ρ/ρ₀)^0.36). Peak thermal power **P_max = 3.18·W^0.56 kt/s** | G&D 1977 eq. 7.85. FIT (Grable measured 122–138 ms vs 137 ms) |
| 7 | Time to max size | 0.25·W^0.5 s | ≈10·t₂ for kt yields (1 Mt 8.7 s, 20 kt 1.6 s). Fill-in after breakaway: R = R_bw + (R_max − R_bw)(1 − e^(−(t − t_bw)/τ)), **τ ≈ 1.2·t₂** (merge §0.4.6) | G&D §2.05, §2.121; DERIVED |
| 8 | Thermal pulse shape | 90 % by 12·t₂ | **P/P_max = (15/7)τ²/(1 + (8/7)τ^3.75)**, τ = t/t₂: 18 % emitted at τ = 1, 46 % at 2, 73 % at 5, 84 % at 10, 90 % at ≈20. Add a first-pulse spike before t_min (≈1 % of energy) | Fit to G&D 1962 (Fletcher eq. 2.112) and 1977. DERIVED |
| 9 | R_max contact | 290·W^0.4 ft (88 m) | **79 m·W^0.4**; air **61 m·W^0.4**; linear HOB interpolation between 1.5 m·W^0.3 and 55 m·W^0.4; × (W/1000)^−0.03 above 1 Mt (Bravo 6.8 km, Tsar 8.2 km). Per-bomb values of §1 override | Fletcher Fig. 2.19. DISPUTED → resolved |
| 10 | Arrival times | e.g. 1 kt @ 1 km 2.1 s | DNA t₁(r) = r²(6.7 + r)/(7.12·10⁶ + 7.32·10⁴r + 340.5r²) s (1 kt, r in m), t = W^(1/3)·t₁(R/W^(1/3)); surface 2W; Mach factor for air bursts. Table: 1 kt @ 1 km 2.27–2.39 s; 1 Mt @ 5 km 8.9–9.8 s; 50 Mt @ 100 km 267–272 s | DNA; reproduces G&D's 20 kt and 1 Mt checks. FIT |
| 11 | Positive phase | 5 psi 0.40, 2.5 psi 0.52 s·W^(1/3) | Opt. HOB: 100 psi 0.097, 20 0.208, 10 0.267, 5 0.331, 2.5 0.401, 1 psi 0.505; surface: 0.569·p^−0.381 | Fletcher eqs. 2.68, 2.10. FIT |
| 12 | Light transmission | e^(−d/25 km) | **τ = exp(−k·d_km^0.44)**, k = 0.14 (very clear) / 0.22 (typical). Cloud deck above or snow below ×1.5 each | Fit to Fletcher/Sublette; G&D §7.100. DERIVED |
| 13 | 3rd-degree burn radius | 0.67·W^0.41 km | Clear air: **R3 = 0.65·W^0.44, R2 = 0.79·W^0.44, R1 = 1.12·W^0.43 km** (1 Mt 13.5 km). Surface bursts: thermal ×0.7 (≤10 kt) falling to ×0.5 (≥1 Mt) | G&D Fig. 12.65 (NUKEMAP polynomials). DISPUTED → resolved |
| 14 | Cloud top | 1 Mt 23.5 km | 23.5 km is equatorial. Formula: Miller h + b up to 1 Mt (1 Mt 24.3 km), 24.3·(W/1000)^0.2 km above; ×0.82 **only** for megatons at mid/high latitude (merge §0.4.5); **measured per-bomb overrides (§1) take precedence** | Miller 1963, Shreve 1961, G&D Fig. 9.96 |
| 15 | Cap radius | table | a = 0.713 km·W^0.431 at ≈10 min; growth a(z) = R_s·(a/R_s)^((z − R_s)/(h − R_s)) | Miller (NUKEMAP), DELFIC check. FIT |
| 16 | Rise | normalised table | z_top = H·tanh(t/τ_r), τ_r = 165 s·(W/1000)^0.1 clamped to **[150, 250] s** (merge §0.4.12); measured keyframes override | G&D Table 2.12. ESTIMATED |
| 17 | Conventional blast | 1 t: 220 m (1 psi), 71 m (5 psi), 0.54 s | Kingery–Bulmash (hemispherical TNT): R(1 psi) = 18.2·M^(1/3) m, R(5 psi) = 5.7·M^(1/3) m, 1-psi arrival 44 ms·M^(1/3) (M kg TNT) → 1 t: 181 m / 57 m / 0.44 s. Free-air charge: M/1.8 | DDESB TP-20 (Swisdak). FIT |
| 18 | HE fireball | R ≈ 1.0·m^(1/3) m, duration 0.04·m^(1/3) s | **R ≈ 1.6·W_kg^(1/3) m** (Cooper 8.13·W_lb^(1/3) ft; HSE 8.5·W_lb^0.341 ft; Beirut ≈2.0); bright phase 0.25 s (100 kg) to 0.4 s (500 kg), flame to 0.6–1.0 s | LA-14209-T; photo check (part 01–03). DISPUTED → resolved |
| 19 | HE cloud top | — | Church 1969: **H(2 min) = 76·W_lb^(1/4) m** (measured 140–2,800 lb TNT stacks; ±20–35 %); buoyant rise ends ≈2 min. Buried charges: lower (Tallboy 300 m) | Sandia SC-RR-68-903. MEASURED fit |
| 20 | Cased / buried HE | — | Optional casing factor 0.6–0.8 on air-blast overpressure for Mk 82/84 (≈55 % of mass is steel); buried bursts: air-blast effective yield ≈5–10 % of TNT eq. (Tallboy 0.2 t, Grand Slam 0.4 t) | ESTIMATED (design choice) |
| 21 | Crater | 18.3·W^0.3 m, depth R/2 | Confirmed (G&D §6.09). Add lip crest 1.25·R, lip height 0.25·D, continuous ejecta to 2.15·R, volume ≈ ½πR²D; no crater for HOB ≳ 14 m·W^(1/3); coral/water-saturated → per-bomb measured (Mike, Bravo) | FIT |
| 22 | Flash brightness | 1 Mt ≈450× sun at 10 km | ≈280–350× at the thermal peak (clear/typical air); 1 Mt at 50 km 6–9×; 50 Mt at 100 km 8–16× | DERIVED |
| 23 | Base surge (Baker) | qualitative | R(t) = (3,600 + 3,700·t)/(90 + t) m for 10–200 s; height 130 → 300 (60 s) → 550 m (≥140 s); inner clear radius ≈2/3 outer | Glasstone 1950 Table 4.71. MEASURED |
| 24 | Wilson cloud | heuristic | Appears at t_w = 1.0 s·(W/20)^(1/3), lasts 1.5 s·(W/20)^(1/3), outer radius ≈0.85·R_shock, thickness ≈0.3 R, only if RH ≳ 70 %; Baker measured: 0.5 → 3.5 s, Ø 1.6 km. Skip in polar dry air (Test 219) | G&D §2.48–2.50. ESTIMATED (no quantitative data found) |

**Confirmed values of `02` (keep):** optimum-HOB radii 2.2 / 1.0 / 0.71 / 0.45 / 0.28 km·W^(1/3) for 1 / 3 / 5 / 10 / 20 psi; Rankine–Hugoniot shock speed, dynamic pressure, reflection and peak wind (5 psi → 162.8 mph); breakaway radii 90 / 100–110 / 145·W^0.4 ft (use 33.5 m·W^0.4 air, 44.2 m·W^0.4 contact); thermal partition 0.35 and Q = 0.35·W·10¹²·τ/(4πD²); ignition table; 1 psi = 170.75 dB; Mach-stem onset x_m = h^2.5/5822 + 2.09·h^0.75 (scaled m); the 1 Mt cloud-rise table; stem ratios.

**For real burst heights** use Brode 1986 (coefficients in A3.3, CPU double precision, z^18 overflows float32), with the DNA tail spliced below 1 psi and Fletcher 2.4/2.5 for contact bursts (blend for scaled HOB < 30 m). Verified: Hiroshima (15 kt, 580 m) 5.0 psi at 1.6 km; Tsar 54 psi at 5 km, 4.8 psi at 20 km.

### 3.2 Unit-test values for `tools/selftest.gd` (techniques A10, adjusted by the merge)

- R_max_air(1 kt) = 61 m (±3 %); R_max_contact(15 Mt) ≈ 3.41 km (±10 %).
- t₂(1 Mt) = 0.871 s (±2 %); **t_min(15 kt) = 13.3 ms (±35 %; measured Grable 13.3–14.9 ms)** (replaces 11.6 ms at 20 kt).
- p_surface(1 kt, 1,191 m) = 1.00 psi (±3 %); R_opt(5 psi, 1 kt) = 0.696 km; R_opt(1 psi, 1 Mt) = 21.7 km.
- Brode: Hiroshima 15 kt / 580 m at 1.6 km = 5.0 psi (±10 %).
- Arrival (surface, 2W): 20 kt @ 1,609 m = 3.1 s; 1 Mt @ 3,219 m = 4.5 s (±5 %). R_shock(1 kt free air, 1 s) = 506 m (±2 %).
- Trinity 21 kt hemisphere (E = 0.8 W) at 25 ms = 130–140 m; **at 53 ms = 170–185 m (Taylor 175 m)**.
- Pulse: F(τ = 2) = 0.46, F(5) = 0.73 (±0.03). R_burn3(1 Mt, clear) = 13.5 km (±7 %).
- H_top(1 Mt, humid) = 24.3 km; cap a(1 Mt) = 14.0 km; crater R(100 kt) = 72.9 m; KB R(1 psi, 1,000 kg) = 181 m (±3 %).
- Per-bomb overrides must be honoured: Grable cloud 9.7 km, Trinity 10.5 km, Bravo 35 km, Tsar 64–67 km, Mike 37 km (each ±20 %).
- Monotonic yield across the 20 entries in game order (catches the 15 = 15 and 21 = 21 ties).

---

## 4. Development techniques (Godot 4.7.2)

Full recipes, shader code and API tables: `research_parts/techniques_and_physics.md` part B. Every API below was checked against the 4.7 stable documentation (docs.godotengine.org/en/stable, fetched 2026-11-07).

| Topic | Fact (verified) | Source | How it is used |
|---|---|---|---|
| Tonemapping | `Environment.tonemap_mode` has **AGX = 4** (slowest); AgX-only `tonemap_agx_white` (docs: ≥6 for photoreal; default 16.29) and `tonemap_agx_contrast` 1.25; `tonemap_white` ignored with AgX | class_environment | AgX, white 8–16 |
| Glow | `glow_hdr_luminance_cap` default 12 → raise to 50–100 for the flash; `glow_blend_mode` ADDITIVE/SCREEN; levels via `set_glow_level(i, v)` | class_environment | Wide halo on levels 4–6 |
| Exposure | Auto exposure is **Forward+ only**; deterministic renders script `CameraAttributesPractical.exposure_multiplier = 2^EV` with EV target from flash irradiance (fast down τ 0.03 s, slow up 4–10 s), white-out quad above 100× scene | class_cameraattributes(practical) | `ExplosionClock`-driven exposure |
| Global uniforms | `RenderingServer.global_shader_parameter_add(name, GLOBAL_VAR_TYPE_*, default)`, `_set`, `_get`; `frame_post_draw` signal | class_renderingserver | `blast_age`, `shock_radius`, `fireball_radius`, `fireball_temp`, `flash_level`, `cloud_top`, camera-relative `blast_center_rel` |
| One clock | Single autoload advances `age` by 1/fps in movie mode; never use shader `TIME` for physical motion; fixed seeds everywhere | B1 | Scrubbing, determinism |
| Volumetric cloud | Ray-marched BoxMesh proxy (`unshaded, cull_front, depth_draw_never, depth_test_disabled, blend_premul_alpha, fog_disabled, shadows_disabled`), 48–96 steps (128 in movie mode), manual depth clip, jittered start, early exit; **one combined volume** (fireball + cap + stem + skirt) because transparents sort by origin and there is no OIT | B2; Dunn GPU Pro 6; Wallis 2020; Hillaire 2015 | Fireball and mushroom |
| Shape | SDF: flattened dome + torus (smin) + stem cylinder with base flare; density = SDF shell + fBM "billow" erosion; toroidal (poloidal) swirl with a two-phase flow map | B2–B3; iq articles | Cauliflower cap, vortex ring |
| Noise | `NoiseTexture3D` is generated on threads: `await tex.changed`; seamless = true; 4-octave fBM from one texture | class_noisetexture3d | Cheap noise |
| Colour | Blackbody ramp `GradientTexture1D`, axis u = (1 − 1000/T)/0.975, stops 1000 K (255,56,0) … 6500 K (255,249,253) … 40000 K (155,188,255); intensity ∝ (T/8000)⁴; smoke albedo NO₂ (0.45,0.30,0.20) → grey (0.75) over 30–90 s; T(τ) = 8000 K·(P/P_max)^(1/4)·(R₂/R)^(1/2) | B4 (Charity table, approximate) | Fireball and cloud colour |
| Shock | Refraction limb shader on a sphere/hemisphere at R_shock (only opaque background is bent; `hint_screen_texture` excludes transparents); terrain ground ring from global uniforms; Mach band h_T ≈ 0.15(x − x_m); Wilson veil at 0.85·R_shock. True post-transparent distortion only via **CompositorEffect (experimental)** | B5; class_compositoreffect | Visible shock, dust front |
| Dust | GPUParticles3D ring emitter (`EMISSION_SHAPE_RING`) riding R_shock; `GPUParticlesCollisionHeightField3D.size` defaults to **2 m** → set ≈20 × 2 × 20 km, follow camera; enlarge `visibility_aabb`; afterwind stem emitter; base surge torus 25–37 m/s | B6; class_gpuparticlescollisionheightfield3d | Skirts, stems, base surges |
| Lighting | OmniLight at the fireball (energy ∝ P(t), colour = ramp(T)) plus a DirectionalLight from fireball to observer for distant terrain; sky term for horizon glow; heat-haze distortion | B7 | Flash on the landscape |
| Precision | Observer/camera at the origin, bomb at (0,0,−D), D ≤ 200 km (float32 step 1.6 cm at 131–262 km); effects in proxy-local space; particles `local_coords = true`; camera near 1–2 m, far 300–400 km; floating origin if the camera moves >8 km | B8; large_world_coordinates doc | Hundreds-of-km scene |
| Terrain | Addon-free geometry clipmap: ≈10 nested ring `ArrayMesh` levels snapped on the CPU, geomorph in the outer 25 %, heightmap + fBM in the vertex shader, large `extra_cull_margin`, aerial perspective | B9; Losasso & Hoppe 2004, CDLOD | Desert to the horizon |
| Sound | Procedural `AudioStreamWAV` (FORMAT_16_BITS, signed little-endian, verify once with `save_to_wav`): crack (5–20 ms noise, near only) + Friedlander/N-wave body with 38 → 28 Hz sweep + brown-noise rumble (length 5–30 s with distance); air-absorption low-pass f_c ≈ 1.2 kHz·(d/1 km)^−0.8; play at the DNA arrival time; ground rumble first (P-wave). Master: compressor + **AudioEffectHardLimiter** (`AudioEffectLimiter` is deprecated; `03` still names it) | B10; class_audiostreamwav; class_audioeffecthardlimiter | Blast audio |
| Offline render | `OS.has_feature("movie")` → max quality; MovieWriter finalises only on window close or `get_tree().quit()`, **not Ctrl+C**; screenshots after `await RenderingServer.frame_post_draw`; contact sheets with `Image.blit_rect` (same format) and `Image.create_empty` | B11; class_moviewriter; class_image | Verification rig |
| Pitfalls | Transparent sorting/no OIT; transparents absent from screen/depth textures; collision heightfield and particle AABB defaults; Brode on CPU only; volumetric fog length 64 m (unusable for km clouds); AgX cost; async NoiseTexture3D; scripted exposure for renders | B12 | Checklist |

---

## 5. Reference images and licences (`docs/refs/`)

All 20 folders were checked by the merge on 2026-11-07: every image is a real JPEG/PNG (`file`), the smallest is 10.3 KB (a PD line drawing, viewed), and each folder has a `SOURCES.md` with source pages and licences. `docs/refs/.gdignore` exists, so the references do not ship with the game. Full descriptions are in each `SOURCES.md`.

| Folder | Files (what they show) | Licence |
|---|---|---|
| `01_mk82` | `mk82_explosion_saberstrike18_a/b/c.jpg` (live Mk 82 burst, Latvia 2018: fireball + shock arc, crown, black plume); `mk82_bombs_kittyhawk_1972.jpg` (paint) | PD, US ANG / US Navy |
| `02_mk84` | `mk84_explosion_vietnam_1972.jpg`; `mk84_2000lb_explosion_usmc_2007_a/b.jpg` (2,000-lb burst with fragment splashes; type not named, Mk 84-class); `mk84_bombs_desert_storm_1991.jpg` | PD, US Navy / USMC / USAF |
| `03_tallboy` | `tallboy_tirpitz_attack_1944_C4775.jpg` (shore burst crown); `tallboy_saumur_tunnel_crater_1944_CL80.jpg` (crater field); `tallboy_hoisted_woodhall_spa_1944_CH15363.jpg`; `tallboy_falling_watten_1944_CH15380.jpg` | PD, UK Crown Copyright expired (IWM) |
| `04_grand_slam` | `gs_explosion_arnsberg_1945.jpg`; `gs_falling_arnsberg_CH15374.jpg`; `gs_bomb_on_trolley_CH15369.jpg`; `gs_museum_hendon_cc0.jpg` | PD (Crown Copyright expired); last file CC0 |
| `05_moab` | `moab_2003_fireball_t0.4s.png`, `moab_2003_cloud_t8s.png` (USAF test video stills); `moab_2017_achin_ir_detonation.png` (DoD IR video); `moab_bomb_2003_test_prep.jpg`; plus backup `backup_blu82/blu82_last_drop_fireball_2008.jpg`, `backup_blu82/blu82_bomb.jpg` | PD, USAF / DoD |
| `06_davy_crockett` | `lf1_ivyflats_film_t1s.png`, `lf1_ivyflats_film_t22s.png` (Ivy Flats film; sepia, colours unreliable); `lf1_dna6027f_fig8-1_20s.png`; `m388_davy_crockett_1961.jpg` | PD, US Army/DOE film, DNA report, US Gov photo |
| `07_foab` | **Analogues only** (no free FOAB imagery; Russian TV footage is copyrighted): `blu82_fireball_2008_usaf.jpg` (identical to the MOAB backup copy); `fae_bomb_uss_mcnulty_1972_usn.jpg` (fuel-air look); `atbip_conceptual_drawing_pd.png` (non-official shape hint) | PD (USAF, US Navy; drawing released by author) |
| `08_b61_12` | `b61_12_f35_drop_test_lanl.jpg` (inert test unit, test livery); analogues `tumbler_snapper_able_1952_1kt.jpg`, `teapot_wasp_1955_cloud_nnsa.jpg`, `hardtack2_eddy_1958_83t_balloon152m_cloud.jpg` | PD, LANL / US federal government / NNSA |
| `09_little_boy` | `little_boy_bomb_aec_1960.jpg`; `little_boy_L11_tinian_pit_1945_nara.jpg`; `hiroshima_cloud_caron_enola_gay_nara.jpg` (real mushroom cloud); `hiroshima_firestorm_cloud_from_matsuyama.jpg` (firestorm cloud hours later: late phase only) | PD, AEC / NARA / 509th |
| `10_grable` | `grable_reflected_shock.jpg`; `grable_mushroom_dust_stem.jpg`; `grable_fireball_ascending.jpg`; `grable_cloud_ice_caps.jpg` | PD, NNSA/DOE |
| `11_trinity` | `trinity_fireball_16ms.jpg`; `trinity_aeby_color.jpg` (red cast); `trinity_cloud_10s.jpg`; `trinity_crater_aerial_28h.jpg` (100 m scale bar) | PD, LANL / J. Aeby (Manhattan Project) / NARA / NNSA |
| `12_baker` | `01_baker_column_wilson_cloud_wide.jpg`; `02_baker_spray_dome_early_ms.jpg`; `03_baker_base_surge_nagato.jpg`; `04_baker_aerial_wilson_cloud_crown.jpg` (no genuine colour stills; colourised files rejected) | PD, US DoD / JTF-1 |
| `13_sedan` | `01_sedan_dome_venting_nnsa_xx13.jpg` (balanced colour); `02_…_hd10183.jpg`, `03_…_hd10187.jpg` (DOE film frames, magenta fade); `04_sedan_crater_nnsa_nf12187.jpg` | PD, NNSA / DOE |
| `14_ivy_king` | `ivy_king_mushroom_cloud.jpg` (XX-42); `ivy_king_distance.jpg` (colour-shifted print); `ivy_king_film_frames_2s.jpg` (DOE film, edited timing); `mk6_casing_usafm_cc0.jpg` (Mk 6 stand-in for Mk 18) | PD, NNSA/DOE; last file CC0 |
| `15_b83` | `b83_trainer_pease_1989.jpg`; `b83_hill_museum_cc0.jpg`; `b83_release_f4c_1983.jpg` (red-orange test body, parachute); analogue `analog_castle_nectar_surface_burst_frames.jpg` | PD, USAF; museum photo CC0; Nectar film PD |
| `16_rds37` | **Analogues** (no free RDS-37 imagery; the known colour still is non-free): `analog_cherokee_fireball_xx98.jpg`, `analog_cherokee_wilson_cloud.jpg`, `analog_cherokee_cloud_005.jpg` (Redwing Cherokee 3.8 Mt airdrop); `carrier_tu16_badger_usn_pd.jpg` | PD, NNSA/NSO, US DoD |
| `17_ivy_mike` | `mike_color_fireball_cloud_IvyMike2.jpg`; `mike_early_fireball_highspeed.jpg`; `mike_late_cloud_overshooting_top.jpg`; `mike_sausage_device.jpg` | PD, DOE/NNSA, USAF Lookout Mountain Lab |
| `18_castle_bravo` | `bravo_condensation_rings_red_sky.jpg`; `bravo_fireball_rings_rocket_trails.jpg`; `bravo_rising_cap_ice_caps.jpg`; `bravo_shrimp_device_in_cab.jpg` | PD, US DOE / NOAA / LANL-DTRIAC |
| `19_test219` | **Analogues** (no imagery of Test 219 exists): `dominic_bighorn_001.jpg` (7.65 Mt at 3.6 km, flattened fireball + Wilson shell), `dominic_housatonic_001.jpg`, `dominic_housatonic_002.jpg` (8.3 Mt at 3.7 km); `novaya_zemlya_modis_2020.jpg` (environment) | PD, US federal government; NASA |
| `20_tsar_bomba` | `tsar_fireball_1961.jpg` (actual fireball above the overcast); `fireball_size_comparison.png` (formula diagram, origin of the "4.6 km" confusion); `tu95_bear_1963_usn.jpg` | Fireball photo: Commons `{{PD-1978}}` (US-law claim; credited Soviet ministry / AP): **reference only, never ship**. Diagram PD (author release). Tu-95 PD US Navy |

---

## 6. Gaps, unverified items and deviations

- **Refs folders:** all 20 have 3–4 valid images and a `SOURCES.md`. Deviations: `05_moab/` holds 4 images plus 2 BLU-82 backup images in a subfolder (6 in total; harmless, the backup is not used). `07_foab/` and `20_tsar_bomba/` have 3 images each (within 2–4). Five folders rely on analogues because no free imagery of the actual event exists: FOAB, B61-12 (explosion), B83 (explosion), RDS-37, Test 219.
- **Not reachable during research:** DTIC PDFs (HTTP 403): the Ivy King "65,000 ft in slightly over 4 min / 40,000 ft wide" quote was seen only in search extracts (it agrees with the Castle 9.1 interpolation); the Kingery–Bulmash original (DDESB TP-20 used instead); the G&D Fig. 7.84 scan (1962 eq. 2.112 used).
- **Not found:** quantitative Wilson-cloud sizes except Baker (A7 heuristic is ESTIMATED; the search backend refused the query); Little Feller I crater numbers (Project 1.9 report offline); Sedan base-surge timing (extent measured, timing estimated); a source for the Mk 82 yellow-band width (76 mm) and for the dossier's Trinity device mass (≈4 t, one secondary source); RDS-37 length ("up to 7 m", single source).
- **Second-hand only:** the MOAB Alcis analysis (page behind Cloudflare, read via search summary); Romps et al. 2026 Hiroshima cloud-height study (press coverage); Mk 82/84 fragment ranges (forum-level).
- **Physics:** the blackbody colour stops and the sound-absorption table are approximate; the Wilson-cloud model and the cloud-rise tanh law are heuristics; megaton cloud tops and timings must come from the per-bomb keyframes.

## 7. Sound research (audio rework, 2026-11-07)

Three research agents (nuclear eyewitness accounts and recordings, conventional/HE blasts, rockets
and falling bombs) and one synthesis-technique agent read primary and technical sources; the
numbers below are the ones the synthesizer (`scripts/audio/blast_synth.gd`, `audio_synth.gd`) uses.

**What the real events sounded like**
- Trinity (pre-dawn, mountains on both sides): at 16 km the air blast came after ~40-50 s as a dull
  double thud with no sharp crack, followed by thunder that rolled between the ranges for a long
  time; at 9 km a blast push followed at once by a sustained roar; at 32 km some heard a sharp
  report. Reconstruction: ~1 kPa and t+ ~1.1-1.4 s at 16 km. -> dawn inversion, long mountain coda.
- Hiroshima/Nagasaki: survivors close in describe a flash with no sound ("noiseless flash"); nobody
  heard the bomb fall. -> no whistle for free-falling bombs beyond ~5 km, none under parachutes.
- Crossroads Baker: a muffled report, then the roar of the water column falling back for tens of
  seconds; flat atolls, so no terrain echoes. -> eruption / fall-back roar, no mountain echoes.
- Megatons (Castle Bravo, Tsar Bomba, RDS-37): at tens to hundreds of km a sharp report, then a long
  push and gale and prolonged rumbling, often several distinct bangs (multipath); RDS-37's shock was
  focused by an inversion and hurt people far away. -> 'avalanche' of arrivals, inversion preset.
- Most nuclear test films are dubbed; 1950s recordings that are authentic (Annie 1953, Baker 1946
  radio) lost everything below ~30-50 Hz and clipped the peak - the 'click' of old broadcasts is the
  recording chain, not the event. The infrasonic push has to be rebuilt, not copied.
- HE: a Mk 82-class blast is a hard crack-boom with a ~20 ms positive phase (fundamental ~20 Hz),
  hill echoes and little infrasonic push; thermobaric (MOAB/FOAB) has a dispersal pop, then the
  main report with a long positive phase; buried 'earthquake' bombs give ground tremor before a
  muffled thump.

**Physics used**
- Peak overpressure and positive-phase duration from the game's blast physics (DNA/Kingery-Bulmash;
  far field t+ grows slowly with range); waveform Friedlander -> rounded N-wave with scaled distance
  Z = R/W^(1/3) from 100 to 500.
- Shock rise time tau ~ 0.5-1.5 ms x (100 Pa / dp), longer in turbulence and in the shadow zone;
  nonlinear steepening keeps the front sharp: absorption on the front is capped at ~6 dB while
  dp > 150 Pa.
- ISO 9613-1 atmospheric absorption (computed, not tabulated; humidity from the site/player).
- Refraction: daytime lapse -> shadow zone from x_s = sqrt(2 * 86 km * H) + 0.6 km (duller, weaker
  diffracted boom); night/dawn inversion -> no shadow, extra arrivals 1.5-6 s later.
- Rolling rumble: direct-to-rumble ratio ~-25 dB within 2 km, -6..-15 dB beyond 20 km; coda
  T60 = 3 + 2 log10(W + 1) + R_km/20 s; echo delays (d1 + d2 - R)/c from ridges 8-70 km away.
- Blast wind u = dp / (rho c) ~ dp / 412 m/s, audible as a gust above ~3 m/s.
- Solid rockets: jet-noise spectrum peaking near 21 * sqrt(7.6 MN / F) Hz with ~-9 dB/oct below and
  ~-4.5 dB/oct above; crackle = skewed shocklet train (waveform skewness ~0.3-0.6, derivative
  skewness >= 5); ignition overpressure = ~60 ms positive triangle + ~120 ms negative half-sine.
- Loudspeaker practice (film/game sound design): a designed 30-60 Hz 'body' under infrasonic events,
  compressive loudness mapping, transient emphasis on the front.

**Sources (selection)** - Glasstone & Dolan ch. III (bkardell.com/effects-of-nuclear-math);
arXiv 2102.06574, 2103.05784 ('Fermi at Trinity'), 2408.04078; Rigby et al. 2014 (negative phase,
eprints.whiterose.ac.uk/78295); DTIC AD0737127, AD0743173; NASA NTRS 19940028990, 19720023371,
19910007381; AHF Trinity eyewitness documents (ahf.nuclearmuseum.org); A. Wellerstein,
blog.nuclearsecrecy.com/?p=2071 (dubbed test films); nuclearweaponarchive.org Tsar Bomba;
DENIX DoD blast-noise fact sheet; BYU acoustics (K. Gee) rocket crackle and Starship/SLS far-field
papers (physics.byu.edu, acoustics.byu.edu/nonlinearity, JASA-EL 3(2) 023601); sengpielaudio ISO
9613-1 calculator; python-acoustics ISO 9613-1 implementation; Farnell, 'Designing Sound' (MIT
Press) practicals 17/31/32; DICE Battlefield 1 sound talk (asoundeffect.com, GDC Vault 1024111).
No recording or sample was downloaded: every sound in the game is synthesized.
