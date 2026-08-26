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
-- ── Job #120: the tie affordance got a BODY ───────────────────────────────────────────────────────
-- Reported: "players don't know that you need to tie boat at piers."
--
-- The feature was never missing — the prompt's `ActionText` has always read "Tie Boat". What was
-- missing is an OBJECT. Because `Deck` is invisible (above), the prompt was a bubble hanging over empty
-- air at the geometric centre of a 32-stud quay, and the rope's dock end was anchored at `WATER_Y + 2`,
-- which is 1.08 studs BELOW the plank surface — i.e. inside the pier, where you cannot see it.
--
-- So a physical "TIE BOAT" sign now stands on the pier's water edge (`World/WorldSign.luau` — the same
-- recipe as the camps' TRADING POST board), the prompt hangs on that board, and the mooring rope runs
-- from the foot of the nearer signpost to the hull's rim.
--
-- ⚠️ THREE THINGS THAT LOOK COSMETIC AND ARE NOT:
--
--   a. **Exactly ONE prompt.** Job #106 measured this at the trading post: two prompts sharing the
--      default `KeyCode.E` under `Exclusivity = OnePerButton` means only one ever renders, and it is
--      NOT the nearest — "a trigger that is visible half the time is the reported bug, shipped again".
--      `TieSpot` is kept (it is the geometry note above, and it is the fallback host if the sign cannot
--      be built) but it must never carry a second prompt.
--   b. **The board is repainted on tie.** `ActionText` is state and a painted board is not; leave the
--      two independent and the board tells a tied player to tie up. See `WorldSign.setText`.
--   c. **The sign does not block raycasts.** See the `blockRaycasts` note in `WorldSign` — a board in
--      front of a moored boat is in the firing line, and `findings/0023` is this bug with foliage.
--
-- 🔴 AND THE ONE THAT COST THE MOST TO FIND — `findings/0037`: `measureDeckY` below is DEAD CODE.
-- `buildPier` raycasts against the pier while the dock model is still unparented (`buildDock` does not
-- parent it until the very end), so `Workspace:Raycast` cannot hit it, `measured` is always nil, and the
-- `DECK_Y` correction never runs. Measured live: the plank surface sits at 15.08, not the `DECK_Y` = 16
-- it is supposed to match. The sign therefore measures the deck AFTER the model is parented, and never
-- uses `DECK_Y`. Do not "simplify" that back to the constant.
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
-- Job #120: the shared physical-sign recipe, the same one every camp's TRADING POST board uses.
local WorldSign = require(ServerScriptService:WaitForChild("World"):WaitForChild("WorldSign"))

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
-- ⚠️ Job #120: 0.15 → 0.45. The user's requirement was a rope that is *visible*, and 0.15 is not: the
-- game's own decorative mooring lines on this very boat are 0.45 (`CargoServer`, `LobbyBoat`), and
-- STYLEGUIDE §"Never do" bans "thin beams/architecture" outright. This is the thickness the rest of the
-- game already agreed on, not a new number.
local ROPE_THICKNESS = 0.45

-- ── Job #120 (second pass): the rope is BUILT, not a constraint visual ────────────────────────────
-- 🔴 Reported by the user against the first pass: "rope is not visible, right now is no indications if
-- it is tied." Measured against that report, and both halves of it were true:
--
--   1. `RopeConstraint.Visible` draws an unlit HAIRLINE, not a rope. Probed live by lifting the boat
--      end 12 studs into open air: the line renders, and it still reads as a stray thin stick. The
--      spawn dock has NO rope at all (`StagingServer` deleted it), so this constraint visual had never
--      actually been looked at by anybody since it was written.
--   2. Its boat end was INSIDE the boat. `Hull` is a 14-wide collision box, but the boat's visible
--      geometry is 17.2 wide — `ArmoredHullL1` reaches 10.25 studs from the centre (measured). An
--      attachment on the hull box's rim at 6.5 is 3.75 studs deep inside the side armour.
--
-- So the rope is now the recipe this game already uses for every visible rope it has —
-- `CargoServer`'s and `LobbyBoat`'s Fabric cylinder — laid in segments so it SAGS, and re-laid each
-- frame from the moor loop because one end is on a bobbing boat. `ROPE_BURY` is carried over verbatim
-- from `CargoServer`: ends are pushed past their anchors because a cylinder stopping exactly on a
-- surface leaves a visible gap, and burying it is invisible while a gap is not.
local ROPE_COLOR = Color3.fromRGB(150, 133, 100) -- keep in sync with CargoServer / LobbyBoat
local ROPE_BURY = 1.2
local ROPE_SEGMENTS = 6 -- enough to read as a hanging line; only ONE dock is ever tied at a time
local ROPE_SAG = 0.55 -- studs at midspan. ⚠️ Cosmetic ONLY — the physics tether is the RopeConstraint,
-- which stays (invisible) and is still slack per the ROPE_SLACK note above.

