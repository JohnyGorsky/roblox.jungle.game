--!strict
-- VillageLayout.luau — the OUTLYING HUTS of a landing site (Job #108).
--
-- ── Why this exists ───────────────────────────────────────────────────────────────────────────────
-- Reported: *"right now each camp still feels empty… position Kubo1 and Kubo2 randomly… that way we
-- will have more crowded and enterable buildings."*
--
-- A landing basin is **400 studs across** and contained exactly two camps of radius 70–76. Job #100
-- already made the inside of a camp bigger and less repetitive, but that only ever addressed two
-- ~150-stud pockets: everything between and around them — most of the ground the player actually walks
-- over — was bare jungle floor with 22 scattered ferns on it. So a stop read as "two clearings and a
-- long walk", not as a place people live.
--
-- This module scatters 6–10 outlying huts across the REST of the basin. `CampLayout` owns the inside of
-- a camp; this owns the space between them. They share `CampDefs.FOOTPRINT`/`CampDefs.halfDiagonal`,
-- which is not optional — two placers with different ideas of how big a hut is will put one through the
-- other at the camp fence.
--
-- ── What it is NOT allowed to do ──────────────────────────────────────────────────────────────────
--   · stand inside a camp fence, on the walking lane, on the trading post, or on the shore,
--   · stand in the clearing ring, whose trees are 24–46 studs in from the basin edge,
--   · overlap another hut (checked against the SUM of both half-diagonals — see `CampLayout`'s header
--     for what a discount on that number did to the camp buildings),
--   · stand on ground that is not flat across ITS OWN FOOTPRINT. The basin carve leaves ~2.5% of
--     columns as stumps of the original hillside, and one centre raycast cannot see a stump under the
--     far corner of a 30-stud building.
--
-- ── Doors are the point, not decoration ───────────────────────────────────────────────────────────
-- Every Bahay Kubo in the library is a stilt house with ONE walk-through doorway and a floor 3.5–4.6
-- studs up (measured; see `CampDefs.VILLAGE.door`). A random yaw therefore has a real chance of aiming
-- the only entrance at the jungle wall, and an un-enterable "enterable building" is the whole job
-- failing quietly. So yaw is chosen from the DOOR outward: the door is aimed at the walking route and
-- then jittered ±70°, which keeps the scattered, randomly-turned look while guaranteeing the way in
-- faces the way the player comes.
--
-- Deterministic from the site seed, like everything else here, so a reported layout can be regenerated.

local CampDefs = require(script.Parent:WaitForChild("CampDefs"))

local VillageLayout = {}

export type Hut = {
	x: number,
	z: number,
	model: string,
	yaw: number, -- world yaw, ready for `prop()`
	doorDir: Vector3, -- unit XZ direction the doorway faces, in world space
	rise: number, -- interior floor height above the model's base
	halfDiag: number,
}

export type Camp = { pos: Vector3, radius: number }

export type Options = {
	seed: number,
	basinCenterX: number,
	basinZ: number,
	basinSize: number,
	waterEdge: number,
	side: number, -- +1 / -1, the inland direction from the water
	camps: { Camp },
	pathAx: number,
	pathAz: number,
	pathBx: number,
	pathBz: number,
	pathHalf: number,
	postPos: Vector3,
	-- RAW downward terrain probe: the FIRST terrain surface at (x, z), or nil if there is none.
	--
	-- ⚠️ It must be raw. `ExcursionServer.groundAt` deliberately REJECTS stump hits and answers with the
	-- floor around them, which is right for seating a prop and exactly wrong here — a flatness test fed
	-- a stump-hiding probe reports every slot as flat and the check does nothing.
	rawGround: (x: number, z: number) -> number?,
}

local function distToSeg(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Nearest point on the walking lane — what a hut's door is aimed at.
local function nearestOnPath(px: number, pz: number, o: Options): (number, number)
	local dx, dz = o.pathBx - o.pathAx, o.pathBz - o.pathAz
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - o.pathAx) * dx + (pz - o.pathAz) * dz) / len2, 0, 1) else 0
	return o.pathAx + dx * t, o.pathAz + dz * t
end

local function pickModel(rng: Random): string
	local entries = CampDefs.VILLAGE.entries
	local total = 0
	for _, e in ipairs(entries) do
		total += e.weight
	end
	local r = rng:NextNumber(0, total)
	for _, e in ipairs(entries) do
		r -= e.weight
		if r <= 0 then
			return e.model
		end
	end
	return entries[1].model
end

