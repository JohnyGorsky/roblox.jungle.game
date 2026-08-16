--!strict
-- RiverBootstrap.server.luau — owns the live river (Job 005).
--
-- On server start: clear old terrain, seed the river, generate the opening stretch, then signal
-- "RiverReady" so the boat spawns onto real water. Thereafter it STREAMS: generate chunks ahead of
-- the boat, cull chunks behind (mobile memory budget), and place the finish line at END_DISTANCE.
-- Publishes BoatDistance / RiverEndDistance attributes for a future HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- real river obstacles (Job 036): built on "obstacle" hooks; tagged "Obstacle" with Slow/Damage attributes
-- that ObstacleServer reads on boat contact. Non-colliding triggers (physical collision would blow up the
-- boat assembly) — the hit applies a velocity cut + hull damage instead.
-- Job #076: each type now names a REAL model from `ServerStorage.AssetLibrary`. The greybox box is kept
-- as the FALLBACK, not deleted, because the library lives in the place file rather than in git — a fresh
-- clone with no saved .rbxl must still get playable obstacles rather than an invisible river hazard.
--
-- `Sandbar` has no model. It is drawn as a squashed DOME at the waterline (`shape = "dome"`) — the raw
-- trigger box is an 18-stud column whose only visible face is a flat square top, which read in game as an
-- unidentifiable tan tile rather than a shoal.
type Obstacle = {
	name: string,
	-- Relative pick weight (absent = 1). Added 2026-08-16 so the MIX can be steered without adding or
	-- removing types — the user wanted more of the floating debris you actually run into.
	weight: number?,
	-- "dome" = build a rounded shoal instead of showing the raw trigger box. Sandbar only.
	shape: string?,
	model: string?, -- nil = the greybox box IS the visual (Sandbar)
	-- "bed"   rests on the RIVERBED and is stretched so its top breaks the surface
	-- "float" floats AT the surface (a log), positioned by `submerge`
	seatOn: string,
	protrude: number, -- studs above WATER_Y for a "bed" obstacle
	submerge: number, -- fraction of height below WATER_Y for a "float" obstacle
	size: Vector3,
	color: Color3,
	mat: Enum.Material,
	slow: number,
	damage: number,
}

