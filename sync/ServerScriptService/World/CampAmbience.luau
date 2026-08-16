--!strict
-- CampAmbience.luau — camp VFX, positional audio and night practicals (Job #077).
--
-- Before this, the GAME place had **zero `Light` objects in the entire Workspace** and no camp audio or
-- VFX at all. `LightController` has switched anything tagged `NightLight` at dusk since Job 038 — it
-- worked, it just had nothing to switch except the player's torch and the boat searchlight, both of
-- which are CARRIED. This is the first placed light in the world.
--
-- ── Two shared tasks, not per-camp connections ────────────────────────────────────────────────────
-- Camps are destroyed when the boat passes them (`ExcursionServer.CULL_BEHIND`). A per-camp connection
-- or a "list of my emitters" holds a reference to every camp of the whole run and leaks the lot. Both
-- loops below iterate a `CollectionService` tag instead, which prunes itself the moment an instance is
-- destroyed. Same reason `LightController` is written that way.
--
-- ── Budget ────────────────────────────────────────────────────────────────────────────────────────
-- `CampDefs.BUDGET` is a cap PER CAMP, and it is enforced by construction here rather than checked:
-- this module creates exactly 3 lights (the campfire's is the 4th) and 2 emitters, of which fireflies
-- and motes are phase-exclusive so only one is ever running. With 1–2 camps live that is ~8 lights and
-- ~6 emitters worst case, sharing a frame with Job #076's ~5,560 foliage instances.

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))
-- for `worldBottom` — seating the lantern on the sandbag line by its true base rather than its pivot
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))

local CampAmbience = {}

-- ── small builders ────────────────────────────────────────────────────────────────────────────────

