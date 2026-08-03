--!strict
-- GunClient.local.luau — man the mounted gun (Job 014).
-- Sit in the GunSeat → an over-the-gun aiming CAMERA + mouse aims within the arc (sends clamped
-- yaw/pitch to the server, which rotates the barrel + fires). Click/tap = fire. Crosshair while manning.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local aimRemote = ReplicatedStorage:WaitForChild("GunAim") :: UnreliableRemoteEvent
local fireRemote = ReplicatedStorage:WaitForChild("GunFire") :: RemoteEvent

local YAW_LIMIT = math.rad(80)
local PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)
local SENS = 0.006
local BIND = "GunCam"
local CAM_UP, CAM_BACK = 2, 3 -- MUST match GunServer so the shot hits the crosshair

local seated = false
local yaw, pitch = 0, 0

-- crosshair (Job #075: on-palette, and with a dark ring so it survives bright water and dark canopy —
-- a bare coloured dot vanished against sunlit river, which is most of where you shoot)
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local gui = Components.screen("GunGui", player:WaitForChild("PlayerGui"))
gui.ScreenInsets = Enum.ScreenInsets.None -- must sit at the true viewport centre, where the shot goes
gui.DisplayOrder = 12
gui.Enabled = false

local dot = Instance.new("Frame")
dot.Name = "Reticle"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(10, 10)
dot.BackgroundColor3 = Theme.color.red -- the turret's reticle: this one kills things
dot.BackgroundTransparency = 0.1
dot.BorderSizePixel = 0
dot.Active = false
Components.corner(Theme.radius.pill, dot)
Components.stroke(Theme.color.stroke, Theme.strokeWidth.control, dot)
dot.Parent = gui

-- ammo, under the reticle: the gunner's own camera hides the deck HUD behind them, so the one number
-- that decides whether to keep firing has to be where they are already looking
local ammo = Instance.new("TextLabel")
ammo.Name = "Ammo"
ammo.AnchorPoint = Vector2.new(0.5, 0)
ammo.Position = UDim2.new(0.5, 0, 0.5, 26)
ammo.Size = UDim2.fromOffset(140, 22)
ammo.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(ammo, Theme.text.caption, Theme.font.bodyBold)
ammo.TextStrokeTransparency = 0.1
ammo.Text = ""
ammo.Parent = gui

local function gunBase(): BasePart?
	local boat = Workspace:FindFirstChild("Boat")
	local b = boat and boat:FindFirstChild("GunBase")
	return if b and b:IsA("BasePart") then b else nil
end

local function setCharHidden(hidden: boolean)
	local char = player.Character
	if not char then
		return
	end
	local t = if hidden then 1 else 0
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
			d.LocalTransparencyModifier = t
		end
	end
end

local function update()
	local base = gunBase()
	local cam = Workspace.CurrentCamera
	if not base or not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable -- re-assert control so nothing steals the camera
	setCharHidden(true) -- first-person: keep your own head out of the shot (re-applied each frame)
	local aim = base.CFrame * CFrame.Angles(pitch, yaw, 0)
	cam.CFrame = aim * CFrame.new(0, CAM_UP, CAM_BACK) -- crosshair (screen centre) == the ray direction
	cam.Focus = CFrame.new(aim.Position + aim.LookVector * 60)
end

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not seated or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	yaw = math.clamp(yaw - input.Delta.X * SENS, -YAW_LIMIT, YAW_LIMIT)
	pitch = math.clamp(pitch - input.Delta.Y * SENS, PITCH_MIN, PITCH_MAX)
	aimRemote:FireServer(yaw, pitch)
end)

-- visual tracer along the SAME line the server fires (origin/dir match) → confirms the crosshair
local function drawTracer()
	local base = gunBase()
	if not base then
		return
	end
	local aim = base.CFrame * CFrame.Angles(pitch, yaw, 0)
	local origin = (aim * CFrame.new(0, CAM_UP, CAM_BACK)).Position
	local dir = aim.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if player.Character then
		table.insert(filter, player.Character)
	end
	local boat = Workspace:FindFirstChild("Boat")
	if boat then
		table.insert(filter, boat)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, dir * 350, params)
	local toPos = if hit then hit.Position else origin + dir * 350
	local muzzle = base.Position + dir * 5
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Theme.color.yellow -- turret tracer, same accent as the handheld one
	part.Size = Vector3.new(0.2, 0.2, (toPos - muzzle).Magnitude)
	part.CFrame = CFrame.lookAt((muzzle + toPos) / 2, toPos)
	part.Parent = Workspace
	task.delay(0.06, function()
		part:Destroy()
	end)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not seated or gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		fireRemote:FireServer()
		drawTracer()
	end
end)

-- Turret ammo lives on the BOAT (`Rounds` = loose rounds already fed to the gun, `Ammo` = crates on the
-- deck still to be fed), not on the player — the turret draws from the shared stock. Both are shown,
-- because "40 rounds and no crates left" is a very different situation from "40 rounds and eight crates".
local ammoConn: RBXScriptConnection? = nil
local crateConn: RBXScriptConnection? = nil

local function renderAmmo()
	local boat = Workspace:FindFirstChild("Boat")
	if not boat then
		ammo.Text = ""
		return
	end
	local rounds = (boat:GetAttribute("Rounds") :: number?) or 0
	local crates = (boat:GetAttribute("Ammo") :: number?) or 0
	ammo.Text = ("%d RDS   ·   %d CRATES"):format(rounds, crates)
	ammo.TextColor3 = if rounds <= 0 then Theme.color.red else Theme.color.cream
end

local function watchAmmo(on: boolean)
	if ammoConn then
		ammoConn:Disconnect()
		ammoConn = nil
	end
	if crateConn then
		crateConn:Disconnect()
		crateConn = nil
	end
	if not on then
		return
	end
	local boat = Workspace:FindFirstChild("Boat")
	if boat then
		ammoConn = boat:GetAttributeChangedSignal("Rounds"):Connect(renderAmmo)
		crateConn = boat:GetAttributeChangedSignal("Ammo"):Connect(renderAmmo)
	end
	renderAmmo()
end

local function startGunner()
	seated = true
	yaw, pitch = 0, 0
	gui.Enabled = true
	watchAmmo(true)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, update)
end

local function stopGunner()
	if not seated then
		return
	end
	seated = false
	gui.Enabled = false
	watchAmmo(false)
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	setCharHidden(false)
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Seated:Connect(function(active: boolean, seatPart: Seat?)
		if active and seatPart and seatPart.Name == "GunSeat" then
			startGunner()
		else
			stopGunner()
		end
	end)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
