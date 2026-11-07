"""FPS report (task section 9 / 11.7): windowed real-time runs of the shot rig with the explosion
frozen at a given age (`--fps_hold N` renders N frames at that age and prints avg / worst frame time).
Scenarios: every bomb from the bunker at its recommended distance at noon (fireball and cloud
stages), the binocular view of every bomb at the cloud stage, the worst case (Tsar Bomba, night,
cloud peak) at all four quality presets, and the Tsar worst case with the binocular view filling
the screen. Writes docs/fps_report.json and prints a markdown table.
Usage: python tools/fps_report.py [--res 2560x1440] [--bombs 1,20] [--frames 240]
"""
import argparse
import json
import os
import re
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
FPS_RE = re.compile(r"FPS bomb=(\d+) age=([\d.]+) avg_fps=([\d.]+) avg_ms=([\d.]+) worst_ms=([\d.]+)")


def run(bomb, ages, view, tod, quality, res, frames, extra=None):
    tmp = tempfile.mkdtemp(prefix="fps_")
    cmd = [GODOT, "--path", ROOT, "--resolution", res, "--", "--bomb", str(bomb), "--view", view, "--tod", tod,
           "--quality", quality, "--shots", ",".join(str(a) for a in ages), "--out", tmp, "--prefix", "f",
           "--fps_hold", str(frames)] + (extra or [])
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
    out = []
    for m in FPS_RE.finditer(p.stdout):
        out.append({"bomb": int(m.group(1)), "age": float(m.group(2)), "fps": float(m.group(3)),
                    "avg_ms": float(m.group(4)), "worst_ms": float(m.group(5)), "view": view, "tod": tod,
                    "quality": quality, "res": res})
    errs = [l for l in (p.stdout + p.stderr).splitlines() if "SCRIPT ERROR" in l or l.startswith("ERROR")]
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    return out, errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", default="2560x1440")
    ap.add_argument("--bombs", default="")
    ap.add_argument("--frames", type=int, default=240)
    a = ap.parse_args()
    data = json.load(open(os.path.join(ROOT, "data", "bombs.json"), encoding="utf-8"))["bombs"]
    nums = [int(x) for x in a.bombs.split(",")] if a.bombs else list(range(1, 21))
    rows, errors = [], []
    for n in nums:
        b = data[n - 1]
        conv = b["burst_type"].startswith("CONVENTIONAL") or b["burst_type"] == "THERMOBARIC"
        mt = float(b["yield_kt"]) >= 1000.0
        ages = [0.1, 2.0, 20.0] if conv else ([2.0, 40.0, 180.0, 360.0] if mt else [1.0, 20.0, 90.0])
        r, e = run(n, ages, "bunker", "noon", "high", a.res, a.frames)
        rows += r
        errors += e
        r, e = run(n, [ages[-1]], "zoom", "noon", "high", a.res, a.frames)
        rows += r
        errors += e
        print(f"bomb {n:2d} done ({len(rows)} rows)", flush=True)
    if not a.bombs or "20" in a.bombs.split(","):
        for q in ["low", "medium", "high", "cine"]:
            r, e = run(20, [90.0, 180.0, 360.0], "bunker", "night", q, a.res, a.frames)
            rows += r
            errors += e
        r, e = run(20, [20.0, 90.0, 180.0], "zoom", "night", "high", a.res, a.frames)
        rows += r
        errors += e
    json.dump({"rows": rows, "errors": errors}, open(os.path.join(ROOT, "docs", "fps_report.json"), "w"), indent=1)
    print("| bomb | view | tod | quality | age s | avg fps | avg ms | worst ms |")
    print("|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['bomb']} {data[r['bomb'] - 1]['id']} | {r['view']} | {r['tod']} | {r['quality']} | {r['age']:g} | "
              f"{r['fps']:.0f} | {r['avg_ms']:.2f} | {r['worst_ms']:.1f} |")
    print("errors:", len(errors))
    for e in errors[:10]:
        print(e)


if __name__ == "__main__":
    main()
