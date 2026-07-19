--!strict
-- LightController.server.luau — dusk-to-dawn lights (Job 038, tuned Job 038.1). Any Light tagged
-- "NightLight" (player torch, boat searchlight) turns ON at DUSK and OFF at DAWN — keyed off ClockTime, not
-- the "night" Phase (which flips at 19:00, after the world already looks dark). Server sets Light.Enabled →
-- replicates to clients.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local DUSK, DAWN = 17.5, 6.5 -- lights on when ClockTime >= DUSK or < DAWN (world darkens ~sunset, not 19:00)

local function lightsOn(): boolean
	local t = (Workspace:GetAttribute("ClockTime") :: number?) or 12
	return t >= DUSK or t < DAWN
end

local function applyAll()
	local on = lightsOn()
	for _, l in CollectionService:GetTagged("NightLight") do
		if l:IsA("Light") then
			l.Enabled = on
		end
	end
end

-- new tagged lights (torch equipped, searchlight built) → match the current state immediately
CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(l)
	if l:IsA("Light") then
		l.Enabled = lightsOn()
	end
end)

-- poll for the dusk/dawn transition (ClockTime changes every frame — only re-apply when the on/off flips)
task.spawn(function()
	local last: boolean? = nil
	while true do
		local on = lightsOn()
		if on ~= last then
			last = on
			applyAll()
		end
		task.wait(0.5)
	end
end)

applyAll()

print("[Lights] dusk→dawn light controller online (on " .. DUSK .. "h–" .. DAWN .. "h)")
