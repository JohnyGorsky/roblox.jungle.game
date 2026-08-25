--!strict
-- MonetizationServer.server.luau — Robux receipts + game-pass ownership (Job 027, design Job 020 §6).
-- ProcessReceipt grants Gold for gold-pack developer products (idempotent, persisted). Game-pass ownership
-- (Armored Boat, cosmetics) is checked on join + on purchase → an "Owns_<key>" player attribute the game
-- reads. Guarded against unset IDs (0). IDENTICAL copy in both trees (dev products purchasable anywhere).
--
-- Job #117 added a THIRD receipt route: per-run loadout charges (MonetizationDefs.RunGrants), which land on
-- the profile rather than going through the GrantProduct hook. The long note at that branch explains why —
-- read it before adding a fourth route, because the obvious choice there is the wrong one.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any

-- ── utility-product grant hook (Job 067) ─────────────────────────────────────────────────────────
-- Non-gold developer products (self-revive) are granted by whichever system owns the effect, not here.
-- That system sets `OnInvoke` on this BindableFunction; we call it with (player, key) and it returns true
-- if it actually granted. If NOTHING has claimed the hook — which is the normal case in the LOBBY, where
-- there is no downed state to revive from — the invoke throws and we return NotProcessedYet, so Roblox
-- retries the receipt later in the place that CAN honour it. The player is never charged for nothing.
--
-- A BindableFunction under ServerScriptService (rather than a shared module) because ServerStorage is
-- mapped in the GAME tree only, and this file is byte-identical in both.
local grantHook = Instance.new("BindableFunction")
grantHook.Name = "GrantProduct"
grantHook.Parent = ServerScriptService

-- ── developer-product receipts (gold packs + utility products) ──────────────────────────────────
--
-- ⚠️ REWRITTEN IN JOB 089. `PurchaseGranted` is a ONE-WAY DOOR — Roblox never delivers that receipt
-- again — so it must not be returned until the grant is durable ON DISK.
--
-- The old code returned it as soon as `purchaseIds[pkey]` was set in memory. That was defensible only
-- because the pre-089 `Profiles.save()` yielded until the write landed; ProfileStore's `Save()`
-- task.spawns the write instead, so the identical code would now confirm a purchase that had not been
-- stored, and a server crash in between would take the player's Gold with it.
--
-- All of that now lives in `Profiles.recordPurchase`, which implements ProfileStore's official
-- `PurchaseIdCheckAsync` pattern: grant once, then YIELD until `LastSavedData` proves the write landed.
-- It also refuses outright when the profile can't persist (in-memory fallback, a session lost to
-- another server, or Studio/offline mock mode) — a receipt is never consumed into a void.
--
-- ⏳ This callback now yields, on purpose. `MarketplaceService.ProcessReceipt` tolerates that.
local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	if not plr or not Profiles.isReady(plr) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retry when the player/profile is ready
	end

	-- gold pack
	local gold = MonetizationDefs.goldForProduct(info.ProductId)
	if gold then
		local ok = Profiles.recordPurchase(plr, info.PurchaseId, function()
			Profiles.addGold(plr, gold)
		end)
		return if ok
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- ── per-run loadout charge (M16) — Job #117 ─────────────────────────────────────────────────
	-- Granted straight onto the profile, exactly like a gold pack, and NOT through the `GrantProduct`
	-- hook below. Two reasons, both load-bearing:
	--
	--   1. THE HOOK HAS ONE OWNER. `PlayerCombat` assigns `OnInvoke` outright for `selfRevive`. A second
	--      claimant replaces it silently, load order is undefined, and the loser returns false forever →
	--      NotProcessedYet → Roblox re-delivers that receipt on every join. Copying the selfRevive
	--      pattern here would have broken PAID SELF-REVIVE with no diagnostic anywhere.
	--   2. THE HOOK IS THE WRONG SHAPE FOR THIS. It exists so a place that CANNOT honour a product
	--      declines it and lets Roblox retry elsewhere. But a charge bought in the LOBBY is meant to be
	--      honoured later, by a place that does not exist yet — so "decline and hope Roblox retries while
	--      they happen to be in the game place" is not a mechanism, it is a coin flip. A durable profile
	--      field makes the lobby purchase and the crash-site purchase the SAME code path.
	--
	-- ⚠️ `addRunGrant` is called INSIDE the closure on purpose — see its own header. That is what puts the
	-- write under `recordPurchase`'s yield-until-`LastSavedData`, which is what survives the session steal
	-- that the lobby → game teleport performs on every single run.
	local runKey = MonetizationDefs.runGrantForProduct(info.ProductId)
	if runKey then
		local ok = Profiles.recordPurchase(plr, info.PurchaseId, function()
			Profiles.addRunGrant(plr, runKey, 1)
		end)
		return if ok
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- utility product (self-revive): hand off to whoever owns the effect
	local key = MonetizationDefs.keyForProduct(info.ProductId)
	if key then
		local ok = Profiles.recordPurchase(plr, info.PurchaseId, function(): boolean
			-- Returning false leaves the receipt unconsumed: no handler in this place (the normal case
			-- in the LOBBY, where there is nothing to revive from), or the grant couldn't apply because
			-- they are no longer downed. Roblox retries, and the player keeps what they paid for.
			local invoked, granted = pcall(function()
				return grantHook:Invoke(plr, key)
			end)
			return invoked and granted == true
		end)
		return if ok
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet -- not one of ours — don't consume
end
MarketplaceService.ProcessReceipt = processReceipt

-- ── game-pass ownership → Owns_<key> attribute ──────────────────────────────────────────────────
local function checkPasses(plr: Player)
	local t = 0
	while not Profiles.isReady(plr) and t < 20 do
		task.wait(0.25)
		t += 0.25
	end
	for _, gp in ipairs(MonetizationDefs.GamePasses) do
		if gp.gamePassId and gp.gamePassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, gp.gamePassId)
			end)
			if ok and owns then
				plr:SetAttribute("Owns_" .. gp.key, true)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(checkPasses, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(checkPasses, p)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, gpId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, gp in ipairs(MonetizationDefs.GamePasses) do
		if gp.gamePassId == gpId and gpId > 0 then
			plr:SetAttribute("Owns_" .. gp.key, true)
		end
	end
end)

print("[Monetization] receipts + game-pass ownership online")
