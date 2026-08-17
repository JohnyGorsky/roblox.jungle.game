--!strict
-- WeaponServer.server.luau — authoritative free-aim hitscan for the LOOTED guns (Job 006 → Job 015).
--
-- The client sends only the world AIM POINT it tapped. The SERVER re-raycasts from the shooter's own
-- character toward that point and applies damage — the client never says "I hit X", so it can't fake
-- hits. Which gun fires (and its damage/range/spread/ammo) is decided SERVER-SIDE from the shooter's
-- ActiveItem — you can only fire a gun you've looted into a slot and equipped. Ammo is PER-PLAYER,
-- PER-GUN (Job 015): the mounted turret (GunServer) still uses the shared boat pool. Rate-limited.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local CombatFx = require(game:GetService("ServerScriptService"):WaitForChild("Combat"):WaitForChild("CombatFx"))
local KillReward = require(game:GetService("ServerScriptService"):WaitForChild("Economy"):WaitForChild("KillReward")) :: any

local remote = Instance.new("RemoteEvent")
remote.Name = "FireWeapon"
remote.Parent = ReplicatedStorage

local lastShot: { [Player]: number } = {}
local rng = Random.new()

local function enemyFrom(inst: Instance?): Model?
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and (CollectionService:HasTag(cur, "Enemy") or CollectionService:HasTag(cur, "CampGuard")) then
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

remote.OnServerEvent:Connect(function(player: Player, aimPoint: any)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end

	-- which gun? decided server-side from what the player has equipped (can't fire an unlooted gun)
	local def = ItemDefs.get(player:GetAttribute("ActiveItem") :: string?)
	if not def or def.kind ~= "Gun" or not def.ammoAttr then
		return
	end

	-- Gun Discipline (Job 029): faster fire rate (shrinks the interval between shots)
	local gunSkill = (player:GetAttribute("SkillGun") :: number?) or 0
	local interval = (def.fireInterval or 0.22) * (0.965 ^ gunSkill)
	local now = time()
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

	-- ── Job #079: the gun you can hear ──────────────────────────────────────────────────────────
	-- `gun_shot` has been uploaded and owned since 2026-08-02 and was never wired (ASSETS.md §3.2
	-- deferred it: *"this will be a separate task"*). This is that task.
	--
	-- ⚠️ ONE Sound on the barrel, RESTARTED — never a new Sound per bullet. The pistol fires every
	-- 0.22 s; an instance per shot is the stacking mistake `GameSoundscape`'s header documents with the
	-- cicadas, where a clip fired faster than its own length layered six copies into noise.
	-- `player.Character` directly: the local `char` is declared further down, after the ammo gate.
	local heldChar = player.Character
	local held = heldChar and heldChar:FindFirstChild("HeldItem")
	local function cue(name: string)
		local s = held and held:FindFirstChild(name)
		if s and s:IsA("Sound") then
			s.TimePosition = 0
			s:Play()
		end
	end

	-- per-player, per-gun ammo (Job 015)
	local ammo = (player:GetAttribute(def.ammoAttr) :: number?) or 0
	if ammo <= 0 then
		cue("empty") -- dry-fire click, so an empty gun tells you WHY nothing happened
		return -- out of ammo for this gun
	end
	player:SetAttribute(def.ammoAttr, ammo - 1)
	cue("fire")
	-- the pump is the shotgun's follow-through; it has no meaning on a semi-auto pistol
	if held and held:FindFirstChild("pump") then
		task.delay(0.18, function()
			cue("pump")
		end)
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return
	end

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

	local tally: Tally = {}
	for i = 1, pellets do
		local dir = baseDir
		if i > 1 and spread > 0 then
			-- jitter the pellet direction within the spread cone
			dir = (baseDir + Vector3.new(
				rng:NextNumber(-spread, spread),
				rng:NextNumber(-spread, spread),
				rng:NextNumber(-spread, spread)
			)).Unit
		end
		fireRay(char, origin, dir * range, range, damage, tally)
	end
	-- one burst + one number per enemy struck by this shot, however many pellets found it
	for _, entry in tally do
		CombatFx.hit(entry.pos, entry.amount, "deal")
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastShot[p] = nil
end)
