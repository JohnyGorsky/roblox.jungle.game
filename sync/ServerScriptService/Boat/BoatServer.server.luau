--!strict
-- BoatServer.server.luau — P1 greybox physics boat.
--
-- Builds a placeholder boat at the river start and drives it with REAL forces so it feels
-- like an engine-driven boat (momentum + drift), not "hold-W-and-slide":
--   • Buoyancy  — a spring force floats the hull at the water line (deterministic; does NOT
--                 rely on terrain-water buoyancy, which let the boat sink/fall through).
--   • Thrust    — VectorForce = throttle × hull look-vector (world; at CoM).
--   • Current   — VectorForce pushing downstream along the winding channel.
--   • Drag      — VectorForce opposing horizontal velocity → a finite top speed + engine feel.
--   • Orient    — ONE AlignOrientation drives the whole hull attitude (per the roblox-physics
--                 recipe: don't fight the same DOF with two constraints):
--                   · Heading — RUDDER model. Steer integrates a desired yaw at a rate that scales
--                     with forward speed, so you must be MOVING to turn (no tank-spin-in-place) and
--                     linear momentum carries the hull through the bend = drift. Reverse flips it.
--                   · Bank    — rolls INTO the turn (inside dips, outside lifts), ∝ steer × speed.
--                   · Trim    — bow rises under throttle (planing), dips when braking, ∝ throttle.
--                 It also keeps pitch/roll level (anti-capsize) when you're not steering/throttling.
-- Input: a VehicleSeat (WASD + default mobile controls; ThrottleFloat/SteerFloat replicate to the
-- server regardless of physics ownership).
-- Authority: SERVER-OWNED. The VehicleSeat auto-hands ownership to the driver on sit; we re-assert
--   SetNetworkOwner(nil) so this server loop reads accurate (un-lagged) Position/velocity and stays
--   exploit-resistant for co-op (decided in Job 003 review, 2026-07-18).
-- Greybox only — real boat model/art swap in at P9. Tune the CONSTANTS for feel.
--
-- NOTE (Job 005): the river shape now comes from the shared RiverData module — the SAME source the
-- RiverGenerator uses to build the terrain — so the boat's spawn/heading/waterline can never desync
-- from the actual river. Waits for the RiverGenerator to signal "RiverReady" before spawning.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

-- ── tunables ─────────────────────────────────────────────────────────────
local WATER_Y = RiverData.WATER_Y  -- water surface (spring target for hull CENTER), from the shared river data
local HULL_SIZE = Vector3.new(14, 3, 22) -- length trimmed 28→22 (Job 019) so the driver can see the boat's ends
local DENSITY = 0.7
-- Speed knobs. Top speed ≈ THRUST/DRAG, idle downstream drift ≈ CURRENT/DRAG. THRUST is the natural
-- target for a future "boat speed upgrade" (multiply it — e.g. THRUST * speedTier — for a faster engine).
local THRUST = 60000         -- forward force at full throttle → top speed ≈ 30 studs/s
local REVERSE = 30000
local TURN = 0.8             -- max yaw rad/s ≈ 46°/s (only reached at/above TURN_FULL_SPEED)
local TURN_FULL_SPEED = 22   -- forward speed (studs/s) for full rudder authority; less speed = less turn
local CURRENT = 12000        -- downstream push (0 to disable) → idle drift ≈ 6 studs/s
local DRAG = 2000            -- horizontal velocity damping → top speed ≈ THRUST/DRAG
local FLOAT_K = 8            -- buoyancy spring stiffness
local FLOAT_D = 8            -- buoyancy damping (raised from 3 → kills the moving-boat bob/limit-cycle)
local LEVEL_TORQUE = 4e6     -- orientation torque cap (also the anti-capsize authority)
local LEVEL_RESP = 22        -- orientation responsiveness (5..200) — lower = softer sway
local MAX_BANK = math.rad(11)  -- max roll INTO a turn at full steer + speed
local MAX_PITCH = math.rad(7)  -- max bow-up (throttle) / bow-down (brake) trim
-- ramp jump assist (Job 019): Roblox gravity (~196) is high, so a natural ramp launch barely lifts the
-- boat — amplify forward-speed-up-an-incline into upward velocity for a satisfying jump.
local RAMP_LIFT = 5          -- forward speed up a ramp → upward launch velocity (high, since Roblox gravity
--                             ~196 eats jumps: v studs/s only clears v²/392 studs, so we launch hard)
local RAMP_MIN_SPEED = 8     -- need at least this forward speed to launch
local MAX_LAUNCH = 95        -- cap on launch velocity (studs/s) — ~95 ≈ a ~23-stud peak off the steep ramp

-- Spawn point — set AFTER RiverReady (once RiverBootstrap has applied the seed), so it matches the
-- generated river. Placeholder until then.
local START = Vector3.zero
-- ─────────────────────────────────────────────────────────────────────────

-- unit downstream tangent from the shared river data (no hardcoded centerline — can't desync)
local function downstream(z: number): Vector3
	return RiverData.tangentAtZ(z)
end

local function buildBoat(): Model
	local old = Workspace:FindFirstChild("Boat")
	if old then old:Destroy() end

	local model = Instance.new("Model")
	model.Name = "Boat"

	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = HULL_SIZE
	hull.Color = Color3.fromRGB(120, 85, 55)
	hull.Material = Enum.Material.WoodPlanks
	hull.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, 0.3, 0.4)
	hull.CFrame = CFrame.lookAt(START, START + downstream(START.Z)) -- face downstream
	hull.Parent = model
	model.PrimaryPart = hull

	-- force/velocity/orientation anchor at the hull center of mass (identity orientation = hull axes)
	local att = Instance.new("Attachment")
	att.Name = "Root"
	att.Parent = hull

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(4, 1, 5)
	seat.Color = Color3.fromRGB(60, 45, 30)
	seat.CFrame = hull.CFrame * CFrame.new(0, 2, 0)
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = seat
	weld.Parent = hull

	local function force(name: string): VectorForce
		local f = Instance.new("VectorForce")
		f.Name = name
		f.Attachment0 = att
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Force = Vector3.zero
		f.Parent = hull
		return f
	end
	force("Buoy")
	force("Thrust")
	force("Current")
	force("Drag")

	-- single attitude controller: heading (steer) + bank + bow trim + keep-level. Driven each frame.
	local level = Instance.new("AlignOrientation")
	level.Name = "Level"
	level.Mode = Enum.OrientationAlignmentMode.OneAttachment
	level.Attachment0 = att
	level.PrimaryAxisOnly = false
	level.RigidityEnabled = false
	level.MaxTorque = LEVEL_TORQUE
	level.Responsiveness = LEVEL_RESP
	level.CFrame = hull.CFrame.Rotation -- start facing downstream, level
	level.Parent = hull

	model.Parent = Workspace
	return model
end

-- wait for the RiverGenerator to build the initial terrain (and apply the seed) so the boat spawns
-- onto real water at the correct place
if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
START = RiverData.positionAt(RiverData.Z_START + 40) + Vector3.new(0, 2, 0)

local boat = buildBoat()
local hull = boat.PrimaryPart :: BasePart
local seat = boat:FindFirstChild("DriverSeat") :: VehicleSeat
local buoy = hull:FindFirstChild("Buoy") :: VectorForce
local thrust = hull:FindFirstChild("Thrust") :: VectorForce
local current = hull:FindFirstChild("Current") :: VectorForce
local drag = hull:FindFirstChild("Drag") :: VectorForce
local level = hull:FindFirstChild("Level") :: AlignOrientation

-- integrated desired heading (yaw). Steering changes this; AlignOrientation drives the hull to it.
local desiredYaw = select(2, hull.CFrame:ToOrientation())

-- boat health + fail state (Job 006). HP lives as an attribute on the Boat model; threats damage it.
local MAX_HP = 100
boat:SetAttribute("MaxHP", MAX_HP)
boat:SetAttribute("HP", MAX_HP)
local destroyed = false
boat:GetAttributeChangedSignal("HP"):Connect(function()
	if not destroyed and ((boat:GetAttribute("HP") :: number?) or MAX_HP) <= 0 then
		destroyed = true
		Workspace:SetAttribute("BoatDestroyed", true)
		print("[Boat] DESTROYED — run over")
	end
end)

-- boat fuel (Job 010): drains as you ride; empty → the engine cuts and you drift (stranded)
local MAX_FUEL = 100
local FUEL_IDLE = 0.15 -- drain/s with the engine on
local FUEL_THROTTLE = 0.85 -- extra drain/s at full throttle
boat:SetAttribute("MaxFuel", MAX_FUEL)
boat:SetAttribute("Fuel", MAX_FUEL)

-- SERVER-OWNED physics. VehicleSeat hands ownership to the driver on sit; re-assert server ownership
-- so this loop reads accurate state and stays authoritative.
local function claimServerOwnership()
	if hull:IsGrounded() then return end
	local ok = pcall(function()
		hull:SetNetworkOwner(nil)
	end)
	if not ok then
		-- assembly not simulated yet this frame; retry next step
		task.defer(function()
			pcall(function()
				hull:SetNetworkOwner(nil)
			end)
		end)
	end
end
claimServerOwnership()
seat:GetPropertyChangedSignal("Occupant"):Connect(claimServerOwnership)

RunService.Heartbeat:Connect(function(dt: number)
	-- KEEP SERVER OWNERSHIP even while driven. The VehicleSeat hands the boat to the driver's client on
	-- sit, but the buoyancy force is computed HERE (server-side) — a client-owned boat + server-computed
	-- force means the spring reacts to LAGGED replicated position → a delayed-feedback loop that makes the
	-- boat bounce higher and higher. Re-grab ownership whenever a client holds it (the seat only hands it
	-- over once on sit, so this settles immediately and doesn't thrash). Inputs replicate regardless.
	if not hull:IsGrounded() then
		local ok, owner = pcall(function()
			return hull:GetNetworkOwner()
		end)
		if ok and owner ~= nil then
			pcall(function()
				hull:SetNetworkOwner(nil)
			end)
		end
	end

	local pos = hull.Position
	local vel = hull.AssemblyLinearVelocity
	local mass = hull.AssemblyMass
	local g = Workspace.Gravity
	local look = hull.CFrame.LookVector
	local fwd = vel:Dot(look) -- forward speed

	-- probe for a solid surface just under the hull. IgnoreWater → over open (deep) water this misses.
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { boat }
	rp.IgnoreWater = true
	local hit = Workspace:Raycast(pos, Vector3.new(0, -(HULL_SIZE.Y / 2 + 2.5), 0), rp)
	local incline = if hit then math.acos(math.clamp(hit.Normal.Y, -1, 1)) else 0 -- 0 = flat, bigger = ramp
	local onRamp = hit ~= nil and incline > math.rad(8) -- an INCLINED surface under us (not flat bed)
	local airborne = hit == nil and pos.Y > WATER_Y + 3 -- launched / over a gap, clear of the water

	-- RAMP LAUNCH ASSIST (Job 019): forward speed up an inclined surface → UPWARD velocity so the boat
	-- actually launches (Roblox gravity is high). Gated on the ramp UNDER the hull (not height), so it
	-- assists the whole climb. One-shot velocity set = the impulse tool (roblox-physics).
	if onRamp and fwd > RAMP_MIN_SPEED then
		local up = math.min(fwd * math.sin(incline) * RAMP_LIFT, MAX_LAUNCH)
		if vel.Y < up then
			hull.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
			vel = hull.AssemblyLinearVelocity
		end
	end

	-- buoyancy: damped spring to the water line (damping separate from the up-only spring — bob fix).
	-- OFF while on a ramp (the ramp supports it) or airborne (free-projectile arc), so neither is fought.
	if onRamp or airborne then
		buoy.Force = Vector3.zero
	elseif pos.Y < WATER_Y + 12 then
		local spring = math.max(mass * (g + (WATER_Y - pos.Y) * FLOAT_K), 0)
		local damp = -vel.Y * FLOAT_D * mass
		buoy.Force = Vector3.new(0, spring + damp, 0)
	else
		buoy.Force = Vector3.zero
	end

	-- dead in the water once destroyed: kill propulsion + steering, but keep it floating
	if destroyed then
		thrust.Force = Vector3.zero
		current.Force = Vector3.zero
		drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG)
		return
	end

	-- drive (look/fwd computed above)
	local t = seat.Throttle -- 1 (W) / -1 (S) / 0
	local s = seat.Steer    -- 1 (D) / -1 (A) / 0

	-- fuel: drain while the engine runs; empty = no engine (drift at the current's mercy = stranded)
	local fuel = (boat:GetAttribute("Fuel") :: number?) or 0
	if fuel > 0 then
		boat:SetAttribute("Fuel", math.max(0, fuel - (FUEL_IDLE + FUEL_THROTTLE * math.abs(t)) * dt))
	else
		t = 0
	end
	thrust.Force = look * (t * ((t >= 0) and THRUST or REVERSE))
	current.Force = downstream(pos.Z) * CURRENT
	drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG) -- horizontal only; Y left to buoyancy

	-- rudder heading: turn rate ∝ signed forward speed (0 when stopped; reverse flips it)
	local fwdSpeed = vel:Dot(look)
	local authority = math.clamp(fwdSpeed / TURN_FULL_SPEED, -1, 1)
	desiredYaw -= s * TURN * authority * dt

	-- attitude: bank INTO the turn (inside dips) ∝ steer × |speed|; bow up on throttle, down on brake
	local bank = -s * math.abs(authority) * MAX_BANK
	local pitch = t * MAX_PITCH
	level.CFrame = CFrame.Angles(0, desiredYaw, 0) * CFrame.Angles(pitch, 0, bank)
end)

print(("[Boat] built at %s (water y=%d, server-owned)"):format(tostring(START), WATER_Y))
