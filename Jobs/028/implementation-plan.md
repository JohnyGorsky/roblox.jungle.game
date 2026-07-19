# Job #028 — Implementation plan: Retention (daily rewards + streaks + weekly objectives)

**Project**: `roblox.jungle` · POC · Design source: Job #020 §9 · Depends on #021 (profile) + #022/#026 (Gold/River Score).

## Daily login reward (lobby, auto on first join of the day)
- 7-day escalating Gold cycle: **10,15,20,30,40,50,100** (`(streak-1)%7`); **+250 at every 30th day**.
- **Forgiving streak:** gap ≤ 2 UTC days keeps it (misses one day); gap > 2 resets to 1. First ever = 1.
- Uses **integer UTC day number** (`floor(os.time()/86400)`) so gap math is trivial + year-safe.
- Auto-granted server-side on join once ready; a client popup notifies (Day N / streak / +Gold).
- (Day-7 "cosmetic token" deferred — no cosmetic system yet; Gold only.)

## Weekly objectives (tracked at run end, claimed in lobby)
Reset when the UTC **week number** (`floor(os.time()/604800)`) changes. POC set (trackable from `endRun`):
| id | Objective | Target | Reward |
|----|-----------|-------:|--------|
| finish | Finish (win) runs | 3 | 80 Gold + 500 River Score |
| travel | Travel total studs | 30,000 | 60 Gold + 300 |
| zone | Reach Zone 4 in a run | 4 | 50 Gold + 250 |
Claim only when complete + unclaimed; server-authoritative.

## Files
**Both trees:**
- `ReplicatedStorage/Progression/RetentionDefs.luau` — daily table, weekly defs, `dayNumber`/`weekNumber`. NEW.
- `ReplicatedStorage/Progression/ProfileConfig.luau` — add `lastLoginDay, loginStreak, weekId, weekly{finish,travel,zone}, weeklyClaimed{}`. EDIT.

**Lobby:**
- `ServerScriptService/Progression/RetentionServer.server.luau` — on join: weekly reset + daily grant +
  `DailyReward` RemoteEvent; `Weekly` RemoteFunction (list/claim). NEW.
- `StarterPlayer/StarterPlayerScripts/UI/RetentionClient.local.luau` — daily popup + "WEEKLY" button/panel
  (progress bars + Claim). NEW.

**Game:**
- `ServerScriptService/RunServer.server.luau` — EDIT `endRun`: bump `profile.weekly` (finish/travel/zone).

## Verification (Studio)
- Analyzer-clean (both trees).
- Daily: fresh (lastLoginDay 0) join → grant day-1 (10) streak 1; seed "yesterday" → next grant streak 2
  (15); seed gap>2 → reset to 1; same-day rejoin → no double grant.
- Weekly: run end bumps finish/travel/zone; claim awards Gold+Score once; re-claim rejected; week rollover resets.
- Verify via attributes / profile reads / Client `InvokeServer`.

## Out of scope (P11 live-ops)
Daily-seeded runs, seasons/battle pass, cosmetic tokens; the camps/nights/revives objective variants
(need per-run counters not yet tracked).
