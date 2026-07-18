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

-- apply one ray of damage; returns true if it hit an enemy
local function fireRay(char: Model, origin: Vector3, dir: Vector3, range: number, damage: number): boolean
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

	local now = time()
	local last = lastShot[player]
	if last and now - last < (def.fireInterval or 0.22) then
		return
	end
	lastShot[player] = now

	if not canShoot(player) then
		return
	end

	-- per-player, per-gun ammo (Job 015)
	local ammo = (player:GetAttribute(def.ammoAttr) :: number?) or 0
	if ammo <= 0 then
		return -- out of ammo for this gun
	end
	player:SetAttribute(def.ammoAttr, ammo - 1)

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
		fireRay(char, origin, dir * range, range, damage)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastShot[p] = nil
end)
