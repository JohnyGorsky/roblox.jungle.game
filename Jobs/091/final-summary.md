# Final Summary — Job #091

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ **COMPLETE (2026-08-17)** — analyzer clean; user playtested and reported *"looks better"*.

Two items from the 2026-08-17 session. Both grew past their first fix once the user tested it, and in
both cases the first fix was **necessary but not sufficient** — worth reading for that alone.

---

## Item 1 — Boars: not "remove them", but "they could walk on water"

The ask started as *"Remove boars for now, they somehow attack boat and boat spins."* They were removed.
Then came the detail that cracked it: ***"pig jumped on my boat at the start and it started
glitching"***, followed by *"can you move boars only to land so they never go to water?"*

### The cause

`EnemyServer.groundYAt` raycasts down to seat a land creature on terrain. Its `RaycastParams` **never set
`IgnoreWater`, which defaults to `false`** — so the ray hit the **river surface** and returned `WATER_Y`
as perfectly good ground.

A land creature walking toward the boat therefore found "ground" across the entire river and **walked out
onto the water**, straight onto the moored boat.

### Why the existing bank clamp didn't save it

Job #086 added a bank clamp, so "keep them on land" looked already solved. But `bankEdgeAt` is computed
**entirely from `RiverData.branchesAt(z)`** — the *generated* river's geometry — and **the run begins at
the hand-built spawn base**, where the channel is sculpted terrain and not `RiverData` geometry at all.
`BoatServer`'s header records the same caveat about its own heading. At precisely the spot the report
came from, the clamp was pointing at a shoreline that does not exist.

That is why "at the start" was the tell.

### Fixed

1. `groundParams.IgnoreWater = true` — water stops answering as ground.
2. New **`isLand(x, z)`** — dry terrain at least `LAND_CLEARANCE` (1.5) studs above `WATER_Y`. Measured
   from terrain, so it holds at the spawn base *and* on the generated river, and a sandbar poking above
   the surface doesn't qualify.
3. **`stepToward` refuses any step that is not onto land** — the creature holds its ground on the bank
   rather than wading. This is the rule that can't be worked around, and it is literally the request.
4. **Boar restored to `LAND_POOL`.** The banks have their ambusher back.

The `#LAND_POOL > 0` spawner gate added while boars were out is **kept**: `pickType` ends with
`return EnemyDefs.Defs[pool[1].name]`, which indexes nil on an empty pool and would error every tick.

### ❌ A wrong theory, corrected

Mid-job I named *"the Humanoid re-asserts `CanCollide` on its anchored root"* as the leading candidate,
after scanning the asset and finding `CanCollide = true` on `Head`/`HumanoidRootPart` in the source.
**That was wrong** — `EnemyRig:266-271` already sets `humanoid.EvaluateStateMachine = false` and `:258`
destroys the legacy `Animate` script, so nothing is left running to re-enable collision. Recorded in
[todo 0056](../../todo/0056-boar-spins-the-boat-when-it-attacks-root.md) rather than deleted, so nobody
re-derives it.

**Still unproven:** *why* a boar on the deck spun the boat, given `CanCollide = false` should hold. It no
longer matters in practice — a boar can't get there — but if a spin is ever seen near a bank again,
measure `hull.AssemblyAngularVelocity` and the live creature's `CanCollide` before theorising.

---

## Item 2 — The intro plane: the camera was half of it

> *"intro — looks like camera cant keep up plane and it wiggles a lot"* → after the first fix:
> *"plane still glitches, i think this is camera issue"*

### The shared root

`IntroPlane` is an **anchored** model whose CFrame `PlaneServer` rewrites every Heartbeat. An anchored
part's CFrame replicates as **discrete property writes** — the client does **not** interpolate them the
way it interpolates a physics body — so the plane's rendered pose arrives in visible steps.

### Fix 1 (camera) — necessary, insufficient

`IntroCameraClient` smoothed its own **position** but passed the **raw** stepping pivot into
`CFrame.lookAt`, so every replication step snapped the view. Fixed by smoothing the aim target
(`AIM_GAIN` 20) and raising the body gain (3.5 → **8**; 3.5 was a 0.29 s time constant ≈ 13 studs of
trail at `CRUISE_SPEED` 45).

**But a smooth camera pointed at a stepping plane just means the plane steps inside a steady frame.**
That is what "plane still glitches" was. The subject itself has to be continuous.

### Fix 2 (the plane) — the missing half

- **`PlaneServer.poseFlyer(cf)`** replaces four bare `flyer:PivotTo(...)` calls. It still poses the
  model, and additionally publishes the pose to **`Workspace.IntroPlaneCF`**.
- **New `IntroPlaneSmooth.local.luau`** renders the plane from that attribute, interpolated
  (`POS_GAIN` 26 / `ROT_GAIN` 20 — rotation slightly looser so the descent keeps its deliberate judder
  and roll).

Two things make this work, both borrowed from Job #087's turret/searchlight fix, which had the identical
anchored-part-driven-by-server-CFrame problem:

- **A client write to a server-owned anchored part is local-only** — it does not replicate. Every player
  smooths the plane for themselves; the server stays authoritative; seats, flight path and crash timing
  are untouched.
- **The client reads the ATTRIBUTE, not the model.** Once the client poses the model locally,
  `plane:GetPivot()` returns its *own* value — the smoothing would chase its own tail. The attribute is
  the one source a local write can never clobber.

**To revert:** delete `IntroPlaneSmooth.local.luau`. `poseFlyer` still calls `PivotTo`, so the plane
flies exactly as before, just without interpolation.

---

## Files changed

| File | Change |
| --- | --- |
| `Enemies/EnemyServer.server.luau` | `IgnoreWater = true`; new `isLand`; `stepToward` refuses non-land steps; Boar restored |
| `Intro/PlaneServer.server.luau` | new `poseFlyer` publishing `IntroPlaneCF`; 4 pose sites routed through it |
| `StarterPlayer/.../Boat/IntroPlaneSmooth.local.luau` | **new** — client-side interpolated plane rendering |
| `StarterPlayer/.../Boat/IntroCameraClient.local.luau` | aim target smoothed; position gain 3.5 → 8 |

Game tree only — none of these exist in the lobby.

## Verification

- [x] `tools/luau-analyze.sh` — GAME clean
- [x] Boar/Wolf assets scanned live in the GAME place (Edit): `PrimaryPart == HumanoidRootPart`, no
      unjointed parts — which is what ruled out the anchoring theories
- [x] **Playtest — user, 2026-08-17: *"looks better"*.** The intro and the boars both read right in
      play. ⚠️ That is a general sign-off, not a point-by-point one: nobody specifically verified
      **no boar stands on water at the spawn base**, which is the exact case the old `RiverData` clamp
      could not see. Worth one deliberate look on the next run to the first dock.
