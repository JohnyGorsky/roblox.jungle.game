--!strict
-- BoatCamera.local.luau — chase cam for the greybox boat (Job 003).
--
-- Activates ONLY while the local player sits in the Boat's DriverSeat; restores the default camera
-- on dismount. Follows behind+above the hull with look-ahead along velocity, a collision-aware
-- pull-in, speed-based FOV, and a decaying-trauma shake hook. Runs at RenderPriority.Camera with
-- frame-rate-independent smoothing (1 - exp(-k·dt)), per the roblox-camera skill.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BIND = "BoatCam"
local FOLLOW_DIST = 26
-- Raised 9 -> 16 (playtest: "when driver drives in boat, camera is locked, we need to rise camera, because
-- it is hard to see ahead"). At 9 the camera sat barely above the gunwale, so the boat's own bow, the
-- mounted gun and the crew filled the lower half of the screen and the next bend was hidden behind them —
-- which matters because reading the bend early IS the driving skill.
local FOLLOW_HEIGHT = 16
-- How far ABOVE the hull to aim. Looking dead level at hull height put the horizon in the middle of the
-- frame with the deck eating the rest; lifting the aim point tilts the view down the river instead of at
-- it, so the water ahead gets the screen space and the deck drops to the bottom edge.
local LOOK_UP = 4
local LOOK_AHEAD = 8
local SMOOTH_K = 9           -- position follow. Was 6, which read as the camera lagging behind the boat.
-- ⚠️ THESE TWO ARE THE FIX FOR "when i drive i have feeling that screen like cant keep up and like shakes".
--
-- The boat is SERVER-OWNED (`BoatServer` calls SetNetworkOwner(nil)), so on the client its CFrame and
-- velocity are REPLICATED values that step at roughly 20 Hz, not smooth per-frame values. The old code
-- smoothed only the camera POSITION and then aimed it with `CFrame.lookAt(smoothPos, rawTarget)`, where
-- rawTarget came straight from `AssemblyLinearVelocity` each frame. So the position glided while the
-- ROTATION snapped to a stepped, buoyancy-wobbling vector — which is exactly what reads as shake.
--
-- Both the aim point and the forward direction are now smoothed too, so nothing the camera uses is a raw
-- replicated value.
local TARGET_K = 7           -- how fast the aim point follows
local FWD_K = 4              -- how fast the "which way are we heading" vector turns
local FOV_BASE = 68          -- FOV at rest
local FOV_BOOST = 28         -- extra FOV at full speed → sense of rushing water
local FOV_SPEED = 30         -- speed (studs/s) at which the boost maxes out
local FOV_K = 3             -- how fast FOV eases toward its target

local hull: BasePart? = nil
local currentPos = Vector3.zero
local currentTarget = Vector3.zero
local currentFwd = Vector3.zero
local trauma = 0

local function isBoatSeat(seat: Instance?): boolean
	if not seat or not seat:IsA("VehicleSeat") then return false end
	if seat.Name ~= "DriverSeat" then return false end
	local parent = seat.Parent
	return parent ~= nil and parent.Name == "Boat"
end

local function update(dt: number)
	local h = hull
	if not h or not h.Parent then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local pos, vel = h.Position, h.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)

	-- Smoothed heading. Raw velocity on a bobbing, server-owned hull swings every replication tick; easing
	-- it means the aim drifts round a bend instead of twitching toward it.
	local fwdWanted = if flat.Magnitude > 1 then flat.Unit else h.CFrame.LookVector
	if currentFwd.Magnitude < 0.01 then
		currentFwd = fwdWanted
	end
	currentFwd = currentFwd:Lerp(fwdWanted, 1 - math.exp(-FWD_K * dt))
	if currentFwd.Magnitude > 0.01 then
		currentFwd = currentFwd.Unit
	end

	local targetWanted = pos + currentFwd * LOOK_AHEAD + Vector3.new(0, LOOK_UP, 0)
	local desired = pos - currentFwd * FOLLOW_DIST + Vector3.new(0, FOLLOW_HEIGHT, 0)

	-- collision-aware: don't clip through terrain/banks between the boat and the camera
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { h.Parent :: Instance }
	if player.Character then
		table.insert(filter, player.Character)
	end
	rp.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(pos, desired - pos, rp)
	if hit then
		desired = hit.Position + (pos - desired).Unit * 1.5
	end

	currentPos = currentPos:Lerp(desired, 1 - math.exp(-SMOOTH_K * dt))
	if currentTarget.Magnitude < 0.01 then
		currentTarget = targetWanted
	end
	currentTarget = currentTarget:Lerp(targetWanted, 1 - math.exp(-TARGET_K * dt))
	local cf = CFrame.lookAt(currentPos, currentTarget)

	if trauma > 0 then
		local s = trauma * trauma
		local a = math.rad(6) * s
		cf = cf * CFrame.Angles(
			(math.random() * 2 - 1) * a,
			(math.random() * 2 - 1) * a,
			(math.random() * 2 - 1) * a
		)
		trauma = math.max(0, trauma - dt * 1.5)
	end

	camera.CFrame = cf
	camera.Focus = CFrame.new(currentTarget)

	-- speed-based FOV, eased so it swells/settles smoothly instead of snapping with every wobble
	local fovTarget = FOV_BASE + FOV_BOOST * math.clamp(flat.Magnitude / FOV_SPEED, 0, 1)
	camera.FieldOfView += (fovTarget - camera.FieldOfView) * (1 - math.exp(-FOV_K * dt))
end

local function startCam(h: BasePart)
	hull = h
	local camera = Workspace.CurrentCamera
	if camera then
		currentPos = camera.CFrame.Position
		-- seed the smoothed state from the boat, so mounting doesn't whip the camera round from wherever
		-- the character cam happened to be looking
		currentFwd = h.CFrame.LookVector
		currentTarget = h.Position + currentFwd * LOOK_AHEAD + Vector3.new(0, LOOK_UP, 0)
		camera.CameraType = Enum.CameraType.Scriptable
	end
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, update)
end

local function stopCam()
	if hull == nil then return end
	hull = nil
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70 -- restore Roblox default for on-foot
	end
end

local function onCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(function(active: boolean, seat: Seat?)
		if not (active and seat and isBoatSeat(seat)) then
			stopCam()
			return
		end
		local model = seat.Parent
		if not (model and model:IsA("Model")) then
			return
		end
		local h = model.PrimaryPart or model:FindFirstChild("Hull")
		if h and h:IsA("BasePart") then
			startCam(h)
		end
	end)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
