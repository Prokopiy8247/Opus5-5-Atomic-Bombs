"""Turns the QA-matrix result (qa_results.json from `-- --qa_matrix`) and docs/fps_report.json
(tools/fps_report.py) into the Markdown tables used in docs/QA_REPORT.md.
Usage: python tools/qa_tables.py --qa <qa_results.json> [--fps docs/fps_report.json]
"""
import argparse
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qa", required=True)
    ap.add_argument("--fps", default=os.path.join(ROOT, "docs", "fps_report.json"))
    a = ap.parse_args()
    bombs = json.load(open(os.path.join(ROOT, "data", "bombs.json"), encoding="utf-8"))["bombs"]
    qa = json.load(open(a.qa, encoding="utf-8"))
    s = qa["summary"]
    print("### QA matrix summary\n")
    print(f"- launches: {s['runs']} (20 bombs x 3 distances x 2 times of day + feature test), failures: {s['fails']}")
    print(f"- engine/script/shader errors counted in-process: {s.get('errors', 'n/a')}, warnings: {s.get('warnings', 'n/a')}")
    print(f"- nodes after the 2nd launch / at the end (range objects excluded): {s['nodes_start']} / {s['nodes_end']}")
    print(f"- static memory: {s['mem_start_mb']} MB -> {s['mem_end_mb']} MB; wall time {s['minutes']} min\n")
    print("| # | bomb | tod | rec km | psi rec | near km | psi near | far km | psi far | destroyed | min fps | worst frame ms | errors |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    rows = {}
    for r in qa["runs"]:
        if r.get("feature_test"):
            continue
        rows.setdefault((r["bomb"], r["tod"]), {})[r["mode"]] = r
    for (n, tod), d in sorted(rows.items(), key=lambda x: (x[0][1] != "noon", x[0][0])):
        rr, nn, ff = d.get("rec", {}), d.get("near", {}), d.get("far", {})
        runs = [x for x in (rr, nn, ff) if x]
        dest = ",".join(m for m, x in (("near", nn), ("rec", rr), ("far", ff)) if x.get("destroyed"))
        print(f"| {n} | {bombs[n - 1]['id']} | {tod} | {rr.get('dist_km', '')} | {rr.get('p_bunker_psi', '')} | {nn.get('dist_km', '')} | "
              f"{nn.get('p_bunker_psi', '')} | {ff.get('dist_km', '')} | {ff.get('p_bunker_psi', '')} | {dest or '-'} | "
              f"{min(x.get('fps', 0) for x in runs):.0f} | {max(x.get('worst_ms', 0) for x in runs):.0f} | {sum(x.get('errors', 0) for x in runs)} |")
    feats = [r for r in qa["runs"] if r.get("feature_test")]
    if feats:
        print(f"\nFeature test (slow motion 0.05x, pause, cinematographer, 4 director angles, HUD off/on, RU/EN, 4 times of day, humidity): ok={feats[0].get('ok')}")
    if os.path.exists(a.fps):
        f = json.load(open(a.fps, encoding="utf-8"))
        print("\n### FPS (windowed, real time, explosion frozen at the given age)\n")
        print("| # | bomb | view | tod | quality | age s | avg fps | avg ms | worst ms |")
        print("|---|---|---|---|---|---|---|---|---|")
        for r in f["rows"]:
            print(f"| {r['bomb']} | {bombs[r['bomb'] - 1]['id']} | {r['view']} | {r['tod']} | {r['quality']} | {r['age']:g} | "
                  f"{r['fps']:.0f} | {r['avg_ms']:.2f} | {r['worst_ms']:.1f} |")
        print(f"\nerrors during FPS runs: {len(f.get('errors', []))}")


if __name__ == "__main__":
    main()
