--!strict
-- GunServer.server.luau — mounted gunner turret on the boat (Job 014).
--
-- A Seat + kinematic barrel welded to the hull (moves with the boat). The gunner sits and sends a
-- clamped aim (yaw/pitch relative to the boat's forward); the server rotates the barrel to it and,
-- on fire, raycasts a STRONG, ammo-fed hitscan from the muzzle. Server-authoritative (seated check,
-- arc clamp, ammo, range). Greybox.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local YAW_LIMIT = math.rad(80) -- ±arc from the boat's forward
local PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)
local GUN_DAMAGE = 60 -- much stronger than the handheld (20)
local GUN_RANGE = 350
local FIRE_INTERVAL = 0.3
local ROUNDS_PER_AMMO = 12
-- gunner-camera offset (MUST match GunClient) so the shot goes exactly where the crosshair points
local CAM_UP, CAM_BACK = 2, 3

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local topY = hull.Size.Y / 2
local FRONT = -hull.Size.Z / 2 -- boat faces -Z, so the front edge is -Z

local function weldTo(part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hull
	w.Part1 = part
	w.Parent = part
end

-- turret base (welded, at the bow)
local base = Instance.new("Part")
base.Name = "GunBase"
base.Size = Vector3.new(3, 2, 3)
base.Color = Color3.fromRGB(70, 72, 80)
base.Material = Enum.Material.Metal
base.Massless = true
base.CanCollide = false
base.CFrame = hull.CFrame * CFrame.new(0, topY + 2, FRONT + 5)
base.Parent = boat
weldTo(base)

-- gun seat, just behind the base (gunner faces the bow)
local seat = Instance.new("Seat")
seat.Name = "GunSeat"
seat.Size = Vector3.new(3, 1, 3)
seat.Color = Color3.fromRGB(45, 45, 52)
seat.Massless = true
seat.CanCollide = false
seat.CFrame = hull.CFrame * CFrame.new(0, topY + 1, FRONT + 9)
seat.Parent = boat
weldTo(seat)

-- barrel (kinematic — the server sets its CFrame each frame from the aim)
local barrel = Instance.new("Part")
barrel.Name = "GunBarrel"
barrel.Size = Vector3.new(0.8, 0.8, 8)
barrel.Color = Color3.fromRGB(40, 42, 48)
barrel.Material = Enum.Material.Metal
barrel.Anchored = true
barrel.CanCollide = false
barrel.CFrame = base.CFrame
barrel.Parent = boat

local aimRemote = Instance.new("UnreliableRemoteEvent")
aimRemote.Name = "GunAim"
aimRemote.Parent = ReplicatedStorage
local fireRemote = Instance.new("RemoteEvent")
fireRemote.Name = "GunFire"
fireRemote.Parent = ReplicatedStorage

local gunnerYaw, gunnerPitch = 0, 0
local lastFire = 0

local function humOf(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- the barrel/aim CFrame from the base + the clamped yaw/pitch (arc is relative to the boat)
local function aimCFrame(): CFrame
	return base.CFrame * CFrame.Angles(gunnerPitch, gunnerYaw, 0)
end

aimRemote.OnServerEvent:Connect(function(player: Player, yaw: any, pitch: any)
	if seat.Occupant ~= humOf(player) then
		return
	end
	if typeof(yaw) ~= "number" or typeof(pitch) ~= "number" then
		return
	end
	gunnerYaw = math.clamp(yaw, -YAW_LIMIT, YAW_LIMIT)
	gunnerPitch = math.clamp(pitch, PITCH_MIN, PITCH_MAX)
end)

RunService.Heartbeat:Connect(function()
	if not base.Parent or not barrel.Parent then
		return
	end
	if seat.Occupant == nil then
		gunnerYaw, gunnerPitch = 0, 0 -- recentre when nobody's manning it
	end
	barrel.CFrame = aimCFrame() * CFrame.new(0, 0, -barrel.Size.Z / 2)
end)

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

fireRemote.OnServerEvent:Connect(function(player: Player)
	if seat.Occupant ~= humOf(player) then
		return
	end
	-- Gun Discipline skill (Job 029) + a manned Gun-seat station bonus (Job 034) both speed the turret
	local gunSkill = (player:GetAttribute("SkillGun") :: number?) or 0
	local interval = FIRE_INTERVAL * (0.965 ^ gunSkill) * ((boat:GetAttribute("StationGunMul") :: number?) or 1)
	local now = time()
	if now - lastFire < interval then
		return
	end
	lastFire = now

	-- ammo from the boat cargo
	local rounds = (boat:GetAttribute("Rounds") :: number?) or 0
	if rounds <= 0 then
		local crates = (boat:GetAttribute("Ammo") :: number?) or 0
		if crates <= 0 then
			return
		end
		boat:SetAttribute("Ammo", crates - 1)
		rounds = ROUNDS_PER_AMMO
	end
	boat:SetAttribute("Rounds", rounds - 1)

	local cf = aimCFrame()
	local origin = (cf * CFrame.new(0, CAM_UP, CAM_BACK)).Position -- match the gunner camera → shot hits the crosshair
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { boat }
	if player.Character then
		table.insert(filter, player.Character)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, cf.LookVector * GUN_RANGE, params)
	if result then
		local enemy = enemyFrom(result.Instance)
		if enemy then
			-- Armored Boat (Job 027/029): GunDamageMul boosts mounted-gun damage (+20% with the pass)
			local dmg = GUN_DAMAGE * ((boat:GetAttribute("GunDamageMul") :: number?) or 1)
			local before = (enemy:GetAttribute("HP") :: number?) or 0
			local after = math.max(0, before - dmg)
			enemy:SetAttribute("HP", after)
			print(string.format("[Gun] HIT %s  HP %d -> %d%s", enemy.Name, before, after, if after <= 0 then "  (KILLED)" else ""))
		else
			print(string.format("[Gun] hit %s (%s) — not an enemy", result.Instance:GetFullName(), result.Material.Name))
		end
	else
		print("[Gun] missed (nothing within range)")
	end
end)

print("[Gun] mounted turret online")
