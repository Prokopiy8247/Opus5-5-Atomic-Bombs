# Techniques and Physics: verified formulas and rendering recipes

Research part for `docs/RESEARCH_NOTES.md`. Written 2026-11-07 by the techniques/physics research subagent.
Scope: (A) a cross-check of every formula in `docs/02_PHYSICS_REFERENCE.md` against primary sources, with corrections; (B) implementable rendering and audio recipes for Godot 4.7, with every API checked against the 4.7 stable docs.
Only public effects data is used (sizes, timings, pressures, fluences, cloud dimensions). Nothing about weapon design.

Status labels:
- **FIT**: a published curve fit to measured test data, transcribed from the primary document.
- **MEASURED**: a value read from a test record or source text.
- **DERIVED**: computed here from FIT or MEASURED sources, or my own fit to them, checked numerically.
- **ESTIMATED**: an engineering or visual heuristic, physically motivated but not validated against data.
- **DISPUTED**: sources disagree. The resolution and the value to use are given.

All numerics were computed in Python (scripts in the session scratchpad) from the coefficients quoted below. W is yield in kilotons. Distances are in metres unless stated.

---

## 0. The corrections that matter most (read this first)

| # | Item in 02_PHYSICS_REFERENCE.md | What it says | Correct / recommended | Status |
|---|---|---|---|---|
| 1 | Surface-burst blast radii | "× ≈ 0.8 of the airburst radii" | The surface/optimum-HOB ratio depends on pressure: **1 psi 0.55, 3 psi 0.60, 5 psi 0.64, 10 psi 0.70, 20 psi 0.77, 50 psi 0.85, 100 psi 0.90**. 1 kt contact burst: 1 psi 1.19 km, 3 psi 0.59, 5 psi 0.44, 10 psi 0.305, 20 psi 0.216, 50 psi 0.140 km | FIT (Fletcher 1963 eq. 2.5 = G&D 1962; the NUKEMAP 1977 knee data agree within 4%) |
| 2 | Far field below 1 psi | p ≈ 2200·W^(1/3)/R | That overestimates by ×1.4 at 5·R(1 psi) and ×1.7 at 10·R(1 psi). Use the DNA 1-kt free-air standard, where p falls off as 1/(R·√ln R) (formula in A3.4). | FIT |
| 3 | Sedov–Taylor table, "1 s" column | 1 kt 290 m, 15 kt 498 m, 1 Mt 1150 m | At 1 s the shock is no longer strong. Use the inverse of the DNA time-of-arrival formula, which gives **1 kt 506 m, 15 kt 682 m, 1 Mt 1280 m, 15 Mt 2065 m, 50 Mt 2584 m** at 1 s. The 1/10/100 ms columns are correct within 5%. | FIT |
| 4 | Sedov energy | "E ≈ 0.5·W (airburst)" (yet the Trinity check uses the full W) | Both are roughly right but in different cases. **E = 0.5 W in free air.** A surface or tower hemisphere acts like a free-air sphere of 2 × 0.5 W = W in the ideal case; Trinity's data fit best with **E ≈ 0.8 W**. With E = 0.8 W, Trinity (21 kt, tower) gives 76/112/134 m at 6/16/25 ms against the measured 75/108/138 m. E = W gives 79/117/140 m. | DERIVED |
| 5 | t_min (first thermal minimum) | 0.0022·W^0.5 s | **t_min ≈ 3.5·W^0.4 ms**. G&D §2.125–2.126 give 11 ms at 20 kt with time ∝ W^0.4; Small & Brode give 3.8·W^0.4 ms ±35%. 1 Mt: 55 ms (not 70). 50 Mt: 0.27 s (not 0.49). | FIT |
| 6 | t₂ (second maximum) | 0.039·W^0.45 s | Use G&D 1977 eq. 7.85.1, **t₂ = 0.0417·W^0.44 s** (burst below 15,000 ft). The numbers are almost the same (1 Mt: 0.87 s). | FIT |
| 7 | Time to maximum fireball size | 0.25·W^0.5 s | **≈ 10·t₂ = 0.42·W^0.44 s**. G&D: 1 Mt about 10 s (§2.05), 20 kt "a second or so" (§2.121). Formula: 1 Mt 8.7 s, 20 kt 1.6 s. | DERIVED |
| 8 | Thermal pulse cumulative fraction | 90% by 12·t₂ | The G&D 1962 fit (Fletcher eq. 2.112) gives **20% at t₂, 48% at 2t₂, 69% at 5t₂, 80% at 9t₂**. The recommended pulse shape gives 90% only at ≈ 20·t₂. Use the shape **P/Pmax = (15/7)τ²/(1 + (8/7)τ^3.75)** with τ = t/t₂ (A2.3). | DERIVED from FIT |
| 9 | Contact-burst max fireball radius | 290·W^0.4 ft (88 m) | **79 m·W^0.4** (260 ft; G&D 1962 via Fletcher Fig. 2.19). NUKEMAP uses 88 m (2 × 145 ft breakaway). With a factor (W/1000)^−0.03 above 1 Mt, Bravo (15 Mt) gives a 6.8 km diameter against the ≈ 7 km observed, and Tsar (50 Mt, air) gives 8.2 km against ≈ 8 km. The airburst value of 61 m·W^0.4 (200 ft) is confirmed. | DISPUTED → resolved |
| 10 | Arrival-time table | e.g. 1 kt @1 km 2.1 s; 50 Mt @100 km 254 s | 5–15% too early. The DNA formula reproduces G&D exactly (20 kt: 3.1 s @1 mi and 7.6 s @2 mi; 1 Mt: 1.25 s @1 mi and 4.5 s @2 mi). Corrected table in A3.6. | FIT |
| 11 | Positive-phase duration constants c(p) | 5 psi 0.40, 2.5 psi 0.52, 10 psi 0.30 | Optimum HOB (Fletcher eq. 2.68): **100 psi 0.097, 50 0.139, 20 0.208, 10 0.267, 5 0.331, 2.5 0.401, 1 0.505 s·W^(1/3)** | FIT |
| 12 | Atmospheric transmission of light/heat | T = exp(−d/25 km) | Far too opaque beyond about 20 km. Use **τ = exp(−k·d_km^0.44)** with k = 0.14 (very clear air, 80 km visibility; reproduces G&D/Fletcher) or k = 0.22 (typical air; reproduces Sublette's burn ranges). A 1 Mt flash at 50 km peaks at 6–9 × solar irradiance; a 50 Mt flash at 100 km at 8–16 × (not ≈ 1 ×). | DERIVED |
| 13 | Burn radii | Sublette, r3 = 0.67·W^0.41 km | Sublette corresponds to typical haze. NUKEMAP-consistent clear-air values (G&D 1977 Fig. 12.65 thresholds + Fletcher Q(D)) are **R3 ≈ 0.65·W^0.44, R2 ≈ 0.79·W^0.44, R1 ≈ 1.12·W^0.43 km**: 1 Mt 13.5/16.5/22.3 km, 15 Mt 43/52/69 km. Use clear air for desert and sea test sites. | DISPUTED → resolved |
| 14 | Cloud top vs yield | 1 Mt 23.5 km "[S]" | That value is **equatorial** (Shreve/Kellogg 1961: 50 kt 12.2, 100 kt 14.6, 1 Mt 23.5, 10 Mt 32.0 km). Mid-latitude G&D Fig. 9.96 gives 1 Mt 19.8 km and 10 Mt 29.4 km. The Miller 1963 fit used by NUKEMAP gives 1 Mt 24.3 km. Use the Miller top for humid/tropical sites, × 0.82 for dry mid-latitude ones, and per-bomb measured overrides for ≥ 10 Mt (formulas in A5). | DISPUTED → resolved |
| 15 | Cap radius | (table) | **a = 0.713 km·W^0.431** (Miller; NUKEMAP). It matches DELFIC: 10 kt 1.9 (DELFIC 1.5), 100 kt 5.2 (5.0), 1 Mt 14.0 (15) km. The FAS/Purnell fit to G&D Fig. 2.16 (0.017·W^0.83 + 2 km) underestimates at 0.1–1 Mt. | FIT |
| 16 | Conventional HE blast | 1 t: R(1 psi) 220 m, R(5 psi) 71 m, 1-psi arrival 0.54 s | Kingery–Bulmash (Swisdak, hemispherical TNT): **R(1 psi) = 18.2 m·M^(1/3), R(5 psi) = 5.7 m·M^(1/3), 1-psi arrival 44 ms·M^(1/3)** (M in kg). For 1 t that is 181 m / 57 m / 0.44 s. The old values were about 22% too large. | FIT |
| 17 | Flash brightness | "≈ 450 × sun at 10 km (1 Mt)" | ≈ 280–350 × at the thermal peak. Peak thermal power **Pmax = 3.18·W^0.56 kt/s** (G&D eq. 7.85.2). | FIT |
| 18 | Crater | 18.3·W^0.3 m, depth ≈ R/2 | Confirmed (G&D 1977 §6.09: 60 ft, 30 ft, W^0.3). Add: lip crest radius 1.25·R_a, lip height 0.25·D_a, continuous ejecta out to 2.15·R_a, volume ≈ ½πR²D. NUKEMAP still uses the 1962 W^(1/3) law (19.3 m), which gives 45% more at 15 Mt. | FIT |

Values in 02_PHYSICS_REFERENCE.md that **were confirmed** (keep them):
- Optimum-HOB radii (Sublette): 1 psi 2.2, 3 psi 1.0, 5 psi 0.71, 10 psi 0.45, 20 psi 0.28 km·W^(1/3). These are exactly the G&D 1962 optimum-HOB fit (2.17/0.99/0.70/0.44/0.28) and the 1977 knee curves (2.14/–/0.71/0.44/0.28).
- Rankine–Hugoniot shock speed, dynamic pressure, normal reflection and the peak-wind list. Checked: 5 psi → 162.8 mph.
- Fireball breakaway radii, 90/100(110)/145·W^0.4 ft.
- Thermal partition 0.35, the Q formula, the ignition table and the 1 psi = 170.75 dB conversion.
- Mach-stem onset at a ground range ≈ HOB (DNA: 1 Mt at 6500 ft gives 2.05 km; G&D gives 1.3 mi = 2.09 km).
- The double-pulse description and the colour/temperature table, which is consistent with the pulse shape within ±15% (A2.4).
- The 1 Mt cloud-rise table (G&D Table 2.12), stem ratios and base-surge numbers.

---

# PART A: PHYSICS

## A1. Scaling basics (confirmed)
- Blast lengths and times ∝ W^(1/3) (Hopkinson–Cranz). At other ambient conditions use Sachs scaling: distance × (P/P₀)^(1/3), pressure × (P/P₀), time × (P/P₀)^(1/3)·(T₀/T)^(1/2). FIT (Fletcher 1963 §2.1)
- Fireball dimensions ∝ W^0.4 (Fletcher Fig. 2.19; G&D §2.127). Thermal-pulse times ∝ W^0.44 (G&D 1977) or W^0.5 (G&D 1962). FIT
- Thermal partition f = 0.35 for HOB < 15 kft at all yields (G&D Table 7.88). It rises to 0.36–0.43 at 20–80 kft for yields of 10 kt–10 Mt. Brode's form, ±20%: f = 0.27 + 0.06η + 114η/(82000η² + 1) + 0.0085√W/(1 + 0.032√W), with η = ρ(h)/ρ₀ (Small & Brode). FIT
- Nuclear-to-TNT blast equivalence, checked numerically: a 1 kt nuclear **ideal-surface** burst equals **0.5 kt TNT hemispherical** (Kingery–Bulmash). Both give 1 psi at 1.43–1.44 km and 5 psi at 0.45–0.47 km. A real (non-ideal, dusty) surface burst in G&D/Fletcher equals about 0.35–0.45 kt TNT at ≤ 5 psi. DERIVED

## A2. Fireball

### A2.1 Size

| Quantity | Formula | Validity | Source / status |
|---|---|---|---|
| Radius at first thermal minimum | 90·W^0.4 ft = 27.4 m·W^0.4 | air burst | G&D 1977 eq. 2.127; FIT |
| Breakaway radius, air | 100–110·W^0.4 ft = 30.5–33.5 m·W^0.4 | air burst | The G&D text (atomicarchive transcription) says 100. NUKEMAP uses 110. Sublette gives 220 m diameter at 20 kt, i.e. 110. **Use 33.5 m.** DISPUTED → resolved |
| Breakaway radius, contact surface | 145·W^0.4 ft = 44.2 m·W^0.4 | contact burst | G&D eq. 2.127.2; FIT |
| Max radius, air burst | **61 m·W^0.4** (200 ft) | HOB ≥ 55 m·W^0.4 (= 180·W^0.4 ft) | Fletcher Fig. 2.19 (R_ab = 0.03788·W^0.4 mi); NUKEMAP uses 2 × 110 ft = 67 m; FIT |
| Max radius, contact surface | **79 m·W^0.4** (260 ft) | HOB ≤ 1.5 m·W^0.3 (= 5·W^0.3 ft, G&D note 8) | Fletcher (R_sb = 0.04924·W^0.4 mi); NUKEMAP uses 2 × 145 ft = 88 m; DISPUTED → 79 m |
| Intermediate HOB | Linear interpolation of R₀ between the two HOB limits above | | Same scheme as NUKEMAP; ESTIMATED |
| High-yield roll-off | × (W/1000)^−0.03 for W > 1000 kt | 1–50 Mt | DERIVED: Bravo 6.8 km vs ≈ 7 km observed; Tsar 8.2 km vs ≈ 8 km |
| Min HOB for negligible local fallout | 55 m·W^0.4 (180 ft·W^0.4, ±30%) | | G&D eq. 2.128.1, Fletcher; FIT |

**NUKEMAP's own fireball formula** (nukeeffects.js, fetched 2026-11-07): R_max = 2 × 145·W^0.4 ft for a contact burst (HOB ≤ 5·W^0.3 ft), 2 × 110·W^0.4 ft for an air burst (HOB ≥ 180·W^0.4 ft), linear interpolation in HOB in between. The older Fletcher constants (0.04924/0.03788/0.04356·W^0.4 mi) remain in its source as a commented-out alternative.

Recommended table (game values):

| W | R_bw air | R_max air | R_max contact | t_min | t_bw | t₂ | t(R_max) |
|---|---|---|---|---|---|---|---|
| 0.01 kt | 5 m | 10 m | 13 m | 0.55 ms | 0.75 ms | 5 ms | 0.05 s |
| 0.1 kt | 13 m | 24 m | 31 m | 1.4 ms | 1.9 ms | 15 ms | 0.15 s |
| 1 kt | 34 m | 61 m | 79 m | 3.5 ms | 4.8 ms | 42 ms | 0.42 s |
| 15 kt | 99 m | 180 m | 233 m | 10.3 ms | 14 ms | 137 ms | 1.4 s |
| 21 kt | 113 m | 206 m | 267 m | 11.8 ms | 16 ms | 159 ms | 1.6 s |
| 100 kt | 211 m | 385 m | 498 m | 22 ms | 30 ms | 0.32 s | 3.2 s |
| 1 Mt | 531 m | 967 m | 1.25 km | 55 ms | 75 ms | 0.87 s | 8.7 s |
| 10.4 Mt | 1.36 km | 2.30 km | 2.98 km | 0.14 s | 0.19 s | 2.44 s | 24 s |
| 15 Mt | 1.57 km | 2.63 km | 3.41 km | 0.16 s | 0.22 s | 2.87 s | 29 s |
| 50 Mt | 2.54 km | 4.11 km | 5.32 km | 0.27 s | 0.36 s | 4.87 s | 49 s |

(The roll-off is applied to R_max only.) Per-bomb measured diameters, where the bomb research has them, override these numbers.

### A2.2 Times
- t_min = **3.5·W^0.4 ms**. G&D §2.125: 20 kt → 11 ms, about 3000 °C. G&D §2.126: times ∝ W^0.4. Small & Brode: 3.8·W^0.4 ms ±35%. FIT
- t_bw ≈ 1.36·t_min (G&D §2.120: 15 ms at 20 kt). FIT
- t₂ = **0.0417·W^0.44 s** (G&D eq. 7.85.1, HOB < 15 kft). Above 15 kft: 0.038·W^0.44·(ρ/ρ₀)^0.36. Small & Brode give 0.05·W^0.42 s ±20%. FIT
- Pmax = **3.18·W^0.56 kt/s** (G&D 7.85.2). Above 15 kft: 3.56·W^0.59/(ρ/ρ₀)^0.45. A consistency check: E_th/(Pmax·t₂) = 0.35/(3.18 × 0.0417) = 2.64, independent of yield. FIT
- t(R_max) ≈ 10·t₂. DERIVED
- Fireball rise speed: G&D §2.05 gives 250–350 ft/s (76–107 m/s) for 1 Mt and ~4.5 mi (7.2 km) altitude at 1 min. A buoyancy scaling that reproduces this: v ≈ 0.9·√(g·R_max) (1 Mt gives 88 m/s). ESTIMATED

### A2.3 Thermal power pulse (the main correction)
The function **P(τ)/Pmax = (15/7)·τ² / (1 + (8/7)·τ^3.75)**, with τ = t/t₂, peaks at exactly 1 at τ = 1. It reproduces:
- the G&D 1962 cumulative fit (Fletcher eq. 2.112): 0.197/0.38/0.48/0.61/0.69/0.80 at τ = 1/1.56/2/3.1/5/8.9, against the model's 0.18/0.36/0.46/0.60/0.73/0.82 (rms error 0.05);
- G&D 1977's worked example (40% emitted at τ = 1.56);
- Sublette's "75% and 10% of peak power at 5·t₂";
- the G&D 1977 normalisation (area 2.74 against the implied 2.64).

The popular Brode shape 2τ²/(1 + τ⁴) has the right rise but too light a tail: 82% emitted at 5 t₂ and 91% at 10 t₂, against about 70% and 80% in G&D.

| τ = t/t₂ | 0.25 | 0.5 | 1 | 1.5 | 2 | 3 | 5 | 7 | 10 | 15 | 20 | 30 | 50 | 100 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P/Pmax | 0.133 | 0.494 | 1.000 | 0.774 | 0.523 | 0.270 | 0.112 | 0.062 | 0.033 | 0.016 | 0.010 | 0.005 | 0.002 | 0.0006 |
| E/E_th cumulative | 0.004 | 0.031 | 0.182 | 0.347 | 0.464 | 0.601 | 0.728 | 0.788 | 0.838 | 0.881 | 0.904 | 0.929 | 0.952 | 0.971 |

The first pulse (before t_min, about 1% of thermal energy) is not in this curve. Add a spike: P₁(t) ≈ 0.02·Pmax_bright·exp(−t/(0.3·t_min)), visually a blue-white point that saturates the frame. The minimum at t_min is P ≈ 0.05·Pmax. The curve's τ² rise starting at τ_min ≈ 0.05–0.08 covers the rest. For E/E_th, integrate numerically at load time into a 256-entry lookup table.

### A2.4 Apparent temperature and colour
T(τ) = 8000 K·[P(τ)/Pmax]^(1/4)·[R(t₂)/R(t)]^(1/2). This is Stefan–Boltzmann with P = 4πσT⁴R², anchored to G&D's 7700 °C peak. It gives:
- 2t₂ ≈ 6200 K
- 5t₂ ≈ 3800 K (the 02 table's 4500 K is slightly high)
- 10t₂ ≈ 2700 K
- 20t₂ ≈ 1950 K
- 50t₂ ≈ 1300 K

The first minimum is ~3300 K (G&D: 3000 °C) and early times are ≥ 10⁵ K (blue-white). These are G&D §2.115–2.125 values. Surface radiance relative to the Sun at 8000 K: (8000/5772)⁴ = 3.7. The 02 colour table can stay; only shift 5t₂ to ~4000 K. DERIVED

### A2.5 Early growth (Sedov–Taylor) and shock radius at all times
- Sedov–Taylor (γ = 1.4): R = 1.033·(E·t²/ρ₀)^(1/5), ρ₀ = 1.225 kg/m³. Taylor's constant K(1.4) = 0.856 gives the same thing (arXiv 2403.19657, Table 3). **E = 0.5·W·4.184·10¹² J in free air and E ≈ 0.8·W·4.184·10¹² J for a surface or tower hemisphere** (ideal reflection would give 1.0·W; Trinity fits 0.75–0.8·W, consistent with Taylor's 16.8 kt estimate for a 21–25 kt shot). Valid while the shock is strong (≳ 10 atm, roughly t < 10 ms·W^(1/3)). FIT, with the E choice DERIVED
- **For any time, use the DNA 1-kt free-air time of arrival**, then scale and invert it numerically (bisection on r):
  t₁(r) [s] = r²·(6.7 + r) / (7.12·10⁶ + 7.32·10⁴·r + 340.5·r²), with r in m for 1 kt at sea level.
  t(R, W) = W^(1/3)·t₁(R/W^(1/3)). For a surface burst use 2W (ideal hemisphere). Real ground is ≈ 1.6 W: Trinity's early radii fit 1.5–1.6 W, and Fletcher's surface pressures correspond to 1.2–1.8 W.
  It equals Sedov(0.5 W) at early times (1 kt: 18 m @ 1 ms) and tends to the speed of sound later (t → r/340.5). FIT (DNA BLAST/WE help files via NRDC, as implemented in the MIT-licensed glasstone library)

Shock radius (free air, W) from inverting the DNA formula:

| W | 0.1 ms | 1 ms | 10 ms | 100 ms | 1 s | 10 s | 60 s |
|---|---|---|---|---|---|---|---|
| 1 t | 2 | 5 | 13 | 51 | 361 | 3426 | 20451 |
| 1 kt | 7 | 18 | 46 | 128 | 506 | 3607 | 20637 |
| 15 kt | 13 | 32 | 79 | 207 | 682 | 3882 | 20937 |
| 1 Mt | 28 | 74 | 185 | 461 | 1280 | 5062 | 22408 |
| 15 Mt | 46 | 125 | 319 | 790 | 2065 | 6819 | 25011 |
| 50 Mt | 57 | 158 | 407 | 1007 | 2584 | 8022 | 26978 |

Trinity check (21 kt tower, hemisphere): with E = 0.75–0.8 W, 75/111/132/179/190 m at 6/16/25/53/62 ms; with E = W (= DNA with 2W), 80/117/140/191/204 m. Measured: 75/108/138 m at 6/16/25 ms (Taylor/Mack data as quoted in the lecture notes; the 02 doc gives 138 m @25 ms and 200 m @53 ms). Within 5% for t ≤ 25 ms.

Luminous fireball radius vs time (for rendering): R_fb(t) = R_shock(t) for t ≤ t_bw. Afterwards R_fb(t) = R_bw + (R_max − R_bw)·(1 − exp(−(t − t_bw)/(t(R_max)/3))). ESTIMATED; it gives R ≈ 0.6·R_max at t₂.

## A3. Blast wave

### A3.1 Fletcher 1963 fits (G&D 1962 data; NUKEMAP's blast engine)
Form: log₁₀y = a + b·L + c·L² + d·L³ with L = log₁₀x. Distances are scaled, d·(1/W)^(1/3) in **miles**. Pressures in psi. Times scaled as t·(1/W)^(1/3) in s. Sea level (P = 14.7 psi, c₀ = 1117 ft/s).

| Eq. | y ← x | Limits of x | a | b | c | d |
|---|---|---|---|---|---|---|
| 2.4 surface | p ← d | 0.0472–4.82 mi | −0.1877932 | −1.3986162 | +0.3255743 | −0.0267036 |
| 2.5 surface | d ← p | 0.1–200 psi | −0.1307982 | −0.6836211 | +0.1091296 | −0.0167348 |
| 2.12 surface | t_a ← d | 0.0570–1.10 mi | +0.6078753 | +1.1039021 | −0.2836934 | +0.1006855 |
| 2.10 surface | t₊ ← p | 2.5–90 psi | −0.2450537 | −0.3809152 | – | – |
| 2.16 surface | u_wind (mph) ← d | 0.0598–4.73 mi | +1.3827823 | −1.3518147 | +0.1841482 | +0.0361427 |
| 2.60 opt. HOB | p ← d | 0.0508–1.35 mi | +0.1829156 | −1.4114030 | −0.0373825 | −0.1635453 |
| 2.61 opt. HOB | d ← p | 1–200 psi | +0.1292768 | −0.7227471 | +0.0147366 | +0.0135239 |
| 2.70 opt. HOB | t_a ← d | 0.0379–0.954 mi | +0.6351033 | +1.0691963 | −0.1700728 | +0.0059191 |
| 2.68 opt. HOB | t₊ ← p | 1–200 psi | −0.2969664 | −0.2449086 | −0.0065515 | −0.0252191 |
| 2.78 | H_opt (ft) ← p | 1–200 psi | +3.2015016 | −0.3263444 | – | – |
| 2.79 | H_opt (ft) ← d | 0.0512–1.35 mi | +3.1356018 | +0.3833517 | −0.1159125 | – |

(Transcribed from scanned Tables 2.1 and 2.9 of CEX-62.2. The same coefficients are in NUKEMAP's nukeeffects.js, which is an independent confirmation.)

### A3.2 Radii, 1 kt (km)

| p (psi) | Contact surface (Fletcher 2.5) | Optimum HOB (Fletcher 2.61) | H_opt (2.78) | G&D 1977 knee max range (NUKEMAP data) | Brode 1986, ideal surface | Brode, best HOB |
|---|---|---|---|---|---|---|
| 0.5 | 1.96 | ≈3.7 (DNA tail) | ~600 m | – | 2.42 | – |
| 1 | **1.19** | **2.17** | 485 m | 2.14 (HOB ~480 m) | 1.43 | 2.29 |
| 2 | 0.76 | 1.32 | 387 m | 1.28 | 0.85 | 1.31 |
| 3 | **0.59** | **0.99** | 339 m | – | 0.64 | 0.97 |
| 5 | **0.44** | **0.70** | 287 m | ≈0.71 | 0.47 | 0.67 |
| 10 | **0.305** | **0.44** | 229 m | 0.44 | 0.31 | 0.41 |
| 20 | **0.216** | **0.28** | 182 m | 0.28 | 0.22 | 0.26 |
| 50 | 0.140 | 0.165 | 135 m | 0.150 | 0.146 | 0.146 (surface) |
| 100 | 0.103 | 0.114 | 108 m | 0.108 | 0.110 | 0.110 (surface) |
| 200 | 0.075 | 0.082 | 86 m | 0.082 | 0.084 | 0.084 |

Scale by W^(1/3). Multi-yield values (km), surface | optimum:

| W | 1 psi | 3 psi | 5 psi | 10 psi | 20 psi | 50 psi |
|---|---|---|---|---|---|---|
| 15 kt | 2.94 \| 5.35 | 1.46 \| 2.44 | 1.09 \| 1.72 | 0.75 \| 1.08 | 0.53 \| 0.70 | 0.35 \| 0.41 |
| 21 kt | 3.29 \| 5.98 | 1.63 \| 2.73 | 1.22 \| 1.92 | 0.84 \| 1.21 | 0.60 \| 0.78 | 0.39 \| 0.45 |
| 1 Mt | 11.9 \| 21.7 | 5.93 \| 9.91 | 4.42 \| 6.96 | 3.05 \| 4.38 | 2.16 \| 2.82 | 1.40 \| 1.65 |
| 15 Mt | 29.4 \| 53.5 | 14.6 \| 24.4 | 10.9 \| 17.2 | 7.53 \| 10.8 | 5.33 \| 6.96 | 3.46 \| 4.06 |
| 50 Mt | 43.9 \| 79.9 | 21.8 \| 36.5 | 16.3 \| 25.6 | 11.2 \| 16.1 | 7.95 \| 10.4 | 5.17 \| 6.07 |

Caution: the "optimum" HOB for megaton yields and low pressures (e.g. 50 Mt, 1 psi → 17.9 km) is unrealistic. For real bombs use the actual HOB with Brode (A3.3).

### A3.3 Arbitrary height of burst: Brode 1986 analytic fit (recommended for real HOBs)
For 1 kt, x = scaled ground range and y = scaled HOB, both in **kilofeet**/kt^(1/3). z = y/x, r = √(x² + y²). Result in psi. Brode, *Airblast from Nuclear Bursts – Analytic Approximations* (PSR 1986), pp. 60–71, as transcribed in glasstone (MIT). Accuracy about 10% for a near-ideal surface.
```
a = 1.22 - 3.908 z^2/(1+810.2 z^5)
b = 2.321 + 6.195 z^18/(1+1.113 z^18) - 0.03831 z^17/(1+0.02415 z^17) + 0.6692/(1+4164 z^8)
c = 4.153 - 1.149 z^18/(1+1.641 z^18) - 1.1/(1+2.771 z^2.5)
d = -4.166 + 25.76 z^1.75/(1+1.382 z^18) + 8.257 z/(1+3.219 z)
e = 1 - 0.004642 z^18/(1+0.003886 z^18)
f = 0.6096 + 2.879 z^9.25/(1+2.359 z^14.5) - 17.5 z^2/(1+71.66 z^3)
g = 1.83 + 5.361 z^2/(1+0.3139 z^6)
h = 8.808 z^1.5/(1+154.5 z^3.5) - (0.2905+64.67 z^5)/(1+441.5 z^5) - 1.389 z/(1+49.03 z^5)
    + 1.094 r^2/((781.2 - 123.4 r + 37.98 r^1.5 + r^2)(1+2y))
j = 0.000629 y^4/(3.493e-9 + y^4) - 2.67 y^2/(1 + 1e7 y^4.3)
k = 5.18 + 0.2803 y^3.5/(3.788e-6 + y^4)
p = 10.47/r^a + b/r^c + d*e/(1 + f r^g) + h + j/r^k
```
Validated here:
- 1 kt optimum radii within 2–9% of Fletcher.
- Hiroshima (15 kt, 580 m): 30 psi at GZ, 10 psi at 1.0 km, 5.0 psi at 1.6 km, 3.4 psi at 2.0 km, 1.8 psi at 3.0 km.
- Nagasaki (21 kt, 503 m): 5.4 psi at 1.6 km.
- Tsar (50 Mt, 4 km): 54 psi at 5 km, 16 psi at 10 km, 4.8 psi at 20 km, 1.2 psi at 50 km.

Rules:
- **Evaluate on the CPU in GDScript (64-bit floats)**, because z^18 overflows float32.
- At HOB ≈ 0 it is ideal-surface and about 20% long at 1 psi. For contact bursts use Fletcher 2.4/2.5 instead (blend linearly for scaled HOB < 30 m).
- **It goes negative below ~1 psi.** Beyond R(1 psi), splice on the DNA free-air tail: p(R) = 1 psi·p_DNA(R/W^(1/3))/p_DNA(R₁/W^(1/3)).

### A3.4 DNA 1-kt free-air overpressure standard (far field, and to splice tails)
p(r) [Pa] = 3.04·10¹¹/r³ + 1.13·10⁹/r² + 7.9·10⁶ / (r·√(ln(r/445.42 + 3·exp(−√(r/445.42)/3))))
Here r is in m for 1 kt. For yield W use r = R/W^(1/3); for an ideal surface burst use 2W.
Check: 1 kt free air gives 1 psi at 1129 m and 5 psi at 370 m. With 2W it gives 1422/466 m, matching Brode at the surface. FIT
Mach-stem formation range (DNA): x_m = h^2.5/5822 + 2.09·h^0.75 (scaled metres; h = HOB/W^(1/3)). Examples: 1 Mt at 1981 m → 2.05 km; Hiroshima → 0.67 km; Tsar → 3.4 km. FIT
Airburst time of arrival (DNA): v = 1 if x ≤ x_m, else v = 1.26 − 0.26·x_m/x; t = W^(1/3)·v·t₁(slant_scaled/v). FIT
Positive-phase duration at the surface (DNA): t₀ = ln(1000·t_a)/3.77, t₊ = [155·e^(−20.8·t_a) + e^(−t₀² + 4.86·t₀ + 0.25)]/1000 s, with t_a the scaled free-air arrival time in s. For 1 kt at 1 km this gives 0.41 s (Fletcher: 0.40). FIT
Shock thermodynamics (DNA real-gas, for q and reflection): ξ = p/101325 + 1; z = ln ξ − 0.47t/(100 + t) with t = 10⁻¹²ξ⁶; γ = 1.402 − 3.4·10⁻⁴z⁴/(1 + 2.22·10⁻⁵z⁶); μ = (γ + 1)/(γ − 1); density ratio n = (1 + μξ)/(5.975 + ξ); normal reflection factor = 2 + (γ + 1)(n − 1)/2; dynamic pressure q = 0.5·p·(n − 1).
(The DNA full airburst model with regular/Mach blending was also tested. Its Mach branch diverges near GZ, giving 10⁸ Pa at x = 1 m, so it is **not recommended** without clamping. Use Brode.)

### A3.5 Rankine–Hugoniot (ideal gas; 02 formulas confirmed)
U = c₀√(1 + 6p/(7P₀)); q = 2.5p²/(7P₀ + p); p_r = 2p(7P₀ + 4p)/(7P₀ + p); u = 5p·c₀/(7P₀·√(1 + 6p/(7P₀))). 5 psi → 162.8 mph. FIT (G&D ch. 3; Fletcher eqs. 2.2, 2.3, 2.80)

### A3.6 Arrival time (s): free air W (≈ airburst at long range, use slant range) / ideal surface 2W

| Distance | 1 kt | 15 kt | 1 Mt | 15 Mt | 50 Mt | Sound 343 m/s |
|---|---|---|---|---|---|---|
| 1 km | 2.39 / 2.27 | 1.80 / 1.60 | 0.60 / 0.45 | 0.18 / 0.13 | 0.10 / 0.07 | 2.9 |
| 2 km | 5.30 / 5.16 | 4.57 / 4.29 | 2.34 / 1.92 | 0.93 / 0.69 | 0.55 / 0.39 | 5.8 |
| 5 km | 14.1 / 13.9 | 13.3 / 12.9 | 9.8 / 8.9 | 5.9 / 4.9 | 4.1 / 3.3 | 14.6 |
| 10 km | 28.8 / 28.6 | 27.9 / 27.5 | 23.9 / 22.7 | 18.0 / 16.0 | 14.5 / 12.4 | 29.2 |
| 20 km | 58.1 / 58.0 | 57.3 / 56.9 | 53.0 / 51.6 | 45.7 / 42.9 | 40.5 / 37.0 | 58.3 |
| 50 km | 146.2 / 146.1 | 145.3 / 145.0 | 140.9 / 139.4 | 132.6 / 129.2 | 126.2 / 121.4 | 145.8 |
| 100 km | 293.1 / 292.9 | 292.2 / 291.8 | 287.6 / 286.1 | 279.0 / 275.4 | 272.1 / 266.8 | 291.5 |

Checks: G&D's quoted 20 kt at 1/2 mi → 3.1/7.6 s (quoted ≈ 3 and 7.5) and 1 Mt at 1/2 mi → 1.25/4.49 s (quoted 1.4 and 4.5), using 2W. Fletcher 2.12 for 1 kt at 1 km gives 2.33 s. KB (0.5 kt TNT) gives 2.16 s. Note: c = 340.5 m/s in the DNA formula (15 °C). Beyond 100 km the arrival time is effectively d/c minus a constant lead (≈ 20 s for 50 Mt).

### A3.7 Positive-phase duration (s·W^(1/3))
- Optimum HOB (Fletcher 2.68): 100 psi 0.097, 50 psi 0.139, 20 psi 0.208, 10 psi 0.267, 5 psi 0.331, 2.5 psi 0.401, 1 psi 0.505.
- Surface (2.10): t₊ = 0.569·p^−0.381·W^(1/3) for 2.5–90 psi (5 psi 0.31, 10 psi 0.24, 20 psi 0.18).
FIT. The doc values for 5 and 2.5 psi were 20–30% high.

### A3.8 Conventional HE: Kingery–Bulmash (Swisdak simplified, SI; DDESB TP-20 Table 2-3/2-4/2-6)
S(Z) = exp(A + B·lnZ + C·ln²Z + D·ln³Z + E·ln⁴Z + F·ln⁵Z), with Z = R/M^(1/3) in m/kg^(1/3) and M in kg TNT, **hemispherical surface burst**.

| Quantity | Z range | A | B | C | D | E | F |
|---|---|---|---|---|---|---|---|
| p_so (kPa) | 0.2–2.9 | 7.2106 | −2.1069 | −0.3229 | 0.1117 | 0.0685 | – |
| p_so (kPa) | 2.9–23.8 | 7.59345 | −3.05133 | 0.40908 | 0.02633 | −0.01270 | – |
| p_so (kPa) | 23.8–198.5 | 6.0536 | −1.4066 | – | – | – | – |
| t_a/M^(1/3) (ms) | 0.06–1.50 | −0.76102 | 1.80448 | 0.13258 | −0.04187 | −0.03617 | −0.00862 |
| t_a/M^(1/3) (ms) | 1.50–40 | −0.74020 | 1.66382 | 0.45234 | −0.36834 | 0.09271 | −0.00816 |
| t_a (ms) | 40–198.5 | M^(1/3)·2.2495832·Z^1.0478 | | | | | |
| t₊/M^(1/3) (ms) | 0.2–1.02 | 0.55208 | 3.43680 | −0.62621 | −4.28609 | −2.86846 | −0.60800 |
| t₊/M^(1/3) (ms) | 1.02–2.80 | 0.55250 | 2.32380 | −7.34364 | 8.77005 | −4.24959 | 0.88170 |
| t₊/M^(1/3) (ms) | 2.80–40 | −1.91410 | 5.86454 | −4.44451 | 1.76090 | −0.34340 | 0.02624 |

Derived thresholds: 1 psi at Z = 18.15 and 5 psi at Z = 5.71.

| TNT | R(1 psi) | R(5 psi) | Arrival of 1 psi |
|---|---|---|---|
| 100 kg | 84 m | 27 m | 0.20 s |
| 1 t | 181 m | 57 m | 0.44 s |
| 10 t | 391 m | 123 m | 0.95 s |
| 50 t | 669 m | 210 m | 1.63 s |
| 500 t | 1440 m | 454 m | 3.50 s |

For an HE charge in free air far above the ground, use M/1.8 (reflection factor ≈ 1.8, as in the 02 doc). Use TNT-equivalent masses; tritonal and H-6 have about 1.07–1.35 × TNT blast. FIT

## A4. Thermal radiation

### A4.1 Fluence
Q [cal/cm²] = f·W·10¹²·τ/(4πD²), with D in cm (G&D eq. 7.96.2). With D in miles: 3.07·f·W·τ/D². With D in kilofeet: 85.6·f·W·τ/D². FIT
- f = 0.35 for an air burst. For a contact surface burst G&D §7.101 gives an effective f of 0.18, i.e. ×0.5. Fletcher uses ×0.7 (0.5–0.8 range). Small & Brode say "about half" for megatons. **Recommended: ×0.7 for ≤ 10 kt, falling log-linearly to ×0.5 at ≥ 1 Mt.** DISPUTED → resolved
- Transmittance: **τ = exp(−k·d_km^0.44)**. k = 0.14 is very clear air: it reproduces the Fletcher curve for 50-mile visibility (0.85 at 1.6 km, 0.70 at 8 km, 0.61 at 16 km, 0.52 at 32 km, 0.43 at 64 km). k = 0.22 is typical air: it reproduces Sublette's burn ranges (implied τ 0.52 at 12 km and 0.33 at 39 km). DERIVED
- Cloud deck above or snow below: τ × 1.5. Both: × 2.25 (G&D §7.100). FIT
- Fletcher's direct fit (clear air, 50-mile visibility; Q in cal/cm² per kt; slant range in miles): log₁₀(Q/W) = −0.0401874 − 2.0823477L − 0.0511744L² − 0.0074958L³. Inverse: log₁₀d = −0.0193419 − 0.4804553L − 0.0055685L² + 0.0002013L³. FIT

### A4.2 Burn thresholds (50% probability, unshielded skin): G&D 1977 Fig. 12.65, as fitted in NUKEMAP
Q = Σ aᵢ(ln W)ⁱ:
- 1st degree: a = [1.93566, 0.325315, −0.113516, 0.0300972, −0.00330446, 0.000129666]
- 2nd degree: a = [4.01471, 0.371805, −0.0450261, 0.0135496, −0.00165598, 7.03802e−5]
- 3rd degree: a = [5.99816, 0.533508, −0.0234359, 0.0103953, −0.00143664, 6.39307e−5]
- 3rd degree, 100%: a = [7.00184, 0.554373, 0.0565013, −0.0152193, 0.0017063, −6.79502e−5]
- "No harm" 100%: a = [1.14706, 0.12466, −0.0160088, 0.00359442, −0.000263841, 5.30508e−6]

Valid 1 kt–20 Mt. FIT (digitised)

| W | 1st | 2nd | 3rd (50%) | 3rd (100%) | No harm |
|---|---|---|---|---|---|
| 1 kt | 1.9 | 4.0 | 6.0 | 7.0 | 1.15 |
| 15 kt | 2.4 | 4.9 | 7.4 | 8.7 | 1.4 |
| 100 kt | 2.75 | 5.5 | 8.5 | 9.9 | 1.6 |
| 1 Mt | 3.2 | 6.2 | 9.7 | 11.3 | 1.9 |
| 20 Mt | 3.8 | 7.2 | 11.4 | 13.2 | 2.3 |

Sublette's list is 2.5/5/8 (20 kt), 3.2/6/10 (1 Mt) and 5/8.5/12 (20 Mt) cal/cm². It is within 15% except for 1st degree at 20 Mt.

### A4.3 Burn radii (air burst, slant range, clear air; NUKEMAP-consistent), km

| W | 1st | 2nd | 3rd (50%) | Sublette 3rd (hazier) |
|---|---|---|---|---|
| 1 kt | 1.12 | 0.79 | 0.65 | 0.67 |
| 15 kt | 3.67 | 2.63 | 2.16 | 2.03 |
| 20 kt | 4.16 | 2.99 | 2.45 | 2.29 |
| 100 kt | 8.4 | 6.1 | 5.0 | 4.4 |
| 1 Mt | 22.3 | 16.5 | 13.5 | 11.4 |
| 15 Mt | 68.7 | 52.0 | 42.6 | 34.5 |
| 50 Mt (extrapolated) | 114 | 87 | 71.5 | 56.6 |

Power-law fits (±6%): R3 = 0.65·W^0.44, R2 = 0.79·W^0.44, R1 = 1.12·W^0.43 km. For a surface burst multiply Q by the surface factor (A4.1), i.e. radii × ≈ 0.8. Ground range = √(slant² − HOB²). DERIVED

### A4.4 Flash irradiance for exposure and glare
Peak irradiance E_pk = Pmax·4.184·10¹²·τ/(4πd²) W/m², with Pmax = 3.18·W^0.56 kt/s. In units of the Sun (≈ 1000 W/m² at the ground), clear air / typical air:
- 1 Mt: 10 km → 345 / 276 ×; 50 km → 9.3 / 5.9 ×.
- 50 Mt: 50 km → 83 ×; 100 km → 16 / 8.5 ×.
The time profile of irradiance = Pmax·[P(τ)/Pmax] (A2.3) plus the first-pulse spike. Ignition thresholds (G&D Tables 7.35/7.40) are confirmed as in 02. DERIVED

## A5. Mushroom cloud

### A5.1 Final (stabilized) dimensions: four sources compared (km, above burst/ground)

| W | G&D Fig. 9.96 top (mid-lat; NUKEMAP fit) | Purnell/FAS fit 9.1W^0.15−6.7 | Miller 1963 top = h+b (NUKEMAP 3D) | Shreve/Kellogg 1961 equatorial | G&D bottom | Miller cap radius a |
|---|---|---|---|---|---|---|
| 1 kt | 2.78 | 2.40 | 2.44 | – | 1.73 | 0.71 |
| 10 kt | 5.79 (G&D text: 19,000 ft = 5.8) | 6.15 | 6.76 | – | 3.19 (G&D: 10,000 ft) | 1.92 |
| 15 kt | 6.58 | 6.96 | 8.08 | – | 3.55 | 2.29 |
| 21 kt | 7.32 | 7.67 | 9.38 | – | 3.88 | 2.65 |
| 50 kt | 9.60 | 9.66 | 12.0 | 12.2 | 4.86 | 3.85 |
| 100 kt | 11.8 | 11.5 | 14.0 | 14.6 | 5.82 | 5.19 |
| 1 Mt | 19.8 | 19.0 | 24.3 | 23.5 | 10.6 | 14.0 |
| 10.4 Mt | 29.4 | 29.7 | 46.3 | 32.0 (10 Mt) | 19.6 | 38.4 |
| 15 Mt | 32.0 | 31.8 | 51.7 | – | 21.7 | 45.0 |
| 50 Mt | 43.7 (extrap.) | 39.4 | 75.4 | – | 31.5 | 75.6 |

Formulas:
- G&D 9.96 as fitted by NUKEMAP, result in kft:
  - W ≤ 100: 9.0356·W^(0.32095 − 4.7081·10⁻⁵W) + 0.08178
  - 100 < W ≤ 4000: 23.0372·W^(0.15120 − 4.63474/W) + 1.47099
  - W > 4000: 6.53576·(1.08174·10²⁸⁸)^(1/W)·W^0.284161
  - Bottom: 171.550·(W/524029.66)^0.254453·exp(W/524029.66) − 0.326654
- Purnell (FAS, fits to G&D 9.96 and 2.16): h_top = 9.1·W^0.15 − 6.7 km; h_bottom = 1.6·W^0.27 + 0.13 km; R_cap = 0.017·W^0.83 + 2.0 km.
- Miller (Fallout and Radiological Countermeasures, SRI 1963, as coded in NUKEMAP; feet):
  - cap-centre height h = 6600·W^0.445 (W ≤ 28 kt) or 16800·W^0.164 (W > 28 kt)
  - horizontal semi-axis a = 2340·W^0.431
  - vertical semi-axis b = 1400·W^0.431
  - initial radius R_s = 209·W^(1/3)
  - In metric: h = 2.01 km·W^0.445 / 5.12 km·W^0.164; a = 0.713 km·W^0.431; b = 0.427 km·W^0.431; R_s = 63.7 m·W^(1/3).
- Shreve 1961 (equatorial surface bursts, Kellogg): top 40/48/77/105 kft and centre 34/40/63/82 kft for 50 kt/100 kt/1 Mt/10 Mt.

Which to use (resolution of the DISPUTE):
- Up to ~1 Mt, the Miller top matches the equatorial table within 5% at 50 kt–1 Mt. Use it as the default for humid or tropical sites (Pacific, summer Japan).
- For dry mid-latitude sites (Nevada, Semipalatinsk) multiply by **0.82** (the G&D/Miller ratio at 15 kt–1 Mt is 0.81–0.85).
- Above 1 Mt, Miller's b blows up (bottom < 0 at ≥ 10 Mt) and G&D is too low compared with the observed tests. Use **H_top = 24.3 km·(W/1000)^0.2**: 10 Mt 38.5 km, 15 Mt 41.8 km, 50 Mt 53 km.
- **Override with measured per-bomb values** from the bomb research (e.g. Tsar ≈ 64–67 km; Bravo and Mike ≈ 40 km class).
- Sub-kiloton: H_top ≈ 2.44 km·W^0.3. This is continuous at 1 kt and matches the G&D fit's slope (0.32) and buoyant-thermal theory (0.25): 1 t → 0.31 km, 10 t → 0.61 km, 100 t → 1.22 km. ESTIMATED
- Bottom: H_bottom ≈ 0.6·H_top. G&D ratios are 0.49–0.72 and Shreve's 0.56–0.70. ESTIMATED
- **Cap radius a = 0.713 km·W^0.431** at ~10 min (Miller; matches DELFIC to ±25%). Cap vertical half-thickness ≈ (H_top − H_bottom)/2 = 0.2·H_top. Miller's b is too thick at megatons.
- Stem radius: r_stem = a·clamp(0.5 − 0.2·log₁₀(W/20), 0.1, 0.5). This gives 0.5 at ≤ 20 kt and 1/5–1/10 at megatons (G&D §2.17). ESTIMATED

### A5.2 Growth of the cap with altitude (Miller, as used by NUKEMAP)
a(z) = R_s·(a/R_s)^((z − R_s)/(h − R_s)) and b(z) = R_s·(b/R_s)^((z − R_s)/(h − R_s)). Here z is the current cap-centre altitude. The cap starts as the fireball (R_s ≈ R_max) and grows exponentially in altitude to its final size. FIT. Apply the same idea using the final a and half-thickness chosen in A5.1.

### A5.3 Rise curve
Data: G&D Table 2.12 for 1 Mt gives 2 mi @ 0.3 min, 4 mi @ 0.7, 6 mi @ 1.1, 10 mi @ 2.5, 12 mi @ 3.8 min (rate then 27 mph). Stabilization at ~10 min (G&D §2.15). DELFIC durations: 10 kt ~5 min, 100 kt ~10 min, 1 Mt 15–20 min. Rough DELFIC diameters: 3 km @ 5 min (10 kt), 10 km @ 10 min (100 kt), 30 km @ 15 min (1 Mt) (Hooper et al., arXiv 2108.04888).

Normalized curves (z_top/H_top):

| t (s) | 18 | 42 | 66 | 150 | 228 | 300 | 600 |
|---|---|---|---|---|---|---|---|
| G&D 1 Mt (H = 12.9 mi) | 0.155 | 0.31 | 0.465 | 0.775 | 0.93 | – | 1 |
| NUKEMAP cubic fit to G&D Fig. 2.12 | 0.148 | 0.313 | 0.458 | 0.82 | 0.98 | 1 | 1 |
| Miller top (eq. 4.34/4.35) | 0.224 | 0.358 | 0.468 | 0.725 | 0.851 | 0.915 | 0.992 |
| tanh(t/130 s) | 0.137 | 0.312 | 0.468 | 0.819 | 0.942 | 0.98 | 1 |

- NUKEMAP cubic: f(t) = 0.0097225 + 0.0079926t − 1.88669·10⁻⁵t² + 1.07656·10⁻⁸t³ for t < 270 s, otherwise 1.
- Miller top: f(t) = 0.331(1 − e^(−0.0626t)) for t < 20 s, and 0.893(1.120 − e^(−0.00784t)) after.
- Miller cap centre: 0.915(1.093 − e^(−0.00905t)).

**Game recommendation:** z_top(t) = H_top·tanh(t/τ_r), with τ_r = 165 s·(W/1000)^0.1 clamped to [60, 250] s. (165 s with the tropical H_top = 24.3 km reproduces G&D's 7–8 km at 1 min for 1 Mt.) Per-bomb values: 1 kt 83 s, 15 kt 109 s, 15 Mt 216 s, 50 Mt 244 s. Optional overshoot for very large yields: multiply by 1 + 0.06·exp(−((t − 2τ_r)/τ_r)²). ESTIMATED, anchored to G&D 2.12

### A5.4 Look (confirmed from 02 and G&D)
- The cloud is reddish-brown at first (nitrogen oxides), then turns white as water condenses.
- Megaton clouds form ice caps and collars.
- Surface bursts have a dark, dusty stem.
- If HOB > 55 m·W^0.4 (±30%), there is almost no dust stem.

## A6. Crater (dry soil, contact burst)
R_a = 18.3 m·W^0.3; D_a = 9.1 m·W^0.3 (G&D 1977 §6.09: 60 ft and 30 ft at 1 kt). FIT
- 100 kt → 73 m (G&D example: 240 ft).
- 1 kt 18 m, 15 kt 41 m, 21 kt 46 m, 1 Mt 145 m, 15 Mt 328 m.

Geometry (G&D §6.70–6.75): lip crest radius 1.25·R_a; lip height 0.25·D_a; continuous ejecta to 2.15·R_a; ejecta thickness 0.9·D_a·(R_a/R)^3.86; volume ≈ ½πR_a²D_a. FIT
- Hard rock: about 0.8 × these values (Fletcher's rock/soil ratio).
- Water-saturated coral reef: radius about 3× larger and the crater shallower. Bravo and Mike made craters about 2 km across and 50–80 m deep. Use per-bomb measured values. MEASURED (bomb research to confirm)
- NUKEMAP (Fletcher, 1962) uses W^(1/3): lip 38.6 m, apparent radius 19.3 m, depth 9.24 m·W^(1/3).
- No significant crater for HOB ≳ 14 m·W^(1/3) (G&D §2.21: 1 Mt needs HOB ≤ 450 ft). FIT/DERIVED

## A7. Wilson condensation cloud (ESTIMATED; no closed-form model available)
G&D §2.48–2.50 (Bikini, nearly saturated air): the cloud forms in the rarefaction behind the shock, appears 1–2 s after detonation and dissipates about 1 s later. It forms ahead of the fireball and barely affects radiation.

Game model:
- Appears at t_w = 1.0 s·(W/20)^(1/3).
- Lasts 1.5 s·(W/20)^(1/3).
- Shape: a hemispherical or annular veil with outer radius ≈ 0.85·R_shock(t). For 20 kt that is ≈ 0.6 km growing to 0.95 km, i.e. ~220–350 m·W^(1/3).
- Thickness ~0.3 of the radius.
- Only if relative humidity ≳ 70% (assumption).
- Fades early if the fireball overtakes it.
- The same applies to conventional explosions (Beirut 2020) using the TNT-equivalent W.

## A8. Mach stem, precursor, dust (02 confirmed)
- Mach stem from x_m (A3.4). In the Mach region the pressure is about 2 × the direct wave (G&D §2.33).
- Triple-point height grows with distance: use h_T ≈ 0.15·(x − x_m). ESTIMATED visual.
- Thermal precursor on desert, asphalt or dry soil for scaled HOB < ~800 ft·W^(1/3) and p > ~6 psi. None over water, snow or ice.
- Base surge (BAKER): forms at 10–12 s, reaches 900 ft and moves > 1 mi/min. At 4 min it is 3.5 mi across and 1800 ft high. G&D gives a typical height of 1000–2000 ft (§2.68–2.75).

## A9. Recommended formula table (for scripts/physics/blast_physics.gd)

| Quantity | Recommended formula | Validity | Source | Status |
|---|---|---|---|---|
| R_max fireball | 61 (air) / 79 (contact) m·W^0.4·min(1, (W/1000)^−0.03), HOB interpolation | 1 t–50 Mt | Fletcher Fig. 2.19 / G&D | FIT + DERIVED roll-off |
| R_breakaway | 33.5 / 44.2 m·W^0.4 | | G&D 2.127, Sublette | FIT |
| t_min, t_bw | 3.5·W^0.4 ms; 1.36·t_min | ±35% | G&D 2.125, Small & Brode | FIT |
| t₂, Pmax | 0.0417·W^0.44 s; 3.18·W^0.56 kt/s | HOB < 15 kft | G&D 7.85 | FIT |
| Pulse shape | (15/7)τ²/(1 + (8/7)τ^3.75) | τ > τ_min | fit to G&D 1962 eq. 2.112 + G&D 1977 | DERIVED |
| T(t) | 8000 K·(P/Pmax)^(1/4)·(R₂/R)^(1/2) | after t_min | Stefan–Boltzmann + G&D | DERIVED |
| Shock radius R(t) | invert t = W^(1/3)·r²(6.7 + r)/(7.12e6 + 7.32e4r + 340.5r²); surface: 1.6 W (real) to 2 W (ideal) | all t | DNA 1-kt standard; Trinity check | FIT |
| p(R), contact | Fletcher 2.4 (inverse 2.5) | 0.1–200 psi | Fletcher/G&D 1962 | FIT |
| p(R), real HOB | Brode 1986 (CPU, double), DNA tail < 1 psi | ≥ 1 psi | Brode PSR 1986 | FIT |
| p(R), far field | DNA free-air formula, matched at 1 psi | any | DNA | FIT |
| Mach stem start | x_m = h^2.5/5822 + 2.09·h^0.75 (scaled m) | | DNA | FIT |
| Arrival time | DNA t₁ with Mach factor v; 2W for surface | any | DNA; checked against G&D | FIT |
| Positive phase | Fletcher 2.68 (opt) / 2.10 (surface) / DNA formula | | Fletcher, DNA | FIT |
| HE blast | Kingery–Bulmash/Swisdak (A3.8) | Z 0.2–198.5 | DDESB TP-20 | FIT |
| Thermal Q | 0.35·W·10¹²·τ/(4πD²), τ = exp(−k·d_km^0.44) | 0.1–100 km | G&D 7.96 + fit to Fletcher | FIT + DERIVED |
| Burn thresholds | NUKEMAP polynomials of G&D Fig. 12.65 | 1 kt–20 Mt | G&D 1977 | FIT |
| Cloud top | Miller h + b (≤ 1 Mt); 24.3·(W/1000)^0.2 km above; × 0.82 dry mid-latitude; per-bomb override | 1 t–50 Mt | Miller 1963, Shreve 1961, G&D 9.96 | DISPUTED → resolved |
| Cloud bottom | 0.6·H_top | | G&D 9.96, Shreve | ESTIMATED |
| Cap radius | 0.713 km·W^0.431 at ~10 min; a(z) growth law | ≤ 15 Mt | Miller, DELFIC check | FIT |
| Rise | H_top·tanh(t/τ_r), τ_r = 165 s·(W/1000)^0.1 in [60, 250] | | fit to G&D Table 2.12 | ESTIMATED |
| Crater | R = 18.3·W^0.3 m, D = 9.1·W^0.3 m, lip 1.25R, ejecta 2.15R | dry soil | G&D ch. 6 | FIT |
| Wilson cloud | t_w = (W/20)^(1/3) s, life 1.5(W/20)^(1/3) s, R ≈ 0.85·R_shock | humid | G&D 2.48–2.50 | ESTIMATED |
| Sound attenuation | low-pass f_c ≈ 1.2 kHz·(d/1 km)^−0.8 | 0.1–50 km | from ISO 9613-1 absorption (20 °C, 70% RH) | ESTIMATED |

## A10. Numbers for selftest.gd (tolerances in brackets)
- R_max_air(1) = 61 m (±3%).
- R_max_contact(15000) ≈ 3.41 km (diameter 6.8 km, ±10%).
- t₂(1000) = 0.871 s (±2%).
- t_min(20) = 11.6 ms (±20%).
- p_surface(1 kt, 1191 m) = 1.00 psi (±3%).
- R_opt(5 psi, 1 kt) = 0.696 km. R_opt(1 psi, 1 Mt) = 21.7 km.
- Brode: Hiroshima (15 kt, 580 m HOB) at 1.6 km = 5.0 psi (±10%).
- Arrival time, surface (2W): 20 kt @ 1609 m = 3.1 s; 1 Mt @ 3219 m = 4.5 s (±5%).
- R_shock(1 kt free air, 1 s) = 506 m (±2%). Trinity 21 kt hemisphere @ 25 ms = 130–140 m.
- Pulse: F(τ = 2) = 0.46, F(5) = 0.73 (±0.03).
- R_burn3(1 Mt, clear) = 13.5 km (±7%).
- H_top(1 Mt, humid) = 24.3 km; H_top(10 kt, dry mid-latitude) ≈ 5.5–5.8 km.
- a(1 Mt) = 14.0 km.
- Crater R(100 kt) = 72.9 m.
- KB: R(1 psi, 1000 kg) = 181 m (±3%).

---

# PART B: RENDERING AND AUDIO TECHNIQUES (Godot 4.7)

## B0. API verification (docs.godotengine.org/en/stable = "Godot Engine 4.7 documentation", fetched 2026-11-07)

| API | Verified facts | Notes for the project |
|---|---|---|
| `Environment.tonemap_mode` | Enum ToneMapper: LINEAR 0, REINHARDT 1, FILMIC 2, ACES 3, **AGX 4** | AgX is "the slowest" option. AgX-only properties: `tonemap_agx_white` (default 16.29; docs recommend ≥ 6.0 for photoreal) and `tonemap_agx_contrast` (1.25; use instead of adjustment_contrast). `tonemap_white` is ignored with AgX. |
| Environment glow | `glow_enabled` (false), `glow_intensity` 0.3, `glow_strength` 1.0, `glow_bloom` 0.0, `glow_hdr_threshold` 1.0, `glow_hdr_scale` 2.0, `glow_hdr_luminance_cap` 12.0, `glow_blend_mode` (ADDITIVE 0, SCREEN 1 default, SOFTLIGHT 2, REPLACE 3, MIX 4), `glow_levels/1..7` (0, 0.8, 0.4, 0.1, 0, 0, 0) | Raise `glow_hdr_luminance_cap` to 50–100 for the flash. Enable levels 5–7 for a wide halo. |
| `volumetric_fog_length` | default 64.0 | Confirms the 03 note: froxel fog is not for km-scale effects. |
| `CameraAttributesPractical` | `auto_exposure_min_sensitivity` 0.0, `auto_exposure_max_sensitivity` 800.0, plus DoF properties | Auto exposure is **Forward+ only**. |
| `CameraAttributes` (base) | `auto_exposure_enabled` false, `auto_exposure_scale` 0.4, `auto_exposure_speed` 0.5, `exposure_multiplier` 1.0, `exposure_sensitivity` 100 (needs physical light units) | Drive `exposure_multiplier` from script for deterministic renders. |
| `GPUParticlesCollisionHeightField3D` | `size` default **Vector3(2,2,2)** (must enlarge), `resolution` enum 256…8192 (default 1024), `update_mode` WHEN_MOVED 0 / ALWAYS 1, `follow_camera_enabled` false, `heightfield_mask` | Requires `ParticleProcessMaterial.collision_mode` ≠ DISABLED. GPU particles only. No overhangs. |
| `RenderingServer.global_shader_parameter_add(name: StringName, type: GlobalShaderParameterType, default_value: Variant)` | Also `_set`, `_get` (const), `_remove`, `_set_override`, `_get_list`, `_get_type`. Signal `frame_post_draw` exists. | In a shader: `global uniform float blast_age;`. Use the constant names (e.g. `RenderingServer.GLOBAL_VAR_TYPE_FLOAT`), not numbers. |
| `AudioEffectHardLimiter` | `ceiling_db` −0.3 (range −24..0), `pre_gain_db` 0 (−24..24), `release` 0.1 s (0.01..3) | `AudioEffectLimiter` is **deprecated** ("Use AudioEffectHardLimiter instead"). The 03 doc mentions the old one. |
| `AudioStreamWAV` | `data` PackedByteArray, `format` (FORMAT_8_BITS 0, **FORMAT_16_BITS 1**, IMA_ADPCM 2, QOA 3), `mix_rate` 44100, `stereo` false, `loop_mode`/`loop_begin`/`loop_end`, `save_to_wav(path)`, static `load_from_buffer`/`load_from_file` | Docs give no byte layout for 16-bit/stereo. Use standard WAV PCM (signed little-endian, interleaved L,R) and verify once with `save_to_wav` plus an external player. |
| `Camera3D` | `near` 0.05, `far` 4000, `fov` 75 (vertical), `keep_aspect` KEEP_HEIGHT | Docs: lowering near reduces precision everywhere. Use near 1–2 m outdoors. |
| `Viewport.use_hdr_2d` | default false; HDR framebuffer for 2D, linear maths until display | Only needed for 2D HDR UI/glow. The 3D scene is HDR anyway on Forward+. |
| `SubViewport` | `size` 512×512, `render_target_update_mode` (DISABLED 0, ONCE 1, WHEN_VISIBLE 2 default, WHEN_PARENT_VISIBLE 3, ALWAYS 4), `render_target_clear_mode` | Use for offscreen captures (thumbnails, contact sheets). Set ALWAYS for continuous rendering. |
| Spatial `render_mode` | blend_mix/add/sub/mul/premul_alpha; depth_draw_opaque/always/never; depth_prepass_alpha; depth_test_disabled/default/inverted; cull_back/front/disabled; unshaded; vertex_lighting; shadows_disabled; ambient_light_disabled; shadow_to_opacity; fog_disabled; skip_vertex_transform; world_vertex_coords; alpha_to_coverage(_and_one); particle_trails; diffuse_*; specular_*; sss_mode_skin; wireframe; debug_shadow_splits | Writing ALPHA puts the material in the transparent pipeline, and transparent objects are **not** in `hint_screen_texture`/`hint_depth_texture`. If DEPTH is written, write it in every branch. |
| `Image.blit_rect(src: Image, src_rect: Rect2i, dst: Vector2i)` | Same format required, clipped, no blending (`blend_rect` blends), `create_empty(w, h, mipmaps, format)` (`create` deprecated), `save_exr(path, grayscale = false, color_image = false, max_linear_value = −1.0)` | Use for contact sheets, heightmap tiling and atlas building. |
| `OS.has_feature("movie")` | Feature tag `movie` = "Movie Maker mode is active" | Switch to maximum quality when true. |
| `MovieWriter` | Built-in OGV (Theora+Vorbis; Theora encode only in editor binaries), AVI (MJPEG, uncompressed audio, 4 GB cap), PNG sequence (+WAV). Fixed delta like `--fixed-fps`. `_write_end` runs on window close or `SceneTree.quit()`, **not on Ctrl+C**. Custom writers default to 48 kHz. | Always end with `get_tree().quit()`. |
| `ParticleProcessMaterial` | EMISSION_SHAPE_RING (6) with `emission_ring_axis/height/radius/inner_radius/cone_angle`; `turbulence_*` (enabled false, strength 1, scale 9, speed, influence 0.1); `collision_mode` RIGID/HIDE_ON_CONTACT; `sub_emitter_mode` incl. AT_COLLISION/AT_START; `radial_velocity_*`, `directional_velocity_*`, `velocity_pivot` | A ring emitter riding the shock radius is the dust skirt. |
| `NoiseTexture3D` | width/height/depth 64, `seamless` false, `normalize` true, generated **on threads** | `await tex.changed` before relying on the data. Set seamless = true for tiling. |
| `CompositorEffect` | **Experimental**. Callback types PRE_OPAQUE 0, POST_OPAQUE 1, POST_SKY 2, PRE_TRANSPARENT 3, POST_TRANSPARENT 4. `_render_callback(type, render_data)`. | The only way to post-process **after** transparents (e.g. refraction that also bends the cloud). |
| Large world coordinates (docs) | float32 step: 0.0002 m at 2–4 km, 0.0039 m at 32–65 km, 0.0156 m at 131–262 km, 0.031 m beyond | Official builds are single precision. Double precision needs a custom build. Shaders are always single precision. |

## B1. Architecture: one physics clock drives everything
- A single `ExplosionClock` (autoload) keeps `age` in seconds. Advance it by `1.0/fps` in movie mode and by `delta·time_scale` interactively. Scrub by setting it.
- On startup, register globals:
  `RenderingServer.global_shader_parameter_add(&"blast_age", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)`.
  Do the same for `blast_center_rel` (vec3, relative to camera origin), `shock_radius`, `fireball_radius`, `fireball_temp`, `flash_level` and `cloud_top`.
  Each frame, compute the physics on the CPU (A-formulas in double precision) and push the results with `global_shader_parameter_set`.
- Shaders never use `TIME` for physical motion (it wraps at 3600 s and follows time_scale). TIME is allowed only for cosmetic shimmer.
- All random seeds are fixed per bomb (`RandomNumberGenerator.seed`, particle `seed`/`use_fixed_seed`).

## B2. Volumetric fireball and mushroom cloud (ray-marched proxy)
Recipe (Dunn, GPU Pro 6; Wallis 2020; Hillaire 2015):
1. **Proxy**: a BoxMesh of size 2 (local [−1, 1]³), uniformly scaled to the cloud bounds (S = half-size in m). Material render modes: `unshaded, cull_front, depth_draw_never, depth_test_disabled, blend_premul_alpha, fog_disabled, shadows_disabled`. cull_front keeps it visible when the camera is inside. Depth testing is done manually against the depth texture, so terrain in front of the box's back faces does not cut the volume.
2. Pass the camera position in box-local space from GDScript each frame: `mat.set_shader_parameter("cam_local", node.global_transform.affine_inverse() * cam.global_position)`. This is cheaper than `inverse()` per pixel.
3. March 48–96 steps between the box entry/exit, clipped by scene depth. Jitter the start by a per-pixel hash (with TAA on, or a blue-noise texture). Exit early when transmittance < 0.01.
4. Density = smooth SDF shell + fBM erosion (B3). Emission = blackbody(T) × gain (B4). Scattering = sun with a 4-tap light march + ambient sky.
5. For each step: a = 1 − exp(−σ·ds); colour += T_acc·a·(emission + albedo·light); T_acc *= 1 − a. Output premultiplied: `ALBEDO = col; ALPHA = 1.0 - T_acc;`. HDR values above 1 feed glow.
6. Use one combined volume (fireball + cap + stem + skirt) so there are no sorting conflicts between transparent proxies. Godot sorts transparents by node origin, and there is no OIT.

```glsl
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled,
            blend_premul_alpha, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler3D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D bb_ramp : source_color, repeat_disable;   // B4
uniform vec3 cam_local;            // camera in box space
uniform float box_scale = 1000.0;  // metres per local unit
uniform vec3 sun_dir_local = vec3(0.3, 0.8, 0.2);
global uniform float blast_age;
varying vec3 v_local;
void vertex() { v_local = VERTEX; }

vec2 hit_box(vec3 ro, vec3 rd) {
    vec3 inv = 1.0 / rd;
    vec3 a = (-1.0 - ro) * inv, b = (1.0 - ro) * inv;
    vec3 lo = min(a, b), hi = max(a, b);
    return vec2(max(max(lo.x, lo.y), max(lo.z, 0.0)), min(min(hi.x, hi.y), hi.z));
}
float hash12(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// density(p) (B3) and temperature(p) (K; A2.4 plus radial falloff) must be DEFINED here,
// above fragment(): Godot shading language has no forward declarations.

void fragment() {
    vec3 rd = normalize(v_local - cam_local);
    vec2 t = hit_box(cam_local, rd);
    // clip against opaque scene (Forward+: NDC xy = uv*2-1, z = depth sample, reversed-Z)
    float z = texture(depth_tex, SCREEN_UV).r;
    vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
    t.y = min(t.y, length(vp.xyz / vp.w) / box_scale);
    if (t.y <= t.x) discard;
    const int N = 64;
    float ds = (t.y - t.x) / float(N);
    float s = t.x + ds * hash12(FRAGCOORD.xy);
    vec3 col = vec3(0.0); float tr = 1.0;
    for (int i = 0; i < N; i++) {
        vec3 p = cam_local + rd * s;
        float d = density(p);
        if (d > 0.002) {
            float a = 1.0 - exp(-d * 0.004 * ds * box_scale);  // sigma_t ~ 4 /km at d = 1
            float T = temperature(p);
            vec3 emit = texture(bb_ramp, vec2((1.0 - 1000.0 / T) / 0.975, 0.5)).rgb
                      * pow(T / 8000.0, 4.0) * 40.0;               // HDR gain, tune
            float sh = 0.0;                                      // 4-tap light march
            for (int k = 1; k <= 4; k++) sh += density(p + sun_dir_local * 0.04 * float(k * k));
            vec3 lit = vec3(1.0, 0.95, 0.88) * exp(-sh * 0.8) + vec3(0.25, 0.3, 0.4);
            col += tr * a * (emit + vec3(0.8) * lit);
            tr *= 1.0 - a;
            if (tr < 0.01) break;
        }
        s += ds;
    }
    ALBEDO = col;
    ALPHA = 1.0 - tr;
}
```
Performance on the target GPU (RTX 5070, 1080p): 64 steps × (4 fBM taps + 4 shadow taps) runs at about 2–4 ms when the volume covers half the screen (estimate). Use 128 steps and 8 shadow taps when `OS.has_feature("movie")`. If it is too slow, empty-space skip with the SDF (step = max(ds, sdf·0.8) outside the shell).

Shape (SDF, all in box-local units; iq formulas):
```glsl
uniform float cap_y; uniform float ring_R; uniform float ring_r; uniform float stem_r;
float sd_torus(vec3 p, float R, float r) { return length(vec2(length(p.xz) - R, p.y)) - r; }
float sd_cyl(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)); }
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
float cloud_sdf(vec3 p) {
    vec3 q = p - vec3(0.0, cap_y, 0.0);
    float dome = (length(q / vec3(1.0, 0.55, 1.0)) - ring_R) * 0.55;        // flattened cap
    float cap  = smin(sd_torus(q, ring_R * 0.75, ring_r), dome, 0.3 * ring_r);
    float flare = 1.0 + 1.5 * smoothstep(0.25 * cap_y, 0.0, p.y);         // skirt at the base
    float stem = sd_cyl(p - vec3(0.0, 0.5 * cap_y, 0.0), 0.5 * cap_y, stem_r * flare);
    return smin(cap, stem, 0.5 * stem_r);
}
```
Physics-to-shape mapping per frame (CPU):
- cap_y = z_c(t) (A5.3, cap centre = z_top − half-thickness);
- ring_R = a(z_c)/S·0.8 and ring_r = half-thickness/S (A5.1–A5.2);
- stem_r = r_stem/S;
- before the toroid forms (t < ~10·t₂), use a sphere of radius R_fb(t) rising at v = 0.9√(gR).
- Surface bursts add a dust stem and skirt (B6). Airbursts above 55 m·W^0.4 get no dust stem.

## B3. Noise: fBM, billows and toroidal flow
- Use a `NoiseTexture3D` (FastNoiseLite, cellular or simplex, 64³ or 128³, `seamless = true`) and `await tex.changed` before the first frame. One texture with 4 octaves at different scales is cheaper than procedural 3D noise.
```glsl
float fbm(vec3 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * texture(noise_tex, p).r;
        p = p * 2.03 + vec3(0.31, 0.17, 0.77); a *= 0.5; }
    return s / 0.9375; }
float billow(float n) { return 1.0 - abs(2.0 * n - 1.0); }   // "cauliflower" cells
```
- **Toroidal (poloidal) flow**: in the cap, gas rises through the centre, rolls outwards over the top and descends on the outside. Rotate the noise lookup in the (ρ − R₀, y − y_c) plane around the ring core, with angular speed ω(d) = ω₀/(1 + d²/r²). To avoid infinite shearing, use a **two-phase flow map**: sample at phases φ₁ = fract(t/T) and φ₂ = fract(t/T + 0.5) and blend with the weight |1 − 2φ₁|.
```glsl
uniform float vortex_omega = 0.4;  // rad/s at the core, scale ~ v_rise / ring_r
vec3 swirl(vec3 p, float ang) {
    float rho = length(p.xz); vec2 dir = p.xz / max(rho, 1e-4);
    vec2 d = vec2(rho - ring_R * 0.75, p.y - cap_y);
    float w = ang / (1.0 + dot(d, d) / (ring_r * ring_r));
    vec2 r = vec2(cos(w) * d.x - sin(w) * d.y, sin(w) * d.x + cos(w) * d.y);
    return vec3(dir * (r.x + ring_R * 0.75), r.y + cap_y).xzy; }
float density(vec3 p) {
    const float T = 8.0;
    float f1 = fract(blast_age / T), f2 = fract(blast_age / T + 0.5);
    float n1 = fbm(swirl(p, vortex_omega * f1 * T) * 3.0);
    float n2 = fbm(swirl(p, vortex_omega * f2 * T) * 3.0 + 0.5);
    float n = mix(n1, n2, abs(1.0 - 2.0 * f1));
    float edge = 0.08;
    return clamp((-cloud_sdf(p) + edge * (billow(n) - 0.45) * 2.0) / edge, 0.0, 1.0); }
```
(`.xzy` maps the result back to x, y, z. Check the axis order in your own code.)
- **Curl noise** (Bridson 2007) for particles: the built-in `ParticleProcessMaterial.turbulence_*` is curl-like and cheaper than writing it yourself. For a custom particle shader, use curl(ψ) = (∂ψ_z/∂y − ∂ψ_y/∂z, …) with central differences on three offset noise lookups.

## B4. Blackbody colour ramp
Build a `GradientTexture1D` (width 256) in GDScript. The stops below are the sRGB chromaticities of a blackbody (Mitchell Charity's table, CIE 10°; ESTIMATED, ±5 in 8-bit values). Use u = (1 − 1000/T)/0.975 (an inverse-temperature or "mired" axis gives even colour steps):

| T (K) | 1000 | 1500 | 2000 | 2500 | 3000 | 4000 | 5000 | 6500 | 8000 | 10000 | 15000 | 40000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sRGB | 255,56,0 | 255,109,0 | 255,137,18 | 255,161,72 | 255,180,107 | 255,209,163 | 255,228,206 | 255,249,253 | 227,233,255 | 204,219,255 | 181,205,255 | 155,188,255 |

```gdscript
static func blackbody_ramp() -> GradientTexture1D:
    var temps := [1000, 1500, 2000, 2500, 3000, 4000, 5000, 6500, 8000, 10000, 15000, 40000]
    var cols := [Color8(255,56,0), Color8(255,109,0), Color8(255,137,18), Color8(255,161,72),
        Color8(255,180,107), Color8(255,209,163), Color8(255,228,206), Color8(255,249,253),
        Color8(227,233,255), Color8(204,219,255), Color8(181,205,255), Color8(155,188,255)]
    var g := Gradient.new()
    g.offsets = PackedFloat32Array(temps.map(func(t): return (1.0 - 1000.0 / t) / 0.975))
    g.colors = PackedColorArray(cols)
    var tex := GradientTexture1D.new()
    tex.gradient = g
    tex.width = 256
    return tex
```
Intensity is separate from chromaticity: radiance ∝ (T/8000)⁴. Smoke (cool regions) uses albedo grey-brown: NO₂ tint (0.45, 0.30, 0.20) early, fading to (0.75, 0.75, 0.75) as the cloud whitens over 30–90 s.

## B5. Shock wave: visible shell, ground ring, Mach stem, Wilson veil
- **Shell refraction** (cheap; distorts only opaque background): a SphereMesh scaled to R_shock(t) (A2.5) each frame. For a surface burst use a hemisphere and the 2W radius.
```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.015;   // set from p(R)/P0, clamp 0..0.05
uniform float rim_glow = 0.0;     // >0 only for very close views (hot shocked air)
void fragment() {
    float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 6.0);
    vec2 off = NORMAL.xy * rim * strength;
    ALBEDO = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb + vec3(rim * rim_glow);
    ALPHA = smoothstep(0.02, 0.25, rim);   // only the limb is drawn; interior untouched
}
```
  Because transparent objects are not in the screen texture, the limb does not bend the cloud behind it. That is acceptable at a distance. For a hero close-up, implement the same offset as a `CompositorEffect` (POST_TRANSPARENT compute pass, experimental API). The shock is nearly invisible in real footage except through refraction, dust and condensation, so keep `strength` subtle (≤ 0.02) beyond 5 psi.
- **Ground ring**: in the terrain shader, read `global uniform float shock_radius;` and the blast position. Apply a band b = exp(−((r − R)/w)²) with w ≈ 0.02·R that darkens and kicks normals (dust front), plus a small brightness flicker on the precursor (A8). Behind the front, raise the dust density (B6).
- **Mach stem / triple point**: for ground range x > x_m (A3.4), add to the shell a vertical band whose height grows as h_T ≈ 0.15(x − x_m), with opacity 2× higher (it carries 2× pressure). Lift dust higher in this band.
- **Wilson veil** (A7): a second sphere or hemisphere at 0.85·R_shock(t), white, with fBM-eroded alpha. It fades in over 0.2 s at t_w and out over its lifetime. Lit by the sun and the fireball (it glows orange from inside).

## B6. Dust skirt, base surge, afterwinds
- A GPUParticles3D ring emitter (`EMISSION_SHAPE_RING`, axis Y, `emission_ring_radius` = R_shock(t), `emission_ring_inner_radius` = 0.97·R, height a few m). Each frame set the radius from the CPU, `amount_ratio` ∝ local dynamic pressure q(R), and initial velocity outward plus upward.
- Large soft billboards with a soft-particle depth fade (read `hint_depth_texture` in the particle draw shader). Use 6-way-lit or flipbook smoke for quality.
- `GPUParticlesCollisionHeightField3D` with `follow_camera_enabled = true` and `size` ≈ 20 × 2 × 20 km (the default 2 m box does nothing), resolution 2048–4096. Set `collision_mode = COLLISION_RIGID` with friction 0.8 so dust hugs the terrain.
- **Enlarge `visibility_aabb`** to the full effect extent.
- **Afterwinds / dust stem**: a second emitter at ground zero with an attractor or `radial_velocity_min < 0` plus upward velocity toward the cap. Turbulence on.
- **Base surge** (underwater or underground shots): a toroidal ring of particles expanding at 25–30 m/s (BAKER: > 1 mi/min), 300–600 m high, inner radius ≈ 2/3 of outer (02).

## B7. Lighting, exposure and post-processing (cinematic)
- Environment: `tonemap_mode = Environment.TONE_MAPPER_AGX`, `tonemap_agx_white = 8–16`, `tonemap_agx_contrast = 1.25`, `glow_enabled = true`, `glow_blend_mode = GLOW_BLEND_MODE_ADDITIVE` (or SCREEN for a softer look), `glow_hdr_threshold = 1.0`, `glow_hdr_scale = 2.0`, `glow_hdr_luminance_cap = 50–100`, `glow_intensity = 0.6–1.0`, `glow_bloom = 0.02–0.05`. Set levels with `env.set_glow_level(i, v)`, raising levels 4–6 (0-based) for the wide halo.
- **Exposure (deterministic)**: keep `auto_exposure_enabled = false` in movie mode and script `CameraAttributesPractical.exposure_multiplier = 2^EV`:
  - EV_target(t) = −clamp(log₂(1 + E_flash(t)/E_scene), 0, 8), with E_flash from A4.4 and the pulse A2.3;
  - EV moves toward its target with time constant τ_down = 0.03 s (the eye or film is instantly overloaded) and τ_up = 4–10 s (recovery);
  - add a full-screen white-out quad when E_flash/E_scene > 100.
  For interactive play the built-in auto exposure (Forward+) with `auto_exposure_speed` 1–2 is fine, but it is frame-time dependent.
- Fireball light on the world:
  - one `OmniLight3D` at the fireball (range ≥ 2·R_glow), energy ∝ P(t), colour = ramp(T(t)), shadows on;
  - for terrain kilometres away, a `DirectionalLight3D` aimed from fireball to observer is cheaper and unlimited in range, with energy ∝ E_flash(observer)/E_sun × sun energy;
  - fade it as the fireball cools;
  - add a sky-shader term for scattered glow near the horizon.
- Heat haze: screen-space distortion in a ground-hugging volume (same technique as the shock limb, noise-driven), strength ∝ local thermal fluence.

## B8. Large scenes on float32
- **Camera (observer) at the origin.** The bomb is at (0, 0, −D) with D ≤ 200 km. At 131–262 km the float32 step is 1.6 cm, which is invisible for kilometre-scale effects. Near objects (bunker, observer) are precise.
- Effects march in **proxy-local space** (B2). Noise coordinates never use world positions. GPUParticles use `local_coords = true` far from the origin (the docs warn that particles with local_coords off snap).
- Keep large-scale positions in GDScript `float` (64-bit) and send **camera-relative** float32 values to shaders. Avoid `world_vertex_coords`.
- Camera: `near` 1–2 m outdoors (0.05 inside the bunker with a separate camera), `far` 300–400 km. Reversed-Z float depth keeps enough precision. The sky renders at infinity.
- If the camera must travel more than ~8 km (e.g. a fly-out), use a floating origin:
```gdscript
const REBASE := 4096.0
var origin_offset := Vector3.ZERO   # world offset, 64-bit in GDScript
func _process(_d: float) -> void:
    var c := camera.global_position
    if absf(c.x) > REBASE or absf(c.z) > REBASE:
        var shift := Vector3(snappedf(c.x, 1024.0), 0.0, snappedf(c.z, 1024.0))
        world_root.global_position -= shift   # moves terrain, bomb, fx, camera rig
        origin_offset += shift
        RenderingServer.global_shader_parameter_set(&"origin_offset", origin_offset)
```
  (Snap to a multiple of the coarsest clipmap spacing so terrain sampling stays aligned.)

## B9. Addon-free clipmap terrain
1. Meshes: build L levels (e.g. 8) of `ArrayMesh`. Level 0 is a filled (2n+1)² grid with spacing s₀ (e.g. n = 64, s₀ = 2 m). Level k is a square ring with spacing s₀·2^k whose inner hole is level k−1, so its half-extent is n·s₀·2^k (with n = 64 and s₀ = 2 m: 16 km at k = 7, 65 km at k = 9, i.e. 10 levels). The outermost ring plus a flat skirt reaches the horizon.
2. Each level is a MeshInstance3D. Every frame its position is **snapped on the CPU** to multiples of 2·s_k around the camera XZ, so vertices never swim.
3. Vertex shader: world XZ = MODEL_MATRIX·VERTEX. Height = heightmap (`textureLod`, mip chosen by level) + procedural fBM detail. **Geomorph** near the outer 25% of each ring so odd vertices slide onto the coarser grid (no cracks or pops). Set `extra_cull_margin` large (16384) or a `custom_aabb`, because displacement escapes the flat AABB.
```glsl
shader_type spatial;
uniform sampler2D height_map : filter_linear_mipmap, repeat_disable;
uniform vec2 map_origin; uniform float map_size; uniform float height_scale;
uniform float spacing; uniform float ring_half;   // half extent of this level (m)
uniform float lod_bias;
float H(vec2 xz, float lod) { return textureLod(height_map, (xz - map_origin) / map_size, lod).r * height_scale; }
void vertex() {
    vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 d = abs(w.xz - CAMERA_POSITION_WORLD.xz) / ring_half;
    float m = clamp((max(d.x, d.y) - 0.70) / 0.25, 0.0, 1.0);    // morph factor
    vec2 g = w.xz / spacing;
    w.xz -= fract(g * 0.5) * 2.0 * spacing * m;                   // odd verts -> even
    w.y = H(w.xz, lod_bias);
    VERTEX = w - NODE_POSITION_WORLD;                             // node has no rot/scale
}
void fragment() {
    vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float e = spacing;
    float hx = H(wp.xz + vec2(e, 0.0), lod_bias) - H(wp.xz - vec2(e, 0.0), lod_bias);
    float hz = H(wp.xz + vec2(0.0, e), lod_bias) - H(wp.xz - vec2(0.0, e), lod_bias);
    vec3 n = normalize(vec3(-hx, 2.0 * e, -hz));
    NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
    ALBEDO = vec3(0.55, 0.48, 0.38);                              // + splat / scorch from blast globals
}
```
   (In 4.x spatial shaders, `CAMERA_POSITION_WORLD` and `NODE_POSITION_WORLD` are available in vertex(). If either is missing in a given build, pass them as uniforms.)
4. Aerial perspective: in the terrain fragment shader, apply exp(−d/L) toward the sky colour (or `Environment.fog_aerial_perspective`).
5. Range objects (trees, houses) go in `MultiMeshInstance3D`s split into areas, with `visibility_range_*` per area (03 doc).
6. Scorch, burn and shock-ring decals are read from blast global uniforms in the terrain shader: no extra meshes.

References: Losasso & Hoppe 2004 (geometry clipmaps); Strugar 2009 (CDLOD geomorphing); Mike J. Savage's clipmap write-up (the code reused by Terrain3D); godotshaders "Wandering Clipmap" (CC0, Godot 4.1).

## B10. Procedural low-frequency sound (GDScript → AudioStreamWAV)
Physics:
- The pressure history at the listener is a Friedlander wave, p(t) = p_s(1 − t/t₊)·e^(−b·t/t₊), with b ≈ 1–2, p_s from A3, and t₊ from A3.7/DNA.
- Far away it becomes an N-wave (sharp rise, linear fall through zero, sharp return), lasting ~2·t₊.
- Its fundamental is ~1/(2t₊), which is infrasonic (0.3–3 Hz for kt–Mt). Speakers cannot play it, so render the *feeling* as a 30–45 Hz pitched thump with the same envelope.
- Level: SPL = 20·log₁₀(p/20 µPa); 1 psi = 170.75 dB (BEC-O eq. 2-29). Map it to the game loudness with a compressor.
- Delay: the blast arrives at t_a (A3.6), slightly earlier than d/343 near the bomb. The ground shake (P-wave) comes before it.

Atmospheric absorption (ISO 9613-1, 20 °C, 70% RH, approximate; ESTIMATED):

| Frequency | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|
| Absorption (dB/km) | 0.3 | 1.1 | 2.8 | 5 | 9 | 23 | 77 |

This makes a natural low-pass with cutoff **f_c ≈ 1.2 kHz·(d/1 km)^−0.8**: 7.6 kHz at 100 m, 190 Hz at 10 km, ~55 Hz at 50 km. Distant blasts are therefore a dull boom followed by long thunder-like rumble.

Layers:
1. Crack: a white-noise burst, 5–20 ms, 2–8 kHz, only within a few km.
2. Body: the Friedlander or N-wave plus a 38 → 28 Hz sine sweep under the same envelope.
3. Rumble: brown noise, low-passed at 80–200 Hz, amplitude-modulated at 0.3–3 Hz (multipath and terrain echoes). Its length grows with distance (5–30 s, like thunder).
4. Close range only: fireball roar (low-passed noise swelling over t₂…t(R_max)).
5. Debris and wind gust when q is large.
```gdscript
static func blast_wav(dist_m: float, t_pos: float, seed: int, sr: int = 48000) -> AudioStreamWAV:
    var dur := 3.0 + 25.0 * clampf(dist_m / 30000.0, 0.1, 1.0)
    var n := int(dur * sr)
    var rng := RandomNumberGenerator.new(); rng.seed = seed
    var fc := clampf(1200.0 * pow(maxf(dist_m, 50.0) / 1000.0, -0.8), 40.0, 16000.0)
    var k := 1.0 - exp(-TAU * fc / sr)                      # one-pole low-pass coefficient
    var tp := clampf(t_pos, 0.03, 0.6)
    var lp := 0.0; var brown := 0.0; var peak := 1e-6
    var out := PackedFloat32Array(); out.resize(n)
    for i in n:
        var t := float(i) / sr
        var body := (1.0 - t / tp) * exp(-1.5 * t / tp) if t < 4.0 * tp else 0.0
        var sub := sin(TAU * (38.0 - 10.0 * minf(t / 1.5, 1.0)) * t) * exp(-t / (0.5 + tp))
        var crack := rng.randf_range(-1.0, 1.0) * exp(-t / 0.01)
        brown = (brown + rng.randf_range(-1.0, 1.0) * 0.02) * 0.998
        var am := 0.6 + 0.4 * sin(TAU * 0.7 * t + 3.0 * sin(TAU * 0.13 * t))
        var rumble := brown * am * exp(-t / (0.3 * dur)) * smoothstep(0.0, 0.3, t)
        lp += k * ((0.8 * body + 0.6 * sub + crack + 2.0 * rumble) - lp)
        out[i] = lp; peak = maxf(peak, absf(lp))
    var bytes := PackedByteArray(); bytes.resize(n * 2)
    for i in n:
        bytes.encode_s16(i * 2, int(clampf(out[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sr
    wav.stereo = false
    wav.data = bytes
    return wav
```
- Performance: about 1.4 M samples for a 30 s tail is slow in GDScript (~1–3 s). Generate during the flight, or with `WorkerThreadPool.add_task`, or synthesise the rumble at 12 kHz with `mix_rate = 12000` (it is low-passed anyway).
- Playback: `AudioStreamPlayer` on a "Blast" bus, started at t_a (`await get_tree().create_timer(t_a).timeout` runs on game time in movie mode).
- Master bus: `AudioEffectCompressor`, then `AudioEffectHardLimiter` (ceiling −0.3 dB). The old `AudioEffectLimiter` is deprecated.
- Pre-blast ground rumble: a separate 8–20 Hz-modulated 30–40 Hz layer starting at d/5000 s (rock P-wave ~5–6 km/s; 0.5–1.5 km/s in soft ground).
- Movie mode records audio to WAV (PNG writer). The mix rate must divide by the fps (44100 and 48000 both divide by 30).

## B11. Determinism, screenshots and offline render
- `OS.has_feature("movie")` → highest quality presets (ray-march steps, particle `amount_ratio` 1.0, shadow atlas 8192).
- Take screenshots after `await RenderingServer.frame_post_draw`, never in `_ready()`. `Image.save_png`, or `save_exr(path, false, false, -1.0)` for HDR.
- Use `Image.blit_rect` (same format) to tile shots into QA contact sheets.
- Quit through `get_tree().quit()` so `MovieWriter._write_end` finalises the AVI/WAV.
- Fixed seeds for noise (FastNoiseLite.seed), particles and RNG.

## B12. Pitfalls checklist
- Transparents are sorted by node origin, with no OIT. Keep one volume for the whole explosion and use `render_priority` for the shock shell and Wilson veil.
- Transparent materials do not appear in the screen or depth textures, so the refraction shell will not bend the cloud (B5).
- The `GPUParticlesCollisionHeightField3D.size` default is 2 m and `visibility_aabb` is small: enlarge both.
- Evaluate Brode on the CPU in double precision (z^18). Never in a shader.
- Volumetric fog length is 64 m by default: unusable for km-scale clouds.
- AgX is the slowest tonemapper; that is fine on the target GPU, but say so in the perf notes.
- `NoiseTexture3D` is generated asynchronously: `await tex.changed`.
- The auto-exposure temporal response differs between interactive and movie runs, so script the exposure for renders.

---

## UI glossary blurbs (optional; RU and EN)
- Fireball / Огненный шар
  - RU: «За первые миллисекунды воздух раскаляется до сотен тысяч градусов. Яркость падает, когда ударная волна закрывает шар, и вспыхивает вновь: главный тепловой импульс длится от долей секунды до секунд.»
  - EN: "In the first milliseconds the air is heated to hundreds of thousands of degrees. The glow dims while the shock front hides the fireball, then flares again: the main heat pulse lasts from a fraction of a second to several seconds."
- Shock wave / Ударная волна
  - RU: «Фронт сжатого воздуха сначала обгоняет звук, потом замедляется до скорости звука. 1 psi выбивает стёкла, 5 psi рушит дома.»
  - EN: "A wall of compressed air that starts faster than sound and slows to sound speed. 1 psi breaks windows; 5 psi destroys houses."
- Wilson cloud / Облако Вильсона
  - RU: «Во влажном воздухе за фронтом волны на секунду-две возникает белый купол конденсата: разрежение охлаждает воздух ниже точки росы.»
  - EN: "In humid air a white dome of condensation appears behind the shock front for a second or two, because the rarefaction cools the air below its dew point."
- Mushroom cloud / Грибовидное облако
  - RU: «Горячий шар всплывает, как пузырь, и закручивается в вихревое кольцо. Мегатонные облака пробивают тропопаузу и поднимаются на 20–40 км и выше.»
  - EN: "The hot fireball rises like a bubble and rolls into a vortex ring. Megaton clouds punch through the tropopause to 20–40 km and higher."

---

## Sources (all fetched or read 2026-11-07)
Physics:
- Glasstone & Dolan, *The Effects of Nuclear Weapons* (1977), ch. 2, 6, 7, 12 — https://www.atomicarchive.com/resources/documents/effects/glasstone-dolan/chapter2.html (and chapter6/7/12)
- E. R. Fletcher et al., *Nuclear Bomb Effects Computer (incl. slide-rule design and curve fits)*, CEX-62.2 / ADA384998, 1963. Tables 2.1, 2.9, 2.11 and Fig. 2.19 were transcribed from the scan — https://www.deepspace.ucsb.edu/wp-content/uploads/2025/10/NUCLEAR-BOMB-EFFECTS-COMPUTER-incl-slide-rule-and-functional-fits-Fletcher-et-al-1963.pdf
- NUKEMAP FAQ (methodology: Fletcher, G&D 1977, Miller 1963) — https://nuclearsecrecy.com/nukemap/faq/
- NUKEMAP effects code (fireball, crater, thermal, cloud fits; read for verification, not copied) — https://static.nuclearsecrecy.com/nukeeffects.js
- A. Wellerstein blog on NUKEMAP airburst modelling — https://blog.nuclearsecrecy.com/?p=4773
- C. Sublette, Nuclear Weapons FAQ §5 — https://nuclearweaponarchive.org/Nwfaq/Nfaq5.html
- R. D. Small & H. L. Brode, "Thermal radiation from a nuclear weapon burst" (PSR) — https://digital2.library.iit.edu/files//original/811f3f169824119d6afe44bbce0b5197b4882af1.pdf
- E. Geist, *glasstone* Python library (MIT): Brode 1986 HOB fit and the DNA 1-kt standard from the DNA BLAST/WE help files; WSEG-10 — https://github.com/GOFAI/glasstone
- B. Purnell, "Fallout Model for the RNEP" (FAS), cloud fits to G&D Figs. 9.96 and 2.16 — https://programs.fas.org/ssp/nukes/nuclearcalculators/cloudmodel.pdf (archived copy)
- Shreve (ed.), *Proceedings of the Upper Atmosphere Sampling Symposium* (Sandia, 1961), Table 1 (equatorial cloud heights) — https://rminucleardocs.icaad.ngo/en/entity/7o6w0a59f0w?page=74
- Hooper et al., arXiv:2108.04888 (DELFIC cloud sizes and times) — https://arxiv.org/abs/2108.04888
- "Revisiting Taylor and the Trinity Test", arXiv:2403.19657 (K(γ) constants) — https://arxiv.org/html/2403.19657v1
- DDESB TP-20 (BEC-O), Kingery–Bulmash/Swisdak SI coefficients — https://www.denix.osd.mil/ddes/denix-files/sites/32/2018/07/2018-06-11-DDESB-TP-202c-DDESB-Blast-Effects-Computer-Open-BEC-O2c-V...-1.pdf
- ISO 9613-1 atmospheric absorption: values quoted from the standard table (approximate)

Rendering and Godot:
- Godot 4.7 docs: class_environment, class_cameraattributes, class_cameraattributespractical, class_gpuparticlescollisionheightfield3d, class_renderingserver, class_audioeffecthardlimiter, class_audioeffectlimiter, class_audiostreamwav, class_camera3d, class_viewport, class_subviewport, class_image, class_moviewriter, class_particleprocessmaterial, class_noisetexture3d, class_compositoreffect, tutorials/shaders/shader_reference/spatial_shader, tutorials/export/feature_tags, tutorials/physics/large_world_coordinates — https://docs.godotengine.org/en/stable/
- C. Wallis, "Volumetric Rendering Part 1" — https://wallisc.github.io/rendering/2020/05/02/Volumetric-Rendering-Part-1.html
- I. Quilez, distance functions and smooth minimum — https://iquilezles.org/articles/distfunctions/ , https://iquilezles.org/articles/smin/ , https://iquilezles.org/articles/fbm/
- A. Dunn, "Realistic Volumetric Explosions in Games", GPU Pro 6 (2015)
- S. Hillaire, "Physically Based and Unified Volumetric Rendering in Frostbite", SIGGRAPH 2015 Advances
- R. Bridson et al., "Curl-Noise for Procedural Fluid Flow", SIGGRAPH 2007 — https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf
- F. Losasso & H. Hoppe, "Geometry Clipmaps", SIGGRAPH 2004; F. Strugar, "CDLOD", 2009; Terrain3D (MIT, clipmap from M. J. Savage) — https://github.com/TokisanGames/Terrain3D ; godotshaders "Wandering Clipmap" — https://godotshaders.com/shader/wandering-clipmap-stylized-terrain/
- M. Charity, blackbody colour datafile (vendian.org): stops in B4 quoted approximately

Not reachable during this session: DTIC PDFs (HTTP 403: ADA047372, ADA083755, ADA526744) and the Swisdak original, so the KB coefficients were taken from DDESB TP-20; a G&D Fig. 7.84 scan (the 1962 eq. 2.112 fit was used instead). A web search for quantitative Wilson-cloud dimensions was refused by the search backend; A7 is therefore ESTIMATED.
