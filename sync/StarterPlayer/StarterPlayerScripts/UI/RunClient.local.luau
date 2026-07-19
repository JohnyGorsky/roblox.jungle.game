--!strict
-- RunClient.local.luau — spectate-on-death + end-of-run results screen (Job 018).
--
-- While the run is on and you have no character (you died — permadeath), the camera spectates the boat and
-- a "you died" tag shows. On RunEnded the results panel appears (win/lose, distance, reward, survivors) with
-- a Return to Lobby button + an auto-return countdown. Greybox (real design = P9).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local runEnded = ReplicatedStorage:WaitForChild("RunEnded") :: RemoteEvent
local returnRemote = ReplicatedStorage:WaitForChild("ReturnToLobby") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "RunGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

-- ── "you died — spectating" tag ───────────────────────────────────────────────────────────────
local deadTag = Instance.new("TextLabel")
deadTag.AnchorPoint = Vector2.new(0.5, 0)
deadTag.Position = UDim2.new(0.5, 0, 0, 24)
deadTag.Size = UDim2.fromScale(0.4, 0.06)
deadTag.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
deadTag.BackgroundTransparency = 0.25
deadTag.TextColor3 = Color3.new(1, 1, 1)
deadTag.Font = Enum.Font.GothamBold
deadTag.TextScaled = true
deadTag.Text = "You died — spectating the crew"
deadTag.Visible = false
local dtc = Instance.new("UICorner")
dtc.CornerRadius = UDim.new(0, 8)
dtc.Parent = deadTag
local dts = Instance.new("UITextSizeConstraint")
dts.MaxTextSize = 20
dts.Parent = deadTag
deadTag.Parent = gui

-- spectate: while run on + no character, follow the boat
local ended = false
RunService.RenderStepped:Connect(function()
	if ended then
		return
	end
	local runOn = Workspace:GetAttribute("RunStarted") == true
	local hasChar = player.Character ~= nil and player.Character:FindFirstChild("Humanoid") ~= nil
		and (player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health > 0
	if runOn and not hasChar then
		deadTag.Visible = true
		local boat = Workspace:FindFirstChild("Boat")
		local hull = boat and boat:FindFirstChild("Hull")
		local cam = Workspace.CurrentCamera
		if hull and hull:IsA("BasePart") and cam then
			cam.CameraSubject = hull
			cam.CameraType = Enum.CameraType.Custom
		end
	else
		deadTag.Visible = false
	end
end)

-- ── results panel ─────────────────────────────────────────────────────────────────────────────
runEnded.OnClientEvent:Connect(function(data)
	ended = true
	deadTag.Visible = false

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.42, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	panel.Parent = dim
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 14)
	pc.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = panel

	local order = 0
	local won = data and data.won == true
	local function label(text: string, scaleY: number, color: Color3, maxSize: number)
		order += 1
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.Size = UDim2.fromScale(0.9, scaleY)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = color
		l.TextScaled = true
		l.Text = text
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize
		c.Parent = l
		l.Parent = panel
		return l
	end

	label(won and "🏆 YOU REACHED THE END!" or "☠ THE CREW WAS LOST", 0.2, won and Color3.fromRGB(150, 230, 130) or Color3.fromRGB(230, 120, 110), 34)
	label(("Distance: %d"):format((data and data.distance) or 0), 0.1, Color3.new(1, 1, 1), 22)
	label(("Survivors: %d"):format((data and data.survivors) or 0), 0.1, Color3.new(1, 1, 1), 20)
	label(("🪙 + %d Gold"):format((data and data.reward) or 0), 0.13, Color3.fromRGB(255, 225, 120), 26)

	order += 1
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Size = UDim2.fromScale(0.6, 0.16)
	btn.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Text = "Return to Lobby"
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = btn
	local btsc = Instance.new("UITextSizeConstraint")
	btsc.MaxTextSize = 22
	btsc.Parent = btn
	btn.Parent = panel
	btn.Activated:Connect(function()
		btn.Text = "Returning…"
		returnRemote:FireServer()
	end)

	local countdown = label("Returning automatically in " .. tostring((data and data.returnIn) or 30) .. "s…", 0.08, Color3.fromRGB(180, 180, 190), 16)
	task.spawn(function()
		local t = (data and data.returnIn) or 30
		while t > 0 and countdown.Parent do
			countdown.Text = "Returning automatically in " .. t .. "s…"
			task.wait(1)
			t -= 1
		end
	end)
end)
