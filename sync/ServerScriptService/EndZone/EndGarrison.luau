--!strict
-- EndGarrison.luau — the extraction end zone's defenders (Job #121).
--
-- *"Endgame now has empty enemies. What i want - entering endgame, and getting to plane challenging. So i
-- want … 2) endgame territory has towers. Each tower must have 1 grenadier. And on ground 10 enemies.
-- (random wolfs or bandits), but do not make that they all run towards you. And one bigger and scaled
-- bandit that is boss, he has x10 health."*
--
-- So: one grenadier on every `RangerTower` in `Workspace.EndBase`, ten Wolf/Bandit raiders spaced across
-- the open middle of the airfield, and one 550 HP warlord holding the extraction pad. Plus an AMMO chest on
-- every tower's inboard pad — see `CHEST_AMMO` for why ammo and not the camps' salvage.
--
-- And the warlord GATES THE EXTRACTION (owner's call): `EscapeServer` will not fire while he lives, because
-- without that a player could sprint dock → pad past all fourteen defenders and win — the pad grants
-- invincibility the instant you stand on it.
--
-- ── 🔴 WHY THIS IS A MODULE THAT BORROWS BEHAVIOUR RATHER THAN A SERVER SCRIPT THAT OWNS IT ──────────
--
-- The camp guard AI — `tickGuard`, `tickRocketMan`, the `guardState` table, the `campChasers` budget — is
-- all **local to `ExcursionServer.server.luau`**. And `tickGuard`'s second line is:
--
--       if not body or not st then guard:Destroy(); return end
--
-- `st` comes from that local `guardState`. So a guard built anywhere else is tagged `CampGuard`, picked up
-- by ExcursionServer's Heartbeat on the very next frame, found to have no AI state, and **destroyed**. The
-- rig would appear and vanish inside 16 ms.
--
-- The alternative — lifting ~700 lines of six-times-debugged AI into a shared module — was put to the owner
-- and declined for this job: it would put every camp on the river at risk to add content to the end zone.
--
-- So the split is: **ExcursionServer owns behaviour, this module owns the place.** It receives the four
-- spawn/dress functions it needs through `api` and holds every position and every number itself. Nothing
-- about camps can change as a result of editing this file, which is the property that made the cross-system
-- edit acceptable at all.
--
-- ── What this file deliberately does NOT do ───────────────────────────────────────────────────────────
--
-- · **No respawn, and there is nothing to do to get that.** The end zone is never appended to
--   ExcursionServer's `garrisons` list, so its day-shift respawn loop never sees it. Kill the field once and
--   it is yours — the same rule the hut ambushers and the Rocket Man already follow. (The nearest real camp
--   is at z = 17600, **700 studs** from `FIELD_CENTRE`, comfortably outside that loop's 90-stud
--   `GUARD_COUNT_RANGE`, so no camp's garrison count is perturbed either.)
-- · **No new geometry.** *"no additional buildings, just space them in endgame middle"* — this module places
--   creatures and one crate per tower pad. It builds no structures.
--
-- ── How *"do not make that they all run towards you"* is delivered ────────────────────────────────────
--
-- The ten raiders share ONE `campPos`, so they share one chase budget — `RAIDER_CHASERS` = 4 of ten. The
-- other six hold their posts until a chaser dies or loses you. The warlord carries his OWN key so he is
-- never locked out of the fight by four wolves (see `BOSS_CAMP`), which puts the field's ceiling at five
-- attackers out of eleven.
--
-- ⚠️ The budget is not only a difficulty dial. `tickGuard` nils a slot-less guard's TARGET, and its bite is
-- gated on having one — so a raider with no slot will not swing at a player standing next to it. Set the cap
-- too low and the "restraint" reads as scenery you can walk through.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))

local EndGarrison = {}

