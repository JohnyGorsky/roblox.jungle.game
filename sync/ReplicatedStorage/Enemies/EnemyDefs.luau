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

-- ⚠️ GLOBAL DAMAGE SCALE — applied wherever a bite is dealt, not baked into the per-creature numbers.
--
-- Set to 0.8 (a flat 20% cut) on the user's call after camp fights proved unwinnable: *"i cant beat
-- them"*. Kept as one multiplier rather than editing six `biteDamage` values so the per-creature BALANCE
-- (a Croc bites for 20 where a Piranha bites for 4) is preserved exactly, and so this is one number to
-- turn if 20% proves to be the wrong amount.
--
-- Consumed by `EnemyServer` (river threats) and `ExcursionServer` (camp guards). Anything new that deals
-- bite damage must multiply by this too.
--
-- ⚠️ 20% was not enough. Cut a SECOND 20% on report that enemies "still hit too hard", so this is
-- 0.8 × 0.8 and NOT 0.6 — the cuts COMPOUND, they do not add. If a further cut is ever wanted,
-- multiply again; never subtract from 1.
--
-- ⚠️ Job #102 — a THIRD 20% ("decrease enemy hit by 20%"), so this is 0.8³ = 0.512 and NOT 0.4.
-- Three compounding cuts have now taken every bite in the game to just over HALF its authored value:
--     Bandit / Wolf  10.8 → 5.53      Boar  10 → 5.12
--     Crocodile       8   → 4.10      Hippo 20 → 10.24     Piranha 4 → 2.05
-- (before `strengthFor`, which is ×1.5 for LAND by day and for SEA by night — so a day Bandit lands
-- 8.29 and a night Croc 6.14.) Against a 100 HP player that is ~12 daytime Bandit bites to kill.
-- 🔴 THIS IS NEAR THE FLOOR OF MEANINGFUL. A fourth cut would put a daytime Bandit under 7 damage and
-- camp guards stop being a threat at all — if the fight is still wrong after this, the lever is guard
-- COUNT, the chase-slot cap or the reinforcement rate, not this number.
EnemyDefs.DAMAGE_SCALE = 0.512

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
	-- sea: fast, fragile, low bite — but comes in numbers (a swarm nibbling the hull)
	Piranha = {
		name = "Piranha",
		category = "sea",
		hp = 15,
		speed = 22,
		aggroRadius = 120,
		biteRange = 11,
		biteDamage = 4,
		biteCooldown = 0.8,
		color = Color3.fromRGB(120, 70, 70),
		size = Vector3.new(2, 1.2, 4),
	},
	-- sea: slow, tanky, hits HARD — a mini-threat that appears deeper downriver
	RiverHippo = {
		name = "RiverHippo",
		category = "sea",
		hp = 120,
		speed = 10,
		aggroRadius = 130,
		biteRange = 18,
		biteDamage = 20,
		biteCooldown = 2.6,
		color = Color3.fromRGB(120, 110, 120),
		size = Vector3.new(8, 5, 12),
	},
	-- land: ambushes from the bank (leashed), fast lunge; most active by day
	--
	-- ⚠️ RENAMED from `Panther` (Job #078). We already own a rigged, sounded, animated Wolf in
	-- roblox.defender, so reusing it beat generating a panther that would have needed a model, a rig,
	-- 4 animations and 3 sounds. The STATS are unchanged from the Panther — this is an art swap wearing
	-- a new name, so Job #058's crew-size difficulty scaling still holds.
	Wolf = {
		name = "Wolf",
		category = "land",
		hp = 55,
		speed = 26,
		aggroRadius = 95,
		biteRange = 14,
		-- Job #093: 12 -> 10.8, an exact 10%% cut (user: "reduce enemies (on land) bandits and wolf hit
		-- to me by 10%%, they are a little bit too strong"). Fractional is fine and not a slip: bite damage
		-- is ALREADY fractional in play because `applyBite` multiplies it by `strengthFor`. Boar is left at
		-- 10 - the user named only bandits and wolf, and boar was already the weaker of the three.
		biteDamage = 10.8,
		biteCooldown = 1.8,
		color = Color3.fromRGB(72, 66, 60),
		size = Vector3.new(5, 4, 11),
	},
	-- land: the human raider who guards a camp. NOT part of the riverbank spawn pool — `ExcursionServer`
	-- spawns these as `CampGuard`s, which is why a raider camp full of loot crates and sandbags is
	-- defended by people rather than by wildlife.
	Bandit = {
		name = "Bandit",
		category = "land",
		hp = 55,
		speed = 20, -- on two legs, so slower than the wolf but relentless
		aggroRadius = 95,
		biteRange = 12,
		-- Job #093: 12 -> 10.8, an exact 10%% cut (user: "reduce enemies (on land) bandits and wolf hit
		-- to me by 10%%, they are a little bit too strong"). Fractional is fine and not a slip: bite damage
		-- is ALREADY fractional in play because `applyBite` multiplies it by `strengthFor`. Boar is left at
		-- 10 - the user named only bandits and wolf, and boar was already the weaker of the three.
		biteDamage = 10.8,
		biteCooldown = 1.4,
		color = Color3.fromRGB(96, 78, 58),
		size = Vector3.new(5, 4, 11), -- ⚠️ unchanged from the Panther: Job #058 tuning depends on it
	},
	-- land: fast pack hunter; charges from the bank in numbers
	--
	-- ⚠️ Job #086: HP 40 → 50, and the reason is worth keeping. Wolf left the riverbank pool for the
	-- camps, making Boar the ONLY bank ambusher. Comparing what the bank had to what it has:
	--     Wolf  55 HP · speed 26 · 12 dmg / 1.8s = 6.67 DPS
	--     Boar  40 HP · speed 30 · 10 dmg / 1.4s = 7.14 DPS
	-- Boar already hits harder per second AND moves faster, so the only thing the bank actually lost
	-- was hit points. 50 rather than a straight 55: matching the Wolf's HP while keeping Boar's higher
	-- DPS and speed would leave the riverbank harder than it was, not equal to it.
	Boar = {
		name = "Boar",
		category = "land",
		hp = 50,
		speed = 30,
		aggroRadius = 90,
		biteRange = 12,
		biteDamage = 10,
		biteCooldown = 1.4,
		color = Color3.fromRGB(90, 65, 45),
		size = Vector3.new(4, 3, 7),
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