-- ── Job #120: the pier's "TIE BOAT" sign ──────────────────────────────────────────────────────────
-- Every number here was picked from a live 7×5 raycast probe of a real pier, not by eye.
--
-- The pier is a QUAY ALONG THE BANK, not a jetty into the river: `buildPier` aligns its longer
-- horizontal extent (32.2) with the river tangent, leaving 12.7 across. So the sign stands mid-length
-- and 3 studs toward the water, which is clear of all three of the pier's railing posts (measured
-- topping out at 17.39; the nearest is ~4 studs away) and 3 studs inboard of the water edge.
local SIGN_WATER_OFFSET = 2 -- studs from the pier's centreline, toward the channel
local SIGN_FACE_DIST = 40 -- how far ahead the sign looks; only its direction matters
local ROPE_CLEAT_UP = 1.0 -- the rope ties round the post this far above the deck
-- A down-ray at some points on the pier lands in a plank GAP and hits nothing (proved by the probe
-- grid). One raycast is not a measurement here; these are the fallback offsets to retry at.
local DECK_PROBE_OFFSETS = { Vector3.zero, Vector3.new(1.5, 0, 0), Vector3.new(-1.5, 0, 0), Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5) }

-- 🔴 THE MOOR POINT MUST SIT ON THE ASSEMBLY'S CENTRE OF MASS. Reported 2026-08-16: untying at a river
-- dock and driving off sent the boat into a violent spin.
--
-- A `LinearVelocity` applies its force AT ITS ATTACHMENT, and it has no `ApplyAtCenterOfMass` escape
-- hatch — which is exactly why every `VectorForce` in `BoatServer` sets `ApplyAtCenterOfMass = true`
-- (`BoatServer:174`). Anchored on `MoorRoot` at the hull's origin, `MaxForce = 1e6` acting on a lever
-- arm to the real centre of mass is an enormous torque.
--
-- ⚠️ WHY THE SPAWN DOCK NEVER SHOWED THIS, and why copying it verbatim was not enough: `StagingServer`
-- moors a ONE-PART boat, before modules exist, so its origin and its centre of mass are the same point
-- and the lever arm is zero. By the time a river dock is reached the boat is 12 parts — fuel tank, a
-- second motor, a trailer, a searchlight — and the centre of mass has moved well off the hull origin.
-- Confirmed by the console ordering: "[Staging] moored boat online" precedes "[BoatModules] applied"
-- and "Boat -> navy (12 parts)".
--
-- A dedicated attachment, re-solved on every tie because the centre of mass moves when modules or cargo
-- change, and destroyed on untie. Deliberately NOT `StagingServer`'s shared `MoorRoot` — moving that
-- would silently retarget anything else that ever hangs off it.
local function makeMoorPoint(hullPart: BasePart): Attachment
	local stale = hullPart:FindFirstChild("DockMoorPoint")
	if stale then
		stale:Destroy()
	end
	local a = Instance.new("Attachment")
	a.Name = "DockMoorPoint"
	a.Parent = hullPart
	a.WorldPosition = hullPart.AssemblyCenterOfMass -- zero lever arm ⇒ pure translation, no torque
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
local function buildPier(pos: Vector3, tangent: Vector3, parent: Instance): Model?
	local source = dockSource
	if not source then
		return nil
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

	return pier
end

-- ── the visible mooring line ──────────────────────────────────────────────────────────────────────
-- A parabola, not a straight bar: `sag` is 0 at both ends and maximal at midspan, so the segments hang.
local function ropePoint(a: Vector3, b: Vector3, t: number, sag: number): Vector3
	return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
end

local function newRopeSegment(parent: Instance): Part
	local seg = Instance.new("Part")
	seg.Name = "MooringRope"
	seg.Shape = Enum.PartType.Cylinder
	seg.Anchored = true -- never welded and never part of the boat assembly: it must add no mass
	seg.CanCollide = false -- header note 1: nothing may collide with the boat assembly
	seg.CanQuery = false -- header note (c): nothing on this pier may eat a bullet
	seg.CanTouch = false
	seg.CastShadow = false
	seg.Color = ROPE_COLOR
	seg.Material = Enum.Material.Fabric
	seg.Size = Vector3.new(1, ROPE_THICKNESS, ROPE_THICKNESS) -- length is set per frame below
	seg.Parent = parent
	return seg
