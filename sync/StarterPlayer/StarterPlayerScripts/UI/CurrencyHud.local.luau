--!strict
-- CurrencyHud.local.luau — the in-run currency chips (Job #075). Replaces `GoldHud.local.luau` and the
-- Salvage pill that `DockShopClient` used to draw.
--
-- WHY THEY MERGED: the two pills were built by unrelated scripts at hardcoded pixel offsets — Gold at
-- `(1, -14, 0, 14)`, Salvage at `(1, -14, 0, 58)` — so the second was positioned by having counted the
-- first one's height. Any change to either broke the stack. They are one row now, laid out, and either
-- one can appear or disappear without the other caring.
--
-- Gold is persistent meta currency; Salvage is in-run and resets. Both are mandatory at-a-glance info
-- under STYLEGUIDE §6.11, which is why they are the ONLY things allowed in the top-right during a run —
-- no avatar, no name, no level, no XP bar. That block is the LOBBY's top bar (TopBar.local.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local player = Players.LocalPlayer

local gui = Components.screen("CurrencyHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local row = Instance.new("Frame")
row.Name = "Chips"
row.AnchorPoint = Vector2.new(1, 0)
row.Position = UDim2.fromScale(0.985, 0.02)
row.Size = UDim2.fromScale(0.34, 0.058)
row.BackgroundTransparency = 1
row.BorderSizePixel = 0
row.Active = false

-- The chips derive every internal dimension from their own height (see Components.chip), so the row's
-- height is the only thing that has to be right. Clamped so it stays a comfortable read on a phone and
-- doesn't turn into a banner on a 4K monitor.
local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(0, 34)
clamp.MaxSize = Vector2.new(10000, 54)
clamp.Parent = row

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.sm)
layout.Parent = row

row.Parent = gui

local gold = Components.chip("coin", row)
gold.instance.LayoutOrder = 1

local salvage = Components.chip("salvage", row)
salvage.instance.LayoutOrder = 2
-- Salvage is the in-run currency, so it reads green (the "earned right now" accent) rather than gold.
local salvageValue = salvage.instance:FindFirstChild("Value") :: TextLabel?
if salvageValue then
	salvageValue.TextColor3 = Theme.color.green
end

-- Thousands separators: a six-figure Gold balance is unreadable as a bare run of digits, and the chip
-- measures its own text so a wider string simply makes a wider chip.
local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function attr(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function render()
	gold.setValue(commas(attr("Gold")))
	salvage.setValue(commas(attr("Salvage")))
end

player:GetAttributeChangedSignal("Gold"):Connect(render)
player:GetAttributeChangedSignal("Salvage"):Connect(render)
render()
