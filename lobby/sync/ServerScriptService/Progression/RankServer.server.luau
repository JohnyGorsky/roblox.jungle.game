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
-- Theme is tokens only (no instances), so it is safe to read from a server script (Job 065)
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

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

	-- Job 065: the player nameplate is a small wood-bordered dog-tag rather than bare floating text, so
	-- it belongs to the same world as the signage around it. Theme is client/server-safe (tokens only,
	-- no instances), so a server script can read the palette too.
	local bb = Instance.new("BillboardGui")
	bb.Name = "RankTag"
	bb.Size = UDim2.fromScale(4.2, 1.15)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	-- You don't need your own name floating in front of you — it just blocks the view of the airfield.
	-- Everyone ELSE still sees it, which is the point of a rank tag.
	bb.PlayerToHideFrom = plr

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Theme.color.panel
	plate.BackgroundTransparency = 0.25
	plate.BorderSizePixel = 0
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0, 8)
	plateCorner.Parent = plate
	local plateStroke = Instance.new("UIStroke")
	plateStroke.Color = Theme.color.wood
	plateStroke.Thickness = 2
	plateStroke.Parent = plate
	plate.Parent = bb

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "Tier"
	tierLabel.Position = UDim2.fromScale(0.04, 0.06)
	tierLabel.Size = UDim2.fromScale(0.92, 0.5)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Theme.font.heading
	tierLabel.TextScaled = true
	tierLabel.Text = ""
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = Theme.color.stroke
	ts.Parent = tierLabel
	tierLabel.Parent = plate

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position = UDim2.fromScale(0.04, 0.56)
	nameLabel.Size = UDim2.fromScale(0.92, 0.38)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Theme.font.body
	nameLabel.TextColor3 = Theme.color.cream -- §5: cream, never pure white
	nameLabel.TextScaled = true
	nameLabel.Text = plr.DisplayName
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2
	ns.Color = Theme.color.stroke
	ns.Parent = nameLabel
	nameLabel.Parent = plate

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
-- Prefer the EDITOR-placed board (find-by-name, per Job 064 pivot); fall back to a generated wall
-- so the leaderboard still shows if the editor board is missing.
local board: BasePart
local displays = workspace:FindFirstChild("LOBBY_GREYBOX") and workspace.LOBBY_GREYBOX:FindFirstChild("Displays")
local editorLb = displays and displays:FindFirstChild("Leaderboard_TopRuns")
local editorBoardPart = editorLb and editorLb:FindFirstChild("Board")
if editorBoardPart and editorBoardPart:IsA("BasePart") then
	board = editorBoardPart
else
	board = Instance.new("Part")
	board.Name = "LeaderboardBoard"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(24, 13, 1)
	board.Color = Color3.fromRGB(36, 53, 45)
	board.Material = Enum.Material.WoodPlanks
	board.CFrame = CFrame.new(0, 17, -16) * CFrame.Angles(0, math.rad(180), 0)
	board.Parent = workspace
end

-- pick the board face pointing toward the lobby centre so text reads for approaching players
local function faceToward(part: BasePart, target: Vector3): Enum.NormalId
	-- big faces = the two normals along the part's THINNEST axis (the flat board faces);
	-- pick whichever points more toward the target so text reads for approaching players.
	local s = part.Size
	local candidates
	if s.Z <= s.X and s.Z <= s.Y then
		candidates = { Enum.NormalId.Front, Enum.NormalId.Back }
	elseif s.X <= s.Y then
		candidates = { Enum.NormalId.Right, Enum.NormalId.Left }
	else
		candidates = { Enum.NormalId.Top, Enum.NormalId.Bottom }
	end
	local best, bestDot = candidates[1], -math.huge
	for _, nid in ipairs(candidates) do
		local n = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(nid))
		local d = n:Dot((target - part.Position).Unit)
		if d > bestDot then bestDot, best = d, nid end
	end
	return best
end

for _, g in ipairs(board:GetChildren()) do
	if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then g:Destroy() end
end
local sg = Instance.new("SurfaceGui")
sg.Name = "BoardGui"
sg.Face = faceToward(board, Vector3.new(0, board.Position.Y, 0))
sg.CanvasSize = Vector2.new(700, 400)
sg.Parent = board

-- backing panel (dark jungle UI) so cream text reads on the wood
local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(1, 1)
panel.BackgroundColor3 = Color3.fromRGB(36, 53, 45)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.16)
title.BackgroundColor3 = Color3.fromRGB(214, 155, 34) -- gold (progression)
title.BorderSizePixel = 0
title.TextColor3 = Color3.fromRGB(36, 26, 14)
title.Font = Enum.Font.Oswald
title.TextScaled = true
title.Text = "TOP RIVER LEGENDS"
title.Parent = panel

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
		err.Font = Theme.font.body
		err.TextColor3 = Theme.color.creamDim
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
		none.Font = Theme.font.body
		none.TextColor3 = Theme.color.creamDim
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
		if rank == 1 then
			-- #1 glow: gold plate + glowing stroke
			row.BackgroundColor3 = Color3.fromRGB(214, 155, 34)
			row.BackgroundTransparency = 0.08
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(255, 224, 120)
			st.Thickness = 2
			st.Parent = row
		end
		row.Font = Theme.font.body
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
