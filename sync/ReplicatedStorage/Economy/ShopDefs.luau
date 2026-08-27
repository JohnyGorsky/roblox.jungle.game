--!strict
-- ShopDefs.luau — dock shop catalog (Job 023, design Job 020 §3). Shared client/server. Bought with
-- in-run Salvage (resets each run). Prices per Job 020 §3.
--
-- ── Job #104: HANDHELD AMMO IS BUYABLE ────────────────────────────────────────────────────────────
-- Reported as *"we currently can buy pistol but not ammo"*, and that was exactly true. The post sold
-- both guns and a row called **"Ammo Box"** — which is the BOAT TURRET's ammo (it adds 1 to the boat's
-- `Ammo` cargo, see `SalvageServer.applyItem`) and does nothing for the pistol in your hand. Handheld
-- ammo had two sources, both loot: `ammoOnLoot` when you pick the gun up, and an `Ammo` crate at a camp.
-- So the only way to buy pistol rounds was to buy a SECOND 400-salvage pistol, because `grant()` tops
-- up ammo when the gun is already owned. That is a workaround, not a feature.
--
-- Now: one row per gun, `ammoFor` naming the `ItemDefs` id it feeds. And the turret row is called
-- **"Turret Ammo"**, because its old name was half the reported bug.
--
-- ⚠️ THE AMOUNT IS NOT TYPED HERE. It is `ItemDefs.ammoPerCrate` — the same number a looted ammo crate
-- grants — so a balance pass tunes ONE value and the crate, the shop, and the blurb all move together.
-- A hand-copied 18 in this file is precisely the drift `ItemDefs.TURRET_ROUNDS_PER_CRATE` was extracted
-- to stop.
--
-- ⚠️ THE FLIP SIDE, SO THE NEXT BALANCE PASS KNOWS: `ammoPerCrate` is now load-bearing in TWO economies
-- — the camp loot crate AND this shop box — while the PRICE below is not derived from anything. Retune
-- `ammoPerCrate` to fix looting and you silently re-price the shop (more rounds for the same salvage);
-- retune the price here and the crate does not follow. Change one, look at the other.
--
-- ── Job #123: THE M16 AND BAZOOKA ARE BUYABLE, AND THEIR ROWS ARE STOP-GATED ──────────────────────
-- Two new concepts, both generic so a fifth weapon is data only:
--   · `grants` — the `ItemDefs` id a weapon row puts in a slot. Replaces the hardcoded
--     `id == "pistol" or id == "shotgun"` that used to live in `SalvageServer.applyItem`.
--   · `minStop` — the landing ordinal a row first appears at. See `ShopDefs.stockedAt`.
--
-- ⚠️ THE ONE ASYMMETRY WORTH KNOWING: the caveat above ("load-bearing in TWO economies") does NOT apply
-- to the M16 or the Bazooka. A camp `Kind == "Ammo"` crate reads `ammoPerCrate` for ITS OWN `weaponId`,
-- and `ExcursionServer` only ever sets that to Pistol or Shotgun — so for these two guns `ammoPerCrate`
-- feeds this shop and nothing else. Their per-run ammo cap is therefore purely a price.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

