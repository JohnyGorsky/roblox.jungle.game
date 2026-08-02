--!strict
-- FoliageServer.server.luau — greybox jungle trees along ALL shores (Job 012 follow-up).
--
-- Streams simple tree blocks along both banks near the boat (generate ahead, cull behind). Each tree
-- is raycast onto the terrain and only placed on LOW GRASS bank (not up on rock/snow), so the whole
-- river reads as jungle. Greybox — real foliage/instancing comes in the art pass.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local AHEAD = 800
local BEHIND = 220
local SEG = 40 -- studs of river per foliage segment
local PER_BANK = 16 -- trees per bank per segment (a THICK jungle wall — off-path is dense, Job 051)
local MAX_TREE_Y = 27 -- keep trees on the grassy banks, not up on the rock/snow
local BAND = 150 -- how far inland from the water edge trees can go (up to where mountains start)
local DOCK_CLEAR = 30 -- leave a clearing this wide around a landing dock so you can disembark (Job 051)
local CAMP_MARGIN = 40 -- keep greybox this far clear of the hand-built spawn base (Job 073)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

local root = Instance.new("Folder")
root.Name = "Foliage"
root.Parent = Workspace

local placed: { [number]: Model } = {}
local rng = Random.new(99)

-- ── NEVER plant greybox inside the hand-built spawn base (Job 073) ──────────────────────────────────
-- The camp is hand-dressed in the editor with REAL foliage (45 palm/tree/fern models in
-- `SpawnBase.Foliage`). This generator streams from `boat.Z - BEHIND` to `boat.Z + AHEAD`, and the boat
-- now starts at Z −270 (Job 072), so it was planting box-trunk/box-canopy greybox straight through the
-- finished camp — right next to the real palms. It already had a `DOCK_CLEAR` carve-out for landing
-- docks; it just knew nothing about the camp.
--
-- The footprint is MEASURED from the camp itself rather than hardcoded, so extending the hand-placed
-- dressing in the editor widens the exclusion automatically — no script edit.
--
-- ⚠️ Two things this gets right that are easy to get wrong:
--   · World-space AABB from part CORNERS. `GetBoundingBox()`/`GetExtentsSize()` return the ORIENTED box
--     and lie about world occupancy — the lesson Job 072 learned the hard way on the plane wreck.
--   · `Dock.PlacePlace` is EXCLUDED. It is the plane's fly-in start marker parked 500 studs west at
--     X −760, not camp geometry; including it inflated the footprint from 681 to 845 studs wide and
--     would have suppressed foliage over empty terrain the player never visits.
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
		warn("[Foliage] no Workspace.SpawnBase — greybox trees may be planted inside the hand-built camp")
	end
end

local function inCamp(x: number, z: number): boolean
	local mn, mx = campMin, campMax
	if not mn or not mx then
		return false
	end
	return x >= mn.X and x <= mx.X and z >= mn.Y and z <= mx.Y
end

local function tree(pos: Vector3, parent: Instance)
	local h = rng:NextNumber(10, 17)
	local trunk = Instance.new("Part")
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Size = Vector3.new(2, h, 2)
	trunk.Color = Color3.fromRGB(90, 60, 40)
	trunk.Material = Enum.Material.Wood
	trunk.CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0))
	trunk.Parent = parent
	local canopy = Instance.new("Part")
	canopy.Anchored = true
	canopy.CanCollide = false
	canopy.Size = Vector3.new(10, 7, 10)
	canopy.Color = Color3.fromRGB(45, 100, 50)
	canopy.CFrame = CFrame.new(pos + Vector3.new(0, h + 2, 0))
	canopy.Parent = parent
end

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

	local terrainFound = false
	for _, side in ipairs({ -1, 1 }) do
		for _ = 1, PER_BANK do
			local z = idx * SEG + rng:NextNumber(0, SEG)
			-- fork-aware: plant beyond the OUTERMOST branch edge on this side (never in a fork channel / island)
			local rightEdge, leftEdge = -math.huge, math.huge
			for _, b in RiverData.branchesAt(z) do
				rightEdge = math.max(rightEdge, b.c + b.halfW)
				leftEdge = math.min(leftEdge, b.c - b.halfW)
			end
			local baseEdge = if side == 1 then rightEdge else leftEdge
			-- inland-biased (u^0.6 favours the far band → a THICK back-forest, lighter right at the shore)
			local inland = 4 + (BAND - 4) * (rng:NextNumber() ^ 0.6)
			local x = baseEdge + side * inland
			local hit = Workspace:Raycast(Vector3.new(x, 90, z), Vector3.new(0, -200, 0), params)
			if hit and hit.Instance == Workspace.Terrain then
				terrainFound = true
				-- terrainFound stays set above even when we skip, so the segment is still marked
				-- placed and we don't re-scan it every 0.4 s forever
				if
					hit.Material == Enum.Material.Grass
					and hit.Position.Y < MAX_TREE_Y
					and not nearLanding(x, z)
					and not inCamp(x, z)
				then
					tree(hit.Position, model)
				end
			end
		end
	end
	if not terrainFound then
		model:Destroy() -- terrain not generated here yet → leave unmarked, retry next tick
		return
	end
	model.Parent = root
	placed[idx] = model
end

while true do
	local bz = hull.Position.Z
	for i = math.floor((bz - BEHIND) / SEG), math.floor((bz + AHEAD) / SEG) do
		buildSeg(i)
	end
	for i, m in placed do
		if i * SEG < bz - BEHIND - SEG then
			m:Destroy()
			placed[i] = nil
		end
	end
	task.wait(0.4)
end