local OBSTACLES: { Obstacle } = {
	-- `submerge` = fraction of the model's height BELOW the waterline. A boulder is mostly under and breaks
	-- the surface; a log floats with most of it showing. Without this they hover (Job #076 playtest: "why do
	-- we have rocks on water :D").
	-- A boulder RESTS ON THE BOTTOM. Positioning it relative to the water surface (the first attempt) left
	-- it suspended: the bed is 18 studs down (`CHANNEL_DEPTH`), so a "55% submerged" rock hung 13 studs
	-- above the riverbed and read as floating through the clear water.
	{ name = "Rock", model = "RockA", weight = 1.0, seatOn = "bed", protrude = 3, submerge = 0, size = Vector3.new(10, 10, 10), color = Color3.fromRGB(110, 112, 122), mat = Enum.Material.Rock, slow = 0.85, damage = 25 },
	-- A log genuinely FLOATS, so this one is surface-relative and stays that way.
	{ name = "Log", model = "LogMossy", weight = 2.6, seatOn = "float", protrude = 0, submerge = 0.35, size = Vector3.new(4, 3, 20), color = Color3.fromRGB(92, 62, 40), mat = Enum.Material.Wood, slow = 0.5, damage = 12 },
	-- A sandbar is a MOUND rising off the bed to just under the surface. ⚠️ Seating alone did NOT make it
	-- read as one — see `shape = "dome"`; the box's flat top is all you ever see of it above water.
	{ name = "Sandbar", model = nil, weight = 0.8, shape = "dome", seatOn = "bed", protrude = 0.4, submerge = 0, size = Vector3.new(22, 1.5, 16), color = Color3.fromRGB(205, 188, 132), mat = Enum.Material.Sand, slow = 0.7, damage = 4 },
	-- A log JAM — tangled debris wedged across the channel, so it hits harder than the single `Log` but
	-- not as hard as a boulder. Floats like the log, because that is what it is made of.
	--
	-- ⚠️ THE SIZE IS CHOSEN TO SURVIVE THE RANDOM YAW BELOW, not picked for looks alone. Single-mesh
	-- obstacles are STRETCHED to this box (`m.Size = p.Size`) and then yawed by `math.noise`, so a box
	-- whose X and Z differ wildly would present its narrow side across the river half the time and
	-- distort the logs the rest. 14×6×11 is within ~10% of the mesh's own 7.59×3.78×5.44 proportions,
	-- so it stretches almost uniformly and reads the same from any angle.
	{ name = "LogJam", model = "LogJam", weight = 1.6, seatOn = "float", protrude = 0, submerge = 0.45, size = Vector3.new(14, 6, 11), color = Color3.fromRGB(92, 62, 40), mat = Enum.Material.Wood, slow = 0.72, damage = 16 },
}

-- ── Jump ramps (Job #082) ─────────────────────────────────────────────────────────────────────────
-- `RiverData` has emitted `kind = "ramp"` hooks since the river existed and nothing ever used them for
-- more than a marker. Job 019 proved the jump works and left the physics in a DEV-only script; this is
-- that feature promoted onto the real hooks. `RampServer` owns the launch.
--
-- ⚠️ The ANGLE is the whole difficulty knob: launch scales with it (`LAUNCH_BASE + angle * PER_DEG`),
-- so these three are a gentle/medium/big spread rather than three cosmetic variants. Keep the steepest
-- rare — `RiverData` favours obstacles over ramps ~3:2, and a river of big air stops reading as a river.
local RAMP_MODEL = "RiverRamp" -- AssetLibrary name; absent => the WedgePart greybox below
local RAMP_WIDTH = 34 -- Job 019's proven footprint: wide enough to hit without aiming
local RAMP_HEIGHT = 8
local RAMPS = {
	{ angle = 12 }, -- a nudge — clears a log, lands flat
	{ angle = 22 }, -- the standard jump
	{ angle = 32 }, -- big air; with the Ramp Bow module this is the one that clears real gaps
}

-- Real obstacle art, looked up once. Missing library => greybox fallback, warned once, river still playable.
local obstacleArt: { [string]: Model } = {}
do
	local lib = game:GetService("ServerStorage"):FindFirstChild("AssetLibrary")
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				if m:IsA("Model") then
					obstacleArt[m.Name] = m
				end
			end
		end
	else
		warn("[Obstacle] no ServerStorage.AssetLibrary — obstacles fall back to greybox boxes")
	end
end

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local RiverGenerator = require(ServerScriptService:WaitForChild("River"):WaitForChild("RiverGenerator"))
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))

-- ── config ─────────────────────────────────────────────────────────────────
local AHEAD_CHUNKS = 7   -- chunks kept generated ahead of the boat (~1800 studs)
local BEHIND_CHUNKS = 2  -- chunks kept behind before culling
local TICK = 0.15        -- streaming update period (s)
-- ───────────────────────────────────────────────────────────────────────────

local CHUNK_LEN = RiverGenerator.CHUNK_LEN
local MAX_CHUNK = math.floor(RiverData.END_DISTANCE / CHUNK_LEN)

