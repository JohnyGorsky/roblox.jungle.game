--!strict
-- FoliageServer.server.luau — real banded jungle along both shores (Job 012 → rebuilt in Job #076).
--
-- Streams foliage along both banks near the boat: generate ahead, cull behind. Every model is raycast onto
-- the terrain and only planted on valid ground, so the whole river reads as jungle.
--
-- ── WHAT CHANGED IN #076 ──────────────────────────────────────────────────────────────────────────
-- It used to plant a 2-part box trunk + box canopy, 16 per bank per 40-stud segment, inland-biased by
-- `u^0.6`. Now it clones REAL models from `ServerStorage.AssetLibrary` in three bands (see `FoliageDefs`):
--
--   band 1 SHORE  light undergrowth + the hero palm, on Sand or grass
--   band 1 ALLEY  leaning palms at the waterline, tilted out over the channel
--   band 2 MID    individual trees with gaps between
--   band 3 WALL   `JungleTreesPack` TILED on a global grid into a solid canopy
--
-- ⚠️ THE MATERIAL TEST HAD TO CHANGE, AND IT IS EASY TO MISS. The old code required
-- `hit.Material == Enum.Material.Grass`. Job #076 also repaints the world — shore Sand, jungle
-- Grass + LeafyGrass — so that single-material test would have silently refused to plant on most of the
-- map. Bands now declare the materials they accept (`FoliageDefs.*_GROUND`).
--
-- ── WHAT DELIBERATELY DID NOT CHANGE ──────────────────────────────────────────────────────────────
-- Three pieces of hard-won behaviour are preserved verbatim; all three exist because of a real bug:
--   · FORK AWARENESS — plant beyond the OUTERMOST branch edge, never inside a fork channel or on its island
--   · DOCK CLEARINGS — a `DOCK_CLEAR` gap at landing docks, so you can actually disembark (Job 051)
--   · SPAWN-BASE EXCLUSION — measured from the camp's own parts, so extending the hand-dressed camp in
--     the editor widens the exclusion with no script edit (Job 073)
--
-- The models live in the PLACE FILE (`ServerStorage.AssetLibrary` is not a Rojo-synced path), so a missing
-- library is a loud failure here rather than a silently empty jungle.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))

local AHEAD = 800
local BEHIND = 220
local SEG = 40 -- studs of river per foliage segment
local MAX_GROUND_Y = 27 -- keep foliage on the grassy banks, not up on the rock/snow
local DOCK_CLEAR = 30 -- clearing around a landing dock so you can disembark (Job 051)
local CAMP_MARGIN = 40 -- keep clear of the hand-built spawn base (Job 073)
local SINK = 0.4 -- push models this far into the ground so they never appear to float

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

-- ── the asset library ─────────────────────────────────────────────────────────────────────────────
-- Flattened by NAME across the library's group folders (Foliage / Rocks / Logs / …), so `FoliageDefs` can
-- say "PalmCoconut" without also encoding which folder it happens to live in.
local library: { [string]: Model } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	if not lib then
		warn("[Foliage] ⛔ NO ServerStorage.AssetLibrary — the river will have NO foliage. It lives in the "
			.. "place file, not in git: open the game place and save it.")
		return
	end
	for _, group in ipairs(lib:GetChildren()) do
		for _, m in ipairs(group:GetChildren()) do
			if m:IsA("Model") and not library[m.Name] then
				library[m.Name] = m
			end
		end
	end
end

-- BASEPARTS, not descendants. The first playtest reported "~21420 instances live" against a ~5,560
-- budget, which looked like a density bug and wasn't: `#GetDescendants()` also counts SurfaceAppearance,
-- Attachments, Textures and so on, so it was measuring a different quantity from the one the budget was
-- reasoned about. Parts are what cost frames, so parts are what gets counted.
local function instancesOf(name: string): number
	local m = library[name]
	if not m then
		return 0
	end
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Fail loudly and by name for anything the band table asks for and the library doesn't have, rather than
-- planting a thinner jungle and leaving no clue why.
do
	local missing: { string } = {}
	local function need(name: string)
		if not library[name] then
			table.insert(missing, name)
		end
	end
	for _, band in ipairs(FoliageDefs.BANDS) do
		for _, e in ipairs(band.entries) do
			need(e.model)
		end
	end
	need(FoliageDefs.ALLEY.model)
	need(FoliageDefs.WALL.model)
	if #missing > 0 then
		warn(("[Foliage] ⛔ missing from AssetLibrary: %s"):format(table.concat(missing, ", ")))
	end
