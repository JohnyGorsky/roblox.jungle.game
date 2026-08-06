--!strict
-- ExcursionServer.server.luau — dock → jungle-zone raid loop (Jobs 011 → 012).
--
-- Only LANDING-site docks open a big walkable jungle BASIN carved inland (the steep mountains become
-- the ring around it). Greybox trees scatter through it; a few CAMPS sit at increasing depth (deeper =
-- more guards). Tie the boat, go ashore, trek in, loot camps (guarded), carry loot back to the boat.
-- Server-authoritative. (Trees/camps are greybox — real objects come in the art pass.)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerStorage = game:GetService("ServerStorage")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local ServerScriptService = game:GetService("ServerScriptService")
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
-- Job #076: camp clearings draw from the SAME shore-band table the riverbank uses, so the two can't drift
local FoliageDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("FoliageDefs"))
-- Job #077: the camp's CONTENTS (which model plays which role, where it sits, how the ground is painted,
-- what the VFX/light budget is) live in CampDefs. Nothing in this file decides dressing.
local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))
local Campfire = require(ServerScriptService:WaitForChild("World"):WaitForChild("Campfire"))
local CampAmbience = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampAmbience"))
-- Models AND single parts: `GoldNugget` is a bare MeshPart (see `prop`).
local campFloraLib: { [string]: PVInstance } = {}
local openShop = ReplicatedStorage:WaitForChild("OpenShop") :: RemoteEvent -- village trading post (Job 023)

local CAMP_AHEAD = 1400
local CULL_BEHIND = 1200 -- destroy a landing site once the boat is this far past it (frees trees/huts/guards) — Job 060
local BASIN_SIZE = 400 -- walkable jungle zone size (studs)
local GUARD_LEASH = 55
local PATH_HALF = 18 -- keep a tree-free walking lane this wide (half) from the shore to the camps (Job 053)
local MAX_GUARDS = 6 -- escalation cap per camp (Job 053)

-- perpendicular distance (X/Z) from point (px,pz) to segment A→B — used to keep the path lane clear of trees
local function distToSeg(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + t * dx, az + t * dz
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Rare "found gold" (Job 022, design Job 020 §2): a nugget worth 1 Gold may spawn at a camp. Chance per
-- camp is low and the run is hard-capped so looting can't eclipse finishing (the Dead Rails trap).
local NUGGET_CHANCE = 0.25 -- per camp
local NUGGET_VALUE = 1 -- Gold per nugget
local NUGGET_CAP = 3 -- max nuggets spawned per run (tracked on Workspace)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local Terrain = Workspace.Terrain
local CLEAR_Y = RiverData.WATER_Y + 3 -- basin floor / walkable ground height

local campsRoot = Instance.new("Folder")
campsRoot.Name = "Camps"
campsRoot.Parent = Workspace

local built: { [number]: boolean } = {}
local siteModels: { [number]: Model } = {} -- index → LandingSite model, for culling (Job 060)
-- Job #077: the carried crate is a MODEL now (a scaled `Barrel`), not a single Part. Everything that
-- touches it — the deposit prompt, `pickupLoot` — only ever reads an attribute or destroys it, both of
-- which work identically on a Model.
local carrying: { [Player]: Model } = {}
type GuardState = { biteTimer: number, anchor: Vector3 }
local guardState: { [Model]: GuardState } = {}

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, parent: Instance, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- ── REAL PROPS (Job #077) ─────────────────────────────────────────────────────────────────────────
-- Every visible camp object is a model from `ServerStorage.AssetLibrary` now. `block()` above survives
-- only for INVISIBLE trigger/anchor parts — if you can see a coloured box in a camp, it is a bug.

-- Ground height under a point, measured not assumed. `CLEAR_Y` is the carve height (15) but terrain voxels
-- snap to the RES=4 grid, so the walkable surface is ~17 — trusting CLEAR_Y buried props by 2.4 studs.
--
-- ⚠️ Rejects near-VERTICAL hits. The basin is ringed by terrain `wallBlock` walls; a ray landing on a wall
-- face returns a height metres above the floor, which is what put a handful of props visibly out of place.
local function groundAt(x: number, z: number): number
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
	rp.IgnoreWater = true
	for _, from in ipairs({ CLEAR_Y + 60, CLEAR_Y + 6 }) do
		local hit = Workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -300, 0), rp)
		-- Normal.Y near 1 = a floor. A wall face gives ~0 and is not somewhere a tent belongs.
		if hit and hit.Normal.Y > 0.7 then
			return hit.Position.Y
		end
	end
	return CLEAR_Y
end

-- Place a library model with its BASE on the ground, facing `lookAt`, and return it.
-- `yawOnly` keeps props upright; nothing here should ever be tilted.
type PropOpts = {
	scale: number?,
	yaw: number?,
	faceTo: Vector3?,
	collide: boolean?,
	sink: number?,
	-- Defaults to `collide`, which is right for almost everything. The exception that forced this to be
	-- separable is `RangerTower`: 128 parts that must be solid (you can climb it) but must NOT each cast
	-- a shadow, which would be the single most expensive object in the scene.
	shadow: boolean?,
}

-- ⚠️ Returns a `PVInstance`, not a `Model`. Most of the library is Models, but `GoldNugget` is a bare
-- `MeshPart` — a Model-only signature meant `prop("GoldNugget")` returned nil and NO NUGGET EVER SPAWNED,
-- while still burning a slot against the run cap. Anything here must cope with both.
local function prop(name: string, x: number, z: number, parent: Instance, opts: PropOpts?): PVInstance?
	local source = campFloraLib[name]
	if not source then
		warn(("[Excursion] AssetLibrary has no %q — camp prop skipped"):format(name))
		return nil
	end
	local o: PropOpts = opts or {}
	local clone = source:Clone()
	local parts = clone:GetDescendants()
	table.insert(parts, clone) -- a MeshPart source IS the part; it has no BasePart descendants
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- Structures you walk around SHOULD collide; loose dressing should not, so a firefight in a
			-- camp doesn't turn into a maze of invisible walls.
			d.CanCollide = o.collide == true
			d.CastShadow = if o.shadow ~= nil then o.shadow else o.collide == true
		end
	end

	-- The model's own corrective scale from `CampDefs.SCALE` (published models are not authored for this
	-- camp — `Tent` ships at 43×34 studs) COMPOSED with any per-instance jitter the caller asked for.
	--
	-- `ScaleTo` is a Model method. A single-part prop scales by Size instead — and note that resizing a
	-- MeshPart re-derives its collision geometry (the gotcha recorded in `ASSETS.md` §3.5), which is
	-- harmless only because everything we scale this way is non-colliding.
	local scale = (CampDefs.SCALE[name] or 1) * (o.scale or 1)
	if math.abs(scale - 1) > 1e-3 then
		if clone:IsA("Model") then
			clone:ScaleTo(scale)
		elseif clone:IsA("BasePart") then
			clone.Size *= scale
		end
	end

	local yaw = o.yaw or 0
	if o.faceTo then
		local d = Vector3.new(o.faceTo.X - x, 0, o.faceTo.Z - z)
		if d.Magnitude > 0.01 then
			yaw = math.atan2(d.X, d.Z)
		end
	end
	clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * CFrame.Angles(0, yaw, 0))
	FoliageDefs.seatOnGround(clone, groundAt(x, z), o.sink or 0.3)
	clone.Parent = parent
	return clone
