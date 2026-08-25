--!strict
-- Generators.luau — destructible generator props (Job #115). SERVER ONLY, and deliberately REUSABLE:
-- the three end-zone generators are wired by `GeneratorServer.server.luau`, and a later job that spawns
-- generators in a camp or a village gets identical behaviour for free.
--
-- ── The whole feature hangs off ONE attribute ────────────────────────────────────────────────────
-- `MeleeServer`, `WeaponServer` and `GunServer` all already do the same thing: find a Model carrying a
-- known TAG, subtract from its `HP` attribute, and let something else notice. That is the seam this
-- module plugs into, so:
--   · making a generator damageable is one tag in each of those three target lists — no new damage
--     code, no new remote, and the numbers stay whatever those weapons already deal;
--   · every reaction here (zap, burning particles, bar, death) is driven by watching `HP` CHANGE.
-- Nothing polls. There is no Heartbeat loop in this file, and there must not be one: three generators
-- that each cost a frame budget to stand still would be three props paid for like three enemies.
--
-- ── Proximity is the BillboardGui's job, not a loop's ────────────────────────────────────────────
-- "Show the health bar when approached" is `BillboardGui.MaxDistance`, which culls PER VIEWER on the
-- client for free. A server-side distance loop would have had to pick ONE answer for the whole crew
-- (the GUI is one replicated instance), so it would have been both slower and less correct.
--
-- ── Everything scales off the model's own bounds ─────────────────────────────────────────────────
-- ⚠️ `Generator3` in the end zone is the SAME model at HALF scale (4.48 x 4 x 2.66 against
-- 8.96 x 8 x 5.31, measured 2026-08-25). Nothing below may hard-code a stud offset or a particle size:
-- the sign height, spark size, light range and smoke size are all derived from `GetBoundingBox`, or the
-- small one wears the big one's bar three studs inside its own roof.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local Generators = {}

-- ── the contract other files rely on ────────────────────────────────────────────────────────────
-- TAG is what the three damage sites look for. NAME_PREFIX is how editor-placed ones are found — the
-- same "find the hand-placed fitting by name" contract `EscapeServer` and `StagingServer` use.
Generators.TAG = "Generator"
Generators.NAME_PREFIX = "Generator"
Generators.LIBRARY_PATH = { "AssetLibrary", "Structures", "Generator" } -- under ServerStorage

-- 150 = exactly 10 axe swings (`ItemDefs.Axe.damage` = 15), 8 pistol shots (20), or ~2 point-blank
-- shotgun blasts (24 x 6 pellets). User's call: "with fists you must hit like 10 times, with bullets
-- they will take more damage" — which falls out of the weapons' own numbers, so nothing here scales
-- damage per weapon.
Generators.MAX_HP = 150

-- ── audio (registry `audio.md` → Jungle / GAME place; user uploads 2026-08-25) ───────────────────
-- Ids live in ONE table, the way `GameSoundscape` and `PlaneServer` do it — nothing below writes an
-- asset id inline.
--
-- ⚠️ `eletricity_going` is a 3.94 s HUM (measured in Studio, not assumed), not a zap. So it is used
-- twice, and differently: looped and quiet as the idle voice of a live generator, and RESTARTED loud
-- and cut short as the hit reaction. Playing the whole 3.94 s clip on every hit would overlap itself
-- six times over a 10-swing kill and turn a fight into a drone.
local SFX = {
	hum = "rbxassetid://90617779140381", -- eletricity_going  3.94 s — looped idle + truncated hit zap
	dead = "rbxassetid://119782619832290", -- generator_dead   1.10 s — one-shot on death
}
local ZAP_TAIL = 0.5 -- seconds of `hum` that read as a zap when restarted at volume

-- ── tuning ──────────────────────────────────────────────────────────────────────────────────────
local APPROACH_STUDS = 70 -- bar appears at this range (per viewer — see the header)
local DEAD_SIGN_STUDS = 110 -- "DISABLED" reads from further: it is state, not a combat readout
local HUM_VOLUME, ZAP_VOLUME, DEAD_VOLUME = 0.32, 0.9, 0.95
local BURN_SECONDS = 1.6 -- how long a hit keeps smouldering before it settles back down

-- ── module state ────────────────────────────────────────────────────────────────────────────────
type Rig = {
	model: Model,
	part: BasePart,
	scale: number,
	hum: Sound,
	zap: Sound,
	sparks: ParticleEmitter,
	burn: ParticleEmitter,
	smoke: Smoke,
	light: PointLight,
	track: Frame,
	fill: Frame,
	status: TextLabel,
	gui: BillboardGui,
	lastHP: number,
	dead: boolean,
	zapToken: number,
	burnToken: number,
}
local rigs: { [Model]: Rig } = {}
local disabledListeners: { (Model) -> () } = {}

-- ── helpers ─────────────────────────────────────────────────────────────────────────────────────

-- The one BasePart a generator model is made of. Named `Generator` inside every copy of the asset, but
-- fall back to any BasePart so a re-dress or a re-export cannot silently un-wire the prop.
local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local named = model:FindFirstChild("Generator")
	if named and named:IsA("BasePart") then
		return named
	end
	return model:FindFirstChildWhichIsA("BasePart")
end

local function playOnce(parent: BasePart, id: string, volume: number, maxDist: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = maxDist
	s.Parent = parent
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

-- ── the FX rig ──────────────────────────────────────────────────────────────────────────────────

local function buildRig(model: Model, part: BasePart): Rig
	-- Scale factor against the full-size asset (8 studs tall). Everything visual is multiplied by this.
	local _, bb = model:GetBoundingBox()
	local scale = math.clamp(bb.Y / 8, 0.35, 3)

	-- ── the live hum ───────────────────────────────────────────────────────────────────────────
	-- Positional, on the prop itself, per the `GameSoundscape` rule that world audio is 3D and only 2D
	-- beds live on SoundService. `InverseTapered` + a 90-stud tail means one generator has faded before
	-- you are in earshot of the next (they sit ~200 studs apart in the end zone).
	local hum = Instance.new("Sound")
	hum.Name = "Hum"
	hum.SoundId = SFX.hum
	hum.Looped = true
	hum.Volume = HUM_VOLUME
	hum.RollOffMode = Enum.RollOffMode.InverseTapered
	hum.RollOffMinDistance = 10
	hum.RollOffMaxDistance = 90
	hum.Parent = part
	hum:Play()

	-- The hit zap: ONE reused instance, restarted per hit and cut at ZAP_TAIL (see the SFX note).
	local zap = Instance.new("Sound")
	zap.Name = "Zap"
	zap.SoundId = SFX.hum
	zap.Volume = ZAP_VOLUME
	zap.PlaybackSpeed = 1.15 -- reads as a discharge rather than a second copy of the idle hum
	zap.RollOffMode = Enum.RollOffMode.InverseTapered
	zap.RollOffMinDistance = 8
	zap.RollOffMaxDistance = 130
	zap.Parent = part

	-- ── electricity, always on while alive ─────────────────────────────────────────────────────
	-- Emitters are parented to the PART, not to an Attachment, so sparks come off the whole housing
	-- instead of one point in the middle of it.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Electricity"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- same spark art as CampAmbience
	-- 20/s at a 0.22-0.55 s lifetime keeps ~7 sparks alive at any moment. Deliberately readable rather
	-- than subtle: this is the cue that says a generator is LIVE and therefore worth breaking, and it has
	-- to survive being seen across a lit base at noon. Three of them is still nothing next to the
	-- ~9,170-part foliage window this game already carries.
	sparks.Rate = 20
	sparks.Lifetime = NumberRange.new(0.22, 0.55)
	sparks.Speed = NumberRange.new(3, 9)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(198, 240, 255), Color3.fromRGB(96, 170, 255))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.SpreadAngle = Vector2.new(180, 180) -- arcing in every direction, not a fountain
	sparks.Acceleration = Vector3.new(0, -6, 0) -- sparks fall; only smoke rises
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.Parent = part

	-- ── the hit reaction: bigger, RED, burning ─────────────────────────────────────────────────
	-- `Rate = 0` at rest: this emitter exists to be `Emit`-ed in bursts, then smoulder for a beat.
	local burn = Instance.new("ParticleEmitter")
	burn.Name = "Burning"
	burn.Texture = "rbxasset://textures/particles/fire_main.dds" -- the campfire's ember art
	burn.Rate = 0
	burn.Lifetime = NumberRange.new(0.5, 1.15)
	burn.Speed = NumberRange.new(4, 10)
	burn.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	burn.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	burn.Color = ColorSequence.new(Color3.fromRGB(255, 128, 46), Color3.fromRGB(168, 32, 24))
	burn.LightEmission = 0.85
	burn.LightInfluence = 0
	burn.SpreadAngle = Vector2.new(60, 60)
	burn.Acceleration = Vector3.new(0, 7, 0)
	burn.Rotation = NumberRange.new(0, 360)
	burn.Parent = part

	-- ── the dead state: smoke only ─────────────────────────────────────────────────────────────
	local smoke = Instance.new("Smoke")
	smoke.Name = "DeadSmoke"
	smoke.Size = 3.2 * scale
	smoke.Opacity = 0.28
	smoke.RiseVelocity = 7
	smoke.Color = Color3.fromRGB(126, 122, 116) -- grey, warmed slightly; never pure grey against jungle
	smoke.Enabled = false
	smoke.Parent = part

	-- Night-only practical, tagged the way every other dusk-to-dawn light in the game is, so
	-- `LightController` owns it and it costs nothing at noon. Untagged and killed on death.
	local light = Instance.new("PointLight")
	light.Name = "ElectricGlow"
	light.Color = Color3.fromRGB(150, 210, 255)
	light.Brightness = 1.5
	light.Range = 13 * scale
	light.Shadows = false
	light.Enabled = false -- LightController turns it on at dusk
	light.Parent = part
	CollectionService:AddTag(light, "NightLight")

	-- ── the status billboard: HP bar while alive, "DISABLED" once dead ─────────────────────────
	local gui = Instance.new("BillboardGui")
	gui.Name = "GeneratorStatus"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(112, 38)
	-- World space, so a rotated housing cannot tip the sign, and derived from the model's own height.
	gui.StudsOffsetWorldSpace = Vector3.new(0, bb.Y / 2 + 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = APPROACH_STUDS
	gui.Parent = part

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 13)
	track.Position = UDim2.fromOffset(0, 0)
	track.BackgroundColor3 = Theme.color.sunken
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, Theme.radius.control)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Theme.color.stroke
	trackStroke.Thickness = Theme.strokeWidth.hairline
	trackStroke.Parent = track
	track.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.color.green
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, Theme.radius.control)
	fillCorner.Parent = fill
	fill.Parent = track

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Position = UDim2.fromOffset(0, 15)
	status.BackgroundTransparency = 1
	status.Font = Theme.font.button
	status.TextScaled = true
	status.TextColor3 = Theme.color.red
	status.TextStrokeColor3 = Theme.color.stroke
	status.TextStrokeTransparency = 0.15 -- readable against jungle with no panel behind it
	status.Text = ""
	status.Visible = false
	status.Parent = gui

	return {
		model = model,
		part = part,
		scale = scale,
		hum = hum,
		zap = zap,
		sparks = sparks,
		burn = burn,
		smoke = smoke,
		light = light,
		gui = gui,
		track = track,
		fill = fill,
		status = status,
		lastHP = Generators.MAX_HP,
		dead = false,
		zapToken = 0,
		burnToken = 0,
	}
