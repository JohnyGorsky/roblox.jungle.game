# Camps — defended from outside, not infested from within

**Source:** user feedback, 2026-08-18. **Relates:**
[camps-bigger-and-varied.md](camps-bigger-and-varied.md), `World/CampDefs.luau`,
`Excursion/ExcursionServer` (`CampGuard`), the `roblox-ai` skill.

## The complaint, in the user's words

> *"When players are in camp, enemies must not spawn inside camp — they must spawn from outside and move
> to their positions. Also around camp we can set sandbags etc."*

## Two changes, and the second is the interesting one

### 1. Enemies arrive, they do not appear

Spawning a guard **inside** the camp while the crew is standing in it is the single most immersion-
breaking thing a raid can do — it reads as a bug even when it is working as designed, and it removes any
possibility of *seeing them coming*. Guards should spawn **outside the camp perimeter** and path in to
their posts.

Consequences worth planning for rather than discovering:
- Needs a **perimeter** concept — a camp radius, and spawn points on or beyond it.
- Needs **pathfinding in** to a post (the `roblox-ai` skill covers PathfindingService, posts, and the
  idle/patrol/chase loop). Guards currently exist at their posts from the start.
- Raises a **timing** question: are guards present when the crew arrives, or do they respond to the
  crew's arrival? "Already posted, reinforcements arrive from outside" is probably the answer, but it
  is a design decision with a big feel difference.

### 2. Sandbags and fortification around the camp

Not just decoration. A defended perimeter gives the camp:
- **A readable edge** — you can see where the camp starts, which the current open layout lacks.
- **Cover** for both sides, which turns a raid into a fight with shape instead of an open-field trade.
- **A reason the loot is here** — it looks held, not scattered.

`SandbagWall` already exists as a model and is used heavily at the crash site (`Workspace.SpawnBase` has
dozens), so the vocabulary is in the game already and does not need sourcing.

## Open questions

- Do guards **respawn** during a raid (a siege), or is the camp cleared once cleared? Big difference to
  pacing and to whether hauling loot back is tense or safe.
- Should the perimeter have **gaps/entrances**, making approach direction a choice? That would pair well
  with a larger camp.
- Does the arriving-from-outside rule apply to **night** raids too, where visibility is much lower and
  "you can see them coming" stops being true?
- Perf: pathfinding several guards in from a perimeter is more expensive than placing them. Mobile
  budget applies (`roblox-optimization`).

## Pairs with

[camps-bigger-and-varied.md](camps-bigger-and-varied.md). A bigger camp with an undefended edge and a
defended small camp are both half-answers — these two probably want to be one job, or two run back to
back, so the layout and the defence are designed against each other.
