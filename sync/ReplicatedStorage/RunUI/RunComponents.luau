--!strict
-- RunComponents.luau — builders the in-run HUD needs and the lobby doesn't (Job #075). Client-side.
--
-- Sits ON TOP of `UI/Components.luau`, never beside it: anything a shop row and a fuel gauge both need
-- (colour, corner, stroke, type rules, buttons, chips, toasts) still comes from there. This file only
-- adds shapes the lobby has no use for — a vehicle gauge, a journey progress track, a hotbar slot, a
-- thumb control. Keeping them here is what lets `UI/` stay byte-identical across the two trees.
--
-- Same construction rules as Components (they are the house style, not that file's private business):
--   · every colour via Theme, never a literal      · BorderSizePixel = 0 everywhere
--   · UICorner on rounded elements                 · UIStroke on bordered elements
--   · Parent set LAST                              · GuiButton.Activated (click AND tap)
--   · size/position by SCALE — STYLEGUIDE §6.10, mobile-first

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))

local RunComponents = {}

-- ── card (a non-modal framed box) ────────────────────────────────────────────────────────────────
-- `Components.panel` is a MODAL: it owns a ScreenGui, a scrim and a close button, and it is the right
-- answer for a shop. A HUD readout is none of those things — it is always-on, never blocks input, and
-- must never dim the game behind it. So the HUD gets its own container with the same §6.1 skin.

export type CardOptions = {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	accent: Color3?, -- border tint; wood by default
	transparency: number?,
	parent: Instance?,
}

function RunComponents.card(opts: CardOptions): Frame
	local frame = Instance.new("Frame")
	frame.Name = opts.name or "Card"
	frame.Size = opts.size or UDim2.fromScale(0.24, 0.12)
	frame.Position = opts.position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = opts.anchor or Vector2.new(0, 0)
	frame.BackgroundColor3 = Theme.color.panel
	-- Slightly transparent by default: a HUD card sits over live gameplay, and an opaque slab reads as
	-- a menu that has covered the river rather than an overlay on it.
	frame.BackgroundTransparency = opts.transparency or 0.15
	frame.BorderSizePixel = 0
	frame.Active = false -- never eats input (§6.11)
	Components.corner(Theme.radius.control, frame)
	Components.stroke(opts.accent or Theme.color.wood, Theme.strokeWidth.control, frame)
	frame.Parent = opts.parent
	return frame
end

-- ── gauge (fuel · hull · health) ─────────────────────────────────────────────────────────────────
-- Icon badge + track + fill + value, on one line. The three vitals in this game all answer the same
-- question ("how much left before something bad happens"), so they are one component — which is also
-- what guarantees fuel and hull cross into danger identically instead of drifting apart.

export type GaugeOptions = {
	icon: string, -- Theme.icon key
	color: Color3, -- fill colour in the normal band
	dangerBelow: number?, -- 0..1; below this the fill turns red and pulses
	dangerSound: string?, -- Theme.sound key, fired ONCE per crossing (not per frame)
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
	parent: Instance?,
}

export type Gauge = {
	instance: Frame,
	set: (alpha: number, text: string) -> (),
	setDimmed: (dimmed: boolean) -> (),
}

