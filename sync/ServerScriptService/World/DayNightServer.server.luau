--!strict
-- DayNightServer.server.luau — the run's heartbeat (Job 009).
--
-- Cycles Lighting.ClockTime and publishes a "Phase" ("day"/"night") Workspace attribute that threats
-- read to scale their strength (GAME.md day/night: sea peaks at night, land by day; players should
-- shelter on land at night). Server-authoritative; ClockTime + attributes replicate to clients.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DAY_LENGTH = 240 -- real seconds for a full 24 h cycle
local START_CLOCK = 8 -- start mid-morning

-- remove the moon disc (too shiny at night — TODO 0009). Runs at startup; replicates to clients.
do
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = 0
		sky.MoonTextureId = ""
	end
end

local function phaseFor(t: number): string
	return if (t >= 6 and t < 19) then "day" else "night"
end

local clock = START_CLOCK
Lighting.ClockTime = clock
Workspace:SetAttribute("ClockTime", clock)
Workspace:SetAttribute("Phase", phaseFor(clock))

RunService.Heartbeat:Connect(function(dt: number)
	clock = (clock + dt * (24 / DAY_LENGTH)) % 24
	Lighting.ClockTime = clock
	Workspace:SetAttribute("ClockTime", clock)
	local ph = phaseFor(clock)
	if Workspace:GetAttribute("Phase") ~= ph then
		Workspace:SetAttribute("Phase", ph)
		print("[DayNight] now " .. ph .. string.format(" (%.1fh)", clock))
	end
end)
