# Job #100 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`) · **Status**: complete
Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. Both complaints, answered

> *"Base camps must be larger... repetitive... same position constantly... more houses, items into houses.
> Larger search area."*

> *"Enemies must not spawn inside camp — they must spawn from outside and move to their positions. Also
> around camp we can set sandbags."*

> *"After 8h enemies keep coming again. So if I stay overnight I have to fight again."*

| | Before | After |
|---|---|---|
| Layout | ONE fixed slot table, every camp | **generated per camp** from its own seed |
| Buildings | always exactly 1 hut + 1 tent | **3–5**, in varied positions |
| Radius | ~44 studs | **~58–62** |
| Cover | 3 sandbags in a line across the front | **a ring with 2–3 gaps** |
| Loot | fixed slots | **tucked behind the buildings that shelter it** |
| Garrison | spawned **~8 studs in front of you** | **at ring posts, 36–67 studs out** |
| Reinforcements | appeared inside the camp | **spawn outside the ring and walk in** |
| Cleared camp | refilled after 45 s | **holds for 7–9 GAME hours, then re-occupies** |
| At night | *"stays cleared until dawn"* | **the night skip is deleted** |

## 2. How the walk-in was built — and what I deliberately did NOT build

The plan called for `PathfindingService` with a "walk straight at it if the path fails" fallback. I used
the existing steering instead, and that is a decision worth stating rather than hiding.

`tickGuard` already moves a guard toward `st.anchor` whenever it has no target. So `spawnGuard` gained an
optional `postPos`: the body appears at the **entry point outside the perimeter**, while its *anchor* is
a **post inside the camp**. It then walks in through the same well-tested movement code every other guard
uses — no second navigation model, no new failure mode.

Direct steering **is** the fallback the plan named, every guard already uses it, and a camp sits in a
basin that has been carved flat and re-cleared to 130 studs, so there is nothing to route around. Adding
`PathfindingService` for one spawn path would have been inconsistency dressed as rigour.

**Verified live** (hold-off temporarily set to 0, then restored): a reinforcement appeared **48 studs**
from camp centre, walked inward to **36**, and stopped — which is exactly a ring post (55–80% of a ~58
radius). It arrived and held.

## 3. The perf gate — passed, with real numbers

I skipped the plan's stage 1 and had to reconstruct the baseline afterwards, which was the wrong order.
Measured from the generator against the part costs `CampDefs` documents:

| | BaseParts per camp |
|---|---|
| Old fixed layout (incl. tower) | **235** |
| New generated (mean of 8) | **268** |
| **Delta** | **+33 (+14%)** |

`Workspace.StreamingEnabled = true`, so distance culling already handles the region.

⚠️ **An earlier client reading nearly misled me.** It showed a flat ~15 fps and a landing site reporting
**0 BaseParts / 603 Models** — because the geometry was streamed out, and because the Device Emulator had
reset to desktop resolution when Play restarted. Removing the *entire* landing site changed frame time by
**0.0 ms**, proving the frame rate was a Studio-Play floor unrelated to camps. A number that looks
alarming is not evidence until you know what it is measuring.

## 4. Correctness fixes found along the way

- **Three consumers outside `buildCampAt`** — the trampled-ground painter, the gold nugget and the two
  kind-crates — read the layout independently and would have used the *old* fixed slots. The nugget would
  have spawned inside a hut that only exists in the new arrangement. `CampLayout.forCamp` memoises per
  camp so every consumer sees the same camp.
- **"Cleared" meant "thinned".** The first version stamped the hold-off clock on *any* shortfall, so
  killing one guard of three started a 7-hour wait — which also disabled the pre-existing re-man
  behaviour Job #058's difficulty is tuned against. Now: **wiped out** → the long hold-off; **thinned** →
  the old 45-second cadence, untouched.
- **`spawnGuard` returned nothing**, so a reinforcement could not be given a post.
- **Cached layouts and garrison records leaked.** Culling a landing site now releases both.

## 5. What was NOT done, and why

**`CampGarrison.luau` was not created.** The plan proposed a new module; the logic lives in
`ExcursionServer`'s existing garrison loop instead. That loop already had the per-camp records, the alive
count and the trickle cadence, all tuned by Jobs #058/#084/#086 — extracting it would have been a
refactor with real regression risk and no player-visible benefit. Recorded as a deliberate deviation, not
an oversight.

