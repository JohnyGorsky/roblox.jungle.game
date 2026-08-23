# FINDING 0028: Start junction has a lateral notch the editor hides

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 22:17:14

**Symptom:** MEASURED in Edit, Job #110. The SpawnBase sculpt runs z=-898 to z=+28 - it overshoots the junction plane by ~28 studs. RiverGenerator.chunkRegion(0) spans z[0..256], so that apron is OVERWRITTEN by generated terrain at runtime, every run. The apron is also the only part of the sculpt wide enough to meet the generator: at z=+0..16 sculpt land spans x[-558..+398], but at z=-4 (the last slice the generator cannot touch) it spans only x[-558..+298]. Generated land reaches x[-398..+390]. So once the generator runs, the +X side of the start junction has a ~92-stud strip where generated land at x +298..+390 has no sculpted land behind it. In Edit the apron fills the notch, which is why it looks sealed there. NEEDS PLAY VERIFICATION - Edit is not evidence. Same defect mirrors onto the new end junction (-X side, ~100 studs), where it will be sculpted out as part of Job #110.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
