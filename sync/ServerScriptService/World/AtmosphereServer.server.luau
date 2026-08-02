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

local AtmosphereRig = require(ReplicatedStorage:WaitForChild("World"):WaitForChild("AtmosphereRig"))

local STEP = 0.5 -- seconds between palette updates

print(AtmosphereRig.apply(Lighting.ClockTime))

task.spawn(function()
	while true do
		task.wait(STEP)
		AtmosphereRig.applyPalette(AtmosphereRig.paletteAt(Lighting.ClockTime))
	end
end)
