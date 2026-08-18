# Job #101 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: IMPLEMENTED — see final-summary.md

Intake: [intake.md](intake.md). Skills: `jungle-style` (the accent palette and the "quiet HUD" rule),
`mobile` (a marker has to survive a phone screen), `roblox-dev` (Highlight budget and DepthMode).

---

## 1. Decisions (agreed via wizard)

| # | Decision |
|---|---|
| 1 | **Gold outline that fades in, plus prompt range 10 → 14.** No floating icons — STYLEGUIDE asks for an uncluttered screen |
| 2 | ⚠️ **Leave the ~100-stud loot spread.** Walking the whole camp is what Job #100's "larger search area" asked for |
| 3 | ⚠️ **Glow range 40 → 60, decided later against measurement** — see §4. Decision 2 only survives if the marker actually reaches the loot |

## 2. Why a Highlight and not a repaint

`ExcursionServer`'s Job #077 note already ruled on this:

> *"the fix is a small painted stencil or a resource icon on the crate — NOT re-tinting the whole barrel"*

A `Highlight` adorns a model without touching its material or colour, so the barrel stays a weathered
wooden barrel (STYLEGUIDE §12) and only its *outline* carries the signal. It is also **screen-space**, so
the outline is the same thickness on a phone as on a desktop — which is why this approach survives the
mobile pillar where a world-space marker would not.

## 3. Architecture

### 3a. One tag is the contract

`CampDefs.TAG.lootable = "Lootable"`. The server tags **only** things a player can pick up:

- every crate that goes through `lootPrompt` (resource crates, weapon crate, weapon-ammo crate),
- the gold nugget, which builds its own prompt and so needs the tag applied by hand.

Camp dressing — the loose barrels and crates that look identical — is deliberately **not** tagged. That
asymmetry *is* the feature.

### 3b. `LootGlow.local.luau` (new, client)

10 Hz sweep over `CollectionService:GetTagged("Lootable")`:

- outside `RANGE` → highlight destroyed,
- inside → gold outline, transparency ramped over the last `FADE` studs so nothing pops in,
- nearest-first with a `MAX_GLOWS` cap, because Roblox degrades past ~31 rendered Highlights,
- highlight is parented **to the crate**, so it dies with the crate on loot or site cull.

### 3c. ⚠️ `XRAY` is the whole design in one number

Inside 18 studs the outline draws **through** walls; beyond it, geometry occludes it.

Job #100 puts loot behind cover on purpose — *"cover between the player and the crates is what makes the
guards matter"* — so an always-on-top outline would delete the search the camps were just rebuilt to
have. But the thing that stranded the run was a crate tucked behind a hut the player was **standing
next to**. So once you are close enough to be searching *this* corner, the wall stops hiding it; far
away you still have to walk the camp and look.

## 4. ⚠️ The gate this job turns on

Decision 2 makes the marker the **only** thing between a wide search and a stranded run. So the test is
not "does it glow" but **"does it glow where a player actually walks"** — measured by taking the real
route (shore → near fire → deep fire) and asking how far each lootable sits off that line.

If the answer is that loot stays dark on that route, decision 2 is wrong and either the range or the
spread has to move. That measurement is the substance of the job; see the summary.

## 5. Order of work

1. Confirm the premise before building anything — *are* both gasoline crates spawning?
2. Tag + prompt range (server), the smaller half.
3. `LootGlow` (client).
4. Verify tagging is exact: every lootable lit, no dressing lit.
5. Measure the fade curve and the x-ray switch by distance, not by eye.
6. Screenshot a real crate beside a decoy barrel — numbers cannot show "reads as loot".
7. Route measurement (§4), and re-tune if it fails.
