--!strict
-- Components.luau — the lobby's reusable GUI builders (Job 065). Client-side.
--
-- Consumes Theme and returns instances. Owns NO game logic — a component never talks to a remote,
-- never reads a profile, never decides whether a purchase is allowed. Screens wire behaviour in.
--
-- Construction rules held throughout (game-agnostic):
--   · every colour via Theme, never a literal      · BorderSizePixel = 0 everywhere
--   · UICorner on rounded elements                 · UIStroke on bordered elements
--   · Parent set LAST, after all other properties  · GuiButton.Activated (fires for click AND tap)
--   · size/position by SCALE (offset only for hairlines/padding) — STYLEGUIDE §6.10, mobile-first
--
-- Sound is paired at the call site via UISound; see the juice rule (STYLEGUIDE §12).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local InputMode = require(script.Parent:WaitForChild("InputMode"))
local UISound = require(UI:WaitForChild("UISound"))

local Components = {}

-- ── low-level helpers ─────────────────────────────────────────────────────────────────────────────

local function corner(radius: number, parent: Instance): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(color: Color3, thickness: number, parent: Instance): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function padding(all: number, parent: Instance): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
	return p
end

Components.corner = corner
Components.stroke = stroke
Components.padding = padding

-- Apply the §5 type rules to any text object: TextScaled + a size clamp + cream + dark stroke.
-- `target` is widened to any because Luau won't let you assign through a `TextLabel | TextButton`
-- union — both classes carry these properties, but the union type itself exposes none of them.
function Components.applyText(target: GuiObject, size: Theme.TextSize, font: Enum.Font?)
	local label = target :: any
	label.Font = font or Theme.font.body
	label.TextColor3 = Theme.color.cream
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeColor3 = Theme.color.stroke
	label.TextStrokeTransparency = 0.6
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0

	local clamp = Instance.new("UITextSizeConstraint")
	clamp.MaxTextSize = size.max
	clamp.MinTextSize = size.min
	clamp.Parent = target
end

