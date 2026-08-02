--!strict
-- IntroCameraClient.local.luau — cinematic camera for the plane intro (Job 045).
-- While the intro plays (Workspace.IntroActive), take a Scriptable camera:
--   • CRUISE + DESCENT: a stable 3/4 chase shot that rides Workspace.IntroPlane (reads its pivot each frame,
--     so it tracks smoothly even though the plane is anchored + moved by CFrame — the default camera won't).
--   • WAKE (Workspace.IntroWake): a low ground shot on the local character that slowly rises as they come to.
-- When the intro ends (IntroActive false), hand the camera back to the default (Custom) controller.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local WAKE_TIME = 2.6

-- wait briefly for the server to claim the intro; if there's none, leave the default camera alone
local t0 = os.clock()
while Workspace:GetAttribute("IntroActive") == nil and os.clock() - t0 < 5 do
	task.wait()
end
if not Workspace:GetAttribute("IntroActive") then
	return
end

local function charRoot(): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

local wakeStart: number? = nil
local smoothPos: Vector3? = nil

local conn
conn = RunService.RenderStepped:Connect(function(dt: number)
	if not Workspace:GetAttribute("IntroActive") then
		-- intro over → restore the normal camera and stop
		camera.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
		conn:Disconnect()
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	if Workspace:GetAttribute("IntroWake") then
		-- crash cold-open: low shot on the character, rising as they wake
		wakeStart = wakeStart or os.clock()
		local root = charRoot()
		if root then
			local t = math.clamp((os.clock() - (wakeStart :: number)) / WAKE_TIME, 0, 1)
			local eased = t * t * (3 - 2 * t)
			local h = 1.2 + eased * 5.5 -- rise from near the ground to standing height
			local d = 5 + eased * 5 -- pull back a little as we rise
			local p = root.Position
			camera.CFrame = CFrame.lookAt(p + Vector3.new(d * 0.6, h, -d), p + Vector3.new(0, 1 + eased * 1.5, 0))
		end
		return
	end

	local plane = Workspace:FindFirstChild("IntroPlane")
	if plane and plane:IsA("Model") and plane.PrimaryPart then
		-- ⚠️ The offset MUST be derived from the plane's travel direction, not hardcoded. It used to be
		-- a fixed world `Vector3.new(40, 16, -48)`, correct only while the plane flew along +Z. The
		-- flight now runs +X toward the spawn base, so that offset sat the camera AHEAD of the plane and
		-- produced a close-up down the wing.
		--
		-- ⚠️ Do NOT read `GetPivot().LookVector` here. The plane mesh's nose is local **+X**, so once the
		-- server applies its MESH_FIX the pivot's LookVector points straight UP — flattening it yields a
		-- zero vector and the shot collapses. The server publishes the heading it is actually flying as
		-- `Workspace.IntroPlaneDir`; that is the single authority. RightVector is the fallback because,
		-- with the nose on +X, that is the nose.
		local cf = plane:GetPivot()
		local dir = Workspace:GetAttribute("IntroPlaneDir")
		local fwd = if typeof(dir) == "Vector3" then dir :: Vector3 else cf.RightVector
		local flat = Vector3.new(fwd.X, 0, fwd.Z)
		fwd = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
		local right = fwd:Cross(Vector3.yAxis)
		right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis

		local target = cf.Position
		local want = target - fwd * 62 + Vector3.yAxis * 20 + right * 26 -- behind, above, off the shoulder
		-- frame-rate-independent smoothing (skill §: never a constant alpha)
		local alpha = 1 - math.exp(-3.5 * math.min(dt, 0.1))
		local prev = smoothPos
		if prev then
			smoothPos = prev:Lerp(want, alpha)
		else
			smoothPos = want
		end

		camera.CFrame = CFrame.lookAt(smoothPos :: Vector3, target)
		camera.Focus = CFrame.new(target)
	end
	-- (plane not built yet & not waking → leave the camera as-is; the loading mask covers this)
end)
