# Final Summary — Job #026: Leaderboards + River Score rank + lobby overhead tag

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §7–§8.
Depends on #021 (profile) + #022 (run stats).

## What was built
A lifetime **River Score** rank (server-authoritative), a lobby **overhead rank tag**, and **global
leaderboards**.

### River Score (earned at run end, GAME)
POC subset of the Job 020 §8 formula (the terms we have reliable data for):
`runScore = floor(distance/100) + zonesReached*50 + (finished ? 300 : 0)`, accumulated into
`profile.riverScore` (never decreases). A full win ≈ 680; a forced no-distance win = 300 (finish bonus).

### Files
- **New (both trees):** `ReplicatedStorage/Progression/RankDefs.luau` — 10-tier ladder (Castaway → River
  Legend) with colours, `tierFor(score)`, `legendStars`, `shortScore`, board names.
- **Edit (both trees):** `ServerScriptService/Progression/Profiles.luau` — `_publish` now also sets the
  `RiverScore` player attribute; added `getRiverScore` / `addRiverScore`.
- **Edit (game):** `RunServer.server.luau` — at run end: `addRiverScore(runScore)` per crew member + writes
  the two **OrderedDataStores** (`Board_RiverScore_v1`, `Board_BestDistance_v1`, integer, pcall, spawned).
- **New (lobby):** `ServerScriptService/Progression/RankServer.server.luau` — overhead `BillboardGui` on
  each head (tier name in tier colour + `name · score`, updates on the `RiverScore` attribute) + a physical
  **leaderboard board** (`SurfaceGui`, global Top-10 by River Score via `GetSortedAsync(false,10)` +
  `GetNameFromUserIdAsync`, refreshed every 30s).

## Verified (live in Studio)
- [x] Analyzer-clean (both trees).
- [x] **Earning:** WIN → `RiverScore 0 → 300`, tier Castaway; the **OrderedDataStore board was written
      (=300)** by the real run.
- [x] **Overhead tag (lobby):** setting a score → tag shows **"Rapids Runner" (cyan) / "johnygorsky10 ·
      20.0k"** above the head, outlined, live-updating on the attribute (screenshot).
- [x] **Board (lobby):** renders "TOP RIVER LEGENDS" + the top entry with tier (screenshot).

## Notes / follow-ups
- **Not committed.** Test account reset to a clean baseline (score 0, boards cleared).
- **Board placement nit:** it currently sits behind the launch pads, so the pads' AlwaysOnTop "N/6" signs
  overlap it from some angles. Works fine; reposition to a clear wall in a polish pass.
- River Score currently uses distance + depth + finish only. The kills/camps/nights/revives/objectives/
  daily terms (Job 020 §8) need per-run counters — deferred (#028 + P11). Hook point: `runScore` in
  `endRun`.
- **Friends / daily-seeded / weekly / season** boards deferred to P11 live-ops.
- Overhead tag is **lobby-only** (in-run keeps minimal nameplates, per §8.2).
- Testing note: I earlier confused the active Studio (lobby vs game) — the lobby has no `RunServer`, so the
  "win" force did nothing there. Verified earning in the game, display in the lobby. (No dev River-Score
  granter yet — can add one like DevGrant if we want to test high tiers without grinding.)
- Next: **#023** (in-run Salvage + dock shop) or **#024** (skill tree — pending your skill-list review).
