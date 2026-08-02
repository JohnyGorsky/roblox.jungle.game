--!strict
-- StagingServer.server.luau — crash-site hub + moored-boat rope START gate (Job 016).
--
-- Inserts a STAGING phase in front of the river run (same place, phased). Players spawn at a greybox
-- crash-site hub (see PlayerCombat), the boat sits MOORED (anchored + tied) with a visible rope, and all
-- threats/progression are gated behind Workspace.RunStarted. Anyone can UNTIE the rope to start: the boat
-- is released and the run begins. Boat driving is unchanged after start.
--
-- Hand-built vs procedural (GROUND-RULES §2): the greybox hub here is a PLACEHOLDER — the human will
-- hand-build the real crash-site hub + startup river; a later job points the procedural generator at
-- HANDOFF_Z. Nothing here is hero art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

-- shared "untie from the driver seat" remote (Job 030) — created here (StagingServer runs first); DockServer
-- WaitForChilds + also listens. Lets a seated driver untie via a GUI button when the prompt is out of reach.
local untieRemote = Instance.new("RemoteEvent")
untieRemote.Name = "RequestUntie"
untieRemote.Parent = ReplicatedStorage

local WATER_Y = RiverData.WATER_Y

-- ── BIND TO THE HAND-BUILT SPAWN BASE (Job #072) ─────────────────────────────────────────────────
-- This script used to GENERATE a greybox crash-site hub at Z_START + 40, derived from the river's
-- centreline. Its own header always called that temporary: "the human will hand-build the real
-- crash-site hub + startup river; a later job points the generator at HANDOFF_Z." That build now
-- exists as `Workspace.SpawnBase`, so we bind to it and generate nothing.
--
-- The handoff is real now too — `RiverData.START_ZONE_Z_END` (Job #071) is where the sculpted start
-- zone ends and the generated river begins.
--
-- ⚠️ FAIL LOUDLY, NEVER FALL BACK. If a helper is missing, halt. Silently regenerating a greybox hub
-- 300 studs away in the middle of the river would put players in the wrong world with no error — far
-- harder to diagnose than a warning and a dead staging phase.
local function findHelper(parent: Instance?, name: string): BasePart?
	local found = parent and parent:FindFirstChild(name)
	if found and found:IsA("BasePart") then
		return found
	end
	warn(("[Staging] SpawnBase helper %q missing or not a BasePart"):format(name))
	return nil
end

local spawnBase = Workspace:WaitForChild("SpawnBase", 20)
local dockFolder = spawnBase and spawnBase:FindFirstChild("Dock")
local spawnMarker = findHelper(spawnBase, "SpawnLocation")
local boatPlace = findHelper(dockFolder, "BoatPlace")
if not (spawnBase and dockFolder and spawnMarker and boatPlace) then
	warn("[Staging] HALTED — expected Workspace.SpawnBase with SpawnLocation and Dock.BoatPlace. "
		.. "No hub will be generated and the run cannot stage.")
	return
end
local dockModel = dockFolder:FindFirstChild("Dock")

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

-- run state: not started until someone unties
Workspace:SetAttribute("RunStarted", false)

-- Moor WITHOUT anchoring. Anchoring an assembly and later unanchoring it while a client-owned player
-- stands on it makes the physics explode in one step (the engine then removes the boat) — that was the
-- "boat disappears" bug. Instead keep the boat DYNAMIC + server-owned and hold it with an AlignPosition
-- (created below once we know the target). Releasing = destroying that constraint — no anchor transition.
pcall(function()
	hull:SetNetworkOwner(nil)
end)
boat:SetAttribute("Tied", true)

local area = Instance.new("Folder")
area.Name = "StagingArea"
area.Parent = Workspace

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = area
	return p
end

-- ---- the boat's docked + start positions, from the hand-placed helpers ----
-- NOTHING is generated here any more: the greybox HubPlatform, the greybox PlaneWreck and the greybox
-- Jetty are all gone. SpawnBase supplies the real dock, the real wreck and the spawn point.
local halfBeam = hull.Size.X / 2
local halfLen = hull.Size.Z / 2
local hullBottomY = WATER_Y + 2 - hull.Size.Y / 2

-- Docked = exactly where you put BoatPlace, snapped to the boat's float height.
local dockedPos = Vector3.new(boatPlace.Position.X, WATER_Y + 2, boatPlace.Position.Z)

-- It starts moored OFF the dock and is reeled in. "Off" = further along the line from the dock model
-- to BoatPlace, so the boat always approaches the jetty head-on however the dock happens to be rotated
-- (the old code assumed a +X bank, which a hand-placed dock cannot be relied on to match).
local REEL_OFFSET = 26
local awayDir = Vector3.new(1, 0, 0)
if dockModel then
	local d = dockedPos - dockModel:GetPivot().Position
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude > 1 then
		awayDir = flat.Unit
	end
end
local startPos = dockedPos + awayDir * REEL_OFFSET

-- SAFETY PROBE (kept from the procedural version, and it still matters). A boat docked with part of
-- its hull buried in the bank is fine while held, but on release the collision blows the assembly into
-- NaN and the engine deletes it — that was the original "boat disappears" bug. We now TRUST the
-- hand-placed BoatPlace rather than searching for a spot, but we still verify the whole footprint
-- floats, and say so loudly if it does not.
local function groundYat(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { boat, area, spawnBase }
	params.IgnoreWater = true
	local r = Workspace:Raycast(Vector3.new(x, WATER_Y + 12, z), Vector3.new(0, -80, 0), params)
	return if r then r.Position.Y else -1e9 -- no hit = deep water
end
local DECK_CLEAR = 3 -- studs the terrain must sit below the hull bottom
local worstGround = -1e9
for bx = -1, 1 do
	for bz = -1, 1 do
		worstGround = math.max(worstGround, groundYat(dockedPos.X + bx * halfBeam, dockedPos.Z + bz * halfLen))
	end
end
if worstGround > hullBottomY - DECK_CLEAR then
	warn(("[Staging] Dock.BoatPlace is too shallow — ground reaches Y %.1f but the hull bottom sits at "
		.. "Y %.1f and needs %d studs of clearance. Move BoatPlace into deeper water or the boat may be "
		.. "destroyed on release."):format(worstGround, hullBottomY, DECK_CLEAR))
end

-- Hold the boat DYNAMICALLY (no anchoring) with a LinearVelocity in PLANE mode: it only controls
-- HORIZONTAL (world X/Z) velocity and NEVER touches Y — so buoyancy alone owns the vertical float and the
-- boat bobs exactly like normal (an AlignPosition would fight buoyancy on Y → bounce). Reeling = drive the
-- target X/Z; releasing = destroy this. Heading stays downstream via BoatServer's own AlignOrientation.
local moorAtt = hull:FindFirstChild("Root") :: Attachment?
if not moorAtt then
	local a = Instance.new("Attachment")
	a.Name = "MoorRoot"
	a.Parent = hull
	moorAtt = a
end
local hold = Instance.new("LinearVelocity")
hold.Name = "Moor"
hold.Attachment0 = moorAtt
hold.RelativeTo = Enum.ActuatorRelativeTo.World
hold.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
hold.PrimaryTangentAxis = Vector3.new(1, 0, 0) -- world X
hold.SecondaryTangentAxis = Vector3.new(0, 0, 1) -- world Z  (plane = horizontal; Y is free for buoyancy)
hold.PlaneVelocity = Vector2.zero -- zero horizontal velocity = hold position (current can't drift it)
hold.MaxForce = 1000000 -- beat the boat's constant Current force
hold.Parent = hull

-- drive the boat's horizontal position to (moorX, moorZ): set a planar velocity toward it, ease near it.
local REEL_SPEED = 16 -- studs/s reel-in
local moorX, moorZ = startPos.X, startPos.Z
do
	local RunService = game:GetService("RunService")
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not hold.Parent then
			conn:Disconnect()
			return
		end
		local hp = hull.Position
		local ex, ez = moorX - hp.X, moorZ - hp.Z
		local d = math.sqrt(ex * ex + ez * ez)
		if d < 0.3 then
			hold.PlaneVelocity = Vector2.zero
		else
			local s = math.min(REEL_SPEED, d * 3)
			hold.PlaneVelocity = Vector2.new(ex / d * s, ez / d * s)
		end
	end)
end

-- Hub spawn point, read by PlayerCombat (pre-run placement), PlaneServer (where the crew lands after
-- the crash) and StartShopServer (kiosk position). Re-pointing this ONE attribute moves all three.
local spawnPos = spawnMarker.Position + Vector3.new(0, 3, 0)
Workspace:SetAttribute("HubSpawn", spawnPos)
print(("[Staging] bound to SpawnBase — wake at %d,%d,%d · boat docks at %d,%d"):format(
	math.floor(spawnPos.X), math.floor(spawnPos.Y), math.floor(spawnPos.Z),
	math.floor(dockedPos.X), math.floor(dockedPos.Z)))

-- No greybox jetty: SpawnBase.Dock.Dock is the real one, and players walk that to board.
-- The winch is still built, because it hosts the reel/untie prompt and the rope anchor — but it now
-- sits just off the docked boat, on the dock side, instead of at a computed jetty tip.
local winchPos = dockedPos - awayDir * (halfBeam + 4) + Vector3.new(0, 2.2, 0)
local post = block("Winch", Vector3.new(3, 3, 3), Color3.fromRGB(210, 120, 40), CFrame.new(winchPos), Enum.Material.Metal)
post.CanCollide = false
local a0 = Instance.new("Attachment")
a0.Parent = hull
local a1 = Instance.new("Attachment")
a1.Parent = post -- parent first, then set world position
a1.WorldPosition = post.Position + Vector3.new(0, 1, 0)
local rope = Instance.new("RopeConstraint")
rope.Attachment0 = a0
rope.Attachment1 = a1
rope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude
rope.Thickness = 0.15
rope.Visible = true
rope.Color = BrickColor.new("Brown")
rope.Parent = hull

-- prompt: PULL (reel the boat to the pier) → then UNTIE (launch)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "MooringPrompt"
prompt.ActionText = "Pull rope"
prompt.ObjectText = "Winch"
prompt.HoldDuration = 0.4
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 24
prompt.Parent = post

local PULL_STEP = 8 -- studs reeled per pull
local DOCK_DIST = 3 -- within this of the dock = docked
local started = false
local docked = false
local reeling = false

local function refreshRope()
	rope.Length = math.max(1, (a0.WorldPosition - a1.WorldPosition).Magnitude)
end

local function reel()
	if reeling or docked then
		return
	end
	reeling = true
	-- move the HOLD TARGET (X/Z) a step toward the dock; the AlignPosition glides the (dynamic) boat to it,
	-- so a player standing on the boat rides along — no teleporting, no anchoring.
	local flat = Vector3.new(dockedPos.X - moorX, 0, dockedPos.Z - moorZ)
	local stepDist = math.min(PULL_STEP, flat.Magnitude)
	local nt = Vector3.new(moorX, 0, moorZ) + (if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero) * stepDist
	moorX, moorZ = nt.X, nt.Z
	refreshRope()
	task.wait(0.35) -- let the boat glide to the new target
	refreshRope()
	if (Vector3.new(moorX - dockedPos.X, 0, moorZ - dockedPos.Z)).Magnitude <= DOCK_DIST then
		docked = true
		prompt.ActionText = "Untie rope — START"
		print("[Staging] boat docked — board it, then untie to start")
	end
	reeling = false
end

local function startRun()
	if started or not docked then
		return
	end
	if ((boat:GetAttribute("OnBoatCount") :: number?) or 0) < 1 then
		return -- someone must be aboard to launch (don't sail off without the crew)
	end
	started = true
	Workspace:SetAttribute("RunStarted", true)
	-- release = destroy the hold constraint. The boat was NEVER anchored (always dynamic + server-owned),
	-- so there is no anchor→unanchor transition to explode. The current + driver take over cleanly.
	hold:Destroy()
	boat:SetAttribute("Tied", false)
	rope:Destroy()
	a0:Destroy()
	a1:Destroy()
	prompt:Destroy()
	Workspace:SetAttribute("HubSpawn", nil)
	-- leave the greybox hub standing behind (the crew has sailed off on the boat)
	print("[Staging] rope untied — RUN STARTED")
end

prompt.Triggered:Connect(function()
	if not docked then
		reel()
	else
		startRun()
	end
end)

-- GUI untie button (Job 030): a seated driver can reel/start without reaching the winch prompt.
-- Same progression as the prompt (pull to dock → untie to start). Staging only acts before the run starts.
untieRemote.OnServerEvent:Connect(function()
	if started then
		return
	end
	if not docked then
		reel()
	else
		startRun()
	end
end)

-- accurate "on boat" test: raycast straight down from the player and only count a hit on a BOAT part.
-- (A bounding box overlaps the pier when the boat is docked ~2 studs off it, wrongly counting pier-standers.)
local function isOnBoat(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { boat }
	params.IgnoreWater = true
	return Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params) ~= nil
end

-- boat-occupancy readout while staging: "N/M on boat" (published as Boat attributes for the client HUD)
task.spawn(function()
	while not started do
		local onBoat = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and isOnBoat(root) then
				onBoat += 1
			end
		end
		boat:SetAttribute("OnBoatCount", onBoat)
		boat:SetAttribute("CrewCount", #Players:GetPlayers())
		task.wait(0.4)
	end
end)

print("[Staging] crash-site hub + moored boat online (untie to start)")
