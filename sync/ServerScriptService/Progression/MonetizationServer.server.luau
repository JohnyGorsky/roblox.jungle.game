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

-- ── developer-product receipts (gold packs) ─────────────────────────────────────────────────────
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
	if not gold then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not one of ours — don't consume
	end
	Profiles.addGold(plr, gold)
	prof.purchaseIds[pkey] = true
	Profiles.save(plr, false) -- persist promptly (real money)
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
