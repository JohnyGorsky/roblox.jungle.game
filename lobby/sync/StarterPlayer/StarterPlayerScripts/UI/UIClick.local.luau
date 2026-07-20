--!strict
-- UIClick.local.luau — plays a click on every GUI button press (lobby UI polish).
-- One shared Sound in SoundService; hooks existing + future GuiButtons under PlayerGui.
-- Audio: ui_mouse_click 89108158102227 (registry audio.md).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local CLICK_ID = "rbxassetid://89108158102227"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local click = Instance.new("Sound")
click.Name = "UIClick"
click.SoundId = CLICK_ID
click.Volume = 0.5
click.Parent = SoundService

local function hook(inst: Instance)
	if inst:IsA("GuiButton") then
		inst.Activated:Connect(function()
			click.TimePosition = 0
			click:Play()
		end)
	end
end

for _, d in ipairs(playerGui:GetDescendants()) do
	hook(d)
end
playerGui.DescendantAdded:Connect(hook)
