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
local SENS = 0.006 -- radians per pixel of MOUSE movement
-- Touch needs its own constant, not a reuse of SENS: a thumb drag covers a few hundred pixels where a
-- mouse sweep covers a thousand, so the mouse value would make the barrel feel nailed down on a phone.
-- ⚠️ FIRST VALUE, NOT A TUNED ONE (Job #096) — chosen so a ~280 px drag covers the full ±80° yaw arc,
-- which is about one comfortable thumb sweep on a phone. It cannot be judged from Studio (a desktop
-- session reports TouchEnabled = false), so it is EXPECTED to need one round of adjustment from a real
-- device. If aiming feels sluggish raise it; twitchy, lower it.
local TOUCH_SENS = 0.010
local BIND = "GunCam"
local CAM_UP, CAM_BACK = 2, 3 -- MUST match GunServer so the shot hits the crosshair

local seated = false
local yaw, pitch = 0, 0

-- crosshair (Job #075: on-palette, and with a dark ring so it survives bright water and dark canopy —
-- a bare coloured dot vanished against sunlit river, which is most of where you shoot)
local TweenService = game:GetService("TweenService")
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local TouchFire = require(ReplicatedStorage:WaitForChild("RunUI"):WaitForChild("TouchFire"))

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
-- 460 wide, not 140: at 140 the longest string ("NO AMMO — LOAD CRATES ON THE DECK") clipped mid-word,
-- because `applyText` sets TextScaled with a 12 px MinTextSize floor — so it can't shrink its way out of
-- a box that's too small, it just overflows. Offset rather than scale on purpose: this label is pinned a
-- fixed distance under the reticle, which is itself a fixed pixel size.
ammo.Size = UDim2.fromOffset(460, 24)
ammo.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(ammo, Theme.text.caption, Theme.font.bodyBold)
ammo.TextStrokeTransparency = 0.1
ammo.Text = ""
ammo.Parent = gui

-- Can the turret fire at all? This is the SAME condition GunServer checks (`Rounds > 0`, else spend a
-- crate) — mirrored here so the client stops pretending, not so it decides. The server still refuses.
local function shotsLeft(): number
	local boat = Workspace:FindFirstChild("Boat")
	if not boat then
		return 0
	end
	local rounds = (boat:GetAttribute("Rounds") :: number?) or 0
	local crates = (boat:GetAttribute("Ammo") :: number?) or 0
	return rounds + crates * ItemDefs.TURRET_ROUNDS_PER_CRATE
end

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

-- Job #087: mirror the local gunner's aim onto their own Player attributes, so `BoatTurretVisual`
-- can pose the barrel from THIS input rather than from the round-tripped `GunYaw`/`GunPitch` the
-- server publishes. For the person actually aiming, the barrel then has no network delay in it at all.
-- Player attributes rather than a shared module: the two scripts stay decoupled, exactly as the server
-- already decouples the turret from the searchlight through boat attributes.
local function publishLocalAim()
	player:SetAttribute("GunAimYaw", yaw)
	player:SetAttribute("GunAimPitch", pitch)
end

-- ⚠️ Job #096 / finding #0007 — THE GUNNER ROLE DID NOT WORK ON A PHONE AT ALL.
--
-- This handler used to read `input.UserInputType ~= Enum.UserInputType.MouseMovement then return`.
-- Roblox does NOT emit `MouseMovement` for a touch drag — a drag arrives as `UserInputType.Touch` on
-- `InputChanged` — so on mobile `yaw`/`pitch` never changed. A gunner sat down, got the over-the-gun
-- camera, and could not move the barrel: they could only ever shoot straight ahead. Combined with the
-- old tap-anywhere trigger, every attempt to look around also burned a round of the boat's shared,
-- scavenged ammo. One of the game's interdependent roles was unplayable on the platform GAME.md calls
-- a hard requirement.
--
-- `gameProcessed` is checked for TOUCH ONLY, and that asymmetry is deliberate. A drag that begins on
-- the fire button must not also swing the barrel — but the mouse path is left byte-for-byte as it
-- behaved before, because a PC player has no such conflict and this fix must not change their aim.
UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
	if not seated then
		return
	end

	local sens: number
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		sens = SENS
	elseif input.UserInputType == Enum.UserInputType.Touch then
		if gameProcessed then
			return -- this drag belongs to a GUI control (the fire button), not to aiming
		end
		sens = TOUCH_SENS
	else
		return
	end

	-- `Delta` is per-frame movement in pixels for both input types, so the only difference between them
	-- is the constant.
	yaw = math.clamp(yaw - input.Delta.X * sens, -YAW_LIMIT, YAW_LIMIT)
	pitch = math.clamp(pitch - input.Delta.Y * sens, PITCH_MIN, PITCH_MAX)
	aimRemote:FireServer(yaw, pitch)
	publishLocalAim()
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

-- One trigger body, two ways in (Job #096): the mouse click below, and the on-screen fire button for
-- touch. Extracted rather than duplicated so the empty-turret answer below can never drift between them.
local function pullTrigger()
	if not seated then
		return
	end
	-- ⚠️ THE BUG THIS FIXES (found in playtest): `drawTracer()` used to run unconditionally. GunServer
	-- correctly refuses a shot with no rounds and no crates (:167-169) — but the client drew the
	-- tracer anyway, so an empty turret looked and felt exactly like a firing one. You could "shoot"
	-- forever and wonder why nothing died.
	--
	-- The handheld path already got this right (WeaponClient checks `haveAmmo` before sending); only
	-- the turret didn't. Now empty means: no remote call, no tracer, a dry click, and a red reticle
	-- pulse — the same three-part answer the handheld gives.
	if shotsLeft() <= 0 then
		UISound.play("emptyClick")
		local was = dot.BackgroundColor3
		dot.BackgroundColor3 = Theme.color.red
		TweenService:Create(dot, Theme.tween.slow, { BackgroundColor3 = was }):Play()
		return
	end
	fireRemote:FireServer()
	drawTracer()
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not seated or gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pullTrigger()
	elseif input.UserInputType == Enum.UserInputType.Touch and not TouchFire.isActive() then
		-- Fallback only — see the matching note in WeaponClient. On a real touch device the button is
		-- the trigger, so this arm is dead; it exists so a failure to build the button leaves the turret
		-- usable rather than inert.
		pullTrigger()
	end
end)

TouchFire.onFire(pullTrigger)

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
	local total = rounds + crates * ItemDefs.TURRET_ROUNDS_PER_CRATE
	-- Total first, because that is the decision ("do I keep firing?"); the breakdown second, because the
	-- gunner is also the person who needs to know a crate is about to be spent.
	ammo.Text = if total > 0
		then ("%d SHOTS   ·   %d RDS + %d CRATES"):format(total, rounds, crates)
		else "NO AMMO — LOAD CRATES ON THE DECK"
	ammo.TextColor3 = if total <= 0 then Theme.color.red else Theme.color.cream
	dot.BackgroundColor3 = if total <= 0 then Theme.color.metal else Theme.color.red
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
	publishLocalAim() -- Job #087: seed the recentred aim so the barrel starts level, not at last session's angle
	gui.Enabled = true
	watchAmmo(true)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, update)
	-- Job #096: on touch the barrel is aimed by DRAGGING, so the trigger needs a button of its own.
	TouchFire.setVisible("GunClient", true)
end

local function stopGunner()
	if not seated then
		return
	end
	seated = false
	gui.Enabled = false
	watchAmmo(false)
	TouchFire.setVisible("GunClient", false)
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
