--!strict
-- TeleportGui.local.luau — themed in-transit teleport screen (Job 056, todo 0007; on the design system
-- in Job #075). When this client teleports (lobby→game or game→lobby), Roblox shows this GUI while the
-- destination loads, instead of the default teleport screen. Matches the loading screen.
-- Note: only visible during a REAL place-to-place teleport (not in solo Studio Play).
--
-- ⚠️ IDENTICAL COPY IN BOTH TREES — `sync/` and `lobby/sync/`. Edit one, copy to the other in the same
-- commit. Same arrangement as the `UI/` folder, and for the same reason: the player sees this screen on
-- the way OUT of one place and the way IN to the other, so a difference between the copies would show
-- up as the screen changing halfway through a teleport.
--
-- Built with raw instances rather than `Components.screen` on purpose: a teleport GUI is handed to
-- `SetTeleportGui` and re-parented by the engine into the destination's loading context, so it must not
-- depend on anything from ReplicatedStorage being present when it is shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local bg = Instance.new("Frame")
bg.Name = "Backdrop"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Theme.color.jungleDark
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 1)
title.Position = UDim2.fromScale(0.5, 0.48)
title.Size = UDim2.fromScale(0.8, 0.12)
title.BackgroundTransparency = 1
title.BorderSizePixel = 0
title.Font = Theme.font.display
title.Text = "LAST RIVER"
title.TextColor3 = Theme.color.cream
title.TextStrokeColor3 = Theme.color.stroke
title.TextStrokeTransparency = 0.5
title.TextScaled = true
title.Parent = bg

local titleClamp = Instance.new("UITextSizeConstraint")
titleClamp.MaxTextSize = Theme.text.display.max
titleClamp.MinTextSize = Theme.text.display.min
titleClamp.Parent = title

local sub = Instance.new("TextLabel")
sub.Name = "Subtitle"
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.52)
sub.Size = UDim2.fromScale(0.6, 0.05)
sub.BackgroundTransparency = 1
sub.BorderSizePixel = 0
sub.Font = Theme.font.body
sub.Text = "Heading downriver…"
sub.TextColor3 = Theme.color.creamDim
sub.TextScaled = true
sub.Parent = bg

local subClamp = Instance.new("UITextSizeConstraint")
subClamp.MaxTextSize = Theme.text.body.max
subClamp.MinTextSize = Theme.text.body.min
subClamp.Parent = sub

TeleportService:SetTeleportGui(gui)
