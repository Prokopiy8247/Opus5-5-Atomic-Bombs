# Research: bombs 01–03 (Mk 82, Mk 84, Tallboy)

Researched 2026-11-07. The scope is only historical, visual and effects data: yield, burst, fireball, cloud, crater, appearance, outer dimensions, mass and paint. No design details are included.

Status labels:
- **MEASURED**: a published specification or a recorded field or test measurement.
- **ESTIMATED**: scaled or derived by me or by a source from formulas or analogues.
- **DISPUTED**: sources disagree, so a reasoned game value is given.

Every row lists its sources. "Game value" is what `data/bombs.json` and the `ExplosionProfile` should use.

---

## 0. Shared findings for the three conventional bombs

### 0.1 TNT equivalence (relative effectiveness, RE)

| Explosive | RE values found | Sources | Note |
|---|---|---|---|
| Tritonal (80 % TNT + 20 % Al) | **1.05** (RE table); "about **18 %** more powerful than TNT" (1.18, energy/impulse basis); 0.93 (heat-of-detonation calculator, weak source) | https://en.wikipedia.org/wiki/TNT_equivalent (RE table) · https://en.wikipedia.org/wiki/Tritonal · https://omnicalculator.com/physics/tnt-equivalent | Aluminium burns late. It adds heat and lengthens the positive phase (impulse) more than it raises peak pressure. |
| Torpex / Torpex D1 (42 % RDX, 40 % TNT, 18 % Al) | **1.30** (RE table); "**50 %** more powerful than TNT by mass" (1.5); "a typical Torpex is **60 %** more powerful than TNT" (1.6, underwater-warhead context) | https://en.wikipedia.org/wiki/TNT_equivalent · https://en.wikipedia.org/wiki/Torpex · C. R. Howe, "Torpedo Warhead Design", J. Naval Eng. 34(2), https://library.imarest.org/record/8412/files/v34b2p07a.pdf | The 1.5–1.6 figures come from underwater/bubble energy. For a blast in soil or air, 1.3 is the defensible value. |

**Status: DISPUTED.** The value depends on the metric: peak pressure, impulse or total energy.

**Recommendation:**
- Tritonal: use **RE ≈ 1.15** (between the 1.05 pressure basis and the 1.18 energy basis). This gives Mk 82 = 87 kg × 1.15 ≈ **100 kg = 0.10 t** and Mk 84 = 429 kg × 1.15 ≈ **493 kg ≈ 0.5 t**. The 0.1 t in the task is **not low**: it is the top of the honest range (91–103 kg).
- Torpex D1: use **RE 1.30**. This gives Tallboy = 2,359 kg × 1.30 ≈ **3.07 t → 3.1 t**. The full range is 3.1–3.8 t.

**Casing caveat (ESTIMATED):** about 55 % of a Mk 80-series bomb's weight is steel case. "Approximately 45 percent of their complete weight is explosive", per GlobalSecurity Mk 84 (https://www.globalsecurity.org/military/systems/munitions/mk84.htm) and the US Navy Airman manual NAVEDTRA 14014 (https://navyaviation.tpub.com/14014/css/14014_183.htm). Part of the energy goes into breaking up and throwing the case, so the free-air blast of a cased bomb is lower than for a bare charge of the same fill. The game should keep the fill TNT equivalent (0.1 / 0.5 / 3.1 t) as the "yield", because that is what the public quotes. The blast-radius module may apply an optional casing factor of about 0.6–0.8 to air-blast overpressure for Mk 82 and Mk 84; this is a design choice, not a measured value.

### 0.2 Bomb crater data: a primary WWII source

US Navy BuOrd **Ordnance Pamphlet 1172**, "Performance of Bombs and Projectiles against Shore Installations" (9 May 1944, declassified). Table 3 gives crater size in feet (depth × diameter) for horizontal bombing. Source: https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USN/USN%20Manuals%20and%20Reports/USN.Perf.Bombs.Project.v.Shore.Installations.1944-05-09.pdf (PDF page 11, "Table 3").

| Bomb (fill) | Release alt. | Clay, inst. fuze | Clay, 0.01 s delay | Clay, 0.1 s delay | Sand, inst. | Sand, 0.01 s |
|---|---|---|---|---|---|---|
| 500 lb GP AN-M64 (~262–267 lb TNT/amatol) | 1,000 ft | 3 × 7 | 9 × 30 | 8 × 29 | 2 × 10 | 7 × 26 |
| " | 10,000 ft | | 10 × 34 | 10 × 35 | | 8 × 28 |
| " | 25,000 ft | | 10 × 36 | 10 × 38 | | 8 × 27 |
| 2,000 lb GP AN-M66 (~1,063–1,117 lb amatol/TNT) | 1,000 ft | 4 × 11 | 12 × 45 | 12 × 45 | 4 × 15 | 11 × 41 |
| " | 10,000 ft | | 15 × 50 | 17 × 56 | | 13 × 43 |
| " | 25,000 ft | | 17 × 54 | 15 × 60 | | 14 × 44 |

The fill weights of AN-M64 and AN-M66 come from https://bulletpicker.com/an-series-bombs.html, https://www.bulletpicker.com/bomb_-2000-lb-gp_-an-m66.html and https://harringtonmuseum.org.uk/an-m64/. These are the same source groups as in the search results: 262 lb amatol / 267 lb TNT for AN-M64, and 1,063 lb amatol / ~1,117 lb TNT for AN-M66.

