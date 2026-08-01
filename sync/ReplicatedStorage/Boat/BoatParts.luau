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
	-- Where the skin sits relative to its host part. ALSO carries rotation — Meshy exports don't know
	-- which way our boat faces, and several parts import with their long axis on X while the boat's
	-- length runs along Z (bow = −Z). A yaw here fixes that without re-exporting anything.
	offset: CFrame?,
	-- Exact size for the skin, in the MESH's own local axes (i.e. before `offset` rotates it). Use this
	-- when a part must match a known footprint — it's how the hull skin is made to agree with the
	-- physics box instead of whatever scale Meshy happened to export.
	size: Vector3?,
	-- Size used when the UPGRADE model is shown instead (gun only). Without this the heavy barrel would be
	-- forced into the base barrel's dimensions and wouldn't read as an upgrade.
	upgradeSize: Vector3?,
	-- Uniform scale, applied only when `size` is not given.
	scale: number?,
	-- "skin" (default) = CanCollide false + Massless true, physics untouched.
	-- "deck"           = real collision, for surfaces players stand on.
	collision: Collision?,
	-- Job 067: does the Boat Paint Pack repaint this part? Only the HULL and its armour plates — the deck
	-- planking, engines, seats and stations keep their own materials, because a boat whose wooden deck
	-- turns navy blue reads as a bug rather than a livery. See BoatPaint.
	paintable: boolean?,
}

