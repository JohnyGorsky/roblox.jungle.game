--!strict
-- MonetizationDefs.luau — Robux product catalog (Job 027, design Job 020 §6). Shared client/server.
-- FILL THE IDs after creating the products on the Roblox Creator Hub (see Jobs/027/final-summary.md).
-- All IDs default to 0 (unset): the shop skips unset products and ownership checks are guarded, so nothing
-- breaks before publish. IDENTICAL copy in both trees.

local MonetizationDefs = {}

-- ── Gold packs (DEVELOPER PRODUCTS — repeatable). productId ← Creator Hub ──────────────────────────
MonetizationDefs.GoldPacks = {
	{ id = "pack10", productId = 3610663250, gold = 10, robux = 49, name = "10 Gold" },
	{ id = "pack25", productId = 3610663288, gold = 25, robux = 99, name = "25 Gold" },
	{ id = "pack60", productId = 3610663341, gold = 60, robux = 199, name = "60 Gold" },
	{ id = "pack150", productId = 3610663385, gold = 150, robux = 449, name = "150 Gold" },
}

-- ── Game passes (one-time). gamePassId ← Creator Hub ───────────────────────────────────────────────
MonetizationDefs.GamePasses = {
	{ key = "armoredBoat", gamePassId = 1919001295, robux = 499, name = "Armored Boat", power = true, blurb = "+20% hull HP & +20% weapon damage" },
	{ key = "boatPaint", gamePassId = 1919355255, robux = 99, name = "Boat Paint Pack", power = false, blurb = "Hull colour skins (cosmetic)" },
	{ key = "cosmeticBundle", gamePassId = 1918077339, robux = 249, name = "Cosmetic Bundle", power = false, blurb = "Trails, wake FX, emote (cosmetic)" },
}

-- gold amount for a purchased developer product (or nil if not one of ours)
function MonetizationDefs.goldForProduct(productId: number): number?
	for _, p in ipairs(MonetizationDefs.GoldPacks) do
		if p.productId == productId and p.productId > 0 then
			return p.gold
		end
	end
	return nil
end

return MonetizationDefs
