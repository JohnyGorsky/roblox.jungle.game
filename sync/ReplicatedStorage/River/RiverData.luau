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
RiverData.DOCK_SPACING = 1600     -- studs between docks; landings (gasoline) every 2× that (Job 054 pacing)

export type Hook = { z: number, x: number, kind: string } -- kind = "obstacle" | "ramp"
export type Dock = { z: number, x: number, side: number, landing: boolean } -- landing = opens a big jungle zone

-- meander: layered Perlin octaves (noise ≈ ±0.5, ×2 for full range; amplitudes ~studs side-to-side). The big
-- slow course bend (A1) is always on; the medium (A2) + fine (A3) octaves are scaled by the zone "turniness"
-- (ZONE_PROFILE.turn) so some stretches snake sharply (Rapids) and others stay lazy (Headwaters). The 3rd
-- octave breaks up the old two-octave "straight & predictable" feel.
local A1, F1 = 300, 1 / 1600 -- big slow course bends (always on)
local A2, F2 = 105, 1 / 620 -- medium bends — the main "turns" (× turniness)
local A3, F3 = 26, 1 / 360 -- fine detail wiggle (× turniness); kept broad so narrow zones don't hairpin
-- width: a per-zone BASE (see ZONE_PROFILE) + gentle noise variation, clamped to a drivable span. The boat
-- beam is 14, so even the tight ~95-wide Rapids leaves plenty of clearance; the Delta opens to ~300.
local W_VAR, F_W = 22, 1 / 700
local W_FLOOR, W_CEIL = 80, 330
-- obstacle hooks: a dense candidate grid, thinned per zone by ZONE_PROFILE.obs (density).
local HOOK_BASE = 120
-- forks: the channel splits into two branches around an island, then merges. Only in WIDE zones so a branch
-- never gets too tight; separation ramps 0→max→0 across the fork (smooth split/merge).
local FORK_SPACING = 1500 -- avg studs between fork candidates
local FORK_LEN = 520 -- length of one fork (split → island → merge)
local FORK_MAX_OFFSET = 130 -- peak branch-center offset from the island center
local FORK_BRANCH_FRAC = 0.62 -- each branch's width as a fraction of widthAt
local FORK_MIN_WIDTH = 220 -- only fork where the base channel is at least this wide (≈ Delta)
-- ───────────────────────────────────────────────────────────────────────────

