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
local RADIUS_MIN, RADIUS_MAX = 58, 62
local FOOT_LIMIT = 130 / 2 -- the re-cleared footprint's half-extent

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
	for i = 1, buildingCount do
		-- back arc: |angle| from 60° to 165° off the approach direction
		local side = if rng:NextNumber() < 0.5 then 1 else -1
		local s = place(rng, taken, 34, math.rad(60) * side, math.rad(165) * side, radius * 0.45, radius * 0.82)
		if s then
			table.insert(buildings, {
				slot = s,
				model = models[((i - 1) % #models) + 1],
				faceFire = true,
			})
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
	local GAP_HALF = math.rad(17)
	local SEGMENTS = 22
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
		table.insert(perimeter, polar(a, radius))
	end
	for _, g in ipairs(gapCentres) do
		table.insert(entrances, polar(g, radius))
	end

	-- ── loot ─────────────────────────────────────────────────────────────────────────────────────
	-- RULE 3: behind cover. Every loot slot is tucked BEHIND a building (further from the approach than
	-- the building that shelters it) or deep inside the ring — never in the open front of the camp.
	-- This is also what "items into houses" means here: you walk round the back of things to find them.
	local loot: { Slot } = {}
	for i = 1, math.max(opts.resourceCount, 1) do
		local host = buildings[((i - 1) % math.max(#buildings, 1)) + 1]
		local s: Slot?
		if host then
			-- just behind its host, pushed a little further from the fire
			local a = math.atan2(host.slot.right, host.slot.forward) + rng:NextNumber(-0.5, 0.5)
			local d = math.sqrt(host.slot.right ^ 2 + host.slot.forward ^ 2) + rng:NextNumber(9, 16)
			local cand = polar(a, math.min(d, radius - 5))
			if farEnough(cand, taken, 9) then
				table.insert(taken, cand)
				s = cand
			end
		end
		s = s or place(rng, taken, 9, math.rad(50), math.rad(310), radius * 0.35, radius * 0.75)
		if s then
			table.insert(loot, s)
		end
	end

	-- Kind-crates apart from the resource pile, so the top reward reads as separate (kept from #077).
	local kindCrates: { Slot } = {}
	for _ = 1, 2 do
		local s = place(rng, taken, 12, math.rad(200), math.rad(320), radius * 0.5, radius * 0.8)
		if s then
			table.insert(kindCrates, s)
		end
	end

	-- ── guard posts (inside) and reinforcement spawns (OUTSIDE) ──────────────────────────────────
	-- Posts face outward at the ring; the garrison is visible on approach and never pops in front of the
	-- player. Spawns sit BEYOND the ring near the gaps — that is the whole point of Job #100's defence
	-- half: reinforcements walk IN through a door, they do not appear at your feet.
	local posts: { Slot } = {}
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		table.insert(posts, polar(a, radius * rng:NextNumber(0.55, 0.8)))
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

	local tower: Slot? = nil
	if opts.kind.tower then
		-- off the flank and well back, so its 128 instances never fight the huts for space
		tower = polar(math.rad(rng:NextNumber(215, 255)), radius * 0.95)
	end
	local nugget: Slot? = place(rng, taken, 7, 0, math.pi * 2, radius * 0.3, radius * 0.8)

	return {
		fire = fire,
		buildings = buildings,
		perimeter = perimeter,
		entrances = entrances,
		loot = loot,
		kindCrates = kindCrates,
		dressing = dressing,
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
