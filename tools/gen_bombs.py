# Generates data/bombs.json from the tables below (data lives here so that numbers are not
# hard-coded in GDScript). Run:  python tools/gen_bombs.py
# Sources: docs/01_BOMBS_REFERENCE.md and docs/RESEARCH_NOTES.md.
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bomb_profiles import PROFILES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = []


def bomb(**k):
    B.append(k)


OLIVE = [0.33, 0.36, 0.24]
YELLOW = [0.95, 0.80, 0.10]

bomb(id="mk82", name={"ru": "Mk 82", "en": "Mk 82"}, original="Mk 82 (500 lb GP)", year=1954, date="1950s-",
     country={"ru": "США", "en": "USA"}, yield_kt=0.0001, charge_kg=89, yield_conf="estimate",
     burst_type="CONVENTIONAL_SURFACE", burst_height_m=1.0, medium="ground",
     length_m=2.21, diameter_m=0.273, mass_kg=241, model="gp_bomb",
     colors={"body": OLIVE, "band": YELLOW, "accent": [0.2, 0.2, 0.2]}, rec_km=2.0)
bomb(id="mk84", name={"ru": "Mk 84", "en": "Mk 84"}, original="Mk 84 (2000 lb GP)", year=1960, date="1960s-",
     country={"ru": "США", "en": "USA"}, yield_kt=0.0005, charge_kg=429, yield_conf="estimate",
     burst_type="CONVENTIONAL_SURFACE", burst_height_m=1.5, medium="ground",
     length_m=3.84, diameter_m=0.46, mass_kg=925, model="gp_bomb_fat",
     colors={"body": OLIVE, "band": YELLOW, "accent": [0.2, 0.2, 0.2]}, rec_km=3.0)
bomb(id="tallboy", name={"ru": "«Толлбой»", "en": "Tallboy"}, original="Tallboy (12,000 lb MC)", year=1944, date="1944-06-08",
     country={"ru": "Великобритания", "en": "United Kingdom"}, yield_kt=0.003, charge_kg=2400, yield_conf="estimate",
     burst_type="CONVENTIONAL_BURIED", burst_height_m=-18.0, medium="underground",
     length_m=6.4, diameter_m=0.97, mass_kg=5400, model="tallboy",
     colors={"body": [0.28, 0.30, 0.26], "band": [0.85, 0.85, 0.75], "accent": [0.15, 0.15, 0.15]}, rec_km=4.0)
bomb(id="grand_slam", name={"ru": "«Гранд Слэм»", "en": "Grand Slam"}, original="Grand Slam (22,000 lb MC)", year=1945, date="1945-03-14",
     country={"ru": "Великобритания", "en": "United Kingdom"}, yield_kt=0.0066, charge_kg=4200, yield_conf="estimate",
     burst_type="CONVENTIONAL_BURIED", burst_height_m=-25.0, medium="underground",
     length_m=7.7, diameter_m=1.17, mass_kg=10000, model="grand_slam",
     colors={"body": [0.10, 0.10, 0.10], "band": [0.92, 0.92, 0.92], "accent": [0.9, 0.9, 0.9]}, rec_km=5.0)
bomb(id="moab", name={"ru": "GBU-43/B MOAB", "en": "GBU-43/B MOAB"}, original="GBU-43/B Massive Ordnance Air Blast", year=2003, date="2003-03-11",
     country={"ru": "США", "en": "USA"}, yield_kt=0.011, charge_kg=8500, yield_conf="measured",
     burst_type="CONVENTIONAL_SURFACE", burst_height_m=6.0, medium="air",
     length_m=9.19, diameter_m=1.03, mass_kg=9800, model="moab",
     colors={"body": [0.45, 0.47, 0.46], "band": YELLOW, "accent": [0.3, 0.3, 0.3]}, rec_km=8.0, parachute=True)
bomb(id="davy_crockett", name={"ru": "W54 «Дэви Крокетт»", "en": "W54 Davy Crockett"}, original="M388 / W54 (Little Feller I)", year=1962, date="1962-07-17",
     country={"ru": "США", "en": "USA"}, yield_kt=0.018, yield_conf="measured",
     burst_type="NUCLEAR_SURFACE", burst_height_m=3.0, medium="ground",
     length_m=0.79, diameter_m=0.28, mass_kg=34.5, model="watermelon",
     colors={"body": [0.36, 0.40, 0.28], "band": YELLOW, "accent": [0.2, 0.2, 0.2]}, rec_km=8.0)
