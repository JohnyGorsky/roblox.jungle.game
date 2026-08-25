--!strict
-- CampDefs.luau — the dock-camp dressing table (Job #077).
--
-- THE ONE PLACE A CAMP'S CONTENTS ARE LISTED. `ExcursionServer` reads this and owns no content
-- decisions: which model plays which role, where each piece sits, how the ground is painted, and what
-- the per-camp VFX/light budget is. Same contract `FoliageDefs` has with `FoliageServer` — if a camp
-- looks wrong, the fix is a number in this file, not a line in the server script.
--
-- ── Why the layout is a LOCAL frame, not world offsets ────────────────────────────────────────────
-- The greybox used hardcoded world offsets (`campPos + (-12, 4, 10)`). That cannot survive the swap:
-- `Tent` is 43×34 studs against the 10×10 `Hut` block it replaces, so at the old spacings the new
-- models intersect each other and the loot.
--
-- Slots below are `{ right, forward }` in studs, in a frame where **forward = the direction the player
-- walks INTO the camp** (from the dock). So `forward = -14` is between the player and the camp centre,
-- and `forward = +26` is at the back. Rotating the whole camp to face the approach is then one CFrame,
-- and a camp always reads the same way whichever bank of the river it is on.
--
-- ── The layout rules these numbers encode ─────────────────────────────────────────────────────────
--   · The FIRE is the centre (0,0). Everything else is positioned relative to it.
--   · Everything FACES THE APPROACH. A camp you walk into from behind is a camp you can't read.
--   · LOOT SITS BEHIND COVER — sandbags at negative forward, loot at positive. That is the one piece of
--     dressing here that does real gameplay work: cover between the player and the crates is what makes
--     the guards matter.
--   · Slot SPACING is sized to the measured footprints of the models below (the huts are 20–40 studs
--     across, `Tent` is 43×34), with clearance to spare. It is NOT auto-derived: swap a model here for a
--     substantially bigger one and you must re-check the spacing by eye. There is no collision solver.
--
-- ⚠️ Guard spawn positions are NOT in this file and must not move — they are world offsets in
-- `ExcursionServer` and Job #058's crew-size difficulty scaling is tuned against them.

-- Required for its side effect, BEFORE anything clones from the library: repairs the AssetLibrary
-- models whose pivot sits far outside their own geometry. Without it every rock placed from here
-- lands tens of studs from where it was asked to go. See AssetPivots.luau.
require(game:GetService("ServerScriptService"):WaitForChild("World"):WaitForChild("AssetPivots"))

local CampDefs = {}

-- ── Models, by role ───────────────────────────────────────────────────────────────────────────────
-- Names resolve against `ServerStorage.AssetLibrary` (searched across its group folders). Anything
-- missing is warned about and skipped, never substituted — a silent fallback would hide a place file
-- that was never saved.
-- ⚠️ COUNTS BELOW ARE **BasePart** COUNTS, measured in the place — that is what costs frame time.
-- Do not "correct" them from `#model:GetDescendants()`, which also counts SpecialMeshes, Attachments,
-- Decals and Motors and runs 2–6× higher (`AmmoBox` is 22 parts but 140 descendants; `RangerTower` is
-- 128 parts but 356). That mistake was made once during this job and reversed.
CampDefs.MODEL = {
	tent = "Tent", -- supply tent — 1 part, 43×13×34. The cheapest swap in the job.
	hut = "BahayKubo5", -- sleeping hut — 13 parts, 30×22×34, best value of the four
	hutAlt = "BahayKubo1", -- deep-camp variety — 22 parts, so two camps aren't the same photo
	-- The trading post itself, once per village ONLY. Job #107: was `BahayKubo7`, a 40.2×25.8×50.2
	-- stilt house of **95 parts**. This is the SAME kiosk the crash-site Robux shop uses
	-- (`SpawnBase.Stands.RobuxShop`) — 24.5×21.3×19.4 and **6 parts**.
	--
	-- Not just a look change: the old building's 40×50 footprint swallowed its own signage. Job #106's
	-- sign sits at `approach * 16`, which was INSIDE the stilt house; at 24.5×19.4 the board stands clear
	-- beside the shop, which is the whole point of the swap. Every number that depends on the building —
	-- the gold-chest standoff and the shop prompt's reach — is derived from its bounding box in
	-- `buildTradingPost`, so they follow this automatically.
	--
	-- ⚠️ `buildTradingPost` STRIPS this model's built-in `EntrySign` from its clone: it reads
	-- "ROBUX SHOP", which is the wrong shop, on an AlwaysOnTop BillboardGui, which STYLEGUIDE §5 and
	-- Job #077 both rule out for world signage.
	post = "RobuxShop",
	barrel = "Barrel", -- bulk loot + the carried crate — 6 parts
	crate = "CrateWood", -- ⚠️ 66 parts — the hero crate, exactly ONE per camp
	weaponCrate = "AmmoBox", -- weapon / ammo kind-crates — 22 parts, a military crate for a weapon cache
	sandbag = "SandbagWall", -- 1 part, 8×6×3
	-- ⚠️ 128 parts — the heaviest thing in a landing site after the trading post. Affordable only because
	-- it is ONE per landing (near camp only) and 1–2 sites are ever live. `KIND.near.tower = false` turns
	-- it off in one edit if a real device complains.
	tower = "RangerTower",
	nugget = "GoldNugget", -- ⚠️ a bare MeshPart, not a Model — 2.0×1.3×1.4, CanCollide off
	-- The FIXTURE for the perimeter practicals — 1 part, 1.86×3.80×1.58. Before this the camp's night
	-- lights were invisible 1×1×1 anchors floating 4.5 studs up: light coming from nothing.
	lantern = "Lantern",
	-- ⚠️ PURE DRESSING, beside the trading-post counter — 1 part. It grants NOTHING and carries no prompt.
	-- It is here to say "this is where gold is spent"; the game's only gold SOURCE is `trySpawnNugget`,
	-- which is run-capped on purpose (see its header on the Dead Rails trap). Do not give this a prompt
	-- without deciding a value, a rate and a cap first — that is an economy change, not an art change.
	goldChest = "GoldChest",
	dock = "Dock", -- 62 parts, 32×8×13
	rockSmall = "RockA",
	rockMid = "RockB",
	rockLarge = "RockC",
	log = "LogMossy",
}

-- ── Per-model scale ───────────────────────────────────────────────────────────────────────────────
-- Library models are published at wildly different scales and NONE of them were authored for this camp.
-- ⚠️ `Tent` is the one that matters: it ships at **43×13×34 studs** — wider than either stilt house and
-- nearly the whole camp footprint — so at 1.0 it reads as a giant beige tarp lying in a field, not as a
-- supply tent. Seen and fixed in the first playtest. Anything absent here is 1.0.
CampDefs.SCALE = {
	-- ⚠️ 0.84 = the old 0.42 DOUBLED, and the ceiling — do not raise this without re-measuring.
	--
	-- The request was "these tents are to small size them x4", and ×4 was tried: 1.68, rendering
	-- 72×22×57. Measured across 24 generated camps it placed **zero tents**. `CampLayout` sizes a
	-- building's radial band from its own half-diagonal — 46 studs at ×4 — so the tent had to stand
	-- 50 studs clear of the campfire AND 50 studs inside a fence only 70–76 out. Those bounds cross
	-- over, so the model was skipped every time. Bigger, and it silently disappeared.
	--
	-- ×2 renders **36×11×29**, against the stilt houses' 30×34. That is what "too small" actually
	-- meant: the tent read shrunken beside the huts. At ×2 it matches them and still places in every
	-- camp. Above ~×2.4 the bands cross again and the tent vanishes.
	Tent = 0.84,
	RangerTower = 0.85, -- → ~43 studs tall; still reads from the water, without dwarfing the camp
	GoldNugget = 1.0, -- already resized to 2 studs on import — do not scale again (ASSETS.md §3.5)
	-- → ~2.4 studs tall. A hurricane lantern is a carried object: at 1.0 it ships at 3.8 studs, which is
	-- three-quarters of a player's height sitting on a barricade.
	Lantern = 0.63,
	-- → ~6.1×4.8×7.4. ⚠️ Its 9.44×7.36×11.40 bounding box is INFLATED by coins modelled loose on the
	-- ground around it, so the chest body is smaller than the box implies — scale to how it reads beside
	-- the counter, not to the numbers. Measured against a 2.90×4.60 `Barrel` and a 6.28×2.34 `CrateWood`.
	GoldChest = 0.65,
}

-- ── Measured footprints — THE one source, shared by every placer ─────────────────────────────────
-- Ship sizes in studs, `{ X, Z }`, as the model arrives from the library and BEFORE `CampDefs.SCALE`.
-- Every separation rule in the game divides by these, so a wrong number here is a building inside
-- another building or a crate under a hut — both of which have already shipped once.
--
-- ⚠️ Job #108 CORRECTED THREE OF THESE against a Studio measurement of the live library:
--   · `BahayKubo1` was listed as 30×34; it is **19.8×27.0**. The overstated half-diagonal (~22 against
--     the true ~16.7) cost camp buildings through `CampLayout`'s rejection sampling — i.e. it was one of
--     the reasons a camp read as empty.
--   · `BahayKubo2` was absent entirely (nothing used it).
--   · `BahayKubo7` was listed as 40×40; it is **40.2×50.2**. Unused since Job #107 swapped the trading
--     post to `RobuxShop`, but a stale number is a trap for whoever puts it back.
-- Measure with `Model:GetBoundingBox()` on the library copy, not by eye.
CampDefs.FOOTPRINT = {
	Tent = { 43, 34 },
	BahayKubo1 = { 19.8, 27.0 },
	BahayKubo2 = { 24.7, 21.8 },
	BahayKubo5 = { 29.6, 34.0 },
	BahayKubo7 = { 40.2, 50.2 },
	RangerTower = { 20, 20 },
	RobuxShop = { 24.5, 19.4 },
} :: { [string]: { number } }

-- Half-diagonal of a model AT THE SCALE IT ACTUALLY RENDERS — the number every separation check wants.
-- Derived from `FOOTPRINT` × `SCALE` rather than hand-written, because `SCALE` is a knob that has
-- already been turned once (`Tent` ×2) and a hand-written clearance goes stale the moment it moves.
-- `fallback` is what an unmeasured model gets; keep it pessimistic.
function CampDefs.halfDiagonal(model: string, fallback: number?): number
	local raw = CampDefs.FOOTPRINT[model]
	if not raw then
		return fallback or 22
	end
	local sc = (CampDefs.SCALE :: { [string]: number })[model] or 1
	local hx, hz = raw[1] * sc / 2, raw[2] * sc / 2
	return math.sqrt(hx * hx + hz * hz)
end

-- ── Layout slots — { right, forward } in the approach frame ───────────────────────────────────────
export type Slot = { right: number, forward: number }

CampDefs.LAYOUT = {
	fire = { right = 0, forward = 0 } :: Slot,

	-- Living quarters at the BACK, facing the fire. Wide apart because these are 30–43-stud models.
	hut = { right = -27, forward = 28 } :: Slot,
	tent = { right = 25, forward = 26 } :: Slot,

	-- The sandbag line: across the approach, between the player and the loot.
	sandbags = {
		{ right = -19, forward = -15 },
		{ right = 0, forward = -17 },
		{ right = 19, forward = -15 },
	} :: { Slot },

	-- Loot BEHIND that line. Index 1 is the hero `CrateWood`; the rest are `Barrel`s.
	loot = {
		{ right = 0, forward = -4 },
		{ right = -13, forward = -2 },
		{ right = 13, forward = -2 },
		{ right = -7, forward = 6 },
		{ right = 7, forward = 6 },
	} :: { Slot },

	-- Kind-crates (weapon / ammo) sit apart from the resource pile so the top reward reads as separate.
	kindCrates = {
		{ right = 30, forward = -2 },
		{ right = 30, forward = 8 },
	} :: { Slot },

	nugget = { right = -14, forward = -12 } :: Slot,

	-- Off to the flank and well back, so the tower's 128 instances never fight the huts for space.
	tower = { right = -44, forward = -26 } :: Slot,

	-- Loose dressing: barrels lying about, so the camp isn't only functional objects.
	dressing = {
		{ right = 34, forward = 16 },
		{ right = -34, forward = 6 },
		{ right = 18, forward = 34 },
	} :: { Slot },
}

-- ── The camp clearing (user direction, 2026-08-06) ────────────────────────────────────────────────
-- A landing basin should read as a CLEARING CUT INTO the jungle, not as a lawn with plants dotted on
-- it. Before this the basin got one uniform scatter of shore-band undergrowth from edge to edge, so the
-- camp had no edge — and the terrain `wallBlock` rock walls that contain the basin were plainly visible
-- as walls.
--
-- So the basin is planted in two zones:
--   · RING  — dense trees in two staggered rows around the three inland sides, just inside the rock
--             wall, so the wall is hidden and the camp has an edge.
--   · INSIDE— light undergrowth only, and LESS of it, so the camp stays legible and walkable.
--
-- ⚠️ COST ~80 objects ≈ **350 parts**, because every model in the ring list is cheap (4, 3, 8 and 1
-- parts). `spacing` and `rows` are the levers if a real device complains.
CampDefs.CLEARING = {
	-- ⚠️ THE RING IS INDIVIDUAL TREES, NOT `JungleTreesPack`, AND THAT IS A MEASURED DECISION.
	-- The pack is the obvious choice — it is what `FoliageDefs.WALL` walls the riverbank with — but it
	-- is **218 studs long**, and a 400-stud basin that also has to hold two camps has nowhere to put
	-- one. Measured both ways round: tiles at the basin edge bury 27–45 studs of themselves in the
	-- basin's rock wall, and tiles pulled far enough inland to fit land on top of the deep camp.
	-- Cheap individual trees at close spacing give the same enclosure with a footprint that fits.
	ring = {
		-- Weighted pick. `PalmCoconut` is the workhorse for the same reason it is in `FoliageDefs`:
		-- 4 parts for a 44×50-stud tree. Nothing expensive is in this list — the ring is ~80 objects.
		entries = {
			{ model = "PalmCoconut", weight = 5, scale = { 0.9, 1.3 }, tiltMax = 5 },
			{ model = "PalmLowPoly", weight = 3, scale = { 0.8, 1.2 }, tiltMax = 6 },
			{ model = "BushPack", weight = 4, scale = { 0.9, 1.4 }, tiltMax = 0 },
			{ model = "FernTall", weight = 3, scale = { 0.8, 1.3 }, tiltMax = 8 },
		},
		inset = 24, -- studs in from the basin edge — inside the rock wall, so the trees hide it
		spacing = 26, -- along the perimeter
		rows = 2, -- two staggered rows, so you cannot see through the ring
		rowGap = 22,
		jitter = 9,
	},
	-- How far in from the basin edge the ring zone reaches. Interior scatter stays inside this, so the
	-- undergrowth does not fight the ring for the same ground.
	ringZone = 70,
	-- Interior undergrowth, down from the flat 45 the greybox scattered edge-to-edge: the middle of a
	-- camp you fight in should be open, and the ring should be the thing enclosing it.
	interiorCount = 22,
}

-- ── The outlying village (Job #108) ───────────────────────────────────────────────────────────────
-- Reported: *"right now each camp still feels empty… position Kubo1 and Kubo2 randomly… that way we
-- will have more crowded and enterable buildings."*
--
-- A landing basin is 400 studs across and held exactly two ~75-stud camps, so ~90% of the ground the
-- player walks over was empty jungle floor. This scatters outlying huts across the REST of the basin,
-- outside both camp fences, so a stop reads as a settlement with two defended camps inside it.
--
-- ⚠️ THESE HUTS ARE ENTERABLE, AND THAT IS NOT FREE. Measured in Studio: every Bahay Kubo in the
-- library stands on stilts with its floor **3.5–4.6 studs above its own base**, which is above the
-- Humanoid auto-step (~2 studs) — placing one is therefore NOT the same as making it enterable, you
-- would have to jump in. Each hut gets a step built at its OWN doorway, which is why `door` below
-- exists and why it is a measurement rather than a guess.
CampDefs.VILLAGE = {
	countMin = 6,
	countMax = 10,

	-- Weighted pick. `BahayKubo2` was in the library and used NOWHERE before this job, so it is the
	-- cheapest new silhouette available; `Tent` is in the mix at low weight so the outskirts do not read
	-- as a row of identical houses.
	entries = {
		{ model = "BahayKubo1", weight = 4 },
		{ model = "BahayKubo2", weight = 4 },
		{ model = "BahayKubo5", weight = 2 },
		{ model = "Tent", weight = 1 },
	},

	-- ── 🔴 THE ENTRANCE. MEASURED, AND MEASURED THE RIGHT WAY THE SECOND TIME (Job #109). ───────────
	--
	--   `bearing` — the direction of the model's OWN BUILT-IN STAIRCASE, in its pivot frame, degrees,
	--   0° = +X, increasing toward +Z. `rise` — interior floor height above the model's base, studs.
	--
	-- ⚠️ THESE MODELS ALREADY HAVE STAIRS, AND JOB #108 DID NOT CHECK.
	-- It measured the widest *clear arc*, called that the door, and built two wooden treads there — which
	-- the user then photographed as "2 strange blocks [that] block the entrance", because they landed
	-- BESIDE the real staircase. The treads are gone. All this table does now is turn the hut so the
	-- stairs it already has face the player.
	--
	-- ⚠️ AND THE TWO BEARINGS ARE NOT THE SAME THING. On `BahayKubo1`/`BahayKubo2` the widest arc happens
	-- to sit near the stairs (223 vs 212, 213 vs 208) so the error was small and invisible. On
	-- `BahayKubo5` the widest arc reads **312** and the staircase is at **160** — 152° out, i.e. that hut
	-- was being turned with its steps facing away from the approach entirely.
	--
	-- Method (Studio, Edit): clone into Workspace; raycast down from inside for the floor height; then
	-- for each of 180 bearings walk a probe inward from 32 studs out, casting a LOW ray (from floor + 2,
	-- down floor + 2.5) and recording the height profile. The entrance is the bearing whose profile
	-- starts on open ground, ends on the floor, and whose biggest single-stud rise is smallest.
	-- Measured: Kubo1 **0.87**, Kubo2 **1.00**, Kubo5 **1.00** — all inside the ~2-stud ledge a Humanoid
	-- climbs without jumping, which is why no step of ours is needed.
	--
	-- ⚠️ CAST LOW. A ray dropped from well above the floor hits the ROOF EAVES first and reports a
	-- 9–11-stud "step", which is exactly what made the first attempt at this measurement unreadable.
	-- ⚠️ SAMPLE FAR ENOUGH OUT. At 18 studs `BahayKubo5` (29.6×34.0) is still standing on its own deck,
	-- so every bearing reads as flat and the search picks nonsense. 32 studs clears it.
	entrance = {
		BahayKubo1 = { bearing = 212, rise = 3.5 },
		BahayKubo2 = { bearing = 208, rise = 3.5 },
		BahayKubo5 = { bearing = 160, rise = 4.6 },
		Tent = { bearing = 0, rise = 0 }, -- ground-level, open front: nothing to climb
	} :: { [string]: { bearing: number, rise: number } },

	-- What is inside. ⚠️ SALVAGE ONLY, BY DECISION — a stash grants currency instantly and is NOT
	-- carried. Filling 6–10 huts with real `Gasoline`/`Metal` crates would have tripled the cargo a
	-- landing yields and added that many one-at-a-time carry trips to the boat; the run economy is tuned
	-- against 4 resource crates per site (2 per camp) and this job did not set out to retune it.
	stash = {
		chance = 0.75, -- most huts, not all: an empty hut is what makes a full one worth checking
		model = "Barrel", -- 6 parts. `CrateWood` is 66 and there is exactly one of those per camp.
		salvage = { 25, 40 }, -- against a 50-salvage bandage and a 400-salvage pistol
		scale = 0.8, -- these interiors are ~14 studs across
	},

	-- ── Placement bounds. Every one of these is derived from something, not chosen. ────────────────
	-- How far in from the basin EDGE a hut centre must stay. The clearing ring plants trees 24–46 studs
	-- in from that edge (`CLEARING.ring.inset`/`rowGap`), so 75 keeps the widest hut's corner (~23 studs
	-- of half-diagonal) clear of the innermost tree row instead of standing in it.
	edgeInset = 75,
	-- Clear of a camp: its fence radius plus the hut's OWN half-diagonal plus this. `CampLayout` caps the
	-- fence at RADIUS_MAX 76, and a hut whose corner crosses the sandbag line reads as a broken camp.
	campMargin = 6,
	-- Clear of the walking lane (`PATH_HALF` 18) and of the trading post, likewise plus half-diagonal.
	pathMargin = 8,
	postClear = 55,
	-- Off the water. The bank paint is 26 wide and the dock sits on it.
	shoreClear = 55,
	-- Between two huts: the SUM of both half-diagonals plus this. ⚠️ THE SUM, never a fraction of it —
	-- `CampLayout`'s header records what a 0.72 discount did to the camp buildings (they intersected).
	hutMargin = 10,
	-- Ground must be this flat across the hut's own footprint before the slot is accepted. The basin
	-- carve leaves ~2.5% of columns as stumps of the original hillside; one centre raycast cannot see a
	-- stump under a 30-stud building's corner.
	maxGroundSpread = 2.5,
	-- Keep the interior tree scatter out of a hut: half-diagonal plus this.
	treeClear = 12,

	-- ── What stands AROUND each hut (Job #109) ────────────────────────────────────────────────────
	-- Reported: *"add some rocks and getables, maybe some trees so camp feels more alive with those
	-- houses not just houses"*. Job #108 dropped huts onto bare carved ground, so the village read as
	-- buildings on a lawn — the same complaint Job #100 had to fix INSIDE the camps, where the answer
	-- was `CampLayout`'s ambient pass. This is that pass, applied to the outskirts.
	--
	-- ⚠️ Rocks and logs COLLIDE (they are cover); undergrowth does NOT. Same rule as the camp ambient
	-- list, and for the same reason: a firefight must not become a maze of invisible walls.
	dressing = {
		perHut = { 5, 9 },
		-- Ring around the hut, as a multiple of the hut's own half-diagonal — so a 20-stud Kubo1 and a
		-- 36-stud Tent both get their clutter at the right distance instead of a fixed radius that is
		-- inside one and far from the other.
		bandNear = 1.25,
		bandFar = 2.6,
		-- ⚠️ KEEP THE STAIRS CLEAR. Nothing may be placed within this half-angle of the entrance bearing.
		-- The whole point of Job #109's first item is that the way in was obstructed; re-blocking it with
		-- a boulder would be the same bug wearing a different hat.
		entranceKeepOut = math.rad(34),
		entries = {
			{ model = "RockA", weight = 5, collide = true, scale = { 0.7, 1.3 } },
			{ model = "RockB", weight = 3, collide = true, scale = { 0.6, 1.1 } },
			{ model = "RockC", weight = 1, collide = true, scale = { 0.5, 0.8 } },
			{ model = "LogMossy", weight = 3, collide = true, scale = { 0.8, 1.2 } },
			{ model = "BushPack", weight = 6, collide = false, scale = { 0.8, 1.4 } },
			{ model = "FernTall", weight = 6, collide = false, scale = { 0.7, 1.3 } },
			{ model = "PalmLowPoly", weight = 3, collide = false, scale = { 0.8, 1.2 } },
			{ model = "PalmCoconut", weight = 2, collide = false, scale = { 0.9, 1.2 } },
		},
	},

	-- Pickable things OUTSIDE, among the clutter — the "getables" half of the request. Same salvage
	-- drop as an interior stash but smaller, so searching the village yard is worth doing and is not
	-- just walking between doors.
	yardLoot = {
		perSite = { 3, 5 },
		model = "Barrel",
		salvage = { 12, 22 }, -- lower than the interior stash (25–40): outdoors is the easy find
		scale = 0.75,
	},

	-- ── Hut bandits (Job #109) ────────────────────────────────────────────────────────────────────
	-- User: *"in 2 of houses spawn one bandit … He just sits in house and waits."* TWO per landing site
	-- in total, in two randomly chosen huts — not two per hut, and not one in every hut.
	--
	-- ⚠️ `aggro` is DELIBERATELY tiny against the Bandit def's ~95. An ambusher with a 95-stud sight
	-- radius leaves the house and meets you in the open long before you reach the village, which is the
	-- opposite of sitting and waiting. 24 studs is roughly "you are at the foot of my stairs".
	bandits = {
		count = 2,
		type = "Bandit",
		aggro = 24,
		-- ⚠️ BACKSTOP ONLY — it is NOT how the ambusher decides it has left the house. That test is a
		-- raycast for floorboards underfoot (see `GuardState.perch`), because a radius cannot describe a
		-- 24×14 floor: the first version used a flat 14 studs and the bandit walked 6.8 studs out of its
		-- own doorway still floating at floor height. This number only covers the hut being destroyed
		-- out from under it, e.g. the landing site culled mid-chase.
		perchRadius = 14,
	},
}


-- ── Ground painting (Part 3 of the plan) ──────────────────────────────────────────────────────────
-- The basin was ONE FLAT `Grass` fill, which is exactly what STYLEGUIDE §4 forbids ("never flat-coloured
-- — mix sand, dirt, mud, grass patches").
--
-- ⚠️ THE TWO DIRT PASSES ARE ORDERED AND THE ORDER MATTERS. Scattered patches are painted FIRST at low
-- weight, then the desire-line path and the trampled rings go ON TOP at full weight. The other way round
-- and the random patches eat holes in the path.
--
-- ⚠️ The risk this accepts (assumption A3, user-approved): bare patches AROUND the path can make the path
-- itself read as less deliberate — the navigational hint you get on landing is weaker if everything is
-- patchy. The mitigation is CONTRAST, not restraint: scatter stays small and sparse, the path stays wide
-- and continuous. If it reads as mush in a playtest, the lever is `scatter.count`, NOT the path width.
CampDefs.GROUND = {
	base = Enum.Material.LeafyGrass, -- deeper and more overgrown than Grass; jungle floor, not lawn

	-- Grass patches break the LeafyGrass up so the default isn't one flat tone either.
	grassPatches = { count = 22, radius = { 10, 26 } },

	-- Bare-earth scatter — SMALL and SPARSE on purpose. See the A3 warning above.
	scatter = { count = 24, radius = { 5, 13 }, materials = { Enum.Material.Ground, Enum.Material.Mud } },

	-- The bank where the basin meets the water. §4 wants the bank a different tone from the interior.
	-- ⚠️ Must stay ABOVE the water line or it reads as a muddy pool rather than a bank. `CLEAR_Y` is
	-- `WATER_Y + 3` and every paint block tops out AT `CLEAR_Y`, so this is safe by construction.
	bank = { material = Enum.Material.Mud, width = 26 },

	-- Worn earth where people actually walk. Environmental storytelling, not texture variety.
	trampled = { material = Enum.Material.Ground, fireRadius = 17, hutRadius = 15 },

	-- Paint blocks span `[CLEAR_Y - depth, CLEAR_Y]` — they must top out exactly at the carve height or
	-- they add solid ABOVE the floor and the basin grows bumps.
	depth = 6,
}

-- ── VFX + lights, budget-capped by construction (Parts 5 and 6) ───────────────────────────────────
-- Per-camp caps, not "one emitter per prop". Camps stream with the boat so 1–2 are live at once; these
-- numbers are what a phone pays when two camps and Job #076's ~5,560 foliage instances share a frame.
CampDefs.BUDGET = {
	lightsPerCamp = 4, -- fire + 2 along the sandbag line + 1 inside a hut
	emittersPerCamp = 4, -- fire, embers, smoke, and ONE of fireflies/motes (they are phase-exclusive)
}

CampDefs.VFX = {
	-- The fire has to look alive at 3 studs and at 60, which is why it is an emitter AND a Fire.
	ember = { rate = 7, speed = { 3, 7 }, lifetime = { 1.2, 2.4 }, size = 0.28 },

	-- ⚠️ THE SMOKE COLUMN EARNS ITS PLACE ON GAMEPLAY, NOT LOOKS (assumption A2). A column visible from
	-- the river tells the driver a landing is coming — the same job `RangerTower` does, at eye level.
	-- Nothing else currently signals a camp from the water, so it is sized to CLEAR the band-3 canopy
	-- (`FoliageDefs.WALL`, ~110–220 studs inland) and is verified FROM THE BOAT at approach distance,
	-- not from beside the fire.
	smoke = { size = 14, opacity = 0.42, riseSpeed = 9 },

	-- Night only. §8 names fireflies explicitly. Gated on `Workspace.Phase` so they cost nothing by day.
	fireflies = { rate = 5, count = 1, radius = 26, lifetime = { 4, 8 } },

	-- The day counterpart: drifting motes sell warm shafts of light through the canopy.
	motes = { rate = 4, count = 1, radius = 30, lifetime = { 6, 11 } },
}

-- Warm practicals. Tagged `NightLight`, so `LightController` switches them at dusk (17.5 h) and dawn
-- (6.5 h) — that wiring already existed and had nothing to switch: there were ZERO Light objects in the
-- entire Workspace before this job.
--
-- > ⚠️ THE CONFLICT, recorded so nobody "fixes" it by lowering the night ambient.
-- > Job #073's night palette is deliberately propped up (`outdoorAmbient (66,76,96)`, `exposure 0.26`)
-- > PURELY because there were no practicals, and `Planned/camp-night-practicals.md` says the two changes
-- > must land together. **That reasoning was written for the spawn base and does not transfer to the
-- > river.** These camps are 6 spots on an 18,000-stud river; dropping the GLOBAL night ambient to suit a
-- > lit camp makes the other 17,000 studs unnavigable, and the river at night is a core beat
-- > (`EnemyServer` scales sea threat by `Phase`). So this job adds practicals and does NOT touch
-- > `AtmosphereRig.NIGHT` (assumption A1). Consequence, stated honestly: the camps are lit, but the pools
-- > read weaker than §8 wants against a night that is still artificially lifted. The ambient drop is its
-- > own job, balanced against the boat searchlight.
CampDefs.LIGHT = {
	fire = { brightness = 2.6, range = 34, color = Color3.fromRGB(255, 170, 88), shadows = true },
	perimeter = { brightness = 1.1, range = 20, color = Color3.fromRGB(255, 196, 130), shadows = false },
	-- ⚠️ WHERE THE PERIMETER LANTERN STANDS, AND WHY THERE IS NO HEIGHT CONSTANT HERE.
	-- The two perimeter practicals reuse `LAYOUT.sandbags[1]` and `[3]` — the SAME x/z as two sandbag
	-- walls — so a lantern on the ground would stand inside the barricade. It sits on TOP of the wall,
	-- which is where a camp would put one anyway.
	-- A constant for that height was tried and REMOVED: `groundY + 5.30` (SandbagWall's 5.60 height less
	-- `prop`'s 0.30 sink) floated every lantern exactly 1.0 stud, because `groundY` here is the ground
	-- under the CAMPFIRE while each sandbag is seated on its own `groundAt(x, z)`. `CampAmbience.mountFor`
	-- measures the wall instead. Do not reintroduce a height here.
	--
	-- Height of the flame inside the lantern, as a fraction of the fixture's height — the light belongs at
	-- the glass, not at the base.
	lanternFlame = 0.55,
	interior = { brightness = 1.4, range = 16, color = Color3.fromRGB(255, 205, 148), shadows = false },
	-- Flicker is one shared task over the tagged set, not a connection per fire.
	flicker = { amplitude = 0.35, hz = 11 },
}

-- ── Audio (registry `audio.md` → Jungle / Last River) ─────────────────────────────────────────────
-- The rule `GameSoundscape` sets out: POSITIONAL world cues live on their part with rolloff; only 2D
-- interface sound goes through `UISound`. Nothing here touches the global bed.
--
-- ⚠️ NIGHT INSECTS ARE NOT IN THIS TABLE AND MUST NOT BE ADDED. `GameSoundscape` already runs `cicadas`
-- as a global crossfading night bed, and its header records the measurement: the clip is 71.4 s long, so
-- firing it per camp as a one-shot layers six or seven concurrent 71-second loops into a wall of noise.
CampDefs.SOUND = {
	-- Owned and wired in the LOBBY since Job #069; this is its first use in the game place.
	crackle = { id = "rbxassetid://113774133604878", volume = 0.45, min = 8, max = 60 },
	-- `max` deliberately ~60: the crackle must fade out before the next camp is in earshot.
	water = { id = "rbxassetid://115704936377395", volume = 0.4, min = 10, max = 110 },
	-- Only while the boat is actually tied. An idle creak with no boat on the rope is noise.
	rope = { id = "rbxassetid://99642631685891", volume = 0.35, min = 6, max = 45 },
}

-- ── Per-camp variation ────────────────────────────────────────────────────────────────────────────
-- Same code path, different table — which is how a trading village reads as a different KIND of place
-- rather than the same camp with an extra building.
export type CampKind = {
	-- Job #119: which kind this IS, so a caller can gate on it. Added because the Rocket Man goes on the
	-- DEEP camp's tower only, and `buildCampAt` receives the kind TABLE with nothing on it to test.
	-- ⚠️ A named field rather than `kind == CampDefs.KIND.deep`: table identity holds today (both call
	-- sites pass these very tables) but breaks silently the first time anyone builds a camp from a copy.
	name: string,
	hut: string,
	extraDressing: number,
	sandbags: boolean,
	tower: boolean, -- landing landmark; one per LANDING SITE, not per camp
}

CampDefs.KIND = {
	near = { name = "near", hut = CampDefs.MODEL.hut, extraDressing = 1, sandbags = true, tower = true } :: CampKind,
	-- ⚠️ Job #119: `deep.tower` was FALSE. Turned on so the deep camp has a watchtower for the Rocket Man
	-- to stand on — the owner's call was one rocket man per landing site, at the FAR camp, where the Metal
	-- and Ammo crates are, so the shelling guards the good loot. The near camp keeps its (now unmanned)
	-- tower because it is the tall silhouette you see from the water when you arrive.
	-- 🔴 THIS IS THE COST OF THE JOB: a second 128-part tower per landing site. 1-2 sites are live at once.
	deep = { name = "deep", hut = CampDefs.MODEL.hutAlt, extraDressing = 2, sandbags = true, tower = true } :: CampKind,
}

-- ── The watchtower's top platform — Job #119 ──────────────────────────────────────────────────────
-- The owner edited `AssetLibrary.Structures.RangerTower` by hand and put two invisible 4x1x2 marker pads
-- inside its `Tower` child, both **0.69 studs above the platform floor's top face**. This table is the one
-- place their names and everything hanging off them is written down; `ExcursionServer` reads it and owns no
-- decision about what a tower contains.
--
-- 🔴 BOTH PADS MUST BE MADE INTANGIBLE WHEN THE TOWER IS PLACED, AND THAT IS A BUG FIX, NOT TIDINESS.
-- `prop()` applies `d.CanCollide = o.collide == true` to EVERY BasePart in the clone, and the tower is
-- placed with `collide = true` (you climb it). So as authored these two pads arrive in the world as
-- **invisible collidable slabs** on the deck. `CanQuery` matters separately and for a different reason:
-- `GroundRing`'s header lists four unrelated systems a stray queryable part breaks — other players'
-- bullets, the boat camera, the bazooka's own aim ray, and `HudState`'s 8-stud "am I aboard?" probe, which
-- would read a pad underfoot as ground.
CampDefs.TOWER = {
	-- Marker pad names, as the owner named them inside `RangerTower.Tower`.
	pad = {
		defender = "Defender", -- out near the railing: where the Rocket Man stands and fires
		chest = "InnerPlace", -- inboard: where the loot chest sits
	},

	-- ── The loot chest, on BOTH towers (owner's call) ─────────────────────────────────────────────
	-- ⚠️ `AmmoBox` rather than `Barrel` or `CrateWood`, and the choice is not arbitrary: it is the military
	-- crate (22 parts) the camps already use for weapon caches, so it reads as belonging on a ranger tower
	-- instead of looking like the sixth identical barrel in the camp. `CrateWood` would have been the
	-- "hero" read at **66 parts**, and there are two of these per landing site on top of two towers.
	--
	-- ⚠️ 45-70 salvage against a village hut stash's 25-40 and a yard barrel's 12-22. Higher because the
	-- reward has to pay for a 36-stud climb, and at the deep tower for killing the Rocket Man first. Two
	-- chests per site therefore add ~90-140 salvage to a run; the run economy is tuned against 4 resource
	-- crates per site, and this is SALVAGE (spent at the trading post), not carried cargo, so it does not
	-- touch the one-at-a-time carry loop.
	--
	-- ⚠️ AND IT IS NOT AMMO, despite the model. Making it top up Bazooka rockets was considered and
	-- rejected: `ItemDefs.Bazooka` has NO `ammoPerCrate` on purpose, and that absence is the only thing
	-- holding 6 rockets as a hard per-run cap on a 250 R$ purchase (see MonetizationDefs).
	chest = {
		model = "AmmoBox",
		salvage = { 45, 70 },
		scale = 0.85, -- the platform is 20x20 and the crate shares it with a soldier
	},

	-- ── The Rocket Man ───────────────────────────────────────────────────────────────────────────
	-- ⚠️ `onKind` is what makes "one enemy per landing site" true: only the camp of this kind gets one, so
	-- the near camp's tower stays empty. Change this string to `"near"` to move him, or drop the check to
	-- have one on every tower.
	rocketMan = {
		onKind = "deep",
		type = "RocketMan", -- the `EnemyDefs` def, and therefore the `EnemyAssets.ART` entry

		-- ── ⚠️ THE ONE OPEN QUESTION IN THIS FEATURE, AND IT IS A ONE-WORD ANSWER ─────────────────
		-- `false` = EVERY landing site gets a rocket man, including the FIRST one. That is the literal ask
		-- ("each camp will have one new enemie"), so it is the default: narrowing the owner's scope on our
		-- own initiative is not ours to do.
		--
		-- 🔴 BUT IT COLLIDES WITH A DOCUMENTED DECISION, so read that before leaving it. Job #102 hardcodes
		-- landing 1 to 1 near / 2 deep guards, and its comment block gives the reason as ONBOARDING, not
		-- difficulty: *"first camp has too many enemies when i land"*, *"first time players just confused
		-- when 2 attack same time"*, "first contact has to be legible". A ranged attacker who opens fire
		-- from 160 studs away, before the player has learned that going ashore is a thing at all, is
		-- squarely inside that concern — and unlike a guard you cannot walk away from him.
		--
		-- Set to `true` to exempt the tutorial landing and leave every later one shelled.
		skipFirstLanding = false,

		-- 🔴 20 SECONDS BETWEEN SHOTS — the owner's number, verbatim. For scale, the PLAYER's Bazooka
		-- reload is 5 s, so he fires at a quarter of your rate; the threat is that you cannot shoot back
		-- from where his shells land.
		fireInterval = 20,

		-- 🔴 HE WILL NOT FIRE AT A TARGET CLOSER THAN THIS, AND THE NUMBER IS DERIVED.
		-- The blast radius is 30. Without a floor he drops a 30-stud crater on the foot of his own tower —
		-- and because friendly fire is on and he wears the `CampGuard` tag, on HIMSELF and on every guard
		-- standing under him. 48 puts the crater's rim ~18 studs clear of the tower base.
		minFireRange = 48,

		-- How close a player has to get before he stops shelling and starts swinging. Deliberately just
		-- over `EnemyDefs.RocketMan.biteRange` (14) so there is no dead band where he neither fires nor
		-- fights: inside `meleeRange` he is in close combat, outside it he is a mortar.
		meleeRange = 16,

		-- ── What his shell does. NOT `ItemDefs.Bazooka`'s numbers. ─────────────────────────────────
		-- The player's rocket does **300** in the same radius, which one-shots every land threat in the
		-- game. Pointed at a 100-HP player that is not a weapon, it is a delete button — so the owner set
		-- these independently: 40 across the inner 15 studs, falling to 10 at the rim.
		--
		-- For scale: a camp guard bites for 5.53, so ignoring the ring costs about seven bites at once. A
		-- walking player covers 64 studs in the 4 s flight against a 30-stud radius, so MOVING AT ALL
		-- clears it and standing still is the only thing that gets punished. That is the mechanic.
		blast = {
			flightTime = 4.0, -- matches the player's rocket, so the 4 s of whistle audio still lines up
			blastDamage = 40,
			blastRadius = 30,
			blastInner = 0.5, -- the inner 15 studs take the full 40
			blastMinFactor = 0.25, -- and the rim takes 10
		},

		-- Max distance the shot itself can reach, handed to `Ballistics.resolveImpact`. Left at the
		-- Bazooka's 300 rather than lowered to his 160-stud sight: sight is what he acquires you at, range
		-- is how far the shell flies, and clamping range below sight would make him fire at a point short
		-- of the target he is looking at.
		range = 300,
	},
}

-- ── Tags ──────────────────────────────────────────────────────────────────────────────────────────
-- CollectionService rather than per-camp connections, for one reason that matters: camps are DESTROYED
-- when the boat passes them (`CULL_BEHIND`), and a tagged set prunes itself when the instance dies.
-- A table of "all the fires I made" would leak a reference to every camp of the whole run.
CampDefs.TAG = {
	nightLight = "NightLight", -- read by LightController — dusk/dawn on/off. Do not rename.
	fireLight = "CampFireLight", -- the flicker task's set
	nightVFX = "CampNightVFX", -- fireflies: enabled only while Phase == "night"
	dayVFX = "CampDayVFX", -- motes: enabled only while Phase ~= "night"
	-- Job #084: the fire's `Core` part. `CampfireHeal` finds every fire in the world through this one
	-- tag, the way Defender's `AIHealingPad` finds its pads — so a fire built anywhere (camp, spawn
	-- base, a future hand-placed one) becomes a rest point with no extra wiring.
	campfire = "Campfire",
	-- Job #101: anything a player can actually pick up. The client's `LootGlow` outlines these and
	-- NOTHING else — which is the entire point, since loot and camp dressing are the same models. Tag it
	-- when you make something lootable, or it will look exactly like scenery.
	lootable = "Lootable",
}

-- ── Job #084: resting at a fire ───────────────────────────────────────────────────────────────────
-- Until now NOTHING in the game restored player HP: 100 down to 0 across an 18,000-stud run, with the
-- only recovery being downed-and-revived to 50. Bandages are spent by the REVIVER and never heal the
-- person holding them, and they cannot be found in the world at all (shop only, 50 Salvage).
CampDefs.HEAL = {
	radius = 14, -- studs from the fire core; matches Defender's DefaultRadius
	-- ⚠️ 2.5, NOT 4.0. At 4 the fire out-healed the boat's Medic station (3 HP/s, `RoleServer:17`,
	-- Job 057) while also working solo and ashore, which made the dedicated Medic role pointless.
	-- The station must stay the best heal in the game; the fire is the fallback when you are off the boat.
	rate = 2.5, -- HP/s once the camp is clear
	contestedRate = 1.0, -- HP/s while a living CampGuard is near the fire — a trickle, never nothing
	guardRange = 60, -- a guard within this of the fire counts as "contested"
	interval = 0.5, -- how often the heal loop ticks
}

-- ── Helpers ───────────────────────────────────────────────────────────────────────────────────────

-- Turn a `{ right, forward }` slot into a world position, given the camp centre and the direction the
-- player approaches FROM the dock. `forward` runs deeper into the camp; `right` is perpendicular.
function CampDefs.slotToWorld(centre: Vector3, approach: Vector3, slot: Slot): Vector3
	local f = Vector3.new(approach.X, 0, approach.Z)
	f = if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, 1)
	local r = Vector3.new(f.Z, 0, -f.X) -- right-hand perpendicular in the XZ plane
	return centre + r * slot.right + f * slot.forward
end

return CampDefs
