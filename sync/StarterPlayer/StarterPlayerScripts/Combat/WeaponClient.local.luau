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
local TweenService = game:GetService("TweenService")
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
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local TouchFire = require(RunUI:WaitForChild("TouchFire"))

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

-- ── Job #084: the muzzle flash ────────────────────────────────────────────────────────────────────
-- Lives here rather than in `CombatFeedback` because it must fire on a MISS too, and that file only
-- hears about landed hits. One pooled emitter, moved to the barrel and burst — never one per shot.
local muzzlePart = Instance.new("Part")
muzzlePart.Name = "MuzzleFlash"
muzzlePart.Size = Vector3.new(0.2, 0.2, 0.2)
muzzlePart.Transparency = 1
muzzlePart.Anchored = true
muzzlePart.CanCollide = false
muzzlePart.CanQuery = false
muzzlePart.CanTouch = false
muzzlePart.CastShadow = false
muzzlePart.Parent = Workspace

local muzzle = Instance.new("ParticleEmitter")
muzzle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Theme.color.yellow)
muzzle.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})
muzzle.Size = NumberSequence.new(0.9, 0.1)
muzzle.Lifetime = NumberRange.new(0.05, 0.09)
muzzle.Speed = NumberRange.new(2, 6)
muzzle.SpreadAngle = Vector2.new(28, 28)
muzzle.LightEmission = 1
muzzle.Rate = 0 -- burst-only
muzzle.Enabled = false
muzzle.Parent = muzzlePart

local function muzzleFlash()
	local char = player.Character
	local held = char and char:FindFirstChild("HeldItem")
	if held and held:IsA("BasePart") then
		-- the barrel end: the held gun's long axis is -Z (see `InventoryService:211`)
		muzzlePart.CFrame = held.CFrame * CFrame.new(0, 0, -held.Size.Z / 2)
		muzzle:Emit(6)
	end
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

-- ── the three reasons a gun won't fire, kept APART ────────────────────────────────────────────────
-- Job #084: these used to be one `localCanShoot()` that hid the reticle for all of them. Hiding is
-- right for two of them and wrong for the third:
--
--   • no gun equipped / seated at the helm or turret → HIDE. The hotbar hides in a control seat too
--     (`InventoryHud:114`), so the whole loadout UI disappears together and reads as intentional.
--   • carrying a crate → SHOW IT, YELLOW. A dot that vanishes reads as a UI glitch, and the player
--     concludes the weapon is broken — which is exactly what happened in the 2026-08-16 playtest.
--     A yellow reticle says "the game knows you pulled the trigger, and this is deliberate".
local function seatedAtStation(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return seat ~= nil and (seat.Name == "DriverSeat" or seat.Name == "GunSeat")
end

-- carrying loot: the server refuses the shot (`WeaponServer:54`) and the axe too (`MeleeServer:65`)
local function blockedByCarry(): boolean
	return player:GetAttribute("Busy") == true
end

-- is the reticle drawn at all? (a gun is up and you are not at a station)
local function reticleShown(): boolean
	return activeGun() ~= nil and not seatedAtStation()
end

local function haveAmmo(): boolean
	local def = activeGun()
	if not def or not def.ammoAttr then
		return false
	end
	return ((player:GetAttribute(def.ammoAttr) :: number?) or 0) > 0
end

local function updateCrosshair()
	dot.Visible = reticleShown()
	-- The trigger follows the reticle exactly: if there is nothing to aim, there is nothing to fire, and
	-- a fire button with no gun up would be a button that does nothing — the worst thing to put on a
	-- phone screen. `reticleShown()` already excludes the helm and the turret seat, so this never fights
	-- GunClient for the corner.
	TouchFire.setVisible("WeaponClient", reticleShown())
	-- yellow outranks the ammo colour: with your hands full the ammo count is not why you can't shoot,
	-- and showing red there would send the player hunting for ammo they already have.
	dot.BackgroundColor3 = if blockedByCarry()
		then Theme.color.yellow
		elseif haveAmmo() then Theme.color.cream
		else Theme.color.red
end

-- A blocked trigger pull has to answer BACK. The steady yellow says "blocked"; this says "blocked, and
-- I registered that tap" — without it a refused shot is indistinguishable from an input that never
-- landed, which on a phone is the explanation a player reaches for first (the same reasoning that put
-- the click on the empty-ammo path in Job #075).
local PULSE = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RESTORE = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local pulsing = false
local function pulseBlocked()
	UISound.play("emptyClick") -- debounced 0.3 s in UISound; safe to call on every mashed tap
	if pulsing then
		return
	end
	pulsing = true
	local grow = TweenService:Create(dot, PULSE, { Size = UDim2.fromOffset(16, 16) })
	grow.Completed:Connect(function()
		local shrink = TweenService:Create(dot, RESTORE, { Size = UDim2.fromOffset(7, 7) })
		shrink.Completed:Connect(function()
			pulsing = false
		end)
		shrink:Play()
	end)
	grow:Play()
end

local function fire(screenPos: Vector2)
	if not reticleShown() then
		return -- no gun up, or seated at the helm/turret: nothing is drawn, nothing to explain
	end
	if blockedByCarry() then
		pulseBlocked() -- hands full — the chip says why, this says "yes, I heard you"
		return
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
	muzzleFlash() -- on the shot, not on the hit: a miss must look like a shot too
	tracer(aim)
end

-- ── the trigger ──────────────────────────────────────────────────────────────────────────────────
-- Job #096 / finding #0006: on touch, EVERY tap used to fire. Dragging to look around is a touch, so
-- looking at the river — the thing a player does constantly — spent ammo from the boat's shared,
-- scavenged stock. The mouse keeps its click; touch gets the dedicated button instead (`RunUI/TouchFire`).
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- tap landed on a GUI button (e.g. the hotbar)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fire(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.UserInputType == Enum.UserInputType.Touch and not TouchFire.isActive() then
		-- Fallback only. `isActive()` is true on every touch device, so in practice this arm is dead on
		-- a phone and live nowhere else — it exists so that if the button ever fails to build, the gun
		-- is still usable rather than silently inert.
		fire(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- The button aims at the RETICLE, not at where the finger landed: the reticle is drawn at the true
-- viewport centre (see this file's ScreenInsets note), which is the line the player is actually sighting
-- along. Firing at the thumb's position would send the shot into the bottom-right corner of the screen.
TouchFire.onFire(function()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if not viewport then
		return
	end
	fire(Vector2.new(viewport.X / 2, viewport.Y / 2))
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
