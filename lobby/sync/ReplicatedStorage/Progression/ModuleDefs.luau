--!strict
-- ModuleDefs.luau — boat module catalog (Job 025, design Job 020 §5). Shared client/server, no secrets.
-- Modules are one-time Gold unlocks bought in the lobby; they add a visible boat part + a capability
-- ("modules unlock, skills tune"). IDENTICAL copy in sync/ and lobby/sync/.

export type ModuleDef = { name: string, cost: number, blurb: string }

local ModuleDefs = {}

-- display / purchase order
ModuleDefs.Order = { "motor2", "hullkit", "searchlight", "fueltank", "trailer", "gunupgrade" }

ModuleDefs.Defs = {
	motor2 = { name = "Twin Motors Mount", cost = 150, blurb = "A second engine — more thrust." },
	hullkit = { name = "Reinforced Hull", cost = 200, blurb = "Armor plating — more boat HP." },
	searchlight = { name = "Searchlight Rig", cost = 120, blurb = "A spotlight for night runs." },
	fueltank = { name = "Extended Fuel Tank", cost = 150, blurb = "Bigger tank — fewer stops." },
	-- Job 066: renamed from "Cargo Trailer / A towed barge". Towing was removed in Job 013 (a towed
	-- second body was jittery per roblox-physics) and replaced by the welded rear deck, so the old
	-- player-facing text described something the game no longer has. The id stays `trailer` so profiles,
	-- BoatModules and BoatParts keep working.
	trailer = { name = "Cargo Racks", cost = 180, blurb = "Deck racks and crates — carry more loot." },
	gunupgrade = { name = "Mounted Gun Upgrade", cost = 200, blurb = "A stronger mounted turret." },
} :: { [string]: ModuleDef }

function ModuleDefs.get(id: string): ModuleDef?
	return ModuleDefs.Defs[id]
end

return ModuleDefs
