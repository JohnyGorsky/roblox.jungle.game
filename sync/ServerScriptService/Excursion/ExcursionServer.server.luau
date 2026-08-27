--!strict
-- ExcursionServer.server.luau — dock → jungle-zone raid loop (Jobs 011 → 012).
--
-- Only LANDING-site docks open a big walkable jungle BASIN carved inland (the steep mountains become
-- the ring around it). Greybox trees scatter through it; a few CAMPS sit at increasing depth (deeper =
-- more guards). Tie the boat, go ashore, trek in, loot camps (guarded), carry loot back to the boat.
-- Server-authoritative. (Trees/camps are greybox — real objects come in the art pass.)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerStorage = game:GetService("ServerStorage")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))
-- Job #119: the Rocket Man holds the SAME Bazooka the player does, welded with the SAME grip maths —
-- scale, `holdInChar` and `gripOffset` all come from this table rather than being re-derived. Its header
-- records three separate occasions when a weapon's orientation was guessed wrong.
local WeaponAssets = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("WeaponAssets"))
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local Hints = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Hints"))
-- Job #076: camp clearings draw from the SAME shore-band table the riverbank uses, so the two can't drift
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))
-- Job #077: the camp's CONTENTS (which model plays which role, where it sits, how the ground is painted,
-- what the VFX/light budget is) live in CampDefs. Nothing in this file decides dressing.
local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))
local CampLayout = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampLayout"))
-- Job #120: the physical-sign recipe used to be `buildShopSign` right here. It moved to a module so the
-- river piers can stand the SAME sign (a "TIE BOAT" board) rather than growing a second copy of it.
-- Nothing about the camp sign changed in the move — same size, same tokens, same both-faces SurfaceGui.
local WorldSign = require(ServerScriptService:WaitForChild("World"):WaitForChild("WorldSign"))
-- Job #108: `CampLayout` owns the inside of a camp; this owns the basin AROUND the two camps.
local VillageLayout = require(ServerScriptService:WaitForChild("World"):WaitForChild("VillageLayout"))
-- Job #109: "received X" feedback. See its header for why this is an explicit call per reward and not
-- a client-side watcher on the Salvage attribute.
local RewardFeed = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("RewardFeed"))
local Campfire = require(ServerScriptService:WaitForChild("World"):WaitForChild("Campfire"))
local CampAmbience = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampAmbience"))
local EnemyRig = require(ServerScriptService:WaitForChild("Enemies"):WaitForChild("EnemyRig"))
-- Job #119: the Rocket Man fires the SAME rocket the player's Bazooka does — same module, same
-- `RocketLaunched` broadcast, so `RocketFx` draws an incoming shell exactly like one of your own and this
-- feature needs no client code at all. `Ballistics` resolves where it lands, shared with the client's ring.
local Rocket = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("Rocket"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Ballistics"))
-- Models AND single parts: `GoldNugget` is a bare MeshPart (see `prop`).
local campFloraLib: { [string]: PVInstance } = {}
local openShop = ReplicatedStorage:WaitForChild("OpenShop") :: RemoteEvent -- village trading post (Job 023)

local CAMP_AHEAD = 1400
local CULL_BEHIND = 1200 -- destroy a landing site once the boat is this far past it (frees trees/huts/guards) — Job 060
local BASIN_SIZE = 400 -- walkable jungle zone size (studs)
local GUARD_LEASH = 55
-- 🔴 Job #090 — GETTING SHOT PULLS THE CAMP.
--
-- The exploit, measured from the defs rather than guessed: a gun reaches **350** studs
-- (`GunServer.GUN_RANGE`, or 220 for a handheld) while a guard aggros at `def.aggroRadius` = **95** and
-- could never travel more than `GUARD_LEASH` = **55** studs from its camp. A player standing ~110 studs
-- out was untouchable BY CONSTRUCTION and could empty magazines into a camp at zero risk. The weapon
-- outranged the enemy's maximum possible reach by 4–6×.
--
-- The fix is deliberately NOT "raise aggroRadius". Raising sight alone just means guards sprint to the
-- end of a 55-stud rope and stand there being shot, and raising both permanently makes them abandon
-- camp on sight and trail the player back to the boat. Instead, **taking damage** is what escalates:
-- shooting from cover starts a fight rather than farming one, and an unprovoked camp still behaves
-- like a camp.
--
-- While alerted a guard ignores `aggroRadius` entirely (it knows it is being shot at — it does not need
-- to see you) and its leash opens up to `GUARD_LEASH_ALERT`. Both revert on their own.
local GUARD_LEASH_ALERT = 250 -- reach while alerted; covers a handheld's 220 and most of a gun's 350
local GUARD_ALERT_SECONDS = 15 -- refreshed on every hit; after this long untouched the camp stands down
-- Job #092: how far a guard may walk before its ground height is measured again (studs).
local REMEASURE_STEP = 6
local PATH_HALF = 18 -- keep a tree-free walking lane this wide (half) from the shore to the camps (Job 053)
local MAX_GUARDS = 6 -- escalation cap per camp (Job 053) — a PERF ceiling: each guard is a full R15 rig
-- Per-village escalation (user, 2026-08-16). Compounds on the landing's ordinal: village N is
-- `VILLAGE_STEP^(N-1)` times the first, applied to BOTH guard count and guard strength (HP + bite).
-- Village 1 is deliberately unchanged, so this only ever makes the river harder as you go.
local VILLAGE_STEP = 1.10

-- perpendicular distance (X/Z) from point (px,pz) to segment A→B — used to keep the path lane clear of trees
local function distToSeg(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + t * dx, az + t * dz
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Rare "found gold" (Job 022, design Job 020 §2): a nugget worth 1 Gold may spawn at a camp. Chance per
-- camp is low and the run is hard-capped so looting can't eclipse finishing (the Dead Rails trap).
local NUGGET_CHANCE = 0.25 -- per camp
local NUGGET_VALUE = 1 -- Gold per nugget
local NUGGET_CAP = 3 -- max nuggets spawned per run (tracked on Workspace)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local Terrain = Workspace.Terrain
local CLEAR_Y = RiverData.WATER_Y + 3 -- basin floor / walkable ground height

local campsRoot = Instance.new("Folder")
campsRoot.Name = "Camps"
campsRoot.Parent = Workspace

local built: { [number]: boolean } = {}
local siteModels: { [number]: Model } = {} -- index → LandingSite model, for culling (Job 060)
-- Job #077: the carried crate is a MODEL now (a scaled `Barrel`), not a single Part. Everything that
-- touches it — the deposit prompt, `pickupLoot` — only ever reads an attribute or destroys it, both of
-- which work identically on a Model.
local carrying: { [Player]: Model } = {}
-- `camp` is the camp's own centre position, and it is what makes campmates findable: alerting a camp is
-- a scan of `guardState` for guards sharing that key.
--
-- ⚠️ IT IS THE CAMP POSITION, NOT THE PARENT INSTANCE, AND THAT MATTERS. Every landing site builds a
-- NEAR camp and a DEEP camp (`buildCampAt` is called twice) and passes both the SAME `model` as parent.
-- Keying on the parent would therefore pull both camps at once — up to 12 guards, 180 studs apart —
-- when the user's decision was that getting shot pulls *the camp*, not the whole shore.
--
-- `alertUntil`/`lastHP` are the Job #090 pull; `lastHP` exists because an attribute-changed signal says
-- *that* HP changed, not *which way*, and healing must never count as being attacked.
type GuardState = {
	biteTimer: number,
	anchor: Vector3,
	roared: boolean?,
	camp: Vector3?,
	alertUntil: number?,
	lastHP: number?,
	-- Job #092: the ground height last MEASURED under this guard, and where it was measured. See the
	-- re-measure block in `tickGuard` for why a single spawn-time reading is not enough any more.
	-- Job #100 follow-up: does this guard currently hold one of its camp's limited chase slots? See
	-- CAMP_MAX_CHASERS — a camp of six must not arrive as six.
	chasing: boolean?,
	seatY: number?,
	seatAt: number?,
	seatAtZ: number?,
	-- Job #102: a reinforcement's ONE-TIME leash, wide enough to cover the walk from the entry point it
	-- spawned at to the post it is heading for. Cleared the moment it gets inside the normal leash, after
	-- which it is an ordinary guard. See the leash clamp in `tickGuard`.
	entryLeash: number?,
	-- ── Job #109: the hut ambushers ──────────────────────────────────────────────────────────────
	-- *"in 2 of houses spawn one bandit … He just sits in house and waits."*
	--
	-- ⚠️ A GUARD'S SEAT HEIGHT COMES FROM `groundAt`, WHICH ONLY SEES TERRAIN. A bandit standing on a
	-- hut floor 3.5 studs up would therefore be re-seated onto the dirt on its very first tick — i.e.
	-- standing UNDER the house, between the stilts, which is not sitting in it.
	--
	-- So a perched guard carries the one Y it should occupy while it is still home. The moment it
	-- leaves `perchRadius` (it has taken the stairs and is coming for you) the perch is dropped for
	-- good and it seats on terrain like every other guard, which is what makes the walk down look
	-- right instead of the guard hovering at floor height across the basin.
	perch: number?, -- absolute seated Y while inside its hut
	perchAt: Vector3?, -- the hut it belongs to
	perchModel: Model?, -- ⚠️ the authority on "am I still indoors" — see the release test in `tickGuard`
	perchRadius: number?, -- backstop only, in case the floor raycast ever misses
	-- Per-guard sight override. The Bandit def aggros at ~95 studs; an ambusher with that much sight
	-- walks out to meet you long before you reach the village, which is the opposite of waiting.
	aggroRadius: number?,
	-- ── Job #119: the Rocket Man on the watchtower ───────────────────────────────────────────────
	--
	-- 🔴 `pin` IS NOT A PERCH, AND IT MUST NOT BECOME ONE.
	--
	-- The obvious way to keep an enemy on a 36-stud platform is to reuse `perch` above. That is wrong on
	-- both halves of what `perch` does:
	--   · Its release is PERMANENT and by design (`perch/perchAt/perchModel` are nil'd and `seatY` is
	--     cleared) — because a hut ambusher is SUPPOSED to come down the stairs. A rocket man never
	--     descends, so the first frame its 4-stud floor ray misses (over the stair well, past the
	--     railing) he is dropped to terrain height **for good**: a 36-stud fall with no way back.
	--   · Its own header says a radius cannot describe a rectangular floor, and it costs a raycast per
	--     perched guard per frame.
	--
	-- `pin` is the simpler and stricter thing: the ONE world position this guard occupies, forever. It is
	-- re-asserted every frame from a stored Vector3 with no raycast and nothing to drift, so there is no
	-- release condition to get wrong. `tickGuard` returns early for a pinned guard before it reaches any
	-- of the seat/step/leash logic — which is what actually keeps him up there.
	pin: Vector3?,
	pinYaw: number?, -- the facing he returns to with no target, so he watches the approach, not the sky
	tower: Model?, -- the placed tower clone: excluded from his own aim ray so he cannot shell his railing
	fireTimer: number?, -- seconds since his last shot; his 20 s cycle
	swingFlip: boolean?, -- alternates `attack`/`attack2` so close combat does not look canned
	-- 🔴 Job #121 — HIS PHASE WITHIN THAT CYCLE, and it exists because THREE of them now share a field.
	--
	-- A camp has one rocket man, so it never mattered that `spawnRocketMan` starts every one of them at
	-- `fireTimer = 0`. The end zone has three, spawned in one loop on one frame, all on the same interval,
	-- all picking the NEAREST player, all aiming at the ground under them. They therefore fired on the same
	-- frame at the same point: three overlapping 30-stud craters, 40 damage each at the inner radius =
	-- **120 against a 100 HP player**. Job #119 verified the ring was escapable with ONE shell; three
	-- simultaneous rings from three bearings is a different and unverified geometry.
	--
	-- ⚠️ IT IS ALSO WHERE `fireTimer` RESETS TO WHEN HE HAS NO TARGET, not 0 — otherwise all three re-sync
	-- the instant they lose sight of you and reacquire, which is the common case (you walk into range of all
	-- three at once) and would undo the stagger every time.
	firePhase: number?,
}
local guardState: { [Model]: GuardState } = {}

-- ⚠️ Job #100 follow-up — A CAMP MUST NOT ARRIVE ALL AT ONCE.
--
-- Reported: *"i landed on camp and 7 enemies attacked me"*. Two things combined to produce that. The
-- garrison floor went to 4–6 per camp (and a landing has TWO camps), and `alertCamp` woke EVERY guard in
-- a camp the instant one of them was hit. Land on the near camp, take a swing, and the whole shore
-- converges.
--
-- The count is not the problem — a camp worth clearing should hold 4–6. Arriving as a wall is. So:
--   · only CAMP_MAX_CHASERS guards may chase at any moment; the rest hold their posts until a slot
--     frees (a chaser dies, or loses the player), so the fight comes in waves you can move through and,
--     crucially, RETREAT from,
--   · a hit wakes the guards NEAR the one that was hit, not the entire camp.
-- ⚠️ NEVER MORE THAN TWO AT ONCE.
--
-- A camp holds 2–3 and reinforcements trickle in, so the total is small by design — but two guards and a
-- wandering reinforcement can still converge. This is the hard ceiling on how many may engage at any
-- moment; everyone else holds their post until a slot frees.
--
-- An earlier version ramped this 1 → 3 over the course of a fight. That was over-thought: with a
-- garrison of 2–3 the ramp had almost nothing to ramp, and it made the behaviour hard to predict for no
-- benefit. A flat 2 is the rule, and it is legible.
local CAMP_MAX_CHASERS = 2
local ALERT_SPREAD = 70 -- studs: how far the noise of one guard being hit actually carries

local campChasers: { [string]: number } = {}

local function campKey(camp: Vector3?): string
	return if camp then ("%d:%d"):format(math.floor(camp.X), math.floor(camp.Z)) else "?"
end

-- ── Job #121: a per-area override on that budget ───────────────────────────────────────────────────
-- Empty for every camp on the river, so `CAMP_MAX_CHASERS` = 2 remains the rule everywhere it always was.
--
-- The end zone registers 4 for its ten raiders, on the owner's call, and the reason is not "harder": a
-- guard with no chase slot has its TARGET nil'd, and the bite is gated on having a target — so it will not
-- swing at a player standing next to it. Two slots shared by ten raiders therefore leaves EIGHT of them as
-- scenery you can walk through. (The warlord sidesteps this entirely by carrying his own key; see
-- `EndGarrison.BOSS_CAMP`.)
local campChaserCap: { [string]: number } = {}

local function chaserCapFor(key: string): number
	return campChaserCap[key] or CAMP_MAX_CHASERS
end

local function setChaserCap(camp: Vector3, cap: number)
	campChaserCap[campKey(camp)] = cap
end

-- Wake the guards near the one that got hit. Job #090 added the camp-wide pull so a player could not
-- farm a camp from 110 studs out at zero risk; that intent is preserved — a shot still starts a fight
-- rather than a free kill — but it now starts it with the part of the camp that could plausibly hear it.
local function alertNear(camp: Vector3?, atPos: Vector3?)
	if camp == nil then
		return -- no camp key (shouldn't happen): alert nobody rather than alert the whole map
	end
	local until_ = os.clock() + GUARD_ALERT_SECONDS
	for guard, st in pairs(guardState) do
		if st.camp == camp then
			local body = guard.PrimaryPart
			local within = true
			if atPos and body then
				within = (Vector3.new(body.Position.X, 0, body.Position.Z) - Vector3.new(atPos.X, 0, atPos.Z)).Magnitude <= ALERT_SPREAD
			end
			if within then
				st.alertUntil = until_
			end
		end
	end
end

-- ── Job #084: camps re-man themselves BY DAY ──────────────────────────────────────────────────────
-- Guards used to spawn once when a camp was built and never return, so clearing a camp cleared it for
-- the rest of the run and the player could stroll it at leisure.
--
-- Per the user's call: respawn happens **only during the day phase**, and **one guard at a time** — not
-- a wave. That also sits correctly with `EnemyDefs.strengthFor`, where LAND threats peak by day and sea
-- threats by night: the shore getting busier while the sun is up is the rule the rest of the game
-- already follows. At night a cleared camp stays cleared, which makes a night landing the safe one to
-- make and gives the night set-piece its own distinct shape.
-- `wolves` (Job #086) = how many of this camp's `target` guards are Wolves rather than Bandits. They
-- occupy the first slots, so the day-respawn loop can rebuild the same mix from the count alone.
-- Job #100 adds the fields the re-garrison needs: where reinforcements come IN from (`spawns`), where
-- they walk TO (`posts`), the camp's own re-occupation interval in GAME hours, and the ClockTime reading
-- at which it first fell short — which is what "cleared" means for the hold-off.
type Garrison = {
	campPos: Vector3,
	parent: Instance,
	target: number,
	wolves: number?,
	strength: number?,
	timer: number,
	approach: Vector3?,
	spawns: { CampDefs.Slot }?,
	posts: { CampDefs.Slot }?,
	-- Job #102: the basin this camp sits in, so reinforcement entry points can be kept out of the river
	-- and out of the rock wall. Set by `buildLandingSite`, which is the only scope that knows them.
	waterEdge: number?,
	side: number?,
	nextIn: number?, -- this camp's own randomised interval, so camps do not tick in lockstep
}
local garrisons: { Garrison } = {}

local GUARD_RESPAWN_TICK = 5 -- how often the loop looks at each camp
-- ⚠️ Job #100 follow-up — reinforcements arrive every ~2–3 REAL minutes, one or two at a time.
--
-- Was 45 s for exactly one guard. The user's shape: *"then other enemies come ~2 or 3 minutes real time.
-- Maybe one, maybe two."* Randomised per arrival so the rhythm is not a metronome you can count against.
--
-- The batch stays small on purpose — it is what keeps a player who is CARRYING loot survivable, since
-- carrying blocks both the gun and the axe. One or two is a fight you can run from; six is not.
-- ⚠️ Job #102 — 240 → 180, so the spread is 2–3 minutes and not 2–4. The user asked for a new enemy
-- "after 2-3 minutes"; 240 put the slow half of the roll outside the number they gave.
-- 🔴 AND THIS IS NOW THE WHOLE WAIT. It was not before — see the retired hold-off in the loop below.
local GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX = 120, 180 -- 2–3 real minutes between arrivals
local GUARD_RESPAWN_BATCH_MAX = 2
-- ⚠️ Job #102 — THE RESPAWN LOOP HAD NO OBSERVABILITY AT ALL, AND IT COST A WHOLE DIAGNOSIS ROUND.
--
-- Not one `print` or `warn` existed between the loop's first line and its last, so "no reinforcements
-- arrive" could not be told apart from "the garrison record is gone", "the camp reads as full", or "the
-- timer never reaches its interval" — every number had to be re-derived from constants and then guessed
-- at. Same shape as `DEV_BOAT_LOG` in `BoatServer`: off in normal play, one edit to turn on.
--
-- Leave this FALSE. Flip it when a camp is not re-garrisoning and read the Output.
local DEV_GARRISON_LOG = false
-- The respawn loop runs outside any camp's build scope, so it needs its own generator: the `rng` in
-- `buildLandingSite` is a local seeded per site and is not in scope here. (Caught by the analyzer as a
-- shadowed global, which at runtime would have been a nil index.)
local respawnRng = Random.new()
local GUARD_COUNT_RANGE = 90 -- a guard within this of the camp centre counts as part of its garrison
-- Job #102: how far inside the basin's water edge and far rock wall a reinforcement entry point must
-- stay. The far wall spans 400–430 studs inland, so 20 keeps a guard clear of both it and the river.
local ENTRY_MARGIN = 20

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, parent: Instance, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- ── REAL PROPS (Job #077) ─────────────────────────────────────────────────────────────────────────
-- Every visible camp object is a model from `ServerStorage.AssetLibrary` now. `block()` above survives
-- only for INVISIBLE trigger/anchor parts — if you can see a coloured box in a camp, it is a bug.

-- Ground height under a point, measured not assumed. `CLEAR_Y` is the carve height (15) but terrain voxels
-- snap to the RES=4 grid, so the walkable surface is ~17 — trusting CLEAR_Y buried props by 2.4 studs.
--
-- ⚠️ Rejects near-VERTICAL hits. The basin is ringed by terrain `wallBlock` walls; a ray landing on a wall
-- face returns a height metres above the floor, which is what put a handful of props visibly out of place.
-- 🔴 AND it must DESCEND PAST LEFTOVER SPIKES.
--
-- The basin is carved FLAT at `CLEAR_Y` (real surface ~17–18 after voxel snapping), but `carve` does not
-- clear it perfectly: a measured **2.5% of columns survive above y=21** — stumps of the original hillside
-- standing inside the basin. A prop that happens to land on one gets seated on top of it, and when you
-- look at the camp the stump is invisible-ish but the tent is hanging 15 studs in the air.
--
-- That is exactly what produced the floating Tent / Barrel / AmmoBox: logged live, `Tent at (533,1621)
-- groundAt=33.6` while an `AmmoBox` ten studs away read `17.0`. Not a seating bug, not a timing bug — a
-- leftover terrain column.
--
-- So: take the LOWEST floor within the basin's plausible height band, stepping down past anything above
-- it, rather than the FIRST thing the ray hits.
local BASIN_RISE = 8 -- studs above CLEAR_Y that still counts as "the basin floor"; above this is a stump

-- 🔴 YIELD AFTER WRITING TERRAIN, BEFORE RAYCASTING IT.
--
-- `roblox-terrain` §2: "re-reading immediately after a write IN THE SAME SCRIPT can return pre-write
-- data". This is not theoretical here — it is the single biggest cause of the floating props in this
-- job. Logged live: `BahayKubo7 groundAt=22.0` on ground that measures 17.0 a second later, because the
-- trading post's levelling fill had not landed when the raycast ran. The camps escaped it only by
-- accident, because enough other work happened between their fill and their first prop.
--
-- One frame is enough, and it is free: `buildLandingSite` already runs off a 0.5 s loop, and spreading a
-- site build over a few frames is what the optimization skill asks for anyway.
local function settleTerrain()
	-- Two frames, not one: a single `task.wait()` still returned pre-write data for the trading post pad.
	task.wait()
	task.wait()
end

-- ── Job #121: surfaces that are NOT terrain but ARE floor ─────────────────────────────────────────
-- Empty for every camp on the river, so camp behaviour is bit-identical to before this existed. The end
-- zone registers exactly three models into it (`EndGarrison`, via the `addFloor` api) and here is why:
--
-- MEASURED 2026-08-27 in Edit: `EndBase.Objects.RunWay`'s slab top is **21.11**, the terrain under it is
-- **18.00**, and the extraction pad sits ON that slab. `tickGuard` re-measures a walking guard's height
-- with `groundAt` every `REMEASURE_STEP` studs — so a guard chasing a player toward the pad would walk at
-- 18.00 across a surface topping out at 21.11 and stand **3.1 studs sunk into the concrete**. The end
-- zone's boss is posted 46 studs from the pad with a 55-stud leash, so that is his whole beat, not an
-- edge case.
--
-- ⚠️ REGISTER INDIVIDUAL SURFACES, NEVER A WHOLE FOLDER. `groundAt` returns the FIRST downward hit that
-- looks like floor, so handing it `EndBase` would offer a tower platform (y = 61.7) and the plane's
-- fuselage (y = 34.77) as candidates. Both happen to be rejected by the `CLEAR_Y + BASIN_RISE` = 23 clamp
-- below — but the runway's 21.11 passes that clamp by 1.9 studs, which is exactly how little margin there
-- is, and far too little to hand a subtree.
local extraFloors: { Instance } = {}
local floorFilter: { Instance } = { Terrain }

local function addFloor(inst: Instance)
	for _, e in ipairs(extraFloors) do
		if e == inst then
			return -- idempotent: a second run re-registers the same runways
		end
	end
	table.insert(extraFloors, inst)
	-- Rebuilt rather than mutated in place, so `groundAt` can never observe a half-written filter.
	local next_: { Instance } = { Terrain }
	table.move(extraFloors, 1, #extraFloors, 2, next_)
	floorFilter = next_
end

local function groundAt(x: number, z: number): number
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = floorFilter
	rp.IgnoreWater = true

	local function probe(px: number, pz: number): number?
		local hit = Workspace:Raycast(Vector3.new(px, CLEAR_Y + 60, pz), Vector3.new(0, -300, 0), rp)
		-- Normal.Y near 1 = a floor. A wall face gives ~0 and is not somewhere a tent belongs.
		-- Above `CLEAR_Y + BASIN_RISE` is a leftover stump, not the basin floor.
		if hit and hit.Normal.Y > 0.7 and hit.Position.Y <= CLEAR_Y + BASIN_RISE then
			return hit.Position.Y
		end
		return nil
	end

	local here = probe(x, z)
	if here then
		return here
	end

	-- The point itself is a stump or a wall face. The basin is FLAT by construction, so ask the ground
	-- around it — do NOT step the ray down through the stump: a ray that starts inside solid terrain
	-- registers no floor at all and falls through to the fallback, which seats the prop 3 studs UNDER
	-- the real floor. (Measured: that turned a 15-stud float into a 3-stud burial.)
	local best: number? = nil
	for _, r in ipairs({ 7, 14, 22 }) do
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2
			local g = probe(x + math.cos(a) * r, z + math.sin(a) * r)
			if g and (not best or g < best) then
				best = g
			end
		end
		if best then
			return best
		end
	end
	-- Nothing readable anywhere near: fall back to the carve height plus the voxel-snap offset. The
	-- carve fills to `CLEAR_Y` but voxels quantise to the RES=4 grid, so the real surface measures ~17–18
	-- against a `CLEAR_Y` of 15 — returning bare `CLEAR_Y` here is what buried props by ~2.4 studs.
	return CLEAR_Y + 2.5
end

-- ⚠️ THE RAW PROBE, AND WHY IT IS NOT `groundAt` (Job #108).
--
-- `groundAt` above is a SEATING function: when the ray lands on a stump or a wall face it deliberately
-- looks around the obstacle and answers with the floor beside it, which is exactly right for putting a
-- barrel down and exactly wrong for asking "is this ground flat?". Fed to a flatness test it reports
-- every slot as flat, and the test silently does nothing — which is how you get a 30-stud hut with one
-- corner on a stump.
--
-- So this one reports what is actually there: the first terrain surface at (x, z), stumps included, or
-- nil if there is no terrain at all.
local function rawGroundAt(x: number, z: number): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
	rp.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, CLEAR_Y + 120, z), Vector3.new(0, -400, 0), rp)
	return if hit then hit.Position.Y else nil
end

-- Place a library model with its BASE on the ground, facing `lookAt`, and return it.
-- `yawOnly` keeps props upright; nothing here should ever be tilted.
type PropOpts = {
	scale: number?,
	yaw: number?,
	faceTo: Vector3?,
	collide: boolean?,
	sink: number?,
	-- Defaults to `collide`, which is right for almost everything. The exception that forced this to be
	-- separable is `RangerTower`: 128 parts that must be solid (you can climb it) but must NOT each cast
	-- a shadow, which would be the single most expensive object in the scene.
	shadow: boolean?,
	-- ⚠️ Job #107: strip the ROTATION from the model's pivot before placing it. Opt-in, per model.
	--
	-- `PivotTo` transforms every part by `target * pivot:Inverse()`, so a model whose PIVOT is rotated
	-- lands rotated by that inverse — even when every part inside it is perfectly upright. `RobuxShop`
	-- is exactly that: measured, all six parts read `UpVector:Dot(Y) = +1.000` while the model pivot
	-- reads `rot(90, 0, -90.5)`, `upDot = -0.000`. Placed, the whole kiosk lay on its side.
	--
	-- `AssetPivots` does not catch this. It repairs pivot POSITION (bounding-box centre) for models more
	-- than a stud out, and leaves rotation alone — which is correct for the rocks it was written for.
	-- Fixing rotation globally there would re-orient every repaired model in the library, so this is
	-- opt-in here instead: the caller that knows its model is affected asks for it.
	upright: boolean?,
}

-- ⚠️ Returns a `PVInstance`, not a `Model`. Most of the library is Models, but `GoldNugget` is a bare
-- `MeshPart` — a Model-only signature meant `prop("GoldNugget")` returned nil and NO NUGGET EVER SPAWNED,
-- while still burning a slot against the run cap. Anything here must cope with both.
local function prop(name: string, x: number, z: number, parent: Instance, opts: PropOpts?): PVInstance?
	local source = campFloraLib[name]
	if not source then
		warn(("[Excursion] AssetLibrary has no %q — camp prop skipped"):format(name))
		return nil
	end
	local o: PropOpts = opts or {}
	local clone = source:Clone()
	local parts = clone:GetDescendants()
	table.insert(parts, clone) -- a MeshPart source IS the part; it has no BasePart descendants
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- Structures you walk around SHOULD collide; loose dressing should not, so a firefight in a
			-- camp doesn't turn into a maze of invisible walls.
			d.CanCollide = o.collide == true
			d.CastShadow = if o.shadow ~= nil then o.shadow else o.collide == true
		end
	end

	-- The model's own corrective scale from `CampDefs.SCALE` (published models are not authored for this
	-- camp — `Tent` ships at 43×34 studs) COMPOSED with any per-instance jitter the caller asked for.
	--
	-- `ScaleTo` is a Model method. A single-part prop scales by Size instead — and note that resizing a
	-- MeshPart re-derives its collision geometry (the gotcha recorded in `ASSETS.md` §3.5), which is
	-- harmless only because everything we scale this way is non-colliding.
	local scale = (CampDefs.SCALE[name] or 1) * (o.scale or 1)
	if math.abs(scale - 1) > 1e-3 then
		if clone:IsA("Model") then
			-- ⚠️ `Model:ScaleTo` is ABSOLUTE, and a bare `ScaleTo(scale)` here is a bug waiting for the
			-- next import. The 3D Importer BAKES a scale into the model it creates (`GoldChest` arrives at
			-- `GetScale() = 6.0`, `Lantern` 2.0, `LogJam` 4.0, `Boar` 3.0), so `ScaleTo(0.65)` measured
			-- against the RAW mesh and produced a 1.02-stud chest instead of a 6.14-stud one.
			-- Multiply the current scale so `CampDefs.SCALE` always means "× how this model looks now",
			-- which is what its own comment claims and what `CampAmbience`/`WeaponAssets` already do.
			-- Safe for the existing entries: `Tent` and `RangerTower` both sit at `GetScale() = 1.0`, where
			-- absolute and relative are identical.
			clone:ScaleTo(clone:GetScale() * scale)
		elseif clone:IsA("BasePart") then
			clone.Size *= scale
		end
	end

	-- Job #107: see `PropOpts.upright`. Must happen BEFORE `PivotTo`, which is what bakes the pivot's
	-- rotation into the placed geometry.
	if o.upright and clone:IsA("Model") then
		local model = clone :: Model
		-- ⚠️ `WorldPivot` is IGNORED while a `PrimaryPart` exists — the engine defines the pivot as that
		-- part's CFrame. Same trap `AssetPivots` documents; clearing it first is what makes the write land.
		model.PrimaryPart = nil
		model.WorldPivot = CFrame.new(model.WorldPivot.Position) -- keep the position, drop the rotation
	end

	local yaw = o.yaw or 0
	if o.faceTo then
		local d = Vector3.new(o.faceTo.X - x, 0, o.faceTo.Z - z)
		if d.Magnitude > 0.01 then
			yaw = math.atan2(d.X, d.Z)
		end
	end
	clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * CFrame.Angles(0, yaw, 0))
	FoliageDefs.seatOnGround(clone, groundAt(x, z), o.sink or 0.3)
	clone.Parent = parent
	return clone
end

-- A ProximityPrompt cannot be parented to a Model, and library models have no dependable PrimaryPart.
-- So every interactive Model gets one invisible anchor INSIDE it, at a consistent height above the
-- model's true base — which also means the prompt floats at the same height on a barrel and on a 40-stud
-- hut instead of wherever the publisher happened to put the origin.
--
-- A single-part prop needs none of that: the prompt goes straight on the part.
local function promptAnchor(inst: PVInstance, height: number): BasePart
	if inst:IsA("BasePart") then
		return inst
	end
	local model = inst :: Model
	local _, extents = model:GetBoundingBox()
	local base = FoliageDefs.worldBottom(model) or model:GetPivot().Position.Y
	local centre = model:GetPivot().Position
	local a = Instance.new("Part")
	a.Name = "PromptAnchor"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.CFrame = CFrame.new(centre.X, base + math.min(height, extents.Y * 0.7), centre.Z)
	a.Parent = model
	return a
end

-- rare gold nugget: grab it for 1 Gold, run-capped. Credits the persistent profile immediately.
--
-- Job #077: was a 2×2×2 **Neon** cube. It is the Meshy `GoldNugget` mesh now — grey quartz with gold
-- veining, so it reads as ore you found in a jungle rather than a video-game coin, and so it still reads
-- against the sand and grass it lies on. `CanCollide` stays FALSE (it is collected by prompt, and a
-- collidable pebble underfoot is a trip hazard); the run cap and the Gold value are untouched.
local function trySpawnNugget(pos: Vector3, parent: Instance, rng: Random)
	local spawned = (Workspace:GetAttribute("NuggetsSpawned") :: number?) or 0
	if spawned >= NUGGET_CAP or rng:NextNumber() > NUGGET_CHANCE then
		return
	end
	Workspace:SetAttribute("NuggetsSpawned", spawned + 1)

	local nug = prop(CampDefs.MODEL.nugget, pos.X, pos.Z, parent, { scale = 1, sink = 0, yaw = rng:NextNumber(0, math.pi * 2) })
	if not nug then
		return -- warned by `prop`; a missing library must not silently consume a capped nugget slot
	end
	nug.Name = "GoldNugget"

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NuggetPrompt"
	prompt.ActionText = "Grab Gold"
	prompt.ObjectText = "Gold Nugget"
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = promptAnchor(nug, 1.5)
	-- Job #101: the nugget is the rarest thing in the game (25% per camp, run-capped) and it is a small
	-- rock lying on the ground of a camp full of rocks. If anything in here has to be findable, it is
	-- this. It does not go through `lootPrompt`, so the tag is applied by hand — see CampDefs.TAG.
	CollectionService:AddTag(nug, CampDefs.TAG.lootable)
	prompt.Triggered:Connect(function(player: Player)
		if not nug.Parent then
			return
		end
		nug:Destroy()
		if Profiles.isReady(player) then
			Profiles.addGold(player, NUGGET_VALUE)
		end
		player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + 30) -- Job 023
		-- Job #109: two rewards, so two lines — the gold is the rare part and must not be swallowed by
		-- the salvage. (This one does NOT route through `awardSalvage`; it never applied the Scavenger
		-- bonus, and changing that here would be a balance edit smuggled into a UI job.)
		RewardFeed.notify(player, "gold", "Gold", NUGGET_VALUE)
		RewardFeed.notify(player, "salvage", "Salvage", 30)
	end)
end

-- 🔴 CARVE THE BASIN IN Z-SLICES, FOLLOWING THE RIVER — never as one square block.
--
-- This used to be a single 400×400 `FillBlock` whose inner edge was the bank sampled at ONE z (the
-- dock's). The river MEANDERS, so 200 studs up- or downstream the channel has moved sideways — and the
-- square carve then filled the channel itself with solid ground. On screen that is a slab of land
-- jutting out into the river with a dead-straight edge: "land is outside".
--
-- Same root cause as every other placement bug in this job: ONE SAMPLE USED FOR A 400-STUD FOOTPRINT.
-- So walk the basin in slices and re-read the bank for each one; the basin's inner edge then follows
-- the water instead of cutting across it.
--
-- Job #077 also changed the base material to `LeafyGrass` — deeper and more overgrown than `Grass`, so
-- the basin floor reads as jungle floor rather than lawn. `FoliageDefs.JUNGLE_GROUND` accepts both, so
-- #076's foliage plants on it unchanged.
local CARVE_SLICE = 20 -- studs of Z per slice; small enough to track the meander, few enough to be cheap

local function bankAt(z: number, side: number): number
	return RiverData.centerlineX(z) + side * RiverData.widthAt(z) * 0.5
end

-- 🔴 A SLICE MUST USE ITS MOST-INLAND BANK, NOT ITS MIDPOINT.
--
-- Each carve slice is an axis-aligned box 20 studs deep in Z, but the river meanders WITHIN those 20
-- studs. Taking the bank at the slice midpoint means that wherever the channel swings toward the camp
-- inside the slice, the box starts out in open water and fills the river with solid ground. Measured at
-- the basin's +Z end: 59 intrusions reaching **32 studs inside the bank**.
--
-- So sample across the slice and keep whichever bank is furthest INLAND (the one that leaves the most
-- water alone), plus a margin for the bank's own irregularity.
local BANK_MARGIN = 6

local function bankForSlice(z0: number, z1: number, side: number): number
	local best = bankAt(z0, side)
	for i = 1, 4 do
		local b = bankAt(z0 + (z1 - z0) * (i / 4), side)
		if (b - best) * side > 0 then
			best = b
		end
	end
	return best + side * BANK_MARGIN
end

local function carve(cx: number, cz: number, size: number, side: number)
	local half = size / 2
	local outerX = cx + side * half -- the inland edge, which does not move
	for z0 = cz - half, cz + half - CARVE_SLICE, CARVE_SLICE do
		local zMid = z0 + CARVE_SLICE / 2
		local innerX = bankForSlice(z0, z0 + CARVE_SLICE, side) -- most-inland bank ACROSS the slice
		local width = (outerX - innerX) * side
		if width > 8 then
			local xMid = (innerX + outerX) / 2
			Terrain:FillBlock(CFrame.new(xMid, CLEAR_Y - 20, zMid), Vector3.new(width, 40, CARVE_SLICE), CampDefs.GROUND.base)
			Terrain:FillBlock(CFrame.new(xMid, CLEAR_Y + 32, zMid), Vector3.new(width, 64, CARVE_SLICE), Enum.Material.Air)
		end
	end
end

-- ── ground painting (Job #077, plan Part 3) ───────────────────────────────────────────────────────
-- The basin used to be ONE FLAT `Grass` fill — exactly what STYLEGUIDE §4 forbids. This paints over the
-- SAME voxels the carve already filled: no new terrain region, one extra pass at camp-build time and
-- ZERO at runtime.
--
-- ⚠️ EVERY PAINT BLOCK TOPS OUT AT `CLEAR_Y`. Go a stud higher and you are not painting, you are adding
-- solid above the floor — and the basin grows bumps you cannot see in the editor but trip over in play.
local function paintDisc(x: number, z: number, radius: number, material: Enum.Material)
	local d = CampDefs.GROUND.depth
	Terrain:FillCylinder(CFrame.new(x, CLEAR_Y - d / 2, z), d, radius, material)
end

-- Pass 1 and 2 of three. Scattered patches are painted FIRST at low weight; the desire-line path (the
-- caller's `FillBlock`) and the trampled rings (`paintTrampled`) go ON TOP at full weight. The other way
-- round and the random patches eat holes in the path.
local function paintBasin(cx: number, cz: number, size: number, waterEdge: number, side: number, rng: Random)
	local G = CampDefs.GROUND
	local half = size / 2 - 6

	-- 🔴 A PAINT DISC CREATES GROUND, IT DOES NOT ONLY RECOLOUR IT.
	--
	-- `FillCylinder` fills solid, so a "repaint" disc whose centre sits near the bank builds NEW LAND out
	-- over the river. This was the last source of solid ground in the channel: 14 samples, up to 32 studs
	-- in, every one of them `Grass` or `Ground` — the scatter, not the carve or the walls.
	--
	-- So every disc is pushed inland until its whole radius clears the local bank.
	local function inland(x: number, z: number, radius: number): number
		local limit = bankForSlice(z - radius, z + radius, side) + side * radius
		return if (x - limit) * side < 0 then limit else x
	end

	-- Grass patches, so the LeafyGrass default isn't one flat tone either
	for _ = 1, G.grassPatches.count do
		local r = rng:NextNumber(G.grassPatches.radius[1], G.grassPatches.radius[2])
		local z = cz + rng:NextNumber(-1, 1) * half
		paintDisc(inland(cx + rng:NextNumber(-1, 1) * half, z, r), z, r, Enum.Material.Grass)
	end

	-- Bare-earth scatter. SMALL and SPARSE by decision — see the A3 risk note in `CampDefs.GROUND`: if
	-- this reads as mush next to the path, the lever is `scatter.count`, never the path width.
	for _ = 1, G.scatter.count do
		local r = rng:NextNumber(G.scatter.radius[1], G.scatter.radius[2])
		local z = cz + rng:NextNumber(-1, 1) * half
		paintDisc(
			inland(cx + rng:NextNumber(-1, 1) * half, z, r),
			z,
			r,
			G.scatter.materials[rng:NextInteger(1, #G.scatter.materials)]
		)
	end

	-- The bank where the basin meets the water — §4 wants it a different tone from the interior.
	-- ⚠️ SLICED, following the meander, for the same reason `carve` is: one bank sample smeared over 400
	-- studs paints mud across open water at the ends.
	-- ⚠️ Safe above the water line by construction: `CLEAR_Y` is `WATER_Y + 3` and this tops out AT
	-- `CLEAR_Y`. Push it any lower and it reads as a muddy pool rather than a bank.
	local bankHalf = size / 2
	for z0 = cz - bankHalf, cz + bankHalf - CARVE_SLICE, CARVE_SLICE do
		local zMid = z0 + CARVE_SLICE / 2
		local bankX = bankForSlice(z0, z0 + CARVE_SLICE, side) + side * (G.bank.width / 2)
		Terrain:FillBlock(
			CFrame.new(bankX, CLEAR_Y - G.depth / 2, zMid),
			Vector3.new(G.bank.width, G.depth, CARVE_SLICE),
			G.bank.material
		)
	end
end

-- Pass 3: worn earth where people actually walk. This is environmental storytelling, not texture
-- variety — bare ground under the tents and around the fire is the evidence that someone lives here.
-- ⚠️ Job #100: paints under the buildings this camp ACTUALLY has, not under the two fixed slots the old
-- layout always used. Worn earth is evidence someone lives here; painting it where no hut stands (and
-- leaving bare grass under the ones that do) is worse than not painting at all.
local function paintTrampled(campPos: Vector3, approach: Vector3, layout: CampLayout.Layout)
	local G = CampDefs.GROUND
	local fire = CampDefs.slotToWorld(campPos, approach, layout.fire)
	paintDisc(fire.X, fire.Z, G.trampled.fireRadius, G.trampled.material)
	for _, b in ipairs(layout.buildings) do
		local p = CampDefs.slotToWorld(campPos, approach, b.slot)
		paintDisc(p.X, p.Z, G.trampled.hutRadius, G.trampled.material)
	end
end

-- deposit carried loot at the boat → a resource count. ONLY shown while someone is carrying.
local deposit = Instance.new("ProximityPrompt")
deposit.Name = "DepositPrompt"
deposit.ActionText = "Deposit"
deposit.ObjectText = "Cargo"
deposit.HoldDuration = 0.5
deposit.RequiresLineOfSight = false
-- 🔴 WAS 16, AND THAT IS WHY DEPOSIT "SOMETIMES DID NOTHING" (reported 2026-08-16).
-- This prompt hangs off `hull`, so it is anchored at the boat's CENTRE — but the boat is far bigger
-- than the hull part. Measured live: hull is 14×3×32, the full boat bounds are 14.7×11×46, and the
-- furthest COLLIDABLE (walkable) part sits **23.0 studs** from the hull origin. So the outer ~7 studs
-- of deck — the bow and the stern — were outside the prompt entirely. The player who reported it was
-- standing at 14.3, right on the edge.
--
-- Intermittent for two compounding reasons: where you stand on the deck decides whether it responds at
-- all, and with a 0.5 s hold, taking one step mid-hold crosses the boundary and cancels it silently.
--
-- 26 covers the measured 23 with margin for the deck rocking. ⚠️ If the boat ever gets longer (a hull
-- module, a bigger trailer), re-measure — this number tracks the BOAT, not the hull part it hangs on.
deposit.MaxActivationDistance = 26
deposit.Enabled = false
deposit.Parent = hull
-- Job #084: the crew feed. One small stacking toast channel, consumed by `CrewToast.local.luau`.
local crewToast = Instance.new("RemoteEvent")
crewToast.Name = "CrewToast"
crewToast.Parent = ReplicatedStorage

-- ⚠️ Job #084: the deck's fullness is shown ON THE PROMPT, before it is pressed.
-- Reported in play as *"i sometimes deposit and nothing happens"*. It was a full cargo deck and a bare
-- `return` — the same unsignalled-gate bug as the pistol's `Busy` check earlier in this job. A refused
-- action that says nothing reads as a broken button, and here it also strands the player: `Busy` stays
-- true, so they are stuck carrying a crate they cannot deposit and cannot fight with.
local function cargoTotal(): number
	return ((boat:GetAttribute("Gasoline") :: number?) or 0)
		+ ((boat:GetAttribute("Metal") :: number?) or 0)
		+ ((boat:GetAttribute("Ammo") :: number?) or 0)
end

local function refreshDeposit()
	deposit.Enabled = next(carrying) ~= nil
	local full = cargoTotal() >= ((boat:GetAttribute("CargoMax") :: number?) or 10)
	deposit.ActionText = if full then "Cargo FULL" else "Deposit"
end

-- the deck fills from the shop and the fuel station too, not just from deposits
for _, attr in ipairs({ "Gasoline", "Metal", "Ammo", "CargoMax" }) do
	boat:GetAttributeChangedSignal(attr):Connect(refreshDeposit)
end

deposit.Triggered:Connect(function(player: Player)
	local carried = carrying[player]
	if not carried then
		return
	end
	local resource = (carried:GetAttribute("Resource") :: string?) or "Metal"
	if cargoTotal() >= ((boat:GetAttribute("CargoMax") :: number?) or 10) then
		refreshDeposit() -- deck full → keep carrying it, and SAY so on the prompt
		return
	end
	boat:SetAttribute(resource, ((boat:GetAttribute(resource) :: number?) or 0) + 1)

	-- Job #098: now they have delivered something, tell them what it is FOR. Placed after the
	-- cargo-deck-full early-return above, so a REFUSED deposit never teaches a lesson that did not
	-- happen. No delay here: the crew toast below is small and off to one side, so nothing competes.
	Hints.show(player, "fuelAndRepair")
	-- Job #084: tell the WHOLE crew, not just the depositor — the cargo hold is shared, so a deposit is
	-- crew news. Deliberately its own feed and not the `Announce`/`ZoneBanner` channel: that is a large
	-- centre-screen banner with a hold, tuned for rare beats (zone crossings, nightfall), and firing it
	-- several times per landing would both nag and stomp real zone announcements.
	crewToast:FireAllClients({
		icon = "crate",
		text = ("%s deposited 1 %s"):format(player.DisplayName, resource),
		detail = ("%d/%d"):format(cargoTotal() + 1, (boat:GetAttribute("CargoMax") :: number?) or 10),
	})
	carried:Destroy()
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	local char = player.Character
	if char then
		char:SetAttribute("Carrying", nil)
	end
	refreshDeposit()
end)

-- 🔴 Job #084: DYING WHILE CARRYING USED TO DISARM YOU FOR THE REST OF THE RUN.
-- Nothing anywhere cleared `carrying` or `Busy` except a successful deposit — this file had no
-- `CharacterAdded`/`CharacterRemoving`/`PlayerRemoving` handler at all. So on death:
--   · the carried model died with the character (it is parented to `char`), but
--   · `carrying[player]` kept pointing at the destroyed instance — still TRUTHY in Luau, so the
--     "already carrying" guard in `pickupLoot` blocked every future pickup, and
--   · `Busy` is a PLAYER attribute, so it survived respawn — leaving the new character permanently
--     unable to shoot or swing, with the "HANDS FULL" chip up and no crate to explain it.
local function clearCarry(player: Player)
	local carried = carrying[player]
	if carried then
		carried:Destroy() -- no-op if it already went with the character
	end
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	local char = player.Character
	if char then
		char:SetAttribute("Carrying", nil)
	end
	refreshDeposit()
end

local function watchPlayer(player: Player)
	player.CharacterRemoving:Connect(function()
		clearCarry(player) -- the loot is lost with the body; that is the cost of dying on a raid
	end)
	-- belt and braces: a character can be replaced without CharacterRemoving firing first
	player.CharacterAdded:Connect(function()
		clearCarry(player)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	carrying[player] = nil
	refreshDeposit()
end)

-- award in-run Salvage (Job 023) — cash rewards raiding, not passive driving.
-- Scavenger's Instinct (Job 029): the looter's skill boosts the Salvage payout.
local function awardSalvage(player: Player, amount: number)
	local scav = (player:GetAttribute("SkillScavenge") :: number?) or 0
	local total = math.floor(amount * (1 + 0.03 * scav))
	player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + total)
	-- Job #109: every salvage payout in this file funnels through here — loot crates, hut stashes,
	-- weapon and ammo crates — so ONE call covers all of them, and it reports the SCALED total rather
	-- than the base amount, which is what the counter actually moved by.
	RewardFeed.notify(player, "salvage", "Salvage", total)
end

-- Build the thing that rides over your head while you haul loot back to the boat.
--
-- ⚠️ THREE PROPERTIES HERE ARE LOAD-BEARING, and two of them are new hazards created by making this a
-- model instead of a Part:
--   · `Anchored = false` on EVERY part. An anchored part welded to the character's root anchors the
--     whole assembly — you would freeze in place the instant you picked up loot.
--   · `Massless = true` on every part. It is welded to your root; a 6-part barrel with real mass changes
--     how the character moves while hauling, and hauling feel is tuned (Job 023).
--   · `CanCollide = false`, else it collides with the world over your head.
local function makeCarried(root: BasePart, resource: string): Model
	local carried: Model
	local source = campFloraLib[CampDefs.MODEL.barrel]
	if source and source:IsA("Model") then
		carried = source:Clone()
		carried:ScaleTo(0.5) -- shoulder-sized, not the full camp barrel
		-- Job #088: ON THE BACK, not balanced on the head. This was `(0, 3, 0)` — three studs straight up
		-- from the root, which put a rusted barrel on top of the player's hat.
		-- ⚠️ +Z is BEHIND: `HumanoidRootPart.CFrame.LookVector` is the way the character faces (−Z), so a
		-- positive Z offset sits between the shoulder blades. Tilted back slightly so it reads as slung
		-- and carried rather than stuck on.
		carried:PivotTo(root.CFrame * CFrame.new(0, 0.6, 1.3) * CFrame.Angles(math.rad(-12), 0, 0))
	else
		-- The library is missing (unsaved place file). Still give the player something to carry rather
		-- than an invisible haul — the Busy/deposit flow depends on this object existing.
		carried = Instance.new("Model")
		local box = Instance.new("Part")
		box.Name = "Crate"
		box.Size = Vector3.new(3, 3, 3)
		box.Color = Color3.fromRGB(150, 120, 70)
		box.Material = Enum.Material.WoodPlanks
		box.CFrame = root.CFrame * CFrame.new(0, 0.6, 1.6) -- Job #088: back, not head (matches the model path)
		box.Parent = carried
		carried.PrimaryPart = box
	end

	carried.Name = "CarriedCrate"
	carried:SetAttribute("Resource", resource)
	for _, d in ipairs(carried:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	return carried
end

local function pickupLoot(player: Player, crate: PVInstance)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return
	end

	-- weapon / ammo crates GRANT to the loadout instantly (no carry, no Busy) — Job 015
	local kind = (crate:GetAttribute("Kind") :: string?) or "Resource"
	if kind == "Weapon" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		if InventoryService.grant(player, id) then
			RewardFeed.notify(player, "weapon", id) -- no amount: "+1 Pistol" reads like a stack count
			awardSalvage(player, 80)
			crate:Destroy()
		end -- inventory full → leave the crate so the player can free a slot
		return
	elseif kind == "Salvage" then
		-- Job #108: the outlying village huts. Grants CURRENCY and nothing else — no carry, no `Busy`,
		-- no cargo. That is the decision, not an omission: a landing site's cargo economy is tuned
		-- against exactly four resource crates (two per camp), and filling 6–10 new huts with carryable
		-- Gasoline/Metal would have tripled the haul and added that many one-at-a-time trips to the boat.
		-- Making these a currency drop instead means the village can be as big as it needs to look
		-- without re-tuning fuel, hull repair or the shop.
		awardSalvage(player, (crate:GetAttribute("Amount") :: number?) or 30)
		crate:Destroy()
		return
	elseif kind == "Ammo" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		local def = ItemDefs.get(id)
		local rounds = (def and def.ammoPerCrate) or 12
		InventoryService.addAmmo(player, id, rounds)
		RewardFeed.notify(player, "ammo", id .. " Ammo", rounds)
		awardSalvage(player, 40)
		crate:Destroy()
		return
	end

	-- resource crates (gasoline/metal/turret-ammo): carry back to the boat cargo (existing behaviour)
	if carrying[player] then
		return
	end
	local resource = (crate:GetAttribute("Resource") :: string?) or "Metal"
	local carried = makeCarried(root, resource)
	carried.Parent = char
	carrying[player] = carried
	-- Job #109: name the thing you picked up. The salvage line comes from `awardSalvage` below; this one
	-- is the cargo, which is the half a bare "+40 Salvage" could never tell you.
	RewardFeed.notify(player, "resource", resource, 1)
	awardSalvage(player, 40)
	char:SetAttribute("Carrying", resource)
	player:SetAttribute("Busy", true) -- hands full → can't shoot
	refreshDeposit()
	crate:Destroy()

	-- Job #098: teach the carry mechanic, ONCE EVER. Deliberately here and not at the top of this
	-- function — the weapon and ammo branches above return early because those crates grant instantly
	-- and are never carried, so firing there would tell the player to deliver something they are not
	-- holding.
	--
	-- Delayed a beat: the HandsFull card and the pickup sound land on this frame, and a banner in the
	-- same frame competes with them. 0.6 s puts it into a quiet screen.
	task.delay(0.6, function()
		if player.Parent then -- they may have left in the meantime
			Hints.show(player, "carryToBoat")
		end
	end)
end

-- ── Job #084: put it down ─────────────────────────────────────────────────────────────────────────
-- Carrying sets `Busy`, which disables the gun AND the axe, and until now the ONLY way out was a
-- successful deposit. With a full cargo deck that was a dead end: you could not deposit, could not
-- fight, and could not put the crate down — a run could be soft-locked until you died.
--
-- The dropped crate stays RE-LOOTABLE (user's call): nothing is destroyed, so you can stage a haul by
-- the pier and ferry it aboard in trips, and a mis-tap costs seconds instead of the whole crate.
local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "DropCarried"
dropRemote.Parent = ReplicatedStorage

-- Build a ground crate that can be picked back up. Deliberately NOT `makeCarried` — that one is welded
-- to the player and massless. This is a free-standing object with its own prompt.
local function makeDropped(resource: string, cf: CFrame): Model
	local crate: Model
	local source = campFloraLib[CampDefs.MODEL.barrel]
	if source and source:IsA("Model") then
		crate = source:Clone()
		crate:ScaleTo(0.5) -- same size it was on the player's shoulder
		crate:PivotTo(cf)
	else
		crate = Instance.new("Model")
		local box = Instance.new("Part")
		box.Name = "Crate"
		box.Size = Vector3.new(3, 3, 3)
		box.Color = Color3.fromRGB(150, 120, 70)
		box.Material = Enum.Material.WoodPlanks
		box.CFrame = cf
		box.Parent = crate
		crate.PrimaryPart = box
	end
	crate.Name = "DroppedCrate"
	crate:SetAttribute("Resource", resource)
	-- ⚠️ ANCHORED. A dynamic crate on the boat's deck slides off the moment the boat turns, and a
	-- dynamic crate on a river bank rolls into the water. Anchoring it is also what makes dropping on
	-- the deck safe at all — the deck is a moving platform, and an unanchored crate is not carried by it
	-- reliably (see the held-item drift in `InventoryService`).
	for _, d in ipairs(crate:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false -- never a snag hazard underfoot on a 14-stud-wide deck
			d.CastShadow = false
		end
	end
	crate.Parent = Workspace
	return crate
end

local function dropCarried(player: Player)
	local carried = carrying[player]
	if not carried then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local resource = (carried:GetAttribute("Resource") :: string?) or "Metal"

	-- "where you stand": just in front of the player's feet, so it never lands inside them.
	local at = if root then root.CFrame * CFrame.new(0, -1.5, -3) else CFrame.new(0, CLEAR_Y, 0)
	local crate = makeDropped(resource, at)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LootPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = resource
	prompt.HoldDuration = 0.4 -- quicker than a camp crate (1.2): you already earned this one
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = promptAnchor(crate, 3)
	prompt.Triggered:Connect(function(taker: Player)
		pickupLoot(taker, crate)
	end)

	carried:Destroy()
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	if char then
		char:SetAttribute("Carrying", nil)
	end
	refreshDeposit()
end

dropRemote.OnServerEvent:Connect(function(player: Player)
	dropCarried(player) -- no payload to validate; the server decides entirely from its own state
end)

-- Job #078: camp guards go through the SAME `EnemyRig` builder the river threats use.
--
-- ⚠️ They used to have their own greybox path here — a bare `block("Body", …)` with **no glowing eyes**,
-- while `EnemyServer` gave every river creature eyes since Job 039. Two builders for one creature meant
-- a Panther model would have fixed the riverbank ambushers and left every camp guard a grey box.
-- The model is still named `CampGuard` (Job 053's AI, the tag and the leash all key off that) but its
-- body, eyes, animations and sounds are the **Bandit's** — a human raider, which is what should be
-- guarding a camp of loot crates and sandbags. Stats are the old Panther's, unchanged.
-- ⚠️ `strength` is a MULTIPLIER on this guard's HP and bite, not a new stat block. It comes from the
-- village's ordinal (see `VILLAGE_STRENGTH_STEP`), so the same Bandit gets tougher the further downriver
-- you meet him. `EnemyDefs.Defs.Bandit` itself is never mutated — a shared table edited per-spawn would
-- leak the buff onto every camp built afterwards, including earlier ones on a re-dress.
-- ⚠️ Job #086: `guardType` selects the def. Camps used to be Bandit-only; wolves moved here off the
-- riverbank pool (user direction: "wolves should be in bases"), so a camp's roster is now mixed. The
-- type is written to a `GuardType` attribute rather than held in a side table, because `tickGuard`
-- runs off the `CampGuard` TAG and would otherwise have no way back to the def for a given model.
-- 🔴 Job #090: SEAT THE GUARD ON THE MEASURED FLOOR, NOT ON `CLEAR_Y`.
--
-- Guards used to be built at `anchorPos.Y` (which is `campPos.Y`, i.e. bare `CLEAR_Y` = 15) and then
-- held there by `tickGuard`. Measured live in Play on 2026-08-17: body bottom **15.00**, terrain
-- underneath **18.00** — every camp guard stood **3 studs underground**, which on a 5.49-tall Wolf is
-- buried past the shoulders. Reported as "Bandit is half ground… same with wolf".
--
-- This is the exact failure `groundAt()` was written for, and its own comments already spell out the
-- 3-stud number: the basin is CARVED to `CLEAR_Y` but terrain voxels snap to the RES=4 grid, so the
-- real walkable surface measures ~17–18. Every camp PROP has gone through `groundAt` since Job #077.
-- Guards were the one thing that never did.
--
-- ⚠️ NOT a Job #088 regression. #088 aligned the VISUAL to the hitbox and that is verified still
-- correct here (visual bottom == body bottom, exactly). #088 fixed visual-vs-hitbox; nothing had ever
-- seated the hitbox itself to the ground.
--
-- The seated Y is stored in `guardState.anchor` and is the single source of truth from then on —
-- `tickGuard` reads it rather than recomputing, so no raycast runs per guard per frame.
-- ⚠️ Job #100 — `postPos` is how a reinforcement WALKS IN.
--
-- `tickGuard` moves a guard toward `st.anchor` whenever it has no target. So a reinforcement that spawns
-- at `anchorPos` (outside the perimeter) with its anchor set to `postPos` (a station inside the camp)
-- walks in by itself, through the existing, well-tested movement code — no second navigation system.
--
-- ⚠️ Deliberately NOT PathfindingService. The plan called for pathing with a "walk straight at it if the
-- path fails" fallback; direct steering IS that fallback, every other guard in the game already uses it,
-- and a camp sits in a basin that has been carved flat and re-cleared to 130 studs, so there is nothing
-- to route around. Adding a second movement model for one spawn path would be inconsistency, not rigour.
local function spawnGuard(
	anchorPos: Vector3,
	parent: Instance,
	strength: number?,
	guardType: string?,
	campPos: Vector3?, -- Job #090: which CAMP this guard belongs to, for the alert pull
	postPos: Vector3? -- Job #100: where it should END UP, if that differs from where it spawns
)
	local typeName = guardType or "Bandit"
	local def = EnemyDefs.Defs[typeName] or EnemyDefs.Defs.Bandit
	local footY = groundAt(anchorPos.X, anchorPos.Z)
	local guard = EnemyRig.build(def, Vector3.new(anchorPos.X, footY + def.size.Y / 2, anchorPos.Z), parent)
	guard.Name = "CampGuard"
	guard:SetAttribute("GuardType", typeName)
	CollectionService:AddTag(guard, "CampGuard")
	local mul = strength or 1
	if mul ~= 1 then
		-- `EnemyRig.build` has already written HP/MaxHP from the def; scale what it wrote.
		local hp = math.floor(def.hp * mul + 0.5)
		guard:SetAttribute("HP", hp)
		guard:SetAttribute("MaxHP", hp)
		-- read back by the bite in `tickGuard`, which falls back to `def.biteDamage` when unset
		guard:SetAttribute("BiteDamage", math.floor(def.biteDamage * mul + 0.5))
	end
	-- `anchor.Y` is now the MEASURED seated height (see the header above), and `tickGuard` uses it as the
	-- one Y a guard ever occupies. The basin is carved flat, so one measurement covers the whole leash.
	-- The anchor is the guard's HOME, which is not always where it appeared (see the postPos note above).
	local home = postPos or anchorPos
	local st: GuardState = {
		biteTimer = def.biteCooldown,
		anchor = Vector3.new(home.X, footY + def.size.Y / 2, home.Z),
		camp = campPos,
		lastHP = (guard:GetAttribute("HP") :: number?) or def.hp,
	}
	-- 🔴 Job #102 — WITHOUT THIS A REINFORCEMENT NEVER WALKS ANYWHERE; IT POPS IN AT THE FENCE LINE.
	--
	-- The requirement is *"they come from side to camp to their position"*, and Job #100 built the two
	-- halves for it — spawn beyond the perimeter, `postPos` inside — but not the third. `tickGuard` clamps
	-- every step to `GUARD_LEASH` = 55 studs from `st.anchor`, and for a reinforcement the anchor is its
	-- POST, not where it spawned. Entries are 96–114 studs from the camp centre and posts are 35–65, so
	-- spawn-to-post is routinely well over 55 — and the clamp is not a speed limit, it is a hard
	-- reposition. On the guard's very FIRST Heartbeat it is moved onto the 55-stud sphere around its post,
	-- 40–120 studs in one frame. The player never sees it approach; it appears at the barricade.
	--
	-- So a reinforcement carries its own wider leash until it has actually made the walk. It is cleared on
	-- arrival (see `tickGuard`), so this buys exactly one trip and never a permanently roomier guard.
	if postPos then
		local trek = (Vector3.new(anchorPos.X, 0, anchorPos.Z) - Vector3.new(postPos.X, 0, postPos.Z)).Magnitude
		if trek > GUARD_LEASH then
			st.entryLeash = trek + 6 -- a little slack, so the clamp never nips at it en route
		end
	end
	guardState[guard] = st

	-- Job #090: ANY damage from ANY range pulls the whole camp. Hooked to the HP attribute rather than
	-- to each weapon, because three separate call sites deal enemy damage (`GunServer`, `WeaponServer`,
	-- `MeleeServer`) and a fourth would silently miss this. Watching the attribute catches them all,
	-- including anything added later.
	-- ⚠️ Decrease only — `lastHP` is what distinguishes a hit from the strength multiplier written just
	-- above, and from any future heal.
	guard:GetAttributeChangedSignal("HP"):Connect(function()
		local now = (guard:GetAttribute("HP") :: number?) or 0
		local was = st.lastHP or now
		st.lastHP = now
		if now < was then
			local body = guard.PrimaryPart
			alertNear(st.camp, body and body.Position or nil)
		end
	end)

	-- Job #100: returned so a reinforcement can be told which post to walk to after spawning outside.
	return guard
end

-- ── Putting the Bazooka in his hands (Job #119, requirement 2) ───────────────────────────────────
-- 🔴 THE POSE IS SOLVED AGAINST THE **POSED** HAND, AND THAT IS COPIED FROM `InventoryService`,
-- NOT INVENTED HERE. `WeaponAssets`' header records THREE separate failed attempts at storing a
-- hand-relative angle instead — averaging across the ±180° wrap, a term silently vanishing on read-back,
-- and a value that round-tripped at 0.00° error and was still ~67° off. Its conclusion is that each weapon
-- declares the orientation it wants in CHARACTER space and the hand-relative offset is derived at weld
-- time from the live hand:
--       rot = handRotation⁻¹ · characterRotation · holdInChar
--
-- ⚠️ WHICH IS WHY THIS CANNOT BE BAKED INTO THE LIBRARY MODEL. `idle` for the Rocket Man is
-- `ItemDefs.HOLD_ANIM` — the same carry pose that "rotates the forearm ~90°, so anything authored against
-- the old arms-down stance broke the moment it went in". A C0 measured on the rest pose is wrong the
-- instant that clip starts. So it waits for the animation to actually pose the rig, then solves.
--
-- 🔴 AND A MOTOR6D, NOT A WELDCONSTRAINT — Job #084 shipped that bug and wrote it down: *"weapon and lamp
-- flys away from boat when move, they are like drifting"*. `RightHand` is an ANIMATED limb driven by the
-- Animator's Motor6Ds; a WeldConstraint is a physics constraint forever chasing a limb whose motion comes
-- from elsewhere. A Motor6D IS a rig joint, transformed alongside the limb. It is also exactly how a
-- Roblox `Tool` attaches its Handle.
local function equipBazooka(guard: Model)
	local art = WeaponAssets.ART.Bazooka
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local weapons = lib and lib:FindFirstChild("Weapons")
	local source = weapons and weapons:FindFirstChild(art.model or "Bazooka")
	if not (source and source:IsA("BasePart")) then
		warn("[RocketMan] AssetLibrary.Weapons.Bazooka missing — he will shell you empty-handed")
		return
	end
	local visual = guard:FindFirstChild("Visual")
	local hand = visual and visual:FindFirstChild("RightHand", true)
	local root = visual and visual:FindFirstChild("HumanoidRootPart", true)
	if not (hand and hand:IsA("BasePart") and root and root:IsA("BasePart")) then
		warn("[RocketMan] rig has no RightHand/HumanoidRootPart — no launcher welded")
		return
	end

	local clone = (source :: BasePart):Clone()
	clone.Name = "HeldItem"
	-- Matches what `EnemyRig` did to every other part of this rig: unanchored + massless so the joint
	-- carries it and it cannot sag the rig, non-colliding and non-queryable so it neither shoves the
	-- player nor blocks anyone's bullets, and shadow-free like the tower it stands on.
	clone.Anchored = false
	clone.Massless = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CastShadow = false
	if art.scale and math.abs(art.scale - 1) > 1e-3 then
		clone.Size *= art.scale -- 5.548 → a 6.50-stud launcher, longer than the M16 on purpose
	end

	local rot: CFrame
	if art.holdInChar then
		local handRot = hand.CFrame - hand.CFrame.Position
		local charRot = root.CFrame - root.CFrame.Position
		rot = handRot:Inverse() * charRot * art.holdInChar
	else
		rot = CFrame.Angles(0, math.rad(art.yawOffset or 0), 0)
	end
	local grip = art.gripOffset or Vector3.zero
	-- ⚠️ Rotation BEFORE the grip translation: `-grip` is expressed in the ROTATED frame, which is what
	-- keeps the model's grip point in the fist however it is angled. Swap the order and it slides out.
	clone.CFrame = hand.CFrame * rot * CFrame.new(-grip.X, -grip.Y, -grip.Z)
	clone.Parent = visual

	local joint = Instance.new("Motor6D")
	joint.Name = "HeldGrip"
	joint.Part0 = hand
	joint.Part1 = clone
	-- Preserve the pose solved above EXACTLY: Part0.CFrame * C0 == Part1.CFrame * C1 with C1 identity.
	joint.C0 = hand.CFrame:ToObjectSpace(clone.CFrame)
	joint.Parent = hand
end

-- ── The Rocket Man — Job #119 ─────────────────────────────────────────────────────────────────────
-- *"Each camp will have one new enemie. This will be rocket man, who fires with bazooka… he shoots with
-- 20 s intervals… You have some seconds to escape red circle… if you get close to enemy, you go into
-- close combat… rocket mans only spawn at tower top."*
--
-- He is built through `spawnGuard` like every other camp guard, and that is deliberate: it is what gets
-- him the `CampGuard` TAG, and the tag is what makes the player's four damage paths able to touch him at
-- all — `WeaponServer` (handheld hitscan), `GunServer` (the boat turret), `MeleeServer` (the axe) and
-- `Rocket.TARGET_TAGS` (your own bazooka), plus his health bar (`EnemyHealthBars`). A bespoke tag would
-- have meant editing all five and hoping none was missed.
--
-- 🔴 AND THEN HE IS EXEMPTED FROM ALMOST EVERYTHING THAT TAG NORMALLY IMPLIES:
--   · `tickGuard` returns early for him before any seat/step/leash/chase-slot logic runs (see there).
--   · He is NOT appended to `garrisons`, so he never respawns — the owner's call, and the same
--     deliberate omission `placeHutBandits` documents. Nothing to do; just do not add it.
--   · The garrison respawn loop SKIPS him when it counts a camp's strength. Without that he inflates the
--     deep camp's garrison by one for as long as he lives — and then, the moment you kill him, the count
--     drops and the loop sends a Bandit up to replace him, which is the exact opposite of "kill him once
--     and the tower is yours".
--
-- ⚠️ `padPos` MUST BE READ FROM THE PLACED CLONE, NEVER COMPUTED FROM THE LIBRARY MODEL.
-- `prop` multiplies the tower's scale by `CampDefs.SCALE.RangerTower` (0.85) BEFORE `PivotTo`, and
-- `Model:ScaleTo` moves part POSITIONS about the pivot as well as resizing them — so the pad's 43.69
-- studs above the base become ~37.1, and its (-0.91, -8.09) offset becomes (-0.77, -6.88). Then
-- `faceTo = firePos` ROTATES that offset, and `seatOnGround`'s 0.3-stud sink drops the lot again. Every
-- hardcoded number about these pads is wrong at runtime. The caller hands us the live CFrame.
local function spawnRocketMan(
	pad: BasePart,
	tower: Model,
	parent: Instance,
	strength: number?,
	campPos: Vector3?
): Model?
	local R = CampDefs.TOWER.rocketMan
	local def = EnemyDefs.Defs[R.type]
	if not def then
		warn(("[Excursion] no EnemyDefs entry %q — no rocket man on this tower"):format(R.type))
		return nil
	end
	local padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	-- `spawnGuard` seats on TERRAIN (`groundAt`), i.e. on the dirt 36 studs below the deck — exactly the
	-- problem `placeHutBandits` has with hut floors. Built there, then lifted onto the platform.
	local guard = spawnGuard(Vector3.new(padTop.X, padTop.Y, padTop.Z), parent, strength, R.type, campPos)
	local st = guardState[guard]
	if not st then
		return nil -- `spawnGuard` always registers state; this only fires if that ever changes
	end

	local stand = Vector3.new(padTop.X, padTop.Y + def.size.Y / 2, padTop.Z)
	-- Face the way the pad faces. The owner placed the pad out by the railing, so its own forward is the
	-- direction that looks over the camp — better than guessing at the approach, and it means moving the
	-- pad in the editor re-aims him with no code change.
	local yaw = math.atan2(pad.CFrame.LookVector.X, pad.CFrame.LookVector.Z)
	guard:PivotTo(CFrame.new(stand) * CFrame.Angles(0, yaw, 0))

	st.anchor = stand
	st.pin = stand -- 🔴 the one position he ever occupies. See `GuardState.pin` for why this is not a perch
	st.pinYaw = yaw
	st.tower = tower
	st.fireTimer = 0
	st.aggroRadius = def.aggroRadius
	-- 🔴 THE ATTRIBUTE IS THE SWITCH, and it is on the MODEL rather than in `guardState` on purpose:
	-- `tickGuard` runs off the `CampGuard` tag, and the garrison respawn loop counts off that tag too —
	-- neither has a `guardState` handle at the point it needs to ask "is this the rocket man?".
	guard:SetAttribute("RocketMan", true)

	-- ⚠️ THE LAUNCHER IS WELDED LATE, ON PURPOSE. See `equipBazooka`: the grip is solved against the hand
	-- as the `idle` carry clip poses it, and that clip is only started by `tickRocketMan`'s first
	-- `setMotion`, which happens on the next Heartbeat. Welding here would measure the rest pose and put
	-- the launcher wherever the arms-down stance had the wrist.
	task.spawn(function()
		for _ = 1, 8 do
			RunService.Heartbeat:Wait() -- a few frames for the Animator to actually move the arm
		end
		if guard.Parent then -- the landing site can be culled mid-wait
			equipBazooka(guard)
		end
	end)

	print(("[RocketMan] posted at %s (deck y=%.2f, %.0f studs up)"):format(
		tostring(stand), padTop.Y, padTop.Y - (groundAt(padTop.X, padTop.Z) or padTop.Y)))
	return guard
end

-- Put a prop on a tower pad: on the DECK, at the pad, not on the ground under it.
--
-- ⚠️ IT CANNOT GO THROUGH `prop()`. That function ends with
-- `FoliageDefs.seatOnGround(clone, groundAt(x, z), …)` — it would drop the crate 36 studs down onto the
-- terrain beneath the tower, which is where a chest placed "at the tower" would silently end up.
local function placeOnPad(modelName: string, pad: BasePart, parent: Instance, scale: number?): PVInstance?
	local source = campFloraLib[modelName]
	if not source then
		warn(("[Excursion] AssetLibrary has no %q — tower pad left empty"):format(modelName))
		return nil
	end
	local clone = source:Clone()
	local parts = clone:GetDescendants()
	table.insert(parts, clone) -- a MeshPart source IS the part
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true -- you walk around it on a 20x20 deck
			d.CastShadow = false -- the tower itself is placed shadow-off; a crate on it should match
		end
	end
	local s = (CampDefs.SCALE[modelName] or 1) * (scale or 1)
	if math.abs(s - 1) > 1e-3 then
		if clone:IsA("Model") then
			clone:ScaleTo(clone:GetScale() * s) -- RELATIVE: the importer bakes a scale into these models
		elseif clone:IsA("BasePart") then
			clone.Size *= s
		end
	end
	-- Sit its own measured bottom on the pad's top face, and face it the way the pad faces.
	local padTopY = pad.Position.Y + pad.Size.Y / 2
	local yaw = math.atan2(pad.CFrame.LookVector.X, pad.CFrame.LookVector.Z)
	clone:PivotTo(CFrame.new(pad.Position.X, pad.Position.Y, pad.Position.Z) * CFrame.Angles(0, yaw, 0))
	local bottom = FoliageDefs.worldBottom(clone)
	if bottom then
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, padTopY - bottom, 0))
	end
	clone.Parent = parent
	return clone
end

-- The two marker pads inside a placed tower, made safe and handed back.
--
-- 🔴 THE `CanCollide`/`CanQuery` WRITES ARE A BUG FIX, NOT TIDINESS.
-- The owner authored both pads `Transparency = 1`, but `prop` applies `d.CanCollide = o.collide == true`
-- to EVERY BasePart in the clone and the tower is placed with `collide = true` (you climb it). So without
-- this they arrive as **invisible collidable slabs** standing 1 stud proud of the deck. `CanQuery` is a
-- separate and less obvious hazard: `GroundRing`'s header lists four unrelated systems a stray queryable
-- part breaks, and one of them is `HudState`'s 8-stud downward "am I aboard?" probe, which would read a
-- pad underfoot as ground.
local function towerPads(tower: Model): (BasePart?, BasePart?)
	local P = CampDefs.TOWER.pad
	-- Searched recursively (`true`): the pads live inside the model's `Tower` child, and a later editor
	-- re-organise must not silently un-man every tower in the game.
	local defender = tower:FindFirstChild(P.defender, true)
	local chest = tower:FindFirstChild(P.chest, true)
	for _, p in ipairs({ defender, chest }) do
		if p and p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1 -- re-asserted: these are markers, never geometry
			p.CastShadow = false
		end
	end
	return (if defender and defender:IsA("BasePart") then defender else nil),
		(if chest and chest:IsA("BasePart") then chest else nil)
end

-- The `LootPrompt` wiring, identical for every kind of crate. Name, hold duration, activation distance
-- and the `Triggered` → `pickupLoot` connection are all exactly what the greybox had — only the object
-- the prompt hangs off changed.
local function lootPrompt(crate: PVInstance, actionText: string)
	local loot = Instance.new("ProximityPrompt")
	loot.Name = "LootPrompt"
	loot.ActionText = actionText
	loot.ObjectText = "Crate"
	loot.HoldDuration = 1.2
	loot.RequiresLineOfSight = false
	-- ⚠️ Job #101: 10 was too tight ONCE THE CAMPS GREW. A camp is now ~150 studs across and dressed with
	-- barrels identical to the loot, so a 10-stud prompt meant walking up to every barrel to find out
	-- which one was real — and a missed gasoline strands the run, because the near camp is the only fuel
	-- source. 14 is deliberately modest: the outline from `LootGlow` is what does the finding, the prompt
	-- just should not require you to stand on top of it.
	loot.MaxActivationDistance = 14
	loot.Parent = promptAnchor(crate, 3)
	-- The client outlines this tag, and only this tag. Both halves of "which barrel is real" are fixed
	-- here: the prompt says WHAT it is, the tag makes it visible that there is anything to read.
	CollectionService:AddTag(crate, CampDefs.TAG.lootable)
	loot.Triggered:Connect(function(player: Player)
		pickupLoot(player, crate)
	end)
end

-- ── the camp (Job #077) ───────────────────────────────────────────────────────────────────────────
-- Was: two coloured `Hut` blocks and up to three tinted 4×4×4 cubes at hardcoded world offsets.
--
-- The offsets could not survive the swap — `Tent` is 43×34 studs against the 10×10 block it replaces —
-- so the layout is re-derived from `CampDefs.LAYOUT` in a frame oriented on `approach`, the direction the
-- player walks in from the dock. That is what makes "everything faces the way you arrive" true on both
-- banks of the river without a per-camp table.
--
-- ⚠️ ONE THING DELIBERATELY LOST: the greybox tinted each crate by resource (yellow gasoline, grey
-- metal). Real wooden barrels cannot carry that without the neon-prop look STYLEGUIDE §12 forbids, so
-- what is in a crate is now read off its `LootPrompt` ActionText ("Loot Gasoline") on approach instead of
-- its colour at distance. If that turns out to matter in play, the fix is a small painted stencil or a
-- resource icon on the crate — NOT re-tinting the whole barrel.
local function buildCampAt(
	campPos: Vector3,
	parent: Instance,
	guards: number,
	resources: { string },
	kind: CampDefs.CampKind,
	approach: Vector3,
	rng: Random,
	strength: number?, -- per-village HP/bite multiplier; nil = 1 (village 1)
	-- Job #119: is this the TUTORIAL landing? Only `CampDefs.TOWER.rocketMan.skipFirstLanding` reads it.
	-- ⚠️ It exists because Job #102 hardcoded landing 1 to 1 near / 2 deep guards for an ONBOARDING reason
	-- that is written out in full at that override — *"first time players just confused when 2 attack same
	-- time"*, "first contact has to be legible". A ranged attacker who shells you from a tower before you
	-- have learned that going ashore is a thing at all is squarely inside that concern, so the tutorial
	-- landing gets no rocket man by default. Flip the flag in `CampDefs` to put one there.
	firstLanding: boolean?
): Garrison
	-- ⚠️ Job #100 — the layout is GENERATED now, not read from one fixed table.
	--
	-- `CampDefs.LAYOUT` was a single slot list shared by every camp in the game, which is exactly why
	-- camps read the same twice in a row. `CampLayout.generate` produces a per-camp arrangement from the
	-- run seed while keeping the three rules that make a camp legible: fire at centre, everything faces
	-- the approach, loot behind cover. See that module's header.
	--
	-- Seeded from the camp's own position so it is deterministic and reproducible: the same run puts the
	-- same camp in the same shape, and a reported layout bug can be regenerated exactly.
	local L = CampLayout.forCamp(campPos, {
		seed = math.floor(campPos.X * 31 + campPos.Z * 17),
		kind = kind,
		resourceCount = #resources,
		deep = kind == CampDefs.KIND.deep,
	})
	local function at(slot: CampDefs.Slot): Vector3
		return CampDefs.slotToWorld(campPos, approach, slot)
	end
	-- a point back down the path, for everything that should face the way the player arrives
	local approachFrom = campPos - approach * 80

	-- 🔴 RE-CLEAR THE CAMP FOOTPRINT FIRST. `carve` is measurably imperfect — ~2.5% of columns survive
	-- above y=21 as stumps of the original hillside. Anywhere else in the basin that is just scenery, but
	-- a stump inside a camp is a rock spike in the middle of the clearing AND it makes any prop that
	-- lands on it seat 15 studs in the air (the floating Tent/Barrel/AmmoBox). One extra pair of fills
	-- per camp is far cheaper than trying to make the basin-wide carve perfect.
	--
	-- Safe from the river by construction: camps sit 120 and 300 studs inland, and this reaches 65.
	-- ⚠️ MUST MATCH `CampLayout.FOOT_LIMIT` (= FOOT/2). The layout places the perimeter out at its
	-- radius; carve a smaller basin than the layout plans for and the fence climbs the uncarved jungle.
	local FOOT = 160
	Terrain:FillBlock(CFrame.new(campPos.X, CLEAR_Y - 20, campPos.Z), Vector3.new(FOOT, 40, FOOT), CampDefs.GROUND.base)
	Terrain:FillBlock(CFrame.new(campPos.X, CLEAR_Y + 32, campPos.Z), Vector3.new(FOOT, 64, FOOT), Enum.Material.Air)

	-- ground next: props raycast the terrain to seat themselves, so paint before you place.
	paintTrampled(campPos, approach, L)
	settleTerrain()

	-- The fire is the centre. Placed first; everything else is positioned relative to it.
	local firePos = at(L.fire)
	local fireGround = groundAt(firePos.X, firePos.Z)
	Campfire.build({
		position = Vector3.new(firePos.X, fireGround, firePos.Z),
		parent = parent,
		lib = campFloraLib,
		rng = rng,
	})

	-- Living quarters at the back, facing the fire — now 3–5 of them in generated positions rather than
	-- exactly one hut and one tent at fixed offsets. `kind.hut` still wins for the first building so the
	-- near/deep camps keep their distinct silhouettes.
	local hutAt = campPos
	for i, b in ipairs(L.buildings) do
		local p = at(b.slot)
		local model = if i == 1 then kind.hut else b.model
		prop(model, p.X, p.Z, parent, { collide = true, faceTo = firePos })
		if i == 1 then
			hutAt = p -- CampAmbience dresses around the first building
		end
	end

	-- The sandbag line, across the approach. This is the piece of dressing that does real gameplay work:
	-- cover between the player and the crates is what makes the guards matter.
	-- Job #100: a RING with 2–3 gaps, not a 3-piece line across the front. Which opening you come in
	-- through is now a choice — front door into the posts, or the long way round to the loot. Each
	-- segment is a 1-part SandbagWall, so the ring is cheap; the cost of a bigger camp is in buildings.
	if kind.sandbags then
		for _, slot in ipairs(L.perimeter) do
			local p = at(slot)
			-- face each segment outward, away from the fire: a wall you shelter behind, not a fence
			prop(CampDefs.MODEL.sandbag, p.X, p.Z, parent, { collide = true, faceTo = firePos })
		end
	end

	-- Loot BEHIND that line. Index 1 is the hero `CrateWood` — 66 instances, so exactly ONE per camp;
	-- everything after it is a 6-instance `Barrel`. That single choice is ~90% of the part cost the
	-- all-CrateWood version would have carried.
	for i, res in ipairs(resources) do
		local slot = L.loot[i] or L.loot[#L.loot]
		local p = at(slot)
		local model = prop(
			if i == 1 then CampDefs.MODEL.crate else CampDefs.MODEL.barrel,
			p.X,
			p.Z,
			parent,
			{ collide = true, faceTo = approachFrom }
		)
		if model then
			model.Name = "LootCrate"
			model:SetAttribute("Resource", res)
			lootPrompt(model, "Loot " .. res)
		end
	end

	-- A landmark you can see from the water, marking the stops that open a jungle basin.
	-- ⚠️ 128 parts, and shadows explicitly OFF: 128 shadow casters at every landing would be the most
	-- expensive single object in the scene, for an effect nobody looks at.
	-- `L.tower` is optional now (the generator only produces it when kind.tower is set), so the nil
	-- check is on the slot itself rather than on the flag.
	local towerSlot = L.tower
	if kind.tower and towerSlot then
		local t = at(towerSlot)
		-- 🔴 Job #119: THE RETURN VALUE IS KEPT NOW. It used to be discarded, and two things need it:
		--   1. the `Defender`/`InnerPlace` marker pads live inside THIS clone, and their world CFrames are
		--      the only honest source of where the deck is (scale, sink and yaw all move them);
		--   2. the tower must be excluded from the Rocket Man's own aim ray, or `Ballistics.resolveImpact`
		--      returns the first thing the ray hits — which, firing down at someone near the base, is his
		--      own railing, floor edge or stairs. `prop` set all 128 of those parts `CanCollide = true`
		--      and left `CanQuery` alone, so every one of them is a ray-blocker.
		local towerInst = prop(CampDefs.MODEL.tower, t.X, t.Z, parent, { collide = true, shadow = false, faceTo = firePos })
		local tower = if towerInst and towerInst:IsA("Model") then towerInst :: Model else nil
		if tower then
			local defenderPad, chestPad = towerPads(tower)

			-- The loot chest, on EVERY tower (owner's call) — the reward for a 36-stud climb.
			if chestPad then
				local C = CampDefs.TOWER.chest
				local crate = placeOnPad(C.model, chestPad, parent, C.scale)
				if crate then
					crate.Name = "LootCrate"
					crate:SetAttribute("Kind", "Salvage")
					crate:SetAttribute("Amount", rng:NextInteger(C.salvage[1], C.salvage[2]))
					lootPrompt(crate, "Search")
				end
			else
				warn(("[Excursion] tower has no %q pad — no chest on this platform")
					:format(CampDefs.TOWER.pad.chest))
			end

			-- The Rocket Man, on this camp kind only — which is what makes it ONE per landing site.
			local R = CampDefs.TOWER.rocketMan
			if kind.name == R.onKind and not (R.skipFirstLanding and firstLanding) then
				if defenderPad then
					spawnRocketMan(defenderPad, tower, parent, strength, campPos)
				else
					warn(("[Excursion] tower has no %q pad — no rocket man on this tower")
						:format(CampDefs.TOWER.pad.defender))
				end
			end
		end
	end

	-- Loose dressing so the camp isn't only functional objects. Non-colliding: a firefight in a camp
	-- must not become a maze of invisible walls.
	for _, d in ipairs(L.dressing) do
		local p = at(d.slot)
		prop(d.model, p.X, p.Z, parent, {
			collide = false,
			yaw = d.yaw or rng:NextNumber(0, math.pi * 2),
			scale = d.scale or rng:NextNumber(0.85, 1.15),
		})
	end

	-- Job #100 follow-up — rocks, logs and undergrowth inside the camp. Reported as *"it feels empty,
	-- just houses, some trees and that's it"*. Rocks and logs COLLIDE (they are cover, and a camp fight
	-- with things to duck behind is a better fight); undergrowth does not, so the place never becomes a
	-- maze of invisible walls. `faceFire` carries the collide flag from the generator.
	for _, a in ipairs(L.ambient) do
		local p = at(a.slot)
		prop(a.model, p.X, p.Z, parent, {
			collide = a.faceFire == true,
			yaw = a.yaw or rng:NextNumber(0, math.pi * 2),
			scale = a.scale or 1,
		})
	end

	CampAmbience.dress({
		centre = Vector3.new(firePos.X, fireGround, firePos.Z),
		approach = approach,
		parent = parent,
		groundY = fireGround,
		hutPos = Vector3.new(hutAt.X, groundAt(hutAt.X, hutAt.Z), hutAt.Z),
	})

	-- ⚠️ SPAWN POSITIONS UNCHANGED, AND THEY MUST STAY UNCHANGED. Job #058 tunes difficulty by crew size
	-- against these exact positions. The 2026-08-16 village ramp changes the COUNT and the STRENGTH that
	-- reach here; it does not move where a guard stands.
	-- Job #086: the roster is now MIXED. The NEAR camp stays all-Bandit — it is the human raider outpost,
	-- the one with the sandbags and the landing tower. The DEEP camp, which holds the Metal and Ammo the
	-- crew actually needs, gets at least one Wolf. The TOTAL count is untouched (see the warning above):
	-- this only decides what each of those guards is, so Job #058's crew-size tuning still holds.
	local wolves = if kind == CampDefs.KIND.deep then math.max(1, math.floor(guards / 3)) else 0
	for i = 1, guards do
		-- ⚠️ Job #100 — the GARRISON now stands at generated posts around the camp instead of in a row
		-- 8 studs in front of the player. It still spawns at build time, so it is visible on approach and
		-- never materialises in someone's face; only REINFORCEMENTS come from outside (see the loop).
		--
		-- Guard COUNT and the Wolf/Bandit mix are untouched — Job #058's crew-size tuning is measured
		-- against those, and this job deliberately moves only WHERE they stand and WHEN they arrive.
		local post = L.posts[((i - 1) % math.max(#L.posts, 1)) + 1]
		local at3 = if post then at(post) else campPos + Vector3.new((i - 1) * 7, 0, 8)
		spawnGuard(at3, parent, strength, if i <= wolves then "Wolf" else "Bandit", campPos)
	end

	-- Job #084: remember this camp's garrison so it can be re-manned by day (see the respawn loop).
	--
	-- 🔴 Job #102 — RETURNED, NOT INSERTED, AND THAT IS A BUG FIX, NOT A TIDY-UP.
	--
	-- This used to `table.insert(garrisons, …)` right here. `buildCampAt` runs while the site `model` is
	-- still DETACHED — `model.Parent = campsRoot` is the last line of `buildLandingSite`, after both camps,
	-- the trading post and the crates. The respawn loop's first gate drops any garrison whose
	-- `g.parent.Parent` is nil, so a record inserted here is reapable for the whole rest of the build.
	--
	-- The build YIELDS in that window: `settleTerrain()` waits two frames inside the DEEP camp's own
	-- `buildCampAt`. If the loop's 5-second tick resumes in there, the NEAR camp's record is removed and
	-- that camp never re-garrisons again for the entire run — silently, with no error and no warning.
	--
	-- ⚠️ The asymmetry is the tell, and it matches the report ("at the FIRST camp"): the deep camp's record
	-- is created after the last yield in the function, so only the near camp can ever lose one.
	--
	-- So the record is handed back and `buildLandingSite` inserts it once the site is parented and can no
	-- longer be mistaken for a culled one. Do not move this back inline.
	return {
		campPos = campPos,
		parent = parent,
		target = guards,
		wolves = wolves, -- Job #086: so a re-manned garrison keeps its mix instead of drifting all-Bandit
		strength = strength,
		timer = 0,
		-- Job #100: where reinforcements walk IN from, and where they walk TO.
		approach = approach,
		spawns = L.spawns,
		posts = L.posts,
	}
end

-- a loadout crate: Kind "Weapon" (grants a gun to a slot) or "Ammo" (tops up that gun's ammo). No carry.
-- Job #077: `AmmoBox` (22 parts) — a military crate, which is what a weapon cache should look like next
-- to the wooden barrels of the resource pile.
local function makeKindCrate(pos: Vector3, kind: string, id: string, actionText: string, parent: Instance, faceTo: Vector3)
	local crate = prop(CampDefs.MODEL.weaponCrate, pos.X, pos.Z, parent, { collide = true, faceTo = faceTo })
	if not crate then
		return
	end
	crate.Name = "LootCrate"
	crate:SetAttribute("Kind", kind)
	crate:SetAttribute("Id", id)
	lootPrompt(crate, actionText)
end

-- ── the outlying village (Job #108, corrected in #109) ────────────────────────────────────────────
-- One hut somewhere in the basin, outside both camps. `VillageLayout` decided WHERE, which way it is
-- turned and what stands around it; this seats it, dresses it and puts something inside.
--
-- ── 🔴 THE MISTAKE THIS FUNCTION USED TO MAKE, kept because it is the useful part ─────────────────
-- Job #108 correctly worked out that a stilt house with its floor 3.5–4.6 studs up is not enterable by
-- simply being placed — and then built two wooden treads at what it had measured as the doorway. It had
-- never checked whether the model already solved this. **It does: every Bahay Kubo ships with its own
-- staircase.** So the treads were redundant, and because #108 aimed them at the widest *clear arc*
-- rather than at the stairs, they landed beside the real steps — photographed by the user as
-- *"2 strange blocks [that] block the entrance"*.
--
-- The lesson is not "check for stairs". It is that "the model cannot do X" was an ASSUMPTION presented
-- as a measurement, in a job whose whole selling point was that it measured things. The fix is one
-- deletion plus a better bearing (`CampDefs.VILLAGE.entrance`), and the hut is enterable on its own.
local function buildVillageHut(hut: VillageLayout.Hut, parent: Instance, rng: Random): Model?
	local V = CampDefs.VILLAGE
	local model = prop(hut.model, hut.x, hut.z, parent, { collide = true, yaw = hut.yaw })
	if not model or not model:IsA("Model") then
		return nil
	end
	model.Name = "VillageHut"

	-- The real base of the placed model, read back rather than assumed: `prop` seats by the model's own
	-- lowest corner and sinks it slightly, so the floor is `base + rise`, not `groundAt() + rise`.
	local base = FoliageDefs.worldBottom(model) or groundAt(hut.x, hut.z)
	local floorY = base + hut.rise
	model:SetAttribute("FloorY", floorY) -- read by the hut-bandit pass, which must stand ON the floor

	-- ── what stands around it (Job #109) ─────────────────────────────────────────────────────────
	-- *"add some rocks and getables, maybe some trees so camp feels more alive"*. Positions came from
	-- `VillageLayout`, which already kept them out of the stairs, the path and the neighbours; this just
	-- places them. Rocks and logs collide (cover), plants do not (no invisible-wall mazes).
	for _, q in ipairs(hut.props) do
		prop(q.model, q.x, q.z, parent, { collide = q.collide, yaw = q.yaw, scale = q.scale })
	end

	-- ── something inside ─────────────────────────────────────────────────────────────────────────
	-- Not in every hut: an empty one is what makes a stocked one worth the walk.
	if rng:NextNumber() > V.stash.chance then
		return model
	end
	local source = campFloraLib[V.stash.model]
	if not source then
		return model -- library incomplete; the hut still stands, it is just bare
	end
	local stash = source:Clone()
	for _, d in ipairs(stash:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- ⚠️ CanCollide OFF, deliberately. These interiors measure ~14 studs across and the doorway is
			-- one body wide; a solid barrel in there can wedge a player between it and a wall.
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	if stash:IsA("Model") then
		stash:ScaleTo(stash:GetScale() * V.stash.scale)
	end
	-- Tucked to the BACK of the interior — away from the stairs, so it is something you go in for rather
	-- than something you can reach from the top step.
	local inset = hut.stairDir * -(hut.halfDiag * 0.3)
	stash:PivotTo(CFrame.new(hut.x + inset.X, floorY, hut.z + inset.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	FoliageDefs.seatOnGround(stash, floorY, 0) -- the HUT FLOOR, not the ground it stands on
	stash.Name = "LootCrate"
	stash.Parent = model
	stash:SetAttribute("Kind", "Salvage")
	stash:SetAttribute("Amount", rng:NextInteger(V.stash.salvage[1], V.stash.salvage[2]))
	lootPrompt(stash, "Search")
	return model
end

-- ── the village yard loot (Job #109) ─────────────────────────────────────────────────────────────
-- The "getables" half of *"add some rocks and getables"*. A few small salvage barrels standing OUTSIDE
-- among the clutter, so walking the village is worth doing between doors. Deliberately worth less than
-- an interior stash (12–22 against 25–40): what you can see from the path should pay less than what you
-- had to go inside for.
local function buildYardLoot(huts: { VillageLayout.Hut }, parent: Instance, rng: Random): number
	local Y = CampDefs.VILLAGE.yardLoot
	local source = campFloraLib[Y.model]
	if not source or #huts == 0 then
		return 0
	end
	local placed = 0
	local want = rng:NextInteger(Y.perSite[1], Y.perSite[2])
	for i = 1, want do
		-- Hang each one off a hut's OWN clutter ring, so yard loot appears among the rocks rather than
		-- alone in open grass — and reuse those slots' vetting (off the path, off the neighbours).
		local hut = huts[((i - 1) % #huts) + 1]
		if #hut.props == 0 then
			continue
		end
		local q = hut.props[rng:NextInteger(1, #hut.props)]
		-- a couple of studs off the prop it keeps company with, never inside it
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = q.x + math.cos(a) * 5, q.z + math.sin(a) * 5
		local crate = prop(Y.model, x, z, parent, { collide = false, yaw = rng:NextNumber(0, math.pi * 2), scale = Y.scale })
		if crate then
			crate.Name = "LootCrate"
			crate:SetAttribute("Kind", "Salvage")
			crate:SetAttribute("Amount", rng:NextInteger(Y.salvage[1], Y.salvage[2]))
			lootPrompt(crate, "Search")
			placed += 1
		end
	end
	return placed
end

-- ── hut ambushers (Job #109) ─────────────────────────────────────────────────────────────────────
-- *"in 2 of houses spawn one bandit, so 2 additional bandits but only in one of houses randomly. He
-- just sits in house and waits."*
--
-- TWO per landing site, in two randomly chosen huts. Not two per hut; not one in every hut.
--
-- ⚠️ EACH IS ITS OWN "CAMP". `st.camp` keys both the alert pull (`alertNear`) and the chase-slot
-- budget (`campChasers`). Passing the near camp's position here would mean shooting a bandit in a hut
-- 200 studs away wakes the whole garrison, and that the two of them eat the camp's chase slots. Keying
-- them on their own hut makes each one a self-contained encounter, which is what an ambush is.
--
-- ⚠️ AND THEY ARE NOT REGISTERED IN `garrisons`. That list drives the reinforcement loop; a hut bandit
-- is a one-off, so it must never respawn. Nothing to do — just do not add it — but it is the kind of
-- omission a later reader "fixes".
local function placeHutBandits(huts: { { model: Model, hut: VillageLayout.Hut } }, parent: Instance, rng: Random, strength: number?): number
	local B = CampDefs.VILLAGE.bandits
	if #huts == 0 then
		return 0
	end
	-- Fisher-Yates over a copy, so two different huts are picked without ever retrying a collision.
	local order = table.create(#huts)
	for i = 1, #huts do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end

	local placed = 0
	for k = 1, math.min(B.count, #order) do
		local entry = huts[order[k]]
		local hut = entry.hut
		local floorY = (entry.model:GetAttribute("FloorY") :: number?)
		if not floorY then
			continue -- the hut did not report a floor; better no bandit than one buried in the dirt
		end
		-- Stand it at the BACK of the interior, away from the stairs, so it is not visible from the
		-- bottom step — the point is that you find it by going in.
		local back = hut.stairDir * -(hut.halfDiag * 0.28)
		local at = Vector3.new(hut.x + back.X, floorY, hut.z + back.Z)
		-- ⚠️ `camp` and `post` are BOTH the back-of-the-interior point, not the hut centre. `tickGuard`
		-- walks an idle guard to its anchor, so anchoring on the centre (the first cut of this) quietly
		-- slid both ambushers into the middle of the floor where they are visible from the bottom step.
		local guard = spawnGuard(at, parent, strength, B.type, at, at)
		local st = guardState[guard]
		if not st then
			continue
		end
		local def = EnemyDefs.Defs[B.type] or EnemyDefs.Defs.Bandit
		-- `spawnGuard` seated it on the TERRAIN (see `groundAt`), i.e. under the house. Lift it onto the
		-- floor and record that height as its perch; `tickGuard` holds it there until it leaves.
		local seated = floorY + def.size.Y / 2
		guard:PivotTo(CFrame.new(at.X, seated, at.Z))
		st.anchor = Vector3.new(at.X, seated, at.Z)
		st.perch, st.perchAt, st.perchRadius = seated, Vector3.new(hut.x, seated, hut.z), B.perchRadius
		st.perchModel = entry.model -- the floor it is standing on, and the thing that decides when it is out
		st.seatY, st.seatAt, st.seatAtZ = seated, at.X, at.Z
		st.aggroRadius = B.aggro
		guard:SetAttribute("HutBandit", true)
		placed += 1
	end
	return placed
end

-- ── camp foliage (Job #076) ───────────────────────────────────────────────────────────────────────
-- This used to be a 2-part box trunk + box canopy, 45 per camp. It is real models now, drawn from the
-- SAME shore-band table `FoliageServer` uses (`FoliageDefs.BANDS[1]`), so a camp clearing is planted with
-- the same vocabulary as the riverbank it sits behind and the two never drift apart.
--
-- Scoped to #076 rather than #077 on purpose: this is foliage, and leaving it greybox would have put box
-- trees at all six landings inside an otherwise real jungle. Camp STRUCTURES are #077.
local campFlora: { { model: string, scale: { number }, tiltMax: number? } } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local byName: { [string]: PVInstance } = {}
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				-- BaseParts too, not just Models — the library stores `GoldNugget` as a lone MeshPart
				if m:IsA("Model") or m:IsA("BasePart") then
					byName[m.Name] = m
				end
			end
		end
	end
	for _, e in ipairs(FoliageDefs.BANDS[1].entries) do
		if byName[e.model] then
			table.insert(campFlora, { model = e.model, scale = e.scale, tiltMax = e.tiltMax })
		end
	end
	if #campFlora == 0 then
		warn("[Excursion] no AssetLibrary foliage — camp clearings will be bare (the library is in the "
			.. "place file, not git: open the game place and save it)")
	end
	campFloraLib = byName
end

local function tree(x: number, z: number, parent: Instance, rng: Random)
	if #campFlora == 0 then
		return
	end
	local pick = campFlora[rng:NextInteger(1, #campFlora)]
	local source = campFloraLib[pick.model]
	if not source or not source:IsA("Model") then
		return -- every foliage entry is a Model; a single-part one would need the `prop` path instead
	end
	local clone = source:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false -- a camp you fight in must not be a maze of invisible collision
			d.CastShadow = false
		end
	end
	-- (no LevelOfDetail write here either — server scripts lack the Plugin capability; it is authored on
	-- the AssetLibrary source models and inherited by clones)

	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local orient = yaw
	if pick.tiltMax and pick.tiltMax > 0 then
		local a = math.rad(rng:NextNumber(0, pick.tiltMax))
		local dir = rng:NextNumber(0, math.pi * 2)
		orient = CFrame.fromAxisAngle(Vector3.new(math.cos(dir), 0, math.sin(dir)), a) * yaw
	end

	clone:ScaleTo(rng:NextNumber(pick.scale[1], pick.scale[2]))
	clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * orient)

	-- ⚠️ RAYCAST THE GROUND, DO NOT ASSUME `CLEAR_Y`. The basin is filled to CLEAR_Y (=15), but terrain
	-- voxels snap to the RES=4 grid, so the actual walkable surface is ~17 — and the first pass, which
	-- trusted CLEAR_Y, buried every camp plant by a measured 2.4 studs. Measure, don't assume.
	--
	-- ⚠️ And use `groundAt`, NOT a raw first-hit raycast. A plain raycast happily lands on one of the
	-- leftover hillside stumps `carve` leaves inside the basin, which put a `PalmCoconut` 23 studs in
	-- the air. `groundAt` rejects stumps and asks the surrounding basin instead.
	FoliageDefs.seatOnGround(clone, groundAt(x, z), 0.4)
	clone.Parent = parent

	-- The raycast above is a POINT test. Check the ground the plant actually STANDS on — a small disc,
	-- not the canopy, for the reason `groundClearFraction` documents.
	if FoliageDefs.groundClearFraction(x, z, 6, RiverData.WATER_Y, 1) > FoliageDefs.MAX_OVER_WATER then
		clone:Destroy()
	end
end

-- ── the physical shop sign (Job #077) ─────────────────────────────────────────────────────────────
-- Replaces a floating `BillboardGui`. STYLEGUIDE §5 is explicit that world signage is PHYSICAL and uses
-- `Theme.font.sign`, not screen UI — and an `AlwaysOnTop` billboard renders THROUGH the terrain and
-- through the hut it is meant to be attached to. That is the same class of bug Job #072 hit with world
-- tags visible from the plane, shipped a second time.
--
-- Built from parts rather than cloned from `EntrySign`/`WelcomeSign`: those are LOBBY scenery, and this
-- is the game place. Rather than depend on an asset that may not have been localized here, this is the
-- lobby's own proven recipe — a WoodPlanks board on two posts (`ASSETS.md` §1.3) — rebuilt in code, with
-- a `SurfaceGui` on BOTH faces so it reads from the water and from the path.
-- ⚠️ `ground` is PASSED IN, not re-probed. The sign stands on the same levelled pad as the post 16
-- studs away, and an independent probe here read 22.0 on ground that measures 17.0 — leaving the sign
-- hanging 4.7 studs up. One measurement, shared by everything on the pad.
--
-- Job #106: RETURNS THE BOARD, because the sign now carries a shop prompt of its own. See the note on
-- `shopPrompt` in `buildTradingPost` for why there are two triggers.
--
-- Job #120: the recipe itself moved to `World/WorldSign.luau` so the river piers stand the same sign.
-- This stays as the camp's named entry point — same board name, same geometry, same tokens, so the
-- `ShopPrompt` that parents to the returned board is unaffected.
local function buildShopSign(pos: Vector3, faceTo: Vector3, parent: Instance, ground: number): Part
	local board = WorldSign.build({
		position = pos,
		faceTo = faceTo,
		parent = parent,
		ground = ground,
		text = "TRADING POST",
		boardName = "ShopSign",
	})
	return board
end

-- ── the clearing ring (user direction, 2026-08-06) ────────────────────────────────────────────────
-- A landing basin must read as a CLEARING CUT INTO the jungle, not a lawn with plants dotted on it.
-- Before this, `tree()` scattered shore-band undergrowth uniformly edge to edge, so the camp had no
-- edge — and the terrain `wallBlock` rock walls that contain the basin were plainly visible as walls.
--
-- This plants two staggered rows of dense trees around the three INLAND sides, just inside the wall.
-- The water side stays open, because that is the side you arrive from and the side the dock is on.
--
-- ⚠️ NOT `JungleTreesPack`, and that was measured rather than assumed — see `CampDefs.CLEARING`. The
-- pack is 218 studs long; every placement either buried 27–45 studs of itself in the basin's rock wall
-- or landed on top of the deep camp. Individual cheap trees enclose the clearing for half the parts.
local function plantClearingRing(cx: number, cz: number, size: number, waterEdge: number, side: number, parent: Instance, rng: Random)
	local R = CampDefs.CLEARING.ring

	local pool: { any } = {}
	for _, e in ipairs(R.entries) do
		local src = campFloraLib[e.model]
		if src and src:IsA("Model") then
			for _ = 1, e.weight do
				table.insert(pool, e)
			end
		end
	end
	if #pool == 0 then
		warn("[Excursion] no ring foliage in AssetLibrary — camp clearing gets no tree ring")
		return
	end

	-- ⚠️ The bank is NOT where the dock says it is. `waterEdge` is sampled at the dock's Z, but the river
	-- MEANDERS: 170 studs up- or downstream the channel has moved, so a ring run along the basin's Z
	-- edges that trusts one sample walks straight into the water at its ends.
	local function bankAt(z: number): number
		return RiverData.centerlineX(z) + side * RiverData.widthAt(z) * 0.5
	end

	local placed, rejected = 0, 0
	local function plant(x: number, z: number)
		local pick = pool[rng:NextInteger(1, #pool)]
		-- Refuse anything whose footing is river. A point raycast is not enough (see
		-- `FoliageDefs.groundClearFraction`); the disc is the trunk's footing, not the canopy, because
		-- canopy over the water is wanted.
		if FoliageDefs.groundClearFraction(x, z, 8, RiverData.WATER_Y, 1) > FoliageDefs.MAX_OVER_WATER then
			rejected += 1
			return
		end
		local clone = (campFloraLib[pick.model] :: Model):Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				-- Non-colliding: the ring is scenery you look at, not geometry you fight through. The
				-- rock wall behind it is what actually contains the basin.
				d.CanCollide = false
				d.CastShadow = false
			end
		end
		local orient = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if pick.tiltMax and pick.tiltMax > 0 then
			local a = math.rad(rng:NextNumber(0, pick.tiltMax))
			local dir = rng:NextNumber(0, math.pi * 2)
			orient = CFrame.fromAxisAngle(Vector3.new(math.cos(dir), 0, math.sin(dir)), a) * orient
		end
		clone:ScaleTo(rng:NextNumber(pick.scale[1], pick.scale[2]))
		clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * orient)
		FoliageDefs.seatOnGround(clone, groundAt(x, z), 0.4)
		clone.Parent = parent
		placed += 1
	end

	for row = 0, R.rows - 1 do
		local inset = R.inset + row * R.rowGap
		local half = size / 2 - inset
		local stagger = (row % 2) * (R.spacing / 2) -- so you cannot see straight through the two rows
		local farX = cx + side * half

		-- the far inland edge, running along Z
		for z = cz - half, cz + half, R.spacing do
			plant(farX + rng:NextNumber(-R.jitter, R.jitter), z + stagger + rng:NextNumber(-R.jitter, R.jitter))
		end
		-- the two Z edges, running inland from the LOCAL bank
		for _, ez in ipairs({ cz - half, cz + half }) do
			local nearX = bankAt(ez) + side * inset
			local span = (farX - nearX) * side
			local t = stagger
			while t < span do
				plant(nearX + side * t + rng:NextNumber(-R.jitter, R.jitter), ez + rng:NextNumber(-R.jitter, R.jitter))
				t += R.spacing
			end
		end
	end
	print(("[Excursion] clearing ring: %d trees, %d rejected as over-water"):format(placed, rejected))
end

-- a visible market stall in the village so players can SEE where to trade (Job 023). Fires the shop panel.
--
-- Job #077: was EIGHT hand-assembled blocks — a platform, a counter, four posts and a red fabric awning.
-- It is `BahayKubo7` now: a Filipino stilt house, which is what a river-village trading post actually
-- looks like. ⚠️ 95 instances, by far the heaviest model in the job — ONE per village, never per camp.
--
-- ── Job #106: 🔴 THE SHOP PROMPT LIVES ON THE SIGN. DO NOT MOVE IT BACK TO THE COUNTER. ───────────
-- Reported as "the shop trigger is somewhere inside the house and nobody knows". Measured in Play at
-- the first landing BEFORE changing anything:
--
--     player at the sign     → dCounter 16.6, dSign  9.6 → NO prompt shown at all
--     player at the counter  → dCounter  5.1, dSign  7.3 → ShopPrompt on Counter
--
-- The cause is geometry, not wiring. `BahayKubo7` measures **40.2 x 25.8 x 50.2** studs (read from the
-- live AssetLibrary, not quoted from a comment), so its half-extent along the approach is ~20-25 — and
-- the `Counter` anchor sits at `approach * 10`, i.e. UNDER THE STILT HOUSE'S DECK. At the old fixed
-- `MaxActivationDistance = 14` the only place the shop existed was under the building.
--
-- ⚠️ WIDENING THE COUNTER'S REACH DOES NOT FIX IT, and that was tried and measured in this job before
-- being reverted. With reach 35 the prompt is in range at the sign — and STILL INVISIBLE: the bubble
-- renders at the counter's position, which the house occludes. Screenshotted from the player's camera
-- with the counter prompt as the only live one: prompt shown, its position on-screen at (795,564),
-- and no bubble anywhere in frame.
--
-- ⚠️ AND TWO PROMPTS IS NOT THE ANSWER EITHER. `Exclusivity` defaults to `OnePerButton` (verified in
-- this place, not recalled) and both would use the default `KeyCode.E`, so only ONE ever renders — and
-- which one is NOT the nearest. Walking in showed the sign's; teleporting to the same spot showed the
-- counter's. A trigger that is visible half the time is the reported bug, shipped again.
--
-- So there is exactly one prompt and it hangs on the physical "TRADING POST" board — the thing players
-- actually walk up to — with the reach sized to the whole building. Visible from outside, visible from
-- under the deck (the board reads from under the overhang), and deterministic.
-- The invisible `Counter` part is LEFT IN PLACE but is now inert — grepped both trees, nothing outside
-- this function reads it. Kept rather than deleted because removing an instance from every generated
-- village is a content change this job was not asked to make; logged as todo 0060 instead.
local function buildTradingPost(pos: Vector3, parent: Instance, faceTo: Vector3)
	local padGround = groundAt(pos.X, pos.Z) -- ONE measurement for the whole pad
	-- `upright = true`: this model's pivot is rotated 90° while its parts are not, so without it the whole
	-- kiosk is placed lying on its side. See `PropOpts.upright`.
	local postModel = prop(CampDefs.MODEL.post, pos.X, pos.Z, parent, { collide = true, faceTo = faceTo, upright = true })

	-- ── Job #107: fix up the kiosk clone ──────────────────────────────────────────────────────────
	-- `CampDefs.MODEL.post` is now `RobuxShop`, the same kiosk the crash-site Robux shop uses. It ships
	-- with two fittings that are right at the spawn base and wrong in a river camp. Both are fixed on
	-- THE CLONE — `AssetLibrary` and `Workspace.SpawnBase.Stands.RobuxShop` must not be touched, or the
	-- crash-site kiosk loses its own signage.
	if postModel then
		-- ⚠️ STRIP BY TYPE, NOT BY NAME. The kiosk's "ROBUX SHOP" branding is in THREE places and they do
		-- NOT share a parent — measured:
		--     EntrySign > Board > SurfaceGui > TextLabel     "ROBUX SHOP"
		--     EntrySign > Board > SurfaceGui > TextLabel     "ROBUX SHOP"
		--     Anchor    > BillboardGui > TextLabel           "ROBUX SHOP"   ← NOT under EntrySign
		-- Destroying `EntrySign` alone leaves the third one floating over the camp, which is exactly what
		-- shipped and was caught in playtest. Removing every Surface/Billboard Gui in the clone is the
		-- version that cannot be defeated by the next re-import moving things around.
		--
		-- The camp's own physical "TRADING POST" board is the signage here, and since Job #106 it is also
		-- what carries the shop prompt. An AlwaysOnTop BillboardGui is separately banned for world
		-- signage by STYLEGUIDE §5 / Job #077 — it renders through terrain.
		local stripped = 0
		for _, d in ipairs(postModel:GetDescendants()) do
			if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				d:Destroy()
				stripped += 1
			end
		end
		local entrySign = postModel:FindFirstChild("EntrySign")
		if entrySign then
			entrySign:Destroy() -- the now-blank board + its posts; the camp has its own sign
		end
		if stripped == 0 then
			warn("[Excursion] trading post: no branding GUIs found to strip — did the RobuxShop model change?")
		end
		-- `prop()` applies ONE `collide` flag to every BasePart it clones, so the kiosk's invisible
		-- 1×1×1 `Anchor` marker would become a solid block standing in the shop doorway.
		local anchor = postModel:FindFirstChild("Anchor")
		if anchor and anchor:IsA("BasePart") then
			anchor.CanCollide = false
			anchor.CanQuery = false
		end
	end

	-- ⚠️ Job #106: this INVISIBLE part no longer hosts the shop prompt — see the header. Its comment used
	-- to claim it sat "in front of the building"; measured, it sits UNDER the deck, which is what made
	-- the shop unfindable. It is inert now (todo 0060).
	local approach = (Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z))
	approach = if approach.Magnitude > 0.01 then approach.Unit else Vector3.new(0, 0, -1)
	local counterPos = pos + approach * 10
	local counter = block("Counter", Vector3.new(6, 4, 2), Theme.color.wood, CFrame.new(counterPos.X, padGround + 2, counterPos.Z), parent, Enum.Material.WoodPlanks)
	counter.Transparency = 1
	counter.CanCollide = false
	counter.CanQuery = false

	local lateral = Vector3.new(approach.Z, 0, -approach.X)
	local signBoard = buildShopSign(pos + approach * 16 + lateral * 7, pos + approach * 40, parent, padGround)

	-- A chest of gold OUT FRONT of the vendor, so the trading post reads as the place gold is SPENT
	-- (Job #079). ⚠️ Dressing only — no prompt, no attribute, no Gold granted.
	--
	-- ⚠️ IT CANNOT SIT AT THE COUNTER. `counterPos` is only `approach * 10`, and `BahayKubo7` measures
	-- **40×50 studs** — so the counter (an invisible prompt anchor, which does not care) is INSIDE the
	-- building footprint, and the first version of this put the chest under the stilt house's deck where
	-- nobody can see it. Measure the building and step outside it instead of picking a number.
	-- ONE measurement of the building, shared by the chest standoff and the prompt reach below. Both
	-- were previously magic numbers picked against a model nobody had measured.
	local postExt: Vector3? = nil
	if postModel and postModel:IsA("Model") then
		local _, e = (postModel :: Model):GetBoundingBox()
		postExt = e
	end

	local standoff = 26
	if postExt then
		local pext = postExt :: Vector3
		-- the box's half-extent along `approach` (its support function), + room for the chest and a margin
		standoff = (math.abs(approach.X) * pext.X + math.abs(approach.Z) * pext.Z) / 2 + 7
	end
	-- opposite side from the shop sign, so the two landmarks flank the approach instead of stacking
	local chestPos = pos + approach * standoff - lateral * 7
	prop(CampDefs.MODEL.goldChest, chestPos.X, chestPos.Z, parent, { collide = true, faceTo = faceTo })

	-- ── the shop trigger — ON THE SIGN, and only there ────────────────────────────────────────────
	-- Reach is sized to the WHOLE building plus a walk-up margin, the same rule `StartShopServer` uses
	-- for the crash-site Robux kiosk. Measured here: 35 studs, against the old hardcoded 14.
	local reach = 20
	if postExt then
		local pext = postExt :: Vector3
		reach = math.max(math.max(pext.X, pext.Z) / 2 + 10, 20)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Trading Post"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = reach
	prompt.Parent = signBoard
	prompt.Triggered:Connect(function(player: Player)
		openShop:FireClient(player)
	end)
end

-- 🔴 DO NOT BUILD A CAMP ON TERRAIN THAT DOES NOT EXIST YET.
--
-- `RiverBootstrap` STREAMS the river: it keeps `AHEAD_CHUNKS` (~2560 studs, Job #113) generated ahead of the boat
-- and un-generates the rest. This script builds landing sites up to `CAMP_AHEAD` (1400) ahead, and the
-- `ForceFirstCamp` admin helper builds the first one immediately — which can be ~1900 studs ahead, i.e.
-- **beyond the generated window**.
--
-- When that happened the failure was silent and total: `carve` wrote a basin into empty space, every
-- `groundAt` found nothing and fell back to `CLEAR_Y`, so all 24 camp props were seated at 14.7 — and
-- then the generator reached that stretch and wrote the real hillside (measured 22→48) straight over
-- them. Every structure ended up underground. It read as "the camp is broken"; the camp was fine and
-- the ground arrived afterwards.
--
-- So: probe first, and if the terrain is not there, DON'T mark the site built — the main loop retries
-- every 0.5 s and will build it once the generator has caught up.
local function terrainReadyAt(cx: number, cz: number): boolean
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
	rp.IgnoreWater = true
	-- Sample across the basin, not one point: a single hit can be a stray voxel at the boundary of a
	-- half-generated chunk.
	local hits = 0
	for _, o in ipairs({ Vector2.new(0, 0), Vector2.new(120, 0), Vector2.new(-120, 0), Vector2.new(0, 150), Vector2.new(0, -150) }) do
		if Workspace:Raycast(Vector3.new(cx + o.X, 200, cz + o.Y), Vector3.new(0, -500, 0), rp) then
			hits += 1
		end
	end
	return hits >= 4
end

local function buildLandingSite(dock: RiverData.Dock, index: number)
	if built[index] then
		return
	end
	local halfW = RiverData.widthAt(dock.z) * 0.5
	local waterEdge = RiverData.centerlineX(dock.z) + dock.side * halfW
	local basinCenterX = waterEdge + dock.side * (BASIN_SIZE / 2) -- inner edge AT the water line (walkable shore), not into the channel

	if not terrainReadyAt(basinCenterX, dock.z) then
		return -- river not generated this far yet; retry next tick (see the note above)
	end

	built[index] = true
	carve(basinCenterX, dock.z, BASIN_SIZE, dock.side)

	-- contain the valley: raise rock walls on the 3 inland sides (water side stays open for the dock)
	-- so the crew can't walk off the carved basin's edge.
	local half = BASIN_SIZE / 2
	local function wallBlock(cx: number, cz: number, sx: number, sz: number)
		Terrain:FillBlock(CFrame.new(cx, 17, cz), Vector3.new(sx, 50, sz), Enum.Material.Rock) -- solid Y[-8..42]
	end
	wallBlock(basinCenterX + dock.side * (half + 15), dock.z, 30, BASIN_SIZE + 60) -- far inland wall

	-- ⚠️ The two Z walls run from the WATER inland, so their inner end must follow the LOCAL bank. They
	-- sit 215 studs up- and downstream of the dock, and using the dock's own water edge for them put a
	-- 50-stud-tall rock wall up to 32 studs INTO the channel — the last source of solid ground in the
	-- river (measured 14/1691 samples against 0/1691 on control stretches with no camp).
	for _, wz in ipairs({ dock.z + half + 15, dock.z - half - 15 }) do
		local innerX = bankForSlice(wz - 15, wz + 15, dock.side)
		local outerX = basinCenterX + dock.side * (half + 30)
		local w = (outerX - innerX) * dock.side
		if w > 8 then
			wallBlock((innerX + outerX) / 2, wz, w, 30)
		end
	end

	local model = Instance.new("Model")
	model.Name = "LandingSite"
	local rng = Random.new(index * 131 + 7)

	-- Job #077 ground pass, BEFORE the path fill below: scattered patches at low weight first, then the
	-- desire line on top at full weight. Reverse the order and the scatter eats holes in the path.
	paintBasin(basinCenterX, dock.z, BASIN_SIZE, waterEdge, dock.side, rng)

	-- camp positions first, so we can keep the walking lane to them clear of trees (Job 053)
	local nearPos = Vector3.new(waterEdge + dock.side * 120, CLEAR_Y, dock.z)
	local deepPos = Vector3.new(waterEdge + dock.side * 300, CLEAR_Y, dock.z + 40)
	-- the path runs from the shore (just past the water line) to the deep camp, passing the near camp
	local pathAx, pathAz = waterEdge + dock.side * 8, dock.z
	local pathBx, pathBz = deepPos.X, deepPos.Z

	-- paint a dirt PATH into the TERRAIN along the lane. Ground material grows no grass blades, so it reads as
	-- a clear walkway through the leafy basin (a thin Part just gets buried by the grass decoration).
	local pathLen = (Vector3.new(pathBx, 0, pathBz) - Vector3.new(pathAx, 0, pathAz)).Magnitude
	local pathMid = Vector3.new((pathAx + pathBx) / 2, CLEAR_Y - 3, (pathAz + pathBz) / 2)
	local pathCF = CFrame.lookAt(pathMid, Vector3.new(pathBx, CLEAR_Y - 3, pathBz))
	Terrain:FillBlock(pathCF, Vector3.new(PATH_HALF * 1.2, 6, pathLen), Enum.Material.Ground)

	settleTerrain() -- the ring and the scatter both raycast this terrain; let the writes land first

	-- ⚠️ Job #108 — THE TRADING POST'S POSITION IS COMPUTED HERE, NOT WHERE IT IS BUILT.
	-- It is built further down (after the camps, unchanged), but the village scatter has to know where
	-- it will stand so it does not put a hut on it. See `buildTradingPost`'s call site for why its X
	-- comes from the bank at ITS OWN Z rather than the dock's.
	local postZ = dock.z - 24
	local postPos = Vector3.new(bankForSlice(postZ - 30, postZ + 30, dock.side) + dock.side * 90, CLEAR_Y, postZ)

	-- ── the outlying village (Job #108) ──────────────────────────────────────────────────────────
	-- Generated HERE, before anything is planted, for one reason: the interior tree scatter below runs
	-- first and the huts are built last, so a tree planted now would end up standing inside a hut placed
	-- later. Generating the slots up front lets the scatter route around them.
	--
	-- The camp radii come from `CampLayout.forCamp`, which is memoised on camp position — this is the
	-- same layout object the camps themselves will use, so the exclusion is the fence that really gets
	-- built rather than a conservative guess at it.
	local nearLayoutEarly = CampLayout.forCamp(nearPos, {
		seed = math.floor(nearPos.X * 31 + nearPos.Z * 17),
		kind = CampDefs.KIND.near, resourceCount = 2, deep = false,
	})
	local deepLayoutEarly = CampLayout.forCamp(deepPos, {
		seed = math.floor(deepPos.X * 31 + deepPos.Z * 17),
		kind = CampDefs.KIND.deep, resourceCount = 2, deep = true,
	})
	local villageHuts = VillageLayout.generate({
		seed = index * 977 + 41,
		basinCenterX = basinCenterX,
		basinZ = dock.z,
		basinSize = BASIN_SIZE,
		waterEdge = waterEdge,
		side = dock.side,
		camps = {
			{ pos = nearPos, radius = nearLayoutEarly.radius },
			{ pos = deepPos, radius = deepLayoutEarly.radius },
		},
		pathAx = pathAx,
		pathAz = pathAz,
		pathBx = pathBx,
		pathBz = pathBz,
		pathHalf = PATH_HALF,
		postPos = postPos,
		rawGround = rawGroundAt,
	})

	-- The canopy that frames the clearing goes in FIRST, around the three inland sides.
	plantClearingRing(basinCenterX, dock.z, BASIN_SIZE, waterEdge, dock.side, model, rng)

	-- ...and the interior gets LIGHT undergrowth only, kept inside the ring zone so palms and bushes
	-- don't fight the canopy for the same ground. Down from 45 scattered edge-to-edge: the middle of a
	-- camp you fight in should be open, and the trees should be the thing enclosing it.
	local interiorReach = BASIN_SIZE / 2 - CampDefs.CLEARING.ringZone
	for _ = 1, CampDefs.CLEARING.interiorCount do
		local rx = basinCenterX + rng:NextNumber(-1, 1) * interiorReach
		local rz = dock.z + rng:NextNumber(-1, 1) * interiorReach
		-- keep trees on land (out of the channel), out of the walking lane to the camps, and — Job #108 —
		-- out of the village huts, which are placed after this loop and would otherwise get a palm
		-- through the roof.
		if
			(rx - waterEdge) * dock.side > 10
			and distToSeg(rx, rz, pathAx, pathAz, pathBx, pathBz) > PATH_HALF
			and not VillageLayout.blocked(villageHuts, rx, rz)
		then
			tree(rx, rz, model, rng)
		end
	end

	-- tiered, ESCALATING camps: rosters are predefined + non-respawning, and grow at each successive landing
	-- (tier = the landing's ordinal downriver). Deeper camp always has one more guard than the near camp.
	local tier = math.max(1, math.ceil(index / 2))
	-- SOLO tuning (Job 058): fewer guards for a small crew so a lone raider can clear a camp (min 1).
	local scale = 0.55 + (1 - 0.55) * math.clamp((#Players:GetPlayers() - 1) / 5, 0, 1)

	-- ⚠️ **PER-VILLAGE ESCALATION, user direction 2026-08-16: "each next village +10% more monsters, and
	-- stronger by 10%".** Compounding on the landing's ordinal, so village 1 is unchanged and each one
	-- after is 1.10x the last on BOTH axes.
	--
	-- ⚠️ The COUNT multiplier is applied INSIDE the `MAX_GUARDS` clamp on purpose. The cap is a
	-- performance ceiling (each guard is a full R15 rig), not a difficulty knob — letting the ramp push
	-- past it would put 10+ rigs at the last village. Once the count saturates at 6, the escalation
	-- continues through STRENGTH, which costs nothing to render. That is the intended behaviour, not a
	-- ramp that quietly stops.
	local villageStep = VILLAGE_STEP ^ math.max(0, index - 1)
	local strength = villageStep
	-- ⚠️ Job #100 follow-up — a camp is a GARRISON, not a picket.
	--
	-- Reported: *"now camps is not challenging, there is just 2 enemies, and then nothing"*. The crew-size
	-- scaling below is Job #058's and it is right that a solo player faces less than a six-stack — but it
	-- was scaling down to ONE guard per camp, which is not a raid, it is a formality.
	--
	-- So the scaling still decides the CEILING; a randomised 4–6 is the floor. `MAX_GUARDS` (6) is a perf
	-- ceiling — each guard is a full R15 rig — so the floor is clamped to it and never exceeds it.
	-- 2–3, per the user's call after 4–6 proved unwinnable. The camp's threat now comes from
	-- reinforcements arriving over time, not from a big garrison standing there when you land.
	local GARRISON_MIN, GARRISON_MAX = 2, 3
	local function garrisonFor(base: number): number
		local floorCount = rng:NextInteger(GARRISON_MIN, GARRISON_MAX)
		return math.clamp(math.max(base, floorCount), 1, MAX_GUARDS)
	end
	local nearGuards = garrisonFor(math.max(1, math.floor(math.min(MAX_GUARDS, tier * villageStep) * scale)))
	local deepGuards = garrisonFor(math.max(1, math.floor(math.min(MAX_GUARDS, (tier + 1) * villageStep) * scale)))

	-- ⚠️ Job #102 — THE FIRST LANDING IS THE TUTORIAL, AND IT IS EXEMPT FROM ALL OF THE ABOVE.
	--
	-- Reported: *"first camp has too many enemies when i land"*, and the reason given is the one that
	-- matters — *"first time players just confused when 2 attack same time"*. The floor above rolls 2–3
	-- per camp and a landing builds TWO camps, so the very first time a player ever goes ashore they meet
	-- 4–6 guards while still learning that going ashore is a thing at all. That is not a difficulty
	-- problem, it is an ONBOARDING problem: first contact has to be legible, which means ONE enemy in the
	-- first camp and a pair in the second.
	--
	-- So landing 1 is hardcoded: near camp = 1, deep camp = 2. Written as a flat override rather than by
	-- lowering GARRISON_MIN, because the 2–3 floor is Job #100's answer to *"camps are not challenging"*
	-- and must keep applying everywhere else. This is an on-ramp, not a rebalance.
	--
	-- ⚠️ `index` is the DOCK ordinal, not the landing ordinal: `docksBetween` marks only ODD docks as
	-- landings (`(i % 2) == 1`, RiverData:319), so landings are docks 1, 3, 5… and `index == 1` is exactly
	-- the first one. Do NOT rewrite this as `tier == 1` — `tier = ceil(index / 2)` is 1 for BOTH dock 1
	-- and dock 2, so it would read as covering two landings when only one exists.
	--
	-- The Wolf/Bandit mix falls out of `buildCampAt` unchanged and is already what was asked for: the near
	-- camp is all-Bandit (`wolves = 0` for KIND.near), and the deep camp's `math.max(1, math.floor(2/3))`
	-- = 1 gives one Wolf and one Bandit.
	--
	-- ⚠️ This also sets each camp's respawn `target` (the `garrisons` record at the end of `buildCampAt`),
	-- which is intended: the first landing's camps refill to 1 and to 2, so reinforcements keep arriving
	-- indefinitely but never stack the camp back up into a wall.
	if index == 1 then
		nearGuards = 1
		deepGuards = 2
	end
	-- Job #077: the direction the player walks INTO each camp. The near camp is approached from the shore
	-- landing; the deep camp is approached from the near camp — which is the real route, so the deep camp
	-- presents its front to someone who has just fought through the first one.
	local shorePoint = Vector3.new(pathAx, CLEAR_Y, pathAz)
	local nearApproach = (nearPos - shorePoint) * Vector3.new(1, 0, 1)
	nearApproach = if nearApproach.Magnitude > 0.01 then nearApproach.Unit else Vector3.new(dock.side, 0, 0)
	local deepApproach = (deepPos - nearPos) * Vector3.new(1, 0, 1)
	deepApproach = if deepApproach.Magnitude > 0.01 then deepApproach.Unit else nearApproach

	local nearGarrison = buildCampAt(nearPos, model, nearGuards, { "Gasoline", "Gasoline" }, CampDefs.KIND.near, nearApproach, rng, strength, index == 1) -- 2 gas → a haul can fund skipping a stop (Job 054)
	local deepGarrison = buildCampAt(deepPos, model, deepGuards, { "Metal", "Ammo" }, CampDefs.KIND.deep, deepApproach, rng, strength, index == 1)

	-- village trading post (Job 023): between the shore and the first camp, reached on foot after tying up
	--
	-- ⚠️ Its X comes from the bank at ITS OWN Z, not the dock's. It sits 24 studs upstream of the dock,
	-- and over that distance the meander moves the bank enough to put the post outside the carved basin,
	-- standing on the raw bank shelf ~5 studs below the camp floor (measured: post, counter and sign all
	-- floated +4.7).
	--
	-- ⚠️ AND IT GETS NO LEVELLING PAD, which was tried twice and reverted both times. The post stands
	-- close to the water, so any axis-aligned pad big enough to hold it reaches the channel wherever the
	-- meander swings in — measured at 32 studs of solid ground in the river, then 77. The basin carve
	-- ALREADY flattens everything from the bank to 400 studs inland, so the fix is to stand the post on
	-- that rather than to make new ground: move it inland until it is on the carve.
	buildTradingPost(postPos, model, shorePoint) -- faces back toward the water, so you see its front on landing

	-- ── the outlying village goes up LAST (Job #108) ─────────────────────────────────────────────
	-- After the camps, because each of those re-clears a 160-stud terrain footprint and calls
	-- `settleTerrain`; a hut seated before those writes land reads the pre-fill surface and floats.
	--
	-- ⚠️ THE COUNT IS LOGGED, NOT ASSUMED. These are placed by rejection sampling into the ring of free
	-- ground left between two camps, the walking lane and the tree ring, and that sampling is allowed to
	-- fail. Without this line a basin that quietly fitted two huts instead of eight looks identical to
	-- "the scatter is sparse today" — and the whole job is the count.
	local standing: { { model: Model, hut: VillageLayout.Hut } } = {}
	for _, hut in ipairs(villageHuts) do
		local built = buildVillageHut(hut, model, rng)
		if built then
			table.insert(standing, { model = built, hut = hut })
		end
	end
	local hutsBuilt = #standing
	if hutsBuilt < CampDefs.VILLAGE.countMin then
		warn(("[Excursion] landing %d: only %d/%d village huts placed — the basin is out of free ground "
			.. "(check CampDefs.VILLAGE margins against the camp radii)"):format(index, hutsBuilt, #villageHuts))
	end
	-- Job #109: the yard loot and the two hut ambushers, both AFTER the huts exist — the first hangs off
	-- their clutter rings, the second needs each hut's reported `FloorY`.
	local yard = buildYardLoot(villageHuts, model, rng)
	local ambushers = placeHutBandits(standing, model, rng, strength)
	if DEV_GARRISON_LOG then
		print(("[Village] landing %d: %d huts · %d yard crates · %d hut bandits"):format(index, hutsBuilt, yard, ambushers))
	end

	-- ⚠️ Job #100 — these read the camp's GENERATED layout, not `CampDefs.LAYOUT`.
	-- The nugget and the two kind-crates are placed out here rather than inside `buildCampAt`, and they
	-- used to share the same fixed slot table it did. With a per-camp layout they must fetch the SAME one
	-- (`CampLayout.forCamp` is memoised on camp position) or the nugget lands inside a hut that only
	-- exists in this camp's arrangement.
	--
	-- Job #108: fetched further up now (the village scatter needs the camp radii before anything is
	-- planted) and reused here rather than fetched twice. Same memoised objects either way; one variable
	-- makes it obvious there is only ever one layout per camp.
	local nearLayout, deepLayout = nearLayoutEarly, deepLayoutEarly

	-- rare gold nuggets (run-capped): a chance at each camp
	local nearNug, deepNug = nearLayout.nugget, deepLayout.nugget
	if nearNug then
		trySpawnNugget(CampDefs.slotToWorld(nearPos, nearApproach, nearNug), model, rng)
	end
	if deepNug then
		trySpawnNugget(CampDefs.slotToWorld(deepPos, deepApproach, deepNug), model, rng)
	end

	-- loadout loot at the deep camp (Job 015): a scarce WEAPON crate + a handheld-ammo crate.
	-- Weapon crates are the top reward — alternate pistol/shotgun by landing; spawn rate is tunable.
	--
	-- 🔴 Job #104: WAS `index % 2 == 0`, WHICH COULD NEVER BE TRUE.
	-- `index` is the DOCK ordinal and only ODD docks are landings (`RiverData:319`,
	-- `landing = (i % 2) == 1`) — the very thing this file's own comment at the top of `buildLandingSite`
	-- spells out. So the Shotgun arm was dead code: EVERY weapon crate in the game was a Pistol, and
	-- because the ammo crate below reuses `weaponId`, every handheld ammo crate was Pistol ammo too. The
	-- shotgun and its shells existed only in the 750-salvage shop row. Found by an independent reviewer
	-- while Job #104 was adding buyable ammo, and it is exactly why "add ammo to the shotgun" was thin
	-- on its own — there was no shotgun to feed.
	--
	-- `tier` is the LANDING ordinal (1, 2, 3…) already computed above for exactly this kind of use, so
	-- landing 1 gives a Pistol, landing 2 a Shotgun, landing 3 a Pistol… and both guns really appear.
	local weaponId = if tier % 2 == 0 then "Shotgun" else "Pistol"
	local deepFrom = deepPos - deepApproach * 80
	-- ⚠️ These must ALWAYS exist. The weapon crate is the run's top reward, and the generator places by
	-- rejection sampling — which can fail. Guarding with `if kc[1] then` (as the first version did) meant
	-- a crowded camp could silently ship with no weapon in it at all. A fixed fallback slot is far better
	-- than a missing reward.
	local kc = deepLayout.kindCrates
	local fallback1: CampDefs.Slot = { right = 30, forward = -2 }
	local fallback2: CampDefs.Slot = { right = 30, forward = 8 }
	makeKindCrate(CampDefs.slotToWorld(deepPos, deepApproach, kc[1] or fallback1), "Weapon", weaponId, "Take " .. weaponId, model, deepFrom)
	makeKindCrate(CampDefs.slotToWorld(deepPos, deepApproach, kc[2] or fallback2), "Ammo", weaponId, weaponId .. " Ammo", model, deepFrom)
	model.Parent = campsRoot
	siteModels[index] = model -- track for culling (Job 060)

	-- 🔴 Job #102 — THE GARRISON RECORDS GO IN *AFTER* THE SITE IS PARENTED. See `buildCampAt`'s return.
	--
	-- Registered here and not inside `buildCampAt` because the respawn loop reaps any record whose site is
	-- unparented, and the site is unparented for the whole of the build — which contains yields.
	--
	-- `waterEdge`/`side` ride along because the respawn loop has to keep reinforcement ENTRY POINTS inside
	-- the basin, and this is the only scope that knows where the basin is. `CampLayout` places entries at
	-- `radius + 26..40` ≈ 96–114 studs from a camp centre, with no idea what is out there:
	--   · the NEAR camp sits 120 studs inland, so an entry toward the water lands ~6 studs from the river;
	--   · the DEEP camp sits 300 inland, so an entry away from it lands ~414 — INSIDE the far rock wall,
	--     which spans 400–430 (`wallBlock(basinCenterX + side * (half + 15), …, 30, …)`).
	-- `groundAt` does not save us: it rejects the wall-top hit and falls back to `CLEAR_Y + 2.5`, i.e. it
	-- cheerfully seats a guard inside solid rock. That was survivable only while the leash instantly
	-- teleported reinforcements to their posts; now that they actually walk in, it is not.
	nearGarrison.waterEdge, nearGarrison.side = waterEdge, dock.side
	deepGarrison.waterEdge, deepGarrison.side = waterEdge, dock.side
	table.insert(garrisons, nearGarrison)
	table.insert(garrisons, deepGarrison)
	if DEV_GARRISON_LOG then
		print(("[Garrison] registered near (%d,%d) target=%d · deep (%d,%d) target=%d · #garrisons=%d"):format(
			nearGarrison.campPos.X, nearGarrison.campPos.Z, nearGarrison.target,
			deepGarrison.campPos.X, deepGarrison.campPos.Z, deepGarrison.target, #garrisons))
	end
end

-- ── Job #122: who is standing on a watchtower right now ──────────────────────────────────────────
-- 🔴 A GRENADIER MUST NOT SHELL A PLAYER WHO IS ON A **DIFFERENT** TOWER.
--
-- Reported: *"rocketmans cant shoot me while i am at tower, now i climb on tower, and other rocket man
-- targets me"*. Job #119's design is that you answer a rocket man by CLIMBING to him — *"if you get close to
-- enemy, you go into close combat"* — and the shell's counter-play is that a walking player covers 64 studs
-- in its 4 s flight against a 30-stud blast, so **moving at all clears the ring**. On a 20×20 platform 44
-- studs up there is nowhere to move to. The telegraph is unanswerable there, which makes the intended
-- counter-play to one grenadier a death sentence delivered by another.
--
-- ⚠️ "A DIFFERENT tower" is the whole subtlety. The man on the platform you are standing on must still fight
-- you — that is the fight you climbed for. He is already handled: `minFireRange`/`meleeRange` put him into
-- melee rather than shelling his own deck. So this filter is keyed on `st.tower`, not applied to every
-- grenadier.
--
-- Resolved ONCE PER FRAME for all players rather than per grenadier: `tickRocketMan` runs per guard per
-- frame, and the end zone has three of them.
--
-- ⚠️ Detected by asking the FLOOR, not by a height threshold. A "y above the basin" test would also catch
-- the runway, the extraction pad deck, a hut roof and any stump, and would need a different number for the
-- end zone (deck y=62.19) than for a camp (deck y=54.26, because `prop` scales the tower by 0.85). One short
-- downward ray answers it exactly, at any scale, for any tower the owner places later. Same reasoning as the
-- perched-ambusher release in `tickGuard`.
local towerRideParams = RaycastParams.new()
towerRideParams.FilterType = Enum.RaycastFilterType.Exclude
towerRideParams.IgnoreWater = true

local onTower: { [Model]: Model } = {}

local function refreshTowerRiders()
	table.clear(onTower)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			-- Exclude the character itself so the ray does not stop on their own legs. 12 studs reaches the
			-- deck from an HRP ~3 studs above the feet, and covers a jump.
			towerRideParams.FilterDescendantsInstances = { char }
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), towerRideParams)
			if hit then
				local m = hit.Instance:FindFirstAncestorOfClass("Model")
				while m do
					if m.Name == CampDefs.MODEL.tower then
						onTower[char] = m
						break
					end
					m = m:FindFirstAncestorOfClass("Model")
				end
			end
		end
	end
end

-- ── The Rocket Man's tick — Job #119 ─────────────────────────────────────────────────────────────
-- Runs INSTEAD of `tickGuard`'s body (see the branch below), not alongside it.
--
-- 🔴 WHY IT REPLACES `tickGuard` RATHER THAN EXTENDING IT.
-- Six separate things in that function assume a guard stands on terrain and walks:
--   · `seatY` is re-derived from `groundAt`, which filters to Terrain ONLY and additionally throws away
--     any hit above `CLEAR_Y + BASIN_RISE` as a leftover stump — so it can never return a deck height,
--     and its failure path returns `CLEAR_Y + 2.5`. A tower guard is re-seated onto the dirt inside one
--     frame, and every frame after.
--   · movement is XZ-only with a horizontal stop distance, so a player 40 studs out horizontally reads as
--     40 studs away and he walks at the railing at full speed. `CanCollide` is false on the whole rig, so
--     the railing does not stop him.
--   · the bite gate is 3D, so from 36 studs up he could never reach anyone anyway — he would stand at the
--     edge in a run-in-place animation forever.
--   · the chase-slot budget is 2 per camp and a slot is held for as long as a guard has a target. A
--     stationary sniper with 160 studs of sight holds one from the moment you enter the camp until he
--     dies, halving the ground pressure the rest of the garrison can apply.
--   · the leash clamp is a hard reposition, not a speed limit.
--   · `setMotion("move")` would play the Bandit's RUN clip on a man holding a position.
-- Every one of those is avoided by not running any of it.
local function tickRocketMan(guard: Model, def: EnemyDefs.EnemyDef, st: GuardState, dt: number)
	local R = CampDefs.TOWER.rocketMan
	local pin = st.pin
	if not pin then
		return -- not actually posted (should not happen); do nothing rather than guess a position
	end
	-- Job #121: pick up this man's phase within the fire cycle, once. Read LAZILY rather than in
	-- `spawnRocketMan` because the caller stamps the attribute after that function returns — a value
	-- captured at spawn would always be the default. Camps set no attribute, so `firePhase` is 0 and every
	-- camp rocket man behaves exactly as it did before this existed.
	if st.firePhase == nil then
		st.firePhase = (guard:GetAttribute("FirePhase") :: number?) or 0
		st.fireTimer = st.firePhase
	end
	-- ⚠️ Distances below are measured from `pin`, NOT from `body.Position`. They are the same value by
	-- construction (the pin is re-asserted every frame), and using the pin means the reads cannot be
	-- perturbed by a frame in which something else has moved the rig.
	local alerted = (st.alertUntil ~= nil) and (os.clock() < (st.alertUntil :: number))

	-- ── acquire ───────────────────────────────────────────────────────────────────────────────────
	-- ⚠️ BOUNDED EVEN WHEN ALERTED, and that is deliberately unlike `tickGuard`. There, being alerted sets
	-- the search distance to `math.huge` — fine for a guard that then has to run to you, incoherent for a
	-- man with a 300-stud weapon, who would otherwise shell someone 900 studs downriver who shot him once.
	-- Alerted widens his sight to the weapon's own reach and no further.
	local sight = if alerted then R.range else (st.aggroRadius or def.aggroRadius)
	-- 🔴 Job #122 — AN OPTIONAL PER-GUARD CEILING, AND IT IS THE **ALERTED** BRANCH THAT NEEDED IT.
	--
	-- Reported after Job #121 shipped: *"also reduce how far they shoot"*. The obvious number to reach for is
	-- `EnemyDefs.RocketMan.aggroRadius` (160) — and it is the wrong one. `alertUntil` is refreshed by ANY hit
	-- landing within `ALERT_SPREAD` (70) of a guard and lasts `GUARD_ALERT_SECONDS` (15), so once a firefight
	-- starts the tower crews are alerted essentially continuously, and this line hands them **`R.range` =
	-- 300**. The end-zone airfield is only ~400 studs across. So in practice they were shelling from anywhere
	-- on it, and lowering the 160 would have changed almost nothing.
	--
	-- Capping AFTER the branch is what makes that fixable with one number: it binds the alerted reach and the
	-- unalerted reach together, so there is no second value to forget.
	--
	-- Measured in Edit, 2026-08-27 — grenadiers able to engage, by cap (pads sit ~44 studs up):
	--                          160   130   110    90    70
	--     boat mooring          2     2     2     2     0
	--     field centre          3     3     3     1     0
	--     extraction pad        1     1     1     1     0
	--     warlord's post        3     1     1     1     1
	-- 130 is the cliff that matters: it takes the WARLORD'S POST from three grenadiers to one, which is where
	-- the boss fight happens, while leaving the open middle contested by all three. 110 is identical to 130 at
	-- every measured spot, so there is nothing to buy below it until 90 (which also thins the middle to one).
	--
	-- No camp rocket man carries this attribute, so camps keep 160 / 300 exactly as before.
	local sightMax = guard:GetAttribute("SightMax") :: number?
	if sightMax then
		sight = math.min(sight, sightMax)
	end
	local target: BasePart? = nil
	local bestD = sight
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Skips a DOWNED player for the same reason `tickGuard` does: they are out of the fight, and
		-- `PlayerCombat` pins their WalkSpeed to 0 — a downed crewmate cannot leave a red circle, so
		-- shelling them would be the one case where the telegraph is impossible to answer.
		--
		-- Job #122 adds the SECOND case where it is impossible to answer: a player standing on ANOTHER
		-- tower's platform. See `refreshTowerRiders` — 20×20 studs, 44 up, nothing to dodge to, and
		-- climbing is the intended counter to a grenadier in the first place. `onTower[char] == st.tower`
		-- means they have climbed to THIS man, who still fights them (in melee, not with a shell).
		-- Both sides widened to `Instance?` before comparing: `onTower` yields `Model?` and `st.tower` is
		-- `Model?`, and the strict solver refuses `Model ~= nil` once it has narrowed one side.
		local riding: Instance? = onTower[char :: Model]
		local myTower: Instance? = st.tower
		local ridingOther = riding ~= nil and riding ~= myTower
		if root and char and not char:GetAttribute("Downed") and not ridingOther then
			local d = (root.Position - pin).Magnitude
			if d <= bestD then
				target, bestD = root, d
			end
		end
	end

	-- ── hold the post ─────────────────────────────────────────────────────────────────────────────
	-- The ONLY thing he ever writes is his yaw. Position is re-asserted from `pin` every frame, so there
	-- is nothing to drift and no raycast to miss. With no target he returns to the pad's own facing, which
	-- the owner aimed over the camp when they placed it.
	local yaw = st.pinYaw or 0
	if target then
		local flat = Vector3.new(target.Position.X - pin.X, 0, target.Position.Z - pin.Z)
		if flat.Magnitude > 0.01 then
			yaw = math.atan2(flat.Unit.X, flat.Unit.Z)
		end
	end
	guard:PivotTo(CFrame.new(pin) * CFrame.Angles(0, yaw, 0))

	-- He never walks, so he is never in the `move` clip. `EnemyAssets.RocketMan` sets no `move` id at all.
	EnemyRig.setMotion(guard, "idle")
	if target and not st.roared then
		st.roared = true
		EnemyRig.playSound(guard, "aggro") -- the "he has seen you" cue, BEFORE the first shell
	elseif not target then
		st.roared = false
	end

	if not target then
		-- No banking a shot while nobody is in sight, so arriving is never punished instantly. Job #121:
		-- resets to his PHASE rather than to 0 — three men on one field would otherwise re-synchronise every
		-- time they lost and reacquired a target, which is exactly when the player walks up to them.
		st.fireTimer = st.firePhase or 0
		return
	end

	-- ── close combat (requirement 5) ──────────────────────────────────────────────────────────────
	-- 3D distance, so "close" means ON THE PLATFORM WITH HIM, not 16 studs below his feet.
	if bestD <= R.meleeRange then
		-- ⚠️ The fire timer is HELD, not reset: backing off the platform must not buy you a fresh 20 s.
		st.biteTimer += dt
		if st.biteTimer >= def.biteCooldown then
			st.biteTimer = 0
			-- Two swings, alternated — the same trick `MeleeServer` uses on the player's own melee "so
			-- repeated swings do not look canned". This is requirement 6.
			st.swingFlip = not st.swingFlip
			EnemyRig.playOnce(guard, if st.swingFlip then "attack" else "attack2")
			EnemyRig.playSound(guard, "attack")
			local char = target.Parent
			if char and char:IsA("Model") then
				local bite = ((guard:GetAttribute("BiteDamage") :: number?) or def.biteDamage) * EnemyDefs.DAMAGE_SCALE
				-- 🔴 POST-REVIVE GRACE. Same check, same reason, same clock as `tickGuard`'s bite: there is
				-- NO single chokepoint for player damage, so every site that writes a player's `HP` has to
				-- re-check this or it punches a hole in the invincibility window.
				if Workspace:GetServerTimeNow() >= (((char:GetAttribute("InvincibleUntil") :: number?)) or 0) then
					char:SetAttribute("HP", math.max(0, ((char:GetAttribute("HP") :: number?) or 0) - bite))
				end
			end
		end
		return -- 🔴 in melee he does NOT also shell his own feet
	end

	-- ── the 20-second shell (requirement 4) ───────────────────────────────────────────────────────
	st.fireTimer = (st.fireTimer or 0) + dt
	-- Job #121: a PER-GUARD cadence, with `CampDefs`' 20 s as the floor-plan. The end zone's three tower
	-- grenadiers are stamped `FireInterval = 12` by `EndGarrison` on the owner's call ("faster cadence"),
	-- and every camp on the river sets no attribute at all and therefore still fires at exactly 20.
	--
	-- ⚠️ Read every frame rather than cached into `st` at spawn: `spawnRocketMan` returns the rig and the
	-- caller stamps the attribute AFTER it, so a value captured at spawn time would always be the default.
	local interval = (guard:GetAttribute("FireInterval") :: number?) or R.fireInterval
	if st.fireTimer < interval then
		return
	end
	-- 🔴 TOO CLOSE TO FIRE. The blast radius is 30 and friendly fire is ON, so without this floor he drops
	-- a crater on the foot of his own tower — hitting the guards below him and, because he wears the
	-- `CampGuard` tag himself, potentially his own HP.
	if bestD < R.minFireRange then
		return -- hold the shot (and the accumulated timer): he fires the moment you back off
	end

	-- The muzzle: chest height at the pad, not the hitbox centre, so the shell leaves the man rather than
	-- his shins and the ray starts above the deck's own floor.
	local origin = pin + Vector3.new(0, def.size.Y * 0.25, 0)

	-- 🔴 AIM AT THE GROUND UNDER THE TARGET, NOT AT THE TARGET. AND EXCLUDE THE TARGET FROM THE RAY.
	--
	-- Reported: *"red circle for shooter is up high it is not on the ground"*. Both halves of that were
	-- this block. `Ballistics.resolveImpact` returns the FIRST thing the ray meets, and a player's own
	-- character is solid and queryable — so aiming at `HumanoidRootPart` made the ray STOP ON THEIR
	-- TORSO. The impact point was therefore ~3 studs in the air, `GroundRing` drew a 60-stud disc at the
	-- player's chest height, and the player stood inside it. Measured in the logs before the fix:
	-- `BLAST johnygorsky10 1.7 studs` — the crater centre was 1.7 studs from the root it was aimed at,
	-- i.e. on the body, where a ground impact would have read ~3.
	--
	-- ⚠️ THE PLAYER'S OWN BAZOOKA NEVER HIT THIS, which is why it was not inherited. `WeaponServer`
	-- passes `ignore = { char, boat }` — it excludes the SHOOTER, and the shooter is who its ray starts
	-- inside. Here the shooter and the target are different characters, so the target needs excluding too.
	local charModel = target.Parent
	local ignore: { Instance } = { guard }
	if charModel then
		table.insert(ignore, charModel :: Instance)
	end
	-- The tower as well: `prop` made all 128 of its parts collidable and left them queryable, so firing
	-- down at someone near the base would otherwise detonate on his own railing or the stair well.
	if st.tower then
		table.insert(ignore, st.tower :: Instance)
	end

	-- Drop the aim point to the floor beneath the target, so the ring lies where a ring should lie even
	-- when they are standing on a hut roof or the tower stairs rather than on terrain.
	local aimAt = target.Position
	do
		local down = RaycastParams.new()
		down.FilterType = Enum.RaycastFilterType.Exclude
		down.FilterDescendantsInstances = ignore
		down.IgnoreWater = false -- a rocket plumes off the river; it does not sink to the riverbed
		local hit = Workspace:Raycast(target.Position, Vector3.new(0, -80, 0), down)
		if hit then
			aimAt = hit.Position
		end
	end
	local impact = Ballistics.resolveImpact(origin, aimAt, R.range, ignore)

	st.fireTimer = 0
	EnemyRig.playOnce(guard, "fire")
	EnemyRig.playSound(guard, "attack")
	-- Same module and same broadcast as the player's own Bazooka, so the red warning ring, the 4-second
	-- arc, the whistle and both impact clips all arrive with no client code. `launchEnemy` (NOT `launch`)
	-- is what makes the crater hit players, the boat and his own side — see `Rocket.luau`.
	Rocket.launchEnemy(origin, impact, R.blast, guard)
	print(("[RocketMan] FIRE at %s (%.0f studs)%s"):format(
		tostring(impact), bestD, if alerted then " [alerted]" else ""))
end

-- guard AI: chase the nearest on-foot player, leashed to the camp; bite = damage player HP
local function tickGuard(guard: Model, dt: number)
	-- Job #086: read the per-guard type (Bandit or Wolf). Falls back to Bandit so a guard built before
	-- this change — or one whose attribute was stripped — still ticks with the stats it was built from.
	local def = EnemyDefs.Defs[(guard:GetAttribute("GuardType") :: string?) or "Bandit"] or EnemyDefs.Defs.Bandit
	local body = guard.PrimaryPart
	local st = guardState[guard]
	if not body or not st then
		guard:Destroy()
		return
	end
	if ((guard:GetAttribute("HP") :: number?) or 0) <= 0 then
		-- free this guard's chase slot so a post-holder can step up
		if st.chasing then
			local k = campKey(st.camp)
			campChasers[k] = math.max((campChasers[k] or 1) - 1, 0)
			st.chasing = false
		end
		guardState[guard] = nil
		EnemyRig.playSound(guard, "death")
		EnemyRig.destroy(guard) -- NOT :Destroy() — the rig holds AnimationTracks
		return
	end
	-- 🔴 Job #119 — THE ROCKET MAN BRANCHES OUT HERE, AND THE POSITION OF THIS LINE MATTERS.
	--
	-- It is placed AFTER the `def` lookup, the no-state destroy and the DEATH block above — all of which
	-- he wants and all of which are correct for him (his death frees no chase slot because he never takes
	-- one, and `EnemyRig.destroy` is what releases his AnimationTracks). It is placed BEFORE `st.biteTimer`
	-- and everything below, because from here down the function assumes a guard that stands on terrain and
	-- walks toward its target — see `tickRocketMan`'s header for the six ways that breaks a man on a
	-- 36-stud platform. He owns his own bite timing.
	if guard:GetAttribute("RocketMan") == true then
		tickRocketMan(guard, def, st, dt)
		return
	end
	st.biteTimer += dt
	local pos = body.Position

	-- Job #090: an alerted guard has been SHOT, so it does not need line of sight or a sight radius to
	-- know someone is out there — it hunts the nearest player at any range until the alert lapses.
	local alerted = st.alertUntil ~= nil and os.clock() < (st.alertUntil :: number)
	local target: BasePart? = nil
	local bestD = if alerted then math.huge else (st.aggroRadius or def.aggroRadius)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") then
			local d = (root.Position - pos).Magnitude
			if d <= bestD then
				target, bestD = root, d
			end
		end
	end

	-- ⚠️ CHASE SLOTS — a camp of six must not arrive as six.
	--
	-- A guard may only pursue if its camp has a free slot. Everyone else holds their post, which is what
	-- turns "7 enemies attacked me" into a fight that comes at you in waves you can back out of. The
	-- guard keeps its slot while it still has a target, so slots turn over as chasers die or lose you —
	-- not every frame.
	local ck = campKey(st.camp)
	if target then
		if not st.chasing then
			if (campChasers[ck] or 0) < chaserCapFor(ck) then
				campChasers[ck] = (campChasers[ck] or 0) + 1
				st.chasing = true
			else
				target = nil -- two are already on you: hold the post
			end
		end
	elseif st.chasing then
		campChasers[ck] = math.max((campChasers[ck] or 1) - 1, 0)
		st.chasing = false
	end

	-- Job #078: drive the rig's presentation from the AI, exactly as `EnemyServer.tickEnemy` does.
	-- ⚠️ This was the missed half of unifying the two creature paths: the BUILD was shared via
	-- `EnemyRig.build`, but camp guards have their own tick loop here, so without this a guard was
	-- built with animations and sounds and then never played any of them.
	EnemyRig.setMotion(guard, if target then "move" else "idle")
	if target and not st.roared then
		st.roared = true
		EnemyRig.playSound(guard, "aggro")
	elseif not target then
		st.roared = false
	end

	local goal = if target then target.Position else st.anchor
	local dir = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = dir.Magnitude
	if dist > 0.5 then
		dir = dir.Unit
		local stop = if target then def.biteRange * 0.5 else 1
		local step = math.min(def.speed * dt, math.max(dist - stop, 0))
		-- ⚠️ Job #090: the MEASURED seated height, never `CLEAR_Y + size.Y/2`. This loop rewrites Y every
		-- frame, so seating the guard only at spawn would be undone on its first step.
		--
		-- 🔴 Job #092: RE-MEASURE AS IT WALKS. #090 used `st.anchor.Y` — the height measured once at the
		-- SPAWN POINT — and justified it with "the basin is carved flat, so one measurement covers the
		-- whole leash". That was true of a 55-stud leash inside the basin. It stopped being true in the
		-- same job, when the alert pull raised the leash to `GUARD_LEASH_ALERT` (250): a guard chasing a
		-- shooter now leaves the flat basin entirely while still holding the basin's floor height, and
		-- floats over any ground that sits lower. Reported as *"wolfs fly (they are too much in air, a
		-- little bit)"*.
		--
		-- Throttled by DISTANCE, not time: `groundAt` can fire up to 25 probes on its fallback path, and
		-- this runs per guard per frame. Re-measuring every `REMEASURE_STEP` studs of travel costs a
		-- fraction of a raycast per frame per guard and is imperceptible at walking speed. On a failed
		-- read the previous height is kept — never teleport a creature because a ray missed.
		local seatY = st.seatY or st.anchor.Y
		-- 🔴 Job #109 — A PERCHED GUARD IS NOT ON THE TERRAIN. See `GuardState.perch`. While a hut
		-- ambusher is still inside its house it holds the floor height; the re-measure below would drop
		-- it through the floorboards onto the dirt between the stilts. Once it steps out of the hut the
		-- perch is cleared permanently and it becomes an ordinary guard from that frame on.
		--
		-- ⚠️ IT SETS `seatY` AND FALLS THROUGH — it must not `return`. An early return here skips the
		-- rest of `tickGuard`, which is where the BITE lives: the ambusher would stand on its floor and
		-- politely decline to attack the player standing next to it.
		--
		-- 🔴 AND THE RELEASE TEST IS "IS THERE FLOOR UNDER ME", NOT A RADIUS.
		--
		-- The first cut released the perch at a flat 14 studs from the hut. Measured in play: the
		-- ambusher committed, walked 6.8 studs out of its doorway — and was still 5.2 studs above the
		-- ground, floating out of the house at floor height, because 6.8 < 14. A radius cannot describe
		-- a 24×14 rectangular floor no matter what number you pick: too small and the guard drops
		-- through its own floorboards indoors, too large and it walks on air outside.
		--
		-- So ask the floor directly — one short downward ray against THIS HUT ONLY. Exact, self-
		-- correcting for every model and scale, and it costs one raycast per perched guard per frame,
		-- of which there are two per landing site. The radius survives only as a backstop for the case
		-- where the hut has been destroyed out from under the guard (site culled mid-chase).
		local perched = false
		local perch, perchAt = st.perch, st.perchAt
		if perch and perchAt then
			local stillIn = false
			local hutModel = st.perchModel
			if hutModel and hutModel.Parent then
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Include
				rp.FilterDescendantsInstances = { hutModel }
				-- from just above the floor, down past it: a hit means there are still boards below.
				stillIn = Workspace:Raycast(Vector3.new(pos.X, perch + 1.5, pos.Z), Vector3.new(0, -4, 0), rp) ~= nil
			end
			if stillIn then
				perched = true
				seatY = perch
				st.seatY, st.seatAt, st.seatAtZ = perch, pos.X, pos.Z
			else
				st.perch, st.perchAt, st.perchModel = nil, nil, nil
				st.seatY = nil -- force a fresh terrain reading now that it is outside
			end
		end
		local moved = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(st.seatAt or st.anchor.X, 0, st.seatAtZ or st.anchor.Z)).Magnitude
		if not perched and (st.seatY == nil or moved > REMEASURE_STEP) then
			local g = groundAt(pos.X, pos.Z)
			if g then
				seatY = g + def.size.Y / 2
			end
			st.seatY, st.seatAt, st.seatAtZ = seatY, pos.X, pos.Z
		end
		local footY = seatY
		local np = Vector3.new(pos.X + dir.X * step, footY, pos.Z + dir.Z * step)
		local off = Vector3.new(np.X - st.anchor.X, 0, np.Z - st.anchor.Z)
		-- Job #090: the leash opens up while alerted so a guard can actually REACH a distant shooter.
		-- When the alert lapses the leash snaps back to 55 and this same clamp walks it home, so a camp
		-- never permanently abandons its post.
		-- Job #102: a reinforcement still making its way in from the perimeter keeps the wider leash it was
		-- given at spawn, and drops it the moment it is inside the normal one — from then on it is an
		-- ordinary post-holder. Without the release a guard that had ever been a reinforcement would keep a
		-- 100+ stud rope forever and could be pulled off its post from across the camp.
		if st.entryLeash and off.Magnitude <= GUARD_LEASH then
			st.entryLeash = nil
		end
		local leash = if alerted then GUARD_LEASH_ALERT else (st.entryLeash or GUARD_LEASH)
		-- 🔴 Job #121 — AN OPTIONAL PER-GUARD CEILING ON THAT, and it is what makes "he guards the pad" true.
		--
		-- `GUARD_LEASH_ALERT` is 250 studs, and the crew will be shooting constantly, so an alerted guard's
		-- rope is effectively the whole map. For the end zone's warlord that is not a detail: his post is 46
		-- studs from the extraction pad and 173 from the boat's mooring, so a 250-stud leash lets him be
		-- pulled off the pad entirely — and the crew then walks past him to the thing he is supposed to be
		-- blocking. 70 keeps him covering the pad and the near field and nothing else.
		--
		-- No camp guard carries this attribute, so the alert pull that Job #090 added is untouched for
		-- every camp on the river.
		local leashMax = guard:GetAttribute("LeashMax") :: number?
		if leashMax then
			leash = math.min(leash, leashMax)
		end
		if off.Magnitude > leash then
			local c = st.anchor + off.Unit * leash
			np = Vector3.new(c.X, footY, c.Z)
		end
		guard:PivotTo(CFrame.lookAt(np, np + dir))
	end

	if target and bestD <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		EnemyRig.playOnce(guard, "attack")
		EnemyRig.playSound(guard, "attack")
		local char = target.Parent
		if char then
			-- per-guard `BiteDamage` (the village strength ramp) with the def as the floor
			--
			-- ⚠️ DAMAGE_SCALE is applied HERE, not where the attribute is written, and that is deliberate.
			-- `BiteDamage` is only set when the village strength multiplier is not 1 — so village-1 guards
			-- have no attribute at all and fall through to `def.biteDamage`. Scaling at the write site
			-- therefore missed exactly the camps a new run fights, which is where the complaint came from.
			-- Scaling at the bite covers both paths and can only apply once.
			local bite = ((guard:GetAttribute("BiteDamage") :: number?) or def.biteDamage) * EnemyDefs.DAMAGE_SCALE
			-- 🔴 Job #103 — POST-REVIVE GRACE. Do no damage while the window is open.
			--
			-- Set by `PlayerCombat.revive()` on the `Workspace:GetServerTimeNow()` clock. A revive puts the player back on the
			-- spot they went down with everything that killed them still adjacent and off cooldown, so without this
			-- they are re-downed on the frame they stand up. There is NO single chokepoint for player damage — this
			-- check has to exist at every site that writes a player's `HP`.
			--
			-- ⚠️ Guarded around the DAMAGE only, not around the whole attack. The swing animation and the
			-- attack sound above have already fired and are left alone on purpose: the player should see and
			-- hear that they are being attacked and surviving it, not watch the guards freeze for ten seconds.
			if Workspace:GetServerTimeNow() >= (((char:GetAttribute("InvincibleUntil") :: number?)) or 0) then
				char:SetAttribute("HP", math.max(0, ((char:GetAttribute("HP") :: number?) or 0) - bite))
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	-- Job #122: resolved once here, not inside `tickRocketMan`, because that runs per guard per frame and
	-- the end zone has three grenadiers. Same once-per-frame reasoning as `EnemyServer`'s `refreshSwimmers`.
	refreshTowerRiders()
	for _, guard in CollectionService:GetTagged("CampGuard") do
		if guard:IsA("Model") and guard.Parent then
			tickGuard(guard, dt)
		end
	end
end)

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

-- admin helper (Job 053): force-build the FIRST landing site and return its near-camp spawn position, so an
-- admin can teleport straight to a camp without sailing there. Invoked by AdminServer.
local forceCamp = Instance.new("BindableFunction")
forceCamp.Name = "ForceFirstCamp"
forceCamp.Parent = ServerStorage
forceCamp.OnInvoke = function(): Vector3?
	local first: RiverData.Dock? = nil
	for _, dock in RiverData.docksBetween(RiverData.Z_START, RiverData.Z_START + RiverData.END_DISTANCE) do
		if dock.landing then
			first = dock
			break
		end
	end
	if not first then
		return nil
	end
	-- ⚠️ The first landing can be ~1,900 studs ahead — OUTSIDE `RiverBootstrap`'s generated window. Build
	-- is now refused until the terrain exists (see `terrainReadyAt`), so poll rather than firing once and
	-- teleporting an admin into a camp that was never built.
	local idx = dockIndex(first.z)
	local t0 = os.clock()
	while not built[idx] and os.clock() - t0 < 30 do
		buildLandingSite(first, idx)
		if not built[idx] then
			task.wait(0.5)
		end
	end
	if not built[idx] then
		warn("[Excursion] ForceFirstCamp: river terrain never reached the first landing — nothing built")
		return nil
	end
	local halfW = RiverData.widthAt(first.z) * 0.5
	local waterEdge = RiverData.centerlineX(first.z) + first.side * halfW
	return Vector3.new(waterEdge + first.side * 120, CLEAR_Y + 3, first.z) -- the near camp
end

-- ── Job #084: the day-shift garrison ──────────────────────────────────────────────────────────────
-- One or two guards, at one camp, every 2–3 real minutes — never a wave, and (since Job #100) also at
-- night. The per-camp timer only advances while that camp is actually short-handed, so a full camp does
-- not bank credit and then dump three guards on the player the moment they kill one.
task.spawn(function()
	while true do
		task.wait(GUARD_RESPAWN_TICK)
		-- ⚠️ Job #100 — THE NIGHT SKIP IS GONE, deliberately.
		--
		-- This used to `continue` at night: "night belongs to the river; a cleared camp stays cleared
		-- until dawn". The user's call reverses it — *"after 8h enemies keep coming again, so if I stay
		-- overnight I have to fight again"*. Holding ground in a camp you cleared is now a decision with
		-- a cost, which is the entire point.
		--
		-- Night needs no extra rule to be harder: `DayNightServer` compresses 11 night hours into 180 real
		-- seconds against 13 daylight hours over 480, so a camp re-garrisons more than twice as fast in
		-- real time after dark, for free.
		for i = #garrisons, 1, -1 do
			local g = garrisons[i]
			-- the camp's landing site was culled behind the boat: drop the record with it
			if not g.parent or not g.parent.Parent then
				if DEV_GARRISON_LOG then
					warn(("[Garrison] REAPED camp (%d,%d) — its site is unparented"):format(g.campPos.X, g.campPos.Z))
				end
				table.remove(garrisons, i)
				continue
			end
			local alive = 0
			for _, guard in CollectionService:GetTagged("CampGuard") do
				-- 🔴 Job #119 — THE ROCKET MAN IS NOT PART OF THE GARRISON, AND SKIPPING HIM FIXES TWO BUGS.
				--
				-- This count is a PROXY for camp membership: "any `CampGuard` within GUARD_COUNT_RANGE (90)
				-- studs of the camp centre". The tower slot is `LAYOUT.tower` = {-44, -26}, i.e. ~51 studs
				-- out — and `CampLayout` can push it to ~70. Either way, comfortably inside 90. So without
				-- this line:
				--   1. while he is alive `alive` is inflated by one, `alive >= g.target` holds, `g.timer` is
				--      reset every tick, and the deep camp NEVER re-garrisons for the whole run;
				--   2. and the moment you kill him `alive` drops below target, so the loop sends a BANDIT up
				--      to replace him — the exact opposite of the owner's "kill him once and the tower is
				--      yours", and it would look like the rocket man respawning as the wrong enemy.
				-- He is deliberately absent from `garrisons` for the same reason; this is the other half.
				if guard:GetAttribute("RocketMan") == true then
					continue
				end
				if guard:IsA("Model") and guard.Parent then
					local body = guard.PrimaryPart
					if body and ((guard:GetAttribute("HP") :: number?) or 0) > 0 then
						if (Vector3.new(body.Position.X, 0, body.Position.Z) - Vector3.new(g.campPos.X, 0, g.campPos.Z)).Magnitude <= GUARD_COUNT_RANGE then
							alive += 1
						end
					end
				end
			end
			if DEV_GARRISON_LOG then
				print(("[Garrison] camp (%d,%d) alive=%d target=%d timer=%.0f nextIn=%s")
					:format(g.campPos.X, g.campPos.Z, alive, g.target, g.timer, tostring(g.nextIn)))
			end
			if alive >= g.target then
				g.timer = 0 -- at full strength: no credit accrues
				continue
			end

			-- 🔴 Job #102 — JOB #100's GAME-CLOCK HOLD-OFF IS GONE. THIS IS THE FIX FOR THE REPORTED BUG.
			--
			-- Reported: *"after i defeat both, i can wait whole day and no new enemies come"*, against a
			-- requirement of *"we need new enemie after 2-3 minutes"*.
			--
			-- A WIPED-OUT camp (`alive == 0` — exactly the reported case) used to have to clear TWO gates in
			-- series, and nobody ever added them up:
			--   1. `regarrisonHours` of GAME time — 7 h near, 9 h deep;
			--   2. and only THEN did `g.timer` start accruing toward GUARD_RESPAWN_MIN..MAX.
			--
			-- `DayNightServer` runs 13 daylight hours over 480 real seconds, i.e. **36.9 real seconds per
			-- game hour**. Measured from the constants rather than guessed:
			--     near camp, cleared by day → 258 s hold-off + 120–240 s timer = **6.3–8.3 real minutes**
			--     deep camp, cleared by day → 332 s hold-off + 120–240 s timer = **7.5–9.5 real minutes**
			-- against a full game day of 11.0 minutes. The loop's own header claimed "every 2–3 REAL minutes"
			-- the whole time; the hold-off standing in front of it was simply never counted in that claim.
			--
			-- ⚠️ The intent behind #100's hold-off ("a camp you cleared stays cleared for a while") is being
			-- deliberately dropped, not accidentally lost — the user has now given an explicit number that
			-- contradicts it, and their words are the specification. The whole wait is `nextIn` below.
			--
			-- ⚠️ IF ANYTHING LIKE THIS IS EVER REINSTATED: it stacks IN FRONT of the respawn timer, it does
			-- not replace it, and it is denominated in GAME hours whose real duration changes with the phase
			-- (night runs 2.25× faster). Convert to real seconds and add before quoting a player-facing number.

			g.timer += GUARD_RESPAWN_TICK
			-- Each camp draws its own interval, so two camps do not tick in lockstep and the player cannot
			-- count the rhythm.
			if g.nextIn == nil then
				g.nextIn = respawnRng:NextNumber(GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX)
			end
			if g.timer >= (g.nextIn :: number) then
				g.timer = 0
				g.nextIn = respawnRng:NextNumber(GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX)
				-- the next unoccupied slot in the original line, so replacements stand where the
				-- garrison always stood (Job #058 tuned difficulty against these exact positions)
				-- Job #086: keep the camp's Wolf/Bandit mix on re-man. Wolves hold the first slots, so the
				-- replacement filling slot `alive + 1` is a Wolf exactly while that slot is within the count.
				local wolfSlots = (g.wolves :: number?) or 0
				-- ⚠️ Job #100 — reinforcements arrive from OUTSIDE the perimeter and walk in.
				--
				-- This is the reported bug: they used to appear at `campPos + (alive*7, 0, 8)`, i.e. a few
				-- studs in front of a crew standing in the camp. They now spawn at one of the layout's
				-- entry points beyond the sandbag ring and path to a post, so the player sees them coming.
				--
				-- Still ONE at a time, as it always was — which is also the user's "only 1 or 2 can come,
				-- no more, then after some time others". A trickle keeps a defenceless hauler's situation
				-- survivable (carrying blocks both gun and axe) and keeps the R15 rig count flat.
				-- `approach` is optional on the record (older garrisons predate Job #100), so both it and
				-- the spawn list are checked before use; without them this degrades to the old behaviour
				-- rather than erroring.
				local spawns = g.spawns
				local ga = g.approach
				-- Job #102: pull an entry point back inside the basin — see the note where `waterEdge`/`side`
				-- are recorded in `buildLandingSite`. Only the inland axis can go wrong: entries reach ±114 in
				-- Z against side walls at ±215, so Z is safe by construction and is left alone.
				local function inBasin(v: Vector3): Vector3
					local we, side = g.waterEdge, g.side
					if not we or not side then
						return v -- a record from before this field existed: leave it exactly as it was
					end
					local inland = (v.X - we) * side
					local clamped = math.clamp(inland, ENTRY_MARGIN, BASIN_SIZE - ENTRY_MARGIN)
					if clamped == inland then
						return v
					end
					return Vector3.new(we + side * clamped, v.Y, v.Z)
				end
				local entry = if spawns and ga and #spawns > 0
					then inBasin(CampDefs.slotToWorld(g.campPos, ga, spawns[((alive % #spawns) + 1)]))
					else g.campPos + Vector3.new(alive * 7, 0, 8)
				local posts = g.posts
				-- One or two — the user's "maybe one, maybe two" — and never more than the camp is short.
				local batch = math.min(respawnRng:NextInteger(1, GUARD_RESPAWN_BATCH_MAX), g.target - alive)
				for k = 0, math.max(batch, 1) - 1 do
					local slotIndex = alive + k
					local post: Vector3? = if posts and ga and #posts > 0
						then CampDefs.slotToWorld(g.campPos, ga, posts[((slotIndex % #posts) + 1)])
						else nil
					local entryK = if spawns and ga and #spawns > 0
						then inBasin(CampDefs.slotToWorld(g.campPos, ga, spawns[((slotIndex % #spawns) + 1)]))
						else entry
					-- Spawns OUTSIDE at the entry point, but its home is the post INSIDE, so `tickGuard`
					-- walks it in of its own accord.
					if DEV_GARRISON_LOG then
						print(("[Garrison] +1 %s at entry (%d,%d) -> post %s  [camp (%d,%d)]"):format(
							if slotIndex < wolfSlots then "Wolf" else "Bandit", entryK.X, entryK.Z,
							if post then ("(%d,%d)"):format(post.X, post.Z) else "nil", g.campPos.X, g.campPos.Z))
					end
					spawnGuard(entryK, g.parent, g.strength, if slotIndex < wolfSlots then "Wolf" else "Bandit", g.campPos, post)
				end
			end
		end
	end
end)

-- ── Job #102: teach the loop the first time someone sets foot off the boat ─────────────────────────
--
-- Reported: *"when you exit first time boat, we need message — gather resources etc, now users dont
-- know what to do"*. `Hints.goAshore` is the copy; this is the moment it fires on.
--
-- ⚠️ THE TRIGGER IS A CONFIRMED TRANSITION, NOT THE STATE "not on the boat". Three things forced that:
--
--   1. **Jumping on the deck leaves the boat by this test.** The on-boat check is a raycast 8 studs
--      down from the HumanoidRootPart (copied from `StagingServer.isOnBoat` deliberately — a
--      bounding-box test counts anyone standing on the pier the boat is moored against). The HRP sits
--      ~3 studs above the feet and a jump adds ~5, so a player bouncing on deck mid-river momentarily
--      reads as ashore. Firing on the raw state would teach "gather supplies" to someone in the middle
--      of the river. Hence `ASHORE_CONFIRM` — they must be off it CONTINUOUSLY.
--   2. **The crash-site hub is not the boat.** Before launch the crew stands on land at the hub, which
--      is off-boat by every test there is. `RunStarted` gates the loop, and `boarded` additionally
--      requires that this player has actually stood on the boat at some point — so "exit the boat" is
--      literally true and not merely "is not currently on the boat".
--   3. **Dying is not disembarking.** `PlayerCombat` puts a mid-run respawn back ON the hull, so a
--      death re-arms this rather than tripping it, which is what we want: the hint waits for a real
--      landing.
--
-- `Hints.show` is once-ever by itself, so this does not need to be exact — but clearing `boarded` after
-- firing stops the loop re-asking every 0.5 s for the rest of the run, and re-arms on the next boarding.
local ASHORE_TICK = 0.5
local ASHORE_CONFIRM = 2.0 -- seconds continuously off the boat before it counts as going ashore

local boarded: { [Player]: true } = {}
local offBoatSince: { [Player]: number } = {}

local ashoreParams = RaycastParams.new()
ashoreParams.FilterType = Enum.RaycastFilterType.Include
ashoreParams.FilterDescendantsInstances = { boat }
ashoreParams.IgnoreWater = true

Players.PlayerRemoving:Connect(function(plr: Player)
	boarded[plr] = nil
	offBoatSince[plr] = nil
end)

task.spawn(function()
	while true do
		task.wait(ASHORE_TICK)
		if Workspace:GetAttribute("RunStarted") ~= true then
			continue
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				offBoatSince[plr] = nil
				continue
			end
			if Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), ashoreParams) ~= nil then
				boarded[plr] = true
				offBoatSince[plr] = nil
			elseif boarded[plr] then
				local since = offBoatSince[plr]
				if not since then
					offBoatSince[plr] = os.clock()
				elseif os.clock() - since >= ASHORE_CONFIRM then
					Hints.show(plr, "goAshore")
					boarded[plr] = nil -- handled; re-arms when they next stand on the boat
					offBoatSince[plr] = nil
				end
			end
		end
	end
end)

-- ── Job #121: manning the extraction end zone ─────────────────────────────────────────────────────
--
-- 🔴 THE END ZONE HAS TO BE BUILT FROM HERE, AND THAT IS NOT A CONVENIENCE.
--
-- `tickGuard`'s second line destroys any `CampGuard` with no entry in `guardState` — a local table in this
-- script. So a rig spawned by a script in `EndZone/` is tagged, picked up by the Heartbeat loop above on
-- its very next frame, found stateless, and **destroyed inside 16 ms**. Either the AI moves out of this
-- file (≈700 lines of repeatedly-debugged code, and every camp on the river put at risk to add content to
-- the end zone — offered to the owner and declined for this job), or the end zone is built through the
-- same five functions the camps use.
--
-- So `EndGarrison` owns the PLACE — every position, every count, every number — and this hook lends it the
-- BEHAVIOUR. Nothing about camps is reachable from that module: it cannot see `guardState`, `campChasers`,
-- `garrisons` or the site-cull loop, and the three additions this job made to this file
-- (`addFloor`/`floorFilter`, the `FireInterval` attribute, this hook) are all no-ops when nobody opts in.
local EndGarrison = require(ServerScriptService:WaitForChild("EndZone"):WaitForChild("EndGarrison"))

-- 🔴 Job #121 — TEARING GUARDS DOWN IS NOT `:Destroy()`, AND GETTING THAT WRONG BREAKS THE **NEXT** RUN.
--
-- Three pieces of state live outside the model and none of them is released by destroying it:
--   1. `campChasers[campKey]` — decremented ONLY in `tickGuard`'s death path and the site-cull loop. Destroy
--      two chasing guards from under it and the count stays pinned at `CAMP_MAX_CHASERS` forever, so after a
--      reset **no end-zone guard can ever acquire a chase slot again**: a field of eleven statues.
--   2. `guardState[guard]` — left keyed on a destroyed model.
--   3. the rig's `AnimationTrack`s and `EnemyRig`'s own per-rig Heartbeat entry — this is exactly open
--      finding **0035** (the site-cull loop does the same thing), which is why this goes through
--      `EnemyRig.destroy` and not `Instance:Destroy`.
--
-- Mirrors the release the site-cull loop does, so the two paths cannot drift.
local function disposeGuards(container: Instance): number
	local n = 0
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("Model") and CollectionService:HasTag(d, "CampGuard") then
			local st = guardState[d]
			if st then
				if st.chasing then
					local k = campKey(st.camp)
					campChasers[k] = math.max((campChasers[k] or 1) - 1, 0)
					st.chasing = false
				end
				guardState[d] = nil
			end
			EnemyRig.destroy(d) -- NOT :Destroy() — the rig holds AnimationTracks
			n += 1
		end
	end
	return n
end

local endGarrisonApi: EndGarrison.Api = {
	spawnGuard = spawnGuard,
	spawnRocketMan = spawnRocketMan,
	towerPads = towerPads,
	placeOnPad = placeOnPad,
	lootPrompt = lootPrompt,
	addFloor = addFloor,
	disposeGuards = disposeGuards,
	setChaserCap = setChaserCap,
}

-- 🔴 POLLED, NOT DRIVEN OFF `GetAttributeChangedSignal("RunStarted")`. THAT WAS A BUG, FOUND IN PLAY.
--
-- `StagingServer` sets `RunStarted = false` ONCE at boot and `true` when the run launches; nothing ever
-- sets it back. `RunServer` sets `RunEnded = true` and nothing ever clears that either. So a second
-- `RunStarted = true` — which is exactly what `AdminServer`'s force-start does — is not a CHANGE, the
-- signal never fires, and a reset hung off it silently never runs. Measured: run 2 in the same server
-- inherited run 1's depleted field (17 children down to 6) and a stale `EndBossAlive`.
--
-- Polling the STATE instead of listening for a transition cannot be fooled that way, and it is what the
-- rest of this script already does (the landing-site loop below is a 0.5 s poll).
--
-- ⚠️ The teardown is on `RunEnded`, and that is the safety property that matters: the moment a run is over
-- the warlord flag is cleared and the guards are released, so no later state can inherit an
-- `EndBossAlive = true` from a boss who no longer exists — which `EscapeServer` would read as "not yet" and
-- turn into an unwinnable run.
--
-- Two BUILD triggers, and the second one is not optional:
--   1. the boat crossing `TRIGGER_Z` (900 studs upstream of the mouth) — so all fourteen rigs exist long
--      before the airfield is in view and nothing pops in front of the player;
--   2. any player already standing in the end zone — because `AdminServer.tpEndBase` jumps a tester there
--      **without moving the boat**. Without this clause that button lands you in an empty airfield and the
--      whole feature reads as broken. It is also how this job gets tested at all.
task.spawn(function()
	while true do
		task.wait(1)
		local started = Workspace:GetAttribute("RunStarted") == true
		local ended = Workspace:GetAttribute("RunEnded") == true
		if ended then
			if EndGarrison.isBuilt() then
				EndGarrison.reset() -- releases chase slots + rigs, clears the boss flag
			end
		elseif
			started
			and not EndGarrison.isBuilt()
			and (hull.Position.Z >= EndGarrison.TRIGGER_Z or EndGarrison.anyoneInEndZone())
		then
			EndGarrison.build(endGarrisonApi)
		end
	end
end)

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - 200, boatZ + CAMP_AHEAD) do
		if dock.landing then
			buildLandingSite(dock, dockIndex(dock.z))
		end
	end

	-- cull landing sites far behind (frees trees/huts/crates/guards) — never while a player is still ashore
	for idx, model in siteModels do
		local siteZ = RiverData.Z_START + idx * RiverData.DOCK_SPACING
		if boatZ - siteZ > CULL_BEHIND then
			local occupied = false
			for _, plr in ipairs(Players:GetPlayers()) do
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and math.abs(root.Position.Z - siteZ) < BASIN_SIZE then
					occupied = true
					break
				end
			end
			if not occupied then
				for _, d in model:GetDescendants() do
					if d:IsA("Model") and guardState[d] then
						local gst = guardState[d]
						if gst.chasing then -- release its chase slot with it
							local k = campKey(gst.camp)
							campChasers[k] = math.max((campChasers[k] or 1) - 1, 0)
						end
						guardState[d] = nil -- drop the guard's AI state so it doesn't leak
					end
				end
				-- Job #100: release this site's cached camp layouts and garrison records with it. Without
				-- this a long run accumulates one layout table and one garrison entry per camp forever,
				-- for camps that no longer exist.
				for i = #garrisons, 1, -1 do
					local g = garrisons[i]
					if g.parent == model then
						CampLayout.forget(g.campPos)
						table.remove(garrisons, i)
					end
				end
				model:Destroy()
				siteModels[idx] = nil
				built[idx] = nil
			end
		end
	end

	task.wait(0.5)
end
