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
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local Hints = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Hints"))
-- Job #076: camp clearings draw from the SAME shore-band table the riverbank uses, so the two can't drift
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))
-- Job #077: the camp's CONTENTS (which model plays which role, where it sits, how the ground is painted,
-- what the VFX/light budget is) live in CampDefs. Nothing in this file decides dressing.
local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))
local CampLayout = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampLayout"))
local Campfire = require(ServerScriptService:WaitForChild("World"):WaitForChild("Campfire"))
local CampAmbience = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampAmbience"))
local EnemyRig = require(ServerScriptService:WaitForChild("Enemies"):WaitForChild("EnemyRig"))
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

local function groundAt(x: number, z: number): number
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
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
			awardSalvage(player, 80)
			crate:Destroy()
		end -- inventory full → leave the crate so the player can free a slot
		return
	elseif kind == "Ammo" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		local def = ItemDefs.get(id)
		InventoryService.addAmmo(player, id, (def and def.ammoPerCrate) or 12)
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
	strength: number? -- per-village HP/bite multiplier; nil = 1 (village 1)
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
		prop(CampDefs.MODEL.tower, t.X, t.Z, parent, { collide = true, shadow = false, faceTo = firePos })
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
local function buildShopSign(pos: Vector3, faceTo: Vector3, parent: Instance, ground: number)
	local d = Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z)
	local yaw = if d.Magnitude > 0.01 then math.atan2(d.X, d.Z) else 0
	local base = CFrame.new(pos.X, ground, pos.Z) * CFrame.Angles(0, yaw, 0)

	for _, dx in ipairs({ -3.4, 3.4 }) do
		local post = block("Post", Vector3.new(0.5, 7, 0.5), Theme.color.woodDark, base * CFrame.new(dx, 3.5, 0), parent, Enum.Material.Wood)
		post.CanCollide = false
	end
	local board = block("ShopSign", Vector3.new(8, 3, 0.4), Theme.color.wood, base * CFrame.new(0, 6.2, 0), parent, Enum.Material.WoodPlanks)
	board.CanCollide = false

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.MaxDistance = 320 -- occluded correctly by the world, unlike the billboard it replaces
		sg.Parent = board
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(0.9, 0.8)
		lbl.Position = UDim2.fromScale(0.05, 0.1)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Theme.color.cream -- never pure white (STYLEGUIDE §4)
		lbl.TextStrokeColor3 = Theme.color.stroke
		lbl.TextStrokeTransparency = 0.4
		lbl.Font = Theme.font.sign -- SpecialElite — physical world signs only
		lbl.TextScaled = true
		lbl.Text = "TRADING POST"
		lbl.Parent = sg
	end
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
local function buildTradingPost(pos: Vector3, parent: Instance, faceTo: Vector3)
	local padGround = groundAt(pos.X, pos.Z) -- ONE measurement for the whole pad
	local postModel = prop(CampDefs.MODEL.post, pos.X, pos.Z, parent, { collide = true, faceTo = faceTo })

	-- The counter survives as an INVISIBLE anchor, so the shop prompt keeps its name, its reach and its
	-- position in front of the building rather than being buried inside 95 parts of geometry.
	local approach = (Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z))
	approach = if approach.Magnitude > 0.01 then approach.Unit else Vector3.new(0, 0, -1)
	local counterPos = pos + approach * 10
	local counter = block("Counter", Vector3.new(6, 4, 2), Theme.color.wood, CFrame.new(counterPos.X, padGround + 2, counterPos.Z), parent, Enum.Material.WoodPlanks)
	counter.Transparency = 1
	counter.CanCollide = false
	counter.CanQuery = false

	local lateral = Vector3.new(approach.Z, 0, -approach.X)
	buildShopSign(pos + approach * 16 + lateral * 7, pos + approach * 40, parent, padGround)

	-- A chest of gold OUT FRONT of the vendor, so the trading post reads as the place gold is SPENT
	-- (Job #079). ⚠️ Dressing only — no prompt, no attribute, no Gold granted.
	--
	-- ⚠️ IT CANNOT SIT AT THE COUNTER. `counterPos` is only `approach * 10`, and `BahayKubo7` measures
	-- **40×50 studs** — so the counter (an invisible prompt anchor, which does not care) is INSIDE the
	-- building footprint, and the first version of this put the chest under the stilt house's deck where
	-- nobody can see it. Measure the building and step outside it instead of picking a number.
	local standoff = 26
	if postModel and postModel:IsA("Model") then
		local _, pext = (postModel :: Model):GetBoundingBox()
		-- the box's half-extent along `approach` (its support function), + room for the chest and a margin
		standoff = (math.abs(approach.X) * pext.X + math.abs(approach.Z) * pext.Z) / 2 + 7
	end
	-- opposite side from the shop sign, so the two landmarks flank the approach instead of stacking
	local chestPos = pos + approach * standoff - lateral * 7
	prop(CampDefs.MODEL.goldChest, chestPos.X, chestPos.Z, parent, { collide = true, faceTo = faceTo })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Trading Post"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player: Player)
		openShop:FireClient(player)
	end)
