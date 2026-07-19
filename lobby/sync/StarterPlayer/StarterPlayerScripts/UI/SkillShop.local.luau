--!strict
-- SkillShop.local.luau — LOBBY skill-tree UI (Job 024). A "SKILLS" button opens a panel listing the 10
-- skills with their level (X/10) and the next level's Gold cost. Buys go through the server RemoteFunction.
-- Greybox, mobile-safe. Real tree design later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any
local rf = ReplicatedStorage:WaitForChild("Skills") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "SkillShop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- open button (stacked above the BOAT UPGRADES button, bottom-left)
local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 14, 1, -84)
openBtn.Size = UDim2.fromScale(0.18, 0.06)
openBtn.BackgroundColor3 = Color3.fromRGB(150, 110, 60)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextScaled = true
openBtn.Text = "SKILLS"
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
panel.Size = UDim2.fromScale(0.52, 0.78)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.Parent = dim
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.09)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(230, 190, 120)
title.TextScaled = true
title.Text = "SKILLS"
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

type Row = { refresh: (gold: number, level: number) -> () }
local rows: { [string]: Row } = {}
local refreshAll: (gold: number, skills: { [string]: number }) -> ()

local function makeRow(order: number, id: string)
	local def = SkillDefs.get(id)
	if not def then
		return
	end
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromScale(0.03, 0.12)
	name.Size = UDim2.fromScale(0.5, 0.5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextScaled = true
	name.Text = def.name .. "  (" .. def.group .. ")"
	local ntsc = Instance.new("UITextSizeConstraint")
	ntsc.MaxTextSize = 17
	ntsc.Parent = name
	name.Parent = row

	local lvl = Instance.new("TextLabel")
	lvl.Position = UDim2.fromScale(0.03, 0.58)
	lvl.Size = UDim2.fromScale(0.5, 0.38)
	lvl.BackgroundTransparency = 1
	lvl.Font = Enum.Font.Gotham
	lvl.TextColor3 = Color3.fromRGB(180, 185, 195)
	lvl.TextXAlignment = Enum.TextXAlignment.Left
	lvl.TextScaled = true
	lvl.Text = ""
	local ltsc = Instance.new("UITextSizeConstraint")
	ltsc.MaxTextSize = 13
	ltsc.Parent = lvl
	lvl.Parent = row

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.fromScale(0.97, 0.5)
	buy.Size = UDim2.fromScale(0.32, 0.7)
	buy.Font = Enum.Font.GothamBold
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.TextScaled = true
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = buy
	local btnsc = Instance.new("UITextSizeConstraint")
	btnsc.MaxTextSize = 15
	btnsc.Parent = buy
	buy.Parent = row

	local function refresh(gold: number, level: number)
		lvl.Text = ("Lv %d / %d  ·  +%s%s"):format(level, SkillDefs.MAX_LEVEL, tostring(def.per), def.unit)
		if level >= SkillDefs.MAX_LEVEL then
			buy.Text = "MAX"
			buy.BackgroundColor3 = Color3.fromRGB(60, 120, 70)
			buy.Active = false
			buy.AutoButtonColor = false
		else
			local cost = SkillDefs.cost(level + 1)
			if gold < cost then
				buy.Text = tostring(cost) .. " G"
				buy.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
				buy.Active = false
				buy.AutoButtonColor = false
			else
				buy.Text = "Buy  " .. cost .. " G"
				buy.BackgroundColor3 = Color3.fromRGB(60, 130, 90)
				buy.Active = true
				buy.AutoButtonColor = true
			end
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
			refreshAll(res.gold, res.skills or {})
		end
	end)

	rows[id] = { refresh = function(gold, level)
		refresh(gold, level)
	end }
end

refreshAll = function(gold: number, skills: { [string]: number })
	for id, row in pairs(rows) do
		row.refresh(gold, (skills[id] :: number?) or 0)
	end
end

for i, id in ipairs(SkillDefs.Order) do
	makeRow(i, id)
end

local function openShop()
	local ok, res = pcall(function()
		return rf:InvokeServer("list")
	end)
	local gold = (ok and type(res) == "table" and res.gold) or (player:GetAttribute("Gold") :: number?) or 0
	local skills = (ok and type(res) == "table" and res.skills) or {}
	refreshAll(gold, skills)
	dim.Visible = true
end

openBtn.Activated:Connect(openShop)
closeBtn.Activated:Connect(function()
	dim.Visible = false
end)

-- lobby kiosk (Job 032): the SKILL TRAINER station opens this panel too
local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "skills" then
		openShop()
	end
end)
