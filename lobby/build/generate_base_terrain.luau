--!nocheck
-- ============================================================================
-- Last River — LOBBY (Jungle Airfield) base terrain generator      [Job #064]
-- ============================================================================
-- Procedural BASE blockout only. The human hand-sculpts hero detail afterwards
-- (GROUND-RULES §2). Re-runnable: clears its own region + markers first.
-- ALWAYS verify after running: Terrain:ReadVoxels a few columns + screen_capture.
--
-- Design (matches assets/Images/MapIdea.png; applies STYLEGUIDE landmark->path->
-- secondary-area + the "no visible map edges" rule):
--   * Flat, readable SAND clearing (~270 x 236) with the plane/spawn at ~origin.
--   * +X = East/water, -Z = North/runway, +Z = South/entry.
--   * The clearing is a VALLEY: jungle hills rise on all land sides so you can
--     never see the map edge or fall off; distant mountains (snow caps) close
--     every horizon.
--   * East WATER LOBE = the dock bay, bending SE into the river mouth, closed by
--     a far shore + mountains so the water has no visible edge either.
--   * Warm afternoon light + atmospheric haze fade the far distance.
--
-- Zone coordinates (studs) — see markers created at the bottom:
--   SPAWN (0,-35) · PLANE+PILOT (0,0) · PARTY Blue(-30,-22) Red(30,-22)
--   Green(-30,30) Yellow(30,30) · GOLD SHOP (-105,-20) · SMALL SHOP (-105,45)
--   BOAT DOCK (150,5, over water) · WELCOME SIGN (0,120) · RUNWAY (0,-155)
--   WATCHTOWER NW (-95,-120) / NE (90,-120)
-- ============================================================================

local T = workspace.Terrain
local Lighting = game:GetService("Lighting")
local Mat = Enum.Material
local res = 4

local MINX, MAXX = -360, 560
local MINZ, MAXZ = -320, 340
local MINY, MAXY = -48, 140
local WATER_Y = -4

-- readable flat clearing
local cx, cz = -10, 18
local hx, hz = 135, 118
local shoreX = 120

local function riverCenter(x) return 18 + (x - shoreX) * 0.33 end   -- bay bends SE
local function riverHalf(x)  return 100 + (x - shoreX) * 0.10 end    -- and widens

-- surface height (world Y) + isWater flag for a column
local function heightAt(x, z)
	-- flat runway corridor cut north through the hills
	if x >= -20 and x <= 20 and z >= -220 and z <= -95 then return 0, false end

	-- east water lobe (dock bay -> SE river mouth): carve a sloped basin
	if x > shoreX - 6 and x < 480 then
		local half = riverHalf(x)
		local dz = math.abs(z - riverCenter(x))
		if dz < half then
			local edge = (half - dz) / half                 -- 0 bank .. 1 centre
			local basin = -26 + math.noise(x * 0.02, z * 0.02, 1.3) * 5
			return basin * (edge * edge), true              -- banks ~0, centre deep
		end
	end

	-- land bowl: rise with distance beyond the clearing rectangle (all land sides)
	local outX = math.max(0, (cx - hx) - x, x - (cx + hx))
	local outN = math.max(0, (cz - hz) - z)
	local outS = math.max(0, z - (cz + hz))
	local out = math.sqrt(outX * outX + outN * outN + outS * outS)
	if out <= 0 then return 0, false end

	local h
	local ramp = 150
	if out < ramp then
		local t = out / ramp; t = t * t * (3 - 2 * t)       -- smoothstep
		h = t * 58
	else
		h = 58 + (out - ramp) * 0.5                          -- climb to mountains
	end
	h = math.min(h, 132)
	local amp = math.min(out * 0.16, 30)                    -- rougher farther out
	h = h + math.noise(x * 0.012, z * 0.012, 0.7) * amp
	if h < 0 then h = 0 end
	return h, false
end

local function surfaceMat(h, isWater)
	if isWater then return Mat.Sand end
	if h < 2 then return Mat.Sand
	elseif h < 46 then return Mat.Grass
	elseif h < 88 then return Mat.Rock
	else return Mat.Snow end
end

-- 1) clear our working region (idempotent)
T:FillBlock(
	CFrame.new((MINX + MAXX) / 2, (MINY + MAXY) / 2, (MINZ + MAXZ) / 2),
	Vector3.new(MAXX - MINX, MAXY - MINY, MAXZ - MINZ), Mat.Air)

