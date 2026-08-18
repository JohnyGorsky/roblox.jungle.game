--!strict
-- TouchControls.local.luau — purpose-built touch driving for the boat (Job #075).
--
-- Closes P1's outstanding success criterion. Until now the boat drove on the `VehicleSeat`'s DEFAULT
-- mobile controls: functional on a phone, but not ours, not scale-based, and not styled.
--
-- ── The open question in Planned/mobile-boat-controls.md: "buttons vs a virtual joystick?" ─────────
-- BUTTONS. `VehicleSeat.Steer` is `-1 | 0 | 1` (see roblox-physics §8 — Throttle/Steer are tri-state),
-- so a joystick's analogue precision quantises to the same three values a button pair produces, while
-- being materially harder to hit: a joystick needs the thumb to find and hold a floating origin, and the
-- driver is watching the river, not their hands. Fixed, large, always-in-the-same-place wins here.
--
-- ── How the input reaches the boat ────────────────────────────────────────────────────────────────
-- We write `SteerFloat` / `ThrottleFloat` on the seat, which is what the default controls do and what
-- `BoatServer` reads (`seat.Throttle` / `seat.Steer`, :327-328). Two consequences worth knowing:
--
--   1. **They auto-reset to 0 every frame** (roblox-physics §8), so a held button has to re-assert its
--      value continuously — this is a per-frame write, not an on-press one.
--   2. The default control module writes them too, from the keyboard. We bind at a LATE render
--      priority so our value is the one standing at the end of the frame; a PC player who never
--      touches these buttons writes 0 here and keeps their keys, because we only write while held.
--
-- No new remote: this drives the same replicated seat properties the keyboard does, so server authority
-- is exactly as it was.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local BIND = "BoatTouchDrive"

local player = Players.LocalPlayer

-- Nothing is built at all on a device that can't touch. A keyboard player should not pay for this
-- script beyond the one branch below.
if not UserInputService.TouchEnabled then
	return
end

local gui = Components.screen("BoatTouchControls", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 9

-- ── steer, bottom-left ───────────────────────────────────────────────────────────────────────────
-- The hotbar normally lives here, and hides itself while you're in a control seat (InventoryHud) —
-- precisely so this can have the left thumb.
local steerHolder = Instance.new("Frame")
steerHolder.Name = "Steer"
steerHolder.AnchorPoint = Vector2.new(0, 1)
steerHolder.Position = UDim2.fromScale(0.02, 0.96)
steerHolder.Size = UDim2.fromScale(0.19, 0.16)
steerHolder.BackgroundTransparency = 1
steerHolder.BorderSizePixel = 0
steerHolder.Parent = gui

local steerLayout = Instance.new("UIListLayout")
steerLayout.FillDirection = Enum.FillDirection.Horizontal
steerLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
steerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
-- ⚠️ REQUIRED (Job #094). SortOrder DEFAULTS TO `Name`, and these buttons are named from their glyph
-- — so left to the default the pair is ordered by Unicode codepoint. `Touch_▶` (U+25B6) sorts before
-- `Touch_◀` (U+25C0), which put the RIGHT-turn button on the LEFT and made the boat turn the wrong way
-- on every phone. Measured, not guessed: the left-arrow landed at x=227 and the right-arrow at x=39.
-- Every other layout in this game already sets this; these two were the only ones that didn't.
steerLayout.SortOrder = Enum.SortOrder.LayoutOrder
steerLayout.Padding = UDim.new(0, Theme.space.sm)
steerLayout.Parent = steerHolder

-- ── throttle, bottom-right ───────────────────────────────────────────────────────────────────────
local throttleHolder = Instance.new("Frame")
throttleHolder.Name = "Throttle"
throttleHolder.AnchorPoint = Vector2.new(1, 1)
throttleHolder.Position = UDim2.fromScale(0.98, 0.96)
throttleHolder.Size = UDim2.fromScale(0.19, 0.16)
throttleHolder.BackgroundTransparency = 1
throttleHolder.BorderSizePixel = 0
throttleHolder.Parent = gui

local throttleLayout = Instance.new("UIListLayout")
throttleLayout.FillDirection = Enum.FillDirection.Horizontal
throttleLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
throttleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
-- Same reason as the steer layout above. This pair was correct only by ACCIDENT — `▲` (U+25B2) happens
-- to sort before `▼` (U+25BC) — so it would have broken silently the day anyone changed a glyph.
throttleLayout.SortOrder = Enum.SortOrder.LayoutOrder
throttleLayout.Padding = UDim.new(0, Theme.space.sm)
throttleLayout.Parent = throttleHolder

-- ── the four buttons ─────────────────────────────────────────────────────────────────────────────

local steer = 0
local throttle = 0

-- Each pair is mutually exclusive: pressing one releases the other first, so a thumb rolling from ◀ to
-- ▶ never leaves both held — which would otherwise cancel to a dead rudder mid-bend.
local function makePair(holder: Instance, first: { glyph: string, value: number }, second: { glyph: string, value: number }, set: (value: number) -> ())
	local a: RunComponents.TouchButton, b: RunComponents.TouchButton

	-- The trailing 1 and 2 are the LayoutOrder, and they are the whole fix for the inverted steering:
	-- `first` must render left of `second`, and without an explicit order the glyphs' codepoints decide
	-- it instead. Paired with SortOrder = LayoutOrder on the holder's layout above — neither half works
	-- alone.
	a = RunComponents.touchButton(first.glyph, function()
		if b then
			b.setActive(false) -- fires b's onUp → set(0); the set(first.value) below then wins
		end
		set(first.value)
	end, function()
		set(0)
	end, holder, 1)

	b = RunComponents.touchButton(second.glyph, function()
		a.setActive(false)
		set(second.value)
	end, function()
		set(0)
	end, holder, 2)
end

makePair(steerHolder, { glyph = "◀", value = -1 }, { glyph = "▶", value = 1 }, function(v)
	steer = v
end)

-- Forward is the LEFT button of the throttle pair: it's the one held for minutes at a stretch, so it
-- gets the spot the thumb rests on, and reverse — used in short corrective taps — gets the reach.
makePair(throttleHolder, { glyph = "▲", value = 1 }, { glyph = "▼", value = -1 }, function(v)
	throttle = v
end)

-- ── drive the seat ───────────────────────────────────────────────────────────────────────────────

local function driverSeat(): VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		return seat
	end
	return nil
end

-- Enum.RenderPriority.Input is where the default control module runs; +1 puts our write after it, so
-- the value the physics step sees is ours whenever a button is held.
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Input.Value + 1, function()
	local seat = driverSeat()
	local driving = seat ~= nil

	steerHolder.Visible = driving
	throttleHolder.Visible = driving

	if not seat then
		-- leaving the seat mid-hold must not strand a value
		steer, throttle = 0, 0
		return
	end
	if steer ~= 0 then
		seat.SteerFloat = steer
	end
	if throttle ~= 0 then
		seat.ThrottleFloat = throttle
	end
end)
