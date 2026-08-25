--!strict
-- WeaponServer.server.luau — authoritative free-aim hitscan for the LOOTED guns (Job 006 → Job 015).
--
-- The client sends only the world AIM POINT it tapped. The SERVER re-raycasts from the shooter's own
-- character toward that point and applies damage — the client never says "I hit X", so it can't fake
-- hits. Which gun fires (and its damage/range/spread/ammo) is decided SERVER-SIDE from the shooter's
-- ActiveItem — you can only fire a gun you've looted into a slot and equipped. Ammo is PER-PLAYER,
-- PER-GUN (Job 015): the mounted turret (GunServer) still uses the shared boat pool. Rate-limited.
--
-- ── Job #117: BURST weapons ───────────────────────────────────────────────────────────────────────
-- The M16 fires 20 bullets over 2 s from one trigger pull, for one round. The SERVER owns that clock:
-- the client cannot lengthen a burst, shorten the gap between bullets, or fire two at once. A gun is a
-- burst gun purely by having `burstDuration` in `ItemDefs` — nothing here branches on an item id.
--
-- ── Job #118: PROJECTILE weapons ──────────────────────────────────────────────────────────────────
-- The Bazooka lobs a rocket that lands 4 s later and blasts a radius. Same principle: a gun is a
-- projectile gun purely by having `flightTime`, and this file still only owns the TRIGGER — the flight
-- and the blast live in `Combat/Rocket.luau`, the way a landed hit lives in `Combat/CombatFx.luau`.
-- There are now three kinds of trigger and they are decided in a fixed order: burst, then projectile,
-- then the original single shot as the fall-through.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Ballistics"))
local CombatFx = require(game:GetService("ServerScriptService"):WaitForChild("Combat"):WaitForChild("CombatFx"))
local Rocket = require(game:GetService("ServerScriptService"):WaitForChild("Combat"):WaitForChild("Rocket"))
local KillReward = require(game:GetService("ServerScriptService"):WaitForChild("Economy"):WaitForChild("KillReward")) :: any

local remote = Instance.new("RemoteEvent")
remote.Name = "FireWeapon"
remote.Parent = ReplicatedStorage

local lastShot: { [Player]: number } = {}
local rng = Random.new()

