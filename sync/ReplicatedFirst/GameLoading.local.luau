--!strict
-- GameLoading.local.luau — GAME-place loading screen (Job 042, todo 0006/0007). Mirrors the lobby loader
-- (Job 041). Removes the default Roblox loading screen, shows the simple "LAST RIVER" screen (built in code —
-- a design pass replaces the visuals later), WAITS for full replication, preloads assets, holds through the
-- intro-readiness gate, lets the scene settle, shows rotating tips, then fades out and reveals the game.
-- Runs from ReplicatedFirst so it's up before anything else replicates.
--
-- This is STEP 1 of the bigger game-intro-sequence (Planned/game-intro-sequence.md): the startup screen that
-- MASKS all-players-joining + world-generation behind the plane scene. The IntroReady gate below is where the
-- world generator / crew-join hold plugs in. NOTE: the game world keeps StreamingEnabled ON, so PreloadAsync
-- only warms what's replicated so far — the intro gate + settle cover the rest.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MIN_SHOWN = 1.5 -- keep the screen up at least this long so it never just flickers
local SETTLE = 2.5    -- after preload/gate, hold so texture streaming + lighting/shadows finish behind the screen
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
gui.Name = "GameLoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local bg = Instance.new("Frame")
bg.Name = "Backdrop"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(12, 18, 16) -- deep jungle-night (fallback behind the image)
bg.BorderSizePixel = 0
bg.Parent = gui

-- background art (fills the screen; cropped to cover any aspect)
local bgImage = Instance.new("ImageLabel")
bgImage.Name = "BgImage"
bgImage.Size = UDim2.fromScale(1, 1)
bgImage.BackgroundTransparency = 1
-- use the image from ReplicatedFirst.LoadingBackground (author-editable in Studio); fall back to the id
local BG_FALLBACK = "rbxassetid://73636751330777"
local bgSrc = ReplicatedFirst:FindFirstChild("LoadingBackground")
local bgId = BG_FALLBACK
if bgSrc then
	if (bgSrc:IsA("Decal") or bgSrc:IsA("Texture")) and bgSrc.Texture ~= "" then
		bgId = bgSrc.Texture
	elseif (bgSrc:IsA("ImageLabel") or bgSrc:IsA("ImageButton")) and bgSrc.Image ~= "" then
		bgId = bgSrc.Image
	end
end
bgImage.Image = bgId
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.Parent = bg

-- dark scrim so the title/tips stay readable over the art
local scrim = Instance.new("Frame")
scrim.Name = "Scrim"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.fromRGB(8, 12, 10)
scrim.BackgroundTransparency = 0.4
scrim.BorderSizePixel = 0
scrim.Parent = bg

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

-- rotating gameplay tip (fills the load time with something useful to read)
local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.fromScale(0.5, 0.9)
tip.Size = UDim2.fromScale(0.72, 0.09)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.GothamMedium
tip.Text = ""
tip.TextColor3 = Color3.fromRGB(200, 214, 205)
tip.TextScaled = true
tip.TextWrapped = true
tip.TextTransparency = 1
tip.Parent = bg
local tipMax = Instance.new("UITextSizeConstraint")
tipMax.MaxTextSize = 22
tipMax.Parent = tip

local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

local function setProgress(p: number, text: string?)
	p = math.clamp(p, 0, 1)
	fill.Size = UDim2.fromScale(p, 1)
	if text then
		status.Text = text
	end
end

-- ── rotating tips: cycle useful gameplay hints while the screen is up ────────────────────────────────────
local TIPS = {
	"Weave around rocks and logs — hitting them damages the hull and slows you down.",
	"Watch your FUEL — run dry mid-river and the run is over.",
	"Crews win: split into Driver, Gunner, Engineer, Mechanic and Medic.",
	"The Mechanic keeps the hull patched; the Engineer keeps the motor running.",
	"Night falls on the river. A searchlight or a carried torch keeps you from going blind.",
	"Glowing eyes in the dark are enemies — spot them before they reach the boat.",
	"The Medic can revive downed crew. Never leave a teammate behind.",
	"Read the water — currents, forks and narrows all change your line.",
	"A well-upgraded boat (motors, armor, fuel) survives far deeper down the river.",
	"Score climbs the further you push — bank a run before the boat goes down.",
}

local loading = true
task.spawn(function()
	math.randomseed(os.time())
	local idx = math.random(1, #TIPS)
	local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
	while loading do
		tip.Text = "TIP:  " .. TIPS[idx]
		TweenService:Create(tip, fade, { TextTransparency = 0 }):Play()
		idx = (idx % #TIPS) + 1
		local t0 = os.clock()
		while loading and os.clock() - t0 < 3.5 do task.wait(0.1) end
		if not loading then break end
		TweenService:Create(tip, fade, { TextTransparency = 1 }):Play()
		task.wait(0.35)
	end
end)

-- ── 1) wait for FULL replication first ───────────────────────────────────────────────────────────────────
local startedAt = os.clock()
setProgress(0.10, "Connecting...")
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ── 2) preload everything players see/hear (with streaming ON this warms the replicated region) ──────────
local containers = {
	Workspace,
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
		setProgress(0.10 + (i - 1) / total * 0.65, "Loading assets... " .. math.floor((i - 1) / total * 100) .. "%")
	end
end

-- ── 3) intro readiness gate (game-intro-sequence, Job 043) ──────────────────────────────────────────────
-- The server (IntroGateServer) holds Workspace.IntroReady == false until the whole crew has joined and the
-- world is built, publishing progress in Workspace.IntroStatus. We keep the loading screen up and mirror that
-- status. If no gate is present (IntroReady never set), this is skipped so the loader behaves standalone.
if Workspace:GetAttribute("IntroReady") == false then
	local function showStatus()
		local s = Workspace:GetAttribute("IntroStatus")
		setProgress(0.80, (type(s) == "string" and s) or "Preparing your run...")
	end
	showStatus()
	local statusConn = Workspace:GetAttributeChangedSignal("IntroStatus"):Connect(showStatus)
	while Workspace:GetAttribute("IntroReady") ~= true do
		Workspace:GetAttributeChangedSignal("IntroReady"):Wait()
	end
	statusConn:Disconnect()
end

-- ── 4) settle: let texture streaming + Future-lighting voxelization finish behind the screen ─────────────
local s0 = os.clock()
while os.clock() - s0 < SETTLE do
	setProgress(0.85 + math.clamp((os.clock() - s0) / SETTLE, 0, 1) * 0.13, "Finishing up...")
	task.wait(0.1)
end

-- honour the minimum on-screen time
local elapsed = os.clock() - startedAt
if elapsed < MIN_SHOWN then
	task.wait(MIN_SHOWN - elapsed)
end

setProgress(1, "Ready")
task.wait(0.25)

-- ── fade out and reveal the game ─────────────────────────────────────────────────────────────────────────
loading = false -- stop the tip cycler
local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(bgImage, info, { ImageTransparency = 1 }):Play()
TweenService:Create(scrim, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, info, { TextTransparency = 1 }):Play()
TweenService:Create(status, info, { TextTransparency = 1 }):Play()
TweenService:Create(track, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(tip, info, { TextTransparency = 1 }):Play()

task.wait(FADE_TIME)
setCoreGui(true)
gui:Destroy()
