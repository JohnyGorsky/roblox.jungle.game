# Job #101 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: Complete

> *"i could not found 2 gasoline only one … Is there a way that if you are close to crate then it lights
> up? because we also have props that looks like lootable and you cant understand what is what"*

---

## 1. 🔴 The premise was half wrong, and checking it first changed the whole job

**Both gasoline crates were spawning the entire time.** Measured in the built world at landing 1:

```
Gasoline   at 346, 1552          Gasoline   at 367, 1649
```

and in the generator directly: across **40 near camps it returned 2 loot slots every time, 0 failures**.

Had this not been checked first, the obvious reading of *"you must ensure that it is there"* would have
sent me into the placement code to fix a bug that does not exist — and the actual cause would have
shipped untouched. **There was nothing to ensure. There was something to make findable.**

Confirmed again live, in the user's own running session, when they asked directly: two crates, both
present, both tagged, **99 studs apart on opposite sides of the near camp**.

## 2. Three compounding causes, none of them a spawn failure

**A. Loot uses the same models as the dressing.** `buildCampAt` places resource #1 as a `CrateWood` and
every one after it as a `Barrel` — and the camp is *also* dressed with loose barrels and crates. Measured
at landing 1: **7 barrels, 4 in the near camp, exactly one of them the gasoline.** Same model, same
texture, same size. There was no way to tell them apart by looking.

**B. The prompt existed only within 10 studs**, in a camp ~150 studs across. Finding loot meant walking
within 10 studs of every barrel in the camp.

**C. Job #100 had just made the camp much bigger**, which multiplied A and B.

### The codebase called this shot in Job #077

> *"⚠️ ONE THING DELIBERATELY LOST: the greybox tinted each crate by resource … what is in a crate is now
> read off its `LootPrompt` ActionText on approach instead of its colour at distance. **If that turns out
> to matter in play, the fix is a small painted stencil or a resource icon on the crate — NOT re-tinting
> the whole barrel.**"*

It turned out to matter in play, and the prescribed direction was followed.

## 3. What was built

| File | Change |
|---|---|
| `World/CampDefs.luau` | `TAG.lootable = "Lootable"` |
| `Excursion/ExcursionServer.server.luau` | tag in `lootPrompt`; prompt range **10 → 14**; tag + range **8 → 10** on the gold nugget |
| `StarterPlayerScripts/UI/LootGlow.local.luau` | **new** — the client marker |

A `Highlight` adorns the model without touching its material or colour, so the barrel stays a weathered
wooden barrel (STYLEGUIDE §12). It is also **screen-space**, so the outline is the same thickness on a
phone as on a desktop — the reason this approach survives the mobile pillar where a world-space marker
would not.

**One tag is the whole contract.** Only things a player can pick up carry it; the look-alike dressing
deliberately does not. That asymmetry *is* the feature.

## 4. ⚠️ `XRAY = 18` — the design in one number

Inside 18 studs the outline draws **through** walls; beyond it, geometry occludes it.

Job #100 puts loot behind cover on purpose — *"cover between the player and the crates is what makes the
guards matter"* — so an always-on-top outline would have deleted the search the camps were just rebuilt to
have. But what stranded the run was a crate behind a hut the player was **standing next to**. Close enough
to be searching *this* corner → the wall stops hiding it. Far away → walk the camp and look.

## 5. Verified — by distance, not by eye

Tagging is exact:

```
lootable models in site     : 6
tagged "Lootable"           : 6   -> Ammo, Ammo:Pistol, Gasoline, Gasoline, Metal, Weapon:Pistol
decorative Barrels          : 7   (untagged, stay dark)
highlights on NON-lootables : 0
```

The fade curve and the x-ray switch, sampled by walking the player in:

| dist | outlineT | depth mode | |
|---|---|---|---|
| 48, 42 | — | — | no glow |
| 38 | 0.84 | Occluded | fading in |
| 34 | 0.51 | Occluded | fading in |
| 30 | 0.17 | Occluded | full |
| 22 | 0.00 | Occluded | full |
| 16, 10, 6 | 0.00 | **AlwaysOnTop** | full, through walls |

And a screenshot beside a decoy — because *"reads as loot"* is not a number. The crate outlines gold; the
sandbags, rocks, hut and the barrel next to it stay dark.

## 6. ⚠️ THE FIRST RANGE WAS WRONG, AND ONLY THE ROUTE TEST CAUGHT IT

Everything above passed at `RANGE = 40`. The job could have been closed there. The gate in the plan asked
a different question — **does it glow where a player actually walks?** — measured by taking the real route
(shore → near fire → deep fire) and finding how far each lootable sits off that line:

```
Metal      3 studs      Ammo      21      Gasoline  39      <- lit at 40
Weapon    50 studs      Gasoline  52      Ammo      68      <- NEVER lit at 40
```

**Three of six never lit, including a gasoline.** The near camp is the run's only fuel source, so that is
not a smaller haul — it is a stranded run, which is exactly what was reported. The marker fixed *"which
barrel is real"* and did nothing at all for *"I didn't know there was another one"*.

**`RANGE` 40 → 60**, chosen against those numbers: lights five of six (measured live at the time: 3/5 →
**4/5**). Deliberately not higher — the fence radius is 70–76, so 60 measured from a *moving* player lights
what you walk past, not the whole camp from the entrance. `FADE` 12 → 18 keeps the ramp-in gentle.

The one still unlit is a cargo `Ammo`, which costs a haul and not the run.

## 7. Two false alarms, both worth recording

- **"The weapon crate is missing."** It was — because the player had **looted it**. Confirmed from the
  console (`[Weapon] HIT CampGuard`), not inferred from the empty world. Worth the check:
  `makeKindCrate` returns silently if `prop` fails, so a genuinely missing crate would look identical.
- **A one-off in-session marker** was pushed to the live client (yellow, through-walls, labelled, with a
  live distance readout) so the user could see both crates immediately. Named `FindGasMarker` so
  `LootGlow` would never adopt or destroy it. It is not part of the game and does not survive a restart.

## Not done / worth knowing

- ⚠️ **The `RANGE = 60` change was verified against measured off-route distances, not re-run in-world** —
  Studio disconnected before a final rebuild. The distances are measured and the comparison is
  deterministic, but a fresh run has not confirmed it end to end.
- **Never seen on a phone.** The outline is screen-space so it should hold, but the `mobile` skill's rule
  is to measure rather than reason, and that has not been done.
- **The far cargo `Ammo` (68 studs off route) still never lights.** Accepted: it costs a haul, not a run.
