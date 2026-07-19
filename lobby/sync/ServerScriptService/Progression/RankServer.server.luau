--!strict
-- RankServer.server.luau — LOBBY rank display (Job 026, design Job 020 §8). Two things:
--   1) an overhead BillboardGui on each player's head (tier name in tier colour + River Score),
--   2) a physical leaderboard board (SurfaceGui) showing the global Top 10 by River Score.
-- River Score itself is earned server-side in the game (RunServer) and persisted; here we only DISPLAY it.
-- Server-built so everyone sees everyone's rank. Lobby only (in-run keeps minimal nameplates).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local RankDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("RankDefs")) :: any

local scoreBoard = DataStoreService:GetOrderedDataStore(RankDefs.BOARD_RIVERSCORE)

-- ── overhead rank tag ────────────────────────────────────────────────────────────────────────
local function buildTag(plr: Player, char: Model): (() -> ())?
	local head = char:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return nil
	end
	local existing = head:FindFirstChild("RankTag")
	if existing then
		existing:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RankTag"
	bb.Size = UDim2.fromScale(6, 1.7)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Size = UDim2.fromScale(1, 0.55)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Enum.Font.GothamBold
	tierLabel.TextScaled = true
	tierLabel.Text = ""
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = Color3.new(0, 0, 0)
	ts.Parent = tierLabel
	tierLabel.Parent = bb

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromScale(0, 0.55)
	nameLabel.Size = UDim2.fromScale(1, 0.45)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Text = plr.DisplayName
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2
	ns.Color = Color3.new(0, 0, 0)
	ns.Parent = nameLabel
	nameLabel.Parent = bb

	bb.Parent = head

	local function render()
		local score = (plr:GetAttribute("RiverScore") :: number?) or 0
		local tier = RankDefs.tierFor(score)
		local stars = RankDefs.legendStars(score)
		tierLabel.Text = tier.name .. (stars > 0 and (" " .. string.rep("★", math.min(stars, 5))) or "")
		tierLabel.TextColor3 = tier.color
		nameLabel.Text = plr.DisplayName .. "  ·  " .. RankDefs.shortScore(score)
	end
	render()
	return render
end

local function onPlayer(plr: Player)
	local render: (() -> ())? = nil
	plr.CharacterAdded:Connect(function(char)
		render = buildTag(plr, char)
	end)
	if plr.Character then
		render = buildTag(plr, plr.Character)
	end
	plr:GetAttributeChangedSignal("RiverScore"):Connect(function()
		if render then
			render()
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerAdded:Connect(onPlayer)

-- ── leaderboard board (global Top 10 by River Score) ────────────────────────────────────────────
local board = Instance.new("Part")
board.Name = "LeaderboardBoard"
board.Anchored = true
board.CanCollide = false
board.Size = Vector3.new(24, 13, 1)
board.Color = Color3.fromRGB(24, 26, 32)
board.Material = Enum.Material.SmoothPlastic
-- raised HIGH and set back behind the pads so it clears the pads' AlwaysOnTop signs; front face
-- (+Z after 180° yaw) toward players walking in from spawn — reads as a leaderboard wall
board.CFrame = CFrame.new(0, 17, -16) * CFrame.Angles(0, math.rad(180), 0)
board.Parent = workspace

local sg = Instance.new("SurfaceGui")
sg.Name = "BoardGui"
sg.Face = Enum.NormalId.Front
sg.CanvasSize = Vector2.new(600, 380)
sg.Parent = board

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.14)
title.BackgroundColor3 = Color3.fromRGB(245, 197, 66)
title.TextColor3 = Color3.fromRGB(20, 20, 24)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Text = "TOP RIVER LEGENDS"
title.Parent = sg

local rows = Instance.new("Frame")
rows.Position = UDim2.fromScale(0, 0.15)
rows.Size = UDim2.fromScale(1, 0.85)
rows.BackgroundTransparency = 1
rows.Parent = sg
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = rows

local nameCache: { [number]: string } = {}
local function nameFor(uid: number): string
	if nameCache[uid] then
		return nameCache[uid]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(uid)
	end)
	local name = (ok and n) or ("User " .. uid)
	nameCache[uid] = name
	return name
end

local function refresh()
	local ok, pages = pcall(function()
		return scoreBoard:GetSortedAsync(false, 10)
	end)
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if not ok or not pages then
		local err = Instance.new("TextLabel")
		err.LayoutOrder = 1
		err.Size = UDim2.fromScale(1, 0.09)
		err.BackgroundTransparency = 1
		err.Font = Enum.Font.Gotham
		err.TextColor3 = Color3.fromRGB(200, 200, 210)
		err.TextScaled = true
		err.Text = "No scores yet — finish a run!"
		err.Parent = rows
		return
	end
	local top = pages:GetCurrentPage()
	if #top == 0 then
		local none = Instance.new("TextLabel")
		none.LayoutOrder = 1
		none.Size = UDim2.fromScale(1, 0.09)
		none.BackgroundTransparency = 1
		none.Font = Enum.Font.Gotham
		none.TextColor3 = Color3.fromRGB(200, 200, 210)
		none.TextScaled = true
		none.Text = "No scores yet — finish a run!"
		none.Parent = rows
		return
	end
	for rank, entry in ipairs(top) do
		local uid = tonumber(entry.key) or 0
		local score = entry.value :: number
		local tier = RankDefs.tierFor(score)
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.fromScale(1, 0.092)
		row.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
		row.BackgroundTransparency = rank % 2 == 0 and 0.35 or 0.1
		row.Font = Enum.Font.GothamMedium
		row.TextColor3 = tier.color
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("  %d.  %s   —   %s  (%s)", rank, nameFor(uid), RankDefs.shortScore(score), tier.name)
		row.Parent = rows
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(30)
	end
end)

print("[Rank] lobby overhead tags + leaderboard board online")
