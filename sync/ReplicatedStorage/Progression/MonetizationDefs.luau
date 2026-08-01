--!strict
-- MonetizationDefs.luau — Robux product catalog (Job 027, design Job 020 §6). Shared client/server.
-- FILL THE IDs after creating the products on the Roblox Creator Hub (see Jobs/027/final-summary.md).
-- All IDs default to 0 (unset): the shop skips unset products and ownership checks are guarded, so nothing
-- breaks before publish. IDENTICAL copy in both trees.
--
-- ⚠️ THE RULE THIS FILE EXISTS TO KEEP (GAME.md): Robux buys CONVENIENCE AND COSMETICS, never raw power.
-- `power = true` is a red flag, not a category — see the Armored Boat note below. Before adding anything
-- here, ask whether a player who doesn't pay is now worse at the game. If yes, it doesn't belong.

local MonetizationDefs = {}

-- ── Gold packs (DEVELOPER PRODUCTS — repeatable). productId ← Creator Hub ──────────────────────────
MonetizationDefs.GoldPacks = {
	{ id = "pack10", productId = 3610663250, gold = 10, robux = 49, name = "10 Gold" },
	{ id = "pack25", productId = 3610663288, gold = 25, robux = 99, name = "25 Gold" },
	{ id = "pack60", productId = 3610663341, gold = 60, robux = 199, name = "60 Gold" },
	{ id = "pack150", productId = 3610663385, gold = 150, robux = 449, name = "150 Gold" },
}

-- ── Utility developer products (repeatable, NOT gold) — Job 067 ────────────────────────────────────
-- Consumables bought in the moment they're needed, so they are deliberately NOT listed in the lobby shop;
-- each has its own contextual buy point. ProcessReceipt routes them by `key`.
MonetizationDefs.Products = {
	-- Bought from the DOWNED overlay while bleeding out (PlayerCombat / DownedHud).
	-- Convenience, not power: it does exactly what a teammate's bandage does, for a player with no
	-- teammate in reach. It cannot be used when you are NOT downed, so it can never be a combat advantage.
	-- Created on the Creator Hub 2026-08-01. Priced at 20 R$ by the user (managed pricing enabled).
	{ key = "selfRevive", productId = 3612677893, robux = 20, name = "Self Revive", blurb = "Get back up on your own." },
}

-- ── Game passes (one-time). gamePassId ← Creator Hub ───────────────────────────────────────────────
-- Job 067 removed `cosmeticBundle` (249 R$, trails/wake/emote). It was LIVE and delivered nothing at all —
-- no code in either tree ever read `Owns_cosmeticBundle`. Rather than ship three unbuilt features to
-- justify a price, it is no longer sold from inside the game. The Creator Hub listing is unlisted
-- separately by hand; removing it here is what stops new purchases from this client.
MonetizationDefs.GamePasses = {
	-- ⚠️ THE ONE POWER ITEM WE SELL, and a deliberate, documented exception to the rule above
	-- (GAME.md "Monetization"). Tolerated because the buff applies to the WHOLE CREW, not the buyer — one
	-- player owning it helps everyone aboard, which reads as "someone brought good gear" rather than as a
	-- solo advantage. Do not use it as precedent: nothing else here may set `power = true`.
	{ key = "armoredBoat", gamePassId = 1919001295, robux = 499, name = "Armored Boat", power = true, blurb = "+20% hull HP & +20% weapon damage" },
	{ key = "boatPaint", gamePassId = 1919355255, robux = 99, name = "Boat Paint Pack", power = false, blurb = "Hull colour liveries (cosmetic)" },
	-- Job 067. Pure carry convenience — no damage, no health, no speed. See ItemDefs.slotsFor().
	-- Created on the Creator Hub 2026-08-02 at 149 R$; `robux` below must keep matching the Hub price,
	-- because it is what the shop row prints.
	{ key = "extraSlots", gamePassId = 1935044952, robux = 149, name = "Extra Inventory Slots", power = false, blurb = "+2 loadout slots" },
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

-- utility-product key for a purchased developer product (or nil if not one of ours)
function MonetizationDefs.keyForProduct(productId: number): string?
	for _, p in ipairs(MonetizationDefs.Products) do
		if p.productId == productId and p.productId > 0 then
			return p.key
		end
	end
	return nil
end

-- look up a utility product by key (nil if unknown). `productId == 0` means "not created on the Hub yet".
function MonetizationDefs.product(key: string): any?
	for _, p in ipairs(MonetizationDefs.Products) do
		if p.key == key then
			return p
		end
	end
	return nil
end

return MonetizationDefs
