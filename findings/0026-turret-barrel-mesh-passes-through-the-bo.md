# FINDING 0026: Turret barrel mesh passes through the bow at high depression

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 17:31:47

**Symptom:** Measured in Play (Job #105). The GunBarrel host is 8 studs and pivots at GunBase (hull-local Y 4.8, Z -11), so the ~4.6-stud barrel SKIN (BoatParts:147-154) rides 4 studs forward of the pivot. Depressed, it swings down into the bow stem: at the OLD -12 deg stop the skin centre sat hull-local Y 3.97 at Z -14.91, already 0.55 studs BELOW the hull skin's top edge (4.52) and 1.09 studs from the bow tip; at the new -22.6 deg stop it is Y 3.26, i.e. 1.26 studs below. Confirmed visually with an A/B from the same external camera at 0 / -12 / -22.6 deg: the barrel jacket is seen emerging through the foredeck. PRE-EXISTING, made ~0.7 studs deeper by #105. NOTE: a raycast cannot detect this - Hull.Skin_hull has CanQuery=false, so rays pass straight through and report a false 'clear'. Likely fix: restore the +1.2 Y pivot lift that GunServer:91 builds the barrel with but BoatTurretVisual:75 drops when re-posing it.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
