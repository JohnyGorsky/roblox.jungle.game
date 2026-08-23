# Final Summary — Job #105

**Project**: `roblox.jungle`
**Studio**: `Last River COOP Game`, PlaceId 138141472932347
**Status**: Implemented, verified in Play. Awaiting the user's *feel* judgement + commit.

Intake: [intake.md](intake.md) · Plan (with the full measurement log): [implementation-plan.md](implementation-plan.md)

## The report

> "Boat turret has limitations to rotate down. When we ride boat is little bit up, and you cant target
> enemies near boat. So we must add +30% rotation up and down for turret."

## What was actually wrong — three causes, not one

The player named the axis correctly and the *cause* was not the one they named. Three things stacked:

1. **The arc is measured against the boat, not the world.** `GunBase` is welded to the hull, and
   `BoatServer` deliberately trims the hull bow-up under throttle. Measured in Play: **+6.96° at full
   throttle** (the `MAX_PITCH = rad(7)` constant was honest). So the −12° down stop became **−5.04° of real
   depression** exactly when you're moving — which is when you need it.
2. **Elevation collapsed off-axis.** All four aim sites built `CFrame.Angles(pitch, yaw, 0)` = `Rx·Ry`, which
   applies pitch about the **un-yawed** X axis. Real elevation was `asin(cos(yaw)·sin(pitch))`, so the −12°
   stop was **−2.07° at yaw 80°**. At the edges of the ±80° traverse the gun had almost no elevation at all.
3. **🔴 The bow lamp filled the cone the gunner aims through.** A 2.76-stud-tall lamp skin at hull-local
   (0, 4.9, −14.5) — dead centre, ~5 studs from an eye that sat at +2. Its silhouette covered
   **−25.1°…+3.0°** of the view at the old −12° stop: **the crosshair was already on the lamp**, and
   depressing further buried it deeper (+9.3° at −22.6°).

**Cause 3 is why the requested change could not have worked alone.** Widening the arc without moving the eye
would have bought more depression and pointed the crosshair further into a lamp housing.

## What changed

Three files, four aim sites, three constants.

| file | change |
|---|---|
| [GunServer.server.luau:22](../../sync/ServerScriptService/Combat/GunServer.server.luau#L22) | `PITCH_MIN, PITCH_MAX` → `rad(-22.6), rad(45.5)` |
| [GunServer.server.luau:35](../../sync/ServerScriptService/Combat/GunServer.server.luau#L35) | `CAM_UP` `2` → `4` |
| [GunServer.server.luau:143](../../sync/ServerScriptService/Combat/GunServer.server.luau#L143) | `aimCFrame` → `Angles(0,yaw,0) * Angles(pitch,0,0)` |
| [GunClient.local.luau:17](../../sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau#L17) | same clamp pair |
| [GunClient.local.luau:27](../../sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau#L27) | same `CAM_UP` |
| [GunClient.local.luau:116,175](../../sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau#L116) | same composition, at **both** the camera and the tracer |
| [BoatTurretVisual.local.luau:75](../../sync/StarterPlayer/StarterPlayerScripts/Boat/BoatTurretVisual.local.luau#L75) | same composition, for the barrel mesh |

**Why −22.6° and not −15.6°.** The literal +30% is −15.6°; the hull trim eats 6.96° of it. −22.6° is the +30%
**plus** the trim, so the arc survives being under way. Up is the plain +30% (+45.5°) — bow-up trim *helps*
elevation, so it needs no headroom.

**Why `CAM_UP` moved.** It is the one lever that clears the lamp without touching the boat's art. It is
**both** the camera offset and the firing-ray origin, so it had to move in both files at once or the crosshair
would silently stop matching the bullet.

## Verified in Play (not in Edit)

| check | result |
|---|---|
| hull trim under throttle | 0.00° at rest → **peak +6.96°** |
| effective depression while riding | **−5.04° → −15.64°** |
| elevation across the traverse | **−22.60° at yaw 0/40/80/−80** (old form: −3.83° at ±80°) |
| max elevation at full yaw | **+45.50°** (old form: +7.11°) |
| server clamp still authoritative | sent −90° → accepted **−22.60°**; sent +90° → **+45.50°** |
| crosshair vs the bow lamp | **+8.17° clear** at −22.6° (was **−9.29°**, blocked); still +4.77° clear at −30° |
| steep shot not blocked by hull/water | `[Gun] hit Workspace.Terrain (Sand)` |
| client/server constants agree | read back from the **live** place, both sides identical |
| analyzer can actually fail | injected a type error → reported, exit 1; restored → exit 0 |

Before/after gunner-eye captures were taken from the same rig at the same pitch.

## Two constants that were wrong

Per GROUND-RULES §7 — recorded rather than propagated:

- **`WATER_Y = 12` is not the ride height.** It is the buoyancy spring *target*. The hull actually floats at
  **13.374** at rest and rises to **14.705** under throttle. Any blind-radius figure derived from the constant
  is ~1.4 studs optimistic.
- **`hull.CFrame:ToEulerAnglesXYZ()` is useless for attitude here** — it reports 180°/180° at rest, a
  degenerate decomposition of a yaw-180 orientation. Trim must be read from `LookVector.Y`.

## Known defect this job did NOT fix — finding 0026

**The barrel mesh passes through the bow at high depression, and it did so before this job too.** The skin
rides 4 studs forward of the pivot, so depressing swings it into the bow stem: at the **old** −12° stop its
centre was already 0.55 studs below the hull skin's top edge; at −22.6° it is 1.26 below. **Pre-existing,
~0.7 studs worse now.** Confirmed by an A/B from one external camera at 0° / −12° / −22.6°.

⚠️ **A raycast cannot detect it** — `Hull.Skin_hull` has `CanQuery = false`, so ray probes return a confident
false "clear". Two such results were discarded rather than reported. Likely fix, in the finding: restore the
`+1.2` Y pivot lift that `GunServer:91` builds the barrel with and `BoatTurretVisual:75` drops when re-posing.

## Also found, deliberately out of scope

- **finding 0024** — the Euler-order bug, fixed here as part of this job.
- **finding 0025** — the **±80° yaw arc cannot reach the flank point the sea AI steers to.**
  `EnemyServer:463-469` sends crocodiles to `FLANK_DIST = 12` studs *abeam* ("attack from the boat's SIDE"),
  which is ~124° off the bow, and `Crocodile.biteRange = 16`. So a croc biting the hull sits ~44° outside the
  traverse arc. **Elevation work does not touch this**, and it is a strong candidate for the *next* job on
  "can't hit things near the boat".

## Independent review (GROUND-RULES §8)

One agent, given only the player's verbatim quote and the repo — never my hypothesis. It independently found
the trim mechanism, then went past it and surfaced all three of causes 2, 3 and finding 0025, which I had not
looked at. It was not taken at face value: its lamp arithmetic used the lamp's *near*-top corner and concluded
"clear by 0.2°" at −12°; the correct highest-in-view corner gives **+3.0°, already blocked**. Its conclusion
was right and its number was wrong in the direction that made the bug look smaller. Re-derived, then confirmed
in Play. Its Euler claim was verified as algebra (`LookVector.Y = cos(yaw)·sin(pitch)`) before being believed.

## Open for the user

- **Feel**, which I can't decide: the same sensitivity now covers a 68.1° arc instead of 47°, and the eye sits
  4 studs above the mount rather than 2 (reads as standing at the gun rather than crouching behind it). `SENS`
  / `TOUCH_SENS` and `CAM_UP` are the dials.
- **Commit** — Claude never commits.
