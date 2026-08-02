--!strict
-- AtmosphereServer.server.luau — drives the lighting rig off the clock                [Job #073]
--
-- All the VALUES live in `ReplicatedStorage.World.AtmosphereRig` (one source of truth, also used to
-- bake the Edit-time look). This script's only job is to apply the static half once and then keep the
-- hourly half tracking `Lighting.ClockTime`, which `DayNightServer` owns.
--
-- Server-side on purpose: Lighting property writes replicate, so every client gets the same sky with
-- no per-client script and no chance of one player seeing a different time of day than their crew.
--
-- Cost: ~11 property writes twice a second. DayNightServer already writes ClockTime plus an attribute
-- every single Heartbeat (60×/s), so this is a rounding error next to what is already there — and a
-- Heartbeat-rate palette update would be invisible anyway: the clock moves 0.014 h in half a second.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AtmosphereRig = require(ReplicatedStorage:WaitForChild("World"):WaitForChild("AtmosphereRig"))

local STEP = 0.5 -- seconds between palette updates
local CLOCK_WAIT = 3 -- seconds to wait for DayNightServer to publish the starting hour

-- ⚠️ DON'T seed from `Lighting.ClockTime` — there is a start-up RACE, and it was observed in Play:
-- the property still holds whatever the PLACE was saved with (16.1, baked by the Edit-time apply), and
-- DayNightServer may not have written the run's real start hour yet. The first log line read
-- "applied at 16.10h" on a run that starts at 06:30 — one frame of warm afternoon at dawn.
--
-- `Workspace.ClockTime` is the attribute DayNightServer publishes, so waiting for it to appear means we
-- bake the FIRST frame at the correct hour instead of correcting it half a second later.
local function startingHour(): number
	local t0 = os.clock()
	while Workspace:GetAttribute("ClockTime") == nil and os.clock() - t0 < CLOCK_WAIT do
		task.wait(0.05)
	end
	local published = Workspace:GetAttribute("ClockTime") :: number?
	return published or Lighting.ClockTime -- no DayNightServer in this place → fall back to the property
end

print(AtmosphereRig.apply(startingHour()))

task.spawn(function()
	while true do
		task.wait(STEP)
		AtmosphereRig.applyPalette(AtmosphereRig.paletteAt(Lighting.ClockTime))
	end
end)