function RunComponents.gauge(opts: GaugeOptions): Gauge
	local holder = Instance.new("Frame")
	holder.Name = "Gauge_" .. opts.icon
	holder.Size = opts.size or UDim2.fromScale(1, 0.42)
	holder.Position = opts.position or UDim2.fromScale(0, 0)
	holder.AnchorPoint = opts.anchor or Vector2.new(0, 0)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.LayoutOrder = opts.layoutOrder or 0
	holder.Active = false

	local badge = Components.icon({ name = opts.icon, size = UDim2.fromScale(0.14, 1), parent = holder })
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromScale(0, 0.5)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.fromScale(1, 0.5)
	track.Size = UDim2.fromScale(0.84, 0.66)
	track.BackgroundColor3 = Theme.color.sunken
	track.BackgroundTransparency = 0.1
	track.BorderSizePixel = 0
	track.Active = false
	Components.corner(Theme.radius.pill, track)
	Components.stroke(Theme.color.woodDark, Theme.strokeWidth.hairline, track)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = opts.color
	fill.BorderSizePixel = 0
	fill.Active = false
	Components.corner(Theme.radius.pill, fill)
	fill.Parent = track

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	Components.applyText(label, Theme.text.caption, Theme.font.bodyBold)
	label.TextStrokeTransparency = 0.15 -- reads over both the dark track and the bright fill
	label.Text = ""
	label.Parent = track

	track.Parent = holder
	holder.Parent = opts.parent

	local inDanger = false
	local pulse: Tween? = nil

	local function stopPulse()
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		fill.BackgroundTransparency = 0
	end

	local function setDanger(on: boolean)
		if on == inDanger then
			return
		end
		inDanger = on
		if on then
			fill.BackgroundColor3 = Theme.color.red
			-- a slow breathing fill, not a strobe: it must be noticeable in peripheral vision while
			-- you're watching the river, without becoming the thing you look at
			pulse = TweenService:Create(
				fill,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.45 }
			)
			;(pulse :: Tween):Play()
			if opts.dangerSound then
				UISound.play(opts.dangerSound)
			end
		else
			stopPulse()
			fill.BackgroundColor3 = opts.color
		end
	end

	return {
		instance = holder,
		set = function(alpha: number, text: string)
			local a = math.clamp(alpha, 0, 1)
			TweenService:Create(fill, Theme.tween.fast, { Size = UDim2.fromScale(a, 1) }):Play()
			label.Text = text
			if opts.dangerBelow then
				setDanger(a < opts.dangerBelow)
			end
		end,
		-- State A shows the boat's vitals before they matter. Dimming says "present, not yet at stake"
		-- without removing them — you still want to see the tank you're setting off with.
		setDimmed = function(dimmed: boolean)
			holder.BackgroundTransparency = 1
			track.BackgroundTransparency = if dimmed then 0.5 else 0.1
			fill.BackgroundTransparency = if dimmed then 0.5 else 0
			label.TextTransparency = if dimmed then 0.35 else 0
			badge.BackgroundTransparency = if dimmed then 0.6 else 0
		end,
	}
end

-- ── stat chip (compact icon + number) ────────────────────────────────────────────────────────────
-- `Components.chip` is the CURRENCY chip: pill-shaped, gold number, hugs its text, sized for a top bar.
-- Cargo and ammo readouts want the same vocabulary at half the weight and in the resource's own colour,
-- so they get a smaller sibling rather than a pile of overrides on the original.

export type StatChip = { instance: Frame, setValue: (text: string) -> (), setAlert: (on: boolean) -> () }

-- `label` is optional and it is not decoration. A bare icon + number is only self-explanatory when the
-- icon is unmistakable, and ours are a sourced set that isn't in yet — the first playtest reading of the
-- bandage chip was "what is that 3?". Where there is room for a word, spend it: the fuel and hull gauges
-- already read "FUEL 95%" / "BOAT 100%", so a labelled chip matches the HUD rather than adding a style.
-- Cramped rows (the three cargo chips) pass no label and stay icon + number.
function RunComponents.statChip(iconName: string, tint: Color3, parent: Instance?, label: string?): StatChip
	local frame = Instance.new("Frame")
	frame.Name = "Stat_" .. iconName
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.color.sunken
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Active = false
	Components.corner(Theme.radius.control, frame)
	local border = Components.stroke(Theme.color.woodDark, Theme.strokeWidth.hairline, frame)

	local ico = Components.icon({ name = iconName, size = UDim2.fromScale(0.9, 0.68), chip = false, parent = frame })
	ico.AnchorPoint = Vector2.new(0, 0.5)
	ico.Position = UDim2.fromScale(0.06, 0.5)

	if label then
		local caption = Instance.new("TextLabel")
		caption.Name = "Label"
		caption.AnchorPoint = Vector2.new(0, 0.5)
		caption.Position = UDim2.fromScale(0.26, 0.5)
		caption.Size = UDim2.fromScale(0.46, 0.6)
		caption.TextXAlignment = Enum.TextXAlignment.Left
		Components.applyText(caption, Theme.text.caption, Theme.font.button)
		caption.TextColor3 = Theme.color.creamDim
		caption.Text = string.upper(label)
		caption.Parent = frame
	end

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.fromScale(0.94, 0.5)
	-- a labelled chip gives the number the right-hand third; an unlabelled one lets it use the whole width
	value.Size = UDim2.fromScale(if label then 0.24 else 0.58, 0.62)
	value.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(value, Theme.text.body, Theme.font.bodyBold)
	value.TextColor3 = tint
	value.Text = "0"
	value.Parent = frame

	frame.Parent = parent

	return {
		instance = frame,
		setValue = function(text: string)
			value.Text = text
		end,
		setAlert = function(on: boolean)
			border.Color = if on then Theme.color.red else Theme.color.woodDark
			value.TextColor3 = if on then Theme.color.red else tint
		end,
	}
