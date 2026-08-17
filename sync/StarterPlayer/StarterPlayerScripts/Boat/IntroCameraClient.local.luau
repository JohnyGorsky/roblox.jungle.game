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

-- 🔴 Job #091: THE AIM POINT MUST BE SMOOTHED, NOT JUST THE CAMERA POSITION.
--
-- Reported as *"looks like camera cant keep up plane and it wiggles a lot"*, and it is two faults with
-- one root, both already diagnosed on this project in Job #087:
--
--  1. **THE WIGGLE.** `IntroPlane` is an ANCHORED model whose CFrame the SERVER rewrites every
--     Heartbeat (`PlaneServer` `flyer:PivotTo(...)`). An anchored part's CFrame replicates as discrete
--     property writes — the client does NOT interpolate them the way it interpolates a physics body —
--     so the plane's rendered position arrives in visible steps. This camera smoothed its own POSITION
--     but passed the RAW stepping pivot as `lookAt`'s target, so every replication step snapped the
--     whole view. Job #087 found the exact mirror image in `BoatCamera` (position raw, aim smoothed)
--     and recorded the rule this now follows: **a smoothed follow of a jittery point is not a smooth
--     camera — every input the camera reads has to be continuous.**
--
--  2. **THE LAG.** `POS_GAIN` was 3.5, a ~0.29 s time constant. At `CRUISE_SPEED` 45 studs/s that
--     trails the plane by ~13 studs, and more through the descent where it accelerates — which is
--     literally "can't keep up".
--
-- The aim is deliberately smoothed HARDER than the position (higher gain = tighter tracking): the shot
-- should stay locked on the plane while the camera body drifts behind it. At 20 the aim's time
-- constant is 0.05 s ≈ 2 studs of trail, enough to erase the replication step and not enough to see.
local POS_GAIN = 8 -- was 3.5 — camera body catch-up
local AIM_GAIN = 20 -- the fix for the wiggle; must stay well above POS_GAIN
local smoothTarget: Vector3? = nil

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

		-- Frame-rate-independent smoothing (skill §: never a constant alpha). `dt` is clamped so a
		-- one-off hitch can't teleport either value.
		local step = math.min(dt, 0.1)

		-- The raw, STEPPING replicated pivot. Nothing downstream may read this directly — see the header.
		local raw = cf.Position
		local aimAlpha = 1 - math.exp(-AIM_GAIN * step)
		smoothTarget = if smoothTarget then (smoothTarget :: Vector3):Lerp(raw, aimAlpha) else raw
		local target = smoothTarget :: Vector3

		local want = target - fwd * 62 + Vector3.yAxis * 20 + right * 26 -- behind, above, off the shoulder
		local posAlpha = 1 - math.exp(-POS_GAIN * step)
		local prev = smoothPos
		if prev then
			smoothPos = prev:Lerp(want, posAlpha)
		else
			smoothPos = want
		end

		-- Both arguments are now continuous: the camera body and the point it looks at.
		camera.CFrame = CFrame.lookAt(smoothPos :: Vector3, target)
		camera.Focus = CFrame.new(target)
	end
	-- (plane not built yet & not waking → leave the camera as-is; the loading mask covers this)
end)
