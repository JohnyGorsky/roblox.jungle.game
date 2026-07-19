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
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

local CAMP_AHEAD = 1400
local BASIN_SIZE = 400 -- walkable jungle zone size (studs)
local TREE_COUNT = 45
local GUARD_LEASH = 55

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
local carrying: { [Player]: BasePart } = {}
type GuardState = { biteTimer: number, anchor: Vector3 }
local guardState: { [Model]: GuardState } = {}

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

-- rare gold nugget: grab it for 1 Gold, run-capped. Credits the persistent profile immediately.
local function trySpawnNugget(pos: Vector3, parent: Instance, rng: Random)
	local spawned = (Workspace:GetAttribute("NuggetsSpawned") :: number?) or 0
	if spawned >= NUGGET_CAP or rng:NextNumber() > NUGGET_CHANCE then
		return
	end
	Workspace:SetAttribute("NuggetsSpawned", spawned + 1)
	local nug = block("GoldNugget", Vector3.new(2, 2, 2), Color3.fromRGB(245, 197, 66), CFrame.new(pos), parent, Enum.Material.Neon)
	nug.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NuggetPrompt"
	prompt.ActionText = "Grab Gold"
	prompt.ObjectText = "Gold Nugget"
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Parent = nug
	prompt.Triggered:Connect(function(player: Player)
		if not nug.Parent then
			return
		end
		nug:Destroy()
		if Profiles.isReady(player) then
			Profiles.addGold(player, NUGGET_VALUE)
		end
	end)
end

-- flatten a walkable grass patch (fill solid below CLEAR_Y, clear terrain above — incl. tall mountains)
local function carve(cx: number, cz: number, size: number)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y - 20, cz), Vector3.new(size, 40, size), Enum.Material.Grass)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y + 32, cz), Vector3.new(size, 64, size), Enum.Material.Air)
end

-- deposit carried loot at the boat → a resource count. ONLY shown while someone is carrying.
local deposit = Instance.new("ProximityPrompt")
deposit.Name = "DepositPrompt"
deposit.ActionText = "Deposit"
deposit.ObjectText = "Cargo"
deposit.HoldDuration = 0.5
deposit.RequiresLineOfSight = false
deposit.MaxActivationDistance = 16
deposit.Enabled = false
deposit.Parent = hull
deposit.Triggered:Connect(function(player: Player)
	local carried = carrying[player]
	if not carried then
		return
	end
	local resource = (carried:GetAttribute("Resource") :: string?) or "Metal"
	local total = ((boat:GetAttribute("Gasoline") :: number?) or 0)
		+ ((boat:GetAttribute("Metal") :: number?) or 0)
		+ ((boat:GetAttribute("Ammo") :: number?) or 0)
	if total >= ((boat:GetAttribute("CargoMax") :: number?) or 10) then
		return -- cargo deck full → keep carrying it
	end
	boat:SetAttribute(resource, ((boat:GetAttribute(resource) :: number?) or 0) + 1)
	carried:Destroy()
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	local char = player.Character
	if char then
		char:SetAttribute("Carrying", nil)
	end
	deposit.Enabled = next(carrying) ~= nil
end)

local function pickupLoot(player: Player, crate: Part)
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
			crate:Destroy()
		end -- inventory full → leave the crate so the player can free a slot
		return
	elseif kind == "Ammo" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		local def = ItemDefs.get(id)
		InventoryService.addAmmo(player, id, (def and def.ammoPerCrate) or 12)
		crate:Destroy()
		return
	end

	-- resource crates (gasoline/metal/turret-ammo): carry back to the boat cargo (existing behaviour)
	if carrying[player] then
		return
	end
	local resource = (crate:GetAttribute("Resource") :: string?) or "Metal"
	local carried = Instance.new("Part")
	carried.Name = "CarriedCrate"
	carried.Size = Vector3.new(3, 3, 3)
	carried.Color = Color3.fromRGB(150, 120, 70)
	carried.Material = Enum.Material.WoodPlanks
	carried.CanCollide = false
	carried.Massless = true
	carried.CFrame = root.CFrame * CFrame.new(0, 2.5, 0)
	carried:SetAttribute("Resource", resource)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carried
	weld.Parent = carried
	carried.Parent = char
	carrying[player] = carried
	char:SetAttribute("Carrying", resource)
	player:SetAttribute("Busy", true) -- hands full → can't shoot
	deposit.Enabled = true
	crate:Destroy()
end

