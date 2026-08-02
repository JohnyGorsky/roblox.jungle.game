# TODO 0040: OPTIONAL (Job 068 E6): Verify Lighting.Technology = Future by eye and SAVE the place

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 11:32:49

Found by the Job 068 live sweep, 2026-08-02. Lighting.Technology CANNOT be read from the MCP execution context ("lacking capability RobloxScript"), so the sweep could not confirm it. ASSETS.md 1.14 requires Future and warns "Save the place or it resets". Check it by eye in Studio Lighting properties. All the rig OBJECTS are confirmed present (Sky, Atmosphere, ColorCorrection JungleCC, Bloom, SunRays, DepthOfField) and the water is tinted muted teal (24,78,86), so only the Technology enum and the saved-state are unverified. Whether the rig is persisted is only answerable by reopening the place.
