--!strict
-- LobbyClient.local.luau — lobby hint banner (Job 017). The pad signs + Start prompt are server-built;
-- this is just a short instruction so players know what to do. Greybox.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyHint"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 70)
panel.Size = UDim2.fromScale(0.5, 0.09)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.55)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 235, 150)
title.TextScaled = true
title.Text = "Step on a LAUNCH PAD to form a party"
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 22
tsc.Parent = title
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Position = UDim2.fromScale(0, 0.55)
sub.Size = UDim2.fromScale(1, 0.45)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextColor3 = Color3.new(1, 1, 1)
sub.TextScaled = true
sub.Text = "First on a pad leads — hold Start to launch the run (up to 6)"
local ssc = Instance.new("UITextSizeConstraint")
ssc.MaxTextSize = 16
ssc.Parent = sub
sub.Parent = panel

panel.Parent = gui
