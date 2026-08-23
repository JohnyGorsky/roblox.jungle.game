--!strict
-- DownedHud.local.luau — the DOWNED overlay + paid self-revive (Job 067, put on the design system in
-- Job #075).
--
-- Until this existed, going down had NO client feedback whatsoever: you simply stopped being able to
-- move, with nothing telling you why, how long you had, or that a teammate could pick you up. That was
-- worth fixing on its own; the paid revive is one button inside it.
--
-- Reads the character attributes PlayerCombat publishes — `Downed` and `BleedOutAt` (a wall-clock
-- os.time() deadline, so the client can count down without a per-frame server tick).
--
-- Job #075 closes the note its own header used to carry: *"the GAME place has NO design system —
-- Theme/Components are lobby-only and this HUD is still greybox... when the design system lands in the
-- game tree, delete these constants and use the real components."* Done — the five hand-copied Color3
-- constants are gone and this is built from Components like everything else.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local PANIC_SECONDS = 10 -- the tail of the bleed-out where the timer starts pulsing

local player = Players.LocalPlayer
local selfReviveProduct = MonetizationDefs.product("selfRevive")

local gui = Components.screen("DownedHud", player:WaitForChild("PlayerGui"))
-- 30, above the 20 that panels use. Found in the Job #075 playtest: with both at 20 the DOWNED card and
-- an open Trading Post interleaved — the shop's scrim sat over the red vignette and its rows showed
-- through the card. Bleeding out has to cover everything except the end-of-run screen.
gui.DisplayOrder = 30
gui.ScreenInsets = Enum.ScreenInsets.None -- the vignette has to reach the real screen edge
gui.Enabled = false

-- a red vignette so being downed reads instantly, before any text is parsed
local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Theme.color.red
vignette.BackgroundTransparency = 0.78
vignette.BorderSizePixel = 0
vignette.ZIndex = 1
vignette.Active = false
vignette.Parent = gui

local card = RunComponents.card({
	name = "DownedCard",
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
	size = UDim2.fromScale(0.42, 0.28),
	accent = Theme.color.red,
	transparency = 0.05,
	parent = gui,
})
card.ZIndex = 2

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(300, 190)
clamp.MaxSize = Vector2.new(620, 380)
clamp.Parent = card

local skull = Components.icon({ name = "skull", size = UDim2.fromScale(0.14, 0.26), parent = card })
skull.AnchorPoint = Vector2.new(0.5, 0)
skull.Position = UDim2.fromScale(0.5, 0.04)
skull.ZIndex = 3

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromScale(0.05, 0.3)
title.Size = UDim2.fromScale(0.9, 0.16)
title.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(title, Theme.text.h1, Theme.font.display)
title.Text = "YOU ARE DOWN"
title.ZIndex = 3
title.Parent = card

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.Position = UDim2.fromScale(0.05, 0.44)
timer.Size = UDim2.fromScale(0.9, 0.22)
timer.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(timer, Theme.text.display, Theme.font.display)
timer.TextColor3 = Theme.color.red
timer.Text = ""
timer.ZIndex = 3
timer.Parent = card

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Position = UDim2.fromScale(0.05, 0.65)
hint.Size = UDim2.fromScale(0.9, 0.1)
hint.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(hint, Theme.text.caption, Theme.font.body)
hint.TextColor3 = Theme.color.creamDim
hint.Text = "A teammate can revive you with a bandage."
hint.ZIndex = 3
hint.Parent = card

-- Hidden entirely when the product hasn't been created on the Creator Hub yet (productId 0) — the same
-- "unset ids never render a dead button" rule the Robux shop follows.
local canBuy = selfReviveProduct ~= nil and selfReviveProduct.productId > 0

local buy = Components.button({
	text = "GET UP — R$ " .. tostring((selfReviveProduct and selfReviveProduct.robux) or "?"),
	variant = "gold",
	icon = "robux",
	size = UDim2.fromScale(0.66, 0.17),
	parent = card,
	onActivated = function()
		if not canBuy then
			return
		end
		-- No custom confirm: MarketplaceService shows Roblox's own purchase dialog, and a second popup
		-- on top of a bleed-out timer would be actively hostile.
		MarketplaceService:PromptProductPurchase(player, (selfReviveProduct :: any).productId)
	end,
})
buy.instance.AnchorPoint = Vector2.new(0.5, 1)
buy.instance.Position = UDim2.fromScale(0.5, 0.95)
buy.instance.ZIndex = 3
buy.instance.Visible = canBuy

-- ── drive from the character's attributes ────────────────────────────────────────────────────────

local conn: RBXScriptConnection? = nil

local function stopTicking()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

-- ── Job #103: the post-revive grace chip ─────────────────────────────────────────────────────────
--
-- Getting up is only half the payoff; the other half is knowing you have ten seconds to get OUT. Without
-- a readout the window passes unnoticed and the player stands still through the one thing that was bought
-- for them — which is exactly the complaint this job came from (*"you respawn by robux and instantly
-- killed"*).
--
-- ⚠️ ITS OWN ScreenGui, NOT part of the downed card. `gui.Enabled = downed` above, so anything parented
-- to that gui is switched OFF at the precise moment this needs to switch ON.
--
-- Sits at y 0.36 to clear `ZoneBanner`, which occupies 0.17–0.34 and can fire on the same frame (a zone
-- crossing does not wait for you to finish being revived).
local graceGui = Components.screen("ReviveGraceHud", player:WaitForChild("PlayerGui"))
graceGui.DisplayOrder = 29 -- under the downed card (30), over ordinary panels (20)
graceGui.Enabled = false

local graceChip = RunComponents.card({
	name = "GraceChip",
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.36),
	size = UDim2.fromScale(0.24, 0.07),
	accent = Theme.color.gold,
	transparency = 0.1,
	parent = graceGui,
})

local graceClamp = Instance.new("UISizeConstraint")
graceClamp.MinSize = Vector2.new(190, 46)
graceClamp.MaxSize = Vector2.new(360, 88)
graceClamp.Parent = graceChip

local graceIcon = Components.icon({ name = "hull", size = UDim2.fromScale(0.16, 0.62), parent = graceChip })
graceIcon.AnchorPoint = Vector2.new(0, 0.5)
graceIcon.Position = UDim2.fromScale(0.06, 0.5)
graceIcon.ZIndex = 3

local graceText = Instance.new("TextLabel")
graceText.Name = "GraceText"
graceText.AnchorPoint = Vector2.new(0, 0.5)
graceText.Position = UDim2.fromScale(0.27, 0.5)
graceText.Size = UDim2.fromScale(0.68, 0.7)
graceText.BackgroundTransparency = 1
graceText.TextXAlignment = Enum.TextXAlignment.Left
-- Same helper every other label in this file uses, so the size clamps and the dark stroke come from the
-- design system rather than being hand-set here.
Components.applyText(graceText, Theme.text.h2, Theme.font.display)
graceText.TextColor3 = Theme.color.gold
graceText.Text = "INVULNERABLE"
graceText.ZIndex = 3
graceText.Parent = graceChip

local graceConn: RBXScriptConnection? = nil

local function watchGrace(char: Model)
	if graceConn then
		graceConn:Disconnect()
		graceConn = nil
	end
	graceGui.Enabled = false
	graceConn = RunService.Heartbeat:Connect(function()
		local until_ = char:GetAttribute("InvincibleUntil") :: number?
		-- Same float server clock the deadline was stamped on, so the number on screen and the moment
		-- damage actually resumes are the same instant. See PlayerCombat's note.
		local left = if until_ then until_ - Workspace:GetServerTimeNow() else 0
		-- Job #111: the extraction stamps a LONG deadline (it has to outlast the 30 s results screen), so
		-- without this the chip would sit next to the VICTORY panel counting down from ~300. Once the run
		-- is over the number is true but meaningless — there is nothing left to run from.
		if Workspace:GetAttribute("RunEnded") == true then
			graceGui.Enabled = false
			return
		end
		-- Job #112: admin god mode re-stamps the deadline every 0.25 s, so the chip would sit on screen
		-- for the whole session flickering an 8-second countdown that never runs out.
		if char:GetAttribute("AdminGod") == true then
			graceGui.Enabled = false
			return
		end
		if left <= 0 then
			graceGui.Enabled = false
			return
		end
		graceGui.Enabled = true
		graceText.Text = ("INVULNERABLE  %d"):format(math.ceil(left))
		-- pulses through the whole window, not just the tail: the point is "move NOW", and a static chip
		-- reads as a status rather than as a clock running out.
		graceText.TextTransparency = 0.12 + 0.12 * math.sin(os.clock() * 7)
	end)
end

local function watch(char: Model)
	stopTicking()
	watchGrace(char)
	gui.Enabled = false

	local wasDowned = false

	local function update()
		local downed = char:GetAttribute("Downed") == true
		gui.Enabled = downed

		if downed and not wasDowned then
			UISound.play("downed")
			TweenService:Create(vignette, Theme.tween.slow, { BackgroundTransparency = 0.78 }):Play()
			-- You cannot shop while bleeding out, and a panel left open behind the overlay is just
			-- clutter over the one screen that now matters (§6.11).
			Components.closeAllPanels()
		elseif not downed and wasDowned then
			-- Getting back up is the payoff for a teammate's bandage or a purchase — it deserves the
			-- cue as much as going down does.
			UISound.play("revived")
		end
		wasDowned = downed

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
			timer.Text = ("%d"):format(left)
			-- the last seconds pulse, so panic-buying is a decision and not a surprise
			timer.TextTransparency = if left <= PANIC_SECONDS
				then 0.25 + 0.25 * math.sin(os.clock() * 8)
				else 0
		end)
	end

	char:GetAttributeChangedSignal("Downed"):Connect(update)
	update()
end

if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)
