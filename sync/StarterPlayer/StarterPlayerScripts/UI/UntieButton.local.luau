--!strict
-- UntieButton.local.luau — the seated driver's untie/start button (Job 030, restyled in Job #075).
--
-- Shown while you're in the boat's DriverSeat and the boat is TIED, so you can untie without reaching
-- the winch/dock ProximityPrompt — which can be unreachable at an awkward mooring angle (todo 0001).
-- Fires the server `RequestUntie`; the server (StagingServer pre-run, DockServer at a dock) validates
-- and performs the untie. No client authority here beyond asking.
--
-- Job #075: it is a real `Components.button` with the right variant for what it does — PRIMARY green at
-- the crash site, where untying is the positive act that starts the run, and GOLD at a dock, where it
-- is the deliberate "we're done scavenging, cast off" call rather than a default next step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = ReplicatedStorage:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components"))

local TICK = 0.2

local player = Players.LocalPlayer
local untieRemote = ReplicatedStorage:WaitForChild("RequestUntie") :: RemoteEvent

local gui = Components.screen("UntieButton", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 8

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5, 1)
-- Above the boat vitals (which top out around y = 0.865), clear of the hotbar and the throttle.
holder.Position = UDim2.fromScale(0.5, 0.8)
holder.Size = UDim2.fromScale(0.2, 0.075)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Visible = false

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(150, 44)
clamp.MaxSize = Vector2.new(300, 68)
clamp.Parent = holder

holder.Parent = gui

local function untie()
	untieRemote:FireServer()
end

-- TWO buttons, one visible at a time, rather than one button that gets re-tinted.
-- `Components.button` captures its variant colour at build time and repaints to it on hover/leave, so
-- overwriting BackgroundColor3 from outside works until the first mouse-out and then silently reverts.
-- Two instances keep the component's state machine intact and cost one hidden frame.
local startButton = Components.button({
	text = "PULL & START",
	variant = "primary", -- green: the positive act that begins the run
	icon = "rope",
	size = UDim2.fromScale(1, 1),
	parent = holder,
	onActivated = untie,
})

local castOffButton = Components.button({
	text = "UNTIE",
	variant = "gold", -- gold: a deliberate mid-run decision to leave a dock, not a default next step
	icon = "rope",
	size = UDim2.fromScale(1, 1),
	parent = holder,
	onActivated = untie,
})
castOffButton.instance.Visible = false

local function seatedInDriver(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return seat ~= nil and seat.Name == "DriverSeat"
end

local acc = 0

RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	local boat = Workspace:FindFirstChild("Boat")
	local tied = boat ~= nil and boat:GetAttribute("Tied") == true
	local show = tied and seatedInDriver()
	holder.Visible = show
	if not show then
		return
	end

	-- Pre-run this button STARTS THE RUN; mid-run it just casts off from a dock. Same remote, very
	-- different weight of decision, so it says so.
	local started = Workspace:GetAttribute("RunStarted") == true
	startButton.instance.Visible = not started
	castOffButton.instance.Visible = started
end)