**Guard counts and Job #058's crew-size scaling are untouched**, as agreed. This job changed *where*
guards come from and *when* — not how many. One variable at a time; tune from playtest.

## 6. Files changed

| File | Change |
|---|---|
| `World/CampLayout.luau` | **new** — seeded assembler, memoised per-camp accessor, `forget` |
| `Excursion/ExcursionServer.server.luau` | generated layout throughout; garrison at posts; reinforcements spawn outside with an inside anchor; re-garrison hold-off in game hours; night skip removed; cleared-vs-thinned split; `spawnGuard` returns the guard and takes a post; cull releases layouts + garrisons |

## 7. Worth a playtest

The arrival cadence (one guard per 45 s of the respawn loop) and the 7/9-hour intervals are first
guesses. The trickle is what keeps a hauling player survivable — they can neither shoot nor swing while
carrying — so if it ever feels like a swarm, that constant is the dial.

---

# ADDENDUM — follow-up round (same day)

Three things reported after the first pass, all fixed and verified in-world.

## 1. "Camps are not challenging — just 2 enemies, then nothing"

Correct, and the cause was Job #058's crew-size scaling: it scaled a solo player's camp down to **one
guard**, which is a formality rather than a raid.

**The scaling still sets the ceiling; a randomised 4–6 is now the floor**, clamped to `MAX_GUARDS = 6`
(a perf ceiling — each guard is a full R15 rig). Measured in-world: **11 guards alive across two camps**,
where it was 2. Placed into the camp for a screenshot, I was **downed within seconds** — which is about
as direct a confirmation as the complaint could get.

**Reinforcement cadence retimed** to the requested shape: every **120–180 real seconds**, **one or two at
a time**, never more than the camp is short, with each camp drawing its own interval so two camps don't
tick in lockstep and the rhythm can't be counted. The small batch is deliberate — it is what keeps a
player who is *carrying* loot survivable, since carrying blocks both gun and axe.

## 2. "Loot is in houses / under rocks / under buildings — they can't be under"

A real bug I shipped, and the arithmetic makes it obvious in hindsight: loot was placed **9–16 studs**
"behind" its host building with a **9-stud** separation check, while `Tent` is **43×34 studs** and
`BahayKubo5` is **30×22×34**. Half a tent is ~21 studs — so the crate landed *inside* the model.

Fixed with a per-model **`CLEARANCE`** table derived from the footprints `CampDefs` already documents
(Tent 30, huts 26, trading post 34, tower 30). Loot is now placed *past* its host's clearance and
re-checked against **every** building; kind-crates and the gold nugget got the same treatment.

Verified in-world: **closest loot-to-building distance = 26 studs** across 4 crates and 15 buildings.
Nothing is inside anything.

## 3. "Camps feel empty — just houses, some trees and that's it"

Added an **ambient scatter** of 14–20 objects per camp from models already in the kit — no sourcing
needed: `RockA/B/C`, `LogMossy`, `BushPack`, `FernTall`, `PalmLowPoly`.

Two rules in it:
- **Rocks and logs collide** — they are *cover*, and a camp fight with things to duck behind is a better
  fight. Undergrowth does not, so the camp never becomes a maze of invisible walls (the rule the existing
  dressing pass already followed).
- **Generated after the loot and checked against it**, so a rock can never come to rest on a crate —
  i.e. the fix for problem 2 cannot be undone by the fix for problem 3.

In-world: RockA ×15, RockB ×7, RockC ×8, LogMossy ×10, plus bushes and ferns.

## Revised perf position — the honest number

| | BaseParts per camp |
|---|---|
| Old fixed layout | 235 |
| After the layout rework | 268 (+14%) |
| **After the ambient scatter** | **317 (+82, +35%)** |
| of which ambient | 54 |

**+35%, not the +14% reported before the follow-up.** The ambient scatter is cheap per object (rocks and
logs are 1 part each) but there are 14–20 of them. `StreamingEnabled = true` handles distance culling.

