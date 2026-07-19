--!strict
-- BoatRideClient.local.luau — carry standing riders with the moving boat (Job 040, fixes FINDING 0000).
-- The boat is a SERVER-owned physics assembly; a CLIENT-owned character standing on it isn't carried
-- smoothly (the deck slips under your feet as the boat drifts/drives). Fix CLIENT-SIDE: each frame, if the
-- local character is standing ON the boat and NOT seated, apply the hull's per-frame transform delta to the
-- character's root — so it rides along (position + yaw) while you can still walk. No server/ownership change
-- (keeps the boat physics untouched). Seated players are already carried by the seat, so we skip them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function getBoatHull(): BasePart?
	local boat = Workspace:FindFirstChild("Boat")
	local hull = boat and boat:FindFirstChild("Hull")
	return (hull and hull:IsA("BasePart")) and hull or nil
end

-- is the character standing on a part of the boat? (raycast straight down a few studs)
local function floorIsBoat(root: BasePart, boat: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { boat }
	params.IgnoreWater = true
	local r = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
	return r ~= nil
end

local prevHullCF: CFrame? = nil

RunService.RenderStepped:Connect(function()
	local hull = getBoatHull()
	if not hull then
		prevHullCF = nil
		return
	end
	local boat = hull.Parent
	local now = hull.CFrame

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if root and hum and boat and hum.SeatPart == nil and prevHullCF then
		if floorIsBoat(root, boat) then
			-- the world transform the hull underwent this frame; apply the same to the rider
			local delta = now * prevHullCF:Inverse()
			root.CFrame = delta * root.CFrame
		end
	end

	prevHullCF = now
end)
