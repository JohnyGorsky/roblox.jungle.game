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

export type IconOptions = {
	name: string?, -- a Theme.icon key
	image: string?, -- or a raw rbxassetid (e.g. Theme.productIcon store art)
	size: UDim2?,
	chip: boolean?, -- default true
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

	if opts.chip ~= false then
		corner(Theme.radius.control, holder)
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
	image.Image = opts.image or (opts.name and (Theme.icon :: { [string]: string })[opts.name]) or ""
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
	setText: (text: string) -> (),
}

function Components.button(opts: ButtonOptions): Button
	local base = VARIANT[opts.variant or "primary"] or VARIANT.primary
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

	btn.Parent = opts.parent

	return {
		instance = btn,
		setEnabled = setEnabled,
		setText = function(text: string)
			btn.Text = text
		end,
	}
end

-- ── chip (STYLEGUIDE §6.3 — the currency readout) ────────────────────────────────────────────────

export type Chip = { instance: Frame, setValue: (text: string) -> () }

function Components.chip(iconName: string, parent: Instance?): Chip
	local frame = Instance.new("Frame")
	frame.Name = "Chip"
	frame.Size = UDim2.fromScale(0.17, 0.055)
	frame.BackgroundColor3 = Theme.color.sunken
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	corner(Theme.radius.pill, frame)
	stroke(Theme.color.wood, Theme.strokeWidth.control, frame)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 3.6
	ratio.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.space.sm)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	padding(Theme.space.sm, frame)

	Components.icon({ name = iconName, size = UDim2.fromScale(0.22, 0.8), chip = false, layoutOrder = 1, parent = frame })

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.fromScale(0.7, 0.9)
	value.LayoutOrder = 2
	value.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(value, Theme.text.h2, Theme.font.bodyBold)
	value.TextColor3 = Theme.color.gold
	value.RichText = false
	value.Text = "0"
	value.Parent = frame

	frame.Parent = parent

	return {
		instance = frame,
		setValue = function(text: string)
			value.Text = text
		end,
	}
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

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.7, 0.72)
	title.Position = UDim2.fromScale(0.04, 0.14)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(title, Theme.text.h1, Theme.font.heading)
	title.Text = string.upper(opts.title) -- §5: major headings ALL CAPS
	title.Parent = bar

	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "Close"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.fromScale(0.98, 0.5)
	closeBtn.Size = UDim2.fromScale(0.09, 0.66)
	closeBtn.BackgroundColor3 = Theme.color.red
	closeBtn.BackgroundTransparency = 0.15
	closeBtn.BorderSizePixel = 0
	closeBtn.Image = Theme.icon.close
	closeBtn.ScaleType = Enum.ScaleType.Fit
	corner(Theme.radius.control, closeBtn)
	local closeRatio = Instance.new("UIAspectRatioConstraint")
	closeRatio.AspectRatio = 1
	closeRatio.Parent = closeBtn
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
		else
			gui.Enabled = false
			UISound.panelClosed()
		end
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
		local ico = Components.icon({
			name = opts.icon,
			image = opts.iconImage,
			size = UDim2.fromScale(0.1, 0.7),
			parent = frame,
		})
		ico.AnchorPoint = Vector2.new(0, 0.5)
		ico.Position = UDim2.fromScale(0.01, 0.5)
		textX = 0.14
	end

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

	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.fromScale(0.012, 0.985)
	holder.Size = UDim2.fromScale(0.15, 0.42)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0

	local sizeClamp = Instance.new("UISizeConstraint")
	sizeClamp.MinSize = Vector2.new(120, 180)
	sizeClamp.MaxSize = Vector2.new(280, 420)
	sizeClamp.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, Theme.space.sm)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	for index, entry in ipairs(entries) do
		Components.button({
			text = entry.label,
			variant = "secondary",
			icon = entry.icon,
			size = UDim2.fromScale(1, 0.2),
			layoutOrder = index,
			sound = "open",
			parent = holder,
			onActivated = entry.onActivated,
		})
	end

	holder.Parent = gui
	return gui
end

return Components
