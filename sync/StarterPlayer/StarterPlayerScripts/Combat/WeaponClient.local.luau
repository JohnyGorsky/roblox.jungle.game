--!strict
-- WeaponClient.local.luau — free-aim tap-to-hit shooting for LOOTED guns (Job 006 → Job 015).
--
-- Only active when the equipped loadout item is a GUN (Pistol/Shotgun/M16) — the Axe is handled by
-- MeleeClient. On click/tap, raycast the camera through the pointer to a world point, send ONLY that
-- point to the server (which authoritatively picks the gun, checks ammo, and applies damage), and draw a
-- local tracer. The crosshair only shows while a gun is equipped and you can fire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
-- Job #118: the projectile maths, shared with `WeaponServer` and `RocketFx` so the preview ring, the
-- flight and the blast cannot disagree about where a rocket lands.
local Combat = ReplicatedStorage:WaitForChild("Combat")
local Ballistics = require(Combat:WaitForChild("Ballistics"))
local GroundRing = require(Combat:WaitForChild("GroundRing"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FireWeapon") :: RemoteEvent
-- Job #117: live aim during a burst. The server fires 20 rounds over 2 s and reads the newest aim point
-- for each one, so a player can sweep across two targets instead of emptying the burst into whatever they
-- first clicked. Unreliable because the newest wins and a dropped update costs nothing.
local aimRemote = ReplicatedStorage:WaitForChild("AimWeapon") :: UnreliableRemoteEvent

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

local function aimPointFromRay(ray: Ray): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 1000
end

local function aimPointFrom(screenPos: Vector2): Vector3
	local cam = Workspace.CurrentCamera
	-- ScreenPointToRay (NOT ViewportPointToRay): input.Position is in SCREEN space (includes the topbar
	-- inset), so ScreenPointToRay lines the ray up with the cursor; ViewportPointToRay is off by the inset.
	return aimPointFromRay(cam:ScreenPointToRay(screenPos.X, screenPos.Y))
end

-- Where the pointer is RIGHT NOW — used for the 2nd..20th bullet of a burst (Job #117).
--
-- 🔴 `ViewportPointToRay`, NOT `ScreenPointToRay`, AND THE DIFFERENCE IS NOT COSMETIC.
-- `UserInputService:GetMouseLocation()` returns VIEWPORT space (topbar inset excluded); an
-- `InputObject.Position` is SCREEN space (inset included). That is exactly the mismatch the comment in
-- `aimPointFrom` above warns about, and getting it wrong here would put every bullet after the first a
-- topbar's height off the one before it — a burst that visibly climbs for no reason.
local function livePointerAim(): Vector3
	local cam = Workspace.CurrentCamera
	local loc = UserInputService:GetMouseLocation()
	return aimPointFromRay(cam:ViewportPointToRay(loc.X, loc.Y))
end

-- The reticle's own line of sight: the true viewport centre. What TOUCH aims along, for every bullet.
local function reticleAim(): Vector3
	local cam = Workspace.CurrentCamera
	local vp = cam.ViewportSize
	return aimPointFrom(Vector2.new(vp.X / 2, vp.Y / 2))
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

-- 🔴 Job #104: THE MUZZLE END IS FOUND, NOT ASSUMED.
-- This used to be `held.CFrame * CFrame.new(0, 0, -held.Size.Z / 2)`, with a comment claiming the held
-- gun's long axis is -Z. That was true of the GREYBOX BOX only (`InventoryService:211`, still the
-- fallback). Both real guns are authored barrel-along-**+X** (`WeaponAssets`: `BARREL_FORWARD`), so
-- `Size.Z` was the gun's THICKNESS — 0.29 studs — and the flash fired from the middle of the weapon,
-- i.e. out of the character's fist. Doubling the shotgun (Job #104) doubled the error to 2.4 studs and
-- made it obvious.
--
-- Rather than hardcode the other axis and break the greybox, ask the geometry: of the six face centres,
-- the muzzle is the one furthest along the direction you are shooting. That is correct for the +X meshes
-- AND for the -Z box, and stays correct for any weapon added later, whatever axis it is modelled on.
-- ⚠️ `WeaponAssets` cannot help here — it is ServerStorage, unreachable from the client.
-- Where the bullet leaves the gun, in world space. Job #117 pulled this out of `muzzleFlash` so the
-- TRACER can start from the same place — they were disagreeing, and that disagreement is what produced
-- the "big yellow square" (see `tracer`).
--
-- 🔴 THE GEOMETRY ITSELF MOVED TO `ReplicatedStorage/Combat/Ballistics.luau` IN JOB #118, and the reason
-- is not tidiness: the SERVER now needs the same answer, because that is where a Bazooka rocket is
-- launched from. Two copies would let the rocket appear somewhere the muzzle flash is not. This wrapper
-- keeps the "no held part → nil" behaviour the callers here rely on.
local function muzzleWorld(aimDir: Vector3): Vector3?
	local char = player.Character
	local held = char and char:FindFirstChild("HeldItem")
	if not (held and held:IsA("BasePart")) then
		return nil
	end
	return Ballistics.muzzleWorld(held :: BasePart, aimDir)
end

local function muzzleFlash(aimDir: Vector3)
	local at = muzzleWorld(aimDir)
	if at then
		muzzlePart.CFrame = CFrame.new(at)
		muzzle:Emit(6)
	end
end

-- 🔴 THE TRACER MUST NOT CONTAIN THE CAMERA. This is a bug fix, not a polish pass.
--
-- It used to start at `Head.Position`. In FIRST PERSON the camera sits at the head, so the tracer part
-- enclosed the camera — and a `Neon` part you are inside renders as a solid slab of colour across
-- whatever quadrant it happens to cross. Reported in play, 2026-08-25:
--     "when i shoot from first person perpective i have big yellow square, looks ugly"
-- and captured from the player's own camera before changing anything: a hard-edged orange-yellow quad
-- over the bottom-right of the screen. ⚠️ THE MUZZLE FLASH WAS NOT THE CAUSE — that was the first
-- suspicion and it was wrong; the emitter has a real `sparkles_main` texture and produces a soft glow,
-- not a hard edge. The straight diagonal boundary is geometry, which is what pointed at this part.
--
-- The M16 is what made it unmissable rather than new: 20 tracers a burst at 0.05 s each covers most of
-- the 2 seconds, where a single pistol shot flickered it for a twentieth of a second and read as noise.
--
-- Two changes, and both are needed:
--   1. START AT THE MUZZLE. Also simply more correct in third person — a tracer should leave the barrel,
--      not the eyeball — and it now shares `muzzleWorld` with the flash, so the two agree by construction.
--   2. PUSH THE ORIGIN CLEAR OF THE CAMERA ANYWAY. The muzzle alone is not a guarantee: the greybox
--      fallback item is 1.2 studs long and sits at the chest (`InventoryService`), which in first person
--      is still inside the near plane. When the start point is closer than this, the tracer is re-based to
--      a fixed clearance ahead of the camera along the shot, which cannot enclose it.
local NEAR_CLEARANCE = 2.5 -- studs of daylight between the camera and the near end of a tracer

local function tracer(fromPos: Vector3?, toPos: Vector3)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	-- muzzle if we have one, else the old head/camera behaviour as the floor
	local from = fromPos or (if head then head.Position else camPos)

	local delta = toPos - from
	if delta.Magnitude < 0.1 then
		return
	end
	local unit = delta.Unit
	if (from - camPos).Magnitude < NEAR_CLEARANCE then
		-- Re-based rather than nudged: this is exact, where sliding `from` forward by the shortfall is not
		-- (the shot need not point directly away from the camera).
		from = camPos + unit * NEAR_CLEARANCE
	end

	local length = (toPos - from).Magnitude
	if length < 0.5 then
		return -- muzzle practically on the target: a 0-length neon sliver is a dot of noise, not a tracer
	end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Theme.color.yellow -- tracer: warning-yellow, the palette's "hot" accent
	part.Size = Vector3.new(0.15, 0.15, length)
	part.CFrame = CFrame.lookAt((from + toPos) / 2, toPos)
	part.Parent = Workspace
	task.delay(0.05, function()
		part:Destroy()
	end)
end

-- One shot's worth of local FX, for the trigger pull AND for every bullet of a burst (Job #117).
-- Both are drawn on the shot, never on the hit: a miss has to look like a shot too.
--
-- 🔴 `withTracer` IS FALSE FOR A PROJECTILE WEAPON, AND IT IS NOT A COSMETIC PREFERENCE (Job #118).
-- A tracer is a HITSCAN idea: "the bullet is already there". The Bazooka's rocket takes four seconds to
-- arrive, so drawing a yellow beam from the muzzle to the landing spot at t=0 would (a) instantly spoil
-- the arc the whole feature is built around, (b) show every other player precisely where the rocket is
-- going four seconds before it does, and (c) in first person put a 300-stud Neon slab through the camera
-- — the "big yellow square" family of bug this very file was fixed for. The muzzle flash stays: a
-- launcher firing should still flash.
local function shotFx(aim: Vector3, withTracer: boolean)
	local shooter = player.Character
	local origin = shooter and (shooter:FindFirstChild("HumanoidRootPart") :: BasePart?)
	local aimDir = if origin and (aim - origin.Position).Magnitude > 0.1
		then (aim - origin.Position).Unit
		else Workspace.CurrentCamera.CFrame.LookVector
	muzzleFlash(aimDir) -- aim direction, so it can pick the barrel end rather than assume an axis
	if withTracer then
		tracer(muzzleWorld(aimDir), aim) -- same origin as the flash; nil falls back inside `tracer`
	end
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

-- 🔴 `lockedUntil` COVERS THE BAZOOKA'S RELOAD TOO, AND THAT IS LOAD-BEARING (Job #118).
-- It used to be `burstingUntil`, armed ONLY by a weapon with `burstDuration` -- so for every other
-- weapon the guard below was dead code. Give the Bazooka a 5-second server-side lockout and leave
-- this alone, and every click during those 5 seconds would draw a muzzle flash for a shot the server
-- has already thrown away, with the rocket counter frozen: about ten flashes and no rocket. That is
-- precisely the "the gun does not fire" confusion the Job #084 notes in this file were written to
-- eliminate, and it would be worse here because this cooldown is more than twice the M16's.
local lockedUntil = 0
-- When the current reload ends, and how long it was. Only the RETICLE and the aim ring read these:
-- they are what turn a dead five seconds into visible feedback rather than a weapon that feels
-- broken. `reloadFor` is kept so the ring can show PROGRESS, not just a binary state.
local reloadUntil = 0
local reloadFor = 0

local function updateCrosshair()
	dot.Visible = reticleShown()
	-- The trigger follows the reticle exactly: if there is nothing to aim, there is nothing to fire, and
	-- a fire button with no gun up would be a button that does nothing — the worst thing to put on a
	-- phone screen. `reticleShown()` already excludes the helm and the turret seat, so this never fights
	-- GunClient for the corner.
	TouchFire.setVisible("WeaponClient", reticleShown())
	-- yellow outranks the ammo colour: with your hands full the ammo count is not why you can't shoot,
	-- and showing red there would send the player hunting for ammo they already have.
	--
	-- Job #118 inserts RELOADING between them, and the order matters: a Bazooka that has just fired
	-- its last rocket is both reloading AND empty, and "reloading" is the useful half to say first --
	-- red would send the player looking for ammo during a wait that is about to end anyway. It turns
	-- red when the reload finishes and there is genuinely nothing left.
	dot.BackgroundColor3 = if blockedByCarry()
		then Theme.color.yellow
		elseif os.clock() < reloadUntil then Theme.color.metal
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

-- ── the impact ring (Job #118) ─────────────────────────────────────────────────
-- YOUR OWN preview of where the rocket would land, following your aim. The public warning marker that
-- appears once you actually fire is drawn by `RocketFx` from the server's broadcast -- this one is
-- local, unreplicated and seen by nobody else.
--
-- 🔴 IT RESOLVES THE IMPACT POINT THROUGH THE SAME `Ballistics.resolveImpact` THE SERVER USES.
-- Not a similar calculation: the same function, from the same module, with the same arguments. If this
-- ring and the real impact ever disagreed, the weapon would be lying to the player about where 300
-- damage is going -- and it would do it silently, because both halves would look correct on their own.
--
-- ⚠️ The ring is also the RELOAD indicator, which is why it fades from grey back to red rather than
-- simply switching on. A five-second wait with no on-screen change is indistinguishable from a broken
-- weapon; a ring visibly recovering its colour tells you both THAT you are reloading and HOW FAR IN.
local RING_READY = Theme.color.red
local RING_RELOADING = Color3.fromRGB(116, 120, 110)

local aimRing: GroundRing.Ring? = nil
local aimConn: RBXScriptConnection? = nil

local function projectileGun(): ItemDefs.ItemDef?
	local def = activeGun()
	return if def and def.flightTime then def else nil
end

local function stopAimRing()
	if aimConn then
		aimConn:Disconnect()
		aimConn = nil
	end
	if aimRing then
		aimRing.destroy()
		aimRing = nil
	end
end

-- Connected only while a projectile weapon is actually equipped, and torn down the moment it is not.
-- An always-on RenderStepped would be nearly free, but it would also leave a stray part in Workspace
-- for every player who has never bought the weapon.
local function syncAimRing()
	local def = projectileGun()
	if not def then
		stopAimRing()
		return
	end
	if aimConn then
		return -- already running for this weapon
	end

	-- Sized to the REAL blast radius, so the circle is the actual footprint rather than a decoration.
	local ring = GroundRing.new(def.blastRadius or 30, RING_READY)
	aimRing = ring
	-- ⚠️ HEARTBEAT, NOT RENDERSTEPPED. Measured during verification: a Studio client that is not
	-- rendering (window minimised or occluded) reports Heartbeat = 60/s and RenderStepped = **0/s**,
	-- and the ring simply stopped updating -- it sat at the world origin. The ring is a world-space
	-- anchored part with no camera-locked geometry, so it gains nothing from running before the render
	-- and loses the guarantee of running at all. Same change was made to the rocket in `RocketFx`.
	aimConn = RunService.Heartbeat:Connect(function()
		local d = projectileGun()
		if not d then
			return -- the equip watcher will tear this down; just do nothing this frame
		end
		-- Hidden for the same three reasons the reticle hides or goes yellow. A ring on the ground while
		-- you are seated at the helm or carrying a crate would promise a shot that cannot happen.
		if not reticleShown() or blockedByCarry() or not haveAmmo() then
			ring.setVisible(false)
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (char and root) then
			ring.setVisible(false)
			return
		end

		-- ⚠️ TOUCH AIMS ALONG THE RETICLE, NEVER THE FINGER. On a phone the thumb is parked on the fire
		-- button in the bottom-right corner (`TouchFire`), so sampling the pointer would peg the ring to
		-- the corner of the screen. Same rule the trigger itself already follows.
		local aim = if TouchFire.isActive() then reticleAim() else livePointerAim()
		local delta = aim - root.Position
		local aimDir = if delta.Magnitude > 0.1
			then delta.Unit
			else Workspace.CurrentCamera.CFrame.LookVector
		-- Launched from the barrel, exactly as the server will launch it (`Ballistics.muzzleWorld`).
		local origin = muzzleWorld(aimDir) or (root.Position + Vector3.new(0, 1.5, 0))

		local ignore: { Instance } = { char }
		local boat = Workspace:FindFirstChild("Boat")
		if boat then
			table.insert(ignore, boat)
		end
		ring.setAt(Ballistics.resolveImpact(origin, aim, d.range or 300, ignore))

		local now = os.clock()
		if now < reloadUntil and reloadFor > 0 then
			ring.setColor(RING_RELOADING:Lerp(RING_READY, 1 - (reloadUntil - now) / reloadFor))
		else
			ring.setColor(RING_READY)
		end
		ring.setVisible(true)
	end)
end

-- ── the burst (Job #117) ─────────────────────────────────────────────────────────────────────────
-- The SERVER owns the burst clock and the damage; this loop only draws it and feeds the aim. Both sides
-- read `burstInterval` from `ItemDefs`, so neither hand-copies the other's number.
local IDLE_DOT = UDim2.fromOffset(7, 7)
local BURST_DOT = UDim2.fromOffset(13, 13) -- a bloom while it rips, so firing is visible at the reticle

-- `sample()` is called once per bullet. Each input path supplies the sampler that is right for it, and
-- the difference matters:
--   · MOUSE -> the live pointer, so the player can sweep the burst across two targets.
--   · TOUCH -> the RETICLE (viewport centre), NEVER the finger. The thumb is parked on the fire button in
--     the bottom-right corner; sampling it would spray the burst into the corner of the screen. Same
--     reasoning as `TouchFire.onFire` below already applies to the first shot.
local function fire(sample: () -> Vector3)
	if not reticleShown() then
		return -- no gun up, or seated at the helm/turret: nothing is drawn, nothing to explain
	end
	-- Already firing. ⚠️ Deliberately SILENT — no `pulseBlocked()`, no click. Pulling the trigger again
	-- while an automatic weapon is mid-burst is not an error and must not be scolded; and without this
	-- guard every tap in the 2 s window would draw a muzzle flash and a tracer for a shot the server has
	-- already discarded — ~10 flashes with the ammo counter frozen, which is precisely the "the gun does
	-- not fire" confusion the Job #084 notes below were written to eliminate. On touch that is the common
	-- case: `TouchFire` is one-shot-per-tap by design and no weapon has ever had a cooldown this long.
	if os.clock() < lockedUntil then
		return
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

	local def = activeGun()
	local aim = sample()
	remote:FireServer(aim)
	-- ⚠️ NO TRACER FOR A PROJECTILE WEAPON -- see `shotFx`. A beam drawn to the landing spot four
	-- seconds before the rocket gets there spoils the arc, tells every other player exactly where it
	-- is going, and in first person puts a 300-stud Neon slab through the camera.
	shotFx(aim, def == nil or def.flightTime == nil)

	-- ── projectile weapons (Job #118) ───────────────────────────────────────────
	-- Nothing is drawn flying from here: `RocketFx` does that for EVERY player, this one included,
	-- off the server's launch broadcast. All this owns is the local trigger lockout and the reticle,
	-- so the 5 s reload reads on screen instead of the weapon feeling broken.
	if def and def.flightTime then
		local cool = def.cooldown or def.flightTime
		lockedUntil = os.clock() + cool
		reloadUntil = lockedUntil
		reloadFor = cool
		updateCrosshair()
		task.delay(cool, function()
			-- Guarded rather than cleared outright: this closure fires on a fixed delay, and a second
			-- shot landing in between would have pushed `lockedUntil` further out. Clearing blindly
			-- would end a reload that is genuinely still running.
			if os.clock() >= lockedUntil then
				lockedUntil = 0
				reloadUntil = 0
				updateCrosshair()
			end
		end)
		return
	end

	local burst = def and def.burstDuration
	if not burst then
		return -- single-shot gun: exactly what this function did before Job #117
	end

	lockedUntil = os.clock() + burst
	local step = (def and def.burstInterval) or 0.1
	local shots = math.max(1, math.floor(burst / step + 0.5))
	-- Skip the bloom if `pulseBlocked` happens to be mid-tween: it owns `dot.Size` for ~0.2 s and its
	-- restore would land in the middle of the burst and fight this.
	if not pulsing then
		dot.Size = BURST_DOT
	end

	task.spawn(function()
		for _ = 2, shots do
			task.wait(step)
			-- The server re-checks its own gates every bullet; this only stops DRAWING once the gun is
			-- plainly no longer up (slot switched, sat down at the helm, died).
			if not reticleShown() then
				break
			end
			local a = sample()
			aimRemote:FireServer(a) -- what the server will aim the next round along
			shotFx(a, true) -- a burst gun IS hitscan, so every bullet keeps its tracer
		end
		lockedUntil = 0
		dot.Size = IDLE_DOT
		updateCrosshair()
	end)
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
		-- The FIRST bullet uses exactly what the click gave us — byte-for-byte the pre-#117 behaviour for
		-- a single-shot gun — and only a burst's later bullets follow the live pointer.
		local clicked = Vector2.new(input.Position.X, input.Position.Y)
		local firstBullet = true
		fire(function()
			if firstBullet then
				firstBullet = false
				return aimPointFrom(clicked)
			end
			return livePointerAim()
		end)
	elseif input.UserInputType == Enum.UserInputType.Touch and not TouchFire.isActive() then
		-- Fallback only. `isActive()` is true on every touch device, so in practice this arm is dead on
		-- a phone and live nowhere else — it exists so that if the button ever fails to build, the gun
		-- is still usable rather than silently inert.
		local tapped = Vector2.new(input.Position.X, input.Position.Y)
		local firstBullet = true
		fire(function()
			if firstBullet then
				firstBullet = false
				return aimPointFrom(tapped)
			end
			return reticleAim() -- a burst tracks the reticle, not where the finger landed
		end)
	end
end)

-- The button aims at the RETICLE, not at where the finger landed: the reticle is drawn at the true
-- viewport centre (see this file's ScreenInsets note), which is the line the player is actually sighting
-- along. Firing at the thumb's position would send the shot into the bottom-right corner of the screen.
TouchFire.onFire(function()
	if not Workspace.CurrentCamera then
		return
	end
	fire(reticleAim)
end)

-- keep the crosshair in sync with equip/ammo/busy/seat changes
player:GetAttributeChangedSignal("Busy"):Connect(updateCrosshair)
player:GetAttributeChangedSignal("ActiveItem"):Connect(updateCrosshair)
-- Job #118: the ring lives and dies with the equipped weapon, so it is built when a projectile gun
-- comes up and destroyed the instant anything else does.
player:GetAttributeChangedSignal("ActiveItem"):Connect(syncAimRing)
-- 🔴 Job #117: EVERY gun's ammo attribute, derived from the catalog — not two hand-written names.
-- This was `AmmoPistol` and `AmmoShotgun` spelled out, and the asymmetry is what made it dangerous:
-- `InventoryHud` builds the same connections correctly by looping `ItemDefs.Items`, so adding a gun and
-- forgetting to add a line here gives you a hotbar count that updates and a reticle that does not — "the
-- HUD says 0 rounds but the crosshair is still cream", with nothing to grep for.
for _, def in pairs(ItemDefs.Items) do
	if def.ammoAttr then
		player:GetAttributeChangedSignal(def.ammoAttr):Connect(updateCrosshair)
	end
end
local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum:GetPropertyChangedSignal("SeatPart"):Connect(updateCrosshair)
	updateCrosshair()
	-- Rebuilt per character: `HumanoidRootPart` and `HeldItem` are both new after a respawn, and a ring
	-- left over from the previous body would sit wherever that body died.
	stopAimRing()
	syncAimRing()
	hum.Died:Connect(stopAimRing)
end
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
updateCrosshair()
syncAimRing()
