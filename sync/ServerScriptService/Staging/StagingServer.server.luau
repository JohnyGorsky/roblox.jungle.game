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
local HUB_Z = RiverData.Z_START + 40 -- level with the boat spawn (BoatServer: positionAt(Z_START+40))
local HUB_SIDE = 1 -- which bank the hub sits on (+X)

-- Where the hand-built startup section ends and the procedural river takes over. DOCUMENTED ONLY for now
-- (the generator still builds from Z_START this POC); a follow-up job will start procedural gen here.
local HANDOFF_Z = RiverData.Z_START + 300 -- luau: keep referenced so the intent is greppable
assert(HANDOFF_Z > RiverData.Z_START)

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

-- ---- PLACEHOLDER greybox hub (replace with the hand-built crash-site hub) ----
local centerX = RiverData.centerlineX(HUB_Z)
local waterEdgeX = centerX + HUB_SIDE * (RiverData.widthAt(HUB_Z) * 0.5)
local PLATFORM_SX = 36

-- Keep ALL collidable land geometry on the LAND side (past waterEdgeX) so nothing overlaps the boat.
local platformCenter = Vector3.new(waterEdgeX + HUB_SIDE * (PLATFORM_SX / 2), WATER_Y + 2.5, HUB_Z)
block("HubPlatform", Vector3.new(PLATFORM_SX, 1, 46), Color3.fromRGB(120, 110, 92), CFrame.new(platformCenter), Enum.Material.Ground)
block(
	"PlaneWreck",
	Vector3.new(10, 7, 24),
	Color3.fromRGB(150, 150, 160),
	CFrame.new(platformCenter + Vector3.new(HUB_SIDE * 4, 4, -12)) * CFrame.Angles(0, math.rad(20), math.rad(8)),
	Enum.Material.Metal
)

-- The boat spawns mid-channel; it starts moored OFF the pier. Players PULL the rope to reel it in until it
-- docks ALONGSIDE the jetty. Held dynamically (AlignPosition) — never anchored — so releasing is safe.
local halfBeam = hull.Size.X / 2
local hullBottomY = WATER_Y + 2 - hull.Size.Y / 2

-- Terrain-aware docking: the bank slopes UNDERWATER, so docking by a fixed margin can leave the boat's
-- bank-side edge buried in the bank — fine while anchored, but on release the collision blows the assembly
-- into NaN and the engine deletes it. Probe the ground and dock only as far in as the water is deep enough
-- for the hull's bank-side edge (with clearance). Adapts to the real slope (and to a hand-built shore).
local function groundYat(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { boat, area }
	params.IgnoreWater = true
	local r = Workspace:Raycast(Vector3.new(x, WATER_Y + 12, z), Vector3.new(0, -80, 0), params)
	return if r then r.Position.Y else -1e9 -- no hit = deep water
end
-- highest terrain under the WHOLE hull footprint if its bank-side edge were at edgeX (samples a grid, so a
-- bump under the middle of the boat is caught too, not just the bank edge)
local halfLen = hull.Size.Z / 2
local function maxGroundUnderBoat(edgeX: number): number
	local m = -1e9
	for bx = 0, 4 do
		local x = edgeX - HUB_SIDE * (bx / 4) * (2 * halfBeam) -- across the beam, bank edge → far edge
		for _, z in { HUB_Z - halfLen, HUB_Z, HUB_Z + halfLen } do
			m = math.max(m, groundYat(x, z))
		end
	end
	return m
end
local DECK_CLEAR = 3 -- studs the terrain must sit below the hull bottom
local EXTRA_CLEAR = 16 -- keep the boat this much FURTHER out in deep water past the first clear point
--                       (the probe's grid can miss a bump; staying well out guarantees no bank collision)
local boatEdgeX = waterEdgeX - HUB_SIDE * 90 -- fallback: well out in the channel
for step = 0, 90 do -- scan the boat outward from the shore until its whole footprint clears the bank
	local testEdge = waterEdgeX - HUB_SIDE * step
	if maxGroundUnderBoat(testEdge) < hullBottomY - DECK_CLEAR then
		boatEdgeX = testEdge - HUB_SIDE * EXTRA_CLEAR -- push further out for a safe margin
		break
	end
end
local DOCKED_X = boatEdgeX - HUB_SIDE * halfBeam
local REEL_OFFSET = 26 -- how far off the pier it starts (studs)
local dockedPos = Vector3.new(DOCKED_X, WATER_Y + 2, HUB_Z)
local startPos = Vector3.new(DOCKED_X - HUB_SIDE * REEL_OFFSET, WATER_Y + 2, HUB_Z)

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

-- hub spawn point (read by PlayerCombat before the run starts)
local spawnPos = platformCenter + Vector3.new(0, 3, 0)
Workspace:SetAttribute("HubSpawn", spawnPos)

-- jetty: a walkway from the shore out over the water to the boat's side, ending ~1 stud short of the boat
-- (no overlap → the boat launches free). Players walk it to board. CanCollide so you can stand on it.
local jettyTipX = boatEdgeX + HUB_SIDE * 1 -- 1-stud step gap from the boat
local jettyLenX = math.max(2, math.abs(waterEdgeX - jettyTipX))
local jettyCenterX = (waterEdgeX + jettyTipX) / 2
block("Jetty", Vector3.new(jettyLenX, 0.5, 12), Color3.fromRGB(110, 80, 55), CFrame.new(jettyCenterX, WATER_Y + 2.7, HUB_Z), Enum.Material.WoodPlanks)

-- winch at the jetty's boat-side tip (PLACEHOLDER cube; non-colliding so it never blocks the boat). Pull lives here.
local post = block("Winch", Vector3.new(3, 3, 3), Color3.fromRGB(210, 120, 40), CFrame.new(jettyTipX, WATER_Y + 4.2, HUB_Z), Enum.Material.Metal)
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