-- Offsets here are relative to the HOST part, not the boat. A module part is already positioned by
-- BoatModules, so its skin usually needs no offset — the boat-space coordinates in the comments are for
-- the concept-sheet brief and for anyone reading this cold.
BoatParts.Defs = {
	-- ── base boat ────────────────────────────────────────────────────────────────────────────────
	-- Hull is 14 wide × 3 tall × 22 long (BoatServer HULL_SIZE). The hero piece.
	--
	-- The Meshy export measured 35.06 × 6.60 × 15.33 studs with its LENGTH ON X, so it needs a 90° yaw to
	-- line up with a boat whose length runs along Z (bow = −Z). Its natural proportions are 2.29 : 1
	-- (length : width) where the physics box is 1.57 : 1, so a uniform scale to 22 long would leave the
	-- visible hull only ~9.6 wide inside a 14-wide collision box — you'd stand on water beside it.
	-- `size` therefore stretches it to the box footprint: 22 long, 14 wide, ~4.1 tall (its own height
	-- ratio at that length), which keeps visual and collision honest at the cost of a beamier boat.
	-- Hull skin, at the mesh's TRUE proportions. The import measured 35.06 × 6.60 × 15.33 studs, i.e.
	-- 2.29:1 length:width, with its length on X — so it needs a 90° yaw to match a boat whose length runs
	-- along Z. At 32 × 14 the stretch is ZERO (the earlier 22-long hull forced it 46% wider than modelled,
	-- which is what made it look squat and sunk); height follows at 6.02.
	--
	-- The skin is TALLER than the physics box (6.02 vs 3) because the mesh has gunwales the box doesn't
	-- model. Centring the two would hang the keel 1.5 below the box and the boat would ride swamped, so it
	-- is lifted by half the difference: the mesh's KEEL sits on the box's bottom face and all the extra
	-- height becomes freeboard.
	hull = {
		library = "Hull",
		size = Vector3.new(32, 6.02, 14), -- local axes: X = mesh length, Z = mesh width
		offset = CFrame.new(0, (6.02 - 3) / 2, 0) * CFrame.Angles(0, math.rad(90), 0),
		collision = "skin",
		paintable = true, -- the hero surface the Paint Pack sells
	} :: PartDef,
	-- The walkable deck — the ONE part that keeps real collision.
	-- Mesh imported 8.80 × 1.20 × 4.63 with its length already on X, same as the host (14 × 1 × 8), so no
	-- rotation is needed. Its natural ratio (1.90:1) is close to the host's (1.75:1), so stretching to the
	-- host footprint barely distorts it. Lifted 0.1 so the skin's top face lines up with the greybox top —
	-- this is the surface players actually stand on.
	cargoDeck = {
		library = "CargoDeck",
		size = Vector3.new(14, 1.2, 8),
		offset = CFrame.new(0, 0.1, 0),
		collision = "deck",
	} :: PartDef,
	-- Base motor (Job 066 decision #1): every boat has one. `motor2` is its twin, added by the upgrade.
	-- Outboard motor, imported upright (longest axis Y) so it needs no rotation. Its host sits at the
	-- transom with the leg reaching toward the water, which is what an outboard does.
	motor = {
		library = "Motor",
		-- 3x the first pass (2.5 × 2.6 × 1.1): it read as a toy on a 32-stud boat. Mounted on the transom
		-- with the powerhead above the gunwale and the leg reaching into the water, like a real outboard —
		-- which is why the rear cargo deck was pushed aft to make an engine bay (CargoServer DECK_GAP).
		size = Vector3.new(7.5, 7.8, 3.3),
		-- Yaw -90: the mesh's propeller points along +X as imported, i.e. out to starboard. Rotating +X
		-- onto +Z aims it AFT, which is where a propeller pushes from.
		offset = CFrame.Angles(0, math.rad(-90), 0),
		collision = "skin",
	} :: PartDef,
	-- Seat + console + steering wheel. Mesh imported 1.36 × 1.00 × 0.88 with its longest axis (X) running
	-- seat→console, i.e. fore-aft — so it needs the same 90° yaw as the hull to line up with a boat whose
	-- length is on Z. Scaled to ~3.5 studs tall, which reads correctly next to a 5-stud character.
	--
	-- The host is only a 1-tall seat pad (it stays a VehicleSeat — driving depends on that), so centring
	-- would bury the console in the deck. Lifted so the mesh's BASE sits on the pad's top face.
	-- Scaled up ~15% from the first pass (4.75 × 3.5 × 3.08) — it read slightly small for a driving
	-- position next to a 5-stud character. The lift keeps the base exactly on the deck: host pad centre is
	-- at hull-space Y 2, deck top at 1.5, so a 4.0-tall seat needs its centre at 3.5, i.e. +1.5.
	driverSeat = {
		library = "DriverSeat",
		size = Vector3.new(5.5, 4.0, 3.55), -- local X = fore-aft, becomes boat Z after the yaw
		offset = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		collision = "skin",
	} :: PartDef,
	-- Pintle mount. Mesh imported 1.59 × 1.20 × 1.45 — near-cubic like its 3 × 2 × 3 host and already
	-- axis-aligned, so no rotation. Sized to the host's footprint at the mesh's own height ratio.
	gunBase = {
		library = "GunBase",
		size = Vector3.new(3.45, 2.60, 3.15),
		collision = "skin",
	} :: PartDef,
	-- Barrel. Mesh imported 2.10 × 1.20 × 0.81 with its length on X, so it takes the usual 90° yaw to point
	-- down the boat's Z. `upgradeLibrary` is decision #2: the gunupgrade SWAPS this model rather than
	-- bolting on a second barrel.
	-- SIZED TO THE MESH, NOT THE HOST. The host barrel is 8 studs long (GunServer) purely as an aim pivot;
	-- filling that length stretched the 2.1-long mesh ~3.8× and it read as a thin rod skewering the bow.
	-- The skin is now ~4 long at near-natural proportions, so it looks like a mounted MG. The host stays
	-- 8 — it is invisible and its length only affects the aim maths, not the silhouette.
	gunBarrel = {
		library = "GunBarrel",
		upgradeLibrary = "GunBarrelHeavy",
		upgradeSize = Vector3.new(5.52, 2.42, 2.30), -- visibly heavier than the base barrel
		size = Vector3.new(4.6, 2.3, 1.61),
		offset = CFrame.Angles(0, math.rad(90), 0),
		collision = "skin",
	} :: PartDef,
	-- Gunner's seat. Longest axis X runs front-to-back like the driver's, so it takes the same 90° yaw.
	-- The gunner sits in the OPEN WELL aft of the raised foredeck, so the host now follows the deck
	-- (topY + 0.5) and the skin lifts just 0.5 to put a 2-tall seat base flat on it. It previously used the
	-- gun mount height and floated 3 studs above the floor.
	gunSeat = {
		library = "GunSeat",
		-- Bigger again (was 2.53 × 2.30 × 1.96) — it read tiny beside a 5-stud character and the 4-tall
		-- driver's seat next to it.
		--
		-- NO YAW, unlike the driver's seat. That mesh is strongly elongated (1.00/0.74/0.65) with its long
		-- axis running seat→console, so it needs rotating to lie fore-aft. This one is near-cubic
		-- (1.00/0.89/0.76): its long axis is the seat's WIDTH, so rotating it turned the gunner sideways.
		-- Left unrotated, X = across the boat and Z = fore-aft, and the gunner faces the bow — and the gun.
		--
		-- Lift 0.45 puts the seat's base on the foredeck (~3.5, derived from where the gun mount sits)
		-- instead of hovering above it.
		size = Vector3.new(3.6, 3.2, 2.6),
		offset = CFrame.new(0, 0.45, 0),
		collision = "skin",
	} :: PartDef,
	-- Crew seats for the "helpers/fighters" — the rest of the party (GAME.md roles). Same mesh as the
	-- gunner's seat, but its own def because the well floor (1.5) is 2 studs below the raised foredeck the
	-- gunner sits on, so the lift differs. Host sits at y 2, so +1.1 puts a 3.2-tall seat base on the deck.
	crewSeat = {
		library = "GunSeat",
		size = Vector3.new(3.6, 3.2, 2.6),
		offset = CFrame.new(0, 1.1, 0),
		collision = "skin",
	} :: PartDef,
	-- Lamp imported 0.85 × 1.20 × 0.81 — already upright (long axis Y) and already about the size of its
	-- 1.2-cube host, so it needs neither scaling nor rotation. Left at natural size deliberately; if the
	-- lens ends up facing the wrong way, add a yaw here rather than re-exporting.
	-- Scaled up from its natural 0.85 × 1.20 × 0.81: at that size it was under a stud tall on a 32-stud
	-- boat and simply read as a speck. No rotation — it imported upright.
	bowLight = { library = "BowLight", size = Vector3.new(1.96, 2.76, 1.84), collision = "skin" } :: PartDef,

	-- ── upgrade modules (ModuleDefs — 6, bought once, no tiers) ──────────────────────────────────
	motor2 = { library = nil, collision = "skin" } :: PartDef, -- boat space (−3.5, 1, 10.5)
	-- Armour plate on the flanks. Mesh imported 2.76 × 1.20 × 0.28 with its length on X, so it takes a 90°
	-- yaw to run fore-aft.
	--
	-- TILED, NOT STRETCHED. The first attempt scaled ONE plate to the full 30-stud hull length. That was
	-- wrong twice over: it smeared the bolt detail ~11×, and — worse — a straight strip at constant beam
	-- doesn't fit a hull that TAPERS, so the ends jutted out into open air like oars. Now several short
	-- plates at their modelled proportions are placed along the parallel midbody only, where the hull
	-- sides really are straight. See PLATE_SEGMENTS in BoatModules / LobbyBoat.
	hullPlate = {
		library = "HullPlate",
		size = Vector3.new(4.6, 2, 0.47), -- natural proportions at 2 studs tall — no stretch
		offset = CFrame.Angles(0, math.rad(90), 0),
		collision = "skin",
		paintable = true, -- plates are bolted to the hull; they must repaint with it, not stay olive
	} :: PartDef,
	-- Fuel drum, lying with its length on X — no rotation needed, it reads fine either way on the deck.
	fuelTank = {
		library = "FuelTank",
		size = Vector3.new(2.5, 1.5, 1.5), -- natural proportions
		collision = "skin",
	} :: PartDef,
	-- Job 067: art generated. ⚠️ `size` is deliberately UNSET until the import is MEASURED — the concept
	-- render came out ~3:1 tall:wide (a stocky riveted pedestal, kept deliberately: a 0.8-stud pole is the
	-- geometry Meshy reconstructs worst). Sizing it to the old 0.8 × 6 host would stretch it 2.5× and smear
	-- every rivet, which is exactly the mistake the hull plates taught us. Size to the MESH, then move the
	-- boat around it. Expect roughly 1.7 × 5.5 × 1.7.
	searchlightMast = { library = "SearchlightMast", collision = "skin" } :: PartDef,
	-- Searchlight lamp. ⚠️ The imported asset is spelled "SearchLightHead" (capital L) — this string must
	-- match the library child exactly, so it is deliberately NOT normalised to our camelCase key.
	searchlightHead = {
		library = "SearchLightHead",
		size = Vector3.new(2.2, 2.4, 1.94),
		collision = "skin",
	} :: PartDef,
	-- Cargo Racks. Job 067: art generated (lashed crates in an olive angle-iron rack with a back rail).
	-- ⚠️ `size` UNSET pending measurement — the render is ~2.5 : 1 : 1.8, chunkier than the 4.3 : 1 : 2.7
	-- the rear deck was laid out for, so at natural proportions it will be TALLER and DEEPER than the old
	-- 9 × 3 × 6 slab. The three role stations share that deck and will need moving forward around it.
	-- Until the mesh is imported, `cargoRackPieces` below builds the greybox stand-in.
	trailer = { library = "CargoRacks", collision = "skin" } :: PartDef,
	-- Bow ramp / hull-shape kit (the `ramps` module). Job 067: art generated.
	-- ⚠️ `size` UNSET pending measurement — the render's footprint is near-square where the bow has room
	-- for ~2.6:1, and the gun mount sits at z −11, so the depth decides whether it clears the gun or the
	-- hull tip. Measure, then place. Paintable: it's a hull surface, so it repaints with the hull.
	ramp = { library = "RampBow", collision = "skin", paintable = true } :: PartDef,

	-- ── role stations (currently coloured boxes; nicer props optional) ───────────────────────────
	-- Fuel post. Imported 0.72 × 1.20 × 0.72 — a slim upright, already the right way up, so NO rotation.
	-- Host is a 3-cube whose base sits on the rear deck (1.5); a 3-tall skin centres on it exactly.
	fuelStation = {
		library = "FuelStation",
		size = Vector3.new(2.25, 3.75, 2.25), -- +25%
		-- Derived from the deck: base = deck top (1.70, measured off the deck skin) — then dropped 0.3,
		-- because the mesh's geometry sits a little above its own bounding-box floor, so a box-flush base
		-- still reads as hovering. 0.3 is the whole correction; an earlier attempt at ~1.2 came from a stale
		-- Play session and buried them.
		offset = CFrame.new(0, 0.275, 0), -- deck-top derivation minus 0.3: the mesh sits slightly high in its box
		collision = "skin",
	} :: PartDef,
	-- Repair toolbox. Imported 1.20 × 1.20 × 0.76 — a square-fronted cabinet, upright, no rotation.
	-- Slightly shorter than its 3-cube host, so nudged down to keep its base on the deck.
	repairStation = {
		library = "RepairStation",
		size = Vector3.new(3.5, 3.5, 2.25), -- +25%
		offset = CFrame.new(0, 0.15, 0), -- deck-top derivation minus 0.3: the mesh sits slightly high in its box
		collision = "skin",
	} :: PartDef,
	-- Medic crate (GAME place only — CargoServer builds this one). Imported 1.80 × 1.20 × 1.37, a crate
	-- lying with its length on X. Left unrotated: a crate has no meaningful "front", and after the gunner
	-- seat I don't add a yaw unless the mesh's shape actually calls for one.
	medicStation = {
		library = "MedicStation",
		size = Vector3.new(2.75, 1.84, 2.09), -- natural proportions, +25% to match the other stations
		collision = "skin",
	} :: PartDef,
} :: { [string]: PartDef }

-- ── Cargo Racks greybox (Job 067) ────────────────────────────────────────────────────────────────
-- The `trailer` module still has NO mesh, and it used to be built as ONE 9 × 3 × 6 slab dropped on the
-- rear deck. It read exactly like what it was — a featureless brown box ("why big box at the back?"). A
-- 180-Gold upgrade has to look like something.
--
-- So until art exists it is built from these pieces, which read as **racks + crates** at a glance. Shared
-- by BoatModules (game) and LobbyBoat (lobby) so the showroom can never disagree with the real boat.
--
-- Layout, in HULL SPACE (bow = −Z), derived from the hull rather than hardcoded (Job 066's lesson):
--   · rear deck is centred at z = halfZ + 7 and spans 8 studs deep, 14 wide
--   · the four crates sit in the deck CORNERS, so they clear the role stations at (±4, 3, deck centre) —
--     the stations occupy the middle 3 studs of z, the crates sit outside it
--   · one stacked crate + an open frame across the transom give it a silhouette from a distance
export type RackPiece = { name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material }

local WOOD = Color3.fromRGB(122, 92, 58)
local WOOD_DARK = Color3.fromRGB(96, 72, 46)
local RACK_METAL = Color3.fromRGB(88, 90, 98)

function BoatParts.cargoRackPieces(halfZ: number): { RackPiece }
	local backZ = halfZ + 7 -- rear deck centre, same derivation both builders use
	local deckTop = 1.7 -- measured off the deck SKIN, not the greybox host (the skin sits 0.2 proud)
	local fore, aft = backZ - 2.6, backZ + 2.6 -- corner rows, clear of the stations in the middle
	local crate = Vector3.new(2.2, 2.0, 2.2)
	local crateY = deckTop + crate.Y / 2
	local pieces: { RackPiece } = {}
	local function add(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, mat: Enum.Material)
		table.insert(pieces, { name = name, size = size, offset = CFrame.new(x, y, z), color = color, material = mat })
	end
	local n = 0
	for _, z in ipairs({ fore, aft }) do
		for _, x in ipairs({ -5.4, 5.4 }) do
			n += 1
			add("CargoCrate" .. n, crate, x, crateY, z, n % 2 == 0 and WOOD or WOOD_DARK, Enum.Material.WoodPlanks)
		end
	end
	-- one crate stacked on the port-aft corner: breaks the flat top line so the module reads from the dock
	add("CargoCrate5", Vector3.new(1.8, 1.8, 1.8), -5.4, crateY + crate.Y / 2 + 0.9, aft, WOOD, Enum.Material.WoodPlanks)
	-- open frame across the transom — the "rack" half of "deck racks and crates"
	-- named fields, not a {string, number} tuple — Luau strict mode can't index a mixed-type array
	local posts: { { name: string, x: number } } = { { name = "L", x = -6.4 }, { name = "R", x = 6.4 } }
	for _, side in ipairs(posts) do
		add("CargoRackPost" .. side.name, Vector3.new(0.3, 3.2, 0.3), side.x, deckTop + 1.6, backZ + 3.7, RACK_METAL, Enum.Material.Metal)
	end
	add("CargoRackRail", Vector3.new(13.1, 0.3, 0.3), 0, deckTop + 3.0, backZ + 3.7, RACK_METAL, Enum.Material.Metal)
	return pieces
end

-- Module id (ModuleDefs) → the BoatParts key its art lives under.
BoatParts.moduleToPart = {
	motor2 = "motor2",
	hullkit = "hullPlate",
	fueltank = "fuelTank",
	searchlight = "searchlightMast",
	trailer = "trailer",
	gunupgrade = "gunBarrel", -- handled as a swap on the existing barrel
	ramps = "ramp",
} :: { [string]: string }

-- Job 067: the set of skin names the Boat Paint Pack may repaint, keyed by the `Skin_<id>` name that
-- `BoatParts.skin` assigns below. Handing BoatPaint a NAME SET rather than the defs keeps BoatPaint free of
-- any ServerStorage dependency, so the lobby's paint picker can require it on the CLIENT to read swatch
-- colours without dragging the art library along.
function BoatParts.paintableSkinNames(): { [string]: boolean }
	local names: { [string]: boolean } = {}
	for id, def in pairs(BoatParts.Defs) do
		if def.paintable then
			names["Skin_" .. id] = true
		end
	end
	return names
end

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
		-- NOTE: CollisionFidelity is NOT set here. A runtime script cannot write it — Roblox gates it
		-- behind plugin capability ("The current thread cannot write 'CollisionFidelity'"), and the
		-- attempt throws, taking the whole boat build down with it. It is an AUTHORING-TIME property:
		-- set it once on each library MeshPart via BoatParts.applyLibraryFidelity() below, run from
		-- Studio (Edit mode), and it saves with the place.
		local wantSize = (useUpgrade and def.upgradeSize) or def.size
		if wantSize then
			skin.Size = wantSize -- exact footprint wins over whatever Meshy exported
		elseif def.scale and def.scale ~= 1 then
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

-- ── authoring-time helper ────────────────────────────────────────────────────────────────────────
-- ⚠️ LIMITED USE. CollisionFidelity turned out to be unwritable from a game script AND silently ignored
-- from the Studio command bar / MCP Edit context (the assignment "succeeds" and the value does not
-- change). In practice it can only be set in the **Properties panel** or in the 3D Importer.
--
-- That is fine, because it does not actually matter here: every mesh is a SKIN over a greybox host, and
-- the HOST carries the collision (a clean box, which is also the cheapest and most stable option for a
-- deck people walk on). A skin's own fidelity is irrelevant while it is non-colliding, and for the flat
-- deck plate a box is the right shape anyway.
--
-- ⚙️ RUN ONCE FROM STUDIO (Edit mode / command bar), THEN SAVE THE PLACE.
--
--     local BP = require(game.ReplicatedStorage.Boat.BoatParts) print(BP.preparePaintLibrary())
--
-- Gives every PAINTABLE library mesh a second SurfaceAppearance named `PaintablePBR` — a copy of the stock
-- one with an EMPTY ColorMap, so `BasePart.Color` becomes the albedo while the normal / roughness /
-- metalness maps keep all the weathering detail.
--
-- WHY IT HAS TO BE AN AUTHORING STEP: a game script cannot write `SurfaceAppearance.ColorMap` at all —
-- "lacking capability Plugin", the same gate as MeshId and CollisionFidelity above. Unlike CollisionFidelity
-- (which is silently ignored outside the Properties panel), this one DOES work from the command bar, so a
-- one-shot prepare here is a real fix rather than a workaround that quietly does nothing.
--
-- At runtime BoatPaint then only DESTROYS whichever appearance it doesn't want, which needs no capability.
-- Safe to re-run: the old `PaintablePBR` is replaced, not stacked.
function BoatParts.preparePaintLibrary(): string
	local lib = library()
	if not lib then
		return "no ServerStorage.AssetLibrary.BoatParts folder found"
	end
	local BoatPaint = require(script.Parent:WaitForChild("BoatPaint"))
	local lines = {}
	for id, def in pairs(BoatParts.Defs) do
		local name = def.library
		local part = if def.paintable and name then lib:FindFirstChild(name) else nil
		if name and part and part:IsA("BasePart") then
			local existing = part:FindFirstChild(BoatPaint.PAINT_SA_NAME)
			if existing then
				existing:Destroy()
			end
			local stock = part:FindFirstChildOfClass("SurfaceAppearance")
			if not stock then
				table.insert(lines, string.format("%-16s %-22s SKIPPED (no SurfaceAppearance to copy)", id, name))
				continue
			end
			local copy = stock:Clone()
			copy.Name = BoatPaint.PAINT_SA_NAME
			local ok, err = pcall(function()
				copy.ColorMap = ""
			end)
			if not ok then
				copy:Destroy()
				table.insert(lines, string.format("%-16s %-22s FAILED: %s", id, name, tostring(err)))
				continue
			end
			copy.Parent = part
			table.insert(lines, string.format("%-16s %-22s ok (normal=%s rough=%s metal=%s kept)", id, name,
				copy.NormalMap ~= "" and "Y" or "-",
				copy.RoughnessMap ~= "" and "Y" or "-",
				copy.MetalnessMap ~= "" and "Y" or "-"))
		end
	end
	if #lines == 0 then
		return "no paintable library MeshParts matched any Defs entry yet"
	end
	table.sort(lines)
	return table.concat(lines, "\n") .. "\n⚠️ SAVE THE PLACE — these appearances are place content."
end

-- Kept for the case where a future part genuinely needs precise collision — run it from a real plugin
-- context, or just set the property by hand and save the place.
function BoatParts.applyLibraryFidelity(): string
	local lib = library()
	if not lib then
		return "no ServerStorage.AssetLibrary.BoatParts folder found"
	end
	local lines = {}
	for id, def in pairs(BoatParts.Defs) do
		local name = def.library
		local part = if name then lib:FindFirstChild(name) else nil
		if name and part and part:IsA("MeshPart") then
			local want = if def.collision == "deck"
				then Enum.CollisionFidelity.PreciseConvexDecomposition
				else Enum.CollisionFidelity.Box
			local before = part.CollisionFidelity
			local ok, err = pcall(function()
				part.CollisionFidelity = want
			end)
			table.insert(lines, string.format("%-16s %-22s %s -> %s%s", id, name, tostring(before),
				tostring(part.CollisionFidelity), ok and "" or (" FAILED: " .. tostring(err))))
		end
	end
	if #lines == 0 then
		return "no library MeshParts matched any Defs entry yet"
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

return BoatParts