end

-- ── river progress bar ───────────────────────────────────────────────────────────────────────────
-- The journey, as one line: how far down the river you are, which zone you're in, where the next fuel
-- landing sits, and where it ends. This replaces a bare "NEXT FUEL 1234 studs" text readout — the
-- number was accurate and told you nothing about whether stopping was a good idea.

export type RiverBar = {
	instance: Frame,
	set: (alpha: number, zone: number, zoneName: string) -> (),
	setDock: (alpha: number?, reachable: boolean) -> (),
}

function RunComponents.riverBar(zoneCount: number, parent: Instance?): RiverBar
	local holder = Instance.new("Frame")
	holder.Name = "RiverBar"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Active = false

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.1)
	track.Size = UDim2.fromScale(1, 0.34)
	track.BackgroundColor3 = Theme.color.sunken
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Active = false
	Components.corner(Theme.radius.pill, track)
	Components.stroke(Theme.color.woodDark, Theme.strokeWidth.hairline, track)

	local travelled = Instance.new("Frame")
	travelled.Name = "Travelled"
	travelled.Size = UDim2.fromScale(0, 1)
	travelled.BackgroundColor3 = Theme.color.palmLeaf
	travelled.BackgroundTransparency = 0.35
	travelled.BorderSizePixel = 0
	travelled.Active = false
	Components.corner(Theme.radius.pill, travelled)
	travelled.Parent = track

	-- zone dividers: COUNT-1 hairlines at the even fractions ZoneDefs.zoneFor uses
	for i = 1, zoneCount - 1 do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. i
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(i / zoneCount, 0.5)
		tick.Size = UDim2.new(0, 2, 0.7, 0)
		tick.BackgroundColor3 = Theme.color.woodDark
		tick.BorderSizePixel = 0
		tick.Active = false
		tick.ZIndex = 2
		tick.Parent = track
	end

	-- the END flag, pinned to the right end of the track
	local endFlag = Components.icon({ name = "flag", size = UDim2.fromScale(0.05, 1.9), parent = track })
	endFlag.Name = "EndFlag"
	endFlag.AnchorPoint = Vector2.new(0.5, 0.5)
	endFlag.Position = UDim2.fromScale(1, 0.5)
	endFlag.ZIndex = 3

	-- next fuel landing
	local dockPin = Components.icon({ name = "pin", size = UDim2.fromScale(0.045, 1.6), parent = track })
	dockPin.Name = "DockPin"
	dockPin.AnchorPoint = Vector2.new(0.5, 0.5)
	dockPin.ZIndex = 3
	dockPin.Visible = false
	local dockStroke = dockPin:FindFirstChildOfClass("UIStroke")

	-- you
	local boatMark = Components.icon({ name = "boat", size = UDim2.fromScale(0.055, 2.1), parent = track })
	boatMark.Name = "Boat"
	boatMark.AnchorPoint = Vector2.new(0.5, 0.5)
	boatMark.Position = UDim2.fromScale(0, 0.5)
	boatMark.ZIndex = 4

	track.Parent = holder

	local caption = Instance.new("TextLabel")
	caption.Name = "Zone"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.fromScale(0.5, 1)
	caption.Size = UDim2.fromScale(1, 0.4)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	Components.applyText(caption, Theme.text.caption, Theme.font.button)
	caption.TextColor3 = Theme.color.creamDim
	caption.Text = ""
	caption.Parent = holder

	holder.Parent = parent

	return {
		instance = holder,
		set = function(alpha: number, zone: number, zoneName: string)
			local a = math.clamp(alpha, 0, 1)
			travelled.Size = UDim2.fromScale(a, 1)
			TweenService:Create(boatMark, Theme.tween.fast, { Position = UDim2.fromScale(a, 0.5) }):Play()
			caption.Text = ("ZONE %d/%d · %s"):format(zone, zoneCount, string.upper(zoneName))
		end,
		-- `reachable` is the whole point of drawing the pin: a full tank that cannot make the next
		-- landing turns it red, which is the "conserve or be stranded" call the run is built around.
		setDock = function(alpha: number?, reachable: boolean)
			if not alpha then
				dockPin.Visible = false
				return
			end
			dockPin.Visible = true
			dockPin.Position = UDim2.fromScale(math.clamp(alpha, 0, 1), 0.5)
			if dockStroke then
				dockStroke.Color = if reachable then Theme.color.gold else Theme.color.red
			end
		end,
	}
