# TODO 0046: Wolves swim in open water; land enemies should hold the bank / bases

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-16) — Job #086. Land creatures are clamped to their own bank (BANK_MARGIN) and seated on raycast ground height; Wolf moved off LAND_POOL to the deep camp as a CampGuard; Boar hp 40->50 to hold the bank's difficulty.
**Created:** 2026-08-16 22:11:44

Observed in a Studio playtest (screenshot 2026-08-16): a Wolf glided across open river at water level, straight at the boat.

ROOT CAUSE (verified in code, not guessed): land enemies are not land-bound at all. sync/ServerScriptService/Enemies/EnemyServer.server.luau:184 -- stepToward() builds every move as Vector3.new(x, WATER_Y, z), for BOTH categories. The land spawner (line ~447) also anchors them at WATER_Y, only 8-20 studs past the bank edge. With LAND_LEASH = 65 a wolf can lunge ~45+ studs INTO the channel, floating at water height the whole way. Nothing clamps a land creature to the shore or to terrain height.

USER INTENT (2026-08-16): wolves belong at camps/bases, not roaming the bank as free ambushers.

So there are two separable changes: (a) land creatures must follow ground height and never enter water; (b) reconsider whether Wolf stays in LAND_POOL (EnemyServer:343) at all, or becomes camp/base fauna like Bandit already is (Bandit is deliberately excluded from the bank pool and spawned by ExcursionServer as a CampGuard -- that is the existing precedent to copy).

ALSO IN THE SCREENSHOT, unconfirmed: a dark shape on the deck by the mounted turret, circled by the user. Could be an enemy that reached the boat. Needs identifying before it is written up.
