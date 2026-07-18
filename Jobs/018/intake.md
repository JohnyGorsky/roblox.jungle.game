# Job #018: Run ending: win/lose + results + reward + return to lobby

**Project**: `roblox.jungle`
**Created**: 2026-07-19 00:45:18
**Status**: Requirements Gathering (intake)

## Requirements / goal

Close the POC loop (P5/P7 slice). END CONDITIONS: (WIN) boat reaches RiverData.END_DISTANCE; (LOSE) the whole crew is wiped — during a run, bleed-out = permanent death (NO respawn; spectate), and when all players are dead the run ends; boat destroyed also ends the run. On end: a RESULTS screen (win/lose, distance reached, survivors, REWARD earned). REWARD scales with distance travelled, so even a mid-run death pays out (meta-currency hook; persistence TBD). Then RETURN TO LOBBY: teleport the party back to the lobby place (114309626266505). Runs on the reserved Game server. Server-authoritative. Greybox results UI (real design P9). Decided with user 2026-07-19.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed — win/lose/reward/permadeath/spectate verified live in Studio; return-to-lobby
      teleport is live-only (needs a published playtest)
- [x] Final summary + changelog written
