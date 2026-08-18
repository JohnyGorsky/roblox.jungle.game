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
local UserInputService = game:GetService("UserInputService")

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
-- Job #099: on touch this whole bar moves to the EMPTY top-left instead, joining the boat vitals as one
-- glanceable column. See the note above reflowForSeat.
if UserInputService.TouchEnabled then
	holder.AnchorPoint = Vector2.new(0, 0)
	holder.Position = UDim2.fromScale(0.015, 0.02) -- row 1 of the touch column
end
-- Wider than the bar alone needs: the bandage chip beside it carries a word now, not just a number.
holder.Size = UDim2.fromScale(0.27, 0.042)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false

local sizeClamp = Instance.new("UISizeConstraint")
sizeClamp.MinSize = Vector2.new(215, 26)
sizeClamp.MaxSize = Vector2.new(450, 46)
sizeClamp.Parent = holder

holder.Parent = gui

local gauge = RunComponents.gauge({
	icon = "heart",
	color = Theme.color.green,
	dangerBelow = DANGER,
	size = UDim2.fromScale(0.61, 1),
	parent = holder,
})

-- Bandages sit with health because they are the same fact from two sides: what you have left, and what
-- you can do about it. They are also the ONE resource with no hotbar slot to report them — bandages are
-- a player attribute consumed by the revive hold, not an equippable — so without this chip the number
-- that decides whether you can pick a teammate up is invisible. (Gun ammo deliberately is NOT duplicated
-- here; the hotbar slot already carries it, and §6.11 does not permit saying the same thing twice.)
-- Labelled, because "3" next to an icon we haven't sourced yet told the first playtester nothing.
-- Job #099: no word on touch. The label exists because an unlabelled icon confused a playtester — but
-- that was about a MISSING icon, and in the compact touch column the word does not fit: it rendered as
-- "BANDA", truncated mid-word, which teaches less than no label at all. Icon + number on a phone, the
-- full word where there is room for it.
local bandages = RunComponents.statChip(
	"bandage",
	Theme.color.cream,
	holder,
	if UserInputService.TouchEnabled then nil else "Bandages"
)
bandages.instance.AnchorPoint = Vector2.new(1, 0.5)
bandages.instance.Position = UDim2.fromScale(1, 0.5)
bandages.instance.Size = UDim2.fromScale(0.37, 1)

local function renderBandages()
	local n = (player:GetAttribute("Bandages") :: number?) or 0
	bandages.setValue(tostring(n))
	bandages.setAlert(n <= 0)
end
player:GetAttributeChangedSignal("Bandages"):Connect(renderBandages)
renderBandages()

-- ── drive it from the character ──────────────────────────────────────────────────────────────────

local lastFraction = 1

local function setVignette(fraction: number)
	-- ramps from invisible at DANGER to a firm wash at zero, so it grows with the danger rather than
	-- snapping on at a threshold
	local target = if fraction >= DANGER then 1 else 0.72 + 0.28 * (fraction / DANGER)
	TweenService:Create(vignette, Theme.tween.normal, { BackgroundTransparency = target }):Play()
end

-- ⚠️ PLAYER HEALTH IS THE CHARACTER ATTRIBUTE `HP`, NOT `Humanoid.Health`.
--
-- This is the bug the first version shipped with, and it made the bar useless: it read
-- `Humanoid.Health`, which `PlayerCombat` only ever touches at the very end
-- (`hum.Health = 0` on bleed-out, :190). All actual damage, the downed state and every heal go through
-- `char:SetAttribute("HP", …)` — `PlayerCombat` :92-129, and `RoleServer`'s medic regen reads the same
-- attribute. So the bar sat at a constant HEALTH 100 no matter what hit you, right up to the moment you
-- died. Reported from a playtest: "health bar is not working, even if i am hit".
--
-- The Humanoid is kept only as a FALLBACK, for any context where `HP` hasn't been published yet (the
-- attributes are set on spawn, so there is a brief window, and the lobby has no PlayerCombat at all).
-- ── touch: stay clear of the steer buttons (Job #094) ────────────────────────────────────────────
-- On a phone the boat's steer pair occupies the bottom-left corner (x 0.02–0.21, y 0.80–0.96), and this
-- bar sits at y 0.803–0.845 — straight underneath them. Measured, not assumed: the overlap detector
-- reported HealthHud ↔ BoatTouchControls at every landscape resolution swept, 78x17 px at the smallest.
--
-- It moves RIGHT rather than up because the left column above is already fully allocated — the
-- HandsFull card owns 0.761–0.797 and its drop hint 0.733–0.756 (see InventoryHud) — so raising this
-- bar would only trade one collision for another.
--
-- It reflows on SEAT CHANGE rather than sitting permanently offset, because that is the same instant
-- the hotbar vacates the corner: the column already reshapes itself there, so the bar moving with it
-- reads as one layout rather than as a jump. A keyboard player never enters this branch at all.
local _DRIVING_X = 0.225 -- kept only so the Job #094 note above still reads against real values
local _RESTING_X = 0.015

-- ⚠️ SUPERSEDED by Job #099 and deliberately left as a no-op rather than deleted, so the reasoning
-- survives. Job #094 slid this bar sideways while driving to dodge the steer buttons. Job #099 moved it
-- to the top-left on touch outright — which dodges the steer buttons AND the movement thumbstick AND
-- the hotbar, in every state, without anything moving on screen mid-run. A HUD element that relocates
-- when you sit down was always the weaker answer; it only looked reasonable while the bottom-left was
-- assumed to be ours.
local function reflowForSeat(_humanoid: Humanoid?) end

local conns: { RBXScriptConnection } = {}

local function watch(char: Model)
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	lastFraction = 1

	local humanoid = char:FindFirstChildOfClass("Humanoid")

	local function render()
		local hp = char:GetAttribute("HP") :: number?
		local maxHp = char:GetAttribute("MaxHP") :: number?

		local current, max
		if hp and maxHp and maxHp > 0 then
			current, max = hp, maxHp
		elseif humanoid and humanoid.MaxHealth > 0 then
			current, max = humanoid.Health, humanoid.MaxHealth -- fallback, pre-spawn / lobby
		else
			return
		end

		local fraction = math.clamp(current / max, 0, 1)
		-- "HEALTH 100", not "100". The fuel and hull gauges directly below read "FUEL 95%" and
		-- "BOAT 100%", so a bare number here was the odd one out AND the ambiguous one.
		gauge.set(fraction, ("HEALTH  %d"):format(math.max(0, math.ceil(current))))
		setVignette(fraction)

		-- One cue per hit, on the falling edge only — this fires for healing too, and a grunt while a
		-- medic is patching you up would be nonsense.
		if fraction < lastFraction - 0.001 then
			UISound.play("hurt")
		end
		lastFraction = fraction
	end

	table.insert(conns, char:GetAttributeChangedSignal("HP"):Connect(render))
	table.insert(conns, char:GetAttributeChangedSignal("MaxHP"):Connect(render))
	if humanoid then
		table.insert(conns, humanoid.HealthChanged:Connect(render))
		table.insert(conns, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			reflowForSeat(humanoid)
		end))
	end
	reflowForSeat(humanoid)
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
