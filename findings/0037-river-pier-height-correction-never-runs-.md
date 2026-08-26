# FINDING 0037: River pier height correction never runs - measureDeckY always returns nil

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-26 19:27:56

**Symptom:** DockServer:202 calls measureDeckY(pier, pos), which does Workspace:Raycast against the pier. But buildPier is called at :244 from buildDock, and buildDock does not parent the dock model into Workspace until :381. So the pier is NOT a Workspace descendant when the rays are cast, every ray misses, measured is nil, and the DECK_Y correction at :203-205 never executes.

MEASURED IN PLAY (Job #120, dock at z=1600): the live pier's bounding-box min Y is 8.99999952, which is exactly WATER_Y - 3 = 9 - the provisional seat set at :188-191. Had the correction run, min Y would be 9 + (DECK_Y - measured). The walkable plank surface probes at Y 15.08 across a 7x5 grid, against the DECK_Y = 16 it is supposed to match: every river pier stands 0.92 studs lower than intended.

The file header (:25-28) is emphatic that 'the deck height is MEASURED, not assumed' and cites Job #076 burying camp props by 2.4 studs. That machinery is present and correct but is never reached.

NOT FIXED IN JOB #120 deliberately: raising every pier 0.92 studs moves where the boat sits relative to the pier and where players stand, which is a world change the sign job was not asked to make. Job #120 measures the real surface AFTER parenting instead, so its sign seats correctly either way.

Fix would be: parent the dock model into docksRoot before calling buildPier, or have buildPier take the already-parented model. Then re-verify boat clearance and the DECK_Y basin-floor note at :110.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
