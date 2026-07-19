# Final Summary — Job #036: River obstacles that slow + damage the boat

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0004. Game-only.

## What was built
The "obstacle" river hooks (previously do-nothing red placeholder cubes) are now **real obstacles** the
driver must weave around — on contact they **cut the boat's speed** and **damage the hull**, scaled by type.

| Obstacle | Slow (velocity cut) | Damage | Feel |
|---|---:|---:|---|
| Rock | 85% | 25 | near-stop, big hit |
| Log / deadwood | 50% | 12 | medium both |
| Sandbar | 70% | 4 | big slow, little damage |

- **Non-colliding triggers** (a collidable rock would blow up the boat assembly) — the hit applies
  `AssemblyLinearVelocity *= (1 − slow)` + hull damage, then the obstacle is destroyed (plowed through).
- **Streamed** with the river chunks (RiverBootstrap) on the existing `RiverData` obstacle hooks; type is
  deterministic per z. Hits are **skipped while the boat is tied** (safe at docks).

### Files
- **Edit:** `River/RiverBootstrap.server.luau` — builds real obstacles (rock/log/sandbar, tagged "Obstacle"
  with Slow/Damage attrs) on obstacle hooks instead of the red marker; ramp hooks stay greybox markers.
- **New:** `World/ObstacleServer.server.luau` — per-Heartbeat boat↔obstacle overlap → slow + damage + flash
  + destroy.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Obstacle variety streams (Rock/Log seen; Sandbar in the type set).
- [x] Contact → **Rock: boat HP 100→75 (−25) + obstacle destroyed**; cumulative hits drove **BOAT 0%** →
      destroyed → run lost (extra proof of damage).
- [x] Tied boat → hits skipped (verified: first attempt correctly no-op'd while moored).
- [~] The velocity cut is construction-verified (anchored test hull reports 0 velocity); code is a trivial
      `*= (1-slow)`.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Greybox shapes; real rock/log/sandbar art in the design pass.
- Density = the existing hook spacing (~220 studs, ~2:1 obstacle:ramp). Tune per-zone later if needed.
- Pairs well with the night set-piece (#035) and the queued Lights/Glowing-eyes todos (dodging in the dark).
