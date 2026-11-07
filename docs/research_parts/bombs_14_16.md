# Research part: bombs 14–16 (Ivy King, B83, RDS-37)

Researched 2026-11-07. Scope: public historical, visual and effects data only (yield, burst geometry, fireball, cloud, crater, appearance, external dimensions and mass, paint). No weapon-design details are collected or given.

Status labels used in the tables:
- **MEASURED**: an instrumented or official figure, or a direct observation recorded in a primary or official document.
- **ESTIMATED**: scaled from Glasstone & Dolan (1977) or from the formulas in `docs/02_PHYSICS_REFERENCE.md`, or read off a photo or film. Always rounded.
- **DISPUTED**: the sources disagree. A reasoned game value is given.
- **DESIGN**: no source exists. The value is a game decision.

Scaling notes used throughout:
- Glasstone & Dolan §2.03/2.12: a 1 Mt air burst fireball reaches about 5,700 ft (1.74 km) diameter at about 10 s, so R(1 Mt) ≈ 869 m.
- R_max scales as W^0.4. A surface burst is treated as an air burst of 2W, a factor of 2^0.4 = 1.32 on radius.
- Breakaway radius: air ≈ 100·W^0.4 ft, contact surface burst ≈ 145·W^0.4 ft (Glasstone ch. 2).
- Crater, surface burst in dry soil (Glasstone §6.09): radius 60 ft and depth 30 ft at 1 kt, scaled by W^0.3. Lip crest radius ≈ 1.25·R, lip height ≈ 0.25·depth, continuous ejecta out to ≈ 2.15·R (Glasstone §6.71, §6.74).
- Timings come from the 02 reference: t_min = 0.0022·W^0.5, t₂ = 0.039·W^0.45, t_max = 0.25·W^0.5. Thermal output is 90% complete by about 12·t₂.

Key primary sources found in this pass (more URLs in each table):
- **DNA 6036F, "Operation IVY: 1952"** (Defense Nuclear Agency, 1982), full text: https://archive.org/stream/DTIC_ADA128082/DTIC_ADA128082_djvu.txt
- **Operation Castle Project 9.1, "Cloud Photography"** (1954), with its summary table of Ivy cloud parameters: https://rminucleardocs.icaad.ngo/en/entity/93hlfbs1utr?page=8 (PDF: https://rminucleardocs.icaad.ngo/api/files/1610649231735rgo5hl67jkf.pdf, p. 8)
- **Hubert, Machta, List, "A Meteorological Analysis of the Transport of Debris from Operation Ivy"** (1953): https://rminucleardocs.icaad.ngo/en/entity/tlii5dtbfif?page=29
- **"Ядерные испытания СССР"**, vol. I, ch. 5 (RFNC-VNIIEF, Sarov 1997), pp. 232–237, page scans: https://elib.biblioatom.ru/text/yadernye-ispytaniya-sssr_1997/p0_o/ (images at https://elib.biblioatom.ru/data/yadernye-ispytaniya-sssr_1997/jpg/0234.jpg … 0237.jpg)
- **Sublette, Nuclear Weapon Archive**: B83 https://nuclearweaponarchive.org/Usa/Weapons/B83.html, all US bombs https://nuclearweaponarchive.org/Usa/Weapons/Allbombs.html, Ivy https://nuclearweaponarchive.org/Usa/Tests/Ivy.html
- **Glasstone & Dolan**, ch. 2 and ch. 6: https://www.atomicarchive.com/resources/documents/effects/glasstone-dolan/chapter2.html and .../chapter6.html

---

## 14. Ivy King (Mk 18 "Super Oralloy Bomb"), 15/16 November 1952

### Fact table

