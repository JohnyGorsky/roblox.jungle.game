--!strict
-- ShopDefs.luau — dock shop catalog (Job 023, design Job 020 §3). Shared client/server. Bought with
-- in-run Salvage (resets each run). Prices per Job 020 §3.

export type ShopItem = { name: string, cost: number, blurb: string }

local ShopDefs = {}

ShopDefs.Order = { "bandage", "fuel", "ammo", "repair", "pistol", "shotgun" }

ShopDefs.Items = {
	bandage = { name = "Bandage", cost = 50, blurb = "Revive / heal supply (+1)" },
	fuel = { name = "Fuel Can", cost = 120, blurb = "+1 gasoline to the boat" },
	ammo = { name = "Ammo Box", cost = 90, blurb = "+1 turret ammo" },
	repair = { name = "Repair Kit", cost = 150, blurb = "+1 metal (repairs the hull)" },
	pistol = { name = "Pistol", cost = 400, blurb = "A ranged sidearm" },
	shotgun = { name = "Shotgun", cost = 750, blurb = "Close-range punch" },
} :: { [string]: ShopItem }

function ShopDefs.get(id: string): ShopItem?
	return ShopDefs.Items[id]
end

return ShopDefs
