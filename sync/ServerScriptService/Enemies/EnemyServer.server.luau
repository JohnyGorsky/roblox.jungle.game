--!strict
-- EnemyServer.server.luau — sea + land threat spawn director & AI (Jobs 006 → 009).
--
-- SEA crocs swim the open channel and chase the boat. LAND panthers ambush from the banks, leashed to
-- their spawn anchor (they can't chase across open water). One global Heartbeat ticks all Enemy-tagged
-- foes (roblox-ai multi-agent). Bite damage + spawn rate scale with time of day via
-- EnemyDefs.strengthFor (sea peaks at night, land by day). Server-authoritative.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
-- Job #078: the creature's BODY (model, glowing eyes, animator, sounds) is built by a shared module, so
-- `ExcursionServer`'s camp guards get exactly the same treatment instead of their own greybox.
local EnemyRig = require(ServerScriptService:WaitForChild("Enemies"):WaitForChild("EnemyRig"))
local CombatFx = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatFx"))

-- ── config ─────────────────────────────────────────────────────────────────
-- ⚠️ **+20% on user direction 2026-08-16.** Expressed as ONE multiplier rather than by editing four
-- numbers, so the original Job 051 tuning stays legible and the next density change is a single edit.
-- Applied where the cap is computed, and floored — so 4 -> 4 (4.8) and 9 -> 10 (10.8) for sea,
-- 3 -> 3 (3.6) and 7 -> 8 (8.4) for land. The base is barely moved, the ceiling is what grows, which is
-- what "more monsters" means on a run that escalates with distance.
local ENEMY_DENSITY = 1.2

local BASE_SEA_CAP, MAX_SEA_CAP = 4, 9 -- concurrent sea enemies: grows with distance (+2 at night)
local BASE_LAND_CAP, MAX_LAND_CAP = 3, 7 -- banks are dangerous — more land ambushers (Job 051)
local SEA_AHEAD_MIN, SEA_AHEAD_MAX = 180, 320 -- spawn well ahead → time to react at speed
local FLANK_DIST = 12 -- crocs attack from ~this far off the boat centre (its side), not underneath
local LAND_AHEAD_MIN, LAND_AHEAD_MAX = 60, 130
local LAND_LEASH = 65 -- how far a panther will lunge from its bank anchor
local CULL_BEHIND = 260
local LEAD_TIME = 0.8
local BASE_SEA_INTERVAL, BASE_LAND_INTERVAL = 4.0, 4.5 -- land shorter → banks feel alive with threats (Job 051)
local ESCALATE_DISTANCE = 12000
-- Job #078: how often a creature that is NOT chasing makes its idle noise. Deliberately sparse and
-- randomised per creature — a gator hiss is a lurking cue, and on a timer short enough to notice it
-- turns into a machine. Up to 9 sea + 7 land creatures are alive at once.
local IDLE_SOUND_MIN, IDLE_SOUND_MAX = 10, 22
-- ── Job #084: the tied-dock safe zone ──────────────────────────────────────
-- Two playtest decisions meet here and, taken literally, contradict:
--   • tying the boat makes threats BACK OFF (the dock is a safe place to regroup)
--   • sea creatures now hunt SWIMMERS (swimming is no longer a free safe route)
-- A player swimming beside a tied boat satisfies both. This radius resolves it with one number
-- instead of leaving it to emerge in play: while the boat is tied, sea creatures neither approach nor
-- bite ANYTHING within this distance of the hull — the boat or a swimmer. Step outside it and normal
-- targeting resumes. So the dock is genuinely safe, and swimming away from it is genuinely not.
-- ⚠️ This is the lever if docks play too generous (lower it) or the safe zone feels stingy (raise it).
local TIED_SAFE_RADIUS = 55
-- ───────────────────────────────────────────────────────────────────────────

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y
local rng = Random.new()

type State = { biteTimer: number, anchor: Vector3?, side: number?, roared: boolean?, idleTimer: number? }
local state: { [Model]: State } = {}

-- 🔴 Job #084: THE DEATH ANIMATION STILL NEVER PLAYED, and the earlier fix is why.
--
-- Killing an enemy clears `state[enemy]` so a corpse stops chasing, then hands the body to
-- `EnemyRig.die` for a 1.1 s topple-and-sink. But `tickEnemy`'s FIRST guard despawns any enemy with no
-- state entry — so on the very next Heartbeat (~16 ms later) the corpse hit that guard and was
-- destroyed outright. The topple, the splash and the death sound were all started on a model that had
-- microseconds to live, which is the same "enemies blink out of existence" report as before, caused
-- the second time by the fix for the first.
--
-- A dying body is now TRACKED rather than merely stateless: the tick skips it and leaves it alone
-- until `EnemyRig.die`'s own callback despawns it.
local dying: { [Model]: boolean } = {}

-- Job #078: model, glowing eyes (Job 039), animator and sounds all live in `EnemyRig` now — one builder
-- shared with `ExcursionServer`'s camp guards. `def.size` remains the hitbox the AI reasons about; the
-- sourced art hangs off it and never becomes it.
local function spawnEnemy(def: EnemyDefs.EnemyDef, pos: Vector3, anchor: Vector3?): Model
	local model = EnemyRig.build(def, pos, Workspace)
	CollectionService:AddTag(model, "Enemy")
	state[model] = { biteTimer = def.biteCooldown, anchor = anchor }
	return model
end

local function despawn(enemy: Model)
	state[enemy] = nil
	dying[enemy] = nil
	EnemyRig.destroy(enemy) -- NOT :Destroy() — AnimationTracks have to be stopped and dropped too
end

local flashing = false
local function flashHull()
	if flashing then
		return
	end
	flashing = true
	local orig = hull.Color
	hull.Color = Color3.fromRGB(210, 45, 45)
	task.delay(0.12, function()
		hull.Color = orig
		flashing = false
	end)
end

local function boatAlive(): boolean
	return hull.Parent ~= nil and ((boat:GetAttribute("HP") :: number?) or 1) > 0
end

local function currentPhase(): string
	return (Workspace:GetAttribute("Phase") :: string?) or "day"
end

local function nearestPlayer(pos: Vector3, range: number): Model?
	local best: Model? = nil
	local bestD = range
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") then
			local d = (root.Position - pos).Magnitude
			if d <= bestD then
				best, bestD = char, d
			end
		end
	end
	return best
end

-- ── Job #084: who is in the water right now ───────────────────────────────────────────────────────
-- Rebuilt ONCE per Heartbeat, before the enemy loop — never per enemy. Up to 10 sea creatures are
-- alive at once and the answer is identical for all of them, so doing it inside `tickEnemy` would walk
-- the player list ten times a frame for one list.
--
-- `nearestPlayer` was never the problem with swimmers (it excludes only `Downed`, so a swimmer has
-- always been a valid BITE target). The hole was TARGETING: every sea enemy chased `hull.Position`, so
-- a player who swam away was never approached and could only be bitten by standing next to the boat.
local swimmers: { BasePart } = {}
local tiedNow = false

local function refreshSwimmers()
	table.clear(swimmers)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and char and hum and not char:GetAttribute("Downed") and hum:GetState() == Enum.HumanoidStateType.Swimming then
			table.insert(swimmers, root)
		end
	end
end

local function nearestSwimmer(pos: Vector3): BasePart?
	local best: BasePart? = nil
	local bestD = math.huge
	for _, root in swimmers do
		local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then
			best, bestD = root, d
		end
	end
	return best
end

local function flatDist(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- move an enemy one step toward target (flat, on the water surface); optionally leashed to an anchor
local function stepToward(enemy: Model, from: Vector3, target: Vector3, speed: number, dt: number, stopAt: number, anchor: Vector3?)
	local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local reach = (Vector3.new(target.X, 0, target.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	local step = math.min(speed * dt, math.max(reach - stopAt * 0.5, 0))
	local newPos = Vector3.new(from.X + dir.X * step, WATER_Y, from.Z + dir.Z * step)
	if anchor then
		local off = Vector3.new(newPos.X - anchor.X, 0, newPos.Z - anchor.Z)
		if off.Magnitude > LAND_LEASH then
			local clamped = anchor + off.Unit * LAND_LEASH
			newPos = Vector3.new(clamped.X, WATER_Y, clamped.Z)
		end
	end
	enemy:PivotTo(CFrame.lookAt(newPos, newPos + dir))
end

-- ⚠️ `canHitBoat` (Job #084) is NOT redundant with the tie check this used to do. Sea creatures can now
-- chase a SWIMMER far from the boat; without this flag, a croc that lunged at a swimmer who slipped
-- away would find no victim in range and fall through to damaging a hull 200 studs behind it.
-- The caller passes false whenever the creature was hunting a person rather than the boat.
--
-- The tie check itself has moved to the CALL SITE: while tied, `applyBite` is not reached at all, so
-- the crew standing on deck stops being bitten too — which was the broken half of the tied-boat report
-- (the hull was already spared; the people on it were not).
local function applyBite(def: EnemyDefs.EnemyDef, pos: Vector3, canHitBoat: boolean)
	local dmg = def.biteDamage * EnemyDefs.strengthFor(def.category, currentPhase())
	local victim = nearestPlayer(pos, def.biteRange)
	if victim then
		local before = (victim:GetAttribute("HP") :: number?) or 0
		local after = math.max(0, before - dmg)
		victim:SetAttribute("HP", after)
		flashHull()
		local vroot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		if vroot then
			CombatFx.hit(vroot.Position, before - after, "take") -- Job #084: RED, damage taken
		end
	elseif canHitBoat then
		local hp = (boat:GetAttribute("HP") :: number?) or 0
		local after = math.max(0, hp - dmg)
		boat:SetAttribute("HP", after)
		flashHull()
		CombatFx.hit(hull.Position, hp - after, "take")
	end
end

local function tickEnemy(enemy: Model, dt: number)
	-- ⚠️ BEFORE the guard below, which would otherwise destroy the corpse mid-topple (see `dying`).
	if dying[enemy] then
		return -- EnemyRig.die owns this body until its callback despawns it
	end
	local body = enemy.PrimaryPart
	local def = EnemyDefs.Defs[enemy.Name]
	local st = state[enemy]
	if not body or not def or not st then
		despawn(enemy)
		return
	end
	if ((enemy:GetAttribute("HP") :: number?) or 0) <= 0 then
		Workspace:SetAttribute("RunKills", ((Workspace:GetAttribute("RunKills") :: number?) or 0) + 1) -- run objective (Job 061)
		-- 🔴 THE DEATH USED TO BE INVISIBLE. `playOnce("death")` was followed by `despawn()` on the SAME
		-- FRAME, so the animation, the splash and the sound were all started on a model that was destroyed
		-- microseconds later. Enemies simply blinked out of existence — reported in play as "enemies just
		-- die by disappearing, not falling on the ground".
		--
		-- `EnemyRig.die` now plays the cues, topples the body and THEN despawns. `state[enemy]` is cleared
		-- here so `tickEnemy` stops driving it the instant it dies — a corpse must not keep chasing.
		state[enemy] = nil
		dying[enemy] = true -- Job #084: keeps the tick's guard off the body while it topples
		EnemyRig.die(enemy, function()
			despawn(enemy)
		end)
		return
	end
	local pos = body.Position
	local boatPos = hull.Position
	if boatPos.Z - pos.Z > CULL_BEHIND then
		despawn(enemy)
		return
	end
	st.biteTimer += dt

	-- ── Job #084: pick the target ─────────────────────────────────────────────────────────────────
	-- Sea creatures take the NEARER of {the boat, the nearest swimmer}. Land creatures stay on the boat:
	-- they are leashed to a bank anchor and cannot cross open water to reach a swimmer anyway.
	local targetPos, targetVel = boatPos, hull.AssemblyLinearVelocity
	local huntingSwimmer = false
	if def.category == "sea" then
		local sw = nearestSwimmer(pos)
		if sw and flatDist(sw.Position, pos) < flatDist(boatPos, pos) then
			targetPos, targetVel = sw.Position, sw.AssemblyLinearVelocity
			huntingSwimmer = true
		end
	end

	local dist = flatDist(targetPos, pos)
	-- lead the TARGET, not always the hull — leading a swimmer on the boat's velocity would aim at open
	-- water whenever the two are moving differently, which is most of the time.
	local lead = targetPos + targetVel * LEAD_TIME

	-- The tied-dock safe zone (see TIED_SAFE_RADIUS). Measured on the TARGET's distance from the hull,
	-- so one rule covers both halves: the boat itself is always inside its own bubble (→ everything
	-- disengages while tied), and a swimmer is protected only while they stay near the dock.
	local suppressed = tiedNow and flatDist(targetPos, boatPos) <= TIED_SAFE_RADIUS

	-- Job #078: presentational only. `chasing` is what the creature is DOING, so the animation follows
	-- the AI rather than the AI following the animation. Suppressed creatures settle to idle in view
	-- rather than freezing mid-stroke, and re-aggro (roar included — `st.roared` resets below) the
	-- instant the boat is untied.
	local chasing = dist <= def.aggroRadius and not suppressed
	EnemyRig.setMotion(enemy, if chasing then "move" else "idle")
	if chasing and not st.roared then
		st.roared = true
		EnemyRig.playSound(enemy, "aggro") -- once per aggro, not once per frame
	elseif not chasing then
		st.roared = false
		-- lurking: the occasional hiss/growl that tells you something is out there before it moves
		st.idleTimer = (st.idleTimer or rng:NextNumber(IDLE_SOUND_MIN, IDLE_SOUND_MAX)) - dt
		if st.idleTimer <= 0 then
			st.idleTimer = rng:NextNumber(IDLE_SOUND_MIN, IDLE_SOUND_MAX)
			EnemyRig.playSound(enemy, "idle")
		end
	end

	if def.category == "sea" then
		if chasing then
			if huntingSwimmer then
				-- Straight at the person. FLANK_DIST exists to stop crocs surfacing UNDERNEATH the
				-- hull; applied to a swimmer it would make them circle just out of reach instead of
				-- closing. Stop at bite range rather than 2 studs so they don't swim through them.
				stepToward(enemy, pos, lead, def.speed, dt, def.biteRange, nil)
			else
				-- attack from the boat's SIDE, not underneath it: aim at a flank point beside the hull
				local right = hull.CFrame.RightVector
				local flatRight = Vector3.new(right.X, 0, right.Z)
				flatRight = if flatRight.Magnitude > 0.01 then flatRight.Unit else Vector3.new(1, 0, 0)
				local target = lead + flatRight * ((st.side or 1) * FLANK_DIST)
				stepToward(enemy, pos, target, def.speed, dt, 2, nil)
			end
		end
	else -- land: leashed bank ambush
		if chasing then
			stepToward(enemy, pos, lead, def.speed, dt, def.biteRange, st.anchor)
		elseif st.anchor then
			-- also the tied-dock behaviour: suppressed land creatures slink back to their bank rather
			-- than standing in the shallows, which is exactly what this branch already did.
			stepToward(enemy, pos, st.anchor, def.speed * 0.6, dt, 2, nil)
		end
	end

	if not suppressed and dist <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		EnemyRig.playOnce(enemy, "attack")
		EnemyRig.playSound(enemy, "attack")
		applyBite(def, pos, not huntingSwimmer)
	end
end

-- enemy mix by category; weights shift from "near" (start) to "far" (deep) with progress (Job 033)
local SEA_POOL = {
	{ name = "Crocodile", near = 6, far = 3 },
	{ name = "Piranha", near = 4, far = 5 },
	{ name = "RiverHippo", near = 0, far = 4 }, -- only appears deeper downriver
}
local LAND_POOL = {
	{ name = "Wolf", near = 5, far = 4 },
	{ name = "Boar", near = 3, far = 5 },
}

local function distFrac(): number
	return math.clamp(RiverData.worldToDistance(hull.Position.Z) / ESCALATE_DISTANCE, 0, 1)
end

local function pickType(pool: { { name: string, near: number, far: number } }): EnemyDefs.EnemyDef
	local f = distFrac()
	local weights, total = {}, 0
	for i, e in ipairs(pool) do
		local w = math.max(0, e.near + (e.far - e.near) * f)
		weights[i] = w
		total += w
	end
	local r = rng:NextNumber(0, total)
	for i, e in ipairs(pool) do
		r -= weights[i]
		if r <= 0 then
			return EnemyDefs.Defs[e.name]
		end
	end
	return EnemyDefs.Defs[pool[1].name]
end

-- SOLO tuning (Job 058): scale threat by crew size so a lone player (who can't man two stations at once) can
-- finish, while a full crew faces the full load. 0.55× at 1 player → 1.0× at 6.
local SOLO_SCALE = 0.55
local function crewScale(): number
	local t = math.clamp((#Players:GetPlayers() - 1) / 5, 0, 1)
	return SOLO_SCALE + (1 - SOLO_SCALE) * t
end

local function seaCap(): number
	local c = math.floor((BASE_SEA_CAP + (MAX_SEA_CAP - BASE_SEA_CAP) * distFrac()) * ENEMY_DENSITY)
	if currentPhase() == "night" then
		c += 3 -- NIGHT SET-PIECE: the water surges (Job 035) — reach a dock and hold out
	end
	return math.max(1, math.floor(c * crewScale()))
end
local function landCap(): number
	local c = math.floor((BASE_LAND_CAP + (MAX_LAND_CAP - BASE_LAND_CAP) * distFrac()) * ENEMY_DENSITY)
	return math.max(1, math.floor(c * crewScale()))
end

local function countByCategory(cat: string): number
	local n = 0
	for _, e in CollectionService:GetTagged("Enemy") do
		if e:GetAttribute("Category") == cat then
			n += 1
		end
	end
	return n
end

-- global AI tick
RunService.Heartbeat:Connect(function(dt: number)
	-- Job #084: both of these are the SAME for every creature this frame, so they are resolved once
	-- here rather than recomputed inside `tickEnemy` up to 17 times.
	refreshSwimmers()
	tiedNow = boat:GetAttribute("Tied") == true
	for _, enemy in CollectionService:GetTagged("Enemy") do
		if enemy:IsA("Model") and enemy.Parent == Workspace then
			tickEnemy(enemy, dt)
		end
	end
end)

-- spawn interval: escalates with distance, and shortens when this category's time-of-day is strong
local function spawnInterval(base: number, category: string): number
	local dist = math.max(0, RiverData.worldToDistance(hull.Position.Z))
	local ramp = base * (1 - 0.5 * math.clamp(dist / ESCALATE_DISTANCE, 0, 1))
	return ramp / EnemyDefs.strengthFor(category, currentPhase())
end

-- SEA spawner: a mix of crocs / piranha / (deep) hippos in the channel ahead
task.spawn(function()
	while true do
		if Workspace:GetAttribute("RunStarted") and boatAlive() and countByCategory("sea") < seaCap() then
			local def = pickType(SEA_POOL)
			local z = hull.Position.Z + rng:NextNumber(SEA_AHEAD_MIN, SEA_AHEAD_MAX)
			local x = RiverData.centerlineX(z) + rng:NextNumber(-1, 1) * RiverData.widthAt(z) * 0.35
			local e = spawnEnemy(def, Vector3.new(x, WATER_Y, z), nil)
			local st = state[e]
			if st then
				st.side = if rng:NextNumber(-1, 1) >= 0 then 1 else -1 -- attack from left or right
			end
		end
		task.wait(spawnInterval(BASE_SEA_INTERVAL, "sea"))
	end
end)

-- LAND spawner: a mix of panthers / boars on the bank ahead (anchored to that bank point)
task.spawn(function()
	while true do
		if Workspace:GetAttribute("RunStarted") and boatAlive() and countByCategory("land") < landCap() then
			local def = pickType(LAND_POOL)
			local z = hull.Position.Z + rng:NextNumber(LAND_AHEAD_MIN, LAND_AHEAD_MAX)
			local side = if rng:NextNumber(-1, 1) >= 0 then 1 else -1
			-- fork-aware bank edge, then a bit INTO the treeline so they emerge from the dense forest (Job 051)
			local rightEdge, leftEdge = -math.huge, math.huge
			for _, b in RiverData.branchesAt(z) do
				rightEdge = math.max(rightEdge, b.c + b.halfW)
				leftEdge = math.min(leftEdge, b.c - b.halfW)
			end
			local baseEdge = if side == 1 then rightEdge else leftEdge
			local edge = baseEdge + side * rng:NextNumber(8, 20)
			local anchor = Vector3.new(edge, WATER_Y, z)
			spawnEnemy(def, anchor, anchor)
		end
		task.wait(spawnInterval(BASE_LAND_INTERVAL, "land"))
	end
end)

print("[Enemy] sea + land spawn directors online")
