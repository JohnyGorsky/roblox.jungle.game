--!strict
-- Rocket.luau — the Bazooka's projectile: one broadcast at launch, one blast four seconds later (Job #118).
--
-- `WeaponServer` owns the trigger (which gun, is it loaded, is the player allowed to shoot). This module
-- owns everything that happens AFTER the trigger, the way `CombatFx` owns everything after a hit.
--
-- ── The split between this and the client ─────────────────────────────────────────────────────────
-- The server sends ONE event describing the whole flight and then goes quiet for four seconds. Every
-- client draws its own rocket from those parameters; the server independently applies the damage on the
-- same clock. Nothing about the projectile is replicated per frame.
--
-- 🔴 AND THAT IS NOT AN OPTIMISATION — A SERVER-MOVED PART WOULD VISIBLY STEP.
-- `PlaneServer:237-251` already learned this the hard way and wrote it down: *"A server script writing an
-- anchored part's CFrame replicates as discrete property writes, and the client does NOT interpolate
-- them"*. The intro plane arrived in chunks and had to be re-rendered client-side
-- (`IntroPlaneSmooth.local.luau`) to fix it. A rocket crossing 300 studs in 4 s would do exactly the same
-- for everyone except (possibly) the shooter. Sending the parameters once also survives Instance
-- Streaming — a locally-created part cannot stream out from under its own flight.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players") -- Job #119: the enemy blast damages players; the player's never does
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Ballistics"))
-- Job #121: only for `END_ZONE_Z_START` — the boat is exempt from an ENEMY blast inside the end zone. See
-- the note in `enemyBlast`.
local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local CombatFx = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatFx"))
local KillReward = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("KillReward")) :: any

local Rocket = {}

-- 🔴 THE THREE TAGS ARE THE WHOLE SAFETY MODEL. READ THIS BEFORE CHANGING THE BLAST.
--
-- The obvious way to write area damage is "find every Model in the radius that has an `HP` attribute and
-- subtract from it". **That kills the entire crew and sinks the boat**, because `HP` is not an
-- enemy-only name: a player's health is a character-Model attribute (`PlayerCombat:108`
-- `char:SetAttribute("HP", MAX_HP)`) and the boat's hull is `boat:SetAttribute("HP", …)`
-- (`EnemyServer:366`). Same attribute, same shape, completely different thing.
--
-- The owner's decision for this weapon is that it damages enemies, camp guards and generators and
-- **never** a player, a crewmate or the boat. Iterating these tags is what makes that true BY
-- CONSTRUCTION rather than by a "skip players" filter that a later edit could drop without noticing.
-- Nothing in the game tags a character or the boat with any of them.
--
-- ⚠️ AND NOT A ROBLOX `Explosion` INSTANCE EITHER, which is the other obvious answer and is the worst
-- available: enemies here take damage through the `HP` ATTRIBUTE, not through a `Humanoid`, so an
-- `Explosion` would deal exactly ZERO damage to every enemy in the radius while ragdolling and killing
-- every player in it. The same three-tag contract is what `WeaponServer.enemyFrom` encodes for hitscan.
local TARGET_TAGS = { "Enemy", "CampGuard", "Generator" }

local remote = Instance.new("RemoteEvent")
remote.Name = "RocketLaunched"
remote.Parent = ReplicatedStorage

-- ── publish the projectile art so CLIENTS can draw it ─────────────────────────────────────────────
-- The mesh lives in `ServerStorage.AssetLibrary.Weapons.Rocket`, which no client can read. One clone into
-- ReplicatedStorage at startup keeps the AssetLibrary as the single source of the asset while letting
-- every client build its own rocket locally.
--
-- ⚠️ `AssetLibrary` is NOT Rojo-synced (ASSETS.md) — an unsaved place simply has no `Weapons` folder. So
-- this warns and moves on rather than erroring, and `RocketFx` falls back to a plain part. Same
-- everything-degrades rule as `WeaponAssets`.
local function publishArt()
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local weapons = lib and lib:FindFirstChild("Weapons")
	local src = weapons and weapons:FindFirstChild("Rocket")
	if not (src and src:IsA("BasePart")) then
		warn("[Rocket] ServerStorage.AssetLibrary.Weapons.Rocket is missing or is not a BasePart "
			.. "(a Model wrapper does NOT count) — clients will draw the fallback projectile")
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("CombatArt")
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "CombatArt"
		f.Parent = ReplicatedStorage
		folder = f
	end
	local existing = folder:FindFirstChild("Rocket")
	if existing then
		existing:Destroy()
	end
	local clone = (src :: BasePart):Clone()
	clone.Name = "Rocket"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	clone.Parent = folder
	print(("[Rocket] projectile art published (%s studs long)"):format(string.format("%.2f", clone.Size.X)))
