--!strict
-- HealthHud.local.luau — the player's own health bar (Job #075).
--
-- Replaces Roblox's core health bar, which is the single most off-palette thing that was on screen: a
-- blue-to-red gradient slab in the top-left, in a game whose entire UI is cream-on-jungle-green. It is
-- switched off for good in `IntroHudGate` (which used to switch it back ON when the intro ended).
--
-- STYLEGUIDE §6.11 lists health as mandatory at-a-glance info, so this is one of the few things that is
-- persistently on screen in every HUD state. It sits bottom-left directly above the hotbar, because
-- that's where your eye already goes to pick a bandage.
--
-- Low health also gets a screen-edge vignette. Reading a number is a deliberate act; a red rim is not,
-- and "am I about to die" should not require a deliberate act while a crocodile is on the deck.

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

local DANGER = 0.3 -- fraction below which the bar turns red and the vignette comes up

local player = Players.LocalPlayer

local gui = Components.screen("HealthHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

-- ── low-health vignette ──────────────────────────────────────────────────────────────────────────
-- A plain tinted frame rather than a real vignette image: we have no vignette asset, and a flat wash at
-- high transparency reads the same at the screen edge once the eye is on the centre of the action.
-- Parented to its own gui so it can sit BEHIND the bar without fighting DisplayOrder with other HUDs.
local vignetteGui = Components.screen("HealthVignette", player.PlayerGui)
vignetteGui.DisplayOrder = 4
vignetteGui.ScreenInsets = Enum.ScreenInsets.None -- must reach the true screen edge, notch included

local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Theme.color.red
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.Active = false
vignette.Parent = vignetteGui

-- ── the bar ──────────────────────────────────────────────────────────────────────────────────────
local holder = Instance.new("Frame")
holder.Name = "Health"
holder.AnchorPoint = Vector2.new(0, 1)
-- Sits above the hotbar. The hotbar is anchored at y=0.975 and is ~0.11 tall, so this clears it.
holder.Position = UDim2.fromScale(0.015, 0.845)
holder.Size = UDim2.fromScale(0.2, 0.042)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false

local sizeClamp = Instance.new("UISizeConstraint")
sizeClamp.MinSize = Vector2.new(150, 26)
sizeClamp.MaxSize = Vector2.new(340, 46)
sizeClamp.Parent = holder

holder.Parent = gui

local gauge = RunComponents.gauge({
	icon = "heart",
	color = Theme.color.green,
	dangerBelow = DANGER,
	size = UDim2.fromScale(0.76, 1),
	parent = holder,
})

-- Bandages sit with health because they are the same fact from two sides: what you have left, and what
-- you can do about it. They are also the ONE resource with no hotbar slot to report them — bandages are
-- a player attribute consumed by the revive hold, not an equippable — so without this chip the number
-- that decides whether you can pick a teammate up is invisible. (Gun ammo deliberately is NOT duplicated
-- here; the hotbar slot already carries it, and §6.11 does not permit saying the same thing twice.)
local bandages = RunComponents.statChip("bandage", Theme.color.cream, holder)
bandages.instance.AnchorPoint = Vector2.new(1, 0.5)
bandages.instance.Position = UDim2.fromScale(1, 0.5)
bandages.instance.Size = UDim2.fromScale(0.21, 1)

local function renderBandages()
	local n = (player:GetAttribute("Bandages") :: number?) or 0
	bandages.setValue(tostring(n))
	bandages.setAlert(n <= 0)
end
player:GetAttributeChangedSignal("Bandages"):Connect(renderBandages)
renderBandages()

-- ── drive it from the character ──────────────────────────────────────────────────────────────────

local conn: RBXScriptConnection? = nil
local lastFraction = 1

local function setVignette(fraction: number)
	-- ramps from invisible at DANGER to a firm wash at zero, so it grows with the danger rather than
	-- snapping on at a threshold
	local target = if fraction >= DANGER then 1 else 0.72 + 0.28 * (fraction / DANGER)
	TweenService:Create(vignette, Theme.tween.normal, { BackgroundTransparency = target }):Play()
end

local function watch(char: Model)
	if conn then
		conn:Disconnect()
		conn = nil
	end
	lastFraction = 1

	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
	if not hum or not hum:IsA("Humanoid") then
		return
	end
	local humanoid = hum :: Humanoid

	local function render()
		local max = humanoid.MaxHealth
		local fraction = if max > 0 then math.clamp(humanoid.Health / max, 0, 1) else 0
		gauge.set(fraction, ("%d"):format(math.ceil(humanoid.Health)))
		setVignette(fraction)

		-- One cue per hit, on the falling edge only — a Changed handler fires for healing too, and a
		-- grunt while a medic is patching you up would be nonsense.
		if fraction < lastFraction - 0.001 then
			UISound.play("hurt")
		end
		lastFraction = fraction
	end

	conn = humanoid.HealthChanged:Connect(render)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(render)
	render()
end

-- Dead or missing character: empty the bar and clear the wash, rather than leaving the last live value
-- frozen on screen while you spectate (RunClient owns the spectate tag itself).
local function clear()
	gauge.set(0, "0")
	TweenService:Create(vignette, Theme.tween.normal, { BackgroundTransparency = 1 }):Play()
end

if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)
player.CharacterRemoving:Connect(clear)

-- The vignette must never outlive a respawn hiccup; a cheap safety net rather than a per-frame driver.
RunService.Heartbeat:Connect(function()
	if not player.Character and vignette.BackgroundTransparency < 1 then
		clear()
	end
end)
