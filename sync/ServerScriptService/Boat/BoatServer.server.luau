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
-- part→art mapping (Job 066). While no art is imported this is a no-op and the boat stays greybox.
local BoatParts = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatParts"))

-- ── tunables ─────────────────────────────────────────────────────────────
local WATER_Y = RiverData.WATER_Y  -- water surface (spring target for hull CENTER), from the shared river data
-- Job 066: 22 → 32 long. The boat read as too small next to its own rear cargo deck, and 32 × 14 is the
-- EXACT natural proportion of the imported hull mesh (2.29:1), so the skin no longer has to be stretched
-- 46% wider than it was modelled — which is what made it look squat and low in the water.
-- ⚠️ This changes physics: more hull volume and length alters buoyancy, inertia and turning. THRUST /
-- DRAG / TURN may need retuning, so boat feel must be re-tested in the game place.
local HULL_SIZE = Vector3.new(14, 3, 32)
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
-- ramp jumps (Job 019): ramps are NON-COLLIDING triggers (RampTest) — driving over one applies the launch
-- (linear up + angular flip) directly to the boat and sets boat.LaunchUntil; while that window is open this
-- loop suspends buoyancy + leveling so the boat arcs/flips freely. (A heavy buoyant boat can't physically
-- climb a solid ramp — it jams — so we drive over a trigger and apply the velocities instead.)