end
publishArt()

-- ── the blast ─────────────────────────────────────────────────────────────────────────────────────
-- 🔴 EVERY TARGET IS FOUND AT IMPACT TIME. NOTHING IS CAPTURED AT LAUNCH.
-- Four seconds is a long time in this game and the world is actively demolished during it:
--   · `EnemyServer:404` despawns any enemy more than CULL_BEHIND (260) studs behind the boat, and the
--     boat covers ~208 studs in 4 s — so a target just behind the boat at launch is GONE at impact.
--   · `EnemyServer:386` / `EnemyRig:668` destroy an enemy the moment it dies to anything else.
--   · `ExcursionServer:2308` destroys a camp guard at HP<=0 immediately, with no topple.
--   · Whole camp sites are culled wholesale once passed.
-- A list captured at launch would hold destroyed instances, and the first `SetAttribute` on one throws
-- and aborts the rest of the blast — i.e. one reaped enemy silently cancels the damage to everything
-- else in the crater.
local function blast(shooterName: string, shooter: Player?, impact: Vector3, def: ItemDefs.ItemDef)
	local radius = def.blastRadius or 30
	local damage = def.blastDamage or 0
	local inner = def.blastInner or 0.5
	local minFactor = def.blastMinFactor or 0.25
	if damage <= 0 or radius <= 0 then
		return
	end

	-- A player who has left mid-flight is not a valid `KillReward` recipient, but the rocket they fired
	-- still lands — a fired rocket does not un-fire.
	local payTo: Player? = if shooter and shooter.Parent ~= nil then shooter else nil

	local seen: { [Model]: true } = {}
	local hits = 0
	for _, tag in ipairs(TARGET_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if not inst:IsA("Model") or seen[inst] then
				continue
			end
			-- Re-checked here, not at launch: `GetTagged` can still hand back an instance that was
			-- destroyed this frame, and a destroyed model is not in the world any more.
			if inst.Parent == nil or not inst:IsDescendantOf(Workspace) then
				continue
			end
			local ok, pivot = pcall(function()
				return inst:GetPivot().Position
			end)
			if not ok then
				continue
			end
			local dist = (pivot - impact).Magnitude
			local factor = Ballistics.blastFactor(dist, radius, inner, minFactor)
			if factor <= 0 then
				continue
			end
			seen[inst] = true

			local before = (inst:GetAttribute("HP") :: number?) or 0
			if before <= 0 then
				continue -- already dead and awaiting its reaper; do not re-report it
			end
			local dealt = math.floor(damage * factor + 0.5)
			local after = math.max(0, before - dealt)
			inst:SetAttribute("HP", after)
			if payTo then
				KillReward.onEnemyDamaged(payTo, inst, before, after)
			end
			-- One number per TARGET, never per part — `CombatFx`'s header forbids the per-fragment
			-- version, and a 30-stud crater over a camp would be the worst offender in the game.
			CombatFx.hit(pivot, before - after, "deal")
			hits += 1
			print(string.format(
				"[Rocket] BLAST %s  %.1f studs  x%.2f  HP %d -> %d%s",
				inst.Name, dist, factor, before, after, if after <= 0 then "  (KILLED)" else ""
			))
		end
	end
	print(string.format("[Rocket] %s impact at %s — %d target(s)", shooterName, tostring(impact), hits))
end

-- ── launch ────────────────────────────────────────────────────────────────────────────────────────
-- `impact` has already been resolved by the caller through `Ballistics.resolveImpact`, so the point sent
-- to the clients and the point the blast uses are the same value, not two computations of it.
function Rocket.launch(player: Player, def: ItemDefs.ItemDef, origin: Vector3, impact: Vector3)
	local flight = def.flightTime or 4
	local arc = Ballistics.arcHeightFor((impact - origin).Magnitude)
	local radius = def.blastRadius or 30

	-- One event, everything the client needs for the whole 4 s: where it starts, where it lands, how long
	-- it takes, how high it lobs, and how big the crater is (so the public warning ring is honest).
	remote:FireAllClients(origin, impact, flight, arc, radius)

	local name = player.Name
	task.delay(flight, function()
		blast(name, player, impact, def)
	end)
end

-- ══════════════════════════════════════════════════════════════════════════════════════════════════
-- THE ENEMY-FIRED ROCKET — Job #119 (the Rocket Man on the camp watchtower)
-- ══════════════════════════════════════════════════════════════════════════════════════════════════
--
-- 🔴 WHY THIS LIVES IN THIS FILE, AND WHY IT IS A SECOND FUNCTION RATHER THAN A FLAG.
--
-- It is HERE because the `RocketLaunched` RemoteEvent is *created* above, by this module. A separate
-- module creating its own would hand every client two remotes and half the rockets would go undrawn; a
-- separate module `WaitForChild`-ing this one would add a server-module load-order dependency for no
-- benefit. One file owns the rocket.
--
-- It is a SEPARATE FUNCTION because the two blasts want **opposite** target sets, and the header at the
-- top of this file spends fifteen lines explaining that the player's blast is safe *by construction* —
-- it iterates three tags rather than filtering players out, precisely so that a later edit cannot
-- quietly drop the filter. Merging these two behind a `hitsPlayers` boolean throws that away: it is
-- exactly the shape in which the PLAYER's rocket eventually learns to kill the crew and sink the boat.
-- Two functions, two target sets, no shared branch.
--
--            │ `blast` (player-fired)        │ `enemyBlast` (rocket-man-fired)
--   ─────────┼───────────────────────────────┼──────────────────────────────────────────
--   players  │ NEVER                         │ yes — the owner's call
--   the boat │ NEVER                         │ yes — the owner's call
--   the tags │ yes                           │ yes (friendly fire — his shell hurts his own camp)
--   reward   │ credited to the shooter       │ NONE — nobody fired it
--
-- ⚠️ THE MISSING `KillReward` IS A DECISION, NOT AN OVERSIGHT. `onEnemyDamaged` needs a Player, and there
-- is no player here — but more importantly, paying out for tower-inflicted kills would hand the player a
-- strategy of standing next to the garrison and letting the tower farm it for them.
--
-- The two share `Ballistics.blastFactor`, so the falloff curve — and therefore the promise the red ring
-- makes about its own rim — stays one calculation for both sides of the fight.

export type BlastSpec = {
	flightTime: number,
	blastDamage: number,
	blastRadius: number,
	blastInner: number,
	blastMinFactor: number,
}

-- 🔴 EVERY SITE THAT WRITES A PLAYER'S `HP` MUST RE-CHECK THESE TWO. There is no chokepoint.
-- `tickGuard`'s bite says so in as many words, and Job #103 shipped the bug this prevents: a revive puts
-- the player back on the spot they went down with everything that killed them still adjacent, so without
-- the grace window they are re-downed on the frame they stand up. A live 30-stud crater is the worst
-- possible place for that, because the rocket lands 4 s after anyone could have reacted to it.
local function canHurtPlayer(char: Model): boolean
	if char:GetAttribute("Downed") == true then
		return false -- already out of the fight; do not re-damage a downed crewmate
	end
	return Workspace:GetServerTimeNow() >= (((char:GetAttribute("InvincibleUntil") :: number?)) or 0)
end

-- Like `blast`, EVERY TARGET IS FOUND AT IMPACT TIME AND NOTHING IS CAPTURED AT LAUNCH — the reasoning in
-- `blast`'s header applies unchanged (4 s is long enough for the whole landing site to be culled, and the
-- first `SetAttribute` on a destroyed instance throws and aborts the rest of the crater).
-- `shooter` is the model that fired, and it is EXCLUDED from its own crater. That is not the same thing as
-- the friendly fire the owner asked for: his shell hurting the guards beside him is friendly fire, his
-- shell hurting HIM is suicide, and nothing in the design asked for a unit that can kill itself.
--
-- It also decouples the safety of the weapon from the tuning of `minFireRange`: with this, that number is
-- free to be chosen for how the fight READS (see its note in `CampDefs`) instead of being held hostage to
-- keeping the shooter out of its own blast radius.
local function enemyBlast(impact: Vector3, spec: BlastSpec, shooter: Model?)
	local radius, damage = spec.blastRadius, spec.blastDamage
	if damage <= 0 or radius <= 0 then
		return
	end
	local inner, minFactor = spec.blastInner, spec.blastMinFactor
	local hits = 0

	local function apply(what: Instance, name: string, pos: Vector3)
		local dist = (pos - impact).Magnitude
		local factor = Ballistics.blastFactor(dist, radius, inner, minFactor)
		if factor <= 0 then
			return
		end
		local before = (what:GetAttribute("HP") :: number?) or 0
		if before <= 0 then
			return -- already dead/wrecked and awaiting its reaper
		end
		local dealt = damage * factor
		local after = math.max(0, before - dealt)
		what:SetAttribute("HP", after)
		hits += 1
		print(string.format(
			"[EnemyRocket] BLAST %s  %.1f studs  x%.2f  HP %.1f -> %.1f%s",
			name, dist, factor, before, after, if after <= 0 then "  (DOWN)" else ""
		))
	end

	-- 1. PLAYERS. Measured from `HumanoidRootPart`, the same part `tickGuard` measures a target from, so
	--    "am I in the ring" means the same thing to the shell as it does to the guards.
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root and char:IsDescendantOf(Workspace) and canHurtPlayer(char) then
			apply(char, player.Name, root.Position)
		end
	end

	-- 2. THE BOAT. `EnemyServer` keeps the hull's health in the same `HP` attribute the creatures use, so
	--    nothing special is needed — but it is found by name here rather than captured, because the boat
	--    is rebuilt on respawn (`BoatServer:80` destroys the old one).
	--
	-- 🔴 Job #121 — NOT INSIDE THE END ZONE, AND THIS IS A LOSE-ARM, NOT A NICETY.
	--
	-- Job #119's own verification measured it: `[EnemyRocket] BLAST Boat 11.8 studs x1.00 HP 100.0 -> 60.0`,
	-- then 20, then 0, then `[Boat] DESTROYED — run over`. **Three shells.** The boat has 100 max HP
	-- (`BoatServer:267`) and `Workspace.BoatDestroyed` is one of `RunServer`'s two LOSE arms.
	--
	-- That was survivable while rocket men only stood at river camps, because the crew is aboard and moving.
	-- Job #121 puts three of them on the end zone's towers — two of which are ~65 studs from the mooring, so
	-- inside their 160-stud sight and well outside `minFireRange` — at the one place in the game where the
	-- crew MUST abandon the boat and fight ashore for minutes. Without this the reliable outcome is a run
	-- LOST to the towers shelling an empty hull, after the crew had effectively arrived.
	--
	-- Job #111's own follow-up flagged the underlying hazard and left it standing: *"BoatDestroyed remains an
	-- instant lose — including while the crew is already ashore walking to the plane."* This closes the half
	-- of it that this job would otherwise have weaponised, and matches the exemption `EnemyServer.applyBite`
	-- now applies to wildlife in the same water.
	--
	-- ⚠️ THE HULL ONLY. Players in the crater still take the full blast, in the end zone as everywhere else.
	local boat = Workspace:FindFirstChild("Boat")
	if boat and boat:IsA("Model") then
		local hull = boat.PrimaryPart or boat:FindFirstChild("Hull")
		if hull and hull:IsA("BasePart") and hull.Position.Z < RiverData.END_ZONE_Z_START then
			apply(boat, "Boat", hull.Position)
		end
	end

	-- 3. FRIENDLY FIRE. The same three tags the player's rocket uses — enemies, camp guards and generators
	--    — because the owner's call was that his shell hurts whatever is in the crater. ⚠️ Including the
	--    rocket man himself, who wears the `CampGuard` tag: that is why `tickRocketMan` refuses to fire at
	--    anything closer than `MIN_FIRE_RANGE`, which puts the crater rim clear of his own tower.
	local seen: { [Model]: true } = {}
	for _, tag in ipairs(TARGET_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if not inst:IsA("Model") or seen[inst] or inst == shooter then
				continue
			end
			if inst.Parent == nil or not inst:IsDescendantOf(Workspace) then
				continue
			end
			local ok, pivot = pcall(function()
				return inst:GetPivot().Position
			end)
			if ok then
				seen[inst] = true
				apply(inst, inst.Name, pivot)
			end
		end
	end

	print(string.format("[EnemyRocket] impact at %s — %d target(s)", tostring(impact), hits))
end

-- `impact` has already been resolved by the caller through `Ballistics.resolveImpact`, so the point the
-- clients draw and the point the blast goes off at are the same value rather than two computations of it.
--
-- ⚠️ IT BROADCASTS ON THE SAME REMOTE AS THE PLAYER'S ROCKET, AND THAT IS THE WHOLE TRICK.
-- `RocketFx.local.luau` is a pure listener that knows nothing about who fired — so the red warning ring,
-- the 4-second arc, the whistle, the shockwave and the two impact clips all arrive for free, and an
-- incoming shell looks and sounds exactly like one of your own. Zero client-side work for this feature.
function Rocket.launchEnemy(origin: Vector3, impact: Vector3, spec: BlastSpec, shooter: Model?)
	local flight = spec.flightTime
	local arc = Ballistics.arcHeightFor((impact - origin).Magnitude)
	remote:FireAllClients(origin, impact, flight, arc, spec.blastRadius)
	-- ⚠️ `shooter` is captured, but it is only ever COMPARED against live instances four seconds later —
	-- never indexed, never assumed to still exist. A shooter killed mid-flight simply matches nothing, and
	-- its rocket still lands: a fired rocket does not un-fire.
	task.delay(flight, function()
		enemyBlast(impact, spec, shooter)
	end)
end

return Rocket
