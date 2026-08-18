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
}

export type ButtonOptions = {
	text: string,
	variant: string?, -- primary | secondary | gold | danger
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

	corner(Theme.radius.control, btn)
	stroke(Theme.color.woodDark, Theme.strokeWidth.control, btn)

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

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
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
	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.fromScale(0.014, 0.975)
	holder.Size = UDim2.fromScale(0.062, 0.46)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0

	-- ⚠️ Job #095 — height floor raised 240 -> 420, and that is a deliberate, expensive choice.
	--
	-- The badges measured 47x47 on a 1136x640 phone, under the 58 px thumb floor this game already
	-- applies to the driver's controls. This rail is the ONLY way a mobile player reaches the shops and
	-- progression screens without walking to a kiosk, so a mis-tap here is a player who cannot spend —
	-- which outranks a cosmetic overlap.
	--
	-- The badge is square and sized from the TILE's height (0.78 of it), so the only lever that makes it
	-- bigger is the rail being taller. Working backwards from 58 px with five entries and an 8 px gap:
	-- tile >= 74.4 px -> holder >= 5 x (74.4 + 6.4) ~= 404 px. 420 leaves margin, and lands the badge at
	-- ~60 px on the smallest phone we sweep.
	--
	-- The cost is real: 420 px is ~66% of a 640-tall phone's height. Accepted because the lobby is a menu
	-- screen with no gameplay competing for that space (unlike the in-run HUD, where Job #094 refused the
	-- equivalent trade). MaxSize rises with it so the proportion holds on a tablet instead of the rail
	-- hitting its cap and shrinking the badges again.
	local sizeClamp = Instance.new("UISizeConstraint")
	sizeClamp.MinSize = Vector2.new(64, 420)
	sizeClamp.MaxSize = Vector2.new(110, 560)
	sizeClamp.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- sm rather than md: every pixel of gap is a pixel the badges don't get, and with five entries the
	-- 4 px saved per gap is worth more on the tap target than in the whitespace.
	local GAP = Theme.space.sm
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	for index, entry in ipairs(entries) do
		Components.iconButton({
			icon = entry.icon,
			label = entry.label,
			layoutOrder = index,
			parent = holder,
			onActivated = entry.onActivated,
			-- the tile divides by the REAL count, so adding a sixth entry resizes the rail instead of
			-- overflowing it (see IconButtonOptions.count)
			count = #entries,
			gap = GAP,
		})
	end

	holder.Parent = gui
	return gui
end

return Components
