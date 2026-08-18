--!strict
-- LootGlow.local.luau — make a real lootable readable from across the camp (Job #101).
--
-- ⚠️ THE PROBLEM THIS SOLVES IS NOT "loot is hard to see". It is that loot is INDISTINGUISHABLE.
--
-- `buildCampAt` places resource #1 as a `CrateWood` and every one after it as a `Barrel` — and the camp
-- is *also* dressed with loose barrels and crates. Measured at landing 1: 7 barrels, 4 of them in the
-- near camp, exactly ONE of which is the gasoline. Same model, same texture, same size. The only thing
-- that ever distinguished them was a `ProximityPrompt` with a 10-stud range, in a camp ~150 studs across.
--
-- Reported as *"i could not found 2 gasoline only one … we also have props that looks like lootable and
-- you cant understand what is what"*. Both crates were in fact spawning, 99 studs apart. It was a search
-- failure, and because the near camp is the run's ONLY gasoline source, a missed crate strands the run.
--
-- ⚠️ NOT a re-tint. `STYLEGUIDE §12` forbids the neon-prop look, and `ExcursionServer`'s own Job #077
-- note says so explicitly: *"the fix is a small painted stencil or a resource icon on the crate — NOT
-- re-tinting the whole barrel"*. A `Highlight` leaves the model's material and colour untouched.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TAG = "Lootable"

-- ⚠️ 60, NOT 40, AND THE NUMBER WAS MEASURED RATHER THAN CHOSEN.
--
-- 40 was the first guess and it failed. Walking the route a player actually takes — shore → near fire →
-- deep fire — and asking how far each lootable sits off that line:
--
--     Metal      3 studs      Ammo      21      Gasoline  39      <- lit at 40
--     Weapon    50 studs      Gasoline  52      Ammo      68      <- NEVER lit at 40
--
-- Three of six, including a gasoline. The near camp is the run's only fuel source, so that is not a
-- smaller haul, it is a stranded run — which is exactly what was reported, twice, with both crates
-- provably in the world. 60 lights five of the six; the sixth is a cargo Ammo, which costs a haul and
-- not the run.
--
-- ⚠️ It is deliberately NOT set high enough to light the whole camp from the entrance. The fence radius
-- is 70–76, so 60 measured from a moving player lights what you walk past, not what you can see. Job
-- #100 made camps big so they would take searching; this makes the search fair, not unnecessary.
local RANGE = 60 -- studs: full strength inside this
local FADE = 18 -- ...fading out over the last this-many, so nothing pops in
-- Inside this, the outline draws THROUGH walls. Beyond it, geometry occludes it.
--
-- This is the whole design in one number. Job #100 puts loot behind cover on purpose ("cover between the
-- player and the crates is what makes the guards matter"), so an always-on-top outline would delete the
-- search the camps were just rebuilt to have. But the specific thing that stranded the run was a crate
-- tucked behind a hut the player was standing next to — so once you are close enough to be searching
-- *this* corner, the wall stops hiding it. Far away you must still walk the camp and look.
local XRAY = 18

local GOLD = Color3.fromRGB(214, 155, 34) -- STYLEGUIDE §4 accent: gold means progression
local FILL_MIN = 0.82 -- barely-there interior wash; the outline does the work

-- A hard ceiling on rendered Highlights. Roblox degrades past roughly 31 of them, and while a landing
-- only holds ~6 lootables, nothing here should be the thing that discovers otherwise.
local MAX_GLOWS = 16

local player = Players.LocalPlayer
local glows: { [Instance]: Highlight } = {}

local function highlightFor(target: Instance): Highlight?
	local existing = glows[target]
	if existing then
		return existing
	end
	if not target:IsDescendantOf(workspace) then
		return nil
	end
	local h = Instance.new("Highlight")
	h.Name = "LootGlow"
	h.FillColor = GOLD
	h.OutlineColor = GOLD
	h.Adornee = target
	-- Parented to the target, so it dies with the crate when the crate is looted or the site is culled.
	h.Parent = target
	glows[target] = h
	return h
end

local function drop(target: Instance)
	local h = glows[target]
	if h then
		h:Destroy()
		glows[target] = nil
	end
end

local function pivotOf(inst: Instance): Vector3?
	if inst:IsA("PVInstance") then
		return inst:GetPivot().Position
	end
	return nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	-- 10 Hz. This walks every lootable at a landing and does distance maths; at 60 Hz that is six times
	-- the work for a fade nobody can see move.
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		for target in glows do
			drop(target)
		end
		return
	end
	local from = root.Position

	-- Nearest-first, so the cap sheds the far ones rather than whichever the tag list happened to yield.
	local near: { { inst: Instance, d: number } } = {}
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		local p = pivotOf(inst)
		if p and inst:IsDescendantOf(workspace) then
			local d = (p - from).Magnitude
			if d <= RANGE then
				table.insert(near, { inst = inst, d = d })
			else
				drop(inst)
			end
		else
			drop(inst)
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)

	local shown: { [Instance]: true } = {}
	for i, entry in ipairs(near) do
		if i > MAX_GLOWS then
			drop(entry.inst)
			continue
		end
		local h = highlightFor(entry.inst)
		if h then
			shown[entry.inst] = true
			-- 0 at the edge of RANGE, 1 once inside RANGE-FADE
			local strength = math.clamp((RANGE - entry.d) / FADE, 0, 1)
			h.OutlineTransparency = 1 - strength
			h.FillTransparency = 1 - (1 - FILL_MIN) * strength
			h.DepthMode = if entry.d <= XRAY
				then Enum.HighlightDepthMode.AlwaysOnTop
				else Enum.HighlightDepthMode.Occluded
		end
	end
	for target in glows do
		if not shown[target] then
			drop(target)
		end
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(drop)
