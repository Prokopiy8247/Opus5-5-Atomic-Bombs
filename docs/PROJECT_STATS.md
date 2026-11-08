# PROJECT STATS (task section 14)

All numbers below are measured from `docs/TIMELOG.md`, git commit times and the Claude Code session logs, unless marked
**estimate**. Updated 2026-11-08T15:33+01:00 after the follow-up requests (standalone build, recorded explosion sounds);
the original build's figures (to 2026-11-08T00:05) are kept in sections 1-3 below.

## 0. Totals for the whole project (original build + follow-up requests)

| | Original build (to 11-08 00:05) | Follow-up requests (11-08 06:22 - 15:33) | **Total** |
|---|---|---|---|
| Active working time | 8h 05m 00s | 4h 24m 06s | **12h 29m 06s** |
| Assistant messages (API requests) | 5,299 | 1,244 | **6,543** |
| Input tokens (uncached) | 10,712 | 2,518 | **13,230** |
| Output tokens | 6,839,795 | 1,858,274 | **8,698,069** |
| Cache write tokens (5 min / 1 h) | 22,184,742 (19,516,819 / 2,667,923) | 5,324,643 (4,324,403 / 1,000,240) | **27,509,385** (23,841,222 / 3,668,163) |
| Cache read tokens | 1,370,630,120 | 241,164,852 | **1,611,794,972** |
| Cost at API-equivalent prices | $529.89 | $115.03 | **$644.92** |

All 6,543 requests are `claude-opus-5-5`, `service_tier=standard`, `speed=standard`, `inference_geo=global` (no fast
mode, no US-only inference, no other models). Cost by category (total): input $0.05, output $173.96, cache write 5 min
$119.21, cache write 1 h $29.35, cache read $322.36. Prices re-checked on the official pricing page on 2026-11-08
(unchanged): Claude Opus 5.5 $4 / MTok input, $20 output, $5 5-minute cache write, $8 1-hour cache write, $0.20
cache read; the full 1M context is billed at standard rates. Same script and formula as section 2-3
(`tools/usage_report.py`, both sessions); the report was run at 15:33, so the last messages of this statistics step
are not included (a few thousand tokens).

**Active time method.** Original build: from `docs/TIMELOG.md` boundaries (section 1). Follow-up: from the log
timestamps of the main session and all workflow agents; a silence longer than 15 minutes with nothing running counts
as a pause (the user away). Cross-check with the same log-only method over the whole project: 12h 33m 20s (it counts
the first session from its first log line, 05:32, and to its last, 09:44, a few minutes wider than the timelog).

### Follow-up requests on 2026-11-08 (wall clock, from the logs)

| Period | Work | Duration |
|---|---|---|
| 06:22 - 06:32 | "build the game": export preset, `build.bat`, build verified from a copy | 0h 10m |
| 10:40 - 12:13 | small-bomb blasts inaudible: diagnosis by measurement, research workflow (7 agents, 83 min), design spec; stopped by the user at 12:13 before any code change | 1h 33m |
| 12:16 - 12:45 | English ElevenLabs prompts for 20 bombs + extras, reviewed by 3 agents | 0h 29m |
| 12:45 - 13:24 | pause: the user generated the sounds in ElevenLabs | (pause) |
| 13:24 - 13:29 | rocket launch prompts | 0h 05m |
| 13:29 - 15:22 | integration of the 24 recordings: processing tool, per-shot adaptation, sample mode, recorded rocket, silent bunker (user requests 14:07 / 14:09), in-game renders, QA matrix (102 launches), independent review (22 agents) and its 16 fixes, rebuild, commit | 1h 53m |
| 15:30 - 15:33 | build check (the 15:18 build is current) and these statistics | 0h 03m |

Pauses between the follow-ups: 00:06 - 06:22 (night), 06:32 - 10:40, 12:45 - 13:24 (sound generation by the user).

Follow-up tokens by log (difference to the original report):

| Kind (follow-up only) | Input | Output | Cache write | Cache read |
|---|---|---|---|---|
| e7610a78 main | 588 | 392,712 | 1,000,240 | 116,065,966 |
| e7610a78 workflow agents (research 7, prompt review 4, code review 22 agents) | 1,930 | 1,465,562 | 4,324,403 | 125,098,886 |

| Kind (whole project) | Input | Output | Cache write | Cache read |
|---|---|---|---|---|
| 957e3f63 main | 958 | 772,166 | 1,380,615 | 222,434,664 |
| 957e3f63 subagents | 682 | 419,703 | 970,358 | 108,803,627 |
| 957e3f63 workflow agents | 4,014 | 3,105,702 | 11,076,570 | 406,500,203 |
| e7610a78 main | 1,646 | 840,573 | 2,287,548 | 335,523,486 |
| e7610a78 workflow agents | 5,930 | 3,559,925 | 11,794,294 | 538,532,992 |

## 1. Time (original build)

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

## 2. Tokens (original build)

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

## 3. Cost at API-equivalent prices (method; original build)

Prices: official pricing page https://platform.claude.com/docs/en/about-claude/pricing (fetched 2026-11-07 and
re-checked 2026-11-08), stored in `tools/prices.json`. Claude Opus 5.5, USD per 1M tokens: input $4, output $20,
5-minute cache write $5, 1-hour cache write $8, cache read (hit/refresh) $0.20.

Formula: `cost = (input x 4 + output x 20 + cache_write_5m x 5 + cache_write_1h x 8 + cache_read x 0.20) / 1,000,000`.

Assumptions: standard (non-batch, non-fast, global) pricing; no long-context surcharge - the pricing page states that
Claude 4.6 and later models (except Haiku 5.5) bill the full 1M context window at standard rates (3,049 requests had
more than 200k tokens of context, the largest ~966k); no server-side tool charges (web search/fetch were client-side
tools of Claude Code); the cost is API-equivalent, not what the user's subscription actually charged.
