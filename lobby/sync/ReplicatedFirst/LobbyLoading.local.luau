--!strict
-- LobbyLoading.local.luau — lobby game loading screen (Job 041, todo 0006). Ref roblox.defender's
-- ReplicatedFirst/Loading. Removes the default Roblox loading screen, shows a simple custom screen (built in
-- code — a design pass replaces the visuals later), preloads assets with a progress bar + status text, WAITS
-- until the game is fully loaded, then fades out and reveals the lobby. Runs from ReplicatedFirst so it's up
-- before anything else replicates.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local MIN_SHOWN = 1.5 -- keep the screen up at least this long so it never just flickers
local FADE_TIME = 0.6

local player = Players.LocalPlayer

-- take over from the default loading screen as early as possible
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- hide the core game HUD while loading; restore on finish
local function setCoreGui(show: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, show)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, show)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, show)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, show)
	end)
end
setCoreGui(false)

-- ── build a simple loading GUI in code (greybox; real design later) ──────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "LobbyLoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local bg = Instance.new("Frame")
bg.Name = "Backdrop"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(12, 18, 16) -- deep jungle-night
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 1)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.fromScale(0.8, 0.12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "LAST RIVER"
title.TextColor3 = Color3.fromRGB(230, 240, 232)
title.TextScaled = true
title.Parent = bg

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.55)
status.Size = UDim2.fromScale(0.6, 0.05)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = "Loading..."
status.TextColor3 = Color3.fromRGB(150, 170, 158)
status.TextScaled = true
status.Parent = bg

-- progress bar track
local track = Instance.new("Frame")
track.Name = "BarTrack"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.62)
track.Size = UDim2.fromScale(0.4, 0.02)
track.BackgroundColor3 = Color3.fromRGB(30, 40, 36)
track.BorderSizePixel = 0
track.Parent = bg
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "BarFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(90, 190, 130) -- river green
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

local function setProgress(p: number, text: string?)
	p = math.clamp(p, 0, 1)
	fill.Size = UDim2.fromScale(p, 1)
	if text then
		status.Text = text
	end
end

-- ── preload assets, then wait for the whole game to finish loading ───────────────────────────────────────
local startedAt = os.clock()

-- gather the containers players actually see/hear so PreloadAsync warms them
local containers = {
	game:GetService("Workspace"),
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterGui"),
	game:GetService("Lighting"),
	game:GetService("SoundService"),
}

local assets: { Instance } = {}
for _, c in containers do
	for _, d in c:GetDescendants() do
		table.insert(assets, d)
	end
end

local total = #assets
if total > 0 then
	-- preload in small batches so the bar advances smoothly instead of one big stall
	local batchSize = math.max(1, math.floor(total / 40))
	local i = 1
	while i <= total do
		local batch = {}
		for j = i, math.min(i + batchSize - 1, total) do
			table.insert(batch, assets[j])
		end
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		i += #batch
		setProgress((i - 1) / total * 0.9, "Loading assets... " .. math.floor((i - 1) / total * 100) .. "%")
	end
end

-- make sure the client has fully replicated before we reveal
setProgress(0.92, "Finishing up...")
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- honour the minimum on-screen time
local elapsed = os.clock() - startedAt
if elapsed < MIN_SHOWN then
	task.wait(MIN_SHOWN - elapsed)
end

setProgress(1, "Ready")
task.wait(0.25)

-- ── fade out and reveal the lobby ───────────────────────────────────────────────────────────────────────
local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, info, { TextTransparency = 1 }):Play()
TweenService:Create(status, info, { TextTransparency = 1 }):Play()
TweenService:Create(track, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, info, { BackgroundTransparency = 1 }):Play()

task.wait(FADE_TIME)
setCoreGui(true)
gui:Destroy()