-- ── the api ExcursionServer hands over ────────────────────────────────────────────────────────────────
-- Behaviour only. Every one of these already exists and is already proven at camps; none of them is
-- modified for this job.
export type Api = {
	-- (anchorPos, parent, strength, guardType, campPos, postPos) -> the rig
	spawnGuard: (Vector3, Instance, number?, string?, Vector3?, Vector3?) -> Model,
	-- (defenderPad, tower, parent, strength, campPos) -> the rig, or nil if the def is missing
	spawnRocketMan: (BasePart, Model, Instance, number?, Vector3?) -> Model?,
	-- (tower) -> defenderPad, chestPad — ALSO makes both pads intangible + non-queryable (see its header)
	towerPads: (Model) -> (BasePart?, BasePart?),
	-- (modelName, pad, parent, scale) -> the placed prop, seated on the pad's top face
	placeOnPad: (string, BasePart, Instance, number?) -> PVInstance?,
	-- (crate, actionText) -> wires the LootPrompt + the lootable tag the client outlines
	lootPrompt: (PVInstance, string) -> (),
	-- (inst) -> teach `groundAt`'s seating raycast about a surface that is not terrain. See RUNWAY below.
	addFloor: (Instance) -> (),
	-- (container) -> tear down every CampGuard under it PROPERLY: release its chase slot, drop its AI
	-- state, and `EnemyRig.destroy` it. See `clearField` for why a plain `:Destroy()` is a bug.
	disposeGuards: (Instance) -> number,
	-- (campPos, cap) -> how many guards keyed to that position may chase at once. Camps keep the default 2.
	setChaserCap: (Vector3, number) -> (),
}

-- ── tuning ────────────────────────────────────────────────────────────────────────────────────────────

-- 🔴 WHEN THE FIELD IS BUILT. 900 studs upstream of the mouth, i.e. z = 17100 — the crew is at or just
-- past the last camp (z = 17600 is the final landing) and still has the whole approach to sail. Building
-- here means all fourteen rigs exist well before anyone can see the airfield, so nothing pops in front of
-- the player; and it is late enough that the first 17 km of the run pays nothing for it.
EndGarrison.TRIGGER_Z = RiverData.END_ZONE_Z_START - 900

-- The open middle of the airfield, which is where the owner circled on the screenshot. MEASURED, not
-- eyeballed: the basin floor is dead flat at y = 18.00 across x ∈ [200..500], z ∈ [18150..18450] (probed on
-- a 50-stud grid, 2026-08-27), the boat's dock is at (172, 18302) and the extraction pad at (391, 18300) —
-- so this is the midpoint of the 219-stud walk between them.
local FIELD_CENTRE = Vector3.new(280, 18, 18295)

-- Ten raiders on two rings about that centre. The inner four are the ones you meet first walking up from
-- the dock; the outer six spread the fight across the field instead of stacking it in one clump.
local RINGS = {
	{ r = 30, n = 4, a0 = 0.125 },
	{ r = 62, n = 6, a0 = 0.0 },
}

-- 🔴 EVERY POST IS SEARCHED FOR AND VALIDATED, NOT HARDCODED — see `findPosts`. The airfield is
-- hand-dressed content the owner keeps editing (towers, sandbag walls, barrels, tents, a bunker), so a
-- table of literal coordinates would be correct on the day it was written and wrong the first time
-- something is moved. These are the acceptance criteria instead.
local SLOT_CLEAR = 10 -- studs of empty space a raider needs around it (no visible EndBase part inside this)
local SELF_CLEAR = 16 -- and this far from every other defender, so they read as SPACED, not as a huddle
local FLOOR_MIN, FLOOR_MAX = 14, 26 -- a floor outside this band is not the basin: a hillside, a roof, a stump
-- How far the search may wander from a slot's nominal angle/radius before giving up on it. Both are needed:
-- the towers and the bunker are large enough that an angular nudge alone cannot clear them, and pulling the
-- radius in is what gets a slot past the sandbag/barrel cluster on the south side.
local NUDGE = { 0, 0.06, -0.06, 0.12, -0.12, 0.18, -0.18, 0.26, -0.26, 0.34, -0.34, 0.42, -0.42 }
local RADIUS_FACTORS = { 1.0, 0.82, 1.18, 0.66, 1.34 }

-- 50/50 Wolf or Bandit — *"random wolfs or bandits"*.
local RAIDER_TYPES = { "Wolf", "Bandit" }

-- 🔴 HOW MANY OF THE TEN MAY FIGHT AT ONCE — 4, on the owner's call, against a camp's 2.
--
-- This is not a difficulty dial, it is a "how many of them are real" dial. `tickGuard` nils a slot-less
-- guard's TARGET, and the bite is gated on having a target — so a raider with no slot will not swing at a
-- player standing next to it. At the camps' cap of 2 out of ten, EIGHT of the field would have been scenery
-- you walk straight through, which reads as a broken finale rather than as a restrained one.
--
-- The owner's *"do not make that they all run towards you"* is still honoured: four is well under eleven,
-- and the other six hold their posts until a chaser dies or loses you. With the warlord's own reserved slot
-- the field's ceiling is five attackers.
local RAIDER_CHASERS = 4

