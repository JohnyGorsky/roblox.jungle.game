--!strict
-- ObstacleServer.server.luau — river obstacle hits (Job 036). Obstacles are non-colliding triggers placed
-- by RiverBootstrap (tagged "Obstacle" with Slow/Damage attributes). When the boat overlaps one, we cut its
-- speed and damage the hull (per obstacle type), then destroy the obstacle (plowed through) so it can't
-- re-hit. Non-physical on purpose — a collidable rock would blow up the boat assembly. Server-authoritative.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat", 30)
local hull = boat and boat:WaitForChild("Hull", 10) :: BasePart?
if not boat or not hull then
	warn("[Obstacle] no boat/hull — obstacle hits not started")
	return
end
local theBoat = boat :: Model
local theHull = hull :: BasePart

local function flash()
	local orig = theHull.Color
	theHull.Color = Color3.fromRGB(210, 120, 45)
	task.delay(0.12, function()
		theHull.Color = orig
	end)
end

RunService.Heartbeat:Connect(function()
	if Workspace:GetAttribute("RunStarted") ~= true or Workspace:GetAttribute("RunEnded") == true then
		return
	end
	if theBoat:GetAttribute("Tied") == true or not theHull.Parent then
		return
	end
	local hp = theHull.Position
	local hullHalf = theHull.Size.X / 2
	for _, obs in CollectionService:GetTagged("Obstacle") do
		if obs:IsA("BasePart") and obs.Parent then
			local d = obs.Position - hp
			local flat = Vector3.new(d.X, 0, d.Z).Magnitude
			local reach = (hullHalf + math.max(obs.Size.X, obs.Size.Z) / 2) * 0.85
			if flat <= reach and math.abs(d.Y) < 8 then
				local slow = (obs:GetAttribute("Slow") :: number?) or 0.5
				local dmg = (obs:GetAttribute("Damage") :: number?) or 10
				theHull.AssemblyLinearVelocity = theHull.AssemblyLinearVelocity * (1 - slow)
				theBoat:SetAttribute("HP", math.max(0, ((theBoat:GetAttribute("HP") :: number?) or 100) - dmg))
				flash()
				print(("[Obstacle] hit %s — slow %.0f%%, -%d HP"):format(obs.Name, slow * 100, dmg))
				obs:Destroy() -- plowed through; no re-hit
			end
		end
	end
end)

print("[Obstacle] river obstacle hits online")
