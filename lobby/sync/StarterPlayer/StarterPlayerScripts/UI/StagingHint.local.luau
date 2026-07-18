--!strict
-- StagingHint.local.luau — pre-run staging banner: "board the boat & untie to start" + N/M on boat (Job 016).
--
-- Shows only before Workspace.RunStarted. Reads the boat-occupancy counts StagingServer publishes
-- (Boat.OnBoatCount / Boat.CrewCount) so the crew knows to board before anyone unties. Greybox.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "StagingHint"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 70)
panel.Size = UDim2.fromScale(0.5, 0.12)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 4)
layout.Parent = panel
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 235, 150)
title.TextScaled = true
title.Text = "Pull the rope to reel the boat in — then board & untie to START"
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 22
tsc.Parent = title
title.Parent = panel

local crew = Instance.new("TextLabel")
crew.Size = UDim2.fromScale(1, 0.45)
crew.BackgroundTransparency = 1
crew.Font = Enum.Font.GothamBold
crew.TextColor3 = Color3.new(1, 1, 1)
crew.TextScaled = true
crew.Text = "0/0 on boat"
local csc = Instance.new("UITextSizeConstraint")
csc.MaxTextSize = 20
csc.Parent = crew
crew.Parent = panel

local function refresh()
	if Workspace:GetAttribute("RunStarted") then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local boat = Workspace:FindFirstChild("Boat")
	local onBoat = boat and (boat:GetAttribute("OnBoatCount") :: number?) or 0
	local total = boat and (boat:GetAttribute("CrewCount") :: number?) or 0
	crew.Text = string.format("%d/%d on boat", onBoat, total)
	crew.TextColor3 = if total > 0 and onBoat >= total then Color3.fromRGB(150, 220, 120) else Color3.new(1, 1, 1)
end

Workspace:GetAttributeChangedSignal("RunStarted"):Connect(refresh)

-- follow the boat's occupancy attributes (the Boat may not exist yet at load)
local function hookBoat(boat: Instance)
	boat:GetAttributeChangedSignal("OnBoatCount"):Connect(refresh)
	boat:GetAttributeChangedSignal("CrewCount"):Connect(refresh)
	refresh()
end
local existing = Workspace:FindFirstChild("Boat")
if existing then
	hookBoat(existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Boat" then
		hookBoat(child)
	end
end)

refresh()