| Fact | Value | Status | Sources (URLs) | Game value |
|---|---|---|---|---|
| Date / time | 16 Nov 1952, 11:30 local = 15 Nov 1952, 23:30 GMT | MEASURED | DNA 6036F (archive.org link above); https://nuclearweaponarchive.org/Usa/Tests/Ivy.html; https://en.wikipedia.org/wiki/Ivy_King | Show "16 Nov 1952, 11:30 local" (UTC 15 Nov 23:30). Midday sun at about 11°N in November: high sun (≈ 55–60° elevation). |
| Location | Over the reef/lagoon 2,000 ft (610 m) north of Runit Island, Enewetak Atoll | MEASURED | DNA 6036F p. 204; Wikipedia Ivy King | Flat shallow reef and lagoon water below. Atoll islets with palms 5–20 km away. |
| Weather | "Almost cloudless day with a few low, fair-weather cumulus". By midday the spreading King cloud turned the sky into a high thin overcast, with small convective showers for about 2 h. | MEASURED (observed) | DNA 6036F p. 204 (JTF 132 weather narrative) | Clear tropical sky with scattered low trade cumulus (bases ≈ 600 m, tops ≈ 1.5–2.5 km). |
| Yield | 500 kt. The largest pure-fission explosion the US ever set off. | MEASURED (official) | DNA 6036F summary table; NWA Ivy page; Wikipedia. The "550 ± 20 kt" in `01_BOMBS_REFERENCE.md` was not found in any source checked: 1 unverified source. | **500 kt** |
| Burst type / height | Free-fall airburst at 1,480 ft = 451 m above sea level, about 20 ft below the planned height. Bombing error 570 ft. | MEASURED | DNA 6036F p. 204 ("1,480 feet (451 meters)"); NWA Ivy page (20 ft low, CEP 570 ± 35 ft) | **450 m**, airburst over water |
| Scaled burst height | 451 m / 500^(1/3) = 57 m/kt^(1/3), which is very low for an airburst. Expect a strong Mach stem over water and a lot of spray. | ESTIMATED | derived | Mach stem forms almost at once. Bright, broad surface shock and spray ring on the lagoon. |
| Drop aircraft | B-36H from Kwajalein. Release from 40,000 ft (12.2 km). The aircraft turned to 140° right after release. | MEASURED | DNA 6036F fig. 26 caption; NWA | B-36H at 12.2 km |
| Bomb | Mk 18 (prototype of the stockpile "Super Oralloy Bomb", a high-yield variant on the Mk 6 casing). 90 built in 1953–55, retired 1956. | MEASURED | NWA Allbombs; https://en.wikipedia.org/wiki/Mark_18_nuclear_bomb | — |
| Bomb dimensions | Length 128 in (3.25 m), width 60 in (1.52 m) | MEASURED (one direct source; matches the Mk 6 casing, 128 x 61 in) | https://nuclearweaponarchive.org/Usa/Weapons/Allbombs.html (Mk-18 and Mk-6 rows); https://en.wikipedia.org/wiki/Mark_6_nuclear_bomb | **3.25 m x 1.52 m** |
| Bomb mass | 8,600 lb (3,900 kg) | MEASURED (Sublette, Allbombs and Ivy page) | NWA Ivy page; NWA Allbombs | **3,900 kg** |
| Paint | Not documented for the King unit. Mk 6 museum casings: olive drab with a yellow nose cap and yellow bands with red rectangles. | DESIGN | Photo: refs/14_ivy_king/mk6_casing_usafm_cc0.jpg | Olive-drab Mk 6-style ribbed "fat" casing with a box tail. Optional yellow bands. Label it as a reconstruction. |
| Fireball max radius | Glasstone 1 Mt-scaled: 660 m. 02-reference formula 200·W^0.4 ft: 732 m. | ESTIMATED | Glasstone ch. 2 | **≈ 650 m radius (1.3 km wide), at ≈ 5–6 s.** Because 650 m > 450 m burst height, the lower part flattens against the sea. Scaling also puts King below the "fireball does not touch the surface" height (180·W^0.4 ft = 659 m). |
| Fireball timings | t_min ≈ 0.05 s; second maximum t₂ ≈ 0.64 s; max size ≈ 5.6 s; 90% of thermal energy by ≈ 8 s. On film the visible white glow lasts tens of seconds, then turns orange inside the rising cap. | ESTIMATED (formulas), film-checked for order of stages | 02 reference formulas; refs/14_ivy_king/ivy_king_film_frames_2s.jpg | as given |
| Heat / blast at observers | Observers about 11 miles (≈ 18 km) away on Parry Island felt the heat immediately. The shock wave hit Parry about 45 s after detonation and sounded like a nearby 90 mm gun. | MEASURED (eyewitness, JTF 132 historian) | DNA 6036F p. 204 | **Shock at 18 km: 45 s** (the physics table gives ≈ 46 s, consistent) |
| Condensation | The "cloud-chamber effect" (Wilson cloud) was "clearly visible" from the atoll. Film shows bright horizontal condensation layers lit by the fireball. | MEASURED (observed) | DNA 6036F p. 204; DOE film | Condensation dome and discs from ≈ 0.5 s to ≈ 4–5 s. Radius ≈ 1.2–2 km (heuristic from the 02 reference, ESTIMATED). |
| Cloud rise | 28,000 ft (8.5 km) at 1 min | MEASURED (photogrammetry) | Castle Project 9.1 summary table, p. 8 (Ivy rows) | **8.5 km at 60 s** |
| Cloud top (max) | 76,000 ft (23.2 km) per the Castle 9.1 table. 75,000 ft (22.9 km) per Hubert & Machta 1953. An early JTF report gave 67,000 ft (20.4 km). A DTIC report (secondary, quoted in search results; DTIC offline during this check) gives 65,000 ft (19.8 km) "in slightly over 4 min". | DISPUTED, resolved | Castle 9.1 p. 8; Hubert/Machta p. 29 (rminucleardocs link above); DNA 6036F p. 204; Wikipedia (75,000 ft) | **23 km final top at ≈ 8–10 min.** Use 19.8 km at 4 min as a waypoint. |
| Cloud base (mushroom bottom) | 40,000 ft (12.2 km) | MEASURED (two independent reports) | DNA 6036F p. 204; Hubert/Machta p. 29 | **12 km** |
| Tropopause | ≈ 58,000 ft (17.7 km) | MEASURED | Wikipedia Ivy King, citing Project 7.5 | Cap spreads at and above 17–18 km, so it overshoots the tropopause by about 5 km. |
| Cap diameter | 11,000 ft (3.4 km) at 1 min; 90,000 ft (27.4 km) at 10 min (Castle 9.1). 40,000 ft (12.2 km) at about 4 min (DTIC secondary). | MEASURED (1 and 10 min); 4 min DISPUTED but consistent (log-interpolation of 1→10 min gives 39,000 ft at 4 min) | Castle 9.1 p. 8; 01 reference | **3.4 km @1 min → 12 km @4 min → 27 km @10 min**, then thin streaks spreading W, SE and SW |
| Stem | Thin, reddish-brown to grey. A water-vapour and spray column over the lagoon, not a dust column. | MEASURED (photos) | refs/14_ivy_king/ivy_king_mushroom_cloud.jpg | Stem ≈ 1/8 of cap width |
| Crater | None (airburst over water and reef). Ground effects: brush scorched at Lojwa (north), brush burning at Jinedrol (south), palms broken and burned on Billae, power poles down and burning on Runit, seawater pushed 400 m inland on Runit. | MEASURED | DNA 6036F pp. 204–205 | No crater. A surface spray ring, plus fires and flooding on nearby islets. |
| Fallout | Little fallout and island contamination. 0.3 R/h measured 500 ft above the target area after the shot. | MEASURED | DNA 6036F p. 205 | — |

