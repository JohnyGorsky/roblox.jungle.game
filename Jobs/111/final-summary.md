# Job #111 — Final summary

**Project**: `roblox.jungle` · **Status**: COMPLETE — implemented & verified in Play

## What changed

The run now ends because the crew is **extracted**, not because a number crossed a threshold.

- The gold Neon `FinishLine` bar is gone, along with `RiverBootstrap.placeEnd()`.
- `RunServer` wins on `Workspace.EscapeReached` instead of `BoatDistance >= END_DISTANCE`.
- A new `EndZone/EscapeServer.server.luau` builds a gold extraction pad on the editor-placed marker
  `Workspace.EndBase.Objects.Plane.Escape` and owns the win.
- Standing on the pad makes a player invincible. Every living crew member aboard extracts immediately;
  a majority aboard can hold a prompt to leave the stragglers.
- The existing results screen is untouched — except that it can no longer be dismissed.

## Files

`+` `sync/ServerScriptService/EndZone/EscapeServer.server.luau`
`~` `sync/ServerScriptService/River/RiverBootstrap.server.luau`
`~` `sync/ServerScriptService/RunServer.server.luau`
`~` `sync/ReplicatedStorage/UI/Components.luau`
`~` `sync/StarterPlayer/StarterPlayerScripts/UI/RunClient.local.luau`
`~` `sync/StarterPlayer/StarterPlayerScripts/UI/DownedHud.local.luau`
`~` `ASSETS.md` (new §3.7)

## Five bugs found and fixed on the way

1. A winning extraction filed `distance=17867 zone=3` — 50 River Score short, and it failed the weekly
   *"Reach Zone 4 in a run"* objective the same run had just earned. A win now credits the full river.
2. The results screen had the standard X and tap-outside-to-close, so a player could shut it and wander
   a finished world until the auto-teleport. `Components.PanelOptions.dismissable` added.
3. The pad's ground probe filtered to `Workspace.Terrain`, but the marker sits on the RunWay slab three
   studs above it — the pad built itself into the concrete.
4. The billboard wrapped "EXTRACTING…" onto two lines at 11 studs, then filled the screen at 24. Fixed
   with 18 studs plus a `MaxTextSize` cap.
5. The first pad put its walking surface 2.4 studs up, right at a Humanoid's step limit.

## Verified in Play

Negative control (run live, player 18,600 studs away, 8 s) → nothing fires, sign reads `0/1 aboard`.
Positive → invincibility and `EscapeReached` at 0.22 s, `RunEnded` at 0.45 s, `RunResult = win`, player
alive; console `[Run] ENDED — WIN | distance=18000 (boat at 0) zone=4 gold=+10 survivors=1`. Results
panel Close hidden and inert. No stray INVULNERABLE chip. Pad base flush with the runway at 21.11.
`luau-analyze` clean on all six files, canary-tested.

## Not verified — needs 2+ players

`PAD_GRACE` "protected while waiting" and the majority hold-to-launch prompt are both unreachable solo
(`1/1 aboard` extracts instantly; `canForce` requires `total > 1`). A 2-player Local Server test covers
both.

## Follow-ups

- The end-zone camp is a rotated copy of the crash site and reads as the same camp twice.
- Nothing stops the boat on `RunEnded`; it no longer matters (the basin has ground) but it is still true.
- `BoatDestroyed` remains an instant lose — including while the crew is already ashore walking to the plane.
- Findings 0027 (snow on tropical hills) and 0028 (start-junction notch) are open.