end

local root = Instance.new("Folder")
root.Name = "Foliage"
root.Parent = Workspace

local placed: { [number]: Model } = {}
local rng = Random.new(RiverData.getSeed()) -- same river ⇒ same jungle

-- ── spawn-base exclusion (Job 073, preserved) ─────────────────────────────────────────────────────
-- The camp is hand-dressed in the editor with real foliage. This generator streams across it, so without
-- an exclusion it plants a second, procedural jungle straight through the finished camp.
--
-- Two things this gets right that are easy to get wrong:
--   · World-space AABB from part CORNERS. `GetBoundingBox()`/`GetExtentsSize()` return the ORIENTED box and
--     lie about world occupancy — the lesson Job 072 learned on the plane wreck.
--   · `Dock.PlacePlace` is EXCLUDED. It is the plane's fly-in marker parked 500 studs west at X −760, not
--     camp geometry; including it inflated the footprint from 681 to 845 studs wide.
local campMin: Vector2?, campMax: Vector2? = nil, nil
do
	local sb = Workspace:FindFirstChild("SpawnBase")
	if sb then
		local mn = Vector2.new(math.huge, math.huge)
		local mx = Vector2.new(-math.huge, -math.huge)
		local n = 0
		for _, d in sb:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "PlacePlace" then
				n += 1
				local cf, half = d.CFrame, d.Size / 2
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local c = cf * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
							mn = Vector2.new(math.min(mn.X, c.X), math.min(mn.Y, c.Z))
							mx = Vector2.new(math.max(mx.X, c.X), math.max(mx.Y, c.Z))
						end
					end
				end
			end
		end
		if n > 0 then
			campMin = mn - Vector2.new(CAMP_MARGIN, CAMP_MARGIN)
			campMax = mx + Vector2.new(CAMP_MARGIN, CAMP_MARGIN)
			print(("[Foliage] spawn-base exclusion: X %.0f..%.0f Z %.0f..%.0f (%d parts, +%d margin)")
				:format((campMin :: Vector2).X, (campMax :: Vector2).X, (campMin :: Vector2).Y, (campMax :: Vector2).Y, n, CAMP_MARGIN))
		end
	else
		warn("[Foliage] no Workspace.SpawnBase — foliage may be planted inside the hand-built camp")
	end
end

local function inCamp(x: number, z: number): boolean
	local mn, mx = campMin, campMax
	if not mn or not mx then
		return false
	end
	return x >= mn.X and x <= mx.X and z >= mn.Y and z <= mx.Y
end

-- ── placement ─────────────────────────────────────────────────────────────────────────────────────

-- Sit a cloned model on the ground with its BASE at `pos`, whatever its pivot happens to be.
--
-- Store models have arbitrary pivots — some at the origin, some at the centre, some off in space — so
-- `PivotTo(CFrame.new(pos))` floats or buries them unpredictably. Measuring the bounding box after
-- orienting and then lifting by the difference works for every model without per-asset offsets.
local function seat(model: Model, pos: Vector3, orient: CFrame, scale: number)
	model:ScaleTo(scale)
	model:PivotTo(CFrame.new(pos) * orient)
	local bcf, bsize = model:GetBoundingBox()
	local bottom = bcf.Position.Y - bsize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, (pos.Y - bottom) - SINK, 0))
end