bomb(id="foab", name={"ru": "АВБПМ «Отец всех бомб»", "en": "ATBIP \"Father of All Bombs\""}, original="АВБПМ (ATBIP / FOAB)", year=2007, date="2007-09-11",
     country={"ru": "Россия", "en": "Russia"}, yield_kt=0.044, charge_kg=7100, yield_conf="claimed",
     burst_type="THERMOBARIC", burst_height_m=10.0, medium="air",
     length_m=6.0, diameter_m=1.0, mass_kg=7100, model="foab",
     colors={"body": [0.40, 0.44, 0.36], "band": [0.8, 0.1, 0.1], "accent": [0.25, 0.25, 0.25]}, rec_km=10.0, parachute=True)
bomb(id="b61_12", name={"ru": "B61 мод. 12", "en": "B61 Mod 12"}, original="B61-12 (lowest yield option)", year=2020, date="never tested",
     country={"ru": "США", "en": "USA"}, yield_kt=0.3, yield_conf="estimate",
     burst_type="NUCLEAR_AIR", burst_height_m=100.0, medium="air",
     length_m=3.6, diameter_m=0.34, mass_kg=374, model="b61",
     colors={"body": [0.78, 0.78, 0.76], "band": [0.2, 0.2, 0.2], "accent": [0.55, 0.55, 0.55]}, rec_km=12.0)
bomb(id="grable", name={"ru": "«Грейбл»", "en": "Grable"}, original="Upshot-Knothole Grable (W9, 280 mm)", year=1953, date="1953-05-25",
     country={"ru": "США", "en": "USA"}, yield_kt=15.0, yield_conf="measured",
     burst_type="NUCLEAR_LOW_AIR", burst_height_m=160.0, medium="air",
     length_m=1.38, diameter_m=0.28, mass_kg=364, model="shell",
     colors={"body": [0.35, 0.38, 0.30], "band": [0.9, 0.8, 0.2], "accent": [0.6, 0.45, 0.2]}, rec_km=20.0)
bomb(id="little_boy", name={"ru": "«Малыш» (Хиросима)", "en": "Little Boy (Hiroshima)"}, original="Little Boy", year=1945, date="1945-08-06",
     country={"ru": "США", "en": "USA"}, yield_kt=16.0, yield_conf="measured",
     burst_type="NUCLEAR_AIR", burst_height_m=580.0, medium="air",
     length_m=3.0, diameter_m=0.71, mass_kg=4400, model="little_boy",
     colors={"body": [0.30, 0.32, 0.27], "band": [0.30, 0.32, 0.27], "accent": [0.2, 0.2, 0.2]}, rec_km=20.0)
bomb(id="trinity", name={"ru": "«Тринити» («Гаджет»)", "en": "Trinity (\"Gadget\")"}, original="Trinity / Gadget", year=1945, date="1945-07-16",
     country={"ru": "США", "en": "USA"}, yield_kt=21.0, yield_conf="measured",
     burst_type="NUCLEAR_TOWER", burst_height_m=30.0, medium="ground",
     length_m=1.5, diameter_m=1.5, mass_kg=4700, model="gadget",
     colors={"body": [0.55, 0.55, 0.52], "band": [0.3, 0.3, 0.3], "accent": [0.7, 0.5, 0.3]}, rec_km=25.0)
bomb(id="baker", name={"ru": "«Бейкер» (Crossroads)", "en": "Baker (Crossroads)"}, original="Crossroads Baker (Mk III)", year=1946, date="1946-07-25",
     country={"ru": "США", "en": "USA"}, yield_kt=23.0, yield_conf="measured",
     burst_type="NUCLEAR_UNDERWATER", burst_height_m=-27.0, medium="water",
     length_m=3.26, diameter_m=1.53, mass_kg=4670, model="fatman",
     colors={"body": [0.78, 0.66, 0.25], "band": [0.15, 0.15, 0.15], "accent": [0.2, 0.2, 0.2]}, rec_km=8.0)
