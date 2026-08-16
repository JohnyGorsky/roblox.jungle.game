# Job #083: Density and difficulty pass — logs, monsters, ramps, village escalation

**Project**: `roblox.jungle`
**Created**: 2026-08-16 18:02:27
**Status**: Requirements Gathering (intake)

## Requirements / goal

User-directed tuning 2026-08-16: more shore logs on the river, +20% monsters, +30% more ramps, and each successive village gets +10% more guards and +10% stronger guards (HP and bite). Presentation and density only - no new mechanics.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation completed — all four measured in Play
- [ ] Final summary + changelog written

---

# What changed, and the measurement behind each

| Ask | Knob | Verified |
|---|---|---|
| More river logs | `FoliageDefs` shore band, `LogMossy` spacing **120 → 50** | **6 → 14** live instances in the ~1020-stud window = **2.4×** |
| +20% monsters | new `ENEMY_DENSITY = 1.2` in `EnemyServer` | sea cap `4..9 → 4..10`, land cap `3..7 → 3..8` |
| +30% ramps | `RiverData` kind threshold **-0.15 → -0.08** | **27 → 36** ramps over 18,000 studs = **+33%** |
| Village escalation | new `VILLAGE_STEP = 1.10` in `ExcursionServer` | village 1 → 6: guards 1/2 → 4/6, bandit **55 → 89 HP**, bite **9 → 14** |

## ⚠️ The ramp number is +33% MORE RAMPS, not +30 percentage points

Worth stating because it is easy to misread. Every hook is either an obstacle or a ramp, so the ramp
*share* went 28.7% → 38.3% — which is **36/27 = +33% more ramps**, the ask. Adding ramps necessarily
removes obstacles.

⚠️ It was also measured the hard way. A first attempt solved the threshold against a uniform z-sweep and
predicted 41.9%; the real hook stream has density and fork filters and gave 38.3%. Attempts to recover
the seed offset `offW` analytically failed (it is a float from a seeded `Random` chain, and a derivation
attempt mismatched 9/94 hooks). **The trustworthy method was to run the real generator at both
thresholds on the same seed and count** — do that if this is ever retuned.

## ⚠️ The village count ramp is applied INSIDE the `MAX_GUARDS` clamp, deliberately

`MAX_GUARDS = 6` is a **performance** ceiling — every guard is a full R15 rig — not a difficulty knob.
Letting the +10% ramp push past it would put 10+ rigs at the last village. Once the count saturates at 6,
escalation continues through **strength**, which costs nothing to render. A ramp that appears to stop is
the intended behaviour, not a bug.

---

# Second pass, same day — playtest feedback

## 🔴 "from start to first camp I had one log and not a single ramp"

Measured, and the complaint was literally exact: **z 0→1600 contained 1 hook — an obstacle — and zero
ramps.** Cause: the Headwaters zone ran `obs = 0.55`, and `keep = 0.55 × obs = 0.30`, so 70% of an
already-sparse 120-stud candidate grid was discarded in the opening.

`ZONE_PROFILE` Headwaters **obs 0.55/0.60 → 1.00/1.10**. Result: the opening now holds **9 hooks — 3
ramps and 6 obstacles** (`z=240`, `720`, `1200` are ramps). Whole river 94 → 114 hooks, 44 ramps.
The Rapids (1.90) is still the clear peak, so zone escalation is preserved.

## 🔴 "logs" meant the FLOATING obstacle, not shore dressing — my mistake

I had increased `FoliageDefs`' `LogMossy` **bank foliage**. The user meant the thing the boat runs into.
Corrected by adding a `weight` field to `OBSTACLES` and steering the mix:

| | Rock | Log | Sandbar | LogJam |
|---|---|---|---|---|
| weight | 1.0 | **2.6** | 0.8 | **1.6** |
| measured over 7000 studs | 17% | **49%** | 11% | **23%** |

Floating debris is now **72% of the mix**, against 50% when all four types were equally likely. The
shore-foliage increase is kept — it is good dressing and cost nothing.

## 🔴 Ramps faced the wrong way

The wedge was yawed 180° "so the slope faces the boat" and did the exact opposite: driving downstream you
met a **sheer vertical rock wall**, slope on the far side. Fixed by removing the rotation.

> ⚠️ **My verification was what failed here, not just the code.** A raycast sampling the wedge's top
> surface at two z values reported "CORRECT" — that test passes for BOTH orientations. It only showed up
> by putting the camera at the boat's eye and looking. For anything directional, look from the player's
> position.

## 🔴 "what is that?" — the mystery tan tile was the Sandbar

Its trigger seats on the riverbed, making it an **18-stud-tall column** whose only visible face is a flat
square top 0.4 studs above the water. The existing comment claimed this seating had stopped it "reading
as a plank floating on the water" — it hadn't. Now the column is invisible and a squashed **dome**
(22×9×16 Ball, crown 1.0 above the waterline) is drawn at the surface, which is what a shoal looks like.

## Hippo doubled again

`scale 1.369 → 2.738` (2.6× its original), **sink 0.8 → 1.6** so the submerged fraction is unchanged at
41% — it reads exactly as before, at twice the size.

> ⚠️ It is now **16.5 × 18.3 × 31.2 studs — as long as the 32-stud boat hull.** That is a boss-scale read.
> The HITBOX stays 8×5×12, so every aggro/bite/leash distance is untouched and the art simply overhangs.
> Say if that is too far and it should come back to ~1.5×.

## Notes

- Guard strength is a **per-spawn multiplier**, never a mutation of `EnemyDefs.Defs.Bandit`. Editing that
  shared table per spawn would leak the buff onto every camp built afterwards, including earlier ones on
  a re-dress.
- `tickGuard` now reads a per-guard `BiteDamage` attribute with `def.biteDamage` as the floor.
- **Guard spawn POSITIONS are untouched.** Job #058 tunes crew-size difficulty against those exact spots.
- The **floating `Log` obstacle is untouched.** The user asked for more logs "on river"; the shore
  dressing is the visual read, while `RiverBootstrap.OBSTACLES.Log` is a hazard — changing it would move
  difficulty, which was not the ask. Say the word if it should go up too.
- Village 1 is deliberately unchanged, so this only ever makes the river harder as you go.
