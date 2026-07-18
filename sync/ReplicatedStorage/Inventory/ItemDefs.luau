--!strict
-- ItemDefs.luau — the item catalog for the 4-slot loadout (Job 015).
--
-- Shared by client (hotbar UI) and server (inventory + weapon logic). One "what am I holding?" model:
-- Sword is the default fallback; Pistol/Shotgun are looted at camps; each gun has its OWN per-player
-- ammo pool (attribute `ammoAttr`). Numbers here are greybox/functional — tune in a later balance pass.

export type ItemDef = {
	name: string,
	kind: "Melee" | "Gun",
	color: Color3, -- greybox held-item colour
	-- gun-only fields:
	ammoAttr: string?, -- Player attribute holding this gun's ammo (per-player)
	damage: number?,
	range: number?,
	pellets: number?, -- rays per shot (shotgun spread)
	spread: number?, -- cone half-angle in radians for extra pellets
	fireInterval: number?, -- min seconds between shots
	ammoOnLoot: number?, -- ammo granted when you first loot the gun
	ammoPerCrate: number?, -- ammo granted per ammo pickup
	-- melee-only fields:
	meleeRange: number?,
	swingInterval: number?,
}

local ItemDefs = {}

ItemDefs.SLOT_COUNT = 4

ItemDefs.Items = {
	Sword = {
		name = "Sword",
		kind = "Melee",
		color = Color3.fromRGB(200, 205, 215),
		damage = 15,
		meleeRange = 9, -- short range only — pure fallback
		swingInterval = 0.6,
	},
	Pistol = {
		name = "Pistol",
		kind = "Gun",
		color = Color3.fromRGB(60, 60, 70),
		ammoAttr = "AmmoPistol",
		damage = 20,
		range = 220,
		pellets = 1,
		spread = 0,
		fireInterval = 0.22,
		ammoOnLoot = 24,
		ammoPerCrate = 18,
	},
	Shotgun = {
		name = "Shotgun",
		kind = "Gun",
		color = Color3.fromRGB(80, 55, 40),
		ammoAttr = "AmmoShotgun",
		damage = 12, -- per pellet (close range = big total)
		range = 95,
		pellets = 6,
		spread = 0.14,
		fireInterval = 0.7,
		ammoOnLoot = 8,
		ammoPerCrate = 6,
	},
} :: { [string]: ItemDef }

function ItemDefs.get(id: string?): ItemDef?
	if not id then
		return nil
	end
	return ItemDefs.Items[id]
end

return ItemDefs
