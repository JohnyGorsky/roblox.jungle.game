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