local function spawnGuard(anchorPos: Vector3, parent: Instance)
	local def = EnemyDefs.Defs.Panther
	local guard = Instance.new("Model")
	guard.Name = "CampGuard"
	local body = block("Body", def.size, def.color, CFrame.new(anchorPos + Vector3.new(0, def.size.Y / 2, 0)), guard)
	guard.PrimaryPart = body
	guard:SetAttribute("HP", def.hp)
	guard:SetAttribute("MaxHP", def.hp)
	CollectionService:AddTag(guard, "CampGuard")
	guard.Parent = parent
	guardState[guard] = { biteTimer = def.biteCooldown, anchor = Vector3.new(anchorPos.X, CLEAR_Y + def.size.Y / 2, anchorPos.Z) }
end

local CRATE_COLOR: { [string]: Color3 } = {
	Gasoline = Color3.fromRGB(230, 180, 60),
	Metal = Color3.fromRGB(150, 150, 160),
	Ammo = Color3.fromRGB(180, 90, 70),
}

local function buildCampAt(campPos: Vector3, parent: Instance, guards: number, resources: { string })
	block("Hut", Vector3.new(10, 8, 10), Color3.fromRGB(92, 70, 45), CFrame.new(campPos + Vector3.new(-12, 4, 10)), parent)
	block("Hut", Vector3.new(8, 6, 8), Color3.fromRGB(104, 82, 55), CFrame.new(campPos + Vector3.new(13, 3, 4)), parent)
	for i, res in ipairs(resources) do
		local crate = block("LootCrate", Vector3.new(4, 4, 4), CRATE_COLOR[res] or Color3.fromRGB(150, 120, 70), CFrame.new(campPos + Vector3.new((i - 1) * 6 - 3, 2, -8)), parent, Enum.Material.WoodPlanks)
		crate:SetAttribute("Resource", res)
		local loot = Instance.new("ProximityPrompt")
		loot.Name = "LootPrompt"
		loot.ActionText = "Loot " .. res
		loot.ObjectText = "Crate"
		loot.HoldDuration = 1.2
		loot.RequiresLineOfSight = false
		loot.MaxActivationDistance = 10
		loot.Parent = crate
		loot.Triggered:Connect(function(player: Player)
			pickupLoot(player, crate)
		end)
	end
	for i = 1, guards do
		spawnGuard(campPos + Vector3.new((i - 1) * 7, 0, 8), parent)
	end
end

