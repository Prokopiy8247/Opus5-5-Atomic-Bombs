"""Renders the showcase frames for docs/screens/ (2-3 per bomb): the bunker view, the binocular
(zoom) view and an outside 'near' cinematic view, at the bomb's historical time of day.
Usage: python tools/make_screens.py [--bombs 1,2] [--res 2560x1440]
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

# per-bomb showcase ages (s): (bunker, zoom, near)
AGES = {
    "mk82": (0.15, 1.0, 4.0), "mk84": (0.2, 1.5, 6.0), "tallboy": (1.0, 2.0, 8.0), "grand_slam": (0.35, 2.0, 10.0),
    "moab": (0.6, 1.5, 30.0), "davy_crockett": (10.0, 3.0, 60.0), "foab": (2.0, 4.0, 30.0), "b61_12": (20.0, 2.0, 90.0),
    "grable": (20.0, 10.0, 60.0), "little_boy": (40.0, 10.0, 120.0), "trinity": (30.0, 0.05, 90.0),
    "baker": (2.0, 8.0, 60.0), "sedan": (5.0, 3.6, 60.0), "ivy_king": (60.0, 20.0, 240.0), "b83": (60.0, 10.0, 240.0),
    "rds37": (60.0, 20.0, 240.0), "ivy_mike": (90.0, 20.0, 360.0), "castle_bravo": (40.0, 90.0, 360.0),
    "test219": (40.0, 20.0, 360.0), "tsar": (90.0, 20.0, 600.0),
}


def run(n, b, view, age, res, out_dir, extra):
    tmp = tempfile.mkdtemp(prefix="screens_")
    tod = b.get("profile", {}).get("tod_hist", "noon")
    cmd = [GODOT, "--path", ROOT, "--resolution", res, "--", "--bomb", str(n), "--tod", tod, "--view", view,
           "--shots", str(age), "--out", tmp, "--prefix", "s", "--quality", "cine"] + extra
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
    files = [f for f in os.listdir(tmp) if f.endswith(".png")]
    if files:
        dst = os.path.join(out_dir, f"{n:02d}_{b['id']}_{view}_t{age:g}s_{tod}.png")
        shutil.copy(os.path.join(tmp, files[0]), dst)
        print("wrote", dst)
    shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bombs", default="")
    ap.add_argument("--res", default="2560x1440")
    a = ap.parse_args()
    data = json.load(open(os.path.join(ROOT, "data", "bombs.json"), encoding="utf-8"))["bombs"]
    out_dir = os.path.join(ROOT, "docs", "screens")
    os.makedirs(out_dir, exist_ok=True)
    nums = [int(x) for x in a.bombs.split(",")] if a.bombs else list(range(1, 21))
    for n in nums:
        b = data[n - 1]
        ab, az, an = AGES.get(b["id"], (10.0, 5.0, 60.0))
        rec = float(b["rec_km"])
        run(n, b, "bunker", ab, a.res, out_dir, [])
        run(n, b, "zoom", az, a.res, out_dir, [])
        near = max(min(rec * 0.12, 25000.0 / 1000.0), 0.8)
        run(n, b, "near", an, a.res, out_dir, ["--near", str(int(max(BOMB_NEAR.get(b["id"], 0), near * 1000))), "--fov", "55",
                                                 "--look_h", str(int(LOOK_H.get(b["id"], 300))), "--cam_h", "30"])


BOMB_NEAR = {"mk82": 250, "mk84": 350, "tallboy": 450, "grand_slam": 600, "moab": 2500, "davy_crockett": 3000,
             "foab": 1500, "b61_12": 4000, "grable": 9000, "little_boy": 12000, "trinity": 12000, "baker": 7000,
             "sedan": 6000, "ivy_king": 35000, "b83": 35000, "rds37": 35000, "ivy_mike": 70000,
             "castle_bravo": 80000, "test219": 90000, "tsar": 110000}
LOOK_H = {"mk82": 40, "mk84": 80, "tallboy": 90, "grand_slam": 110, "moab": 700, "davy_crockett": 800,
          "foab": 600, "b61_12": 1000, "grable": 4000, "little_boy": 5000, "trinity": 4500, "baker": 1200,
          "sedan": 1500, "ivy_king": 9000, "b83": 9000, "rds37": 9000, "ivy_mike": 15000,
          "castle_bravo": 16000, "test219": 20000, "tsar": 25000}

if __name__ == "__main__":
    main()
