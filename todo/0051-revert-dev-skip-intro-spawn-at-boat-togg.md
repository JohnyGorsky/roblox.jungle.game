# TODO 0051: REVERT: dev skip-intro + spawn-at-boat toggle

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 23:21:23

TEMPORARY TESTING AID, added 2026-08-16 at the user's request during Job #087 so the boat can be reached in seconds instead of sitting through the plane-crash cold-open every Play. THE USER ASKED FOR THIS TO BE REVERTED LATER - that is what this todo tracks.

WHAT WAS ADDED (two places, both marked with the same marker comment 'DEV ONLY (todo 0051)'):
  1. sync/ServerScriptService/Intro/PlaneServer.server.luau - a DEV_SKIP_INTRO flag near the top that early-returns exactly the way the existing missing-helper path does (sets IntroActive=false and returns), so no other system has to know the intro was skipped.
  2. sync/ServerScriptService/Dev/DevSpawnAtBoat.server.luau - NEW FILE. On spawn, moves the character next to the moored boat at SpawnBase.Dock.BoatPlace.

BOTH ARE GUARDED BY RunService:IsStudio() AS WELL AS THEIR FLAG, so a published server can never take either path even if someone leaves the flags on. Same belt-and-braces pattern as USE_MOCK_IN_STUDIO in Defender's UserDataStorage.

  3. sync/ServerScriptService/Boat/BoatServer.server.luau - DEV_BUOYANCY_SLIDE flag (added 2026-08-17). Bisect aid for Job #087: replaces the buoyancy SPRING with a velocity-level hold at the water line, so the boat glides instead of floating. ⚠️ THIS IS A DIAGNOSTIC, NOT A FIX, AND MUST NOT SHIP - it is server-authored kinematic control of the vertical axis and discards real buoyancy (wave response, float dynamics). It exists only because it PROVED the spring is the remaining cause of the ride shake. It stays on until the real spring fix lands.

NO LONGER IN THIS LIST: the boat camera. What began as a DEV_DISABLE_BOAT_CAM bisect toggle became a PERMANENT DESIGN DECISION on 2026-08-17 - the chase camera is retired and the boat uses Roblox's default camera, with the speed-based FOV kept as BoatSpeedFov.local.luau. The flag is now `USE_CHASE_CAMERA = false` in BoatCamera.local.luau, deliberately NOT Studio-gated because it is shipped behaviour. Nothing to revert there.

TO REVERT WHAT REMAINS: delete DevSpawnAtBoat.server.luau, delete the DEV_SKIP_INTRO block from PlaneServer, and delete the DEV_BUOYANCY_SLIDE branch from BoatServer once the real buoyancy fix exists. Search the codebase for 'todo 0051' to find every touched line.
