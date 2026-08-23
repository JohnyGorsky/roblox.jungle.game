# Implementation Plan — Job #105

**Project**: `roblox.jungle`
**Created**: 2026-08-23 16:53:59
**Status**: Planning (awaiting go-ahead)

## The report

> "Boat turret has limitations to rotate down. When we ride boat is little bit up, and you cant target
> enemies near boat. So we must add +30% rotation up and down for turret."

Two claims, and the middle one is the mechanism: **the boat rides bow-up, and the turret's arc is measured
against the boat**, so riding spends the down-aim before the gunner touches the mouse.

## Analysis

### Where the arc is defined

The elevation clamp is a **duplicated pair of constants**, one on each side of the remote:

| | file:line | value |
|---|---|---|
| server (authoritative clamp) | [GunServer.server.luau:22](../../sync/ServerScriptService/Combat/GunServer.server.luau#L22) | `PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)` |
| client (input clamp) | [GunClient.local.luau:17](../../sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau#L17) | `PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)` |

Both must change together. The client clamp is what the player *feels* (it also drives the gunner camera at
`GunClient:116` and the barrel visual via the `GunAimPitch` attribute); the server clamp at `GunServer:154` is
what the shot is allowed to be. If only the client moved, the server would silently clip the extra travel and
the crosshair would stop agreeing with the bullet.

### Why riding eats the down-aim

The arc is **relative to the boat**, not to the world:

- `GunServer:143` — `aimCFrame() = base.CFrame * CFrame.Angles(gunnerPitch, gunnerYaw, 0)`
- `GunBase` is **welded to the hull** (`GunServer:66`, `weldTo`), so `base.CFrame` carries the hull's attitude.

And the hull is deliberately trimmed bow-up with throttle:

- [BoatServer.server.luau:59](../../sync/ServerScriptService/Boat/BoatServer.server.luau#L59) — `MAX_PITCH = math.rad(7)` — "max bow-up (throttle) / bow-down (brake) trim"
- [BoatServer.server.luau:418](../../sync/ServerScriptService/Boat/BoatServer.server.luau#L418) — `local pitch = t * MAX_PITCH`, written into the `AlignOrientation` goal on the next line.

So at full throttle the deck is 7° nose-high and the gunner's real depression is **−12° + 7° = −5° from level**.
That is the player's "boat is little bit up" — it is not a perception, it is a constant.

### What that costs, in studs

All values read from the repo, not assumed:

| quantity | source | value |
|---|---|---|
| hull collision box | `BoatServer:44` | `14 × 3 × 32` |
| hull centre rides at | `RiverData.luau:14` + `BoatServer:107,340` (buoyancy spring target is the hull **centre**) | `Y = 12` |
| gun mount above hull centre | `GunServer:46` `GUN_Y = topY + 3.3`, `topY = 1.5` | `+4.8` → `Y = 16.8` |
| mount is forward of hull centre | `GunServer:64` `FRONT + 5` = `−16 + 5` | `11 studs` |
| shot origin offset from the aim frame | `GunServer:35,239` `CAM_UP, CAM_BACK = 2, 3` | `(0, +2, +3)`, rotated **with** the aim |

The shot leaves from the gunner-camera point, so its height depends on the aim itself. Bow-up also *lifts* the
bow-mounted gun (rotating `(0, 4.8, −11)` by +7° puts the mount at `+6.11`, i.e. `Y = 18.11`).

Blind radius = origin height above water ÷ tan(world depression):

| | down limit (vs boat) | world depression | origin height over water | water-level blind circle |
|---|---|---|---|---|
| **now**, at rest | −12.0° | −12.0° | 7.38 | **~35 studs** |
| **now**, full throttle | −12.0° | **−5.0°** | 8.36 | **~96 studs** |
| literal +30% only, full throttle | −15.6° | −8.6° | 8.54 | ~56 studs |
| **this job**, at rest | −22.6° | −22.6° | 7.80 | **~19 studs** |
| **this job**, full throttle | −22.6° | −15.6° | 8.84 | **~32 studs** |

`GUN_RANGE = 350` (`GunServer:32`), so today a rider has a ~96-stud hole punched in the middle of a 350-stud
weapon. That is the reported bug, quantified.

### Does widening the arc actually account for the symptom?

The **literal** +30% (−15.6°) does not, on its own — it leaves a ~56-stud blind circle while riding, which is
still "can't target enemies near the boat". Answered via the wizard: go to **−22.6°**, i.e. the +30% asked for
**plus** the 7° the hull trim steals, so the fix lands on the symptom rather than halving it.

Deliberately **not** doing dynamic trim compensation (subtracting the live hull pitch from the clamp): the
server clamps against its own hull pose while each client clamps against its own interpolated one, so the
authoritative aim and the barrel visual would disagree by a fraction of a degree, every frame, forever. A
static constant has no such failure mode. Rejected by choice, recorded here so it isn't re-litigated.

### Things that are safe, checked rather than assumed

- **The shot cannot hit our own boat.** `GunServer:242` puts `boat` in an `Exclude` filter.
- **Water will not stop the shot.** `GunServer:246` sets `params.IgnoreWater = true` (client tracer matches at
  `GunClient:189`).
- **The searchlight does not follow elevation**, so a steeper arc cannot point the beam anywhere new —
  `BoatModules.server.luau:111` is yaw-only, by explicit design.
- **The gunner camera stays above the deck.** `GunClient:117` puts it at `aim * (0, +2, +3)`; at −22.6° that
  point is still ~3.0 studs above the mount, i.e. above the foredeck.
- **Nothing else reads these constants.** `PITCH_MIN`/`PITCH_MAX` appear only in the two files above.

### The one real risk: the barrel mesh clipping the foredeck

This one cannot be settled from the repo and must be looked at in Play.

The visible barrel is a ~4.6-stud skin (`BoatParts.luau:147-154`) centred on an invisible 8-stud host part,
which pivots at the mount (`BoatTurretVisual.local.luau:75`). So the art spans roughly 1.7–6.3 studs forward of
the pivot, while the hull leaves the water at 5 studs forward. Meanwhile the hull *skin* is 6.02 tall against a
3-tall box, lifted so the keel sits on the box floor (`BoatParts.luau:86-91`) — its top is ~3.0 above the
greybox deck, and the mount centre is only 3.3 above it. At −22.6° the barrel's inboard end drops to ~1.4–2.7
above the greybox deck, i.e. **into the height band the bow mesh occupies**.

Whether that actually shows depends on the foredeck's real profile where it tapers — a screenshot question, not
an arithmetic one. If it clips, the cheap fix is to restore the barrel's `+1.2` Y pivot lift that
`poseBarrel` currently drops (`GunServer:83` builds the barrel at `base.CFrame * CFrame.new(0, 1.2, 0)`, but
`BoatTurretVisual:75` re-poses it with no Y term, so the barrel sits 1.2 lower than it was built). That is a
pre-existing inconsistency this job did not create; noted, not silently fixed.

## 🔴 REVISED — measured in Play, and the arc is not the binding constraint

Everything above survives, but it is **not sufficient**, and one measured fact inverts the conclusion.

### The bow lamp fills exactly the cone the gunner needs

`BoatModules.server.luau:86` sets `BOW_LIGHT_X = 0` — directly under a comment that reads *"off the centreline:
on it, the lamp sits directly in front of the gun barrel."* The comment describes an intent the value
contradicts; [ASSETS.md:418](../../ASSETS.md#L418) records the real decision — *"on the centreline — off-centre
it hangs past the bow taper"* — and the mesh is ✅ wired. So a **2.76-stud-tall** lamp skin
(`BoatParts.luau:189`) sits at hull-local **(0, 4.9, −14.5)**, about **5 studs from the gunner's eye**, dead
ahead of a gun whose pivot is at (0, 4.8, −11).

Measured in Play off the real instances (8-corner silhouette, `FOV = 70`), lamp angular span in the gunner's
view, 0° = the crosshair:

| turret pitch | lamp occupies | crosshair |
|---|---|---|
| 0° | −30.5° … −4.0° | clear (lamp starts just below it) |
| **−12° (today's stop)** | −25.1° … **+3.0°** | **BLOCKED** |
| −15.6° (literal +30%) | −23.5° … +5.1° | **BLOCKED** |
| **−22.6° (this job)** | −20.5° … **+9.3°** | **BLOCKED, worse** |

Confirmed visually from the gunner's eye at both −12° and −22.6°: the crosshair sits on the lamp housing at
−12° and moves **into the glass lens** at −22.6°. Depressing does reveal more near water either side of the
lamp — but the centre of the screen, where the crosshair and the shot are, is lamp.

**So widening the arc on its own makes aiming worse, not better.** The player's "you cant target enemies near
boat" is at least as much this lamp as it is the arc. This is why the +30% had to be measured rather than
shipped.

### Elevation collapses to nothing at the edges of the traverse (finding 0024)

All three sites build the aim as `CFrame.Angles(pitch, yaw, 0)` = `Rx·Ry` (`GunServer:143`, `GunClient:116`,
`BoatTurretVisual:75`), so pitch is applied about the **un-yawed** base X axis and the pitch axis does not
follow the traverse. World elevation is `asin(cos(yaw) · sin(pitch))`:

| yaw | world depression at the −12° stop | at a −22.6° stop |
|---|---|---|
| 0° | −12.00° | −22.60° |
| 40° | −9.17° | −17.09° |
| **80°** | **−2.07°** | **−3.83°** |

Widening the clamp buys **1.8°** at full traverse. The composition order has to change too, or the new limit
only exists dead ahead. `CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)` holds the full angle at every
yaw and also removes the camera's horizon tilt (~11.8° at max yaw today).

### Two constants that were wrong (GROUND-RULES §7 — measure, don't assert)

- `WATER_Y = 12` is the buoyancy spring **target**, not the ride height. The hull actually floats at
  **Y 13.376** at rest — 1.376 studs higher. Every blind-radius figure in the table above is computed from
  the constant and is therefore ~1.4 studs optimistic.
- `hull.CFrame:ToEulerAnglesXYZ()` reports **pitch 180° / roll 180°** at rest — a degenerate decomposition of
  a yaw-180 orientation, not real attitude. Trim must be read from `LookVector.Y`, not Euler angles.

### Also logged, out of scope for this job

- **finding 0025** — the ±80° yaw arc cannot reach the flank point the sea AI deliberately steers to
  (`EnemyServer:463-469`, `FLANK_DIST = 12` → ~124° off the bow). Elevation work does not touch it.

## Implementation steps

_Scope confirmed with the user via the wizard before any of this is written._

0. Move the bow lamp out of the gunner's sight line **or** raise the gunner's eye over it — see the wizard
   decision. Without one of the two, steps 1–2 make the depressed view worse.
0b. Fix the aim composition order at all three sites (`GunServer:143`, `GunClient:116`,
   `BoatTurretVisual:75`) so the new limit exists at every yaw, not just dead ahead.
1. `GunServer.server.luau:22` — `PITCH_MIN, PITCH_MAX = math.rad(-22.6), math.rad(45.5)`, with a comment
   carrying the *reason* (the 7° hull trim) so nobody "tidies" it back to a symmetric-looking number.
2. `GunClient.local.luau:17` — the identical pair, with a pointer to the server as the authority.
3. Run `tools/luau-analyze.sh` (absolute paths — GROUND-RULES §7) and confirm no new diagnostics.
4. Verify in **Play**, per the gates below.

## Independent review (GROUND-RULES 8)

Every job gets at least one agent, handed the symptom and the repo but NOT my hypothesis - the whole value
is that it is not anchored to my theory. A second agent is mandatory after one failed fix.

- [x] Agent run, without being told my theory — given only the player's verbatim quote and the repo
- **What it said to check first**: it independently found the same trim mechanism, then went past it: that
  the arc is only the **fourth** most important cause. It surfaced three things I had not looked at — the
  `CFrame.Angles` composition order collapsing elevation off-axis, the bow lamp filling the gunner's lower
  view, and the ±80° yaw arc versus a sea AI coded to attack from ~124° abeam.
- **What came of it**: the job changed shape. Its lamp claim was the decisive one and I had dismissed nothing
  like it. **I did not take it at face value** — I recomputed the silhouette and found it had used the lamp's
  *near-top* corner, which understates a silhouette (it concluded "clear by 0.2°" at −12°); the correct
  highest-in-view corner gives **+3.0°, i.e. already blocked today**. Its conclusion was right and its
  arithmetic was slightly wrong in the direction that made the bug look smaller. Verified in Play with two
  screenshots. The Euler-order claim I verified independently as pure algebra —
  `LookVector.Y = cos(yaw)·sin(pitch)` — before believing the table.

## What I need from you

- [x] Scope agreed via the wizard: −22.6°/+45.5°, raise the eye (`CAM_UP` 2→4), fix the composition order.
- [x] Studio open on the GAME place — Play test driven over MCP, session started and stopped by Claude.
- [ ] **Your judgement on *feel*** — two things I cannot decide for you:
      1. The same mouse sensitivity now covers a 68.1° arc instead of 47°, so the gun travels faster per
         pixel through elevation. If it feels twitchy, `SENS`/`TOUCH_SENS` is the dial.
      2. The eye now sits 4 studs above the mount rather than 2. It reads as standing at the gun rather than
         crouching behind it, and the tracer starts further below the sight line (pre-existing parallax,
         now larger — `GunClient:192` draws from the barrel, not from the true ray origin).
- [ ] Commit (Claude never commits).

## Verification - MANDATORY GATES (GROUND-RULES 7)

None of these may be ticked from an Edit session. Edit does not run LocalScripts and has nothing created at
runtime, so it cannot show a whole class of bug.

- [x] **Reproduced in PLAY**, at the player's camera angle, BEFORE attempting a fix — and it is what changed
      the job: the pre-fix gunner-view captures are what proved the lamp, not the arc, was the binding constraint
- [x] N/A — this was not a "works in X, broken in Y" report
- [x] Every check below says what a FAILURE would have looked like
- [x] Before/after from the SAME camera rig, and the "before" is kept
- [x] No world fact asserted from a constant — two constants were measured and found wrong (see below)
- [x] The fix accounts for the REPORTED symptom — "cant target enemies near boat" is now measurably targetable

### Checks

- [x] **Measure the trim, don't trust `MAX_PITCH`.** Read from `hull.CFrame.LookVector.Y` (Euler angles report
      a degenerate 180°/180° at rest and are useless here) while holding full throttle.
      *Failure would have looked like*: a peak far off 7°, making the 7° of headroom the wrong amount.
      **Result: 0.00° at rest, peak +6.96° at full throttle** — the constant was honest. Effective depression at
      the new stop while riding **−15.64°, against −5.04° before**.
- [x] **The hull does not float where `WATER_Y` says.** *Failure*: the ride height differs from the constant.
      **It does** — `WATER_Y = 12` is the spring *target*; the hull actually sits at **13.374** at rest and rises
      to **14.705** under throttle. Every blind-radius figure derived from the constant is ~1.4 studs optimistic.
      Recorded rather than propagated.
- [x] **Elevation must hold across the whole traverse** (the Euler-order fix), driven through the real remote
      and read off the actual barrel, not recomputed.
      *Failure would have looked like*: depression decaying toward −3.8° as yaw approached ±80°.
      **Result: −22.60° at yaw 0, 40, 80 and −80; +45.50° at yaw 80.** The old form is shown alongside for
      contrast (−3.83° / +7.11° at ±80°).
- [x] **The arc is still bounded, and the server is still the authority.** Pushed past the stops over the remote.
      *Failure would have looked like*: the barrel accepting anything sent, or stopping at the old ±values.
      **Result: sent −90° → accepted −22.60°; sent +90° → accepted +45.50°.**
- [x] **The crosshair is clear of the bow lamp at the new stop.** 8-corner silhouette off the live instances.
      *Failure would have looked like*: any negative clearance, i.e. the lamp still over the crosshair.
      **Result: +8.17° of clearance at −22.6° (was −9.29°, i.e. blocked), and still +4.77° clear at −30°.**
      Confirmed visually: before/after gunner-eye captures at the same pitch.
- [x] **The shot is not blocked by our own boat or the water at a steep angle.**
      *Failure would have looked like*: `[Gun] hit Workspace.Boat...` or a hit on Water.
      **Result: `[Gun] hit Workspace.Terrain (Sand)`** — through the water surface to the riverbed, as designed.
- [x] **Client and server constants still agree.** Read back from the *live* place, not from disk:
      `PITCH_MIN/MAX = -22.6/45.5` and `CAM_UP, CAM_BACK = 4, 3` on both sides, same composition expression.
      *Failure would have looked like*: either file still on the old value → crosshair silently ≠ bullet.
- [x] **The analyzer can actually fail.** GROUND-RULES §7 — proved it by injecting a type error into
      `GunClient` (reported, exit 1), then restoring and re-running clean (exit 0). Not a vacuous green.
- [x] **Barrel clipping the bow at full depression** — ran it, and it **fails**: the barrel mesh does pass
      through the bow. A/B from one external camera at 0° / −12° / −22.6°.
      *Failure looked like*: the barrel jacket visibly emerging through the foredeck — which is what happens.
      **Measured: at the OLD −12° stop the barrel skin centre was already hull-local Y 3.97, i.e. 0.55 studs
      BELOW the hull skin's 4.52 top edge and 1.09 studs from the bow tip. At −22.6° it is Y 3.26, 1.26 below.**
      So this is **pre-existing and ~0.7 studs worse** after this job, not introduced by it. Logged as
      **finding 0026** with the likely fix (restore the +1.2 Y pivot lift `GunServer:91` builds the barrel with
      and `BoatTurretVisual:75` drops when re-posing).
      ⚠️ **A raycast cannot test this.** `Hull.Skin_hull` has `CanQuery = false`, so ray probes pass straight
      through and return a confident "clear". Two such results were discarded rather than reported — this is
      exactly the §7 "verification incapable of failing" trap, caught only because the A/B disagreed with it.