-- 2) generate the heightfield in chunks (WriteVoxels is the official pattern)
local CH = 64
for bx = MINX, MAXX - 1, CH do
	for bz = MINZ, MAXZ - 1, CH do
		local region = Region3.new(
			Vector3.new(bx, MINY, bz),
			Vector3.new(math.min(bx + CH, MAXX), MAXY, math.min(bz + CH, MAXZ))
		):ExpandToGrid(res)
		local rmin = region.CFrame.Position - region.Size / 2
		local nx = math.floor(region.Size.X / res)
		local ny = math.floor(region.Size.Y / res)
		local nz = math.floor(region.Size.Z / res)
		local materials, occ = {}, {}
		for xi = 1, nx do
			materials[xi] = {}; occ[xi] = {}
			for yi = 1, ny do materials[xi][yi] = {}; occ[xi][yi] = {} end
			local wx = rmin.X + (xi - 0.5) * res
			for zi = 1, nz do
				local wz = rmin.Z + (zi - 0.5) * res
				local gTop, isWater = heightAt(wx, wz)
				local gMat = surfaceMat(gTop, isWater)
				for yi = 1, ny do
					local cellBottom = rmin.Y + (yi - 1) * res
					local m, o = Mat.Air, 0
					if cellBottom < gTop then
						m = gMat
						o = math.clamp((gTop - cellBottom) / res, 0, 1)
					elseif isWater and gTop < WATER_Y and cellBottom < WATER_Y then
						m = Mat.Water
						o = math.clamp((WATER_Y - cellBottom) / res, 0, 1)
					end
					materials[xi][yi][zi] = m
					occ[xi][yi][zi] = o
				end
			end
		end
		T:WriteVoxels(region, res, materials, occ)
	end
end

-- 3) zone markers + spawn (editor guide; not the final assets)
local old = workspace:FindFirstChild("LOBBY_BLOCKOUT"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "LOBBY_BLOCKOUT"; folder.Parent = workspace
local function marker(name, pos, rgb, size)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide = name, true, false
	p.Size = size or Vector3.new(8, 1, 8); p.Position = pos
	p.Color, p.Material, p.Transparency = rgb, Enum.Material.SmoothPlastic, 0.1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 190, 0, 42); bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true; bb.Parent = p
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0); tl.BorderSizePixel = 0
	tl.BackgroundColor3 = Color3.fromRGB(36, 53, 45); tl.BackgroundTransparency = 0.1
	tl.TextColor3 = Color3.fromRGB(243, 230, 194); tl.TextScaled = true
	tl.Font = Enum.Font.BuilderSansBold; tl.Text = name; tl.Parent = bb
	local uic = Instance.new("UICorner"); uic.CornerRadius = UDim.new(0, 8); uic.Parent = tl
	p.Parent = folder; return p
end
local GOLD = Color3.fromRGB(214,155,34); local BLUE = Color3.fromRGB(53,107,154)
local GREEN = Color3.fromRGB(75,122,43); local RED = Color3.fromRGB(168,75,60)
local YELLOW = Color3.fromRGB(213,161,43); local OLIVE = Color3.fromRGB(89,97,59)
local WOOD = Color3.fromRGB(128,97,66); local METAL = Color3.fromRGB(78,82,70)
local DOLIVE = Color3.fromRGB(63,73,48); local pad = Vector3.new(14,1,14)
marker("SPAWN", Vector3.new(0,1,-35), GOLD, Vector3.new(12,1,12))
marker("PLANE + PILOT", Vector3.new(0,0.6,0), OLIVE, Vector3.new(16,1,16))
marker("PARTY BLUE", Vector3.new(-30,0.6,-22), BLUE, pad)
marker("PARTY RED", Vector3.new(30,0.6,-22), RED, pad)
marker("PARTY GREEN", Vector3.new(-30,0.6,30), GREEN, pad)
marker("PARTY YELLOW", Vector3.new(30,0.6,30), YELLOW, pad)
marker("GOLD SKILL SHOP", Vector3.new(-105,0.6,-20), GOLD, Vector3.new(14,1,12))
marker("SMALL SKILL SHOP", Vector3.new(-105,0.6,45), BLUE, Vector3.new(14,1,12))
marker("BOAT DOCK + BOAT", Vector3.new(150,1,5), GREEN, Vector3.new(14,1,10))
marker("WELCOME SIGN", Vector3.new(0,0.6,120), WOOD, Vector3.new(12,1,6))
marker("RUNWAY 27", Vector3.new(0,0.6,-155), METAL, Vector3.new(30,1,20))
marker("WATCHTOWER NW", Vector3.new(-95,0.6,-120), DOLIVE)
marker("WATCHTOWER NE", Vector3.new(90,0.6,-120), DOLIVE)
local sp = Instance.new("SpawnLocation")
sp.Name, sp.Anchored, sp.Neutral = "LobbySpawn", true, true
sp.Size = Vector3.new(12,1,12); sp.Position = Vector3.new(0,0.5,-35)
sp.Color = GOLD; sp.Material = Enum.Material.SmoothPlastic; sp.Transparency = 0.4
sp.Parent = folder

-- 4) warm afternoon light + haze (STYLEGUIDE §8) — fades the far horizon
Lighting.Technology = Enum.Technology.Future
Lighting.ClockTime = 15.5
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(120,112,92)
Lighting.EnvironmentDiffuseScale = 0.4
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.36; atm.Offset = 0.1; atm.Glare = 0.25; atm.Haze = 2.6
atm.Color = Color3.fromRGB(199,172,120); atm.Decay = Color3.fromRGB(106,112,80)
atm.Parent = Lighting

return "lobby base terrain generated"
