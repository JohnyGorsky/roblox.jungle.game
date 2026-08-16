--!strict
-- EnemyRig.luau — builds a creature's BODY: model, glowing eyes, animator, sounds (Job #078).
--
-- ── Why this is a shared module and not code in EnemyServer ───────────────────────────────────────
-- There were TWO greybox creature builders in the codebase and they had drifted:
--   · `EnemyServer.spawnEnemy` — Body + Snout + glowing eyes.
--   · `ExcursionServer.spawnGuard` — Body only, reusing `EnemyDefs.Defs.Panther`, and **no eyes at all**.
-- So a Panther model dropped into the AssetLibrary would have fixed the river ambushers and left every
-- camp guard a grey box. One builder, both callers.
--
-- ── The shape it builds, and why the invisible Body survives ──────────────────────────────────────
--   Model (PrimaryPart = Body)
--   ├── Body     invisible when a real model is present; the greybox itself when it is not
--   ├── Snout    greybox only
--   ├── Eye ×2   Neon (Job 039)
--   └── Visual   the sourced creature model, with AnimationController + Animator
--
-- 🔴 `Body` IS ALWAYS CREATED, AT `def.size`, EVEN WITH A REAL MODEL, and that is deliberate. The whole
-- AI — bite range, aggro distance, leashing, culling, the `stepToward` maths — reads `enemy.PrimaryPart`
-- and reasons in `def.size`. Swapping the PrimaryPart for a sourced mesh of a different size would
-- silently retune every one of those distances and re-open the balance work of Jobs 006–009, 053 and
-- 058. The art hangs off the hitbox; it does not become the hitbox.
--
-- Everything degrades: no model → greybox, no animation id → no animation, no sound id → silence. A
-- creature can be finished one asset at a time without ever breaking the spawn director.

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
local EnemyAssets = require(ServerScriptService:WaitForChild("Enemies"):WaitForChild("EnemyAssets"))

local EnemyRig = {}

-- ── the AssetLibrary, flattened by NAME ───────────────────────────────────────────────────────────
-- Same lookup `ExcursionServer` uses. The library groups models into folders and there is no `Enemies`
-- group yet, so creature models can be dropped into any group — resolution is by name.
-- ⚠️ Models AND single parts. The crocodile ships as one `MeshPart`, not a Model — exactly the trap
-- that made `GoldNugget` silently never spawn in Job #077. A Model-only scan would leave the croc
-- greyboxed with no warning.
local library: { [string]: PVInstance } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				if m:IsA("Model") or m:IsA("BasePart") then
					library[m.Name] = m
				end
			end
		end
	end
end

-- Per-model animation tracks and sounds, keyed by the spawned creature. Pruned in `EnemyRig.destroy`.
type Rig = {
	tracks: { [string]: AnimationTrack },
	sounds: { [string]: Sound },
	current: string?,
	conns: { RBXScriptConnection },
	-- water creatures: procedural motion instead of a skeleton
	visual: PVInstance?,
	yaw: number, -- radians; the model's authored-facing correction, re-applied every frame
	eyes: { { part: BasePart, att: Attachment? } }?,
	joints: { Motor6D }?, -- land rigs with no animation ids: swung by hand while moving
	jointSwing: EnemyAssets.JointSwing?,
	moving: boolean?,
	water: EnemyAssets.WaterMotion?,
	wake: ParticleEmitter?,
	splash: ParticleEmitter?,
	lastPos: Vector3?,
	phase: number, -- per-creature phase offset, so a pack doesn't bob in unison
}
local rigs: { [Model]: Rig } = {}

