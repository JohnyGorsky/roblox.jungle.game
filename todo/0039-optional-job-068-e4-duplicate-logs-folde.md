# TODO 0039: OPTIONAL (Job 068 E4): Duplicate Logs folder, doubled post-effects, empty Upgrades folder

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 11:32:49

Found by the Job 068 live sweep, 2026-08-02. Three small place-hygiene items. (1) TWO Scenery.Logs folders, 6 and 8 children = 14 logs; ASSETS.md 1.1 specifies LogMossy x2, "6 near tree line", so the 8-child folder looks like an accidental second copy. (2) Lighting has DOUBLED post-effects -- Bloom AND JungleBloom (both BloomEffect), SunRays AND JungleSunRays (both SunRaysEffect). Two of each stack, a real mobile-perf and look cost; decide which pair is canonical and delete the other. Full Lighting children: Sky, Atmosphere, DepthOfField, JungleCC, Bloom, JungleBloom, SunRays, JungleSunRays. (3) Workspace.LOBBY_GREYBOX.Upgrades is an empty folder.
