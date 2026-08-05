--!strict
-- RiverBootstrap.server.luau — owns the live river (Job 005).
--
-- On server start: clear old terrain, seed the river, generate the opening stretch, then signal
-- "RiverReady" so the boat spawns onto real water. Thereafter it STREAMS: generate chunks ahead of
-- the boat, cull chunks behind (mobile memory budget), and place the finish line at END_DISTANCE.
-- Publishes BoatDistance / RiverEndDistance attributes for a future HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- real river obstacles (Job 036): built on "obstacle" hooks; tagged "Obstacle" with Slow/Damage attributes
-- that ObstacleServer reads on boat contact. Non-colliding triggers (physical collision would blow up the
-- boat assembly) — the hit applies a velocity cut + hull damage instead.
-- Job #076: each type now names a REAL model from `ServerStorage.AssetLibrary`. The greybox box is kept
-- as the FALLBACK, not deleted, because the library lives in the place file rather than in git — a fresh
-- clone with no saved .rbxl must still get playable obstacles rather than an invisible river hazard.
--
-- `Sandbar` has no model and doesn't want one: it is a flat shoal, so it stays a low box on Sand material,
-- which is exactly what a sandbar looks like from a boat.
type Obstacle = {
	name: string,
	model: string?, -- nil = the greybox box IS the visual (Sandbar)
	-- "bed"   rests on the RIVERBED and is stretched so its top breaks the surface
	-- "float" floats AT the surface (a log), positioned by `submerge`
	seatOn: string,
	protrude: number, -- studs above WATER_Y for a "bed" obstacle
	submerge: number, -- fraction of height below WATER_Y for a "float" obstacle
	size: Vector3,
	color: Color3,
	mat: Enum.Material,
	slow: number,
	damage: number,
}

local OBSTACLES: { Obstacle } = {
	-- `submerge` = fraction of the model's height BELOW the waterline. A boulder is mostly under and breaks
	-- the surface; a log floats with most of it showing. Without this they hover (Job #076 playtest: "why do
	-- we have rocks on water :D").
	-- A boulder RESTS ON THE BOTTOM. Positioning it relative to the water surface (the first attempt) left
	-- it suspended: the bed is 18 studs down (`CHANNEL_DEPTH`), so a "55% submerged" rock hung 13 studs
	-- above the riverbed and read as floating through the clear water.
	{ name = "Rock", model = "RockA", seatOn = "bed", protrude = 3, submerge = 0, size = Vector3.new(10, 10, 10), color = Color3.fromRGB(110, 112, 122), mat = Enum.Material.Rock, slow = 0.85, damage = 25 },
	-- A log genuinely FLOATS, so this one is surface-relative and stays that way.
	{ name = "Log", model = "LogMossy", seatOn = "float", protrude = 0, submerge = 0.35, size = Vector3.new(4, 3, 20), color = Color3.fromRGB(92, 62, 40), mat = Enum.Material.Wood, slow = 0.5, damage = 12 },
	-- A sandbar is a MOUND rising off the bed to just under the surface — which is what it looks like once
	-- it is seated properly, and it also stops the old flat slab reading as a plank floating on the water.
	{ name = "Sandbar", model = nil, seatOn = "bed", protrude = 0.4, submerge = 0, size = Vector3.new(22, 1.5, 16), color = Color3.fromRGB(205, 188, 132), mat = Enum.Material.Sand, slow = 0.7, damage = 4 },
}

-- Real obstacle art, looked up once. Missing library => greybox fallback, warned once, river still playable.
local obstacleArt: { [string]: Model } = {}
do
	local lib = game:GetService("ServerStorage"):FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				if m:IsA("Model") then
					obstacleArt[m.Name] = m
				end
			end
		end
	else
		warn("[Obstacle] no ServerStorage.AssetLibrary — obstacles fall back to greybox boxes")
	end
end

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local RiverGenerator = require(ServerScriptService:WaitForChild("River"):WaitForChild("RiverGenerator"))
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))

-- ── config ─────────────────────────────────────────────────────────────────
local AHEAD_CHUNKS = 7   -- chunks kept generated ahead of the boat (~1800 studs)
local BEHIND_CHUNKS = 2  -- chunks kept behind before culling
local TICK = 0.15        -- streaming update period (s)
-- ───────────────────────────────────────────────────────────────────────────

local CHUNK_LEN = RiverGenerator.CHUNK_LEN
local MAX_CHUNK = math.floor(RiverData.END_DISTANCE / CHUNK_LEN)

