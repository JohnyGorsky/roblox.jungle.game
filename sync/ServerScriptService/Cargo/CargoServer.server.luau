--!strict
-- CargoServer.server.luau — the boat's back cargo DECK + fuel/repair stations (Job 013, back-deck design).
--
-- Cargo (Gasoline/Metal/Ammo) is stored ON the boat — ONE rigid assembly, no towed body (roblox-physics:
-- a single assembly is bulletproof; a towed second body is the fiddly/jittery path). A welded, MASSLESS
-- back deck extends the boat and holds the stations, so the boat's handling is unchanged. Loot fills the
-- cargo counts; the FUEL station spends gasoline → tank, the REPAIR station spends metal → hull HP; the
-- weapon draws ammo. Server-authoritative. Greybox.

local Workspace = game:GetService("Workspace")

local CARGO_MAX = 10
local FUEL_PER_GAS = 40
local REPAIR_PER_METAL = 25

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

-- cargo is stored on the boat
boat:SetAttribute("Gasoline", 0)
boat:SetAttribute("Metal", 0)
boat:SetAttribute("Ammo", 3) -- start with a little ammo (crates); the weapon reloads rounds from these
boat:SetAttribute("Rounds", 0)
boat:SetAttribute("CargoMax", CARGO_MAX)

local backZ = hull.Size.Z / 2 + 8 -- behind the stern (boat faces -Z, so +Z is the back)
local topY = hull.Size.Y / 2

-- back cargo deck: a MASSLESS welded extension of the hull → adds no mass/inertia, boat feel unchanged
local deck = Instance.new("Part")
deck.Name = "CargoDeck"
deck.Size = Vector3.new(14, 1, 16)
deck.Color = Color3.fromRGB(120, 85, 55)
deck.Material = Enum.Material.WoodPlanks
deck.Massless = true
deck.CanCollide = true -- players stand on it
deck.CFrame = hull.CFrame * CFrame.new(0, topY - 0.5, backZ) -- top ~flush with the hull deck
local dweld = Instance.new("WeldConstraint")
dweld.Part0 = hull
dweld.Part1 = deck
dweld.Parent = deck
deck.Parent = boat

local function makeStation(name: string, localCF: CFrame, color: Color3, actionText: string): ProximityPrompt
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(3, 3, 3)
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Massless = true
	p.CanCollide = false
	p.CFrame = hull.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
	p.Parent = boat
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.HoldDuration = 1.2
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Parent = p
	return prompt
end

-- FUEL station: spend 1 gasoline → refuel the tank (Fuel Handling skill scales fuel/gas — Job 029)
makeStation("Fuel Station", CFrame.new(-4, topY + 1.5, backZ), Color3.fromRGB(240, 190, 60), "Refuel").Triggered:Connect(function(player: Player)
	if ((boat:GetAttribute("Gasoline") :: number?) or 0) > 0 then
		boat:SetAttribute("Gasoline", (boat:GetAttribute("Gasoline") :: number) - 1)
		local maxF = (boat:GetAttribute("MaxFuel") :: number?) or 100
		local skill = (player:GetAttribute("SkillRefuel") :: number?) or 0
		local gain = FUEL_PER_GAS * (1 + 0.05 * skill)
		boat:SetAttribute("Fuel", math.min(maxF, ((boat:GetAttribute("Fuel") :: number?) or 0) + gain))
	end
end)

-- REPAIR station: spend 1 metal → mend the hull (Field Repair skill scales HP/metal — Job 029)
makeStation("Repair Station", CFrame.new(4, topY + 1.5, backZ), Color3.fromRGB(120, 200, 130), "Repair").Triggered:Connect(function(player: Player)
	if ((boat:GetAttribute("Metal") :: number?) or 0) > 0 then
		boat:SetAttribute("Metal", (boat:GetAttribute("Metal") :: number) - 1)
		local maxH = (boat:GetAttribute("MaxHP") :: number?) or 100
		local skill = (player:GetAttribute("SkillRepair") :: number?) or 0
		local gain = REPAIR_PER_METAL * (1 + 0.05 * skill)
		boat:SetAttribute("HP", math.min(maxH, ((boat:GetAttribute("HP") :: number?) or 0) + gain))
	end
end)

-- MEDIC station (Job 057): the 4th role. Presence-based (no spend) — while a crew member mans it, RoleServer
-- heals the crew and buffs revives (see RoleServer + PlayerCombat). Just a labelled part to stand at.
do
	local m = Instance.new("Part")
	m.Name = "Medic Station"
	m.Size = Vector3.new(3, 3, 3)
	m.Color = Color3.fromRGB(230, 90, 90)
	m.Material = Enum.Material.Metal
	m.Massless = true
	m.CanCollide = false
	m.CFrame = hull.CFrame * CFrame.new(0, topY + 1.5, backZ + 3)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hull
	w.Part1 = m
	w.Parent = m
	m.Parent = boat
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 90, 0, 28)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = m
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(255, 150, 150)
	lbl.TextStrokeTransparency = 0.4
	lbl.TextScaled = true
	lbl.Text = "MEDIC"
	lbl.Parent = bb
end

print("[Cargo] back deck + fuel/repair/medic stations online")