-- A ScreenGui set up for interactive UI: safe-area aware, survives respawn.
function Components.screen(name: string, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- keep interactive UI clear of notches and the Roblox topbar (roblox-ui rule 4)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = parent
	return gui
end

-- ── icon ──────────────────────────────────────────────────────────────────────────────────────────
-- The icon set is full-colour, so it is NOT tinted (ImageColor3 multiplies and muddies it). It sits on
-- a dark sunken chip instead, which is what makes a bright icon read as deliberate. (ASSETS.md §1.9)

-- Resolve a Theme.icon key to an asset id, substituting `Theme.iconFallback` when the real art hasn't
-- been uploaded yet (Job #075). Exposed because a few call sites set `ImageLabel.Image` directly
-- (ImageButtons, billboards) and must not bypass the fallback and render an empty square.
function Components.iconId(name: string): string
	local id = (Theme.icon :: { [string]: string })[name]
	if id and id ~= "" then
		return id
	end
	local substitute = (Theme.iconFallback :: { [string]: string })[name]
	if substitute then
		return (Theme.icon :: { [string]: string })[substitute] or ""
	end
	return ""
end

export type IconOptions = {
	name: string?, -- a Theme.icon key
	image: string?, -- or a raw rbxassetid (e.g. Theme.productIcon store art)
	size: UDim2?,
	chip: boolean?, -- default true
	round: boolean?, -- circular badge with a gold ring (used for row art that breaks out of the row)
	layoutOrder: number?,
	parent: Instance?,
}

function Components.icon(opts: IconOptions): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon_" .. (opts.name or "image")
	holder.Size = opts.size or UDim2.fromScale(0.12, 0.7)
	holder.BackgroundColor3 = Theme.color.sunken
	holder.BackgroundTransparency = (opts.chip == false) and 1 or 0.15
	holder.BorderSizePixel = 0
	holder.LayoutOrder = opts.layoutOrder or 0

	-- Icons are CIRCULAR BADGES everywhere by default — title bars, rows, anywhere a chip is drawn — so
	-- the set reads as one system. `round = false` opts a chip back to a rounded rectangle;
	-- `chip = false` drops the backing entirely (used for icons sitting inside a button).
	if opts.chip ~= false then
		local isRound = opts.round ~= false
		corner(isRound and Theme.radius.pill or Theme.radius.control, holder)
		if isRound then
			stroke(Theme.color.gold, Theme.strokeWidth.control, holder)
			holder.BackgroundTransparency = 0
		end
	end

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Size = UDim2.fromScale(0.78, 0.78)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = opts.image or (opts.name and Components.iconId(opts.name)) or ""
	image.Parent = holder

	holder.Parent = opts.parent
	return holder
end

-- ── button (STYLEGUIDE §6.2 — 4 variants, 4 states) ───────────────────────────────────────────────

local VARIANT: { [string]: Color3 } = {
	primary = Theme.color.green,
	secondary = Theme.color.blue,
	gold = Theme.color.gold,
	danger = Theme.color.red,
	-- Job #099: a DARK button, not a coloured slab. The four variants above are solid accent fills, and
	-- the palette says an accent MEANS something — gold = progression, green = boat/mechanical. Stacked
	-- in the top-right corner, a gold `+` and a green menu button next to a dark currency chip read as
	-- three unrelated design languages, and neither colour matched what the button actually did.
	-- `chip` is the currency chip's own skin: panel fill, accent stroke, cream label. It lets a control
	-- sit in a cluster without shouting, and carries its meaning in the border instead of the fill.
	chip = Theme.color.panel,
}

export type ButtonOptions = {
	text: string,
	variant: string?, -- primary | secondary | gold | danger | chip
	strokeColor: Color3?, -- override the border tone (chip buttons carry their meaning here)
	round: boolean?, -- pill corner instead of the control radius, for circular icon buttons
	icon: string?,
	size: UDim2?,
	layoutOrder: number?,
	sound: string?, -- Theme.sound key; defaults to "click"
	parent: Instance?,
	onActivated: (() -> ())?,
}

export type Button = {
	instance: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setMuted: (muted: boolean) -> (),
	setText: (text: string) -> (),
}

function Components.button(opts: ButtonOptions): Button
	local variantColor = VARIANT[opts.variant or "primary"] or VARIANT.primary
	-- `base` is what hover/pressed/leave paint against, and `setMuted` swaps it. Callers must never
	-- write BackgroundColor3 from outside: the MouseLeave handler repaints to `base`, so an external
	-- tint looks right until the first time a cursor crosses the button and then silently reverts.
	local base = variantColor
	local enabled = true

	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. opts.text
	btn.Size = opts.size or UDim2.fromScale(1, 0.12)
	btn.BackgroundColor3 = base
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false -- we drive the states ourselves
	btn.Text = opts.text
	btn.LayoutOrder = opts.layoutOrder or 0
	Components.applyText(btn, Theme.text.button, Theme.font.button)
	btn.BackgroundTransparency = 0

	corner(if opts.round then Theme.radius.pill else Theme.radius.control, btn)
	stroke(opts.strokeColor or Theme.color.woodDark, Theme.strokeWidth.control, btn)

	-- Keep every button tappable once the panel shrinks to a phone (measured: row actions fell to 31px).
	--
	-- ⚠️ Job #095: 34 -> 58. 34 stopped buttons being ABSURD but left every shop row's action at 84x34,
	-- including the Robux rows — a third under the 58 px thumb floor this game uses for the driver's
	-- controls, on the controls that spend the player's money. Raised here, on the button's own
	-- constraint, rather than layering a second UISizeConstraint at the call site: two constraints on one
	-- object do NOT stack (only one applies), which is exactly why the first attempt at this fix silently
	-- did nothing. Rows are Theme.rowHeight (66 px), so a 58 px button still sits inside one with margin.
	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(0, 58)
	floor.Parent = btn

	-- slight scale-down on press (§6.2) without disturbing layout
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = btn

	if opts.icon then
		-- ⚠️ Job #099 — TWO layouts, because there are two kinds of button and one layout was serving both
		-- badly. The branch below is the original: a LABELLED button, where the icon is a small mark to
		-- the left of the words. Applied to an icon-ONLY square button it produced exactly what was
		-- reported — a tiny graphic shoved into the corner of a big empty box, because it kept the 32 px
		-- left padding and the 0.62 height meant for a text row.
		if opts.text == "" then
			-- Icon-only: the icon IS the button. Centred, square, and large enough to read at a glance —
			-- 0.62 of the face leaves the ring and the bevel visible without the art crowding the rim.
			local ico = Components.icon({ name = opts.icon, size = UDim2.fromScale(0.62, 0.62), chip = false })
			ico.AnchorPoint = Vector2.new(0.5, 0.5)
			ico.Position = UDim2.fromScale(0.5, 0.5)
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.Parent = ico
			ico.Parent = btn
		else
			btn.TextXAlignment = Enum.TextXAlignment.Right
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, Theme.space.xxl)
			pad.PaddingRight = UDim.new(0, Theme.space.md)
			pad.Parent = btn

			local ico = Components.icon({ name = opts.icon, size = UDim2.fromScale(0.9, 0.62), chip = false })
			ico.AnchorPoint = Vector2.new(0, 0.5)
			ico.Position = UDim2.new(0, Theme.space.sm, 0.5, 0)
			ico.Parent = btn
		end
	end

	local function paint(color: Color3, tween: TweenInfo)
		TweenService:Create(btn, tween, { BackgroundColor3 = color }):Play()
	end

	btn.MouseEnter:Connect(function()
		if enabled then
			paint(Theme.lighten(base, 0.08), Theme.tween.fast)
		end
	end)
	btn.MouseLeave:Connect(function()
		if enabled then
			paint(base, Theme.tween.fast)
			TweenService:Create(scale, Theme.tween.fast, { Scale = 1 }):Play()
		end
	end)
	btn.MouseButton1Down:Connect(function()
		if enabled then
			paint(Theme.darken(base, 0.1), Theme.tween.fast)
			TweenService:Create(scale, Theme.tween.fast, { Scale = 0.97 }):Play()
		end
	end)
	btn.MouseButton1Up:Connect(function()
		if enabled then
			TweenService:Create(scale, Theme.tween.fast, { Scale = 1 }):Play()
		end
	end)

	-- Activated fires for mouse click AND touch tap (roblox-ui rule 5)
	btn.Activated:Connect(function()
		if not enabled then
			return
		end
		UISound.play(opts.sound or "click")
		if opts.onActivated then
			opts.onActivated()
		end
	end)

	local function setEnabled(value: boolean)
		enabled = value
		if value then
			btn.BackgroundColor3 = base
			btn.BackgroundTransparency = 0
			btn.TextTransparency = 0
			btn.Active = true
		else
			-- §6.2 disabled: desaturated, transparency up
			btn.BackgroundColor3 = Theme.desaturate(base, 0.5)
			btn.BackgroundTransparency = 0.35
			btn.TextTransparency = 0.4
			btn.Active = false
		end
	end

	-- Looks unavailable, still takes the tap. For "you can't afford this yet": a shop row that goes fully
	-- disabled can no longer explain itself — `Activated` stops firing, so there is no `flashFail`, no
	-- `fail` cue, and the player is left tapping a dead button wondering what's broken. Muting keeps the
	-- explanation and still stops the button reading as the obvious next action.
	--
	-- It changes `base` rather than `BackgroundColor3` so the hover/pressed/leave handlers agree with it;
	-- setting the colour directly would survive exactly until the first MouseLeave.
	local function setMuted(muted: boolean)
		base = if muted then Theme.desaturate(variantColor, 0.65) else variantColor
		if enabled then
			btn.BackgroundColor3 = base
			btn.TextTransparency = if muted then 0.25 else 0
		end
	end

	btn.Parent = opts.parent

	return {
		instance = btn,
		setEnabled = setEnabled,
		setMuted = setMuted,
		setText = function(text: string)
			btn.Text = text
		end,
	}
end

-- ── chip (STYLEGUIDE §6.3 — the currency readout) ────────────────────────────────────────────────

export type Chip = { instance: Frame, setValue: (text: string) -> () }

-- The chip HUGS ITS CONTENT so "12" and "1,284,900" both look deliberate instead of one slab fitting
-- neither. It does that by MEASURING the text (TextBounds) and sizing itself, rather than by
-- AutomaticSize: automatic sizing does not reliably measure children sized by scale or by a
-- UIAspectRatioConstraint on the automatic axis, which collapses the icon and the whole chip with it.
--
-- Height comes from the parent by scale (mobile-first); everything horizontal is then derived from that
-- height, so the chip stays proportional on any screen while still hugging its number.
function Components.chip(iconName: string, parent: Instance?): Chip
	local PAD = Theme.space.md
	local GAP = Theme.space.sm

	local frame = Instance.new("Frame")
	frame.Name = "Chip"
	frame.Size = UDim2.new(0, 140, 1, 0) -- width recomputed by relayout(); height from the parent
	frame.BackgroundColor3 = Theme.color.sunken
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	corner(Theme.radius.pill, frame)
	stroke(Theme.color.wood, Theme.strokeWidth.control, frame)

	local ico = Components.icon({
		name = iconName,
		size = UDim2.fromOffset(24, 24), -- real size set in relayout()
		chip = false,
		parent = frame,
	})
	ico.AnchorPoint = Vector2.new(0, 0.5)
	-- both dimensions are set explicitly, so the aspect constraint is redundant and only adds a way to
	-- collapse to zero
	local icoRatio = ico:FindFirstChildOfClass("UIAspectRatioConstraint")
	if icoRatio then
		icoRatio:Destroy()
	end

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(0, 0.5)
	value.BackgroundTransparency = 1
	value.BorderSizePixel = 0
	value.Font = Theme.font.bodyBold
	value.TextColor3 = Theme.color.gold
	value.TextStrokeColor3 = Theme.color.stroke
	value.TextStrokeTransparency = 0.6
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextScaled = false -- TextBounds is only meaningful when the text isn't stretched to its box
	value.TextWrapped = false
	value.Text = "0"
	value.Parent = frame

	local function relayout()
		local height = frame.AbsoluteSize.Y
		if height <= 0 then
			return
		end
		local iconSize = math.floor(height * 0.66)
		value.TextSize = math.clamp(math.floor(height * 0.46), Theme.text.h2.min, Theme.text.h2.max)

		ico.Size = UDim2.fromOffset(iconSize, iconSize)
		ico.Position = UDim2.new(0, PAD, 0.5, 0)

		local textWidth = math.ceil(value.TextBounds.X)
		value.Size = UDim2.new(0, textWidth, 1, 0)
		value.Position = UDim2.new(0, PAD + iconSize + GAP, 0.5, 0)

		frame.Size = UDim2.new(0, PAD + iconSize + GAP + textWidth + PAD, frame.Size.Y.Scale, frame.Size.Y.Offset)
	end

	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	task.defer(relayout) -- AbsoluteSize is 0 until the first layout pass

	frame.Parent = parent

	return {
		instance = frame,
		setValue = function(text: string)
			value.Text = text
			relayout() -- the number changed width; the chip follows it
		end,
	}
end

-- ── icon button (circular, for the entry rail) ───────────────────────────────────────────────────

export type IconButtonOptions = {
	icon: string,
	label: string,
	layoutOrder: number?,
	parent: Instance?,
	onActivated: (() -> ())?,
	-- How many tiles share the rail. Job #095: the tile height used to be a hardcoded 0.22, which was
	-- correct for the FOUR entries this bar shipped with and silently wrong once PAINT made it five —
	-- 5 x 0.22 = 1.10, so the rail overflowed its own holder. Dividing by the real count makes a sixth
	-- entry safe instead of quietly breaking the layout again.
	count: number?,
	-- Vertical gap between tiles, in px, so the tile can subtract its share and the rail FITS.
	gap: number?,
	-- false = icon only, no caption (Job #099: touch drops labels to reclaim canvas height).
	showLabel: boolean?,
}

function Components.iconButton(opts: IconButtonOptions): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Tile_" .. opts.label
	-- Scale share minus this tile's slice of the total inter-tile padding, so N tiles plus N-1 gaps come
	-- to exactly the holder's height rather than overflowing it.
	local count = math.max(opts.count or 4, 1)
	local gap = opts.gap or 0
	-- The extra -1 is for ROUNDING, not arithmetic: AbsoluteSize resolves to whole pixels, so five tiles
	-- of 77.6 px each render as 78 and the rail spilled 2 px past its holder. A pixel off each tile
	-- absorbs that and still leaves the badge above the thumb floor.
	tile.Size = UDim2.new(1, 0, 1 / count, -((gap * (count - 1)) / count) - 1)
	tile.BackgroundTransparency = 1
	tile.BorderSizePixel = 0
	tile.LayoutOrder = opts.layoutOrder or 0

	local btn = Instance.new("ImageButton")
	btn.Name = "Button"
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Position = UDim2.fromScale(0.5, 0)
	-- 0.78, not 0.74: with the 0.22 caption below it that now sums to exactly 1, where 0.74 left 4% of
	-- every tile as dead space. Job #095 needed those pixels — the badge is a TAP TARGET and was
	-- measuring 47x47 on a small phone, under the 58 px thumb floor this game uses elsewhere.
	btn.Size = UDim2.fromScale(1, 0.78)
	btn.BackgroundColor3 = Theme.color.panel
	btn.BackgroundTransparency = 0.1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	corner(Theme.radius.pill, btn)
	stroke(Theme.color.gold, Theme.strokeWidth.control, btn)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = btn

	-- The artwork is a child sized by SCALE rather than the button's own Image with pixel padding, so the
	-- inset stays proportional at any badge size — the ring keeps its breathing room on a phone and a
	-- 4K monitor alike, instead of the icon swelling to the rim.
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.56, 0.56)
	art.BackgroundTransparency = 1
	art.BorderSizePixel = 0
	art.ScaleType = Enum.ScaleType.Fit
	art.Image = Components.iconId(opts.icon)
	art.Parent = btn

	local scale = Instance.new("UIScale")
	scale.Parent = btn

	-- Job #099: on touch the caption is dropped and the badge takes the whole tile. Job #095 argued to
	-- KEEP labels (a playtester once failed to read an unlabelled icon) — that argument was made before
	-- measuring what the rail costs: with labels and thumb-sized badges it takes 70-78% of a real
	-- phone's usable canvas. A rail that covers three-quarters of the lobby is a worse comprehension
	-- problem than an unlabelled icon.
	local showLabel = opts.showLabel ~= false
	if showLabel then
		btn.Size = UDim2.fromScale(1, 0.78)
	else
		btn.Size = UDim2.fromScale(1, 1)
	end

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Visible = showLabel
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.fromScale(0.5, 1)
	caption.Size = UDim2.fromScale(1, 0.22)
	Components.applyText(caption, Theme.text.caption, Theme.font.button)
	caption.Text = string.upper(opts.label)
	caption.Parent = tile

	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, Theme.tween.fast, { Scale = 1.08 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, Theme.tween.fast, { Scale = 1 }):Play()
	end)
	btn.Activated:Connect(function()
		UISound.play("open")
		if opts.onActivated then
			opts.onActivated()
		end
	end)

	btn.Parent = tile
	tile.Parent = opts.parent
	return tile
