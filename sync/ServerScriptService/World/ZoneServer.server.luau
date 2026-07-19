--!strict
-- ZoneServer.server.luau — river zones + day/night announces (Job 035, GAME.md P5). The river is split into
-- escalating ZONES; crossing into one announces it (the threat director already ramps by distance). Night
-- is a set-piece: the water surges (EnemyServer night cap) — players should reach a dock and hold out (a
-- TIED boat is safe from bites). This broadcasts the banners; it doesn't own the threat scaling.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NUM_ZONES = 4
local ZONE_NAMES = { "Headwaters", "Croc Country", "The Rapids", "Lost Delta" }
local ZONE_COLOR = Color3.fromRGB(90, 200, 230)

local announce = Instance.new("RemoteEvent")
announce.Name = "Announce"
announce.Parent = ReplicatedStorage

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end

local function isRun(): boolean
	return Workspace:GetAttribute("RunStarted") == true and Workspace:GetAttribute("RunEnded") ~= true
end

local function endDist(): number
	return (Workspace:GetAttribute("RiverEndDistance") :: number?) or 18000
end

local function zoneFor(): number
	local dist = (Workspace:GetAttribute("BoatDistance") :: number?) or 0
	local e = endDist()
	local frac = e > 0 and (dist / e) or 0
	return math.clamp(math.floor(frac * NUM_ZONES) + 1, 1, NUM_ZONES)
end

local lastZone = 0

-- announce zone 1 the moment the run starts, then each crossing
local function announceZone(z: number)
	announce:FireAllClients({
		title = ("ZONE %d / %d"):format(z, NUM_ZONES),
		subtitle = ZONE_NAMES[z] or "",
		color = ZONE_COLOR,
	})
end

-- day/night set-piece announces (only during a run)
Workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	if not isRun() then
		return
	end
	if Workspace:GetAttribute("Phase") == "night" then
		announce:FireAllClients({
			title = "NIGHTFALL",
			subtitle = "The water turns deadly — reach a dock and hold out!",
			color = Color3.fromRGB(120, 90, 220),
		})
	else
		announce:FireAllClients({
			title = "DAWN",
			subtitle = "The river calms — press on downriver",
			color = Color3.fromRGB(245, 210, 120),
		})
	end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.4 then
		return
	end
	acc = 0
	if not isRun() then
		lastZone = 0 -- reset so a fresh run re-announces zone 1
		return
	end
	local z = zoneFor()
	Workspace:SetAttribute("Zone", z)
	if z > lastZone then
		lastZone = z
		announceZone(z)
	end
end)

print("[Zone] zone + day/night announcer online (" .. NUM_ZONES .. " zones)")
