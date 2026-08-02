# TODO 0037: REQUIRED (Job 068 E2): Dock water-lapping sound never attaches -- LobbySoundscape looks up the wrong path

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 11:32:33

Found by the Job 068 live sweep, 2026-08-02. LobbySoundscape.server.luau:100-104 does Scenery.Dock:FindFirstChild("Pier"). The Store dock model is nested one level deeper -- the real path is Scenery.Dock.Dock.Pier -- so the lookup returns nil, waterCount stays 0, and NO water-lapping loop is ever created at the dock. ASSETS.md 1.11 claims it is wired; it is not. Invisible from disk, only the live tree shows it. One-line fix: FindFirstChild("Pier", true) for a recursive search, or re-point at the nested model. Verify by re-running and checking the [LobbySoundscape] print reports water x1.
