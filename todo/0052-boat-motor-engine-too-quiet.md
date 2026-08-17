# TODO 0052: Boat motor engine too quiet

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-17) — Fixed 2026-08-17 in BoatSound.local.luau: IDLE_VOL 0.16->0.34, MAX_VOL 0.62->1.0, ROLL_MIN 12->30 (whole deck now inside the full-volume radius). NEEDS AN EAR CHECK in a playtest - if it is now too loud, drop MAX_VOL first and leave ROLL_MIN alone.
**Created:** 2026-08-17 15:49:53

User 2026-08-17: 'we need louder motor boat, it is too quiet. I cant here it.' Two causes in BoatSound.local.luau: (1) MAX_VOL ceiling was only 0.62, IDLE_VOL 0.16; (2) the real one - the engine loop is parented to Motor at the STERN of a 32-stud hull and RollOffMinDistance was 12, so the driver (listener = CAMERA) sat OUTSIDE the full-volume radius and every attenuation stacked on a low ceiling.
