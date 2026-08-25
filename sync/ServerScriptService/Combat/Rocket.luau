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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Ballistics"))
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

return Rocket