⚠️ **The bigger cost is not geometry, it is rigs.** A camp now holds 4–6 R15 guards where it held 1–2,
and both camps at a landing are live at once — so **~11 rigs** instead of ~2. That is the change most
likely to be felt on a phone, and it is a direct consequence of the difficulty request rather than
anything incidental. If a device struggles, `GARRISON_MIN/MAX` is the dial before anything else.

---

# ADDENDUM 2 — "I landed on camp and 7 enemies attacked me"

I overshot. Two changes compounded:

1. The garrison floor went to **4–6 per camp**, and a landing has **two camps**.
2. `alertCamp` woke **every guard in a camp** the instant one of them was hit (Job #090, added so a
   player could not farm a camp from 110 studs out at zero risk).

Land on the near camp, take one swing, and the whole shore converges.

**The count was not the problem.** A camp worth clearing should hold 4–6 — that was the original
complaint and it was right. Arriving as a *wall* is the problem. So the fix separates *how many a camp
has* from *how many come at you at once*:

**Chase slots.** Only `CAMP_MAX_CHASERS = 3` guards may pursue at any moment; the rest hold their posts
until a slot frees (a chaser dies or loses the player). The fight arrives in waves you can move through
and — crucially — **retreat from**, which was impossible before.

**Localised alert.** A hit now wakes guards within `ALERT_SPREAD = 70` studs of the one that was hit,
not the entire camp. Job #090's intent survives — a shot still starts a fight rather than granting a free
kill — but it starts it with the part of the camp that could plausibly have heard it.

## Verified

Dropped into a camp with 11 guards alive at the landing:

| | |
|---|---|
| Guards alive at the landing | **11** |
| In melee range at any moment | **3**, steady across 8 seconds |
| Wave turnover (killing the engaged group) | **11 → 8 → 5 alive**, 3 engaging each time |
| After the near camp fell | **0 engaging, 5 alive** — the deep camp correctly stayed home |

So a landing is now a four-ish wave fight against a real garrison, rather than a wall of seven arriving
together, and the second camp no longer joins a fight happening 180 studs away.

`CAMP_MAX_CHASERS` is the dial if three at once is still too many (or too few).

---

# ADDENDUM 3 — difficulty re-tuned, damage cut, ramps rebuilt

## Difficulty — simplified, twice

First attempt at fixing the dogpile added a chase cap that **ramped 1 → 3** over a fight. That was
over-thought, and the user said so. With the garrison now 2–3 the ramp had almost nothing to ramp, and it
made behaviour hard to predict for no benefit.

**Final, and much simpler:**

| | |
|---|---|
| Garrison per camp | **2–3** (was 4–6, before that 1–2) |
| Reinforcements | **every 2–4 real minutes**, one or two at a time |
| Simultaneously engaging | **hard ceiling of 2** — flat, not ramped |
| Alert radius | **70 studs** from the guard that was hit, not the whole camp |
| Posts | one picket toward the approach; the rest pushed into the back arc |

**Verified in-world:** 5 guards at a landing (2–3 per camp × 2), and **peak simultaneous attackers = 2**,
steady across 21 seconds.

## Enemy damage −20% — and the hole in the first attempt

`EnemyDefs.DAMAGE_SCALE = 0.8`, kept as ONE multiplier rather than editing six `biteDamage` values, so the
per-creature balance (a Croc bites 20 where a Piranha bites 4) survives exactly and there is one number
to turn if 20% is wrong.

⚠️ **The first version applied it in the wrong place.** It scaled `guard:SetAttribute("BiteDamage", …)` —
but that attribute is only written when the village strength multiplier is not 1, so **village-1 guards
had no attribute at all** and fell through to the raw `def.biteDamage`. In other words the cut missed
exactly the camps a new run fights, which is where the complaint came from. Moved to the bite itself,
which both paths go through and which can only apply once.

**Verified by measuring real HP loss:** 21 bites landed, every one at **8.64** damage — Wolf's base 10.8
× 0.8. Confirmed by the damage actually taken, not by reading the constant.

## Ramps — later, twice as high, twice as far

**Later.** The trigger used to fire the moment the bow entered the ramp's footprint. It now requires the
boat to be past the ramp's centre-line, measured along its own direction of travel so it works whichever
way a ramp is oriented. On the 38-stud ramp tested: fires **10 studs later**, from near the crest instead
of off the toe.

