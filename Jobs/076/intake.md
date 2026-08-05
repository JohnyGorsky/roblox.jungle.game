# Job #076: River terrain + 3-band foliage generation with real assets

**Project**: `roblox.jungle`
**Created**: 2026-08-05 20:36:09
**Status**: Plan written — awaiting go-ahead. See [`implementation-plan.md`](implementation-plan.md).

## Settled before planning

- **Reuse the existing library — no new assets.** The hand-built starting area is the target look and is
  built entirely from `ServerStorage.AssetLibrary`, which proves the set is sufficient.
- **The alley is SPARSE, not dense** (revises the first wizard answer). This is what makes the two
  63/65-part palms affordable as accents.
- **Band 2 = individual palms; band 3 = `JungleTreesPack` tiled as a canopy wall.**
- **Scope:** terrain materials + three foliage bands + river obstacles. Camp structures and enemies are
  separate jobs; camp *foliage* is folded in (see the plan's Part 5 note).

## Requirements / goal

Replace the greybox jungle with real models, banded by distance from the water. Each bank splits into three bands: FIRST LINE (near shore) = BushPack, FernTall, LogMossy, PalmCoconut, PalmCurved, PalmLowPoly; SECOND LINE = JungleTreesPack, PalmTall; THIRD LINE (back) = mostly JungleTreesPack. Rocks (RockA/B/C) scatter across all bands. All placement randomised off the river seed. Terrain materials: SAND on the shore strip, Grass + LeafyGrass through the jungle (riverbed is currently Grass, and no Sand exists anywhere). Shore palms are placed as an ALLEY that leans out over the river so the channel reads as a tunnel of palms. Remove the greybox scatter and greybox props from the map and use the real AssetLibrary models. Audit what foliage/prop assets already exist, and list any new ones needed. Perf is the central constraint: PalmTall and PalmCurved are 65- and 63-PART models and JungleTreesPack is a 218-stud 112-instance cluster, against a live window of ~816 scatter slots today.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Asset audit done — conclusion: **nothing new needed**
- [x] Implementation plan created — [`implementation-plan.md`](implementation-plan.md)
- [ ] Plan agreed (awaiting go-ahead)
- [ ] Implementation completed
- [ ] Final summary + changelog written
