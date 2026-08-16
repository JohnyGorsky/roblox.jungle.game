# TODO 0049: Tied boat is not safe: player still downed, and the boat still takes damage

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-16) — Job #086. Decided: a mooring is safe from the river only - camp guards are exempt by design. Boat half was never a bug (no code path damages a tied boat). Job #084's changelog line corrected.
**Created:** 2026-08-16 22:14:57

Reported 2026-08-16 playtest (screenshot): YOU ARE DOWN while moored at the trading post, with BOAT 0%.

ROOT CAUSE, the player half (verified): the tied-dock safe zone exists ONLY in the wildlife director. EnemyServer.server.luau:281 computes 'suppressed = tiedNow and flatDist(...) <= TIED_SAFE_RADIUS' and gates both chasing (:287) and biting (:328) on it. But CAMP GUARDS are a completely separate system -- ExcursionServer.server.luau -- and the string 'Tied' does not appear in that file AT ALL. ExcursionServer:1475 subtracts bite damage straight off the player's char HP with no tie check. So mooring calms the crocs and does nothing about the raiders, which is exactly the reported experience.

THE BOAT HALF IS NOT A BUG -- resolved by tracing every write to the boat's HP attribute:
  - EnemyServer.server.luau:218 (wildlife) is gated on `not suppressed` at :328, and a boat-targeting
    creature measures suppression at distance 0 from the hull, so it is ALWAYS suppressed while tied;
  - ObstacleServer.server.luau:37 returns early on `Tied == true` before any damage -- an earlier note
    in this file wrongly flagged :51 as unguarded. Corrected.
  - camp guards subtract from the PLAYER's char HP only (:1475), never the hull;
  - CargoServer:136 and BoatModules:384 only ADD HP (repair).
So no code path can damage a moored boat. The BOAT 0% in the screenshot was damage taken BEFORE tying
up -- the boat was already wrecked when it moored. Only the player half below is a real defect.

DESIGN QUESTION for the plan: is a tied boat meant to be safe from EVERYTHING, or safe from the river only? Job #084's changelog promises 'Docks are a genuine safe zone', which reads as everything -- but camps are supposed to be dangerous, and the trading post sits between the shore and the near camp. Needs a decision, not a guess.
