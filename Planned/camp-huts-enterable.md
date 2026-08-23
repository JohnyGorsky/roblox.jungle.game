# Make the CAMPS' own huts enterable too

**Deferred out of Job #108, deliberately — not forgotten.**

Job #108 made the 6–10 *outlying* village huts enterable: it measured each Bahay Kubo's single doorway
and its 3.5–4.6-stud floor rise (`CampDefs.VILLAGE.door`) and builds two treads at that doorway
(`buildVillageHut` in `ExcursionServer`). The buildings **inside** a camp — placed by `buildCampAt` from
`CampLayout.buildings` — did not get that treatment, so a landing site now has enterable houses on its
outskirts and sealed ones at its centre.

## Why it was left out

Two real reasons, both worth knowing before picking this up:

1. **Camp buildings are yawed to face the fire** (`prop(model, …, { faceTo = firePos })`), so their
   doorway points wherever the mesh's door happens to end up relative to the fire — sometimes straight
   at the sandbag ring. Making them enterable properly means deciding whether "faces the fire" should
   mean *the door* faces the fire, which changes how every existing camp looks.
2. **The treads are solid parts inside a fought-in space.** In the village they stand in open ground; in
   a camp they land among the perimeter, the guard posts and the loot slots, none of which know about
   them. That wants a separation check, not a one-line call.

## The work

- Call the same tread builder for `L.buildings` in `buildCampAt`, sourcing rise/bearing from
  `CampDefs.VILLAGE.door` (rename that table if it stops being village-only).
- Decide the yaw question above. If the door should face the fire, `CampLayout` gains a per-building
  door bearing and `prop`'s `faceTo` is no longer the right knob for buildings.
- Feed the tread footprint into `CampLayout`'s `taken` list so sandbags, loot and ambient clutter stop
  spawning on the steps.
- Consider whether camp huts should hold anything. Job #108's salvage stashes were sized against a
  village of 6–10; repeating them in every camp building is a second economy decision, not a free one.

## Verify

Walk in — Edit is not evidence. Failure looks like: a doorway you still have to jump into, treads
standing inside a sandbag segment, or a door opening onto the fence with no way round.
