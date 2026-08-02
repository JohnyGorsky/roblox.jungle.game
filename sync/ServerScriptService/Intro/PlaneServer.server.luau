--!strict
-- PlaneServer.server.luau — plane-crash cold open (Job 044 → rewritten for the hand-built spawn base, Job 072).
--
-- The opening beat: the crew rides the plane in, the engine fails, it dives, and it crashes at the spawn
-- base — then they wake in the wreckage. Runs BEHIND the loading-screen mask:
--   1. Claim the intro (Workspace.IntroActive) so PlayerCombat doesn't place players yet.
--   2. HIDE the hand-placed wreck and fly a CLONE of it in from SpawnBase.Dock.PlacePlace, seats and all.
--   3. Hover while the readiness gate holds (Workspace.IntroReady — Job 043).
--   4. On IntroReady: cruise, then engine failure → smoking dive.
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
-- The model's nose is local −Z (verified from above in Studio), which is exactly what `CFrame.lookAt`
-- points along its target direction — so no 180° flip constant is needed.

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

-- ⚠️ THE MESH IS BAKED A QUARTER-TURN INSIDE ITS PART.
-- `CFrame.lookAt` correctly points the part's −Z along the flight path (the nose IS −Z), but at roll 0
-- the aircraft flies KNIFE-EDGE: wings vertical, star roundels facing sideways. Verified in Studio by
-- levelling clones at 0 / ±41.5 / ±90 and photographing them head-on down the flight line — only −90°
-- puts the wings horizontal with the engine nacelles under them and the tailplane up.
--
-- This also explains the wreck's odd −41.5° part roll: the resting pose is 90 − 41.5 ≈ 48° of visual
-- bank, i.e. tipped onto a wingtip — which is exactly how a crashed plane should sit.
--
-- Applied LAST so it spins the aircraft about its own fuselage axis, after pitch and roll have been
-- applied in the world-aligned flight frame.
local MESH_ROLL = math.rad(-90)

local function flightCF(pos: Vector3, pitch: number, roll: number): CFrame
	return CFrame.lookAt(pos, pos + flatDir) * CFrame.Angles(pitch, 0, roll) * CFrame.Angles(0, 0, MESH_ROLL)
end

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
flyer:PivotTo(flightCF(START_POS, 0, 0))
flyer.Parent = Workspace

-- engine drone rides the plane's own position so it grows as the plane closes in
local enginePart = flyer.PrimaryPart :: BasePart
local engineSnd = soundAt(enginePart, SFX.engine, true, 0.6)
engineSnd:Play()

-- smoke from the failing engine (off until the stall)
local smoke = Instance.new("Smoke")
smoke.Enabled = false
smoke.Color = Color3.fromRGB(40, 40, 40)
smoke.Opacity = 0.6
smoke.RiseVelocity = 6
smoke.Size = 8
smoke.Parent = enginePart

-- ── seats, so the crew rides it down ─────────────────────────────────────────────────────────────────
-- The mesh has no interior, so the seats are invisible pads welded along the fuselage centreline. They
-- exist to carry the players, not to be seen.
local seats: { Seat } = {}
do
	local _, size = flyer:GetBoundingBox()
	local rows = { -size.Z * 0.12, 0, size.Z * 0.12 }
	local cols = { -2.2, 2.2 }
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
			s.CFrame = flyer:GetPivot() * CFrame.new(dx, -1.5, dz)
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
		local yaw = math.rad(math.sin(t * 0.4) * 4)
		flyer:PivotTo(flightCF(START_POS + Vector3.new(0, bob, 0), 0, 0) * CFrame.Angles(0, yaw, 0))
	end
end)

if Workspace:GetAttribute("IntroReady") == false then
	while Workspace:GetAttribute("IntroReady") ~= true do
		Workspace:GetAttributeChangedSignal("IntroReady"):Wait()
	end
else
	task.wait(2)
end

-- ── CRUISE: level flight along the first half of the path ────────────────────────────────────────────
local CRUISE_TIME = 10
local DESCENT_TIME = 9 -- Job #072: 9 s, so the 513-stud approach reads as a glide (~57 studs/s) not a drop
local CRUISE_END = START_POS:Lerp(IMPACT_POS, 0.45)

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
		flyer:PivotTo(flightCF(pos + Vector3.new(0, bob, 0), 0, roll))
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
		flyer:PivotTo(flightCF(pos, -descentPitch * a + shake, math.rad(math.sin(elapsed * 3) * 10) * a))
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

	local _, wsize = (wreck :: Model):GetBoundingBox()
	local spots = {
		Vector3.new(0, 0, -wsize.Z * 0.18),
		Vector3.new(-wsize.X * 0.16, 0, 0),
		Vector3.new(wsize.X * 0.16, 0, 0),
	}
	local fires, smokes, lights = {}, {}, {}
	for i, off in ipairs(spots) do
		local a = Instance.new("Attachment")
		a.Name = "CrashFX" .. i
		a.WorldPosition = wreckCF * off
		a.Parent = anchor

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
	end
end

Workspace:SetAttribute("IntroWake", false)
Workspace:SetAttribute("IntroActive", false)

print("[Intro] crash cold-open complete — crew woke at the spawn base, wreck burning")
