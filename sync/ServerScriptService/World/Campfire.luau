--!strict
-- Campfire.luau — the camp's fire, built not sourced (Job #077).
--
-- The re-dressed camps need a fire and the GAME place had none (the built campfire in `ASSETS.md` §1 is
-- the LOBBY's). **Every Creator Store result was the same spam-uploaded "realistic campfire"** — and
-- "realistic" is the wrong register for our stylized look (STYLEGUIDE §2). So this rebuilds the lobby's
-- recipe from parts we already own and have already scanned: a `RockA/B/C` ring, crossed `LogMossy`, and
-- Fire / Smoke / embers / PointLight / crackle on a single anchor part.
--
-- Building it means the recipe exists ONCE in code instead of being hand-placed per camp, and it is
-- on-palette, needs no attribution, and is identical to the lobby by construction.
--
-- ── The one part that is not dressing ─────────────────────────────────────────────────────────────
-- `Core` is a 1-stud invisible anchor. Everything that emits — Fire, Smoke, embers, the light, the
-- crackle — hangs off it, so the fire keeps working even when the AssetLibrary is missing (an unsaved
-- place file), and so the smoke column's origin does not move when a rock model is swapped.

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))

local Campfire = {}

local RING_RADIUS = 4.6 -- rocks sit this far out; the logs cross inside it
local RING_ROCKS = 6

export type BuildParams = {
	position: Vector3, -- centre of the fire, ON the ground (already ground-measured by the caller)
	parent: Instance,
	lib: { [string]: PVInstance }, -- ServerStorage.AssetLibrary, flattened name → Model or single part
	rng: Random,
}

-- Clone a dressing model, hard-set it safe (anchored, non-colliding, no shadow) and seat it.
-- ⚠️ Non-colliding is deliberate for ALL of it: you fight in a camp, and a ring of collidable rocks
-- around the one landmark players walk to is a snag hazard, not detail.
local function dressing(lib: { [string]: PVInstance }, name: string, cf: CFrame, scale: number, parent: Instance): Model?
	local source = lib[name]
	if not source or not source:IsA("Model") then
		return nil -- every rock/log in the library is a Model; nothing here needs the single-part path
	end
	local clone = source:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	clone:ScaleTo(scale)
	clone:PivotTo(cf)
	clone.Parent = parent
	return clone
end

function Campfire.build(params: BuildParams): Model
	local pos, rng = params.position, params.rng

	local fire = Instance.new("Model")
	fire.Name = "Campfire"

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Transparency = 1
	core.Size = Vector3.one
	-- Job #084: this is what makes a fire a rest point. Tagged on the CORE rather than the model so the
	-- heal radius is measured from the flame itself and cannot drift when dressing models are swapped.
	CollectionService:AddTag(core, CampDefs.TAG.campfire)
	core.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	core.Parent = fire
	fire.PrimaryPart = core

	-- ── the ring of stones ──────────────────────────────────────────────────────────────────────
	local rockNames = { CampDefs.MODEL.rockSmall, CampDefs.MODEL.rockMid, CampDefs.MODEL.rockLarge }
	for i = 1, RING_ROCKS do
		local a = (i / RING_ROCKS) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = RING_RADIUS + rng:NextNumber(-0.5, 0.5)
		local at = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		dressing(
			params.lib,
			rockNames[rng:NextInteger(1, #rockNames)],
			CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			rng:NextNumber(0.22, 0.4),
			fire
		)
	end

	-- ── two logs, crossed over the fire ─────────────────────────────────────────────────────────
	for i = 1, 2 do
		local yaw = (i == 1 and 0.6 or 2.2) + rng:NextNumber(-0.2, 0.2)
		dressing(
			params.lib,
			CampDefs.MODEL.log,
			CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(9)),
			rng:NextNumber(0.4, 0.55),
			fire
		)
	end

	-- ── flame ───────────────────────────────────────────────────────────────────────────────────
	local flame = Instance.new("Fire")
	flame.Name = "Flame"
	flame.Size = 7
	flame.Heat = 9
	flame.Color = Color3.fromRGB(255, 158, 62)
	flame.SecondaryColor = Color3.fromRGB(214, 90, 24)
	flame.Parent = core

	-- Embers: what makes the fire read as alive from further off than the Fire object survives.
	local ember = Instance.new("ParticleEmitter")
	ember.Name = "Embers"
	ember.Texture = "rbxasset://textures/particles/fire_main.dds"
	ember.Rate = CampDefs.VFX.ember.rate
	ember.Speed = NumberRange.new(CampDefs.VFX.ember.speed[1], CampDefs.VFX.ember.speed[2])
	ember.Lifetime = NumberRange.new(CampDefs.VFX.ember.lifetime[1], CampDefs.VFX.ember.lifetime[2])
	ember.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, CampDefs.VFX.ember.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	ember.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(198, 74, 30))
	ember.LightEmission = 0.85
	ember.Acceleration = Vector3.new(0, 5, 0)
	ember.SpreadAngle = Vector2.new(22, 22)
	ember.Rotation = NumberRange.new(0, 360)
	ember.Parent = core

	-- ── the smoke column ────────────────────────────────────────────────────────────────────────
	-- ⚠️ THIS IS A GAMEPLAY SIGNAL, NOT DRESSING (assumption A2). Nothing else tells the driver on the
	-- river that a landing is coming, so it is sized to be read from the water at approach distance and
	-- to clear the band-3 canopy wall. If you shrink it to "look nicer up close" you have deleted a
	-- navigational cue — verify from the boat, not from beside the fire.
	local smoke = Instance.new("Smoke")
	smoke.Name = "Column"
	smoke.Size = CampDefs.VFX.smoke.size
	smoke.Opacity = CampDefs.VFX.smoke.opacity
	smoke.RiseVelocity = CampDefs.VFX.smoke.riseSpeed
	smoke.Color = Color3.fromRGB(178, 170, 158) -- grey, warmed slightly; never pure grey against jungle
	smoke.Parent = core

	-- ── the practical ───────────────────────────────────────────────────────────────────────────
	-- Tagged `NightLight` so `LightController` switches it at dusk/dawn — a campfire's glow is invisible
	-- at noon anyway, so an always-on light would be a dynamic light paid for and never seen.
	local L = CampDefs.LIGHT.fire
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Brightness = L.brightness
	light.Range = L.range
	light.Color = L.color
	light.Shadows = L.shadows
	light.Parent = core
	light:SetAttribute("BaseBrightness", L.brightness) -- the flicker task reads this, never the live value
	CollectionService:AddTag(light, CampDefs.TAG.nightLight)
	CollectionService:AddTag(light, CampDefs.TAG.fireLight)

	-- ── crackle ─────────────────────────────────────────────────────────────────────────────────
	-- Positional, on its own part, per the `GameSoundscape` rule. `RollOffMaxDistance` is set so the
	-- crackle has faded out before the next camp is in earshot.
	local S = CampDefs.SOUND.crackle
	local crackle = Instance.new("Sound")
	crackle.Name = "Crackle"
	crackle.SoundId = S.id
	crackle.Looped = true
	crackle.Volume = S.volume
	crackle.RollOffMode = Enum.RollOffMode.InverseTapered
	crackle.RollOffMinDistance = S.min
	crackle.RollOffMaxDistance = S.max
	crackle.Parent = core
	crackle:Play()

	fire.Parent = params.parent
	return fire
end

return Campfire