end

-- ── role chip ────────────────────────────────────────────────────────────────────────────────────
-- RoleServer has granted station bonuses since Job #034 and nothing has ever told the player they are
-- getting one. This is that missing feedback: it appears when you man a station and states the bonus.

export type RoleChip = { instance: Frame, show: (icon: string, role: string, bonus: string) -> (), hide: () -> () }

function RunComponents.roleChip(parent: Instance?): RoleChip
	local card = RunComponents.card({
		name = "RoleChip",
		size = UDim2.fromScale(0.16, 0.1),
		accent = Theme.color.green, -- green = the bonus is live
		parent = parent,
	})
	card.Visible = false

	-- 3.2, not 2.6: measured in the Job #075 playtest, "+15% turn authority" overflowed the card at 2.6
	-- and spilled past the right edge. The bonus string is the widest thing the chip ever holds, so the
	-- ratio is set by it rather than by the role name.
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 3.2
	ratio.Parent = card

	local ico = Components.icon({ name = "wheel", size = UDim2.fromScale(0.2, 0.6), parent = card })
	ico.AnchorPoint = Vector2.new(0, 0.5)
	ico.Position = UDim2.fromScale(0.05, 0.5)

	local role = Instance.new("TextLabel")
	role.Name = "Role"
	role.Position = UDim2.fromScale(0.29, 0.14)
	role.Size = UDim2.fromScale(0.66, 0.38)
	role.TextXAlignment = Enum.TextXAlignment.Left
	-- h2, not caption. Measured in Studio: at caption scale the label capped at 14 px inside a 76 px-tall
	-- card and read as a footnote rather than as "this is your station". The width was never the problem —
	-- "DRIVER" measured 44 px in a 160 px box — so the fix is the type scale, not the box.
	Components.applyText(role, Theme.text.h2, Theme.font.heading)
	role.Text = ""
	role.Parent = card

	local bonus = Instance.new("TextLabel")
	bonus.Name = "Bonus"
	bonus.Position = UDim2.fromScale(0.29, 0.52)
	bonus.Size = UDim2.fromScale(0.66, 0.34)
	bonus.TextXAlignment = Enum.TextXAlignment.Left
	-- TextWrapped off: the bonus is one short phrase and wrapping it to two lines inside a 34%-tall box
	-- shrinks it below the legibility floor rather than fitting it. Body scale for the same reason the
	-- role name is h2 — "+15% turn authority" at 12 px is a footnote nobody reads.
	Components.applyText(bonus, Theme.text.body, Theme.font.body)
	bonus.TextWrapped = false
	bonus.TextColor3 = Theme.color.green
	bonus.Text = ""
	bonus.Parent = card

	local scale = Instance.new("UIScale")
	scale.Parent = card

	return {
		instance = card,
		show = function(iconName: string, roleName: string, bonusText: string)
			local image = ico:FindFirstChild("Image") :: ImageLabel?
			if image then
				image.Image = Components.iconId(iconName)
			end
			role.Text = string.upper(roleName)
			bonus.Text = bonusText
			if not card.Visible then
				card.Visible = true
				scale.Scale = 0.8
				TweenService:Create(scale, Theme.tween.pop, { Scale = 1 }):Play()
				UISound.play("upgrade")
			end
		end,
		hide = function()
			card.Visible = false
		end,
	}