-- a loadout crate: Kind "Weapon" (grants a gun to a slot) or "Ammo" (tops up that gun's ammo). No carry.
local function makeKindCrate(pos: Vector3, kind: string, id: string, color: Color3, actionText: string, parent: Instance)
	local crate = block("LootCrate", Vector3.new(4, 4, 4), color, CFrame.new(pos), parent, Enum.Material.Metal)
	crate:SetAttribute("Kind", kind)
	crate:SetAttribute("Id", id)
	local loot = Instance.new("ProximityPrompt")
	loot.Name = "LootPrompt"
	loot.ActionText = actionText
	loot.ObjectText = "Crate"
	loot.HoldDuration = 1.2
	loot.RequiresLineOfSight = false
	loot.MaxActivationDistance = 10
	loot.Parent = crate
	loot.Triggered:Connect(function(player: Player)
		pickupLoot(player, crate)
	end)
end

local function tree(x: number, z: number, parent: Instance, rng: Random)
	local h = rng:NextNumber(11, 18)
	block("Trunk", Vector3.new(2, h, 2), Color3.fromRGB(90, 60, 40), CFrame.new(x, CLEAR_Y + h / 2, z), parent, Enum.Material.Wood)
	block("Canopy", Vector3.new(11, 8, 11), Color3.fromRGB(45, 100, 50), CFrame.new(x, CLEAR_Y + h + 2, z), parent)
end

local function buildLandingSite(dock: RiverData.Dock, index: number)
	if built[index] then
		return
	end
	built[index] = true
	local halfW = RiverData.widthAt(dock.z) * 0.5
	local waterEdge = RiverData.centerlineX(dock.z) + dock.side * halfW
	local basinCenterX = waterEdge + dock.side * (BASIN_SIZE / 2) -- inner edge AT the water line (walkable shore), not into the channel
	carve(basinCenterX, dock.z, BASIN_SIZE)

	-- contain the valley: raise rock walls on the 3 inland sides (water side stays open for the dock)
	-- so the crew can't walk off the carved basin's edge.
	local half = BASIN_SIZE / 2
	local function wallBlock(cx: number, cz: number, sx: number, sz: number)
		Terrain:FillBlock(CFrame.new(cx, 17, cz), Vector3.new(sx, 50, sz), Enum.Material.Rock) -- solid Y[-8..42]
	end
	wallBlock(basinCenterX + dock.side * (half + 15), dock.z, 30, BASIN_SIZE + 60) -- far inland wall
	wallBlock(basinCenterX + dock.side * 15, dock.z + half + 15, BASIN_SIZE + 30, 30) -- +Z wall
	wallBlock(basinCenterX + dock.side * 15, dock.z - half - 15, BASIN_SIZE + 30, 30) -- -Z wall

	local model = Instance.new("Model")
	model.Name = "LandingSite"
	local rng = Random.new(index * 131 + 7)
	for _ = 1, TREE_COUNT do
		local rx = basinCenterX + rng:NextNumber(-1, 1) * (BASIN_SIZE / 2 - 15)
		local rz = dock.z + rng:NextNumber(-1, 1) * (BASIN_SIZE / 2 - 15)
		if (rx - waterEdge) * dock.side > 10 then -- keep trees on land, out of the channel
			tree(rx, rz, model, rng)
		end
	end
	-- tiered camps: near (gasoline, 1 guard) + far/deeper (metal + ammo, 2 guards — better haul)
	local nearPos = Vector3.new(waterEdge + dock.side * 120, CLEAR_Y, dock.z)
	buildCampAt(nearPos, model, 1, { "Gasoline" })
	local deepPos = Vector3.new(waterEdge + dock.side * 300, CLEAR_Y, dock.z + 40)
	buildCampAt(deepPos, model, 2, { "Metal", "Ammo" })

	-- rare gold nuggets (run-capped): a chance at each camp
	trySpawnNugget(nearPos + Vector3.new(0, 2, 6), model, rng)
	trySpawnNugget(deepPos + Vector3.new(dock.side * -6, 2, 6), model, rng)

	-- loadout loot at the deep camp (Job 015): a scarce WEAPON crate + a handheld-ammo crate.
	-- Weapon crates are the top reward — alternate pistol/shotgun by landing; spawn rate is tunable.
	local weaponId = if index % 2 == 0 then "Shotgun" else "Pistol"
	makeKindCrate(deepPos + Vector3.new(dock.side * 6, 2, -18), "Weapon", weaponId, ItemDefs.Items[weaponId].color, "Take " .. weaponId, model)
	makeKindCrate(deepPos + Vector3.new(dock.side * 12, 2, -18), "Ammo", weaponId, Color3.fromRGB(200, 170, 80), weaponId .. " Ammo", model)
	model.Parent = campsRoot
end

-- guard AI: chase the nearest on-foot player, leashed to the camp; bite = damage player HP
local function tickGuard(guard: Model, dt: number)
	local def = EnemyDefs.Defs.Panther
	local body = guard.PrimaryPart
	local st = guardState[guard]
	if not body or not st then
		guard:Destroy()
		return
	end
	if ((guard:GetAttribute("HP") :: number?) or 0) <= 0 then
		guardState[guard] = nil
		guard:Destroy()
		return
	end
	st.biteTimer += dt
	local pos = body.Position

	local target: BasePart? = nil
	local bestD = def.aggroRadius
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

	local goal = if target then target.Position else st.anchor
	local dir = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = dir.Magnitude
	if dist > 0.5 then
		dir = dir.Unit
		local stop = if target then def.biteRange * 0.5 else 1
		local step = math.min(def.speed * dt, math.max(dist - stop, 0))
		local np = Vector3.new(pos.X + dir.X * step, CLEAR_Y + def.size.Y / 2, pos.Z + dir.Z * step)
		local off = Vector3.new(np.X - st.anchor.X, 0, np.Z - st.anchor.Z)
		if off.Magnitude > GUARD_LEASH then
			local c = st.anchor + off.Unit * GUARD_LEASH
			np = Vector3.new(c.X, CLEAR_Y + def.size.Y / 2, c.Z)
		end
		guard:PivotTo(CFrame.lookAt(np, np + dir))
	end

	if target and bestD <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		local char = target.Parent
		if char then
			char:SetAttribute("HP", math.max(0, ((char:GetAttribute("HP") :: number?) or 0) - def.biteDamage))
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

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - 200, boatZ + CAMP_AHEAD) do
		if dock.landing then
			buildLandingSite(dock, dockIndex(dock.z))
		end
	end
	task.wait(0.5)
end
