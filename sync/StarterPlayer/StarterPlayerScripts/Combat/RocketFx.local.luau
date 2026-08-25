--!strict
-- RocketFx.local.luau — drawing the Bazooka's rocket, its warning marker and its blast (Job #118).
--
-- Pure listener. It knows nothing about aiming, ammo or who is allowed to shoot: the server sends ONE
-- `RocketLaunched` event describing the entire flight, and this draws it. The server applies the damage
-- on its own copy of the same clock, so the two agree without talking again.
--
-- 🔴 WHY THE PROJECTILE IS DRAWN HERE AND NOT MOVED BY THE SERVER.
-- `PlaneServer:237-251` already shipped that bug and wrote it down: *"A server script writing an anchored
-- part's CFrame replicates as discrete property writes, and the client does NOT interpolate them"* — the
-- intro plane arrived in visible steps and had to be re-rendered client-side to fix it. A rocket crossing
-- 300 studs in 4 s would step exactly the same way for everyone except the shooter. Drawing locally from
-- broadcast parameters is smooth for all six players, and it also means Instance Streaming cannot pull
-- the rocket out from under its own flight at long range.
--
-- ⚠️ EVERY PART CREATED HERE IS `CanQuery = false` — see `GroundRing`'s header for the four unrelated
-- systems a queryable part breaks.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ballistics = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Ballistics"))
local GroundRing = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("GroundRing"))
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local launched = ReplicatedStorage:WaitForChild("RocketLaunched") :: RemoteEvent

-- ── audio ─────────────────────────────────────────────────────────────────────────────────────────
-- ⚠️ THESE IDS ARE ALSO IN `ServerStorage/Inventory/WeaponAssets.luau` (`WeaponAssets.ROCKET`), which is
-- the file that documents them and is "the one place a weapon's sounds are listed". They are repeated
-- here because **the client cannot read ServerStorage** and these are played client-side — the same
-- constraint that put `ItemDefs.HOLD_ANIM` in ReplicatedStorage rather than in `WeaponAssets`. Keep the
-- two in step; the lengths and the reasoning live in `WeaponAssets.ROCKET`.
local SFX = {
	whistle = "rbxassetid://138261119768443", -- 3.840 s — started at t=0.16 so it ENDS on the blast
	loop = "rbxassetid://73214531471418", -- 1.848 s — looped on the moving rocket
	impact = "rbxassetid://73027674412530", -- 2.112 s — the distant blast, 3D at the impact point
	impactNear = "rbxassetid://108549200090609", -- 4.776 s — the close blast, played 2D
}

-- Inside this, you hear `impactNear` (2D) instead of `impact` (3D). Tuned by ear; the blast radius is 30
-- studs, so this is "roughly, the blast happened where I am standing" rather than "I can see it".
local NEAR_DIST = 70
-- `impactNear` is 4.776 s long and the reload is 5 s, so a player shelling their own feet on cooldown
-- would keep it running almost continuously and a crew would stack it. Same class of mistake as the
-- cicadas in `GameSoundscape`. One near-cue at a time is plenty — the far clip still plays for the rest.
local NEAR_DEBOUNCE = 4.0
local lastNear = -math.huge

-- The rocket is hidden inside this distance of YOUR camera. Job #117 shipped the "big yellow square":
-- a Neon tracer that started at the head enclosed the first-person camera and rendered as a solid slab.
-- A 4-stud rocket spawning at the muzzle is the same bug with more geometry. Because this part is
-- client-LOCAL, each viewer can hide their own copy without affecting anyone else's view — which is
-- exact, and free.
local CAM_CLEARANCE = 5

local ROCKET_LENGTH = 4.0 -- studs, nose to tail: big enough to read against jungle at 200+ studs