end

-- ── progress bar (STYLEGUIDE §6.8) ───────────────────────────────────────────────────────────────

export type ProgressBar = {
	instance: Frame,
	setFill: (alpha: number, animate: boolean?) -> (),
	setText: (text: string) -> (),
}

function Components.progressBar(parent: Instance?): ProgressBar
	local track = Instance.new("Frame")
	track.Name = "ProgressBar"
	track.Size = UDim2.fromScale(1, 0.16)
	track.BackgroundColor3 = Theme.color.sunken
	track.BorderSizePixel = 0
	corner(Theme.radius.pill, track)
	stroke(Theme.color.woodDark, Theme.strokeWidth.hairline, track)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.color.green
	fill.BorderSizePixel = 0
	corner(Theme.radius.pill, fill)
	fill.Parent = track

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	Components.applyText(label, Theme.text.caption, Theme.font.bodyBold)
	label.TextStrokeTransparency = 0.2
	label.Text = ""
	label.Parent = track

	track.Parent = parent

	return {
		instance = track,
		setFill = function(alpha: number, animate: boolean?)
			local target = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
			if animate == false then
				fill.Size = target
			else
				TweenService:Create(fill, Theme.tween.normal, { Size = target }):Play()
			end
		end,
		setText = function(text: string)
			label.Text = text
		end,
	}
