--!strict
-- CombatFeedback.local.luau — impact particles + floating damage numbers (Job #080, built in Job #084).
--
-- Reported three times in playtests as "you can't tell if you hit anything". Before this, a landed shot
-- produced a 0.05 s tracer and nothing else: no muzzle flash, no impact, no number. A hit and a miss
-- looked identical, which is most of why the pistol read as broken in the first place.
--
-- GREEN = damage the crew deals. RED = damage a player or the boat takes. The server decides which
-- (`CombatFx`); this file only draws.
--
-- ── Enemy health bars are NOT this file's job ─────────────────────────────────────────────────────
-- `EnemyHealthBars.local.luau` already exists, covers both the `Enemy` and `CampGuard` tags, and was
-- restyled in #075. It deliberately HIDES a bar at full health, which is why enemies can look like they
-- have none. Do not rebuild it here.
--
-- ── Two pools, no allocation per hit ──────────────────────────────────────────────────────────────
-- ⚠️ Mobile-first. At sustained fire a per-hit `BillboardGui` + `Tween` is real cost and real GC churn,
-- and `GameSoundscape`'s cicada lesson (a cue fired faster than its own length stacking into noise)
-- applies to visuals just as well. Both pools are fixed-size and reused round-robin: past the cap the
-- OLDEST effect is recycled, so a heavy firefight degrades by dropping the stalest number rather than by
-- allocating without bound.
--
-- ⚠️ NOT A FLAT PART. Job #075 shipped a cream Neon slab as swing feedback and #079 removed it — on
-- screen it read as "some white object flying past". Impacts here are particles only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local remote = ReplicatedStorage:WaitForChild("CombatFeedback") :: RemoteEvent

local NUMBER_POOL = 20 -- concurrent floating numbers
local BURST_POOL = 8 -- concurrent impact bursts
local RISE = 5.5 -- studs a number floats upward over its life
local LIFE = 0.9 -- seconds a number is visible
local MAX_DIST = 260 -- past this the number is skipped entirely: unreadable, and pure cost

local camera = Workspace.CurrentCamera

-- ── impact burst pool ─────────────────────────────────────────────────────────────────────────────
local bursts: { { part: BasePart, emitter: ParticleEmitter } } = {}
local burstNext = 1

local fxFolder = Instance.new("Folder")
fxFolder.Name = "CombatFeedbackFx"
fxFolder.Parent = Workspace

for _ = 1, BURST_POOL do
	local p = Instance.new("Part")
	p.Name = "Impact"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder

	local e = Instance.new("ParticleEmitter")
	-- warm spark, not blood: the game's register is a stylized expedition, and a red spray on every
	-- crocodile bite would push it somewhere STYLEGUIDE §2 does not go.
	e.Color = ColorSequence.new(Theme.color.yellow, Color3.fromRGB(255, 140, 60))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new(0.45, 0)
	e.Lifetime = NumberRange.new(0.18, 0.34)
	e.Speed = NumberRange.new(9, 17)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -38, 0)
	e.LightEmission = 0.75
	e.Rate = 0 -- burst-only; `Emit` is the whole point of the pool
	e.Enabled = false
	e.Parent = p

	table.insert(bursts, { part = p, emitter = e })
end

local function burstAt(pos: Vector3)
	local slot = bursts[burstNext]
	burstNext = (burstNext % BURST_POOL) + 1
	slot.part.Position = pos
	slot.emitter:Emit(14)
end

-- ── floating number pool ──────────────────────────────────────────────────────────────────────────
-- One BillboardGui per slot, parented to a pooled anchor part that gets MOVED rather than recreated.
-- `Adornee` churn is the expensive part of a naive implementation; there is none here.
type Slot = { part: BasePart, gui: BillboardGui, label: TextLabel, born: number, base: Vector3, live: boolean }
local slots: { Slot } = {}
local slotNext = 1

for _ = 1, NUMBER_POOL do
	local p = Instance.new("Part")
	p.Name = "DamageNumber"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder

	local gui = Instance.new("BillboardGui")
	gui.Name = "Number"
	gui.Size = UDim2.fromOffset(90, 34)
	gui.AlwaysOnTop = false -- a number readable THROUGH the terrain is worse than one occluded by it
	gui.MaxDistance = MAX_DIST
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = p
	gui.Parent = p

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.font.button
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35 -- reads over sunlit water and dark jungle alike
	label.TextStrokeColor3 = Color3.fromRGB(20, 24, 20)
	label.Parent = gui

	table.insert(slots, { part = p, gui = gui, label = label, born = 0, base = Vector3.zero, live = false })
end

local function showNumber(pos: Vector3, amount: number, kind: string)
	local slot = slots[slotNext]
	slotNext = (slotNext % NUMBER_POOL) + 1

	slot.base = pos
	slot.born = os.clock()
	slot.live = true
	slot.part.Position = pos
	slot.label.Text = tostring(amount)
	slot.label.TextColor3 = if kind == "take" then Theme.color.red else Theme.color.green
	slot.label.TextTransparency = 0
	slot.gui.Enabled = true
end

-- One RenderStepped drives every live number: rise and fade. A Tween per label would be 20 tween
-- objects churning at sustained fire; this is one connection whatever happens on screen.
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, slot in slots do
		if not slot.live then
			continue
		end
		local a = (now - slot.born) / LIFE
		if a >= 1 then
			slot.live = false
			slot.gui.Enabled = false
			continue
		end
		slot.part.Position = slot.base + Vector3.new(0, RISE * a, 0)
		-- hold full opacity for the first half, then fade: the number is readable before it starts to go
		slot.label.TextTransparency = math.clamp((a - 0.5) * 2, 0, 1)
		slot.label.TextStrokeTransparency = 0.35 + 0.65 * math.clamp((a - 0.5) * 2, 0, 1)
	end
end)

remote.OnClientEvent:Connect(function(pos: Vector3, amount: number, kind: string)
	if typeof(pos) ~= "Vector3" or typeof(amount) ~= "number" then
		return
	end
	local cam = Workspace.CurrentCamera or camera
	if cam and (cam.CFrame.Position - pos).Magnitude > MAX_DIST then
		return -- off-screen or far downriver: no label, no burst, no cost
	end
	burstAt(pos)
	showNumber(pos, amount, kind)
end)

-- The muzzle flash lives in `WeaponClient`, not here: it must fire on a MISS too, and this file only
-- ever hears about landed hits. `WeaponClient` already owns the moment the shot is taken.

print("[CombatFx] impact bursts + damage numbers online")