-- An invisible, query-free anchor. Emitters and lights need a BasePart; nothing should be able to see,
-- touch, raycast against or collide with the thing holding them.
local function anchor(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Positional world sound, built the one way `GameSoundscape` prescribes: on its own part, with rolloff,
-- never through the 2D bed. Exported because `DockServer` needs the identical construction.
function CampAmbience.positionalSound(
	parent: Instance,
	def: { id: string, volume: number, min: number, max: number },
	name: string,
	autoPlay: boolean
): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.id
	s.Looped = true
	s.Volume = def.volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = def.min
	s.RollOffMaxDistance = def.max
	s.Parent = parent
	if autoPlay then
		s:Play()
	end
	return s
end

-- The lantern FIXTURE, looked up once. Missing library => `practical` falls back to its invisible anchor
-- and the camp is lit exactly as it was before, which is the everything-degrades rule this codebase runs
-- on: no art must ever mean no light.
local lanternSource: PVInstance? = nil
do
	local lib = game:GetService("ServerStorage"):FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			local m = group:FindFirstChild(CampDefs.MODEL.lantern)
			-- BaseParts too, not only Models — the library stores some assets as lone MeshParts
			if m and (m:IsA("Model") or m:IsA("BasePart")) then
				lanternSource = m :: PVInstance
				break
			end
		end
	end
end

-- The highest point of an instance's parts, in world Y.
local function topOf(inst: PVInstance): number?
	local maxY = -math.huge
	local parts = inst:GetDescendants()
	table.insert(parts, inst) -- a MeshPart prop IS the part
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			maxY = math.max(maxY, d.Position.Y + d.Size.Y / 2)
		end
	end
	return if maxY > -math.huge then maxY else nil
end

-- 🔴 WHAT THE PERIMETER LANTERN STANDS ON — MEASURED, NOT CALCULATED.
--
-- The obvious version of this was `params.groundY + <sandbag height>`. It put every lantern exactly
-- 1.0 stud in the air, because those two numbers come from different places: `prop` seats each sandbag
-- on its OWN `groundAt(x, z)` raycast, while `params.groundY` is the ground under the CAMPFIRE. On
-- anything but perfectly flat ground they disagree, and the camp floor is carved terrain, not a plane.
--
-- This is the same footprint-vs-point mistake `FoliageDefs` documents at length. The fix is the same:
-- stop predicting where the wall ended up and go and measure the wall.
local function mountFor(parent: Instance, x: number, z: number, fallbackY: number): number
	local best, bestD = nil, math.huge
	for _, d in ipairs(parent:GetChildren()) do
		if d.Name == CampDefs.MODEL.sandbag and d:IsA("PVInstance") then
			local p = d:GetPivot().Position
			local flat = (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude
			if flat < bestD then
				best, bestD = d, flat
			end
		end
	end
	-- Only accept a wall actually AT this slot. `kind.sandbags = false` builds a camp with none at all,
	-- and the nearest one then belongs to a different slot 19 studs away.
	if best and bestD < 6 then
		local t = topOf(best :: PVInstance)
		if t then
			return t
		end
	end
	-- No wall here: stand it on the ground, measured at this x/z rather than borrowed from the campfire.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, fallbackY + 40, z), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else fallbackY
end

-- Builds the lantern that a perimeter light shines OUT of, standing with its base at `baseY`.
-- Returns the flame position for the caller to hang the `PointLight` at, or nil if there is no art.
local function lanternFixture(x: number, z: number, baseY: number, parent: Instance): Vector3?
	if not lanternSource then
		return nil
	end
	local c = lanternSource:Clone()
	local parts = c:GetDescendants()
	table.insert(parts, c) -- a MeshPart source IS the part; it has no BasePart descendants
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- Dressing on top of a barricade you fight over: a collidable one would snag players and
			-- bullets on a 2-stud prop.
			d.CanCollide = false
			d.CastShadow = false
		end
	end

	local scale = CampDefs.SCALE[CampDefs.MODEL.lantern] or 1
	if math.abs(scale - 1) > 1e-3 then
		if c:IsA("Model") then
			c:ScaleTo(c:GetScale() * scale)
		elseif c:IsA("BasePart") then
			c.Size *= scale
		end
	end

	c.Name = "Lantern"
	c:PivotTo(CFrame.new(x, baseY, z))
	-- Seat it on the mount by its TRUE base, not its pivot: an imported mesh's origin is wherever the
	-- publisher left it, so pivoting to `baseY` alone would sink or float the lantern by an unknown amount.
	local bottom = FoliageDefs.worldBottom(c)
	if bottom then
		c:PivotTo(c:GetPivot() + Vector3.new(0, baseY - bottom, 0))
	end
	c.Parent = parent

	local height = if c:IsA("Model") then select(2, c:GetBoundingBox()).Y else (c :: BasePart).Size.Y
	return Vector3.new(x, baseY + height * CampDefs.LIGHT.lanternFlame, z)
end

-- A warm practical. Tagged `NightLight`, so `LightController` — not this module — owns `Enabled`.
--
-- `mount` is the world Y the FIXTURE stands on. Pass it and the light gets a real lantern to come out of,
-- positioned at that lantern's glass; omit it and the light hangs on an invisible anchor at `pos` exactly
-- as it did before Job #079 (which is what the hut's interior light still wants — see the call site).
local function practical(
	pos: Vector3,
	parent: Instance,
	def: { brightness: number, range: number, color: Color3, shadows: boolean },
	name: string,
	mount: number?
)
	local lightPos = pos
	if mount then
		local flame = lanternFixture(pos.X, pos.Z, mount, parent)
		if flame then
			lightPos = flame
		end
	end
	local a = anchor(name, Vector3.one, CFrame.new(lightPos), parent)
	local l = Instance.new("PointLight")
	l.Name = "Light"
	l.Brightness = def.brightness
	l.Range = def.range
	l.Color = def.color
	l.Shadows = def.shadows
	l.Parent = a
	CollectionService:AddTag(l, CampDefs.TAG.nightLight)
end

-- Area emitter: the anchor part is sized to the effect's radius so particles spawn ACROSS the camp
-- rather than out of one point. Emission comes off the part's volume, which is the cheapest way to get
-- a scattered field without one emitter per firefly.
local function areaEmitter(centre: Vector3, parent: Instance, radius: number, name: string): ParticleEmitter
	local a = anchor(name .. "Field", Vector3.new(radius * 2, 10, radius * 2), CFrame.new(centre + Vector3.new(0, 6, 0)), parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = a
	return e
end

-- ── the per-camp dressing ─────────────────────────────────────────────────────────────────────────

export type DressParams = {
	centre: Vector3, -- camp centre (the fire)
	approach: Vector3, -- unit direction the player walks INTO the camp
	parent: Instance,
	groundY: number, -- measured, not assumed — see ExcursionServer.groundAt
	hutPos: Vector3?, -- if given, one warm light goes inside it
}

function CampAmbience.dress(params: DressParams)
	local centre, parent = params.centre, params.parent

	-- ── fireflies (night) ───────────────────────────────────────────────────────────────────────
	-- STYLEGUIDE §8 names fireflies explicitly. Gated on `Workspace.Phase` so they cost nothing by day.
	local F = CampDefs.VFX.fireflies
	local flies = areaEmitter(centre, parent, F.radius, "Fireflies")
	flies.Rate = F.rate
	flies.Lifetime = NumberRange.new(F.lifetime[1], F.lifetime[2])
	flies.Speed = NumberRange.new(0.4, 1.6)
	flies.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.22),
		NumberSequenceKeypoint.new(0.7, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	flies.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.1),
		NumberSequenceKeypoint.new(0.75, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	flies.Color = ColorSequence.new(Color3.fromRGB(255, 216, 120))
	flies.LightEmission = 1
	flies.Acceleration = Vector3.new(0, 0.3, 0)
	flies.SpreadAngle = Vector2.new(180, 180)
	CollectionService:AddTag(flies, CampDefs.TAG.nightVFX)

	-- ── dust / pollen motes (day) ───────────────────────────────────────────────────────────────
	-- The day counterpart: drifting motes are what sell warm shafts of light through the canopy.
	local M = CampDefs.VFX.motes
	local motes = areaEmitter(centre, parent, M.radius, "Motes")
	motes.Rate = M.rate
	motes.Lifetime = NumberRange.new(M.lifetime[1], M.lifetime[2])
	motes.Speed = NumberRange.new(0.2, 0.9)
	motes.Size = NumberSequence.new(0.16)
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Color = ColorSequence.new(Color3.fromRGB(246, 232, 196))
	motes.LightEmission = 0.5
	motes.Acceleration = Vector3.new(0.4, 0.05, 0.2) -- a slow drift, so they aren't a static haze
	motes.SpreadAngle = Vector2.new(180, 180)
	CollectionService:AddTag(motes, CampDefs.TAG.dayVFX)

	-- ── practicals: two along the sandbag line, one inside a hut ────────────────────────────────
	-- Exactly 3 here; the campfire's own light is the 4th and last of `BUDGET.lightsPerCamp`.
	local perim = CampDefs.LIGHT.perimeter
	for _, slot in ipairs({ CampDefs.LAYOUT.sandbags[1], CampDefs.LAYOUT.sandbags[3] }) do
		local at = CampDefs.slotToWorld(centre, params.approach, slot)
		-- The lantern stands on the sandbag wall these slots also place — `mountFor` measures that wall
		-- rather than assuming where it landed. The +4.5 stays as the no-art fallback height, so a place
		-- file without the `Lantern` model lights the camp exactly as Job #077 did.
		practical(
			Vector3.new(at.X, params.groundY + 4.5, at.Z),
			parent,
			perim,
			"PerimeterLight",
			mountFor(parent, at.X, at.Z, params.groundY)
		)
	end
	if params.hutPos then
		-- ⚠️ NO FIXTURE HERE, DELIBERATELY. This one hangs 6 studs up inside a hut, where there is no
		-- surface to stand a lantern on — a lantern floating under a roof with nothing holding it looks
		-- worse than a light with no visible source, and you are rarely inside the hut to see it. It
		-- wants a hook or a rafter modelled first.
		practical(params.hutPos + Vector3.new(0, 6, 0), parent, CampDefs.LIGHT.interior, "HutLight")
	end
end

-- ── shared task 1: day/night VFX gating ───────────────────────────────────────────────────────────
-- `Phase` is published by `DayNightServer`. Emitters are toggled with `Enabled`, not destroyed, because
-- a camp lives across at most one or two phase flips and rebuilding is more expensive than a boolean.
local function applyPhase()
	local night = Workspace:GetAttribute("Phase") == "night"
	for _, e in CollectionService:GetTagged(CampDefs.TAG.nightVFX) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = night
		end
	end
	for _, e in CollectionService:GetTagged(CampDefs.TAG.dayVFX) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = not night
		end
	end
end

Workspace:GetAttributeChangedSignal("Phase"):Connect(applyPhase)
-- A camp built mid-phase must match immediately, exactly as LightController does for new NightLights.
CollectionService:GetInstanceAddedSignal(CampDefs.TAG.nightVFX):Connect(function(e)
	if e:IsA("ParticleEmitter") then
		e.Enabled = Workspace:GetAttribute("Phase") == "night"
	end
end)
CollectionService:GetInstanceAddedSignal(CampDefs.TAG.dayVFX):Connect(function(e)
	if e:IsA("ParticleEmitter") then
		e.Enabled = Workspace:GetAttribute("Phase") ~= "night"
	end
end)
applyPhase()

-- ── shared task 2: the fire flicker ───────────────────────────────────────────────────────────────
-- ⚠️ TOUCHES `Brightness` ONLY. `Enabled` belongs to `LightController` (dusk/dawn); writing it from here
-- would mean two systems fighting over the same property twice a day. Disabled lights are skipped, so by
-- day this loop costs one empty iteration at 11 Hz.
task.spawn(function()
	local flick = CampDefs.LIGHT.flicker
	local step = 1 / flick.hz
	local t = 0
	while true do
		t += step
		for _, l in CollectionService:GetTagged(CampDefs.TAG.fireLight) do
			if l:IsA("PointLight") and l.Enabled then
				local base = (l:GetAttribute("BaseBrightness") :: number?) or l.Brightness
				-- two out-of-phase sines + a jitter: cheaper than noise and it never settles into a
				-- visible pulse, which a single sine does immediately
				local wobble = math.sin(t * 5.3) * 0.5 + math.sin(t * 11.7) * 0.3 + math.random() * 0.2 - 0.1
				l.Brightness = base * (1 + wobble * flick.amplitude)
			end
		end
		task.wait(step)
	end
end)

return CampAmbience
