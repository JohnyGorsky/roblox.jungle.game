# TODO 0056: Boar spins the boat when it attacks — CAUSE FOUND: land creatures could walk on water

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-17) — fixed in Job #091 - groundYAt had IgnoreWater=false so the river surface answered as ground; land creatures could walk on water and, at the hand-built spawn base where RiverData's bank clamp does not apply, straight onto the moored boat. New isLand() gate refuses any step that is not dry terrain. Boars re-enabled.
**Created:** 2026-08-17 20:00:20

User 2026-08-17: *"Remove boars for now, they somehow attack boat and boat spins"*, then the decisive
detail: ***"pig jumped on my boat at the start and it started glitching."***

## ✅ The cause — `groundYAt` reported the RIVER SURFACE as ground

`EnemyServer.groundYAt` raycasts down to seat a land creature on the terrain. Its `RaycastParams` never
set **`IgnoreWater`**, which defaults to **`false`** — so the ray *hit the water surface* and returned
`WATER_Y` as perfectly good ground.

A land creature walking toward the boat therefore found "ground" over the entire river and **walked out
onto the water** — and at the spawn base, straight onto the moored boat. Which is exactly what was
reported, including the "at the start" part.

### Why the bank clamp did not save it

`bankEdgeAt` is computed **entirely from `RiverData.branchesAt(z)`** — the *generated* river's geometry.
The run **begins at the hand-built spawn base**, where the channel is sculpted terrain and not
`RiverData` geometry at all (`BoatServer`'s header records the same caveat about its own heading). So at
precisely the place the report came from, the clamp was pointing at a shoreline that isn't there.

## The fix (Job #091)

1. **`groundParams.IgnoreWater = true`** — water stops answering as ground.
2. **New `isLand(x, z)`** — dry terrain at least `LAND_CLEARANCE` (1.5) studs above `WATER_Y`. Measured
   from terrain, so it holds at the hand-built spawn base *and* on the generated river, and it is not
   fooled by a sandbar poking above the surface.
3. **`stepToward` refuses any step that is not onto land.** The creature holds its ground on the bank
   instead of wading. This is the rule that cannot be worked around, and it is what the user asked for:
   *"move boars only to land so they never go to water."*
4. **Boar restored to `LAND_POOL`** — the banks have their ambusher back.

## ❌ Correcting an earlier wrong theory in this file

An earlier revision named *"the Humanoid re-asserts `CanCollide` on its anchored root"* as the leading
candidate. **That was wrong, and was written before reading far enough.** `EnemyRig:266-271` already
sets **`humanoid.EvaluateStateMachine = false`**, and `:258` destroys the legacy `Animate` script — so
there is nothing left running to re-enable collision. Recorded rather than deleted, because the next
person will otherwise re-derive it.

## Residual, not yet proven

*Why* a boar on the deck spun the boat is still unmeasured — with `CanCollide = false` holding, it
should not have. It no longer matters in practice, since a boar can no longer get there. If a spin is
ever seen again near a bank, measure `hull.AssemblyAngularVelocity` and check `CanCollide` on the live
creature's parts before theorising. See [[boat-rider-native-carry]] for the related rule that the boat's
physics must not be fought by ad-hoc per-frame code.
