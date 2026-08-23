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
-- ⚠️ FAILS TOWARD TEACHING, NOT TOWARD SPAMMING. `Profiles.hasSeen` returns false when the profile is
-- not ready (in-memory fallback, a DataStore outage, or Studio with API access off), so an unlucky
-- player sees the hint again rather than never seeing it — silently never teaching the mechanic is the
-- bug this exists to fix.
--
-- But "the profile says no" is checked EVERY pickup, so on its own that fallback would fire the banner
-- on every single crate. Caught in Studio, where no profile loads at all: the hint fired repeatedly.
-- Hence the SESSION set below — a second, in-memory guard so the worst case is "once per session"
-- rather than "once per crate".
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

-- Find-or-create, not blind create. A ModuleScript that makes an Instance as a side effect will make a
-- SECOND one if it is ever required from another Luau VM — which is not hypothetical: requiring this
-- from the Studio command bar during Job #098's own verification produced two `HintBanner` remotes, the
-- server fired through one and the client was listening to the other, and every banner silently
-- vanished. Idempotent construction costs one line and removes the whole class of problem.
local remote = ReplicatedStorage:FindFirstChild("HintBanner") :: RemoteEvent?
if not remote then
	local created = Instance.new("RemoteEvent")
	created.Name = "HintBanner"
	created.Parent = ReplicatedStorage
	remote = created
end
local hintRemote = remote :: RemoteEvent

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
	-- ⚠️ Job #102 — THE FIRST LINK IN THE CHAIN, AND IT WAS MISSING.
	--
	-- Reported: *"when you exit first time boat, we need message — gather resources etc, now users dont
	-- know what to do"*. The two hints below teach what to do with loot once you are holding it; NOTHING
	-- told a player to get off the boat and go looking for it in the first place. A player who never
	-- walks inland never picks up a crate, so `carryToBoat` never fires either and the whole economy
	-- stays invisible. Read the three in order — go inland → carry it back → spend it:
	--     goAshore  → carryToBoat → fuelAndRepair
	--
	-- Copy names the ACTUAL resources the first landing holds (`buildLandingSite` stocks the near camp
	-- with 2× Gasoline and the deep camp with Metal + Ammo), because "gather resources" on its own does
	-- not tell anyone where to walk.
	--
	-- ⚠️ It does NOT mention the guards. This is the hint you get while standing on a beach looking at
	-- an empty basin; warning about enemies here would read as the fight already being on, and the first
	-- landing is deliberately down to three guards (Job #102) so that first contact is legible on its own.
	goAshore = {
		title = "GATHER SUPPLIES",
		subtitle = "Raid the camps inland for fuel, metal and ammo",
		icon = "loot",
		sound = "prompt",
	},
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

-- In-memory backstop, cleared when the player leaves. Covers the case where the profile cannot answer
-- (see the header): without it, an unpersisted player would be re-taught on every crate.
local shownThisSession: { [Player]: { [string]: true } } = {}

Players.PlayerRemoving:Connect(function(player: Player)
	shownThisSession[player] = nil
end)

-- Show a hint to one player, once ever. No-op if they have already seen it.
-- Safe to call on a hot path (every pickup): both checks are table lookups, not DataStore reads.
function Hints.show(player: Player, id: string)
	local def = DEFS[id]
	if not def then
		warn(("[Hints] unknown hint id %q"):format(id))
		return
	end

	local session = shownThisSession[player]
	if session and session[id] then
		return -- already shown in this session, whatever the profile thinks
	end
	if Profiles.hasSeen(player, id) then
		return
	end

	-- Both marked BEFORE firing, so two pickups in the same frame cannot both pass the check.
	if not session then
		session = {}
		shownThisSession[player] = session
	end
	;(session :: { [string]: true })[id] = true
	Profiles.markSeen(player, id) -- no-op when there is no profile to write to
	hintRemote:FireClient(player, {
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