end

-- ── panel (STYLEGUIDE §6.1 + §6.11 — X *and* tap-outside, one primary panel at a time) ───────────

export type Panel = {
	gui: ScreenGui,
	frame: Frame,
	content: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
}

export type PanelOptions = {
	name: string,
	title: string,
	icon: string?,
	size: UDim2?,
	parent: Instance,
}

-- Every panel built by `Components.panel`, so anything can close the lot. STYLEGUIDE §6.11: *"opening a
-- full panel dims/closes other open panels; prefer one primary panel open at a time."*
--
-- This is an EXPLICIT call, not an automatic close-on-open: making `setOpen(true)` close its siblings
-- would silently change how the lobby's four panels behave, which is not this job's business. The game
-- place calls it at the two moments where a leftover panel is plainly wrong — going down, and the run
-- ending (found in the Job #075 playtest: the results screen appeared on top of an open Trading Post).
local openPanels: { [string]: () -> () } = {}

function Components.closeAllPanels(except: string?)
	for name, close in pairs(openPanels) do
		if name ~= except then
			close()
		end
	end
end

function Components.panel(opts: PanelOptions): Panel
	local gui = Components.screen(opts.name, opts.parent)
	gui.Enabled = false
	gui.DisplayOrder = 10

	-- scrim doubles as the tap-outside-to-close target (§6.11 "no dead-end panels")
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Theme.color.scrim
	scrim.BackgroundTransparency = 0.45
	scrim.BorderSizePixel = 0
	scrim.AutoButtonColor = false
	scrim.Text = ""
	scrim.Parent = gui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = opts.size or UDim2.fromScale(0.62, 0.7)
	frame.BackgroundColor3 = Theme.color.panel
	frame.BorderSizePixel = 0
	corner(Theme.radius.panel, frame)
	stroke(Theme.color.wood, Theme.strokeWidth.panel, frame)

	-- keeps the panel usable in portrait as well as landscape
	local sizeClamp = Instance.new("UISizeConstraint")
	sizeClamp.MinSize = Vector2.new(260, 220)
	sizeClamp.Parent = frame

	-- title strip
	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.fromScale(1, 0.11)
	bar.BackgroundColor3 = Theme.color.woodDark
	bar.BorderSizePixel = 0
	corner(Theme.radius.panel, bar)

	-- Every panel carries an icon in its title bar, not text alone — it's what makes a panel
	-- recognisable at a glance before the words are read.
	local titleX = 0.035
	if opts.icon then
		local titleIcon = Components.icon({
			name = opts.icon,
			size = UDim2.fromScale(0.07, 0.7),
			parent = bar,
		})
		titleIcon.AnchorPoint = Vector2.new(0, 0.5)
		titleIcon.Position = UDim2.fromScale(0.025, 0.5)
		-- the badge ends at ~0.095; start the title past that so text never touches the icon
		titleX = 0.135
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.7, 0.72)
	title.Position = UDim2.fromScale(titleX, 0.14)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(title, Theme.text.h1, Theme.font.heading)
	title.Text = string.upper(opts.title) -- §5: major headings ALL CAPS
	title.Parent = bar

	-- Close is a utility, not the loudest thing on the panel: kept small and muted so the title reads
	-- first. Still a comfortable tap target, and tap-outside works as the second way out.
	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "Close"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.fromScale(0.975, 0.5)
	closeBtn.Size = UDim2.fromScale(0.055, 0.52)
	closeBtn.BackgroundColor3 = Theme.color.red
	closeBtn.BackgroundTransparency = 0.45
	closeBtn.BorderSizePixel = 0
	closeBtn.Image = Theme.icon.close
	closeBtn.ImageTransparency = 0.1
	closeBtn.ScaleType = Enum.ScaleType.Fit
	corner(Theme.radius.control, closeBtn)
	local closeRatio = Instance.new("UIAspectRatioConstraint")
	closeRatio.AspectRatio = 1
	closeRatio.Parent = closeBtn
	-- Scale alone let this fall to ~24px on a phone-sized panel, which is not a thumb target. The floor
	-- keeps it comfortably tappable while the scale keeps it visually quiet on a big screen.
	-- (roblox-ui: no official minimum exists — this is our floor, to be confirmed on a real device.)
	-- Job #095: 40 -> 58. The note above said "to be confirmed on a real device"; the mobile pass
	-- measured it at exactly 40x40 on every panel, against the 58 px thumb floor this game already uses
	-- for the driver's controls. This is the ONLY way out of a full-screen modal on a phone, so it is
	-- the last control that should be hard to hit.
	local closeFloor = Instance.new("UISizeConstraint")
	closeFloor.MinSize = Vector2.new(58, 58)
	closeFloor.Parent = closeBtn
	closeBtn.Parent = bar

	bar.Parent = frame

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromScale(0, 0.11)
	content.Size = UDim2.fromScale(1, 0.89)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	padding(Theme.space.lg, content)
	content.Parent = frame

	frame.Parent = gui

	local open = false
	local function setOpen(value: boolean)
		if open == value then
			return
		end
		open = value
		if value then
			gui.Enabled = true
			frame.Size = opts.size or UDim2.fromScale(0.62, 0.7)
			UISound.panelOpened()
			-- 🔴 Job #092: hand the mouse to the UI. In FIRST PERSON the pointer is pinned to the centre
			-- of the screen by Roblox's own camera, so a panel opened there could not be closed at all
			-- — reported as "if you are in first person and open shop then mouse not working to close
			-- shop, thats common bug". `InputMode` forces the camera out of first person for as long as
			-- any panel is up; see that module for why the mouse cannot simply be unlocked instead.
			--
			-- ⚠️ Hooked HERE, in the shared panel, rather than in the shop: every modal in the game is
			-- built from `Components.panel`, so one seam covers the dock shop, the Robux shop, the admin
			-- panel and the results screen — and anything added later gets it for free.
			InputMode.pushUI()
		else
			gui.Enabled = false
			UISound.panelClosed()
			InputMode.popUI()
		end
	end

	-- register for Components.closeAllPanels
	openPanels[opts.name] = function()
		setOpen(false)
	end

	closeBtn.Activated:Connect(function()
		setOpen(false)
	end)
	scrim.Activated:Connect(function()
		setOpen(false)
	end)

	return {
		gui = gui,
		frame = frame,
		content = content,
		setOpen = setOpen,
		isOpen = function()
			return open
		end,
	}