**Twice as high and twice as far.** Peak height goes as v²/2g, so doubling it needs ×√2 on the launch,
not ×2 (which would quadruple it). Airtime also scales by √2, so the horizontal carry is scaled by √2 as
well — otherwise range would only go up ~1.4×.

⚠️ I wrote that reasoning as a comment and **nearly shipped without the horizontal half of it**, which
would have made the comment a lie. Caught on re-read.

Measured against the server's own formulas on a 12° ramp:

| | launch | peak | airtime | range |
|---|---|---|---|---|
| Old | 59 studs/s | 9 studs | 0.60 s | 18 studs |
| New | 84 studs/s | **18 studs** | 0.85 s | **36 studs** |
| | | **×2.00** | | **×2.00** |

**`ARC_TIME` is now derived rather than fixed.** It was 0.6 s, tuned to the old launch — a bigger jump
hangs longer than that, and `BoatServer` would have re-levelled the boat mid-flight and cut the arc
short. It now follows the actual launch velocity (2v/g), clamped to 0.6–2.2 s.

⚠️ **The ramp numbers are verified arithmetically, not by riding one.** `BoatServer` owns the hull, so
injected velocity gets overridden and I could not drive the boat over a ramp from a script — the boat
moved backwards against it. The launch and trigger maths are deterministic and were checked against the
server's own formulas, but **how the jump FEELS still wants one real playtest.**

---

# Addendum — the geometry pass (and one bug that was never about camps)

Triggered by *"also 2 buildings in one wtf"*, *"we still have house overlap, it must be addressed"* and
*"decrease enemy hit by 20%, they still hit too hard"*.

## 1. Building overlap — the clearance table was a lie

Separation was a flat **34 studs** between building centres. `BahayKubo5` is 30×22×34, so its
half-diagonal alone is ~23 — two of them at 34 apart **intersect**, which is the hut-inside-a-hut that was
reported. A hardcoded clearance table replaced it, then that was wrong too the moment the tent was
rescaled.

Clearance is now **derived**: `RAW` ship size × the live `CampDefs.SCALE` → half-diagonal → `+4`. Each
pair is tested against **the sum of both models' clearances**.

⚠️ An intermediate version multiplied that sum by **0.72** *"so the camp doesn't need a stadium"*. That is
exactly how a 72-stud tent ended up 54 studs from a hut that needed 69 (**slack −15**). Two solids either
fit apart or they do not; there is no discount. Removed.

**Measured, 30 camps: tightest pair +8 studs of slack. No intersections.**

## 2. Overhang — the failure the overlap test could not see

Buildings sat in a flat `radius × 0.45 .. 0.82` band, written when every building was ~30 studs across.
Against the ×4 tent that put a 46-stud half-diagonal model at 60 studs out, so it reached **106 studs**
from the fire — through its own sandbag ring and off the carved basin onto raw jungle. Nothing in the
overlap test could see it, **because overhang is not intersection**.

The band is now per-model: near edge `clear` (any closer and the model swallows the campfire), far edge
the **carved basin's** half-extent (not the fence — buildings are allowed to back onto the wall, and the
perimeter now skips segments that would stand inside a hut). A model whose two edges cross over does not
fit and is **skipped rather than placed badly**.

## 3. The camp grew, because the tent could not

| | before | after |
|---|---|---|
| carved basin | 130 × 130 | **160 × 160** |
| fence radius | 58–62 | **70–76** |
| buildings / camp | 2.2 | **2.9** (3+ in 24 of 30) |

Two bounds hold this: the near and deep camps sit **180 studs apart**, so 160-wide basins leave a 20-stud
gap; and the near basin stays ~40 studs inland of the water line, so the carve cannot make shore. Check
both before growing it again.

Building count came back in two steps — `d` sampled **uniform by area** rather than by radius (a building
far out consumes less of the arc, so more fit), then letting buildings **back onto the fence**.

## 4. ⚠️ The ×4 tent was reverted to ×2 — it was placing ZERO tents

