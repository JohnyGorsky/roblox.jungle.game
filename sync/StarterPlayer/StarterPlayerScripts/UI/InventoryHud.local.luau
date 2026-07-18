--!strict
-- InventoryHud.local.luau — the 4-slot loadout hotbar (Job 015).
--
-- Mobile-first, scale-based. One row of slot buttons at the bottom-left: tap a slot to equip it (one
-- item active at a time). The active slot is highlighted; guns show their ammo. Reads the player's
-- replicated inventory attributes (Slot1..N / ActiveSlot / ActiveItem / Ammo*). Keyboard 1-N + Q (drop)
-- are conveniences for Studio testing. Greybox — the real design system is a later pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("InventoryCmd") :: RemoteEvent
local SLOTS = ItemDefs.SLOT_COUNT

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.new(0, 12, 1, -12)
bar.Size = UDim2.fromScale(0.36, 0.1)
bar.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 6)
layout.Parent = bar
bar.Parent = gui

-- a "carrying" banner (hands full → can't use items)
local carryLabel = Instance.new("TextLabel")
carryLabel.AnchorPoint = Vector2.new(0, 1)
carryLabel.Position = UDim2.new(0, 12, 1, -12 - 4)
carryLabel.Size = UDim2.fromScale(0.36, 0.035)
carryLabel.BackgroundColor3 = Color3.fromRGB(160, 90, 40)
carryLabel.BackgroundTransparency = 0.2
carryLabel.TextColor3 = Color3.new(1, 1, 1)
carryLabel.Font = Enum.Font.GothamBold
carryLabel.TextScaled = true
carryLabel.Text = "HANDS FULL — carrying"
carryLabel.Visible = false
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 6)
carryCorner.Parent = carryLabel
local carrySize = Instance.new("UITextSizeConstraint")
carrySize.MaxTextSize = 14
carrySize.Parent = carryLabel
carryLabel.Parent = gui

type SlotUi = { button: TextButton, ammo: TextLabel }
local slotUis: { SlotUi } = {}

for i = 1, SLOTS do
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1 / SLOTS - 0.02, 1)
	button.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = tostring(i)
	button.LayoutOrder = i
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(60, 60, 70)
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = button
	local tsize = Instance.new("UITextSizeConstraint")
	tsize.MaxTextSize = 18
	tsize.Parent = button
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = button

	local ammo = Instance.new("TextLabel")
	ammo.AnchorPoint = Vector2.new(1, 0)
	ammo.Position = UDim2.fromScale(1, 0)
	ammo.Size = UDim2.fromScale(0.6, 0.3)
	ammo.BackgroundTransparency = 1
	ammo.Font = Enum.Font.GothamBold
	ammo.TextColor3 = Color3.fromRGB(255, 230, 150)
	ammo.TextScaled = true
	ammo.TextXAlignment = Enum.TextXAlignment.Right
	ammo.Text = ""
	ammo.Parent = button

	button.Activated:Connect(function()
		remote:FireServer("equip", i)
	end)

	button.Parent = bar
	slotUis[i] = { button = button, ammo = ammo }
end

local function shortName(id: string): string
	if id == "" then
		return ""
	end
	local def = ItemDefs.get(id)
	return if def then def.name else id
end

local function refresh()
	local active = (player:GetAttribute("ActiveSlot") :: number?) or 1
	for i = 1, SLOTS do
		local ui = slotUis[i]
		local id = (player:GetAttribute("Slot" .. i) :: string?) or ""
		ui.button.Text = if id == "" then tostring(i) else shortName(id)
		local isActive = i == active and id ~= ""
		ui.button.BackgroundColor3 = if isActive then Color3.fromRGB(70, 110, 60) else Color3.fromRGB(24, 24, 30)
		local stroke = ui.button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if isActive then Color3.fromRGB(150, 220, 120) else Color3.fromRGB(60, 60, 70)
		end
		local def = ItemDefs.get(id)
		if def and def.ammoAttr then
			ui.ammo.Text = tostring((player:GetAttribute(def.ammoAttr) :: number?) or 0)
		else
			ui.ammo.Text = ""
		end
	end
	carryLabel.Visible = player:GetAttribute("Busy") == true
end

-- react to any inventory/ammo/state change
for i = 1, SLOTS do
	player:GetAttributeChangedSignal("Slot" .. i):Connect(refresh)
end
player:GetAttributeChangedSignal("ActiveSlot"):Connect(refresh)
player:GetAttributeChangedSignal("ActiveItem"):Connect(refresh)
player:GetAttributeChangedSignal("Busy"):Connect(refresh)
for _, def in pairs(ItemDefs.Items) do
	if def.ammoAttr then
		player:GetAttributeChangedSignal(def.ammoAttr):Connect(refresh)
	end
end

-- keyboard shortcuts (testing convenience; mobile uses the buttons)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.One then
		remote:FireServer("equip", 1)
	elseif key == Enum.KeyCode.Two then
		remote:FireServer("equip", 2)
	elseif key == Enum.KeyCode.Three then
		remote:FireServer("equip", 3)
	elseif key == Enum.KeyCode.Four then
		remote:FireServer("equip", 4)
	elseif key == Enum.KeyCode.Q then
		remote:FireServer("drop", (player:GetAttribute("ActiveSlot") :: number?) or 1)
	end
end)

refresh()