end

-- 🔴 DO NOT BUILD A CAMP ON TERRAIN THAT DOES NOT EXIST YET.
--
-- `RiverBootstrap` STREAMS the river: it keeps `AHEAD_CHUNKS` (~1800 studs) generated ahead of the boat
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

	-- The canopy that frames the clearing goes in FIRST, around the three inland sides.
	plantClearingRing(basinCenterX, dock.z, BASIN_SIZE, waterEdge, dock.side, model, rng)

	-- ...and the interior gets LIGHT undergrowth only, kept inside the ring zone so palms and bushes
	-- don't fight the canopy for the same ground. Down from 45 scattered edge-to-edge: the middle of a
	-- camp you fight in should be open, and the trees should be the thing enclosing it.
	local interiorReach = BASIN_SIZE / 2 - CampDefs.CLEARING.ringZone
	for _ = 1, CampDefs.CLEARING.interiorCount do
		local rx = basinCenterX + rng:NextNumber(-1, 1) * interiorReach
		local rz = dock.z + rng:NextNumber(-1, 1) * interiorReach
		-- keep trees on land (out of the channel) AND out of the walking lane to the camps
		if (rx - waterEdge) * dock.side > 10 and distToSeg(rx, rz, pathAx, pathAz, pathBx, pathBz) > PATH_HALF then
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

	local nearGarrison = buildCampAt(nearPos, model, nearGuards, { "Gasoline", "Gasoline" }, CampDefs.KIND.near, nearApproach, rng, strength) -- 2 gas → a haul can fund skipping a stop (Job 054)
	local deepGarrison = buildCampAt(deepPos, model, deepGuards, { "Metal", "Ammo" }, CampDefs.KIND.deep, deepApproach, rng, strength)

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
	local postZ = dock.z - 24
	local postPos = Vector3.new(bankForSlice(postZ - 30, postZ + 30, dock.side) + dock.side * 90, CLEAR_Y, postZ)
	buildTradingPost(postPos, model, shorePoint) -- faces back toward the water, so you see its front on landing

	-- ⚠️ Job #100 — these read the camp's GENERATED layout, not `CampDefs.LAYOUT`.
	-- The nugget and the two kind-crates are placed out here rather than inside `buildCampAt`, and they
	-- used to share the same fixed slot table it did. With a per-camp layout they must fetch the SAME one
	-- (`CampLayout.forCamp` is memoised on camp position) or the nugget lands inside a hut that only
	-- exists in this camp's arrangement.
	local nearLayout = CampLayout.forCamp(nearPos, {
		seed = math.floor(nearPos.X * 31 + nearPos.Z * 17),
		kind = CampDefs.KIND.near, resourceCount = 2, deep = false,
	})
	local deepLayout = CampLayout.forCamp(deepPos, {
		seed = math.floor(deepPos.X * 31 + deepPos.Z * 17),
		kind = CampDefs.KIND.deep, resourceCount = 2, deep = true,
	})

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
	st.biteTimer += dt
	local pos = body.Position

	-- Job #090: an alerted guard has been SHOT, so it does not need line of sight or a sight radius to
	-- know someone is out there — it hunts the nearest player at any range until the alert lapses.
	local alerted = st.alertUntil ~= nil and os.clock() < (st.alertUntil :: number)
	local target: BasePart? = nil
	local bestD = if alerted then math.huge else def.aggroRadius
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
			if (campChasers[ck] or 0) < CAMP_MAX_CHASERS then
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
		local moved = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(st.seatAt or st.anchor.X, 0, st.seatAtZ or st.anchor.Z)).Magnitude
		if st.seatY == nil or moved > REMEASURE_STEP then
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
