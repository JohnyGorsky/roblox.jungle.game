--!strict
-- BoatPaint.luau — hull liveries for the Boat Paint Pack (Job 067).
-- IDENTICAL copy in `sync/` and `lobby/sync/` — keep the two byte-identical, so the lobby showroom boat and
-- the real boat can never disagree about what a livery looks like.
--
-- WHY THIS FILE EXISTS
-- The Boat Paint Pack was LIVE on the Creator Hub and delivered nothing — no code anywhere read
-- `Owns_boatPaint` (Job 067 finding 1). This is the implementation.
--
-- ── THE ONE THING THAT MAKES THIS NON-OBVIOUS ────────────────────────────────────────────────────
-- Every boat mesh imported with a full PBR `SurfaceAppearance`: ColorMap + NormalMap + RoughnessMap +
-- MetalnessMap. **An opaque ColorMap completely overrides `BasePart.Color`.** So the obvious implementation
-- — set `.Color` and call it done — changes absolutely nothing on screen, and does so silently.
--
-- Clearing the ColorMap is what makes Color apply. But:
--
--   ⚠️ `SurfaceAppearance.ColorMap` CANNOT BE WRITTEN BY A GAME SCRIPT.
--      "The current thread cannot write 'ColorMap' (lacking capability Plugin)" — the same runtime gate as
--      `MeshPart.MeshId` and `MeshPart.CollisionFidelity` (Job 066). It DOES succeed from the Studio
--      command bar, which holds plugin capability, so testing it there proves nothing. This cost a
--      debugging cycle in Job 067; don't rediscover it.
--
-- So the swap is PREPARED at authoring time and only SELECTED at runtime:
--
--   1. `BoatParts.preparePaintLibrary()` (run once from Studio, Edit mode) gives every paintable library
--      mesh a SECOND SurfaceAppearance named `PaintablePBR`: identical to the stock one but with an empty
--      ColorMap. It saves with the place, exactly like CollisionFidelity.
--   2. `BoatParts.skin()` clones the library part, so BOTH appearances ride along onto every skin.
--   3. At runtime a livery simply DESTROYS the one it doesn't want — destroying an instance needs no
--      capability — and sets `BasePart.Color`.
--
-- The win over the blunt alternative (deleting the SurfaceAppearance outright) is that `PaintablePBR` keeps
-- Normal + Roughness + Metalness, so every rivet, panel line, dent and wear-polished patch survives the
-- repaint. The boat looks repainted, not replaced with flat plastic.
--
-- If the library was never prepared, `paintPart` falls back to dropping the PBR entirely: the livery still
-- shows, just flat. Visibly worse, never broken.
--
-- The DEFAULT livery is special: it keeps the stock ColorMap and drops `PaintablePBR` instead. "Olive drab"
-- is simply the art as the artist authored it, so the boat every player already knows is bit-for-bit
-- untouched, and a player who never buys the pass can never be shown a downgraded boat.
--
-- ONLY THE HULL AND ITS ARMOUR PLATES TAKE PAINT (`paintable` in BoatParts). Deck planking, engines, seats
-- and stations keep their own materials — a boat whose wooden deck turns navy blue reads as a bug.

local BoatPaint = {}

export type PaintDef = {
	name: string,
	color: Color3,
	-- true only for the free default: keep the authored ColorMap, don't tint at all.
	stock: boolean?,
}

-- The free one. Everyone can always select it, pass or no pass.
BoatPaint.DEFAULT = "olive"

-- Display / picker order.
BoatPaint.Order = { "olive", "graphite", "sand", "navy", "jungle", "rust" }

