--!strict
-- GoldHud.local.luau — minimal Gold balance readout (Job 021). Reads the replicated "Gold" attribute
-- the server mirrors onto the player. Greybox/mobile-safe (scale + aspect + text-size cap). IDENTICAL
-- copy in sync/ and lobby/sync/ so Gold shows in the lobby AND during a run.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local ATTR = "Gold"

local gui = Instance.new("ScreenGui")
gui.Name = "GoldHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(1, 0)
pill.Position = UDim2.new(1, -14, 0, 14)
pill.Size = UDim2.fromScale(0.16, 0.055)
pill.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
pill.BackgroundTransparency = 0.2
pill.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = pill
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 3.6
ar.Parent = pill

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.9, 0.8)
label.Position = UDim2.fromScale(0.05, 0.1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(245, 197, 66)
label.TextScaled = true
label.TextXAlignment = Enum.TextXAlignment.Right
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 22
tsc.Parent = label
label.Parent = pill
pill.Parent = gui

local function render()
	local g = player:GetAttribute(ATTR)
	label.Text = ("GOLD  %d"):format(typeof(g) == "number" and g or 0)
end

player:GetAttributeChangedSignal(ATTR):Connect(render)
render()
