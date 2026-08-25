--!strict
-- KillReward.luau — Salvage for killing land creatures (Job #093). SERVER ONLY.
--
-- User direction 2026-08-17: *"killing enemies should give some scrap, at least something"*, then
-- narrowed to **land only** — bandit, boar and wolf, **6 Salvage each**. Sea creatures (piranha,
-- crocodile, river hippo) pay nothing: you are not salvaging scrap off a fish, and the river fight is
-- already paid for by simply making progress (`SalvageServer`'s distance drip).
--
-- ── Why this lives at the DAMAGE sites and not at the death check ────────────────────────────────
-- The two tick loops that notice `HP <= 0` (`EnemyServer.tickEnemy`, `ExcursionServer.tickGuard`) are
-- the natural place to spot a death — and neither of them knows WHO killed it. The three damage sites
-- do (`GunServer`, `WeaponServer`, `MeleeServer`), so the killing blow is detected there instead.
--
-- ⚠️ `Category` is read off the model, not from an `EnemyDefs` lookup. `EnemyRig.build` writes it on
-- every creature it makes, which means one test covers riverbank creatures (whose model is named after
-- the def) AND camp guards (whose model is named `CampGuard` and carries a separate `GuardType`) — with
-- no name-matching and nothing to update when a creature is added.
--
-- ⚠️ TWO GUARDS AGAINST DOUBLE PAYMENT, and both are needed:
--   · `before > 0` — the killing blow only. Without it, any hit landing on an already-dead corpse
--     (its model lingers while `EnemyRig.die` topples it) reads as another kill.
--   · a `SalvageAwarded` marker on the model — belt and braces across the three separate call sites
--     and across frames, e.g. two crew members firing into the same creature on the same tick.

local CollectionService = game:GetService("CollectionService")

local RewardFeed = require(script.Parent:WaitForChild("RewardFeed"))

local KillReward = {}

-- Flat, and deliberately not scaled by toughness: the user's call. 6 is a little over a tenth of a
-- bandage (50) and well under a loot crate (40-80), so fighting pays without out-earning raiding.
local LAND_SALVAGE = 6

-- Job #115: a destroyed generator pays the same as a land kill. It lands HERE rather than inside
-- `Generators.luau` for the reason this file's header gives — the damage sites are the only place that
-- knows WHO struck the killing blow, and all three already call this function on every hit.
--
-- ⚠️ Checked BEFORE the `Category` test below, not after: a generator is a prop, not a creature, so it
-- has no `Category` and would be filtered out as if it were a fish.
local GENERATOR_SALVAGE = 6

-- ⚠️ Deliberately does NOT apply the Scavenger's Instinct bonus that `ExcursionServer.awardSalvage`
-- adds. That skill is described as boosting the LOOTER's payout; a kill is not a loot pickup, and
-- quietly folding combat into a looting skill would make the skill's own description wrong.
function KillReward.onEnemyDamaged(player: Player, enemy: Model, before: number, after: number)
	if before <= 0 or after > 0 then
		return -- not the killing blow
	end
	if CollectionService:HasTag(enemy, "Generator") then
		if enemy:GetAttribute("SalvageAwarded") == true then
			return
		end
		enemy:SetAttribute("SalvageAwarded", true)
		player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + GENERATOR_SALVAGE)
		RewardFeed.notify(player, "salvage", "Salvage", GENERATOR_SALVAGE)
		return
	end
	if enemy:GetAttribute("Category") ~= "land" then
		return -- sea creatures pay nothing
	end
	if enemy:GetAttribute("SalvageAwarded") == true then
		return
	end
	enemy:SetAttribute("SalvageAwarded", true)
	player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + LAND_SALVAGE)
	-- Job #109: *"Same when killing enemies… now you just guess."* Six salvage moving a three-digit
	-- counter in the far corner, mid-fight, is invisible. Say it.
	RewardFeed.notify(player, "salvage", "Salvage", LAND_SALVAGE)
end

return KillReward
