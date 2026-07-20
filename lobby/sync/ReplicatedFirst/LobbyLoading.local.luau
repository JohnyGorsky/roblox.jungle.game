--!strict
-- LobbyLoading.local.luau — lobby game loading screen (Job 041, todo 0006). Ref roblox.defender's
-- ReplicatedFirst/Loading. Removes the default Roblox loading screen, shows a simple custom screen (built in
-- code — a design pass replaces the visuals later), WAITS for full replication, preloads all assets with a
-- progress bar, lets the scene settle (texture streaming + Future lighting), then fades out and reveals the
-- lobby. Runs from ReplicatedFirst so it's up before anything else replicates.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local MIN_SHOWN = 1.5  -- keep the screen up at least this long so it never just flickers
local SETTLE = 2.5     -- after preload, hold so texture streaming + lighting/shadows finish behind the screen
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
bg.BackgroundColor3 = Color3.fromRGB(12, 18, 16) -- deep jungle-night (fallback behind the image)
bg.BorderSizePixel = 0
bg.Parent = gui

-- background art (fills the screen; cropped to cover any aspect)
local bgImage = Instance.new("ImageLabel")
bgImage.Name = "BgImage"
bgImage.Size = UDim2.fromScale(1, 1)
bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://73636751330777"
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
	"Step on a LAUNCH PAD to form a party — whoever's first on it leads the run.",
	"Upgrade your boat at BOAT UPGRADES: twin motors, hull armor, extra fuel, a searchlight.",
	"Crews win: split into Driver, Gunner, Engineer, Mechanic and Medic.",
	"Weave around rocks and logs — hitting them damages the hull and slows you down.",
	"Watch your FUEL — run dry mid-river and the run is over.",
	"Night falls on the river. A searchlight or a carried torch keeps you from going blind.",
	"Spend gold on SKILLS to get better at your chosen role.",
	"Check BOUNTIES for extra objectives and bonus rewards.",
	"Glowing eyes in the dark are enemies — spot them before they reach the boat.",
	"The Medic can revive downed crew. Never leave a teammate behind.",
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

-- ── 1) wait for FULL replication before doing anything else ──────────────────────────────────────────────
-- Gathering assets before this only sees the early fraction that has replicated — which is exactly why
-- textures/lights popped in AFTER the reveal. Waiting for game.Loaded first means the descendant list below
-- is complete (guaranteed now that the lobby has StreamingEnabled = false).
local startedAt = os.clock()
setProgress(0.10, "Connecting...")
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ── 2) preload everything players see/hear (downloads meshes/textures/images/sounds at full res) ─────────
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
		setProgress(0.10 + (i - 1) / total * 0.75, "Loading assets... " .. math.floor((i - 1) / total * 100) .. "%")
	end
end

-- ── 3) settle: let texture streaming + Future-lighting voxelization (shadows/atmosphere/lights) finish ───
-- behind the screen, so the revealed scene is fully lit and sharp instead of resolving in front of the player.
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

-- ── fade out and reveal the lobby ───────────────────────────────────────────────────────────────────────
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
