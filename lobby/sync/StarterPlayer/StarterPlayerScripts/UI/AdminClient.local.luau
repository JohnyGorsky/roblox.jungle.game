--!strict
-- AdminClient.local.luau — admin panel UI (Job 031). Only builds for allowlisted users. Pick a target
-- (yourself or another player) and grant Gold / River Score / Salvage / all modules / max skills. The
-- server re-checks the allowlist on every action. IDENTICAL copy in both trees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
if not AdminDefs.isAdmin(player.UserId) then
	return -- not an admin → no UI at all
end
local rf = ReplicatedStorage:WaitForChild("Admin") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Parent = player:WaitForChild("PlayerGui")

local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(1, 1)
openBtn.Position = UDim2.new(1, -14, 1, -14)
openBtn.Size = UDim2.fromScale(0.12, 0.05)
openBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 120)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextScaled = true
openBtn.Text = "ADMIN"
local obc = Instance.new("UICorner")
obc.CornerRadius = UDim.new(0, 8)
obc.Parent = openBtn
local obar = Instance.new("UIAspectRatioConstraint")
obar.AspectRatio = 3.4
obar.Parent = openBtn
local obtsc = Instance.new("UITextSizeConstraint")
obtsc.MaxTextSize = 16
obtsc.Parent = openBtn
openBtn.Parent = gui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Visible = false
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.44, 0.6)
panel.BackgroundColor3 = Color3.fromRGB(26, 20, 30)
panel.Parent = dim
local pcc = Instance.new("UICorner")
pcc.CornerRadius = UDim.new(0, 14)
pcc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(210, 130, 220)
title.TextScaled = true
title.Text = "ADMIN PANEL"
local ttsc = Instance.new("UITextSizeConstraint")
ttsc.MaxTextSize = 24
ttsc.Parent = title
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -8, 0, 8)
closeBtn.Size = UDim2.fromScale(0.1, 0.1)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Text = "X"
local cbc = Instance.new("UICorner")
cbc.CornerRadius = UDim.new(0, 8)
cbc.Parent = closeBtn
closeBtn.Parent = panel

-- target selector (cycles Me + current players)
local targets: { { name: string, userId: number } } = {}
local targetIdx = 1

local targetBtn = Instance.new("TextButton")
targetBtn.Position = UDim2.fromScale(0.06, 0.16)
targetBtn.Size = UDim2.fromScale(0.88, 0.12)
targetBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
targetBtn.Font = Enum.Font.GothamBold
targetBtn.TextColor3 = Color3.new(1, 1, 1)
targetBtn.TextScaled = true
targetBtn.Text = "Target: (loading…)"
local tbc = Instance.new("UICorner")
tbc.CornerRadius = UDim.new(0, 8)
tbc.Parent = targetBtn
local tbtsc = Instance.new("UITextSizeConstraint")
tbtsc.MaxTextSize = 16
tbtsc.Parent = targetBtn
targetBtn.Parent = panel

local function refreshTargets()
	targets = { { name = player.DisplayName .. " (me)", userId = player.UserId } }
	local ok, res = pcall(function()
		return rf:InvokeServer("players")
	end)
	if ok and type(res) == "table" and res.players then
		for _, p in ipairs(res.players) do
			if p.userId ~= player.UserId then
				targets[#targets + 1] = { name = p.name, userId = p.userId }
			end
		end
	end
	if targetIdx > #targets then
		targetIdx = 1
	end
	targetBtn.Text = "Target: " .. targets[targetIdx].name .. "  >"
end

targetBtn.Activated:Connect(function()
	if #targets == 0 then
		return
	end
	targetIdx = (targetIdx % #targets) + 1
	targetBtn.Text = "Target: " .. targets[targetIdx].name .. "  >"
end)

-- action buttons
local actions = {
	{ label = "+1000 Gold", kind = "gold", amount = 1000 },
	{ label = "+10000 River Score", kind = "score", amount = 10000 },
	{ label = "+1000 Salvage (in-run)", kind = "salvage", amount = 1000 },
	{ label = "Unlock ALL Modules", kind = "allModules", amount = 0 },
	{ label = "MAX ALL Skills", kind = "maxSkills", amount = 0 },
}

local list = Instance.new("Frame")
list.Position = UDim2.fromScale(0.06, 0.32)
list.Size = UDim2.fromScale(0.88, 0.62)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = list

for i, a in ipairs(actions) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = Color3.fromRGB(70, 50, 90)
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = a.label
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = b
	local btsc = Instance.new("UITextSizeConstraint")
	btsc.MaxTextSize = 16
	btsc.Parent = b
	b.Parent = list
	b.Activated:Connect(function()
		local tgt = targets[targetIdx]
		if not tgt then
			return
		end
		b.Text = "…"
		pcall(function()
			rf:InvokeServer("give", { targetUserId = tgt.userId, kind = a.kind, amount = a.amount })
		end)
		b.Text = a.label
	end)
end

openBtn.Activated:Connect(function()
	refreshTargets()
	dim.Visible = true
end)
closeBtn.Activated:Connect(function()
	dim.Visible = false
end)
