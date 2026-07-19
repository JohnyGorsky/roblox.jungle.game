--!strict
-- DevGrant.server.luau — STUDIO-ONLY testing tool (Job 025 aux). Grants Gold on demand so shops/upgrades
-- can be tested without grinding. Trigger by setting the player attribute "__DevGrantGold" = <amount>
-- (e.g. from the Studio MCP execute_luau, which runs in a separate VM but shares Instances). NO-OP outside
-- Studio, so it can never affect live players. IDENTICAL copy in sync/ and lobby/sync/.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

local ATTR = "__DevGrantGold"

local function hook(plr: Player)
	plr:GetAttributeChangedSignal(ATTR):Connect(function()
		local amt = plr:GetAttribute(ATTR)
		if typeof(amt) == "number" and amt ~= 0 and Profiles.isReady(plr) then
			Profiles.addGold(plr, amt)
			plr:SetAttribute(ATTR, 0)
			print(("[DevGrant] +%d gold to %s (now %d)"):format(amt, plr.Name, Profiles.getGold(plr)))
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	hook(p)
end
Players.PlayerAdded:Connect(hook)

print("[DevGrant] Studio-only gold granter online (set player." .. ATTR .. " = N)")
