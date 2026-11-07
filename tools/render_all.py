"""Batch renderer for the review cycles: runs the deterministic shot rig for a set of bombs,
views and times of day, writes contact sheets. Usage:
  python tools/render_all.py --out DIR [--bombs 1,2,3] [--views zoom,bunker] [--tods noon] [--dist rec|near|far]
"""
import argparse
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
sys.path.insert(0, os.path.join(ROOT, "tools"))

NUKE = [0.002, 0.02, 0.1, 0.5, 1, 2, 5, 10, 20, 40, 90, 180, 360]
CONV = [0.005, 0.02, 0.06, 0.15, 0.4, 1, 2, 4, 8, 15, 30, 60]
BURIED = [0.05, 0.15, 0.3, 0.6, 1, 2, 3, 5, 8, 15, 30, 60]
THERMO = [0.05, 0.2, 0.5, 1, 2, 3, 5, 7, 9, 15, 30, 60]


def schedule(b):
    bt = b["burst_type"]
    if bt == "CONVENTIONAL_BURIED":
        return BURIED
    if bt == "THERMOBARIC":
        return THERMO
    if bt.startswith("CONVENTIONAL"):
        return CONV
    if b["id"] == "sedan":
        return [0.5, 1.5, 2.5, 3.2, 3.6, 5, 8, 15, 30, 60, 120, 240]
    if b["id"] == "baker":
        return [0.02, 0.2, 0.6, 1.2, 2, 4, 8, 15, 30, 60, 120, 240]
    if float(b["yield_kt"]) >= 1000.0:
        return [0.002, 0.02, 0.1, 0.5, 2, 5, 10, 20, 40, 90, 180, 360, 600]
    return NUKE


def main():
    import json
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--bombs", default="")
    ap.add_argument("--views", default="zoom")
    ap.add_argument("--tods", default="noon")
    ap.add_argument("--dist", default="rec")
    ap.add_argument("--extra", default="")
    ap.add_argument("--res", default="1600x900")
    a = ap.parse_args()
    data = json.load(open(os.path.join(ROOT, "data", "bombs.json"), encoding="utf-8"))["bombs"]
    nums = [int(x) for x in a.bombs.split(",")] if a.bombs else list(range(1, 21))
    os.makedirs(a.out, exist_ok=True)
    failures = []
    t0 = time.time()
    for n in nums:
        b = data[n - 1]
        for view in a.views.split(","):
            for tod in (a.tods.split(",") if a.tods != "hist" else [b.get("profile", {}).get("tod_hist", "noon")]):
                for dmode in a.dist.split(","):
                    rec = float(b["rec_km"])
                    dist = {"rec": rec, "near": rec / 3.0, "far": rec * 3.0}.get(dmode, rec)
                    dist = max(0.5, min(200.0, dist))
                    shots = ",".join(str(s) for s in schedule(b))
                    log = os.path.join(a.out, f"b{n:02d}_{view}_{tod}_{dmode}.log")
                    cmd = [GODOT, "--path", ROOT, "--resolution", a.res, "--",
                           "--bomb", str(n), "--dist", f"{dist:.3f}", "--tod", tod, "--view", view,
                           "--shots", shots, "--out", a.out, "--sheet", "1",
                           "--prefix", f"b{n:02d}_{b['id']}_{view}_{tod}_{dmode}"] + (a.extra.split() if a.extra else [])
                    t1 = time.time()
                    with open(log, "w", encoding="utf-8", errors="replace") as f:
                        try:
                            subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=600)
                        except subprocess.TimeoutExpired:
                            f.write("\nTIMEOUT\n")
                    txt = open(log, encoding="utf-8", errors="replace").read()
                    bad = [l for l in txt.splitlines() if ("SCRIPT ERROR" in l or l.startswith("ERROR") or "SHADER ERROR" in l or "Parse Error" in l)
                           and "RID allocations" not in l and "PagedAllocator" not in l and "Unreferenced static" not in l]
                    ok = "READY" in txt and not bad
                    print(f"b{n:02d} {b['id']:14s} {view:7s} {tod:5s} {dmode:4s} {dist:7.2f} km  {'OK ' if ok else 'FAIL'} {time.time() - t1:5.1f}s", flush=True)
                    if not ok:
                        failures.append((n, view, tod, dmode, bad[:3]))
    print(f"done in {time.time() - t0:.0f}s, failures: {len(failures)}")
    for f in failures:
        print("FAIL", f)


if __name__ == "__main__":
    main()