-- ── the warlord ───────────────────────────────────────────────────────────────────────────────────────
-- On the dock→pad line, 46 studs short of the extraction pad: the last thing between the field and the
-- plane. Reserved BEFORE the raiders are placed, so the raider search's own `SELF_CLEAR` rule pushes the
-- outer-ring slot that wants (342, 18295) aside rather than standing a wolf inside him.
local BOSS_POST = Vector3.new(345, 18, 18300)
local BOSS_TYPE = "BanditBoss"

-- 🔴 THE WARLORD GETS HIS OWN CHASE BUDGET, AND WITHOUT IT HE IS A STATUE YOU HAVE TO KILL.
--
-- `tickGuard` gates the BITE on having a target, and it nils the target when the guard's camp has no free
-- chase slot. So a defender with no slot does not merely stand still — it **does not attack at all**, even
-- with the player next to it. And a slot is held for as long as a guard has a target, which while alerted is
-- forever (`tickGuard` sets its search distance to `math.huge` when alerted, and the crew will be shooting
-- constantly). Two raiders can therefore hold both of the zone's slots for the whole fight.
--
-- With eleven ground fighters sharing one key that is a coin-flip on whether the enemy the extraction is
-- GATED ON ever swings at anybody. Giving him a key of his own — `campKey` is just `"%d:%d"` of the position
-- handed to `spawnGuard` — gives him a budget he is the only member of. He always fights, the raiders still
-- share their own 2, and the field's ceiling is 3 attackers rather than 2.
--
-- ⚠️ It also splits him off `alertNear`'s spread (it matches on `st.camp` equality), so shooting a raider
-- across the field no longer wakes the boss and vice versa. That is the better behaviour anyway.
local BOSS_CAMP = BOSS_POST

-- How far the warlord may ever be pulled from his post, alerted or not. See the `LeashMax` note in
-- `ExcursionServer.tickGuard`: the default alert leash is 250, which reaches the boat's mooring.
local BOSS_LEASH_MAX = 70

-- 🔴 `strength` IS DELIBERATELY nil FOR EVERY SPAWN IN THIS FILE, THE BOSS INCLUDED.
-- `spawnGuard`'s strength multiplier scales HP **and** `BiteDamage` together. A ×10 strength boss would
-- therefore hit for 55 per swing against a 100 HP player. His hit points live in `EnemyDefs.BanditBoss.hp`
-- (550) precisely so his bite can stay Bandit-grade at 5.53, which is what the owner asked for.
local NO_STRENGTH: number? = nil

-- ── the grenadiers ────────────────────────────────────────────────────────────────────────────────────
-- 12 s between shells instead of the camps' 20 (owner's call, "faster cadence"). Three towers firing on a
-- 12 s cycle puts a shell on the field roughly every 4 s while you cross it. Written as a per-guard
-- ATTRIBUTE rather than by editing `CampDefs.TOWER.rocketMan.fireInterval`, so every camp on the river
-- keeps its 20 s exactly.
-- 🔴 36, AND IT WAS 12. Job #122, after the owner played it: *"reduce enemy (bazooka) fire rate. It is not
-- survivable."*
--
-- The number you FEEL is not this one — it is this divided by the number of towers that can see you, because
-- `EndGarrison` phases them evenly across the cycle. At 12 s across three towers the field took a shell
-- every **4 seconds** (measured in Play: gaps of 4.04 and 3.95 s). At 36 it is every 12 s in the open middle,
-- and every 36 s at the warlord's post, where the `SightMax` cap below leaves only one grenadier in reach.
-- So the boss fight went from a shell every 4 s to one every 36 s — a 9× reduction where it matters most.
--
-- ⚠️ END ZONE ONLY, on the owner's call. River camps keep `CampDefs.TOWER.rocketMan.fireInterval` = 20 and
-- have ONE tower each, so a camp already only ever saw a shell every 20 s; the unsurvivable part was three
-- of them at once, which happens nowhere else.
local GRENADIER_FIRE_INTERVAL = 36