local function prepare(model: Model, collide: boolean, shadow: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- Non-colliding by default. A tree the boat can hit is a tree that can destroy the boat
			-- assembly (see RiverBootstrap: obstacles are deliberately non-colliding triggers for
			-- exactly this reason), and hundreds of colliding trunks is also a physics bill for nothing.
			d.CanCollide = collide
			-- Shadows are OPT-IN per entry, not per part class. Casting from every instance would mean
			-- ~5,500 shadow casters, which is the single easiest way to lose the mobile frame budget —
			-- but the alley palms' shadows falling across the water are most of the point of the alley,
			-- so those are switched on deliberately (FoliageDefs `shadow`).
			d.CastShadow = shadow
		end
	end
	-- ⚠️ `Model.LevelOfDetail` IS NOT WRITABLE FROM A SERVER SCRIPT — it needs the Plugin capability, and
	-- trying threw "The current thread cannot write 'LevelOfDetail'" once per placement in the first
	-- playtest. It is set ONCE at authoring time on the AssetLibrary source models instead (Studio has the
	-- capability), and clones inherit it. See `tools/` note in the job summary; nothing to do at runtime.
end

local function uniform(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- Expected count for a spacing over a segment, with the fraction resolved probabilistically so a spacing
-- wider than SEG still places sometimes rather than never.
local function countFor(spacing: number): number
	local exact = SEG / spacing
	local n = math.floor(exact)
	if rng:NextNumber() < (exact - n) then
		n += 1
	end
	return n
end

-- ── segment build ─────────────────────────────────────────────────────────────────────────────────

local function buildSeg(idx: number)
	if placed[idx] then
		return
	end

	local model = Instance.new("Model")
	model.Name = "Seg_" .. idx

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	params.IgnoreWater = true

	-- landing docks in this segment get a clearing so players can disembark (Job 051)
	local landings = {}
	for _, d in RiverData.docksBetween(idx * SEG, idx * SEG + SEG) do
		if d.landing then
			table.insert(landings, d)
		end
	end
	local function nearLanding(x: number, z: number): boolean
		for _, d in landings do
			if (Vector2.new(x, z) - Vector2.new(d.x, d.z)).Magnitude < DOCK_CLEAR then
				return true
			end
		end
		return false
	end

	-- Outermost channel edge on a side, so nothing is ever planted in a fork channel or on its island.
	local function bankEdge(z: number, side: number): number
		local right, left = -math.huge, math.huge
		for _, b in RiverData.branchesAt(z) do
			right = math.max(right, b.c + b.halfW)
			left = math.min(left, b.c - b.halfW)
		end
		return if side == 1 then right else left
	end

	local terrainFound = false
	local count = 0

	-- Try to plant one instance. Returns false if the spot was rejected, so callers don't over-count.
	local function tryPlant(
		name: string,
		z: number,
		side: number,
		inland: number,
		ground: { [Enum.Material]: boolean },
		scale: { number },
		collide: boolean,
		shadow: boolean,
		orient: CFrame
	): boolean
		local source = library[name]
		if not source then
			return false
		end
		local x = bankEdge(z, side) + side * inland
		local hit = Workspace:Raycast(Vector3.new(x, 90, z), Vector3.new(0, -200, 0), params)
		if not hit or hit.Instance ~= Workspace.Terrain then
			return false
		end
		-- terrainFound is set even when the spot is rejected, so a segment over real terrain is marked
		-- placed and we stop re-scanning it every tick forever
		terrainFound = true
		if not ground[hit.Material] or hit.Position.Y >= MAX_GROUND_Y then
			return false
		end
		if nearLanding(x, z) or inCamp(x, z) then
			return false
		end

		local clone = source:Clone()
		prepare(clone, collide, shadow)
		seat(clone, hit.Position, orient, uniform(scale))
		clone.Parent = model
		count += 1
		return true
	end

	-- ── bands 1 and 2 ──
	for _, band in ipairs(FoliageDefs.BANDS) do
		for _, e in ipairs(band.entries) do
			-- ipairs, NOT pairs: `pairs` order is undefined, so the RNG would be consumed in a different
			-- order each run and "same seed ⇒ same jungle" would quietly stop being true.
			for _, side in ipairs({ -1, 1 }) do
				for _ = 1, countFor(e.spacing) do
					local z = idx * SEG + rng:NextNumber(0, SEG)
					local inland = uniform(band.inland)
					local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					local orient = yaw
					if e.tiltMax and e.tiltMax > 0 then
						local a = math.rad(rng:NextNumber(0, e.tiltMax))
						local dir = rng:NextNumber(0, math.pi * 2)
						orient = CFrame.fromAxisAngle(Vector3.new(math.cos(dir), 0, math.sin(dir)), a) * yaw
					end
					tryPlant(e.model, z, side, inland, band.ground, e.scale, e.collide == true, e.shadow == true, orient)
				end
			end
		end
	end

	-- ── the alley ──
	-- Leaning palms tilted toward the channel. The lean axis is derived per-palm from the side it stands
	-- on, so on a bend they lean over the WATER rather than in a fixed world direction.
	local A = FoliageDefs.ALLEY
	for _, side in ipairs({ -1, 1 }) do
		local phase = if side == 1 then A.phase else 0
		-- walk the global grid so spacing is consistent across segment boundaries
		local first = math.ceil((idx * SEG - phase) / A.spacing)
		local last = math.floor(((idx + 1) * SEG - phase) / A.spacing)
		for k = first, last do
			local z = k * A.spacing + phase
			-- lean toward the channel centre: that is -side on X
			local leanDir = Vector3.new(-side, 0, 0)
			local axis = Vector3.new(0, 1, 0):Cross(leanDir)
			local orient = CFrame.fromAxisAngle(axis.Unit, math.rad(uniform(A.tilt)))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			-- shadow = true: the alley's shadows falling across the water are the effect itself
			tryPlant(A.model, z, side, uniform(A.inland), A.ground, A.scale, false, true, orient)
		end
	end

	-- ── band 3: the canopy wall ──
	-- Tiled on a global grid, not scattered: the pack is 218 studs long, so a random position would
	-- swallow a third of the streaming window and tiles would gap or double up at segment edges.
	local W = FoliageDefs.WALL
	for _, side in ipairs({ -1, 1 }) do
		local first = math.ceil((idx * SEG) / W.TILE_LEN)
		local last = math.floor(((idx + 1) * SEG) / W.TILE_LEN)
		for k = first, last do
			local z = k * W.TILE_LEN
			local inland = W.inland + rng:NextNumber(-W.jitter, W.jitter)
			-- faced along the river, flipped on the far bank so the pack's own arrangement mirrors
			local orient = CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
			-- no shadows on the wall: 112 instances x ~10 live, and it is 130+ studs from the player
			tryPlant(W.model, z, side, inland, W.ground, W.scale, false, false, orient)
		end
	end

	if not terrainFound then
		model:Destroy() -- terrain not generated here yet → leave unmarked, retry next tick
		return
	end

	if count > FoliageDefs.MAX_PER_SEGMENT then
		warn(("[Foliage] segment %d placed %d models (cap %d) — check FoliageDefs spacing")
			:format(idx, count, FoliageDefs.MAX_PER_SEGMENT))
	end

	model.Parent = root
	placed[idx] = model
end

print(("[Foliage] banded jungle online — %d models in library, ~%d PARTS live in a %d-stud window")
	:format(
		(function()
			local n = 0
			for _ in pairs(library) do
				n += 1
			end
			return n
		end)(),
		FoliageDefs.estimateLive(AHEAD + BEHIND, instancesOf),
		AHEAD + BEHIND
	))

while true do
	local bz = hull.Position.Z
	for i = math.floor((bz - BEHIND) / SEG), math.floor((bz + AHEAD) / SEG) do
		buildSeg(i)
	end
	-- cull behind / far ahead: one Destroy per segment folder
	for i, m in pairs(placed) do
		local segZ = i * SEG
		if segZ < bz - BEHIND - SEG or segZ > bz + AHEAD + SEG then
			m:Destroy()
			placed[i] = nil
		end
	end
	task.wait(0.4)
end
