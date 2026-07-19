# Job #021 — Implementation plan: Persistence foundation

**Project**: `roblox.jungle` · POC · Design source: Job #020 §1, §7 · Skill: `roblox-data`.

## Goal
A safe, session-locked player profile (Gold + lifetime stats) that persists across the **lobby ↔ game**
teleport, with the full save trio and a minimal Gold readout. Everything downstream (#022–#028) builds on it.

## Key facts driving the design
- **Two places, one experience** → DataStore is experience-wide; a `userId`-keyed profile is shared across
  both. **Session locking** handles the teleport handoff (lobby releases → game acquires).
- **Lobby project maps no `ServerStorage`** → shared server code lives under `ServerScriptService`.
- **Studio without API access** must not hard-crash → load falls back to an in-memory profile (flagged,
  never saved) so the POC still runs; real persistence verified on the published Game place (has API).

## Files (identical copies in `sync/` and `lobby/sync/` — same experience, kept byte-identical via copy)
1. `ReplicatedStorage/Progression/ProfileConfig.luau` — shared constants, `default()` profile,
   `migrate()` (dataVersion + forward-compatible field fill). Client-safe.
2. `ServerScriptService/Progression/Profiles.luau` — the service (ModuleScript). Session-locked
   `UpdateAsync` transact (`load`/`beat`/`release`), in-memory cache, API: `load/save/unload/get/
   isReady/getGold/addGold/trySpendGold`. Mirrors Gold → `player:SetAttribute("Gold")` + leaderstats.
3. `ServerScriptService/Progression/ProfileServer.server.luau` — the save trio: `PlayerAdded` (leaderstats
   + load) → autosave loop (heartbeat) → `PlayerRemoving` (release) → `BindToClose` (parallel save).
   Exposes `_G.LR_Profiles` for command-bar dev testing.
4. `StarterPlayer/StarterPlayerScripts/UI/GoldHud.local.luau` — minimal Gold pill (reads the `Gold`
   attribute). In both places so Gold shows in lobby *and* run.

## Session-lock model (simplified ProfileStore)
Lock stored as `__lock = {session=GUID, heartbeat=os.time()}` inside the value; all access via
`UpdateAsync` (no yields in transform). `load` steals only if `heartbeat` older than `LOCK_STALE_SECONDS`
(90s), else retries with backoff; `beat`/`release` abort if the lock was stolen (never clobber a live owner).

## Verification
- `luau-analyze` clean (both trees).
- In the Game place (API access): `_G.LR_Profiles.addGold(plr, 100)` → Gold pill + leaderstats update →
  rejoin → Gold persists. Then teleport lobby→game and confirm the same balance carries across.
- Confirm no double-lock error on teleport (lobby release → game load).

## Out of scope (later jobs)
Crediting Gold from runs (#022), spending it (#023/#024/#025), River Score/boards (#026), purchases (#027).
