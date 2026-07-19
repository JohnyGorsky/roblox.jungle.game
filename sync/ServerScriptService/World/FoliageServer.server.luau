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
				if hit.Material == Enum.Material.Grass and hit.Position.Y < MAX_TREE_Y and not nearLanding(x, z) then
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
