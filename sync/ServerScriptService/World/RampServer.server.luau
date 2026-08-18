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
-- ⚠️ Job #100 follow-up — TWICE AS HIGH AND TWICE AS FAR, and the maths matters here.
--
-- Peak height goes as v²/(2g), so DOUBLING the height needs the vertical launch multiplied by √2, not by
-- 2 (×2 would quadruple it). Airtime also scales with √2, so multiplying the HORIZONTAL carry by √2 as
-- well doubles the range at the same time. Hence one constant, applied to both axes.
local JUMP_SCALE = math.sqrt(2) -- → 2× peak height and 2× distance

local LAUNCH_BASE = 40 * JUMP_SCALE -- upward launch off any ramp (studs/s)
local LAUNCH_PER_DEG = 1.6 * JUMP_SCALE -- extra upward per degree of ramp angle
local LAUNCH_MAX = 95 * JUMP_SCALE -- cap (studs/s) — ~134 ≈ a 46-stud peak
local FLIP_RATE = 0.5 -- gentle angular nose-UP (rad/s). NOT a somersault
local MIN_SPEED = 6 -- forward speed needed to trigger at all: drifting into one does nothing

-- ⚠️ ARC_TIME is now DERIVED, not fixed. It was 0.6 s, tuned against the old 95 studs/s launch — but a
-- launch that hangs longer than the window gets re-levelled by BoatServer mid-flight, which cuts the arc
-- short. Full airtime is 2v/g, so the window follows the actual launch instead of a number that only
-- happened to fit the old one.
local GRAVITY = 196
local function arcTimeFor(launchUp: number): number
	return math.clamp((2 * launchUp / GRAVITY) * 0.95, 0.6, 2.2)
end

-- How far along the ramp the boat must be before it fires. 0 = the leading edge (the old behaviour,
-- which launched the moment the bow touched); positive pushes the trigger toward the crest, so the boat
-- rides up the ramp first and leaves it from the top — *"we must jump little bit later"*.
local TRIGGER_ALONG = 0.35 -- fraction of the ramp's length past its centre-line to wait for
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

			-- ⚠️ …but not YET. Measured along the boat's own direction of travel, so it works whichever
			-- way the ramp is oriented: the boat must be past the ramp's centre-line before it launches,
			-- which means it rides up and leaves from near the crest instead of popping off the toe.
			if inFootprint and TRIGGER_ALONG > 0 then
				local travel = Vector3.new(vel.X, 0, vel.Z)
				if travel.Magnitude > 0.1 then
					local along = (p - r.Position):Dot(travel.Unit)
					if along < -r.Size.Z * TRIGGER_ALONG then
						inFootprint = false -- still on the way up: wait for it
					end
				end
			end
			if inFootprint and (os.clock() - (lastLaunch[r] or -100)) > DEBOUNCE then
				lastLaunch[r] = os.clock()
				local angle = (r:GetAttribute("Angle") :: number?) or 20
				-- `RampBoost` is the Ramp Bow & Hull Shape module (Job 067), applied BEFORE the cap so
				-- owning it can never launch the boat past what the landing was tuned to catch.
				local boost = (theBoat:GetAttribute("RampBoost") :: number?) or 1
				local launchUp = math.min((LAUNCH_BASE + angle * LAUNCH_PER_DEG) * boost, LAUNCH_MAX)
				-- ⚠️ The horizontal run is boosted by the SAME √2, and it has to be for "twice as far" to be
				-- true. Vertical ×√2 alone doubles the height and stretches airtime by √2, which carries
				-- the boat ~1.4× further — not 2×. Scaling the horizontal carry by √2 as well makes the
				-- range genuinely double. (Written as a comment first and nearly shipped without the
				-- code; the arithmetic is the whole point of the constant.)
				theHull.AssemblyLinearVelocity = Vector3.new(vel.X * JUMP_SCALE, launchUp, vel.Z * JUMP_SCALE)
				theHull.AssemblyAngularVelocity = -theHull.CFrame.RightVector * FLIP_RATE
				theBoat:SetAttribute("LaunchUntil", os.clock() + arcTimeFor(launchUp))
				print(("[Ramp] LAUNCH %d° — fwd %.1f → up %.1f (boost x%.2f)"):format(angle, fwd, launchUp, boost))
			end
		end
	end
end)

print("[Ramp] river jump ramps online")
