--!strict
-- BoatParts.luau — the boat's part→art mapping (Job 066). Shared data + one assembly helper.
-- IDENTICAL copy in `sync/` and `lobby/sync/` — keep the two byte-identical (they are copied, not
-- hand-edited separately), so the lobby showroom boat and the real boat can never look different.
--
-- WHY THIS EXISTS
-- The boat is built from named parts that gameplay resolves at runtime (Hull, DriverSeat, GunSeat,
-- GunBase, GunBarrel, CargoDeck, the stations…). Their APPEARANCE must be swappable without touching any
-- of that logic — the user wants to drop in a better motor model later, and the gun upgrade REPLACES the
-- base barrel's model. So "which mesh is this part" lives here as data. Changing art = editing one id in
-- one file; no gameplay code, no physics retune, no re-test of boat feel.
--
-- THE GOLDEN RULE: ART NEVER TOUCHES PHYSICS.
-- `Hull` is the boat's PrimaryPart. It carries the tuned CustomPhysicalProperties that make the boat
-- FLOAT and hosts the `Root` attachment every thrust/turn force acts through (see BoatServer). So a mesh
-- is NEVER the physics part. Each visual mesh is welded on as a separate child that is
-- `CanCollide = false` + `Massless = true` — a skin. Mass, centre of mass, buoyancy and collision stay
-- exactly as tuned. The one exception is `collision = "deck"`, for surfaces players must stand on.
--
-- ART SOURCE — the AssetLibrary convention (same as the lobby foliage)
-- The human imports each mesh ONCE into `ServerStorage/AssetLibrary/BoatParts/` as a MeshPart, named
-- exactly as the `library` field below. We CLONE from there. That avoids setting MeshId at runtime and
-- keeps a single reviewable place where the art lives. Record the ids in the shared registry
-- (`Assets/registry/meshes.md`) as usual.
--
-- UNTIL THE ART EXISTS: every `library` is nil, `skin()` does nothing, and the boat stays exactly the
-- greybox it is today. That is deliberate — the harness lands and is proven before any art arrives.

local ServerStorage = game:GetService("ServerStorage")

local BoatParts = {}

BoatParts.LIBRARY_PATH = { "AssetLibrary", "BoatParts" } -- under ServerStorage

export type Collision = "skin" | "deck"

export type PartDef = {
	-- Child name under ServerStorage/AssetLibrary/BoatParts. nil = no art yet → keep the greybox.
	library: string?,
	-- Gun only: the model shown INSTEAD of `library` once the upgrade is owned (a swap, not an addition).
	upgradeLibrary: string?,
	-- Where the skin sits relative to its host part.
	offset: CFrame?,
	-- Uniform scale applied to the cloned mesh.
	scale: number?,
	-- "skin" (default) = CanCollide false + Massless true, physics untouched.
	-- "deck"           = real collision, for surfaces players stand on.
	collision: Collision?,
}