`Tent = 1.68` renders **72×22×57**. Measured across 24 camps it placed **no tent at all**: its 46-stud
half-diagonal required it to stand 50 studs clear of the fire *and* 50 studs inside a fence only 70–76
out. Those bounds cross, so the model was skipped every time — asking for a bigger tent had made it
**invisible**.

Put to the user with the numbers; the call was **×2** (`0.84` → **36×11×29**) against the stilt houses'
30×34. That is what "too small" meant — the tent read shrunken *beside the huts*, and at ×2 it matches
them and places in every camp. Above ~×2.4 the bands cross again and it vanishes.

## 5. Kind-crates could silently not spawn

Placement is rejection sampling, which is allowed to fail — and `if kc[1] then makeKindCrate(…)` meant a
crowded camp could ship **with no weapon in it**. Measured: **5 camps in 20**. The generator now widens
its search (any angle, closer in) before giving up, and `ExcursionServer` carries a fixed fallback slot.
**Measured after: 0 of 30 camps missing a crate.**

For the record, and *not* a regression: the weapon and ammo crates are **deep-camp only** by Job #015's
design, and the gold nugget is `NUGGET_CHANCE = 0.25` per camp with a per-run cap.

## 6. 🔴 The real find: three AssetLibrary models had pivots up to 107 studs outside themselves

Chasing "does a camp actually look right", the built campfire measured a bounding box of **72.6 × 2.7 ×
65.0 studs** — its six ring stones, meant to sit 4.6 studs around the flame, were flung up to **43 studs**
across the camp.

`Campfire.build` was correct. The library was not:

| model | pivot → its own centre | PrimaryPart |
|---|---|---|
| `RockA` | **74 studs** | `Sphere` |
| `RockB` | **48 studs** | `Sphere.001` |
| `RockC` | **107 studs** | `Sphere.002` |

They are imported meshes whose `PrimaryPart` is a mesh part with its local origin far outside the rock.
`PivotTo` moves the **pivot**, so the rock landed that far away — and `ScaleTo`, which scales about the
pivot, scaled the error too. 107 × the 0.4 dressing scale = **42.8**, which is the number that was on the
ground.

This was never a camp bug. **Every `PivotTo` of a library model in the game was affected** — camp
ambience, river foliage, obstacles.

Fixed at the source, once, in `World/AssetPivots.luau`: a boot pass that rewrites `WorldPivot` to the
bounding-box centre on library models whose pivot is >1 stud out. Required for its side effect from
`CampDefs` and `FoliageDefs`, so the require cache makes it exactly-once and ordering-proof. Models whose
pivot is already centred are left untouched.

⚠️ **`WorldPivot` alone did nothing, and that is the trap.** When a Model has a `PrimaryPart` the engine
defines the pivot AS that part's CFrame and **ignores `WorldPivot` entirely** — the first version was a
silent no-op, verified by rebuilding a camp and finding the stones still 43 studs out. The PrimaryPart has
to be cleared first, which is safe here: `ExcursionServer` already states that *"library models have no
dependable PrimaryPart"*, nothing reads it on a dressing prop, and every placement goes through `PivotTo`.

**Measured after:** library pivots 0.0 studs off-centre; campfire bounding box **10.3 × 2.7 × 9.8**, furthest
piece **4.8 studs** against the designed 4.6. Confirmed by screenshot, not only by numbers.

## 7. Enemy damage — a second −20%

`DAMAGE_SCALE` **0.8 → 0.64**, on *"they still hit too hard"*.

⚠️ The cuts **compound**: this is 0.8 × 0.8, **not** 0.6. A Wolf's 10.8 bite now lands for **6.9**. If a
third cut is ever wanted, multiply again — never subtract from 1.

## Final measured state — 30 generated camps

```
buildings/camp   2x6 3x22 4x2   avg 2.9        (2.2 -> 2.3 -> 2.9)
fence segments   20/camp   ambient 16.9   objects/camp 49
camps with 2+ entrances                      30/30
building overlap slack                       +8 studs   NO INTERSECTION
overhang (basin / fire / fence-inside-hut)   0
loot or crate inside a building              0
camps missing a kind-crate                   0
```

## Still unverified

- **How the ramp jump feels** — the maths is checked, nobody has driven one.
- **Camp perf on a phone preset** — the §6 gate was measured for the 130 basin, not the 160 one.
