--!strict
-- DockServer.server.luau — refuel/tie docks along the river (Job 010, real geometry Job #077).
--
-- Streams the seeded docks (RiverData.docksBetween) near the boat with a "Tie Boat" ProximityPrompt.
-- Pull the boat up and hold it → it's held at the dock with a visible rope. Server-authoritative (checks
-- the boat is actually beside the dock). Docks well behind are culled.
--
-- ── Job #077: the plank is a real pier now ────────────────────────────────────────────────────────
-- The `Deck` used to be a 14×1×24 WoodPlanks box. It is the `Dock` model from `ServerStorage.AssetLibrary`
-- (62 instances, 32×8×13) — but the box did not simply get deleted, and that is deliberate:
--
--   `Deck` SURVIVES AS AN INVISIBLE ANCHOR. It keeps its old name, size, CFrame and its `TieSpot`
--   Attachment, and the prompt, the rope and the water sound all still hang off it. So the entire
--   tie/untie flow — including `StagingServer` and the Job #075 `UntieButton` path — is byte-for-byte
--   the geometry it was tuned against, and the model swap cannot move a tie point by a stud.
--
-- ⚠️ TWO THINGS THAT WILL BITE IF YOU CHANGE THEM:
--
--   1. **Nothing below the waterline collides.** `RiverBootstrap`'s standing rule is that physical
--      collision with the boat assembly blows the boat apart, and a 62-part pier has pilings going down
--      exactly where the hull floats. The old greybox was one box sitting 3 studs clear of the water, so
--      this risk is NEW with the real model. Parts topping out under `WATER_Y + PILING_CLEAR` are set
--      non-colliding: you cannot walk on a piling anyway, and the boat has to be able to nose in.
--
--   2. **The deck height is MEASURED, not assumed.** We do not know where the walkable surface sits
--      inside the model, so the model is placed provisionally and then raycast to find its real floor,
--      then shifted so that floor lands at `DECK_Y` — the exact height the greybox deck had. Trusting a
--      constant here is what buried every camp prop by 2.4 studs in Job #076 (see `ExcursionServer`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))
local CampAmbience = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampAmbience"))
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))

local AHEAD = 1600 -- generate docks this far ahead
local BEHIND = 400 -- cull docks this far behind
local REFUEL_RANGE = 65 -- the boat must be within this of the dock to refuel
local TICK = 0.5

local PILING_CLEAR = 2 -- anything topping out below WATER_Y + this loses collision (see note 1 above)

-- ── Job #084: tying MOORS the boat, it does not ANCHOR it ─────────────────────────────────────────
-- This used to be `hull.Anchored = true` on tie and `= false` on untie. That is the exact transition
-- `StagingServer`'s header documents as the old "boat disappears" bug:
--
--     "Anchoring an assembly and later unanchoring it while a client-owned player stands on it makes
--      the physics explode in one step (the engine then removes the boat)."
--
-- and it was running at all 11+ streamed river docks. The reported symptom was milder — riders SLID on
-- the tied deck, because an anchored hull is static ground that no longer participates in Roblox's
-- native moving-platform carry (the carry the project rule says riders must rely on, and which a manual
-- per-frame carry must never replace).
--
-- Same fix as the spawn dock, same shape: keep the hull DYNAMIC and server-owned, hold it with a
-- `LinearVelocity` in PLANE mode. ⚠️ NOT an AlignPosition — `StagingServer:132` records why: plane mode
-- controls world X/Z only and never touches Y, so buoyancy alone keeps owning the float. An
-- AlignPosition fights buoyancy on Y and the boat bounces.
local HOLD_SPEED = 16 -- studs/s max correction, matching StagingServer
local HOLD_FORCE = 1000000 -- must beat BoatServer's constant `Current` force
-- The rope was decoration only while the hull was anchored (anchored parts ignore constraints). A
-- dynamic hull makes it LOAD-BEARING, and this repo has already been bitten by that once:
-- `StagingServer:186` — "the rope was actively harmful (it is what suspended the boat above the
-- waterline)". Slack keeps it decoration: the hold parks the boat within 0.3 studs, so a rope this much
-- longer than the tie-moment distance can never go taut through the bob.
local ROPE_SLACK = 3

-- The hull's mooring attachment. `StagingServer` creates `MoorRoot` at startup and only ever destroys
-- the CONSTRAINT, so it is normally already there — reuse it rather than piling up one attachment per
-- dock tied over a run.
local function moorAttachment(hullPart: BasePart): Attachment
	local existing = hullPart:FindFirstChild("MoorRoot") or hullPart:FindFirstChild("Root")
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local a = Instance.new("Attachment")
	a.Name = "MoorRoot"
	a.Parent = hullPart
	return a
end

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y
local DECK_Y = WATER_Y + 4 -- the greybox deck's top surface; above the Y15 basin floor so a landing basin can't bury it

local docksRoot = Instance.new("Folder")
docksRoot.Name = "Docks"
docksRoot.Parent = Workspace

local placed: { [number]: Model } = {}

