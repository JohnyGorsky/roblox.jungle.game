# Final Summary — Job #018: Run ending (win/lose) + results + reward + return to lobby

**Project**: `roblox.jungle` (repo `roblox.jungle.game`)
**Completed**: 2026-07-19
**Status**: ✅ Built, analyzer-clean, win/lose/reward/permadeath verified live in Studio. **Return-to-lobby
teleport is live-only** (Studio can't teleport) — verified by construction.

## What was implemented — closes the POC loop (lobby → run → END → results → lobby)

### `RunServer.server.luau` (new, ServerScriptService) — run lifecycle
- **Permadeath during a run:** `Players.CharacterAutoLoads = false` + manual `LoadCharacterAsync` on join.
  A character's `Died` while `RunStarted` → the player is marked **`Dead`** (no respawn) and their body is
  cleared (→ spectate). Pre-start deaths just reload (edge). Revive-by-teammate still works during the
  downed window (PlayerCombat unchanged).
- **End monitor** (once `RunStarted`, fires once):
  - **WIN** — `BoatDistance >= RiverEndDistance` (`DEV_WIN_DISTANCE` can override for testing).
  - **LOSE** — `BoatDestroyed`, **or** all players `Dead` (crew wipe).
- **On end:** sets `Workspace.RunEnded` + `RunResult`; computes `distance` (BoatDistance),
  `reward = floor(distance / REWARD_DIV)`, survivors; fires **`RunEnded`** to all clients.
- **Return to lobby:** `ReturnToLobby` RemoteEvent (button) **+** auto `task.delay(RETURN_TIMEOUT=30s)` —
  whichever first → `TeleportAsync(LOBBY_PLACE_ID = 114309626266505, allPlayers)` (pcall + 3× retry).

### `RunClient.local.luau` (new, StarterPlayerScripts/UI)
- **Spectate:** while the run is on and the local player has no living character, the camera follows the
  boat and a "You died — spectating" tag shows.
- **Results panel:** on `RunEnded` — **WIN**/**LOSE** headline, **distance**, **survivors**, **reward**, a
  **Return to Lobby** button (fires `ReturnToLobby`) + an auto-return **countdown**. Greybox styling.

### `PlayerCombat.server.luau` (edit)
- Bleed-out comment updated: `hum.Health = 0` is now **permadeath during a run** (RunServer disables
  respawn). No functional change.

## Verified (live in Studio, Game place)
- [x] Analyzer clean (all three files).
- [x] `CharacterAutoLoads = false` on play (permadeath policy active).
- [x] **WIN:** forcing the win distance → `RunEnded`, `RunResult="win"`, results screen "🏆 YOU REACHED THE
      END!", distance 40, survivors 1, **+4 reward** (40÷10), Return button + countdown (screenshot).
- [x] **LOSE (wipe):** killed the solo player → `Dead=true`, **no respawn**, results "☠ THE CREW WAS LOST",
      survivors 0, +4 reward, Return button + countdown (screenshot). Spectate camera followed the boat.
- [x] Reward = distance-based (display-only).
- [~] **Return-to-lobby teleport** — Studio can't teleport; the auto/button path is verified by
      construction (same pattern as the lobby's launch teleport). **Needs a live playtest.**
- [~] **Boat-destroyed LOSE** — wired identically (reads `BoatDestroyed`); quick live check worthwhile.

## Files
- **New:** `sync/ServerScriptService/RunServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/RunClient.local.luau`.
- **Edit:** `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (permadeath comment).
- New: `Jobs/018/*`.

## Human steps to finish
1. **Sync `sync/` + publish the Game place** (RunServer/RunClient are new).
2. **Live test the full loop:** lobby → pad → Start → teleport to run → **win or wipe** → results → **Return
   to Lobby** teleports the party back. Confirm the return teleport (the one thing not testable in Studio).

## Notes / follow-ups (deferred)
- **Not committed.**
- Reward **persistence** + spending (P8 economy / DataStore); scoring & leaderboards (P7).
- Real win distance is `END_DISTANCE` (18000 ≈ long run) — `DEV_WIN_DISTANCE` exists for testing; tune the
  real length later. `REWARD_DIV` tuning.
- Spectate polish (free-fly / cycle teammates), results art/sound (P9).

## POC status
With this, the **core POC loop is complete**: team up in the lobby → launch → survive the river → **win or
die** → results + reward → back to the lobby to go again. Remaining game work (economy/skills, more content,
all art/sound) is expansion/polish beyond the POC.
