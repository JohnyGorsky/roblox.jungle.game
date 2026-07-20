--!nocheck
-- ============================================================================
-- Last River — LOBBY (Jungle Airfield) base terrain generator      [Job #064]
-- ============================================================================
-- Procedural BASE blockout only; human hand-sculpts hero detail after
-- (GROUND-RULES §2). Re-runnable: clears its own region first. ALWAYS verify:
-- Terrain:ReadVoxels a few columns + screen_capture.
--
-- v2 (2026-07-20): CONTINUOUS height field — no hard walls. The water sits in a
-- river VALLEY with sloped beaches; the runway is a graded, tapered strip that
-- ramps gently into the hills. Clearing stays flat & readable. Bowl of hills +
-- distant snow mountains + warm haze enclose every horizon (no visible edge).
--
-- +X = East/water, -Z = North/runway, +Z = South/entry. Clearing top y=0,
-- water surface ~y-4. Zone coords: see markers created at the bottom.
-- ============================================================================

local T = workspace.Terrain
local Lighting = game:GetService("Lighting")
local Mat = Enum.Material
local res = 4

local MINX, MAXX = -380, 600
local MINZ, MAXZ = -600, 360   -- extended north so a long runway stays enclosed by hills
local MINY, MAXY = -48, 140
local WATER_Y = -4
local BASIN   = -20

local cx, cz = -10, 18       -- clearing centre
local hx, hz = 135, 118      -- clearing half-extents
local shoreX = 120           -- east shore x

local function smooth(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end

-- distance beyond the clearing rectangle (0 inside)
local function rectOut(x, z)
	local ox = math.max(0, (cx - hx) - x, x - (cx + hx))
	local oz = math.max(0, (cz - hz) - z, z - (cz + hz))
	return math.sqrt(ox * ox + oz * oz)
end

-- gentle land profile: flat apron -> rolling hills -> distant mountains
local function landProfile(out)
	if out <= 30 then return 0 end
	local o = out - 30
	if o < 200 then return smooth(o / 200) * 52 end
	return math.min(52 + (o - 200) * 0.42, 130)
end

-- river corridor (bends SE and widens)
local function riverCenterZ(x) return 18 + (x - shoreX) * 0.42 end
local function riverHalf(x)    return 70 + (x - shoreX) * 0.06 end   -- water half-width

-- valley influence 0..1: 1 in the corridor (keep land low), fading out laterally
-- and at the shore start / far end so nothing ends in a wall
local function riverValley(x, z)
	if x < shoreX - 30 then return 0 end
	local half = riverHalf(x)
	local dz = math.abs(z - riverCenterZ(x))
	local vwidth = half + 120
	if dz >= vwidth then return 0 end
	local along = smooth((x - (shoreX - 30)) / 55)
	local farStart, farEnd = 470, 585
	if x > farStart then along = along * smooth((farEnd - x) / (farEnd - farStart)) end
	local lateral = smooth((vwidth - dz) / vwidth)
	return along * lateral
end

-- runway influence 0..1: flat strip with graded sides + tapered ends
-- runway spans z0..z1 (length ~390, matched to the water lobe)
local function runwayInfluence(x, z)
	local z0, z1 = -490, -100
	if z < z0 - 60 or z > z1 + 60 then return 0 end
	local dx = math.abs(x) - 18
	local lat = dx <= 0 and 1 or smooth(1 - dx / 60)
	local lon = 1
	if z < z0 then lon = smooth(1 - (z0 - z) / 55)
	elseif z > z1 then lon = smooth(1 - (z - z1) / 55) end
	return lat * lon
end

-- surface height (world Y) + isWater
local function heightAt(x, z)
	local out = rectOut(x, z)
	local land = landProfile(out)
	local amp = math.min(out * 0.14, 26)
	land = land + math.noise(x * 0.011, z * 0.011, 0.7) * amp
	if land < 0 then land = 0 end

	-- river valley (east): pull land down toward a channel/beach, blended
	local rv = riverValley(x, z)
	if rv > 0 then
		local half = riverHalf(x)
		local dz = math.abs(z - riverCenterZ(x))
		local target
		if dz < half then
			local e = smooth((half - dz) / half)         -- 1 centre .. 0 bank
			target = BASIN * e + 1 * (1 - e)             -- deep centre, ~1 at water edge
		else
			target = 2 + (dz - half) * 0.22               -- gentle beach/bank
		end
		local g = land * (1 - rv) + math.min(target, land) * rv
		return g, (dz < half and g < WATER_Y)
	end

	-- runway: flatten toward 0, blended into the hills
	local rwy = runwayInfluence(x, z)
	if rwy > 0 then land = land * (1 - rwy) end
	return land, false
end

local function surfaceMat(g, isWater)
	if isWater then return Mat.Sand end
	if g < 2.5 then return Mat.Sand
	elseif g < 44 then return Mat.Grass
	elseif g < 86 then return Mat.Rock
	else return Mat.Snow end
end

-- 1) clear our working region
T:FillBlock(CFrame.new((MINX + MAXX) / 2, (MINY + MAXY) / 2, (MINZ + MAXZ) / 2),
	Vector3.new(MAXX - MINX, MAXY - MINY, MAXZ - MINZ), Mat.Air)

-- 2) generate heightfield in chunks
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
						m = gMat; o = math.clamp((gTop - cellBottom) / res, 0, 1)
					elseif isWater and gTop < WATER_Y and cellBottom < WATER_Y then
						m = Mat.Water; o = math.clamp((WATER_Y - cellBottom) / res, 0, 1)
					end
					materials[xi][yi][zi] = m; occ[xi][yi][zi] = o
				end
			end
		end
		T:WriteVoxels(region, res, materials, occ)
	end
