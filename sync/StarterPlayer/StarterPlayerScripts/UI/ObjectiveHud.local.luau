--!strict
-- ObjectiveHud.local.luau — per-run objectives (Job 061, rebuilt in Job #075).
--
-- Lists the run objectives with live progress and a check when done. Reads ObjectiveDefs + the
-- `ObjDone_<id>` / `ObjProg_<id>` Workspace attributes ObjectiveServer publishes.
--
-- ⚠️ THE STRUCTURAL CHANGE: it is a COLLAPSED TRAY now, not a permanently-open panel. STYLEGUIDE §6.11
-- is explicit — *"heavy panels (daily tasks, shop) default collapsed during play"* and *"while playing,
-- show ONLY mandatory at-a-glance info"*. A four-row objective list parked in the top-right for the
-- whole run is exactly what that rule forbids. The header keeps the one fact worth glancing at ("2/4")
-- and the rows are one tap away.
--
-- It also no longer redraws every objective every frame: rows are refreshed when an attribute changes.
-- The old version ran the full list on RenderStepped, which is 60 string formats a second to display
-- numbers that change a handful of times per run.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveDefs = require(ReplicatedStorage:WaitForChild("Objectives"):WaitForChild("ObjectiveDefs"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))
local HudState = require(RunUI:WaitForChild("HudState"))

local player = Players.LocalPlayer

local gui = Components.screen("ObjectiveHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 7 -- above the plain readouts: it expands over them and must not be occluded

local TOUCH = game:GetService("UserInputService").TouchEnabled

local ROW_H = 0.16 -- of the expanded tray
local count = #ObjectiveDefs.List

local tray = RunComponents.tray({
	name = "Objectives",
	icon = "clipboard",
	-- Sits under the currency chips (which end around y = 0.078 at their max height).
	-- ⚠️ Job #099 — LOWER on touch. Measured: the collapsed card sat at y 30..62 while the currency chips
	-- occupy y 6..40, a 150x10 overlap. Ironically caused by this job's own #0009 fix, which raised the
	-- collapsed height to clear the thumb floor and so pushed the card up into the row above it.
	-- 0.17 drops it to y ~54, clear of the chips with margin.
	position = if TOUCH then UDim2.fromScale(0.985, 0.17) else UDim2.fromScale(0.985, 0.095),
	anchor = Vector2.new(1, 0),
	-- ⚠️ Job #099 / finding #0009 — 0.045 of screen height is ~29 px on a phone, and this whole card IS
	-- the tap target that expands the objective list (RunComponents.tray sizes its Header to fill it).
	-- Raised to 0.075 so it clears the 58 px thumb floor on a phone while staying a quiet strip on a
	-- monitor, where 0.075 is still only ~80 px.
	-- Narrower on touch: the collapsed bar carries a count, not a sentence (see setSummary below).
	collapsedSize = if TOUCH then UDim2.fromScale(0.10, 0.075) else UDim2.fromScale(0.17, 0.075),
	expandedSize = UDim2.fromScale(0.24, 0.075 + ROW_H * math.max(count, 1) * 0.42),
	parent = gui,
})

local clamp = Instance.new("UISizeConstraint")
-- ⚠️ Job #099 — this floor is why narrowing `collapsedSize` did nothing at first: the card's Size WAS
-- 0.10 x 0.075, and this constraint clamped it straight back to 150x32. A pixel floor overriding a
-- scale value, exactly the trap this job started with.
--
-- On touch: narrower, because the label is now just "0/4" and not a sentence — and TALLER, because 32 px
-- is under the 58 px thumb floor and this whole card IS the button that expands the objective list.
-- (It escaped the tap-target audit because `Header` is transparent, and the audit only looked at
-- elements that PAINT. A transparent button is still a tap target.)
clamp.MinSize = if TOUCH then Vector2.new(76, 58) else Vector2.new(150, 32)
clamp.MaxSize = Vector2.new(320, 260)
clamp.Parent = tray.instance

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.xs)
layout.Parent = tray.body

-- ── rows ─────────────────────────────────────────────────────────────────────────────────────────

type RowUi = { icon: Frame, label: TextLabel }
local rows: { [string]: RowUi } = {}

for i, def in ObjectiveDefs.List do
	local row = Instance.new("Frame")
	row.Name = "Obj_" .. def.id
	row.LayoutOrder = i
	row.Size = UDim2.fromScale(1, 1 / math.max(count, 1))
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Active = false

	local mark = Components.icon({
		name = "check",
		size = UDim2.fromScale(0.1, 0.66),
		chip = false,
		parent = row,
	})
	mark.AnchorPoint = Vector2.new(0, 0.5)
	mark.Position = UDim2.fromScale(0, 0.5)
	local markImage = mark:FindFirstChild("Image") :: ImageLabel?
	if markImage then
		markImage.ImageTransparency = 0.75 -- pending: present but plainly not yet earned
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.fromScale(1, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.9)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(label, Theme.text.caption, Theme.font.body)
	label.Text = def.label
	label.Parent = row

	row.Parent = tray.body
	rows[def.id] = { icon = mark, label = label }
end

-- ── state ────────────────────────────────────────────────────────────────────────────────────────

local wasDone: { [string]: boolean } = {}

local function render()
	local done = 0

	for _, def in ObjectiveDefs.List do
		local ui = rows[def.id]
		local isDone = Workspace:GetAttribute("ObjDone_" .. def.id) == true
		local image = ui.icon:FindFirstChild("Image") :: ImageLabel?

		if isDone then
			done += 1
			ui.label.Text = def.label
			ui.label.TextColor3 = Theme.color.green
			if image then
				image.ImageTransparency = 0
			end
			-- celebrate the transition, once
			if not wasDone[def.id] then
				wasDone[def.id] = true
				UISound.play("rank")
				Components.burst(ui.label, Theme.color.green)
			end
		else
			wasDone[def.id] = false
			ui.label.TextColor3 = Theme.color.cream
			if image then
				image.ImageTransparency = 0.75
			end
			if def.target > 1 then
				local p = (Workspace:GetAttribute("ObjProg_" .. def.id) :: number?) or 0
				ui.label.Text = ("%s  (%d/%d)"):format(def.label, p, def.target)
			else
				ui.label.Text = def.label
			end
		end
	end

	-- ⚠️ On touch the word goes and the COUNT stays. "just icon not text" was the ask, and the word
	-- "OBJECTIVES" is indeed what makes this wide — but a bare clipboard with no number is a mystery
	-- button, and a count is the entire point of a collapsed summary. Icon + "0/4" is three characters
	-- and stays glanceable; the full sentences are one tap away in the expanded tray.
	tray.setSummary(if TOUCH then ("%d/%d"):format(done, count) else ("OBJECTIVES  %d/%d"):format(done, count))
end

-- Objectives only exist during a run; the tray has nothing to say at the crash site.
local function updateVisibility()
	local running = HudState.runStarted() and not HudState.runEnded()
	tray.instance.Visible = running
	if not running and tray.isExpanded() then
		tray.setExpanded(false) -- don't leave it open across the end of a run
	end
end

for _, def in ObjectiveDefs.List do
	Workspace:GetAttributeChangedSignal("ObjDone_" .. def.id):Connect(render)
	if def.target > 1 then
		Workspace:GetAttributeChangedSignal("ObjProg_" .. def.id):Connect(render)
	end
end
Workspace:GetAttributeChangedSignal("RunStarted"):Connect(updateVisibility)
Workspace:GetAttributeChangedSignal("RunEnded"):Connect(updateVisibility)

render()
updateVisibility()
