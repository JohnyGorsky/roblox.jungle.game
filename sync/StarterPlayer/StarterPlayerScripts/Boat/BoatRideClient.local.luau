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

-- returns the downward raycast hit onto the boat (nil = not standing on the boat)
local function boatFloorHit(root: BasePart, boat: Instance): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { boat }
	params.IgnoreWater = true
	return Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
end

local prevHullCF: CFrame? = nil
local prevSeated = false
local logAcc = 0

RunService.RenderStepped:Connect(function(dt: number)
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

	if root and hum and boat then
		local seated = hum.SeatPart ~= nil
		local hit = boatFloorHit(root, boat)
		local onBoat = hit ~= nil
		local rel = root.Position - hull.Position -- player position RELATIVE to the hull (slide = this changing)
		local v = root.AssemblyLinearVelocity

		-- DEBUG (Job 052): log the moment you leave a seat + a throttled state stream while unseated.
		if prevSeated and not seated then
			print(string.format(
				"[BoatRide] LEFT SEAT | onBoat=%s hit=%s | rel=(%.1f,%.1f,%.1f) vel=(%.1f,%.1f,%.1f) move=%.2f",
				tostring(onBoat), hit and hit.Instance.Name or "nil", rel.X, rel.Y, rel.Z, v.X, v.Y, v.Z, hum.MoveDirection.Magnitude))
		end
		prevSeated = seated

		logAcc += dt
		if not seated and logAcc >= 0.2 then
			logAcc = 0
			print(string.format(
				"[BoatRide] onBoat=%s | rel=(%.1f,%.1f,%.1f) vel=(%.1f,%.1f,%.1f) move=%.2f | hull=(%.0f,%.0f,%.0f)",
				tostring(onBoat), rel.X, rel.Y, rel.Z, v.X, v.Y, v.Z, hum.MoveDirection.Magnitude,
				hull.Position.X, hull.Position.Y, hull.Position.Z))
		end

		if not seated and prevHullCF and onBoat then
			-- the world transform the hull underwent this frame; apply the same to the rider
			local delta = now * prevHullCF:Inverse()
			root.CFrame = delta * root.CFrame
			-- if you're NOT actively walking, cancel residual/inherited horizontal velocity — e.g. the launch
			-- you get when leaving the driver seat on a moving boat (Job 052) — so the carry alone moves you.
			if hum.MoveDirection.Magnitude < 0.1 then
				root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
			end
		end
	end

	prevHullCF = now
end)
