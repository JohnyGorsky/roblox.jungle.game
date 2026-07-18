--!strict
-- RiverData.luau — single source of truth for the river's SHAPE (Job 005).
--
-- Pure, deterministic math from a seed. No terrain writes, no side effects. BOTH the RiverGenerator
-- (which materializes voxels) and BoatServer (which drives on it) read from here, so they can never
-- desync. The river runs along +Z from Z_START; "distance" downstream = z - Z_START.
--
-- Continuity: centerline/width are continuous functions of z (layered Perlin via math.noise), so
-- chunk boundaries line up automatically — no seams to stitch.

local RiverData = {}

-- ── config (tunable) ───────────────────────────────────────────────────────
RiverData.WATER_Y = 12            -- target water surface height
RiverData.Z_START = 0             -- world Z of the river's upstream start
RiverData.END_DISTANCE = 18000    -- campaign finish distance (studs) ≈ a long ~15–25 min run
RiverData.ENDLESS = false         -- true = no end (P10 endless mode)
RiverData.HOOK_SPACING = 220      -- avg studs between obstacle/ramp placement hooks
RiverData.DOCK_SPACING = 2200     -- studs between refuel docks

export type Hook = { z: number, x: number, kind: string } -- kind = "obstacle" | "ramp"
export type Dock = { z: number, x: number, side: number, landing: boolean } -- landing = opens a big jungle zone

-- meander: centerlineX(z) = A1·noise(z·F1) + A2·noise(z·F2). Big slow bends + smaller wiggles.
-- (noise ≈ ±0.5, so ×2 to use its full range; amplitudes are ~studs of side-to-side.)
local A1, F1 = 300, 1 / 1600
local A2, F2 = 75, 1 / 620
-- width: WIDE by design (obstacles/ramps live IN the channel). Gentle variation, never tight — any
-- real pinch-points come later as placed obstacles, not a skinny river.
local W_BASE, W_VAR, F_W = 209, 50, 1 / 700
local W_FLOOR, W_CEIL = 154, 264
-- ───────────────────────────────────────────────────────────────────────────

-- The seed is stored in a replicated Workspace attribute — NOT mutable module state — so it stays
-- consistent across server/client and survives a module reload (e.g. Studio live-sync mid-play).
-- Offsets are cached and re-derived only when the attribute changes.
local DEFAULT_SEED = 2026
local Workspace = game:GetService("Workspace")

local cachedSeed: number? = nil
local offX1, offX2, offW = 0, 0, 0

local function ensureSeed()
	local s = Workspace:GetAttribute("RiverSeed")
	if typeof(s) ~= "number" then
		s = DEFAULT_SEED
	end
	if s ~= cachedSeed then
		cachedSeed = s :: number
		local r = Random.new(s :: number)
		offX1 = r:NextNumber(1, 5000)
		offX2 = r:NextNumber(1, 5000)
		offW = r:NextNumber(1, 5000)
	end
end

-- server-only (clients read the replicated attribute); sets the seed for the whole run
function RiverData.setSeed(newSeed: number)
	Workspace:SetAttribute("RiverSeed", newSeed)
	ensureSeed()
end

function RiverData.getSeed(): number
	ensureSeed()
	return cachedSeed :: number
end

-- world-space X of the channel center at downstream position z
function RiverData.centerlineX(z: number): number
	ensureSeed()
	return A1 * (math.noise(z * F1 + offX1) * 2) + A2 * (math.noise(z * F2 + offX2) * 2)
end

-- channel width (bank to bank) at z — wide, with gentle variation; clamped so it never gets tight
function RiverData.widthAt(z: number): number
	ensureSeed()
	local n = math.noise(z * F_W + offW) * 2 -- ~[-1, 1]
	return math.clamp(W_BASE + W_VAR * n, W_FLOOR, W_CEIL)
end

-- world position of the channel center at z (at the water surface)
function RiverData.positionAt(z: number): Vector3
	return Vector3.new(RiverData.centerlineX(z), RiverData.WATER_Y, z)
end

-- unit downstream tangent at z (finite-difference of the centerline)
function RiverData.tangentAtZ(z: number): Vector3
	local dx = RiverData.centerlineX(z + 1) - RiverData.centerlineX(z - 1)
	return Vector3.new(dx * 0.5, 0, 1).Unit
end

-- Deterministic obstacle/ramp placement hooks with z in [z0, z1] (inclusive). Data only — the actual
-- rock/log/ramp props are placed on these later. Obstacles sit off-centre (steer around them); ramps
-- sit near the centre (line up and jump).
function RiverData.hooksBetween(z0: number, z1: number): { Hook }
	ensureSeed()
	local hooks: { Hook } = {}
	local spacing = RiverData.HOOK_SPACING
	local endZ = RiverData.Z_START + RiverData.END_DISTANCE
	local first = math.ceil((z0 - RiverData.Z_START) / spacing)
	local last = math.floor((z1 - RiverData.Z_START) / spacing)
	for i = first, last do
		local z = RiverData.Z_START + i * spacing
		if z >= RiverData.Z_START and (RiverData.ENDLESS or z <= endZ) then
			-- favour obstacles (dodge, common) over ramps (jump, special) ~2:1
			local kind = if math.noise(z * 0.05 + offW, 12.3) > -0.15 then "obstacle" else "ramp"
			local x = RiverData.centerlineX(z)
			if kind == "obstacle" then
				local side = if math.noise(z * 0.07 + offX1, 4.2) >= 0 then 1 else -1
				x += side * RiverData.widthAt(z) * 0.5 * 0.35 -- ~35% toward one bank; pass on the other side
			end
			hooks[#hooks + 1] = { z = z, x = x, kind = kind }
		end
	end
	return hooks
end

-- Deterministic refuel dock positions (on a bank) with z in [z0, z1]. Seeded → same docks every run.
function RiverData.docksBetween(z0: number, z1: number): { Dock }
	ensureSeed()
	local docks: { Dock } = {}
	local spacing = RiverData.DOCK_SPACING
	local endZ = RiverData.Z_START + RiverData.END_DISTANCE
	local first = math.max(1, math.ceil((z0 - RiverData.Z_START) / spacing)) -- no dock at the very start
	local last = math.floor((z1 - RiverData.Z_START) / spacing)
	for i = first, last do
		local z = RiverData.Z_START + i * spacing
		if RiverData.ENDLESS or z <= endZ then
			local side = if math.noise(z * 0.013 + offW, 7.7) >= 0 then 1 else -1
			local x = RiverData.centerlineX(z) + side * (RiverData.widthAt(z) * 0.5 - 4) -- at the water's edge
			-- only SOME docks are landing sites (open a big jungle zone); others are quick refuel/tie stops
			local landing = (i % 2) == 1
			docks[#docks + 1] = { z = z, x = x, side = side, landing = landing }
		end
	end
	return docks
end

function RiverData.worldToDistance(z: number): number
	return z - RiverData.Z_START
end

function RiverData.distanceToWorldZ(distance: number): number
	return RiverData.Z_START + distance
end

-- true once past the campaign finish (unless endless)
function RiverData.isPastEnd(z: number): boolean
	return not RiverData.ENDLESS and (z - RiverData.Z_START) >= RiverData.END_DISTANCE
end

return RiverData
