--!strict
-- EnemyHealthBars.local.luau — floating HP bar over every enemy (Job 006+ follow-up, on-palette in
-- Job #075). Client-side BillboardGui driven by each enemy's HP/MaxHP attributes (which replicate).
--
-- GAME.md lists these as a design commitment: *"a floating HP bar over each enemy so you can read how
-- close it is to dying."* The green/amber/red banding is that reading, so it stays — it just uses the
-- palette's own three accents now instead of three invented RGB triples.
--
-- Two behaviour fixes that came with the restyle:
--   · bars only update for enemies that are actually damaged and on screen-ish (MaxDistance already
--     culls the render; the Heartbeat loop now skips untouched full-health bars rather than rewriting
--     every bar in the world every frame);
--   · a bar hides entirely at full health, so a calm river isn't a field of full green bars. It appears
--     the moment something takes a hit — which is also the moment it becomes information.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local TICK = 0.1 -- 10 Hz is well past the point a health bar reads as smooth

type Bar = { gui: BillboardGui, fill: Frame, model: Instance }
local bars: { [Instance]: Bar } = {}

local function makeBar(model: Instance)
	if bars[model] or not model:IsA("Model") then
		return
	end
	-- 🔴 THE MODEL'S PARTS MAY NOT HAVE REPLICATED YET, AND THIS USED TO GIVE UP FOREVER.
	-- The server tags an enemy the moment it builds it, so `GetInstanceAddedSignal` can fire on the
	-- client BEFORE any BasePart inside it has arrived. The old code did `if not part then return end`
	-- with no retry, so that enemy silently never got a bar for its whole life — which is why enemies
	-- "don't have health bars" in play while the script looked fine in isolation. Measured: a freshly
	-- tagged Bandit had none while three older enemies did.
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not part then
		task.spawn(function()
			-- wait for the first part, then build. Bounded so a malformed model can't leak a thread.
			local deadline = os.clock() + 10
			while model.Parent and os.clock() < deadline do
				local p = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				if p then
					makeBar(model)
					return
				end
				task.wait(0.2)
			end
		end)
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(94, 13)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Adornee = part
	gui.Enabled = false -- shown on first damage

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Theme.color.sunken
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	Components.corner(Theme.radius.control, track)
	Components.stroke(Theme.color.stroke, Theme.strokeWidth.hairline, track)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.color.green
	fill.BorderSizePixel = 0
	Components.corner(Theme.radius.control, fill)
	fill.Parent = track

	track.Parent = gui
	gui.Parent = part
	bars[model] = { gui = gui, fill = fill, model = model }
end

for _, tag in ipairs({ "Enemy", "CampGuard" }) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		makeBar(m)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(makeBar)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	for model, bar in pairs(bars) do
		if not model.Parent then
			bar.gui:Destroy()
			bars[model] = nil
			continue
		end

		local hp = (model:GetAttribute("HP") :: number?) or 0
		local max = math.max((model:GetAttribute("MaxHP") :: number?) or 1, 1)
		local fraction = math.clamp(hp / max, 0, 1)

		-- ⚠️ VISIBILITY RULE CHANGED 2026-08-16 (user: "enemies don't have health bars").
		-- It used to be `fraction < 1` — a bar appeared only AFTER you damaged something. Combined with
		-- there being no hit feedback yet, that made combat read as having no feedback at all: you shoot,
		-- nothing visibly happens, and the bar you were looking for was hidden by design.
		--
		-- Now: visible if damaged OR close enough to matter. Distant, untouched enemies still draw
		-- nothing, so the original point — a calm river is not a field of green rectangles — survives.
		local NEAR = 140 -- studs; roughly the range at which an enemy is a threat you are aiming at
		local camPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
		local near = camPos ~= nil and (bar.model:IsA("Model") and bar.model.PrimaryPart)
			and (bar.model.PrimaryPart.Position - camPos).Magnitude <= NEAR
		bar.gui.Enabled = fraction < 1 or near == true
		if not bar.gui.Enabled then
			continue
		end

		bar.fill.Size = UDim2.fromScale(fraction, 1)
		bar.fill.BackgroundColor3 = if fraction > 0.5
			then Theme.color.green
			elseif fraction > 0.25 then Theme.color.yellow
			else Theme.color.red
	end
end)