end

-- ── row (STYLEGUIDE §6.5 — the shop / skill / objective line) ────────────────────────────────────

export type Row = {
	instance: Frame,
	action: Button,
	setTitle: (text: string) -> (),
	setBlurb: (text: string) -> (),
	bar: ProgressBar?,
	flashFail: () -> (), -- pairs with the `fail` sound (gap B — never a silent failure)
}

export type RowOptions = {
	icon: string?, -- Theme.icon key
	iconImage: string?, -- or raw store art (Theme.productIcon)
	title: string,
	blurb: string?,
	actionText: string,
	variant: string?,
	withBar: boolean?,
	layoutOrder: number?,
	parent: Instance?,
	onActivated: (() -> ())?,
}

function Components.row(opts: RowOptions): Row
	local frame = Instance.new("Frame")
	frame.Name = "Row_" .. opts.title
	frame.Size = UDim2.fromScale(1, 0.155)
	frame.BackgroundColor3 = Theme.color.sunken
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.LayoutOrder = opts.layoutOrder or 0
	corner(Theme.radius.control, frame)
	stroke(Theme.color.woodDark, Theme.strokeWidth.hairline, frame)
	padding(Theme.space.sm, frame)

	local textX = 0.02
	if opts.icon or opts.iconImage then
		-- The art is the row's selling point (§6.5 "item preview"). It's a circular badge sized LARGER
		-- than the row so it breaks out top and bottom — which is why the list that hosts these rows
		-- uses a wider gap (Theme.space.lg) and the row must not clip its children.
		local ico = Components.icon({
			name = opts.icon,
			image = opts.iconImage,
			size = UDim2.fromScale(0.16, 1.34),
			parent = frame,
		})
		ico.AnchorPoint = Vector2.new(0, 0.5)
		ico.Position = UDim2.fromScale(0.005, 0.5)
		ico.ZIndex = 3
		textX = 0.135
	end
	frame.ClipsDescendants = false

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromScale(textX, 0.1)
	title.Size = UDim2.fromScale(0.5, 0.4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(title, Theme.text.h2, Theme.font.bodyBold)
	title.Text = opts.title
	title.Parent = frame

	local blurb = Instance.new("TextLabel")
	blurb.Name = "Blurb"
	blurb.Position = UDim2.fromScale(textX, 0.52)
	blurb.Size = UDim2.fromScale(0.5, 0.36)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(blurb, Theme.text.caption, Theme.font.body)
	blurb.TextColor3 = Theme.color.creamDim
	blurb.Text = opts.blurb or ""
	blurb.Parent = frame

	local bar: ProgressBar? = nil
	if opts.withBar then
		local made = Components.progressBar(frame)
		made.instance.Position = UDim2.fromScale(textX, 0.86)
		made.instance.Size = UDim2.fromScale(0.5, 0.11)
		bar = made
	end

	local action = Components.button({
		text = opts.actionText,
		variant = opts.variant or "primary",
		size = UDim2.fromScale(0.22, 0.62),
		parent = frame,
		onActivated = opts.onActivated,
	})
	action.instance.AnchorPoint = Vector2.new(1, 0.5)
	action.instance.Position = UDim2.fromScale(0.99, 0.5)

	frame.Parent = opts.parent

	return {
		instance = frame,
		action = action,
		bar = bar,
		setTitle = function(text: string)
			title.Text = text
		end,
		setBlurb = function(text: string)
			blurb.Text = text
		end,
		-- a visible partner for the `fail` sound: red flash + shake
		flashFail = function()
			local original = frame.BackgroundColor3
			frame.BackgroundColor3 = Theme.color.red
			TweenService:Create(frame, Theme.tween.slow, { BackgroundColor3 = original }):Play()

			local basePos = frame.Position
			local nudge = UDim2.new(basePos.X.Scale, basePos.X.Offset + 6, basePos.Y.Scale, basePos.Y.Offset)
			local shake = TweenService:Create(
				frame,
				TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
				{ Position = nudge }
			)
			shake:Play()
			shake.Completed:Connect(function()
				frame.Position = basePos
			end)
		end,
	}
end

-- ── toast (STYLEGUIDE §6.7 — transient, auto-dismiss, never blocks input) ────────────────────────

local toastGui: ScreenGui? = nil

function Components.toast(parent: Instance, iconName: string, title: string, subtitle: string?)
	if not toastGui then
		local made = Components.screen("Toasts", parent)
		made.DisplayOrder = 50
		toastGui = made
	end
	local gui = toastGui :: ScreenGui

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, -0.15) -- starts off-screen, slides in
	frame.Size = UDim2.fromScale(0.34, 0.1)
	frame.BackgroundColor3 = Theme.color.panel
	frame.BorderSizePixel = 0
	-- never blocks input (§6.11)
	frame.Active = false
	corner(Theme.radius.control, frame)
	stroke(Theme.color.green, Theme.strokeWidth.control, frame)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 5
	ratio.Parent = frame

	Components.icon({ name = iconName, size = UDim2.fromScale(0.14, 0.7), parent = frame }).Position =
		UDim2.fromScale(0.03, 0.15)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromScale(0.2, 0.12)
	titleLabel.Size = UDim2.fromScale(0.76, 0.44)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(titleLabel, Theme.text.h2, Theme.font.heading)
	titleLabel.Text = string.upper(title)
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Position = UDim2.fromScale(0.2, 0.55)
	subLabel.Size = UDim2.fromScale(0.76, 0.34)
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(subLabel, Theme.text.caption, Theme.font.body)
	subLabel.TextColor3 = Theme.color.creamDim
	subLabel.Text = subtitle or ""
	subLabel.Parent = frame

	frame.Parent = gui

	TweenService:Create(frame, Theme.tween.toast, { Position = UDim2.fromScale(0.5, 0.04) }):Play()
	task.delay(2.6, function()
		local out = TweenService:Create(frame, Theme.tween.toast, { Position = UDim2.fromScale(0.5, -0.15) })
		out:Play()
		out.Completed:Wait()
		frame:Destroy()
	end)