-- ── glowing eyes (Job 039, moved here unchanged) ──────────────────────────────────────────────────
-- Attachment-aware: a sourced model puts `EyeLeft`/`EyeRight` Attachments where the eyes belong and the
-- Neon spheres land on them; without those attachments it falls back to an offset from the body size,
-- which is right for a greybox and wrong-looking on a real head. **Every sourced model should carry the
-- two attachments** — see `EnemyAssets.EYE`.
-- Returns the eye parts paired with the Attachment each came from (nil for the greybox fallback), so the
-- water heartbeat can keep them glued to the head. Placing them once at build time is not enough: the
-- visual sinks and bobs every frame afterwards, which left the eyes hanging in the air above the snout.
local function addEyes(model: Model, base: BasePart, def: EnemyDefs.EnemyDef): { { part: BasePart, att: Attachment? } }
	local E = EnemyAssets.EYE
	local made: { { part: BasePart, att: Attachment? } } = {}
	local function eyeAt(cf: CFrame, att: Attachment?)
		local e = Instance.new("Part")
		e.Name = "Eye"
		e.Shape = Enum.PartType.Ball
		e.Size = Vector3.new(E.size, E.size, E.size)
		e.Material = Enum.Material.Neon
		e.Color = E.color
		e.Anchored = true
		e.CanCollide = false
		e.CanQuery = false
		e.CFrame = cf
		e.Parent = model
		table.insert(made, { part = e :: BasePart, att = att })
	end
	local aL = model:FindFirstChild(E.leftName, true)
	local aR = model:FindFirstChild(E.rightName, true)
	if aL and aL:IsA("Attachment") and aR and aR:IsA("Attachment") then
		eyeAt(aL.WorldCFrame, aL)
		eyeAt(aR.WorldCFrame, aR)
	else
		local s = def.size
		-- front = -Z (the snout end), up = +Y, sides = ±X
		eyeAt(base.CFrame * CFrame.new(-s.X * 0.22, s.Y * 0.22, -s.Z * 0.42), nil)
		eyeAt(base.CFrame * CFrame.new(s.X * 0.22, s.Y * 0.22, -s.Z * 0.42), nil)
	end
	return made
end

-- ── water VFX ─────────────────────────────────────────────────────────────────────────────────────
-- A WAKE that only emits while the creature is actually moving, and a SPLASH burst it fires on strike
-- and on death. Both are sized from `def.size`, so a hippo throws a bigger splash than a piranha
-- without anyone maintaining two sets of numbers — the per-creature `vfx` values are multipliers.
--
-- ⚠️ These live on their own Attachment at the WATERLINE, not on the mesh: the mesh bobs and rolls
-- every frame, and a wake that bobbed with it would spray upward as the creature rocked.
local SPLASH_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FOAM = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 226, 232))

