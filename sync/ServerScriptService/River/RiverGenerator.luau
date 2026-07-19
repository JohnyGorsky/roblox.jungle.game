--!strict
-- RiverGenerator.luau — materializes the river as seeded voxel terrain, one CHUNK at a time (Job 005).
--
-- Reads shape from RiverData (the single source of truth) and writes Roblox terrain with the
-- roblox-terrain discipline: compute the whole voxel grid up front, then ONE WriteVoxels per chunk
-- (carve-then-fill in a single pass). Chunks tile seamlessly because RiverData is continuous.
--
-- Per column we precompute centerline/width (depends on z only) and the land surface height
-- (depends on x,z only), so the inner y-loop is cheap — keeps a chunk well under a frame's budget.

local RiverData = require(game:GetService("ReplicatedStorage"):WaitForChild("River"):WaitForChild("RiverData"))

local RiverGenerator = {}

local Terrain = workspace.Terrain

-- ── config (tunable) ───────────────────────────────────────────────────────
RiverGenerator.CHUNK_LEN = 256      -- downstream studs per chunk
local RES = 4                       -- voxel resolution
local CHANNEL_DEPTH = 18            -- water carved this far below WATER_Y (bed = WATER_Y - depth)
local LAND = 220                    -- grass+hill band beyond each bank edge
local MAX_HALFW = 170               -- upper bound of widthAt()/2 (≥ W_CEIL/2 = 165, wide Delta), for sizing the chunk region
local HILL_MAX = 42                 -- max hill height added far from the channel
local BANK_LIP = 10                 -- how high the immediate bank rises out of the water
local Y_MIN, Y_MAX = -8, 64         -- vertical span of generated terrain
local ROCK_Y, SNOW_Y = 26, 40       -- altitude bands for material painting
local HOFF1, HOFF2 = 13.2, 27.7     -- hill-noise offsets
-- ───────────────────────────────────────────────────────────────────────────

local WATER_Y = RiverData.WATER_Y

-- world-aligned Region3 covering one chunk (X sized to the centerline's local span + banks)
function RiverGenerator.chunkRegion(chunkIndex: number): Region3
	local zMin = RiverData.Z_START + chunkIndex * RiverGenerator.CHUNK_LEN
	local zMax = zMin + RiverGenerator.CHUNK_LEN
	local minCx, maxCx = math.huge, -math.huge
	for z = zMin, zMax, 16 do
		local cx = RiverData.centerlineX(z)
		minCx = math.min(minCx, cx)
		maxCx = math.max(maxCx, cx)
	end
	local pad = MAX_HALFW + LAND
	return Region3.new(
		Vector3.new(minCx - pad, Y_MIN, zMin),
		Vector3.new(maxCx + pad, Y_MAX, zMax)
	):ExpandToGrid(RES)
end

-- generate (or regenerate) one chunk's terrain
function RiverGenerator.generateChunk(chunkIndex: number): Region3
	local region = RiverGenerator.chunkRegion(chunkIndex)
	local size = region.Size
	local nx = math.floor(size.X / RES + 0.5)
	local ny = math.floor(size.Y / RES + 0.5)
	local nz = math.floor(size.Z / RES + 0.5)
	local base = region.CFrame.Position - size / 2 -- min corner

	-- per-z: the channel(s) at this slice — one normally, two (around an island) inside a fork
	local brk = table.create(nz)
	for k = 1, nz do
		local wz = base.Z + (k - 0.5) * RES
		brk[k] = RiverData.branchesAt(wz)
	end

	-- per-(x,z) column: land surface height, or -1 to mark the water channel. "edge" = distance PAST the
	-- nearest branch's bank; <0 means inside a channel. Land between two branches becomes a low island.
	local surf = table.create(nx)
	for i = 1, nx do
		local wx = base.X + (i - 0.5) * RES
		local col = table.create(nz)
		for k = 1, nz do
			local edge = math.huge
			for _, b in brk[k] do
				local e = math.abs(wx - b.c) - b.halfW
				if e < edge then
					edge = e
				end
			end
			if edge < 0 then
				col[k] = -1 -- channel (within some branch)
			else
				local lip = math.min(edge * 0.6, BANK_LIP)
				-- keep a grassy jungle flat near the water; hills only rise well back from the bank
				local far = math.clamp((edge - 70) / 170, 0, 1)
				local hn = math.noise(wx * 0.012 + HOFF1, base.Z * 0.012 + (k * RES) * 0.012 + HOFF2) * 2 * 0.5 + 0.5
				col[k] = WATER_Y + lip + hn * HILL_MAX * far
			end
		end
		surf[i] = col
	end

	-- fill the voxel grid
	local mats = table.create(nx)
	local occs = table.create(nx)
	for i = 1, nx do
		local colSurf = surf[i]
		local matI = table.create(ny)
		local occI = table.create(ny)
		for j = 1, ny do
			local wy = base.Y + (j - 0.5) * RES
			local matJ = table.create(nz)
			local occJ = table.create(nz)
			for k = 1, nz do
				local s = colSurf[k]
				local mat: Enum.Material = Enum.Material.Air
				local occ = 0
				if s < 0 then
					-- water channel
					if wy < WATER_Y - CHANNEL_DEPTH then
						mat, occ = Enum.Material.Grass, 1 -- riverbed
					elseif wy < WATER_Y then
						mat, occ = Enum.Material.Water, 1
					end
				elseif wy < s then
					occ = 1
					if wy > SNOW_Y then
						mat = Enum.Material.Snow
					elseif wy > ROCK_Y then
						mat = Enum.Material.Rock
					else
						mat = Enum.Material.Grass
					end
				end
				matJ[k] = mat
				occJ[k] = occ
			end
			matI[j] = matJ
			occI[j] = occJ
		end
		mats[i] = matI
		occs[i] = occI
	end

	Terrain:WriteVoxels(region, RES, mats, occs)
	return region
end

-- clear one chunk's terrain (cull behind the boat)
function RiverGenerator.clearChunk(chunkIndex: number)
	Terrain:FillRegion(RiverGenerator.chunkRegion(chunkIndex), RES, Enum.Material.Air)
end

return RiverGenerator