end

-- ── burst (STYLEGUIDE §12 juice rule — sound alone is only half of it) ───────────────────────────
-- A short, cheap confirmation flourish on the element that changed: a colour wash plus a few rising
-- motes. Deliberately NOT a ParticleEmitter — this is 2D UI, so it's a handful of tweened frames that
-- clean themselves up. Budget-capped by construction: MOTES per call, all destroyed on completion.

local MOTES = 6

function Components.burst(target: GuiObject, color: Color3?)
	local tint = color or Theme.color.gold

	-- 1) a quick wash over the element that changed
	local wash = Instance.new("Frame")
	wash.Name = "Burst"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = tint
	wash.BackgroundTransparency = 0.55
	wash.BorderSizePixel = 0
	wash.ZIndex = 5
	wash.Active = false -- never eats input
	corner(Theme.radius.control, wash)
	wash.Parent = target

	local washOut = TweenService:Create(wash, Theme.tween.slow, { BackgroundTransparency = 1 })
	washOut:Play()
	washOut.Completed:Connect(function()
		wash:Destroy()
	end)

	-- 2) motes rising off it
	for i = 1, MOTES do
		local mote = Instance.new("Frame")
		mote.Name = "Mote"
		mote.AnchorPoint = Vector2.new(0.5, 0.5)
		mote.Position = UDim2.fromScale(0.1 + (0.8 * (i - 1) / math.max(1, MOTES - 1)), 0.65)
		mote.Size = UDim2.fromOffset(6, 6)
		mote.BackgroundColor3 = tint
		mote.BorderSizePixel = 0
		mote.ZIndex = 6
		mote.Active = false
		corner(Theme.radius.pill, mote)
		mote.Parent = target

		local rise = TweenService:Create(
			mote,
			TweenInfo.new(0.5 + (i % 3) * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(mote.Position.X.Scale, 0.05), BackgroundTransparency = 1 }
		)
		rise:Play()
		rise.Completed:Connect(function()
			mote:Destroy()
		end)
	end
