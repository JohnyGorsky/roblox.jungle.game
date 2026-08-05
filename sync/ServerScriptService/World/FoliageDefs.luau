--!strict
-- FoliageDefs.luau — the river's foliage band table (Job #076).
--
-- THE ONE PLACE A DENSITY NUMBER LIVES. `FoliageServer` reads this and owns no content decisions; if the
-- jungle is too thin, too dense, or too expensive, the fix is a number in this file.
--
-- ── The three bands ────────────────────────────────────────────────────────────────────────────────
-- Each bank is split by distance inland from the water's edge, because a real riverbank is not uniform:
--
--   1 SHORE (0–35)    light, varied undergrowth + the big bright hero palm. Where the player actually
--                     looks, and where they walk when they land.
--   2 MID   (35–110)  individual trees with gaps you can see between. The transition.
--   3 BACK  (110–220) `JungleTreesPack` TILED into a solid canopy wall that hides the mountain seam.
--
-- ── Why the cheap models do the heavy lifting ─────────────────────────────────────────────────────
-- Instance counts per model (measured in Studio, not estimated):
--   PalmCoconut 4 · BushPack 8 · FernTall 1 · PalmLowPoly 3 · LogMossy 1 · RockA/B/C 1
--   PalmCurved 63 ⚠️ · PalmTall 65 ⚠️ · JungleTreesPack 112 ⚠️ (and 218 studs long)
--
-- `PalmCoconut` is 4 meshes and 44×50×38 studs — a big bright tree for almost nothing. It is the
-- workhorse. The two 63/65-PART palms are garnish at wide spacing; between them they are still over half
-- the live budget from ~45 objects, so they are the first lever if a real device complains. Swapping
-- either for a MeshPart equivalent later is one `model` string in this table.
--
-- `spacing` = studs of river per instance PER BANK. Bigger = sparser. Expected live count in the
-- streaming window is `1020 / spacing` per bank, doubled for two banks.

local FoliageDefs = {}

-- Terrain materials foliage may be planted on. This list is not cosmetic: `RiverGenerator` (Job #076)
-- paints the shore Sand and the jungle Grass + LeafyGrass, and the old FoliageServer tested
-- `hit.Material == Enum.Material.Grass` — which after the material pass would have refused to plant on
-- most of the map. Bands declare what they accept.
FoliageDefs.JUNGLE_GROUND = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
}
FoliageDefs.SHORE_GROUND = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Sand] = true, -- the shore strip is Sand now; the beach must still get its palms
}

export type Entry = {
	model: string, -- name under ServerStorage.AssetLibrary (searched across its group folders)
	spacing: number, -- studs of river per instance, per bank
	scale: { number }, -- { min, max } uniform scale jitter
	collide: boolean?, -- default false. True only for things a player should bump into.
	tiltMax: number?, -- max random lean in degrees, for things that shouldn't stand perfectly straight
	-- Default FALSE, and that is the important default. Shadows from every instance would mean ~5,500
	-- shadow casters, which is the easiest way there is to lose the mobile frame budget. Switch it on
	-- only where the shadow itself is the effect — the hero palms near the player, and the alley.
	shadow: boolean?,
}

export type Band = {
	name: string,
	inland: { number }, -- { min, max } studs beyond the outermost channel edge
	ground: { [Enum.Material]: boolean },
	entries: { Entry },
}

