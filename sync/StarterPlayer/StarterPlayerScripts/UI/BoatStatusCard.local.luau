--!strict
-- BoatStatusCard.local.luau — how the boat is doing while you're not on it (Job #075). ASHORE only.
--
-- GAME.md names this as a core tension: *"the boat sits exposed at the dock while you're inland."* It
-- has never been surfaced. You'd walk into the jungle, loot a camp, walk back, and discover the hull
-- had been chewed down — with no signal at any point that it was happening, and no reason to turn back
-- early. A tension the player cannot perceive isn't a tension; it's just an outcome.
--
-- So this card carries the three facts that decide "do I keep pushing inland or head back":
--   · hull %          — is it being damaged
--   · distance back   — how long would returning take
--   · UNDER ATTACK    — is it happening RIGHT NOW
--
-- The alert is edge-triggered on hull DROPPING, not on a low-hull threshold: a boat sitting at 40% and
-- untouched is not an emergency, and a boat at 95% losing HP every second is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))
local HudState = require(RunUI:WaitForChild("HudState"))

local TICK = 0.25
local ALERT_HOLD = 4 -- seconds the warning stays up after the last hit, so a single bite still registers
local ALERT_COOLDOWN = 8 -- min seconds between warning sounds — a swarm must not become a machine gun

local player = Players.LocalPlayer

local gui = Components.screen("BoatStatusCard", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local card = RunComponents.card({
	name = "BoatStatus",
	anchor = Vector2.new(0, 0),
	position = UDim2.fromScale(0.015, 0.02),
	size = UDim2.fromScale(0.19, 0.14),
	parent = gui,
})
card.Visible = false

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(160, 84)
clamp.MaxSize = Vector2.new(300, 150)
clamp.Parent = card

local cardStroke = card:FindFirstChildOfClass("UIStroke")

-- header: icon + "BOAT" + distance
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.fromScale(1, 0.34)
header.BackgroundTransparency = 1
header.BorderSizePixel = 0
header.Active = false
header.Parent = card

local ico = Components.icon({ name = "boat", size = UDim2.fromScale(0.2, 0.72), chip = false, parent = header })
ico.AnchorPoint = Vector2.new(0, 0.5)
ico.Position = UDim2.fromScale(0.05, 0.5)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.fromScale(0.3, 0.5)
title.Size = UDim2.fromScale(0.28, 0.6)
title.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(title, Theme.text.caption, Theme.font.heading)
title.Text = "BOAT"
title.Parent = header

local distance = Instance.new("TextLabel")
distance.Name = "Distance"
distance.AnchorPoint = Vector2.new(1, 0.5)
distance.Position = UDim2.fromScale(0.94, 0.5)
distance.Size = UDim2.fromScale(0.44, 0.6)
distance.TextXAlignment = Enum.TextXAlignment.Right
Components.applyText(distance, Theme.text.caption, Theme.font.bodyBold)
distance.TextColor3 = Theme.color.creamDim
distance.Text = ""
distance.Parent = header

-- hull gauge
local gaugeHolder = Instance.new("Frame")
gaugeHolder.Name = "HullHolder"
gaugeHolder.Position = UDim2.fromScale(0.05, 0.36)
gaugeHolder.Size = UDim2.fromScale(0.9, 0.3)
gaugeHolder.BackgroundTransparency = 1
gaugeHolder.BorderSizePixel = 0
gaugeHolder.Active = false
gaugeHolder.Parent = card

local hullGauge = RunComponents.gauge({
	icon = "hull",
	color = Theme.color.green,
	dangerBelow = 0.3,
	size = UDim2.fromScale(1, 1),
	parent = gaugeHolder,
})

-- under-attack strip
local alert = Instance.new("Frame")
alert.Name = "Alert"
alert.AnchorPoint = Vector2.new(0.5, 1)
alert.Position = UDim2.fromScale(0.5, 0.96)
alert.Size = UDim2.fromScale(0.9, 0.24)
alert.BackgroundColor3 = Theme.color.red
alert.BackgroundTransparency = 0.25
alert.BorderSizePixel = 0
alert.Visible = false
alert.Active = false
Components.corner(Theme.radius.control, alert)
alert.Parent = card

local alertIcon = Components.icon({ name = "warning", size = UDim2.fromScale(0.16, 0.8), chip = false, parent = alert })
alertIcon.AnchorPoint = Vector2.new(0, 0.5)
alertIcon.Position = UDim2.fromScale(0.04, 0.5)

local alertLabel = Instance.new("TextLabel")
alertLabel.Name = "Label"
alertLabel.AnchorPoint = Vector2.new(1, 0.5)
alertLabel.Position = UDim2.fromScale(0.96, 0.5)
alertLabel.Size = UDim2.fromScale(0.76, 0.8)
alertLabel.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(alertLabel, Theme.text.caption, Theme.font.heading)
alertLabel.Text = "UNDER ATTACK"
alertLabel.Parent = alert

-- ── drive it ─────────────────────────────────────────────────────────────────────────────────────

local lastHp: number? = nil
local alertUntil = 0
local lastAlertSound = 0
local alertPulse: Tween? = nil

local function setAlert(on: boolean)
	if alert.Visible == on then
		return
	end
	alert.Visible = on
	if cardStroke then
		cardStroke.Color = if on then Theme.color.red else Theme.color.wood
	end
	if on then
		alertPulse = TweenService:Create(
			alert,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.6 }
		)
		;(alertPulse :: Tween):Play()
	elseif alertPulse then
		alertPulse:Cancel()
		alertPulse = nil
		alert.BackgroundTransparency = 0.25
	end
end

local function num(inst: Instance, name: string): number
	return (inst:GetAttribute(name) :: number?) or 0
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	local boat = HudState.boat()
	local show = HudState.current() == "ASHORE" and boat ~= nil and not HudState.runEnded()
	card.Visible = show
	if not show or not boat then
		lastHp = nil -- a fresh reading on the next disembark, so re-boarding doesn't fake a hit
		setAlert(false)
		return
	end

	local hp, maxHp = num(boat, "HP"), num(boat, "MaxHP")
	local fraction = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
	hullGauge.set(fraction, ("%d%%"):format(math.floor(fraction * 100 + 0.5)))

	-- how far back to the boat
	local hull = boat:FindFirstChild("Hull") :: BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hull and root then
		distance.Text = ("%dm"):format(math.floor((root.Position - hull.Position).Magnitude))
	else
		distance.Text = ""
	end

	-- taking damage right now?
	local now = os.clock()
	if lastHp and hp < lastHp - 0.01 then
		alertUntil = now + ALERT_HOLD
		if now - lastAlertSound >= ALERT_COOLDOWN then
			lastAlertSound = now
			UISound.play("lowHull")
		end
	end
	lastHp = hp
	setAlert(now < alertUntil)
end)
