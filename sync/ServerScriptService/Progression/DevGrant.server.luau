--!strict
-- DevGrant.server.luau — STUDIO-ONLY testing tool (Job 025/026 aux). Grants Gold or River Score on demand
-- so shops/upgrades/ranks can be tested without grinding. Trigger by setting a player attribute (e.g. from
-- the Studio MCP execute_luau, which runs in a separate VM but shares Instances):
--   player.__DevGrantGold  = <amount>   → adds gold
--   player.__DevGrantScore = <amount>   → adds River Score (rank)
-- NO-OP outside Studio, so it can never affect live players. IDENTICAL copy in sync/ and lobby/sync/.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

local GOLD_ATTR = "__DevGrantGold"
local SCORE_ATTR = "__DevGrantScore"

local function hook(plr: Player)
	plr:GetAttributeChangedSignal(GOLD_ATTR):Connect(function()
		local amt = plr:GetAttribute(GOLD_ATTR)
		if typeof(amt) == "number" and amt ~= 0 and Profiles.isReady(plr) then
			Profiles.addGold(plr, amt)
			plr:SetAttribute(GOLD_ATTR, 0)
			print(("[DevGrant] +%d gold to %s (now %d)"):format(amt, plr.Name, Profiles.getGold(plr)))
		end
	end)
	plr:GetAttributeChangedSignal(SCORE_ATTR):Connect(function()
		local amt = plr:GetAttribute(SCORE_ATTR)
		if typeof(amt) == "number" and amt ~= 0 and Profiles.isReady(plr) then
			Profiles.addRiverScore(plr, amt)
			plr:SetAttribute(SCORE_ATTR, 0)
			print(("[DevGrant] +%d River Score to %s (now %d)"):format(amt, plr.Name, Profiles.getRiverScore(plr)))
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	hook(p)
end
Players.PlayerAdded:Connect(hook)

print("[DevGrant] Studio-only granter online (set player." .. GOLD_ATTR .. " or ." .. SCORE_ATTR .. " = N)")
