--!strict
-- RetentionClient.local.luau — LOBBY daily-reward popup + weekly objectives panel (Job 028).
-- The daily reward is auto-granted server-side; this just NOTIFIES (popup). Weekly objectives are viewed +
-- claimed here through the server RemoteFunction. Greybox, mobile-safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local dailyRemote = ReplicatedStorage:WaitForChild("DailyReward") :: RemoteEvent
local weeklyRF = ReplicatedStorage:WaitForChild("Weekly") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "Retention"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

-- ── daily reward popup ──────────────────────────────────────────────────────────────────────────
dailyRemote.OnClientEvent:Connect(function(data)
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.32, 0.32)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	panel.Parent = dim
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 14)
	pc.Parent = panel

	local function line(text: string, y: number, h: number, color: Color3, max: number, bold: boolean)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.BackgroundTransparency = 1
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextColor3 = color
		l.TextScaled = true
		l.Text = text
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = max
		c.Parent = l
		l.Parent = panel
	end
	line("DAILY REWARD", 0.08, 0.18, Color3.fromRGB(245, 197, 66), 26, true)
	line(("Day %d  ·  Streak %d"):format((data and data.day) or 1, (data and data.streak) or 1), 0.32, 0.12, Color3.new(1, 1, 1), 18, false)
	line(("+ %d Gold"):format((data and data.gold) or 0), 0.46, 0.16, Color3.fromRGB(245, 197, 66), 30, true)

	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.fromScale(0.5, 0.92)
	ok.Size = UDim2.fromScale(0.5, 0.2)
	ok.BackgroundColor3 = Color3.fromRGB(60, 130, 90)
	ok.Font = Enum.Font.GothamBold
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.TextScaled = true
	ok.Text = "Collect"
	local okc = Instance.new("UICorner")
	okc.CornerRadius = UDim.new(0, 10)
	okc.Parent = ok
	local oktsc = Instance.new("UITextSizeConstraint")
	oktsc.MaxTextSize = 20
	oktsc.Parent = ok
	ok.Parent = panel
	ok.Activated:Connect(function()
		dim:Destroy()
	end)
end)

-- ── weekly objectives panel ──────────────────────────────────────────────────────────────────────
local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 14, 1, -154)
openBtn.Size = UDim2.fromScale(0.18, 0.06)
openBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextScaled = true
openBtn.Text = "WEEKLY"
local obc = Instance.new("UICorner")
obc.CornerRadius = UDim.new(0, 8)
obc.Parent = openBtn
local obar = Instance.new("UIAspectRatioConstraint")
obar.AspectRatio = 3.2
obar.Parent = openBtn
local obtsc = Instance.new("UITextSizeConstraint")
obtsc.MaxTextSize = 18
obtsc.Parent = openBtn
openBtn.Parent = gui

local wdim = Instance.new("Frame")
wdim.Size = UDim2.fromScale(1, 1)
wdim.BackgroundColor3 = Color3.new(0, 0, 0)
wdim.BackgroundTransparency = 0.5
wdim.Visible = false
wdim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.5, 0.6)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.Parent = wdim
local pcc = Instance.new("UICorner")
pcc.CornerRadius = UDim.new(0, 14)
pcc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.13)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(160, 210, 120)
title.TextScaled = true
title.Text = "WEEKLY OBJECTIVES"
local ttsc = Instance.new("UITextSizeConstraint")
ttsc.MaxTextSize = 24
ttsc.Parent = title
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -8, 0, 8)
closeBtn.Size = UDim2.fromScale(0.09, 0.1)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Text = "X"
local cbc = Instance.new("UICorner")
cbc.CornerRadius = UDim.new(0, 8)
cbc.Parent = closeBtn
closeBtn.Parent = panel

local list = Instance.new("Frame")
list.Position = UDim2.fromScale(0.04, 0.16)
list.Size = UDim2.fromScale(0.92, 0.8)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = list

local function render(objectives)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, o in ipairs(objectives or {}) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
		row.Parent = list
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromScale(0.03, 0.08)
		name.Size = UDim2.fromScale(0.6, 0.4)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		name.Text = o.name
		local ntsc = Instance.new("UITextSizeConstraint")
		ntsc.MaxTextSize = 16
		ntsc.Parent = name
		name.Parent = row

		local prog = math.min(o.progress, o.target)
		local barBg = Instance.new("Frame")
		barBg.Position = UDim2.fromScale(0.03, 0.56)
		barBg.Size = UDim2.fromScale(0.6, 0.24)
		barBg.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
		barBg.Parent = row
		local bbc = Instance.new("UICorner")
		bbc.CornerRadius = UDim.new(1, 0)
		bbc.Parent = barBg
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(prog / o.target, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(120, 200, 110)
		fill.BorderSizePixel = 0
		fill.Parent = barBg
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		local ptxt = Instance.new("TextLabel")
		ptxt.Size = UDim2.fromScale(1, 1)
		ptxt.BackgroundTransparency = 1
		ptxt.Font = Enum.Font.GothamBold
		ptxt.TextColor3 = Color3.new(1, 1, 1)
		ptxt.TextScaled = true
		ptxt.Text = ("%d / %d   (+%d G, +%d score)"):format(prog, o.target, o.gold, o.score)
		local pt = Instance.new("UITextSizeConstraint")
		pt.MaxTextSize = 12
		pt.Parent = ptxt
		ptxt.Parent = barBg

		local claim = Instance.new("TextButton")
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Position = UDim2.fromScale(0.97, 0.5)
		claim.Size = UDim2.fromScale(0.28, 0.6)
		claim.Font = Enum.Font.GothamBold
		claim.TextColor3 = Color3.new(1, 1, 1)
		claim.TextScaled = true
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = claim
		local ctsc = Instance.new("UITextSizeConstraint")
		ctsc.MaxTextSize = 15
		ctsc.Parent = claim
		claim.Parent = row

		if o.claimed then
			claim.Text = "CLAIMED"
			claim.BackgroundColor3 = Color3.fromRGB(60, 120, 70)
			claim.Active = false
			claim.AutoButtonColor = false
		elseif o.progress >= o.target then
			claim.Text = "CLAIM"
			claim.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
			claim.Active = true
		else
			claim.Text = "…"
			claim.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
			claim.Active = false
			claim.AutoButtonColor = false
		end
		claim.Activated:Connect(function()
			if not claim.Active then
				return
			end
			claim.Text = "…"
			pcall(function()
				weeklyRF:InvokeServer("claim", o.id)
			end)
			local ok, res = pcall(function()
				return weeklyRF:InvokeServer("list")
			end)
			if ok and type(res) == "table" then
				render(res.objectives)
			end
		end)
	end
end

local function openWeekly()
	local ok, res = pcall(function()
		return weeklyRF:InvokeServer("list")
	end)
	if ok and type(res) == "table" then
		render(res.objectives)
	end
	wdim.Visible = true
end

openBtn.Activated:Connect(openWeekly)
closeBtn.Activated:Connect(function()
	wdim.Visible = false
end)
