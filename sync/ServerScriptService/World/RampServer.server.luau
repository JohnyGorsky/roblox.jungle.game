--!strict
-- RampServer.server.luau — river jump ramps: drive over one at speed and the boat launches. [Job #082]
--
-- ── What this is, and what it is NOT ─────────────────────────────────────────────────────────────
-- This is Job 019's PROVEN launch, promoted from a dev-only test script onto the real river. Nothing
-- about the physics is new — the numbers below are the ones that were tuned in Studio in #019 and left
-- behind `DEV_RAMPS = false` in `RampTest.server.luau` waiting for real ramps (todo 0013).
--
-- 🔴 RAMPS ARE NON-COLLIDING TRIGGERS, AND MUST STAY THAT WAY.
-- A heavy, buoyant, level-controlled boat physically CANNOT climb a solid ramp — it jams against the
-- face and stalls. That was measured in #019. So the boat drives THROUGH the ramp and we apply the
-- launch directly: upward linear velocity, a gentle angular nose-up, and a `LaunchUntil` window that
-- tells `BoatServer` to stop fighting the arc. Make the ramp collidable and the feature dies.
--
-- Mirrors `ObstacleServer`: one Heartbeat over a CollectionService tag, reading attributes off the part
-- that `RiverBootstrap` placed. Ramps stream in and out with their chunk, and the tag prunes itself.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- ── launch tuning — Job 019's proven values, do not re-derive ────────────────────────────────────
-- Roblox gravity ≈196, so a launch of v studs/s peaks at about v²/392 studs.
local LAUNCH_BASE = 40 -- upward launch off any ramp (studs/s)
local LAUNCH_PER_DEG = 1.6 -- extra upward per degree of ramp angle
local LAUNCH_MAX = 95 -- cap (studs/s) — ~95 ≈ a 23-stud peak, the height the landing was tuned for
local FLIP_RATE = 0.5 -- gentle angular nose-UP (rad/s). NOT a somersault
local MIN_SPEED = 6 -- forward speed needed to trigger at all: drifting into one does nothing
local ARC_TIME = 0.6 -- seconds BoatServer keeps out of the way, then re-levels to catch the landing
local DEBOUNCE = 2.5 -- seconds before the SAME ramp can fire again

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat", 30)
local hull = boat and boat:WaitForChild("Hull", 10) :: BasePart?
if not boat or not hull then
	warn("[Ramp] no boat/hull — jump ramps not started")
	return
end
local theBoat = boat :: Model
local theHull = hull :: BasePart

local lastLaunch: { [Instance]: number } = {}

RunService.Heartbeat:Connect(function()
	-- Same guards as ObstacleServer: nothing fires before the run starts, after it ends, or while the
	-- boat is tied at a dock.
	if Workspace:GetAttribute("RunStarted") ~= true or Workspace:GetAttribute("RunEnded") == true then
		return
	end
	if theBoat:GetAttribute("Tied") == true or not theHull.Parent then
		return
	end

	local p = theHull.Position
	local vel = theHull.AssemblyLinearVelocity
	local fwd = vel:Dot(theHull.CFrame.LookVector)
	if fwd <= MIN_SPEED then
		return -- not moving forward hard enough to jump anything
	end

	for _, r in ipairs(CollectionService:GetTagged("Ramp")) do
		if r:IsA("BasePart") and r.Parent then
			local d = r.Position - p
			-- the trigger part IS the footprint, so test against its own size rather than a constant
			local inFootprint = math.abs(d.X) <= r.Size.X / 2 + 3
				and math.abs(d.Z) <= r.Size.Z / 2 + 4
				and math.abs(d.Y) < r.Size.Z + 8 -- not sailing way over the top of it
			if inFootprint and (os.clock() - (lastLaunch[r] or -100)) > DEBOUNCE then
				lastLaunch[r] = os.clock()
				local angle = (r:GetAttribute("Angle") :: number?) or 20
				-- `RampBoost` is the Ramp Bow & Hull Shape module (Job 067), applied BEFORE the cap so
				-- owning it can never launch the boat past what the landing was tuned to catch.
				local boost = (theBoat:GetAttribute("RampBoost") :: number?) or 1
				local launchUp = math.min((LAUNCH_BASE + angle * LAUNCH_PER_DEG) * boost, LAUNCH_MAX)
				-- keep the horizontal run, add the launch
				theHull.AssemblyLinearVelocity = Vector3.new(vel.X, launchUp, vel.Z)
				theHull.AssemblyAngularVelocity = -theHull.CFrame.RightVector * FLIP_RATE
				theBoat:SetAttribute("LaunchUntil", os.clock() + ARC_TIME)
				print(("[Ramp] LAUNCH %d° — fwd %.1f → up %.1f (boost x%.2f)"):format(angle, fwd, launchUp, boost))
			end
		end
	end
end)

print("[Ramp] river jump ramps online")
