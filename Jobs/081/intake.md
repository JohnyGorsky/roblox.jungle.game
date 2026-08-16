# Job #081: Boat wake VFX + the unwired boat audio

**Project**: `roblox.jungle`
**Created**: 2026-08-16 10:33:19
**Status**: Requirements Gathering (intake)

## Requirements / goal

Boat needs visual life on the water: bow spray and prop wash particles that respond to speed, plus a trail behind it. Also wire the boat sounds that are uploaded and owned but never hooked up (boat_destroyed, boat_on_fire, metal_debris) and give movement a water cue.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Audit done
- [x] Built — `BoatWake.local.luau` (new) + `BoatSound.local.luau` (3 unwired ids hooked up)
- [ ] ⚠️ **Visual sign-off outstanding** — see "What is NOT verified" below
- [ ] Final summary + changelog written

---

# The audit

| | State before this job |
|---|---|
| Boat particles / trail | **NONE.** `grep` for `ParticleEmitter`/`Trail` across the boat scripts returned nothing |
| Boat audio | `boat_engine_starts`, `speed_boat_loop`, `boat_hit` wired in `BoatSound` |
| Owned but **never wired** | `boat_destroyed` `89814954215320` · `boat_on_fire` `85716055048481` · `metal_debris` `139877854727588` — registry `audio.md` listed all three as *"uploaded — NOT yet wired"* |

Measured boat geometry (live, 2026-08-16): Hull **14 × 3 × 32**, centre y 13.38, `WATER_Y` 12.0 → the
hull rides with ~0.12 studs wetted. **Forward is −Z** (bow gun at z −15, `Motor` at z +17).

# What was built

**`BoatWake.local.luau`** — client-side, mirroring `BoatSound`'s `attach(boat)` + generation-guard
pattern. 3 emitters + 2 trails, all scaled by speed:

- bow spray ×2 at the forward corners, angled outward/back (16/s each at full speed)
- prop wash behind the `Motor` (26/s at full speed)
- two `Trail`s off the stern quarters, `Lifetime` 0.7 → 2.2 with speed

**`BoatSound.local.luau`** — three cues added to the existing `HP` hook (one listener already covers
enemy bites and obstacles, so nothing new had to be edited): `metal_debris` layered on a hit ≥18 % of
MaxHP, `boat_on_fire` looping under 30 % hull, `boat_destroyed` one-shot at 0.

# ✅ What IS verified

- Analyzer exit 0.
- Script runs and builds all 5 instances on the hull.
- **At rest:** every emitter `Rate = 0`, both trails disabled — a moored boat emits nothing.
- **At 24 studs/s:** bow 12.5/s each, wash 20.3/s, both trails on, `Lifetime` 1.87.
- All 7 wake attachments pin to the waterline at **exactly y = 12.00** as the hull bobs.

# ⚠️ What is NOT verified — and why

**No clean sustained visual.** Driving the boat in Studio kept beaching it on the river's meander, and
every throttle-holding rig died between MCP calls (an `execute_luau` `task.spawn` does not survive the
call; even a `Script` planted in `ServerScriptService` only bought one window before the boat ran
aground). One screenshot caught faint foam at the stern; that is all.

> **So the effect's STRENGTH is untuned.** It may well read too subtle at speed. Driving the boat for ten
> seconds in a normal playtest will settle it far faster than any further scripted rig — then the knobs
> are `BOW_RATE`, `WASH_RATE`, the emitter `Size` sequences, and the trail `Lifetime`/width, all at the
> top of the file.

# 🔎 Finding worth checking separately

`BoatSound`'s header states the boat being server-owned means `AssemblyLinearVelocity` "already
replicates". A mid-run sample had the **server reporting 34 studs/s while the client read 0.00**. That
was not conclusively isolated (the boat also stops a lot in these tests), but if it holds, `BoatSound`'s
engine note is driven off a signal that is zero on clients and would sit at idle volume/pitch all run.
`BoatWake` sidesteps it by measuring speed from the hull's own position delta and taking
`math.max(positionDelta, velocity)`.
