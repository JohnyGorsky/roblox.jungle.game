--!strict
-- Hints.luau — one-shot onboarding hints (Job #098). Server-side.
--
-- ── Why this exists ───────────────────────────────────────────────────────────────────────────────
-- Reported in play: **players do not know they can pick loot up and carry it to the boat.** The
-- mechanic is central to the loop — scavenge, haul, spend on fuel and repairs — and nothing in the game
-- ever said so. A player who never carries a crate never discovers the resource economy, and therefore
-- never discovers the rear stations either.
--
-- ── Once EVER, not once per run ───────────────────────────────────────────────────────────────────
-- The seen-set lives on the persistent profile (`ProfileConfig.seen`), so a veteran on their 50th run is
-- never taught to carry a crate again. Session-only flags were the cheaper option and the wrong one:
-- re-teaching every run is exactly the HUD noise Job #094 spent its effort removing.
--
-- ⚠️ FAILS TOWARD TEACHING. `Profiles.hasSeen` returns false when the profile is not ready (in-memory
-- fallback, a session lost to a DataStore outage), so an unlucky player sees the hint again rather than
-- never seeing it. A repeat is a small annoyance; silently never teaching the mechanic is the bug.
--
-- ── Why its own remote and not `Announce` ─────────────────────────────────────────────────────────
-- `Announce` (→ ZoneBanner) is owned by `ZoneServer` and only ever fired with `FireAllClients`; its own
-- comment reserves it for rare crew-wide beats (zone crossings, nightfall). A hint is PER PLAYER — fired
-- through that channel, one newcomer's tutorial would land on all six crew members' screens, veterans
-- included. `HintBanner` is a separate RemoteEvent fired with `FireClient`, which also avoids a
-- load-order dependency between two unrelated systems. `ZoneBanner` renders both.
--
-- ── Adding a hint ─────────────────────────────────────────────────────────────────────────────────
-- One entry in DEFS below, then `Hints.show(player, "yourId")` at the moment it should teach. There
-- will be more: nobody knows about the turret or the medic station either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local remote = Instance.new("RemoteEvent")
remote.Name = "HintBanner"
remote.Parent = ReplicatedStorage

export type HintDef = {
	title: string,
	subtitle: string,
	icon: string?,
	sound: string?,
	color: Color3?,
}

-- Copy deliberately echoes the in-world `BoatInfoSign` ("deposit them in the center area", "use the
-- fuel station", "use the repair station"). A player who reads the sign and then sees the banner should
-- recognise the same words — two phrasings for one mechanic is worse than either alone.
local DEFS: { [string]: HintDef } = {
	-- fires on the FIRST resource crate a player ever picks up
	carryToBoat = {
		title = "CARRY IT TO THE BOAT",
		subtitle = "Deposit it in the centre area of the deck",
		icon = "crate",
		sound = "prompt",
	},
	-- fires on the FIRST successful deposit
	fuelAndRepair = {
		title = "FUEL & REPAIR",
		subtitle = "Load fuel and mend the hull at the stations on the rear deck",
		icon = "fuel",
		sound = "prompt",
	},
}

local Hints = {}

-- Show a hint to one player, once ever. No-op if they have already seen it.
-- Safe to call on a hot path (every pickup): the seen-check is a table lookup, not a DataStore read.
function Hints.show(player: Player, id: string)
	local def = DEFS[id]
	if not def then
		warn(("[Hints] unknown hint id %q"):format(id))
		return
	end
	if Profiles.hasSeen(player, id) then
		return
	end
	-- Marked BEFORE firing, so two pickups in the same frame cannot both pass the check and fire twice.
	Profiles.markSeen(player, id)
	remote:FireClient(player, {
		title = def.title,
		subtitle = def.subtitle,
		-- Gold, not a zone colour: a teaching beat should not read as a zone crossing.
		color = def.color or Theme.color.gold,
		icon = def.icon,
		sound = def.sound,
	})
end

-- Deliberately one-way: `HintBanner` is never listened to on the server. The client can't ask for a
-- hint, because a client-triggered hint would be a free way to spam every screen in the run.

return Hints