local function buildWaterVfx(model: Model, body: BasePart, def: EnemyDefs.EnemyDef, vfx: EnemyAssets.CreatureVfx): (ParticleEmitter?, ParticleEmitter?)
	local girth = math.max(def.size.X, def.size.Y) -- how wide it sits in the water
	local att = Instance.new("Attachment")
	att.Name = "WaterLine"
	-- forward is -Z, so the bow wave belongs at the front third
	att.Position = Vector3.new(0, -def.size.Y * 0.25, -def.size.Z * 0.3)
	att.Parent = body

	local wake: ParticleEmitter? = nil
	if vfx.wakeRate > 0 then
		local w = Instance.new("ParticleEmitter")
		w.Name = "Wake"
		w.Texture = SPLASH_TEXTURE
		w.Color = FOAM
		w.Rate = vfx.wakeRate
		w.Lifetime = NumberRange.new(0.5, 1.1)
		w.Speed = NumberRange.new(1, 3)
		w.SpreadAngle = Vector2.new(28, 28)
		w.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, girth * 0.25 * vfx.wakeScale),
			NumberSequenceKeypoint.new(1, girth * 0.9 * vfx.wakeScale),
		})
		w.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		w.Acceleration = Vector3.new(0, -1.5, 0)
		w.Rotation = NumberRange.new(0, 360)
		w.Enabled = false -- only while moving
		w.Parent = att
		wake = w
	end

	local splash: ParticleEmitter? = nil
	if vfx.splashOnAttack > 0 or vfx.splashOnDeath > 0 then
		local sp = Instance.new("ParticleEmitter")
		sp.Name = "Splash"
		sp.Texture = SPLASH_TEXTURE
		sp.Color = FOAM
		sp.Rate = 0
		sp.Lifetime = NumberRange.new(0.4, 0.9)
		sp.Speed = NumberRange.new(9, 20)
		sp.SpreadAngle = Vector2.new(55, 55)
		sp.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, girth * 0.3 * vfx.splashScale),
			NumberSequenceKeypoint.new(0.6, girth * 0.85 * vfx.splashScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sp.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		sp.Acceleration = Vector3.new(0, -34, 0) -- thrown up, falls back
		sp.Rotation = NumberRange.new(0, 360)
		sp.Enabled = false -- :Emit() only
		sp.Parent = att
		splash = sp
	end
	return wake, splash
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────────

function EnemyRig.build(def: EnemyDefs.EnemyDef, pos: Vector3, parent: Instance): Model
	local art = EnemyAssets.ART[def.name]
	local model = Instance.new("Model")
	model.Name = def.name

	-- the hitbox the AI reasons about — always def.size, always the PrimaryPart
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = def.size
	body.Color = def.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true -- kinematic (PivotTo)
	body.CanCollide = false
	body.CFrame = CFrame.new(pos)
	body.Parent = model
	model.PrimaryPart = body

	local source = if art and art.model then library[art.model] else nil
	if source then
		-- real creature: the greybox hitbox becomes invisible scenery-free geometry
		body.Transparency = 1
		body.CanQuery = false

		local visual = source:Clone()
		visual.Name = "Visual"

		-- 🔴 A REAL RIG IS PREPARED DIFFERENTLY FROM A STATIC MESH.
		-- The Wolf and the Bandit come from roblox.defender as full Humanoid rigs. If every part is
		-- anchored the joints are ignored and NOTHING can animate — an anchored part obeys no Motor6D.
		-- So for a rig: anchor ONLY the root, leave the limbs jointed, and make them massless so the
		-- rig cannot sag or drag. For a plain mesh, keep anchoring everything as before.
		local humanoid = visual:FindFirstChildWhichIsA("Humanoid", true)
		local rootPart = if visual:IsA("Model") then (visual.PrimaryPart or visual:FindFirstChild("HumanoidRootPart")) else nil

		-- 🔴 REBUILD THE JOINT REST POSE BEFORE UNANCHORING — for joint-swing rigs only.
		--
		-- A Motor6D holds `Part0.CFrame * C0 == Part1.CFrame * C1`. While every part is anchored those
		-- offsets are ignored, but the moment we unanchor the limbs the joints snap them to whatever C0/C1
		-- say. The Boar's offsets do not match how its parts are actually placed, so it collapsed into a
		-- 1.6-stud clump instead of a 4.7-stud pig. roblox.defender hit this too — it ships a
		-- `FixBoarMotor6DOffsets` script that patches the Boar by copying the Wolf's offsets.
		--
		-- Deriving the offsets from the parts' CURRENT placement makes the authored pose the rest pose,
		-- which fixes it without depending on another animal's rig.
		--
		-- ⚠️ ONLY for rigs we animate by hand (`art.joints`). Doing this to the Bandit would destroy its
		-- animations: R15 clips are authored against the STANDARD R15 rest offsets, not ours.
		if art and art.joints and visual:IsA("Model") then
			for _, d in ipairs(visual:GetDescendants()) do
				if d:IsA("Motor6D") and d.Part0 and d.Part1 then
					d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame
					d.C1 = CFrame.identity
				end
			end
		end

		local vparts = visual:GetDescendants()
		table.insert(vparts, visual) -- a MeshPart source IS the part; it has no BasePart descendants
		for _, d in ipairs(vparts) do
			if d:IsA("BasePart") then
				d.Anchored = if humanoid then (d == rootPart) else true
				d.Massless = humanoid ~= nil
				d.CanCollide = false -- the AI is kinematic; a colliding croc would shove the boat
				d.CastShadow = false -- up to 9 sea + 7 land creatures live at once
			elseif d:IsA("LuaSourceContainer") then
				-- ⚠️ The Wolf and Boar ship Defender's legacy `Animate` script. It drives the joints off
				-- `Humanoid.Running`, an event that never fires here because we move by `PivotTo` — so it
				-- would hold them frozen in the Standing pose AND fight our own joint swing.
				d:Destroy()
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				-- ⚠️ The Boar arrives wearing Defender's floating health bar. Jungle shows enemy health its
				-- own way, and another game's HUD hovering over a jungle pig is exactly the kind of thing
				-- that ships unnoticed.
				d:Destroy()
			end
		end
		if humanoid then
			-- park the state machine: it has no ground to walk on and nothing to decide
			humanoid.EvaluateStateMachine = false
			humanoid.BreakJointsOnDeath = false
			humanoid.RequiresNeck = false
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		if art and art.scale then
			if visual:IsA("Model") then
				-- 🔴 RELATIVE, NOT ABSOLUTE. `Model:ScaleTo(x)` sets scale against the model's AUTHORED
				-- size, so it throws away any scale the asset already carries. The Boar arrives from
				-- roblox.defender already scaled ~3x; `ScaleTo(0.778)` shrank it to a quarter of its
				-- intended size (measured 1.6 x 1.9 x 2.3 against an expected 4.7 x 5.7 x 7.0).
				-- Multiplying the CURRENT scale means `scale` always reads as "x times how it looks now".
				visual:ScaleTo(visual:GetScale() * art.scale)
			elseif visual:IsA("BasePart") then
				visual.Size *= art.scale
				-- ⚠️ Attachments do NOT scale with `Size`. `Model:ScaleTo` moves them; setting `Size` on a
				-- part does not, so the eye attachments would stay out at the unscaled offsets and the
				-- glowing eyes would float off the head. Scale them by hand.
				for _, a in ipairs(visual:GetChildren()) do
					if a:IsA("Attachment") then
						a.Position *= art.scale
					end
				end
			end
		end
		-- ⚠️ forward is -Z. `stepToward` drives every creature with `CFrame.lookAt(newPos, newPos + dir)`
		-- and the greybox puts its Snout at -Z; a model authored facing +Z swims backwards.
		local yaw = math.rad((art and art.yawOffset) or 0)
		visual:PivotTo(body.CFrame * CFrame.Angles(0, yaw, 0))

		-- 🔴 Job #088: STAND A LAND CREATURE ON ITS FEET, don't bury it.
		--
		-- The pivot goes to the hitbox CENTRE, which is only correct if the rig's pivot happens to sit at
		-- its own vertical middle. The Wolf's does not: measured at 1.71 × 4.23 × 6.22 authored (× 1.3 =
		-- 5.50 tall) with its pivot 0.69 ABOVE the bounding-box centre. Against a 4-tall hitbox centred at
		-- ground + 2, that put the rig's feet at ground − 1.44 — a quarter of the wolf underground.
		--
		-- It was ALWAYS mis-seated; over water it read as "swimming", which is why the first report of it
		-- was a wolf apparently swimming. Job #086 put wolves on land at camps, and it became a wolf
		-- buried to the shoulders.
		--
		-- ⚠️ LAND ONLY. Sea creatures are deliberately half-submerged at the water line — seating a
		-- crocodile on its "feet" would lift it clean out of the river.
		--
		-- Measured from the model rather than hand-tuned per creature, so a re-scaled or re-imported rig
		-- stays seated without anyone remembering to update a magic number. `art.yOffset` remains
		-- available on top for deliberate art nudges.
		-- `visual` is a Model for the rigs and a plain MeshPart for the single-mesh creatures, so the
		-- bottom is measured whichever way applies.
		if def.category == "land" then
			local visualBottom: number? = nil
			if visual:IsA("Model") then
				local vcf, vsize = visual:GetBoundingBox()
				visualBottom = vcf.Position.Y - vsize.Y / 2
			elseif visual:IsA("BasePart") then
				visualBottom = visual.Position.Y - visual.Size.Y / 2
			end
			if visualBottom then
				local hitboxBottom = body.Position.Y - body.Size.Y / 2
				local lift = hitboxBottom - visualBottom
				local nudge = (art and (art :: any).yOffset) or 0
				if math.abs(lift) > 0.01 or nudge ~= 0 then
					visual:PivotTo(visual:GetPivot() + Vector3.new(0, lift + nudge, 0))
				end
			end
		end

		visual.Parent = model
	else
		-- greybox fallback, unchanged from Jobs 006→009
		local snout = Instance.new("Part")
		snout.Name = "Snout"
		snout.Size = Vector3.new(def.size.X * 0.6, def.size.Y * 0.7, def.size.Z * 0.35)
		snout.Color = def.color
		snout.Material = Enum.Material.SmoothPlastic
		snout.Anchored = true
		snout.CanCollide = false
		snout.CFrame = body.CFrame * CFrame.new(0, 0, -def.size.Z * 0.6)
		snout.Parent = model
	end

	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:SetAttribute("Category", def.category)
	-- `art.eyes == false` opts a creature out entirely (the Bandit — he is a person, see EnemyAssets).
	-- Anything else keeps the Job #039 glow.
	local eyes = if art and art.eyes == false then {} else addEyes(model, body, def)

	-- ── animator ────────────────────────────────────────────────────────────────────────────────
	-- `AnimationController` + `Animator`, NOT a Humanoid: movement stays `PivotTo`, so animations are
	-- purely cosmetic and the tuned server-authoritative AI is untouched (the decision recorded in the
	-- Job #078 intake). No rig or no ids → this block simply produces nothing.
	local rig: Rig =
		{ tracks = {}, sounds = {}, current = nil, conns = {}, phase = math.random() * 100, yaw = math.rad((art and art.yawOffset) or 0) }

	-- land rig with no animation ids (the Wolf): collect the Motor6Ds we will swing by hand
	local rigVisual = model:FindFirstChild("Visual")
	if art and art.joints and rigVisual then
		local found: { Motor6D } = {}
		for _, want in ipairs(art.joints.parts) do
			local j = rigVisual:FindFirstChild(want, true)
			if j and j:IsA("Motor6D") then
				table.insert(found, j)
			end
		end
		if #found > 0 then
			rig.joints = found
			rig.jointSwing = art.joints
		else
			warn(("[EnemyRig] %s: none of its joints were found — it will not animate"):format(def.name))
		end
	end

	-- water creature: procedural motion + wake/splash instead of a skeleton
	if art and art.water and model:FindFirstChild("Visual") then
		rig.visual = model:FindFirstChild("Visual") :: PVInstance
		rig.water = art.water
		rig.eyes = eyes -- glued to the head each frame; see the heartbeat
		if art.vfx then
			rig.wake, rig.splash = buildWaterVfx(model, body, def, art.vfx)
		end
	end
	local wantsAnim = false
	if art then
		for _, id in pairs(art.anim) do
			if id ~= "" then
				wantsAnim = true
				break
			end
		end
	end
	local visual = model:FindFirstChild("Visual") :: PVInstance?
	if visual and visual:IsA("Model") and art and wantsAnim then
		-- ⚠️ REUSE the rig's own Animator when it has one (both Defender rigs ship a Humanoid + Animator).
		-- Adding a second Animator alongside it silently plays nothing.
		local existing = visual:FindFirstChildWhichIsA("Animator", true)
		local animator: Animator
		local controller: Instance
		if existing then
			animator = existing
			controller = existing.Parent :: Instance
		else
			local c = Instance.new("AnimationController")
			local a = Instance.new("Animator")
			a.Parent = c
			c.Parent = visual
			animator, controller = a, c
		end
		for name, id in pairs(art.anim) do
			if id ~= "" then
				local a = Instance.new("Animation")
				a.Name = name
				a.AnimationId = id
				a.Parent = controller
				local okTrack, track = pcall(function()
					return animator:LoadAnimation(a)
				end)
				if okTrack and track then
					rig.tracks[name] = track
				else
					warn(("[EnemyRig] %s: animation %q failed to load (%s)"):format(def.name, name, id))
				end
			end
		end
	end

	-- ── sounds ──────────────────────────────────────────────────────────────────────────────────
	-- Positional, on the hitbox, with rolloff — the rule `GameSoundscape` sets out for every world cue.
	if art then
		for name, s in pairs(art.sound) do
			if s.id ~= "" then
				local snd = Instance.new("Sound")
				snd.Name = name
				snd.SoundId = s.id
				snd.Volume = s.volume
				snd.Looped = s.looped == true
				snd.RollOffMode = Enum.RollOffMode.InverseTapered
				snd.RollOffMinDistance = s.min
				snd.RollOffMaxDistance = s.max
				snd.Parent = body
				rig.sounds[name] = snd
				if snd.Looped then
					snd:Play()
				end
			end
		end
	end

	-- ── "took a hit" ────────────────────────────────────────────────────────────────────────────
	-- Watched HERE rather than hooked into the shooters, because damage arrives from THREE separate
	-- places — `GunServer`, `MeleeServer` and `WeaponServer` all just write the `HP` attribute. One
	-- listener on the attribute catches every source, including any added later.
	--
	-- Only a DROP counts, and only a non-fatal one: the killing blow gets `death`, not `hurt`.
	local lastHP = def.hp
	table.insert(
		rig.conns,
		model:GetAttributeChangedSignal("HP"):Connect(function()
			local hp = (model:GetAttribute("HP") :: number?) or 0
			if hp < lastHP and hp > 0 then
				EnemyRig.playSound(model, "hurt")
			end
			lastHP = hp
		end)
	)

	rigs[model] = rig
	model.Parent = parent
	return model
end

-- ── the water heartbeat ───────────────────────────────────────────────────────────────────────────
-- One shared loop over every water creature, not a connection each — same reason `CampAmbience` and
-- `LightController` are written that way: creatures spawn and die continuously for a whole run.
--
-- It offsets the **Visual only**, never the Body. `Body` is the hitbox the AI drives with `PivotTo`;
-- bobbing it would make bite range and aggro distance wobble with the swell.
--
-- ⚠️ Running AFTER the AI's own Heartbeat is not guaranteed, so the visual can trail the hitbox by a
-- single frame. At these speeds that is invisible, and it is far cheaper than forcing an ordering.
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for model, rig in pairs(rigs) do
		-- ── land rigs: swing the joints while moving ────────────────────────────────────────────
		-- This is what the Wolf's bundled `Animate` script did off `Humanoid.Running`, reproduced from
		-- our own movement flag because that event never fires for a `PivotTo`-driven creature.
		-- Alternating phase so diagonal pairs swing together, which is how a quadruped actually walks.
		local joints, swing = rig.joints, rig.jointSwing
		if joints and swing then
			local body = model.PrimaryPart
			if body then
				local last = rig.lastPos
				local moving = last ~= nil and (body.Position - last).Magnitude > 0.05
				rig.lastPos = body.Position
				local a = if moving then math.sin((t + rig.phase) * swing.hz * math.pi * 2) * swing.amplitude else 0
				for i, j in ipairs(joints) do
					-- Motor6D drives the pose; C1 keeps the joint's own offset intact
					local sign = if i % 2 == 0 then -1 else 1
					j.Transform = CFrame.Angles(a * sign, 0, 0)
				end
			end
		end

		local water, visual = rig.water, rig.visual
		local body = model.PrimaryPart
		if water and visual and body and model.Parent then
			local ph = rig.phase
			local bob = math.sin((t + ph) * water.bobHz * math.pi * 2) * water.bobAmp
			local roll = math.rad(math.sin((t + ph) * water.rollHz * math.pi * 2) * water.rollDeg)
			local wag = math.rad(math.sin((t + ph) * water.wagHz * math.pi * 2) * water.wagDeg)
			-- ⚠️ `rig.yaw` MUST be re-applied here. This overwrites the Visual's CFrame every frame, so the
			-- authored-facing correction applied at build time is otherwise thrown away on frame 2 and the
			-- crocodile swims tail-first. Caught exactly that way: the eyes were right, the body was not.
			visual:PivotTo(body.CFrame * CFrame.new(0, -water.sink + bob, 0) * CFrame.Angles(0, rig.yaw + wag, roll))

			-- keep the glowing eyes on the head as it sinks, bobs and rolls
			local eyes = rig.eyes
			if eyes then
				for _, e in ipairs(eyes) do
					if e.att then
						e.part.CFrame = e.att.WorldCFrame
					end
				end
			end

			-- the wake only runs while it is actually swimming
			local wake = rig.wake
			if wake then
				local last = rig.lastPos
				local moved = last ~= nil and (body.Position - last).Magnitude > 0.05
				wake.Enabled = moved
			end
			rig.lastPos = body.Position
		end
	end
end)

