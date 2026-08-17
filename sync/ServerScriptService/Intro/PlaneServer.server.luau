--!strict
-- PlaneServer.server.luau — plane-crash cold open (Job 044 → rewritten for the hand-built spawn base, Job 072).
--
-- The opening beat: the crew rides the plane in, the engine fails, it dives, and it crashes at the spawn
-- base — then they wake in the wreckage.
--   1. Claim the intro (Workspace.IntroActive) so PlayerCombat doesn't place players yet.
--   2. HIDE the hand-placed wreck and fly a CLONE of it in along the SpawnBase.Dock.PlacePlace line.
--   3. Hover, hidden, while the readiness gate holds (Workspace.IntroReady — Job 043).
--   4. ⚠️ WAIT FOR THE LOADING SCREEN TO ACTUALLY BE GONE (not merely IntroReady — see the wait below),
--      then fly a LEVEL cruise, then the engine fails and only THEN does the nose drop.
--   5. Impact: fade to black, destroy the flying clone, REVEAL the real wreck with fire + smoke, lay the
--      crew out at SpawnBase.SpawnLocation, fade back in on the crash scene, then they come round.
--
-- ── WHY A CLONE, AND WHY THE POSE SWAP IS FREE ───────────────────────────────────────────────────────
-- The wreck (`SpawnBase.Plane`) is a single MeshPart, 88 x 95, resting at roll −41.5° with yaw 0 — the
-- crashed pose. The flight path you placed runs EAST (heading −84°), so flying it in the wreck's own
-- orientation would have it travelling sideways. We therefore fly LEVEL along the path with the nose
-- leading, and let the real wreck keep its own pose. The 0.45 s fade-to-black on impact hides the swap
-- completely, so no yaw/roll blending is needed — and blending 84° of yaw in the last second would have
-- read as a spin, not a crash.
--
-- The model's nose is local **+X**, not the usual −Z, so `CFrame.lookAt` alone poses it wrong. See
-- `MESH_FIX` below for the measured correction and why it has to be applied innermost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MAX_SEATS = 6

-- Audio (registry `audio.md` → "GAME place — plane-crash intro"). Ids live in ONE table; nothing below
-- writes an asset id inline, mirroring how the lobby resolves everything through Theme.sound.
local SFX = {
	engine = "rbxassetid://131906456545456", -- plane_flying   2D loop
	stall = "rbxassetid://109868059978369", -- engine_fail    2D one-shot
	alarm = "rbxassetid://112730854260419", -- stall_alarm    2D loop
	wind = "rbxassetid://96421007219531", -- wind_rush      2D loop, faded in
	crash = "rbxassetid://107234930559671", -- crash_sound    2D one-shot
	debris = "rbxassetid://139877854727588", -- metal_debris   positional @ wreck
	ringing = "rbxassetid://134266191078049", -- ear_ringing    2D one-shot
	fire = "rbxassetid://99475771894138", -- fire_sound     positional @ wreck, loop
}

Workspace:SetAttribute("IntroActive", true)

local fadeRemote = Instance.new("RemoteEvent")
fadeRemote.Name = "IntroFade"
fadeRemote.Parent = ReplicatedStorage

-- Clients report here once their loading screen is actually GONE (GameLoading fires it after the fade
-- completes and the GUI is destroyed). See the wait below for why IntroReady alone is not enough.
local loadedRemote = Instance.new("RemoteEvent")
loadedRemote.Name = "IntroLoaded"
loadedRemote.Parent = ReplicatedStorage
local loaded: { [Player]: boolean } = {}
loadedRemote.OnServerEvent:Connect(function(plr: Player)
	loaded[plr] = true
end)
Players.PlayerRemoving:Connect(function(plr)
	loaded[plr] = nil
end)

-- ── the hand-built spawn base ────────────────────────────────────────────────────────────────────────
local spawnBase = Workspace:WaitForChild("SpawnBase", 20)
local dockFolder = spawnBase and spawnBase:FindFirstChild("Dock")
local planePlace = dockFolder and dockFolder:FindFirstChild("PlacePlace")
local wreck = spawnBase and spawnBase:FindFirstChild("Plane")
if not (spawnBase and planePlace and planePlace:IsA("BasePart") and wreck) then
	warn("[Intro] missing SpawnBase.Dock.PlacePlace or SpawnBase.Plane — intro SKIPPED, players spawn normally")
	Workspace:SetAttribute("IntroActive", false)
	return