-- Muted, in-world military liveries (user decision, 2026-08-01) rather than bright primaries — the
-- styleguide's art direction is a weathered stylized expedition, and saturated colours fight the
-- roughness/normal detail that survives the repaint.
BoatPaint.Defs = {
	olive = { name = "Olive Drab", color = Color3.fromRGB(104, 108, 74), stock = true },
	graphite = { name = "Graphite", color = Color3.fromRGB(72, 76, 82) },
	sand = { name = "Desert Sand", color = Color3.fromRGB(178, 156, 112) },
	navy = { name = "River Navy", color = Color3.fromRGB(58, 78, 104) },
	jungle = { name = "Jungle Green", color = Color3.fromRGB(66, 96, 62) },
	rust = { name = "Rust Red", color = Color3.fromRGB(132, 68, 50) },
} :: { [string]: PaintDef }

function BoatPaint.get(id: string): PaintDef?
	return BoatPaint.Defs[id]
end

-- Normalise anything (nil, a stale id, a hostile client value) to a real livery id.
function BoatPaint.sanitize(id: unknown): string
	if type(id) == "string" and BoatPaint.Defs[id] ~= nil then
		return id
	end
	return BoatPaint.DEFAULT
end

-- Is `id` sellable — i.e. does it need the pass? The default never does.
function BoatPaint.requiresPass(id: string): boolean
	local def = BoatPaint.Defs[id]
	return def ~= nil and def.stock ~= true
end

-- May `player` use `id`? Reads the attribute MonetizationServer publishes.
function BoatPaint.isUnlocked(player: Player, id: string): boolean
	if not BoatPaint.requiresPass(id) then
		return true
	end
	return player:GetAttribute("Owns_boatPaint") == true
end

-- Name of the authoring-time, ColorMap-free SurfaceAppearance. See the header.
BoatPaint.PAINT_SA_NAME = "PaintablePBR"

local warnedUnprepared = false

-- Paint one already-built part. Safe to call on anything; no-ops on parts that carry no SurfaceAppearance.
--
-- Selects between the two prepared appearances by DESTROYING the unwanted one, because writing ColorMap at
-- runtime is blocked (header). Both branches are idempotent: a rebuilt boat clones a fresh skin with both
-- appearances present again.
local function paintPart(part: BasePart, def: PaintDef)
	local paintable: SurfaceAppearance? = nil
	local stock: SurfaceAppearance? = nil
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			if child.Name == BoatPaint.PAINT_SA_NAME then
				paintable = child
			else
				stock = child
			end
		end
	end

	if def.stock then
		-- stock livery = the authored art. Drop the paintable variant so only one appearance remains.
		if paintable then
			paintable:Destroy()
		end
		return
	end

	if paintable then
		if stock then
			stock:Destroy() -- keep the PBR detail, lose only the baked albedo
		end
	elseif stock then
		-- Library never prepared (BoatParts.preparePaintLibrary not run, or the place not saved since).
		-- Degrade rather than fail: without a ColorMap-free appearance the only way to show ANY colour is
		-- to drop the PBR entirely. Flat, but the player still gets the livery they paid for.
		stock:Destroy()
		if not warnedUnprepared then
			warnedUnprepared = true
			warn("[BoatPaint] library not prepared — run BoatParts.preparePaintLibrary() in Studio (Edit) "
				.. "and save the place, or liveries render flat (no normal/roughness detail)")
		end
	end
	part.Color = def.color
end

-- Apply a livery to a whole boat model.
--
-- Repaints every descendant flagged `paintable` in BoatParts — matched by the `Skin_<partId>` naming that
-- `BoatParts.skin` assigns, so this needs no cooperation from the two different boat builders and picks up
-- armour plates the moment the hullkit module adds them.
--
-- Returns how many parts were repainted, so callers can verify instead of assuming.
function BoatPaint.apply(model: Instance, paintId: string, paintableSkinNames: { [string]: boolean }): number
	local def = BoatPaint.Defs[BoatPaint.sanitize(paintId)]
	if not def then
		return 0
	end
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and paintableSkinNames[d.Name] then
			paintPart(d, def)
			n += 1
		end
	end
	return n
end

return BoatPaint
