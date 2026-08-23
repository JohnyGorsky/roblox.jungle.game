# FINDING 0027: Snow-capped hills flank the tropical river

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 22:12:24

**Symptom:** RiverGenerator paints SNOW_Y=40+ as Enum.Material.Snow, and HILL_MAX=42 puts bank hills at y up to 64 (measured y=42 Snow at x=+-320..390 on the z=18000 cross-section). So snow-capped peaks flank the river along any stretch where hills clear y=40 - in a stylized TROPICAL jungle. Found while measuring the end junction in Job #110; affects the whole generated corridor, not just the end. Fix is probably to raise SNOW_Y above the reachable max (>64) or drop the Snow band entirely and cap with Rock/LeafyGrass.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
