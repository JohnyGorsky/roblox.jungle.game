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
}

local ShopDefs = {}

-- ⚠️ ORDER IS A MOBILE DECISION, NOT A TIDINESS ONE. The panel is 0.74 screen-heights and rows are 66 px,
-- so a phone shows roughly THREE rows at a time. Pairing each ammo row under its gun (the first cut of
-- this job) put them at positions 6 and 8 — the player who reported "we can buy pistol but not ammo"
-- would have had to scroll past four rows to find the fix. Restocks come first, one-off gun purchases
-- last: what you buy every stop is what you can reach without scrolling.
ShopDefs.Order = { "bandage", "pistolAmmo", "shotgunAmmo", "fuel", "ammo", "repair", "pistol", "shotgun" }

-- rounds one purchase grants, straight off the gun's own definition
local function perBox(itemId: string): number
	local def = ItemDefs.get(itemId)
	return (def and def.ammoPerCrate) or 0
end

local PISTOL_ROUNDS = perBox("Pistol") -- 18
local SHOTGUN_SHELLS = perBox("Shotgun") -- 6

ShopDefs.Items = {
	bandage = { name = "Bandage", cost = 50, blurb = "Revive / heal supply (+1)" },
	fuel = { name = "Fuel Can", cost = 120, blurb = "+1 gasoline to the boat" },
	-- ⚠️ The ID STAYS `ammo` — it crosses the `DockShop` remote, and renaming it buys nothing. Only the
	-- player-facing name changed, from the ambiguous "Ammo Box".
	ammo = { name = "Turret Ammo", cost = 90, blurb = "+1 ammo crate for the boat's gun" },
	repair = { name = "Repair Kit", cost = 150, blurb = "+1 metal (repairs the hull)" },
	pistol = { name = "Pistol", cost = 400, blurb = "A ranged sidearm" },
	pistolAmmo = {
		name = "Pistol Ammo",
		cost = 60,
		blurb = ("+%d rounds — needs a pistol"):format(PISTOL_ROUNDS),
		ammoFor = "Pistol",
		amount = PISTOL_ROUNDS,
	},
	shotgun = { name = "Shotgun", cost = 750, blurb = "Close-range punch" },
	shotgunAmmo = {
		name = "Shotgun Ammo",
		cost = 90,
		-- Dearer per shot than pistol rounds on purpose: 15 salvage a shell against 3.3 a round, because
		-- Job #104 also doubled the shotgun to 24 damage a pellet (144 for a full hit) vs the pistol's 20.
		blurb = ("+%d shells — needs a shotgun"):format(SHOTGUN_SHELLS),
		ammoFor = "Shotgun",
		amount = SHOTGUN_SHELLS,
	},
} :: { [string]: ShopItem }

function ShopDefs.get(id: string): ShopItem?
	return ShopDefs.Items[id]
end

return ShopDefs
