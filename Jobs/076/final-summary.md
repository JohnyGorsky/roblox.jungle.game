# Job #076 - Final summary

**River terrain materials + 3-band foliage generation from the real asset library.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

The greybox jungle is gone. `FoliageDefs` (the content table) + `FoliageServer` (the placer) generate
three bands out from each bank, all randomised off the river seed so the world is reproducible:

- **First line** (shore) - BushPack, FernTall, LogMossy, PalmCoconut, PalmCurved, PalmLowPoly
- **Second line** - JungleTreesPack, PalmTall
- **Third line** (back) - mostly JungleTreesPack as a canopy wall
- Rocks (RockA/B/C) scattered across all bands

Terrain materials are painted with it: sand on the shore strip, Grass/LeafyGrass through the jungle.

Live console every run:

```
[Foliage] spawn-base exclusion: X -636..124 Z -593..49 (1596 parts, +40 margin)
[Foliage] banded jungle online - 39 models in library, ~5690 PARTS live in a 1020-stud window
```

**No new assets were needed** - the audit's conclusion held. The hand-built starting area had already
proved the existing library was sufficient.

## Perf, which was the whole constraint

The intake flagged the risk plainly: `PalmTall` and `PalmCurved` are 65- and 63-**part** models and
`JungleTreesPack` is a 218-stud, 112-instance cluster. The shipped answer is a **sparse** shore alley -
which is what makes those two palms affordable as accents - against a measured ~5,690 live parts in a
1,020-stud window. The spawn-base exclusion box keeps generated foliage out of the hand-built area.

WARNING: that ~5,690 figure is the number to watch. Any future band change should be re-measured on a
real device, not estimated - the models differ by roughly 60x in part count.

## Not verified

No mobile-device frame measurement was ever taken. The part count is known; its cost on a phone is not.