-- ── playback ──────────────────────────────────────────────────────────────────────────────────────

-- Switch the looping state animation ("idle" / "move"). No-ops when the creature has no rig, which is
-- every creature until its animations are sourced.
function EnemyRig.setMotion(model: Model, name: string)
	local rig = rigs[model]
	if not rig or rig.current == name then
		return
	end
	local track = rig.tracks[name]
	if not track then
		return
	end
	local prev = if rig.current then rig.tracks[rig.current] else nil
	if prev then
		prev:Stop(EnemyAssets.ANIM_TUNING.crossFade)
	end
	track.Looped = true
	track:Play(EnemyAssets.ANIM_TUNING.crossFade)
	rig.current = name
end

-- One-shot animation ("attack" / "death") — does not become the motion state.
function EnemyRig.playOnce(model: Model, name: string)
	local rig = rigs[model]
	if not rig then
		return
	end
	local track = rig.tracks[name]
	if track then
		track.Looped = false
		track:Play(EnemyAssets.ANIM_TUNING.attackFade)
	end
	-- a water creature has no attack animation to play, so the SPLASH is the strike — it is the only
	-- thing that sells the lunge, which is why it fires here rather than alongside the sound.
	local splash = rig.splash
	if splash then
		local art = EnemyAssets.ART[model.Name]
		local vfx = art and art.vfx
		if vfx then
			local n = if name == "death" then vfx.splashOnDeath else vfx.splashOnAttack
			if n > 0 then
				splash:Emit(n)
			end
		end
	end