export type ShopItem = {
	name: string,
	cost: number,
	blurb: string,
	-- Job #104, ammo rows only: the `ItemDefs` id this row tops up. Its presence is what makes a row an
	-- ammo row — the server keys off it, and it is also the gun you must OWN to buy it.
	ammoFor: string?,
	amount: number?, -- rounds granted; resolved from `ItemDefs.ammoPerCrate`, never written by hand
	-- ── Job #123, WEAPON rows only: the `ItemDefs` id this row grants into a loadout slot ──────────
	-- Its presence is what makes a row a weapon row. Added because `SalvageServer.applyItem` used to
	-- test `id == "pistol" or id == "shotgun"` by hand, so a third gun meant editing the server — the
	-- same shape `ammoFor` fixed for ammo rows in Job #104. Four weapon rows now, zero server changes.
	grants: string?,
	-- ── Job #123: the LANDING ORDINAL this row first appears at (1 = the first stop; nil = always) ──
	-- The trading post at landing N shows a row only when `minStop <= N`, and once a row is unlocked it
	-- stays stocked at every later stop (owner's call: the price is the wall, not a one-time window).
	-- ⚠️ `ExcursionServer` publishes the player's high-water landing as the `ShopStop` attribute, and
	-- `SalvageServer` re-checks this on BUY. A client-side hide is a suggestion; the server is the rule.
	minStop: number?,
}

local ShopDefs = {}

-- ⚠️ ORDER IS A MOBILE DECISION, NOT A TIDINESS ONE. The panel is 0.74 screen-heights and rows are 66 px,
-- so a phone shows roughly THREE rows at a time. Pairing each ammo row under its gun (the first cut of
-- this job) put them at positions 6 and 8 — the player who reported "we can buy pistol but not ammo"
-- would have had to scroll past four rows to find the fix. Restocks come first, one-off gun purchases
-- last: what you buy every stop is what you can reach without scrolling.
--
-- ⚠️ Job #123 KEEPS THAT RULE and it is why the four new rows go at the END, not next to their ammo.
-- The M16 and Bazooka are bought ONCE in a run; the bandage is bought every stop. Putting a 1,250-Salvage
-- gun above the restocks would push the bandage row off a phone screen for the sake of a row you tap once.
ShopDefs.Order = {
	"bandage",
	"pistolAmmo",
	"shotgunAmmo",
	"fuel",
	"ammo",
	"repair",
	"pistol",
	"shotgun",
	-- Job #123 — locked until landing 2 / 3, so for most of stop 1 this tail does not render at all
	"m16",
	"m16Ammo",
	"bazooka",
	"bazookaAmmo",
}

-- rounds one purchase grants, straight off the gun's own definition
local function perBox(itemId: string): number
	local def = ItemDefs.get(itemId)
	return (def and def.ammoPerCrate) or 0
end

local PISTOL_ROUNDS = perBox("Pistol") -- 18
local SHOTGUN_SHELLS = perBox("Shotgun") -- 6
local M16_BURSTS = perBox("M16") -- 10 — BURSTS, not bullets (one round = one 2 s burst)
local BAZOOKA_ROCKETS = perBox("Bazooka") -- 2

ShopDefs.Items = {
	bandage = { name = "Bandage", cost = 50, blurb = "Revive / heal supply (+1)" },
	fuel = { name = "Fuel Can", cost = 120, blurb = "+1 gasoline to the boat" },
	-- ⚠️ The ID STAYS `ammo` — it crosses the `DockShop` remote, and renaming it buys nothing. Only the
	-- player-facing name changed, from the ambiguous "Ammo Box".
	ammo = { name = "Turret Ammo", cost = 90, blurb = "+1 ammo crate for the boat's gun" },
	repair = { name = "Repair Kit", cost = 150, blurb = "+1 metal (repairs the hull)" },
	-- Job #123: `grants` added to the two pre-existing gun rows too. Not cosmetic — it is what let the
	-- hardcoded `id == "pistol" or id == "shotgun"` test come out of `SalvageServer.applyItem`.
	pistol = { name = "Pistol", cost = 400, blurb = "A ranged sidearm", grants = "Pistol" },
	pistolAmmo = {
		name = "Pistol Ammo",
		cost = 60,
		blurb = ("+%d rounds — needs a pistol"):format(PISTOL_ROUNDS),
		ammoFor = "Pistol",
		amount = PISTOL_ROUNDS,
	},
	shotgun = { name = "Shotgun", cost = 750, blurb = "Close-range punch", grants = "Shotgun" },
	shotgunAmmo = {
		name = "Shotgun Ammo",
		cost = 90,
		-- Dearer per shot than pistol rounds on purpose: 15 salvage a shell against 3.3 a round, because
		-- Job #104 also doubled the shotgun to 24 damage a pellet (144 for a full hit) vs the pistol's 20.
		blurb = ("+%d shells — needs a shotgun"):format(SHOTGUN_SHELLS),
		ammoFor = "Shotgun",
		amount = SHOTGUN_SHELLS,
	},

	-- ── Job #123 — THE M16 AND THE BAZOOKA, EARNABLE ─────────────────────────────────────────────────
	-- Until now these were Robux-only, and `MonetizationDefs` carries three `power = true` flags because
	-- of it. These four rows are what retire that objection: Robux still buys them, but what it buys is
	-- **having them from the start of the run** (and, for the passes, every run) rather than exclusivity.
	--
	-- 🔴 THE PRICES ARE MEASURED AGAINST THE RUN'S INCOME, NOT PICKED. Job #123 §3 audited every Salvage
	-- source in the game; a landing site pays a thorough raider ~730 and the drip adds ~53 a leg. So at
	-- the counter, net of the ~175/stop the essentials above cost:
	--     landing 2 → ~1,335 disposable      landing 3 → ~1,937 disposable
	-- The two guns sit at 94% and 93% of those. That is the brief — *"must cost a lot, but you can earn
	-- enough in camp 1 and 2"* — and it produces the property that makes the choice interesting:
	-- **you can afford ONE premium weapon per run, not both.** Buy the M16 at landing 2 and the Bazooka
	-- is out of reach until landing 5; skip it and the Bazooka is yours at landing 3.
	--
	-- ⚠️ SO DO NOT RAISE THESE WITHOUT RE-READING Job #123 §3. They are not round numbers chosen for
	-- feel; each one is a percentage of a measured budget, and the budget itself is sensitive to
	-- finding 0042 (the `hunter` objective's 120 Salvage is currently unreachable by raiding — if that is
	-- ever fixed, both budgets rise by 120 and these prices have room to move up).
	m16 = {
		name = "M16",
		cost = 1250,
		blurb = "Burst rifle — 30 rounds",
		grants = "M16",
		minStop = 2,
	},
	m16Ammo = {
		name = "M16 Ammo",
		cost = 350,
		-- 35 a burst = 0.125 Salvage per damage (280 a burst), against the shotgun's 0.104. Dearer per
		-- damage than any other ammo in the shop, which is the intended shape for a 250-stud burst gun.
		-- ⚠️ And cheaper per burst than re-buying the 1,250 gun (41.7), which is what closes the Job #104
		-- top-up exploit — `InventoryService.grant` refills ammo on a gun you already own.
		blurb = ("+%d bursts — needs an M16"):format(M16_BURSTS),
		ammoFor = "M16",
		amount = M16_BURSTS,
		minStop = 2,
	},
	bazooka = {
		name = "Bazooka",
		cost = 1800,
		blurb = "Rocket launcher — 6 rockets",
		grants = "Bazooka",
		minStop = 3,
	},
	bazookaAmmo = {
		name = "Bazooka Ammo",
		cost = 500,
		-- 250 a rocket: the most expensive shot in the game, deliberately. A rocket one-shots every land
		-- threat inside 30 studs, so the scarcity that used to come from "no way to buy more" has to come
		-- from the price instead. Still under the 300-a-rocket cost of re-buying the gun (see above).
		blurb = ("+%d rockets — needs a bazooka"):format(BAZOOKA_ROCKETS),
		ammoFor = "Bazooka",
		amount = BAZOOKA_ROCKETS,
		minStop = 3,
	},
} :: { [string]: ShopItem }

function ShopDefs.get(id: string): ShopItem?
	return ShopDefs.Items[id]
end

-- ── Job #123: is this row stocked at the trading post of landing `stop`? ─────────────────────────
-- ONE answer shared by the client (which hides the row) and the server (which refuses the buy), so the
-- panel and the rule cannot drift. A row with no `minStop` is stocked everywhere, which is every row
-- that existed before this job.
--
-- ⚠️ `stop` is the LANDING ordinal (1..6), i.e. `ExcursionServer`'s `tier`, NOT the dock ordinal.
-- Landings are only the odd docks, so dock 3 is landing 2 — getting this wrong shifts the whole table by
-- a stop and would put the M16 on sale at the tutorial landing.
function ShopDefs.stockedAt(id: string, stop: number): boolean
	local def = ShopDefs.Items[id]
	if not def then
		return false
	end
	return stop >= (def.minStop or 1)
end

return ShopDefs
