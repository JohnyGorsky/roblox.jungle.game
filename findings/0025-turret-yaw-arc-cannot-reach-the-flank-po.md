# FINDING 0025: Turret yaw arc cannot reach the flank position the sea AI is coded to seek

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 17:16:43

**Symptom:** EnemyServer:463-469 deliberately steers sea creatures to a flank point FLANK_DIST=12 studs off the hull's side ('attack from the boat's SIDE, not underneath it'). A crocodile 12 studs abeam at amidships bears about 124 deg off the bow, but the turret's YAW_LIMIT is 80 deg (GunServer:21, GunClient:16) - roughly 44 deg outside the traverse arc. The mounted gun therefore cannot point at the game's primary boat-attacking enemy in the position that enemy is coded to seek, and Crocodile.biteRange is 16 (EnemyDefs:71) so it is biting the hull from there. Widening ELEVATION does not touch this. Found by the Job #105 reviewer agent.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
