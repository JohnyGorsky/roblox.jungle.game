--!strict
-- DayNightServer.server.luau — the run's heartbeat (Job 009, re-paced Job 073).
--
-- Cycles Lighting.ClockTime and publishes a "Phase" ("day"/"night") Workspace attribute that threats
-- read to scale their strength (GAME.md day/night: sea peaks at night, land by day; players should
-- shelter on land at night). Server-authoritative; ClockTime + attributes replicate to clients.
--
-- ── THE CLOCK IS NON-LINEAR, AND THAT IS THE POINT (Job 073) ─────────────────────────────────────────
-- It used to be one uniform DAY_LENGTH = 240 from START_CLOCK = 8. A run is END_DISTANCE 18000 studs at
-- a ~30 studs/s top speed — 10 min at the absolute best, 12–15 real — so that gave a run THREE full
-- day/night cycles, with night falling 1 min 50 s after the crash. The user's call: start at early
-- morning and stop night arriving early.
--
-- So daylight and night hours run at DIFFERENT rates: the 13 daylight hours are stretched over
-- DAY_SECONDS and the 11 night hours compressed into NIGHT_SECONDS. Against a ~12 min run that reads:
--
--     0:00  06:30  golden dawn — the crash cold-open lands at sunrise
--     3:00  ~11:00 full day
--     6:00  ~16:00 warm afternoon (the canonical lobby palette — see AtmosphereServer)
--     7:30  19:00  NIGHT — a real threat window, not most of the run
--     9:00  ~23:30 deep night
--    10:30  ~05:00 dawn returns
--
-- ⚠️ Night is a BALANCE lever, not just a look: EnemyServer scales spawn rate and bite damage off
-- `Phase`. Changing these two constants changes how long a run spends under sea-threat pressure.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DAWN_HOUR, DUSK_HOUR = 6, 19 -- the day/night boundary, in ClockTime hours
local DAY_SECONDS = 480 -- real seconds for the 13 daylight hours (DAWN_HOUR → DUSK_HOUR)
local NIGHT_SECONDS = 180 -- real seconds for the 11 night hours (DUSK_HOUR → DAWN_HOUR, wrapping)
local START_CLOCK = 6.5 -- early morning: low golden sun, the crash happens at sunrise

local DAY_HOURS = DUSK_HOUR - DAWN_HOUR -- 13
local NIGHT_HOURS = 24 - DAY_HOURS -- 11
local DAY_RATE = DAY_HOURS / DAY_SECONDS -- ClockTime hours per real second, in daylight
local NIGHT_RATE = NIGHT_HOURS / NIGHT_SECONDS -- ...and at night (faster)

-- remove the moon disc (too shiny at night — TODO 0009). Runs at startup; replicates to clients.
do
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = 0
		sky.MoonTextureId = ""
	end
end

local function isDay(t: number): boolean
	return t >= DAWN_HOUR and t < DUSK_HOUR
end

local function phaseFor(t: number): string
	return if isDay(t) then "day" else "night"
end

-- Advance the clock by `dt` real seconds at the rate for whichever side of the boundary we are on.
-- Stepping to the boundary FIRST and spending the remainder at the new rate keeps the two segment
-- durations exact even if a frame straddles dawn or dusk — otherwise a long frame at 3.3 h/s (the night
-- rate) could overshoot dawn by most of an hour and the morning would visibly start late.
local function advance(t: number, dt: number): number
	local remaining = dt
	while remaining > 0 do
		local day = isDay(t)
		local rate = if day then DAY_RATE else NIGHT_RATE
		local boundary = if day then DUSK_HOUR else (if t >= DUSK_HOUR then 24 else DAWN_HOUR)
		local toBoundary = (boundary - t) / rate
		if toBoundary > remaining then
			return (t + remaining * rate) % 24
		end
		t = boundary % 24
		remaining -= toBoundary
	end
	return t % 24
end

local clock = START_CLOCK
Lighting.ClockTime = clock
Workspace:SetAttribute("ClockTime", clock)
Workspace:SetAttribute("Phase", phaseFor(clock))

RunService.Heartbeat:Connect(function(dt: number)
	clock = advance(clock, dt)
	Lighting.ClockTime = clock
	Workspace:SetAttribute("ClockTime", clock)
	local ph = phaseFor(clock)
	if Workspace:GetAttribute("Phase") ~= ph then
		Workspace:SetAttribute("Phase", ph)
		print("[DayNight] now " .. ph .. string.format(" (%.1fh)", clock))
	end
end)

print(("[DayNight] start %.1fh · day %dh over %ds · night %dh over %ds (night falls %.0fs in)")
	:format(START_CLOCK, DAY_HOURS, DAY_SECONDS, NIGHT_HOURS, NIGHT_SECONDS, (DUSK_HOUR - START_CLOCK) / DAY_RATE))
