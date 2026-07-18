--!strict
-- MeleeClient.local.luau — tap-to-swing when the Sword is the active item (Job 015).
--
-- Only requests a swing when the active loadout item is the Sword; the guns are handled by WeaponClient.
-- The server does all validation + hit detection (see MeleeServer). This also plays a quick local swing
-- ARC so the swing reads clearly — greybox demo feedback; a real rigged animation is a later pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SwordSwing") :: RemoteEvent

local SWING_TIME = 0.22
local swinging = false

local function swordActive(): boolean
	if player:GetAttribute("ActiveItem") ~= "Sword" or player:GetAttribute("Busy") == true then
		return false
	end
	-- can't swing while driving the boat or manning the mounted gun
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and (hum.SeatPart.Name == "DriverSeat" or hum.SeatPart.Name == "GunSeat") then
		return false
	end
	return true
end

-- quick demo swing: a neon blade sweeps a downward arc in front of the character
local function playSwingFx()
	if swinging then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return
	end
	swinging = true

	local blade = Instance.new("Part")
	blade.Name = "SwingFx"
	blade.Size = Vector3.new(0.25, 4, 0.6)
	blade.Color = Color3.fromRGB(210, 220, 235)
	blade.Material = Enum.Material.Neon
	blade.Transparency = 0.15
	blade.CanCollide = false
	blade.CanQuery = false
	blade.Massless = true
	blade.Anchored = true
	blade.Parent = char

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) / SWING_TIME
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if a >= 1 or not root or not blade.Parent then
			conn:Disconnect()
			blade:Destroy()
			swinging = false
			return
		end
		-- sweep the blade from up-right to down-left across the front
		local ang = math.rad(80 - a * 170)
		blade.CFrame = root.CFrame
			* CFrame.new(0, 1.5, -1.5)
			* CFrame.Angles(0, 0, ang)
			* CFrame.new(0, 1.8, 0)
		blade.Transparency = 0.15 + a * 0.7
	end)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- tap landed on a GUI button (e.g. the hotbar)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if swordActive() then
			remote:FireServer()
			playSwingFx()
		end
	end
end)