end

-- ── confirm popup (STYLEGUIDE §6.6) ──────────────────────────────────────────────────────────────
-- Gates every GOLD spend. Approved as the job's one deliberate behaviour change: nothing is deducted
-- until BUY is pressed, which prevents mis-tap purchases (worst on mobile).

export type ConfirmOptions = {
	parent: Instance,
	icon: string?,
	title: string,
	body: string?,
	costText: string,
	onConfirm: () -> (),
	onCancel: (() -> ())?,
}

function Components.confirm(opts: ConfirmOptions)
	local panel = Components.panel({
		name = "Confirm",
		title = "Confirm purchase",
		icon = opts.icon or "coin",
		size = UDim2.fromScale(0.38, 0.42),
		parent = opts.parent,
	})

	local item = Instance.new("TextLabel")
	item.Position = UDim2.fromScale(0, 0.02)
	item.Size = UDim2.fromScale(1, 0.2)
	Components.applyText(item, Theme.text.h1, Theme.font.heading)
	item.Text = string.upper(opts.title)
	item.Parent = panel.content

	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromScale(0, 0.24)
	body.Size = UDim2.fromScale(1, 0.2)
	Components.applyText(body, Theme.text.body, Theme.font.body)
	body.TextColor3 = Theme.color.creamDim
	body.Text = opts.body or ""
	body.Parent = panel.content

	local cost = Instance.new("TextLabel")
	cost.Position = UDim2.fromScale(0, 0.46)
	cost.Size = UDim2.fromScale(1, 0.18)
	Components.applyText(cost, Theme.text.h1, Theme.font.heading)
	cost.TextColor3 = Theme.color.gold
	cost.Text = opts.costText
	cost.Parent = panel.content

	local cancel = Components.button({
		text = "CANCEL",
		variant = "danger",
		size = UDim2.fromScale(0.46, 0.2),
		parent = panel.content,
		onActivated = function()
			panel.setOpen(false)
			if opts.onCancel then
				opts.onCancel()
			end
			task.defer(function()
				panel.gui:Destroy()
			end)
		end,
	})
	cancel.instance.Position = UDim2.fromScale(0, 0.76)

	local buy = Components.button({
		text = "BUY",
		variant = "primary",
		size = UDim2.fromScale(0.46, 0.2),
		parent = panel.content,
		onActivated = function()
			panel.setOpen(false)
			opts.onConfirm()
			task.defer(function()
				panel.gui:Destroy()
			end)
		end,
	})
	buy.instance.AnchorPoint = Vector2.new(1, 0)
	buy.instance.Position = UDim2.fromScale(1, 0.76)

	panel.setOpen(true)
end

-- ── entry bar ────────────────────────────────────────────────────────────────────────────────────
-- ONE shared bar replacing the four ad-hoc open buttons each screen used to build at hardcoded pixel
-- offsets (which overlapped on phones). Scale-based and safe-area aware. Kiosks remain the second
-- route in — see LobbyStations.

export type BarEntry = { icon: string, label: string, onActivated: () -> () }

