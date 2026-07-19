# Final Summary — Job #021: Persistence foundation (player profile + Gold)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020
§1/§7 · Skill: `roblox-data`.

## What was built
A safe, session-locked player profile that persists across the **lobby ↔ game** teleport (DataStore is
experience-wide; a `userId`-keyed profile is shared by both places). Foundational — #022–#028 build on it.

### Files (identical copies in `sync/` and `lobby/sync/` — one experience, one DataStore)
- **`ReplicatedStorage/Progression/ProfileConfig.luau`** — shared schema: `default()` profile
  (gold, riverScore, stats per Job 020 §7.1), `migrate()` (dataVersion + forward-compatible field fill),
  store name/lock/autosave constants. Client-safe.
- **`ServerScriptService/Progression/Profiles.luau`** — the service. Session lock stored as
  `__lock = {session, heartbeat}` inside the value; **all access via `UpdateAsync`** (transform never
  yields). `load` steals a lock only if older than `LOCK_STALE_SECONDS` (90s) else retries with backoff;
  `beat`/`release` never clobber a live owner. `load` is **idempotent** (guards the double
  PlayerAdded/catch-up call). Mirrors gold → `player:SetAttribute("Gold")` + leaderstats. API:
  `load/save/unload/isReady/get/getGold/addGold/trySpendGold`.
- **`ServerScriptService/Progression/ProfileServer.server.luau`** — the save trio: PlayerAdded
  (leaderstats + load) → autosave heartbeat (60s) → PlayerRemoving (release) → `BindToClose` (parallel
  save in the shutdown window). Exposes `_G.LR_Profiles` for command-bar dev testing.
- **`StarterPlayer/StarterPlayerScripts/UI/GoldHud.local.luau`** — minimal Gold pill (reads the `Gold`
  attribute); shows in lobby *and* run. Mobile-safe (scale + aspect + text-size cap).

## Verified (live in Studio, Game place — has DataStore API)
- [x] Analyzer clean (both trees).
- [x] **Full persistence cycle:** fresh load (gold 0) → `addGold(100)` → `save(release)` → reload →
      **gold=100 persisted**; session lock acquired, released, and re-acquired cleanly.
- [x] Gold mirrored to the `Gold` attribute (=100) and **GoldHud renders "GOLD 100"** (screenshot).
- [x] Clean shutdown via stop (PlayerRemoving/BindToClose release path runs).
- [x] Fixed a real bug found in test: a player present at server start triggered **double-load**
      (PlayerAdded + catch-up loop), the 2nd load saw the 1st's fresh lock as foreign and spun forever →
      `load` is now idempotent.

## Notes / follow-ups
- **Not committed.** Test account (`Player_5025640608`) reset to a clean baseline after testing.
- **Lobby side verified by construction** (byte-identical scripts, same DataStore) — a live 2-place
  **teleport handoff** test (lobby release → game load) is worth doing on the published places to confirm
  the release completes before the game load (else up to ~31s of load retries, then a 90s in-memory
  fallback until the stale lock clears — standard ProfileStore trade-off; fine for POC).
- **Studio without API access** falls back to a non-saved in-memory profile (warns) so the POC still runs.
- Ready for **#022** (credit real Gold from runs via `Profiles.addGold`) and the spend jobs
  (`trySpendGold`). Consider swapping this simplified service for community **ProfileStore** before launch
  (real money) — API is compatible.
