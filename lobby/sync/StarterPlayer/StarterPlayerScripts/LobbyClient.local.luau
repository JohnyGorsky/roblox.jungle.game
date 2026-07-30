--!strict
-- LobbyClient.local.luau — lobby hint banner (Job 017; restyled to the design system in Job 065).
-- The pad signs + Start prompt are server-built; this is the short instruction that tells a new player
-- what the airfield is for.
--
-- Styled as a wood-bordered field notice (§6.1) rather than a floating dark slab, with the party icon so
-- it reads at a glance. Informational only — it never blocks input (§6.11).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Components.screen("LobbyHint", playerGui)
gui.DisplayOrder = 1

local panel = Instance.new("Frame")
panel.Name = "Hint"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.02)
panel.Size = UDim2.fromScale(0.44, 0.085)
panel.BackgroundColor3 = Theme.color.panel
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Active = false -- informational: never eats a tap
Components.corner(Theme.radius.panel, panel)
Components.stroke(Theme.color.wood, Theme.strokeWidth.control, panel)

local sizeClamp = Instance.new("UISizeConstraint")
sizeClamp.MinSize = Vector2.new(260, 54)
sizeClamp.MaxSize = Vector2.new(760, 130)
sizeClamp.Parent = panel

local icon = Components.icon({ name = "party", size = UDim2.fromScale(0.09, 0.62), parent = panel })
icon.AnchorPoint = Vector2.new(0, 0.5)
icon.Position = UDim2.fromScale(0.025, 0.5)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromScale(0.14, 0.12)
title.Size = UDim2.fromScale(0.82, 0.42)
title.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(title, Theme.text.h2, Theme.font.heading)
title.TextColor3 = Theme.color.gold -- an accent that means "do this" (§4)
title.Text = "STEP ON A LAUNCH PAD TO FORM A PARTY"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Name = "Subtitle"
sub.Position = UDim2.fromScale(0.14, 0.55)
sub.Size = UDim2.fromScale(0.82, 0.34)
sub.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(sub, Theme.text.caption, Theme.font.body)
sub.TextColor3 = Theme.color.creamDim
sub.Text = "First on a pad leads — hold Start to launch the run (up to 6)"
sub.Parent = panel

panel.Parent = gui
