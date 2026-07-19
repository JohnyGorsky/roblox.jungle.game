# Job #026 — Implementation plan: Leaderboards + River Score rank + overhead tag

**Project**: `roblox.jungle` · POC · Design source: Job #020 §7–§8 · Depends on #021 (profile) + #022 (run stats).
Skill: `roblox-data` (OrderedDataStore, integer values, `GetSortedAsync` ≤100, `pcall`+retry).

## Goal
A **lifetime, non-decaying "River Score"** that drives a 10-tier rank, shown on an **overhead tag in the
lobby**, plus **global leaderboards** (River Score + best distance).

## River Score (server-authoritative, computed at run end in the GAME)
POC subset of the Job 020 §8 formula — the terms we already have reliable data for:
```
runScore = floor(distance/100) + zonesReached*50 + (finished ? 300 : 0)
riverScore += runScore        -- never decreases
```
(kills / camps / nights / revives / objectives / daily terms are deferred until those per-run counters
exist — hook points noted.) A full win ≈ 180 + 200 + 300 = **680**; a mid-run loss ≈ ~190.

## Rank ladder (Job 020 §8.1)
Castaway 0 · Drifter 500 · Rafter 1.5k · Riverhand 4k · Navigator 9k · Rapids Runner 18k · Whitewater 35k ·
Riverboat Captain 65k · Delta Master 120k · River Legend 220k (+ Legend ★ every +100k). Each tier has a colour.

## Files
**Both trees:**
- `ReplicatedStorage/Progression/RankDefs.luau` — tier ladder + `tierFor(score)` + board names. NEW.
- `ServerScriptService/Progression/Profiles.luau` — `_publish` also sets the `RiverScore` player attribute;
  add `addRiverScore` / `getRiverScore`. EDIT.

**Game:**
- `ServerScriptService/RunServer.server.luau` — at run end, `runScore` → `addRiverScore`, and write the
  two **OrderedDataStores** (`Board_RiverScore_v1`, `Board_BestDistance_v1`) per player (pcall, spawned). EDIT.

**Lobby:**
- `ServerScriptService/Progression/RankServer.server.luau` — NEW:
  - **Overhead tag:** a `BillboardGui` on each player's Head (server-built → everyone sees it): tier name
    in tier colour + River Score. Updates on spawn + `RiverScore` attribute change. Lobby only.
  - **Leaderboard board:** a `SurfaceGui` on a lobby signpost = global Top 10 by River Score
    (`GetSortedAsync(false,10)` + `GetNameFromUserIdAsync`), refreshed on a throttled loop.

## Verification (Studio)
- Analyzer-clean (both trees).
- Finish/lose runs in the game → `riverScore` grows by the formula; persists (profile + attribute).
- OrderedDataStore receives the score (read back top-N).
- Lobby: overhead tag shows the right tier/colour for a seeded score; board lists top players.
- (Verify via shared Instances / DataStore + Client-context `InvokeServer` per `roblox-studio` notes.)

## Out of scope (later)
Friends/daily/weekly/seasonal boards + the kills/camps/nights/revives/objectives/daily score terms
(#028 + P11 live-ops); prestige-star art. Overhead tag is lobby-only (in-run keeps minimal nameplates).