bomb(id="sedan", name={"ru": "«Седан» (Plowshare)", "en": "Sedan (Plowshare)"}, original="Plowshare Sedan", year=1962, date="1962-07-06",
     country={"ru": "США", "en": "USA"}, yield_kt=104.0, yield_conf="measured",
     burst_type="NUCLEAR_BURIED", burst_height_m=-194.0, medium="underground",
     length_m=0.97, diameter_m=0.43, mass_kg=212, model="canister",
     colors={"body": [0.6, 0.6, 0.58], "band": [0.9, 0.5, 0.1], "accent": [0.3, 0.3, 0.3]}, rec_km=12.0)
bomb(id="ivy_king", name={"ru": "«Айви Кинг»", "en": "Ivy King"}, original="Ivy King (Mk 18 \"SOB\")", year=1952, date="1952-11-16",
     country={"ru": "США", "en": "USA"}, yield_kt=500.0, yield_conf="measured",
     burst_type="NUCLEAR_AIR", burst_height_m=450.0, medium="air",
     length_m=3.25, diameter_m=1.52, mass_kg=3900, model="mk18",
     colors={"body": [0.55, 0.58, 0.55], "band": YELLOW, "accent": [0.3, 0.3, 0.3]}, rec_km=50.0)
bomb(id="b83", name={"ru": "B83", "en": "B83"}, original="B83 (max yield)", year=1983, date="never tested at full yield",
     country={"ru": "США", "en": "USA"}, yield_kt=1200.0, yield_conf="conceptual",
     burst_type="NUCLEAR_SURFACE", burst_height_m=2.0, medium="ground",
     length_m=3.67, diameter_m=0.46, mass_kg=1100, model="b83",
     colors={"body": [0.82, 0.82, 0.80], "band": [0.15, 0.15, 0.15], "accent": [0.6, 0.2, 0.1]}, rec_km=55.0, parachute=True)
bomb(id="rds37", name={"ru": "РДС-37", "en": "RDS-37"}, original="РДС-37", year=1955, date="1955-11-22",
     country={"ru": "СССР", "en": "USSR"}, yield_kt=1600.0, yield_conf="measured",
     burst_type="NUCLEAR_AIR", burst_height_m=1550.0, medium="air",
     length_m=5.9, diameter_m=1.5, mass_kg=5570, model="soviet_bomb",
     colors={"body": [0.40, 0.44, 0.34], "band": [0.8, 0.1, 0.1], "accent": [0.25, 0.25, 0.25]}, rec_km=60.0, parachute=True)
bomb(id="ivy_mike", name={"ru": "«Айви Майк»", "en": "Ivy Mike"}, original="Ivy Mike (\"Sausage\")", year=1952, date="1952-11-01",
     country={"ru": "США", "en": "USA"}, yield_kt=10400.0, yield_conf="measured",
     burst_type="NUCLEAR_SURFACE", burst_height_m=10.0, medium="ground",
     length_m=6.2, diameter_m=2.0, mass_kg=74000, model="sausage",
     colors={"body": [0.62, 0.62, 0.60], "band": [0.3, 0.3, 0.3], "accent": [0.2, 0.2, 0.2]}, rec_km=90.0, device=True)
bomb(id="castle_bravo", name={"ru": "«Касл Браво»", "en": "Castle Bravo"}, original="Castle Bravo (\"Shrimp\")", year=1954, date="1954-03-01",
     country={"ru": "США", "en": "USA"}, yield_kt=15000.0, yield_conf="measured",
     burst_type="NUCLEAR_SURFACE", burst_height_m=2.0, medium="ground",
     length_m=4.56, diameter_m=1.37, mass_kg=10659, model="shrimp",
     colors={"body": [0.70, 0.72, 0.74], "band": [0.3, 0.3, 0.3], "accent": [0.2, 0.2, 0.2]}, rec_km=100.0)
bomb(id="test219", name={"ru": "Испытание № 219", "en": "Test No. 219"}, original="Испытание № 219", year=1962, date="1962-12-24",
     country={"ru": "СССР", "en": "USSR"}, yield_kt=24200.0, yield_conf="measured",
     burst_type="NUCLEAR_HIGH_AIR", burst_height_m=3750.0, medium="air",
     length_m=7.0, diameter_m=1.9, mass_kg=20000, model="soviet_big",
     colors={"body": [0.82, 0.83, 0.82], "band": [0.5, 0.5, 0.5], "accent": [0.3, 0.3, 0.3]}, rec_km=120.0, parachute=True, snow=True)