end

-- ── hotbar slot ──────────────────────────────────────────────────────────────────────────────────

export type Slot = {
	instance: TextButton,
	set: (iconKey: string?, label: string, ammo: string, active: boolean) -> (),
	setVisible: (visible: boolean) -> (),
}

function RunComponents.slot(index: number, onActivated: () -> (), parent: Instance?): Slot
	local btn = Instance.new("TextButton")
	btn.Name = "Slot" .. index
	btn.Size = UDim2.fromScale(0.2, 1)
	btn.BackgroundColor3 = Theme.color.panel
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.LayoutOrder = index
	Components.corner(Theme.radius.control, btn)
	local border = Components.stroke(Theme.color.woodDark, Theme.strokeWidth.control, btn)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = btn

	-- thumb-sized floor, same rule as Components.button
	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(44, 44)
	floor.Parent = btn

	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.46)
	art.Size = UDim2.fromScale(0.58, 0.58)
	art.BackgroundTransparency = 1
	art.BorderSizePixel = 0
	art.ScaleType = Enum.ScaleType.Fit
	art.Image = ""
	art.Parent = btn

	-- the slot number, so keyboard players can map 1-N at a glance
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Position = UDim2.fromScale(0.06, 0.04)
	key.Size = UDim2.fromScale(0.3, 0.24)
	key.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(key, Theme.text.caption, Theme.font.body)
	key.TextColor3 = Theme.color.creamDim
	key.Text = tostring(index)
	key.Parent = btn

	local name = Instance.new("TextLabel")
	name.Name = "Label"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.99)
	name.Size = UDim2.fromScale(0.94, 0.22)
	name.TextXAlignment = Enum.TextXAlignment.Center
	Components.applyText(name, Theme.text.caption, Theme.font.button)
	name.Text = ""
	name.Parent = btn

	local ammo = Instance.new("TextLabel")
	ammo.Name = "Ammo"
	ammo.AnchorPoint = Vector2.new(1, 0)
	ammo.Position = UDim2.fromScale(0.94, 0.04)
	ammo.Size = UDim2.fromScale(0.44, 0.24)
	ammo.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(ammo, Theme.text.caption, Theme.font.bodyBold)
	ammo.TextColor3 = Theme.color.gold
	ammo.Text = ""
	ammo.Parent = btn

	local scale = Instance.new("UIScale")
	scale.Parent = btn

	btn.Activated:Connect(function()
		UISound.play("click")
		TweenService:Create(scale, Theme.tween.fast, { Scale = 0.94 }):Play()
		task.delay(0.09, function()
			TweenService:Create(scale, Theme.tween.fast, { Scale = 1 }):Play()
		end)
		onActivated()
	end)

	btn.Parent = parent

	return {
		instance = btn,
		set = function(iconKey: string?, label: string, ammoText: string, active: boolean)
			art.Image = if iconKey then Components.iconId(iconKey) else ""
			art.ImageTransparency = if iconKey then 0 else 1
			name.Text = label
			ammo.Text = ammoText
			-- the equipped slot is the one thing on the bar that must be unmistakable mid-fight
			btn.BackgroundColor3 = if active then Theme.color.jungleMain else Theme.color.panel
			btn.BackgroundTransparency = if active then 0 else 0.15
			border.Color = if active then Theme.color.gold else Theme.color.woodDark
			border.Thickness = if active then Theme.strokeWidth.panel else Theme.strokeWidth.control
		end,
		setVisible = function(visible: boolean)
			btn.Visible = visible
		end,
	}
end

