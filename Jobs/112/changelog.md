# Job #112 — Changelog

## Added
- Admin panel: **GOD MODE — CHARACTER**, **GOD MODE — BOAT**, **INFINITE FUEL** toggles.
- `Admin` remote actions `cheat` (set) and `cheats` (read back), both allowlist-gated.
- `AdminAction.toggle` — a third action shape in `AdminClient` that reads its label from server state.

## Changed
- `BoatServer` honours `AdminGodBoat` in its HP-changed handler and `AdminInfiniteFuel` at the top of its
  Heartbeat, above every early return.
- `DownedHud` hides the INVULNERABLE chip while `AdminGod` is set.
