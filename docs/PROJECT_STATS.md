# PROJECT STATS (task section 14)

All numbers below are measured from `docs/TIMELOG.md`, git commit times and the Claude Code session logs, unless marked
**estimate**.

## 1. Time

| | |
|---|---|
| Start (`docs/TIMELOG.md`) | 2026-11-07T05:33:02+01:00 |
| End (measured when this file was written, right before the final commit) | 2026-11-08T00:05:22+01:00 |
| Wall-clock duration | 18h 32m 20s |
| Paused by the user (09:41:24 -> 20:08:44, nothing ran) | 10h 27m 20s |
| **Active working time** (session 1 4h 08m 22s + session 2 3h 56m 38s) | **8h 05m 00s** |

Two Claude Code sessions: `957e3f63` (start -> pause) and `e7610a78` (resume -> end). Session `bea59baa` in the
same projects folder is the user's own consultation session and is excluded.

### Per-stage breakdown (wall clock; stages overlap because research, modules and reviews ran as parallel agents)

| Period | Stages / work | Duration |
|---|---|---|
| 05:33 - 05:37 | 0: timelog, prompt copy, progress, reading the references | 0h 05m |
| 05:37 - 07:16 | 1: research (10-agent workflow, ran in the background in parallel with 2-4) | 1h 39m |
| 05:37 - 06:42 | 2: skeleton (project, driver choice, screenshot rig, git) | 1h 05m |
| 06:42 - 07:16 | 3-4: world (terrain, sky, bunker) + blast physics, bombs.json, selftest 112/112 (module agents in parallel) | 0h 34m |
| 07:16 - 07:56 | 5-6: reference explosion, all 20 profiles; review cycle 1 (5 art-director agents) | 0h 40m |
| 07:56 - 09:41 | 6-10: cycle-1/2 fixes, range objects, UI/sound/QA modules, QA matrix, review cycle 2, env + layers agents | 1h 45m |
| 20:08 - 21:32 | 10: cycle-3 render, review, systemic fixes, 5 parallel tuning agents, final render + independent verification | 1h 24m |
| 21:34 - 22:49 | user request: realistic launch/explosion sound - research (4 agents), per-event blast synthesis, rocket/crackle, calibration | 1h 15m |
| 22:49 - 23:29 | final QA matrix + FPS report + 60 screens; independent audio code review (13 agents) and its 9 fixes | 0h 40m |
| 23:29 - 00:05 | clean launch (`.godot` deleted), cinematic test, movie-exit leak fix, final QA matrix, docs, statistics, final commit | 0h 36m |

### Waiting on background processes (session 2, measured from output timestamps)

| Process | Duration | Overlapped with |
|---|---|---|
| QA matrix, run 1 (22:49 - 23:00) | 10.8 min | audio code review, docs |
| FPS report (23:00 - 23:07) | 7 min | QA tables, selftest docs |
| Showcase screens (23:07 - 23:18, + 2 bombs re-rendered at 23:3x) | 11 + 3 min | audio review fixes |
| Audio code-review workflow | 22.6 min | QA matrix, FPS, screens |
| All-bomb audio sweep (140 events) | ~8 min | screenshot review |
| QA matrix, run 2 after the fixes (23:50 - 00:01) | 10.8 min | docs (PROGRESS, README, QA_REPORT) |
| Workflows in session 2 (cycle-3 review, tuning, verification, audio research, code review) | see token table | the lead worked on code meanwhile |

Pure idle waiting (the lead had nothing else to do) in session 2 is **estimated** at 20-30 min; for session 1 it is not
measurable from the logs.

## 2. Tokens

Script: `tools/usage_report.py` (Python). It reads the main JSONL log of each session and every subagent / workflow
agent log under it, de-duplicates by (message id, request id) and sums the `usage` fields. All 11,330 usage records are
`claude-opus-5-5`, `service_tier=standard`, `speed=standard`, `inference_geo=global` (no fast mode, no US-only
inference, no other models). The report was run right before the final commit, so the last few messages of the final
report are not included (a few thousand tokens at most).

Logs scanned: 73 (main + 72 subagent/workflow logs)
First/last log timestamp: 2026-11-07T04:32:21.569Z / 2026-11-07T23:05:14.790Z

| Model | Messages | Input | Output | Cache write | (5m / 1h) | Cache read |
|---|---|---|---|---|---|---|
| claude-opus-5-5 | 5299 | 10,712 | 6,839,795 | 22,184,742 | 19,516,819 / 2,667,923 | 1,370,630,120 |
| **Total** | 5299 | 10,712 | 6,839,795 | 22,184,742 | | 1,370,630,120 |

By log kind:

| Kind | Input | Output | Cache write | Cache read |
|---|---|---|---|---|
| 957e3f63 main | 958 | 772,166 | 1,380,615 | 222,434,664 |
| 957e3f63 subagents | 682 | 419,703 | 970,358 | 108,803,627 |
| 957e3f63 workflow agents | 4,014 | 3,105,702 | 11,076,570 | 406,500,203 |
| e7610a78 main | 1,058 | 447,861 | 1,287,308 | 219,457,520 |
| e7610a78 workflow agents | 4,000 | 2,094,363 | 7,469,891 | 413,434,106 |

Cost at API-equivalent prices (USD):

| Model | Input | Output | Cache write 5m | Cache write 1h | Cache read | Total |
|---|---|---|---|---|---|---|
| claude-opus-5-5 | $0.04 | $136.80 | $97.58 | $21.34 | $274.13 | **$529.89** |

**Grand total: $529.89**

## 3. Cost at API-equivalent prices

Prices: official pricing page https://platform.claude.com/docs/en/about-claude/pricing (fetched 2026-11-07 and
re-checked 2026-11-08), stored in `tools/prices.json`. Claude Opus 5.5, USD per 1M tokens: input $4, output $20,
5-minute cache write $5, 1-hour cache write $8, cache read (hit/refresh) $0.20.

Formula: `cost = (input x 4 + output x 20 + cache_write_5m x 5 + cache_write_1h x 8 + cache_read x 0.20) / 1,000,000`.

Assumptions: standard (non-batch, non-fast, global) pricing; no long-context surcharge - the pricing page states that
Claude 4.6 and later models (except Haiku 5.5) bill the full 1M context window at standard rates (3,049 requests had
more than 200k tokens of context, the largest ~966k); no server-side tool charges (web search/fetch were client-side
tools of Claude Code); the cost is API-equivalent, not what the user's subscription actually charged.