-- ── touch control button ─────────────────────────────────────────────────────────────────────────
-- A hold-to-act thumb button for the driver. Deliberately translucent and unlabelled beyond a glyph:
-- it sits over the river for the whole run, so it has to be findable without looking and invisible to
-- attention when not in use.
--
-- ⚠️ `layoutOrder` IS NOT OPTIONAL IN PRACTICE — pass it whenever two of these share a UIListLayout,
-- and set `SortOrder = Enum.SortOrder.LayoutOrder` on that layout (Job #094). The button's Name is
-- derived from its GLYPH, and `UIListLayout.SortOrder` DEFAULTS TO `Name` — so a pair left to the
-- default is ordered by the Unicode codepoints of its arrows, not by the order it was built in. That
-- is not a hypothetical: it shipped. The steer pair rendered ▶ before ◀ (U+25B6 sorts before U+25C0),
-- so the left-turn button sat on the right and the boat turned the wrong way on every phone. The
-- throttle pair was correct only by luck (U+25B2 sorts before U+25BC). Never rely on the name.
--
-- ── Input: per-InputObject, NOT MouseButton1 (Job #094) ───────────────────────────────────────────
-- These were `MouseButton1Down`/`Up`/`MouseLeave`. Roblox routes only the FIRST active touch through
-- mouse emulation, so a driver holding throttle could not also press steer — the second thumb had no
-- event to fire, which is precisely the input the game is built around. `InputBegan`/`InputEnded`
-- deliver a distinct InputObject per finger, so two buttons can be held at once. We remember WHICH
-- object claimed the button so a second finger landing on an already-held button can't steal it, and
-- the release only counts when that same object ends.

export type TouchButton = { instance: TextButton, setActive: (on: boolean) -> () }

function RunComponents.touchButton(
	glyph: string,
	onDown: () -> (),
	onUp: () -> (),
	parent: Instance?,
	layoutOrder: number?
): TouchButton
	local btn = Instance.new("TextButton")
	btn.Name = "Touch_" .. glyph
	btn.LayoutOrder = layoutOrder or 0
	btn.Size = UDim2.fromScale(0.48, 1)
	btn.BackgroundColor3 = Theme.color.panel
	btn.BackgroundTransparency = 0.42
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = glyph
	Components.applyText(btn, Theme.text.h1, Theme.font.heading)
	btn.BackgroundTransparency = 0.42
	btn.TextTransparency = 0.15
	Components.corner(Theme.radius.control, btn)
	local border = Components.stroke(Theme.color.wood, Theme.strokeWidth.control, btn)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = btn

	-- thumbs, not cursors: this floor is larger than the 44px control minimum on purpose
	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(58, 58)
	floor.Parent = btn

	-- The InputObject currently holding this button down. Tracked (rather than a bare boolean) so that
	-- a second finger landing on an already-held button cannot claim it, and so a release is only
	-- honoured for the finger that actually pressed it.
	local owner: InputObject? = nil

	local held = false
	local function press()
		if held then
			return
		end
		held = true
		btn.BackgroundColor3 = Theme.color.green
		btn.BackgroundTransparency = 0.15
		border.Color = Theme.color.gold
		onDown()
	end
	-- Clearing `owner` here is load-bearing, not tidiness: `makePair` releases the opposite button via
	-- `setActive(false)` while its finger may still be physically down. If that left an owner behind,
	-- the button would refuse every future press until that long-gone finger happened to lift — a
	-- rudder that dies mid-bend and never comes back.
	local function release()
		owner = nil
		if not held then
			return
		end
		held = false
		btn.BackgroundColor3 = Theme.color.panel
		btn.BackgroundTransparency = 0.42
		border.Color = Theme.color.wood
		onUp()
	end

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
	end

	btn.InputBegan:Connect(function(input: InputObject)
		if owner or not isPress(input) then
			return
		end
		owner = input
		press()
	end)

	btn.InputEnded:Connect(function(input: InputObject)
		if owner == input then
			release()
		end
	end)

	-- A finger that slides OFF the button before lifting ends its input somewhere else entirely, so the
	-- button's own InputEnded never fires and the throttle would stay latched with nothing holding it.
	-- (This is the failure the old `MouseLeave` guard was reaching for; on touch, MouseLeave is not
	-- reliable enough to be that guard.) Watching the service-level end closes it for good.
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if owner == input then
			release()
		end
	end)

	btn.Parent = parent

	return {
		instance = btn,
		setActive = function(on: boolean)
			if on then
				press()
			else
				release()
			end
		end,
	}
end

-- ── collapsible tray ─────────────────────────────────────────────────────────────────────────────
-- §6.11: heavy panels DEFAULT COLLAPSED during play and expand on tap. A header that is always a
-- summary ("OBJ 1/3") and a body that is opt-in.

export type Tray = {
	instance: Frame,
	body: Frame,
	setSummary: (text: string) -> (),
	setExpanded: (expanded: boolean) -> (),
	isExpanded: () -> boolean,
}

export type TrayOptions = {
	name: string,
	icon: string,
	collapsedSize: UDim2,
	expandedSize: UDim2,
	position: UDim2,
	anchor: Vector2?,
	parent: Instance?,
}

function RunComponents.tray(opts: TrayOptions): Tray
	local card = RunComponents.card({
		name = opts.name,
		size = opts.collapsedSize,
		position = opts.position,
		anchor = opts.anchor or Vector2.new(1, 0),
		parent = opts.parent,
	})

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 1) -- re-sized on expand so the body gets the rest
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.AutoButtonColor = false
	header.Text = ""
	header.Parent = card

	local ico = Components.icon({ name = opts.icon, size = UDim2.fromScale(0.16, 0.62), chip = false, parent = header })
	ico.AnchorPoint = Vector2.new(0, 0.5)
	ico.Position = UDim2.fromScale(0.04, 0.5)

	local summary = Instance.new("TextLabel")
	summary.Name = "Summary"
	summary.AnchorPoint = Vector2.new(0, 0.5)
	summary.Position = UDim2.fromScale(0.24, 0.5)
	summary.Size = UDim2.fromScale(0.58, 0.6)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(summary, Theme.text.caption, Theme.font.button)
	summary.Text = ""
	summary.Parent = header

	-- the affordance §6.11 asks for: which way this thing is about to move
	local chevron = Instance.new("TextLabel")
	chevron.Name = "Chevron"
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.fromScale(0.95, 0.5)
	chevron.Size = UDim2.fromScale(0.14, 0.6)
	chevron.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(chevron, Theme.text.caption, Theme.font.bodyBold)
	chevron.TextColor3 = Theme.color.creamDim
	chevron.Text = "▾"
	chevron.Parent = header

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromScale(0, 0)
	body.Size = UDim2.fromScale(1, 0)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Visible = false
	body.ClipsDescendants = true
	Components.padding(Theme.space.sm, body)
	body.Parent = card

	local expanded = false
	local headerScale = 1

	local function apply(animate: boolean)
		local size = if expanded then opts.expandedSize else opts.collapsedSize
		chevron.Text = if expanded then "▴" else "▾"
		if expanded then
			-- header keeps its collapsed height; the body takes what the card grew by
			headerScale = opts.collapsedSize.Y.Scale / math.max(opts.expandedSize.Y.Scale, 0.0001)
			header.Size = UDim2.fromScale(1, headerScale)
			body.Position = UDim2.fromScale(0, headerScale)
			body.Size = UDim2.fromScale(1, 1 - headerScale)
			body.Visible = true
		else
			header.Size = UDim2.fromScale(1, 1)
			body.Visible = false
		end
		if animate then
			TweenService:Create(card, Theme.tween.fast, { Size = size }):Play()
		else
			card.Size = size
		end
	end

	local function setExpanded(value: boolean)
		if expanded == value then
			return
		end
		expanded = value
		UISound.play(if value then "open" else "close")
		apply(true)
	end

	header.Activated:Connect(function()
		setExpanded(not expanded)
	end)

	apply(false)

	return {
		instance = card,
		body = body,
		setSummary = function(text: string)
			summary.Text = text
		end,
		setExpanded = setExpanded,
		isExpanded = function()
			return expanded
		end,
	}
end

return RunComponents
