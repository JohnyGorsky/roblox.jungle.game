# Job #100: Camps overhaul — bigger, varied, and defended from outside

**Project**: `roblox.jungle`
**Place**: **GAME only** (`sync/`)
**Created**: 2026-08-18
**Status**: Implemented, NOT signed off — see final-summary.md §4

Sources: [Planned/camps-bigger-and-varied.md](../../Planned/camps-bigger-and-varied.md) ·
[Planned/camps-defended-not-infested.md](../../Planned/camps-defended-not-infested.md)

## The two complaints, in the user's words

> *"Base camps must be larger. Right now they are repetitive and I do not feel like finding things. They
> are in the same position constantly. So more houses, items into houses. Larger search area."*

> *"When players are in camp, enemies must not spawn inside camp — they must spawn from outside and move
> to their positions. Also around camp we can set sandbags etc."*

**These are one job** (agreed): a bigger camp with an undefended edge and a fortified small camp are each
half an answer. The perimeter, the guard posts and the building positions all have to be designed
against each other.

## Why it matters

Camps are the only break from driving, and GAME.md's loop is "ride → reach a dock → scavenge → ride
further". If scavenging is a memorised route, the middle third of the core loop stops being gameplay.
It is also a **retention** problem — a set-piece identical every run is what players stop returning for.

## Investigation — what exists today

### A. Two camps per landing, both from ONE fixed layout

`ExcursionServer.buildCampAt()` is called twice per landing:

| | NEAR camp | DEEP camp |
|---|---|---|
| Roster | all Bandit — the human raider outpost | mixed Wolf + Bandit |
| Loot | 2 × Gasoline | Metal, Ammo, + weapon crate |
| Dressing | sandbags, landing tower | deep-camp variety hut |

**Both use the same `CampDefs.LAYOUT` slot table** — a fixed list of `{right, forward}` offsets in an
approach-relative frame. That is precisely why every camp reads the same: the *contents* vary a little,
the *arrangement* never does.

The existing design intent is good and worth preserving:
- the fire is the centre (0,0); everything else is relative to it,
- everything faces the approach — "a camp you walk into from behind is a camp you can't read",
- **loot sits behind cover** — sandbags at negative forward, loot at positive. That is the one piece of
  dressing already doing gameplay work.

### B. Guards spawn INSIDE the camp — the reported bug

```lua
spawnGuard(campPos + Vector3.new((i - 1) * 7, 0, 8), ...)   -- initial
spawnGuard(g.campPos + Vector3.new(alive * 7, 0, 8), ...)   -- escalation
```

A row 8 studs forward of camp centre — i.e. materialising in front of the crew. `GUARD_LEASH = 55`,
`GUARD_ALERT_SECONDS = 15`, `MAX_GUARDS = 6` (**a perf ceiling — each guard is a full R15 rig**).

⚠️ `CampDefs`'s own header warns: *"Guard spawn positions are NOT in this file and must not move — they
are world offsets in `ExcursionServer` and Job #058's crew-size difficulty scaling is tuned against
them."* **So moving them re-opens a balance question**, and #058's scaling must be re-checked, not
assumed.

### C. The kit already exists

`CampDefs.MODEL`: `tent` · `hut` (BahayKubo5) · `hutAlt` (BahayKubo1) · `post` (BahayKubo7, village
only) · `barrel` · `crate` · `weaponCrate` (AmmoBox) · `sandbag` (SandbagWall, 1 part, 8×6×3).

**Nothing new needs sourcing** for the fortification — `SandbagWall` is already in the library and used
heavily at the crash site.

### D. Part counts are tracked deliberately, and that matters here

`CampDefs` records **BasePart** counts per model with a warning not to "correct" them from
`GetDescendants()`: `crate` = 66 parts (exactly one per camp), `post` = 95 (village only), `AmmoBox` =
22, `RangerTower` = 128, `hut` = 13, `tent` = 1, `sandbag` = 1.

Someone costed this carefully. Any "bigger camp" proposal has to answer to those numbers.

## Decisions (agreed via wizard)

