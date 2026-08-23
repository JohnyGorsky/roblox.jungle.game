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
local ServerStorage = game:GetService("ServerStorage")
local WeaponAssets = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("WeaponAssets"))
-- part→art mapping (Job 066); a no-op until meshes are imported
local BoatParts = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatParts"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local CombatFx = require(game:GetService("ServerScriptService"):WaitForChild("Combat"):WaitForChild("CombatFx"))
local KillReward = require(game:GetService("ServerScriptService"):WaitForChild("Economy"):WaitForChild("KillReward")) :: any
local CollectionService = game:GetService("CollectionService")

local YAW_LIMIT = math.rad(80) -- ±arc from the boat's forward
local PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)
-- ⚠️ Job #104: 60 -> 75, and the reason is a DEPENDENCY, not a buff for its own sake.
-- `GAME.md:147` promises the mounted gun is *"Much stronger than a handheld gun (the boat's real
-- firepower)"*, and it costs hauled cargo crates, a ±80° arc, and a seat that forbids the handheld
-- (`WeaponServer.canShoot`). Doubling the shotgun to 24/pellet made a deck player out-damage the gunner:
--     shotgun  6 x 24 / 0.70s = 205.7 dps      turret  60 / 0.30s = 200.0 dps
-- which quietly makes "nobody mans the gun" the optimal play and deletes one of the five crew roles.
-- 75 restores the gap (250 dps) rather than clawing back the shotgun the user asked for.
local GUN_DAMAGE = 75 -- the boat's real firepower: stays ahead of the handheld shotgun's 205.7 dps
local GUN_RANGE = 350
local FIRE_INTERVAL = 0.3
local ROUNDS_PER_AMMO = ItemDefs.TURRET_ROUNDS_PER_CRATE -- shared with the HUD (Job #075)
-- gunner-camera offset (MUST match GunClient) so the shot goes exactly where the crosshair points
local CAM_UP, CAM_BACK = 2, 3

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local topY = hull.Size.Y / 2
local FRONT = -hull.Size.Z / 2
-- Job 066: the gun sat at topY + 2, which was on the deck of the old 3-stud greybox slab but is buried
-- inside the real hull mesh's raised foredeck. GUN_Y lifts the mount so it stands ON that foredeck.
local GUN_Y = topY + 3.3
 -- boat faces -Z, so the front edge is -Z

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
base.CFrame = hull.CFrame * CFrame.new(0, GUN_Y, FRONT + 5)
base.Parent = boat
weldTo(base)
BoatParts.skin(base, "gunBase")

-- gun seat, just behind the base (gunner faces the bow)
local seat = Instance.new("Seat")
seat.Name = "GunSeat"
seat.Size = Vector3.new(3, 1, 3)
seat.Color = Color3.fromRGB(45, 45, 52)
seat.Massless = true
seat.CanCollide = false
-- the gunner sits in the open well aft of the raised foredeck, so this follows the DECK, not GUN_Y
seat.CFrame = hull.CFrame * CFrame.new(0, GUN_Y - 0.15, FRONT + 10)
seat.Parent = boat
weldTo(seat)
BoatParts.skin(seat, "gunSeat")

-- barrel (kinematic — the server sets its CFrame each frame from the aim)
local barrel = Instance.new("Part")
barrel.Name = "GunBarrel"
barrel.Size = Vector3.new(0.8, 0.8, 8)
barrel.Color = Color3.fromRGB(40, 42, 48)
barrel.Material = Enum.Material.Metal
barrel.Anchored = true
barrel.CanCollide = false
-- the barrel rides ON the mount, not beside it (the aim loop drives it from here)
barrel.CFrame = base.CFrame * CFrame.new(0, 1.2, 0)
barrel.Parent = boat
-- The barrel is ANCHORED and the server rewrites its CFrame every frame from the aim, so when art lands
-- verify the skin actually follows the aim (a welded child of a CFrame-driven anchored part is the one
-- attachment in this job that isn't obviously safe). If it lags, drive the skin's CFrame alongside it.
BoatParts.skin(barrel, "gunBarrel")

local aimRemote = Instance.new("UnreliableRemoteEvent")
aimRemote.Name = "GunAim"
aimRemote.Parent = ReplicatedStorage
local fireRemote = Instance.new("RemoteEvent")
fireRemote.Name = "GunFire"
fireRemote.Parent = ReplicatedStorage

local gunnerYaw, gunnerPitch = 0, 0
local lastPublishedYaw = math.huge -- forces the first publish (Job 067 — see the Heartbeat loop)
local lastPublishedPitch = math.huge -- Job #087: clients need pitch too, to pose the barrel themselves
local lastFire = 0

-- ── Job #079: the turret you can hear ────────────────────────────────────────────────────────────
-- It had NO audio at all. Three cues, built ONCE on the barrel and restarted — never a new Sound per
-- shot, which at this fire rate is the stacking mistake `GameSoundscape` documents about the cicadas.
local turretSounds: { [string]: Sound } = {}
do
	for name, def in pairs(WeaponAssets.TURRET) do
		local snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = def.id
		snd.Volume = def.volume
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = def.min
		snd.RollOffMaxDistance = def.max
		snd.Parent = barrel
		turretSounds[name] = snd
	end
end

local function turretCue(name: string)
	local s = turretSounds[name]
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

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

-- 🔴 Job #087: THE SERVER NO LONGER POSES THE BARREL. `BoatTurretVisual.local.luau` does, on every
-- client, from that client's own view of the boat.
--
-- WHY, measured: the barrel was `Anchored` with its CFrame written here every Heartbeat from the
-- SERVER's view of the hull — while each client renders a different, interpolated hull pose. The two
-- arrive by different routes, so the barrel landed about one frame of travel out. At 53 studs/s that
-- measured **1.14 studs of drift on average and 6.08 at worst**, against welded parts (`GunBase`,
-- `GunSeat`) holding a mathematically exact 0.0000. Reported in play as the gun and light "jiggling"
-- while riding and snapping back when stopped (todo 0047).
--
-- ⚠️ THE WRITE MUST STAY GONE. A server CFrame write replicates, and would fight the client's local
-- write every single frame — reintroducing the drift and adding a tug-of-war on top.
--
-- Aim stays fully server-authoritative: `aimCFrame()` and the firing raycast below are unchanged and
-- never read `barrel.CFrame`, so accuracy does not depend on any client's visual.
RunService.Heartbeat:Connect(function()
	if not base.Parent or not barrel.Parent then
		return
	end
	if seat.Occupant == nil then
		gunnerYaw, gunnerPitch = 0, 0 -- recentre when nobody's manning it
	end

	-- Job 067: publish the yaw so the SEARCHLIGHT module can sweep with the gun (BoatModules reads it).
	-- An attribute rather than a direct reference, so the turret and the light stay decoupled — same
	-- pattern as ModulesRev and StationMedic.
	--
	-- Job #087: `GunPitch` joins it, because the CLIENTS now need the aim to pose the barrel — the
	-- searchlight is still yaw-only (following elevation would point the beam at the sky).
	--
	-- Only written when it actually MOVES: attributes replicate, and setting one every Heartbeat would be
	-- 60 replicated writes a second for a value that is usually unchanged.
	if math.abs(gunnerYaw - lastPublishedYaw) > 0.005 then
		lastPublishedYaw = gunnerYaw
		boat:SetAttribute("GunYaw", gunnerYaw)
	end
	if math.abs(gunnerPitch - lastPublishedPitch) > 0.005 then
		lastPublishedPitch = gunnerPitch
		boat:SetAttribute("GunPitch", gunnerPitch)
	end
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
			turretCue("empty") -- out of cargo entirely: the click tells you WHY nothing happened
			return
		end
		boat:SetAttribute("Ammo", crates - 1)
		rounds = ROUNDS_PER_AMMO
		turretCue("reload") -- a whole crate just went into the belt
	end
	boat:SetAttribute("Rounds", rounds - 1)
	turretCue("fire")

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
			KillReward.onEnemyDamaged(player, enemy, before, after) -- Job #093: Salvage for a land kill
			CombatFx.hit(result.Position, before - after, "deal") -- Job #084: at the impact point
			print(string.format("[Gun] HIT %s  HP %d -> %d%s", enemy.Name, before, after, if after <= 0 then "  (KILLED)" else ""))
		else
			print(string.format("[Gun] hit %s (%s) — not an enemy", result.Instance:GetFullName(), result.Material.Name))
		end
	else
		print("[Gun] missed (nothing within range)")
	end
end)

print("[Gun] mounted turret online")