-- Spawn point — set AFTER RiverReady (once RiverBootstrap has applied the seed), so it matches the
-- generated river. Placeholder until then.
local START = Vector3.zero
-- Mooring heading. When the hand-placed `SpawnBase.Dock.BoatPlace` helper is present we honour ITS yaw,
-- so the boat lies the way the dock was built rather than the way the procedural river happens to run.
-- nil = no helper → fall back to "face downstream" (see buildBoat).
local START_CF: CFrame? = nil
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
	-- 🔴 Job #087: THE FIX FOR THE RIDE SHAKE. Do not remove without reading this.
	--
	-- `EnableFluidForces` defaults to TRUE, and it was never set here — so the ENGINE was applying its
	-- own water buoyancy and drag to this hull at the same time as our `Buoy` spring below. Density is
	-- 0.7 (lighter than water) in terrain water, so Roblox floats it natively whether we ask or not.
	-- Two independent systems driving the SAME axis is the roblox-physics skill's first gotcha: "Two
	-- constraints on the same DOF fight -> oscillation."
	--
	-- WHY IT ONLY SHOWED UP WHILE MOVING, and why that hid it for so long:
	--   · at rest both systems settle to one shared equilibrium -> measured 0.000 studs peak-to-peak,
	--     which is exactly what made buoyancy look innocent for three rounds of investigation;
	--   · under way the engine's fluid force varies with velocity and submerged volume, so it becomes a
	--     DRIVER, and it drives our spring at its own resonance.
	--
	-- The arithmetic proves the spring is not at fault by itself. With FLOAT_K = 8 and FLOAT_D = 8 the
	-- vertical dynamics are y'' = -K(y - WATER_Y) - D*y', giving a natural frequency of sqrt(8) = 2.83
	-- rad/s (0.45 Hz) and a damping ratio of D/(2*sqrt(K)) = 1.41. **A damping ratio above 1 is
	-- overdamped: it CANNOT oscillate on its own.** The 1.7-2.1 stud heave measured at ~0.6 Hz sat right
	-- next to that natural frequency, which is the signature of an overdamped system being driven by
	-- something else -- not of a mistuned spring.
	--
	-- So the boat's flotation is ours alone now: one spring, one damper, one authority.
	hull.EnableFluidForces = false
	-- Moored at the dock's own angle when the helper says so, otherwise face downstream.
	-- ⚠️ The downstream fallback is only right out on the generated river. At the hand-built spawn base
	-- the channel is sculpted terrain, not RiverData geometry, so the tangent there is a flat +Z — which
	-- parked the boat crosswise across the end of a pier that runs at −47°.
	hull.CFrame = START_CF or CFrame.lookAt(START, START + downstream(START.Z))
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
	-- Roblox's built-in "Speed 0" readout. Found in the Job #075 playtest sitting between our fuel and
	-- hull gauges, in Roblox's own font and colours — the one piece of the driving HUD we didn't draw.
	-- The speed it reports is also studs/s, which means nothing to a player; the river progress bar and
	-- the engine note carry pace far better.
	seat.HeadsUpDisplay = false
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = seat
	weld.Parent = hull

	-- Job 066: art rides on top as welded, massless, non-colliding skins. The hull box remains the
	-- PrimaryPart with its tuned density and `Root` attachment, so buoyancy/thrust/turning are untouched.
	-- Base motor (decision #1): every boat has one; `motor2` is the upgrade twin at mirrored X.
	-- derived from the hull so it stays at the stern if the hull length ever changes again
	-- ON the transom, not inside the hull: the hull sides rise to ~4.5 and hid the engine completely.
	local sternZ = HULL_SIZE.Z / 2 + 1
	local motor = Instance.new("Part")
	motor.Name = "Motor"
	motor.Size = Vector3.new(2, 2, 3)
	motor.Color = Color3.fromRGB(40, 40, 46)
	motor.Material = Enum.Material.Metal
	motor.Massless = true
	motor.CanCollide = false
	-- y 3.5, not 1: the hull mesh's sides rise to ~4.5, so at deck level the engine was hidden inside
		motor.CFrame = hull.CFrame * CFrame.new(4, 1, sternZ)
	motor.Parent = model
	local motorWeld = Instance.new("WeldConstraint")
	motorWeld.Part0 = hull
	motorWeld.Part1 = motor
	motorWeld.Parent = motor

	-- Crew seats (Job 066): driver + gunner + 4 = the 4-6 crew GAME.md targets. REAL Seats, because a
	-- physics boat pitches and turns — a standing passenger slides and can go overboard, a seated one is
	-- welded in place. Massless so they add no mass to the tuned assembly. Two per side, leaving a
	-- walkway down the centre; no station bonus attaches to them (helpers are the flexible crew).
	local CREW_SEAT_X, CREW_SEAT_Z = 4.5, { 4, 9 }
	for _, sz in ipairs(CREW_SEAT_Z) do
		for _, sx in ipairs({ -CREW_SEAT_X, CREW_SEAT_X }) do
			local crew = Instance.new("Seat")
			crew.Name = "CrewSeat"
			crew.Size = Vector3.new(3, 1, 3)
			crew.Color = Color3.fromRGB(45, 45, 52)
			crew.Material = Enum.Material.Fabric
			crew.Massless = true
			crew.CFrame = hull.CFrame * CFrame.new(sx, 2, sz)
			crew.Parent = model
			local cw = Instance.new("WeldConstraint")
			cw.Part0 = hull
			cw.Part1 = crew
			cw.Parent = crew
			BoatParts.skin(crew, "crewSeat")
		end
	end

	BoatParts.skin(hull, "hull")
	BoatParts.skin(seat, "driverSeat")
	BoatParts.skin(motor, "motor")

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
-- Spawn beside the hand-built dock, not mid-channel (Job #072).
-- The boat used to appear at `positionAt(Z_START + 40)` — the middle of the generated river — which was
-- correct while the crash-site hub was generated there too. The hub is now the hand-built SpawnBase at
-- Z ≈ −270, so spawning at Z 40 left the boat 310 studs upriver, slowly self-sailing to its mooring at
-- the start of every run.
--
-- Falls back to the old mid-channel spot if the helper is missing, because unlike StagingServer (which
-- can safely halt) a run with NO BOAT is unrecoverable — better a boat in the wrong place than none.
local startPos = RiverData.positionAt(RiverData.Z_START + 40) + Vector3.new(0, 2, 0)
do
	local sb = Workspace:FindFirstChild("SpawnBase")
	local dockFolder = sb and sb:FindFirstChild("Dock")
	local boatPlace = dockFolder and dockFolder:FindFirstChild("BoatPlace")
	if boatPlace and boatPlace:IsA("BasePart") then
		startPos = Vector3.new(boatPlace.Position.X, RiverData.WATER_Y + 2, boatPlace.Position.Z)
		-- Take the helper's YAW ONLY — never its pitch/roll. It's a hand-placed marker and may be
		-- tipped a little; feeding that straight into the hull would start the boat listing, and
		-- AlignOrientation would just fight it back upright on the first frame.
		local _, yaw = boatPlace.CFrame:ToOrientation()
		START_CF = CFrame.new(startPos) * CFrame.Angles(0, yaw, 0)
	else
		warn("[Boat] no SpawnBase.Dock.BoatPlace — falling back to mid-channel at Z_START + 40")
	end
end
START = startPos

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
	-- Admin god-boat (Job #112). The restore lives INSIDE this handler rather than in a polling loop on
	-- AdminServer, because the destroy check below runs on the very same write: a single hit big enough
	-- to take HP straight to 0 would beat any poll, and the run would end before the restore landed.
	-- Guarding here catches every writer — enemies, obstacles, modules — without any of them knowing.
	-- Re-entry is harmless: the restore re-fires this handler, which sees full HP and falls through.
	if boat:GetAttribute("AdminGodBoat") == true then
		local maxHp = (boat:GetAttribute("MaxHP") :: number?) or MAX_HP
		if ((boat:GetAttribute("HP") :: number?) or maxHp) < maxHp then
			boat:SetAttribute("HP", maxHp)
		end
		return
	end
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

local DEV_BOAT_LOG = false -- ⟵ turn on for boat-tuning telemetry ([BoatDBG] spam); off for launch

local logAccum = 0 -- throttle for the debug state log
RunService.Heartbeat:Connect(function(dt: number)
	-- Admin infinite fuel (Job #112). Deliberately ABOVE every early return in this handler — including
	-- the `Tied` one. Three of them sit between here and the fuel burn, so gating the refill on "the boat
	-- is under way" means a dev who flips the switch at the dock watches the gauge stay where it was and
	-- concludes the cheat is broken. It topped up rather than skipping the drain for the same reason: the
	-- HUD should read a truthful full tank, not freeze at whatever it happened to be.
	if boat:GetAttribute("AdminInfiniteFuel") == true then
		local maxFuel = (boat:GetAttribute("MaxFuel") :: number?) or MAX_FUEL
		if ((boat:GetAttribute("Fuel") :: number?) or 0) < maxFuel then
			boat:SetAttribute("Fuel", maxFuel)
		end
	end

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

	-- LAUNCHED: a ramp trigger (RampTest) set boat.LaunchUntil + applied the launch velocity. While that
	-- window is open we suspend buoyancy + leveling so the boat arcs/flips freely as a projectile.
	local launched = os.clock() < ((boat:GetAttribute("LaunchUntil") :: number?) or 0)

	-- buoyancy: OFF while launched (free arc); else a damped spring to the water line (damping separate
	-- from the up-only spring — bob fix).
	if launched then
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

	-- ── Job #084: a TIED boat ignores the helm ────────────────────────────────────────────────────
	-- ⚠️ REQUIRED COMPANION to DockServer's move off `hull.Anchored`. While tying anchored the hull
	-- these forces were inert — anchored parts ignore them — so this loop never needed to know about
	-- `Tied` and never checked it. Docks now MOOR the hull with a `LinearVelocity` hold instead, which
	-- means thrust is live at the pier: a driver holding W would fight the hold and walk the boat off
	-- its berth.
	--
	-- Returning here also (correctly) stops the rudder integrating and stops the fuel burn above: a
	-- boat roped to a dock is not running its engine. Buoyancy is computed BEFORE this point, so it
	-- still floats and bobs exactly as it does anywhere else.
	if boat:GetAttribute("Tied") == true then
		thrust.Force = Vector3.zero
		-- `current` is deliberately LEFT ON. The hold's MaxForce is sized to beat it (StagingServer:149
		-- — "beat the boat's constant Current force"), and cancelling it here would quietly change the
		-- load the spawn dock's identical hold has always been tuned against.
		drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG)
		-- sit flat and hold the moored heading (no bank, no throttle trim)
		level.MaxTorque = LEVEL_TORQUE
		level.CFrame = CFrame.Angles(0, desiredYaw, 0)
		return
	end

	-- drive (look computed above)
	local t = seat.Throttle -- 1 (W) / -1 (S) / 0
	local s = seat.Steer    -- 1 (D) / -1 (A) / 0

	-- fuel: drain while the engine runs; empty = no engine (drift at the current's mercy = stranded)
	local fuel = (boat:GetAttribute("Fuel") :: number?) or 0
	if fuel > 0 then
		-- FuelBurnMul = Diesel Efficiency skill (Job 024); StationFuelMul = Engineer at the fuel station (Job 034)
		local burnMul = ((boat:GetAttribute("FuelBurnMul") :: number?) or 1) * ((boat:GetAttribute("StationFuelMul") :: number?) or 1)
		boat:SetAttribute("Fuel", math.max(0, fuel - (FUEL_IDLE + FUEL_THROTTLE * math.abs(t)) * burnMul * dt))
	else
		t = 0
	end
	-- ThrustMul lets modules (2nd motor, Job 025) / skills (later) tune engine power; default 1
	local thrustMul = (boat:GetAttribute("ThrustMul") :: number?) or 1
	thrust.Force = look * (t * ((t >= 0) and THRUST or REVERSE) * thrustMul)
	-- per-zone flow (Job 048): the Rapids sweep you along faster, the Delta slows — from the shared RiverData.
	-- CurrentMul (Job 067) is the Ramp Bow & Hull Shape module: a shaped hull is shoved around less by the
	-- current, which is the "handles rapids better" half of what GAME.md promises that module.
	local currentMul = (boat:GetAttribute("CurrentMul") :: number?) or 1
	current.Force = downstream(pos.Z) * (CURRENT * RiverData.currentMulAt(pos.Z) * currentMul)
	drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG) -- horizontal only; Y left to buoyancy

	-- rudder heading: turn rate ∝ signed forward speed (0 when stopped; reverse flips it)
	-- TurnMul = Rudder Tuning skill (Job 024); StationTurnMul = a seated Driver's handling bonus (Job 034)
	local turnMul = ((boat:GetAttribute("TurnMul") :: number?) or 1) * ((boat:GetAttribute("StationTurnMul") :: number?) or 1)
	local fwdSpeed = vel:Dot(look)
	-- TurnAuthorityMul (Job 067, ramps module): full rudder authority arrives at a LOWER speed, so the boat
	-- still bites in slow twisty water instead of washing wide. Divides the speed threshold rather than
	-- multiplying TURN, so it sharpens low-speed handling without raising the top turn rate.
	local authSpeed = TURN_FULL_SPEED / ((boat:GetAttribute("TurnAuthorityMul") :: number?) or 1)
	local authority = math.clamp(fwdSpeed / authSpeed, -1, 1)
	desiredYaw -= s * TURN * turnMul * authority * dt

	-- attitude. While LAUNCHED (airborne off a ramp) DON'T fight the arc/flip (leveling off). Otherwise keep
	-- level + bank(into turn) + trim(throttle) and hold the heading.
	if launched then
		level.MaxTorque = 0
	else
		level.MaxTorque = LEVEL_TORQUE
		local bank = -s * math.abs(authority) * MAX_BANK
		local pitch = t * MAX_PITCH
		level.CFrame = CFrame.Angles(0, desiredYaw, 0) * CFrame.Angles(pitch, 0, bank)
	end

	-- state log (throttled) so we can see speed / height / launched while testing (Job 019). Off for launch.
	logAccum += dt
	if DEV_BOAT_LOG and logAccum >= 0.25 and Workspace:GetAttribute("RunStarted") then
		logAccum = 0
		print(("[BoatDBG] spd=%.1f fwd=%.1f Y=%.1f (water %d) velY=%.1f launched=%s thr=%.0f")
			:format(vel.Magnitude, fwdSpeed, pos.Y, WATER_Y, vel.Y, tostring(launched), t))
	end
end)

print(("[Boat] built at %s (water y=%d, server-owned)"):format(tostring(START), WATER_Y))
