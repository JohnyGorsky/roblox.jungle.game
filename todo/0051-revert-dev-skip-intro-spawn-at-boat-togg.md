# TODO 0051: REVERT: dev skip-intro + spawn-at-boat toggle

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 23:21:23

TEMPORARY TESTING AID, added 2026-08-16 at the user's request during Job #087 so the boat can be reached in seconds instead of sitting through the plane-crash cold-open every Play. THE USER ASKED FOR THIS TO BE REVERTED LATER - that is what this todo tracks.

WHAT WAS ADDED (two places, both marked with the same marker comment 'DEV ONLY (todo 0051)'):
  1. sync/ServerScriptService/Intro/PlaneServer.server.luau - a DEV_SKIP_INTRO flag near the top that early-returns exactly the way the existing missing-helper path does (sets IntroActive=false and returns), so no other system has to know the intro was skipped.
  2. sync/ServerScriptService/Dev/DevSpawnAtBoat.server.luau - NEW FILE. On spawn, moves the character next to the moored boat at SpawnBase.Dock.BoatPlace.

BOTH ARE GUARDED BY RunService:IsStudio() AS WELL AS THEIR FLAG, so a published server can never take either path even if someone leaves the flags on. Same belt-and-braces pattern as USE_MOCK_IN_STUDIO in Defender's UserDataStorage.

  3. sync/StarterPlayer/StarterPlayerScripts/Boat/BoatCamera.local.luau - DEV_DISABLE_BOAT_CAM flag (added 2026-08-17). Bisect aid for Job #087 Phase 2: `true` leaves the player on Roblox's DEFAULT camera when they sit in the boat, to answer whether the shake is the BOAT moving or the CAMERA moving. Bails out of startCam BEFORE touching CameraType, so the camera is never left Scriptable with nothing driving it.

TO REVERT: delete DevSpawnAtBoat.server.luau, and delete the DEV_SKIP_INTRO and DEV_DISABLE_BOAT_CAM blocks. Search the codebase for 'todo 0051' to find every touched line.
