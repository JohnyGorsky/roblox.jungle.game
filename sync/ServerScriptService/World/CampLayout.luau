--!strict
-- CampLayout.luau — the SEEDED camp assembler (Job #100).
--
-- ── Why this exists ───────────────────────────────────────────────────────────────────────────────
-- Reported: *"Base camps must be larger. Right now they are repetitive and I do not feel like finding
-- things. They are in the same position constantly."*
--
-- `CampDefs.LAYOUT` was ONE fixed table of `{right, forward}` slots, used by every camp in the game. The
-- contents varied a little (near vs deep roster, which resources); the arrangement never did. Two runs
-- in and a player walks a memorised route, which removes the searching from the scavenge half of the
-- core loop.
--
-- This module generates that slot table per camp from the run seed instead. `CampDefs` keeps the parts
-- list and the RULES; this decides where things go.
--
-- ── The three rules that are NOT randomised, on purpose ───────────────────────────────────────────
-- These are what make a camp readable, and a naive scatter destroys all three:
--
--   1. **The fire is the centre.** Everything is positioned relative to it.
--   2. **Everything faces the approach.** "A camp you walk into from behind is a camp you can't read."
--      Buildings face the fire; cover faces the way the player arrives.
--   3. **Loot sits behind cover.** Cover between the player and the crates is what makes the guards
--      matter. Randomising loot into the open would quietly delete the camp's only real tactical idea.
--
-- ── What IS randomised ────────────────────────────────────────────────────────────────────────────
-- Building count and angular position, rotations, which slots hold loot, where the perimeter's gaps
-- fall, guard posts, dressing scatter — and the whole thing is bigger than it was.
--
-- Deterministic from `(runSeed, campIndex)`, so a run is reproducible and a reported layout bug can be
-- regenerated exactly.

local CampDefs = require(script.Parent:WaitForChild("CampDefs"))

local CampLayout = {}

export type Slot = CampDefs.Slot
export type Placed = { slot: Slot, model: string, faceFire: boolean?, yaw: number?, scale: number? }

export type Layout = {
	fire: Slot,
	buildings: { Placed },
	perimeter: { Slot }, -- sandbag segments; the gaps are simply absent
	entrances: { Slot }, -- where the gaps are, for signposting and for guard routes
	loot: { Slot }, -- index 1 is the hero crate; the rest are barrels
	kindCrates: { Slot },
	dressing: { Placed },
	-- Job #100 follow-up: rocks, logs and undergrowth INSIDE the camp. Reported as "it feels empty,
	-- just houses, some trees and that's it".
	ambient: { Placed },
	posts: { Slot }, -- where the garrison STANDS, inside the camp
	spawns: { Slot }, -- where reinforcements ENTER, OUTSIDE the perimeter
	tower: Slot?,
	nugget: Slot?,
	radius: number,
}

-- ── size ─────────────────────────────────────────────────────────────────────────────────────────
-- The old layout's furthest slot was the tower at 44 right / -26 forward, so the camp read as roughly a
-- 60-stud pocket. `buildCampAt` re-clears a 130-stud FOOT around the centre, which is the real ceiling:
-- anything beyond that sits on un-cleared ground and can end up on a stump.
--
-- ⚠️ So RADIUS_MAX is bounded by that clear, not by taste. Growing the camp past it means growing FOOT
-- too, which means a bigger terrain fill per camp — measure before reaching for it.
-- ⚠️ CLEARANCE — how far anything must stay from a building's CENTRE so it is not inside it.
--
-- This is the bug that shipped in the first version: loot was placed 9–16 studs "behind" its host
-- building with a 9-stud separation check, while `Tent` is **43x34 studs** and `BahayKubo5` is
-- **30x22x34**. Half a tent is ~21 studs, so the loot landed INSIDE the model — reported as crates
-- under houses. Footprints come from CampDefs' measured table; these are half-diagonals plus margin.
-- ⚠️ FOOTPRINT — each model's half-diagonal AT THE SCALE IT ACTUALLY RENDERS.
--
-- Derived, not hand-tuned, and that matters: the tent's scale is a knob in `CampDefs.SCALE` that has
-- already been changed once (×4 on request). A hand-written clearance goes stale the moment someone
-- turns that knob, and stale separation means buildings inside each other — which is exactly what was
-- reported as "2 buildings in one". Computing it from the ship size × the live scale means the geometry
-- follows the knob automatically.
local RAW = { -- ship sizes (studs, X by Z) as measured in CampDefs' header
	Tent = { 43, 34 },
	BahayKubo5 = { 30, 34 },
	BahayKubo1 = { 30, 34 },
	BahayKubo7 = { 40, 40 },
	RangerTower = { 20, 20 },
}
local function halfDiagonal(model: string): number
	local raw = RAW[model]
	if not raw then
		return 22
	end
	local sc = (CampDefs.SCALE :: { [string]: number })[model] or 1
	local hx, hz = raw[1] * sc / 2, raw[2] * sc / 2
	return math.sqrt(hx * hx + hz * hz)
end

-- +4 studs so things stand beside each other rather than flush against.
local function clearanceFor(model: string): number
	return halfDiagonal(model) + 4
end

-- ⚠️ THE CAMP RADIUS IS A CONSEQUENCE OF THE BUILDING SIZES, NOT A FREE NUMBER.
--
-- Measured at radius 58-62: the ×4 tent's half-diagonal is 46 studs, so a tent+hut pair needs 69 studs
-- between centres, and the placement ring only reached ~51. Nothing intersected (the sum-clearance test
-- above saw to that) but rejection sampling simply ran out of room: buildings per camp fell from 3-4 to
-- 2, and the camps read as emptier than before the overhaul.
--
-- The honest fix is area, not a smaller tent — which is what job #100's decision 3 asked for. Bounds:
--   · the near and deep camps sit 180 studs apart, so two 160-wide basins leave a 20-stud gap,
--   · the near basin's edge stays ~40 studs inland of the water line, so the carve cannot make shore.
-- Grow either of these and check BOTH before touching `FOOT` in ExcursionServer, which must match.
local RADIUS_MIN, RADIUS_MAX = 70, 76
local FOOT_LIMIT = 160 / 2 -- the re-cleared footprint's half-extent; keep in step with `FOOT` there

-- Keep a walkable corridor on the approach side so the camp can be entered without climbing scenery.
local APPROACH_CORRIDOR = math.rad(38) -- half-angle around "straight ahead of the player"

local function polar(angle: number, dist: number): Slot
	-- forward = +Z in the approach frame, right = +X
	return { right = math.sin(angle) * dist, forward = math.cos(angle) * dist }
end

local function dist2(a: Slot, b: Slot): number
	local dr, df = a.right - b.right, a.forward - b.forward
	return dr * dr + df * df
end

-- Reject a candidate that lands on top of something already placed. There is no collision solver here
-- (CampDefs says so explicitly), so separation is enforced by rejection sampling — cheap, and good
-- enough because the models' footprints are known and the camp is now large enough to hold them.
local function farEnough(candidate: Slot, taken: { Slot }, minSep: number): boolean
	local m2 = minSep * minSep
	for _, t in ipairs(taken) do
		if dist2(candidate, t) < m2 then
			return false
		end
	end
	return true
end

local function place(rng: Random, taken: { Slot }, minSep: number, angleFrom: number, angleTo: number, distFrom: number, distTo: number): Slot?
	for _ = 1, 24 do -- bounded: a failed camp slot is a missing prop, never a hang
		local a = rng:NextNumber(angleFrom, angleTo)
		local d = rng:NextNumber(distFrom, distTo)
		local s = polar(a, d)
		if farEnough(s, taken, minSep) then
			table.insert(taken, s)
			return s
		end
	end
	return nil
end

-- ── the assembler ────────────────────────────────────────────────────────────────────────────────

export type Options = {
	seed: number,
	kind: CampDefs.CampKind,
	resourceCount: number,
	deep: boolean, -- deep camps get the alternate hut so two camps aren't the same photo
}

function CampLayout.generate(opts: Options): Layout
	local rng = Random.new(opts.seed)
	local radius = math.min(rng:NextNumber(RADIUS_MIN, RADIUS_MAX), FOOT_LIMIT - 6)
	local taken: { Slot } = {}

	local fire: Slot = { right = 0, forward = 0 }
	table.insert(taken, fire)

	-- ── buildings ────────────────────────────────────────────────────────────────────────────────
	-- RULE 2: all face the fire. Placed in the BACK arc (behind the fire, away from the approach), which
	-- is where living quarters sat before and why a camp reads as "occupied space with a front".
	local buildings: { Placed } = {}
	local buildingCount = rng:NextInteger(3, 5) -- was always exactly 2 (one hut, one tent)
	local models = { CampDefs.MODEL.hut, CampDefs.MODEL.tent, if opts.deep then CampDefs.MODEL.hutAlt else CampDefs.MODEL.hut }

	-- ⚠️ BUILDINGS MUST NOT INTERSECT, and a single `minSep` cannot express that.
	--
	-- The first version used a flat 34 studs between building centres. `BahayKubo5` is 30×22×34 — its
	-- half-diagonal alone is ~23 studs — so two of them 34 apart OVERLAP. Reported as "2 buildings in
	-- one", and visible as one hut standing inside another.
	--
	-- Separation must come from BOTH models' own sizes, so each pair is checked against the sum of their
	-- clearances. That also means a ×4 tent (CampDefs.SCALE) automatically pushes everything further
	-- away instead of quietly intersecting it.
	local function fitsBeside(cand: Slot, model: string): boolean
		local need = clearanceFor(model)
		for _, b in ipairs(buildings) do
			local other = clearanceFor(b.model)
			-- The SUM, not a fraction of it. An earlier version multiplied by 0.72 "so the camp doesn't
			-- need a stadium" — and that is precisely how a 72-stud tent ended up 54 studs from a hut
			-- that needed 69. Two solids either fit apart or they do not; there is no discount.
			local gap = need + other
			if dist2(cand, b.slot) < gap * gap then
				return false
			end
		end
		return true
	end

	-- ⚠️ THE RADIAL BAND IS PER-MODEL, and it has to be. A flat `radius * 0.45 .. 0.82` band was written
	-- when every building was ~30 studs across; measured against the ×4 tent it put a 72×57 model with a
	-- 46-stud half-diagonal at 60 studs out, so the tent reached 106 from the fire — through its own
	-- fence and off the 160-wide carved basin onto raw jungle. Nothing in the overlap test could see it,
	-- because overhang is not intersection.
	--
	--   near edge: `clear` — any closer and the model's corner swallows the campfire at (0,0)
	--   far edge:  `radius - clear` — any further and its corner crosses the perimeter
	--
	-- A model whose two edges cross over does not fit in this camp AT ALL and is skipped rather than
	-- placed badly. That is deliberate: the count is what tells us a model has outgrown the camp.
	for i = 1, buildingCount do
		local model = models[((i - 1) % #models) + 1]
		local clear = clearanceFor(model)
		-- Far edge is the CARVED BASIN, not the fence. Buildings are allowed to back onto the sandbag
		-- line — the perimeter routes around them below, the way a real camp walls up to its huts — but
		-- nothing may cross onto uncarved jungle, so the square basin's half-extent is the true ceiling.
		-- Holding buildings a full clearance inside the fence instead cost a whole building per camp.
		local dNear = clear
		local dFar = math.min(radius - 6, FOOT_LIMIT - clear - 4)
		if dNear > dFar then
			continue
		end
		-- back arc: |angle| from 60° to 165° off the approach direction
		local placed: Slot? = nil
		-- ⚠️ `d` IS BIASED OUTWARD, and that is worth 30% more buildings per camp.
		--
		-- Two buildings must be `clear(a) + clear(b)` apart, which at radius r costs `2·asin(sep/2r)` of
		-- arc — so the further out a building sits, the less of the arc it consumes. Sampling `d`
		-- uniformly put buildings at an average radius of 36, where a single hut eats ~97° of the 210°
		-- back arc and a third one had nowhere left to go: measured 2.3 buildings per camp against the
		-- 3–5 asked for, i.e. the camps still read empty after the overhaul. `sqrt` makes the sample
		-- uniform by AREA rather than by radius, which pushes the average out toward the fence.
		for _ = 1, 40 do
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			local a = rng:NextNumber(math.rad(55), math.rad(170)) * side
			local d = dNear + (dFar - dNear) * math.sqrt(rng:NextNumber())
			local cand = polar(a, d)
			if farEnough(cand, taken, 12) and fitsBeside(cand, model) then
				table.insert(taken, cand)
				placed = cand
				break
			end
		end
		if placed then
			table.insert(buildings, { slot = placed, model = model, faceFire = true })
		end
	end

	-- ── perimeter, with gaps ─────────────────────────────────────────────────────────────────────
	-- A ring of sandbags at the camp edge with 2–3 openings, so which way you come in is a decision.
	-- The segments are ~1-part `SandbagWall`s, so a full ring is cheap; the cost is in the buildings.
	local perimeter: { Slot } = {}
	local entrances: { Slot } = {}
	local gapCount = rng:NextInteger(2, 3)
	local gapCentres: { number } = {}
	for i = 1, gapCount do
		-- spread the gaps around the ring, jittered, and always leave one reachable from the approach
		local base = (i - 1) * (math.pi * 2 / gapCount)
		gapCentres[i] = base + rng:NextNumber(-0.35, 0.35)
	end
	-- A segment that would stand inside a hut is skipped, so the wall meets the buildings instead of
	-- passing through them. This is what lets buildings sit right out at the fence line.
	local function blockedByBuilding(cand: Slot): boolean
		for _, b in ipairs(buildings) do
			if dist2(cand, b.slot) < clearanceFor(b.model) ^ 2 then
				return true
			end
		end
		return false
	end

	local GAP_HALF = math.rad(17)
	-- Scaled with the radius so the fence keeps its spacing as the camp grows — a fixed count would
	-- have stretched the same 22 posts around a bigger ring and turned a fence into scattered bags.
	local SEGMENTS = math.round(radius / 2.7)
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		local inGap = false
		for _, g in ipairs(gapCentres) do
			local d = math.abs(((a - g + math.pi) % (math.pi * 2)) - math.pi)
			if d < GAP_HALF then
				inGap = true
				break
			end
		end
		if inGap then
			continue
		end
		local seg = polar(a, radius)
		if blockedByBuilding(seg) then
			continue
		end
		table.insert(perimeter, seg)
	end
	for _, g in ipairs(gapCentres) do
		table.insert(entrances, polar(g, radius))
	end

	-- ── loot ─────────────────────────────────────────────────────────────────────────────────────
	-- RULE 3: behind cover. Every loot slot is tucked BEHIND a building (further from the approach than
	-- the building that shelters it) or deep inside the ring — never in the open front of the camp.
	-- This is also what "items into houses" means here: you walk round the back of things to find them.
	-- ⚠️ Loot must be BEHIND cover (rule 3) but never INSIDE it. Both halves matter: the first version
	-- honoured the first and broke the second, and crates ended up under the huts.
	local function clearOfBuildings(cand: Slot): boolean
		for _, b in ipairs(buildings) do
			local need = clearanceFor(b.model)
			if dist2(cand, b.slot) < need * need then
				return false
			end
		end
		return true
	end

	local loot: { Slot } = {}
	for i = 1, math.max(opts.resourceCount, 1) do
		local host = buildings[((i - 1) % math.max(#buildings, 1)) + 1]
		local s: Slot?
		if host then
			-- Behind its host and PAST it: the offset now starts beyond that model's own clearance, so
			-- "behind the hut" means standing behind it, not buried in it.
			local hostClear = clearanceFor(host.model)
			local a = math.atan2(host.slot.right, host.slot.forward) + rng:NextNumber(-0.45, 0.45)
			local d = math.sqrt(host.slot.right ^ 2 + host.slot.forward ^ 2) + hostClear + rng:NextNumber(4, 10)
			local cand = polar(a, math.min(d, radius - 4))
			if farEnough(cand, taken, 10) and clearOfBuildings(cand) then
				table.insert(taken, cand)
				s = cand
			end
		end
		if not s then
			-- fall back to open ground inside the ring, still clear of every building
			for _ = 1, 30 do
				local cand = polar(rng:NextNumber(math.rad(50), math.rad(310)), rng:NextNumber(radius * 0.3, radius * 0.8))
				if farEnough(cand, taken, 10) and clearOfBuildings(cand) then
					table.insert(taken, cand)
					s = cand
					break
				end
			end
		end
		if s then
			table.insert(loot, s)
		end
	end

	-- Kind-crates apart from the resource pile, so the top reward reads as separate (kept from #077).
	-- ⚠️ BOTH KIND-CRATE SLOTS MUST COME BACK. These carry the run's weapon and its ammo, and rejection
	-- sampling is allowed to fail — measured, it failed on 5 camps in 20, which would have shipped a deep
	-- camp with no gun in it. So on failure the search widens (any angle, any distance inside the ring)
	-- before giving up, and only clears buildings — an ammo box beside a barrel is fine, a missing weapon
	-- is not. `ExcursionServer` still carries a last-resort fixed slot in case even this fails.
	local kindCrates: { Slot } = {}
	for _ = 1, 2 do
		local found: Slot? = nil
		for attempt = 1, 60 do
			local wide = attempt > 30
			local cand = polar(
				if wide then rng:NextNumber(0, math.pi * 2) else rng:NextNumber(math.rad(200), math.rad(320)),
				rng:NextNumber(radius * (if wide then 0.25 else 0.5), radius * 0.8)
			)
			if clearOfBuildings(cand) and (wide or farEnough(cand, taken, 12)) then
				table.insert(taken, cand)
				found = cand
				break
			end
		end
		if found then
			table.insert(kindCrates, found)
		end
	end

	-- ── guard posts (inside) and reinforcement spawns (OUTSIDE) ──────────────────────────────────
	-- Posts face outward at the ring; the garrison is visible on approach and never pops in front of the
	-- player. Spawns sit BEYOND the ring near the gaps — that is the whole point of Job #100's defence
	-- half: reinforcements walk IN through a door, they do not appear at your feet.
	-- ⚠️ Posts are biased AWAY from the approach — "others further".
	--
	-- Evenly spaced posts put roughly a third of the garrison right where the player walks in, so
	-- arriving meant meeting several at once. Post 1 is the picket the approach side gets; the rest are
	-- pushed into the back arc, so the camp is met progressively as it is pushed into rather than all at
	-- the doorstep. Pairs with the ramping chase cap in ExcursionServer: one greets you, the rest are
	-- both further away AND not permitted to commit yet.
	local posts: { Slot } = {}
	table.insert(posts, polar(rng:NextNumber(-0.5, 0.5), radius * rng:NextNumber(0.5, 0.65))) -- the picket
	for i = 2, 6 do
		-- spread across the back arc (|angle| 55°..170° off the approach), further out
		local side = if i % 2 == 0 then 1 else -1
		local a = rng:NextNumber(math.rad(55), math.rad(170)) * side
		table.insert(posts, polar(a, radius * rng:NextNumber(0.6, 0.88)))
	end
	local spawns: { Slot } = {}
	for _, g in ipairs(gapCentres) do
		table.insert(spawns, polar(g, radius + rng:NextNumber(26, 40)))
	end

	-- ── dressing + landmarks ─────────────────────────────────────────────────────────────────────
	local dressing: { Placed } = {}
	for _ = 1, opts.kind.extraDressing + rng:NextInteger(1, 3) do
		local s = place(rng, taken, 8, 0, math.pi * 2, radius * 0.3, radius * 0.9)
		if s then
			table.insert(dressing, {
				slot = s,
				model = CampDefs.MODEL.barrel,
				yaw = rng:NextNumber(0, math.pi * 2),
				scale = rng:NextNumber(0.85, 1.15),
			})
		end
	end

	-- ── ambient clutter ─────────────────────────────────────────────────────────────────────────
	-- ⚠️ Generated AFTER the loot, and checked against `taken`, so a rock can never come to rest on top
	-- of a crate. Burying loot is the exact complaint this job already had to fix once.
	--
	-- Rocks and logs COLLIDE on purpose: they are cover, and a camp fight with things to duck behind is a
	-- better fight. Undergrowth does not — a firefight must not become a maze of invisible walls, which is
	-- the rule the existing dressing pass already follows.
	local AMBIENT = {
		{ model = CampDefs.MODEL.rockSmall, weight = 5, collide = true, scale = { 0.7, 1.2 } },
		{ model = CampDefs.MODEL.rockMid, weight = 3, collide = true, scale = { 0.6, 1.0 } },
		{ model = CampDefs.MODEL.rockLarge, weight = 1, collide = true, scale = { 0.5, 0.8 } },
		{ model = CampDefs.MODEL.log, weight = 4, collide = true, scale = { 0.8, 1.2 } },
		{ model = "BushPack", weight = 6, collide = false, scale = { 0.8, 1.3 } },
		{ model = "FernTall", weight = 5, collide = false, scale = { 0.7, 1.2 } },
		{ model = "PalmLowPoly", weight = 2, collide = false, scale = { 0.7, 1.0 } },
	}
	local totalWeight = 0
	for _, e in ipairs(AMBIENT) do
		totalWeight += e.weight
	end
	local function pickAmbient()
		local r = rng:NextNumber(0, totalWeight)
		for _, e in ipairs(AMBIENT) do
			r -= e.weight
			if r <= 0 then
				return e
			end
		end
		return AMBIENT[1]
	end

	local ambient: { Placed } = {}
	local ambientCount = rng:NextInteger(14, 20)
	for _ = 1, ambientCount do
		local e = pickAmbient()
		-- clear of buildings, and of everything already placed — loot included
		local found: Slot? = nil
		for _ = 1, 20 do
			local cand = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(radius * 0.22, radius * 0.95))
			if farEnough(cand, taken, if e.collide then 11 else 7) and clearOfBuildings(cand) then
				table.insert(taken, cand)
				found = cand
				break
			end
		end
		if found then
			table.insert(ambient, {
				slot = found,
				model = e.model,
				yaw = rng:NextNumber(0, math.pi * 2),
				scale = rng:NextNumber(e.scale[1], e.scale[2]),
				faceFire = e.collide, -- reused as the collide flag by the caller
			})
		end
	end

	local tower: Slot? = nil
	if opts.kind.tower then
		-- off the flank and well back, so its 128 instances never fight the huts for space
		tower = polar(math.rad(rng:NextNumber(215, 255)), radius * 0.95)
	end
	local nugget: Slot? = nil
	for _ = 1, 30 do
		local cand = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(radius * 0.3, radius * 0.8))
		if farEnough(cand, taken, 8) and clearOfBuildings(cand) then
			table.insert(taken, cand)
			nugget = cand
			break
		end
	end

	return {
		fire = fire,
		buildings = buildings,
		perimeter = perimeter,
		entrances = entrances,
		loot = loot,
		kindCrates = kindCrates,
		dressing = dressing,
		ambient = ambient,
		posts = posts,
		spawns = spawns,
		tower = tower,
		nugget = nugget,
		radius = radius,
	}
end

-- ── one layout per camp, shared ──────────────────────────────────────────────────────────────────
-- `buildCampAt` is not the only consumer: the trampled-ground painter, the gold nugget and the two
-- kind-crates are all placed from OUTSIDE it, and they used to read the same fixed `CampDefs.LAYOUT`.
-- With a generated layout they must all see the SAME generated one, or the nugget lands where a hut now
-- stands and the worn earth is painted under nothing.
--
-- Memoised on the camp's own position, which is also the seed — so this is a cache, not a second source
-- of truth. Cleared when a landing site is culled.
local cache: { [string]: Layout } = {}

local function key(campPos: Vector3): string
	return ("%d:%d"):format(math.floor(campPos.X), math.floor(campPos.Z))
end

function CampLayout.forCamp(campPos: Vector3, opts: Options): Layout
	local k = key(campPos)
	local hit = cache[k]
	if hit then
		return hit
	end
	local made = CampLayout.generate(opts)
	cache[k] = made
	return made
end

-- Drop a camp's cached layout when its landing site is culled behind the boat, so a long run does not
-- accumulate one table per camp forever.
function CampLayout.forget(campPos: Vector3)
	cache[key(campPos)] = nil
end

-- Walkability check used by the caller's corridor logic: is this angle inside the lane the player walks
-- in through? Exposed so the path-clearing code and the assembler agree on one definition.
function CampLayout.inApproachCorridor(angle: number): boolean
	local d = math.abs(((angle + math.pi) % (math.pi * 2)) - math.pi)
	return d < APPROACH_CORRIDOR
end

return CampLayout
