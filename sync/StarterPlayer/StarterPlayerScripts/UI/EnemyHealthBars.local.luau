--!strict
-- EnemyHealthBars.local.luau — floating HP bar over every enemy (Job 006+ follow-up).
-- Client-side BillboardGui driven by each enemy's HP/MaxHP attributes (which replicate). Greybox.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

type Bar = { gui: BillboardGui, fill: Frame, model: Instance }
local bars: { [Instance]: Bar } = {}

local function makeBar(model: Instance)
	if bars[model] or not model:IsA("Model") then
		return
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not part then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(90, 12)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Adornee = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	local bgC = Instance.new("UICorner")
	bgC.CornerRadius = UDim.new(0, 4)
	bgC.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 70, 60)
	fill.BorderSizePixel = 0
	local fC = Instance.new("UICorner")
	fC.CornerRadius = UDim.new(0, 4)
	fC.Parent = fill
	fill.Parent = bg

	bg.Parent = gui
	gui.Parent = part
	bars[model] = { gui = gui, fill = fill, model = model }
end

for _, tag in ipairs({ "Enemy", "CampGuard" }) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		makeBar(m)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(makeBar)
end

RunService.Heartbeat:Connect(function()
	for model, b in pairs(bars) do
		if not model.Parent then
			b.gui:Destroy()
			bars[model] = nil
		else
			local hp = (model:GetAttribute("HP") :: number?) or 0
			local max = (model:GetAttribute("MaxHP") :: number?) or 1
			local r = math.clamp(hp / math.max(max, 1), 0, 1)
			b.fill.Size = UDim2.fromScale(r, 1)
			b.fill.BackgroundColor3 = if r > 0.5
				then Color3.fromRGB(90, 200, 110)
				elseif r > 0.25 then Color3.fromRGB(230, 180, 60)
				else Color3.fromRGB(220, 70, 60)
		end
	end
end)
