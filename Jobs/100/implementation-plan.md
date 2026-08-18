# Job #100 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: PARTIALLY IMPLEMENTED — layout + defence done; the perf gate is NOT passed (see final-summary)

Intake: [intake.md](intake.md). Skills: `roblox-ai` (pathfinding, posts, aggro), `game-design`
(replayability, difficulty), `roblox-optimization` + `mobile` (the perf gate), `jungle-style` (dressing).

---

## 1. Decisions (all agreed via wizard)

| # | Decision |
|---|---|
| 1 | **Seeded procedural** camp assembly from the existing kit |
| 2 | **No enterable interiors** — loot in doorways, behind huts, in corners |
| 3 | ⚠️ **Raised part budget** — more buildings *and* more area, gated on profiling (§6) |
| 4 | **One job**, layout + defence together |
| 5 | **Garrisoned + outside reinforcements** — nothing ever appears in front of the player |
| 6 | **Perimeter with 2–3 gaps** — approach direction is a choice |
| 7 | **Finite** reinforcements within a single raid |
| 8 | **Re-garrison** after a per-camp interval (~8 in-game hours) |
| 9 | **Guards only** on re-garrison — loot stays taken |
| 10 | Timer runs **everywhere**, including while the crew stands in the camp |
| 11 | **Per-camp** interval, not one global constant |
| 12 | **Only camps the crew has actually CLEARED** run the timer |
| 13 | **Hauling players are attacked** — drop the loot or run |
| 14 | **No special night rule** — less warning *is* the danger |
| 15 | ⚠️ **TRICKLE ARRIVAL: 1–2 at a time, never all at once, more after a delay** |

## 2. Decision 15 is the keystone — it solves three problems at once

> *"only 1 or 2 can come, no more. then after some time others. So do not come at once all"*

This is not just pacing. It is what makes three other decisions survivable:

1. **Decision 13** (hauling players get attacked) is fair against 1–2 arrivals and brutal against six —
   a carrying player can neither shoot nor swing (`Busy` blocks both `WeaponServer` and `MeleeServer`).
   A trickle means "drop it and fight" or "run for the boat" are both real options.
2. **The perf ceiling holds by construction.** `MAX_GUARDS = 6` is documented as a performance limit —
   each guard is a full R15 rig. A trickle never spikes.
3. **It reads as re-occupation**, not a wave spawn. Men walking back to a camp one or two at a time is
   what actually happens; six appearing together is a video game.

So the arrival cadence is a **first-class tunable**, not an implementation detail:
`REGARRISON_BATCH = 1–2` and `REGARRISON_GAP` (seconds between batches), up to the camp's roster cap.

## 3. Architecture

### 3a. `CampLayout.luau` (new) — the seeded assembler

`CampDefs` stays the **parts list and the rules**; the fixed `LAYOUT` slot table is replaced by a
function that *generates* slots from a seed.

**Preserved on purpose** — these are the rules that make a camp readable, and a random arrangement
would quietly lose them:
- the **fire is the centre** (0,0), everything relative to it,
- **everything faces the approach** — "a camp you walk into from behind is a camp you can't read",
- **loot sits behind cover** — cover between the player and the crates is what makes guards matter.

**Varied per camp:** building count, positions within annular bands, rotations, prop scatter, loot
placement (in doorways / behind huts / in corners), perimeter shape and where its gaps fall.

Deterministic from the run seed + camp index, so a run is reproducible and a bug is repeatable.

### 3b. `CampGarrison.luau` (new) — occupancy over time

Owns, per camp: roster, cleared state, the re-garrison clock, and the trickle queue.

- Timer keyed on **`Workspace.ClockTime`** (published by `DayNightServer`), not real seconds — the
  interval is stated in in-game hours, and daylight/night run at different real rates by design.
- Starts only once a camp is **cleared** (decision 12). Untouched camps keep their original garrison.
- On expiry, enqueue the roster and release it **1–2 at a time with a gap** (decision 15).
- Arrivals spawn **outside the perimeter** and path in to posts (§3c).

### 3c. Guards: posts, arrival, pathing

Replaces `spawnGuard(campPos + Vector3.new((i-1)*7, 0, 8), …)` — the row that materialises in front of
the crew.

- **Garrison** spawns at generated **posts** inside the camp at build time (visible on approach, never
  popped in).
- **Reinforcements and re-garrison** spawn at **perimeter spawn points outside**, then path in
  (`PathfindingService`, per `roblox-ai`).
- **Fallback required:** if a path fails, walk directly toward the post rather than standing still. A
  guard frozen outside the fence is worse than a slightly dumb one.

⚠️ **`CampDefs` warns these offsets are load-bearing** for Job #058's crew-size scaling. Guard *counts*
and scaling are **not changed** in this job (decision: ship then tune) — only *where they come from* and
*when*. That keeps one variable moving at a time.

## 4. What changes where

| File | Change |
|---|---|
| `World/CampDefs.luau` | keep the kit + rules; layout becomes generator **parameters** (bands, counts, spacing, perimeter spec) |
| `World/CampLayout.luau` | **new** — seeded assembler |
| `World/CampGarrison.luau` | **new** — cleared state, re-garrison clock, trickle queue |
| `Excursion/ExcursionServer.server.luau` | `buildCampAt` calls the assembler; `spawnGuard` takes a post/entry point; guard bookkeeping moves to CampGarrison |

## 5. Order of work

1. **Profile the current camp** on a phone preset — the baseline decision 3 is measured against (§6).
2. **`CampLayout`** — seeded assembly, same size as today. Verify variety and that the three preserved
   rules still hold, before anything gets bigger.
3. **Grow it** — larger footprint, more buildings, loot placed in/behind them. Re-profile.
4. **Perimeter** with gaps; posts generated from it.
5. **Arrival** — garrison at posts, reinforcements from outside, pathing + fallback.
6. **`CampGarrison`** — cleared detection, clock, trickle.
7. Full playtest pass; summary + changelog.

Stages 2–4 are shippable on their own if the perf gate stops the job early.

## 6. ⚠️ The perf gate — this is a real gate, not a formality

Decision 3 raises the budget on a **mobile-first** game, against a `CampDefs` that costs every model in
BaseParts (`crate` 66, `post` 95, `RangerTower` 128, `hut` 13, `tent` 1, `sandbag` 1) and a
`MAX_GUARDS = 6` ceiling that exists for the same reason.

**Measured before and after, in the Device Emulator on a phone preset:**
- part count per camp and total in the streamed region,
- frame time approaching and inside a camp,
- rig count at the worst moment (trickle should keep this near-flat).

**If the after-number is bad, the honest answers are fewer parts per building or a smaller step up** —
not shipping and hoping. `roblox-optimization` for streaming/LOD/instancing if it comes to that.

## 7. Open questions for implementation

1. **Exact numbers** — footprint radius, building count, `REGARRISON_BATCH`, `REGARRISON_GAP`, per-camp
   intervals. All chosen against §6's measurements, then tuned from playtest.
2. **Pathfinding cost** with several guards walking in at once — bounded naturally by the trickle, but
   worth measuring.
3. **What "cleared" means precisely** — last guard dead, presumably; and whether a camp partially
   cleared then abandoned counts.
4. **Does the trickle keep running while the crew is fighting it?** Probably yes (that *is* the
   pressure), but it must not stack two garrisons.
5. **Seeded variety needs a spot-check** — generate N camps and eyeball them, so "varied" is verified
   rather than assumed.
