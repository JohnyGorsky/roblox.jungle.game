--!strict
-- StagingServer.server.luau — crash-site hub + moored-boat START gate (Job 016, retooled in Job 072).
--
-- Inserts a STAGING phase in front of the river run (same place, phased). Players spawn at the hand-built
-- SpawnBase (see PlayerCombat), the boat sits MOORED exactly where `Dock.BoatPlace` is placed, and all
-- threats/progression are gated behind Workspace.RunStarted. Anyone can UNTIE to start: the boat is
-- released and the run begins. Boat driving is unchanged after start.
--
-- ⚠️ `Dock.BoatPlace` IS THE CONTROL. Move or rotate that marker in the editor and the moored boat
-- follows — position and heading both. Nothing here computes a berth. There is no winch and no tow.
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

-- Kept (empty) so anything still looking up Workspace.StagingArea finds it. Nothing is built into it any
-- more: the greybox hub/wreck/jetty went in Job 072 when SpawnBase replaced them, and the winch post
-- went with the tow.
local area = Instance.new("Folder")
area.Name = "StagingArea"
area.Parent = Workspace

-- ---- the boat's docked + start positions, from the hand-placed helpers ----
-- NOTHING is generated here any more: the greybox HubPlatform, the greybox PlaneWreck and the greybox
-- Jetty are all gone. SpawnBase supplies the real dock, the real wreck and the spawn point.
local halfBeam = hull.Size.X / 2
local halfLen = hull.Size.Z / 2
local hullBottomY = WATER_Y + 2 - hull.Size.Y / 2

-- ⚠️ THE BOAT SITS EXACTLY WHERE `BoatPlace` IS — position AND rotation. That marker is the single
-- control: drag it or spin it in the editor and the moored boat follows, no code change needed.
-- (BoatServer reads the same helper for the hull's spawn CFrame, yaw included.)
--
-- There is NO reel-in any more. The boat used to spawn `REEL_OFFSET = 26` studs off along the dock→
-- BoatPlace line and be winched to the pier a few studs per pull. That is gone: towing added a chore
-- before every run, and the offset was also what kept knocking the mooring maths out — the rope was cut
-- for the build-time spot and then went taut once the drive pulled the boat out to its hold position,
-- leaving the whole boat hanging in the air above the water.
local dockedPos = Vector3.new(boatPlace.Position.X, WATER_Y + 2, boatPlace.Position.Z)
local startPos = dockedPos

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

-- Hold the boat's horizontal position at (moorX, moorZ): planar velocity toward it, eased near it.
-- The boat now spawns ON this spot, so in practice this only cancels the river current's drift — but the
-- correction is kept so a shove from a player or an enemy cannot walk the boat off its berth.
local HOLD_SPEED = 16 -- studs/s max correction
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
			local s = math.min(HOLD_SPEED, d * 3)
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
--
-- No winch post and no rope. The greybox orange winch block stood in the water beside the boat purely to
-- host the reel prompt and anchor the tow rope; with the tow gone there is nothing for it to do, and the
-- rope was actively harmful (it is what suspended the boat above the waterline). The boat is held in
-- place by the `Moor` LinearVelocity above, which is invisible and cannot fight buoyancy on Y.
--
-- The untie prompt now lives ON THE BOAT, so there is still a world-space way to start the run for a
-- player who is not seated. `UntieButton` (Job 030) remains the seated-driver path — both call startRun.
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "MooringPrompt"
prompt.ActionText = "Untie rope — START"
prompt.ObjectText = "Boat"
prompt.HoldDuration = 0.4
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 24
prompt.Parent = hull

local started = false

local function startRun()
	if started then
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
	prompt:Destroy()
	Workspace:SetAttribute("HubSpawn", nil)
	-- leave the hub standing behind (the crew has sailed off on the boat)
	print("[Staging] untied — RUN STARTED")
end

prompt.Triggered:Connect(startRun)

-- GUI untie button (Job 030): a seated driver starts without reaching the boat's prompt.
-- Staging only acts before the run starts.
untieRemote.OnServerEvent:Connect(function()
	startRun()
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
