--!strict
-- ModulesShop.local.luau — LOBBY boat-upgrade shop (Job 025; restyled to the design system in Job 065).
-- Lists boat modules (name, blurb, cost) with Buy / OWNED / can't-afford. Buys go through the
-- `BoatModules` RemoteFunction; the server validates and persists.
--
-- Job 065 changes: design system, per-module icons, CONFIRM POPUP before Gold is spent, and sound+VFX
-- on every outcome. Server contract untouched — the popup only gates when InvokeServer("buy") is called.
--
-- NOTE ON ART: modules are ONE-TIME unlocks (buy once → OWNED), not levelled, so the mockup's
-- "LEVEL 1 → 2 → 3" art does not apply here (ASSETS.md §1.9b). Each module needs a single render; until
-- those exist the row shows its vocabulary icon (gear/shield/fuel/crate/gun/spotlight).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any
local rf = ReplicatedStorage:WaitForChild("BoatModules") :: RemoteFunction

local panel = Components.panel({
	name = "ModulesShop",
	title = "Boat upgrades",
	icon = "wrench",
	size = UDim2.fromScale(0.56, 0.78),
	parent = playerGui,
})

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
layout.Padding = UDim.new(0, Theme.space.lg) -- row art breaks out of its row
layout.Parent = list
list.Parent = panel.content

type RowEntry = { refresh: (gold: number, owned: { [string]: boolean }) -> () }
local rows: { [string]: RowEntry } = {}
local refreshAll: (gold: number, owned: { [string]: boolean }) -> ()

local function makeRow(order: number, id: string)
	local def = ModuleDefs.get(id)
	if not def then
		return
	end

	local iconKey = (Theme.moduleIcon :: { [string]: string })[id]
	local row = Components.row({
		icon = iconKey,
		title = def.name,
		blurb = def.blurb,
		actionText = "…",
		layoutOrder = order,
		parent = list,
	})
	row.instance.Size = UDim2.new(1, 0, 0, Theme.rowHeight)

	local isOwned = false

	local function refresh(gold: number, owned: { [string]: boolean })
		isOwned = owned[id] == true
		if isOwned then
			row.action.setText("OWNED")
			row.action.setEnabled(false)
			return
		end
		row.action.setText(string.format("%d G", def.cost))
		row.action.setEnabled(gold >= def.cost)
	end

	local function commitBuy()
		local wasOwned = isOwned
		row.action.setText("…")
		local ok, res = pcall(function()
			return rf:InvokeServer("buy", id)
		end)
		if ok and type(res) == "table" and res.gold ~= nil then
			local nowOwned = (res.owned or {})[id] == true
			refreshAll(res.gold, res.owned or {})
			if nowOwned and not wasOwned then
				UISound.play("upgrade")
				Components.burst(row.instance, Theme.color.green)
				Components.toast(playerGui, iconKey, "Boat upgraded!", def.name)
			else
				-- server refused (gold changed under us, already owned, …)
				UISound.play("fail")
				row.flashFail()
			end
		else
			UISound.play("fail")
			row.flashFail()
			refreshAll((player:GetAttribute("Gold") :: number?) or 0, {})
		end
	end

	-- Gold is only ever spent behind a confirm (Job 065 decision)
	row.action.instance.Activated:Connect(function()
		if not row.action.instance.Active or isOwned then
			return
		end
		Components.confirm({
			parent = playerGui,
			icon = iconKey,
			title = def.name,
			body = def.blurb,
			costText = string.format("%d GOLD", def.cost),
			onConfirm = commitBuy,
		})
	end)

	rows[id] = { refresh = refresh }
end

refreshAll = function(gold: number, owned: { [string]: boolean })
	for _, entry in pairs(rows) do
		entry.refresh(gold, owned)
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
	panel.setOpen(true)
end

-- kiosk (server) and client-side entry both open this panel
local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "modules" then
		openShop()
	end
end)
UIBus.onOpen(function(id)
	if id == "modules" then
		openShop()
	end
end)
