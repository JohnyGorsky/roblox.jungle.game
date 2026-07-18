# Implementation Plan — Job #018: Run ending (win/lose) + results + reward + return to lobby

**Project**: `roblox.jungle` (repo `roblox.jungle.game`)
**Created**: 2026-07-19
**Status**: Planning (awaiting go-ahead)

Closes the POC loop: **lobby → run → END → results → back to lobby.**

## Decisions locked (via wizard, 2026-07-19)
- **Win:** boat reaches the river end (`RiverData.END_DISTANCE`).
- **Lose:** **crew wipe** (all players dead) **OR boat destroyed**.
- **Death model:** during a run, bleed-out (not revived) = **dead for the run — no respawn**; the dead player
  **spectates** (free/teammate cam) until the run ends. Revive-by-teammate still works during the downed window.
- **Reward:** scales with **distance travelled** (even a mid-run death pays out). **Display-only** now
  (no persistence; real meta-currency + spending is the P8 economy).
- **Return to lobby:** a **"Return to Lobby" button** on results **+ auto-return** after a timeout.

## Existing hooks (confirmed)
- `Workspace.BoatDistance` (published each tick by RiverBootstrap) + `Workspace.RiverEndDistance` (=END_DISTANCE).
- `Workspace.BoatDestroyed` (BoatServer sets true at hull HP≤0).
- `Workspace.RunStarted` (StagingServer, #016).
- `PlayerCombat`: downed → `BLEEDOUT` timer → `hum.Health = 0` (currently auto-respawns).
- Lobby place id for return = **114309626266505**.

## Plan (server-authoritative; runs on the reserved Game server)

### 1. `RunServer.server.luau` (new, ServerScriptService) — run lifecycle
- **Permadeath policy:** `Players.CharacterAutoLoads = false`; `LoadCharacter()` on join (so players still
  spawn; PlayerCombat's `CharacterAdded` places them). On a character's `Died`:
  - if **not** `RunStarted` → reload (edge: pre-start staging death), else
  - mark the player **`Dead = true`** (no reload → out for the run) and re-check the wipe.
- **End monitor** (once `RunStarted`, fires once): 
  - **WIN** when `BoatDistance >= RiverEndDistance`.
  - **LOSE** when `BoatDestroyed` **or** every player is `Dead`.
- **On end:** set `Workspace.RunEnded=true` + `RunResult` ("win"/"lose"); compute `distance` (BoatDistance)
  + `reward = floor(distance / REWARD_DIV)` + survivor count; fire **`RunEnded`** RemoteEvent to all with
  `{won, distance, reward, survivors}`. Stop threats (belt-and-braces: gate already checks RunStarted).
- **Return to lobby:** a **`ReturnToLobby`** RemoteEvent (button) + an auto `task.delay(RETURN_TIMEOUT)` —
  whichever first → `TeleportAsync(LOBBY_PLACE_ID, allPlayers)` (pcall + retry). Fires once.

### 2. `PlayerCombat.server.luau` (edit) — bleed-out becomes permanent in a run
- Keep downed/revive as-is. Bleed-out still `hum.Health = 0`; with auto-loads off (RunServer) that is now
  **permanent**. No other change needed (RunServer's `Died` handler marks `Dead` + checks wipe).

### 3. `RunClient.local.luau` (new, StarterPlayerScripts/UI) — spectate + results
- **Spectate:** while `RunStarted` and the local player has **no character** (died), set the camera to
  spectate (follow the Boat, or cycle alive teammates) + a "You died — spectating" tag. Restore on results.
- **Results panel:** on `RunEnded`, show **WIN/LOSE**, **distance** (studs → e.g. "1,240 m"), **survivors**,
  **reward earned**, a **Return to Lobby** button (fires `ReturnToLobby`) and a **countdown** to auto-return.
  Greybox styling (P9 for real design).

### 4. Config — constants in RunServer (or a small `RunConfig`)
- `LOBBY_PLACE_ID = 114309626266505`, `REWARD_DIV` (distance→reward), `RETURN_TIMEOUT` (~30s),
  `DEV_WIN_DISTANCE` (optional low override to test WIN without a full 18k run; default `END_DISTANCE`).

## Files
- **New:** `sync/ServerScriptService/RunServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/RunClient.local.luau`.
- **Edit:** `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (minor — permadeath comment/hook).
- New: `Jobs/018/*`.

## Verification (luau-analyze + live Studio MCP, Game place)
- Analyzer clean.
- Start a run (untie). Drive.
- **Lose (wipe):** take damage → down → bleed out → **no respawn**, spectate; solo death → results **LOSE**
  with distance + reward; **Return to Lobby** button + auto-return countdown appear.
- **Lose (boat):** set boat HP 0 → `BoatDestroyed` → results **LOSE**.
- **Win:** with `DEV_WIN_DISTANCE` low, drive past it → results **WIN**.
- **Reward** = distance-based, shown on results.
- **Return teleport** is **live-only** (Studio can't teleport) — verified by construction + it logs/attempts.

## Out of scope / deferred
- Reward **persistence** + spending (P8 economy / DataStore). Scoring/leaderboards (P7).
- Fancy spectate (kill-cam, free-fly polish); results art/sound (P9).
- Rejoin / mid-run join handling.
