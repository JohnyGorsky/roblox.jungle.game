--!strict
-- LightController.server.luau — night-only lights (Job 038). Any Light tagged "NightLight" (the player
-- torch, the boat searchlight) is ON only at night and OFF by day. Toggles on the day/night Phase flip and
-- for any newly-created tagged light. Server sets Light.Enabled → replicates to clients.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local function isNight(): boolean
	return Workspace:GetAttribute("Phase") == "night"
end

local function applyOne(inst: Instance)
	if inst:IsA("Light") then
		inst.Enabled = isNight()
	end
end

local function applyAll()
	for _, l in CollectionService:GetTagged("NightLight") do
		applyOne(l)
	end
end

applyAll()
CollectionService:GetInstanceAddedSignal("NightLight"):Connect(applyOne)
Workspace:GetAttributeChangedSignal("Phase"):Connect(applyAll)

print("[Lights] night-light controller online")
