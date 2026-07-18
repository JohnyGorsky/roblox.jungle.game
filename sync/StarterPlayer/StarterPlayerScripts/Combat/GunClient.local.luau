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

-- crosshair
local gui = Instance.new("ScreenGui")
gui.Name = "GunGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(10, 10)
dot.BackgroundColor3 = Color3.fromRGB(255, 90, 70)
dot.BackgroundTransparency = 0.1
dot.BorderSizePixel = 0
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(1, 0)
c.Parent = dot
dot.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

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
	part.Color = Color3.fromRGB(255, 230, 120)
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

local function startGunner()
	seated = true
	yaw, pitch = 0, 0
	gui.Enabled = true
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
