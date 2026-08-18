# Job #101: Lootables must read at a distance

**Project**: `roblox.jungle`
**Place**: **GAME only** (`sync/`)
**Created**: 2026-08-18
**Status**: Complete

## The complaint, in the user's words

> *"i could not found 2 gasoline only one, you must ensure that it is there because with 1 is not enough
> fuel to get to next station. I found only one. Is there a way that if you are close to crate then it
> lights up? because we also have props that looks like lootable and you cant understand what is what"*

## ⚠️ The premise is half right, and the half that is wrong matters

**Both gasoline crates DO spawn.** Measured in the built world at landing 1:

```
Gasoline        camp 1   54 studs from its fire   at 346,1552
Gasoline        camp 1   67 studs from its fire   at 367,1649
```

The generator was also checked directly: across 40 near camps it returned **2 loot slots every time,
0 failures**. So this is not a spawn bug and there is nothing to "ensure" in the placement code.

It is a **findability** bug, and there are three compounding causes:

### 1. Loot uses the SAME MODELS as the camp dressing

`buildCampAt` places resource #1 as a `CrateWood` and every one after it as a `Barrel`:

```lua
if i == 1 then CampDefs.MODEL.crate else CampDefs.MODEL.barrel
```

and the camp is *also* dressed with loose barrels and crates. Measured at landing 1: **7 Barrels, 4 of
them in the near camp**, of which exactly one is the gasoline. They are the same model, same texture,
same size. There is no way to tell them apart by looking.

### 2. The prompt only exists within 10 studs

`lootPrompt` sets `MaxActivationDistance = 10`. In a camp ~150 studs across, that means walking within
10 studs of *every barrel in the camp* to discover which one is real.

### 3. Job #100 made the camp much bigger, which multiplied 1 and 2

The two crates land up to **~100 studs apart** (measured 99 at landing 1) in a camp whose fence radius is
now 70–76. Job #100 grew the basin 130 → 160 precisely so camps would take longer to search — which is
correct, but it raised the cost of a lootable that cannot be recognised from more than 10 studs away.

## 🔴 The codebase predicted this exactly

`ExcursionServer` line ~1044, written during Job #077:

> *"⚠️ ONE THING DELIBERATELY LOST: the greybox tinted each crate by resource (yellow gasoline, grey
> metal). Real wooden barrels cannot carry that without the neon-prop look STYLEGUIDE §12 forbids, so
> what is in a crate is now read off its `LootPrompt` ActionText ("Loot Gasoline") on approach instead of
> its colour at distance. **If that turns out to matter in play, the fix is a small painted stencil or a
> resource icon on the crate — NOT re-tinting the whole barrel.**"*

It turned out to matter in play. The prescribed direction is followed: mark the crate, do not repaint it.

## Why it is worse than "annoying"

> *"with 1 is not enough fuel to get to next station"*

Fuel is the one resource a run cannot continue without. The near camp is the **only** gasoline source
(the deep camp carries Metal + Ammo), so a missed gasoline crate is not a smaller haul — it is a
**stranded run**, caused by a search problem rather than by a fight the crew lost.

## Decisions (agreed via wizard)

| # | Question | Decision |
|---|---|---|
| 1 | How should a lootable read at distance | **Gold outline fading in ~40 studs, plus prompt range 10 → 14.** Gold is already the progression accent (STYLEGUIDE §4). No floating icons — the style guide asks for a quiet, uncluttered screen |
| 2 | The ~100-stud loot spread | ⚠️ **Leave it.** Walking the whole camp is what Job #100's "larger search area" asked for; the marker is what makes it fair. Explicitly NOT adding a third gasoline crate |

Decision 2 is a deliberate bet: **the marker has to actually work**, because it is now the only thing
standing between a wide search and a stranded run. That makes verification the substance of this job,
not a formality.

## Out of scope

- Re-tinting crates by resource (STYLEGUIDE §12, and the Job #077 note above forbids it).
- Changing how much fuel a landing yields — near camp stays 2 × Gasoline.
- The LOBBY place.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