FoliageDefs.BANDS = ({
	{
		name = "shore",
		inland = { 4, 35 },
		ground = FoliageDefs.SHORE_GROUND,
		entries = {
			-- the hero palm: cheap, big, bright, and the thing the reference screenshot is full of.
			-- The only band-1 entry that casts — a big palm's shadow on sand is worth the cost; a fern's
			-- is not, and there are five times as many ferns.
			{ model = "PalmCoconut", spacing = 30, scale = { 0.85, 1.2 }, tiltMax = 5, shadow = true },
			{ model = "BushPack", spacing = 25, scale = { 0.8, 1.3 } },
			{ model = "FernTall", spacing = 20, scale = { 0.7, 1.25 }, tiltMax = 8 },
			{ model = "PalmLowPoly", spacing = 50, scale = { 0.6, 1.0 }, tiltMax = 6 },
			-- a fallen log is something you climb over, so it earns collision
			{ model = "LogMossy", spacing = 120, scale = { 0.9, 1.4 }, collide = true, tiltMax = 4 },
			{ model = "RockA", spacing = 90, scale = { 0.8, 2.2 }, collide = true },
			{ model = "RockB", spacing = 110, scale = { 0.8, 2.0 }, collide = true },
			{ model = "RockC", spacing = 130, scale = { 0.8, 2.4 }, collide = true },
		},
	},
	{
		name = "mid",
		inland = { 35, 110 },
		ground = FoliageDefs.JUNGLE_GROUND,
		entries = {
			-- ⚠️ 65 PARTS. Wide spacing is not an aesthetic choice here.
			{ model = "PalmTall", spacing = 100, scale = { 0.9, 1.25 }, tiltMax = 4 },
			{ model = "PalmCoconut", spacing = 40, scale = { 0.9, 1.3 }, tiltMax = 5 },
			{ model = "FernTall", spacing = 45, scale = { 0.8, 1.3 }, tiltMax = 8 },
			{ model = "BushPack", spacing = 60, scale = { 0.9, 1.4 } },
			{ model = "RockB", spacing = 140, scale = { 1.0, 2.6 }, collide = true },
		},
	},
} :: { Band })

-- ── Band 3: the canopy wall ───────────────────────────────────────────────────────────────────────
-- `JungleTreesPack` is NOT a tree. It is a pre-arranged cluster of 112 instances, 218 studs long. You
-- cannot scatter it like a bush — one random placement would swallow a third of the streaming window.
--
-- So it TILES: instances sit on a global grid at multiples of TILE_LEN, which makes the wall seamless and
-- deterministic (segment boundaries can't double-place or leave a gap). ~10 live in the window.
FoliageDefs.WALL = {
	model = "JungleTreesPack",
	TILE_LEN = 200, -- slightly under the pack's 218-stud length, so tiles overlap and never show a seam
	inland = 130, -- centre of the wall, beyond the mid band
	jitter = 14, -- per-tile inland wobble, so the wall isn't a ruler-straight hedge
	scale = { 1.0, 1.15 },
	ground = FoliageDefs.JUNGLE_GROUND,
}

-- ── The alley ─────────────────────────────────────────────────────────────────────────────────────
-- Leaning palms at the water's edge, tilted OUT over the channel, so the river reads as a corridor of
-- palms. Sparse by decision (user, revising an earlier "every 20 studs") — which is exactly what makes a
-- 63-part model affordable here.
--
-- `phase` offsets one bank against the other so palms alternate down the river instead of pairing up into
-- gateways, which looks planted rather than grown.
FoliageDefs.ALLEY = {
	model = "PalmCurved",
	spacing = 80, -- per bank
	phase = 40, -- right bank offset from left
	inland = { 1, 7 }, -- right at the waterline; the trunk stays on land, the fronds reach out
	tilt = { 14, 30 }, -- degrees of lean toward the channel
	scale = { 0.9, 1.3 },
	ground = FoliageDefs.SHORE_GROUND,
}

-- Safety net, not a design number. If a segment ever tries to place more than this, something in the
-- spacing maths is wrong and it should be loud rather than quietly melting the frame budget.
FoliageDefs.MAX_PER_SEGMENT = 60

-- Expected live instance count, for the log line on start-up. Cheap to compute and it means a bad edit to
-- this table shows up as a number in the output instead of as a mystery frame drop.
function FoliageDefs.estimateLive(windowStuds: number, instancesOf: (string) -> number): number
	local total = 0
	for _, band in ipairs(FoliageDefs.BANDS) do
		for _, e in ipairs(band.entries) do
			total += math.floor(windowStuds / e.spacing) * 2 * instancesOf(e.model)
		end
	end
	total += math.floor(windowStuds / FoliageDefs.ALLEY.spacing) * 2 * instancesOf(FoliageDefs.ALLEY.model)
	total += math.floor(windowStuds / FoliageDefs.WALL.TILE_LEN) * 2 * instancesOf(FoliageDefs.WALL.model)
	return total
end

return FoliageDefs
