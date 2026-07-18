--!strict
-- EnemyDefs.luau — enemy stat definitions + time-of-day strength (Jobs 006 → 009).
--
-- Data-driven threat system (GAME.md "Threats"): every enemy has a `category` ("sea"/"land").
-- `strengthFor(category, phase)` scales bite damage + spawn rate by time of day — SEA threats peak at
-- NIGHT, LAND threats by DAY — so the day/night cycle flips where the danger is.

export type EnemyDef = {
	name: string,
	category: string, -- "sea" | "land"
	hp: number,
	speed: number, -- studs/s move speed
	aggroRadius: number,
	biteRange: number,
	biteDamage: number,
	biteCooldown: number, -- seconds
	color: Color3,
	size: Vector3,
}

local EnemyDefs = {}

EnemyDefs.Defs = {
	-- sea: swims the open channel, chases the boat; deadliest at night
	Crocodile = {
		name = "Crocodile",
		category = "sea",
		hp = 40,
		speed = 15, -- slower than the boat's top (~30) so full throttle escapes; still catches a dawdler
		aggroRadius = 150,
		biteRange = 16,
		biteDamage = 8,
		biteCooldown = 1.5,
		color = Color3.fromRGB(58, 86, 54),
		size = Vector3.new(6, 3, 16),
	},
	-- land: ambushes from the bank (leashed), fast lunge; most active by day
	Panther = {
		name = "Panther",
		category = "land",
		hp = 55,
		speed = 26,
		aggroRadius = 95,
		biteRange = 14,
		biteDamage = 12,
		biteCooldown = 1.8,
		color = Color3.fromRGB(32, 28, 36),
		size = Vector3.new(5, 4, 11),
	},
} :: { [string]: EnemyDef }

-- time-of-day strength multiplier (applied to damage + spawn rate)
function EnemyDefs.strengthFor(category: string, phase: string): number
	if category == "sea" then
		return if phase == "night" then 1.5 else 1.0
	elseif category == "land" then
		return if phase == "day" then 1.5 else 0.6
	end
	return 1.0
end

return EnemyDefs
