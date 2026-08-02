--!strict
-- BoatSound.local.luau — the boat's audio: live engine + damage                         [Job #073]
-- ============================================================================================
-- Three sounds, all positional on the boat so the crew hears them from the right place:
--   · boat_engine_starts — one-shot, when a player takes the helm   (@ stern Motor)
--   · speed_boat_loop    — loop, volume AND pitch track real work    (@ stern Motor)
--   · boat_hit           — one-shot, whenever OUR boat takes damage  (@ Hull)
--
-- ── WHY THIS IS A CLIENT SCRIPT ─────────────────────────────────────────────────────────────
-- The engine's volume and pitch change EVERY FRAME. Doing that on the server would replicate two
-- property writes per frame to every client for no benefit whatsoever. The boat is server-owned
-- (`BoatServer` calls `SetNetworkOwner(nil)`), so `AssemblyLinearVelocity`, `seat.Throttle` and the
-- `HP` attribute already replicate — each client reads those and drives its own local Sounds.
--
-- Client-created Sounds parented to a replicated part stay local to that client, so there is no
-- duplication and no two players fighting over one instance.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Ids live in ONE table; nothing below writes an asset id inline. Registry `audio.md` →
-- "GAME place — boat engine" / "boat damage".
local SFX = {
	start = "rbxassetid://105048345579705", -- boat_engine_starts   3.7 s one-shot
	loop = "rbxassetid://74719520771875", -- speed_boat_loop      5.6 s loop
	hit = "rbxassetid://131954812341128", -- boat_hit             one-shot on damage
}

-- ── engine ──────────────────────────────────────────────────────────────────────────────────
-- "It must be live" is driven by NEITHER the throttle key alone nor the speed alone:
--   · speed alone lags the player — you press W and hear nothing for half a second
--   · throttle alone is binary (`VehicleSeat.Throttle` is 1 / 0 / −1), so it cannot express
--     "labouring up to speed" vs "cruising", which is the entire point of an engine note
-- So it takes the MAX of real speed and a fraction of raw throttle: the key gives instant response,
-- and actual hull speed takes over authority as the boat gets going.
local TOP_SPEED = 30 -- studs/s; BoatServer's THRUST/DRAG works out to ≈30, the "full" reference
local THROTTLE_LEAD = 0.55 -- how much note pressing W buys before the boat has actually moved
local IDLE_VOL, MAX_VOL = 0.16, 0.62
local IDLE_PITCH, MAX_PITCH = 0.72, 1.32
local RESPONSE = 6 -- how fast the note chases its target (higher = snappier, less smooth)

