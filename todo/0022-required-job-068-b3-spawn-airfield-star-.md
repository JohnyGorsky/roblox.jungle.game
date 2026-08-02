# TODO 0022: REQUIRED (Job 068 B3): Spawn airfield star is still a greybox cream cylinder

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:31

Audit Job 068, gap B3. ASSETS.md 1.8 lists the painted military star as pending (user) -- the decal was never generated. What is actually in the place is greybox_placement.luau:55: a cream SmoothPlastic cylinder named Star, 11 studs across, on the spawn pad. This is the first thing every player sees on join. Also confirm whether Spawn.Pad (sand cylinder, 26 studs) is intentional or greybox. Options: generate the decal, or drop the star and let the sand pad stand alone.
