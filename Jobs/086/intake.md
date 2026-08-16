# Job #086: Playtest fixes batch (enemies, boat attachments, HUD)

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:11:55
**Status**: Requirements Gathering (intake) — batch open, more items expected

## Requirements / goal

Collector job for the playtest issues reported on 2026-08-16. Each item is logged in `todo/` first
with a verified root cause, then pulled into this job's implementation plan once the batch is closed.

**Do not start implementing until the user says the batch is closed and the plan is agreed.**

Boat ride quality (the vibration / clumsy feel) is deliberately **not** here — it is its own
understand-first investigation, **Job #087**.

## Items

### 1 — Wolves swim in open water; they should hold land / bases (`todo/0046`)

Land enemies are not land-bound: `stepToward()` builds every move as `Vector3.new(x, WATER_Y, z)` for
both categories ([EnemyServer.server.luau:184]), and the land spawner anchors them only 8–20 studs
past the bank while `LAND_LEASH = 65` — so they glide ~45 studs into the channel at water height.

Two separable parts:
- **(a)** land creatures must follow ground height and never enter water;
- **(b)** per user direction, wolves belong at camps/bases rather than the free bank pool. `Bandit`
  is the existing precedent: excluded from `LAND_POOL`, spawned by `ExcursionServer` as a `CampGuard`.

### 2 — Turret + searchlight lag behind the boat while riding (`todo/0047`)

The barrel is `Anchored` and its CFrame is written server-side every Heartbeat, so it replicates as
discrete steps while the hull replicates as an interpolated physics assembly — they visibly drift
apart in motion and snap together at rest. The searchlight sweeps from the same server-side path.

⚠️ **Shares a root with Job #087.** If #087 changes how the boat replicates, this item's fix may
change with it — sequence #087's decision first, or pick a fix that survives either outcome.

### 3 — Drop hint text overlaps the health bar (`todo/0048`)

`dropHint` is positioned at `UDim2.fromScale(0.5, 1.05)` below the HANDS FULL card
([InventoryHud.local.luau:124]), which is exactly where the health row sits. Must stay
mobile-first / scale-based.

### 4 — A tied boat is not safe (`todo/0049`)

The tied-dock safe zone exists only in the wildlife director; the string `Tied` does not appear in
`ExcursionServer.server.luau` at all, so camp guards bite the player regardless
([ExcursionServer.server.luau:1475]). The boat-damage half still needs confirming in a playtest
(`ObstacleServer.server.luau:51` has no tie check either).

**Needs a design decision, not a guess:** is a tied boat safe from *everything*, or from the river
only? Job #084's changelog promises "Docks are a genuine safe zone", but camps are meant to be
dangerous and the trading post sits between the shore and the near camp.

## Resolved during intake

- The second shape the user circled at the bow was **not** an enemy — it was the turret and light
  detaching in motion. That is item 2.

## Checklist

- [x] Batch closed by the user (4 items; boat ride quality split out to Job #087)
- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed (analyzer clean, sync verified 11/11 in Studio)
- [x] Final summary + changelog written

**Status: ✅ CLOSED 2026-08-16.** Not committed. Playtest verification still listed in final-summary.md.