-- seed priority: explicit Workspace attribute > lobby TELEPORT DATA (party shares one river) > dev default.
-- On a reserved server the lobby passes { seed } via TeleportData; every party member carries the same
-- value, so we read it off the first arriving player (briefly waiting for them). In Studio / direct joins
-- there's no teleport data → falls back to the default. (Job 017)
local seed = Workspace:GetAttribute("RiverSeed") :: number?
if not seed then
	local deadline = os.clock() + 5
	while not Players:GetPlayers()[1] and os.clock() < deadline do
		task.wait(0.1)
	end
	local first = Players:GetPlayers()[1]
	if first then
		local ok, data = pcall(function()
			return first:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" and typeof(data.seed) == "number" then
			seed = data.seed
		end
	end
end
RiverData.setSeed(seed or 2026)

local generated: { [number]: boolean } = {}

-- greybox obstacle/ramp markers (real props come later), streamed with their chunk
local hooksRoot = Instance.new("Folder")
hooksRoot.Name = "RiverHooks"
hooksRoot.Parent = Workspace

local function placeHooks(index: number)
	if hooksRoot:FindFirstChild("Chunk_" .. index) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Chunk_" .. index
	local zMin = RiverData.Z_START + index * CHUNK_LEN
	for _, h in ipairs(RiverData.hooksBetween(zMin, zMin + CHUNK_LEN - 1)) do
		if h.kind == "ramp" then
			-- ramp hooks stay greybox markers for now (ramp jumps are prototyped separately, Job 019)
			local p = Instance.new("Part")
			p.Name = "Hook_ramp"
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Size = Vector3.new(30, 6, 22)
			p.Position = Vector3.new(h.x, RiverData.WATER_Y + 1, h.z)
			p.Color = Color3.fromRGB(90, 220, 120)
			p:SetAttribute("HookKind", "ramp")
			p.Parent = folder
		else
			-- REAL obstacle (Job 036): pick a type deterministically by z; slow + damage on contact
			local pick = OBSTACLES[(math.floor(math.abs(math.noise(h.z * 0.11, 7.7)) * 97) % #OBSTACLES) + 1]

			-- Find the RIVERBED under this hook. generateChunk() has already run for this chunk (see
			-- ensureChunk), so the terrain is there to hit.
			local bedParams = RaycastParams.new()
			bedParams.FilterType = Enum.RaycastFilterType.Include
			bedParams.FilterDescendantsInstances = { Workspace.Terrain }
			bedParams.IgnoreWater = true
			local bedHit = Workspace:Raycast(Vector3.new(h.x, RiverData.WATER_Y + 60, h.z), Vector3.new(0, -200, 0), bedParams)
			local bedY = if bedHit then bedHit.Position.Y else (RiverData.WATER_Y - 18)

			-- Height and centre come from where the thing actually sits, not from a fixed size.
			local height, centreY
			if pick.seatOn == "bed" then
				height = math.max(2, (RiverData.WATER_Y + pick.protrude) - bedY)
				centreY = bedY + height / 2
			else
				height = pick.size.Y
				centreY = RiverData.WATER_Y + height * (0.5 - pick.submerge)
			end

			-- ⚠️ THE TRIGGER PART IS STILL THE TRIGGER, AND IT MUST STAY NON-COLLIDING.
			-- `ObstacleServer` reads the `Obstacle` tag and the Slow/Damage attributes off THIS part, and it
			-- is deliberately CanCollide = false: physical collision with the boat assembly blows it up.
			-- Job #076 changes only what you SEE.
			local p = Instance.new("Part")
			p.Name = pick.name
			p.Anchored = true
			p.CanCollide = false -- trigger; ObstacleServer applies the hit (physical collision = boat blowup)
			p.Material = pick.mat
			p.Size = Vector3.new(pick.size.X, height, pick.size.Z)
			p.Position = Vector3.new(h.x, centreY, h.z)
			p.Color = pick.color
			p:SetAttribute("HookKind", "obstacle")
			p:SetAttribute("Slow", pick.slow)
			p:SetAttribute("Damage", pick.damage)
			CollectionService:AddTag(p, "Obstacle")

			local art = if pick.model then obstacleArt[pick.model] else nil
			if art then
				local clone = art:Clone()
				clone.Name = "Art"
				local meshes = {}
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CastShadow = false
						table.insert(meshes, d)
					end
				end
				-- Our rock and log models are SINGLE MeshParts, so the art can simply be stretched to the
				-- trigger's box — which guarantees the thing you see and the thing that hurts you are the
				-- same shape in the same place, and lets a boulder be tall enough to reach the bed without
				-- also becoming absurdly wide (uniform ScaleTo cannot do that).
				if #meshes == 1 then
					local m = meshes[1]
					m.Size = p.Size
					m.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.noise(h.z * 0.31, 3.1) * math.pi * 2, 0)
					p.Transparency = 1 -- trigger invisible; the mesh is the visual
				else
					local _, ext = clone:GetBoundingBox()
					local have = math.max(ext.X, ext.Z)
					if have > 0 then
						clone:ScaleTo(math.max(pick.size.X, pick.size.Z) / have)
					end
					clone:PivotTo(CFrame.new(p.Position))
					local bottom = FoliageDefs.worldBottom(clone)
					if bottom then
						clone:PivotTo(clone:GetPivot() + Vector3.new(0, (centreY - height / 2) - bottom, 0))
					end
					p.Transparency = 1
				end
				clone.Parent = p
			end
			p.Parent = folder
		end
	end
	folder.Parent = hooksRoot
end

local function clearHooks(index: number)
	local folder = hooksRoot:FindFirstChild("Chunk_" .. index)
	if folder then
		folder:Destroy()
	end
end

local function ensureChunk(index: number)
	if index < 0 or index > MAX_CHUNK or generated[index] then
		return
	end
	RiverGenerator.generateChunk(index)
	placeHooks(index)
	generated[index] = true
end

local function cullChunk(index: number)
	if generated[index] then
		RiverGenerator.clearChunk(index)
		clearHooks(index)
		generated[index] = nil
	end
end

-- finish line: a bright marker spanning the channel at END_DISTANCE (greybox — real end set-piece at P9)
local endPlaced = false
local function placeEnd()
	if endPlaced or RiverData.ENDLESS then
		return
	end
	endPlaced = true
	local z = RiverData.distanceToWorldZ(RiverData.END_DISTANCE)
	local pos = RiverData.positionAt(z)
	local bar = Instance.new("Part")
	bar.Name = "FinishLine"
	bar.Anchored = true
	bar.CanCollide = false
	bar.Size = Vector3.new(RiverData.widthAt(z) + 40, 24, 4)
	bar.Position = pos + Vector3.new(0, 10, 0)
	bar.Color = Color3.fromRGB(255, 215, 0)
	bar.Material = Enum.Material.Neon
	bar.Transparency = 0.3
	bar.CFrame = CFrame.lookAt(bar.Position, bar.Position + RiverData.tangentAtZ(z))
	bar.Parent = Workspace
end

-- ── boot: generate the opening stretch, signal ready ────────────────────────
--
-- ⚠️ NO `Workspace.Terrain:Clear()` HERE — Job #071. It used to wipe every voxel on boot, which was
-- harmless while the whole world was procedural and became DESTRUCTIVE the moment the START and END
-- areas became hand-sculpted terrain living in the place file: every server start would have erased
-- them. Nothing needs clearing now — the place ships with the two editor zones and an EMPTY corridor,
-- the generator writes chunks as the boat advances, and cullChunk removes them behind it.
--
-- If stale terrain ever does appear in the corridor, fix it in the place file (clear it once in Studio
-- and save) rather than reinstating a blanket Clear here.
Workspace:SetAttribute("RiverEndDistance", RiverData.END_DISTANCE)
Workspace:SetAttribute("BoatDistance", 0)
for i = 0, AHEAD_CHUNKS do
	ensureChunk(i)
end
Workspace:SetAttribute("RiverReady", true)

-- ── stream with the boat ────────────────────────────────────────────────────
while true do
	local boat = Workspace:FindFirstChild("Boat")
	local hull = boat and boat:FindFirstChild("Hull") :: BasePart?
	if hull then
		local dist = RiverData.worldToDistance(hull.Position.Z)
		Workspace:SetAttribute("BoatDistance", math.max(0, math.floor(dist)))
		local cur = math.floor(dist / CHUNK_LEN)

		-- generate the nearest missing chunk ahead (one per tick to spread the cost)
		for i = cur, cur + AHEAD_CHUNKS do
			if i >= 0 and i <= MAX_CHUNK and not generated[i] then
				ensureChunk(i)
				break
			end
		end

		-- cull anything outside the live window
		for index in pairs(generated) do
			if index < cur - BEHIND_CHUNKS or index > cur + AHEAD_CHUNKS then
				cullChunk(index)
			end
		end

		-- finish line once its chunk is in view
		if cur >= MAX_CHUNK - AHEAD_CHUNKS then
			placeEnd()
		end
	end
	task.wait(TICK)
end
