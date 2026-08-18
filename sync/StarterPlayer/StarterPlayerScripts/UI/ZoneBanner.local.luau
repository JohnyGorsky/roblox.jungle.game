--!strict
-- ZoneBanner.local.luau — centre-screen banner for zone crossings and the day/night set-pieces
-- (Job 035, restyled in Job #075).
--
-- Driven by TWO RemoteEvents (Job #098): `Announce` for crew-wide beats, and `HintBanner` for
-- per-player onboarding hints. Both render through the same `showBanner` — see the note at the bottom.
-- ZoneServer sends an `icon` and a `sound` key alongside the
-- title/subtitle/colour it always sent, so a crossing lands as a moment rather than as text appearing:
-- ZONE 2/4 gets a pin and the combat stinger, NIGHTFALL a moon, DAWN a sun. Older senders that omit
-- those two fields still work — the icon is simply skipped and nothing plays.
--
-- Transient by construction (§6.11): it fades itself out, never blocks input, and a newer banner
-- replaces an older one rather than queueing behind it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))

-- Job #094 — a touch player reads this banner over a screen a third the size, with both thumbs already
-- committed to the corners and the river still coming at them. Same words, less time in the way: it is
-- a zone crossing, not something you act on, so the banner only has to register. Shortened rather than
-- removed — mobile sees the same game, quieter.
local HOLD = if game:GetService("UserInputService").TouchEnabled then 1.8 else 2.6
local FADE_IN = 0.3
local FADE_OUT = 0.6

local player = Players.LocalPlayer
local announce = ReplicatedStorage:WaitForChild("Announce") :: RemoteEvent

local gui = Components.screen("ZoneBanner", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 40
gui.ScreenInsets = Enum.ScreenInsets.None -- a full-bleed moment, not a piece of chrome

local holder = Instance.new("Frame")
holder.Name = "Banner"
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Position = UDim2.fromScale(0.5, 0.17)
holder.Size = UDim2.fromScale(0.6, 0.17)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false -- never blocks input
holder.Parent = gui

local badge = Components.icon({ name = "pin", size = UDim2.fromScale(0.1, 0.44), parent = holder })
badge.AnchorPoint = Vector2.new(0.5, 0)
badge.Position = UDim2.fromScale(0.5, 0)
badge.Visible = false

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromScale(0, 0.44)
title.Size = UDim2.fromScale(1, 0.34)
title.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(title, Theme.text.display, Theme.font.display)
title.TextStrokeTransparency = 0.1 -- reads over bright water and dark canopy alike
title.TextTransparency = 1
title.Text = ""
title.Parent = holder

local sub = Instance.new("TextLabel")
sub.Name = "Subtitle"
sub.Position = UDim2.fromScale(0, 0.79)
sub.Size = UDim2.fromScale(1, 0.21)
sub.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(sub, Theme.text.body, Theme.font.bodyBold)
sub.TextColor3 = Theme.color.cream
sub.TextStrokeTransparency = 0.2
sub.TextTransparency = 1
sub.Text = ""
sub.Parent = holder

-- ── show / hide ──────────────────────────────────────────────────────────────────────────────────

local token = 0

-- Set transparency instantly. Used to snap the previous banner away before the new one fades in — a
-- zero-length tween would work on paper but leaves the old tween still running against the new one.
local function snap(target: number)
	title.TextTransparency = target
	title.TextStrokeTransparency = 0.1 + target * 0.9
	sub.TextTransparency = target
	sub.TextStrokeTransparency = 0.2 + target * 0.8
	badge.BackgroundTransparency = target
	local image = badge:FindFirstChild("Image") :: ImageLabel?
	if image then
		image.ImageTransparency = target
	end
	local stroke = badge:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = target
	end
end

local function fade(target: number, time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(title, info, { TextTransparency = target, TextStrokeTransparency = 0.1 + target * 0.9 }):Play()
	TweenService:Create(sub, info, { TextTransparency = target, TextStrokeTransparency = 0.2 + target * 0.8 }):Play()
	TweenService:Create(badge, info, { BackgroundTransparency = target }):Play()
	local image = badge:FindFirstChild("Image") :: ImageLabel?
	if image then
		TweenService:Create(image, info, { ImageTransparency = target }):Play()
	end
	local stroke = badge:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = target }):Play()
	end
end

local function showBanner(data)
	if typeof(data) ~= "table" then
		return
	end

	token += 1
	local myToken = token

	title.Text = string.upper(tostring(data.title or ""))
	title.TextColor3 = if typeof(data.color) == "Color3" then data.color else Theme.color.gold
	sub.Text = tostring(data.subtitle or "")

	local iconName = if typeof(data.icon) == "string" then data.icon else nil
	badge.Visible = iconName ~= nil
	if iconName then
		local image = badge:FindFirstChild("Image") :: ImageLabel?
		if image then
			image.Image = Components.iconId(iconName)
		end
	end

	if typeof(data.sound) == "string" then
		UISound.play(data.sound)
	end

	snap(1) -- clear whatever was on screen, then bring the new banner in
	fade(0, FADE_IN)

	task.delay(HOLD, function()
		if myToken ~= token then
			return -- a newer banner replaced this one
		end
		fade(1, FADE_OUT)
	end)
end

-- ── two channels, one banner (Job #098) ──────────────────────────────────────────────────────────
-- `Announce` is the CREW beat — zone crossings, nightfall, dawn — fired with FireAllClients by
-- ZoneServer. `HintBanner` is a PERSONAL teaching moment, fired with FireClient by Progression/Hints at
-- a player's first pickup and first deposit.
--
-- They share this renderer because they should look identical: a hint is not a different kind of
-- object on screen, it is the same banner carrying different words. They stay separate REMOTES because
-- one is crew-wide and one is per player — routing hints through `Announce` would put one newcomer's
-- tutorial on all six crew members' screens.
--
-- `token` already makes a newer banner replace an older one, so a hint arriving during a zone crossing
-- degrades to "the second one wins" rather than to two banners fighting.
announce.OnClientEvent:Connect(showBanner)

local hintBanner = ReplicatedStorage:WaitForChild("HintBanner") :: RemoteEvent
hintBanner.OnClientEvent:Connect(showBanner)
