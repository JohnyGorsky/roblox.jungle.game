# Final Summary — Job #017: Lobby place + launch-pad party + reserved teleport

**Project**: `roblox.jungle` (repo `roblox.jungle.game`)
**Completed (code)**: 2026-07-19
**Status**: ✅ Code-complete & lobby verified live in Studio. **Live teleport needs a published playtest**
(reserved-server teleport can't run in Studio) + the human publish/save steps below.

## What was implemented — the two-place front end (first P6 slice)

### Place structure (corrected during the job)
Roblox can't reassign the start place, so: **root place = LOBBY** ("Last River COOP", the ★ start place),
and a **new place = GAMEPLAY** ("Last River COOP Game", ID **138141472932347**). **One git repo**
(`roblox.jungle.game`), **two folders**, each with its own `default.project.json`:
- `sync/` → **Game** place (all existing gameplay).
- `lobby/sync/` → **Lobby** place (this job).

### Lobby (`lobby/sync/`)
- **`LobbyConfig`** — `GAMEPLAY_PLACE_ID = 138141472932347`, `PAD_COUNT = 3`, `MAX_PER_PAD = 6`,
  `COUNTDOWN = 3`.
- **`LobbyServer`** — server-authoritative:
  - Greybox **airfield** (ground/runway/hangar) + **SpawnLocation** + **3 launch pads**, each with a
    floating **BillboardGui sign**. (PLACEHOLDER art.)
  - **Pad-party system:** step on a pad → join (occupancy via a 0.3s overlap check, arrival-ordered);
    **first on the pad = leader (★)**; sign shows `N/6` + names + status; leader-only **Start** prompt;
    **leader leaves → next-longest becomes leader**; step off / leave game → removed.
  - **Start → 3s countdown → reserved teleport:** `ReserveServerAsync` + `TeleportAsync(padGroup, opts)`
    (pcall + 3× retry) with `SetTeleportData({ seed })` (a shared river seed; PUBLIC data only). Countdown
    cancels if the pad empties. If the place ID were 0 it logs a warning instead (kept for safety).
- **`LobbyClient`** — a short hint banner ("Step on a pad… first on a pad leads… hold Start").

### Gameplay side (`sync/`)
- **`RiverBootstrap` arrival-seed hook** — seed priority: `Workspace.RiverSeed` attribute > **lobby
  TeleportData seed** (read off the first arriving player, brief wait) > dev default `2026`. So a party
  shares one river, and each run's river can vary. Studio/direct-join → no teleport data → default.

## Verified (live in Studio, Lobby place)
- [x] Lobby scripts analyzer-clean (lobby sourcemap); `RiverBootstrap` edit analyzer-clean.
- [x] Airfield + 3 pads + spawn build at runtime; **leftover gameplay + baked terrain/water cleared**
      (the airfield was submerged until the terrain was cleared).
- [x] Stepping on a pad updates its sign (`1/6`, ★ leader) and enables the leader's Start prompt.
- [x] Player stands on the dry airfield (was swimming before the terrain clear).
- [~] **Start → countdown → teleport** and **leader handoff with a 2nd player** — the prompt-hold and the
      reserved teleport **can't be driven in Studio** (teleport is unsupported in Studio; prompt-hold not
      injectable headless). Verified by construction + occupancy/leader/sign logic. **Needs a live playtest.**

## Files
- **New (Lobby place):** `lobby/default.project.json`, `lobby/sync/ReplicatedStorage/LobbyConfig.luau`,
  `lobby/sync/ServerScriptService/LobbyServer.server.luau`,
  `lobby/sync/StarterPlayer/StarterPlayerScripts/LobbyClient.local.luau`.
- **Edited (Game place):** `sync/ServerScriptService/River/RiverBootstrap.server.luau` (arrival-seed hook).
- New: `Jobs/017/*`.

## Human steps to finish (I can't do these)
1. **Save/publish the Lobby place** so the **cleared terrain persists** (I cleared it in the Edit session;
   without a save the baked water returns).
2. **Publish both places** (Lobby + Game) so teleport works live.
3. **Live playtest:** join the experience (lands in the Lobby) → step on a pad → hold Start → confirm the
   party teleports **together** into a reserved Game server and arrives at the crash-site staging with a
   shared river.

## Notes / follow-ups (deferred)
- **Not committed.**
- Shop / skills / boat-upgrades (P8 economy) — leave space in the lobby.
- Random fill / matchmaking queue (MemoryStore), friends-invite (`SocialService`), rejoin-same-instance,
  return-to-lobby after a run.
- All lobby art/sound (P9); hand-built departure hangar replaces the greybox.
- `reel-boat-at-every-pier` (separate Planned item) still open.
