--!strict
-- UntieButton.local.luau — GUI untie/start button (Job 030). Shown while you're seated in the boat's
-- DriverSeat and the boat is TIED, so you can untie without reaching the winch/dock ProximityPrompt (which
-- can be unreachable at an awkward mooring angle). Fires the server RequestUntie; the server (StagingServer
-- pre-run, DockServer at a dock) validates + performs the untie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local untieRemote = ReplicatedStorage:WaitForChild("RequestUntie") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "UntieButton"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.AnchorPoint = Vector2.new(0.5, 1)
btn.Position = UDim2.fromScale(0.5, 0.82)
btn.Size = UDim2.fromScale(0.22, 0.08)
btn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
btn.Font = Enum.Font.GothamBold
btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextScaled = true
btn.Text = "UNTIE"
btn.Visible = false
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = btn
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 4
ar.Parent = btn
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 22
tsc.Parent = btn
btn.Parent = gui

btn.Activated:Connect(function()
	untieRemote:FireServer()
end)

local function seatedInDriver(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return seat ~= nil and seat.Name == "DriverSeat"
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	acc = 0
	local boat = Workspace:FindFirstChild("Boat")
	local tied = boat ~= nil and boat:GetAttribute("Tied") == true
	local show = tied and seatedInDriver()
	btn.Visible = show
	if show then
		btn.Text = (Workspace:GetAttribute("RunStarted") == true) and "UNTIE" or "PULL / START"
	end
end)