bomb(id="tsar", name={"ru": "«Царь-бомба» (АН602)", "en": "Tsar Bomba (AN602)"}, original="АН602 (РДС-220)", year=1961, date="1961-10-30",
     country={"ru": "СССР", "en": "USSR"}, yield_kt=50000.0, yield_conf="measured",
     burst_type="NUCLEAR_HIGH_AIR", burst_height_m=4000.0, medium="air",
     length_m=8.0, diameter_m=2.1, mass_kg=26500, model="tsar",
     colors={"body": [0.92, 0.92, 0.90], "band": [0.6, 0.6, 0.6], "accent": [0.3, 0.3, 0.3]}, rec_km=150.0, parachute=True, snow=True)

# ---------------------------------------------------------------- research values
# data/research_values.json is extracted from the research workflow (docs/RESEARCH_NOTES.md):
# measured / resolved numbers override the formula defaults for each bomb.
RES = {}
_rp = os.path.join(ROOT, "data", "research_values.json")
if os.path.exists(_rp):
    for r in json.load(open(_rp, encoding="utf-8")):
        RES[r["number"]] = r
# research numbering follows the task table (Little Boy 9, Grable 10); our order swaps them (D007)
RES_BY_ID = {}
_order_task = ["mk82", "mk84", "tallboy", "grand_slam", "moab", "davy_crockett", "foab", "b61_12", "little_boy",
               "grable", "trinity", "baker", "sedan", "ivy_king", "b83", "rds37", "ivy_mike", "castle_bravo", "test219", "tsar"]
for i, bid in enumerate(_order_task):
    if (i + 1) in RES:
        RES_BY_ID[bid] = RES[i + 1]

for i, b in enumerate(B):
    b["num"] = i + 1
    r = RES_BY_ID.get(b["id"])
    if r is None:
        continue
    for key in ("length_m", "diameter_m", "mass_kg"):
        if r.get(key):
            b[key] = r[key]
    if r.get("burst_height_m") is not None and b["id"] not in ("little_boy",):
        b["burst_height_m"] = r["burst_height_m"]
    if b["id"] == "little_boy":
        b["burst_height_m"] = 600.0
    b["blurb"] = {"ru": r.get("blurb_ru", ""), "en": r.get("blurb_en", "")}
    b["paint_note"] = r.get("paint", "")
    b["research"] = {
        "fireball_max_radius_m": r.get("fireball_max_radius_m"),
        "cloud_top_km": r.get("cloud_top_km"),
        "cloud_cap_diameter_km": r.get("cloud_cap_diameter_km"),
        "crater_diameter_m": r.get("crater_diameter_m"),
        "crater_depth_m": r.get("crater_depth_m"),
    }

    b.setdefault("parachute", False)
    b.setdefault("device", False)
    b.setdefault("snow", False)
    b.setdefault("charge_kg", 0)
    b.setdefault("blurb", {"ru": "", "en": ""})
    prof = dict(PROFILES.get(b["id"], {}))
    rr = b.get("research", {})
    if rr.get("fireball_max_radius_m"):
        prof.setdefault("fireball_r_m", float(rr["fireball_max_radius_m"]))
    if rr.get("cloud_top_km"):
        prof["cloud_top_m"] = float(rr["cloud_top_km"]) * 1000.0
    if rr.get("cloud_cap_diameter_km") and not prof.get("cap_keep"):
        prof["cap_radius_m"] = float(rr["cloud_cap_diameter_km"]) * 500.0
    if rr.get("crater_diameter_m") and prof.get("crater", True) and b["medium"] != "water":
        prof["crater_r_m"] = float(rr["crater_diameter_m"]) * 0.5
        if rr.get("crater_depth_m"):
            prof["crater_depth_m"] = float(rr["crater_depth_m"])
    b["profile"] = prof

if __name__ == "__main__":
    out = {"version": 1, "bombs": B}
    p = os.path.join(ROOT, "data", "bombs.json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("wrote", p, len(B))