end

local function getHubPos(): Vector3
	local t0 = os.clock()
	while Workspace:GetAttribute("HubSpawn") == nil and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	return (Workspace:GetAttribute("HubSpawn") :: Vector3?) or (wreck :: Model):GetPivot().Position
end
local hubPos = getHubPos()

local wreckCF = (wreck :: Model):GetPivot()

-- ── 2D / positional sound helpers ────────────────────────────────────────────────────────────────────
-- A Sound parented to SoundService is NON-POSITIONAL (heard equally by everyone) — right for anything
-- happening "in the cabin" or in your head. Parented to a BasePart it becomes positional.
local audio = Instance.new("Folder")
audio.Name = "IntroAudio"
audio.Parent = SoundService

local function sound2D(id: string, looped: boolean, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.Parent = audio
	return s
end

local function soundAt(part: BasePart, id: string, looped: boolean, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 20
	s.RollOffMaxDistance = 400
	s.Parent = part
	return s
end

-- ── hide the real wreck until impact ─────────────────────────────────────────────────────────────────
-- Transparency + CanCollide, NOT re-parenting to ServerStorage: re-parenting would lose the exact
-- hand-placed CFrame and break anything holding a reference. Originals are stored per part, because the
-- meshes are not guaranteed to start at Transparency 0.
local wreckOriginal: { [BasePart]: { t: number, c: boolean } } = {}
local function setWreckHidden(hidden: boolean)
	for _, d in ipairs((wreck :: Instance):GetDescendants()) do
		if d:IsA("BasePart") then
			if wreckOriginal[d] == nil then
				wreckOriginal[d] = { t = d.Transparency, c = d.CanCollide }
			end
			local o = wreckOriginal[d]
			-- if-expressions, NOT `hidden and false or o.c`: that and-or can never yield false, so the
			-- hidden wreck would have kept its collision and players would walk into an invisible plane.
			d.Transparency = if hidden then 1 else o.t
			d.CanCollide = if hidden then false else o.c
		end
	end
end
if wreck:IsA("BasePart") then
	wreckOriginal[wreck] = { t = wreck.Transparency, c = wreck.CanCollide }
end
setWreckHidden(true)
if wreck:IsA("BasePart") then
	wreck.Transparency = 1
	wreck.CanCollide = false
end

-- ── the flying plane: a clone of the wreck ───────────────────────────────────────────────────────────
local START_POS = planePlace.Position
local IMPACT_POS = wreckCF.Position + Vector3.new(0, 6, 0) -- a touch above the resting pose
local delta = IMPACT_POS - START_POS
local flatDir = Vector3.new(delta.X, 0, delta.Z)
flatDir = if flatDir.Magnitude > 0.01 then flatDir.Unit else Vector3.new(0, 0, -1)

-- ⚠️ THE MESH DOES NOT USE THE STANDARD ROBLOX AXES. Its nose is local **+X** and its belly local −Z —
-- NOT the usual nose = −Z. Measured in Studio, not guessed: a clone posed with plain `CFrame.lookAt` and
-- no correction hangs NOSE STRAIGHT DOWN, and `flatDir:Dot(cf.RightVector)` comes back 1.000.
--
-- `MESH_FIX` is the one rotation that maps mesh axes onto flight axes (nose forward, wings level, gear
-- down). It MUST be applied INNERMOST — i.e. last in the multiply chain:
--
--     lookAt(...) * CFrame.Angles(pitch, 0, roll) * MESH_FIX      ✅ pitch/roll act in the FLIGHT frame
--     lookAt(...) * CFrame.Angles(pitch, 0, roll + MESH_ROLL)     ❌ roll then swings the NOSE, not the wings
--
-- The earlier version folded the correction into the roll term, which is why the plane flew at a wrong
-- attitude for the whole cold open: with the nose on local +X, rotating about local Z moves the nose
-- instead of banking the aircraft. Verified in Studio at (pitch 0, roll 0), (0, +25°) and (−20°, +15°),
-- photographed from the side against a horizon bar and from behind — level is level, bank is bank, and
-- a NEGATIVE pitch is nose-down.
--
-- This also explains the wreck's odd −41.5° part roll: measured against the corrected frame the resting
-- pose is tipped onto a wingtip, which is exactly how a crashed plane should sit.
local MESH_FIX = CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(-90))

-- The AIRCRAFT BODY frame — standard Roblox axes: nose −Z, up +Y, right +X.
-- ⚠️ ANYTHING that reasons about the aircraft's body (seats, mounting offsets, bounding sizes) MUST use
-- this, never `flyer:GetPivot()`. The pivot carries MESH_FIX, so in the model's own frame "Y" points out
-- of the LEFT WING and "Z" points at the SKY. Measured in the body frame the aircraft is
-- 95.0 wide × 34.3 tall × 88.2 long; in the model frame `GetBoundingBox()` reports those as
-- (88.2, 95.0, 34.3), which is how the seat rig ended up spraying passengers out of the fuselage.
local function bodyCF(pos: Vector3, pitch: number, roll: number): CFrame
	return CFrame.lookAt(pos, pos + flatDir) * CFrame.Angles(pitch, 0, roll)
end

local function flightCF(pos: Vector3, pitch: number, roll: number): CFrame
	return bodyCF(pos, pitch, roll) * MESH_FIX
end

-- The chase camera must NOT re-derive "forward" from the plane's pivot — with the nose on local +X,
-- `LookVector` points straight up. Publish the flight heading instead: one authority, no baked-axis
-- knowledge duplicated in the client.
Workspace:SetAttribute("IntroPlaneDir", flatDir)

-- ── flight profile ───────────────────────────────────────────────────────────────────────────────────
-- Defined up here because the plane is BUILT at HOVER_POS.
--   · the cruise HOLDS ALTITUDE — all 227 studs of height loss belong to the dive
--   · PlacePlace → impact is only ~459 studs of ground track, so cruising that alone would be ~14
--     studs/s, which reads as hovering. The spawn is therefore backed up along your flight line so the
--     plane has a real run-in and passes OVER PlacePlace a few seconds in. PlacePlace defines the LINE
--     and ALTITUDE of the approach, which is what "fly in from this direction" means.
local CRUISE_TIME = 10
local DESCENT_TIME = 9
local CRUISE_SPEED = 45 -- studs/s
local CRUISE_FRACTION = 0.3 -- where along the track the engine gives out
local CRUISE_END = Vector3.new(
	START_POS.X + (IMPACT_POS.X - START_POS.X) * CRUISE_FRACTION,
	START_POS.Y, -- <- held: level flight
	START_POS.Z + (IMPACT_POS.Z - START_POS.Z) * CRUISE_FRACTION
)
local HOVER_POS = CRUISE_END - flatDir * (CRUISE_SPEED * CRUISE_TIME)

local flyer: Model
do
	local src = wreck :: Instance
	local clone = src:Clone()
	if clone:IsA("BasePart") then
		local m = Instance.new("Model")
		clone.Parent = m
		m.PrimaryPart = clone
		flyer = m
	else
		flyer = clone :: Model
	end
end
flyer.Name = "IntroPlane"
for _, d in ipairs(flyer:GetDescendants()) do
	if d:IsA("BasePart") then
		local o = wreckOriginal[d]
		d.Transparency = 0 -- the clone is the VISIBLE plane (the source was just hidden)
		d.CanCollide = false -- must never bump terrain on the way down
		d.Anchored = true
		d.CastShadow = true
		if o then
			d.Transparency = o.t
		end
	end
end
if flyer.PrimaryPart == nil then
	flyer.PrimaryPart = flyer:FindFirstChildWhichIsA("BasePart", true)
end
-- 🔴 Job #091: PUBLISH THE POSE, don't just set it.
--
-- `flyer` is an ANCHORED model. A server script writing an anchored part's CFrame replicates as
-- discrete property writes, and the client does NOT interpolate them the way it interpolates a physics
-- body — so the plane's rendered position arrives in visible steps. Smoothing the camera alone could
-- never fix that (Job #091 first attempt): the camera got smooth and the PLANE went on stepping inside
-- a smooth frame, which is what "plane still glitches" was.
--
-- So every pose is also written to `Workspace.IntroPlaneCF`, and `IntroPlaneSmooth.local.luau` renders
-- the plane from THAT, interpolated. The attribute exists because the client poses the model locally:
-- once it does, reading the model's own CFrame back would return the client's value, not the server's.
-- The attribute is the one source a local write can never clobber.
--
-- ⚠️ Use this instead of a bare `flyer:PivotTo(...)` for any flight pose, or the client's smoother has
-- nothing to follow and that segment of the flight will step again.
local function poseFlyer(cf: CFrame)
	flyer:PivotTo(cf)
	Workspace:SetAttribute("IntroPlaneCF", cf)
end

poseFlyer(flightCF(HOVER_POS, 0, 0))
flyer.Parent = Workspace

-- Engine drone rides the plane's own position so it grows as the plane closes in.
-- ⚠️ CREATED HERE BUT NOT PLAYED HERE. The plane is built at script start and then hovers behind the
-- loading screen for several seconds; playing the engine now meant players heard it droning over the
-- loading mask before they could see anything. It starts at the same gate the cruise does — see the
-- ENGINE UP cue after the load wait.
local ENGINE_VOLUME = 0.6
local enginePart = flyer.PrimaryPart :: BasePart
local engineSnd = soundAt(enginePart, SFX.engine, true, 0)

-- smoke from the failing engine (off until the stall)
local smoke = Instance.new("Smoke")
smoke.Enabled = false
smoke.Color = Color3.fromRGB(40, 40, 40)
smoke.Opacity = 0.6
smoke.RiseVelocity = 6
smoke.Size = 8
smoke.Parent = enginePart

-- ── seats, so the crew rides it down ─────────────────────────────────────────────────────────────────
-- The mesh has no interior, so the seats are invisible pads down the fuselage centreline. They exist to
-- carry the players INSIDE the fuselage shell, not to be seen.
--
-- ⚠️ BUILT IN THE BODY FRAME, NOT `flyer:GetPivot()`. The first version used the pivot and the model's
-- own `GetBoundingBox()`, so its three "rows" were spread 4 studs apart VERTICALLY (it had read the
-- 34.3-stud height as the fuselage length), its two "columns" were spread fore-and-aft, and its −1.5
-- "down" offset pushed everyone sideways out through the wing root. The crew rode the intro sitting in
-- mid-air beside the aircraft, tilted on their side — which is exactly what the user saw.
--
-- Rows run along body −Z (fore/aft) and stay inside the ±44-stud fuselage; columns straddle the
-- centreline; SEAT_Y drops them into the tube so the shell hides them.
local SEAT_Y = -3
local seats: { Seat } = {}
do
	local body = flyer:GetPivot() * MESH_FIX:Inverse()
	local rows = { -11, 0, 11 } -- fore/aft, well clear of the nose and tail
	local cols = { -2.2, 2.2 } -- either side of the fuselage centreline
	for _, dz in rows do
		for _, dx in cols do
			if #seats >= MAX_SEATS then
				break
			end
			local s = Instance.new("Seat")
			s.Name = "PlaneSeat" .. (#seats + 1)
			s.Anchored = true
			s.CanCollide = false
			s.Transparency = 1
			s.Size = Vector3.new(2.4, 0.6, 2.4)
			-- body frame → the pad is level and faces the nose, so the crew sits upright facing forward
			s.CFrame = body * CFrame.new(dx, SEAT_Y, dz)
			s.Parent = flyer
			table.insert(seats, s)
		end
	end
end

local function freeSeat(): Seat?
	for _, s in seats do
		if s.Occupant == nil then
			return s
		end
	end
	return nil
end

-- Pin a passenger into their seat for the duration of the flight. Pressing jump normally UNSEATS a
-- character, so players could bail out mid-air and fall to the jungle. Disabling the Jumping state is
-- what actually stops the eject (JumpHeight/JumpPower alone do not — the seat exit is driven by the jump
-- INPUT, not by the jump force), and the client sinks the input too so it never even fires.
-- `Seated` is the backstop: if anything does shake them loose while the intro is running, re-seat them.
local function lockPassenger(hum: Humanoid)
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hum.JumpHeight = 0
	hum.JumpPower = 0
	hum.WalkSpeed = 0
end

local function seatCharacter(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local s = freeSeat()
	if not s then
		return -- more than MAX_SEATS: the overflow simply rides out the intro unseated
	end
	task.spawn(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		local t0 = os.clock()
		while not root and os.clock() - t0 < 5 do
			task.wait()
			root = char:FindFirstChild("HumanoidRootPart")
		end
		if s.Occupant == nil and hum.Parent then
			s:Sit(hum)
			lockPassenger(hum)
		end
	end)

	hum.Seated:Connect(function(active: boolean)
		if active then
			return
		end
		-- only while we're still airborne: IntroWake is the crash, after which they're MEANT to be loose
		if Workspace:GetAttribute("IntroActive") ~= true or Workspace:GetAttribute("IntroWake") == true then
			return
		end
		task.wait()
		local again = freeSeat()
		if again and hum.Parent and Workspace:GetAttribute("IntroActive") == true then
			again:Sit(hum)
			lockPassenger(hum)
		end
	end)
end

local function onCharacter(char: Model)
	if Workspace:GetAttribute("IntroActive") then
		seatCharacter(char)
	end
end

for _, plr in Players:GetPlayers() do
	if plr.Character then
		onCharacter(plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacter)
end
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(onCharacter)
	if plr.Character then
		onCharacter(plr.Character)
	end
end)

-- ── hover while the gate holds ───────────────────────────────────────────────────────────────────────
local hovering = true
task.spawn(function()
	local t = 0
	while hovering do
		local dt = task.wait()
		t += dt
		local bob = math.sin(t * 0.8) * 4
		-- gentle BANK, not a yaw tacked on after flightCF: anything applied after the mesh-roll
		-- correction rotates about an axis that is no longer world-up, so a "yaw" there pitches the nose.
		local bank = math.rad(math.sin(t * 0.4) * 3)
		poseFlyer(flightCF(HOVER_POS + Vector3.new(0, bob, 0), 0, bank))
	end
end)

if Workspace:GetAttribute("IntroReady") == false then
	while Workspace:GetAttribute("IntroReady") ~= true do
		Workspace:GetAttributeChangedSignal("IntroReady"):Wait()
	end
else
	task.wait(2)
end

-- ⚠️ IntroReady ONLY MEANS THE SERVER IS READY — it is not the moment the player can see anything.
-- After it flips, GameLoading still runs out MIN_SHOWN (1.5 s), a 0.25 s settle and a 0.6 s fade before
-- destroying the mask. Starting the cruise here flew the opening seconds behind the loading screen, so
-- players were dropped into a flight already in progress. Wait for every present client to report its
-- loader gone, with a timeout so one slow machine can't stall everyone else's run.
local LOAD_TIMEOUT = 12
do
	local t0 = os.clock()
	while os.clock() - t0 < LOAD_TIMEOUT do
		local present = Players:GetPlayers()
		local all = #present > 0
		for _, p in ipairs(present) do
			if not loaded[p] then
				all = false
				break
			end
		end
		if all then
			break
		end
		task.wait(0.1)
	end
	task.wait(0.5) -- a beat on the revealed scene before anything moves
end

-- ENGINE UP — the first sound of the run, and only now that the loading mask is provably gone.
-- Faded in rather than snapped on, so it reads as the cabin coming up around you.
engineSnd.Volume = 0
engineSnd:Play()
TweenService:Create(engineSnd, TweenInfo.new(1.2), { Volume = ENGINE_VOLUME }):Play()

-- ── CRUISE: genuinely LEVEL flight (profile defined near the top) ────────────────────────────────────
hovering = false
task.wait()

do
	local from = flyer:GetPivot().Position
	local elapsed = 0
	while elapsed < CRUISE_TIME do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local a = math.clamp(elapsed / CRUISE_TIME, 0, 1)
		local eased = a * a * (3 - 2 * a)
		local pos = from:Lerp(CRUISE_END, eased)
		local bob = math.sin(elapsed * 1.2) * 3
		local roll = math.rad(math.sin(elapsed * 0.6) * 8)
		poseFlyer(flightCF(pos + Vector3.new(0, bob, 0), 0, roll))
	end
end

-- ── ENGINE FAILURE → the dive ────────────────────────────────────────────────────────────────────────
local stallSnd = sound2D(SFX.stall, false, 0.9)
stallSnd:Play()
local alarmSnd = sound2D(SFX.alarm, true, 0.35)
alarmSnd:Play()
local windSnd = sound2D(SFX.wind, true, 0) -- faded IN across the dive, never played flat
windSnd:Play()
smoke.Enabled = true
engineSnd.PlaybackSpeed = 0.75 -- the engine drops away as it fails

local descentPitch = math.atan2(CRUISE_END.Y - IMPACT_POS.Y, (Vector3.new(IMPACT_POS.X - CRUISE_END.X, 0, IMPACT_POS.Z - CRUISE_END.Z)).Magnitude)
do
	local from = flyer:GetPivot().Position
	local elapsed = 0
	while elapsed < DESCENT_TIME do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local a = math.clamp(elapsed / DESCENT_TIME, 0, 1)
		local eased = a * a -- accelerate into the ground rather than easing out of it
		local pos = from:Lerp(IMPACT_POS, eased)
		local shake = math.sin(elapsed * 22) * math.rad(1.6) * a -- the airframe starts to judder
		windSnd.Volume = 0.85 * a
		poseFlyer(flightCF(pos, -descentPitch * a + shake, math.rad(math.sin(elapsed * 3) * 10) * a))
	end
end

-- ── IMPACT ───────────────────────────────────────────────────────────────────────────────────────────
sound2D(SFX.crash, false, 1):Play()
fadeRemote:FireAllClients("out", 0.35)
engineSnd:Stop()
alarmSnd:Stop()
windSnd:Stop()
task.wait(0.45) -- black screen: the pose swap happens entirely behind this

flyer:Destroy()
setWreckHidden(false)
if wreck:IsA("BasePart") then
	local o = wreckOriginal[wreck]
	wreck.Transparency = o and o.t or 0
	wreck.CanCollide = o and o.c or true
end

-- ── the burning wreck ────────────────────────────────────────────────────────────────────────────────
-- Full fire for BURN_TIME, then the flames fade and a smoke column remains: dramatic while players are
-- looking straight at it, then a fraction of the particle cost for the rest of the run — and the smoke
-- still marks the camp on the horizon. Emitters are attached at a few points, not one per part.
local BURN_TIME = 45
local anchor: BasePart? = if wreck:IsA("BasePart") then wreck else wreck:FindFirstChildWhichIsA("BasePart", true)
if anchor then
	local fireSnd = soundAt(anchor, SFX.fire, true, 0.75)
	fireSnd:Play()
	soundAt(anchor, SFX.debris, false, 0.8):Play()

	-- ⚠️ MEASURE THE REAL WORLD AABB, AND PARENT BEFORE POSITIONING. Two bugs lived here:
	--
	-- 1. `a.WorldPosition = …` ran while the Attachment still had NO parent, so the engine stored it as
	--    a LOCAL position and then re-anchored it to `anchor.CFrame` on parenting. The emitters landed
	--    ~200 studs away and 220 studs UP (measured live: wreck at −303,28,−288 · fire at −512,249,−593),
	--    which is why the crash site never caught fire even though the Fire/Smoke objects all existed.
	--    Parent FIRST, then set WorldPosition.
	--
	-- 2. The offsets were derived from `GetBoundingBox()` in the wreck's own frame, which says nothing
	--    useful here: the wreck lies nose-down with the tail in the air, so its oriented box
	--    (88.2 × 34.3 × 95.0) bears no relation to how it occupies the world (X 89 · Y 85 · Z 95,
	--    spanning Y −15 up to Y 70). `GetExtentsSize()` is no help — it reports the ORIENTED size too.
	--    So the world AABB is measured from the part corners and the flames are placed in world space.
	local minv = Vector3.new(math.huge, math.huge, math.huge)
	local maxv = Vector3.new(-math.huge, -math.huge, -math.huge)
	local function envelop(p: BasePart)
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local c = p.CFrame * (p.Size * Vector3.new(sx, sy, sz))
					minv = Vector3.new(math.min(minv.X, c.X), math.min(minv.Y, c.Y), math.min(minv.Z, c.Z))
					maxv = Vector3.new(math.max(maxv.X, c.X), math.max(maxv.Y, c.Y), math.max(maxv.Z, c.Z))
				end
			end
		end
	end
	if wreck:IsA("BasePart") then
		envelop(wreck)
	end
	for _, d in ipairs((wreck :: Instance):GetDescendants()) do
		if d:IsA("BasePart") then
			envelop(d)
		end
	end

	local centre = (minv + maxv) * 0.5
	local span = maxv - minv
	-- Sit the flames near the SAND LINE, not the box centre. The nose is buried, so the box centre is
	-- close to ground level anyway, but the fire has to start outside the hull or it just burns inside
	-- an opaque mesh and reads as nothing at all.
	local baseY = minv.Y + span.Y * 0.45
	local spots = {
		Vector3.new(centre.X, baseY, centre.Z),
		Vector3.new(centre.X + span.X * 0.18, baseY + span.Y * 0.10, centre.Z + span.Z * 0.10),
		Vector3.new(centre.X - span.X * 0.16, baseY + span.Y * 0.05, centre.Z - span.Z * 0.14),
	}

	local fires, smokes, lights = {}, {}, {}
	for i, wp in ipairs(spots) do
		local a = Instance.new("Attachment")
		a.Name = "CrashFX" .. i
		a.Parent = anchor -- parent FIRST — see the note above
		a.WorldPosition = wp

		local f = Instance.new("Fire")
		f.Heat = 14
		f.Size = 12
		f.Color = Color3.fromRGB(255, 150, 40)
		f.SecondaryColor = Color3.fromRGB(120, 40, 10)
		f.Parent = a
		table.insert(fires, f)

		local sm = Instance.new("Smoke")
		sm.Color = Color3.fromRGB(35, 33, 32)
		sm.Opacity = 0.5
		sm.RiseVelocity = 11
		sm.Size = 14
		sm.Parent = a
		table.insert(smokes, sm)

		local lt = Instance.new("PointLight")
		lt.Color = Color3.fromRGB(255, 150, 70)
		lt.Brightness = 4
		lt.Range = 42
		lt.Shadows = false
		lt.Parent = a
		table.insert(lights, lt)
	end

	task.delay(BURN_TIME, function()
		for _, f in ipairs(fires) do
			TweenService:Create(f, TweenInfo.new(8), { Size = 0, Heat = 0 }):Play()
		end
		for _, lt in ipairs(lights) do
			TweenService:Create(lt, TweenInfo.new(8), { Brightness = 0 }):Play()
		end
		for _, sm in ipairs(smokes) do
			TweenService:Create(sm, TweenInfo.new(8), { Opacity = 0.22, Size = 9 }):Play()
		end
		TweenService:Create(fireSnd, TweenInfo.new(8), { Volume = 0.12 }):Play()
		task.delay(9, function()
			for _, f in ipairs(fires) do
				f.Enabled = false
			end
		end)
	end)
end

-- ── the crew wakes in the wreckage ───────────────────────────────────────────────────────────────────
Workspace:SetAttribute("IntroWake", true)
sound2D(SFX.ringing, false, 0.7):Play()

for _, plr in Players:GetPlayers() do
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum then
		hum.Sit = false
		hum.PlatformStand = true -- limp: no auto-stand while unconscious
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	end
	if root then
		local px, pz = math.random(-5, 5), math.random(-5, 5)
		root.CFrame = CFrame.new(hubPos + Vector3.new(px, 1.5, pz))
			* CFrame.Angles(math.rad(-90), math.random() * math.pi * 2, 0)
	end
end

task.wait(0.2)
fadeRemote:FireAllClients("in", 1.2) -- fade in ON the crash scene, still down
task.wait(2.6) -- the client camera rises through this window

for _, plr in Players:GetPlayers() do
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = CFrame.new(hubPos + Vector3.new(math.random(-5, 5), 3, math.random(-5, 5)))
	end
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = 16
		hum.JumpHeight = 7.2
		hum.JumpPower = 50
		-- hand jumping back: `lockPassenger` disabled the state to stop them bailing out mid-flight
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

Workspace:SetAttribute("IntroWake", false)
Workspace:SetAttribute("IntroActive", false)

print("[Intro] crash cold-open complete — crew woke at the spawn base, wreck burning")
