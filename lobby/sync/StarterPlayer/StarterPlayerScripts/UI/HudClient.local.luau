--!strict
-- HudClient.local.luau — greybox HUD: boat fuel + hull HP bars (Job 010).
-- Reads the Boat model's replicated attributes. Scale-based / mobile-first; the real design system
-- (colours, fonts, layout) is a P9 job. Bottom-centre so it clears the mobile drive controls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BoatHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -50) -- lifted to clear the VehicleSeat speed gauge
container.Size = UDim2.fromScale(0.42, 0.1)
container.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 4)
layout.Parent = container
container.Parent = gui

local function makeBar(): (Frame, TextLabel)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 0.45)
	bar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	bar.BackgroundTransparency = 0.3
	bar.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill
	fill.Parent = bar
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 18
	tc.Parent = label
	label.Parent = bar
	bar.Parent = container
	return fill, label
end

local fuelFill, fuelLabel = makeBar()
local hpFill, hpLabel = makeBar()

-- cargo/ammo readout (POC — top-left; real design later)
local cargo = Instance.new("TextLabel")
cargo.Name = "Cargo"
cargo.Position = UDim2.new(0, 12, 0, 12)
cargo.Size = UDim2.fromScale(0.34, 0.05)
cargo.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
cargo.BackgroundTransparency = 0.35
cargo.BorderSizePixel = 0
cargo.TextColor3 = Color3.new(1, 1, 1)
cargo.Font = Enum.Font.GothamBold
cargo.TextScaled = true
cargo.TextXAlignment = Enum.TextXAlignment.Left
cargo.Text = ""
local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 6)
cCorner.Parent = cargo
local cPad = Instance.new("UIPadding")
cPad.PaddingLeft = UDim.new(0, 8)
cPad.PaddingRight = UDim.new(0, 8)
cPad.Parent = cargo
local cSize = Instance.new("UITextSizeConstraint")
cSize.MaxTextSize = 16
cSize.Parent = cargo
cargo.Parent = gui

local function ratio(cur: number?, max: number?): number
	if not cur or not max or max <= 0 then
		return 0
	end
	return math.clamp(cur / max, 0, 1)
end

RunService.RenderStepped:Connect(function()
	-- cargo/ammo readout from the boat's deck
	local boatForCargo = Workspace:FindFirstChild("Boat")
	cargo.Visible = boatForCargo ~= nil
	if boatForCargo then
		cargo.Text = string.format(
			"CARGO   Gas %d   Metal %d   Ammo %d (+%d rds)",
			(boatForCargo:GetAttribute("Gasoline") :: number?) or 0,
			(boatForCargo:GetAttribute("Metal") :: number?) or 0,
			(boatForCargo:GetAttribute("Ammo") :: number?) or 0,
			(boatForCargo:GetAttribute("Rounds") :: number?) or 0
		)
	end

	local boat = Workspace:FindFirstChild("Boat")
	container.Visible = boat ~= nil
	if not boat then
		return
	end
	local fr = ratio(boat:GetAttribute("Fuel") :: number?, boat:GetAttribute("MaxFuel") :: number?)
	fuelFill.Size = UDim2.fromScale(fr, 1)
	fuelFill.BackgroundColor3 = if fr < 0.2 then Color3.fromRGB(230, 90, 50) else Color3.fromRGB(240, 190, 60)
	fuelLabel.Text = string.format("FUEL  %d%%", math.floor(fr * 100 + 0.5))

	local hr = ratio(boat:GetAttribute("HP") :: number?, boat:GetAttribute("MaxHP") :: number?)
	hpFill.Size = UDim2.fromScale(hr, 1)
	hpFill.BackgroundColor3 = if hr < 0.3 then Color3.fromRGB(220, 70, 60) else Color3.fromRGB(90, 200, 110)
	hpLabel.Text = string.format("BOAT  %d%%", math.floor(hr * 100 + 0.5))
end)