Key lessons:
1. **An instantaneous (contact) fuze makes a small, shallow crater.** For a 500-lb bomb it is only about 2–3 m wide and 0.6–0.9 m deep, because the charge goes off above the surface.
2. **A short delay of 0.01 s**, with the bomb about 0.6–1.2 m into the soil, makes the classic "bomb crater": 8–11 m for a 500-lb bomb and 12–18 m for a 2,000-lb bomb, with a depth of about 0.3× the diameter.
3. OP 1172 also sketches the **camouflet**: a deep delay-fuzed burst makes an underground chamber with a gas vent and no crater. This is the Tallboy mechanism.

Independent cross-checks:
- **Vietnam bomb craters:** remote-sensing surveys of B-52 craters from 500- and 750-lb bombs report them as "typically only 3 to 12 meters in diameter" (Lin et al. 2020, PLOS ONE, https://pmc.ncbi.nlm.nih.gov/articles/PMC7080274, citing Vad 2017 and Brenner 2018).
- **CNN / Synthetaic 2023:** Gaza satellite analysis found more than 500 craters **over 12 m (40 ft)** wide, which munitions experts called consistent with 2,000-lb bombs in light soil. Reported via https://abc17news.com/news/national-world/cnn-world/2023/12/22/not-seen-since-vietnam-israel-dropped-hundreds-of-2000-pound-bombs-on-gaza-analysis-shows/ and PMC https://pmc.ncbi.nlm.nih.gov/articles/PMC11466298/.
- **The game physics reference** (`02_PHYSICS_REFERENCE.md` §5) uses D ≈ 9.5·W_t^(1/3) m. That gives 4.4 m for 0.1 t and 7.5 m for 0.5 t, which matches a surface or near-surface charge and sits between the OP 1172 instantaneous and delay values.

### 0.3 Fireball size and duration (conventional HE)

| Relation | Source | Mk 82 (≈100 kg = 220 lb TNT) | Mk 84 (≈490 kg = 1,080 lb TNT) |
|---|---|---|---|
| D(ft) = 8.13·W_lb^(1/3) (Cooper, TNT fireball radius) | LANL thesis LA-14209-T, §6.1.3, https://www.osti.gov/servlets/purl/841586 | 15.0 m | 25.4 m |
| D(ft) = 8.5·W_lb^0.341 (UK HSE, munitions/propellants) | same thesis; also quoted from J. Hazard. Mater. A74 (2000) 149–161 at https://boomershoot.com/general/Effects.htm | 16.3 m | 28.0 m |
| D(ft) = 9.21·W_lb^(1/3) (theoretical, full afterburn of TNT) | LA-14209-T | 17.0 m | 28.8 m |
| Fireball stops at about 2.0 m/kg^(1/3) radius (Beirut 2020, AN) | arXiv 2010.13537, https://arxiv.org/pdf/2010.13537 | (D ≈ 18.6 m) | (D ≈ 31.5 m) |
| R ≈ 1.0·m^(1/3) m (`02_PHYSICS_REFERENCE.md` §5) | project reference | 9.3 m | 15.8 m |
| Fireball duration t = 0.0237·D_ft s (HSE "HSE2") | LA-14209-T eq. 6-11 | 1.2 s | 2.0 s |
| Duration ≈ 0.04·m^(1/3) s | project reference | 0.19 s | 0.32 s |

**Status: DISPUTED.** The project reference fireball (R = 1.0 m/kg^(1/3)) is about 40 % smaller than all the published empirical fits (R ≈ 1.6–2.0 m/kg^(1/3)).

The photo check supports the larger value. In the Saber Strike 18 frame (`refs/01_mk82/mk82_explosion_saberstrike18_b.jpg`), the Mk 82 fireball is about 15–20 m wide when compared with 6 m shipping containers.

The `01_BOMBS_REFERENCE.md` values are too large. It gives Ø 40–60 m for Mk 84 and 15–25 m for Mk 82; no source supports 40–60 m for a 0.5 t charge.

**Recommendation:** fireball **R = 1.6·W_kg^(1/3) m**, where W is the TNT equivalent of the fill. This gives **Mk 82 Ø 15 m and Mk 84 Ø 26 m**.

Duration: the HSE 1–2 s describes a full afterburn fireball in still air. In real bomb footage the bright ball is visible for about 0.2–0.4 s before soot and dust swallow it. **Use a bright phase of 0.25 s (Mk 82) / 0.4 s (Mk 84) and visible flame up to about 0.6 s / 1.0 s (ESTIMATED).** By Hopkinson scaling, maximum fireball size is reached within roughly 5–15 ms, which is one frame at 60 fps.

### 0.4 Smoke/dust cloud rise: measured TNT data

H. W. Church, *Cloud Rise from High-Explosives Detonations*, Sandia SC-RR-68-903 (1969), https://digital.library.unt.edu/ark:/67531/metadc1055670/m2/1/high_res_d/4798257.pdf.

The paper fits the 2-minute cloud top as **H(m) = 76·W_lb^(1/4)**, with W in lb TNT (Table III, "4 RC, 13 HE, 5 PHE": K = 76.1). Buoyant rise stops after about 2 min; after that the top grows only by turbulent expansion.

Measured cloud tops for open stacks of TNT on a Nevada dry lake (Table II):

| TNT | 30 s | 1 min | 2 min | 3 min |
|---|---|---|---|---|
| 140 lb (8 shots) | 87–155 m | 143–263 m | 193–397 m | 189–553 m |
| 420–560 lb (3 shots) | 147–196 m | 219–291 m | 286–382 m | 319–461 m |
| 1,600 lb (2 shots) | 212–293 m | 316–385 m | 450–498 m | 552–584 m |
| 2,800 lb under 2.5 m of soil (shot P8) | 358 m | 432 m | 536 m | 645 m |

Applied to the game:
- **Mk 82 (220 lb TNT):** about 130 m at 30 s, 200 m at 1 min and **290 m at 2 min**.
- **Mk 84 (1,080 lb):** about 230 m, 330 m and **440 m** at the same times.

**Status:** MEASURED analogues, ESTIMATED for the bombs. The fit's ±20–35 % scatter comes mostly from atmospheric stability and wind. A real bomb cloud is dirtier: soil loading makes the lower stem darker and heavier and lets it settle sooner, while the top keeps rising like the TNT puffs.

---

## 1. Mk 82 (500-lb general-purpose bomb, USA)

| Fact | Value | Status | Sources | Game value |
|---|---|---|---|---|
| Country, service | USA; Mk 80 series developed in the 1950s, still in service. The warhead of GBU-12 (Paveway II) and GBU-38 (JDAM: "GBU-38(V)1/B Mk 82 and BLU-111"). | MEASURED | https://en.wikipedia.org/wiki/Mark_82_bomb · https://www.globalsecurity.org/military/systems/munitions/mk82.htm · https://en.wikipedia.org/wiki/Joint_Direct_Attack_Munition | USA, 1950s–today |
| Mass | 241 kg (531 lb) typical. The range is 230–260 kg (510–570 lb) depending on fin and fuze configuration. | MEASURED | Wikipedia Mk 82 · GlobalSecurity Mk 82 specs (https://www.globalsecurity.org/military/systems/munitions/mk82-specs.htm, "241 kg / 500 lbs") | **241 kg** |
| Length | 2.21 m (87 in) overall with the conical fin. The body without the fin is about 1.68 m (66.15 in; USAF caption "5 ft 6.2 in"). An af.mil caption gives "7 ft 6.2 in / 18 in diameter", which is an error (18 in is the Mk 84). | MEASURED (overall), DISPUTED (af.mil caption) | Wikipedia · GlobalSecurity specs · USAF caption on https://commons.wikimedia.org/wiki/File:Mk-82_profile_view_picture.jpg | **2.21 m** overall |
| Diameter | 0.273 m (10.75 in) | MEASURED | Wikipedia · GlobalSecurity · USAF caption (Commons) | **0.273 m** |
| Fill | Tritonal, 192 lb = **87 kg** (body text). The infobox says 196 lb / 89 kg, and GlobalSecurity says "89 kg / 192 lb", which is inconsistent. Alternative fills are H-6, Minol II and PBXN-109 (BLU-111). | MEASURED (87–89 kg) | Wikipedia Mk 82 · GlobalSecurity specs · Tritonal article ("87 kg … 863 MJ") https://en.wikipedia.org/wiki/Tritonal | **87 kg tritonal** |
| TNT equivalent | 91–103 kg (RE 1.05–1.18) | DISPUTED (metric), resolved in §0.1 | §0.1 | **0.10 t (100 kg)**. The task's 0.1 t is correct, not low. |
| Burst type | Contact or near-surface. Fuze options include instantaneous, short delay (nose M904 / tail M905) and radar airburst (FMU-113). | MEASURED (options) | GlobalSecurity Mk 82 page ("M904 (nose) and M905 (tail) fuzes or the radar-proximity FMU-113 air-burst fuze") · OP 1172 | **CONVENTIONAL_SURFACE**, short delay: charge centre **−0.7 m** (bomb nose just into the soil) |
| Fireball | Ø about 15 m (formula range 15–17 m; photo about 15–20 m). Full size in about 5–10 ms, bright for about 0.25 s, flame visible up to about 0.6 s. | ESTIMATED / DISPUTED (project ref says Ø 9 m; bombs ref says 15–25 m) | §0.3 · photo `mk82_explosion_saberstrike18_b.jpg` | **R_max 7.5 m; bright 0.25 s; flame end 0.6 s** |
| Visible shock ring | A thin refraction/condensation arc at about 2–2.5 fireball radii (≈ 18–23 m) during the first tens of ms, visible against sky and trees. | MEASURED (photo), sizes ESTIMATED | `mk82_explosion_saberstrike18_b.jpg` (Saber Strike 18, PD) | Shell visible for 0–60 ms; ground dust ring follows the shock |
| Ejecta "crown" / dirt cloud | At 0.3–1 s: a black-grey crown of soil jets about 25–40 m wide and 20–30 m tall | MEASURED (photo, scaled ±30 %) | `mk82_explosion_saberstrike18_a.jpg`, `_c.jpg` | 0.1–1.0 s: crown grows to 35 m wide × 25 m tall |
| Cloud top | About 130 m at 30 s, about 200 m at 1 min, about 290 m at 2 min. The top is a lumpy dark grey-brown puff, roughly 0.5–0.7× as wide as it is tall (about 80–150 m), drifting with the wind. | ESTIMATED from MEASURED TNT analogues | Church 1969 (§0.4) | **H(30 s) 130 m, H(120 s) 290 m**; width about 0.6×H |
| Crater | Instantaneous fuze: about 2–4 m wide, 0.5–1 m deep. Short delay: about 7–8.5 m wide, 1.8–2.5 m deep (OP 1172 AN-M64 values scaled by (fill ratio)^(1/3) ≈ 0.92). Vietnam craters span 3–12 m. | MEASURED (analogues), ESTIMATED (Mk 82) | OP 1172 Table 3 · PLOS ONE 2020 (PMC7080274) · `02_PHYSICS_REFERENCE.md` (4.4 m) | **Ø 7 m, depth 2 m**, with a low lip of 0.3–0.5 m. This is inside the task's "5–8 m". |
| Fragments | The steel case (about 150 kg) breaks into thousands of fragments. Dust puffs and impact sparks appear out to about 100–300 m, with rare fragments much further. Sources range from a 120 m "lethal" radius (for Mk 84) to forum figures of 245 m danger-close and about 760 m (2,500 ft) maximum throw. | DISPUTED / ESTIMATED (no primary public table retrieved) | Wikipedia Mk 84 (lethal frag 400 ft) · DCS/BMS forum threads quoting EOD data (weak) | Visual fan: dense to **150 m**, sparse to **300 m**. Optional hazard flag beyond 500 m. |
| Paint | Olive drab with a yellow band near the nose, which is the US high-explosive colour code (yellow = HE; olive drab = non-significant body colour). Navy thermally protected versions (BLU-111) are grey with a yellow band. | MEASURED | NAVEDTRA 14014 "Ammunition Color Codes", https://navyaviation.tpub.com/14014/css/14014_182.htm · photo `mk82_bombs_kittyhawk_1972.jpg` | **Olive drab, yellow nose band about 76 mm** (band width per the bombs ref; not re-verified) |
| Variants and look | Low-drag conical fin (cruciform). The Snakeye (Mk 15 fin) has 4 folding retarder blades. The AIR variant (BSU-49) has an inflatable "ballute". | MEASURED | Wikipedia Mk 82 · GlobalSecurity specs · NMUSAF fact sheet "MK82 Air Inflatable Retarder Bomb" (https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/197591/) | Model: low-drag conical fin, 2 lugs on top |

**Visual signature (Mk 82, contact or short-delay ground burst, soft soil, daylight):**
- **T+0–10 ms:** a sharp white-yellow point flash. Aluminium in the tritonal makes it whiter than plain TNT. The light pulse is short, so the exposure dip should be 1–2 stops, not 5–8. The fireball reaches about Ø 15 m almost at once, one frame at 60 fps.
- **T+10–60 ms:** a yellow-orange ball (about 1,800–2,500 K), edged with black soot on one side within a few frames. A thin refraction/condensation shell runs ahead to about 20–25 m, and a white dust skirt lifts at ground level as the shock sweeps outward.
- **T+0.05–0.3 s:** the ball turns orange-red and is swallowed by a **black-grey crown** of soil jets. These are radial spikes, ragged and "hairy", with clods arcing out. Low dust puffs from fragment impacts appear in a ring out to about 100–150 m.
- **T+0.3–1 s:** the crown peaks at about 35 m wide × 25 m tall. Residual orange flame may flicker at the base until about 0.6 s. Clods and soil fall back and a tan dust skirt rolls out to about 30–40 m.
- **T+1–30 s:** the dark cloud detaches into a lumpy grey-black-brown puff that rises and grows: about 60 m at 5 s and about 130 m at 30 s. Wind shears it. No cap or stem forms; it is a dirty thermal.
- **T+30–120 s:** the cloud fades to grey-brown and reaches about 290 m at 2 min, then disperses.
- **Ground:** a 7 m wide × 2 m deep crater with dark ejecta flecks on the ground out to about 20–30 m, and scorched soil at the rim.
- **Sound:** a sharp crack, with no long rumble.

**Ref images (in `docs/refs/01_mk82/`):** `mk82_explosion_saberstrike18_b.jpg` (fireball and shock arc), `mk82_explosion_saberstrike18_c.jpg` (crown at about 0.5 s), `mk82_explosion_saberstrike18_a.jpg` (black plume at about 1 s), `mk82_bombs_kittyhawk_1972.jpg` (paint). All are PD US government photos; see `SOURCES.md`.

**Blurb RU:** Mk 82 — стандартная американская 500-фунтовая (≈241 кг) авиабомба общего назначения: в строю с 1950-х годов до наших дней, она же — боевая часть управляемых GBU-12 и GBU-38 JDAM. Внутри около 87 кг тритонала (80 % тротила и 20 % алюминиевой пудры), это примерно 0,1 т в тротиловом эквиваленте. Самый слабый взрыв в коллекции и точка отсчёта для всех остальных.

**Blurb EN:** The Mk 82 is the standard US 500-lb (≈241 kg) general-purpose bomb, in service from the 1950s to this day and the warhead of guided weapons such as the GBU-12 and GBU-38 JDAM. It holds about 87 kg of tritonal (80% TNT, 20% aluminium powder), roughly 0.1 t of TNT equivalent. It is the weakest blast in the collection and the yardstick for all the others.

---

## 2. Mk 84 (2,000-lb general-purpose bomb, USA)

| Fact | Value | Status | Sources | Game value |
|---|---|---|---|---|
| Country, service | USA; Mk 80 series from the 1950s, used heavily in Vietnam. More than 12,000 were expended in Desert Storm. It is the body of GBU-10, GBU-15, GBU-24, GBU-31 JDAM and AGM-130. | MEASURED | https://en.wikipedia.org/wiki/Mark_84_bomb · https://www.globalsecurity.org/military/systems/munitions/mk84.htm ("Most of the over 12,000 MK-84s expended during Desert Storm…") | USA, 1950s–today |
| Mass | 925 kg (2,039 lb) typical; range 894–945 kg | MEASURED | Wikipedia · GlobalSecurity specs (https://www.globalsecurity.org/military/systems/munitions/mk84-specs.htm) · FAS mirror (https://gulflink.health.mil/al_muth/al_muth_refs/n58en036/mk84.htm) | **925 kg** |
| Length | **3.28 m (129 in)** with the conical fin (FAS, GlobalSecurity; a USAF caption gives "10 ft 9 in" = 3.28 m). Wikipedia gives **3.84 m (12 ft 7 in)**, probably a different tail/fuze configuration. | DISPUTED | FAS/gulflink · GlobalSecurity specs · Wikipedia infobox | **3.28 m** (two independent official-derived sources agree). The `01_BOMBS_REFERENCE.md` value of 3.84 m should be corrected. |
| Diameter | 0.46 m (18 in); tail span 0.64 m | MEASURED | Wikipedia · FAS · GlobalSecurity | **0.457 m** |
| Fill | 945 lb = **429 kg** tritonal (or H-6 / PBXN-109) | MEASURED | Wikipedia · FAS · GlobalSecurity | **429 kg tritonal** |
| TNT equivalent | 450–506 kg (RE 1.05–1.18) | DISPUTED (metric), resolved in §0.1 | §0.1 | **0.5 t** (493 kg at RE 1.15) |
| Burst type | Contact or short delay. Air-burst fuzes exist. | MEASURED (options) | GlobalSecurity · OP 1172 | **CONVENTIONAL_SURFACE**, short delay: charge centre **−1.2 m** |
| Fireball | Ø about 26 m (formula range 25–29 m). Full size in about 10–15 ms, bright for about 0.4 s, flame visible up to about 1.0 s. | ESTIMATED / DISPUTED (bombs ref Ø 40–60 m is too large; project formula gives Ø 16 m) | §0.3 · Vietnam photo (orange balls) | **R_max 13 m; bright 0.4 s; flame end 1.0 s** |
| Smoke / dust column | Early: an orange ball under a **black cauliflower smoke cap**, with a grey-tan dust cloud alongside (USMC 2007 photo). About 1 s: column about 50–70 m wide × 40–60 m tall (×1.7 of Mk 82 by W^(1/3), ESTIMATED). | MEASURED (photos, qualitative) / ESTIMATED (sizes) | `mk84_2000lb_explosion_usmc_2007_a.jpg`, `_b.jpg`, `mk84_explosion_vietnam_1972.jpg` | 1 s: column 60 m wide × 50 m tall |
| Cloud top | About 230 m at 30 s, about 330 m at 1 min, about 440 m at 2 min | ESTIMATED from MEASURED TNT analogues | Church 1969, 1,600-lb shots: 212–293 / 316–385 / 450–498 m | **H(30 s) 230 m, H(120 s) 440 m** |
| Crater | Instantaneous: 3.4–4.6 m wide, 1.2 m deep (OP 1172 2,000-lb GP). Short delay: 12.5–16.5 m wide, 3.4–5.2 m deep (OP 1172; the AN-M66 fill ≈ Mk 84 TNT equivalent). Wikipedia: "crater 50 ft (15 m) wide and 36 ft (11 m) deep" (unsourced; the depth/width ratio of 0.72 is implausible for an apparent crater and probably reflects penetration depth or a disturbed zone). Gaza 2023: ≥12 m craters attributed to 2,000-lb bombs. | DISPUTED (depth); width MEASURED (analogues) | OP 1172 Table 3 · Wikipedia Mk 84 · CNN/Synthetaic via PMC11466298 | **Ø 13 m, depth 4 m**, lip 0.5–1 m. Width agrees with all three sources; depth follows OP 1172, not the 11 m. |
| Fragments | Wikipedia: lethal fragmentation to 400 ft (120 m). Older versions and forum posts give 400 yd / 1,200 ft and higher maximum throw. A wide **fan of fragment splashes** is visible in the USMC 2007 photo. | DISPUTED | Wikipedia Mk 84 · DCS forum (weak) · photo `_a.jpg` | Visual fan dense to **250 m**, sparse to **500 m** |
| Penetration (context) | Up to 15 in (38 cm) of metal or 11 ft (3.4 m) of concrete, depending on drop height | MEASURED (spec claim) | Wikipedia Mk 84 | Not needed |
| Paint | Olive drab with a yellow nose band (HE). Training rounds have a blue band. | MEASURED | NAVEDTRA 14014 colour codes · photo `mk84_bombs_desert_storm_1991.jpg` · Commons "Mk-84 xxl.jpg" caption (blue band = inert) | **Olive drab, yellow nose band**, conical cruciform fin |

**Visual signature (Mk 84, short-delay ground burst, dry soil, daylight):**
- **T+0–15 ms:** a hard white-yellow flash, brighter and larger than the Mk 82 (exposure dip about 2 stops). The fireball reaches about Ø 26 m in 1–2 frames.
- **T+15–100 ms:** a **bright orange ball** with a boiling surface. A refraction shell and a **visible ground shock ring** (a lifted dust annulus) run out over dry ground, passing about 50 m at roughly 0.05 s and about 100 m at roughly 0.15 s (radii from the physics module). In humid air a brief white condensation shell may appear.
- **T+0.1–0.5 s:** black soot rolls up from the top of the ball into a **black-brown cauliflower cap**. Soil jets burst radially as a dark crown about 50–70 m wide. The fragment fan throws dust puffs (or water splashes) in a ring out to about 250 m, and sparse ones further.
- **T+0.5–1 s:** orange flame dies inside the dark column. The column is about 60 m wide × 50 m tall. A tan dust skirt and base ring roll out to about 60–80 m.
- **T+1–30 s:** a black-brown column and puff rise as a dirty thermal: about 100 m at 5 s and about 230 m at 30 s. The lower part turns grey-tan with dust and drifts; brown dust settles downwind.
- **T+30–120 s:** the cloud top reaches about 440 m at 2 min, greying and dispersing. There is no true mushroom, only a lumpy, wind-sheared puff.
- **Ground:** a crater Ø 13 m × 4 m with a raised rim and a ring of thrown clods to about 30–50 m. Light objects are flattened and dust is lifted out to the 1 psi radius.
- **Sound:** a deep, heavy boom with a short rumble.

**Ref images (in `docs/refs/02_mk84/`):** `mk84_explosion_vietnam_1972.jpg` (orange balls and black smoke from above), `mk84_2000lb_explosion_usmc_2007_a.jpg` (fireball, black cap, fragment splashes), `mk84_2000lb_explosion_usmc_2007_b.jpg` (later dust cloud and ejecta jet), `mk84_bombs_desert_storm_1991.jpg` (shape and paint). All are PD US government photos.

**Blurb RU:** Mk 84 — самая тяжёлая бомба американской серии Mk 80: около 925 кг, из них 429 кг тритонала, то есть примерно 0,5 т в тротиловом эквиваленте. На её основе сделаны управляемые GBU-10, GBU-24 и GBU-31 JDAM, а только за «Бурю в пустыне» (1991) было сброшено больше 12 000 таких бомб. При подрыве с небольшим замедлением в мягком грунте она оставляет воронку 12–15 м в поперечнике.

**Blurb EN:** The Mk 84 is the heaviest member of the US Mk 80 family: about 925 kg, including 429 kg of tritonal, or roughly 0.5 t of TNT equivalent. It is the basis of the GBU-10, GBU-24 and GBU-31 JDAM guided bombs, and more than 12,000 were dropped in Desert Storm (1991) alone. With a short fuze delay in soft ground it leaves a crater 12–15 m across.

---

## 3. Tallboy ("Bomb, Medium Capacity, 12,000 lb", UK)

| Fact | Value | Status | Sources | Game value |
|---|---|---|---|---|
| Country, service | UK, designed by Barnes Wallis; used 1944–45 by Nos. 617 and 9 Squadrons RAF (Lancaster). **854** dropped. | MEASURED | https://en.wikipedia.org/wiki/Tallboy_(bomb) · Bomber Command Museum of Canada, https://bombercommandmuseumarchives.ca/s,tallboy.html | UK, 1944–45 |
| Mass | About 12,000 lb ≈ **5,400 kg** (Wikipedia; IWM caption "12,000-lb (5,443 kg)"). GlobalSecurity gives 11,855 lb (5,377 kg). | MEASURED (±1 %) | Wikipedia · IWM CH 15380 caption on Commons · GlobalSecurity https://www.globalsecurity.org/military/systems/munitions/tallboy.htm | **5,400 kg** |
| Length | 21 ft = **6.40 m** overall; the body is about 10 ft 4 in (3.15 m), the rest is the long tail cone and fins | MEASURED | Wikipedia · BCM Canada · GlobalSecurity | **6.40 m** |
| Diameter | Body 38 in = **0.97 m** (3 ft 2 in); fin span about 3 ft 8 in (1.12 m) | MEASURED | Wikipedia · BCM Canada (38 in) · GlobalSecurity | **0.97 m** body; 1.12 m fin span |
| Fill | Torpex D1, **5,200 lb = 2,359 kg**. The "TORPEX D1" stencil is visible on IWM CH 15363. | MEASURED | Wikipedia · BCM Canada · GlobalSecurity · photo | **2,359 kg Torpex D1** |
| TNT equivalent | 3.07 t (RE 1.30) to 3.5–3.8 t (RE 1.5–1.6, underwater-energy basis) | DISPUTED, resolved in §0.1 | §0.1 | **3.1 t** |
| Release, impact | Optimum release 18,000 ft (5,500 m) at about 170 mph; fall about **37 s**; impact about **750 mph ≈ 335 m/s** (≈1,210 km/h). GlobalSecurity's "3,600–3,700 ft/s" is an error: it would be about Mach 3 and contradicts 750 mph. | MEASURED (750 mph, 37 s); DISPUTED (GlobalSecurity) | Wikipedia · BCM Canada ("750 mph … 37-second fall") · GlobalSecurity | Impact **335 m/s**; fall about 37 s, compressed by the game's flight time |
| Penetration and burst depth | Saumur, 8/9 June 1944: one Tallboy went through the hillside and **exploded about 60 ft (18 m) below the surface**, blocking the tunnel. Design intent was to burst deep enough to form a **camouflet** (cavern) that removes a structure's support ("trapdoor effect"). It could penetrate 16 ft (4.9 m) of concrete. | MEASURED (Saumur depth, one event); qualitative | Wikipedia Tallboy · Wikipedia Earthquake bomb (https://en.wikipedia.org/wiki/Earthquake_bomb) · OP 1172 camouflet sketch | **CONVENTIONAL_BURIED, burst depth −18 m** |
| Fuze delay | Tail pistols with delays from seconds up to 30–60 min (sources vary) | DISPUTED (minor) | Wikipedia (No. 58 tail pistols) · BCM Canada ("up to 60 minutes") | Game: detonate **1.5 s** after impact so the impact puff is seen first |
| Crater | **About 100 ft (30 m) across** (Wikipedia, GlobalSecurity, hmdb marker at Brooklands, https://www.hmdb.org/m.asp?m=118208). Saumur reconnaissance of 9 June 1944: craters **100 ft and "nearly 110 ft" across** (IBCC Digital Archive, https://ibccdigitalarchive.lincoln.ac.uk/items/show/16508). Depth "80 ft (24 m)" (Wikipedia, GlobalSecurity; unsourced). Unsourced forum report of the single UK test drop (Ashley Walk range, New Forest): "Crater was 130 feet wide by 30 feet deep" (40 × 9 m) (post by "tigbrand", 22 Oct 2009, https://www.bocn.co.uk/threads/tallboy-bomb.58083/). The crater still exists and is photographed on Geograph/Commons ("Ashley Walk Bombing Range – Tallboy bomb crater", CC BY-SA, so not downloaded). | Width MEASURED (≥2 independent); depth DISPUTED | as listed | **Ø 30 m, depth 10 m**, raised lip 1.5–2 m. An apparent crater 24 m deep and 30 m wide is not physically plausible for ejecta fallback; 24 m is closer to the burst depth plus the disturbed zone. |
| Fireball | **None visible** for a deep burst. At most a dull orange glow in the vent for under 0.2 s if it bursts shallow. | ESTIMATED (physics: buried burst, scaled depth ≈ 1.2 m/kg^(1/3)) | OP 1172 camouflet sketch; task §6.3 | No fireball; optional faint vent glow |
| Ground heave and column | The surface domes up, vents, and throws a **spiky dark column of soil and smoke**. The Tirpitz attack photo (IWM C 4775) shows a shore Tallboy burst as a crown of soil jets with a white-grey dust ring. For the 12 Nov 1944 hit on the ship, a "column of steam and smoke rose to roughly 300 feet". | MEASURED (photos, qualitative) · single secondary account for 300 ft | IWM C 4775 (Commons) · Bomber Command Museum of Canada, https://www.bombercommandmuseum.ca/bomber-command/sinking-of-the-battleship-tirpitz/ | Column **60–120 m** by 2–3 s |
| Cloud top | About 150–300 m by 30–60 s | ESTIMATED: buried, so less buoyant than a surface 3 t charge, whose Church value would be about 690 m | Church 1969 scaling plus a burial reduction (judgement) | **H(30 s) 180 m, H(120 s) 300 m** |
| Air blast | Much weaker than a 3 t surface burst; most energy goes into the ground ("earthquake"). | ESTIMATED | buried-burst physics (judgement) | Air-blast **effective yield ≈ 0.2 t** (about 5–10 % of 3.1 t) for the pressure and glass calculations; strong ground shake within about 200 m |
| 2020 Świnoujście event | On 13 Oct 2020 an unexploded Tallboy in the Piast Canal (Poland) **detonated during a deflagration (burn-out) attempt**. It lay buried in mud about **12 m (39 ft)** below the waterline. Video shows a towering plume of water and steam ("hundreds of feet"; no measured height published). There were no injuries and 750+ people had been evacuated. | MEASURED (event), height not measured | Wikipedia Tallboy · TWZ https://www.twz.com/37064/watch-the-biggest-unexploded-world-war-two-bomb-ever-found-in-poland-blow-up · Global News https://globalnews.ca/news/7396050/poland-bomb-explosion-tallboy-earthquake | Blurb fact only |
| Paint / look | Not documented in the sources found. Photos show a dark uniform body (B&W; probably RAF "bronze green" class colour, a weak hobby-paint source), a thin light ring near the nose, a "TORPEX D1" stencil, a long tapering aluminium tail cone, and 4 fins offset about 5° to spin the bomb. The in-flight photo shows a light nose and tail with a darker mid band. | MEASURED (shape, fins); paint DISPUTED / undocumented | IWM CH 15363, CH 15380 (Commons) · BCM Canada (5° fins, hardened nose >4 in thick) | **Dark olive/bronze-green body, light grey nose ring, white stencil**, long cone tail with 4 offset fins |

**Visual signature (Tallboy, penetrating burst at −18 m in soft soil or clay, daylight):**
- **T−1.5 s (impact):** a 5.4 t bomb arrives at about 335 m/s, almost vertical. It throws a small sharp puff of soil (a jet of dust about 5–10 m high) and leaves an entry hole about 1–1.5 m wide. There is no explosion yet.
- **T+0 (detonation, underground):** no flash at all. A ground shock reaches the surface in about 10–20 ms. A **ring of dust jumps off the ground** (spall) out to about 40–60 m, and the camera, trees and objects shake.
- **T+0.05–0.4 s:** a **dome of earth heaves up** about 3–6 m high and 30–40 m wide, cracking radially. Dust spurts from the cracks.
- **T+0.3–1 s:** the dome ruptures and a **geyser of dark brown-black soil and grey-white smoke/gas** bursts upward. It is a spiky crown of jets with big clods and blocks on ballistic arcs. There is no orange fireball; at most a dull red-orange glimmer deep in the vent for a few frames.
- **T+1–3 s:** the column reaches about 60–120 m, then its spikes slow. Ejecta falls back as a curtain and a **low brown base surge rolls outward** to about 100–200 m radius. Thrown blocks land out to about 150–250 m.
- **T+3–10 s:** the column collapses into a broad brown-grey dust cloud. The crater rim appears as the dust thins. The surface may slump into the cavity (subsidence) for several seconds after.
- **T+10–120 s:** a dirty brownish-grey cloud drifts and rises lazily to about 180 m at 30 s and about 300 m at 2 min. There is no cap or stem.
- **Ground:** a crater Ø 30 m and about 10 m deep, a lip of 1.5–2 m, and a fresh-soil apron out to about 40–60 m. This is the bright halo seen in the Saumur reconnaissance photo.
- **Sound and tremor:** observers feel a **ground tremor before the air sound**. The air blast is a muffled heavy thump, not a sharp crack, followed by a long rumble of falling debris.

**Ref images (in `docs/refs/03_tallboy/`):** `tallboy_tirpitz_attack_1944_C4775.jpg` (soil-jet crown and smoke cloud, 12 Nov 1944), `tallboy_saumur_tunnel_crater_1944_CL80.jpg` (crater field, about 30 m craters with bright aprons), `tallboy_hoisted_woodhall_spa_1944_CH15363.jpg` (shape and stencil), `tallboy_falling_watten_1944_CH15380.jpg` (in flight). All are PD (UK Crown Copyright expired, IWM).

**Blurb RU:** Tallboy — британская 12 000-фунтовая (≈5,4 т) «сейсмическая» бомба конструктора Барнса Уоллиса с 2,4 т торпекса (≈3 т в тротиловом эквиваленте). Сброшенная с высоты около 5,5 км, она врезалась в землю на скорости около 1200 км/ч и взрывалась глубоко под поверхностью, обрушивая цели: так в 1944 году были завалены железнодорожный тоннель в Сомюре и потоплен линкор «Тирпиц». За войну сбросили 854 такие бомбы, а одна неразорвавшаяся сдетонировала под водой в польском Свиноуйсьце в 2020 году.

**Blurb EN:** Tallboy was Barnes Wallis's British 12,000-lb (≈5.4 t) "earthquake bomb", filled with 2.4 t of Torpex (about 3 t of TNT equivalent). Dropped from about 5.5 km, it struck the ground at roughly 1,200 km/h and exploded deep underground, bringing targets down from below: in 1944 it blocked the Saumur railway tunnel and sank the battleship Tirpitz. 854 were dropped during the war, and an unexploded one detonated underwater at Świnoujście, Poland, in 2020.

---

## 4. Corrections and recommendations for `01_BOMBS_REFERENCE.md` / `bombs.json`

1. **Mk 82 yield 0.1 t is confirmed**, not low: the range is 91–103 kg TNT for 87 kg of tritonal. Keep 0.1 t.
2. **Mk 84 length:** use **3.28 m** (FAS, GlobalSecurity and a USAF caption agree), not 3.84 m (Wikipedia only).
3. **Mk 84 crater depth 11 m is implausible.** Use Ø 13 m × 4 m (OP 1172 2,000-lb GP data, Gaza ≥12 m).
4. **Fireball sizes:** the bombs reference values are too large (Mk 82 15–25 m; Mk 84 40–60 m) and the physics-reference formula is too small (R = 1.0·m^(1/3)). Use **R = 1.6·W_kg^(1/3)**: Mk 82 Ø 15 m and Mk 84 Ø 26 m. Suggest updating `02_PHYSICS_REFERENCE.md` §5 to this coefficient, with the Cooper and HSE sources.
5. **Mk 82 crater** 5–8 m (task) is confirmed for a short-delay burst. Contact (instantaneous) bursts give only about 2–4 m. Game: Ø 7 m × 2 m with a −0.7 m burst.
6. **Tallboy crater depth** "up to 24 m" is disputed. Use Ø 30 m × 10 m with a burst at −18 m (Saumur). A camouflet (no crater, just subsidence) would occur if the burst were much deeper than about 25–30 m. The game could offer this as a variant.
7. **Tallboy yield:** 3.1 t (RE 1.3 for Torpex D1). The air-blast effective yield is about 0.2 t because it is buried.
8. **Cloud heights for conventional bombs:** use Church (1969), H_2min = 76·W_lb^(1/4) m, which is measured on TNT stacks from 140 to 2,800 lb. This gives Mk 82 about 290 m and Mk 84 about 440 m at 2 min. These bombs have no mushroom and no cap.
9. **Shock visibility:** a thin refraction/condensation arc is clearly visible in a PD photo of a real Mk 82 burst (Saber Strike 18). Keep the visible shock shell even for the smallest bomb, lasting about 50 ms.

## 5. Proposed `ExplosionProfile` numbers (summary)

| Param | Mk 82 | Mk 84 | Tallboy |
|---|---|---|---|
| yield_t (TNT eq.) | 0.10 | 0.50 | 3.1 (air-blast effective 0.2) |
| burst_type | CONVENTIONAL_SURFACE | CONVENTIONAL_SURFACE | CONVENTIONAL_BURIED |
| burst_height_m | −0.7 | −1.2 | −18 |
| fireball R_max (m) / time to max (s) | 7.5 / 0.01 | 13 / 0.015 | 0 (none) |
| bright phase / flame end (s) | 0.25 / 0.6 | 0.4 / 1.0 | — / (vent glow ≤ 0.2) |
| exposure dip (stops) | 1–2 | 2 | 0 |
| ejecta crown at 1 s, W × H (m) | 35 × 25 | 60 × 50 | heave dome 35 × 5 at 0.3 s, then column 60–120 m tall at 2–3 s |
| cloud top 30 s / 120 s (m) | 130 / 290 | 230 / 440 | 180 / 300 |
| cloud colours | black-grey to grey-brown | black-brown to grey-tan | dark brown soil + grey-white smoke to brownish grey |
| crater D × depth (m) | 7 × 2 | 13 × 4 | 30 × 10 |
| fragment fan dense / sparse (m) | 150 / 300 | 250 / 500 | clods and blocks to 150–250 |
| base surge / dust ring radius (m) | 30–40 | 60–80 | 100–200 |
| recommended view distance (km) | 2 | 3 | 4 |
