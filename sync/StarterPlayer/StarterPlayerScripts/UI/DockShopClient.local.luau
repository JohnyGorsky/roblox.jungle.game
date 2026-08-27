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
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs")) :: any
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
	-- Job #104: their own glyphs, not `ammoBox` — see the note in `Theme.icon`
	pistolAmmo = "pistolAmmo",
	shotgunAmmo = "shotgunAmmo",
	-- ── Job #123: all four already existed in `Theme.icon` — no new assets ─────────────────────────
	-- `rifle`/`bazooka` are the WEAPONS, `rifleAmmo`/`rocketAmmo` are the rounds. That weapon-vs-round
	-- split is the same one `Theme.productIcon` makes for the Robux rows, and `Theme.icon:172` was
	-- already registered against the day this row existed: *"the natural glyph for an M16 ammo row if
	-- the trading post ever sells rifle rounds"*.
	m16 = "rifle",
	m16Ammo = "rifleAmmo",
	bazooka = "bazooka",
	bazookaAmmo = "rocketAmmo",
}

-- ── Job #104: do I own the gun this row feeds ammo to? ───────────────────────────────────────────
-- The SERVER is the authority (`SalvageServer.applyItem` refuses with "nogun" and deducts nothing).
-- This is purely so the row can SAY SO before you tap it, instead of letting you aim 90 salvage at
-- shells you cannot use. Reads the same `Slot1..N` attributes the hotbar renders from.
--
-- ⚠️ Loops to MAX_SLOTS, not `slotsFor(player)`. `InvSeeded` writes every slot up to MAX as "" and the
-- Extra Inventory Slots pass can land mid-run, so scanning the full range is both correct and immune to
-- the async `Owns_extraSlots` attribute arriving after this panel was built.
local function ownsItem(itemId: string?): boolean
	if not itemId then
		return true -- not an ammo row: nothing to own
	end
	for i = 1, ItemDefs.MAX_SLOTS do
		if player:GetAttribute("Slot" .. i) == itemId then
			return true
		end
	end
	return false
end

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
--
-- 🔴 Job #104: THIS LIST NOW CLIPS. It used to set `ClipsDescendants = false` for the badge overhang, and
-- with six rows that was invisible because the content happened to fit. The two ammo rows pushed the
-- content past the panel, and an unclipped ScrollingFrame does not hide the overflow — it DRAWS it, so the
-- last row rendered outside the panel, over the world, with no panel behind it. Caught in Play, not
-- reasoned about.
--
-- Clipping is what every other shop in the game does (the lobby's `SkillShop` carries ten rows and simply
-- leaves the default on). The badge is 1.34x row height and centred, so it overhangs by
-- 0.17 * 66 ~= 11 px; a matching top/bottom pad inside the canvas means the first and last badges are
-- still whole, while anything past the panel edge scrolls instead of escaping.
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, Theme.space.md)
listPad.PaddingBottom = UDim.new(0, Theme.space.md)
listPad.Parent = list
list.Parent = panel.content

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.lg)
layout.Parent = list

-- ── rows ─────────────────────────────────────────────────────────────────────────────────────────

type RowEntry = { row: Components.Row, id: string, cost: number, ammoFor: string? }
local rows: { RowEntry } = {}
local refreshAll: (bal: number) -> ()

-- ── Job #123: which stop's stock this panel is showing ───────────────────────────────────────────
-- The rows are built ONCE at startup (see the loop below), so a stop-gated row cannot be created on
-- demand — it is created hidden and revealed. This holds the landing ordinal the server reported on the
-- last open; 0 until the first one, which hides every gated row. Defaulting to 0 rather than 1 is the
-- safe direction: an unknown stop shows less, never more.
local shopStop = 0

