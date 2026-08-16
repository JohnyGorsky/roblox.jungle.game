--!strict
-- CrewToast.local.luau — the small stacking crew feed (Job #084).
--
-- "X deposited 1 Gasoline · 4/25", seen by everyone. The cargo hold is shared, so a deposit is crew
-- news, not private feedback — a player at the helm should see the haul coming in without turning round.
--
-- ── Why this is NOT the ZoneBanner ────────────────────────────────────────────────────────────────
-- `ReplicatedStorage.Announce` → `ZoneBanner` already exists and would have been the cheap reuse. It is
-- the wrong instrument: a large centre-screen banner with a HOLD, tuned for rare beats (zone crossings,
-- NIGHTFALL). A deposit fires several times per landing, so reusing it would nag AND stomp the genuine
-- zone announcements it exists for. Same server→all-clients SHAPE, own lightweight presentation.
--
-- ⚠️ Fixed pool, oldest recycled — the same discipline as `CombatFeedback` and for the same reason. A
-- six-player crew unloading at once must not be able to allocate an unbounded stack of frames on a
-- phone, and `GameSoundscape`'s stacking lesson applies to UI as much as to audio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("CrewToast") :: RemoteEvent

local SLOTS = 3 -- concurrent toasts; past this the oldest is recycled
local LIFE = 3.2 -- seconds a toast stays up
local ROW_H = 0.045 -- scale height of one row, including its gap

local gui = Components.screen("CrewToast", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 9

-- Bottom-RIGHT. The left column is fully spoken for: hotbar (0.865–0.975), health (0.803–0.845), the
-- HANDS FULL card (0.761–0.797), RoleChip (0.42). Stacking upward from the bottom right keeps the feed
-- out of every one of them and off the centre where the zone banner lives.
local holder = Instance.new("Frame")
holder.Name = "Feed"
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.fromScale(0.985, 0.80)
holder.Size = UDim2.fromScale(0.26, ROW_H * SLOTS)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false
holder.Parent = gui

type Row = { card: Frame, label: TextLabel, detail: TextLabel, icon: Frame, born: number, live: boolean }
local rows: { Row } = {}
local nextRow = 1

for i = 1, SLOTS do
	local card = RunComponents.card({
		name = "Toast" .. i,
		anchor = Vector2.new(1, 1),
		position = UDim2.fromScale(1, i * ROW_H / (ROW_H * SLOTS)),
		size = UDim2.fromScale(1, 0.82 / SLOTS),
		accent = Theme.color.green, -- positive: something arrived in the hold
		parent = holder,
	})
	card.Visible = false

	local icon = Components.icon({ name = "crate", size = UDim2.fromScale(0.13, 0.66), chip = false, parent = card })
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0.04, 0.5)

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0.2, 0.5)
	label.Size = UDim2.fromScale(0.56, 0.7)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(label, Theme.text.caption, Theme.font.button)
	label.TextColor3 = Theme.color.cream
	label.Parent = card

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(1, 0.5)
	detail.Position = UDim2.fromScale(0.96, 0.5)
	detail.Size = UDim2.fromScale(0.22, 0.7)
	detail.BackgroundTransparency = 1
	detail.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(detail, Theme.text.caption, Theme.font.button)
	detail.TextColor3 = Theme.color.green
	detail.Parent = card

	table.insert(rows, { card = card, label = label, detail = detail, icon = icon, born = 0, live = false })
end

local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function hide(row: Row)
	row.live = false
	local t = TweenService:Create(row.card, FADE, { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		if not row.live then
			row.card.Visible = false
		end
	end)
	t:Play()
	TweenService:Create(row.label, FADE, { TextTransparency = 1 }):Play()
	TweenService:Create(row.detail, FADE, { TextTransparency = 1 }):Play()
end

local function show(text: string, detail: string, iconName: string?)
	local row = rows[nextRow]
	nextRow = (nextRow % SLOTS) + 1

	row.label.Text = text
	row.detail.Text = detail
	-- `Components.icon` returns a CONTAINER frame with the ImageLabel inside it (same shape ZoneBanner
	-- reads), so the id goes on the child, not on the returned frame.
	local img = row.icon:FindFirstChild("Image") :: ImageLabel?
	if img and iconName then
		img.Image = Components.iconId(iconName)
	end
	row.label.TextTransparency = 0
	row.detail.TextTransparency = 0
	row.card.BackgroundTransparency = 0.12
	row.card.Visible = true
	row.born = os.clock()
	row.live = true

	task.delay(LIFE, function()
		-- only retire it if it has not since been recycled for a newer message
		if row.live and os.clock() - row.born >= LIFE - 0.01 then
			hide(row)
		end
	end)
end

remote.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	show(tostring(data.text or ""), tostring(data.detail or ""), if typeof(data.icon) == "string" then data.icon else nil)
end)
