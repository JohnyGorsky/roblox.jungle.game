--!strict
-- RunClient.local.luau — spectate-on-death + the end-of-run results screen (Job 018, rebuilt on the
-- design system in Job #075).
--
-- While the run is on and you have no character (you died — permadeath), the camera spectates the boat
-- and a "you died" tag shows. On RunEnded the results panel appears (win/lose, distance, reward,
-- survivors) with a Return to Lobby button and an auto-return countdown.
--
-- The results panel is built ONCE at start-up and shown on the event, rather than constructed inside
-- the handler as it used to be. The old version leaked a whole panel tree per RunEnded fire and could
-- stack two of them if the server ever sent twice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local DEFAULT_RETURN = 30

local player = Players.LocalPlayer
local runEnded = ReplicatedStorage:WaitForChild("RunEnded") :: RemoteEvent
local returnRemote = ReplicatedStorage:WaitForChild("ReturnToLobby") :: RemoteEvent

local gui = Components.screen("RunGui", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 50

-- ── "you died — spectating" tag ──────────────────────────────────────────────────────────────────

local deadTag = RunComponents.card({
	name = "DeadTag",
	anchor = Vector2.new(0.5, 0),
	position = UDim2.fromScale(0.5, 0.03),
	size = UDim2.fromScale(0.3, 0.05),
	accent = Theme.color.red,
	parent = gui,
})
deadTag.Visible = false

local deadClamp = Instance.new("UISizeConstraint")
deadClamp.MinSize = Vector2.new(220, 32)
deadClamp.MaxSize = Vector2.new(460, 54)
deadClamp.Parent = deadTag

local deadIcon = Components.icon({ name = "skull", size = UDim2.fromScale(0.11, 0.72), chip = false, parent = deadTag })
deadIcon.AnchorPoint = Vector2.new(0, 0.5)
deadIcon.Position = UDim2.fromScale(0.04, 0.5)

local deadLabel = Instance.new("TextLabel")
deadLabel.Name = "Label"
deadLabel.AnchorPoint = Vector2.new(1, 0.5)
deadLabel.Position = UDim2.fromScale(0.96, 0.5)
deadLabel.Size = UDim2.fromScale(0.82, 0.7)
deadLabel.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(deadLabel, Theme.text.caption, Theme.font.button)
deadLabel.TextColor3 = Theme.color.red
deadLabel.Text = "YOU DIED — SPECTATING THE CREW"
deadLabel.Parent = deadTag

-- ── results panel (built once, shown on the event) ───────────────────────────────────────────────

local results = Components.panel({
	name = "RunResults",
	title = "Run over",
	icon = "trophy",
	size = UDim2.fromScale(0.44, 0.56),
	parent = player.PlayerGui,
	-- Job #111: NOT dismissable. This panel shipped with the standard X and tap-outside-to-close, so a
	-- player could shut the results screen and go on walking around a finished run — no boat, no
	-- objectives, invincible, nothing to do but wait out the auto-teleport. RETURN TO LOBBY is the only
	-- way off this screen (the 30 s countdown presses it for you).
	dismissable = false,
})
results.gui.DisplayOrder = 70 -- the run is over: nothing, not even the admin panel, goes above this

local headline = Instance.new("TextLabel")
headline.Name = "Headline"
headline.Position = UDim2.fromScale(0, 0)
headline.Size = UDim2.fromScale(1, 0.18)
headline.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(headline, Theme.text.h1, Theme.font.display)
headline.Text = ""
headline.Parent = results.content

local statsHolder = Instance.new("Frame")
statsHolder.Name = "Stats"
statsHolder.Position = UDim2.fromScale(0.05, 0.22)
statsHolder.Size = UDim2.fromScale(0.9, 0.34)
statsHolder.BackgroundTransparency = 1
statsHolder.BorderSizePixel = 0
statsHolder.Active = false
statsHolder.Parent = results.content

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, Theme.space.xs)
statsLayout.Parent = statsHolder

local function statRow(order: number, iconName: string, caption: string, tint: Color3)
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. caption
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(1, 0.3)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Active = false

	local ico = Components.icon({ name = iconName, size = UDim2.fromScale(0.09, 0.8), chip = false, parent = row })
	ico.AnchorPoint = Vector2.new(0, 0.5)
	ico.Position = UDim2.fromScale(0, 0.5)

	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0.13, 0.5)
	label.Size = UDim2.fromScale(0.5, 0.8)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(label, Theme.text.body, Theme.font.body)
	label.TextColor3 = Theme.color.creamDim
	label.Text = caption
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.fromScale(1, 0.5)
	value.Size = UDim2.fromScale(0.36, 0.8)
	value.TextXAlignment = Enum.TextXAlignment.Right
	Components.applyText(value, Theme.text.h2, Theme.font.bodyBold)
	value.TextColor3 = tint
	value.Text = "—"
	value.Parent = row

	row.Parent = statsHolder
	return value
