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
-- ── Where it sits, and why ────────────────────────────────────────────────────────────────────────
-- Directly UNDER the currency chips, top-right, stacking downward. The point of the feature is to
-- explain a number that just changed, so the message belongs beside the number — the eye travels from
-- "+40 SALVAGE" straight up to the counter it moved. That is also the only free real estate on that
-- side: `CurrencyHud` occupies y 0.02–0.078 anchored right, `CrewToast` owns the BOTTOM right (0.80),
-- `RiverProgress` the top centre (0.022), and the whole bottom-left is hotbar/health/HANDS FULL.
--
-- ⚠️ Fixed pool, oldest recycled — the same discipline `CrewToast` and `CombatFeedback` follow. Emptying
-- a camp can pay out several times in a second and a phone must not be handed an unbounded stack of
-- frames. On touch the pool is smaller, because a small screen shows one message well and three badly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RewardFeed") :: RemoteEvent

local SLOTS = if UserInputService.TouchEnabled then 2 else 4
local LIFE = 2.4 -- seconds a row stays up
local ROW_H = 0.042 -- scale height of one row including its gap
local TOP = 0.088 -- just below the currency chips (which end at ~0.078)

local gui = Components.screen("RewardFeed", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 8 -- under CurrencyHud (6 is the chips) but above world-space UI

local holder = Instance.new("Frame")
holder.Name = "Feed"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.fromScale(0.985, TOP)
holder.Size = UDim2.fromScale(0.30, ROW_H * SLOTS)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false -- never blocks input (STYLEGUIDE §6.11)
holder.Parent = gui

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

local rows: { Frame } = {}

local function relayout()
	for i, row in ipairs(rows) do
		row.Position = UDim2.fromScale(1, (i - 1) * ROW_H)
	end
end

local function retire(row: Frame)
	local at = table.find(rows, row)
	if not at then
		return
	end
	table.remove(rows, at)
	relayout()
	local out = TweenService:Create(row, Theme.tween.toast, {
		Position = UDim2.fromScale(1.15, row.Position.Y.Scale),
		BackgroundTransparency = 1,
	})
	out:Play()
	out.Completed:Once(function()
		row:Destroy()
	end)
end

local function show(kind: string, label: string, amount: number?)
	local style = STYLE[kind] or STYLE.salvage

	local row = Instance.new("Frame")
	row.Name = "Reward"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.fromScale(1.15, 0) -- slides in from the right edge
	row.Size = UDim2.fromScale(1, ROW_H * 0.86)
	row.BackgroundColor3 = Theme.color.panel
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Active = false

	local corner = Instance.new("UICorner")
	-- ⚠️ `Theme.radius.control` is a NUMBER of pixels (8), not a UDim — same as everywhere else in the
	-- theme. Assigning it straight to CornerRadius is a type error, not a rounded corner.
	corner.CornerRadius = UDim.new(0, Theme.radius.control)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.tint
	stroke.Thickness = Theme.strokeWidth.control
	stroke.Parent = row

	local ico = Components.icon({ name = style.icon, size = UDim2.fromScale(0.1, 0.72), parent = row })
	ico.Position = UDim2.fromScale(0.03, 0.14)

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Position = UDim2.fromScale(0.16, 0)
	text.Size = UDim2.fromScale(0.8, 1)
	text.BackgroundTransparency = 1
	text.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(text, Theme.text.body, Theme.font.heading)
	text.TextColor3 = style.tint
	-- "+40 SALVAGE" for a quantity, plain "PISTOL" for a one-off — "+1 PISTOL" reads like a stack count.
	text.Text = if amount then ("+%d %s"):format(amount, string.upper(label)) else string.upper(label)
	text.Parent = row

	row.Parent = holder

	-- Oldest out first, so the newest reward is always the one at the top next to the counter.
	table.insert(rows, 1, row)
	while #rows > SLOTS do
		retire(rows[#rows])
	end
	relayout()
	TweenService:Create(row, Theme.tween.toast, { Position = UDim2.fromScale(1, row.Position.Y.Scale) }):Play()

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