-- ── the AssetLibrary, flattened ───────────────────────────────────────────────────────────────────
-- Same lookup `ExcursionServer` does: the library groups models into folders, and we only ever want
-- them by name.
local dockSource: Model? = nil
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			local m = group:FindFirstChild(CampDefs.MODEL.dock)
			if m and m:IsA("Model") then
				dockSource = m
				break
			end
		end
	end
	if not dockSource then
		warn(("[Docks] AssetLibrary has no %q — docks fall back to the greybox plank (the library lives in "):format(CampDefs.MODEL.dock)
			.. "the place file, not git: open the game place and save it)")
	end
end

-- GUI untie from the driver seat (Job 030): the currently-tied dock registers its untie here; the shared
-- RequestUntie remote (created by StagingServer) calls it. Only one dock is tied at a time.
local activeUntie: (() -> ())? = nil
local untieRemote = ReplicatedStorage:WaitForChild("RequestUntie") :: RemoteEvent
untieRemote.OnServerEvent:Connect(function()
	if boat:GetAttribute("Tied") and activeUntie then
		activeUntie()
	end
end)

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

-- Find the model's real walkable floor. Samples a small cross rather than one ray, and takes the LOWEST
-- floor-normal hit that is still above water — the deck, rather than a railing cap or a roof plank.
local function measureDeckY(model: Model, centre: Vector3): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { model }
	rp.IgnoreWater = true
	local best: number? = nil
	for _, off in ipairs({ Vector3.zero, Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) }) do
		local from = Vector3.new(centre.X + off.X, WATER_Y + 60, centre.Z + off.Z)
		local hit = Workspace:Raycast(from, Vector3.new(0, -120, 0), rp)
		if hit and hit.Normal.Y > 0.7 and hit.Position.Y > WATER_Y then
			if not best or hit.Position.Y < best then
				best = hit.Position.Y
			end
		end
	end
	return best
end

