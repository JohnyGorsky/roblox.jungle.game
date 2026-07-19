--!strict
-- ZoneBanner.local.luau — center-screen banner for zone crossings + day/night set-pieces (Job 035).
-- Shows on the Announce event, then fades out. Greybox styling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local announce = ReplicatedStorage:WaitForChild("Announce") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "ZoneBanner"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Position = UDim2.fromScale(0.5, 0.18)
holder.Size = UDim2.fromScale(0.6, 0.16)
holder.BackgroundTransparency = 1
holder.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextTransparency = 1
title.Text = ""
local ts = Instance.new("UIStroke")
ts.Thickness = 3
ts.Color = Color3.new(0, 0, 0)
ts.Transparency = 1
ts.Parent = title
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 48
tsc.Parent = title
title.Parent = holder

local sub = Instance.new("TextLabel")
sub.Position = UDim2.fromScale(0, 0.62)
sub.Size = UDim2.fromScale(1, 0.32)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamBold
sub.TextColor3 = Color3.new(1, 1, 1)
sub.TextScaled = true
sub.TextTransparency = 1
sub.Text = ""
local ss = Instance.new("UIStroke")
ss.Thickness = 2
ss.Color = Color3.new(0, 0, 0)
ss.Transparency = 1
ss.Parent = sub
local ssc = Instance.new("UITextSizeConstraint")
ssc.MaxTextSize = 22
ssc.Parent = sub
sub.Parent = holder

local token = 0
local function setTrans(t: number)
	title.TextTransparency = t
	ts.Transparency = t
	sub.TextTransparency = t
	ss.Transparency = t
end

announce.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	token += 1
	local myToken = token
	title.Text = tostring(data.title or "")
	title.TextColor3 = (typeof(data.color) == "Color3") and data.color or Color3.fromRGB(90, 200, 230)
	sub.Text = tostring(data.subtitle or "")
	setTrans(1)
	TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(ts, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(ss, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	task.delay(2.6, function()
		if myToken ~= token then
			return -- a newer banner replaced this one
		end
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(ts, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(ss, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end)
end)
