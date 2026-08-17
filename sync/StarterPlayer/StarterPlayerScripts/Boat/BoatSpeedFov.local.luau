--!strict
-- BoatSpeedFov.local.luau — widens the view as the boat speeds up, and nothing else (Job #087).
--
-- 🔴 WHY THIS IS A SEPARATE SCRIPT.
--
-- `BoatCamera` (the scripted chase cam) was found to be an INDEPENDENT cause of the ride shake: it
-- built its follow target from the RAW `hull.Position` every frame, so the hull's replication residual
-- (measured avg 0.47 / max 7.13 studs) became motion of the entire view, where the eye is far more
-- sensitive to it than it is to the boat itself moving. Disabling it removed roughly half the shake,
-- and re-enabling it while the buoyancy fault was bypassed brought the shake straight back.
--
-- The decision was to keep Roblox's DEFAULT camera for the boat. But the speed-based FOV swell was
-- worth saving on its own — and it is safe to save, because **FOV is not a position**. It cannot
-- amplify replication jitter no matter how noisy the hull's pose is; the worst a jittery speed reading
-- can do is make the number ease slightly unevenly, which the smoothing below absorbs.
--
-- Camera POSITION and ROTATION are left entirely to the player. This script only ever writes
-- `FieldOfView`.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Carried over unchanged from `BoatCamera`, where these were already tuned.
local FOV_BASE = 68 -- at rest
local FOV_BOOST = 28 -- extra at full speed → the sense of rushing water
local FOV_SPEED = 30 -- speed (studs/s) at which the boost maxes out
local FOV_K = 3 -- how fast FOV eases toward its target
local FOV_DEFAULT = 70 -- Roblox's default, restored when you are off the boat

local BIND = "BoatSpeedFov"

local boat = Workspace:WaitForChild("Boat", 60)
if not boat then
	return
end
local hull = boat:WaitForChild("Hull", 30) :: BasePart?
if not hull then
	return
end

-- Are we riding? True when seated in one of the boat's seats OR standing anywhere on its deck.
-- Both matter: the crew ride standing as often as seated, and a passenger should feel the speed too.
--
-- The deck test is done in the HULL'S OWN FRAME rather than by world distance, so it follows the boat's
-- heading for free and does not trigger for someone swimming alongside.
local DECK_MARGIN = 3 -- studs of slack around the hull box, for the raised foredeck and cargo rack
local function isAboard(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local hum = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local seatPart = hum and hum.SeatPart
	if seatPart and seatPart:IsDescendantOf(boat) then
		return true
	end
	local local_ = hull.CFrame:PointToObjectSpace(root.Position)
	local half = hull.Size / 2
	return math.abs(local_.X) <= half.X + DECK_MARGIN
		and math.abs(local_.Z) <= half.Z + DECK_MARGIN
		and local_.Y > -half.Y
		and local_.Y < half.Y + 12 -- deck and superstructure, not the whole sky above the boat
end

RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or not hull.Parent then
		return
	end
	-- ⚠️ Never fight another script that has taken the camera (the intro sequence sets it Scriptable).
	if camera.CameraType == Enum.CameraType.Scriptable then
		return
	end

	local target = FOV_DEFAULT
	if isAboard() then
		local v = hull.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		target = FOV_BASE + FOV_BOOST * math.clamp(speed / FOV_SPEED, 0, 1)
	end
	-- frame-rate-independent easing, per the roblox-camera skill
	camera.FieldOfView += (target - camera.FieldOfView) * (1 - math.exp(-FOV_K * dt))
end)
