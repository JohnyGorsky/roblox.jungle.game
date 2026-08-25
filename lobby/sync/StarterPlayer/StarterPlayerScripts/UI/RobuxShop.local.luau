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

-- ── Per-run charges (Job #117) ───────────────────────────────────────────────────────────────────
-- The LIFETIME M16 needs no code here at all: it is a game pass, so the loop above already renders it
-- with live pricing and OWNED state. This section is the other half — buy the same gun for ONE run.
--
-- 🔴 THIS LOOPS `RunGrants`, NOT `Products`, AND THAT IS NOT ARBITRARY.
-- Neither shop has ever rendered `MonetizationDefs.Products`, deliberately: those are consumables with
-- their own contextual buy points. Reaching for the obvious `for _, p in ipairs(Products)` here would put
-- **Self Revive, 20 R$, on a shelf, buyable at full health** — which that table's own comment says must
-- never happen, and whose grant closure returns false forever, so Roblox would re-deliver the receipt on
-- every join. `RunGrants` exists partly so that mistake is not reachable from this file.
--
-- ⚠️ NO EXTRA CONFIRM POPUP, same as every other Robux row: MarketplaceService shows Roblox's own dialog.
header("Buy for one run")
for _, g in ipairs(MonetizationDefs.RunGrants) do
	local live = g.productId > 0
	local row = offer(g.key, g.name, g.blurb, g.robux, live, function()
		MarketplaceService:PromptProductPurchase(player, g.productId)
	end)

	if live then
		-- ── the three ways this row goes dead, and why each is a DIFFERENT word ──────────────────
		-- Gold packs are excluded from owned-state above because "owned" is meaningless for a repeatable
		-- product. This one is repeatable too, but it is *one per run* — so it needs states that say WHICH
		-- run, or the player cannot tell "you already have it" from "you already paid for the next one".
		--
		--   OWNED    — they hold the lifetime pass. Never sell a per-run charge to someone who gets it free
		--              every run; `passKey` in the def is what links the two rows.
		--   THIS RUN — `Granted_<key>`, set by `Inventory/RifleGrant` when the gun actually reaches the
		--              loadout. GAME PLACE ONLY (nothing sets it in the lobby, which is correct — there is
		--              no run here to have used it up).
		--   NEXT RUN — `RunGrant_<key>` > 0: paid for and banked on the profile, waiting for a run to
		--              start. This is the normal state of a lobby purchase, and an honest label beats a
		--              live button that would take the money a second time.
		--
		-- ⚠️ ENFORCEMENT IS DISABLING THE BUTTON BEFORE THE PROMPT, because refusing AFTER the money is
		-- taken is not something MarketplaceService can do — the only lever is declining to consume the
		-- receipt, and that makes Roblox re-deliver it forever rather than refund. A receipt that arrives
		-- anyway is still honoured: it banks a charge for the next run (see MonetizationServer).
		local attrPass = if g.passKey then "Owns_" .. tostring(g.passKey) else nil
		local attrGranted = "Granted_" .. g.key
		local attrBanked = "RunGrant_" .. g.key

		-- ONE function that re-decides from scratch, exactly like the pass rows above. Three async inputs
		-- land here in any order — the pass check, the profile publish, and the Hub price lookup — and a
		-- handler that wrote the button directly could overwrite a settled state with a stale one.
		-- 🔴 Job #118: A FOURTH STATE, AND IT IS THE OPPOSITE DEFAULT TO THE PASS ROWS ABOVE.
		-- The pass rows deliberately start BUYABLE while `Owns_<key>` is in flight, and their comment
		-- explains why that is the safe way round: buying a pass you already own is refused by Roblox
		-- itself, so the worst case costs nobody anything.
		--
		-- **A PER-RUN CHARGE HAS NO SUCH BACKSTOP.** `MonetizationServer.checkPasses` waits up to 20 s
		-- for the profile before it even asks Roblox, so for those 20 s a lifetime-pass owner would see a
		-- live buy button here — and if they press it, `RifleGrant` prefers the free pass grant and
		-- **never spends or refunds the charge**. It sits on the profile forever. Money taken, nothing
		-- delivered, nothing logged.
		--
		-- So this row waits. `PassesChecked` is set once, after the whole ownership loop, and is the only
		-- honest signal that "not owned" means "not owned" rather than "not asked yet".
		-- ⚠️ Only rows that HAVE a `passKey` wait — a charge with no lifetime equivalent has nothing to
		-- find out and must not be held back.
		local function refresh()
			if attrPass and player:GetAttribute(attrPass) == true then
				row.action.setText("OWNED")
				row.action.setEnabled(false)
			elseif player:GetAttribute(attrGranted) == true then
				row.action.setText("THIS RUN")
				row.action.setEnabled(false)
			elseif ((player:GetAttribute(attrBanked) :: number?) or 0) > 0 then
				row.action.setText("NEXT RUN")
				row.action.setEnabled(false)
			elseif attrPass and player:GetAttribute("PassesChecked") ~= true then
				-- Checked AFTER the three definite states: "already granted" and "already banked" are
				-- known facts that do not depend on the pass lookup, and holding those behind it would
				-- show CHECKING over an answer we already have.
				row.action.setText("CHECKING")
				row.action.setEnabled(false)
			else
				row.action.setText(priceText(g.key, g.robux))
				row.action.setEnabled(true)
			end
		end

		refresh()
		player:GetAttributeChangedSignal("PassesChecked"):Connect(refresh)
		if attrPass then
			player:GetAttributeChangedSignal(attrPass):Connect(refresh)
		end
		player:GetAttributeChangedSignal(attrGranted):Connect(refresh)
		player:GetAttributeChangedSignal(attrBanked):Connect(refresh)
		fetchPrice(g.key, g.productId, Enum.InfoType.Product, refresh)
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
