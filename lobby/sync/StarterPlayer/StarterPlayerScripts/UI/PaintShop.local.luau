--!strict
-- PaintShop.local.luau — LOBBY hull-livery picker (Job 067). Built to the Job 065 design system.
--
-- The Boat Paint Pack was live on the Creator Hub and delivered nothing (Job 067 finding 1). This is
-- where a buyer actually spends it. Picking a livery repaints the player's MOORED SHOWROOM BOAT while
-- they watch — PaintServer bumps `ModulesRev` and LobbyBoat rebuilds — which is the whole point of
-- having a showroom at all.
--
-- A SWATCH GRID, not the usual row list: liveries are a visual choice between six colours, and six rows
-- of text next to six identical badges would tell a player nothing that the colours themselves say
-- better. This is the one screen in the lobby where the product IS the picture.
--
-- Locked liveries are shown, not hidden — a player who hasn't bought the pack should be able to see
-- exactly what it gets them, and tapping one routes straight to the Robux shop (§6.11: no dead ends).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BoatPaint = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatPaint"))
local rf = ReplicatedStorage:WaitForChild("BoatPaint") :: RemoteFunction

local panel = Components.panel({
	name = "PaintShop",
	title = "Hull paint",
	icon = "boat",
	size = UDim2.fromScale(0.56, 0.72),
	parent = playerGui,
})

-- ── layout: a caption line, then the swatch grid ─────────────────────────────────────────────────

local caption = Instance.new("TextLabel")
caption.Name = "Caption"
caption.Size = UDim2.fromScale(1, 0.1)
caption.BackgroundTransparency = 1
caption.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(caption, Theme.text.body, Theme.font.body)
caption.TextColor3 = Theme.color.creamDim
caption.Text = ""
caption.Parent = panel.content

local grid = Instance.new("Frame")
grid.Name = "Swatches"
grid.Position = UDim2.fromScale(0, 0.13)
grid.Size = UDim2.fromScale(1, 0.87)
grid.BackgroundTransparency = 1
grid.Parent = panel.content

local cells = Instance.new("UIGridLayout")
cells.CellSize = UDim2.fromScale(0.31, 0.44)
cells.CellPadding = UDim2.fromScale(0.035, 0.06)
cells.SortOrder = Enum.SortOrder.LayoutOrder
cells.Parent = grid

-- ── one swatch ───────────────────────────────────────────────────────────────────────────────────

type Swatch = { refresh: (current: string, owned: boolean) -> () }
local swatches: { [string]: Swatch } = {}
local refreshAll: (current: string, owned: boolean) -> ()

local function makeSwatch(order: number, id: string)
	local def = BoatPaint.get(id)
	if not def then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = "Swatch_" .. id
	button.LayoutOrder = order
	button.BackgroundColor3 = Theme.color.sunken
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.radius.control)
	corner.Parent = button

	-- the selection ring: gold when chosen, dark wood otherwise. Selection is shown by the FRAME rather
	-- than by a tick, so nothing covers the colour the player is judging.
	local ring = Instance.new("UIStroke")
	ring.Color = Theme.color.woodDark
	ring.Thickness = Theme.strokeWidth.control
	ring.Parent = button

	-- the colour itself, filling most of the tile
	local chipHolder = Instance.new("Frame")
	chipHolder.Name = "Colour"
	chipHolder.AnchorPoint = Vector2.new(0.5, 0)
	chipHolder.Position = UDim2.fromScale(0.5, 0.08)
	chipHolder.Size = UDim2.fromScale(0.84, 0.56)
	chipHolder.BackgroundColor3 = def.color
	chipHolder.BorderSizePixel = 0
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, Theme.radius.control)
	chipCorner.Parent = chipHolder
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Theme.color.woodDark
	chipStroke.Thickness = Theme.strokeWidth.hairline
	chipStroke.Parent = chipHolder
	chipHolder.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Position = UDim2.fromScale(0.06, 0.68)
	label.Size = UDim2.fromScale(0.88, 0.18)
	label.BackgroundTransparency = 1
	Components.applyText(label, Theme.text.body, Theme.font.body)
	label.Text = def.name
	label.Parent = button

	local state = Instance.new("TextLabel")
	state.Name = "State"
	state.Position = UDim2.fromScale(0.06, 0.85)
	state.Size = UDim2.fromScale(0.88, 0.14)
	state.BackgroundTransparency = 1
	Components.applyText(state, Theme.text.caption, Theme.font.body)
	state.TextColor3 = Theme.color.creamDim
	state.Text = ""
	state.Parent = button

	button.Parent = grid

	local locked = false
	local selected = false

	local function refresh(current: string, owned: boolean)
		selected = current == id
		locked = BoatPaint.requiresPass(id) and not owned

		ring.Color = selected and Theme.color.gold or Theme.color.woodDark
		ring.Thickness = selected and Theme.strokeWidth.panel or Theme.strokeWidth.control
		-- Locked liveries are DIMMED, not hidden — seeing what the pack contains is what sells it.
		chipHolder.BackgroundTransparency = locked and 0.55 or 0
		label.TextTransparency = locked and 0.4 or 0

		if selected then
			state.Text = "EQUIPPED"
			state.TextColor3 = Theme.color.gold
		elseif locked then
			state.Text = "LOCKED"
			state.TextColor3 = Theme.color.creamDim
		else
			state.Text = "TAP TO EQUIP"
			state.TextColor3 = Theme.color.creamDim
		end
	end

	button.Activated:Connect(function()
		if selected then
			return
		end
		if locked then
			-- No dead ends (§6.11): send them where they can actually buy it.
			UISound.play("fail")
			panel.setOpen(false)
			UIBus.open("robux")
			return
		end
		local ok, res = pcall(function()
			return rf:InvokeServer("set", id)
		end)
		if ok and type(res) == "table" and res.ok then
			UISound.play("upgrade")
			Components.burst(button, def.color)
			Components.toast(playerGui, "boat", "Hull repainted!", def.name)
			refreshAll(res.current or id, res.owned == true)
		else
			UISound.play("fail")
			local owned = (type(res) == "table" and res.owned == true) or false
			refreshAll((type(res) == "table" and res.current) or BoatPaint.DEFAULT, owned)
		end
	end)

	swatches[id] = { refresh = refresh }
end

refreshAll = function(current: string, owned: boolean)
	for _, s in pairs(swatches) do
		s.refresh(current, owned)
	end
	caption.Text = owned and "Pick a livery — your moored boat repaints instantly."
		or "Olive drab is free. The Boat Paint Pack unlocks the rest."
end

for i, id in ipairs(BoatPaint.Order) do
	makeSwatch(i, id)
end

-- ── open routes ──────────────────────────────────────────────────────────────────────────────────

local function openShop()
	local ok, res = pcall(function()
		return rf:InvokeServer("list")
	end)
	local current = (ok and type(res) == "table" and res.current) or BoatPaint.DEFAULT
	local owned = ok and type(res) == "table" and res.owned == true
	refreshAll(current, owned)
	panel.setOpen(true)
end

local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "paint" then
		openShop()
	end
end)
UIBus.onOpen(function(id)
	if id == "paint" then
		openShop()
	end
end)