end

-- A ProximityPrompt cannot be parented to a Model, and library models have no dependable PrimaryPart.
-- So every interactive Model gets one invisible anchor INSIDE it, at a consistent height above the
-- model's true base — which also means the prompt floats at the same height on a barrel and on a 40-stud
-- hut instead of wherever the publisher happened to put the origin.
--
-- A single-part prop needs none of that: the prompt goes straight on the part.
local function promptAnchor(inst: PVInstance, height: number): BasePart
	if inst:IsA("BasePart") then
		return inst
	end
	local model = inst :: Model
	local _, extents = model:GetBoundingBox()
	local base = FoliageDefs.worldBottom(model) or model:GetPivot().Position.Y
	local centre = model:GetPivot().Position
	local a = Instance.new("Part")
	a.Name = "PromptAnchor"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.CFrame = CFrame.new(centre.X, base + math.min(height, extents.Y * 0.7), centre.Z)
	a.Parent = model
	return a
end

-- rare gold nugget: grab it for 1 Gold, run-capped. Credits the persistent profile immediately.
--
-- Job #077: was a 2×2×2 **Neon** cube. It is the Meshy `GoldNugget` mesh now — grey quartz with gold
-- veining, so it reads as ore you found in a jungle rather than a video-game coin, and so it still reads
-- against the sand and grass it lies on. `CanCollide` stays FALSE (it is collected by prompt, and a
-- collidable pebble underfoot is a trip hazard); the run cap and the Gold value are untouched.
local function trySpawnNugget(pos: Vector3, parent: Instance, rng: Random)
	local spawned = (Workspace:GetAttribute("NuggetsSpawned") :: number?) or 0
	if spawned >= NUGGET_CAP or rng:NextNumber() > NUGGET_CHANCE then
		return
	end
	Workspace:SetAttribute("NuggetsSpawned", spawned + 1)

	local nug = prop(CampDefs.MODEL.nugget, pos.X, pos.Z, parent, { scale = 1, sink = 0, yaw = rng:NextNumber(0, math.pi * 2) })
	if not nug then
		return -- warned by `prop`; a missing library must not silently consume a capped nugget slot
	end
	nug.Name = "GoldNugget"

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NuggetPrompt"
	prompt.ActionText = "Grab Gold"
	prompt.ObjectText = "Gold Nugget"
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Parent = promptAnchor(nug, 1.5)
	prompt.Triggered:Connect(function(player: Player)
		if not nug.Parent then
			return
		end
		nug:Destroy()
		if Profiles.isReady(player) then
			Profiles.addGold(player, NUGGET_VALUE)
		end
		player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + 30) -- Job 023
	end)
end

-- flatten a walkable patch (fill solid below CLEAR_Y, clear terrain above — incl. tall mountains)
-- Job #077: the base material is `LeafyGrass`, not `Grass` — deeper and more overgrown, so the basin
-- floor reads as jungle floor rather than lawn. `FoliageDefs.JUNGLE_GROUND` already accepts both, so
-- #076's foliage plants on it unchanged.
local function carve(cx: number, cz: number, size: number)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y - 20, cz), Vector3.new(size, 40, size), CampDefs.GROUND.base)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y + 32, cz), Vector3.new(size, 64, size), Enum.Material.Air)
end