-- 🔴 HOW FAR THEY SHOOT — capped for the end zone. Job #122: *"also reduce how far they shoot"*.
--
-- ⚠️ THE NUMBER THAT WAS ACTUALLY HURTING IS NOT `aggroRadius` (160). `tickRocketMan` uses
-- `if alerted then R.range else aggroRadius`, `R.range` is **300**, and `alertUntil` is refreshed by any hit
-- within `ALERT_SPREAD` (70) for `GUARD_ALERT_SECONDS` (15) — so in a live firefight the tower crews are
-- alerted essentially continuously and were engaging from 300 studs across a ~400-stud airfield. Lowering
-- the 160 alone would have changed almost nothing. `SightMax` caps BOTH branches, so there is no second
-- number to forget.
--
-- MEASURED in Edit, 2026-08-27 — how many of the three can engage, by cap:
--                          160   130   110    90    70
--     boat mooring          2     2     2     2     0
--     field centre          3     3     3     1     0
--     extraction pad        1     1     1     1     0
--     warlord's post        3     1     1     1     1
--     river mouth           0     0     0     0     0
--
-- 130 is the cliff worth having: it takes the **warlord's post from three grenadiers to one** — that is where
-- the boss fight happens and where the complaint came from — while leaving the open middle contested by all
-- three, which is where the fight is supposed to be. 110 is identical to 130 at every measured spot, so
-- there is nothing to buy until 90, which also thins the middle to one. **90 is the lever if the middle is
-- still too hot.**
--
-- Note the river mouth reads 0 at every cap: the boat was never shelled on its way in, and is not now.
local GRENADIER_SIGHT_MAX = 130

-- ── the tower chests: AMMO, not salvage (owner's call, after review) ─────────────────────────────────
-- 🔴 WHY THIS CHANGED FROM THE CAMPS' SALVAGE CHEST.
--
-- There is no trading post past z = 17 600. Salvage buys nothing in the end zone, so a salvage chest here
-- pays in a currency the run is about to end — while the crew that arrives DRY (which is precisely what the
-- sea gauntlet is designed to cause) faces a 550 HP boss behind a gate that will not open until he is dead,
-- holding a 15-damage axe. That is 37 connected swings under three grenadiers. Ammo on the towers turns
-- "climb the tower" from a detour into the thing that buys you the boss fight.
--
-- ⚠️ PISTOL AND SHOTGUN ONLY, AND **NEVER** M16 OR BAZOOKA.
-- `pickupLoot`'s ammo branch grants `ItemDefs.get(id).ammoPerCrate` and falls back to **12** when that field
-- is absent. The M16 and the Bazooka deliberately have no `ammoPerCrate` — both entries say so in capitals:
-- that absence is the ONLY thing holding their rounds to a hard per-run cap against a paid purchase. An M16
-- ammo chest here would quietly grant 12 rounds off the fallback and break a documented monetisation
-- decision from two jobs away.
--
-- One per tower, indexed rather than random so the same tower always pays the same thing and the field can
-- be learned: Pistol (18 rounds) / Shotgun (6 shells) / Pistol. Pistol twice because it is the gun a crew
-- is most likely to still be holding this late, and 18 × 20 damage is the reliable half of the boss's 550.
local CHEST_AMMO = { "Pistol", "Shotgun", "Pistol" }

-- ── the boss gate on extraction (owner's call, Job #121) ──────────────────────────────────────────────
-- 🔴 A POSITIVE LIVENESS FLAG, NOT A KILL REQUIREMENT, AND THE DIRECTION MATTERS ENORMOUSLY.
--
-- `RunServer`'s ONLY win arm is `Workspace.EscapeReached` (RunServer:255). There is no other way out of a
-- run except dying. So if this gate were expressed as "the win needs `EndBossKilled == true`", then every
-- way this module can fail to run — no `EndBase` in the place, the boss slot failing to resolve, a syntax
-- error, the module missing from the sync — would produce an **unwinnable run**, and it would look like the
-- extraction pad being broken rather than like the garrison being broken.
--
-- Expressed this way round, the failure mode is a field with no boss in it and a pad that works exactly as
-- it does today. `EscapeServer` blocks only while this reads `true`; unset means no gate.
EndGarrison.BOSS_ALIVE_ATTR = "EndBossAlive"

local FOLDER_NAME = "EndGarrison"

-- Fixed seed: this is hand-built content, not a procedural camp. The finale should be the same fight every
-- run — so it can be balanced against, and so a playtest is reproducible.
local SEED = 121_0827

-- ── measurement helpers ───────────────────────────────────────────────────────────────────────────────

-- The basin floor under (x, z), or nil if what is there is not floor. TERRAIN ONLY, on purpose: this is the
-- validation probe for "is this a place a raider can stand", and every post is on terrain by construction
-- (the runway starts at x ≈ 365, east of every post including the boss's at 345). Seating is not this
-- function's job — `spawnGuard` does that with ExcursionServer's own `groundAt`.
local function floorAt(x: number, z: number): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Workspace.Terrain }
	rp.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, 140, z), Vector3.new(0, -220, 0), rp)
	if hit and hit.Normal.Y > 0.7 then
		return hit.Position.Y
	end
	return nil -- a wall face, a stump side, or no terrain at all