local function newPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- 🔴 see the header
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function play(parent: Instance, id: string, volume: number, min: number, max: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = min
	s.RollOffMaxDistance = max
	s.Looped = looped
	s.Parent = parent
	s:Play()
	return s
end

-- ── the projectile ────────────────────────────────────────────────────────────────────────────────
-- The mesh is published into `ReplicatedStorage.CombatArt.Rocket` by the server at startup, because the
-- AssetLibrary it comes from is ServerStorage-only. Missing (an unsaved place has no AssetLibrary at all)
-- → a plain dark part, so the weapon still reads rather than firing nothing. Same everything-degrades
-- rule as `WeaponAssets`.
local function buildRocket(): BasePart
	local art = ReplicatedStorage:FindFirstChild("CombatArt")
	local src = art and art:FindFirstChild("Rocket")
	if src and src:IsA("BasePart") then
		local clone = src:Clone()
		clone.Name = "Rocket"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		-- Scaled from the part's ACTUAL size rather than a hardcoded factor, so a re-import at a
		-- different scale does not silently produce a 40-stud rocket.
		if clone.Size.X > 0.01 then
			clone.Size *= (ROCKET_LENGTH / clone.Size.X)
		end
		return clone
	end
	local p = newPart("Rocket")
	p.Size = Vector3.new(ROCKET_LENGTH, 0.6, 0.6)
	p.Color = Color3.fromRGB(48, 52, 44)
	p.Material = Enum.Material.Metal
	return p
end

-- The mesh's nose is +X (measured — see `WeaponAssets.ART.Bazooka`), so the rocket is oriented by
-- putting its +X along the direction of travel.
local function facing(pos: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-4 then
		return CFrame.new(pos)
	end
	local d = dir.Unit
	-- `CFrame.lookAt` is degenerate when the direction is parallel to its up vector — which happens for
	-- real here, on a shot fired straight up. Swap the reference up in that case.
	local up = if math.abs(d.Y) > 0.999 then Vector3.zAxis else Vector3.yAxis
	-- lookAt puts the LookVector (-Z) along `d`; a 90° yaw turns that into +X, the same
	-- `BARREL_X_TO_MINUS_Z` convention the held weapons use.
	return CFrame.lookAt(pos, pos + d, up) * CFrame.Angles(0, math.rad(90), 0)
end

local function addExhaust(rocket: BasePart)
	-- The trail runs between two attachments across the rocket's TAIL (its -X end), so the smoke leaves
	-- the motor rather than the middle of the body.
	local tailX = -rocket.Size.X / 2
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(tailX, 0.25, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(tailX, -0.25, 0)
	a1.Parent = rocket

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 1.6 -- long enough that the whole arc is legible as a curve in the sky
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.LightEmission = 0.25
	trail.Color = ColorSequence.new(Color3.fromRGB(235, 232, 225), Color3.fromRGB(120, 118, 112))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	trail.Parent = rocket

	local flame = Instance.new("ParticleEmitter")
	-- Ember tones lifted from `Campfire.luau`, the recipe the Torch already reuses. ⚠️ NOT a `Theme`
	-- colour: Theme is the UI palette and has no ember token, and inventing one here would be worse
	-- than a literal that says where it came from.
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 214, 140), Color3.fromRGB(214, 90, 24))
	flame.Size = NumberSequence.new(1.1, 0.15)
	flame.Transparency = NumberSequence.new(0.15, 1)
	flame.Lifetime = NumberRange.new(0.12, 0.26)
	flame.Rate = 60
	flame.Speed = NumberRange.new(2, 5)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.LightEmission = 0.8
	flame.Parent = a0
end

-- ── the blast ─────────────────────────────────────────────────────────────────────────────────────
-- Deliberately NOT routed through `CombatFx`/`CombatFeedback`. That path culls everything past 260 studs
-- (`CombatFeedback:38`) and this weapon reaches 300 — a max-range rocket would land in total silence with
-- nothing on screen, which reads as "the rocket did nothing". The damage NUMBERS still go through
-- `CombatFx` and are still culled at 260; the explosion itself is drawn here so it is always visible.
local function blastFx(impact: Vector3, radius: number)
	-- The flash: a short-lived neon ball. Scaled to the real blast radius so what you see is what it hit.
	local flash = newPart("Blast")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 226, 158)
	flash.Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5)
	flash.CFrame = CFrame.new(impact)
	flash.Parent = Workspace
	TweenService:Create(flash, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 1.5, radius * 1.5, radius * 1.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.5)

	-- The shockwave: a flat ring racing outward along the ground. This is the thing that tells a player
	-- at a distance how big the blast actually was.
	local wave = newPart("Shockwave")
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = Color3.fromRGB(255, 196, 120)
	wave.Size = Vector3.new(0.4, radius * 0.3, radius * 0.3)
	wave.Transparency = 0.35
	wave.CFrame = CFrame.new(impact + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = Workspace
	TweenService:Create(wave, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2.6, radius * 2.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, 0.7)

	-- Debris, smoke and light hang off one emitter part.
	local burst = newPart("BlastFx")
	burst.Size = Vector3.new(0.2, 0.2, 0.2)
	burst.Transparency = 1
	burst.CFrame = CFrame.new(impact)
	burst.Parent = Workspace

	local debris = Instance.new("ParticleEmitter")
	debris.Color = ColorSequence.new(Color3.fromRGB(120, 100, 74), Color3.fromRGB(58, 48, 38))
	debris.Size = NumberSequence.new(1.6, 0.3)
	debris.Transparency = NumberSequence.new(0.1, 1)
	debris.Lifetime = NumberRange.new(0.7, 1.5)
	debris.Speed = NumberRange.new(24, 58)
	debris.SpreadAngle = Vector2.new(70, 70)
	debris.Acceleration = Vector3.new(0, -70, 0)
	debris.Rate = 0
	debris.Parent = burst

	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 60), Color3.fromRGB(130, 126, 118))
	smoke.Size = NumberSequence.new(6, 22)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.2, 2.4)
	smoke.Speed = NumberRange.new(6, 16)
	smoke.SpreadAngle = Vector2.new(45, 45)
	smoke.Rate = 0
	smoke.Parent = burst

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 196, 120)
	light.Range = math.min(60, radius * 2)
	light.Brightness = 6
	light.Shadows = false
	light.Parent = burst

	-- ⚠️ Modest counts on purpose. This is a mobile-first game (`roblox-optimization`), and a 30-stud
	-- crater is already carried by the flash and the shockwave; a thousand particles would buy nothing.
	debris:Emit(46)
	smoke:Emit(14)
	TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()

	-- 🔴 NEAR OR FAR, DECIDED PER CLIENT — that is the whole reason there are two clips.
	-- A positional Sound has no per-listener branch, so making both 3D would play BOTH to everybody at
	-- different volumes. Each client picks one from its OWN camera distance, and six players hear one
	-- explosion correctly from six positions.
	local cam = Workspace.CurrentCamera
	local dist = if cam then (cam.CFrame.Position - impact).Magnitude else math.huge
	if dist <= NEAR_DIST and os.clock() - lastNear >= NEAR_DEBOUNCE then
		lastNear = os.clock()
		-- 2D: "it went off on top of me" is a concussive, subjective cue, and a 3D sound five studs away
		-- does not read that way. Parented to SoundService so nothing positional touches it.
		local s = Instance.new("Sound")
		s.SoundId = SFX.impactNear
		s.Volume = 0.65
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 6)
	else
		play(burst, SFX.impact, 0.7, 40, 700, false)
	end

	Debris:AddItem(burst, 4)