-- ── ground painting (Job #077, plan Part 3) ───────────────────────────────────────────────────────
-- The basin used to be ONE FLAT `Grass` fill — exactly what STYLEGUIDE §4 forbids. This paints over the
-- SAME voxels the carve already filled: no new terrain region, one extra pass at camp-build time and
-- ZERO at runtime.
--
-- ⚠️ EVERY PAINT BLOCK TOPS OUT AT `CLEAR_Y`. Go a stud higher and you are not painting, you are adding
-- solid above the floor — and the basin grows bumps you cannot see in the editor but trip over in play.
local function paintDisc(x: number, z: number, radius: number, material: Enum.Material)
	local d = CampDefs.GROUND.depth
	Terrain:FillCylinder(CFrame.new(x, CLEAR_Y - d / 2, z), d, radius, material)
end

-- Pass 1 and 2 of three. Scattered patches are painted FIRST at low weight; the desire-line path (the
-- caller's `FillBlock`) and the trampled rings (`paintTrampled`) go ON TOP at full weight. The other way
-- round and the random patches eat holes in the path.
local function paintBasin(cx: number, cz: number, size: number, waterEdge: number, side: number, rng: Random)
	local G = CampDefs.GROUND
	local half = size / 2 - 6

	-- Grass patches, so the LeafyGrass default isn't one flat tone either
	for _ = 1, G.grassPatches.count do
		paintDisc(
			cx + rng:NextNumber(-1, 1) * half,
			cz + rng:NextNumber(-1, 1) * half,
			rng:NextNumber(G.grassPatches.radius[1], G.grassPatches.radius[2]),
			Enum.Material.Grass
		)
	end

	-- Bare-earth scatter. SMALL and SPARSE by decision — see the A3 risk note in `CampDefs.GROUND`: if
	-- this reads as mush next to the path, the lever is `scatter.count`, never the path width.
	for _ = 1, G.scatter.count do
		paintDisc(
			cx + rng:NextNumber(-1, 1) * half,
			cz + rng:NextNumber(-1, 1) * half,
			rng:NextNumber(G.scatter.radius[1], G.scatter.radius[2]),
			G.scatter.materials[rng:NextInteger(1, #G.scatter.materials)]
		)
	end

	-- The bank where the basin meets the water — §4 wants it a different tone from the interior.
	-- ⚠️ Safe above the water line by construction: `CLEAR_Y` is `WATER_Y + 3` and this tops out AT
	-- `CLEAR_Y`. Push it any lower and it reads as a muddy pool rather than a bank.
	local bankX = waterEdge + side * (G.bank.width / 2)
	Terrain:FillBlock(
		CFrame.new(bankX, CLEAR_Y - G.depth / 2, cz),
		Vector3.new(G.bank.width, G.depth, size),
		G.bank.material
	)
end

-- Pass 3: worn earth where people actually walk. This is environmental storytelling, not texture
-- variety — bare ground under the tents and around the fire is the evidence that someone lives here.
local function paintTrampled(campPos: Vector3, approach: Vector3)
	local G = CampDefs.GROUND
	local fire = CampDefs.slotToWorld(campPos, approach, CampDefs.LAYOUT.fire)
	paintDisc(fire.X, fire.Z, G.trampled.fireRadius, G.trampled.material)
	for _, slot in ipairs({ CampDefs.LAYOUT.hut, CampDefs.LAYOUT.tent }) do
		local p = CampDefs.slotToWorld(campPos, approach, slot)
		paintDisc(p.X, p.Z, G.trampled.hutRadius, G.trampled.material)
	end
end

-- deposit carried loot at the boat → a resource count. ONLY shown while someone is carrying.
local deposit = Instance.new("ProximityPrompt")
deposit.Name = "DepositPrompt"
deposit.ActionText = "Deposit"
deposit.ObjectText = "Cargo"
deposit.HoldDuration = 0.5
deposit.RequiresLineOfSight = false
deposit.MaxActivationDistance = 16
deposit.Enabled = false
deposit.Parent = hull
deposit.Triggered:Connect(function(player: Player)
	local carried = carrying[player]
	if not carried then
		return
	end
	local resource = (carried:GetAttribute("Resource") :: string?) or "Metal"
	local total = ((boat:GetAttribute("Gasoline") :: number?) or 0)
		+ ((boat:GetAttribute("Metal") :: number?) or 0)
		+ ((boat:GetAttribute("Ammo") :: number?) or 0)
	if total >= ((boat:GetAttribute("CargoMax") :: number?) or 10) then
		return -- cargo deck full → keep carrying it
	end
	boat:SetAttribute(resource, ((boat:GetAttribute(resource) :: number?) or 0) + 1)
	carried:Destroy()
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	local char = player.Character
	if char then
		char:SetAttribute("Carrying", nil)
	end
	deposit.Enabled = next(carrying) ~= nil
end)

-- award in-run Salvage (Job 023) — cash rewards raiding, not passive driving.
-- Scavenger's Instinct (Job 029): the looter's skill boosts the Salvage payout.
local function awardSalvage(player: Player, amount: number)
	local scav = (player:GetAttribute("SkillScavenge") :: number?) or 0
	local total = math.floor(amount * (1 + 0.03 * scav))
	player:SetAttribute("Salvage", ((player:GetAttribute("Salvage") :: number?) or 0) + total)
end

-- Build the thing that rides over your head while you haul loot back to the boat.
--
-- ⚠️ THREE PROPERTIES HERE ARE LOAD-BEARING, and two of them are new hazards created by making this a
-- model instead of a Part:
--   · `Anchored = false` on EVERY part. An anchored part welded to the character's root anchors the
--     whole assembly — you would freeze in place the instant you picked up loot.
--   · `Massless = true` on every part. It is welded to your root; a 6-part barrel with real mass changes
--     how the character moves while hauling, and hauling feel is tuned (Job 023).
--   · `CanCollide = false`, else it collides with the world over your head.
local function makeCarried(root: BasePart, resource: string): Model
	local carried: Model
	local source = campFloraLib[CampDefs.MODEL.barrel]
	if source and source:IsA("Model") then
		carried = source:Clone()
		carried:ScaleTo(0.5) -- shoulder-sized, not the full camp barrel
		carried:PivotTo(root.CFrame * CFrame.new(0, 3, 0))
	else
		-- The library is missing (unsaved place file). Still give the player something to carry rather
		-- than an invisible haul — the Busy/deposit flow depends on this object existing.
		carried = Instance.new("Model")
		local box = Instance.new("Part")
		box.Name = "Crate"
		box.Size = Vector3.new(3, 3, 3)
		box.Color = Color3.fromRGB(150, 120, 70)
		box.Material = Enum.Material.WoodPlanks
		box.CFrame = root.CFrame * CFrame.new(0, 2.5, 0)
		box.Parent = carried
		carried.PrimaryPart = box
	end

	carried.Name = "CarriedCrate"
	carried:SetAttribute("Resource", resource)
	for _, d in ipairs(carried:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	return carried
end

local function pickupLoot(player: Player, crate: PVInstance)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return
	end

	-- weapon / ammo crates GRANT to the loadout instantly (no carry, no Busy) — Job 015
	local kind = (crate:GetAttribute("Kind") :: string?) or "Resource"
	if kind == "Weapon" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		if InventoryService.grant(player, id) then
			awardSalvage(player, 80)
			crate:Destroy()
		end -- inventory full → leave the crate so the player can free a slot
		return
	elseif kind == "Ammo" then
		local id = (crate:GetAttribute("Id") :: string?) or "Pistol"
		local def = ItemDefs.get(id)
		InventoryService.addAmmo(player, id, (def and def.ammoPerCrate) or 12)
		awardSalvage(player, 40)
		crate:Destroy()
		return
	end

	-- resource crates (gasoline/metal/turret-ammo): carry back to the boat cargo (existing behaviour)
	if carrying[player] then
		return
	end
	local resource = (crate:GetAttribute("Resource") :: string?) or "Metal"
	local carried = makeCarried(root, resource)
	carried.Parent = char
	carrying[player] = carried
	awardSalvage(player, 40)
	char:SetAttribute("Carrying", resource)
	player:SetAttribute("Busy", true) -- hands full → can't shoot
	deposit.Enabled = true
	crate:Destroy()
end

local function spawnGuard(anchorPos: Vector3, parent: Instance)
	local def = EnemyDefs.Defs.Panther
	local guard = Instance.new("Model")
	guard.Name = "CampGuard"
	local body = block("Body", def.size, def.color, CFrame.new(anchorPos + Vector3.new(0, def.size.Y / 2, 0)), guard)
	guard.PrimaryPart = body
	guard:SetAttribute("HP", def.hp)
	guard:SetAttribute("MaxHP", def.hp)
	CollectionService:AddTag(guard, "CampGuard")
	guard.Parent = parent
	guardState[guard] = { biteTimer = def.biteCooldown, anchor = Vector3.new(anchorPos.X, CLEAR_Y + def.size.Y / 2, anchorPos.Z) }
end

-- The `LootPrompt` wiring, identical for every kind of crate. Name, hold duration, activation distance
-- and the `Triggered` → `pickupLoot` connection are all exactly what the greybox had — only the object
-- the prompt hangs off changed.
local function lootPrompt(crate: PVInstance, actionText: string)
	local loot = Instance.new("ProximityPrompt")
	loot.Name = "LootPrompt"
	loot.ActionText = actionText
	loot.ObjectText = "Crate"
	loot.HoldDuration = 1.2
	loot.RequiresLineOfSight = false
	loot.MaxActivationDistance = 10
	loot.Parent = promptAnchor(crate, 3)
	loot.Triggered:Connect(function(player: Player)
		pickupLoot(player, crate)
	end)
end

-- ── the camp (Job #077) ───────────────────────────────────────────────────────────────────────────
-- Was: two coloured `Hut` blocks and up to three tinted 4×4×4 cubes at hardcoded world offsets.
--
-- The offsets could not survive the swap — `Tent` is 43×34 studs against the 10×10 block it replaces —
-- so the layout is re-derived from `CampDefs.LAYOUT` in a frame oriented on `approach`, the direction the
-- player walks in from the dock. That is what makes "everything faces the way you arrive" true on both
-- banks of the river without a per-camp table.
--
-- ⚠️ ONE THING DELIBERATELY LOST: the greybox tinted each crate by resource (yellow gasoline, grey
-- metal). Real wooden barrels cannot carry that without the neon-prop look STYLEGUIDE §12 forbids, so
-- what is in a crate is now read off its `LootPrompt` ActionText ("Loot Gasoline") on approach instead of
-- its colour at distance. If that turns out to matter in play, the fix is a small painted stencil or a
-- resource icon on the crate — NOT re-tinting the whole barrel.
local function buildCampAt(
	campPos: Vector3,
	parent: Instance,
	guards: number,
	resources: { string },
	kind: CampDefs.CampKind,
	approach: Vector3,
	rng: Random
)
	local L = CampDefs.LAYOUT
	local function at(slot: CampDefs.Slot): Vector3
		return CampDefs.slotToWorld(campPos, approach, slot)
	end
	-- a point back down the path, for everything that should face the way the player arrives
	local approachFrom = campPos - approach * 80

	-- ground FIRST: props raycast the terrain to seat themselves, so paint before you place.
	paintTrampled(campPos, approach)

	-- The fire is the centre. Placed first; everything else is positioned relative to it.
	local firePos = at(L.fire)
	local fireGround = groundAt(firePos.X, firePos.Z)
	Campfire.build({
		position = Vector3.new(firePos.X, fireGround, firePos.Z),
		parent = parent,
		lib = campFloraLib,
		rng = rng,
	})

	-- Living quarters at the back, facing the fire.
	local hutAt = at(L.hut)
	prop(kind.hut, hutAt.X, hutAt.Z, parent, { collide = true, faceTo = firePos })
	local tentAt = at(L.tent)
	prop(CampDefs.MODEL.tent, tentAt.X, tentAt.Z, parent, { collide = true, faceTo = firePos })

	-- The sandbag line, across the approach. This is the piece of dressing that does real gameplay work:
	-- cover between the player and the crates is what makes the guards matter.
	if kind.sandbags then
		for _, slot in ipairs(L.sandbags) do
			local p = at(slot)
			prop(CampDefs.MODEL.sandbag, p.X, p.Z, parent, { collide = true, faceTo = approachFrom })
		end
	end

	-- Loot BEHIND that line. Index 1 is the hero `CrateWood` — 66 instances, so exactly ONE per camp;
	-- everything after it is a 6-instance `Barrel`. That single choice is ~90% of the part cost the
	-- all-CrateWood version would have carried.
	for i, res in ipairs(resources) do
		local slot = L.loot[i] or L.loot[#L.loot]
		local p = at(slot)
		local model = prop(
			if i == 1 then CampDefs.MODEL.crate else CampDefs.MODEL.barrel,
			p.X,
			p.Z,
			parent,
			{ collide = true, faceTo = approachFrom }
		)
		if model then
			model.Name = "LootCrate"
			model:SetAttribute("Resource", res)
			lootPrompt(model, "Loot " .. res)
		end
	end

	-- A landmark you can see from the water, marking the stops that open a jungle basin.
	-- ⚠️ 128 parts, and shadows explicitly OFF: 128 shadow casters at every landing would be the most
	-- expensive single object in the scene, for an effect nobody looks at.
	if kind.tower then
		local t = at(L.tower)
		prop(CampDefs.MODEL.tower, t.X, t.Z, parent, { collide = true, shadow = false, faceTo = firePos })
	end

	-- Loose dressing so the camp isn't only functional objects. Non-colliding: a firefight in a camp
	-- must not become a maze of invisible walls.
	for i = 1, kind.extraDressing do
		local slot = L.dressing[i]
		if slot then
			local p = at(slot)
			prop(CampDefs.MODEL.barrel, p.X, p.Z, parent, {
				collide = false,
				yaw = rng:NextNumber(0, math.pi * 2),
				scale = rng:NextNumber(0.85, 1.15),
			})
		end
	end

	CampAmbience.dress({
		centre = Vector3.new(firePos.X, fireGround, firePos.Z),
		approach = approach,
		parent = parent,
		groundY = fireGround,
		hutPos = Vector3.new(hutAt.X, groundAt(hutAt.X, hutAt.Z), hutAt.Z),
	})

	-- ⚠️ UNCHANGED, AND MUST STAY UNCHANGED. Job #058 tunes difficulty by crew size against these exact
	-- spawn positions and this exact count. The re-dress moved everything else; it does not move guards.
	for i = 1, guards do
		spawnGuard(campPos + Vector3.new((i - 1) * 7, 0, 8), parent)
	end
end

-- a loadout crate: Kind "Weapon" (grants a gun to a slot) or "Ammo" (tops up that gun's ammo). No carry.
-- Job #077: `AmmoBox` (22 parts) — a military crate, which is what a weapon cache should look like next
-- to the wooden barrels of the resource pile.
local function makeKindCrate(pos: Vector3, kind: string, id: string, actionText: string, parent: Instance, faceTo: Vector3)
	local crate = prop(CampDefs.MODEL.weaponCrate, pos.X, pos.Z, parent, { collide = true, faceTo = faceTo })
	if not crate then
		return
	end
	crate.Name = "LootCrate"
	crate:SetAttribute("Kind", kind)
	crate:SetAttribute("Id", id)
	lootPrompt(crate, actionText)
end

-- ── camp foliage (Job #076) ───────────────────────────────────────────────────────────────────────
-- This used to be a 2-part box trunk + box canopy, 45 per camp. It is real models now, drawn from the
-- SAME shore-band table `FoliageServer` uses (`FoliageDefs.BANDS[1]`), so a camp clearing is planted with
-- the same vocabulary as the riverbank it sits behind and the two never drift apart.
--
-- Scoped to #076 rather than #077 on purpose: this is foliage, and leaving it greybox would have put box
-- trees at all six landings inside an otherwise real jungle. Camp STRUCTURES are #077.
local campFlora: { { model: string, scale: { number }, tiltMax: number? } } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local byName: { [string]: PVInstance } = {}
	if lib then
		for _, group in ipairs(lib:GetChildren()) do
			for _, m in ipairs(group:GetChildren()) do
				-- BaseParts too, not just Models — the library stores `GoldNugget` as a lone MeshPart
				if m:IsA("Model") or m:IsA("BasePart") then
					byName[m.Name] = m
				end
			end
		end
	end
	for _, e in ipairs(FoliageDefs.BANDS[1].entries) do
		if byName[e.model] then
			table.insert(campFlora, { model = e.model, scale = e.scale, tiltMax = e.tiltMax })
		end
	end
	if #campFlora == 0 then
		warn("[Excursion] no AssetLibrary foliage — camp clearings will be bare (the library is in the "
			.. "place file, not git: open the game place and save it)")
	end
	campFloraLib = byName
end

local function tree(x: number, z: number, parent: Instance, rng: Random)
	if #campFlora == 0 then
		return
	end
	local pick = campFlora[rng:NextInteger(1, #campFlora)]
	local source = campFloraLib[pick.model]
	if not source or not source:IsA("Model") then
		return -- every foliage entry is a Model; a single-part one would need the `prop` path instead
	end
	local clone = source:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false -- a camp you fight in must not be a maze of invisible collision
			d.CastShadow = false
		end
	end
	-- (no LevelOfDetail write here either — server scripts lack the Plugin capability; it is authored on
	-- the AssetLibrary source models and inherited by clones)

	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local orient = yaw
	if pick.tiltMax and pick.tiltMax > 0 then
		local a = math.rad(rng:NextNumber(0, pick.tiltMax))
		local dir = rng:NextNumber(0, math.pi * 2)
		orient = CFrame.fromAxisAngle(Vector3.new(math.cos(dir), 0, math.sin(dir)), a) * yaw
	end

	clone:ScaleTo(rng:NextNumber(pick.scale[1], pick.scale[2]))
	clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * orient)

	-- ⚠️ RAYCAST THE GROUND, DO NOT ASSUME `CLEAR_Y`. The basin is filled to CLEAR_Y (=15), but terrain
	-- voxels snap to the RES=4 grid, so the actual walkable surface is ~17 — and the first pass, which
	-- trusted CLEAR_Y, buried every camp plant by a measured 2.4 studs. Measure, don't assume.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, CLEAR_Y + 80, z), Vector3.new(0, -300, 0), params)
	local groundY = if hit then hit.Position.Y else CLEAR_Y
	FoliageDefs.seatOnGround(clone, groundY, 0.4)
	clone.Parent = parent

	-- The raycast above is a POINT test. Check the ground the plant actually STANDS on — a small disc,
	-- not the canopy, for the reason `groundClearFraction` documents.
	if FoliageDefs.groundClearFraction(x, z, 6, RiverData.WATER_Y, 1) > FoliageDefs.MAX_OVER_WATER then
		clone:Destroy()
	end
end

-- ── the physical shop sign (Job #077) ─────────────────────────────────────────────────────────────
-- Replaces a floating `BillboardGui`. STYLEGUIDE §5 is explicit that world signage is PHYSICAL and uses
-- `Theme.font.sign`, not screen UI — and an `AlwaysOnTop` billboard renders THROUGH the terrain and
-- through the hut it is meant to be attached to. That is the same class of bug Job #072 hit with world
-- tags visible from the plane, shipped a second time.
--
-- Built from parts rather than cloned from `EntrySign`/`WelcomeSign`: those are LOBBY scenery, and this
-- is the game place. Rather than depend on an asset that may not have been localized here, this is the
-- lobby's own proven recipe — a WoodPlanks board on two posts (`ASSETS.md` §1.3) — rebuilt in code, with
-- a `SurfaceGui` on BOTH faces so it reads from the water and from the path.
local function buildShopSign(pos: Vector3, faceTo: Vector3, parent: Instance)
	local ground = groundAt(pos.X, pos.Z)
	local d = Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z)
	local yaw = if d.Magnitude > 0.01 then math.atan2(d.X, d.Z) else 0
	local base = CFrame.new(pos.X, ground, pos.Z) * CFrame.Angles(0, yaw, 0)

	for _, dx in ipairs({ -3.4, 3.4 }) do
		local post = block("Post", Vector3.new(0.5, 7, 0.5), Theme.color.woodDark, base * CFrame.new(dx, 3.5, 0), parent, Enum.Material.Wood)
		post.CanCollide = false
	end
	local board = block("ShopSign", Vector3.new(8, 3, 0.4), Theme.color.wood, base * CFrame.new(0, 6.2, 0), parent, Enum.Material.WoodPlanks)
	board.CanCollide = false

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.MaxDistance = 320 -- occluded correctly by the world, unlike the billboard it replaces
		sg.Parent = board
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(0.9, 0.8)
		lbl.Position = UDim2.fromScale(0.05, 0.1)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Theme.color.cream -- never pure white (STYLEGUIDE §4)
		lbl.TextStrokeColor3 = Theme.color.stroke
		lbl.TextStrokeTransparency = 0.4
		lbl.Font = Theme.font.sign -- SpecialElite — physical world signs only
		lbl.TextScaled = true
		lbl.Text = "TRADING POST"
		lbl.Parent = sg
	end
end

-- ── the clearing ring (user direction, 2026-08-06) ────────────────────────────────────────────────
-- A landing basin must read as a CLEARING CUT INTO the jungle, not a lawn with plants dotted on it.
-- Before this, `tree()` scattered shore-band undergrowth uniformly edge to edge, so the camp had no
-- edge — and the terrain `wallBlock` rock walls that contain the basin were plainly visible as walls.
--
-- This tiles `JungleTreesPack` — the same 218-stud canopy cluster `FoliageServer` walls the riverbank
-- with — around the three INLAND sides, just inside the rock wall. The water side stays open, because
-- that is the side you arrive from and the side the dock is on.
--
-- ⚠️ ~6 packs × 112 parts ≈ 670 parts, the biggest single line item in a landing site. Affordable only
-- because 1–2 sites are ever live. `CampDefs.CLEARING.ring.spacing` is the lever, and the ring degrades
-- gracefully when thinned because the tiles are meant to overlap.
local function plantClearingRing(cx: number, cz: number, size: number, waterEdge: number, side: number, parent: Instance, rng: Random)
	local R = CampDefs.CLEARING.ring
	local source = campFloraLib[R.model]
	if not source or not source:IsA("Model") then
		warn(("[Excursion] AssetLibrary has no %q — camp clearing gets no canopy ring"):format(R.model))
		return
	end

	-- ⚠️ HALF THE PACK'S LENGTH, not zero. This model is 218 studs long, so a tile whose CENTRE is 30
	-- studs inland still reaches ~80 studs out into the river. The first version of this ring used the
	-- centre only and put canopy in the water.
	local _, packSize = source:GetBoundingBox()
	local packHalf = math.max(packSize.X, packSize.Z) / 2

	-- ⚠️ AND the bank is not where the dock says it is. `waterEdge` is sampled at the dock's Z, but the
	-- river MEANDERS: 170 studs up- or downstream the channel has moved, so a ring run along the basin's
	-- Z edges that trusts one sample walks straight into the water at its ends.
	local function bankAt(z: number): number
		return RiverData.centerlineX(z) + side * RiverData.widthAt(z) * 0.5
	end

	local half = size / 2 - R.inset
	local farX = cx + side * half
	local pts: { { number } } = {}
	-- the far inland edge, running along Z
	for z = cz - half, cz + half, R.spacing do
		table.insert(pts, { farX, z })
	end
	-- the two Z edges, running inland from the LOCAL bank, offset by the pack's own reach
	for _, ez in ipairs({ cz - half, cz + half }) do
		local nearX = bankAt(ez) + side * (R.inset + packHalf)
		local span = (farX - nearX) * side
		if span > 0 then
			for t = 0, span, R.spacing do
				table.insert(pts, { nearX + side * t, ez })
			end
		end
	end

	local placed, rejected = 0, 0
	for _, p in ipairs(pts) do
		local x = p[1] + rng:NextNumber(-R.jitter, R.jitter)
		local z = p[2] + rng:NextNumber(-R.jitter, R.jitter)
		local clone = source:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				-- Non-colliding: the ring is scenery you look at, not geometry you walk into. The rock
				-- wall behind it is what actually contains the basin.
				d.CanCollide = false
				d.CastShadow = false
			end
		end
		clone:ScaleTo(rng:NextNumber(R.scale[1], R.scale[2]))
		clone:PivotTo(CFrame.new(x, CLEAR_Y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		FoliageDefs.seatOnGround(clone, groundAt(x, z), 0.4)
		clone.Parent = parent

		-- Belt and braces: even with the two guards above, MEASURE the ground the tile stands on and throw
		-- it away if that is river. The maths can be wrong again; the measurement cannot. The disc is the
		-- pack's CORE, not its full 218-stud spread — its outermost trees are meant to overhang.
		if FoliageDefs.groundClearFraction(x, z, packHalf * 0.45, RiverData.WATER_Y, 2) > FoliageDefs.MAX_OVER_WATER then
			clone:Destroy()
			rejected += 1
		else
			placed += 1
		end
	end
	if rejected > 0 then
		print(("[Excursion] clearing ring: %d canopy tiles placed, %d rejected as over-water"):format(placed, rejected))
	end
end

-- a visible market stall in the village so players can SEE where to trade (Job 023). Fires the shop panel.
--
-- Job #077: was EIGHT hand-assembled blocks — a platform, a counter, four posts and a red fabric awning.
-- It is `BahayKubo7` now: a Filipino stilt house, which is what a river-village trading post actually
-- looks like. ⚠️ 95 instances, by far the heaviest model in the job — ONE per village, never per camp.
local function buildTradingPost(pos: Vector3, parent: Instance, faceTo: Vector3)
	prop(CampDefs.MODEL.post, pos.X, pos.Z, parent, { collide = true, faceTo = faceTo })

	-- The counter survives as an INVISIBLE anchor, so the shop prompt keeps its name, its reach and its
	-- position in front of the building rather than being buried inside 95 parts of geometry.
	local approach = (Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z))
	approach = if approach.Magnitude > 0.01 then approach.Unit else Vector3.new(0, 0, -1)
	local counterPos = pos + approach * 10
	local counter = block("Counter", Vector3.new(6, 4, 2), Theme.color.wood, CFrame.new(counterPos.X, groundAt(counterPos.X, counterPos.Z) + 2, counterPos.Z), parent, Enum.Material.WoodPlanks)
	counter.Transparency = 1
	counter.CanCollide = false
	counter.CanQuery = false

	buildShopSign(pos + approach * 16 + Vector3.new(approach.Z, 0, -approach.X) * 7, pos + approach * 40, parent)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Trading Post"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player: Player)
		openShop:FireClient(player)
	end)
end

-- 🔴 DO NOT BUILD A CAMP ON TERRAIN THAT DOES NOT EXIST YET.
--
-- `RiverBootstrap` STREAMS the river: it keeps `AHEAD_CHUNKS` (~1800 studs) generated ahead of the boat
-- and un-generates the rest. This script builds landing sites up to `CAMP_AHEAD` (1400) ahead, and the
-- `ForceFirstCamp` admin helper builds the first one immediately — which can be ~1900 studs ahead, i.e.
-- **beyond the generated window**.
--
-- When that happened the failure was silent and total: `carve` wrote a basin into empty space, every
-- `groundAt` found nothing and fell back to `CLEAR_Y`, so all 24 camp props were seated at 14.7 — and
-- then the generator reached that stretch and wrote the real hillside (measured 22→48) straight over
-- them. Every structure ended up underground. It read as "the camp is broken"; the camp was fine and
-- the ground arrived afterwards.
--
-- So: probe first, and if the terrain is not there, DON'T mark the site built — the main loop retries
-- every 0.5 s and will build it once the generator has caught up.
local function terrainReadyAt(cx: number, cz: number): boolean
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
	rp.IgnoreWater = true
	-- Sample across the basin, not one point: a single hit can be a stray voxel at the boundary of a
	-- half-generated chunk.
	local hits = 0
	for _, o in ipairs({ Vector2.new(0, 0), Vector2.new(120, 0), Vector2.new(-120, 0), Vector2.new(0, 150), Vector2.new(0, -150) }) do
		if Workspace:Raycast(Vector3.new(cx + o.X, 200, cz + o.Y), Vector3.new(0, -500, 0), rp) then
			hits += 1
		end
	end
	return hits >= 4
end

local function buildLandingSite(dock: RiverData.Dock, index: number)
	if built[index] then
		return
	end
	local halfW = RiverData.widthAt(dock.z) * 0.5
	local waterEdge = RiverData.centerlineX(dock.z) + dock.side * halfW
	local basinCenterX = waterEdge + dock.side * (BASIN_SIZE / 2) -- inner edge AT the water line (walkable shore), not into the channel

	if not terrainReadyAt(basinCenterX, dock.z) then
		return -- river not generated this far yet; retry next tick (see the note above)
	end

	built[index] = true
	carve(basinCenterX, dock.z, BASIN_SIZE)

	-- contain the valley: raise rock walls on the 3 inland sides (water side stays open for the dock)
	-- so the crew can't walk off the carved basin's edge.
	local half = BASIN_SIZE / 2
	local function wallBlock(cx: number, cz: number, sx: number, sz: number)
		Terrain:FillBlock(CFrame.new(cx, 17, cz), Vector3.new(sx, 50, sz), Enum.Material.Rock) -- solid Y[-8..42]
	end
	wallBlock(basinCenterX + dock.side * (half + 15), dock.z, 30, BASIN_SIZE + 60) -- far inland wall
	wallBlock(basinCenterX + dock.side * 15, dock.z + half + 15, BASIN_SIZE + 30, 30) -- +Z wall
	wallBlock(basinCenterX + dock.side * 15, dock.z - half - 15, BASIN_SIZE + 30, 30) -- -Z wall

	local model = Instance.new("Model")
	model.Name = "LandingSite"
	local rng = Random.new(index * 131 + 7)

	-- Job #077 ground pass, BEFORE the path fill below: scattered patches at low weight first, then the
	-- desire line on top at full weight. Reverse the order and the scatter eats holes in the path.
	paintBasin(basinCenterX, dock.z, BASIN_SIZE, waterEdge, dock.side, rng)

	-- camp positions first, so we can keep the walking lane to them clear of trees (Job 053)
	local nearPos = Vector3.new(waterEdge + dock.side * 120, CLEAR_Y, dock.z)
	local deepPos = Vector3.new(waterEdge + dock.side * 300, CLEAR_Y, dock.z + 40)
	-- the path runs from the shore (just past the water line) to the deep camp, passing the near camp
	local pathAx, pathAz = waterEdge + dock.side * 8, dock.z
	local pathBx, pathBz = deepPos.X, deepPos.Z

	-- paint a dirt PATH into the TERRAIN along the lane. Ground material grows no grass blades, so it reads as
	-- a clear walkway through the leafy basin (a thin Part just gets buried by the grass decoration).
	local pathLen = (Vector3.new(pathBx, 0, pathBz) - Vector3.new(pathAx, 0, pathAz)).Magnitude
	local pathMid = Vector3.new((pathAx + pathBx) / 2, CLEAR_Y - 3, (pathAz + pathBz) / 2)
	local pathCF = CFrame.lookAt(pathMid, Vector3.new(pathBx, CLEAR_Y - 3, pathBz))
	Terrain:FillBlock(pathCF, Vector3.new(PATH_HALF * 1.2, 6, pathLen), Enum.Material.Ground)

	-- The canopy that frames the clearing goes in FIRST, around the three inland sides.
	plantClearingRing(basinCenterX, dock.z, BASIN_SIZE, waterEdge, dock.side, model, rng)

	-- ...and the interior gets LIGHT undergrowth only, kept inside the ring zone so palms and bushes
	-- don't fight the canopy for the same ground. Down from 45 scattered edge-to-edge: the middle of a
	-- camp you fight in should be open, and the trees should be the thing enclosing it.
	local interiorReach = BASIN_SIZE / 2 - CampDefs.CLEARING.ringZone
	for _ = 1, CampDefs.CLEARING.interiorCount do
		local rx = basinCenterX + rng:NextNumber(-1, 1) * interiorReach
		local rz = dock.z + rng:NextNumber(-1, 1) * interiorReach
		-- keep trees on land (out of the channel) AND out of the walking lane to the camps
		if (rx - waterEdge) * dock.side > 10 and distToSeg(rx, rz, pathAx, pathAz, pathBx, pathBz) > PATH_HALF then
			tree(rx, rz, model, rng)
		end
	end

	-- tiered, ESCALATING camps: rosters are predefined + non-respawning, and grow at each successive landing
	-- (tier = the landing's ordinal downriver). Deeper camp always has one more guard than the near camp.
	local tier = math.max(1, math.ceil(index / 2))
	-- SOLO tuning (Job 058): fewer guards for a small crew so a lone raider can clear a camp (min 1).
	local scale = 0.55 + (1 - 0.55) * math.clamp((#Players:GetPlayers() - 1) / 5, 0, 1)
	local nearGuards = math.max(1, math.floor(math.min(MAX_GUARDS, tier) * scale))
	local deepGuards = math.max(1, math.floor(math.min(MAX_GUARDS, tier + 1) * scale))
	-- Job #077: the direction the player walks INTO each camp. The near camp is approached from the shore
	-- landing; the deep camp is approached from the near camp — which is the real route, so the deep camp
	-- presents its front to someone who has just fought through the first one.
	local shorePoint = Vector3.new(pathAx, CLEAR_Y, pathAz)
	local nearApproach = (nearPos - shorePoint) * Vector3.new(1, 0, 1)
	nearApproach = if nearApproach.Magnitude > 0.01 then nearApproach.Unit else Vector3.new(dock.side, 0, 0)
	local deepApproach = (deepPos - nearPos) * Vector3.new(1, 0, 1)
	deepApproach = if deepApproach.Magnitude > 0.01 then deepApproach.Unit else nearApproach

	buildCampAt(nearPos, model, nearGuards, { "Gasoline", "Gasoline" }, CampDefs.KIND.near, nearApproach, rng) -- 2 gas → a haul can fund skipping a stop (Job 054)
	buildCampAt(deepPos, model, deepGuards, { "Metal", "Ammo" }, CampDefs.KIND.deep, deepApproach, rng)

	-- village trading post (Job 023): between the shore and the first camp, reached on foot after tying up
	local postPos = Vector3.new(waterEdge + dock.side * 65, CLEAR_Y, dock.z - 24)
	buildTradingPost(postPos, model, shorePoint) -- faces back toward the water, so you see its front on landing

	-- rare gold nuggets (run-capped): a chance at each camp
	trySpawnNugget(CampDefs.slotToWorld(nearPos, nearApproach, CampDefs.LAYOUT.nugget), model, rng)
	trySpawnNugget(CampDefs.slotToWorld(deepPos, deepApproach, CampDefs.LAYOUT.nugget), model, rng)

	-- loadout loot at the deep camp (Job 015): a scarce WEAPON crate + a handheld-ammo crate.
	-- Weapon crates are the top reward — alternate pistol/shotgun by landing; spawn rate is tunable.
	local weaponId = if index % 2 == 0 then "Shotgun" else "Pistol"
	local deepFrom = deepPos - deepApproach * 80
	makeKindCrate(CampDefs.slotToWorld(deepPos, deepApproach, CampDefs.LAYOUT.kindCrates[1]), "Weapon", weaponId, "Take " .. weaponId, model, deepFrom)
	makeKindCrate(CampDefs.slotToWorld(deepPos, deepApproach, CampDefs.LAYOUT.kindCrates[2]), "Ammo", weaponId, weaponId .. " Ammo", model, deepFrom)
	model.Parent = campsRoot
	siteModels[index] = model -- track for culling (Job 060)
end

-- guard AI: chase the nearest on-foot player, leashed to the camp; bite = damage player HP
local function tickGuard(guard: Model, dt: number)
	local def = EnemyDefs.Defs.Panther
	local body = guard.PrimaryPart
	local st = guardState[guard]
	if not body or not st then
		guard:Destroy()
		return
	end
	if ((guard:GetAttribute("HP") :: number?) or 0) <= 0 then
		guardState[guard] = nil
		guard:Destroy()
		return
	end
	st.biteTimer += dt
	local pos = body.Position

	local target: BasePart? = nil
	local bestD = def.aggroRadius
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") then
			local d = (root.Position - pos).Magnitude
			if d <= bestD then
				target, bestD = root, d
			end
		end
	end

	local goal = if target then target.Position else st.anchor
	local dir = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = dir.Magnitude
	if dist > 0.5 then
		dir = dir.Unit
		local stop = if target then def.biteRange * 0.5 else 1
		local step = math.min(def.speed * dt, math.max(dist - stop, 0))
		local np = Vector3.new(pos.X + dir.X * step, CLEAR_Y + def.size.Y / 2, pos.Z + dir.Z * step)
		local off = Vector3.new(np.X - st.anchor.X, 0, np.Z - st.anchor.Z)
		if off.Magnitude > GUARD_LEASH then
			local c = st.anchor + off.Unit * GUARD_LEASH
			np = Vector3.new(c.X, CLEAR_Y + def.size.Y / 2, c.Z)
		end
		guard:PivotTo(CFrame.lookAt(np, np + dir))
	end

	if target and bestD <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		local char = target.Parent
		if char then
			char:SetAttribute("HP", math.max(0, ((char:GetAttribute("HP") :: number?) or 0) - def.biteDamage))
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	for _, guard in CollectionService:GetTagged("CampGuard") do
		if guard:IsA("Model") and guard.Parent then
			tickGuard(guard, dt)
		end
	end
end)

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

-- admin helper (Job 053): force-build the FIRST landing site and return its near-camp spawn position, so an
-- admin can teleport straight to a camp without sailing there. Invoked by AdminServer.
local forceCamp = Instance.new("BindableFunction")
forceCamp.Name = "ForceFirstCamp"
forceCamp.Parent = ServerStorage
forceCamp.OnInvoke = function(): Vector3?
	local first: RiverData.Dock? = nil
	for _, dock in RiverData.docksBetween(RiverData.Z_START, RiverData.Z_START + RiverData.END_DISTANCE) do
		if dock.landing then
			first = dock
			break
		end
	end
	if not first then
		return nil
	end
	buildLandingSite(first, dockIndex(first.z))
	local halfW = RiverData.widthAt(first.z) * 0.5
	local waterEdge = RiverData.centerlineX(first.z) + first.side * halfW
	return Vector3.new(waterEdge + first.side * 120, CLEAR_Y + 3, first.z) -- the near camp
end

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - 200, boatZ + CAMP_AHEAD) do
		if dock.landing then
			buildLandingSite(dock, dockIndex(dock.z))
		end
	end

	-- cull landing sites far behind (frees trees/huts/crates/guards) — never while a player is still ashore
	for idx, model in siteModels do
		local siteZ = RiverData.Z_START + idx * RiverData.DOCK_SPACING
		if boatZ - siteZ > CULL_BEHIND then
			local occupied = false
			for _, plr in ipairs(Players:GetPlayers()) do
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and math.abs(root.Position.Z - siteZ) < BASIN_SIZE then
					occupied = true
					break
				end
			end
			if not occupied then
				for _, d in model:GetDescendants() do
					if d:IsA("Model") and guardState[d] then
						guardState[d] = nil -- drop the guard's AI state so it doesn't leak
					end
				end
				model:Destroy()
				siteModels[idx] = nil
				built[idx] = nil
			end
		end
	end

	task.wait(0.5)
end
