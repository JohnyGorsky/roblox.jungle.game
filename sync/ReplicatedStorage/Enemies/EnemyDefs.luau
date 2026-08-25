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
-- Three compounding cuts have now taken every bite in the game to just over HALF its authored value.
--
-- 🔴 THE TWO BITE PATHS DO NOT SCALE THE SAME WAY, AND THIS COMMENT ONCE SAID THEY DID.
--
-- `strengthFor` is applied by `EnemyServer:343` (river threats) and NOT by `ExcursionServer:1995`
-- (camp guards). So a camp guard's bite is flat all day and all night, while a river creature's swings
-- ×1.5 at its peak phase. Measured in Play, 2026-08-23: a village-1 Bandit landed **5.5296** per bite,
-- nine bites in a row, in broad daylight — exactly `10.8 × 0.512 × 1.0`, with no ×1.5 anywhere.
--
--   CAMP GUARDS (ExcursionServer — flat, no phase multiplier):
--     Bandit / Wolf  10.8 → 5.53        ← 18 bites to kill a 100 HP player, one bite per 1.4-1.8 s
--
--   RIVER THREATS (EnemyServer — × strengthFor, ×1.5 at peak phase):
--     Boar   10 → 5.12  (7.68 by day)     Crocodile 8  → 4.10  (6.14 at night)
--     Piranha 4 → 2.05  (3.07 at night)   Hippo    20  → 10.24 (15.36 at night)
--
-- ⚠️ Village 1 guards carry NO `BiteDamage` attribute — `spawnGuard` only writes it when the village
-- strength multiplier is not 1 — so they fall back to `def.biteDamage` here. Verified: the attribute was
-- `nil` on all three guards of the first landing.
--
-- 🔴 THIS IS NEAR THE FLOOR OF MEANINGFUL. A fourth cut would put a camp guard under 4.5 damage — 23
-- bites to kill — and guards stop being a threat at all. If the fight is still wrong after this, the
-- lever is guard COUNT, the chase-slot cap or the reinforcement rate, not this number.
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
	-- land: the ROCKET MAN — Job #119. An army soldier who stands on a camp watchtower's top platform
	-- and lobs the Bazooka's rocket at you every 20 seconds.
	--
	-- 🔴 HE DOES NOT WALK, AND THAT IS THE DESIGN, NOT A LIMITATION.
	-- He is spawned on the `Defender` marker pad 36 studs up (`ExcursionServer.spawnRocketMan`) and holds
	-- it for his whole life: `tickRocketMan` only ever YAWS him. `tickGuard`'s movement block re-measures
	-- ground height as a guard walks and would re-seat him onto the dirt under the tower on its first
	-- frame; and because the AI has no pathfinding and the rig is kinematic (`PivotTo`), a rocket man told
	-- to reach a player on the ground walks THROUGH the platform railing, misses the floor raycast, and
	-- snaps 36 studs down in one frame. Holding the tower sidesteps both, and is what the owner asked for:
	-- *"if you get close to enemy, you go into close combat"* — you climb to him.
	--
	-- ⚠️ `size` IS NOT THE BANDIT'S 5 x 4 x 11. That box is the old Panther's, kept only because Job #058's
	-- crew-size scaling is tuned against it, and it is 11 studs DEEP — on a 20x20 tower platform it would
	-- overhang the railing on both sides and let you bite him from outside the deck. This is the measured
	-- box of the actual rig (4.996 x 5.773 x 2.854, Studio, 2026-08-25). He is a new enemy with no #058
	-- history, so he gets an honest hitbox.
	--
	-- ⚠️ `aggroRadius` 160 against every other land creature's 90-95, on the owner's call. He is 36 studs
	-- up with a clear view and a 300-stud weapon; 95 would put every shot inside his own 30-stud blast plus
	-- your 4-second escape run, which reads as unfair rather than telegraphed. 160 is "you are properly in
	-- the basin, heading for the deep camp", and keeps the moored boat comfortably out of range.
	--
	-- ⚠️ `biteDamage` is Bandit-grade ON PURPOSE — the ROCKET is his threat, not his fists. Like every camp
	-- guard he is NOT scaled by `strengthFor` (see the two-bite-paths note above), so this is flat day and
	-- night: 10.8 x DAMAGE_SCALE = 5.53 per swing, the same as the guards standing below him.
	RocketMan = {
		name = "RocketMan",
		category = "land", -- so `EnemyRig`'s "stand a land creature on its feet" seating applies
		hp = 110, -- double a Bandit (owner's call): the climb is the fight, so he must survive the climb
		-- 🔴 ZERO, and not "slow". `tickRocketMan` never calls the movement block, so this is only ever
		-- read if a future edit routes him through `tickGuard`'s steering by mistake — in which case a 0
		-- makes that a visible no-op instead of a soldier quietly strolling off a 36-stud platform.
		speed = 0,
		aggroRadius = 160,
		biteRange = 14, -- "you are on the platform with me" — a shade over the Bandit's 12
		biteDamage = 10.8,
		biteCooldown = 1.4,
		color = Color3.fromRGB(74, 82, 62), -- greybox fallback only; the real art is the ArmySoldier rig
		size = Vector3.new(4, 5.8, 3),
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
