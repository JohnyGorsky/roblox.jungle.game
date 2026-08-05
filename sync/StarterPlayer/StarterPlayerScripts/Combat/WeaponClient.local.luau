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

-- crosshair (Job #075: cream with a dark ring, not pure white — §4 forbids pure white, and an unringed
-- white dot disappears entirely against sunlit water, which is where most shots are taken)
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))

local gui = Components.screen("WeaponGui", player:WaitForChild("PlayerGui"))
gui.ScreenInsets = Enum.ScreenInsets.None -- the reticle marks the true viewport centre
gui.DisplayOrder = 11

local dot = Instance.new("Frame")
dot.Name = "Reticle"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(7, 7)
dot.BackgroundColor3 = Theme.color.cream
dot.BackgroundTransparency = 0.15
dot.BorderSizePixel = 0
dot.Active = false
Components.corner(Theme.radius.pill, dot)
Components.stroke(Theme.color.stroke, Theme.strokeWidth.hairline, dot)
dot.Parent = gui

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
	part.Color = Theme.color.yellow -- tracer: warning-yellow, the palette's "hot" accent
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
	dot.BackgroundColor3 = if haveAmmo() then Theme.color.cream else Theme.color.red
end

local function fire(screenPos: Vector2)
	if not localCanShoot() then
		return -- server enforces this too; skip the round trip
	end
	if not haveAmmo() then
		-- Empty: flash the crosshair red AND click. The flash was already here; the sound was not, and a
		-- silent trigger pull is indistinguishable from an input that never registered — which on a phone
		-- is the more likely explanation a player reaches for (Job #075).
		dot.BackgroundColor3 = Theme.color.red
		UISound.play("emptyClick")
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
