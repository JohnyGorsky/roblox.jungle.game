--!strict
-- TeleportGui.local.luau — themed in-transit teleport screen (Job 056, todo 0007). When this client teleports
-- (lobby→game or game→lobby), Roblox shows this GUI while the destination loads, instead of the default
-- teleport screen. Matches the loading screen (dark + "LAST RIVER"). IDENTICAL copy in both trees.
-- Note: only visible during a REAL place-to-place teleport (not in solo Studio Play).

local TeleportService = game:GetService("TeleportService")

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(12, 18, 16) -- deep jungle-night (matches the loading screen)
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 1)
title.Position = UDim2.fromScale(0.5, 0.48)
title.Size = UDim2.fromScale(0.8, 0.12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "LAST RIVER"
title.TextColor3 = Color3.fromRGB(230, 240, 232)
title.TextScaled = true
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.52)
sub.Size = UDim2.fromScale(0.6, 0.05)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.Text = "Heading downriver..."
sub.TextColor3 = Color3.fromRGB(150, 170, 158)
sub.TextScaled = true
sub.Parent = bg

TeleportService:SetTeleportGui(gui)