| # | Question | Decision |
|---|---|---|
| 1 | Variety | **Seeded procedural from a kit** — replace the fixed slot table with a seeded assembler driven by the run seed |
| 2 | Interiors | **Loot in and behind buildings, no enterable interiors** — searching means walking round and looking, not new models |
| 3 | Perf budget | ⚠️ **Raise it** — more buildings *and* more area (see the risk below) |
| 4 | Sequencing | **One job**, layout and defence designed together |
| 5 | Guard arrival | **Garrisoned + outside reinforcements** — some guards already at posts (visible on approach, never popped in front of you); every *escalation* spawns outside the perimeter and paths in |
| 6 | Perimeter | **Gaps/entrances** — two or three openings, so approach direction is a real choice |
| 7 | Reinforcements *during* a raid | **Finite** — a fixed roster per camp; the fight itself ends |
| 8 | **Re-garrison** | ⚠️ **A cleared camp REPOPULATES after ~8 in-game hours.** Clearing it is not permanent — hold ground and you fight for it again |
| 9 | Loot on re-garrison | **Guards only. Loot stays taken.** |
| 10 | Timer | **Runs everywhere, including while the crew is standing in the camp** — squat overnight and they come to you |
| 11 | Interval | **Per-camp value**, not one global constant — a difficulty lever alongside crew-size scaling |
| 12 | Which camps run the clock | **Only camps the crew has actually CLEARED.** Untouched camps keep their original garrison |
| 13 | Hauling players | **They are attacked.** A carrier can neither shoot nor swing (`Busy`), so the choice is drop the loot or run |
| 14 | Night | **No special rule** — less warning IS the danger. Night already scales enemy spawn/damage, and camps already return ~2× faster in real time |
| 15 | ⚠️ Arrival cadence | **TRICKLE: 1–2 at a time, never all at once, more after a delay** |

### Decision 15 in the user's words

> *"only 1 or 2 can come, no more. then after some time others. So do not come at once all"*

This is the keystone, not a detail — see [implementation-plan.md](implementation-plan.md) §2. It makes
decision 13 fair (1–2 attackers is escapable; six is a death sentence for someone who cannot fight),
keeps the `MAX_GUARDS = 6` perf ceiling intact by construction, and reads as a camp being re-occupied
rather than a wave spawning.

## The re-garrison rule, against the real clock

> *"After 8h enemies keep coming again. So if I stay overnight I have to fight again."*

`DayNightServer` runs daylight and night at **different real rates**, so "8 hours" is not one duration:

| | in-game hours | real seconds | 8 in-game hours ≈ |
|---|---|---|---|
| Daylight (06→19) | 13 | 480 | **~5 real minutes** |
| Night (19→06) | 11 | 180 | **~2¼ real minutes** |

A run is roughly **12 real minutes**. So 8 hours is about **40% of a run in daylight** and **18% at
night** — near enough one repopulation per camp per run, and because a full night is 11 in-game hours,
**staying through a whole night always trips it.** The instinct matches the clock.

That rate difference is a free feature: the camp comes back **more than twice as fast at night in real
time**, so holding ground in the dark is already the harder choice without a special rule.

**Guards only, never loot** (decision 9) is what keeps this from becoming a farm. The codebase already
guards that line deliberately — the gold nugget is run-capped so *"looting can't eclipse finishing (the
Dead Rails trap)"*. A repopulated camp costs a fight and pays nothing, so squatting is a real cost.

⚠️ Note this interacts with **decision 7**: reinforcements *within* a single raid stay finite, but the
camp itself re-garrisons on the clock. Those are two different systems and the plan must keep them
separate, or "cleared" stops meaning anything.

## ⚠️ The risk I want on the record

**Decision 3 pushes directly against the mobile-first pillar**, which Jobs #094–#099 just spent
considerable effort defending, and against the part budget `CampDefs` documents so carefully.

That is your call and I'll build to it — but the plan will **gate it on measurement**: profile a camp on
a phone preset in the Device Emulator *before* and *after*, and if the after-number is bad, the honest
options are fewer parts per building or a smaller step up, not shipping it and hoping. The `mobile` and
`roblox-optimization` skills both apply.

Decision 5 also has a nice property worth keeping: because reinforcements arrive from outside and the
garrison is visible on approach, **nothing ever materialises in front of the player** — which is the
actual complaint — without needing the camp to be empty when you arrive.

## Open questions for the plan phase

1. **Does #058's crew-size difficulty scaling still hold** once guards start outside and walk in? Arrival
   delay is effectively a difficulty change — and re-garrisoning multiplies total encounters per run,
   which is a second, larger change to the same balance.
1b. **Where does the re-garrison timer live and what survives?** Per-camp attribute, presumably — and it
   must not fire while the crew is mid-fight with the previous wave, nor stack two garrisons.
2. **Pathfinding cost** — several guards pathing in from a perimeter is more expensive than placing them.
   `roblox-ai` for `PathfindingService`, and a fallback if a path fails.
3. **Night raids** — "you can see them coming" is much weaker in the dark. Does the arrival model change
   at night, or is that the point?
4. **How much bigger?** A number, chosen against the measured perf headroom rather than by feel.
5. **Does the seeded layout keep the "everything faces the approach" rule?** It is what makes a camp
   readable; a random arrangement could easily lose it.

## Out of scope

- Enterable building interiors (decision 2).
- The village / trading post (`post`, 95 parts) — a separate set-piece.
- The LOBBY place.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [~] Implementation completed — systems done and verified; perf gate + pathing fallback outstanding
- [ ] Final summary + changelog written
