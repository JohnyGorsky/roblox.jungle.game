# Job #082: River jump ramps — promote Job 019's proven launch onto the real river

**Project**: `roblox.jungle`
**Created**: 2026-08-16 16:03:27
**Status**: Requirements Gathering (intake)

## Requirements / goal

Replace the translucent green Neon marker on every RiverData ramp hook with a real angled ramp, and move Job 019's proven launch physics out of the DEV-only RampTest onto those hooks. Ramps stay NON-COLLIDING triggers (a buoyant boat cannot climb a solid ramp - measured in #019). Closes todo 0013's ramp half.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Audit — **the physics already existed**, see below
- [x] Implementation completed — verified in Play
- [ ] Real ramp ART (Meshy) — awaiting credit approval
- [ ] Final summary + changelog written

---

# The audit — almost all of this was already built

| Piece | State before this job |
|---|---|
| Launch physics | ✅ `RampTest.server.luau`, proven in Job 019 — **but `DEV_RAMPS = false`** |
| Tuning | ✅ `LAUNCH_BASE 40` · `+1.6/deg` · cap `95` · `FLIP_RATE 0.5` · `MIN_SPEED 6` · `ARC_TIME 0.6` · debounce `2.5` |
| Airborne handling | ✅ `BoatServer` — buoyancy OFF while `LaunchUntil` is open, and it stops levelling so the arc survives |
| Upgrade module | ✅ "Ramp Bow & Hull Shape", 170 Gold → `RampBoost = 1.35` (Job 067) |
| River hooks | ✅ `RiverData` has emitted `kind = "ramp"` since the river existed, ~1 per 3 hooks |
| **Missing** | ❌ the hooks drew a **translucent green Neon slab** and nothing read them |

So this was **promotion, not invention**: nothing about the physics is new or re-derived.

# What was built

- **`RampServer.server.luau`** (new) — Job 019's launch, on the real hooks. Mirrors `ObstacleServer`:
  one Heartbeat over a `Ramp` CollectionService tag, same run/tied guards, reads `Angle` off the part.
- **`RiverBootstrap`** — the Neon slab replaced by a real ramp: an invisible trigger box carrying the
  angle, plus a visual (library model `RiverRamp` if present, else a `WedgePart` — a genuine slope you
  can read at speed). Three angles picked by z-noise: **12° / 22° / 32°**.

## 🔴 Ramps are NON-COLLIDING and must stay that way

Job 019 measured it: a heavy, buoyant, level-controlled boat **cannot climb a solid ramp** — it jams
against the face and stalls. The boat drives THROUGH and the launch is applied directly. Making the ramp
collidable would not "improve realism", it would delete the feature.

# Verified in Play

- River generates **4 ramp / 9 obstacle** hooks over the first 6000 studs (the ~2:1 split `RiverData`
  documents), and the tag streams with its chunk.
- Sample ramp: `34 × 8 × 13`, angle 32°, `Transparency 1`, `CanCollide false`, Art = WedgePart.
- **The jump fires:** boat driven at a 32° ramp rose from y 13.38 to a peak of **35.58 — +22.2 studs**,
  with `LaunchUntil` set. Predicted peak from the tuning was ~21, so the numbers hold.
- Console: `[Ramp] LAUNCH 32° — fwd 9.6 → up 95.0 (boost x1.35)`.
- ✅ **The cap works as documented**: with the module owned, `(40 + 32×1.6) × 1.35 = 123` was clamped to
  `LAUNCH_MAX 95`, so owning the upgrade cannot launch the boat past what the landing was tuned to catch.
- Zero leftover Neon marker parts.

# Outstanding

- **Real ramp art.** The greybox `WedgePart` is a grey rock slab — readable and correctly oriented, but
  blocky. A Meshy `RiverRamp` drops straight in: the loader already looks for it by name and stretches a
  single-mesh model to the trigger box, exactly as `LogJam` does.
- `RampTest.server.luau` is now redundant (still `DEV_RAMPS = false`). Left in place as the record of the
  #019 experiment; delete whenever.
- todo **0013** — the ramp third is done; waterfalls and log/dam blockages were closed or dropped
  separately (`LogJam` shipped in #079; waterfalls declared not needed 2026-08-16).
