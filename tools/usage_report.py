"""Token usage report for this project's Claude Code session(s) (task section 14).

Sums the `usage` blocks of every assistant message in the main session log and in all
subagent / workflow logs, de-duplicated by (message id, request id), grouped by model and by
log kind, and prices them with the API price table passed on the command line (USD per 1M
tokens). Prints a Markdown report.

Usage:
  python tools/usage_report.py --project-dir "%USERPROFILE%/.claude/projects/G--YouTube-Atomic-Bombs" \
      --session <session-1-id> --prices prices.json
prices.json: {"claude-opus-5-5": {"input": 5, "output": 25, "cache_write_5m": 6.25, "cache_write_1h": 10, "cache_read": 0.5}, ...}
"""
import argparse
import glob
import json
import os
from collections import defaultdict

CATS = ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]


def scan(paths):
    seen = set()
    per_model = defaultdict(lambda: defaultdict(int))
    per_kind = defaultdict(lambda: defaultdict(int))
    cache_tiers = defaultdict(lambda: defaultdict(int))
    msgs = defaultdict(int)
    first_ts, last_ts = None, None
    for path, kind in paths:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                ts = e.get("timestamp")
                if ts:
                    first_ts = ts if first_ts is None or ts < first_ts else first_ts
                    last_ts = ts if last_ts is None or ts > last_ts else last_ts
                m = e.get("message")
                if not isinstance(m, dict) or m.get("role") != "assistant":
                    continue
                u = m.get("usage")
                if not u:
                    continue
                key = (m.get("id"), e.get("requestId"))
                if key in seen:
                    continue
                seen.add(key)
                model = m.get("model", "unknown")
                if model == "<synthetic>":
                    continue
                msgs[model] += 1
                for c in CATS:
                    v = int(u.get(c) or 0)
                    per_model[model][c] += v
                    per_kind[kind][c] += v
                cc = u.get("cache_creation") or {}
                cache_tiers[model]["5m"] += int(cc.get("ephemeral_5m_input_tokens") or 0)
                cache_tiers[model]["1h"] += int(cc.get("ephemeral_1h_input_tokens") or 0)
    return per_model, per_kind, cache_tiers, msgs, first_ts, last_ts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-dir", required=True)
    ap.add_argument("--session", required=True)
    ap.add_argument("--prices", default="")
    a = ap.parse_args()
    main_log = os.path.join(a.project_dir, a.session + ".jsonl")
    paths = []
    if os.path.exists(main_log):
        paths.append((main_log, "main"))
    for p in glob.glob(os.path.join(a.project_dir, a.session, "**", "*.jsonl"), recursive=True):
        kind = "workflow agents" if os.sep + "workflows" + os.sep in p else "subagents"
        paths.append((p, kind))
    per_model, per_kind, tiers, msgs, t0, t1 = scan(paths)
    prices = json.load(open(a.prices, encoding="utf-8")) if a.prices and os.path.exists(a.prices) else {}

    print(f"Logs scanned: {len(paths)} (main + {len(paths) - 1} subagent/workflow logs)")
    print(f"First/last log timestamp: {t0} / {t1}\n")
    print("| Model | Messages | Input | Output | Cache write | (5m / 1h) | Cache read |")
    print("|---|---|---|---|---|---|---|")
    tot = defaultdict(int)
    for model, d in sorted(per_model.items()):
        print(f"| {model} | {msgs[model]} | {d['input_tokens']:,} | {d['output_tokens']:,} | {d['cache_creation_input_tokens']:,} | "
              f"{tiers[model]['5m']:,} / {tiers[model]['1h']:,} | {d['cache_read_input_tokens']:,} |")
        for c in CATS:
            tot[c] += d[c]
    print(f"| **Total** | {sum(msgs.values())} | {tot['input_tokens']:,} | {tot['output_tokens']:,} | {tot['cache_creation_input_tokens']:,} | | {tot['cache_read_input_tokens']:,} |")
    print("\nBy log kind:\n")
    print("| Kind | Input | Output | Cache write | Cache read |")
    print("|---|---|---|---|---|")
    for kind, d in per_kind.items():
        print(f"| {kind} | {d['input_tokens']:,} | {d['output_tokens']:,} | {d['cache_creation_input_tokens']:,} | {d['cache_read_input_tokens']:,} |")
    if prices:
        print("\nCost at API-equivalent prices (USD):\n")
        print("| Model | Input | Output | Cache write 5m | Cache write 1h | Cache read | Total |")
        print("|---|---|---|---|---|---|---|")
        grand = 0.0
        for model, d in sorted(per_model.items()):
            p = None
            for k, v in prices.items():
                if model.startswith(k):
                    p = v
            if p is None:
                print(f"| {model} | (no price) | | | | | |")
                continue
            w5 = tiers[model]["5m"]
            w1 = tiers[model]["1h"]
            unk = d["cache_creation_input_tokens"] - w5 - w1
            w5 += max(unk, 0)  # tier unknown -> priced as 5-minute writes (assumption)
            ci = d["input_tokens"] / 1e6 * p["input"]
            co = d["output_tokens"] / 1e6 * p["output"]
            c5 = w5 / 1e6 * p["cache_write_5m"]
            c1 = w1 / 1e6 * p["cache_write_1h"]
            cr = d["cache_read_input_tokens"] / 1e6 * p["cache_read"]
            t = ci + co + c5 + c1 + cr
            grand += t
            print(f"| {model} | ${ci:,.2f} | ${co:,.2f} | ${c5:,.2f} | ${c1:,.2f} | ${cr:,.2f} | **${t:,.2f}** |")
        print(f"\n**Grand total: ${grand:,.2f}**")


if __name__ == "__main__":
    main()
