--!strict
-- BoatModules.server.luau — apply owned boat modules to the shared boat (Job 025, design Job 020 §5).
-- Modules are bought in the LOBBY (persist in the profile). Here, on run start, we apply the UNION of the
-- crew's owned modules to the boat: weld on the visible part (massless / non-colliding, so it rides the
-- assembly without disturbing the physics) and set the capability attribute/effect. "Modules unlock, skills
-- tune" — deeper stat tuning is the skill tree (#024). Server-authoritative. Greybox parts (art later).

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
-- part→art mapping (Job 066). No-op while no art is imported; the greybox parts below stay as they are.
local BoatParts = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatParts"))

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat", 30)
local hull = boat and boat:WaitForChild("Hull", 10) :: BasePart?
if not boat or not hull then
	warn("[BoatModules] no boat/hull — modules not applied")
	return
end
local theBoat = boat :: Model
local theHull = hull :: BasePart

-- any crew member owns the module → the shared boat gets it (co-op-friendly for POC)
local function crewOwns(id: string): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		local prof = Profiles.get(plr)
		if prof and prof.modules and prof.modules[id] then
			return true
		end
	end
	return false
end

-- weld a massless, non-colliding visible part at an offset from the hull (rides the assembly)
-- `skinId` (Job 066) is a BoatParts key. When art exists for it, the mesh is welded on and this greybox
-- box becomes the invisible mount; when it doesn't, the box stays visible exactly as before.
local function addPart(
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	mat: Enum.Material?,
	skinId: string?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Massless = true
	p.CanCollide = false
	p.Anchored = false
	p.CFrame = theHull.CFrame * offset
	p.Parent = theBoat
	local w = Instance.new("WeldConstraint")
	w.Part0 = theHull
	w.Part1 = p
	w.Parent = p
	if skinId then
		BoatParts.skin(p, skinId)
	end
	return p
end

-- Job 066: the hull grew 22 -> 32 long, so module positions are DERIVED from it rather than hardcoded.
-- bow = -Z, stern = +Z. Anything that should sit "at the bow" or "at the stern" now follows the hull.
local HALF_Z = theHull.Size.Z / 2
local BOW = -HALF_Z + 1.5    -- just inside the bow
-- Clear of the gunwale: the visible hull now rises to ~4.5 in hull space, so the old 3.2 buried the
-- lamp inside the bow structure where nothing could see it.
local BOW_LIGHT_Y = 4.9
-- off the centreline: on it, the lamp sits directly in front of the gun barrel
local BOW_LIGHT_X = 0
local STERN = HALF_Z - 1.5   -- just inside the stern
local applied = false
local function apply()
	if applied then
		return
	end
	applied = true
	local on: { string } = {}

	-- every boat gets a basic BOW LIGHT at night (FINDING 0001 — boat was dark when riding). Night-only via
	-- the NightLight tag (LightController toggles it dusk→dawn). The Searchlight MODULE below is the upgrade.
	if not theBoat:FindFirstChild("BowLightHead") then
		local head = addPart("BowLightHead", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(245, 245, 210), CFrame.new(BOW_LIGHT_X, BOW_LIGHT_Y, BOW), Enum.Material.Neon, "bowLight")
		local blight = Instance.new("SpotLight")
		blight.Face = Enum.NormalId.Front -- forward / downstream (bow = -Z)
		blight.Angle = 80 -- wide beam so you can actually see the path (Job 052)
		blight.Range = 95
		blight.Brightness = 9
		blight.Enabled = false -- night-only; LightController turns NightLight tags on dusk→dawn
		CollectionService:AddTag(blight, "NightLight")
		blight.Parent = head
		-- local glow so the deck + immediate surroundings are visible, not just the forward beam (Job 052)
		local glow = Instance.new("PointLight")
		glow.Range = 34
		glow.Brightness = 2.5
		glow.Enabled = false
		CollectionService:AddTag(glow, "NightLight")
		glow.Parent = head
	end

	if crewOwns("fueltank") then
		theBoat:SetAttribute("MaxFuel", 150)
		theBoat:SetAttribute("Fuel", 150)
		addPart("FuelTankModule", Vector3.new(2, 3, 3), Color3.fromRGB(210, 180, 60), CFrame.new(4.5, 2.5, STERN * 0.75), Enum.Material.Metal, "fuelTank")
		table.insert(on, "fueltank")
	end
	if crewOwns("hullkit") then
		theBoat:SetAttribute("MaxHP", 150)
		theBoat:SetAttribute("HP", 150)
		-- Job 066: TILED plates along the parallel midbody, not one strip down the whole hull. The hull
		-- tapers fore and aft, so a full-length strip at constant beam hangs in open air at the ends;
		-- and stretching one 2.76-long plate to 30 smeared its bolt detail. Short plates at their
		-- modelled size, repeated, fix both.
		local PLATE_SIDES: { { name: string, x: number } } = { { name = "L", x = -7.1 }, { name = "R", x = 7.1 } }
		-- Height on the topsides. The hull BOX is only 3 tall but the visible hull mesh rises to ~4.5, so
		-- plates at box-centre (Y 0) hung off the keel below the waterline. This sits them on the flank.
		local PLATE_Y = 2.2
		local PLATE_SEGMENTS = 4
		local PLATE_LEN = 4.6
		local span = PLATE_SEGMENTS * PLATE_LEN
		for i = 1, PLATE_SEGMENTS do
			local z = -span / 2 + PLATE_LEN * (i - 0.5)
			for _, side in ipairs(PLATE_SIDES) do
				addPart("HullPlate" .. side.name .. i, Vector3.new(0.5, 2, PLATE_LEN),
					Color3.fromRGB(120, 122, 130), CFrame.new(side.x, PLATE_Y, z), Enum.Material.Metal, "hullPlate")
			end
		end
		table.insert(on, "hullkit")
	end
	if crewOwns("motor2") then
		theBoat:SetAttribute("ThrustMul", 1.25)
		addPart("Motor2", Vector3.new(2, 2, 3), Color3.fromRGB(40, 40, 46), CFrame.new(-3.5, 1, STERN), Enum.Material.Metal, "motor2")
		table.insert(on, "motor2")
	end
	if crewOwns("searchlight") then
		addPart("SearchlightMast", Vector3.new(0.8, 6, 0.8), Color3.fromRGB(60, 60, 66), CFrame.new(0, 5, BOW * 0.6), Enum.Material.Metal, "searchlightMast")
		local head = addPart("SearchlightHead", Vector3.new(2, 2, 2), Color3.fromRGB(245, 245, 210), CFrame.new(0, 8, BOW * 0.6 - 0.6), Enum.Material.Neon, "searchlightHead")
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front -- emits along -Z (forward / downstream)
		light.Angle = 70
		light.Range = 130 -- the searchlight upgrade throws far + bright (Job 052)
		light.Brightness = 11
		light.Enabled = false -- night-only; LightController turns it on at night (Job 038)
		CollectionService:AddTag(light, "NightLight")
		light.Parent = head
		theBoat:SetAttribute("HasSearchlight", true)
		table.insert(on, "searchlight")
	end
	if crewOwns("trailer") then
		theBoat:SetAttribute("CargoMax", ((theBoat:GetAttribute("CargoMax") :: number?) or 10) + 10)
		-- Job 066 (finding 0003): this used to sit at (0, −0.4, 15.5) — entirely inside the rear CargoDeck
		-- footprint (Z 11…27) and 1.4 studs BELOW it, so the 180-Gold upgrade was invisible. It now sits
		-- ON the rear deck as cargo racks, which is the point of a visible module. Deck top is
		-- hull.Y/2 - 0.5 + 0.5 = 1.5, so Y 3.0 puts a 3-tall rack on the deck surface.
		addPart("Trailer", Vector3.new(9, 3, 6), Color3.fromRGB(120, 90, 55), CFrame.new(0, 3, HALF_Z + 4), Enum.Material.WoodPlanks, "trailer")
		table.insert(on, "trailer")
	end
	if crewOwns("gunupgrade") then
		theBoat:SetAttribute("GunTier", 2)
		-- Job 066 decision #2: the upgrade REPLACES the base barrel's model, it does not bolt a second
		-- barrel on. Once art exists we re-skin the existing GunBarrel with the heavier model; until then
		-- we keep the greybox marker part so the upgrade is still visible in the greybox build.
		local barrel = theBoat:FindFirstChild("GunBarrel")
		local swapped = false
		if barrel and barrel:IsA("BasePart") then
			swapped = BoatParts.skin(barrel, "gunBarrel", true) ~= nil
		end
		if not swapped then
			addPart("GunBarrelUpgrade", Vector3.new(0.8, 0.8, 5), Color3.fromRGB(30, 30, 34), CFrame.new(0, 3, -3), Enum.Material.Metal)
		end
		table.insert(on, "gunupgrade")
	end

	-- ── skills (Job 024): boat skills at max crew level, applied on top of modules ──────────────────
	local function maxSkill(id: string): number
		local m = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			local prof = Profiles.get(plr)
			local lv = (prof and prof.skills and prof.skills[id]) or 0
			if lv > m then
				m = lv
			end
		end
		return m
	end

	local motors = maxSkill("motors")
	if motors > 0 then
		theBoat:SetAttribute("ThrustMul", ((theBoat:GetAttribute("ThrustMul") :: number?) or 1) * (1 + 0.03 * motors))
	end
	theBoat:SetAttribute("TurnMul", 1 + 0.025 * maxSkill("rudder"))
	local hullLv = maxSkill("hull")
	if hullLv > 0 then
		local newMax = ((theBoat:GetAttribute("MaxHP") :: number?) or 100) + 5 * hullLv
		theBoat:SetAttribute("MaxHP", newMax)
		theBoat:SetAttribute("HP", newMax)
	end
	theBoat:SetAttribute("FuelBurnMul", 0.975 ^ maxSkill("diesel"))
	local cargoLv = maxSkill("cargo")
	if cargoLv > 0 then
		theBoat:SetAttribute("CargoMax", ((theBoat:GetAttribute("CargoMax") :: number?) or 10) + math.round(0.5 * cargoLv))
	end

	-- crew skills: expose per-player levels for their systems to read (deep-wired later)
	for _, plr in ipairs(Players:GetPlayers()) do
		local prof = Profiles.get(plr)
		local sk = (prof and prof.skills) or {}
		plr:SetAttribute("SkillRepair", (sk.repair :: number?) or 0)
		plr:SetAttribute("SkillRefuel", (sk.refuel :: number?) or 0)
		plr:SetAttribute("SkillMedic", (sk.medic :: number?) or 0)
		plr:SetAttribute("SkillGun", (sk.gun :: number?) or 0)
		plr:SetAttribute("SkillScavenge", (sk.scavenge :: number?) or 0)
	end

	-- ── Armored Boat (Robux game pass, Job 027): the one power item — +20% HP & +20% weapon damage ──
	local armored = false
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("Owns_armoredBoat") == true then
			armored = true
			break
		end
	end
	if armored then
		local hp = math.floor(((theBoat:GetAttribute("MaxHP") :: number?) or 100) * 1.2)
		theBoat:SetAttribute("MaxHP", hp)
		theBoat:SetAttribute("HP", hp)
		theBoat:SetAttribute("GunDamageMul", 1.2) -- mounted-gun damage; combat reads later
		addPart("ArmoredHullL", Vector3.new(0.8, 2.4, 22), Color3.fromRGB(70, 72, 80), CFrame.new(-7.4, 0.3, 0), Enum.Material.DiamondPlate)
		addPart("ArmoredHullR", Vector3.new(0.8, 2.4, 22), Color3.fromRGB(70, 72, 80), CFrame.new(7.4, 0.3, 0), Enum.Material.DiamondPlate)
		addPart("ArmoredProw", Vector3.new(14, 2, 3), Color3.fromRGB(70, 72, 80), CFrame.new(0, 0.3, -11), Enum.Material.DiamondPlate)
	end

	print(("[BoatModules] applied: %s | skills applied%s"):format(#on > 0 and table.concat(on, ", ") or "none", armored and " | ARMORED" or ""))
end

if Workspace:GetAttribute("RunStarted") == true then
	apply()
else
	Workspace:GetAttributeChangedSignal("RunStarted"):Connect(function()
		if Workspace:GetAttribute("RunStarted") == true then
			apply()
		end
	end)
end
