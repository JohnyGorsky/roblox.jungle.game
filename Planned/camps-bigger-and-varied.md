# Camps — bigger, varied, and worth searching

**Source:** user feedback, 2026-08-18. **Relates:** [land-excursions-camps-villages.md](land-excursions-camps-villages.md)
(the original camp concept), `sync/ServerScriptService/World/CampDefs.luau`, `Excursion/ExcursionServer`.

## The complaint, in the user's words

> *"Base camps must be larger. Right now they are repetitive and I do not feel like finding things. They
> are in the same position constantly. So more houses, items into houses. Larger search area."*

Three distinct problems in one sentence, worth separating because they have different fixes:

1. **Repetition** — every camp reads the same.
2. **Fixed placement** — loot sits in the same spot every run, so there is nothing to *find*. Once you
   have played twice you walk a memorised route.
3. **Scale** — the search area is too small to feel like exploration.

## Why it matters

Camps are the game's only break from driving, and GAME.md's pitch is "ride → reach a dock → scavenge →
ride further". If scavenging is a memorised loop, the middle third of the core loop stops being
gameplay. It is also directly a **retention** problem — the `game-design` skill's replayability section
is the reference here: a set-piece that is identical every run is the thing players stop coming back for.

Dead Rails (our north star) gets this right: towns are assembled from parts, so the shape of the raid
changes even though the vocabulary is familiar.

## Direction (to be designed properly, not assumed)

- **More buildings per camp**, and **interiors worth entering** — loot inside houses rather than in the
  open, so searching is an act rather than a glance.
- **Procedural layout from a kit** — seeded assembly of a handful of building/prop pieces so no two
  camps are laid out alike, rather than one hand-placed arrangement reused.
- **Randomised loot placement** within the camp, so the route is discovered each time.
- **Larger footprint** — a real search area, with sightlines that hide things.

## Open questions

- Fully procedural, or hand-built variants picked at random? (Cheaper, less varied, and the ground rules
  say hero terrain is hand-built — camps may sit on the same line.)
- How does size interact with the **mobile perf budget** (STYLEGUIDE §8/§10)? More buildings and
  interiors is more draw calls and more streaming, on the platform we are hard-committed to.
- Does loot density scale with camp size, or stay fixed so bigger camps are *longer* rather than *richer*?
- Interiors mean doors, occlusion and possibly indoor lighting — how far do we take it?

## Pairs with

[camps-defended-not-infested.md](camps-defended-not-infested.md) — enemies arriving from outside rather
than spawning inside. The two are the same set-piece seen from different angles and should probably be
one job, or two jobs run back to back.
