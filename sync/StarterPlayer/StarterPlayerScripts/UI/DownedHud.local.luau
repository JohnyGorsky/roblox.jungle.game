--!strict
-- DownedHud.local.luau — the DOWNED overlay + paid self-revive (Job 067).
--
-- Until this existed, going down had NO client feedback whatsoever: you simply stopped being able to move,
-- with nothing telling you why, how long you had, or that a teammate could pick you up. That was worth
-- fixing on its own; the paid revive is one button inside it.
--
-- Reads the character attributes PlayerCombat publishes — `Downed` and `BleedOutAt` (a wall-clock
-- os.time() deadline, so the client can count down without a per-frame server tick).
--
-- ⚠️ STYLING: the GAME place has NO design system — Theme/Components are lobby-only and this HUD is still
-- greybox, like every other HUD here (P9 job). The palette below is lifted from the lobby's Theme.color so
-- the two places don't look like different games in the meantime; when the design system lands in the game
-- tree, delete these constants and use the real components.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any

local player = Players.LocalPlayer

-- lifted from lobby Theme.color (see the styling note above)
local CREAM = Color3.fromRGB(243, 230, 194)
local CREAM_DIM = Color3.fromRGB(188, 178, 150)
local PANEL = Color3.fromRGB(28, 34, 28)
local DANGER = Color3.fromRGB(178, 70, 55)
local GOLD = Color3.fromRGB(214, 168, 74)

local selfReviveProduct = MonetizationDefs.product("selfRevive")

local gui = Instance.new("ScreenGui")
gui.Name = "DownedHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- a red vignette so being downed reads instantly, before any text is parsed
local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = DANGER
vignette.BackgroundTransparency = 0.78
vignette.BorderSizePixel = 0
vignette.ZIndex = 1
vignette.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromScale(0.42, 0.26)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.1
card.BorderSizePixel = 0
card.ZIndex = 2
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Color = DANGER
cardStroke.Thickness = 3
cardStroke.Parent = card
card.Parent = gui

local title = Instance.new("TextLabel")
title.Position = UDim2.fromScale(0.05, 0.08)
title.Size = UDim2.fromScale(0.9, 0.22)
title.BackgroundTransparency = 1
title.Font = Enum.Font.BuilderSansBold
title.TextColor3 = CREAM
title.TextScaled = true
title.Text = "YOU ARE DOWN"
title.ZIndex = 3
local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MaxTextSize = 34
titleSize.Parent = title
title.Parent = card

local timer = Instance.new("TextLabel")
timer.Position = UDim2.fromScale(0.05, 0.3)
timer.Size = UDim2.fromScale(0.9, 0.26)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.BuilderSansBold
timer.TextColor3 = DANGER
timer.TextScaled = true
timer.Text = ""
timer.ZIndex = 3
local timerSize = Instance.new("UITextSizeConstraint")
timerSize.MaxTextSize = 44
timerSize.Parent = timer
timer.Parent = card

local hint = Instance.new("TextLabel")
hint.Position = UDim2.fromScale(0.05, 0.55)
hint.Size = UDim2.fromScale(0.9, 0.14)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.BuilderSans
hint.TextColor3 = CREAM_DIM
hint.TextScaled = true
hint.Text = "A teammate can revive you with a bandage."
hint.ZIndex = 3
local hintSize = Instance.new("UITextSizeConstraint")
hintSize.MaxTextSize = 18
hintSize.Parent = hint
hint.Parent = card

local buyButton = Instance.new("TextButton")
buyButton.AnchorPoint = Vector2.new(0.5, 1)
buyButton.Position = UDim2.fromScale(0.5, 0.94)
buyButton.Size = UDim2.fromScale(0.66, 0.24)
buyButton.BackgroundColor3 = GOLD
buyButton.AutoButtonColor = true
buyButton.Font = Enum.Font.BuilderSansBold
buyButton.TextColor3 = Color3.fromRGB(28, 24, 14)
buyButton.TextScaled = true
buyButton.ZIndex = 3
buyButton.Text = "GET UP — R$ " .. tostring((selfReviveProduct and selfReviveProduct.robux) or "?")
local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent = buyButton
local buySize = Instance.new("UITextSizeConstraint")
buySize.MaxTextSize = 24
buySize.Parent = buyButton
-- Hidden entirely when the product hasn't been created on the Creator Hub yet (productId 0) — the same
-- "unset ids never render a dead button" rule the Robux shop follows.
buyButton.Visible = selfReviveProduct ~= nil and selfReviveProduct.productId > 0
buyButton.Parent = card

buyButton.Activated:Connect(function()
	if not selfReviveProduct or selfReviveProduct.productId <= 0 then
		return
	end
	-- No custom confirm: MarketplaceService shows Roblox's own purchase dialog, and a second popup on top
	-- of a bleed-out timer would be actively hostile.
	MarketplaceService:PromptProductPurchase(player, selfReviveProduct.productId)
end)

-- ── drive from the character's attributes ────────────────────────────────────────────────────────

local conn: RBXScriptConnection? = nil

local function stopTicking()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

local function watch(char: Model)
	stopTicking()
	gui.Enabled = false

	local function update()
		local downed = char:GetAttribute("Downed") == true
		gui.Enabled = downed
		if not downed then
			stopTicking()
			return
		end
		if conn then
			return
		end
		conn = RunService.Heartbeat:Connect(function()
			local deadline = char:GetAttribute("BleedOutAt") :: number?
			if not deadline then
				timer.Text = ""
				return
			end
			local left = math.max(0, deadline - os.time())
			timer.Text = string.format("%d", left)
			-- the last 10 seconds pulse, so panic-buying is a decision and not a surprise
			timer.TextTransparency = if left <= 10 then 0.25 + 0.25 * math.sin(os.clock() * 8) else 0
		end)
	end

	char:GetAttributeChangedSignal("Downed"):Connect(update)
	update()
end

if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)