end

-- Re-lay the whole line between two world points. Called every frame while tied.
local function layMooringLine(segments: { Part }, from: Vector3, to: Vector3)
	local span = to - from
	if span.Magnitude < 0.05 then
		return
	end
	local unit = span.Unit
	local a, b = from - unit * ROPE_BURY, to + unit * ROPE_BURY
	local sag = math.min(ROPE_SAG, (b - a).Magnitude * 0.12) -- a short rope must not sag like a long one
	local n = #segments
	for i = 1, n do
		local p0 = ropePoint(a, b, (i - 1) / n, sag)
		local p1 = ropePoint(a, b, i / n, sag)
		local seg = segments[i]
		seg.Size = Vector3.new(math.max((p1 - p0).Magnitude, 0.05), ROPE_THICKNESS, ROPE_THICKNESS)
		-- a Cylinder's length runs along its X axis, hence the 90° yaw off the look direction
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0)
	end
end

-- The walkable surface of the pier at one XZ, MEASURED.
--
-- 🔴 Deliberately not `measureDeckY` above, and deliberately not `DECK_Y`. See `findings/0037`: that
-- function is called before the dock model is in the Workspace, so its rays hit nothing and it always
-- returns nil — which is why the piers stand 0.92 studs below the `DECK_Y` they are supposed to match.
-- This one is called AFTER parenting, so it hits, and it takes what is actually underfoot.
--
-- Takes the LOWEST floor-normal hit above water, for the reason `measureDeckY` already documents: the
-- deck, rather than a railing cap. Retries at small offsets because a ray can drop clean through a gap
-- between two planks (measured — several probe points returned nothing at all).
local function measureSurfaceY(pier: Model, xz: Vector3): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { pier }
	rp.IgnoreWater = true
	local best: number? = nil
	for _, off in ipairs(DECK_PROBE_OFFSETS) do
		local from = Vector3.new(xz.X + off.X, WATER_Y + 60, xz.Z + off.Z)
		local hit = Workspace:Raycast(from, Vector3.new(0, -120, 0), rp)
		if hit and hit.Normal.Y > 0.7 and hit.Position.Y > WATER_Y then
			if not best or hit.Position.Y < best then
				best = hit.Position.Y
			end
		end
	end
	return best
end

