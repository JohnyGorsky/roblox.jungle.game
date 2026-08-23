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
-- ── The stairs are the point, not decoration ──────────────────────────────────────────────────────
-- Every Bahay Kubo in the library is a stilt house: floor 3.5–4.6 studs up, ONE entrance, and — this is
-- the bit Job #108 missed — ITS OWN BUILT-IN STAIRCASE at that entrance (measured; see
-- `CampDefs.VILLAGE.entrance`). So nothing needs building at the door. What DOES matter is which way the
-- hut is turned: a random yaw has a real chance of aiming the only staircase at the jungle wall, and an
-- un-enterable "enterable building" is the whole thing failing quietly.
--
-- So yaw is chosen from the STAIRS outward — aimed at the walking route, then jittered ±70°, which keeps
-- the scattered, randomly-turned look while guaranteeing the way in faces the way the player comes.
--
-- Deterministic from the site seed, like everything else here, so a reported layout can be regenerated.

local CampDefs = require(script.Parent:WaitForChild("CampDefs"))

local VillageLayout = {}

export type Hut = {
	x: number,
	z: number,
	model: string,
	yaw: number, -- world yaw, ready for `prop()`
	stairDir: Vector3, -- unit XZ direction the model's own staircase faces, in world space
	rise: number, -- interior floor height above the model's base
	halfDiag: number,
	props: { Prop }, -- Job #109: the rocks/logs/undergrowth standing around this hut
}

-- One piece of clutter around a hut. `collide` is the cover/undergrowth split: rocks and logs are
-- something to duck behind, plants must never become invisible walls in a firefight.
export type Prop = {
	x: number,
	z: number,
	model: string,
	yaw: number,
	scale: number,
	collide: boolean,
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

-- Nearest point on the walking lane — what a hut's staircase is aimed at.
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

-- ── clutter around one hut (Job #109) ────────────────────────────────────────────────────────────
-- Reported: *"add some rocks and getables, maybe some trees so camp feels more alive with those houses
-- not just houses"*. `CampLayout` already learned this lesson INSIDE the camps; this is the same pass
-- for the outskirts, and it borrows the same two rules.
--
-- ⚠️ NOTHING IN FRONT OF THE STAIRS. `entranceKeepOut` is a hard wedge around the entrance bearing.
-- Job #109 exists partly because the way in was blocked by something we put there; dropping a boulder
-- on the steps now would be the identical bug with different geometry.
--
-- ⚠️ Placed against the huts ALREADY generated, and against this hut's own earlier props, so clutter
-- never lands inside a neighbour. It cannot see huts generated AFTER it — accepted deliberately: a later
-- hut keeps `hutMargin` from this one's centre, which is a wider gap than its clutter ring reaches.
local function dressHut(rng: Random, hut: Hut, others: { Hut }, stairBearing: number, o: Options)
	local D = CampDefs.VILLAGE.dressing
	local total = 0
	for _, e in ipairs(D.entries) do
		total += e.weight
	end
	local function pick()
		local r = rng:NextNumber(0, total)
		for _, e in ipairs(D.entries) do
			r -= e.weight
			if r <= 0 then
				return e
			end
		end
		return D.entries[1]
	end

	local count = rng:NextInteger(D.perHut[1], D.perHut[2])
	for _ = 1, count do
		for _ = 1, 14 do
			local a = rng:NextNumber(0, math.pi * 2)
			-- reject the entrance wedge
			local off = math.abs(((a - stairBearing + math.pi) % (math.pi * 2)) - math.pi)
			if off < D.entranceKeepOut then
				continue
			end
			local d = hut.halfDiag * rng:NextNumber(D.bandNear, D.bandFar)
			local px, pz = hut.x + math.cos(a) * d, hut.z + math.sin(a) * d

			-- never on the walking lane
			if distToSeg(px, pz, o.pathAx, o.pathAz, o.pathBx, o.pathBz) < o.pathHalf + 4 then
				continue
			end
			-- never inside a neighbouring hut
			local bad = false
			for _, h in ipairs(others) do
				if (px - h.x) ^ 2 + (pz - h.z) ^ 2 < (h.halfDiag + 5) ^ 2 then
					bad = true
					break
				end
			end
			-- nor on top of clutter already placed around this one
			if not bad then
				for _, q in ipairs(hut.props) do
					if (px - q.x) ^ 2 + (pz - q.z) ^ 2 < 7 * 7 then
						bad = true
						break
					end
				end
			end
			if bad then
				continue
			end

			local e = pick()
			table.insert(hut.props, {
				x = px,
				z = pz,
				model = e.model,
				yaw = rng:NextNumber(0, math.pi * 2),
				scale = rng:NextNumber(e.scale[1], e.scale[2]),
				collide = e.collide,
			})
			break
		end
	end
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

			-- ── aim the STAIRS ───────────────────────────────────────────────────────────────────
			-- `prop` places with `CFrame.Angles(0, yaw, 0)`, under which a model-local bearing `b`
			-- (0° = +X, 90° = +Z) lands at world bearing `b - yaw`. So to put the staircase on a chosen
			-- world bearing D, yaw = b - D. Anything else here is guesswork about which way a mesh faces.
			local e = CampDefs.VILLAGE.entrance[model] or { bearing = 0, rise = 0 }
			local px, pz = nearestOnPath(x, z, o)
			local toPath = math.atan2(pz - z, px - x)
			local wantBearing = toPath + math.rad(rng:NextNumber(-70, 70))
			local yaw = math.rad(e.bearing) - wantBearing

			local hut: Hut = {
				x = x,
				z = z,
				model = model,
				yaw = yaw,
				stairDir = Vector3.new(math.cos(wantBearing), 0, math.sin(wantBearing)),
				rise = e.rise,
				halfDiag = halfDiag,
				props = {},
			}
			dressHut(rng, hut, huts, wantBearing, o)
			table.insert(huts, hut)
			break
		end
		-- A hut that found no slot is simply absent. Not warned per-hut: the caller logs
		-- placed-vs-wanted once per site, which is the number that actually says whether the basin has
		-- run out of room.
	end

	return huts
end

--- Would a tree at (x, z) stand inside one of these huts, or in the clutter ring around it? Used by the
--- basin's interior scatter, which runs BEFORE the huts are built and would otherwise plant a palm
--- through a roof.
---
--- ⚠️ Job #109 — the radius covers the DRESSING BAND, not just the building. `dressing.bandFar` puts
--- rocks and logs out to 2.6 half-diagonals (~44 studs on a Kubo1), well past the old `treeClear`
--- radius of ~29, so a basin tree could land on a boulder we had just placed.
function VillageLayout.blocked(huts: { Hut }, x: number, z: number): boolean
	local V = CampDefs.VILLAGE
	for _, h in ipairs(huts) do
		local need = math.max(h.halfDiag + V.treeClear, h.halfDiag * V.dressing.bandFar + 4)
		if (x - h.x) ^ 2 + (z - h.z) ^ 2 < need * need then
			return true
		end
	end
	return false
end

return VillageLayout