local function buy(id: string, entry: RowEntry)
	-- No gun beats no money: telling someone they need 90 salvage for shells they could not fire is the
	-- wrong sentence, so this check comes first — same precedence as `refreshAll` below.
	if not ownsItem(entry.ammoFor) then
		entry.row.flashFail()
		UISound.play("fail")
		return
	end
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

	-- 🔴 Job #104: `res.ok`, NOT `res.salvage ~= nil`.
	-- The server returns the balance on FAILURE too — `{ error = "poor", salvage = n }`, and likewise for
	-- `invfull`, `cargofull` and the new `nogun` (`SalvageServer.applyItem`). So the old test read every
	-- refusal as a sale: green `Components.burst`, the purchase-success chime, and a balance refresh, for
	-- nothing granted. Read as "the ammo I paid for vanished" — much worse than a plain refusal, and the
	-- gun-ownership gate below is the path that would have hit it constantly.
	local succeeded = ok and type(res) == "table" and (res :: any).ok == true
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
		entry = { row = row, id = id, cost = def.cost, ammoFor = def.ammoFor }
		table.insert(rows, entry)
	end
end

refreshAll = function(bal: number)
	balance.Text = ("SALVAGE  %d"):format(bal)
	for _, entry in ipairs(rows) do
		-- ── Job #123: is this post even stocking the row? ────────────────────────────────────────
		-- HIDDEN, not muted. Muting is for "you can see why you can't buy this" (no gun, no money); a row
		-- the post does not stock has no story to tell and a greyed-out Bazooka at the first landing just
		-- advertises a wall. `Visible = false` also drops it out of the UIListLayout, so the panel is
		-- genuinely 8 rows at stop 1 rather than 12 rows with 4 blanks — which matters on a phone, where
		-- the list shows about three at a time.
		local stocked = ShopDefs.stockedAt(entry.id, shopStop)
		entry.row.instance.Visible = stocked
		if not stocked then
			continue -- nothing below this can matter for a row nobody can see
		end
		-- Affordable rows read as the obvious next tap; unaffordable ones are MUTED, not disabled.
		-- `setEnabled(false)` would set `Active = false` and stop `Activated` firing — and then a hopeful
		-- tap would get no flashFail, no `fail` cue and no explanation, which reads as a broken button.
		-- `setMuted` desaturates through the component's own `base`, so it survives hover (Job #075).
		-- Job #104: two reasons a row can be unbuyable now, and the order matters — see `buy`.
		local hasGun = ownsItem(entry.ammoFor)
		local affordable = bal >= entry.cost
		entry.row.action.setMuted(not (hasGun and affordable))
		entry.row.action.setText(
			if not hasGun
				then ("NEED %s"):format(string.upper(entry.ammoFor or ""))
				elseif affordable then ("BUY  %d"):format(entry.cost)
				else ("NEED  %d"):format(entry.cost)
		)
	end
end

-- ── open / close ─────────────────────────────────────────────────────────────────────────────────

openShop.OnClientEvent:Connect(function()
	local ok, res = pcall(function()
		return shopRF:InvokeServer("list")
	end)
	-- Job #123: the server reports the stop along with the balance. Read it BEFORE `refreshAll`, which is
	-- what applies it to the rows. If the call failed, `shopStop` keeps its last value (0 on a first
	-- open) and the gated rows stay hidden — a hidden row beats a visible one the server then refuses.
	if ok and type(res) == "table" and typeof((res :: any).stop) == "number" then
		shopStop = (res :: any).stop
	end
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

-- Job #104: and honest about the GUN too. A crewmate can hand you a slot's worth of gear, you can drop a
-- gun with Q, or the Extra Inventory Slots pass can land — all while you are standing at the counter. The
-- ammo rows' NEED PISTOL / NEED SHOTGUN state has to follow that, or it goes stale exactly when it matters.
for i = 1, ItemDefs.MAX_SLOTS do
	player:GetAttributeChangedSignal("Slot" .. i):Connect(function()
		if panel.isOpen() then
			refreshAll(salvage())
		end
	end)
end