end

-- Is there hand-placed scenery in the way? `Include`-filtered to `EndBase` so the query cannot be answered
-- by terrain, by the boat, or by the rigs we are placing as we go.
--
-- ⚠️ `Transparency < 0.99` skips the two invisible marker pads inside every tower (`Defender`,
-- `InnerPlace`) and any other invisible anchor. Counting those would reject slots for obstacles the player
-- cannot see — and the tower pads are 43 studs up in the first place.
local function blockedAt(endBase: Instance, x: number, y: number, z: number): boolean
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { endBase }
	op.MaxParts = 8
	for _, p in ipairs(Workspace:GetPartBoundsInRadius(Vector3.new(x, y + 3, z), SLOT_CLEAR, op)) do
		if p.Transparency < 0.99 then
			return true
		end
	end
	return false
end

-- ── post finding ──────────────────────────────────────────────────────────────────────────────────────
-- `taken` is seeded with the boss's post before this runs, so the raiders spread around him.
local function findPosts(endBase: Instance, taken: { Vector3 }): { Vector3 }
	local posts: { Vector3 } = {}

	local function farEnough(x: number, z: number): boolean
		for _, t in ipairs(taken) do
			if (Vector3.new(x, 0, z) - Vector3.new(t.X, 0, t.Z)).Magnitude < SELF_CLEAR then
				return false
			end
		end
		return true
	end

	for ri, ring in ipairs(RINGS) do
		for i = 0, ring.n - 1 do
			local base = (ring.a0 + i / ring.n) * math.pi * 2
			local found: Vector3? = nil
			for _, rf in ipairs(RADIUS_FACTORS) do
				for _, nudge in ipairs(NUDGE) do
					local a, r = base + nudge, ring.r * rf
					local x = FIELD_CENTRE.X + math.cos(a) * r
					local z = FIELD_CENTRE.Z + math.sin(a) * r
					local y = floorAt(x, z)
					if
						y
						and y >= FLOOR_MIN
						and y <= FLOOR_MAX
						and farEnough(x, z)
						and not blockedAt(endBase, x, y, z)
					then
						found = Vector3.new(x, y, z)
						break
					end
				end
				if found then
					break
				end
			end
			if found then
				posts[#posts + 1] = found :: Vector3
				taken[#taken + 1] = found :: Vector3
			else
				-- 🔴 SAID OUT LOUD. A silent nine-of-ten reads in play as "the endgame is easy" and there is
				-- nothing in the log to contradict it. GROUND-RULES §8: no silent caps.
				warn(("[EndGarrison] ring %d slot %d — no clear post found near (%.0f, %.0f) r=%.0f; "
					.. "that raider is NOT placed. The airfield has probably been re-dressed; widen NUDGE/"
					.. "RADIUS_FACTORS or move FIELD_CENTRE."):format(
					ri, i, FIELD_CENTRE.X, FIELD_CENTRE.Z, ring.r))
			end
		end
	end
	return posts
end

-- ── the boss's liveness watch ─────────────────────────────────────────────────────────────────────────
-- Two signals, because there are two ways he can stop existing and only one of them writes HP:
--   · `HP` reaching 0 — what the three damage sites (`WeaponServer`, `GunServer`, `MeleeServer`) and the
--     bazooka all do, and what `tickGuard` reads a frame later to start his death;
--   · the model leaving the DataModel — `tickGuard`'s death path ends in `EnemyRig.destroy`, which calls
--     `model:Destroy()`; and a second run's `reset()` clears the folder wholesale.
-- Whichever fires first opens the gate; the flag is only ever written once, downward.
local function watchBoss(boss: Model)
	Workspace:SetAttribute(EndGarrison.BOSS_ALIVE_ATTR, true)

	local function down(reason: string)
		if Workspace:GetAttribute(EndGarrison.BOSS_ALIVE_ATTR) ~= true then
			return -- already open; do not log twice
		end
		Workspace:SetAttribute(EndGarrison.BOSS_ALIVE_ATTR, false)
		print(("[EndGarrison] WARLORD DOWN (%s) — extraction unlocked"):format(reason))
	end

	boss:GetAttributeChangedSignal("HP"):Connect(function()
		if ((boss:GetAttribute("HP") :: number?) or 0) <= 0 then
			down("killed")
		end
	end)
	boss.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			down("removed from the world")
		end
	end)
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────────────

local built = false

-- Remembered from the last `build`, so `reset()` — which is called from a `RunStarted` signal with no api in
-- scope — can still tear the guards down properly rather than orphaning their state.
local lastApi: Api? = nil

-- Drop the previous field, if any. Split out from `reset` so `build` can use it without also clearing the
-- `built` flag it is in the middle of setting.
--
-- 🔴 `folder:Destroy()` ALONE IS A BUG, AND IT BREAKS THE **NEXT** RUN, NOT THIS ONE.
--
-- `campChasers` is decremented only when `tickGuard` sees a guard die. Destroying two CHASING guards out
-- from under it leaves that count pinned at `CAMP_MAX_CHASERS` for the rest of the server's life — so the
-- second run's garrison can never acquire a chase slot and stands there as eleven statues. Destroying the
-- rigs directly also leaks their `AnimationTrack`s and `EnemyRig`'s per-rig Heartbeat entry, which is open
-- finding **0035** verbatim. `api.disposeGuards` does all three releases; see its note in ExcursionServer.
local function clearField()
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		local api = lastApi
		if api then
			local n = api.disposeGuards(folder)
			if n > 0 then
				print(("[EndGarrison] tore down %d guard(s) — chase slots and rigs released"):format(n))
			end
		else
			-- Only reachable if something calls `reset()` before any `build()`, i.e. there is nothing alive
			-- to release. Say so rather than silently destroying rigs the wrong way.
			warn("[EndGarrison] clearing a field with no api on record — guards destroyed without release")
		end
		folder:Destroy()
	end
	Workspace:SetAttribute(EndGarrison.BOSS_ALIVE_ATTR, nil)
end

-- Tear the field down and re-arm, so an admin-forced second run in the same server gets a fresh garrison.
--
-- 🔴 CLEARING `EndBossAlive` IS THE LOAD-BEARING LINE HERE. Without it a second run inherits a `true` from
-- a warlord who no longer exists, `EscapeServer` refuses to extract, and the run is **unwinnable** with
-- nothing on screen to explain why. `BunkerServer` resets off `RunStarted` for exactly this class of reason.
function EndGarrison.reset()
	built = false
	clearField()
end

function EndGarrison.isBuilt(): boolean
	return built
end

function EndGarrison.build(api: Api): boolean
	if built then
		return false
	end

	local endBase = Workspace:FindFirstChild("EndBase")
	if not endBase then
		-- The lobby tree has no end zone, and a GAME place that has lost it has bigger problems than this.
		warn("[EndGarrison] no Workspace.EndBase — the end zone stands undefended")
		return false
	end
	built = true
	lastApi = api -- so `reset()`, which fires off a signal with no api in scope, can still release properly
	clearField() -- drop any previous run's folder + stale boss flag before rebuilding

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	-- ⚠️ Parented to WORKSPACE, not into `EndBase`. Studio Sync is two-way and `EndBase` is hand-authored
	-- content in the place file; runtime-spawned rigs have no business inside it, and a tidy-up in Studio
	-- that deleted them would be editing the saved scene.
	folder.Parent = Workspace

	-- ONE camp key for the ten raiders, so they share one chase budget and one alert spread. The warlord
	-- carries his own key (`BOSS_CAMP`) and is therefore never locked out of fighting.
	local campPos = FIELD_CENTRE
	api.setChaserCap(campPos, RAIDER_CHASERS)
	local rng = Random.new(SEED)

	-- 🔴 TEACH THE SEATING RAYCAST ABOUT THE RUNWAY, BEFORE ANYTHING IS SPAWNED.
	--
	-- MEASURED, 2026-08-27: `Objects.RunWay` slab top = **21.11**, the terrain beneath it = **18.00**, and
	-- the runway spans x ∈ [365..435] at the pad. ExcursionServer's `groundAt` filters its ray to
	-- `Terrain` ONLY, and `tickGuard` re-measures with it every 6 studs of travel — so a guard chasing a
	-- player toward the extraction pad walks at 18.00 across a surface whose top is 21.11 and ends up
	-- **3.1 studs sunk into the concrete**, buried to above the knee. The warlord's leash (55 studs from
	-- x = 345) reaches x = 400, so this is not an edge case, it is his entire post.
	--
	-- ⚠️ ONLY THE RUNWAY MODELS. Registering `EndBase` wholesale would offer `groundAt` a tower platform at
	-- y = 61.7 and the plane's fuselage at y = 34.77 as candidate floors. Both are above its existing
	-- `CLEAR_Y + BASIN_RISE` = 23 clamp and would be rejected — but the runway's 21.11 sits just *under*
	-- that clamp, which is the only reason this works at all, and it is far too fine a margin to hand a
	-- whole folder.
	local runways = 0
	local runwayTop = -math.huge
	for _, d in ipairs(endBase:GetDescendants()) do
		if d:IsA("Model") and d.Name == "RunWay" then
			api.addFloor(d)
			runways += 1
			local cf, size = (d :: Model):GetBoundingBox()
			runwayTop = math.max(runwayTop, cf.Position.Y + size.Y / 2)
		end
	end
	-- 🔴 MEASURE THE MARGIN, DO NOT TRUST THE COMMENT. `groundAt` throws away any hit above
	-- `CLEAR_Y + BASIN_RISE` = 23 as a leftover terrain stump, and the runway top measured 21.11 — a
	-- 1.89-stud margin that the whole fix rests on. If the owner ever raises the runway, `addFloor` silently
	-- stops working and the symptom is "the boss is knee-deep in concrete", which nobody will trace back
	-- here. A comment cannot fail; this can.
	if runways > 0 and runwayTop > 23 then
		warn(("[EndGarrison] 🔴 RUNWAY TOP IS %.2f, ABOVE groundAt's 23-STUD CLAMP — guards near the "
			.. "extraction pad WILL seat on the terrain %.2f studs below the slab and appear buried. "
			.. "Raise CLEAR_Y + BASIN_RISE in ExcursionServer, or lower the runway."):format(
			runwayTop, runwayTop - 18))
	elseif runways > 0 then
		print(("[EndGarrison] runway floor registered ×%d, top y=%.2f (clamp 23, margin %.2f)")
			:format(runways, runwayTop, 23 - runwayTop))
	end

	-- ── the grenadiers, one per tower ─────────────────────────────────────────────────────────────────
	-- BY NAME, recursively — the same contract every other editor-placed fitting in this game uses
	-- (`EscapeServer`'s `Escape`, `GeneratorServer`'s `Generator*`), so re-parenting a tower while dressing
	-- the scene does not silently un-man it.
	local towers = 0
	local grenadiers = 0
	local chests = 0
	for _, d in ipairs(endBase:GetDescendants()) do
		if d:IsA("Model") and d.Name == CampDefs.MODEL.tower then
			towers += 1
			local tower = d :: Model
			-- ⚠️ Called for its SIDE EFFECT as much as its return: `towerPads` is what makes the two editor
			-- pads non-colliding and non-queryable. The owner authored them `Transparency = 1` but a
			-- collidable invisible slab on the deck is exactly what they would otherwise be, and a
			-- *queryable* one breaks `HudState`'s "am I aboard?" probe and the grenadier's own aim ray.
			local defenderPad, chestPad = api.towerPads(tower)

			if chestPad then
				local C = CampDefs.TOWER.chest
				local crate = api.placeOnPad(C.model, chestPad, folder, C.scale)
				if crate then
					local ammoId = CHEST_AMMO[(chests % #CHEST_AMMO) + 1]
					crate.Name = "LootCrate"
					-- `Kind = "Ammo"` + `Id` is the camps' own weapon-cache contract (`makeKindCrate`), so
					-- `pickupLoot` grants, notifies and destroys with no new code. See CHEST_AMMO.
					crate:SetAttribute("Kind", "Ammo")
					crate:SetAttribute("Id", ammoId)
					api.lootPrompt(crate, ammoId .. " Ammo")
					chests += 1
				end
			else
				warn(("[EndGarrison] a tower has no %q pad — no chest on that platform")
					:format(CampDefs.TOWER.pad.chest))
			end

			if defenderPad then
				local man = api.spawnRocketMan(defenderPad, tower, folder, NO_STRENGTH, campPos)
				if man then
					man:SetAttribute("FireInterval", GRENADIER_FIRE_INTERVAL)
					-- 🔴 STAGGER THEM, OR THREE CRATERS LAND ON THE SAME PLAYER ON THE SAME FRAME.
					--
					-- `spawnRocketMan` starts every man at `fireTimer = 0`, all three are built in this one
					-- loop on one frame, all three pick the NEAREST player, and all three aim at the ground
					-- under them. So without a phase they fire together: three overlapping 30-stud craters at
					-- 40 damage each inside the inner radius = **120 against a 100 HP player**. Job #119
					-- verified the red ring is escapable with ONE shell; three at once from three bearings is
					-- a different geometry that nobody has tested.
					--
					-- Spread evenly across the cycle, so the field takes a shell every `interval / towers`
					-- seconds — which is the "roughly every 4 s" this job was designed around.
					man:SetAttribute("FirePhase", (grenadiers * GRENADIER_FIRE_INTERVAL) / 3)
					man:SetAttribute("SightMax", GRENADIER_SIGHT_MAX)
					grenadiers += 1
				end
			else
				warn(("[EndGarrison] a tower has no %q pad — no grenadier on that platform")
					:format(CampDefs.TOWER.pad.defender))
			end
		end
	end
	if towers == 0 then
		warn(("[EndGarrison] no %q found under EndBase — the towers are unmanned"):format(CampDefs.MODEL.tower))
	end

	-- ── the warlord, reserved first ───────────────────────────────────────────────────────────────────
	local taken: { Vector3 } = {}
	local bossFloor = floorAt(BOSS_POST.X, BOSS_POST.Z)
	local bossOk = false
	if bossFloor and bossFloor >= FLOOR_MIN and bossFloor <= FLOOR_MAX then
		local boss = api.spawnGuard(
			Vector3.new(BOSS_POST.X, bossFloor, BOSS_POST.Z),
			folder,
			NO_STRENGTH,
			BOSS_TYPE,
			BOSS_CAMP -- his OWN chase-slot key, so he is never locked out of fighting. See BOSS_CAMP.
		)
		boss:SetAttribute("EndBoss", true) -- so anything later can find him without matching on HP
		boss:SetAttribute("LeashMax", BOSS_LEASH_MAX) -- he holds the pad; he does not follow you to the boat
		watchBoss(boss)
		taken[#taken + 1] = Vector3.new(BOSS_POST.X, bossFloor, BOSS_POST.Z)
		bossOk = true
	else
		-- 🔴 FAIL OPEN. No boss means no gate — `BOSS_ALIVE_ATTR` is never set, `EscapeServer` never blocks,
		-- and the run is still winnable. The alternative (gate anyway) is an unwinnable run.
		warn(("[EndGarrison] no basin floor at the warlord's post (%.0f, %.0f) — NO BOSS, and therefore NO "
			.. "extraction gate. The pad works as it did before this job."):format(BOSS_POST.X, BOSS_POST.Z))
	end

	-- ── the ten raiders ───────────────────────────────────────────────────────────────────────────────
	local posts = findPosts(endBase, taken)
	for i, p in ipairs(posts) do
		local kind = RAIDER_TYPES[rng:NextInteger(1, #RAIDER_TYPES)]
		local guard = api.spawnGuard(p, folder, NO_STRENGTH, kind, campPos)
		guard:SetAttribute("EndRaider", true)
		print(("[EndGarrison] raider %02d  %-6s at (%.0f, %.1f, %.0f)"):format(i, kind, p.X, p.Y, p.Z))
	end

	print(("[EndGarrison] built: %d grenadiers on %d towers (fire every %ds each, phased -> a shell on the "
		.. "field every %.1fs; sight capped %d), %d ammo chests, %d/%d raiders (max %d chasing), boss=%s, "
		.. "%d runway floor(s) registered")
		:format(grenadiers, towers, GRENADIER_FIRE_INTERVAL,
			(if grenadiers > 0 then GRENADIER_FIRE_INTERVAL / grenadiers else 0), GRENADIER_SIGHT_MAX,
			chests, #posts, RINGS[1].n + RINGS[2].n, RAIDER_CHASERS, tostring(bossOk), runways))

	return true
end

-- Is a player (or the boat) inside the end zone right now? Used by the build trigger, because
-- `AdminServer.tpEndBase` jumps a tester into the end zone **without moving the boat** — and without this
-- the button lands them in an empty airfield and the whole feature reads as broken.
function EndGarrison.anyoneInEndZone(): boolean
	local Players = game:GetService("Players")
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root.Position.Z >= RiverData.END_ZONE_Z_START - 200 then
			return true
		end
	end
	return false
end

-- Count what is actually standing, for the boot log and for verification. Reads the live tag rather than a
-- number this module remembers, so it can never report a garrison that has already been killed.
function EndGarrison.aliveCount(): number
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if not folder then
		return 0
	end
	local n = 0
	for _, g in CollectionService:GetTagged("CampGuard") do
		if g:IsA("Model") and g:IsDescendantOf(folder) and ((g:GetAttribute("HP") :: number?) or 0) > 0 then
			n += 1
		end
	end
	return n
end

return EndGarrison
