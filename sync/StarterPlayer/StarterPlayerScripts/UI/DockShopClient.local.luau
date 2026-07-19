--!strict
-- DockShopClient.local.luau — in-run Salvage readout + dock shop panel (Job 023, design Job 020 §3).
-- A Salvage pill (reads the "Salvage" attribute) sits under the Gold pill. The shop panel opens when the
-- dock's "Dock Shop" prompt fires OpenDockShop; buys go through the DockShop RemoteFunction (server-
-- validated). Greybox, mobile-safe. Salvage is in-run only and resets each run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ShopDefs = require(ReplicatedStorage:WaitForChild("Economy"):WaitForChild("ShopDefs")) :: any
local openDockShop = ReplicatedStorage:WaitForChild("OpenDockShop") :: RemoteEvent
local shopRF = ReplicatedStorage:WaitForChild("DockShop") :: RemoteFunction

local ATTR = "Salvage"

local gui = Instance.new("ScreenGui")
gui.Name = "DockShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- ── Salvage pill (under the Gold pill, top-right) ────────────────────────────────────────────────
local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(1, 0)
pill.Position = UDim2.new(1, -14, 0, 58)
pill.Size = UDim2.fromScale(0.16, 0.05)
pill.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
pill.BackgroundTransparency = 0.2
pill.BorderSizePixel = 0
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(1, 0)
pc.Parent = pill
local par = Instance.new("UIAspectRatioConstraint")
par.AspectRatio = 3.9
par.Parent = pill
local pillLabel = Instance.new("TextLabel")
pillLabel.Size = UDim2.fromScale(0.9, 0.8)
pillLabel.Position = UDim2.fromScale(0.05, 0.1)
pillLabel.BackgroundTransparency = 1
pillLabel.Font = Enum.Font.GothamBold
pillLabel.TextColor3 = Color3.fromRGB(120, 210, 150)
pillLabel.TextScaled = true
pillLabel.TextXAlignment = Enum.TextXAlignment.Right
local ptsc = Instance.new("UITextSizeConstraint")
ptsc.MaxTextSize = 20
ptsc.Parent = pillLabel
pillLabel.Parent = pill
pill.Parent = gui

local function salvage(): number
	local s = player:GetAttribute(ATTR)
	return typeof(s) == "number" and s or 0
end
local function renderPill()
	pillLabel.Text = ("SALVAGE  %d"):format(salvage())
end
player:GetAttributeChangedSignal(ATTR):Connect(renderPill)
renderPill()

-- ── shop panel ──────────────────────────────────────────────────────────────────────────────────
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Visible = false
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.5, 0.72)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.Parent = dim
local pcc = Instance.new("UICorner")
pcc.CornerRadius = UDim.new(0, 14)
pcc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(120, 210, 150)
title.TextScaled = true
title.Text = "DOCK SHOP"
local ttsc = Instance.new("UITextSizeConstraint")
ttsc.MaxTextSize = 26
ttsc.Parent = title
title.Parent = panel

local balance = Instance.new("TextLabel")
balance.Position = UDim2.fromScale(0, 0.1)
balance.Size = UDim2.fromScale(1, 0.06)
balance.BackgroundTransparency = 1
balance.Font = Enum.Font.Gotham
balance.TextColor3 = Color3.new(1, 1, 1)
balance.TextScaled = true
balance.Text = ""
local btsc = Instance.new("UITextSizeConstraint")
btsc.MaxTextSize = 16
btsc.Parent = balance
balance.Parent = panel

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
list.Position = UDim2.fromScale(0.04, 0.18)
list.Size = UDim2.fromScale(0.92, 0.78)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = list

type Row = { refresh: (bal: number) -> () }
local rows: { Row } = {}
local refreshAll: (bal: number) -> ()

local function makeRow(order: number, id: string)
	local def = ShopDefs.get(id)
	if not def then
		return
	end
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 60)
	row.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromScale(0.03, 0.12)
	name.Size = UDim2.fromScale(0.6, 0.45)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextScaled = true
	name.Text = def.name
	local ntsc = Instance.new("UITextSizeConstraint")
	ntsc.MaxTextSize = 18
	ntsc.Parent = name
	name.Parent = row

	local blurb = Instance.new("TextLabel")
	blurb.Position = UDim2.fromScale(0.03, 0.57)
	blurb.Size = UDim2.fromScale(0.6, 0.36)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextColor3 = Color3.fromRGB(180, 185, 195)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextScaled = true
	blurb.Text = def.blurb
	local btsc2 = Instance.new("UITextSizeConstraint")
	btsc2.MaxTextSize = 13
	btsc2.Parent = blurb
	blurb.Parent = row

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.fromScale(0.97, 0.5)
	buy.Size = UDim2.fromScale(0.3, 0.66)
	buy.Font = Enum.Font.GothamBold
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.TextScaled = true
	buy.Text = "Buy  " .. def.cost
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = buy
	local btnsc = Instance.new("UITextSizeConstraint")
	btnsc.MaxTextSize = 16
	btnsc.Parent = buy
	buy.Parent = row

	local function refresh(bal: number)
		if bal < def.cost then
			buy.Text = tostring(def.cost)
			buy.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
			buy.Active = false
			buy.AutoButtonColor = false
		else
			buy.Text = "Buy  " .. def.cost
			buy.BackgroundColor3 = Color3.fromRGB(60, 130, 90)
			buy.Active = true
			buy.AutoButtonColor = true
		end
	end

	buy.Activated:Connect(function()
		if not buy.Active then
			return
		end
		buy.Text = "…"
		local ok, res = pcall(function()
			return shopRF:InvokeServer("buy", id)
		end)
		if ok and type(res) == "table" and res.salvage ~= nil then
			refreshAll(res.salvage)
		else
			refreshAll(salvage())
		end
	end)

	rows[order] = { refresh = refresh }
end

refreshAll = function(bal: number)
	balance.Text = "Salvage: " .. bal
	for _, r in ipairs(rows) do
		r.refresh(bal)
	end
end

for i, id in ipairs(ShopDefs.Order) do
	makeRow(i, id)
end

local function openShop()
	local ok, res = pcall(function()
		return shopRF:InvokeServer("list")
	end)
	local bal = (ok and type(res) == "table" and res.salvage) or salvage()
	refreshAll(bal)
	dim.Visible = true
end

openDockShop.OnClientEvent:Connect(openShop)
closeBtn.Activated:Connect(function()
	dim.Visible = false
end)
