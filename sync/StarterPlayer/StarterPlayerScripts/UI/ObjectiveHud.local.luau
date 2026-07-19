--!strict
-- ObjectiveHud.local.luau — per-run objectives panel (Job 061). Lists the run objectives with live progress
-- and a check when done. Reads ObjectiveDefs + the ObjDone_<id> / ObjProg_<id> Workspace attributes that
-- ObjectiveServer publishes. Shown only during a run; hidden during the intro (see IntroHudGate). Greybox.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveDefs = require(ReplicatedStorage:WaitForChild("Objectives"):WaitForChild("ObjectiveDefs"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ObjectiveHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -14, 0, 96) -- top-right, below the Gold/Salvage pills
panel.Size = UDim2.fromScale(0.24, 0.18)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 8)
pc.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 3)
layout.Parent = panel
panel.Parent = gui

local header = Instance.new("TextLabel")
header.LayoutOrder = 0
header.Size = UDim2.fromScale(1, 0.22)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.TextColor3 = Color3.fromRGB(150, 200, 235)
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextScaled = true
header.Text = "OBJECTIVES"
local htc = Instance.new("UITextSizeConstraint")
htc.MaxTextSize = 14
htc.Parent = header
header.Parent = panel

-- one row per objective
local rows: { [string]: TextLabel } = {}
for i, def in ObjectiveDefs.List do
	local row = Instance.new("TextLabel")
	row.LayoutOrder = i
	row.Size = UDim2.fromScale(1, 0.18)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.Gotham
	row.TextColor3 = Color3.fromRGB(210, 214, 220)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextScaled = true
	row.Text = "• " .. def.label
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 13
	tc.Parent = row
	row.Parent = panel
	rows[def.id] = row
end

RunService.RenderStepped:Connect(function()
	local running = Workspace:GetAttribute("RunStarted") == true and Workspace:GetAttribute("RunEnded") ~= true
	panel.Visible = running
	if not running then
		return
	end
	for _, def in ObjectiveDefs.List do
		local row = rows[def.id]
		local doneIt = Workspace:GetAttribute("ObjDone_" .. def.id) == true
		if doneIt then
			row.Text = "✓ " .. def.label
			row.TextColor3 = Color3.fromRGB(120, 220, 150)
		elseif def.target > 1 then
			local p = (Workspace:GetAttribute("ObjProg_" .. def.id) :: number?) or 0
			row.Text = ("• %s (%d/%d)"):format(def.label, p, def.target)
			row.TextColor3 = Color3.fromRGB(210, 214, 220)
		else
			row.Text = "• " .. def.label
			row.TextColor3 = Color3.fromRGB(210, 214, 220)
		end
	end
end)
