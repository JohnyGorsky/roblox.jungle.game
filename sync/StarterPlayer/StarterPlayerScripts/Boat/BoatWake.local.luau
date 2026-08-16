--!strict
-- BoatWake.local.luau — the boat's water VFX: bow spray, prop wash, and the wake trail   [Job #081]
-- ============================================================================================
-- Before this the boat slid across the river leaving NOTHING behind it — no spray, no foam, no
-- wake. A 14 x 32 stud hull moving at 30 studs/s and the water never reacted.
--
-- ── WHY THIS IS A CLIENT SCRIPT (same reasoning as BoatSound) ───────────────────────────────
-- Emission rates change EVERY FRAME with speed. Driving that from the server would replicate a
-- property write per emitter per frame to every client for no benefit. The boat is server-owned
-- (`BoatServer` calls `SetNetworkOwner(nil)`), so `AssemblyLinearVelocity` already replicates —
-- each client reads it and drives its own local emitters. Client-created instances parented to a
-- replicated part stay local to that client, so there is no duplication.
--
-- ── MOBILE BUDGET, stated up front ──────────────────────────────────────────────────────────
-- This is a mobile-first game, and particles are the easiest way to wreck a phone. The whole
-- effect is deliberately **3 emitters + 2 trails**, and every rate is scaled by speed so a moored
-- boat emits NOTHING (Rate 0, Trails disabled) rather than idling a particle system all run.
-- `GameSoundscape`'s stacking lesson applies here too: reuse one emitter, never spawn per event.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

-- ⚠️ Reference speed shared with `BoatSound`: `BoatServer`'s THRUST/DRAG works out to ≈30 studs/s.
-- If that is ever retuned, both files want the new number.
local TOP_SPEED = 30
local MOVING_SPEED = 2.5 -- below this the boat is "stopped": everything off, no idle particles
local RESPONSE = 5 -- how fast the effect chases its target (matches BoatSound's feel)

-- Foam colours. Slightly blue-tinted white so it reads against the river's teal rather than
-- glowing pure white the way a Neon placeholder would.
local FOAM = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(198, 226, 232))
local SPRAY_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- Rates at FULL speed; everything below is this scaled by the speed fraction.
local BOW_RATE = 16 -- per bow emitter (there are two)
local WASH_RATE = 26 -- the prop churn behind the motor

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- An attachment on the hull, positioned in HULL-LOCAL studs.
-- ⚠️ The waterline in hull-local Y is NOT 0. Measured on the live boat: hull is 14 x 3 x 32 centred
-- at y = 13.38 with `WATER_Y = 12.0`, so the surface sits at local y ≈ -1.38 — i.e. the hull rides
-- almost exactly on top of the water with ~0.12 studs wetted. Emitters belong AT that line, not at
-- the hull's centre, or the spray appears to come out of the deck.
local function att(name: string, parent: BasePart, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

local function spray(name: string, parent: Attachment, rate: number, speed: NumberRange, size: number, spread: Vector2): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Name = name
	p.Texture = SPRAY_TEXTURE
	p.Color = FOAM
	p.LightEmission = 0.35
	p.LightInfluence = 1
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.45),
		NumberSequenceKeypoint.new(0.35, size),
		NumberSequenceKeypoint.new(1, size * 0.2),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Lifetime = NumberRange.new(0.35, 0.85)
	p.Speed = speed
	p.SpreadAngle = spread
	p.Rate = 0 -- starts OFF; the heartbeat below opens it up with speed
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-40, 40)
	p.Acceleration = Vector3.new(0, -14, 0) -- spray falls back into the river
	p.Drag = 2.5
	p.Parent = parent
	return p
end

local conns: { RBXScriptConnection } = {}
local generation = 0

local function detach()
	for _, c in conns do
		c:Disconnect()
	end
	conns = {}
end

