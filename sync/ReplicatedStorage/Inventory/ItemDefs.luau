--!strict
-- ItemDefs.luau — the item catalog for the 4-slot loadout (Job 015).
--
-- Shared by client (hotbar UI) and server (inventory + weapon logic). One "what am I holding?" model:
-- Sword is the default fallback; Pistol/Shotgun are looted at camps; each gun has its OWN per-player
-- ammo pool (attribute `ammoAttr`). Numbers here are greybox/functional — tune in a later balance pass.

export type ItemDef = {
	name: string,
	kind: "Melee" | "Gun" | "Light",
	color: Color3, -- greybox held-item colour
	-- light-only fields (Job 037):
	lightRange: number?,
	lightBrightness: number?,
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

-- Loadout size. BASE is what everyone gets; the Extra Inventory Slots game pass (Job 067) raises a
-- player to MAX. Read `ItemDefs.slotsFor(player)` rather than these constants — the count is per-player
-- now, not global.
ItemDefs.SLOT_COUNT = 4 -- base (kept as the original name: it is what an unpaid player has)
ItemDefs.MAX_SLOTS = 6 -- with the Extra Inventory Slots pass

-- How many rounds the MOUNTED TURRET gets from one ammo crate. Lived as a local `ROUNDS_PER_AMMO` in
-- GunServer until Job #075: the HUD has to total "how many shots do I actually have" across crates and
-- loaded rounds, and a second hand-copied 12 on the client would drift the moment this is tuned.
-- (Distinct from `ammoPerCrate` above, which is a HANDHELD gun picking up an ammo crate.)
ItemDefs.TURRET_ROUNDS_PER_CRATE = 12

-- How many slots this player has. Convenience only — more room to carry, no damage/health/speed change,
-- which is what keeps it on the right side of GAME.md's "core power stays earnable" rule.
--
-- Reads the `Owns_extraSlots` attribute MonetizationServer publishes. That attribute arrives
-- ASYNCHRONOUSLY (UserOwnsGamePassAsync on join), so anything that renders slots must react to it
-- changing rather than sampling it once — see InventoryHud.
function ItemDefs.slotsFor(player: Player): number
	if player:GetAttribute("Owns_extraSlots") == true then
		return ItemDefs.MAX_SLOTS
	end
	return ItemDefs.SLOT_COUNT
end

ItemDefs.Items = {
	-- Job #079: the starting weapon. RENAMED from `Sword` — the model is roblox.defender's Rusty Axe,
	-- reused whole. Damage stays 15 deliberately (Defender's axe does 20): every other weapon is meant
	-- to be an upgrade on this, and Jobs 015/058 tuned the on-foot camp raid against 15.
	Axe = {
		name = "Axe",
		kind = "Melee",
		color = Color3.fromRGB(200, 205, 215),
		damage = 15,
		meleeRange = 9, -- short range only — pure fallback
		swingInterval = 0.6,
	},
	Torch = {
		name = "Torch",
		kind = "Light",
		color = Color3.fromRGB(255, 175, 80),
		lightRange = 30, -- studs the torch lights around you
		lightBrightness = 3,
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
