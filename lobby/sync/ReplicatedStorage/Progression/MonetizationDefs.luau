--!strict
-- MonetizationDefs.luau — Robux product catalog (Job 027, design Job 020 §6). Shared client/server.
-- FILL THE IDs after creating the products on the Roblox Creator Hub (see Jobs/027/final-summary.md).
-- All IDs default to 0 (unset): the shop skips unset products and ownership checks are guarded, so nothing
-- breaks before publish. IDENTICAL copy in both trees.
--
-- ⚠️ THE RULE THIS FILE EXISTS TO KEEP (GAME.md): Robux buys CONVENIENCE AND COSMETICS, never raw power.
-- `power = true` is a red flag, not a category — see the Armored Boat and Job #117 M16 notes below. Before
-- adding anything here, ask whether a player who doesn't pay is now worse at the game. If yes, it doesn't
-- belong. TWO items now carry that flag; the second one did NOT earn it the way the first did, and its note
-- says so out loud rather than letting the exception look routine.

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

-- ── Per-run loadout charges (DEVELOPER PRODUCTS) — Job #117 ───────────────────────────────────────
-- One purchase = one charge, spent when a run starts, then gone. Bought in the LOBBY it waits on the
-- profile for the next run; bought at the crash-site kiosk it is spent on the spot.
--
-- 🔴 A SEPARATE TABLE FROM `Products` ABOVE, AND IT HAS TO BE.
-- `Products` means *"hand this off to the `GrantProduct` BindableFunction"*, and that hook has exactly
-- ONE `OnInvoke` — `PlayerCombat` assigns it outright for `selfRevive`. A second claimant does not error:
-- it REPLACES the first, load order between two ServerScriptService scripts is undefined, and whichever
-- loses returns false forever → `NotProcessedYet` → Roblox re-delivers that receipt on every join. So
-- wiring a new product the obvious way (copy what selfRevive does) would silently break PAID SELF-REVIVE
-- and show nothing in the console but occasional retries. These are granted straight onto the PROFILE
-- instead, through the same `Profiles.recordPurchase` path the gold packs use.
--
-- ⚠️ AND NEITHER SHOP RENDERS `Products`, DELIBERATELY (see its note above — contextual buy points only).
-- These ARE rendered, which is the second reason they need their own table: a three-line loop over
-- `Products` to get the M16 onto a shelf would also list **Self Revive at 20 R$, buyable at full health**,
-- and its own comment says that must never happen.
--
-- Generic on purpose. The Bazooka already exists on the Hub (pass `1956512376`, product `3709767468`) and
-- becomes one row here plus one `ItemDefs` entry, with no new plumbing. ⚠️ It is NOT sold yet.
MonetizationDefs.RunGrants = {
	{
		key = "m16",
		productId = 3709767395,
		robux = 30,
		name = "M16 (one run)",
		itemId = "M16", -- the ItemDefs id granted into a loadout slot
		rounds = 30, -- BURSTS, not bullets — see ItemDefs.M16
		-- Owners of this pass already get it free every run, so never sell them a charge. The shops read
		-- this to flip the row to OWNED rather than each hard-coding the pass key.
		passKey = "m16Lifetime",
		blurb = "The M16 + 30 rounds, this run only",
	},
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
	-- ── Job #117 — the M16, and the SECOND `power = true` item we sell ───────────────────────────
	-- 🔴 THIS IS AN OWNER DECISION, RECORDED AS ONE. Not drift, and not the Armored Boat's exemption
	-- being stretched to cover a second thing.
	--
	-- The boat above earned its exemption with a specific argument: the buff is CREW-WIDE, so one owner
	-- helps everyone aboard and it reads as *"someone brought good gear"*. **The M16 has no such
	-- argument.** It is a solo weapon in one buyer's hands, it is the best sustained gun a player can
	-- carry (140 dps at 250 studs, against the Pistol's 91 at 220), and it cannot be earned at any price
	-- in Salvage or loot. That objection was put to the user in Job #117's plan (§10); they chose to ship
	-- it. Do not quietly add a third — the rule in this file's header is still the rule.
	--
	-- What holds the line, and it is the ONLY thing that does: 30 bursts a run and **no way to buy more**
	-- — no camp crate, no trading-post row (see `ItemDefs.M16`'s deliberately absent `ammoPerCrate`).
	-- If it plays badly the lever is `ammoOnLoot` (bursts per run), NOT `damage`.
	{ key = "m16Lifetime", gamePassId = 1954603618, robux = 150, name = "Lifetime M16", power = true, blurb = "Start every run with the M16 + 30 rounds" },
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

-- per-run charge key for a purchased developer product (or nil if not one of ours). The THIRD receipt
-- route, alongside `goldForProduct` and `keyForProduct` — see the RunGrants note on why it is not the hook.
function MonetizationDefs.runGrantForProduct(productId: number): string?
	for _, g in ipairs(MonetizationDefs.RunGrants) do
		if g.productId == productId and g.productId > 0 then
			return g.key
		end
	end
	return nil
end

-- look up a per-run charge by key (nil if unknown)
function MonetizationDefs.runGrant(key: string): any?
	for _, g in ipairs(MonetizationDefs.RunGrants) do
		if g.key == key then
			return g
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