### Disputes resolved
1. **Cloud top, 23 km vs 19.8 km.** The 19.8 km (65,000 ft) figure is the height reached "in slightly over 4 min", and the 20.4 km (67,000 ft) is an early estimate. The maximum observed top is 75–76 kft (22.9–23.2 km) in two independent 1953–54 analyses (Hubert & Machta; Castle 9.1 photogrammetry). Recommendation: final top **23 km** at about 8–10 min, passing about 20 km at about 4 min.
2. **Cap diameter.** Measured: 3.4 km at 1 min and 27 km at 10 min. The 12 km "diameter at 4 min" sits exactly on the log-interpolation of those two points, so all three figures agree once time is taken into account. Recommendation: animate the cap diameter as **D(t) = 3.4 km × (t/1 min)^0.91**, which gives 12 km at 4 min and 27.4 km at 10 min.
3. **Yield.** Use 500 kt. The "550 ± 20 kt" figure was not confirmed by any source found.

### Visual signature (game)
- **Scene:** 11:30 local, high tropical sun, deep-blue sky, scattered low trade cumulus. Burst 450 m above shallow turquoise reef and lagoon. Recommended camera 50 km away; historical observer view 18 km (Parry Island).
- **0–0.05 s:** blue-white point flash that saturates the frame. Exposure crush.
- **≈ 0.05 s:** brightness dip (first thermal minimum). An orange-red opaque shell about 340 m across (breakaway radius ≈ 370 m at ≈ 0.07 s).
- **0.05–0.64 s:** brightness climbs to the second maximum at 0.64 s. Fireball blue-white then white, ≈ 0.9–1 km across. Its lower edge reaches the sea surface by ≈ 1 s: a flat, very bright, glaring contact patch on the water, and an instant ring of white spray and Mach-stem shock racing outward over the lagoon.
- **0.5–5 s:** a big bright condensation dome and horizontal condensation discs (radius ≈ 1.2–2 km) light up yellow-white around the fireball and evaporate within a few seconds. The cumulus deck within ≈ 10 km is lit yellow from below. A circular shock "scar" spreads through the cumulus layer (the ring visible in NNSA XX-42).
- **≈ 5–6 s:** maximum size, a sphere about 1.3 km wide with a flattened bottom. Colour white turning yellow-orange. 90% of the heat has been delivered by ≈ 8 s.
- **8–30 s:** the fireball rises (≈ 100 m/s), turns orange then red, and forms a vortex ring. The top darkens to red-brown (nitrogen oxides). A thin reddish stem of spray and vapour is drawn up from the lagoon.
- **30–60 s:** an orange glow persists inside a brown cap. The cap reaches **8.5 km and 3.4 km wide at 60 s**. Smoke-rocket trails near the stem bend as the shock passes.
- **45 s at 18 km:** the blast arrives. A single hard "gun-like" crack, then rumble. At 50 km, ≈ 2 min 15 s.
- **1–4 min:** the cap rises to ≈ 20 km and spreads to ≈ 12 km wide. Colour brown-grey turning white-grey as moisture condenses. Base ≈ 12 km.
- **4–10 min:** the top overshoots to **23 km** (tropopause ≈ 18 km), and the cap flattens and spreads to **27 km at 10 min**. Long streaks drift W, SE and SW. Later the sky goes high, thin and overcast.

### Ref images
- `docs/refs/14_ivy_king/ivy_king_mushroom_cloud.jpg`: aerial colour, PD (NNSA XX-42)
- `docs/refs/14_ivy_king/ivy_king_distance.jpg`: view from the atoll, PD (NNSA IVY-52-10), colour-shifted print
- `docs/refs/14_ivy_king/ivy_king_film_frames_2s.jpg`: DOE film frames, PD
- `docs/refs/14_ivy_king/mk6_casing_usafm_cc0.jpg`: Mk 6 casing (stand-in for Mk 18), CC0

### UI blurbs
- **RU:** Ivy King — самый мощный взрыв бомбы деления (без термоядерной ступени) в истории США: 500 килотонн. 16 ноября 1952 года бомбардировщик B-36 сбросил бомбу Mk 18 над рифом атолла Эниветок, и она взорвалась на высоте около 450 м. Облако поднялось примерно до 23 км, а ударная волна дошла до наблюдателей в 18 км примерно через 45 секунд.
- **EN:** Ivy King was the most powerful pure-fission explosion the United States ever set off: 500 kilotons. On 16 November 1952 a B-36 dropped a Mk 18 bomb over the reef of Enewetak Atoll, and it burst about 450 m up. The cloud climbed to about 23 km, and the blast reached observers 18 km away roughly 45 seconds later.

---

## 15. B83 (up to 1.2 Mt). Modelled laydown surface burst (never detonated in the atmosphere)

### Fact table