function Components.iconBar(parent: Instance, entries: { BarEntry }): ScreenGui
	local gui = Components.screen("LobbyEntryBar", parent)
	gui.DisplayOrder = 5

	-- A narrow rail of circular icon badges with a caption under each, rather than four identical
	-- full-width slabs: the icon carries the meaning, the label confirms it, and it takes a fraction of
	-- the screen — which matters most on a phone, where a wide stack eats the play area.
	local touch = UserInputService.TouchEnabled

	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	-- ⚠️ Job #099 — on TOUCH this is not a bottom-left rail at all, it is a centred overlay behind one
	-- button, and the reason is measured rather than aesthetic: Roblox's own movement thumbstick reserves
	-- x -100..266, y 105..416 on a 666x374 phone canvas. The whole bottom-left quadrant belongs to
	-- walking. A persistent rail there put a 74x74 joystick directly on top of two shop buttons.
	--
	-- Nor is there anywhere else to put five persistent badges: the top-left is the identity panel, the
	-- top-right the currency chip, the bottom-right the jump button and the admin launcher. So on a phone
	-- the five collapse behind ONE button and open over a scrim — which also parks the joystick behind an
	-- input blocker while the menu is up, instead of competing with it.
	if touch then
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
	else
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.fromScale(0.014, 0.975)
	end
	holder.Size = UDim2.fromScale(0.062, 0.46)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Visible = not touch -- on touch it starts closed, behind the menu button

	-- ⚠️ Job #099 — THE HARD PIXEL FLOOR IS GONE, and that is the whole point.
	--
	-- Job #095 raised this to `MinSize = (64, 420)` so five thumb-sized badges would fit. That was tuned
	-- against desktop-sized viewports and it is fragile in a way no aspect-ratio test reveals: a PIXEL
	-- floor does not scale with device DPI. Roblox's GUI coordinate space on a high-DPI phone can be far
	-- smaller than the screenshot resolution suggests, and on a device reporting ~1200x540 a 420 px floor
	-- is ~87% of the canvas — the rail then runs up under the Roblox topbar, which is exactly what the
	-- reported screenshot showed.
	--
	-- So the rail is now sized FROM THE CANVAS instead of toward a fixed number: it takes at most
	-- MAX_FRACTION of the available height, and the badge inside is whatever that allows, preferring the
	-- 58 px thumb target and never going below the 44 px platform minimum. It cannot swallow the screen
	-- on a small device and it cannot shrink to nothing on a large one.
	local sizeClamp = Instance.new("UISizeConstraint")
	sizeClamp.MinSize = Vector2.new(64, 0)
	-- The 110px width cap keeps the DESKTOP rail a narrow strip. On touch this is no longer a rail but a
	-- centred multi-column overlay, and that same cap silently strangled it — a 3-wide grid came back
	-- 110px wide with the columns collapsed. Caught by measuring the open panel rather than trusting the
	-- layout maths.
	sizeClamp.MaxSize = if touch then Vector2.new(10000, 10000) else Vector2.new(110, 560)
	sizeClamp.Parent = holder

	-- ⚠️ GRID, not a vertical list (Job #099). A single column of five thumb-sized badges CANNOT fit a
	-- phone: measured in the device emulator, the usable canvas is 666x316 and one column needs 252 px —
	-- 80% of it — and even then the badge fell to 43 px, under the 44 px platform minimum. The rail needs
	-- a different SHAPE on a short screen, not a smaller one, so it wraps into columns instead.
	-- A phone in landscape has width to spare; height is the scarce axis. This spends the one we have.
	local GAP = Theme.space.sm
	local layout = Instance.new("UIGridLayout")
	layout.FillDirection = Enum.FillDirection.Vertical -- fill down a column, then start the next
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	-- Touch drops the captions (Job #099) — see the note in iconButton for why that reverses #095.
	local showLabel = not UserInputService.TouchEnabled

	for index, entry in ipairs(entries) do
		Components.iconButton({
			icon = entry.icon,
			label = entry.label,
			layoutOrder = index,
			parent = holder,
			onActivated = entry.onActivated,
			-- UIGridLayout sets each child's size from CellSize, so `count`/`gap` no longer drive the
			-- tile — kept for the non-grid callers the component still supports.
			count = #entries,
			gap = GAP,
			showLabel = showLabel,
		})
	end

	holder.Parent = gui

	-- ── size the rail FROM THE CANVAS, and WRAP IT into columns when height runs out (Job #099) ──────
	-- Driven off the ScreenGui's own AbsoluteSize, so it is correct on any device without knowing
	-- anything about DPI. Measured reality that forced this: the emulator reports a 666x316 usable
	-- canvas, where one column of five 58 px badges is 80% of the screen.
	local n = #entries
	local BADGE_PREFERRED, BADGE_MIN = 58, 44
	local MAX_FRACTION = 0.62
	local LABEL_SHARE = if showLabel then 0.22 else 0

	local function resize()
		local canvas = gui.AbsoluteSize
		if canvas.Y <= 0 then
			return
		end
		local maxH = canvas.Y * MAX_FRACTION

		-- Fewest columns that still lets the badge reach its preferred size. One column stays the answer
		-- on any screen with the height for it, so desktop and tablet are unchanged. On touch the panel is
		-- centred over a scrim with the whole screen to use, so it starts wider and stays compact.
		local cols, cell = 1, 0
		local minCols = if touch then 3 else 1
		for c = minCols, 3 do
			local rows = math.ceil(n / c)
			local h = (maxH - (rows - 1) * GAP) / rows
			cols, cell = c, h
			if h * (1 - LABEL_SHARE) >= BADGE_PREFERRED then
				break
			end
		end

		-- Never below the platform minimum: past that point a taller rail beats an untappable one.
		local minCell = BADGE_MIN / (1 - LABEL_SHARE)
		if cell < minCell then
			cell = minCell
		end

		local rows = math.ceil(n / cols)
		layout.CellSize = UDim2.fromOffset(cell, cell)
		layout.FillDirectionMaxCells = rows
		holder.Size = UDim2.fromOffset(cols * cell + (cols - 1) * GAP, rows * cell + (rows - 1) * GAP)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	-- ── touch: one button, a scrim, and the five behind it (Job #099) ────────────────────────────────
	if touch then
		-- Scrim first so it sits UNDER the badges. It is what makes the overlay safe: while the menu is
		-- open it eats the taps that would otherwise reach the movement thumbstick underneath.
		local scrim = Instance.new("TextButton")
		scrim.Name = "Scrim"
		scrim.Size = UDim2.fromScale(1, 1)
		scrim.BackgroundColor3 = Theme.color.scrim
		scrim.BackgroundTransparency = 0.35
		scrim.BorderSizePixel = 0
		scrim.AutoButtonColor = false
		scrim.Text = ""
		scrim.ZIndex = 0
		scrim.Visible = false
		scrim.Parent = gui
		holder.ZIndex = 1

		local function setOpen(open: boolean)
			scrim.Visible = open
			holder.Visible = open
			UISound.play(if open then "open" else "close")
		end

		-- Top-right, under the currency chip: the one corner a phone leaves free. The bottom-left is the
		-- thumbstick, the bottom-right the jump button, the top-left the identity panel.
		-- A dark circle with a gold ring: deliberately the SAME vocabulary as the five badges it opens, so
		-- the button visibly belongs to the thing it reveals. `primary` green was wrong twice over — green
		-- means boat/mechanical in this palette, and a solid fill made it a third competing slab in the
		-- corner next to the currency chip.
		local toggle = Components.button({
			text = "",
			variant = "chip",
			strokeColor = Theme.color.gold,
			round = true,
			icon = "shop",
			size = UDim2.fromOffset(58, 58),
			parent = gui,
			onActivated = function()
				setOpen(not holder.Visible)
			end,
		})
		toggle.instance.Name = "MenuToggle"
		toggle.instance.AnchorPoint = Vector2.new(1, 0)
		toggle.instance.Position = UDim2.new(1, -10, 0, 82)
		toggle.instance.ZIndex = 2

		scrim.Activated:Connect(function()
			setOpen(false)
		end)

		-- Picking a destination closes the menu on the way through, so the player is never left with the
		-- overlay sitting on top of the panel they just opened.
		for _, tile in ipairs(holder:GetChildren()) do
			if tile:IsA("Frame") then
				local btn = tile:FindFirstChild("Button")
				if btn and btn:IsA("GuiButton") then
					btn.Activated:Connect(function()
						setOpen(false)
					end)
				end
			end
		end
	end

	return gui
end

return Components
