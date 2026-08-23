# Job #111 — Changelog

## Added
- `EndZone/EscapeServer.server.luau` — extraction pad, crew occupancy, invincibility, and the run win.
- `Components.PanelOptions.dismissable` (defaults `true`) for terminal panels.
- `Workspace.EscapeReached` — the server-authoritative win signal.
- `ASSETS.md` §3.7 — the end-zone airfield, all reused lobby assets.

## Changed
- **The run is won by extraction, not distance.** `RunServer` reads `EscapeReached`; the lose arms are unchanged.
- A winning run credits the full river length, whatever the boat's final position.
- The results screen can no longer be dismissed — RETURN TO LOBBY is the only exit.
- The INVULNERABLE chip hides once the run has ended.

## Removed
- `RiverBootstrap.placeEnd()` and the gold Neon `FinishLine` bar.
- `RunServer.DEV_WIN_DISTANCE` (it would now inflate the reward instead of ending the run).