-- Place the real pier. Long horizontal axis along the river tangent, matching the greybox quay it
-- replaces, so where the boat parks does not change.
local function buildPier(pos: Vector3, tangent: Vector3, parent: Instance)
	local source = dockSource
	if not source then
		return
	end
	local pier = source:Clone()
	local _, extents = pier:GetBoundingBox()

	-- The library model's forward axis is whatever the publisher chose. Align its LONGER horizontal
	-- extent with the tangent rather than trusting that it was authored facing +Z.
	local yaw = if extents.X > extents.Z then math.pi / 2 else 0
	pier:PivotTo(CFrame.lookAt(Vector3.new(pos.X, WATER_Y, pos.Z), Vector3.new(pos.X, WATER_Y, pos.Z) + tangent) * CFrame.Angles(0, yaw, 0))

	-- provisional seat: bottom just under the water, so pilings read as driven into the riverbed
	local bottom = FoliageDefs.worldBottom(pier)
	if bottom then
		pier:PivotTo(pier:GetPivot() + Vector3.new(0, (WATER_Y - 3) - bottom, 0))
	end

	pier.Name = "Pier"
	for _, d in ipairs(pier:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	pier.Parent = parent

	-- now measure the real floor and drop the whole thing so it lands where the greybox deck was
	local measured = measureDeckY(pier, pos)
	if measured then
		pier:PivotTo(pier:GetPivot() + Vector3.new(0, DECK_Y - measured, 0))
	end

	-- ⚠️ collision pass, AFTER the final position — see note 1 in the header. A part is only collidable
	-- if it tops out clear of the water; everything below that is a piling the boat must be able to
	-- occupy, and that nobody can stand on regardless.
	for _, d in ipairs(pier:GetDescendants()) do
		if d:IsA("BasePart") then
			local top = d.Position.Y + d.Size.Y / 2
			d.CanCollide = top > WATER_Y + PILING_CLEAR
			d.CastShadow = d.CanCollide
		end
	end
end

local function buildDock(dock: RiverData.Dock, index: number)
	if placed[index] then
		return
	end
	local pos = Vector3.new(dock.x, WATER_Y, dock.z)
	local tangent = RiverData.tangentAtZ(dock.z)

	local model = Instance.new("Model")
	model.Name = "Dock"

	-- The anchor. Invisible since Job #077 — the real pier is the visible object — but everything the
	-- tie flow depends on still hangs off this exact part at this exact CFrame.
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Anchored = true
	deck.Size = Vector3.new(14, 1, 24)
	deck.CFrame = CFrame.lookAt(pos + Vector3.new(0, 3.5, 0), pos + Vector3.new(0, 3.5, 0) + tangent) -- sits above the basin floor (Y15) so a landing-site basin can't bury it
	deck.Transparency = if dockSource then 1 else 0
	deck.CanCollide = dockSource == nil -- the real pier carries the collision; the greybox fallback still needs it
	deck.CanQuery = false
	deck.Color = Color3.fromRGB(120, 85, 55)
	deck.Material = Enum.Material.WoodPlanks
	deck.Parent = model
	model.PrimaryPart = deck

	buildPier(pos, tangent, model)

	-- water lapping at the pier. `GameSoundscape` already does this positionally at the SPAWN dock and
	-- explicitly leaves the river's streamed docks to whoever builds them — this is that.
	CampAmbience.positionalSound(deck, CampDefs.SOUND.water, "DockWater", true)

	-- Rope creak, built silent. It only plays while the boat is actually on the rope: an idle creak at
	-- eleven untied docks is noise, not atmosphere.
	local creak = CampAmbience.positionalSound(deck, CampDefs.SOUND.rope, "RopeCreak", false)

	-- tie / untie: hold the boat at the dock (won't drift off), with a visible rope.
	-- (No refuel here — refuelling happens at the boat's fuel STATION using looted gasoline; see CargoServer.)
	local tieAtt = Instance.new("Attachment")
	tieAtt.Name = "TieSpot"
	tieAtt.Position = Vector3.new(0, 1.5, 0)
	tieAtt.Parent = deck
	local tie = Instance.new("ProximityPrompt")
	tie.Name = "TiePrompt"
	tie.ActionText = "Tie Boat"
	tie.ObjectText = "Dock"
	tie.HoldDuration = 0.6
	tie.RequiresLineOfSight = false
	tie.MaxActivationDistance = 18
	tie.Parent = tieAtt

	local rope: RopeConstraint? = nil
	local ropeAtts: { Attachment } = {}
	local moor: LinearVelocity? = nil
	local moorConn: RBXScriptConnection? = nil

	local function doUntie()
		-- Release = destroy the hold. No anchor→unanchor transition, so there is nothing to explode
		-- even with the whole crew standing on deck.
		if moorConn then
			moorConn:Disconnect()
			moorConn = nil
		end
		if moor then
			moor:Destroy()
			moor = nil
		end
		boat:SetAttribute("Tied", false)
		tie.ActionText = "Tie Boat"
		creak:Stop()
		if rope then
			rope:Destroy()
			rope = nil
		end
		for _, a in ropeAtts do
			a:Destroy()
		end
		ropeAtts = {}
		activeUntie = nil
	end

	tie.Triggered:Connect(function()
		if boat:GetAttribute("Tied") then
			doUntie()
		elseif (hull.Position - pos).Magnitude <= REFUEL_RANGE then
			-- server-owned so the hold loop below reads un-lagged position, not a client's estimate
			pcall(function()
				hull:SetNetworkOwner(nil)
			end)

			-- ⚠️ MOORED WHERE IT FLOATS, not at the pier. `TiePrompt` fires anywhere within
			-- REFUEL_RANGE (65 studs), so holding at `pos` would reel the boat up to 65 studs across
			-- the river on a single keypress. Freezing the current spot is what the anchor did, so the
			-- tie FEEL is unchanged — only the mechanism is.
			local moorX, moorZ = hull.Position.X, hull.Position.Z

			local hold = Instance.new("LinearVelocity")
			hold.Name = "Moor"
			hold.Attachment0 = moorAttachment(hull)
			hold.RelativeTo = Enum.ActuatorRelativeTo.World
			hold.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			hold.PrimaryTangentAxis = Vector3.new(1, 0, 0) -- world X
			hold.SecondaryTangentAxis = Vector3.new(0, 0, 1) -- world Z (plane = horizontal; Y free for buoyancy)
			hold.PlaneVelocity = Vector2.zero
			hold.MaxForce = HOLD_FORCE
			hold.Parent = hull
			moor = hold

			-- Planar correction toward the berth, eased on arrival: the current cannot drift the boat
			-- off, and neither can a shove from a player or an enemy.
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function()
				if not hold.Parent then
					conn:Disconnect() -- self-disconnect if the hold goes any way other than doUntie
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
			moorConn = conn

			boat:SetAttribute("Tied", true)
			tie.ActionText = "Untie Boat"
			local a0 = Instance.new("Attachment")
			a0.Parent = hull
			local a1 = Instance.new("Attachment")
			a1.Parent = deck -- parent FIRST, then set world position (else the deck transform double-applies)
			a1.WorldPosition = pos + Vector3.new(0, 2, 0)
			ropeAtts = { a0, a1 }
			local newRope = Instance.new("RopeConstraint")
			newRope.Attachment0 = a0
			newRope.Attachment1 = a1
			newRope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude + ROPE_SLACK -- slack: see ROPE_SLACK
			newRope.Thickness = 0.15
			newRope.Visible = true
			newRope.Color = BrickColor.new("Brown")
			newRope.Parent = hull
			rope = newRope
			creak:Play()
			activeUntie = doUntie -- so the GUI untie button can release this dock
		end
	end)

	model.Parent = docksRoot
	placed[index] = model
end

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - BEHIND, boatZ + AHEAD) do
		buildDock(dock, dockIndex(dock.z))
	end
	for index, model in placed do
		if boatZ - (RiverData.Z_START + index * RiverData.DOCK_SPACING) > BEHIND then
			model:Destroy()
			placed[index] = nil
		end
	end
	task.wait(TICK)
end
