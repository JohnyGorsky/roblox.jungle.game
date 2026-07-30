--!strict
-- RobuxShop.local.luau — LOBBY Robux shop (Job 027; restyled to the design system in Job 065).
-- Gold packs (developer products) + game passes. Buys fire real MarketplaceService prompts; unset
-- products (id 0) show "Soon". Real purchases only work on a published place.
--
-- Job 065 changes are VISUAL ONLY — same defs, same prompts, same ids, same "Soon" rule. What's new:
-- the design system (Theme/Components), the real store art per row (Theme.productIcon), and opening via
-- UIBus so the top bar's `+` and the shared entry bar can reach it. Kiosk opens still arrive on
-- ReplicatedStorage.OpenPanel, so both routes work.
--
-- Robux flows deliberately have NO extra confirm popup: MarketplaceService shows Roblox's own purchase
-- dialog. The confirm popup added in Job 065 gates GOLD spends, where nothing else would.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any

local panel = Components.panel({
	name = "RobuxShop",
	title = "Robux shop",
	icon = "shop",
	size = UDim2.fromScale(0.54, 0.78),
	parent = playerGui,
})

-- scrolling list of rows
local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Size = UDim2.fromScale(1, 1)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Theme.color.wood
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
-- wider gap than usual: row art is a circular badge that breaks out above and below its row
layout.Padding = UDim.new(0, Theme.space.lg)
layout.Parent = list

list.Parent = panel.content

local order = 0

local function header(text: string)
	order += 1
	local h = Instance.new("TextLabel")
	h.Name = "Header_" .. text
	h.LayoutOrder = order
	h.Size = UDim2.new(1, 0, 0, 26)
	h.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(h, Theme.text.h2, Theme.font.heading)
	h.TextColor3 = Theme.color.creamDim
	h.Text = string.upper(text)
	h.Parent = list
end

-- One purchasable line. `iconKey` indexes Theme.productIcon (the real Creator Hub art).
local function offer(iconKey: string, name: string, blurb: string, robux: number, enabled: boolean, onBuy: () -> ())
	order += 1
	local row = Components.row({
		iconImage = (Theme.productIcon :: { [string]: string })[iconKey],
		title = name,
		blurb = blurb,
		actionText = enabled and ("R$ " .. robux) or "Soon",
		variant = enabled and "primary" or "secondary",
		layoutOrder = order,
		parent = list,
		onActivated = onBuy,
	})
	row.instance.Size = UDim2.new(1, 0, 0, Theme.rowHeight)
	if not enabled then
		-- unset product: visibly unavailable rather than a dead button (§6.2 disabled state)
		row.action.setEnabled(false)
	end
end

header("Gold packs")
for _, p in ipairs(MonetizationDefs.GoldPacks) do
	offer(p.id, p.name, "+" .. p.gold .. " Gold", p.robux, p.productId > 0, function()
		MarketplaceService:PromptProductPurchase(player, p.productId)
	end)
end

header("Passes")
for _, gp in ipairs(MonetizationDefs.GamePasses) do
	offer(gp.key, gp.name, gp.blurb, gp.robux, gp.gamePassId > 0, function()
		MarketplaceService:PromptGamePassPurchase(player, gp.gamePassId)
	end)
end

-- ── open routes ───────────────────────────────────────────────────────────────────────────────────
-- 1) kiosk: the server fires OpenPanel when a player uses the ROBUX SHOP station (LobbyStations)
local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "robux" then
		panel.setOpen(true)
	end
end)

-- 2) client-side: the top bar's `+` and the shared entry bar
UIBus.onOpen(function(id)
	if id == "robux" then
		panel.setOpen(true)
	end
end)