-- Stand the "TIE BOAT" board on the pier, facing the river.
--
-- ⚠️ MUST be called with `parent` already in the Workspace — it raycasts. And it must be called AFTER
-- `buildPier` has done its final positioning, or it measures a surface that then moves.
local function buildTieSign(pos: Vector3, tangent: Vector3, side: number, pier: Model, parent: Instance): (Part?, { Part })
	-- Across the quay, pointing at the channel. `RiverData` derives `dock.x` as
	-- `centerlineX(z) + side * (width/2 - 4)`, so the water is toward `-side` in world X — and the
	-- pier's own across-axis is the tangent's perpendicular. Take the perpendicular, then flip it to
	-- whichever way the water is, so the board lies ALONG the 32-stud quay whatever the river's bearing.
	local lateral = Vector3.new(tangent.Z, 0, -tangent.X).Unit
	local across = if lateral:Dot(Vector3.new(-side, 0, 0)) >= 0 then lateral else -lateral

	-- 🔴 THE BOARD FACES THE ONCOMING BOAT, NOT STRAIGHT ACROSS THE CHANNEL.
	--
	-- Squaring it to the bank was the first thing tried, and a Play capture from a driver coming
	-- upriver killed it: an 8×3×0.4 board seen edge-on is a thin dark sliver, and it stays one until
	-- the boat is already level with the pier — i.e. until the exact moment the player no longer needs
	-- telling. A sign nobody can read on approach does not fix "players don't know you need to tie".
	--
	-- The river runs along `+tangent`, so boats arrive from `-tangent`. Splitting the difference
	-- between "out at the channel" and "back down the river" turns the board ~45° into the approach: it
	-- reads from a long way downstream AND is still legible once moored alongside.
	local faceDir = (across - tangent).Unit

	local signPos = pos + across * SIGN_WATER_OFFSET
	local ground = measureSurfaceY(pier, signPos)
	if not ground then
		-- Never guess. A sign floating a stud over the planks is worse than no sign, and `DECK_Y` is
		-- exactly the constant that is already wrong here (findings/0037).
		warn(("[Docks] could not measure the pier deck at %d,%d — no TIE BOAT sign at this dock"):format(math.floor(signPos.X), math.floor(signPos.Z)))
		return nil, {}
	end

	local board, posts = WorldSign.build({
		position = signPos,
		faceTo = signPos + faceDir * SIGN_FACE_DIST,
		parent = parent,
		ground = ground,
		text = "TIE BOAT",
		boardName = "TieSign",
		blockRaycasts = false, -- see note (c) in the header — this board is in the firing line
	})
	return board, posts
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

	local pier = buildPier(pos, tangent, model)

	-- ⚠️ Job #120: the model goes LIVE HERE, not at the end of this function as it used to. The sign
	-- below has to raycast the pier to find the deck it stands on, and `Workspace:Raycast` cannot hit an
	-- instance that is not in the Workspace — which is the whole of `findings/0037`. Nothing yields
	-- between here and the end of the function, so the dock is still assembled within one frame.
	model.Parent = docksRoot

	local signBoard: Part?, signPosts: { Part } = nil, {}
	if pier then
		signBoard, signPosts = buildTieSign(pos, tangent, dock.side, pier, model)
	end

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
	-- ⚠️ Job #120: 18 → 24, and the reason is arithmetic rather than taste. Measured: the pier's
	-- cross-half-extent is 6.5, the hull's half-beam is 7 (`BoatServer.HULL_SIZE`), and a docked boat
	-- sits ~2 studs off — so the driver's seat is ~15.5 studs abeam the pier's centreline. At the OLD
	-- prompt (pier centre, Y 17) that left `sqrt(18² − 15.5²) ≈ 9` studs of fore/aft slop before the
	-- driver fell out of range, and `DockServer` moors the boat WHERE IT FLOATS — nothing centres it.
	-- The sign sits 3 studs closer to the water than the old anchor, so the same mooring is now ~13.2
	-- studs away, and 24 buys ~20 studs of fore/aft slop. Still far inside the 162-stud channel width,
	-- so it can never be reached from the far bank, and still stricter than the server's 65-stud gate.
	tie.MaxActivationDistance = 24
	-- 🔴 ON THE SIGN, and ONLY there — see note (a) in the header. `tieAtt` is the fallback host for the
	-- case where the AssetLibrary has no pier model and there is no board to hang this on.
	tie.Parent = signBoard or tieAtt

	local rope: RopeConstraint? = nil
	local ropeAtts: { Attachment } = {}
	local ropeSegs: { Part } = {} -- the VISIBLE rope; the constraint above is the invisible tether
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
		local point = hull:FindFirstChild("DockMoorPoint")
		if point then
			point:Destroy() -- re-solved from the centre of mass on the next tie, so never reused
		end
		boat:SetAttribute("Tied", false)
		tie.ActionText = "Tie Boat"
		-- The BOARD says it too. See note (b) in the header: leave the painted text out of this and a
		-- sign reading "UNTIE BOAT" survives the untie.
		if signBoard then
			WorldSign.setText(signBoard, "TIE BOAT")
		end
		creak:Stop()
		if rope then
			rope:Destroy()
			rope = nil
		end
		for _, seg in ropeSegs do
			seg:Destroy()
		end
		ropeSegs = {}
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

			-- Defensive: if a previous tie ever leaked its hold (a dock model culled and rebuilt while
			-- tied would orphan one on the hull), a live 1e6-force constraint would fight the driver
			-- forever. Clear any stale one before adding ours.
			local orphan = hull:FindFirstChild("DockMoor")
			if orphan then
				orphan:Destroy()
			end

			local moorPoint = makeMoorPoint(hull)
			local hold = Instance.new("LinearVelocity")
			hold.Name = "DockMoor"
			hold.Attachment0 = moorPoint
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
				-- One end of the rope is on a bobbing boat, so the line is re-laid rather than welded.
				-- Piggy-backs on the hold loop that already has to run: no second connection.
				if #ropeSegs > 0 and #ropeAtts == 2 then
					layMooringLine(ropeSegs, ropeAtts[1].WorldPosition, ropeAtts[2].WorldPosition)
				end
			end)
			moorConn = conn

			boat:SetAttribute("Tied", true)
			tie.ActionText = "Untie Boat"
			if signBoard then
				WorldSign.setText(signBoard, "UNTIE BOAT")
			end
			-- ── the rope: FROM THE SIGN, TO THE BOAT, and actually visible (Job #120) ───────────
			-- Its dock end used to be `pos + (0, 2, 0)` — world Y 14, which is 1.08 studs UNDER the
			-- plank surface, i.e. buried in the pier. It now ties round the foot of the nearer
			-- signpost, which is both the thing the player just pressed and a place a rope plausibly
			-- goes.
			local anchorPart: BasePart = deck
			local anchorPos = pos + Vector3.new(0, 2, 0)
			local nearest: Part? = nil
			for _, post in ipairs(signPosts) do
				if not nearest or (post.Position - hull.Position).Magnitude < (nearest.Position - hull.Position).Magnitude then
					nearest = post
				end
			end
			if nearest then
				anchorPart = nearest
				anchorPos = WorldSign.postFoot(nearest, ROPE_CLEAT_UP)
			end

			local a0 = Instance.new("Attachment")
			a0.Parent = hull
			-- 🔴 THE BOAT END GOES ON THE BOAT'S VISIBLE SKIN, WHICH IS NOT THE HULL BOX.
			--
			-- `Hull` is a 14×3×32 COLLISION box. The boat players actually see is 17.2×12.5×43 — the
			-- side armour (`ArmoredHullL1`) reaches 10.25 studs from the centreline, measured live. Both
			-- earlier versions of this rope got that wrong: the original left `a0` at the hull's origin
			-- (the geometric centre, deep inside the boat), and the first Job #120 pass moved it to the
			-- hull BOX's rim at 6.5 — still 3.75 studs inside the armour. Either way the rope started
			-- somewhere no player can see, which is what "rope is not visible" meant.
			--
			-- So: raycast from the signpost toward the boat's gunwale height and stop at whatever the
			-- boat's real geometry presents. That answer stays right through any future module or paint
			-- change, which is exactly why it is measured rather than written down.
			--
			-- Safe against the load-bearing note above: `ROPE_SLACK` (3) is ten times the hold loop's
			-- 0.3-stud dead band, so the rope never goes taut and this off-centre attachment never
			-- applies a torque. Re-verify in Play if the slack or the dead band ever changes.
			local skinParams = RaycastParams.new()
			skinParams.FilterType = Enum.RaycastFilterType.Include
			skinParams.FilterDescendantsInstances = { boat }
			skinParams.IgnoreWater = true
			local gunwale = hull.Position + Vector3.new(0, hull.Size.Y / 2 + 1.5, 0)
			local skin = Workspace:Raycast(anchorPos, gunwale - anchorPos, skinParams)
			if skin then
				a0.WorldPosition = skin.Position
			else
				-- Fallback only: no visible geometry between the post and the gunwale (the boat is
				-- somewhere odd). Put it on the collision box's rim rather than its centre.
				local toSign = hull.CFrame:VectorToObjectSpace(anchorPos - hull.Position)
				local hx, hz = hull.Size.X / 2 - 0.5, hull.Size.Z / 2 - 0.5
				local sx = if math.abs(toSign.X) > 1e-3 then hx / math.abs(toSign.X) else math.huge
				local sz = if math.abs(toSign.Z) > 1e-3 then hz / math.abs(toSign.Z) else math.huge
				local edge = math.min(sx, sz)
				if edge < math.huge then
					a0.Position = Vector3.new(toSign.X * edge, hull.Size.Y / 2, toSign.Z * edge)
				end
			end

			local a1 = Instance.new("Attachment")
			a1.Parent = anchorPart -- parent FIRST, then set world position (else the transform double-applies)
			a1.WorldPosition = anchorPos
			ropeAtts = { a0, a1 }
			local newRope = Instance.new("RopeConstraint")
			newRope.Attachment0 = a0
			newRope.Attachment1 = a1
			newRope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude + ROPE_SLACK -- slack: see ROPE_SLACK
			newRope.Thickness = ROPE_THICKNESS
			-- ⚠️ INVISIBLE ON PURPOSE — this is the tether, not the picture. Its `Visible` hairline is
			-- what the user reported as "rope is not visible"; the built cylinders below are the rope.
			-- Turning this back on just draws a second, thinner line through the middle of them.
			newRope.Visible = false
			newRope.Color = BrickColor.new("Brown")
			newRope.Parent = hull
			rope = newRope

			-- the rope you can actually see, laid now and re-laid every frame by the hold loop above
			ropeSegs = {}
			for _ = 1, ROPE_SEGMENTS do
				table.insert(ropeSegs, newRopeSegment(model))
			end
			layMooringLine(ropeSegs, a0.WorldPosition, a1.WorldPosition)
			creak:Play()
			activeUntie = doUntie -- so the GUI untie button can release this dock
		end
	end)

	-- (`model.Parent = docksRoot` happens up in this function now — the sign has to raycast the pier.)
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