local function attach(boat: Model)
	generation += 1
	local mine = generation
	detach()

	-- ⚠️ WaitForChild, NOT FindFirstChild — the MODEL replicates to the client before its CHILDREN
	-- do. `BoatSound` documents hitting exactly this and bailing every run.
	local hull = boat:WaitForChild("Hull", 10) :: BasePart?
	if generation ~= mine then
		return -- a newer boat arrived while we waited; that attach owns things now
	end
	if not (hull and hull:IsA("BasePart")) then
		warn("[BoatWake] boat has no Hull after 10s — no wake")
		return
	end
	local theHull = hull :: BasePart
	local motor = (boat:WaitForChild("Motor", 5) or theHull) :: BasePart
	if generation ~= mine then
		return
	end

	-- Clear anything a previous attach left on this hull (respawned boat, re-attach).
	for _, d in ipairs(theHull:GetChildren()) do
		if d:IsA("Attachment") and string.sub(d.Name, 1, 5) == "Wake_" then
			d:Destroy()
		end
	end

	-- ── geometry, in hull-local studs (measured on the live boat 2026-08-16) ────────────────
	-- Hull 14 x 3 x 32. **Forward is -Z** — the bow gun sits at z = -15, the Motor at z = +17.
	local WATERLINE_Y = -1.3 -- see `att` above
	local HALF_BEAM = 6.0 -- just inside the 7-stud side, so spray leaves the hull not the air
	local BOW_Z = -15.0
	local STERN_Z = 15.0

	-- Bow spray: two emitters at the forward corners, throwing outward and up as the hull cuts.
	-- ⚠️ Angle them OUTWARD and slightly back — that is what a hull pushing water actually does. An
	-- emitter with no orientation sprays straight up like a fountain.
	local bowAttL = att("Wake_BowL", theHull, Vector3.new(-HALF_BEAM, WATERLINE_Y, BOW_Z))
	local bowAttR = att("Wake_BowR", theHull, Vector3.new(HALF_BEAM, WATERLINE_Y, BOW_Z))
	bowAttL.Orientation = Vector3.new(-25, -120, 0)
	bowAttR.Orientation = Vector3.new(-25, 120, 0)
	local bow = {
		spray("Wake_BowSprayL", bowAttL, BOW_RATE, NumberRange.new(4, 9), 2.6, Vector2.new(28, 16)),
		spray("Wake_BowSprayR", bowAttR, BOW_RATE, NumberRange.new(4, 9), 2.6, Vector2.new(28, 16)),
	}

	-- Prop wash: the churn directly behind the motor. Wider, flatter and faster than the bow.
	local washAtt = att("Wake_Wash", theHull, Vector3.new(motor ~= theHull and 4.0 or 0, WATERLINE_Y, STERN_Z + 2))
	washAtt.Orientation = Vector3.new(-8, 180, 0) -- straight out the back, barely lifted
	local wash = spray("Wake_PropWash", washAtt, WASH_RATE, NumberRange.new(6, 13), 3.4, Vector2.new(20, 10))
	wash.Lifetime = NumberRange.new(0.5, 1.2)

	-- ── the wake trail ─────────────────────────────────────────────────────────────────────
	-- A `Trail` draws a ribbon between TWO attachments as they move, so both go at the stern a
	-- couple of studs apart and the ribbon streams out behind. One per side gives the classic V.
	local function makeTrail(name: string, x0: number, x1: number): Trail
		local a0 = att(name .. "_A", theHull, Vector3.new(x0, WATERLINE_Y, STERN_Z))
		local a1 = att(name .. "_B", theHull, Vector3.new(x1, WATERLINE_Y, STERN_Z))
		local t = Instance.new("Trail")
		t.Name = name
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = FOAM
		t.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		t.Lifetime = 1.6
		t.MinLength = 0.2
		t.LightEmission = 0.3
		t.LightInfluence = 1
		t.FaceCamera = false -- it lies ON the water; camera-facing would stand it up like a sail
		t.Enabled = false
		t.Parent = theHull
		return t
	end
	local trails = { makeTrail("Wake_TrailL", -HALF_BEAM, -HALF_BEAM + 2.2), makeTrail("Wake_TrailR", HALF_BEAM - 2.2, HALF_BEAM) }

	-- ── drive it from speed ────────────────────────────────────────────────────────────────
	--
	-- 🔴 SPEED IS MEASURED FROM POSITION, NOT READ FROM `AssemblyLinearVelocity`.
	-- The boat is SERVER-owned (`BoatServer` calls `SetNetworkOwner(nil)`), and a server-owned
	-- assembly's velocity property is not a signal a client can rely on — measured mid-run with the
	-- server reporting 34 studs/s while this client read 0.00. A wake driven off that reads as a boat
	-- gliding across the river with no water moving at all.
	--
	-- Differencing the hull's own position across frames cannot have that problem: it measures what
	-- the player can actually SEE this client doing, which is exactly what a cosmetic effect wants.
	-- `AssemblyLinearVelocity` is still taken as a floor via `math.max`, so nothing is lost on a build
	-- where it does replicate.
	local smooth = 0
	local lastPos = theHull.Position
	table.insert(
		conns,
		RunService.Heartbeat:Connect(function(dt: number)
			if generation ~= mine or not theHull.Parent then
				return
			end
			-- flat speed: vertical bob must not read as "moving fast"
			local pos = theHull.Position
			local moved = pos - lastPos
			lastPos = pos
			local seen = if dt > 0 then Vector3.new(moved.X, 0, moved.Z).Magnitude / dt else 0
			local v = theHull.AssemblyLinearVelocity
			local flat = math.max(seen, Vector3.new(v.X, 0, v.Z).Magnitude)
			local target = math.clamp((flat - MOVING_SPEED) / (TOP_SPEED - MOVING_SPEED), 0, 1)
			smooth = lerp(smooth, target, math.clamp(dt * RESPONSE, 0, 1))

			-- ⚠️ A boat sitting at the dock must emit NOTHING. Scaling to a small non-zero rate
			-- would leave every moored boat quietly spraying for the whole run.
			local on = smooth > 0.02
			for _, e in ipairs(bow) do
				e.Rate = if on then lerp(0, BOW_RATE, smooth) else 0
			end
			wash.Rate = if on then lerp(0, WASH_RATE, smooth) else 0
			for _, t in ipairs(trails) do
				t.Enabled = on
				-- a faster boat leaves a longer-lived, more opaque wake
				t.Lifetime = lerp(0.7, 2.2, smooth)
			end

			-- Keep the effect ON the water rather than wherever the hull has bobbed to. The river
			-- surface is flat at `WATER_Y`, so this is a straight correction rather than a probe.
			local localWater = theHull.CFrame:PointToObjectSpace(Vector3.new(theHull.Position.X, RiverData.WATER_Y, theHull.Position.Z)).Y
			for _, a in ipairs(theHull:GetChildren()) do
				if a:IsA("Attachment") and string.sub(a.Name, 1, 5) == "Wake_" then
					a.Position = Vector3.new(a.Position.X, localWater, a.Position.Z)
				end
			end
		end)
	)
end

-- Same lifecycle as BoatSound: the boat is rebuilt per run, so re-attach when a new one appears.
local existing = Workspace:FindFirstChild("Boat")
if existing and existing:IsA("Model") then
	task.spawn(attach, existing)
end
Workspace.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Boat" and child:IsA("Model") then
		-- let BoatServer finish welding Motor / seats on, as BoatSound does
		task.delay(0.5, attach, child :: Model)
	end
end)
