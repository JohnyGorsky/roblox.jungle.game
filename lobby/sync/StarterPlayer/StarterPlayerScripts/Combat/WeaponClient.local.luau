--!strict
-- WeaponClient.local.luau — free-aim tap-to-hit shooting for LOOTED guns (Job 006 → Job 015).
--
-- Only active when the equipped loadout item is a GUN (Pistol/Shotgun) — the Sword is handled by
-- MeleeClient. On click/tap, raycast the camera through the pointer to a world point, send ONLY that
-- point to the server (which authoritatively picks the gun, checks ammo, and applies damage), and draw a
-- local tracer. The crosshair only shows while a gun is equipped and you can fire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FireWeapon") :: RemoteEvent

-- crosshair
local gui = Instance.new("ScreenGui")
gui.Name = "WeaponGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BackgroundTransparency = 0.2
dot.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
dot.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function activeGun(): ItemDefs.ItemDef?
	local def = ItemDefs.get(player:GetAttribute("ActiveItem") :: string?)
	if def and def.kind == "Gun" then
		return def
	end
	return nil
end

local function aimPointFrom(screenPos: Vector2): Vector3
	local cam = Workspace.CurrentCamera
	-- ScreenPointToRay (NOT ViewportPointToRay): input.Position is in SCREEN space (includes the topbar
	-- inset), so ScreenPointToRay lines the ray up with the cursor; ViewportPointToRay is off by the inset.
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 1000
end

local function tracer(toPos: Vector3)
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local from = if head then head.Position else Workspace.CurrentCamera.CFrame.Position
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 240, 150)
	part.Size = Vector3.new(0.15, 0.15, (toPos - from).Magnitude)
	part.CFrame = CFrame.lookAt((from + toPos) / 2, toPos)
	part.Parent = Workspace
	task.delay(0.05, function()
		part:Destroy()
	end)
end

-- you can only fire while a gun is equipped, not driving/manning the mounted gun, and not busy (carrying)
local function localCanShoot(): boolean
	if not activeGun() then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and (hum.SeatPart.Name == "DriverSeat" or hum.SeatPart.Name == "GunSeat") then
		return false
	end
	if player:GetAttribute("Busy") == true then
		return false
	end
	return true
end

local function haveAmmo(): boolean
	local def = activeGun()
	if not def or not def.ammoAttr then
		return false
	end
	return ((player:GetAttribute(def.ammoAttr) :: number?) or 0) > 0
end

local function updateCrosshair()
	dot.Visible = localCanShoot()
	dot.BackgroundColor3 = if haveAmmo() then Color3.new(1, 1, 1) else Color3.fromRGB(230, 80, 70)
end

local function fire(screenPos: Vector2)
	if not localCanShoot() then
		return -- server enforces this too; skip the round trip
	end
	if not haveAmmo() then
		-- client-side "empty" cue: flash the crosshair red, don't send the shot
		dot.BackgroundColor3 = Color3.fromRGB(230, 80, 70)
		return
	end
	local aim = aimPointFrom(screenPos)
	remote:FireServer(aim)
	tracer(aim)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- tap landed on a GUI button (e.g. the hotbar)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		fire(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- keep the crosshair in sync with equip/ammo/busy/seat changes
player:GetAttributeChangedSignal("Busy"):Connect(updateCrosshair)
player:GetAttributeChangedSignal("ActiveItem"):Connect(updateCrosshair)
player:GetAttributeChangedSignal("AmmoPistol"):Connect(updateCrosshair)
player:GetAttributeChangedSignal("AmmoShotgun"):Connect(updateCrosshair)
local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum:GetPropertyChangedSignal("SeatPart"):Connect(updateCrosshair)
	updateCrosshair()
end
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
updateCrosshair()
