# TODO 0054: Enemies can be sniped from outside their aggro/leash - no risk

**Project:** `roblox.jungle`
**Status:** open — **camp half fixed in [Job #090](../Jobs/090/)**; riverbank land enemies still exposed

> ✅ **Camps (2026-08-17, Job #090):** any hit from any range now alerts the whole camp for 15 s —
> guards ignore `aggroRadius` and their leash opens 55 → 250, then they walk home. Damage escalates;
> sight does not.
>
> ⏳ **Still open — the riverbank.** `EnemyServer` land enemies have the identical shape
> (`aggroRadius` 95 vs `LAND_LEASH` 65) and were deliberately left alone: the decision taken was
> camp-specific, and a lone bank ambusher has no camp to pull. Needs its own call, because on a moving
> boat the trade-offs are different — a boar that chases 250 studs into open water is not obviously
> better than one that gives up.

**Created:** 2026-08-17 16:14:28

User 2026-08-17: 'why enemies only chase small radius, with weapons it can be exploited easy, because they not running towards you'. MEASURED FROM THE DEFS, not guessed: gun range is 350 (GunServer.GUN_RANGE) / 220 (WeaponServer def default), while camp guards aggro at def.aggroRadius=95 and are hard-clamped to GUARD_LEASH=55 studs from their camp anchor (ExcursionServer :39, :1482). Riverbank land enemies are the same shape: aggroRadius 95 with LAND_LEASH=65 (EnemyServer :37). So a player standing ~110+ studs out is untouchable BY CONSTRUCTION and can empty a magazine into a camp with zero risk - the weapon outranges the enemy's maximum possible reach by 4-6x. Sea enemies aggro further (croc 150, piranha 120, hippo 130) but the land/camp fight is the exploitable one. NEEDS A DESIGN DECISION, not a blind number bump: raising the leash lets guards abandon camp and trail you to the boat; raising aggro alone just means they run to the end of a 55-stud rope and stand there being shot. Options to weigh: leash scaled to weapon range, a return-and-regen behaviour, ranged return fire (todo 0012), or damage taken from outside the leash pulling the whole camp.
