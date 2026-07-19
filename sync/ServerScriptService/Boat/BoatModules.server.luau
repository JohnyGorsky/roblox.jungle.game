--!strict
-- BoatModules.server.luau — apply owned boat modules to the shared boat (Job 025, design Job 020 §5).
-- Modules are bought in the LOBBY (persist in the profile). Here, on run start, we apply the UNION of the
-- crew's owned modules to the boat: weld on the visible part (massless / non-colliding, so it rides the
-- assembly without disturbing the physics) and set the capability attribute/effect. "Modules unlock, skills
-- tune" — deeper stat tuning is the skill tree (#024). Server-authoritative. Greybox parts (art later).

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

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
local function addPart(name: string, size: Vector3, color: Color3, offset: CFrame, mat: Enum.Material?): BasePart
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
	return p
end

-- hull is 14 (X) × 3 (Y) × 22 (Z); front/bow = -Z, stern = +Z
local applied = false
local function apply()
	if applied then
		return
	end
	applied = true
	local on: { string } = {}

	if crewOwns("fueltank") then
		theBoat:SetAttribute("MaxFuel", 150)
		theBoat:SetAttribute("Fuel", 150)
		addPart("FuelTankModule", Vector3.new(2, 3, 3), Color3.fromRGB(210, 180, 60), CFrame.new(4.5, 2.5, 8), Enum.Material.Metal)
		table.insert(on, "fueltank")
	end
	if crewOwns("hullkit") then
		theBoat:SetAttribute("MaxHP", 150)
		theBoat:SetAttribute("HP", 150)
		addPart("HullPlateL", Vector3.new(0.6, 2, 20), Color3.fromRGB(120, 122, 130), CFrame.new(-7.3, 0, 0), Enum.Material.Metal)
		addPart("HullPlateR", Vector3.new(0.6, 2, 20), Color3.fromRGB(120, 122, 130), CFrame.new(7.3, 0, 0), Enum.Material.Metal)
		table.insert(on, "hullkit")
	end
	if crewOwns("motor2") then
		theBoat:SetAttribute("ThrustMul", 1.25)
		addPart("Motor2", Vector3.new(2, 2, 3), Color3.fromRGB(40, 40, 46), CFrame.new(-3.5, 1, 10.5), Enum.Material.Metal)
		table.insert(on, "motor2")
	end
	if crewOwns("searchlight") then
		addPart("SearchlightMast", Vector3.new(0.8, 6, 0.8), Color3.fromRGB(60, 60, 66), CFrame.new(0, 5, -7), Enum.Material.Metal)
		local head = addPart("SearchlightHead", Vector3.new(2, 2, 2), Color3.fromRGB(245, 245, 210), CFrame.new(0, 8, -7.6), Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front -- emits along -Z (forward / downstream)
		light.Angle = 70
		light.Range = 90
		light.Brightness = 4
		light.Enabled = false -- night-only; LightController turns it on at night (Job 038)
		CollectionService:AddTag(light, "NightLight")
		light.Parent = head
		theBoat:SetAttribute("HasSearchlight", true)
		table.insert(on, "searchlight")
	end
	if crewOwns("trailer") then
		theBoat:SetAttribute("CargoMax", ((theBoat:GetAttribute("CargoMax") :: number?) or 10) + 10)
		addPart("Trailer", Vector3.new(8, 1.5, 7), Color3.fromRGB(120, 90, 55), CFrame.new(0, -0.4, 15.5), Enum.Material.WoodPlanks)
		table.insert(on, "trailer")
	end
	if crewOwns("gunupgrade") then
		theBoat:SetAttribute("GunTier", 2)
		addPart("GunBarrelUpgrade", Vector3.new(0.8, 0.8, 5), Color3.fromRGB(30, 30, 34), CFrame.new(0, 3, -3), Enum.Material.Metal)
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
