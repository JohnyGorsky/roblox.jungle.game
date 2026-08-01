--!strict
-- LobbyBoat.server.luau — the harbour showroom (Job 066).
--
-- On join, every player gets their OWN static boat moored in free harbour water, showing exactly the
-- modules they own. It turns the Boat Upgrades shop into a showroom: you can see what you've bought and
-- what you haven't, standing next to it.
--
-- STATIC ON PURPOSE. Every part is Anchored with no constraints, no buoyancy loop and no usable seats.
-- The rideable boat is `sync/ServerScriptService/Boat/BoatServer` in the GAME place; nothing here touches
-- it and none of this runs there.
--
-- LAYOUT IS COPIED FROM THE GAME BOAT so the showroom can't lie: the offsets below are the same ones
-- BoatServer / BoatModules / GunServer / CargoServer use. Art comes from the shared `BoatParts` mapping,
-- so when meshes land, the lobby boat and the real boat get them from one place.
--
-- MOORING SLOTS ARE PROBED, NOT HARDCODED (intake decision #6). The harbour water is found by reading
-- terrain voxels around the existing dock, so a slot can never end up on dry land or inside the pier. If
-- hand-placed `BoatSlot_*` parts ever exist, they win — that's the fallback if the generated spacing
-- reads badly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BoatParts = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatParts"))
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

-- ── boat geometry (mirrors the game boat) ─────────────────────────────────────────────────────────
local HULL = Vector3.new(14, 3, 32) -- Job 066: 22 -> 32, matches BoatServer.HULL_SIZE
local TOP_Y = HULL.Y / 2 -- 1.5
local DECK_DEPTH = 8 -- Job 066: rear deck halved (16 -> 8); it read bigger than the boat
local BACK_Z = HULL.Z / 2 + DECK_DEPTH / 2 -- flush behind the stern (+Z is the back; the boat faces -Z)
local FRONT_Z = -HULL.Z / 2
-- derived bow/stern anchors, mirroring BoatModules so the showroom matches the real boat
local BOW = FRONT_Z + 1.5
-- Clear of the gunwale: the visible hull now rises to ~4.5 in hull space, so the old 3.2 buried the
-- lamp inside the bow structure where nothing could see it.
local BOW_LIGHT_Y = 5.0
local STERN = HULL.Z / 2 - 1.5
-- mount height: the mesh hull has a RAISED foredeck, so the old TOP_Y + 2 buried the gun inside it
local GUN_Y = TOP_Y + 4.1

-- ── mooring ───────────────────────────────────────────────────────────────────────────────────────
-- Boats are yawed so their length (local Z) runs along world X, bow pointing +X out to open water.
local MOOR_YAW = math.rad(-90)
-- How deep the hull sits below the surface. The GAME boat's buoyancy targets the hull CENTRE at the
-- water line, which on a 3-stud-tall hull leaves it looking flush/half-sunk — fine for a physics box you
-- never really look at, wrong for a boat moored on display. Here the hull bottom sits just under the
-- surface instead, so the boat reads as floating. This is the knob to retune once the hull mesh lands
-- (a mesh with real gunwales will want a different draft than a plain box).
local DRAFT = 0.6
-- Clearance needed once yawed: 32 along X, 14 along Z, plus margin (hull grew in Job 066).
local CLEAR_X, CLEAR_Z = 40, 22
local SLOT_STEP = 34 -- spacing between candidate slots (must exceed the 32-long hull)
local MAX_SLOTS = 8
local WATER_PROBE_STEP = 4

local folder = Workspace:FindFirstChild("LobbyBoats")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "LobbyBoats"
folder.Parent = Workspace

-- Water SURFACE height at (x, z), or nil if there's no water there.
--
-- Terrain voxels are 4 studs, and a voxel is only PARTLY full at the surface — its `occupancy` says how
-- much. An earlier version returned the topmost water voxel's CENTRE, which sat the whole boat up to two
-- studs too low: the interior deck ended up under the real waterline and water visibly washed through the
-- hull. Use the voxel's base plus its occupancy to get the actual surface.
local function waterTopAt(x: number, z: number): number?
	local region = Region3.new(Vector3.new(x - 2, -60, z - 2), Vector3.new(x + 2, 60, z + 2)):ExpandToGrid(4)
	local ok, mat, occ = pcall(function()
		return Workspace.Terrain:ReadVoxels(region, WATER_PROBE_STEP)
	end)
	if not ok or not mat then
		return nil
	end
	local top: number? = nil
	for y = 1, #mat[1] do
		if mat[1][y][1] == Enum.Material.Water then
			local base = -60 + (y - 1) * WATER_PROBE_STEP -- bottom face of this voxel
			local fill = (occ and occ[1] and occ[1][y] and occ[1][y][1]) or 1
			top = base + fill * WATER_PROBE_STEP
		end
	end
	return top
end

-- Is the whole footprint of a moored boat over water?
local function footprintClear(x: number, z: number): (boolean, number?)
	local surface = waterTopAt(x, z)
	if not surface then
		return false, nil
	end
	for _, dx in ipairs({ -CLEAR_X / 2, 0, CLEAR_X / 2 }) do
		for _, dz in ipairs({ -CLEAR_Z / 2, 0, CLEAR_Z / 2 }) do
			local y = waterTopAt(x + dx, z + dz)
			if not y or math.abs(y - surface) > 2 then
				return false, nil -- land, or a different water body
			end
		end
	end
	return true, surface
end

type Slot = { position: Vector3, taken: Player? }

local slots: { Slot } = {}

local function findDock(): BasePart?
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Pier" then
			return d
		end
	end
	return nil
end

local function buildSlots()
	-- hand-placed slots win if they exist (the documented fallback)
	local manual: { Slot } = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and string.match(d.Name, "^BoatSlot") then
			table.insert(manual, { position = d.Position, taken = nil })
		end
	end
	if #manual > 0 then
		slots = manual
		print(("[LobbyBoat] using %d hand-placed BoatSlot part(s)"):format(#slots))
		return
	end

	local pier = findDock()
	local originX = pier and pier.Position.X or 121
	local originZ = pier and pier.Position.Z or -3

	-- Scan outward from the dock into the water. Keep whole-footprint-clear candidates, nearest first, so
	-- the harbour fills up tidily next to the pier instead of scattering.
	local candidates: { { pos: Vector3, dist: number } } = {}
	for dz = SLOT_STEP, 140, SLOT_STEP do
		for dx = -2 * SLOT_STEP, 5 * SLOT_STEP, SLOT_STEP do
			local x, z = originX + dx, originZ + dz
			local clear, surface = footprintClear(x, z)
			if clear and surface then
				local pos = Vector3.new(x, surface, z)
				table.insert(candidates, { pos = pos, dist = (pos - Vector3.new(originX, surface, originZ)).Magnitude })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)
	for i = 1, math.min(MAX_SLOTS, #candidates) do
		table.insert(slots, { position = candidates[i].pos, taken = nil })
	end
	print(("[LobbyBoat] probed %d mooring slot(s) from the dock at (%.0f, %.0f)"):format(#slots, originX, originZ))
end

local function claimSlot(plr: Player): Slot?
	for _, slot in ipairs(slots) do
		if slot.taken == nil then
			slot.taken = plr
			return slot
		end
	end
	return nil
end

local function releaseSlots(plr: Player)
	for _, slot in ipairs(slots) do
		if slot.taken == plr then
			slot.taken = nil
		end
	end
end

-- ── building one static boat ──────────────────────────────────────────────────────────────────────

local function addPart(model: Model, base: CFrame, name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material, skinId: string?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat
	p.Anchored = true -- static display: no physics anywhere on this boat
	-- Collidable so players can climb aboard and walk the deck. Anchored parts cannot be pushed, so there
	-- is no "player shoves the showroom boat" risk to protect against — an earlier CanCollide = false here
	-- just made players fall straight through it.
	p.CanCollide = true
	p.CFrame = base * offset
	p.Parent = model
	if skinId then
		BoatParts.skin(p, skinId)
	end
	return p
end

local function buildBoat(plr: Player, slot: Slot): Model
	local prof = Profiles.get(plr)
	local owned = (prof and prof.modules) or {}

	local model = Instance.new("Model")
	model.Name = "LobbyBoat_" .. plr.Name
	model:SetAttribute("Owner", plr.UserId)

	-- Float the hull so only DRAFT studs of it are under the surface (slot.position.Y is the water top).
	local waterline = slot.position.Y
	local hullCentreY = waterline + (HULL.Y / 2) - DRAFT
	local base = CFrame.new(Vector3.new(slot.position.X, hullCentreY, slot.position.Z)) * CFrame.Angles(0, MOOR_YAW, 0)

	local hull = addPart(model, base, "Hull", HULL, CFrame.new(), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks, "hull")
	model.PrimaryPart = hull

	addPart(model, base, "CargoDeck", Vector3.new(14, 1, DECK_DEPTH), CFrame.new(0, TOP_Y - 0.5, BACK_Z), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks, "cargoDeck")
	addPart(model, base, "DriverSeat", Vector3.new(4, 1, 5), CFrame.new(0, 2, 0), Color3.fromRGB(60, 45, 30), Enum.Material.Fabric, "driverSeat")
	addPart(model, base, "Motor", Vector3.new(2, 2, 3), CFrame.new(3.5, 1, STERN), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, "motor")
	addPart(model, base, "GunBase", Vector3.new(3, 2, 3), CFrame.new(0, GUN_Y, FRONT_Z + 5), Color3.fromRGB(70, 72, 80), Enum.Material.Metal, "gunBase")
	addPart(model, base, "GunSeat", Vector3.new(3, 1, 3), CFrame.new(0, GUN_Y - 1, FRONT_Z + 9), Color3.fromRGB(45, 45, 52), Enum.Material.Fabric, "gunSeat")
	addPart(model, base, "BowLightHead", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, BOW_LIGHT_Y, BOW), Color3.fromRGB(245, 245, 210), Enum.Material.Neon, "bowLight")
	addPart(model, base, "Fuel Station", Vector3.new(3, 3, 3), CFrame.new(-4, TOP_Y + 1.5, BACK_Z), Color3.fromRGB(240, 190, 60), Enum.Material.Metal, "fuelStation")
	addPart(model, base, "Repair Station", Vector3.new(3, 3, 3), CFrame.new(4, TOP_Y + 1.5, BACK_Z), Color3.fromRGB(120, 200, 130), Enum.Material.Metal, "repairStation")

	-- the gun barrel: swapped model when the upgrade is owned (decision #2), never two barrels
	local hasGunUpgrade = owned.gunupgrade == true
	local barrel = addPart(model, base, "GunBarrel", Vector3.new(0.8, 0.8, 8), CFrame.new(0, GUN_Y, FRONT_Z + 5 - 2), Color3.fromRGB(40, 42, 48), Enum.Material.Metal, nil)
	if not BoatParts.skin(barrel, "gunBarrel", hasGunUpgrade) and hasGunUpgrade then
		barrel.Size = Vector3.new(1.1, 1.1, 9) -- no art yet: read the upgrade as a visibly bigger barrel
		barrel.Color = Color3.fromRGB(30, 30, 34)
	end

	-- ── owned modules, same offsets as the game boat ──────────────────────────────────────────────
	if owned.motor2 then
		addPart(model, base, "Motor2", Vector3.new(2, 2, 3), CFrame.new(-3.5, 1, STERN), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, "motor2")
	end
	if owned.hullkit then
		-- tiled along the parallel midbody, mirroring BoatModules (a full-length strip juts past the
		-- hull's taper at bow and stern, and stretching one short plate smears its detail)
		local PLATE_SIDES: { { name: string, x: number } } = { { name = "L", x = -7.1 }, { name = "R", x = 7.1 } }
		-- Height on the topsides. The hull BOX is only 3 tall but the visible hull mesh rises to ~4.5, so
		-- plates at box-centre (Y 0) hung off the keel below the waterline. This sits them on the flank.
		local PLATE_Y = 2.2
		local PLATE_SEGMENTS, PLATE_LEN = 4, 4.6
		local span = PLATE_SEGMENTS * PLATE_LEN
		for i = 1, PLATE_SEGMENTS do
			local z = -span / 2 + PLATE_LEN * (i - 0.5)
			for _, side in ipairs(PLATE_SIDES) do
				addPart(model, base, "HullPlate" .. side.name .. i, Vector3.new(0.5, 2, PLATE_LEN),
					CFrame.new(side.x, PLATE_Y, z), Color3.fromRGB(120, 122, 130), Enum.Material.Metal, "hullPlate")
			end
		end
	end
	if owned.fueltank then
		addPart(model, base, "FuelTankModule", Vector3.new(2, 3, 3), CFrame.new(4.5, 2.5, STERN * 0.75), Color3.fromRGB(210, 180, 60), Enum.Material.Metal, "fuelTank")
	end
	if owned.searchlight then
		addPart(model, base, "SearchlightMast", Vector3.new(0.8, 6, 0.8), CFrame.new(0, 5, BOW * 0.6), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, "searchlightMast")
		addPart(model, base, "SearchlightHead", Vector3.new(2, 2, 2), CFrame.new(0, 8, BOW * 0.6 - 0.6), Color3.fromRGB(245, 245, 210), Enum.Material.Neon, "searchlightHead")
	end
	if owned.trailer then
		-- cargo racks ON the rear deck, matching BoatModules (finding 0003 — the old position was buried
		-- under the deck and invisible)
		addPart(model, base, "Trailer", Vector3.new(9, 3, 6), CFrame.new(0, 3, BACK_Z), Color3.fromRGB(120, 90, 55), Enum.Material.WoodPlanks, "trailer")
	end

	-- a nameplate so a crowded harbour is readable
	local tag = Instance.new("BillboardGui")
	tag.Name = "OwnerTag"
	tag.Size = UDim2.fromScale(8, 1.6)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	tag.MaxDistance = 120
	tag.Adornee = hull
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextColor3 = Color3.fromRGB(243, 230, 194)
	label.TextStrokeColor3 = Color3.fromRGB(15, 22, 17)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = plr.DisplayName .. "'s boat"
	label.Parent = tag
	tag.Parent = hull

	model.Parent = folder
	return model
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────────

local boats: { [Player]: Model } = {}

local function despawn(plr: Player)
	local existing = boats[plr]
	if existing then
		existing:Destroy()
		boats[plr] = nil
	end
end

local function spawnFor(plr: Player, slot: Slot?)
	despawn(plr)
	local useSlot = slot
	if not useSlot then
		useSlot = claimSlot(plr)
	end
	if not useSlot then
		warn(("[LobbyBoat] no free mooring slot for %s (%d slot(s) total)"):format(plr.Name, #slots))
		return
	end
	boats[plr] = buildBoat(plr, useSlot)
end

local function slotOf(plr: Player): Slot?
	for _, slot in ipairs(slots) do
		if slot.taken == plr then
			return slot
		end
	end
	return nil
end

local function onPlayer(plr: Player)
	task.spawn(function()
		-- the boat shows owned modules, so wait for the profile rather than showing a wrong boat first
		for _ = 1, 60 do
			if Profiles.isReady(plr) then
				break
			end
			task.wait(0.25)
		end
		spawnFor(plr, nil)
	end)

	-- rebuild when they buy a module (ModulesServer bumps this) — the showroom updates live
	plr:GetAttributeChangedSignal("ModulesRev"):Connect(function()
		if boats[plr] then
			spawnFor(plr, slotOf(plr))
		end
	end)
end

buildSlots()

for _, plr in ipairs(Players:GetPlayers()) do
	onPlayer(plr)
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(plr)
	despawn(plr)
	releaseSlots(plr)
end)

print(("[LobbyBoat] showroom online — %d mooring slot(s)"):format(#slots))