-- "Stop when the boat is stopped" (user's words). A boat with someone at the helm normally idles, so
-- cutting the loop the instant speed touches zero would chatter on and off at every dock. It must be
-- below the threshold with no throttle for a moment first — and it resumes WITHOUT re-playing the
-- starter, because the engine never actually turned over again.
local STOP_SPEED = 1.5
local STOP_AFTER = 1.2
local FADE = 0.5

-- ── damage ──────────────────────────────────────────────────────────────────────────────────
-- Hooked to the boat's `HP` ATTRIBUTE rather than to each damage source. Enemy bites
-- (`EnemyServer`) and river obstacles (`ObstacleServer`) both just write `HP`, so one hook covers
-- both — and covers anything added later — instead of editing every system that can hurt the boat.
-- ⚠️ Only on a DECREASE: `RoleServer` regenerates HP while the Repair station is manned, so an
-- increase must never trigger a hit.
local HIT_MIN_GAP = 0.08 -- rapid hits may overlap (impacts should feel responsive), just not absurdly
local HIT_VOL_MIN, HIT_VOL_MAX = 0.45, 0.95
local HIT_REF_FRAC = 0.12 -- damage of this fraction of MaxHP or more is a "full volume" hit

local ROLL_MIN, ROLL_MAX = 12, 200 -- the engine carries a good way across open water

local function makeSound(id: string, looped: boolean, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = ROLL_MIN
	s.RollOffMaxDistance = ROLL_MAX
	return s
end

-- ⚠️ `Ended` NEVER fires for a Sound whose asset fails to load, so `Ended:Once(destroy)` on its own
-- leaks an instance every time. Job #073 hit exactly this with `night_starts` (unapproved by audio
-- moderation), so every one-shot in this file gets a timed backstop too.
local function playOneShot(id: string, parent: BasePart, volume: number)
	local s = makeSound(id, false, volume)
	s.Name = "BoatOneShot"
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
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

	-- ⚠️ WaitForChild, NOT FindFirstChild. The server builds the boat before any client script runs, but
	-- the MODEL replicates to the client before its CHILDREN do — so the first version of this bailed
	-- with "boat has no Hull/DriverSeat" every single run, because it looked the instant it saw `Boat`.
	-- `boat.PrimaryPart` is no help either: it can still be nil on the client at that moment.
	local hull = boat:WaitForChild("Hull", 10) :: BasePart?
	local seat = boat:WaitForChild("DriverSeat", 10) :: VehicleSeat?
	if generation ~= mine then
		return -- a newer boat arrived while we were waiting; that attach owns the connections now
	end
	if not (hull and hull:IsA("BasePart")) or not (seat and seat:IsA("VehicleSeat")) then
		warn("[BoatSound] boat has no Hull/DriverSeat after 10s — no boat audio")
		return
	end
	-- The Motor sits at the stern, which is where an engine should be heard from. Fall back to the
	-- hull rather than bailing: a boat with no motor part is still better off audible.
	local motor = (boat:WaitForChild("Motor", 5) or hull) :: BasePart
	if generation ~= mine then
		return
	end

	-- ── engine ──
	local engine = makeSound(SFX.loop, true, 0)
	engine.Name = "EngineLoop"
	engine.Parent = motor

	local starter = makeSound(SFX.start, false, 0.7)
	starter.Name = "EngineStart"
	starter.Parent = motor

	local running = false
	local idleFor = 0
	local drive = 0

	local function setRunning(on: boolean)
		if on == running then
			return
		end
		running = on
		if on then
			if not engine.IsPlaying then
				engine:Play()
			end
			TweenService:Create(engine, TweenInfo.new(FADE), { Volume = IDLE_VOL }):Play()
		else
			local out = TweenService:Create(engine, TweenInfo.new(FADE), { Volume = 0 })
			out:Play()
			out.Completed:Once(function()
				if not running then
					engine:Pause() -- Pause, not Stop: resuming mid-phrase avoids the loop re-announcing itself
				end
			end)
		end
	end

	-- the starter fires on an EMPTY→OCCUPIED transition only, so hopping between the helm and a crew
	-- seat doesn't re-crank the engine
	table.insert(conns, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant then
			starter:Play()
		end
	end))
	if seat.Occupant then
		setRunning(true)
	end

	table.insert(conns, RunService.Heartbeat:Connect(function(dt: number)
		if not (motor.Parent and hull.Parent) then
			detach()
			return
		end
		local vel = hull.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local throttle = math.abs(seat.Throttle)

		local target = math.max(math.min(speed / TOP_SPEED, 1), throttle * THROTTLE_LEAD)
		drive += (target - drive) * math.min(1, RESPONSE * dt)

		-- stalled = sitting still with the throttle released. Held long enough, the engine goes quiet;
		-- any throttle or movement resets the timer and it picks straight back up.
		local stalled = speed < STOP_SPEED and throttle == 0
		if seat.Occupant then
			idleFor = if stalled then idleFor + dt else 0
			setRunning(idleFor < STOP_AFTER)
		else
			idleFor = 0
			setRunning(false)
		end

		if running then
			engine.Volume = lerp(IDLE_VOL, MAX_VOL, drive)
			engine.PlaybackSpeed = lerp(IDLE_PITCH, MAX_PITCH, drive)
		end
	end))

	-- ── damage ──
	local lastHP = (boat:GetAttribute("HP") :: number?) or 0
	local lastHitAt = 0
	table.insert(conns, boat:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = (boat:GetAttribute("HP") :: number?) or 0
		local lost = lastHP - hp
		lastHP = hp
		if lost <= 0 then
			return -- healed (Repair station regen), or no change
		end
		local now = os.clock()
		if now - lastHitAt < HIT_MIN_GAP then
			return
		end
		lastHitAt = now
		local maxHP = (boat:GetAttribute("MaxHP") :: number?) or 100
		-- a bigger bite hits harder
		local frac = math.clamp(lost / (maxHP * HIT_REF_FRAC), 0, 1)
		playOneShot(SFX.hit, hull, lerp(HIT_VOL_MIN, HIT_VOL_MAX, frac))
	end))
end

-- BoatServer builds the boat at start-up, but a run can rebuild it, so bind by name and re-attach.
local existing = Workspace:FindFirstChild("Boat")
if existing and existing:IsA("Model") then
	attach(existing)
end
Workspace.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Boat" and child:IsA("Model") then
		task.wait(0.5) -- let BoatServer finish welding Motor / DriverSeat on
		attach(child)
	end
end)
