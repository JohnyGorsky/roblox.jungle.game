# TODO 0024: REQUIRED (Job 068 E): Run the live greybox sweep on the LOBBY place

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:56

Audit Job 068, Part E -- the one item that BLOCKS the audit. Needs Studio open on the LOBBY place with the MCP connected. lobby/build/greybox_placement.luau BUILDS the stand-ins, and every replacement since is described as "localized to AssetLibrary and placed" -- phrasing that does not guarantee the greybox original was deleted rather than left underneath. Full per-object sweep table (name, line number, expected replacement) is in Jobs/068/intake.md Part E. TRAP -- five greybox parts are LOAD-BEARING and must survive or be re-pointed: PartyPad_*.Center (LobbyServer:48 pad detection), Dock.Pier (LobbySoundscape:101 water loop), both FirePit parts (LobbySoundscape:108 campfire crackle), Leaderboard_TopRuns.Board (RankServer:127 live Top-10), and the Watchtower_NW/_NE MODEL NAMES (LobbySoundscape:114 rope creak). Also verify live: Lighting.Technology=Future is SAVED into the place (ASSETS.md 1.14 warns it resets), boat meshes imported + preparePaintLibrary() run and saved or liveries render flat, and the known RampBow square-footprint defect (ASSETS.md 2).