-- seed priority: explicit Workspace attribute > lobby TELEPORT DATA (party shares one river) > dev default.
-- On a reserved server the lobby passes { seed } via TeleportData; every party member carries the same
-- value, so we read it off the first arriving player (briefly waiting for them). In Studio / direct joins
-- there's no teleport data → falls back to the default. (Job 017)
local seed = Workspace:GetAttribute("RiverSeed") :: number?
if not seed then
	local deadline = os.clock() + 5
	while not Players:GetPlayers()[1] and os.clock() < deadline do
		task.wait(0.1)
	end
	local first = Players:GetPlayers()[1]
	if first then
		local ok, data = pcall(function()
			return first:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" and typeof(data.seed) == "number" then
			seed = data.seed
		end
	end
end
RiverData.setSeed(seed or 2026)

local generated: { [number]: boolean } = {}

-- greybox obstacle/ramp markers (real props come later), streamed with their chunk
local hooksRoot = Instance.new("Folder")
hooksRoot.Name = "RiverHooks"
hooksRoot.Parent = Workspace

local function placeHooks(index: number)
	if hooksRoot:FindFirstChild("Chunk_" .. index) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Chunk_" .. index
	local zMin = RiverData.Z_START + index * CHUNK_LEN
	for _, h in ipairs(RiverData.hooksBetween(zMin, zMin + CHUNK_LEN - 1)) do
		if h.kind == "ramp" then
			-- ── REAL jump ramp (Job #082; was a translucent green Neon slab) ──────────────────────
			-- 🔴 NON-COLLIDING, AND THAT IS NOT AN OVERSIGHT. Job 019 proved a heavy, buoyant,
			-- level-controlled boat CANNOT climb a solid ramp — it jams and stalls against it. So the
			-- ramp is a trigger you drive THROUGH, and `RampServer` applies the launch directly.
			-- Making this collidable would break the feature, not improve it.
			local pick = RAMPS[(math.floor(math.abs(math.noise(h.z * 0.09, 3.3)) * 89) % #RAMPS) + 1]
			local run = RAMP_HEIGHT / math.tan(math.rad(pick.angle))

			local p = Instance.new("Part")
			p.Name = "Ramp"
			p.Anchored = true
			p.CanCollide = false
			p.Size = Vector3.new(RAMP_WIDTH, RAMP_HEIGHT, run)
			-- sunk so the low end starts under the surface and the high end breaks it, like a rock shelf
			p.Position = Vector3.new(h.x, RiverData.WATER_Y - 2 + RAMP_HEIGHT / 2, h.z)
			p.Color = Color3.fromRGB(104, 108, 116)
			p.Material = Enum.Material.Rock
			p.Transparency = 1 -- the wedge/art below is the visual; this box is the trigger footprint
			p:SetAttribute("HookKind", "ramp")
			p:SetAttribute("Angle", pick.angle)
			CollectionService:AddTag(p, "Ramp")

			-- The visual. A real model if the library has one, else a WedgePart — which is a genuine
			-- slope you can read at speed, unlike the flat Neon box this replaces.
			local art = obstacleArt[RAMP_MODEL]
			if art then
				local clone = art:Clone()
				clone.Name = "Art"
				local meshes = {}
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CastShadow = false
						table.insert(meshes, d)
					end
				end
				if #meshes == 1 then
					-- same single-mesh stretch the obstacles use: what you see IS the trigger box
					meshes[1].Size = p.Size
					meshes[1].CFrame = p.CFrame
				else
					clone:PivotTo(p.CFrame)
				end
				clone.Parent = p
			else
				local w = Instance.new("WedgePart")
				w.Name = "Art"
				w.Anchored = true
				w.CanCollide = false
				w.Size = p.Size
				-- 🔴 NO YAW. The first version rotated this 180° "so the slope faces the boat" and did the
				-- exact opposite: driving downstream you met a sheer vertical rock wall with the ramp
				-- surface on the far side. A WedgePart's slope already rises toward +Z, which IS the way
				-- the boat travels, so the UNROTATED part presents its low edge to the approach.
				-- ⚠️ Verified by LOOKING from the boat's eye, not by measuring. A height sample at two z
				-- values reads "correct" for BOTH orientations — which is what made this look fine on
				-- paper while being a wall in game.
				w.CFrame = p.CFrame
				w.Color = p.Color
				w.Material = Enum.Material.Rock
				w.Parent = p
			end
			p.Parent = folder
		else
			-- REAL obstacle (Job 036): pick a type deterministically by z; slow + damage on contact
			-- WEIGHTED pick, still fully deterministic in z: the same noise value is mapped onto a
			-- cumulative weight line instead of a flat index. Log + LogJam — the floating debris you run
			-- into — are now ~70% of the mix between them, against 50% when all four types were equal.
			local pick = OBSTACLES[1]
			do
				local total = 0
				for _, o in ipairs(OBSTACLES) do
					total += o.weight or 1
				end
				local roll = ((math.abs(math.noise(h.z * 0.11, 7.7)) * 97) % 1) * total
				local acc = 0
				for _, o in ipairs(OBSTACLES) do
					acc += o.weight or 1
					if roll <= acc then
						pick = o
						break
					end
				end
			end

			-- Find the RIVERBED under this hook. generateChunk() has already run for this chunk (see
			-- ensureChunk), so the terrain is there to hit.
			local bedParams = RaycastParams.new()
			bedParams.FilterType = Enum.RaycastFilterType.Include
			bedParams.FilterDescendantsInstances = { Workspace.Terrain }
			bedParams.IgnoreWater = true
			local bedHit = Workspace:Raycast(Vector3.new(h.x, RiverData.WATER_Y + 60, h.z), Vector3.new(0, -200, 0), bedParams)
			local bedY = if bedHit then bedHit.Position.Y else (RiverData.WATER_Y - 18)

			-- Height and centre come from where the thing actually sits, not from a fixed size.
			local height, centreY
			if pick.seatOn == "bed" then
				height = math.max(2, (RiverData.WATER_Y + pick.protrude) - bedY)
				centreY = bedY + height / 2
			else
				height = pick.size.Y
				centreY = RiverData.WATER_Y + height * (0.5 - pick.submerge)
			end

			-- ⚠️ THE TRIGGER PART IS STILL THE TRIGGER, AND IT MUST STAY NON-COLLIDING.
			-- `ObstacleServer` reads the `Obstacle` tag and the Slow/Damage attributes off THIS part, and it
			-- is deliberately CanCollide = false: physical collision with the boat assembly blows it up.
			-- Job #076 changes only what you SEE.
			local p = Instance.new("Part")
			p.Name = pick.name
			p.Anchored = true
			p.CanCollide = false -- trigger; ObstacleServer applies the hit (physical collision = boat blowup)
			p.Material = pick.mat
			p.Size = Vector3.new(pick.size.X, height, pick.size.Z)
			p.Position = Vector3.new(h.x, centreY, h.z)
			p.Color = pick.color
			p:SetAttribute("HookKind", "obstacle")
			p:SetAttribute("Slow", pick.slow)
			p:SetAttribute("Damage", pick.damage)
			CollectionService:AddTag(p, "Obstacle")

			-- ── the sandbar's SHAPE ────────────────────────────────────────────────────────────
			-- ⚠️ A sandbar seats "on the bed", so its trigger is an **18-stud-tall column** running from
			-- the riverbed to 0.4 studs above the surface. Left visible, all you ever see is its flat
			-- square top — precisely the "plank floating on the water" the old comment claimed this
			-- seating had fixed. It had not; it read as an unidentifiable tan tile ("what is that?").
			-- So the column goes invisible and a squashed DOME sits at the waterline, which is what a
			-- shoal actually looks like.
			if pick.shape == "dome" then
				p.Transparency = 1
				local dome = Instance.new("Part")
				dome.Name = "Art"
				dome.Shape = Enum.PartType.Ball
				dome.Anchored = true
				dome.CanCollide = false
				dome.CastShadow = false
				dome.Material = pick.mat
				dome.Color = pick.color
				local domeH = pick.size.X * 0.42
				dome.Size = Vector3.new(pick.size.X, domeH, pick.size.Z)
				-- most of the ball under the surface so only a sand crown breaks it
				dome.CFrame = CFrame.new(h.x, RiverData.WATER_Y - domeH * 0.5 + pick.protrude + 0.6, h.z)
				dome.Parent = p
			end

			local art = if pick.model then obstacleArt[pick.model] else nil
			if art then
				local clone = art:Clone()
				clone.Name = "Art"
				local meshes = {}
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CastShadow = false
						table.insert(meshes, d)
					end
				end
				-- Our rock and log models are SINGLE MeshParts, so the art can simply be stretched to the
				-- trigger's box — which guarantees the thing you see and the thing that hurts you are the
				-- same shape in the same place, and lets a boulder be tall enough to reach the bed without
				-- also becoming absurdly wide (uniform ScaleTo cannot do that).
				if #meshes == 1 then
					local m = meshes[1]
					m.Size = p.Size
					m.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.noise(h.z * 0.31, 3.1) * math.pi * 2, 0)
					p.Transparency = 1 -- trigger invisible; the mesh is the visual
				else
					local _, ext = clone:GetBoundingBox()
					local have = math.max(ext.X, ext.Z)
					if have > 0 then
						clone:ScaleTo(math.max(pick.size.X, pick.size.Z) / have)
					end
					clone:PivotTo(CFrame.new(p.Position))
					local bottom = FoliageDefs.worldBottom(clone)
					if bottom then
						clone:PivotTo(clone:GetPivot() + Vector3.new(0, (centreY - height / 2) - bottom, 0))
					end
					p.Transparency = 1
				end
				clone.Parent = p
			end
			p.Parent = folder
		end
	end
	folder.Parent = hooksRoot
end

local function clearHooks(index: number)
	local folder = hooksRoot:FindFirstChild("Chunk_" .. index)
	if folder then
		folder:Destroy()
	end
end

local function ensureChunk(index: number)
	if index < 0 or index > MAX_CHUNK or generated[index] then
		return
	end
	RiverGenerator.generateChunk(index)
	placeHooks(index)
	generated[index] = true
end

local function cullChunk(index: number)
	if generated[index] then
		RiverGenerator.clearChunk(index)
		clearHooks(index)
		generated[index] = nil
	end
end

-- finish line: a bright marker spanning the channel at END_DISTANCE (greybox — real end set-piece at P9)
local endPlaced = false
local function placeEnd()
	if endPlaced or RiverData.ENDLESS then
		return
	end
	endPlaced = true
	local z = RiverData.distanceToWorldZ(RiverData.END_DISTANCE)
	local pos = RiverData.positionAt(z)
	local bar = Instance.new("Part")
	bar.Name = "FinishLine"
	bar.Anchored = true
	bar.CanCollide = false
	bar.Size = Vector3.new(RiverData.widthAt(z) + 40, 24, 4)
	bar.Position = pos + Vector3.new(0, 10, 0)
	bar.Color = Color3.fromRGB(255, 215, 0)
	bar.Material = Enum.Material.Neon
	bar.Transparency = 0.3
	bar.CFrame = CFrame.lookAt(bar.Position, bar.Position + RiverData.tangentAtZ(z))
	bar.Parent = Workspace
end

-- ── boot: generate the opening stretch, signal ready ────────────────────────
--
-- ⚠️ NO `Workspace.Terrain:Clear()` HERE — Job #071. It used to wipe every voxel on boot, which was
-- harmless while the whole world was procedural and became DESTRUCTIVE the moment the START and END
-- areas became hand-sculpted terrain living in the place file: every server start would have erased
-- them. Nothing needs clearing now — the place ships with the two editor zones and an EMPTY corridor,
-- the generator writes chunks as the boat advances, and cullChunk removes them behind it.
--
-- If stale terrain ever does appear in the corridor, fix it in the place file (clear it once in Studio
-- and save) rather than reinstating a blanket Clear here.
Workspace:SetAttribute("RiverEndDistance", RiverData.END_DISTANCE)
Workspace:SetAttribute("BoatDistance", 0)
for i = 0, AHEAD_CHUNKS do
	ensureChunk(i)
end
Workspace:SetAttribute("RiverReady", true)

-- ── stream with the boat ────────────────────────────────────────────────────
while true do
	local boat = Workspace:FindFirstChild("Boat")
	local hull = boat and boat:FindFirstChild("Hull") :: BasePart?
	if hull then
		local dist = RiverData.worldToDistance(hull.Position.Z)
		Workspace:SetAttribute("BoatDistance", math.max(0, math.floor(dist)))
		local cur = math.floor(dist / CHUNK_LEN)

		-- generate the nearest missing chunk ahead (one per tick to spread the cost)
		for i = cur, cur + AHEAD_CHUNKS do
			if i >= 0 and i <= MAX_CHUNK and not generated[i] then
				ensureChunk(i)
				break
			end
		end

		-- cull anything outside the live window
		for index in pairs(generated) do
			if index < cur - BEHIND_CHUNKS or index > cur + AHEAD_CHUNKS then
				cullChunk(index)
			end
		end

		-- finish line once its chunk is in view
		if cur >= MAX_CHUNK - AHEAD_CHUNKS then
			placeEnd()
		end
	end
	task.wait(TICK)
end
