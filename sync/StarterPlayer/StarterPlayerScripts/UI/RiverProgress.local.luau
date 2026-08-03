--!strict
-- RiverProgress.local.luau — the journey, as one line (Job #075).
--
-- Replaces the greybox `NEXT FUEL 1234 studs` text line. That readout was accurate and told you almost
-- nothing: a distance in studs is not a unit anyone has intuition for, and it said nothing about how far
-- through the run you were, which zone was next, or where the river ends.
--
-- The track carries four things at once:
--   · how far down the river you are        (the boat marker + the filled portion)
--   · which zone you're in and how many left (the ticks + the caption)
--   · where the next FUEL landing is        (the pin)
--   · whether you can actually reach it     (the pin turns RED when a full tank can't)
--
-- That last one is the whole run in one glyph. GAME.md: "fuel forces stops, so fuel management becomes
-- the central risk/reward decision of every run." A red pin means conserve or be stranded.
--
-- ABOARD only. Ashore you aren't moving, and at the crash site the run hasn't started.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local ZoneDefs = require(ReplicatedStorage:WaitForChild("World"):WaitForChild("ZoneDefs"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))
local HudState = require(RunUI:WaitForChild("HudState"))

-- Full-throttle studs per unit of fuel (speed ÷ burn). Deliberately conservative: the honest answer
-- varies with current, throttle and the diesel skill, and a pin that says "you'll make it" and is wrong
-- is far worse than one that makes you refuel a stop early. Carried over from the old HudClient.
local STUDS_PER_FUEL = 34

local TICK = 0.25
local DOCK_SEARCH = RiverData.DOCK_SPACING * 4 + 100 -- how far ahead to look for the next landing

local player = Players.LocalPlayer

local gui = Components.screen("RiverProgress", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Position = UDim2.fromScale(0.5, 0.022)
holder.Size = UDim2.fromScale(0.36, 0.062)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(210, 34)
clamp.MaxSize = Vector2.new(520, 62)
clamp.Parent = holder

holder.Parent = gui

local bar = RunComponents.riverBar(ZoneDefs.COUNT, holder)

-- ── the next landing ahead ───────────────────────────────────────────────────────────────────────
-- `docksBetween` allocates a table, so it is refreshed on a slow cadence and the result cached; the
-- marker position itself follows the boat every tick off the cached value.

local cachedLandingZ: number? = nil
local landingAcc = 0

local function refreshNextLanding(boatZ: number)
	cachedLandingZ = nil
	for _, d in RiverData.docksBetween(boatZ + 5, boatZ + DOCK_SEARCH) do
		if d.landing then
			cachedLandingZ = d.z
			break
		end
	end
end

local function num(inst: Instance, name: string): number
	return (inst:GetAttribute(name) :: number?) or 0
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	local show = HudState.current() == "ABOARD" and not HudState.runEnded()
	holder.Visible = show
	if not show then
		cachedLandingZ = nil -- so re-boarding recomputes rather than drawing a stale pin
		return
	end

	local dist = num(Workspace, "BoatDistance")
	local endDist = num(Workspace, "RiverEndDistance")
	if endDist <= 0 then
		endDist = RiverData.END_DISTANCE
	end

	local alpha = dist / endDist
	local zone = ZoneDefs.zoneFor(dist, endDist)
	bar.set(alpha, zone, ZoneDefs.nameFor(zone))

	-- Distance IS world Z here (worldToDistance is `z - Z_START`, and Z_START is 0), but go through the
	-- conversion anyway: the day Z_START moves, this keeps working and a bare `dist` would not.
	local boatZ = RiverData.distanceToWorldZ(dist)
	landingAcc += TICK
	if landingAcc >= 2 or cachedLandingZ == nil then
		landingAcc = 0
		refreshNextLanding(boatZ)
	end

	local landingZ = cachedLandingZ
	if landingZ and landingZ > boatZ then
		local boat = HudState.boat()
		local range = (if boat then num(boat, "Fuel") else 0) * STUDS_PER_FUEL
		bar.setDock(RiverData.worldToDistance(landingZ) / endDist, range >= (landingZ - boatZ))
	else
		bar.setDock(nil, true)
	end
end)