end

-- One-shot sound ("aggro" / "attack" / "hurt" / "death"). Looping beds are started at build time.
function EnemyRig.playSound(model: Model, name: string)
	local rig = rigs[model]
	local snd = rig and rig.sounds[name]
	if snd and not snd.Looped then
		snd:Play()
	end
end

-- ⚠️ Call this instead of `enemy:Destroy()`. `AnimationTrack`s and the rig table hold references to a
-- creature that spawns and dies continuously for a whole run; dropping them is not optional.
-- ── dying (Job #083) ──────────────────────────────────────────────────────────────────────────────
-- 🔴 AN ENEMY MUST NOT BLINK OUT. Before this, `EnemyServer` played the death cues and destroyed the
-- model on the same frame, so nothing was ever seen: no animation, no splash, no sound. This gives the
-- corpse a moment — cues fire, the body topples onto its side and sinks, then it is destroyed.
--
-- ⚠️ It TOPPLES rather than ragdolls. These creatures are anchored parts driven by `PivotTo` with no
-- Humanoid (the decision recorded in Job #078), so unanchoring them to "fall" would drop a rig with no
-- joints through the terrain. A tween on the visual is what actually reads as falling here.
local DEATH_TIME = 1.15 -- how long the corpse is visible for
local DEATH_SINK = 2.2 -- studs it settles as it goes

function EnemyRig.die(model: Model, onDone: () -> ())
	local rig = rigs[model]
	EnemyRig.playOnce(model, "death") -- animation if it has one, splash burst if it's a water creature
	EnemyRig.playSound(model, "death")

	-- stop the idle/move loop so a dead thing is not still walking on the spot
	if rig then
		for name, t in pairs(rig.tracks) do
			if name ~= "death" then
				t:Stop(0.15)
			end
		end
		rig.current = nil
		if rig.wake then
			rig.wake.Enabled = false
		end
		-- the water heartbeat re-pivots the visual every frame and would fight the topple
		rig.water = nil
	end

	local visual = model:FindFirstChild("Visual")
	if visual and visual:IsA("PVInstance") then
		local start = visual:GetPivot()
		-- roll onto its side and settle; a land kill falls over, a water kill rolls and sinks
		local target = start * CFrame.Angles(0, 0, math.rad(78)) + Vector3.new(0, -DEATH_SINK, 0)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < DEATH_TIME and visual.Parent do
				local a = math.clamp((os.clock() - t0) / DEATH_TIME, 0, 1)
				visual:PivotTo(start:Lerp(target, a * a)) -- ease-in: it tips, then drops
				task.wait()
			end
		end)
	end

	task.delay(DEATH_TIME, onDone)
end

function EnemyRig.destroy(model: Model)
	local rig = rigs[model]
	if rig and rig.wake then
		rig.wake.Enabled = false
	end
	if rig then
		for _, t in pairs(rig.tracks) do
			t:Stop()
			t:Destroy()
		end
		for _, c in ipairs(rig.conns) do
			c:Disconnect()
		end
		rigs[model] = nil
	end
	model:Destroy()
end

-- Does the library actually have this creature's model? Used only for the boot log, so a missing model
-- is visible in the output rather than silently greyboxed.
function EnemyRig.hasModel(name: string): boolean
	local art = EnemyAssets.ART[name]
	if not art or not art.model then
		return false
	end
	if library[art.model] then
		return true
	end
	return false
end

return EnemyRig