end

-- ── one launch ────────────────────────────────────────────────────────────────────────────────────
launched.OnClientEvent:Connect(function(origin: Vector3, impact: Vector3, flight: number, arc: number, radius: number)
	if typeof(origin) ~= "Vector3" or typeof(impact) ~= "Vector3" then
		return
	end
	flight = if typeof(flight) == "number" then flight else 4
	arc = if typeof(arc) == "number" then arc else Ballistics.arcHeightFor((impact - origin).Magnitude)
	radius = if typeof(radius) == "number" then radius else 30

	-- The public warning marker. Everyone sees it, at the REAL blast radius, so "clear out" is an honest
	-- instruction rather than a decoration.
	local marker = GroundRing.new(radius, Theme.color.red)
	marker.setAt(impact)
	marker.pulse(0.7)

	local rocket = buildRocket()
	rocket.CFrame = facing(origin, impact - origin)
	rocket.Parent = Workspace
	addExhaust(rocket)

	play(rocket, SFX.loop, 0.35, 15, 250, true)
	-- ⚠️ t = 0.16, NOT t = 0. The clip is 3.840 s against a 4.000 s flight, so starting it at launch
	-- would leave 160 ms of silence in the worst possible place: immediately before the explosion.
	-- Delayed, it ends ON the blast. At the launch end 160 ms is inaudible under the fire clip.
	task.delay(math.max(0, flight - 3.84), function()
		if rocket.Parent then
			play(rocket, SFX.whistle, 0.45, 20, 400, false)
		end
	end)

	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - t0) / flight
		if alpha >= 1 then
			stop()
			rocket:Destroy()
			marker.destroy()
			blastFx(impact, radius)
			return
		end
		local pos = Ballistics.pointAt(origin, impact, arc, alpha)
		-- Orientation from the tangent, sampled a hair ahead, so the rocket noses over at the top of its
		-- arc instead of flying flat all the way down.
		local ahead = Ballistics.pointAt(origin, impact, arc, math.min(1, alpha + 0.01))
		rocket.CFrame = facing(pos, ahead - pos)

		-- 🔴 Hidden while it is inside YOUR camera — see CAM_CLEARANCE above.
		local cam = Workspace.CurrentCamera
		local tooClose = cam ~= nil and (cam.CFrame.Position - pos).Magnitude < CAM_CLEARANCE
		rocket.LocalTransparencyModifier = if tooClose then 1 else 0
	end)

	-- A safety net, not the normal path: if RenderStepped stops arriving (the window loses focus, the
	-- player is teleported out mid-flight) the rocket must not become a permanent ornament.
	task.delay(flight + 3, function()
		if conn then
			stop()
			rocket:Destroy()
			marker.destroy()
		end
	end)
end)

print("[RocketFx] projectile FX online")