-- Offsets here are relative to the HOST part, not the boat. A module part is already positioned by
-- BoatModules, so its skin usually needs no offset — the boat-space coordinates in the comments are for
-- the concept-sheet brief and for anyone reading this cold.
BoatParts.Defs = {
	-- ── base boat ────────────────────────────────────────────────────────────────────────────────
	-- Hull is 14 wide × 3 tall × 22 long (BoatServer HULL_SIZE). The hero piece.
	hull = { library = nil, collision = "skin" } :: PartDef,
	-- The walkable deck — the ONE part that keeps real collision.
	cargoDeck = { library = nil, collision = "deck" } :: PartDef,
	-- Base motor (Job 066 decision #1): every boat has one. `motor2` is its twin, added by the upgrade.
	motor = { library = nil, collision = "skin" } :: PartDef,
	driverSeat = { library = nil, collision = "skin" } :: PartDef, -- seat + console + steering wheel
	gunBase = { library = nil, collision = "skin" } :: PartDef,
	-- decision #2: the upgrade REPLACES this barrel's model rather than adding a second one
	gunBarrel = { library = nil, upgradeLibrary = nil, collision = "skin" } :: PartDef,
	gunSeat = { library = nil, collision = "skin" } :: PartDef,
	bowLight = { library = nil, collision = "skin" } :: PartDef,

	-- ── upgrade modules (ModuleDefs — 6, bought once, no tiers) ──────────────────────────────────
	motor2 = { library = nil, collision = "skin" } :: PartDef, -- boat space (−3.5, 1, 10.5)
	hullPlate = { library = nil, collision = "skin" } :: PartDef, -- both flanks, ±7.3
	fuelTank = { library = nil, collision = "skin" } :: PartDef, -- (4.5, 2.5, 8)
	searchlightMast = { library = nil, collision = "skin" } :: PartDef, -- (0, 5, −7)
	searchlightHead = { library = nil, collision = "skin" } :: PartDef, -- (0, 8, −7.6)
	trailer = { library = nil, collision = "skin" } :: PartDef, -- (0, −0.4, 15.5)

	-- ── role stations (currently coloured boxes; nicer props optional) ───────────────────────────
	fuelStation = { library = nil, collision = "skin" } :: PartDef,
	repairStation = { library = nil, collision = "skin" } :: PartDef,
	medicStation = { library = nil, collision = "skin" } :: PartDef,
} :: { [string]: PartDef }

-- Module id (ModuleDefs) → the BoatParts key its art lives under.
BoatParts.moduleToPart = {
	motor2 = "motor2",
	hullkit = "hullPlate",
	fueltank = "fuelTank",
	searchlight = "searchlightMast",
	trailer = "trailer",
	gunupgrade = "gunBarrel", -- handled as a swap on the existing barrel
} :: { [string]: string }

local function library(): Instance?
	local node: Instance = ServerStorage
	for _, name in ipairs(BoatParts.LIBRARY_PATH) do
		local child = node:FindFirstChild(name)
		if not child then
			return nil
		end
		node = child
	end
	return node
end

-- Is there any art at all yet? Lets callers keep the greybox visible when there isn't.
function BoatParts.hasArt(id: string, useUpgrade: boolean?): boolean
	local def = BoatParts.Defs[id]
	if not def then
		return false
	end
	local name = (useUpgrade and def.upgradeLibrary) or def.library
	if not name then
		return false
	end
	local lib = library()
	return lib ~= nil and lib:FindFirstChild(name) ~= nil
end

-- Attach the art for `id` onto `host` as a welded skin, and return it.
-- Returns nil when there is no art yet — the caller then leaves its greybox part visible.
--
-- The host keeps ALL of its physics. The skin is Massless + non-colliding unless the def says "deck".
function BoatParts.skin(host: BasePart, id: string, useUpgrade: boolean?): BasePart?
	local def = BoatParts.Defs[id]
	if not def then
		warn(`[BoatParts] unknown part id "{id}"`)
		return nil
	end

	local name = (useUpgrade and def.upgradeLibrary) or def.library
	if not name then
		return nil -- no art yet: greybox stays
	end

	local lib = library()
	local source = lib and lib:FindFirstChild(name)
	if not source or not source:IsA("BasePart") then
		warn(`[BoatParts] "{name}" missing from ServerStorage.AssetLibrary.BoatParts (or is not a BasePart)`)
		return nil
	end

	-- one skin per host+id; rebuilding replaces rather than stacking
	local existing = host:FindFirstChild("Skin_" .. id)
	if existing then
		existing:Destroy()
	end

	local skin = source:Clone() :: BasePart
	skin.Name = "Skin_" .. id
	skin.Anchored = false
	skin.CanCollide = def.collision == "deck"
	skin.Massless = def.collision ~= "deck" -- a decorative skin must not change the boat's mass
	skin.CanQuery = def.collision == "deck"
	skin.CanTouch = false
	if skin:IsA("MeshPart") then
		-- CollisionFidelity only exists on MeshPart. Imported meshes default to Box, which would seal the
		-- boat shut — so the walkable deck gets precise collision, and skins get the cheapest possible.
		skin.CollisionFidelity = if def.collision == "deck"
			then Enum.CollisionFidelity.PreciseConvexDecomposition
			else Enum.CollisionFidelity.Box
		if def.scale and def.scale ~= 1 then
			skin.Size = skin.Size * def.scale
		end
	end

	skin.CFrame = host.CFrame * (def.offset or CFrame.new())
	skin.Parent = host

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = skin
	weld.Parent = skin

	-- the host becomes the invisible physics body once its art is on
	host.Transparency = 1

	return skin
end

return BoatParts
