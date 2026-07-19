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

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))

-- ── config ─────────────────────────────────────────────────────────────────
local BASE_SEA_CAP, MAX_SEA_CAP = 4, 9 -- concurrent sea enemies: grows with distance (+2 at night)
local BASE_LAND_CAP, MAX_LAND_CAP = 2, 5
local SEA_AHEAD_MIN, SEA_AHEAD_MAX = 180, 320 -- spawn well ahead → time to react at speed
local FLANK_DIST = 12 -- crocs attack from ~this far off the boat centre (its side), not underneath
local LAND_AHEAD_MIN, LAND_AHEAD_MAX = 60, 130
local LAND_LEASH = 65 -- how far a panther will lunge from its bank anchor
local CULL_BEHIND = 260
local LEAD_TIME = 0.8
local BASE_SEA_INTERVAL, BASE_LAND_INTERVAL = 4.0, 6.0
local ESCALATE_DISTANCE = 12000
-- ───────────────────────────────────────────────────────────────────────────

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y
local rng = Random.new()

type State = { biteTimer: number, anchor: Vector3?, side: number? }
local state: { [Model]: State } = {}

local function spawnEnemy(def: EnemyDefs.EnemyDef, pos: Vector3, anchor: Vector3?): Model
	local model = Instance.new("Model")
	model.Name = def.name

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

	local snout = Instance.new("Part")
	snout.Name = "Snout"
	snout.Size = Vector3.new(def.size.X * 0.6, def.size.Y * 0.7, def.size.Z * 0.35)
	snout.Color = def.color
	snout.Material = Enum.Material.SmoothPlastic
	snout.Anchored = true
	snout.CanCollide = false
	snout.CFrame = body.CFrame * CFrame.new(0, 0, -def.size.Z * 0.6)
	snout.Parent = model

	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:SetAttribute("Category", def.category)
	CollectionService:AddTag(model, "Enemy")
	model.Parent = Workspace
	state[model] = { biteTimer = def.biteCooldown, anchor = anchor }
	return model
end

local function despawn(enemy: Model)
	state[enemy] = nil
	enemy:Destroy()
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

local function applyBite(def: EnemyDefs.EnemyDef, pos: Vector3)
	local dmg = def.biteDamage * EnemyDefs.strengthFor(def.category, currentPhase())
	local victim = nearestPlayer(pos, def.biteRange)
	if victim then
		victim:SetAttribute("HP", math.max(0, ((victim:GetAttribute("HP") :: number?) or 0) - dmg))
		flashHull()
	elseif not boat:GetAttribute("Tied") then
		-- tied up at a dock = the boat is safe; threats just patrol around it (no attack)
		local hp = (boat:GetAttribute("HP") :: number?) or 0
		boat:SetAttribute("HP", math.max(0, hp - dmg))
		flashHull()
	end
end

local function tickEnemy(enemy: Model, dt: number)
	local body = enemy.PrimaryPart
	local def = EnemyDefs.Defs[enemy.Name]
	local st = state[enemy]
	if not body or not def or not st then
		despawn(enemy)
		return
	end
	if ((enemy:GetAttribute("HP") :: number?) or 0) <= 0 then
		despawn(enemy)
		return
	end
	local pos = body.Position
	local boatPos = hull.Position
	if boatPos.Z - pos.Z > CULL_BEHIND then
		despawn(enemy)
		return
	end
	st.biteTimer += dt
	local dist = (Vector3.new(boatPos.X, 0, boatPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	local lead = boatPos + hull.AssemblyLinearVelocity * LEAD_TIME

	if def.category == "sea" then
		if dist <= def.aggroRadius then
			-- attack from the boat's SIDE, not underneath it: aim at a flank point beside the hull
			local right = hull.CFrame.RightVector
			local flatRight = Vector3.new(right.X, 0, right.Z)
			flatRight = if flatRight.Magnitude > 0.01 then flatRight.Unit else Vector3.new(1, 0, 0)
			local target = lead + flatRight * ((st.side or 1) * FLANK_DIST)
			stepToward(enemy, pos, target, def.speed, dt, 2, nil)
		end
	else -- land: leashed bank ambush
		if dist <= def.aggroRadius then
			stepToward(enemy, pos, lead, def.speed, dt, def.biteRange, st.anchor)
		elseif st.anchor then
			stepToward(enemy, pos, st.anchor, def.speed * 0.6, dt, 2, nil) -- slink back to the bank
		end
	end

	if dist <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		applyBite(def, pos)
	end
end

-- enemy mix by category; weights shift from "near" (start) to "far" (deep) with progress (Job 033)
local SEA_POOL = {
	{ name = "Crocodile", near = 6, far = 3 },
	{ name = "Piranha", near = 4, far = 5 },
	{ name = "RiverHippo", near = 0, far = 4 }, -- only appears deeper downriver
}
local LAND_POOL = {
	{ name = "Panther", near = 5, far = 4 },
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

local function seaCap(): number
	local c = BASE_SEA_CAP + math.floor((MAX_SEA_CAP - BASE_SEA_CAP) * distFrac())
	if currentPhase() == "night" then
		c += 2 -- night surge on the water
	end
	return c
end
local function landCap(): number
	return BASE_LAND_CAP + math.floor((MAX_LAND_CAP - BASE_LAND_CAP) * distFrac())
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
			local edge = RiverData.centerlineX(z) + side * (RiverData.widthAt(z) * 0.5 + 8)
			local anchor = Vector3.new(edge, WATER_Y, z)
			spawnEnemy(def, anchor, anchor)
		end
		task.wait(spawnInterval(BASE_LAND_INTERVAL, "land"))
	end
end)

print("[Enemy] sea + land spawn directors online")