-- ── the weapon-owned lockout (Job #117, widened in #118) ─────────────────────────────────────────
-- 🔴 `lockUntil` IS THE LOCKOUT, AND IT IS DELIBERATELY NOT `lastShot` + `fireInterval`.
-- The rate limiter below multiplies `fireInterval` by `0.965 ^ SkillGun` (Gun Discipline). On a weapon
-- whose cycle IS its design that is a silent bug, not a buff:
--   · M16     — a 2.0 s `fireInterval` becomes **1.401 s at SkillGun 10**, so two bursts overlap for
--               0.6 s: ~6 extra bullets, ~84 extra damage, no error, nothing in the log.
--   · Bazooka — a 5 s reload would become **3.503 s**, against a requirement of "a hard 5-second reload,
--               identical for every player".
-- It is also invisible in testing, because Studio dev profiles start empty (`ProfileConfig`) and the
-- usual way to fix that is the admin panel's one-click "MAX ALL Skills" — i.e. the tester is *in* the
-- broken case. Both paid weapons are exempt from Gun Discipline by decision (see `SkillDefs`), so this
-- latch is flat for everybody and NOTHING scales it.
--
-- ⚠️ RENAMED from `burstUntil` in Job #118. It was never really about bursts — it is "this weapon says
-- you may not fire again until T", and the Bazooka's reload is the same idea with a different source
-- number (`cooldown` rather than `burstDuration`). Leaving a reload running through something called
-- `burstUntil` is how the next reader gets this wrong.
local lockUntil: { [Player]: number } = {}
-- Bumped to cancel a burst already in flight. A `task.spawn`ed loop cannot be killed from outside, so it
-- checks its own token every bullet and stops when it stops matching.
local burstToken: { [Player]: number } = {}

-- Live aim during a burst. Unreliable on purpose — the same shape as the turret's `GunAim`: these are
-- fire-and-forget position updates where the newest wins and a dropped one costs nothing.
--
-- ⚠️ THIS IS NOT A NEW TRUST HOLE. The server still re-raycasts from the shooter's OWN root, capped at
-- the gun's own `range`, exactly as the single-shot path does with the aim point on `FireWeapon`. A
-- client that lies here can only lie about where it is pointing, which it could already do. If updates
-- stop arriving the burst simply stays pinned to the aim it started with.
local aimRemote = Instance.new("UnreliableRemoteEvent")
aimRemote.Name = "AimWeapon"
aimRemote.Parent = ReplicatedStorage

local latestAim: { [Player]: Vector3 } = {}
aimRemote.OnServerEvent:Connect(function(player: Player, aimPoint: any)
	if typeof(aimPoint) == "Vector3" then
		latestAim[player] = aimPoint
	end
end)

-- ── held-item audio ──────────────────────────────────────────────────────────────────────────────
-- 🔴 RE-FOUND ON EVERY CALL, NEVER CAPTURED. `InventoryService.updateHeldVisual` DESTROYS and rebuilds
-- `HeldItem` on every equip and every respawn, so a `Sound` captured at trigger time can be an orphan a
-- fraction of a second later. That was survivable when every cue was a one-shot; it is not survivable for
-- the M16, whose fire clip is 3.888 s of sustained auto-fire that we must be able to STOP at 2 s.
-- Switching slots mid-burst would otherwise leave it playing to the end, from a part no longer in the
-- world. (It also quietly fixes the shotgun's delayed `pump`, which had the same latent problem.)
local function heldSound(player: Player, name: string): Sound?
	local char = player.Character
	local held = char and char:FindFirstChild("HeldItem")
	local s = held and held:FindFirstChild(name)
	return if s and s:IsA("Sound") then s :: Sound else nil
end

local function cue(player: Player, name: string)
	local s = heldSound(player, name)
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

local function stopCue(player: Player, name: string)
	local s = heldSound(player, name)
	if s then
		s:Stop()
	end
end

-- ── two fire clips, picked at random (Job #118) ──────────────────────────────────────────────────
-- The Bazooka shipped with two takes and the user asked for them to alternate randomly, so one rocket
-- does not sound like the last one. `InventoryService` already attaches EVERY key in a weapon's
-- `sound` table, so `fire` and `fire2` arrive on the held part with no extra wiring.
--
-- ⚠️ THEY ARE TWO SEPARATE `Sound` INSTANCES, which matters if anyone ever adds a stop to this path:
-- `cue`/`stopCue` look a Sound up BY NAME, so `stopCue(player, "fire")` would silence the wrong take
-- half the time. The Bazooka's cues are one-shots and are never stopped, so it does not arise today.
local FIRE_VARIANTS = { "fire", "fire2" }

local function cueRandom(player: Player, names: { string })
	-- Only offer variants that actually exist on the held part, so a weapon with one clip (or a missing
	-- upload) still fires audibly instead of falling silent half the time.
	local available = {}
	for _, n in ipairs(names) do
		if heldSound(player, n) then
			table.insert(available, n)
		end
	end
	if #available == 0 then
		return
	end
	cue(player, available[rng:NextInteger(1, #available)])
end

local function enemyFrom(inst: Instance?): Model?
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		-- Job #115: `Generator` is the third damageable tag. A destructible prop needs nothing from this
		-- file but its place in this list — it carries `HP` like everything else here, and reacts by
		-- watching that attribute (see `World/Generators.luau`).
		if cur:IsA("Model") and (
			CollectionService:HasTag(cur, "Enemy")
			or CollectionService:HasTag(cur, "CampGuard")
			or CollectionService:HasTag(cur, "Generator")
		) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

-- the player currently driving the boat (occupant of the DriverSeat)
local function isDriver(player: Player): boolean
	local boat = Workspace:FindFirstChild("Boat")
	local seat = boat and boat:FindFirstChild("DriverSeat")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return seat ~= nil and seat:IsA("VehicleSeat") and hum ~= nil and seat.Occupant == hum
end

-- who's allowed to fire a handheld gun: not the driver, not manning the mounted gun, not "Busy"
local function canShoot(player: Player): boolean
	if isDriver(player) then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and hum.SeatPart.Name == "GunSeat" then
		return false -- manning the mounted gun → use that, not the handheld
	end
	if player:GetAttribute("Busy") == true then
		return false
	end
	return true
end

-- Job #084: one entry per ENEMY hit by a single trigger pull, not per pellet. A shotgun is 6 pellets;
-- six separate numbers stacked over one crocodile is unreadable, and six remotes per shot × a six-player
-- crew is the kind of traffic `CombatFx`'s header warns about. Damage is summed here and reported once.
type Tally = { [Model]: { amount: number, pos: Vector3 } }

-- apply one ray of damage; returns true if it hit an enemy
local function fireRay(char: Model, origin: Vector3, dir: Vector3, range: number, damage: number, tally: Tally): boolean
	local dist = math.min(dir.Magnitude, range)
	if dist < 0.1 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { char }
	local boatModel = Workspace:FindFirstChild("Boat")
	if boatModel then
		table.insert(filter, boatModel)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, dir.Unit * dist, params)
	if result then
		local enemy = enemyFrom(result.Instance)
		if enemy then
			local before = (enemy:GetAttribute("HP") :: number?) or 0
			local after = math.max(0, before - damage)
			enemy:SetAttribute("HP", after)
			-- Job #093: Salvage for a land kill. `Players:GetPlayerFromCharacter` rather than threading a
			-- player through `fireRay` — the shotgun calls it once per pellet, and a signature change
			-- there would touch every caller for a value only needed on the frame something dies.
			local shooter = Players:GetPlayerFromCharacter(char)
			if shooter then
				KillReward.onEnemyDamaged(shooter, enemy, before, after)
			end
			local entry = tally[enemy]
			if entry then
				entry.amount += before - after
			else
				tally[enemy] = { amount = before - after, pos = result.Position }
			end
			print(string.format("[Weapon] HIT %s  HP %d -> %d%s", enemy.Name, before, after, if after <= 0 then "  (KILLED)" else ""))
			return true
		end
	end
	return false
end

-- ── one volley: the pellet loop, shared by the single shot and by every bullet of a burst ────────
-- `jitter` is what makes a burst weapon's `spread` mean anything. The loop below only jitters pellets
-- 2..n, so a gun with `pellets = 1` — the Pistol AND the M16 — never jitters at all. That is right for a
-- semi-auto sidearm and wrong for 20 rounds of automatic fire, which would otherwise travel down one
-- exact line and read as a laser beam. So a burst passes `jitter = true` from its SECOND bullet on: the
-- first round is dead-on where you aimed, the rest bloom.
local function volley(
	char: Model,
	root: BasePart,
	def: ItemDefs.ItemDef,
	aimPoint: Vector3,
	tally: Tally,
	jitter: boolean
)
	local origin = root.Position
	local baseDelta = aimPoint - origin
	if baseDelta.Magnitude < 0.1 then
		return
	end
	local baseDir = baseDelta.Unit
	local range = def.range or 220
	local damage = def.damage or 20
	local pellets = def.pellets or 1
	local spread = def.spread or 0

	for i = 1, pellets do
		local dir = baseDir
		if spread > 0 and (jitter or i > 1) then
			-- jitter the direction within the spread cone
			dir = (baseDir + Vector3.new(
				rng:NextNumber(-spread, spread),
				rng:NextNumber(-spread, spread),
				rng:NextNumber(-spread, spread)
			)).Unit
		end
		fireRay(char, origin, dir * range, range, damage, tally)
	end
end

-- Announce what the tally has collected and empty it. (Clearing keys during `for k in t` traversal is
-- explicitly allowed in Lua; only ADDING keys is undefined.)
local function flush(tally: Tally)
	for enemy, entry in tally do
		CombatFx.hit(entry.pos, entry.amount, "deal")
		tally[enemy] = nil
	end
end

-- ── the burst (Job #117) ─────────────────────────────────────────────────────────────────────────
-- ⚠️ WHY THE DAMAGE NUMBERS ARE WINDOWED rather than sent per bullet or summed to the end.
-- `CombatFx`'s header forbids per-pellet events — *"a shotgun is 6 pellets at 0.7 s and a full crew is 6
-- players; per-pellet events would be 36 remotes"* — and 20 bullets is far worse: six players bursting
-- would be ~120 `FireAllClients` a second. But one summed number at the end is no good either, because
-- `CombatFeedback`'s labels live 0.9 s, so a 2 s-late number arrives detached from the shot that caused
-- it. Windowing gives an enemy under sustained fire a rising ticker of ~6 numbers.
local FLUSH_WINDOW = 0.3

local function runBurst(player: Player, def: ItemDefs.ItemDef, itemId: string, firstAim: Vector3)
	local token = (burstToken[player] or 0) + 1
	burstToken[player] = token
	latestAim[player] = firstAim

	local step = def.burstInterval or 0.1
	local shots = math.max(1, math.floor((def.burstDuration or 1) / step + 0.5))

	-- ONCE, not per bullet: the M16 clip is 3.888 s of sustained auto-fire (see `WeaponAssets.M16`).
	cue(player, "fire")

	task.spawn(function()
		local tally: Tally = {}
		local lastFlush = time()

		for i = 1, shots do
			-- 🔴 RE-CHECKED EVERY BULLET, NOT ONCE AT THE TRIGGER PULL.
			-- Two seconds is long enough to be downed, killed, seated at the helm or the turret, handed a
			-- cargo crate (`Busy`), to switch slots, or to leave the server — and none of those may leave
			-- a gun firing on its own. It is not hypothetical: `RunServer` destroys a dead character 1.5 s
			-- after death, which lands INSIDE this window.
			if burstToken[player] ~= token then
				break -- superseded by a newer burst, or cancelled (PlayerRemoving)
			end
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if
				player.Parent == nil
				or player:GetAttribute("ActiveItem") ~= itemId
				or not char
				or not hum
				or not (root and root:IsA("BasePart"))
				or hum.Health <= 0
				-- ⚠️ BURST-ONLY, and deliberately not pushed onto the single-shot path. The existing
				-- semi-auto guns do not check `Downed`; changing that is a balance decision for another
				-- job. But a 2 s automatic burst that keeps firing while its owner collapses is absurd on
				-- screen in a way that one pistol shot is not.
				or char:GetAttribute("Downed") == true
				or not canShoot(player)
			then
				break
			end

			volley(char, root :: BasePart, def, latestAim[player] or firstAim, tally, i > 1)

			local now = time()
			if now - lastFlush >= FLUSH_WINDOW then
				lastFlush = now
				flush(tally)
			end
			if i < shots then
				task.wait(step)
			end
		end

		flush(tally) -- whatever the final window collected, however the burst ended
		-- Only if we are still the current burst: a newer one is already playing its own clip, and
		-- stopping it here would silence the shot the player just fired.
		if burstToken[player] == token then
			stopCue(player, "fire")
		end
	end)
end

remote.OnServerEvent:Connect(function(player: Player, aimPoint: any)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end

	-- which gun? decided server-side from what the player has equipped (can't fire an unlooted gun)
	local itemId = player:GetAttribute("ActiveItem") :: string?
	local def = ItemDefs.get(itemId)
	if not def or def.kind ~= "Gun" or not def.ammoAttr then
		return
	end

	local now = time()

	-- 🔴 THE BURST LATCH IS CHECKED FIRST, AND NOTHING SCALES IT. See its declaration for why this is
	-- not folded into the `interval` test below.
	if (lockUntil[player] or 0) > now then
		return
	end

	-- Gun Discipline (Job 029): faster fire rate (shrinks the interval between shots).
	-- ⚠️ On a BURST gun this is only a cheap pre-gate against a mashed trigger; the lockout that actually
	-- matters is the latch above, which this multiplier must never touch (Job #117).
	local gunSkill = (player:GetAttribute("SkillGun") :: number?) or 0
	local interval = (def.fireInterval or 0.22) * (0.965 ^ gunSkill)
	local last = lastShot[player]
	if last and now - last < interval then
		return
	end

	if not canShoot(player) then
		return
	end

	-- Job #084: stamped AFTER the gates, not before. Stamping on arrival meant a REJECTED attempt still
	-- consumed the rate-limit window, so a player who tapped while carrying a crate stayed briefly
	-- rate-limited after putting it down. The clock should measure shots fired, not shots attempted.
	lastShot[player] = now

	-- per-player, per-gun ammo (Job 015)
	local ammo = (player:GetAttribute(def.ammoAttr) :: number?) or 0
	if ammo <= 0 then
		cue(player, "empty") -- dry-fire click, so an empty gun tells you WHY nothing happened
		return -- out of ammo for this gun
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return -- Job #117: checked BEFORE the ammo is spent, so a shot with no body to fire it is free
	end

	-- ⚠️ ONE ROUND PER TRIGGER PULL, burst or not. A burst aborted part-way is NOT refunded: the round is
	-- spent at the pull, exactly as it is for every other gun in the game.
	player:SetAttribute(def.ammoAttr, ammo - 1)

	-- ── burst weapons (Job #117) ────────────────────────────────────────────────────────────────
	-- Presence of `burstDuration` is the only test. The server owns the clock from here.
	if def.burstDuration then
		lockUntil[player] = now + def.burstDuration
		runBurst(player, def, itemId :: string, aimPoint)
		return
	end

	-- ── projectile weapons (Job #118) ───────────────────────────────────────────────────────────
	-- Presence of `flightTime` is the only test. Nothing here knows the word "Bazooka".
	--
	-- 🔴 THIS BRANCH MUST STAY ABOVE THE SINGLE-SHOT FALL-THROUGH BELOW. If it is ever moved, reordered
	-- or lost, a projectile weapon silently becomes an INSTANT-HIT gun using `def.damage` and
	-- `def.range` — and looks, from the outside, exactly like a weapon that works. `ItemDefs.Bazooka`
	-- deliberately leaves `damage` unset so that failure degrades to a 20-damage pistol shot instead of
	-- a 300-damage sniper rifle, but do not rely on that: keep the branch here.
	if def.flightTime then
		lockUntil[player] = now + (def.cooldown or def.flightTime)

		-- The rocket leaves the BARREL, not the chest. Shared with the client's muzzle flash through
		-- `Ballistics.muzzleWorld` so the two cannot disagree about where the shot came from; falls back
		-- to just above the root when there is no held part (the greybox path).
		local aimDelta = aimPoint - root.Position
		local aimDir = if aimDelta.Magnitude > 0.1 then aimDelta.Unit else root.CFrame.LookVector
		local held = char:FindFirstChild("HeldItem")
		local origin = if held and held:IsA("BasePart")
			then Ballistics.muzzleWorld(held :: BasePart, aimDir)
			else root.Position + Vector3.new(0, 1.5, 0)

		-- 🔴 THE SERVER RESOLVES THE IMPACT POINT, NOT THE CLIENT — and then hands the SAME Vector3 to
		-- both the flight broadcast and the blast. The client's preview ring runs the identical
		-- `Ballistics.resolveImpact`, so the two normally agree to the stud; where they cannot (the
		-- client has not streamed in a hillside the server has), this value wins. The client is never
		-- trusted for where 300 damage lands — it only says where it was pointing, which it could
		-- already do through `FireWeapon`.
		-- Built explicitly rather than as `{ char, Workspace:FindFirstChild("Boat") }`: that expression is
		-- `{ Instance | nil }` before a boat exists, and the array silently collapses to one element.
		local ignore: { Instance } = { char }
		local boatModel = Workspace:FindFirstChild("Boat")
		if boatModel then
			table.insert(ignore, boatModel)
		end
		local impact = Ballistics.resolveImpact(origin, aimPoint, def.range or 300, ignore)

		cueRandom(player, FIRE_VARIANTS)
		Rocket.launch(player, def, origin, impact)
		return
	end

	-- ── the single shot, unchanged (Pistol / Shotgun) ───────────────────────────────────────────
	-- ⚠️ ONE Sound on the barrel, RESTARTED — never a new Sound per bullet. The pistol fires every
	-- 0.22 s; an instance per shot is the stacking mistake `GameSoundscape`'s header documents with the
	-- cicadas, where a clip fired faster than its own length layered six copies into noise.
	cue(player, "fire")
	-- the pump is the shotgun's follow-through; it has no meaning on a semi-auto pistol
	if heldSound(player, "pump") then
		task.delay(0.18, function()
			cue(player, "pump")
		end)
	end

	-- one burst + one number per enemy struck by this shot, however many pellets found it
	local tally: Tally = {}
	volley(char, root, def, aimPoint, tally, false)
	flush(tally)
end)

Players.PlayerRemoving:Connect(function(p)
	lastShot[p] = nil
	-- Job #117: a burst is a `task.spawn`ed loop and cannot be killed from outside, so it is cancelled by
	-- invalidating the token it compares against every bullet. Clearing `lastShot` alone — all this used to
	-- do — would leave that loop raycasting from a stale character after the player had gone.
	lockUntil[p] = nil
	burstToken[p] = nil
	latestAim[p] = nil
end)