end

local distanceValue = statRow(1, "pin", "Distance travelled", Theme.color.cream)
local survivorsValue = statRow(2, "crew", "Survivors", Theme.color.cream)
local rewardValue = statRow(3, "coin", "Gold earned", Theme.color.gold)

local returnButton = Components.button({
	text = "RETURN TO LOBBY",
	variant = "primary",
	icon = "boat",
	size = UDim2.fromScale(0.7, 0.15),
	parent = results.content,
	onActivated = function()
		returnRemote:FireServer()
	end,
})
returnButton.instance.AnchorPoint = Vector2.new(0.5, 1)
returnButton.instance.Position = UDim2.fromScale(0.5, 0.9)

local countdown = Instance.new("TextLabel")
countdown.Name = "Countdown"
countdown.AnchorPoint = Vector2.new(0.5, 1)
countdown.Position = UDim2.fromScale(0.5, 1)
countdown.Size = UDim2.fromScale(1, 0.08)
countdown.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(countdown, Theme.text.caption, Theme.font.body)
countdown.TextColor3 = Theme.color.creamDim
countdown.Text = ""
countdown.Parent = results.content

-- ── spectate ─────────────────────────────────────────────────────────────────────────────────────

local ended = false

RunService.RenderStepped:Connect(function()
	if ended then
		return
	end
	local runOn = Workspace:GetAttribute("RunStarted") == true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local alive = hum ~= nil and (hum :: Humanoid).Health > 0

	if runOn and not alive then
		deadTag.Visible = true
		local boat = Workspace:FindFirstChild("Boat")
		local hull = boat and boat:FindFirstChild("Hull")
		local cam = Workspace.CurrentCamera
		if hull and hull:IsA("BasePart") and cam then
			cam.CameraSubject = hull
			cam.CameraType = Enum.CameraType.Custom
		end
	else
		deadTag.Visible = false
	end
end)

-- ── results ──────────────────────────────────────────────────────────────────────────────────────

runEnded.OnClientEvent:Connect(function(data)
	if ended then
		return -- one results screen per run, no matter how many times the server tells us
	end
	ended = true
	deadTag.Visible = false

	local won = typeof(data) == "table" and data.won == true
	local reward = (typeof(data) == "table" and data.reward) or 0

	headline.Text = if won then "YOU REACHED THE END" else "THE CREW WAS LOST"
	headline.TextColor3 = if won then Theme.color.green else Theme.color.red

	-- The panel is built before the outcome is known, so its title bar is re-labelled here. Reaching in
	-- by child name is the trade for `Components.panel` not exposing a setTitle — worth it rather than
	-- widening a shared component for one screen in one place.
	local titleBar = results.frame:FindFirstChild("TitleBar")
	if titleBar then
		local titleText = titleBar:FindFirstChild("Title")
		if titleText and titleText:IsA("TextLabel") then
			titleText.Text = if won then "VICTORY" else "RUN OVER"
		end
		local titleIcon = titleBar:FindFirstChild("Icon_trophy")
		local titleImage = titleIcon and titleIcon:FindFirstChild("Image")
		if titleImage and titleImage:IsA("ImageLabel") then
			titleImage.Image = Components.iconId(if won then "trophy" else "skull")
		end
	end

	distanceValue.Text = ("%d"):format((typeof(data) == "table" and data.distance) or 0)
	survivorsValue.Text = ("%d"):format((typeof(data) == "table" and data.survivors) or 0)
	rewardValue.Text = ("+%d"):format(reward)

	-- Nothing else may be open behind the end of a run. Found in the Job #075 playtest: the results
	-- screen appeared stacked on an open Trading Post, with the shop's rows visible around it.
	Components.closeAllPanels("RunResults")

	results.setOpen(true)
	UISound.play(if won then "runWin" else "runLost")
	if reward > 0 then
		Components.burst(rewardValue, Theme.color.gold)
	end

	-- Auto-return, with the clock visible. Stops a disconnected-but-present player from holding a
	-- reserved server open forever, and the number means nobody has to guess whether it's stuck.
	--
	-- The countdown keeps running even if the player closes the panel to look at the scene: the SERVER
	-- owns the auto-return and will send them back regardless, so stopping the display on close would
	-- only make a re-opened panel show a stale number.
	task.spawn(function()
		local left = (typeof(data) == "table" and data.returnIn) or DEFAULT_RETURN
		while left > 0 do
			countdown.Text = ("Returning to the lobby in %ds…"):format(left)
			task.wait(1)
			left -= 1
		end
		countdown.Text = "Returning to the lobby…"
	end)
end)
