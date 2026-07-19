--!strict
-- IntroFade.local.luau — full-screen black overlay for the plane-intro impact cut (Job 044).
-- The server (PlaneServer) fires ReplicatedStorage.IntroFade with ("out"|"in", duration) to fade the screen
-- to/from black at the moment the plane goes down, so the seat→hub teleport is hidden behind the cut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "IntroFadeGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ResetOnSpawn = false
gui.Parent = playerGui

local black = Instance.new("Frame")
black.Name = "Black"
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 1 -- start clear
black.BorderSizePixel = 0
black.Parent = gui

local fadeRemote = ReplicatedStorage:WaitForChild("IntroFade") :: RemoteEvent

fadeRemote.OnClientEvent:Connect(function(dir: string, duration: number?)
	local target = (dir == "out") and 0 or 1 -- "out" = fade TO black (transparency 0)
	local info = TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(black, info, { BackgroundTransparency = target }):Play()
end)
