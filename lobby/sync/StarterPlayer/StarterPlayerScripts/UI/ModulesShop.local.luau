--!strict
-- ModulesShop.local.luau — LOBBY boat-upgrade shop UI (Job 025). A toggle button opens a panel listing
-- boat modules (name, cost, Buy / OWNED / can't-afford). Buys go through the server RemoteFunction; the
-- server validates + persists. Greybox, mobile-safe (scale + text-size caps). Real design later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any
local rf = ReplicatedStorage:WaitForChild("BoatModules") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "ModulesShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ── open/close button (bottom-left, clear of GoldHud + lobby hint) ─────────────────────────────
local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 14, 1, -14)
openBtn.Size = UDim2.fromScale(0.18, 0.06)
openBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 170)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextScaled = true
openBtn.Text = "BOAT UPGRADES"
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

-- ── panel ──────────────────────────────────────────────────────────────────────────────────────
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Visible = false
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.5, 0.7)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.Parent = dim
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(245, 197, 66)
title.TextScaled = true
title.Text = "BOAT UPGRADES"
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
list.Position = UDim2.fromScale(0.04, 0.12)
list.Size = UDim2.fromScale(0.92, 0.84)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = list

-- one row per module; keep a refresh hook per row
type Row = { refresh: (gold: number, owned: { [string]: boolean }) -> () }
local rows: { [string]: Row } = {}
local refreshAll: (gold: number, owned: { [string]: boolean }) -> ()

local function makeRow(order: number, id: string)
	local def = ModuleDefs.get(id)
	if not def then
		return
	end
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromScale(0.03, 0.1)
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
	blurb.Position = UDim2.fromScale(0.03, 0.55)
	blurb.Size = UDim2.fromScale(0.6, 0.38)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextColor3 = Color3.fromRGB(180, 185, 195)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextScaled = true
	blurb.Text = def.blurb
	local btsc = Instance.new("UITextSizeConstraint")
	btsc.MaxTextSize = 13
	btsc.Parent = blurb
	blurb.Parent = row

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
	btnsc.MaxTextSize = 16
	btnsc.Parent = buy
	buy.Parent = row

	local function refresh(gold: number, owned: { [string]: boolean })
		if owned[id] then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = Color3.fromRGB(60, 120, 70)
			buy.Active = false
			buy.AutoButtonColor = false
		elseif gold < def.cost then
			buy.Text = tostring(def.cost) .. " G"
			buy.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
			buy.Active = false
			buy.AutoButtonColor = false
		else
			buy.Text = "Buy  " .. tostring(def.cost) .. " G"
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
			return rf:InvokeServer("buy", id)
		end)
		if ok and type(res) == "table" and res.gold ~= nil then
			refreshAll(res.gold, res.owned or {})
		end
	end)

	rows[id] = { refresh = refresh }
end

refreshAll = function(gold: number, owned: { [string]: boolean })
	for _, row in pairs(rows) do
		row.refresh(gold, owned)
	end
end

for i, id in ipairs(ModuleDefs.Order) do
	makeRow(i, id)
end

local function openShop()
	local ok, res = pcall(function()
		return rf:InvokeServer("list")
	end)
	local gold = (ok and type(res) == "table" and res.gold) or (player:GetAttribute("Gold") :: number?) or 0
	local owned = (ok and type(res) == "table" and res.owned) or {}
	refreshAll(gold, owned)
	dim.Visible = true
end

openBtn.Activated:Connect(openShop)
closeBtn.Activated:Connect(function()
	dim.Visible = false
end)
