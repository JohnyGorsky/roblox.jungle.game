# TODO 0054: Enemies can be sniped from outside their aggro/leash - no risk

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-17 16:14:28

User 2026-08-17: 'why enemies only chase small radius, with weapons it can be exploited easy, because they not running towards you'. MEASURED FROM THE DEFS, not guessed: gun range is 350 (GunServer.GUN_RANGE) / 220 (WeaponServer def default), while camp guards aggro at def.aggroRadius=95 and are hard-clamped to GUARD_LEASH=55 studs from their camp anchor (ExcursionServer :39, :1482). Riverbank land enemies are the same shape: aggroRadius 95 with LAND_LEASH=65 (EnemyServer :37). So a player standing ~110+ studs out is untouchable BY CONSTRUCTION and can empty a magazine into a camp with zero risk - the weapon outranges the enemy's maximum possible reach by 4-6x. Sea enemies aggro further (croc 150, piranha 120, hippo 130) but the land/camp fight is the exploitable one. NEEDS A DESIGN DECISION, not a blind number bump: raising the leash lets guards abandon camp and trail you to the boat; raising aggro alone just means they run to the end of a 55-stud rope and stand there being shot. Options to weigh: leash scaled to weapon range, a return-and-regen behaviour, ranged return fire (todo 0012), or damage taken from outside the leash pulling the whole camp.
