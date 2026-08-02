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
--
-- Job 069 (audit Job 068 gap A1): PASS ROWS NOW SHOW OWNERSHIP. Until now every row was gated on
-- `gamePassId > 0` — "does this product exist" — never "does this player own it", so an owner of the
-- 499 R$ Armored Boat still saw a live buy button and only Roblox's dialog told them otherwise. This
-- was the one lobby shop with no owned state (ModulesShop=OWNED, SkillShop=MAX, Retention=CLAIMED,
-- PaintShop locks swatches).
--
-- GOLD PACKS ARE DELIBERATELY EXCLUDED — they are repeatable developer products, so "owned" is
-- meaningless for them and the buy button must always stay live.

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
-- Returns the row so pass rows can be flipped to OWNED later (Job 069).
local function offer(iconKey: string, name: string, blurb: string, robux: number, enabled: boolean, onBuy: () -> ())
	order += 1
	local row = Components.row({
		iconImage = (Theme.productIcon :: { [string]: string })[iconKey],
		-- Job 067: a vocabulary icon for anything without store art yet (Extra Inventory Slots), so a new
		-- product shows a meaningful badge instead of an empty circle. Real art wins when it's uploaded.
		icon = (Theme.productFallbackIcon :: { [string]: string })[iconKey],
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
	return row
end

-- ── live prices (Job #069) ────────────────────────────────────────────────────────────────────────
-- `MonetizationDefs.robux` is what this shop PRINTS; the Creator Hub is what the player is actually
-- CHARGED — and all three passes have MANAGED PRICING enabled, so Roblox can move a price without
-- anyone touching our code. All 8 were verified in sync on 2026-08-02, but that is a snapshot, not a
-- guarantee: nothing would tell us if one drifted, and the player would just see a wrong number.
--
-- So ask the Hub for the real price, and fall back to the def when the call fails.
--
-- DELIBERATELY NON-BLOCKING. `GetProductInfo` is a web call and must never gate the UI, so the panel
-- builds and opens immediately showing the def price, and each row corrects itself when its own
-- lookup lands. Fetched once per session and cached — reopening the shop refetches nothing.
local livePrice: { [string]: number } = {}

local function fetchPrice(key: string, id: number, infoType: Enum.InfoType, apply: () -> ())
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			if livePrice[key] ~= info.PriceInRobux then
				livePrice[key] = info.PriceInRobux
				apply()
			end
		end
	end)
end

-- what a row should print: the Hub price once we have it, otherwise the hardcoded def
local function priceText(key: string, fallback: number): string
	return "R$ " .. (livePrice[key] or fallback)
end

header("Gold packs")
for _, p in ipairs(MonetizationDefs.GoldPacks) do
	local live = p.productId > 0
	local row = offer(p.id, p.name, "+" .. p.gold .. " Gold", p.robux, live, function()
		MarketplaceService:PromptProductPurchase(player, p.productId)
	end)
	if live then
		fetchPrice(p.id, p.productId, Enum.InfoType.Product, function()
			row.action.setText(priceText(p.id, p.robux))
		end)
	end
end

header("Passes")
for _, gp in ipairs(MonetizationDefs.GamePasses) do
	local live = gp.gamePassId > 0
	local row = offer(gp.key, gp.name, gp.blurb, gp.robux, live, function()
		MarketplaceService:PromptGamePassPurchase(player, gp.gamePassId)
	end)

	if live then
		-- `Owns_<key>` is published by MonetizationServer — on join (after an async
		-- UserOwnsGamePassAsync round-trip) and again on PromptGamePassPurchaseFinished.
		--
		-- THE DEFAULT MUST BE "NOT OWNED". The attribute arrives some time AFTER this row is built, so
		-- the row starts showing the price and flips to OWNED when it lands. Defaulting the other way
		-- would briefly hide a real buy button from someone who hasn't bought it — a worse failure than
		-- briefly showing one to someone who has. Listening for the change is also what makes the row
		-- update the moment a purchase completes, with no reopen.
		local attr = "Owns_" .. gp.key
		local function refresh()
			if player:GetAttribute(attr) == true then
				row.action.setText("OWNED")
				row.action.setEnabled(false)
			else
				row.action.setText(priceText(gp.key, gp.robux))
				row.action.setEnabled(true)
			end
		end
		refresh()
		player:GetAttributeChangedSignal(attr):Connect(refresh)
		-- The price lookup re-runs the SAME `refresh`, never `setText` directly. Both are async and
		-- race: if a late price wrote the button itself it could overwrite OWNED on a pass the player
		-- already has, turning a settled row back into a buy button. Routing both through one function
		-- that re-decides from scratch makes the order they land in irrelevant.
		fetchPrice(gp.key, gp.gamePassId, Enum.InfoType.GamePass, refresh)
	end
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
