--!strict
-- BoatEngineSound.local.luau — the boat's LIVE engine                                  [Job #073]
-- ============================================================================================
-- Two sounds, both positional on the boat's `Motor` part (welded at the stern by BoatServer):
--   · boat_engine_starts — one-shot, when a player takes the helm
--   · speed_boat_loop    — loop, whose volume AND pitch track how hard the boat is actually working
--
-- ── WHY THIS IS A CLIENT SCRIPT ─────────────────────────────────────────────────────────────
-- The volume and pitch change EVERY FRAME. Doing that on the server would replicate two property
-- writes per frame to every client for no benefit whatsoever. The boat is server-owned
-- (`BoatServer` calls `SetNetworkOwner(nil)`), so `AssemblyLinearVelocity` and `seat.Throttle`
-- already replicate — each client reads those and drives its own local Sound.
--
-- Client-created Sounds parented to a replicated part stay local to that client, so there is no
-- duplication and no fighting between players over the same instance.
--
-- ── "IT MUST BE LIVE" — WHAT DRIVES IT ──────────────────────────────────────────────────────
-- Not the throttle key alone, and not the speed alone:
--   · speed alone lags the player's input — you press W and hear nothing for half a second
--   · throttle alone is binary (VehicleSeat.Throttle is 1 / 0 / −1), so it can't express "labouring
--     up to speed" vs "cruising", which is the whole point of an engine note
-- So it takes the MAX of real speed and a fraction of raw throttle: the key gives an instant
-- response, and the actual hull speed takes over as the boat gets going.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Ids live in ONE table; nothing below writes an asset id inline. Registry `audio.md` →
-- "GAME place — boat engine".
local SFX = {
	start = "rbxassetid://105048345579705", -- boat_engine_starts
	loop = "rbxassetid://74719520771875", -- speed_boat_loop
}

local TOP_SPEED = 30 -- studs/s; BoatServer's THRUST/DRAG works out to ≈30, so this is the "full" reference
local THROTTLE_LEAD = 0.55 -- how much of the note pressing W buys you before the boat has actually moved

local IDLE_VOL, MAX_VOL = 0.16, 0.62
local IDLE_PITCH, MAX_PITCH = 0.72, 1.32
local START_VOL = 0.7

local ROLL_MIN, ROLL_MAX = 12, 200 -- the engine carries a good way across open water
local RESPONSE = 6 -- how fast the note chases its target (higher = snappier, less smooth)

-- "Stop when the boat is stopped" (user's words). A boat with someone at the helm normally idles, so
-- cutting the loop the instant it touches zero would chatter on and off at every dock. Instead it must
-- be BELOW the threshold with no throttle for a moment before the engine goes quiet, and it resumes
-- without re-playing the start one-shot (the engine never actually turned over again).
local STOP_SPEED = 1.5 -- studs/s below which the boat counts as stopped
local STOP_AFTER = 1.2 -- seconds of that before the loop fades out
local FADE = 0.5 -- seconds to fade the loop in/out

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

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local conn: RBXScriptConnection? = nil
local occConn: RBXScriptConnection? = nil

local function detach()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if occConn then
		occConn:Disconnect()
		occConn = nil
	end
end

local function attach(boat: Model)
	detach()

	local hull = (boat.PrimaryPart or boat:FindFirstChild("Hull")) :: BasePart?
	local seat = boat:FindFirstChild("DriverSeat") :: VehicleSeat?
	if not hull or not seat then
		warn("[BoatEngineSound] boat has no Hull/DriverSeat — no engine sound")
		return
	end
	-- The Motor sits at the stern, which is where an engine should be heard from. Fall back to the hull
	-- rather than bailing: a boat with no motor part is still better off audible.
	local anchor = (boat:FindFirstChild("Motor") or hull) :: BasePart

	local engine = makeSound(SFX.loop, true, 0)
	engine.Name = "EngineLoop"
	engine.Parent = anchor

	local starter = makeSound(SFX.start, false, START_VOL)
	starter.Name = "EngineStart"
	starter.Parent = anchor

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

	-- the start one-shot fires on an EMPTY→OCCUPIED transition only, so hopping between the helm and a
	-- crew seat doesn't re-crank the engine
	occConn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant then
			starter:Play()
		end
	end)
	if seat.Occupant then
		setRunning(true)
	end

	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not (anchor.Parent and hull.Parent) then
			detach()
			return
		end

		local vel = hull.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local throttle = math.abs(seat.Throttle)

		-- see the header: instant response from the key, authority from the real hull speed
		local target = math.max(math.min(speed / TOP_SPEED, 1), throttle * THROTTLE_LEAD)
		drive += (target - drive) * math.min(1, RESPONSE * dt)

		if seat.Occupant then
			if speed < STOP_SPEED and throttle == 0 then
				idleFor += dt
				if idleFor >= STOP_AFTER then
					setRunning(false)
				end
			else
				idleFor = 0
				setRunning(true)
			end
		else
			idleFor = 0
			setRunning(false)
		end

		if running then
			engine.Volume = lerp(IDLE_VOL, MAX_VOL, drive)
			engine.PlaybackSpeed = lerp(IDLE_PITCH, MAX_PITCH, drive)
		end
	end)
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
