--!strict
-- DockShopClient.local.luau — the dock trading post (Job 023, rebuilt on the design system in Job #075).
--
-- Opens when a dock's "Dock Shop" prompt fires `OpenDockShop`; buys go through the `DockShop`
-- RemoteFunction, which is server-validated. Salvage is in-run only and resets each run.
--
-- Job #075 changes:
--   · the Salvage pill moved OUT of here and into `CurrencyHud`, which owns both currency chips. This
--     script had been drawing a permanent top-right pill purely because it happened to own the
--     attribute — which is also why `IntroHudGate` had to hide a script called "DockShop" during the
--     plane intro. That coupling is gone.
--   · the panel is `Components.panel` + `Components.row`, so it is the same object as the lobby's three
--     shops: title bar, icon, X, tap-outside-to-close, thumb-sized buy buttons.
--   · a failed buy now says so — `flashFail()` plus the `fail` cue. Previously an unaffordable tap did
--     nothing at all, which reads as a broken button rather than as "you can't afford this".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopDefs = require(ReplicatedStorage:WaitForChild("Economy"):WaitForChild("ShopDefs")) :: any
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))

local player = Players.LocalPlayer
local openShop = ReplicatedStorage:WaitForChild("OpenShop") :: RemoteEvent
local shopRF = ReplicatedStorage:WaitForChild("DockShop") :: RemoteFunction

-- shop item id -> Theme.icon key. Everything the post sells already has a glyph in the set.
local ITEM_ICON: { [string]: string } = {
	bandage = "bandage",
	fuel = "fuel",
	ammo = "ammoBox",
	repair = "tools",
	pistol = "pistol",
	shotgun = "shotgun",
}

local function salvage(): number
	local s = player:GetAttribute("Salvage")
	return if typeof(s) == "number" then s else 0
end

-- ── panel ────────────────────────────────────────────────────────────────────────────────────────

local panel = Components.panel({
	name = "DockShop",
	title = "Trading post",
	icon = "shop",
	size = UDim2.fromScale(0.52, 0.74),
	parent = player:WaitForChild("PlayerGui"),
})
panel.gui.DisplayOrder = 20

local balance = Instance.new("TextLabel")
balance.Name = "Balance"
balance.Position = UDim2.fromScale(0, 0)
balance.Size = UDim2.fromScale(1, 0.07)
balance.TextXAlignment = Enum.TextXAlignment.Right
Components.applyText(balance, Theme.text.body, Theme.font.bodyBold)
balance.TextColor3 = Theme.color.green
balance.Text = ""
balance.Parent = panel.content

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Position = UDim2.fromScale(0, 0.09)
list.Size = UDim2.fromScale(1, 0.91)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.ScrollBarImageColor3 = Theme.color.wood
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
-- rows carry a badge that breaks out of the row top and bottom (see Components.row), so the gap between
-- them is the LARGE step, not the small one — otherwise consecutive badges touch
list.ClipsDescendants = false
list.Parent = panel.content

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.lg)
layout.Parent = list

-- ── rows ─────────────────────────────────────────────────────────────────────────────────────────

type RowEntry = { row: Components.Row, cost: number }
local rows: { RowEntry } = {}
local refreshAll: (bal: number) -> ()

local function buy(id: string, entry: RowEntry)
	if salvage() < entry.cost then
		-- Never a silent no-op: the tap did land, you just can't afford it.
		entry.row.flashFail()
		UISound.play("fail")
		return
	end

	entry.row.action.setEnabled(false)
	local ok, res = pcall(function()
		return shopRF:InvokeServer("buy", id)
	end)
	entry.row.action.setEnabled(true)

	local succeeded = ok and type(res) == "table" and res.salvage ~= nil
	UISound.purchase(succeeded)
	if succeeded then
		Components.burst(entry.row.instance, Theme.color.green)
		refreshAll((res :: any).salvage)
	else
		entry.row.flashFail()
		refreshAll(salvage())
	end
end

for order, id in ipairs(ShopDefs.Order) do
	local def = ShopDefs.get(id)
	if def then
		local entry: RowEntry
		local row = Components.row({
			icon = ITEM_ICON[id] or "crate",
			title = def.name,
			blurb = def.blurb,
			actionText = tostring(def.cost),
			variant = "primary",
			layoutOrder = order,
			parent = list,
			onActivated = function()
				buy(id, entry)
			end,
		})
		row.instance.Size = UDim2.new(1, 0, 0, Theme.rowHeight)
		entry = { row = row, cost = def.cost }
		table.insert(rows, entry)
	end
end

refreshAll = function(bal: number)
	balance.Text = ("SALVAGE  %d"):format(bal)
	for _, entry in ipairs(rows) do
		-- Affordable rows read as the obvious next tap; unaffordable ones are MUTED, not disabled.
		-- `setEnabled(false)` would set `Active = false` and stop `Activated` firing — and then a hopeful
		-- tap would get no flashFail, no `fail` cue and no explanation, which reads as a broken button.
		-- `setMuted` desaturates through the component's own `base`, so it survives hover (Job #075).
		local affordable = bal >= entry.cost
		entry.row.action.setMuted(not affordable)
		entry.row.action.setText(
			if affordable then ("BUY  %d"):format(entry.cost) else ("NEED  %d"):format(entry.cost)
		)
	end
end

-- ── open / close ─────────────────────────────────────────────────────────────────────────────────

openShop.OnClientEvent:Connect(function()
	local ok, res = pcall(function()
		return shopRF:InvokeServer("list")
	end)
	refreshAll(if ok and type(res) == "table" and res.salvage then res.salvage else salvage())
	panel.setOpen(true)
end)

-- Keep the balance line honest while the panel is open — salvage can arrive from a teammate's haul or
-- the passive drip while you're standing at the counter.
player:GetAttributeChangedSignal("Salvage"):Connect(function()
	if panel.isOpen() then
		refreshAll(salvage())
	end
end)