end

-- 3) water look
T.WaterColor = Color3.fromRGB(36, 119, 134)
T.WaterTransparency = 0.55
T.WaterReflectance = 0.12
T.WaterWaveSize = 0.08
T.WaterWaveSpeed = 8

-- 4) zone markers + spawn (editor guide; replaced by real assets later)
local old = workspace:FindFirstChild("LOBBY_BLOCKOUT"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "LOBBY_BLOCKOUT"; folder.Parent = workspace
local function marker(name, pos, rgb, size)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide = name, true, false
	p.Size = size or Vector3.new(8, 1, 8); p.Position = pos
	p.Color, p.Material, p.Transparency = rgb, Enum.Material.SmoothPlastic, 0.1
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 190, 0, 42)
	bb.StudsOffset = Vector3.new(0, 5, 0); bb.AlwaysOnTop = true; bb.Parent = p
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.new(1, 0, 1, 0); tl.BorderSizePixel = 0
	tl.BackgroundColor3 = Color3.fromRGB(36, 53, 45); tl.BackgroundTransparency = 0.1
	tl.TextColor3 = Color3.fromRGB(243, 230, 194); tl.TextScaled = true
	tl.Font = Enum.Font.BuilderSansBold; tl.Text = name; tl.Parent = bb
	local uic = Instance.new("UICorner"); uic.CornerRadius = UDim.new(0, 8); uic.Parent = tl
	p.Parent = folder; return p
end
local GOLD=Color3.fromRGB(214,155,34); local BLUE=Color3.fromRGB(53,107,154)
local GREEN=Color3.fromRGB(75,122,43); local RED=Color3.fromRGB(168,75,60)
local YELLOW=Color3.fromRGB(213,161,43); local OLIVE=Color3.fromRGB(89,97,59)
local WOOD=Color3.fromRGB(128,97,66); local METAL=Color3.fromRGB(78,82,70)
local DOLIVE=Color3.fromRGB(63,73,48); local pad=Vector3.new(14,1,14)
marker("SPAWN",Vector3.new(0,1,-35),GOLD,Vector3.new(12,1,12))
marker("PLANE + PILOT",Vector3.new(0,0.6,0),OLIVE,Vector3.new(16,1,16))
marker("PARTY BLUE",Vector3.new(-30,0.6,-22),BLUE,pad)
marker("PARTY RED",Vector3.new(30,0.6,-22),RED,pad)
marker("PARTY GREEN",Vector3.new(-30,0.6,30),GREEN,pad)
marker("PARTY YELLOW",Vector3.new(30,0.6,30),YELLOW,pad)
marker("GOLD SKILL SHOP",Vector3.new(-105,0.6,-20),GOLD,Vector3.new(14,1,12))
marker("SMALL SKILL SHOP",Vector3.new(-105,0.6,45),BLUE,Vector3.new(14,1,12))
marker("BOAT DOCK + BOAT",Vector3.new(150,1,5),GREEN,Vector3.new(14,1,10))
marker("WELCOME SIGN",Vector3.new(0,0.6,120),WOOD,Vector3.new(12,1,6))
marker("RUNWAY 27",Vector3.new(0,0.6,-295),METAL,Vector3.new(36,1,60))
marker("WATCHTOWER NW",Vector3.new(-95,0.6,-120),DOLIVE)
marker("WATCHTOWER NE",Vector3.new(90,0.6,-120),DOLIVE)
local sp = Instance.new("SpawnLocation")
sp.Name, sp.Anchored, sp.Neutral = "LobbySpawn", true, true
sp.Size = Vector3.new(12,1,12); sp.Position = Vector3.new(0,0.5,-35)
sp.Color = GOLD; sp.Material = Enum.Material.SmoothPlastic; sp.Transparency = 0.4; sp.Parent = folder

-- 5) warm afternoon light + haze (STYLEGUIDE §8). NOTE: set
-- Lighting.Technology = Enum.Technology.Future manually in Studio (blocked via MCP).
Lighting.ClockTime = 15.5
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(120,112,92)
Lighting.EnvironmentDiffuseScale = 0.4
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.36; atm.Offset = 0.1; atm.Glare = 0.25; atm.Haze = 2.6
atm.Color = Color3.fromRGB(199,172,120); atm.Decay = Color3.fromRGB(106,112,80)
atm.Parent = Lighting

return "lobby base terrain v2 generated"
