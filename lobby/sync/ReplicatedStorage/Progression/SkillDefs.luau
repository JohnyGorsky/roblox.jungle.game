--!strict
-- SkillDefs.luau — skill tree catalog + cost ladder (Job 024, design Job 020 §4). Shared client/server.
-- Skills are per-player, bought in the lobby with Gold, applied to the boat/crew in-game. IDENTICAL in both trees.

export type SkillDef = { name: string, group: string, per: number, unit: string, blurb: string }

local SkillDefs = {}

SkillDefs.MAX_LEVEL = 10

SkillDefs.Order = { "motors", "rudder", "hull", "diesel", "cargo", "repair", "refuel", "medic", "gun", "scavenge" }

SkillDefs.Defs = {
	-- Boat skills (wired now — attribute effects, applied at max crew level)
	motors = { name = "Twin Motors", group = "Boat", per = 3, unit = "% top speed", blurb = "Faster boat." },
	rudder = { name = "Rudder Tuning", group = "Boat", per = 2.5, unit = "% turn rate", blurb = "Sharper turning." },
	hull = { name = "Hull Plating", group = "Boat", per = 5, unit = " boat HP", blurb = "Tougher hull." },
	diesel = { name = "Diesel Efficiency", group = "Boat", per = 2.5, unit = "% less fuel", blurb = "Burns less fuel." },
	cargo = { name = "Cargo Rigging", group = "Boat", per = 5, unit = "% capacity", blurb = "Carry more loot." },
	-- Crew skills (persisted + exposed now; deep-wired later)
	repair = { name = "Field Repair", group = "Crew", per = 5, unit = "% repair speed", blurb = "Repair the hull faster." },
	refuel = { name = "Fuel Handling", group = "Crew", per = 5, unit = "% refuel speed", blurb = "Refuel faster." },
	medic = { name = "Combat Medic", group = "Crew", per = 4, unit = "% revive speed", blurb = "Revive teammates faster." },
	-- ⚠️ Job #117 / #118 — THIS SKILL DOES NOT APPLY TO EITHER PAID WEAPON, and the blurb is therefore
	-- slightly generous. Deliberate, and the user's call both times.
	--
	-- `WeaponServer` multiplies a gun's `fireInterval` by `0.965 ^ level`. On a weapon whose cycle IS its
	-- design that is a silent bug, not a buff:
	--   · M16     — the 2 s burst lockout becomes 1.401 s at level 10, overlapping two bursts
	--               (~6 extra bullets, ~84 extra damage, nothing in the log).
	--   · Bazooka — the 5 s reload would become 3.503 s, against a requirement of "a hard 5-second
	--               reload, identical for every player".
	-- Rather than stack a paid skill on top of a paid weapon, both keep a flat latch for everyone
	-- (`WeaponServer.lockUntil`, which nothing scales). Pistol, Shotgun and the turret are unchanged.
	--
	-- ⚠️ It is exactly the kind of bug that survives testing: Studio dev profiles start empty by decision
	-- (`ProfileConfig`), and the usual fix for that is the admin panel's one-click "MAX ALL Skills" — so
	-- the tester is *guaranteed* to be in the broken case and unlikely to notice.
	gun = { name = "Gun Discipline", group = "Crew", per = 3.5, unit = "% faster fire", blurb = "Shoot faster (guns & turret)." },
	scavenge = { name = "Scavenger's Instinct", group = "Crew", per = 3, unit = "% loot", blurb = "More loot & nugget luck." },
} :: { [string]: SkillDef }

function SkillDefs.get(id: string): SkillDef?
	return SkillDefs.Defs[id]
end

-- Gold cost to buy `level` (i.e. going from level-1 → level). Ladder: round(4 · 1.3^(level-1)).
function SkillDefs.cost(level: number): number
	return math.round(4 * 1.3 ^ (level - 1))
end

-- total Gold spent to reach `level` from 0
function SkillDefs.cumulative(level: number): number
	local sum = 0
	for l = 1, level do
		sum += SkillDefs.cost(l)
	end
	return sum
end

return SkillDefs