end

-- ── reactions ───────────────────────────────────────────────────────────────────────────────────

local function paintBar(rig: Rig, hp: number)
	local max = math.max((rig.model:GetAttribute("MaxHP") :: number?) or Generators.MAX_HP, 1)
	local fraction = math.clamp(hp / max, 0, 1)
	rig.fill.Size = UDim2.fromScale(fraction, 1)
	-- Same three bands as the enemy bars (`EnemyHealthBars`), so one glance means the same thing on a
	-- bandit and on a generator.
	rig.fill.BackgroundColor3 = if fraction > 0.5
		then Theme.color.green
		elseif fraction > 0.25 then Theme.color.yellow
		else Theme.color.red
end

local function onHit(rig: Rig, hp: number)
	-- the zap: restart the idle clip loud, then cut it back to silence (see the SFX note)
	rig.zapToken += 1
	local zapMine = rig.zapToken
	rig.zap.TimePosition = 0
	rig.zap:Play()
	task.delay(ZAP_TAIL, function()
		if rig.zapToken == zapMine then
			rig.zap:Stop()
		end
	end)

	-- the burn: a burst now, then a short smoulder that a follow-up hit refreshes
	rig.burn:Emit(math.floor(16 * rig.scale + 0.5))
	rig.burn.Rate = 7
	rig.burnToken += 1
	local burnMine = rig.burnToken
	task.delay(BURN_SECONDS, function()
		if rig.burnToken == burnMine and not rig.dead then
			rig.burn.Rate = 0
		end
	end)

	paintBar(rig, hp)
