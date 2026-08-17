--!strict
-- IntroPlaneSmooth.local.luau — render the intro plane at an interpolated pose (Job #091).
--
-- 🔴 WHY THIS EXISTS. `IntroPlane` is an ANCHORED model whose CFrame `PlaneServer` rewrites every
-- Heartbeat. An anchored part's CFrame replicates as DISCRETE PROPERTY WRITES — the client does not
-- interpolate them the way it interpolates a physics body — so the plane's rendered position arrives
-- in visible steps and the whole intro reads as juddery.
--
-- Job #091 first tried to fix this in `IntroCameraClient` alone, by smoothing the camera's aim. That
-- was necessary but NOT sufficient, and the user's verdict was blunt: *"plane still glitches"*. A
-- smooth camera pointed at a stepping plane just means the plane steps inside a steady frame. The
-- subject itself has to be continuous.
--
-- ⚠️ THE CLIENT WRITE IS LOCAL-ONLY AND THAT IS THE WHOLE TRICK. A client writing to a server-owned
-- anchored part changes only its own view; the write does not replicate. Every player smooths the
-- plane for themselves, the server stays authoritative over where it actually is, and nothing about
-- the flight, the seats or the crash timing changes. Same technique Job #087 used for the boat's
-- turret and searchlight, which had the identical anchored-part-driven-by-server-CFrame problem.
--
-- ⚠️ AND THAT IS WHY WE READ AN ATTRIBUTE, NOT THE MODEL. Once this script poses the model locally,
-- `plane:GetPivot()` returns OUR value, not the server's — self-referential, and the smoothing would
-- chase its own tail. `Workspace.IntroPlaneCF` is written by `PlaneServer.poseFlyer` and is the one
-- source a local write can never clobber.
--
-- TO REVERT: delete this file. The server still calls `flyer:PivotTo` inside `poseFlyer`, so the plane
-- flies exactly as before — just without the interpolation.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Position and rotation are interpolated separately because they need different stiffness: the airframe
-- can rotate faster than it translates (the descent adds judder and roll on purpose, and over-smoothing
-- that would sand off the drama the intro is built around).
local POS_GAIN = 26
local ROT_GAIN = 20

local rendered: CFrame? = nil

RunService.RenderStepped:Connect(function(dt: number)
	if not Workspace:GetAttribute("IntroActive") then
		rendered = nil -- intro over (or not started): let the server own the model outright
		return
	end
	local target = Workspace:GetAttribute("IntroPlaneCF")
	if typeof(target) ~= "CFrame" then
		return -- server hasn't published a pose yet; leave the model alone
	end
	local plane = Workspace:FindFirstChild("IntroPlane")
	if not plane or not plane:IsA("Model") or not plane.PrimaryPart then
		return
	end

	local goal = target :: CFrame
	local prev = rendered
	if prev == nil then
		rendered = goal -- first frame: snap, never lerp in from the origin
	else
		local step = math.min(dt, 0.1) -- a hitch must not teleport the plane
		local p = (prev :: CFrame).Position:Lerp(goal.Position, 1 - math.exp(-POS_GAIN * step))
		local r = (prev :: CFrame).Rotation:Lerp(goal.Rotation, 1 - math.exp(-ROT_GAIN * step))
		rendered = r + p
	end

	plane:PivotTo(rendered :: CFrame)
end)
