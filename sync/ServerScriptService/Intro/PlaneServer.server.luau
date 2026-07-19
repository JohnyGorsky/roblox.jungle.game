--!strict
-- PlaneServer.server.luau — plane intro cinematic (Job 044, step 3 of game-intro-sequence).
--
-- The opening beat: the crew rides a plane in that goes down over the jungle, ending at the crash-site hub
-- (whose existing PlaneWreck greybox is "the plane" after it crashes). Runs BEHIND the loading-screen mask:
--   1. At startup, claim the intro (Workspace.IntroActive = true) so PlayerCombat doesn't place players yet.
--   2. Build a greybox plane in the sky above the hub with up to 6 seats; force-seat every crew member.
--   3. Hover (gentle bob) while the readiness gate holds (Workspace.IntroReady ~= true — Job 043).
--   4. On IntroReady: smoking, nose-down DESCENT toward the hub (the loader fades → the plane is revealed).
--   5. At "impact": fade to black (client IntroFade), unseat everyone, place them at HubSpawn, remove the
--      flying plane (the hub's PlaneWreck remains as the crashed plane), fade back in, IntroActive = false.
--
-- Greybox: no hero art, no cinematic camera yet (camera just follows the seated character). The prone
-- wake-up cold-open + camera work is the next job. Anchored plane moved by CFrame; Seats weld the crew so
-- they ride along.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_SEATS = 6

-- claim the intro IMMEDIATELY so PlayerCombat defers its hub/boat placement (players ride the plane instead)
Workspace:SetAttribute("IntroActive", true)

-- client black-overlay fade for the impact cut (client script waits for this)
local fadeRemote = Instance.new("RemoteEvent")
fadeRemote.Name = "IntroFade"
fadeRemote.Parent = ReplicatedStorage

-- ── where the hub is (plane flies in above it) ───────────────────────────────────────────────────────────
local function getHubPos(): Vector3
	local t0 = os.clock()
	while Workspace:GetAttribute("HubSpawn") == nil and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	local hub = Workspace:GetAttribute("HubSpawn") :: Vector3?
	return hub or Vector3.new(0, 20, 0)
end

local hubPos = getHubPos()
local START_CF = CFrame.new(hubPos + Vector3.new(0, 260, -180)) * CFrame.Angles(0, 0, 0)
local END_CF = CFrame.new(hubPos + Vector3.new(0, 32, 40)) * CFrame.Angles(math.rad(-28), 0, 0) -- nose-down low pass

-- ── build the greybox plane ──────────────────────────────────────────────────────────────────────────────
local plane = Instance.new("Model")
plane.Name = "IntroPlane"

local function part(name: string, size: Vector3, color: Color3, localCF: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = START_CF * localCF
	p.Parent = parent
	return p
end

local BODY = Color3.fromRGB(150, 150, 160)
local fuselage = part("Fuselage", Vector3.new(8, 6, 34), BODY, CFrame.new(0, 0, 0), plane)
plane.PrimaryPart = fuselage
part("WingL", Vector3.new(22, 1, 8), BODY, CFrame.new(-14, 0.5, 0), plane)
part("WingR", Vector3.new(22, 1, 8), BODY, CFrame.new(14, 0.5, 0), plane)
part("TailFin", Vector3.new(1, 6, 6), BODY, CFrame.new(0, 4, 15), plane)
part("TailL", Vector3.new(10, 1, 5), BODY, CFrame.new(-4, 2, 15), plane)
part("TailR", Vector3.new(10, 1, 5), BODY, CFrame.new(4, 2, 15), plane)
part("Nose", Vector3.new(6, 5, 5), Color3.fromRGB(120, 120, 130), CFrame.new(0, 0, -18.5), plane)

-- seats: two rows of three down the fuselage floor (greybox open-top so you can see the crew aboard)
local seats: { Seat } = {}
local SEAT_Y = -1.5
local rows = { -6, 0, 6 } -- along the fuselage (Z)
local cols = { -1.8, 1.8 } -- side by side (X)
for _, z in rows do
	for _, x in cols do
		if #seats >= MAX_SEATS then
			break
		end
		local s = Instance.new("Seat")
		s.Name = "PlaneSeat" .. (#seats + 1)
		s.Anchored = true
		s.CanCollide = false
		s.Size = Vector3.new(2.4, 0.6, 2.4)
		s.Color = Color3.fromRGB(90, 80, 70)
		s.Material = Enum.Material.SmoothPlastic
		s.CFrame = START_CF * CFrame.new(x, SEAT_Y, z)
		s.Parent = plane
		table.insert(seats, s)
	end
end

-- smoke (starts off; turned on for the descent)
local smoke = Instance.new("Smoke")
smoke.Enabled = false
smoke.Color = Color3.fromRGB(40, 40, 40)
smoke.Opacity = 0.6
smoke.RiseVelocity = 6
smoke.Size = 8
smoke.Parent = fuselage

plane.Parent = Workspace

-- ── seating the crew ─────────────────────────────────────────────────────────────────────────────────────
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
		return -- more than MAX_SEATS players: overflow just rides the descent unseated near the hub
	end
	-- wait a beat for the HRP so :Sit welds cleanly, then force-sit
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
	if not Workspace:GetAttribute("IntroActive") then
		return
	end
	seatCharacter(char)
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

-- ── hover while the gate holds ───────────────────────────────────────────────────────────────────────────
local hovering = true
task.spawn(function()
	local t = 0
	while hovering do
		local dt = task.wait()
		t += dt
		-- gentle bob + slow rise so it reads as "airborne, circling"
		local bob = math.sin(t * 0.8) * 4
		local rise = math.min(t * 2, 40)
		plane:PivotTo(START_CF * CFrame.new(0, rise + bob, 0) * CFrame.Angles(0, math.rad(math.sin(t * 0.4) * 4), 0))
	end
end)

-- wait for the readiness gate to open (Job 043). If there's no gate, IntroReady is nil → don't stall forever.
if Workspace:GetAttribute("IntroReady") == false then
	while Workspace:GetAttribute("IntroReady") ~= true do
		Workspace:GetAttributeChangedSignal("IntroReady"):Wait()
	end
else
	-- no gate present (standalone) — give the mask a moment, then go
	task.wait(2)
end

-- ── smoking nose-down descent ────────────────────────────────────────────────────────────────────────────
hovering = false
task.wait() -- let the hover loop exit
smoke.Enabled = true

local hoverCF = plane:GetPivot()
local DESCENT_TIME = 4.5
do
	local elapsed = 0
	while elapsed < DESCENT_TIME do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local a = math.clamp(elapsed / DESCENT_TIME, 0, 1)
		local eased = a * a * (3 - 2 * a) -- smoothstep
		plane:PivotTo(hoverCF:Lerp(END_CF, eased))
	end
end

-- ── impact: fade to black, drop the crew at the hub, remove the plane, fade back in ──────────────────────
fadeRemote:FireAllClients("out", 0.35)
task.wait(0.45)

for _, plr in Players:GetPlayers() do
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum then
		hum.Sit = false
	end
	if root then
		root.CFrame = CFrame.new(hubPos + Vector3.new(math.random(-6, 6), 3, math.random(-6, 6)))
	end
end

plane:Destroy()
Workspace:SetAttribute("IntroActive", false)

task.wait(0.2)
fadeRemote:FireAllClients("in", 0.8)

print("[Intro] plane cinematic complete — crew delivered to the crash-site hub")