end

local function onDeath(rig: Rig)
	if rig.dead then
		return
	end
	rig.dead = true
	local model = rig.model

	-- sound OFF, then the death clip. The user's wording is exact: "when dead generator stops
	-- emitting sound", so the hum is stopped rather than faded, and the zap is silenced with it.
	rig.hum:Stop()
	rig.zap:Stop()
	playOnce(rig.part, SFX.dead, DEAD_VOLUME, 150)

	-- electricity OFF, one last flare, then nothing but smoke
	rig.sparks.Enabled = false
	rig.burn:Emit(math.floor(26 * rig.scale + 0.5))
	rig.burn.Rate = 0
	rig.smoke.Enabled = true

	-- The light must be UNTAGGED, not just switched off: `LightController` re-applies every
	-- `NightLight` at dusk, so a dead generator would light back up on its own a few minutes later.
	CollectionService:RemoveTag(rig.light, "NightLight")
	rig.light.Enabled = false

	-- the sign: bar out, "DISABLED" in, readable from further than the bar was
	rig.track.Visible = false
	rig.status.Text = "DISABLED"
	rig.status.Visible = true
	rig.status.Position = UDim2.fromOffset(0, 0)
	rig.gui.MaxDistance = DEAD_SIGN_STUDS

	model:SetAttribute("Disabled", true)

	-- A running count so a later job (bunker doors, base power, an objective) can react without this
	-- module having to know about it. Cheap, replicated, and readable from anywhere.
	local n = 0
	for _, other in pairs(rigs) do
		if other.dead then
			n += 1
		end
	end
	Workspace:SetAttribute("GeneratorsDisabled", n)

	print(("[Generator] %s DISABLED (%d of %d down)"):format(model:GetFullName(), n, #Generators.all()))

	for _, fn in ipairs(disabledListeners) do
		task.spawn(fn, model)
	end
end

-- ── public API ──────────────────────────────────────────────────────────────────────────────────

-- Every wired generator, dead or alive.
function Generators.all(): { Model }
	local out = {}
	for model in pairs(rigs) do
		out[#out + 1] = model
	end
	return out
end

function Generators.isAlive(model: Instance): boolean
	local rig = rigs[model :: Model]
	return rig ~= nil and not rig.dead
end

-- Called with the model each time one is destroyed. For the door/power/objective wiring a later job
-- will want — it should not have to watch attributes or edit this file.
function Generators.onDisabled(fn: (Model) -> ())
	table.insert(disabledListeners, fn)
end

-- Wire ONE generator model. Idempotent: a second call on the same model is a no-op, which is what
-- makes the boot scan and the tag-added signal safe to both fire for the same prop.
function Generators.attach(model: Model): boolean
	if rigs[model] then
		return false
	end
	local part = bodyOf(model)
	if not part then
		warn(("[Generator] %s has no BasePart — not wired"):format(model:GetFullName()))
		return false
	end

	-- ⚠️ These models ship with NO PrimaryPart, and `MeleeServer` reads `best.PrimaryPart` to place its
	-- impact burst and damage number — without this a sword hit lands silently and invisibly. Setting
	-- it does not move an already-placed model, but it DOES become the pivot: `Generators.spawn` below
	-- therefore positions the clone BEFORE attaching.
	if not model.PrimaryPart then
		model.PrimaryPart = part
	end

	model:SetAttribute("MaxHP", Generators.MAX_HP)
	model:SetAttribute("HP", Generators.MAX_HP)
	model:SetAttribute("Disabled", false)

	local rig = buildRig(model, part)
	rigs[model] = rig
	paintBar(rig, Generators.MAX_HP)

	-- THE one connection per generator. Everything the prop does is a reaction to its HP moving, which
	-- is why the three weapon paths needed no new code: they already write this attribute.
	model:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = (model:GetAttribute("HP") :: number?) or 0
		local took = rig.lastHP - hp
		rig.lastHP = hp
		if took > 0 and not rig.dead then
			onHit(rig, hp)
		else
			paintBar(rig, hp)
		end
		if hp <= 0 then
			onDeath(rig)
		end
	end)

	model.Destroying:Connect(function()
		rigs[model] = nil
	end)

	-- The tag is the seam the damage sites read. Added LAST, so nothing can shoot a generator that is
	-- still half-built.
	if not CollectionService:HasTag(model, Generators.TAG) then
		CollectionService:AddTag(model, Generators.TAG)
	end
	return true
end

-- Wire every generator under `root` (by name). Returns how many were newly wired.
--
-- ⚠️ Call this on WORKSPACE, never on ServerStorage: attaching the AssetLibrary template would give the
-- library copy a humming sound and a health bar, and every clone taken from it afterwards would arrive
-- carrying a second set of FX.
function Generators.attachAll(root: Instance): number
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and d.Name:sub(1, #Generators.NAME_PREFIX) == Generators.NAME_PREFIX then
			-- The asset's own MeshPart is also called `Generator`; only the Model wrapper is wired.
			if Generators.attach(d) then
				n += 1
			end
		end
	end
	return n
end

-- Clone one out of the AssetLibrary, place it, and wire it. This is the entry point for a later job
-- that wants generators in a camp or a village.
--
-- `scale` is a whole-model multiplier (1 = the library size, 8 studs tall) — the end zone's third
-- generator is a 0.5 in the editor, so a spawner needs the same freedom.
function Generators.spawn(cframe: CFrame, parent: Instance?, scale: number?): Model?
	local node: Instance? = ServerStorage
	for _, step in ipairs(Generators.LIBRARY_PATH) do
		node = node and node:FindFirstChild(step)
	end
	if not (node and node:IsA("Model")) then
		warn(("[Generator] ServerStorage.%s is missing — cannot spawn"):format(table.concat(Generators.LIBRARY_PATH, ".")))
		return nil
	end

	local clone = (node :: Model):Clone()
	clone.Name = "Generator"
	-- Order matters: scale and position FIRST, attach second. `attach` sets PrimaryPart, and a model's
	-- PrimaryPart silently overrides its WorldPivot — so a PivotTo after attaching would place the prop
	-- by a different reference point than the one measured here.
	if scale and scale ~= 1 then
		clone:ScaleTo(scale)
	end
	clone:PivotTo(cframe)
	clone.Parent = parent or Workspace
	Generators.attach(clone)
	return clone
end

return Generators
