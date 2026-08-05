--!strict
-- StagingHint.local.luau — the CRASH SITE banner (Job 016, rebuilt in Job #075).
--
-- The first thing you see after waking at the wreck, and the only instruction the game gives before the
-- run starts: get on the boat, untie, go. Reads the occupancy counts StagingServer publishes
-- (Boat.OnBoatCount / Boat.CrewCount).
--
-- The crew count is a PROGRESS BAR now rather than the old "3/4 on boat" text. Same information, but
-- "are we all aboard yet?" is a question about a proportion, and a filling bar answers it without
-- anyone reading a digit — which matters when the person who has to decide is the one at the helm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local player = Players.LocalPlayer

local gui = Components.screen("StagingHint", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 7

local card = RunComponents.card({
	name = "Staging",
	anchor = Vector2.new(0.5, 0),
	-- Pinned to the TOP, not floated at 0.12. At 0.12 it sat in the middle of the view, over the wreck
	-- and over whoever you were walking towards — a banner reading as an obstacle. It is chrome, so it
	-- lives on the edge with the rest of the chrome. `Components.screen` sets CoreUISafeInsets, so y=0 is
	-- already below the Roblox topbar and this 0.02 is a real margin, not a guess at one.
	--
	-- It shares the top-centre with `RiverProgress`, and that is safe by construction rather than by
	-- luck: this card only exists before `RunStarted` and the river bar only after it, so the two can
	-- never be on screen together. The currency chips are right-aligned from 0.7 and this card is 0.4
	-- wide about the centre (0.3–0.7), so they don't meet either.
	position = UDim2.fromScale(0.5, 0.02),
	size = UDim2.fromScale(0.4, 0.13),
	accent = Theme.color.gold,
	transparency = 0.08,
	parent = gui,
})

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(260, 78)
clamp.MaxSize = Vector2.new(560, 150)
clamp.Parent = card

local ico = Components.icon({ name = "boat", size = UDim2.fromScale(0.13, 0.5), parent = card })
ico.AnchorPoint = Vector2.new(0, 0)
ico.Position = UDim2.fromScale(0.04, 0.13)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromScale(0.22, 0.12)
title.Size = UDim2.fromScale(0.74, 0.34)
title.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(title, Theme.text.h1, Theme.font.heading)
title.Text = "BOARD THE BOAT & UNTIE"
title.Parent = card

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Position = UDim2.fromScale(0.22, 0.44)
hint.Size = UDim2.fromScale(0.74, 0.2)
hint.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(hint, Theme.text.caption, Theme.font.body)
hint.TextColor3 = Theme.color.creamDim
hint.Text = "Anyone can pull the rope — the run starts the moment it's loose."
hint.Parent = card

local barHolder = Instance.new("Frame")
barHolder.Name = "CrewBarHolder"
barHolder.AnchorPoint = Vector2.new(0.5, 1)
barHolder.Position = UDim2.fromScale(0.5, 0.9)
barHolder.Size = UDim2.fromScale(0.9, 0.22)
barHolder.BackgroundTransparency = 1
barHolder.BorderSizePixel = 0
barHolder.Active = false
barHolder.Parent = card

local crewBar = Components.progressBar(barHolder)
crewBar.instance.Size = UDim2.fromScale(1, 1)

-- ── state ────────────────────────────────────────────────────────────────────────────────────────

local function refresh()
	-- Hidden the instant the run starts. Deliberately NOT bound through HudState: this is the one screen
	-- that must vanish on the RunStarted edge itself, with no settle window, because the untie that
	-- starts the run is the same action that makes the instruction wrong.
	if Workspace:GetAttribute("RunStarted") == true then
		gui.Enabled = false
		return
	end
	gui.Enabled = true

	local boat = Workspace:FindFirstChild("Boat")
	local onBoat = if boat then ((boat:GetAttribute("OnBoatCount") :: number?) or 0) else 0
	local total = if boat then ((boat:GetAttribute("CrewCount") :: number?) or 0) else 0

	local ready = total > 0 and onBoat >= total
	crewBar.setFill(if total > 0 then onBoat / total else 0)
	crewBar.setText(if ready then ("ALL ABOARD  %d/%d"):format(onBoat, total) else ("%d/%d ON BOAT"):format(onBoat, total))

	local fill = crewBar.instance:FindFirstChild("Fill") :: Frame?
	if fill then
		fill.BackgroundColor3 = if ready then Theme.color.green else Theme.color.yellow
	end
end

Workspace:GetAttributeChangedSignal("RunStarted"):Connect(refresh)

-- follow the boat's occupancy attributes (the Boat may not exist yet at load)
local function hookBoat(boat: Instance)
	boat:GetAttributeChangedSignal("OnBoatCount"):Connect(refresh)
	boat:GetAttributeChangedSignal("CrewCount"):Connect(refresh)
	refresh()
end

local existing = Workspace:FindFirstChild("Boat")
if existing then
	hookBoat(existing)
end
Workspace.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Boat" then
		hookBoat(child)
	end
end)

refresh()
