# Job #083 - Final summary

**Density and difficulty pass - logs, monsters, ramps, village escalation.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

User-directed tuning; presentation and density only, no new mechanics. Each ask has a measurement behind
it:

| Ask | Knob | Verified |
|---|---|---|
| More river logs | `FoliageDefs` shore band, `LogMossy` spacing **120 -> 50** | **6 -> 14** live instances in the ~1020-stud window = **2.4x** |
| +20% monsters | new `ENEMY_DENSITY = 1.2` in `EnemyServer` | sea cap `4..9 -> 4..10`, land cap `3..7 -> 3..8` |
| +30% ramps | `RiverData` kind threshold **-0.15 -> -0.08** | **27 -> 36** ramps over 18,000 studs = **+33%** |
| Village escalation | new `VILLAGE_STEP = 1.10` in `ExcursionServer` | village 1 -> 6: guards 1/2 -> 4/6, bandit **55 -> 89 HP**, bite **9 -> 14** |

## Two things that will be misread if not stated

**The ramp number is +33% MORE RAMPS, not +30 percentage points.** Every hook is either an obstacle or a
ramp, so the ramp *share* went 28.7% -> 38.3% - which is 36/27 = +33%, the ask. Adding ramps necessarily
removes obstacles.

WARNING: it was measured the hard way, and the method matters if this is ever retuned. A first attempt
solved the threshold against a uniform z-sweep and predicted 41.9%; the real hook stream has density and
fork filters and gave 38.3%. Recovering the seed offset analytically failed outright (it is a float from
a seeded `Random` chain; a derivation attempt mismatched 9/94 hooks). **Run the real generator at both
thresholds on the same seed and count.**

**The village count ramp is applied INSIDE the `MAX_GUARDS = 6` clamp, deliberately.** That clamp is a
*performance* ceiling - every guard is a full R15 rig - not a difficulty knob. Once the count saturates
at 6, escalation continues through **strength**, which costs nothing to render. A ramp that appears to
stop is intended behaviour, not a bug.

## Second pass, same day - the opening was empty

Reported: *"from start to first camp I had one log and not a single ramp."* Measured, and the complaint
was literally exact: **z 0->1600 contained 1 hook - an obstacle - and zero ramps.** Cause: the Headwaters
zone ran `obs = 0.55`, so `keep = 0.55 x obs = 0.30` discarded 70% of an already-sparse 120-stud
candidate grid.

`ZONE_PROFILE` Headwaters **obs 0.55/0.60 -> 1.00/1.10**. The opening now holds **9 hooks - 3 ramps and
6 obstacles** (ramps at z 240, 720, 1200). Whole river 94 -> 114 hooks, 44 ramps. The Rapids (1.90)
remains the clear peak, so zone escalation is preserved.
