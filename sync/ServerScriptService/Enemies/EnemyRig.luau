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

local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
local EnemyAssets = require(ServerScriptService:WaitForChild("Enemies"):WaitForChild("EnemyAssets"))

local EnemyRig = {}

-- ── the AssetLibrary, flattened by NAME ───────────────────────────────────────────────────────────
-- Same lookup `ExcursionServer` uses. The library groups models into folders and there is no `Enemies`
-- group yet, so creature models can be dropped into any group — resolution is by name.
local library: { [string]: Model } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				if m:IsA("Model") then
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
}
local rigs: { [Model]: Rig } = {}

-- ── glowing eyes (Job 039, moved here unchanged) ──────────────────────────────────────────────────
-- Attachment-aware: a sourced model puts `EyeLeft`/`EyeRight` Attachments where the eyes belong and the
-- Neon spheres land on them; without those attachments it falls back to an offset from the body size,
-- which is right for a greybox and wrong-looking on a real head. **Every sourced model should carry the
-- two attachments** — see `EnemyAssets.EYE`.
local function addEyes(model: Model, base: BasePart, def: EnemyDefs.EnemyDef)
	local E = EnemyAssets.EYE
	local function eyeAt(cf: CFrame)
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
	end
	local aL = model:FindFirstChild(E.leftName, true)
	local aR = model:FindFirstChild(E.rightName, true)
	if aL and aL:IsA("Attachment") and aR and aR:IsA("Attachment") then
		eyeAt(aL.WorldCFrame)
		eyeAt(aR.WorldCFrame)
	else
		local s = def.size
		-- front = -Z (the snout end), up = +Y, sides = ±X
		eyeAt(base.CFrame * CFrame.new(-s.X * 0.22, s.Y * 0.22, -s.Z * 0.42))
		eyeAt(base.CFrame * CFrame.new(s.X * 0.22, s.Y * 0.22, -s.Z * 0.42))
	end
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
		for _, d in ipairs(visual:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true -- the whole creature is moved by PivotTo, never by physics
				d.CanCollide = false -- the AI is kinematic; a colliding croc would shove the boat
				d.CastShadow = false -- up to 9 sea + 7 land creatures live at once
			end
		end
		if art and art.scale then
			visual:ScaleTo(art.scale)
		end
		-- ⚠️ forward is -Z. `stepToward` drives every creature with `CFrame.lookAt(newPos, newPos + dir)`
		-- and the greybox puts its Snout at -Z; a model authored facing +Z swims backwards.
		local yaw = math.rad((art and art.yawOffset) or 0)
		visual:PivotTo(body.CFrame * CFrame.Angles(0, yaw, 0))
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
	addEyes(model, body, def)

	-- ── animator ────────────────────────────────────────────────────────────────────────────────
	-- `AnimationController` + `Animator`, NOT a Humanoid: movement stays `PivotTo`, so animations are
	-- purely cosmetic and the tuned server-authoritative AI is untouched (the decision recorded in the
	-- Job #078 intake). No rig or no ids → this block simply produces nothing.
	local rig: Rig = { tracks = {}, sounds = {}, current = nil }
	local visual = model:FindFirstChild("Visual")
	if visual and art then
		local controller = Instance.new("AnimationController")
		local animator = Instance.new("Animator")
		animator.Parent = controller
		controller.Parent = visual
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

	rigs[model] = rig
	model.Parent = parent
	return model
end

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
	local track = rig and rig.tracks[name]
	if track then
		track.Looped = false
		track:Play(EnemyAssets.ANIM_TUNING.attackFade)
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
function EnemyRig.destroy(model: Model)
	local rig = rigs[model]
	if rig then
		for _, t in pairs(rig.tracks) do
			t:Stop()
			t:Destroy()
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
