--!strict
-- RoleServer.server.luau — role-station efficiency bonuses (Job 034, GAME.md P2). While a station is MANNED
-- it works better, so dividing the crew pays off (and pulling someone off a station has a cost):
--   Engineer @ Fuel Station  → boat burns less fuel        (StationFuelMul)
--   Driver in the Driver seat → sharper handling           (StationTurnMul)
--   Gunner in the Gun seat    → faster turret              (StationGunMul)
--   Repairer @ Repair Station → passive hull regen         (direct HP)
-- These are CONTINUOUS/presence bonuses (distinct from the per-player skills, which they stack with).
-- Server-authoritative. BoatServer reads the fuel/turn muls; GunServer reads the gun mul.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local MAN_RANGE = 11 -- a player within this of a station "mans" it
local REGEN = 2.5 -- hull HP/s while a repairer mans the repair station
local MEDIC_REGEN = 3 -- player HP/s healed to the crew while a Medic mans the Medic station (Job 057)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat", 30)
local hull = boat and boat:WaitForChild("Hull", 10) :: BasePart?
if not boat or not hull then
	warn("[Roles] no boat/hull — station bonuses not started")
	return
end
local theBoat = boat :: Model
local theHull = hull :: BasePart

local function manned(part: Instance?): boolean
	if not part or not part:IsA("BasePart") then
		return false
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") and (root.Position - part.Position).Magnitude <= MAN_RANGE then
			return true
		end
	end
	return false
end

local function seatOccupied(name: string): boolean
	local s = theBoat:FindFirstChild(name)
	if s and s:IsA("Seat") then
		return s.Occupant ~= nil
	end
	if s and s:IsA("VehicleSeat") then
		return s.Occupant ~= nil
	end
	return false
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.25 then
		return
	end
	local step = acc
	acc = 0
	if not theHull.Parent then
		return
	end

	theBoat:SetAttribute("StationFuelMul", manned(theBoat:FindFirstChild("Fuel Station")) and 0.7 or 1)
	theBoat:SetAttribute("StationTurnMul", seatOccupied("DriverSeat") and 1.15 or 1)
	theBoat:SetAttribute("StationGunMul", seatOccupied("GunSeat") and 0.85 or 1)

	if manned(theBoat:FindFirstChild("Repair Station")) then
		local hp = (theBoat:GetAttribute("HP") :: number?) or 0
		local maxH = (theBoat:GetAttribute("MaxHP") :: number?) or 100
		if hp > 0 and hp < maxH then
			theBoat:SetAttribute("HP", math.min(maxH, hp + REGEN * step))
		end
	end

	-- MEDIC role (Job 057): while the Medic station is manned, passively heal the crew (and flag it so
	-- PlayerCombat buffs revives). Distinct from the per-player SkillMedic — they stack.
	local medicOn = manned(theBoat:FindFirstChild("Medic Station"))
	theBoat:SetAttribute("StationMedic", medicOn)
	if medicOn then
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 and not char:GetAttribute("Downed") then
				local hp = (char:GetAttribute("HP") :: number?) or 0
				local maxH = (char:GetAttribute("MaxHP") :: number?) or 100
				if hp > 0 and hp < maxH then
					char:SetAttribute("HP", math.min(maxH, hp + MEDIC_REGEN * step))
				end
			end
		end
	end
end)

print("[Roles] station bonuses online")