| Fact | Value | Status | Sources (URLs) | Game value |
|---|---|---|---|---|
| Origin / service | US strategic gravity bomb by LLNL, development from 1974 (B77 lineage). First production units June 1983. About 650 built. Planned for retirement since the 2022 NPR and still described as in the stockpile in 2026, with the B61-13 and a future bunker-buster meant to replace it. | MEASURED | https://nuclearweaponarchive.org/Usa/Weapons/B83.html; https://en.wikipedia.org/wiki/B83_nuclear_bomb; https://www.everycrsreport.com/files/2026-04-01_IF10519_f55adb1df8e4e3077ef804fdccba21979c3b7574.html; https://www.armscontrol.org/act/2026-03/news/us-congress-funds-nuclear-bunker-buster-prototype | UI: "in service since 1983, slated for retirement" |
| Testing | Never detonated in the atmosphere. The first underground (Nevada) test detonation was on 15 Dec 1984. All US testing stopped in 1992. | MEASURED | Hill AFB museum fact sheet (via Commons description of the Hill photo and search snippet: https://www.hill.af.mil/About-Us/Fact-Sheets/); NWA | Mark it in the UI as a **"model" (условная модель)** |
| Yield | Variable, from "low kt" to 1.2 Mt maximum | MEASURED (official public figure) | NWA B83; NWA Allbombs; Wikipedia; UCS fact sheet https://ucs-documents.s3.amazonaws.com/nuclear-weapons/b83-fact-sheet.pdf | **1,200 kt** |
| Length | 12 ft (3.66 m). Allbombs lists 145 in (3.68 m). | MEASURED | NWA B83 ("12 ft"); Hill AFB fact sheet (12 ft); Allbombs (145 in) | **3.67 m** |
| Diameter | 18 in (0.46 m) | MEASURED (three sources) | NWA B83; Hill fact sheet ("1 ft 6 in"); Allbombs | **0.46 m** |
| Mass | 2,408 lb (1,092 kg) per NWA. "Basic weight" 2,400 lb (1,089 kg) per the Hill fact sheet and Allbombs. 2,465 lb (1,118 kg) per the Wikipedia infobox. | MEASURED (small spread) | NWA; Hill; Allbombs; Wikipedia | **1,100 kg** |
| Shape | Slim cylinder. Long ogive nose ending in a stepped stack of concentric rings (a hollow shock-absorbing steel nose with frangible rings, so the bomb does not bounce or skid on landing). Two top suspension lugs. Short tail cone with 4 small swept fins. Rear parachute compartment. | MEASURED (photos + NWA text) | NWA B83; refs/15_b83 photos | as described |
| Paint | Trainers and museum examples: gloss white with small black and red stencils. The 1983 flight-test unit was high-visibility red-orange. The war-reserve finish is not described in text, but public photos of service loadings show white or very light grey bombs. | MEASURED (photos) for trainer and test unit; DESIGN for service | refs/15_b83/b83_trainer_pease_1989.jpg; b83_hill_museum_cc0.jpg; b83_release_f4c_1983.jpg | **Gloss white**, small black stencils, no "TRAINING ONLY" |
| Parachute | Main canopy: a 46 ft (14 m) Kevlar-nylon ribbon parachute with 60 Kevlar suspension lines, deployed by three 4 ft pilot chutes. System weight 180 lb. Slows the bomb from Mach 0.93 to about 65 ft/s (≈ 20 m/s) within seconds. | MEASURED (NWA citing Sandia; Wikipedia, "46-foot Kevlar ribbon parachute") | NWA B83; Wikipedia (citing Sandia SAND97-8012) | **14 m ribbon canopy.** Colour not documented: DESIGN orange-and-white ribbons (white pack seen in the 1983 photo). |
| Delivery modes | Free-fall airburst, retarded airburst, free-fall or retarded contact burst, and **parachute-retarded laydown with a delayed surface burst**. Release as low as 150 ft (46 m), at speeds up to about Mach 2. | MEASURED | NWA B83; Wikipedia | Game: low-level release, chute opens, the bomb lies on the ground, then detonates after a delay (DESIGN: about 10–30 s; the real delay is not public). |
| Burst type / height | Laydown, so a contact surface burst (the bomb lying on the ground, centre ≈ 0.2 m up) | DESIGN (the task chose a surface burst) | — | **0–1 m (treat as 0)** |
| Fireball | Hemisphere. Breakaway radius 145·W^0.4 ft ≈ 750 m at ≈ 0.11 s. Max radius: 1.23 km (Glasstone 1 Mt air value × (1.2)^0.4 × 2^0.4) or 1.28 km (02 reference 290·W^0.4 ft × 0.85). | ESTIMATED | Glasstone ch. 2; 02 reference | **Hemisphere, R_max ≈ 1.25 km (2.5 km wide) at ≈ 9–10 s** |
| Fireball timings | t_min ≈ 0.08 s; t₂ ≈ 0.95 s; max size ≈ 9 s; 90% of thermal energy by ≈ 11 s. A surface burst emits noticeably less thermal radiation than an air burst (part of it goes into the ground). | ESTIMATED | 02 reference formulas; Glasstone ch. 7 | as given |
| Crater (dry soil) | Apparent radius 153 m (diameter ≈ 306 m), apparent depth 77 m, lip crest radius ≈ 190 m, lip height ≈ 19 m, continuous ejecta out to radius ≈ 330 m. ±30% at least. Glasstone's W^0.3 scaling is extrapolated here (there are no megaton land surface-burst data). In wet coral the real Pacific craters were about 3x wider (Mike, Bravo ≈ 2 km). | ESTIMATED | Glasstone §6.09, §6.71, §6.74 (chapter 6 link above) | **D = 300 m, depth 75 m, lip 19 m high, lip crest D 380 m, ejecta blanket D ≈ 660 m** |
| Cloud | Glasstone/equatorial curve: 1 Mt top ≈ 23.5 km (77 kft), so ≈ 24 km for 1.2 Mt. The closest-yield filmed surface burst, Castle Nectar (1.69 Mt, tropical), was measured at 72 kft (21.9 km) max, 25 kft (7.6 km) at 1 min, cap 19 kft (5.8 km) at 1 min and 147 kft (44.8 km) at 10 min. Surface bursts "hover a while before beginning to rise" (Castle 9.1). | ESTIMATED (from MEASURED analog) | Castle 9.1 p. 8 and p. 27; 02 reference table | **Top 21 km, base ≈ 12 km, at ≈ 8–10 min. Rise: 7.5 km at 60 s, ≈ 15 km at 3 min. Cap D: 6 km @1 min → 20 km @4 min → 35 km @10 min.** For a high-latitude winter scene, lower the top to about 17–18 km. |
| Stem | A thick, dark, dirty column of soil drawn up by afterwinds. Megaton stem width is about 1/5–1/10 of the cap (02 reference). | ESTIMATED | 02 reference; Glasstone ch. 2 | Stem ≈ 3–4 km wide near the ground, dark brown. A ground dust skirt about 10 km wide. |
| Blast radii (surface burst, ×0.8 of optimum air) | 20 psi ≈ 2.4 km, 5 psi ≈ 6.0 km, 3 psi ≈ 8.5 km, 1 psi ≈ 18.7 km | ESTIMATED | 02 reference §2 | as given |
| Shock arrival | ≈ 8 s at 5 km, ≈ 20 s at 10 km, ≈ 48 s at 20 km, ≈ 150 s at 55 km (recommended camera) | ESTIMATED | 02 reference arrival table | as given |

### Disputes resolved
1. **Dimensions and mass.** Three sources agree on 12 ft x 18 in. Mass is 2,400–2,465 lb depending on configuration. Use 3.67 m x 0.46 m and 1,100 kg.
2. **Paint.** Real public photos show white (trainers and museum) or red-orange (1983 test body). Use white. Mention in tooltips that the red-orange scheme was a test unit.
3. **Explosion model.** No atmospheric data exists, so everything is ESTIMATED from Glasstone scaling, cross-checked against Castle Nectar (a 1.69 Mt surface burst). The game must label it a model.

### Visual signature (game)
- **Scene:** generic dry plain or desert (DESIGN). Clear sky, mid-morning. Recommended camera 55 km.
- **Delivery (DESIGN, using real hardware data):** an aircraft passes low (≈ 50–150 m). The white bomb separates, three small pilot chutes pop out, and the 14 m ribbon canopy blooms within about 1 s. The bomb drops nose-down at ≈ 20 m/s, the ringed nose hits and crumples slightly, and the bomb tips onto its side and lies in the dust under the collapsing canopy. Delay of 10–30 s.
- **0–0.1 s:** a ground-level blue-white flash that saturates the frame. A hemispherical shock is born at the ground (no separate Mach stem: it is a surface burst from the start).
- **≈ 0.1 s:** brightness dip. A red-orange opaque hemisphere ≈ 1.5 km wide (breakaway radius ≈ 750 m).
- **≈ 1 s:** second maximum. A blinding white dome ≈ 2 km wide. The ground around it ignites and smokes. A dense dust skirt rises from the surface shock.
- **1–10 s:** the dome grows to **≈ 2.5 km wide (R ≈ 1.25 km) at ≈ 9 s**, yellow-white turning orange, its base fringed with dark dust and debris. If the air is humid, a short-lived condensation dome about 3–5 km wide appears. The shock front, visible as a bright line of raised dust, runs out across the plain.
- **10–60 s:** the fireball lifts off the crater as an orange-red, then brown, torus. A **thick dark-brown stem** of soil is sucked up behind it (afterwinds). The cap is red-brown (nitrogen oxides plus soil). At 60 s the cap is at ≈ 7.5 km and ≈ 6 km wide. Debris rains back around the crater.
- **1–4 min:** the cloud climbs to ≈ 15–19 km. Cap ≈ 20 km wide at 4 min, brown-grey. The stem stays dark and thick. Dust columns drift downwind.
- **4–10 min:** stabilises at **≈ 21 km top, ≈ 12 km base, ≈ 35 km wide** at 10 min. Colour dirty grey-brown. Heavy local fallout begins downwind (not shown as particles, only as a dark curtain).
- **Aftermath:** a crater **≈ 300 m across and ≈ 75 m deep** with a raised lip ≈ 19 m high and a grey ejecta blanket ≈ 660 m across.
- **Sound at 55 km:** ≈ 2.5 min after the flash, a deep, long "boom" plus a ground tremor that arrives first (the seismic wave).

### Ref images
- `docs/refs/15_b83/b83_trainer_pease_1989.jpg`: B83 trainer, PD (USAF)
- `docs/refs/15_b83/b83_hill_museum_cc0.jpg`: museum B83, CC0
- `docs/refs/15_b83/b83_release_f4c_1983.jpg`: 1983 drop test with parachute deploying, PD (USAF)
- `docs/refs/15_b83/analog_castle_nectar_surface_burst_frames.jpg`: ANALOG megaton surface burst (Castle Nectar, 1.69 Mt), PD

### UI blurbs
- **RU:** B83 — самая мощная бомба, остававшаяся в арсенале США в 2020-х годах: мощность регулируется, максимум 1,2 мегатонны. В атмосфере её не взрывали ни разу (заряд испытывали только под землёй), поэтому здесь показана расчётная модель: бомба опускается на 14-метровом парашюте, ложится на землю и взрывается с задержкой. По формулам Гласстона такой наземный взрыв оставил бы воронку около 300 м в поперечнике.
- **EN:** The B83 is the most powerful bomb still in the US arsenal in the 2020s, with a variable yield of up to 1.2 megatons. It has never been exploded in the atmosphere (its nuclear explosive was tested only underground), so this is a calculated model: the bomb descends on a 14-metre parachute, lies on the ground and detonates after a delay. Glasstone's scaling gives such a surface burst a crater roughly 300 m across.

---

## 16. RDS-37 (first Soviet two-stage thermonuclear bomb), 22 November 1955

### Fact table

| Fact | Value | Status | Sources (URLs) | Game value |
|---|---|---|---|---|
| Date / time | 22 Nov 1955. Bomb hung on the aircraft at 6:55, take-off 8:34, **release at 9:47** over experimental field P5 at the Semipalatinsk test site. Detonation followed after the parachute descent (time zone not stated in the source). An earlier attempt on 20 Nov was aborted (overcast plus radar-sight failure), and the aircraft landed with the bomb. | MEASURED | VNIIEF 1997 p. 234 (scan link above); https://ru.wikipedia.org/wiki/РДС-37 | Show "22 Nov 1955, release 09:47". Low winter sun (at 50.4°N on 22 Nov the sun is ≤ 20° high even at noon) under overcast. |
| Weather | The target was covered by a solid two-layer overcast, 1.5 km thick in total, with its top at 10 km. The weather was deteriorating. Freezing temperatures. Feather-grass steppe. | MEASURED | VNIIEF account reproduced at https://legion.wplus.net/others/rds37.shtml (Russian mirror: https://xn----7sbb5ahj4aiadq2m.xn--p1ai/others/rds37.shtml); Sakharov via https://blog.nuclearsecrecy.com/2014/01/31/sakharovs-turning-point-first-soviet-h-bomb-test/ | Grey overcast deck at ≈ 8.5–10 km. Frozen brown steppe with dry grass, no deep snow (Sakharov saw the shock "flattening the feather-grass"). |
| Yield | 1.6 Mt (test commission, 24 Nov 1955). The design was ≈ 3 Mt, deliberately reduced for the test. Some secondary sources say 1.6–1.9 Mt. | MEASURED | VNIIEF 1997 p. 235 ("Энерговыделение РДС-37 составило 1,6 Мт ТЭ"); en/ru Wikipedia | **1,600 kt** |
| Burst height | **1,550 m** | MEASURED; the "2,000 m" is DISPUTED and rejected | VNIIEF 1997 p. 234 ("Взрыв бомбы произошел на высоте 1550 м"); MilitaryRussia; atomicarchive; en/ru Wikipedia. The 2,000 m appears only in one secondary web page (legion.wplus.net listing). | **1,550 m** |
| Carrier / release | Tu-16 (Tu-16A) crewed by Maj. F. P. Golovashko. Release from 12 km at 985 km/h (VNIIEF 1997) or 870 km/h (later VNIIEF text). Radar aiming through the overcast. MiG-17 escort. | MEASURED | VNIIEF 1997 p. 234; Russian mirror above | 12 km release |
| Carrier paint | Lacquer washed off the lower fuselage, tail and wings. All dark-coloured surfaces painted with special white paint. | MEASURED | VNIIEF 1997 p. 234 | Natural-metal Tu-16 with white-painted dark areas |
| Parachute | PG-4083 (made for the RDS-6s by the Parachute Equipment Research Institute) to slow the fall, so the aircraft could get far enough away and the light pulse on it stayed acceptable. Size and colour not published. | MEASURED (type); DESIGN (look) | VNIIEF 1997 p. 234 | Large single round canopy (DESIGN: white or orange-white) |
| Aircraft at burst | 15 km from the burst. The navigator felt heat "stronger than the hottest sunny day". The bright flash was seen for **10–12 s**. The shock reached the aircraft **224 s after release**, giving load factors up to 2.5 g. | MEASURED | VNIIEF 1997 p. 234; Russian mirror | Flash duration 10–12 s matches scaling (90% of thermal energy by ≈ 13 s) |
| Bomb dimensions | Diameter 1.5 m, length "up to 7 m" (MilitaryRussia). `01_BOMBS_REFERENCE.md` gives 5.87–7 m from an unknown source. | DISPUTED (length), single source (diameter) | MilitaryRussia (archive.org copy: https://archive.org/download/DnaEm1CapabilitiesOfNuclearWeapons/RDS-37%20_%20MilitaryRussia.Ru%20-%20domestic%20military%20equipment%20%28after%201945%29.pdf) | **Ø 1.5 m x 6.0 m** (mid-range, and it fits a Tu-16A bomb bay). Label it approximate. |
| Bomb mass | 5,570 kg | single source (MilitaryRussia, citing the design proposal) | same | **5,570 kg** |
| Bomb paint | Not documented | DESIGN | — | Dark olive-grey, flagged as a reconstruction |
| Fireball | Max radius ≈ 1.0–1.05 km: Glasstone 1 Mt-scaled 1,049 m, 02 formula with ×0.85 = 991 m. At max size its base is ≈ 0.5 km above the ground. VNIIEF observers saw the glowing region grow "from a small ball to a sphere of considerable size" and its **deformation by the shock wave reflected from the ground**. | MEASURED (observed qualitatively); size ESTIMATED | VNIIEF 1997 p. 235; Glasstone ch. 2 | **R_max ≈ 1.0 km at ≈ 10 s.** Underside flattened by the reflected shock from ≈ 2–4 s. |
| Fireball colour (eyewitness) | Sakharov (≈ 30+ km away) saw a blinding yellow-white sphere that swelled quickly and turned orange within a fraction of a second, followed by a huge swirling grey-blue cloud streaked with crimson flashes. The stem was thicker than the 1953 test's. | MEASURED (eyewitness) | Sakharov, *Memoirs*, via https://blog.nuclearsecrecy.com/2014/01/31/sakharovs-turning-point-first-soviet-h-bomb-test/ | Use in the colour script |
| Fireball timings | t_min ≈ 0.09 s, t₂ ≈ 1.1 s, max size ≈ 10 s, 90% of thermal energy by ≈ 13 s | ESTIMATED | 02 reference formulas | as given |
| Condensation | "Formation of large regions of condensation of water vapour" (VNIIEF observers). Photo captions describe a condensation ring and a translucent "skirt" on the stem. The (non-free) colour still shows a bell-shaped translucent skirt around the middle of the stem, below the cap, about half the cap's width. | MEASURED (observed and photographed); size ESTIMATED from the photo | VNIIEF 1997 p. 235; https://en.wikipedia.org/wiki/RDS-37 (photo caption); https://ru.wikipedia.org/wiki/РДС-37 (caption); https://www.atomicarchive.com/media/photographs/testing/soviet/rds-37-1.html (photo, non-free, not downloaded) | **Wilson dome at 0.5–6 s (radius ≈ 2–3 km). Then, at ≈ 30–120 s, a translucent bell "skirt" around the stem (width ≈ 0.5 x cap) and one or two thin condensation rings where the stem crosses the humid cloud deck at 8.5–10 km.** |
| Double thunder | Observers 35 km from the epicentre, lying down in goggles, felt a strong heat surge at the flash. When the shock arrived they heard a **double, strong, sharp sound like a thunderclap**, plus pressure on the ears. At the test-site town (≈ 70 km) the shock came ≈ 3 min after the burst with a "strong multiple sound". | MEASURED (primary report) | VNIIEF 1997 p. 235; ru Wikipedia (same report) | **Two sharp cracks ≈ 0.5–1 s apart (gap ESTIMATED), then rolling rumble. At 70 km, a longer multiple rumble.** The cause is not stated in the sources. The likely explanation (ESTIMATED) is two acoustic paths: the direct near-ground wave and a wave bent back down by the temperature inversion. |
| Inversion focusing | The burst took place under a temperature inversion, which bent the shock wave back to the ground "with unusual vehemence". Sakharov noted there was no inversion on 20 Nov. Damage to buildings in **59 settlements**, **28,615 m² of glazing** broken, windows broken up to ≈ 200 km away (in Semipalatinsk city 16 injured and 3 concussions). A meat-packing plant about 100 miles away had its windows blown in. | MEASURED | VNIIEF 1997 p. 237; Sakharov via Wellerstein (link above); https://en.wikipedia.org/wiki/RDS-37; ru Wikipedia | Glass damage far beyond normal 1-psi ranges: an "anomalous" far-field effect. A UI note is worth adding. |
| Casualties | A 3-year-old girl died when a ceiling collapsed in the village of Malye Akzhary. A soldier suffocated when a dugout collapsed at waiting area No. 1, 36 km from the centre (six were buried). 26 + 16 people injured by glass and debris. | MEASURED | VNIIEF 1997 p. 237 | Blurb: "2 people killed" |
| Shock arrival | 35 km ≈ 90 s (Wikipedia: ≈ 90 s at 32 km; physics table ≈ 90 s). 70 km ≈ 3 min (VNIIEF). | MEASURED + ESTIMATED | VNIIEF 1997 p. 235; en Wikipedia | 35 km: 90 s; 60 km (camera): ≈ 160 s |
| Dust | The lower part, a **dust column and billowing dust**, stayed visible for a long time and on an unprecedented scale. The dust rose to the natural clouds and mixed with them into a **lead-black storm cloud** that drifted toward the lab buildings and town. | MEASURED (primary report) | VNIIEF 1997 p. 235 | Big low dust skirt plus dark stem. Late-stage black cloud merging with the overcast. |
| Cloud top / base | "≈ 5–7 min after the burst the radioactive cloud reached 13–14 km, colour red-brown; mushroom diameter 25–30 km" (VNIIEF-derived texts). VNIIEF 1997 itself says aircraft crews saw the **lower boundary** of the cloud at the end of its rise at "1200–1400 m", which is probably missing a zero (12,000–14,000 m). Equatorial Glasstone scaling gives a top of ≈ 24–25 km for 1.6 Mt. Higher-latitude bursts rise less (NRC 1985). | DISPUTED, resolved | VNIIEF 1997 p. 235; Russian mirror (13–14 km, 25–30 km); ru Wikipedia; 02 reference; NRC "The Effects on the Atmosphere of a Major Nuclear Exchange" (1985), https://nap.nationalacademies.org/read/540 | **Base ≈ 13 km, top ≈ 20 km at ≈ 8 min. 14 km is passed at ≈ 3 min. Cap diameter 28 km at 7 min. Colour red-brown, turning grey-blue with crimson glints.** |
| Fallout | Airburst. Outside the test site, external gamma dose < 0.5 R (table 5.5: 0.12–0.23 R at 90–272 km). Trace azimuth 70°, 70 km wide at 200 km. | MEASURED | VNIIEF 1997 pp. 236–237 | — |
| Crater | None (airburst at 1.55 km; scaled height ≈ 132 m/kt^(1/3), and the fireball did not touch the ground) | ESTIMATED (consistent with the low fallout) | Glasstone criterion 180·W^0.4 ft = 1,049 m < 1,550 m | No crater. Scorched, dusty ground and a flattened grass ring. |

### Disputes resolved
1. **Burst height, 1,550 vs 2,000 m.** The VNIIEF official history (1997, p. 234), Russian Wikipedia, MilitaryRussia, atomicarchive and English Wikipedia all give **1,550 m**. 2,000 m appears only in one secondary listing. Use 1,550 m.
2. **Cloud height.** "13–14 km at 5–7 min" is documented, but (a) it is not the stabilised value; (b) VNIIEF says the overcast stopped observers seeing the whole cloud; (c) crews flying at ≤ 12–13 km can judge the cloud **base** better than its top, and the VNIIEF line "lower boundary 1200–1400 m" (an obvious unit error for a 1.6 Mt cloud) points to 12–14 km being the base; (d) the reported 25–30 km cap diameter is typical of a cloud with a top of ≈ 20–25 km. Recommendation: **base 13 km, top 20 km** (below the 24–25 km equatorial scaling because of the November mid-latitude atmosphere).
3. **Condensation ring and skirt on the stem.** Confirmed by the VNIIEF text ("large regions of condensation") and by the published photo (captions on en/ru Wikipedia). Render it.
4. **Double thunder.** Confirmed by the primary report (observers at 35 km). Render two cracks, with the cause left unstated in the UI.
5. **Inversion focusing.** Confirmed by Sakharov's memoir (via Wellerstein and en Wikipedia) and supported by the damage pattern in the VNIIEF report (59 settlements, casualties in Semipalatinsk city about 200 km away). Render it as an anomalously strong far-field shock and glass breakage.
6. **Time "09:47"** is the **release** time, not the detonation time.
7. **Who died and where.** English Wikipedia places the girl's death in Kurchatov, 65 km away. The VNIIEF primary text says she died in the aul (village) of Malye Akzhary. Follow VNIIEF.

### Visual signature (game)
- **Scene:** 22 Nov, low winter sun, flat frozen feather-grass steppe. A solid grey overcast deck at ≈ 8.5–10 km gives flat, cold light. Recommended camera 60 km; historical observers at 35 km. The Tu-16 (white-patched natural metal) releases at 12 km. The bomb descends for a long time under a large round PG-4083 parachute (timing DESIGN). The aircraft is 15 km away at the burst.
- **0–0.1 s:** a blinding flash that lights the underside of the overcast from below. Total white-out.
- **≈ 0.09 s:** brief dip, an orange-red shell ≈ 1.2 km wide (breakaway radius ≈ 580 m).
- **0.1–1.1 s:** rises to the second maximum at ≈ 1.1 s. A **yellow-white sphere swells and turns orange "in a fraction of a second"** (Sakharov), ≈ 1.5 km wide. The heat pulse is felt at 35 km. The overcast base glows yellow-orange over a wide area.
- **0.5–6 s:** a large **condensation (Wilson) dome and discs**, radius ≈ 2–3 km, flash up around the fireball and fade. The shock reflected off the ground climbs back up and **flattens the fireball's underside** (from ≈ 2–4 s). A dusty Mach-stem ring races out across the steppe and raises a low, wide, billowing dust skirt.
- **≈ 10 s:** maximum size **≈ 2 km wide, base ≈ 0.5 km above the ground**. Colour orange. The bright flash is over by **10–12 s**, as seen by the crew.
- **10–60 s:** the fireball rises as a glowing orange-red torus. A **thin, dark, twisting dust stem** is sucked up from the centre of a broad low dust cloud. The cap is red-brown with crimson glints inside. The cap punches into the overcast at ≈ 8.5–10 km within the first 1–2 min.
- **30–120 s:** a **translucent bell-shaped condensation "skirt"** forms around the middle of the stem (about half the cap's width). Thin condensation rings appear where the stem crosses the humid cloud layers.
- **≈ 90 s at 35 km:** **two sharp thunder-like cracks**, ear pressure, the feather-grass flattened. **≈ 3 min at 70 km:** windows and doors blown in, a long multiple rumble. The shock, bent down by the inversion, reaches unusually far (glass broken up to ≈ 200 km).
- **2–8 min:** the cap spreads above the overcast. From the ground mostly the dust column and the underside are visible. From the air, a red-brown cap with top ≈ 20 km and base ≈ 13 km, **28 km wide at ≈ 7 min**, turning grey-blue.
- **10–30 min:** the dust rising to the natural cloud deck mixes with it into a **lead-black storm cloud** that slowly drifts with the wind (azimuth ≈ 70°).

### Ref images
- `docs/refs/16_rds37/analog_cherokee_fireball_xx98.jpg`: ANALOG (Redwing Cherokee, 3.8 Mt air-dropped airburst at ≈ 1.3 km), PD
- `docs/refs/16_rds37/analog_cherokee_wilson_cloud.jpg`: ANALOG, condensation layers, PD
- `docs/refs/16_rds37/analog_cherokee_cloud_005.jpg`: ANALOG colour early fireball, PD
- `docs/refs/16_rds37/carrier_tu16_badger_usn_pd.jpg`: Tu-16 carrier type, PD (US DoD)
- Not downloaded (non-free, for visual reference only): https://www.atomicarchive.com/media/photographs/testing/soviet/rds-37-1.html

### UI blurbs
- **RU:** РДС-37 — первая советская двухступенчатая водородная бомба. 22 ноября 1955 года её сбросили с самолёта Ту-16 на парашюте над Семипалатинским полигоном, и на высоте 1550 м она взорвалась с мощностью 1,6 Мт (расчётная мощность около 3 Мт была намеренно снижена). Температурная инверсия отразила ударную волну обратно к земле: пострадали строения в 59 населённых пунктах, погибли два человека.
- **EN:** RDS-37 was the first Soviet two-stage hydrogen bomb. On 22 November 1955 a Tu-16 dropped it by parachute over the Semipalatinsk test site, and it exploded 1,550 m up with 1.6 megatons (the planned ~3 Mt was deliberately reduced). A temperature inversion bent the shock wave back to the ground, damaging buildings in 59 settlements and killing two people.

---

## Notes for integration
- None of the three bombs needs replacing: Ivy King and RDS-37 are well documented, and B83 is an intentional model.
- Values in the "Game value" columns are rounded for code. The status tags tell the UI where to show "estimate" or "model".
- The DTIC site was under maintenance during this research, so the "65,000 ft in slightly over 4 min / 40,000 ft diameter" King quote was checked only through search-engine extracts. It agrees with the Castle 9.1 measurements once interpolated.
