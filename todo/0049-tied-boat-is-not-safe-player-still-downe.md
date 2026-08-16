# TODO 0049: Tied boat is not safe: player still downed, and the boat still takes damage

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 22:14:57

Reported 2026-08-16 playtest (screenshot): YOU ARE DOWN while moored at the trading post, with BOAT 0%.

ROOT CAUSE, the player half (verified): the tied-dock safe zone exists ONLY in the wildlife director. EnemyServer.server.luau:281 computes 'suppressed = tiedNow and flatDist(...) <= TIED_SAFE_RADIUS' and gates both chasing (:287) and biting (:328) on it. But CAMP GUARDS are a completely separate system -- ExcursionServer.server.luau -- and the string 'Tied' does not appear in that file AT ALL. ExcursionServer:1475 subtracts bite damage straight off the player's char HP with no tie check. So mooring calms the crocs and does nothing about the raiders, which is exactly the reported experience.

The boat half needs confirming before it is written up. Wildlife cannot hit a tied boat (a boat-targeting creature measures suppression at distance 0 from the hull, so it is always suppressed while tied). The remaining candidates are ObstacleServer.server.luau:51, which subtracts boat HP with NO tie check, or damage taken before tying up. Guards damage players only (:1475), not the hull -- so 'they hit my boat' may be a mis-read of guard fire, or may be a real third path. Confirm in a playtest before deciding.

DESIGN QUESTION for the plan: is a tied boat meant to be safe from EVERYTHING, or safe from the river only? Job #084's changelog promises 'Docks are a genuine safe zone', which reads as everything -- but camps are supposed to be dangerous, and the trading post sits between the shore and the near camp. Needs a decision, not a guess.