-- Per-zone river CHARACTER, keyed at each zone's CENTER as a fraction of END_DISTANCE and linearly
-- interpolated between anchors → a continuous function of z (chunk-seamless, aligned to ZoneServer's 4
-- zones). width in studs · turn = meander multiplier · obs = obstacle-density multiplier (1.0 ≈ old spacing)
-- · currentMul = downstream-flow multiplier (data now; wired into BoatServer in overhaul job #2).
local ZONE_PROFILE = {
	{ f = 0.000, width = 150, turn = 0.65, obs = 0.55, currentMul = 1.0 }, -- Headwaters (start)
	{ f = 0.125, width = 150, turn = 0.70, obs = 0.60, currentMul = 1.0 }, -- Headwaters
	{ f = 0.375, width = 210, turn = 1.00, obs = 1.00, currentMul = 1.0 }, -- Croc Country
	{ f = 0.625, width = 110, turn = 1.35, obs = 1.90, currentMul = 1.5 }, -- The Rapids (tight, twisty, dense, fast)
	{ f = 0.875, width = 300, turn = 0.85, obs = 1.00, currentMul = 0.8 }, -- Lost Delta (wide)
	{ f = 1.000, width = 300, turn = 0.85, obs = 1.00, currentMul = 0.8 }, -- finish
}

export type Profile = { width: number, turn: number, obs: number, currentMul: number }

-- interpolated zone character at downstream position z
function RiverData.profileAt(z: number): Profile
	local span = RiverData.END_DISTANCE
	local f = if span > 0 then math.clamp((z - RiverData.Z_START) / span, 0, 1) else 0
	for i = 1, #ZONE_PROFILE - 1 do
		local lo, hi = ZONE_PROFILE[i], ZONE_PROFILE[i + 1]
		if f >= lo.f and f <= hi.f then
			local span2 = hi.f - lo.f
			local t = if span2 > 0 then (f - lo.f) / span2 else 0
			return {
				width = lo.width + (hi.width - lo.width) * t,
				turn = lo.turn + (hi.turn - lo.turn) * t,
				obs = lo.obs + (hi.obs - lo.obs) * t,
				currentMul = lo.currentMul + (hi.currentMul - lo.currentMul) * t,
			}
		end
	end
	local last = ZONE_PROFILE[#ZONE_PROFILE]
	return { width = last.width, turn = last.turn, obs = last.obs, currentMul = last.currentMul }
end

-- downstream-flow multiplier at z (per-zone current; consumed by BoatServer in overhaul job #2)
function RiverData.currentMulAt(z: number): number
	return RiverData.profileAt(z).currentMul
end

-- The seed is stored in a replicated Workspace attribute — NOT mutable module state — so it stays
-- consistent across server/client and survives a module reload (e.g. Studio live-sync mid-play).
-- Offsets are cached and re-derived only when the attribute changes.
local DEFAULT_SEED = 2026
local Workspace = game:GetService("Workspace")

local cachedSeed: number? = nil
local offX1, offX2, offX3, offW = 0, 0, 0, 0

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
		offX3 = r:NextNumber(1, 5000)
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

-- world-space X of the channel center at downstream position z (big course bend + turniness-scaled wiggles)
function RiverData.centerlineX(z: number): number
	ensureSeed()
	local turn = RiverData.profileAt(z).turn
	local base = A1 * (math.noise(z * F1 + offX1) * 2)
	local mid = A2 * (math.noise(z * F2 + offX2) * 2) * turn
	local fine = A3 * (math.noise(z * F3 + offX3) * 2) * turn
	return base + mid + fine
end

-- channel width (bank to bank) at z — per-zone base + gentle variation, clamped to a drivable span
function RiverData.widthAt(z: number): number
	ensureSeed()
	local n = math.noise(z * F_W + offW) * 2 -- ~[-1, 1]
	return math.clamp(RiverData.profileAt(z).width + W_VAR * n, W_FLOOR, W_CEIL)
end

-- ── forks (braided channel around an island) ─────────────────────────────────
-- smooth 0→1→0 bump over u in [0,1]
local function forkBump(u: number): number
	if u <= 0 or u >= 1 then
		return 0
	end
	local s = math.sin(u * math.pi) -- 0 at ends, 1 at u=0.5
	return s * s -- flatter top / gentler split+merge
end

-- branch-center offset (studs from the island center to each branch) at z; 0 = single channel (no fork)
function RiverData.forkOffsetAt(z: number): number
	ensureSeed()
	if RiverData.widthAt(z) < FORK_MIN_WIDTH then
		return 0 -- never fork a narrow channel
	end
	-- nearest fork candidate on the seeded grid
	local i = math.floor((z - RiverData.Z_START) / FORK_SPACING + 0.5)
	local zc = RiverData.Z_START + i * FORK_SPACING
	if zc <= RiverData.Z_START then
		return 0
	end
	-- only ~some candidates actually fork (deterministic)
	if (math.noise(zc * 0.001 + offW, 5.5) * 0.5 + 0.5) > 0.6 then
		return 0
	end
	if math.abs(z - zc) > FORK_LEN * 0.5 then
		return 0
	end
	local u = (z - (zc - FORK_LEN * 0.5)) / FORK_LEN -- 0..1 across the fork
	return FORK_MAX_OFFSET * forkBump(u)
end

export type Branch = { c: number, halfW: number }

-- the channel(s) at z: one normally, two (left/right around an island) inside a fork
function RiverData.branchesAt(z: number): { Branch }
	local c = RiverData.centerlineX(z)
	local off = RiverData.forkOffsetAt(z)
	if off <= 0 then
		return { { c = c, halfW = RiverData.widthAt(z) * 0.5 } }
	end
	local bh = RiverData.widthAt(z) * 0.5 * FORK_BRANCH_FRAC
	return { { c = c - off, halfW = bh }, { c = c + off, halfW = bh } }
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
	local spacing = HOOK_BASE -- dense candidate grid; per-zone density thins it below
	local endZ = RiverData.Z_START + RiverData.END_DISTANCE
	local first = math.ceil((z0 - RiverData.Z_START) / spacing)
	local last = math.floor((z1 - RiverData.Z_START) / spacing)
	for i = first, last do
		local z = RiverData.Z_START + i * spacing
		if z >= RiverData.Z_START and (RiverData.ENDLESS or z <= endZ) then
			-- per-zone density: keep this candidate with a deterministic probability (obs 1.0 ≈ old ~220 spacing)
			local keep = math.clamp(0.55 * RiverData.profileAt(z).obs, 0, 1)
			local roll = math.noise(z * 0.017 + offW, 31.7) * 0.5 + 0.5 -- deterministic [0, 1]
			-- no obstacles inside a fork (keep the braided island stretch clean)
			if roll <= keep and RiverData.forkOffsetAt(z) <= 0 then
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
		-- no dock inside a fork (its "bank" would land on the island); skip to the next candidate
		if (RiverData.ENDLESS or z <= endZ) and RiverData.forkOffsetAt(z) <= 0 then
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
