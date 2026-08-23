--!strict
-- RewardFeed.local.luau — "+40 SALVAGE" (Job #109).
--
-- Reported: *"when i take loot no messages nothing… We must have one generic message when you receive
-- scrap or loot, now you just guess."*
--
-- Server side is `ServerScriptService.Economy.RewardFeed`, which fires one entry per real reward. Its
-- header records why this is an explicit call and NOT a watcher on the Salvage attribute (short version:
-- the distance drip pays 1 Salvage every 60 studs for the whole run, and a watcher would toast forever).
--
-- ── 🔴 THE FIRST VERSION WAS "WEIRD AND THIN", AND BOTH HALVES OF THAT WERE LAYOUT MISTAKES ───────
--
-- 1. **It stretched.** The row was `Size = fromScale(1, ROW_H * 0.86)` inside a 0.30-wide holder, so on a
--    1920×1080 screen every message — three words or thirty — rendered as a **576 × 39 px strip** with a
--    speck of an icon at the far left and the text floating in the middle of a long empty bar. A message
--    box must be as wide as its message. This file now sizes exactly like `Components.chip` does (the
--    currency pills directly above it): fixed height, `AutomaticSize.X`, content-hugging.
--
-- 2. **It landed on the objectives card.** `ObjectiveHud` sits at `(0.985, 0.095)` anchored right, and
--    this feed was placed at `0.088` — i.e. deliberately "just under the currency chips", which is the
--    one slot in the top-right that was already taken. Nothing in the top-right is free: chips own
--    0.02–0.078 and the objectives tray owns 0.095 down to 0.335 when it is expanded.
--
-- ── Where it sits now ─────────────────────────────────────────────────────────────────────────────
-- Bottom-right, stacking UPWARD, immediately above `CrewToast` (which anchors at y 0.80 and reaches up
-- to 0.665 with three rows). That column is already "things that just happened", so a private reward
-- reads next to the crew's shared news without being mistaken for it — and it is the only free right-
-- hand real estate. Trade-off accepted: it no longer sits beside the Salvage counter it explains, but a
-- message that collides with the objectives card explains nothing at all.
--
-- ⚠️ Fixed pool, oldest recycled — the same discipline `CrewToast` and `CombatFeedback` follow. Emptying
-- a camp can pay out several times in a second and a phone must not be handed an unbounded stack of
-- frames. Fewer rows on touch, because a small screen shows one message well and four badly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RewardFeed") :: RemoteEvent

local TOUCH = UserInputService.TouchEnabled
local SLOTS = if TOUCH then 2 else 4
local LIFE = 2.6 -- seconds a row stays up
-- Bottom edge of the stack, above `CrewToast`.
--
-- ⚠️ MEASURED, NOT DERIVED FROM CREWTOAST'S CONSTANTS. On paper that feed anchors at 0.80 with three
-- 0.045 rows, so its top edge is 0.665 and 0.655 would clear it. Measured live at 1978×1313 its frame
-- actually spans y **835–1004**, i.e. a top edge of 0.636 — the ScreenGui's safe-area inset moves it.
-- 0.655 therefore sat *inside* it. Keep a real margin here rather than trusting the arithmetic.
local BOTTOM = if TOUCH then 0.66 else 0.60

local gui = Components.screen("RewardFeed", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 8

-- The holder hugs its rows in BOTH axes and is anchored by its bottom-right corner, so the stack grows
-- upward from a fixed point and every row right-aligns regardless of how long its text is.
local holder = Instance.new("Frame")
holder.Name = "Feed"
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.fromScale(0.985, BOTTOM)
holder.Size = UDim2.fromOffset(0, 0)
holder.AutomaticSize = Enum.AutomaticSize.XY
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false -- never blocks input (STYLEGUIDE §6.11)
holder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.xs)
layout.Parent = holder

-- Which icon and tint a reward reads as. `resource` covers the carryables (Gasoline/Metal/Ammo), which
-- are cargo rather than currency, so they take the crate glyph and the cream tone instead of the green
-- reserved for Salvage.
local STYLE: { [string]: { icon: string, tint: Color3 } } = {
	salvage = { icon = "salvage", tint = Theme.color.green },
	gold = { icon = "coin", tint = Theme.color.gold },
	resource = { icon = "crate", tint = Theme.color.cream },
	weapon = { icon = "gun", tint = Theme.color.gold },
	ammo = { icon = "ammoBox", tint = Theme.color.cream },
}

-- Row height in PIXELS, clamped — the same reasoning as `CurrencyHud`'s chip clamp. A pure scale height
-- is a 20 px sliver on a phone and a banner on a 4K monitor; these are read at a glance, so they want a
-- consistent physical size.
local function rowHeight(): number
	local cam = Workspace.CurrentCamera
	local vy = if cam then cam.ViewportSize.Y else 1080
	return math.clamp(math.floor(vy * 0.038), 30, 46)
end

local rows: { Frame } = {}
local order = 0

local function retire(row: Frame)
	local at = table.find(rows, row)
	if not at then
		return
	end
	table.remove(rows, at)
	-- Fade, then remove. Position belongs to the UIListLayout, so there is nothing to slide — and the
	-- destroy is driven off a single timer rather than the tween's Completed, because a tween on an
	-- instance that something else has already destroyed never completes.
	TweenService:Create(row, Theme.tween.toast, { BackgroundTransparency = 1 }):Play()
	local edge = row:FindFirstChildOfClass("UIStroke")
	if edge then
		TweenService:Create(edge, Theme.tween.toast, { Transparency = 1 }):Play()
	end
	task.delay(Theme.tween.toast.Time, function()
		row:Destroy()
	end)
end

local function show(kind: string, label: string, amount: number?)
	local style = STYLE[kind] or STYLE.salvage
	local H = rowHeight()
	local PAD, GAP = Theme.space.md, Theme.space.sm

	local row = Instance.new("Frame")
	row.Name = "Reward"
	-- ⚠️ Width 0 + AutomaticSize.X is the whole fix for "thin": the pill is exactly as wide as its icon,
	-- padding and text, and never a stretched bar across the screen.
	row.Size = UDim2.fromOffset(0, H)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundColor3 = Theme.color.sunken
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Active = false
	order += 1
	row.LayoutOrder = order -- newest at the bottom, nearest the eye

	local corner = Instance.new("UICorner")
	-- ⚠️ `Theme.radius.pill` is a NUMBER of pixels, like every radius in the theme — not a UDim.
	corner.CornerRadius = UDim.new(0, Theme.radius.pill)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.tint
	stroke.Thickness = Theme.strokeWidth.control
	stroke.Parent = row

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.Parent = row

	local inner = Instance.new("UIListLayout")
	inner.FillDirection = Enum.FillDirection.Horizontal
	inner.VerticalAlignment = Enum.VerticalAlignment.Center
	inner.HorizontalAlignment = Enum.HorizontalAlignment.Left
	inner.SortOrder = Enum.SortOrder.LayoutOrder
	inner.Padding = UDim.new(0, GAP)
	inner.Parent = row

	local iconPx = math.floor(H * 0.62)
	local ico = Components.icon({ name = style.icon, size = UDim2.fromOffset(iconPx, iconPx), chip = false, parent = row })
	ico.LayoutOrder = 1
	-- Both dimensions are explicit, so an aspect constraint only adds a way to collapse to zero — the
	-- same removal `Components.chip` makes for the same reason.
	local ratio = ico:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then
		ratio:Destroy()
	end

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.LayoutOrder = 2
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.Size = UDim2.new(0, 0, 1, 0)
	text.AutomaticSize = Enum.AutomaticSize.X
	-- ⚠️ TextScaled MUST stay false. `Components.applyText` turns it on, which is why the first version
	-- could not hug its text: a scaled label has no meaningful TextBounds and AutomaticSize collapses.
	text.TextScaled = false
	text.TextWrapped = false
	text.Font = Theme.font.bodyBold
	text.TextSize = math.clamp(math.floor(H * 0.46), Theme.text.body.min, Theme.text.body.max)
	text.TextColor3 = style.tint
	text.TextStrokeColor3 = Theme.color.stroke
	text.TextStrokeTransparency = 0.6
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	-- "+40 SALVAGE" for a quantity, plain "PISTOL" for a one-off — "+1 PISTOL" reads like a stack count.
	text.Text = if amount then ("+%d %s"):format(amount, string.upper(label)) else string.upper(label)
	text.Parent = row

	row.Parent = holder

	table.insert(rows, row)
	while #rows > SLOTS do
		retire(rows[1]) -- oldest is the lowest LayoutOrder, i.e. the top of the stack
	end

	-- A short pop rather than a slide: the row's position belongs to the UIListLayout now, so animating
	-- Position would fight it every frame.
	row.BackgroundTransparency = 1
	stroke.Transparency = 1
	TweenService:Create(row, Theme.tween.toast, { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(stroke, Theme.tween.toast, { Transparency = 0 }):Play()

	task.delay(LIFE, function()
		if row.Parent then
			retire(row)
		end
	end)
end

remote.OnClientEvent:Connect(function(entry)
	if typeof(entry) ~= "table" then
		return
	end
	local label = entry.label
	if typeof(label) ~= "string" then
		return
	end
	local amount = if typeof(entry.amount) == "number" then entry.amount else nil
	show(tostring(entry.kind), label, amount)
end)
