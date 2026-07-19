--!strict
-- RobuxShop.local.luau — LOBBY Robux shop (Job 027, design Job 020 §6). Gold packs (developer products) +
-- game passes (Armored Boat, cosmetics). Buys fire real MarketplaceService prompts; unset products (ID 0)
-- show "Soon". Greybox, mobile-safe. Real purchases only work on a published place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any

local gui = Instance.new("ScreenGui")
gui.Name = "RobuxShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 14, 1, -224)
openBtn.Size = UDim2.fromScale(0.18, 0.06)
openBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 90)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextScaled = true
openBtn.Text = "ROBUX SHOP"
local obc = Instance.new("UICorner")
obc.CornerRadius = UDim.new(0, 8)
obc.Parent = openBtn
local obar = Instance.new("UIAspectRatioConstraint")
obar.AspectRatio = 3.2
obar.Parent = openBtn
local obtsc = Instance.new("UITextSizeConstraint")
obtsc.MaxTextSize = 18
obtsc.Parent = openBtn
openBtn.Parent = gui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Visible = false
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.52, 0.8)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.Parent = dim
local pcc = Instance.new("UICorner")
pcc.CornerRadius = UDim.new(0, 14)
pcc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.09)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(120, 220, 150)
title.TextScaled = true
title.Text = "ROBUX SHOP"
local ttsc = Instance.new("UITextSizeConstraint")
ttsc.MaxTextSize = 26
ttsc.Parent = title
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -8, 0, 8)
closeBtn.Size = UDim2.fromScale(0.08, 0.08)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Text = "X"
local cbc = Instance.new("UICorner")
cbc.CornerRadius = UDim.new(0, 8)
cbc.Parent = closeBtn
closeBtn.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromScale(0.04, 0.11)
list.Size = UDim2.fromScale(0.92, 0.85)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = list

local order = 0
local function header(text: string)
	order += 1
	local h = Instance.new("TextLabel")
	h.LayoutOrder = order
	h.Size = UDim2.new(1, 0, 0, 26)
	h.BackgroundTransparency = 1
	h.Font = Enum.Font.GothamBold
	h.TextColor3 = Color3.fromRGB(150, 160, 175)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextScaled = true
	h.Text = text
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 14
	c.Parent = h
	h.Parent = list
end

local function row(name: string, blurb: string, robux: number, enabled: boolean, onBuy: () -> ())
	order += 1
	local r = Instance.new("Frame")
	r.LayoutOrder = order
	r.Size = UDim2.new(1, 0, 0, 58)
	r.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
	r.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = r

	local nm = Instance.new("TextLabel")
	nm.Position = UDim2.fromScale(0.03, 0.12)
	nm.Size = UDim2.fromScale(0.6, 0.45)
	nm.BackgroundTransparency = 1
	nm.Font = Enum.Font.GothamBold
	nm.TextColor3 = Color3.new(1, 1, 1)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.TextScaled = true
	nm.Text = name
	local nt = Instance.new("UITextSizeConstraint")
	nt.MaxTextSize = 17
	nt.Parent = nm
	nm.Parent = r

	local bl = Instance.new("TextLabel")
	bl.Position = UDim2.fromScale(0.03, 0.57)
	bl.Size = UDim2.fromScale(0.6, 0.35)
	bl.BackgroundTransparency = 1
	bl.Font = Enum.Font.Gotham
	bl.TextColor3 = Color3.fromRGB(180, 185, 195)
	bl.TextXAlignment = Enum.TextXAlignment.Left
	bl.TextScaled = true
	bl.Text = blurb
	local bt = Instance.new("UITextSizeConstraint")
	bt.MaxTextSize = 12
	bt.Parent = bl
	bl.Parent = r

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.fromScale(0.97, 0.5)
	buy.Size = UDim2.fromScale(0.3, 0.66)
	buy.Font = Enum.Font.GothamBold
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.TextScaled = true
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = buy
	local btnsc = Instance.new("UITextSizeConstraint")
	btnsc.MaxTextSize = 15
	btnsc.Parent = buy
	buy.Parent = r

	if enabled then
		buy.Text = "R$ " .. robux
		buy.BackgroundColor3 = Color3.fromRGB(50, 150, 90)
		buy.Active = true
		buy.Activated:Connect(onBuy)
	else
		buy.Text = "Soon"
		buy.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
		buy.Active = false
		buy.AutoButtonColor = false
	end
end

header("GOLD PACKS")
for _, p in ipairs(MonetizationDefs.GoldPacks) do
	row(p.name, "+" .. p.gold .. " Gold", p.robux, p.productId > 0, function()
		MarketplaceService:PromptProductPurchase(player, p.productId)
	end)
end
header("PASSES")
for _, gp in ipairs(MonetizationDefs.GamePasses) do
	row(gp.name, gp.blurb, gp.robux, gp.gamePassId > 0, function()
		MarketplaceService:PromptGamePassPurchase(player, gp.gamePassId)
	end)
end

openBtn.Activated:Connect(function()
	dim.Visible = true
end)
closeBtn.Activated:Connect(function()
	dim.Visible = false
end)