-- Is the ground under this footprint flat enough to stand a building on?
--
-- Samples the centre and a ring at the model's own half-diagonal — the footprint, not the point. A
-- missing sample (no terrain at all) fails outright; so does a spread larger than
-- `VILLAGE.maxGroundSpread`, which is what a leftover stump or the lip of the rock wall looks like.
local function groundIsFlat(x: number, z: number, halfDiag: number, o: Options): boolean
	local V = CampDefs.VILLAGE
	local lo, hi = math.huge, -math.huge
	local centre = o.rawGround(x, z)
	if not centre then
		return false
	end
	lo, hi = centre, centre
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local g = o.rawGround(x + math.cos(a) * halfDiag, z + math.sin(a) * halfDiag)
		if not g then
			return false
		end
		lo, hi = math.min(lo, g), math.max(hi, g)
	end
	return (hi - lo) <= V.maxGroundSpread
end

--- Generate the outlying huts for one landing site. Returns fewer than `countMin` only when the basin
--- genuinely has no room left — the caller is expected to log that rather than let it read as "the
--- scatter is sparse today".
function VillageLayout.generate(o: Options): { Hut }
	local V = CampDefs.VILLAGE
	local rng = Random.new(o.seed)
	local half = o.basinSize / 2
	local reach = half - V.edgeInset -- how far from the basin centre a hut CENTRE may sit

	local want = rng:NextInteger(V.countMin, V.countMax)
	local huts: { Hut } = {}

	for _ = 1, want do
		local model = pickModel(rng)
		local halfDiag = CampDefs.halfDiagonal(model)

		-- Bounded attempts: a slot that cannot be found is one missing hut, never a hang. 90 rather than
		-- the usual 20–40 because the free area here is a ring around two large exclusion discs, so a
		-- uniform sample inside the box lands in a camp a good third of the time.
		for _ = 1, 90 do
			local x = o.basinCenterX + rng:NextNumber(-reach, reach)
			local z = o.basinZ + rng:NextNumber(-reach, reach)

			-- off the water (and therefore off the dock and the bank paint)
			if (x - o.waterEdge) * o.side < V.shoreClear + halfDiag then
				continue
			end
			-- clear of every camp FENCE, not of the camp centre
			local inCamp = false
			for _, c in ipairs(o.camps) do
				local need = c.radius + halfDiag + V.campMargin
				if (Vector3.new(x, 0, z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude < need then
					inCamp = true
					break
				end
			end
			if inCamp then
				continue
			end
			-- off the walking lane
			if distToSeg(x, z, o.pathAx, o.pathAz, o.pathBx, o.pathBz) < o.pathHalf + halfDiag + V.pathMargin then
				continue
			end
			-- clear of the trading post
			if (Vector3.new(x, 0, z) - Vector3.new(o.postPos.X, 0, o.postPos.Z)).Magnitude < V.postClear + halfDiag then
				continue
			end
			-- clear of every hut already placed, by the SUM of the two half-diagonals
			local hitsHut = false
			for _, h in ipairs(huts) do
				local need = halfDiag + h.halfDiag + V.hutMargin
				if (x - h.x) ^ 2 + (z - h.z) ^ 2 < need * need then
					hitsHut = true
					break
				end
			end
			if hitsHut then
				continue
			end
			-- and finally the expensive test: is the ground under the whole footprint flat?
			if not groundIsFlat(x, z, halfDiag, o) then
				continue
			end

			-- ── aim the door ─────────────────────────────────────────────────────────────────────
			-- `prop` places with `CFrame.Angles(0, yaw, 0)`, under which a model-local bearing `b`
			-- (0° = +X, 90° = +Z) lands at world bearing `b - yaw`. So to put the door on a chosen world
			-- bearing D, yaw = b - D. Anything else here is guesswork about which way a mesh faces.
			local d = CampDefs.VILLAGE.door[model] or { bearing = 0, rise = 0 }
			local px, pz = nearestOnPath(x, z, o)
			local toPath = math.atan2(pz - z, px - x)
			local wantBearing = toPath + math.rad(rng:NextNumber(-70, 70))
			local yaw = math.rad(d.bearing) - wantBearing

			table.insert(huts, {
				x = x,
				z = z,
				model = model,
				yaw = yaw,
				doorDir = Vector3.new(math.cos(wantBearing), 0, math.sin(wantBearing)),
				rise = d.rise,
				halfDiag = halfDiag,
			})
			break
		end
		-- A hut that found no slot is simply absent. Not warned per-hut: the caller logs
		-- placed-vs-wanted once per site, which is the number that actually says whether the basin has
		-- run out of room.
	end

	return huts
end

--- Would a tree at (x, z) stand inside one of these huts? Used by the interior scatter, which runs
--- BEFORE the huts are built and would otherwise plant a palm through a roof.
function VillageLayout.blocked(huts: { Hut }, x: number, z: number): boolean
	local clear = CampDefs.VILLAGE.treeClear
	for _, h in ipairs(huts) do
		local need = h.halfDiag + clear
		if (x - h.x) ^ 2 + (z - h.z) ^ 2 < need * need then
			return true
		end
	end
	return false
end

return VillageLayout
