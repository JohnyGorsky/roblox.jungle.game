--!strict
-- MonetizationServer.server.luau — Robux receipts + game-pass ownership (Job 027, design Job 020 §6).
-- ProcessReceipt grants Gold for gold-pack developer products (idempotent, persisted). Game-pass ownership
-- (Armored Boat, cosmetics) is checked on join + on purchase → an "Owns_<key>" player attribute the game
-- reads. Guarded against unset IDs (0). IDENTICAL copy in both trees (dev products purchasable anywhere).

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
local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	if not plr or not Profiles.isReady(plr) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retry when the player/profile is ready
	end
	local prof = Profiles.get(plr)
	if not prof then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	prof.purchaseIds = prof.purchaseIds or {}
	local pkey = tostring(info.PurchaseId)
	if prof.purchaseIds[pkey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (idempotent)
	end
	local gold = MonetizationDefs.goldForProduct(info.ProductId)
	if gold then
		Profiles.addGold(plr, gold)
		prof.purchaseIds[pkey] = true
		Profiles.save(plr, false) -- persist promptly (real money)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- utility product (self-revive): hand off to whoever owns the effect
	local key = MonetizationDefs.keyForProduct(info.ProductId)
	if key then
		local ok, granted = pcall(function()
			return grantHook:Invoke(plr, key)
		end)
		if not ok or granted ~= true then
			-- no handler here, or the grant couldn't apply (e.g. they're no longer downed). Do NOT consume
			-- the receipt — Roblox will retry, and the player keeps what they paid for.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		prof.purchaseIds[pkey] = true
		Profiles.save(plr, false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet -- not one of ours — don't consume
end
MarketplaceService.ProcessReceipt = processReceipt

-- ── game-pass ownership → Owns_<key> attribute ──────────────────────────────────────────────────
-- NO PROFILE WAIT (Job #069). This used to block on `Profiles.isReady` for up to 20 seconds before
-- checking anything — but ownership writes only a PLAYER ATTRIBUTE, never the profile, so the
-- dependency was vestigial. It had a real money-facing cost: until `Owns_<key>` lands, `RobuxShop`
-- correctly defaults a row to "not owned", so a player who ALREADY OWNS a pass saw a live buy button
-- for it for several seconds after joining. Measured in Play before this change: still showing buy
-- buttons at 4s, OWNED by ~12s. Checks now start immediately on PlayerAdded.
--
-- Each pass is checked in PARALLEL, not in sequence: `UserOwnsGamePassAsync` is a web call, and three
-- back to back means three round-trips of exposure instead of one.
--
-- `ProcessReceipt` above KEEPS its profile wait — that one genuinely needs it, because it writes gold.
local function checkPasses(plr: Player)
	for _, gp in ipairs(MonetizationDefs.GamePasses) do
		if gp.gamePassId and gp.gamePassId > 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, gp.gamePassId)
				end)
				-- they can leave mid-call; writing to a departed player is pointless, not harmful
				if ok and owns and plr.Parent then
					plr:SetAttribute("Owns_" .. gp.key, true)
				end
			end)
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
