# Final Summary — Job #035: Zones + day/night stakes

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · GAME.md P5. Game-only.

## What was built
Player-facing **zone progression** + a **day/night set-piece**, layered on the existing distance/time-of-day
threat scaling (which already ramps continuously).

### Zones
- 4 zones (by distance): **Headwaters → Croc Country → The Rapids → Lost Delta**. Crossing into a new zone
  sets `Workspace.Zone` and fires a center-screen banner. (Reward + threat already scale with distance/zone.)

### Day/night set-piece
- On the run's phase flip, a banner announces it: **NIGHTFALL** ("the water turns deadly — reach a dock and
  hold out!") / **DAWN**. The night **sea surge is now +3** concurrent threats (was +2). A **tied boat is
  safe** from bites (existing), so the loop is: reach a dock before dark and hold out (or push through — the
  Searchlight module helps).

### Files
- **New:** `World/ZoneServer.server.luau` — watches `BoatDistance` (zone crossings) + `Phase` (day/night);
  broadcasts an `Announce` RemoteEvent.
- **New:** `StarterPlayer/StarterPlayerScripts/UI/ZoneBanner.local.luau` — center banner (title/subtitle/
  colour), tween in → hold → fade.
- **Edit:** `Enemies/EnemyServer.server.luau` — night sea-cap surge +2 → **+3**.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Parked at 5200 studs (~29%) → `Workspace.Zone = 2` (crossing detected).
- [x] `Announce` fired + the client received it (banner titleText became "NIGHTFALL", ran its show→fade).
      Note: the ~3s banner couldn't be caught in a screenshot (MCP capture latency > the visible window),
      but the client received + processed + faded it — confirmed via the label state.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Zone names/threat are greybox flavor; per-zone hero set-pieces (waterfalls, rapids) are later content.
- **This completes the "deepen the core run" set: #033 (enemies), #034 (roles), #035 (zones/night).**
- Rich follow-ups already queued as todos: obstacles (0004), lights (0005), loading screens (0006/0007),
  glowing eyes (0008).
