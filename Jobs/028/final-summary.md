# Final Summary — Job #028: Retention (daily rewards + streaks + weekly objectives)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §9.
Depends on #021 (profile) + #022/#026 (Gold / River Score).

## What was built
### Daily login reward (lobby, auto on first join of the UTC day)
- 7-day escalating Gold cycle **10/15/20/30/40/50/100**, **+250 at every 30th day**.
- **Forgiving streak:** gap ≤ 2 UTC days keeps it; > 2 resets to 1. Integer UTC day number for gap math.
- Client popup notifies (Day N · Streak M · +Gold).

### Weekly objectives (progress in-game, claim in lobby; reset on UTC-week rollover)
`finish` (win 3 → 80 G + 500 score) · `travel` (30,000 studs → 60 G + 300) · `zone` (reach Zone 4 → 50 G + 250).
Server-authoritative claim (complete + unclaimed only).

### Files
- **New (both trees):** `ReplicatedStorage/Progression/RetentionDefs.luau` (daily table, weekly defs, day/week
  helpers, `dailyReward`).
- **Edit (both trees):** `ProfileConfig.luau` — `lastLoginDay, loginStreak, weekId, weekly{finish,travel,zone},
  weeklyClaimed{}`.
- **New (lobby):** `ServerScriptService/Progression/RetentionServer.server.luau` (join → weekly reset + daily
  grant + `DailyReward` RE; `Weekly` RF list/claim); `StarterPlayer/StarterPlayerScripts/UI/RetentionClient.local.luau`
  (daily popup + "WEEKLY" panel with progress bars + Claim).
- **Edit (game):** `RunServer.server.luau` — `endRun` bumps `profile.weekly` (finish/travel/zone).

## Verified (live in Studio)
- [x] Analyzer-clean (both trees).
- [x] **Daily math:** rewards 10/15/20/30/40/50/100, day-8 cycles to 10, day-30 = 265 (15+250); streak rule
      fresh→1, gap1/gap2→+1, gap3→reset.
- [x] **Daily grant (real, on join):** fresh profile → **Gold 0→10**, popup "Day 1 · Streak 1 · +10 Gold".
- [x] **Weekly (real RF):** finish pre-set 3/3 → claim → **+80 Gold (10→90), +500 River Score (0→500)**;
      re-claim → "claimed"; incomplete (`travel` 0/30000) → "incomplete". Panel shows bars + CLAIMED/locked
      (screenshots).
- [~] **Game run-end progress bump** — construction-verified (6 lines in the same `endRun` loop already
      proven to update gold/River Score/stats); a live run will confirm end-to-end.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Day-7 "cosmetic token" deferred (no cosmetic system yet — Gold only).
- Deferred to P11 live-ops: daily-seeded runs, seasons/battle pass; camps/nights/revives objective variants
  (need per-run counters).
- **This was the last POC economy job.** Remaining from the split: **#027 (Robux)** — build anytime, but real
  purchases need a published place to verify.
