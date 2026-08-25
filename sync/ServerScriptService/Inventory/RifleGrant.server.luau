--!strict
-- RifleGrant.server.luau — the ONE place a Robux-bought weapon enters a loadout (Job #117).
--
-- GAME PLACE ONLY. Two ways a player can be holding the M16 at the start of a run:
--   · the LIFETIME PASS (`Owns_m16Lifetime`) — free, every run, forever
--   · a PER-RUN CHARGE (`profile.runGrants.m16`) — one purchase, one run, then gone
--
-- Both land here, and both go through the same `tryGrant`, which is the point: a charge bought in the
-- LOBBY and a charge bought at the crash-site kiosk are indistinguishable by the time they arrive.
--
-- ⚠️ WHY THIS IS NOT IN `lobby/sync/`. It requires `ServerStorage.Inventory.InventoryService`, and
-- `lobby/default.project.json` maps NO ServerStorage at all — so a copy placed there would silently never
-- run. (There is already a dead pre-Job-067 fork of `InventoryService` sitting in `lobby/sync/ServerStorage/`
-- for exactly that reason; do not add to it.) The lobby's half of this feature is purely the shop row and
-- the receipt, both of which live in files that DO load there.
--
-- ── "Per run" means "per game-place session", and that is not a shortcut ─────────────────────────────
-- The game place IS the run: it is a reserved server per party, `StagingServer` only ever sets
-- `RunStarted` true (never back to false), and `RunServer` teleports everyone out and lets the server
-- drain. So a player attribute is per-run for free — the same idiom `Salvage` and `InvSeeded` already use.
--
-- ⚠️ AND THE CHARGE IS SPENT ON JOIN, NOT ON `RunStarted`. That is deliberate and it is not the obvious
-- choice: the Robux kiosk is editor-placed at the CRASH SITE (`StartShopServer` → `SpawnBase.Stands.RobuxShop`)
-- and `StagingServer` clears `HubSpawn` and sails the crew away from it. There is no kiosk anywhere on the
-- river. So "bought during the run" is in practice "bought while standing in the staging camp, before
-- anyone untied", and waiting for `RunStarted` would leave that player holding nothing while they look
-- straight at the shop they just paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local MonetizationDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("MonetizationDefs")) :: any
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))

-- "This player already has it for this run." Read by BOTH Robux shops to disable the per-run row.
--
-- ⚠️ A DEDICATED ATTRIBUTE RATHER THAN SCANNING THE SLOTS, and the reason is a real hole: a player may
-- DROP the rifle (`InventoryService.drop` refuses only the Axe), and a slot scan would then report "you
-- don't have an M16" and happily sell them a second charge in the same run.
local function grantedAttr(key: string): string
	return "Granted_" .. key
end

-- ── startup consistency check ────────────────────────────────────────────────────────────────────
-- The rounds a player actually receives come from `ItemDefs.<item>.ammoOnLoot`, because that is what
-- `InventoryService.grant` applies. `MonetizationDefs.RunGrants[].rounds` is the number the SHOP ROW
-- PRINTS. If those two drift the shop lies about what the money buys — so this checks instead of
-- assuming, once, loudly, at startup rather than in a comment nobody re-reads.
for _, g in ipairs(MonetizationDefs.RunGrants) do
	local def = ItemDefs.get(g.itemId)
	if not def then
		warn(("[RifleGrant] RunGrant %q names itemId %q, which is not in ItemDefs — it can never be granted")
			:format(tostring(g.key), tostring(g.itemId)))
	elseif def.ammoOnLoot ~= g.rounds then
		warn(("[RifleGrant] %s sells %d rounds but ItemDefs.%s.ammoOnLoot grants %s — the shop is lying")
			:format(tostring(g.name), g.rounds, tostring(g.itemId), tostring(def.ammoOnLoot)))
	end
end

-- 🔴 THE LOADOUT HAS TO EXIST FIRST, AND THIS IS A REAL RACE, NOT A PRECAUTION.
-- `InventoryService.seed` is what writes `Slot1..6` and sets `InvSeeded`; it runs from `InventoryServer`
-- on `PlayerAdded`, and so does this script. Their order is undefined. Granting first would find slot 1
-- "empty" — because NO slot exists yet, and `(nil or "") == ""` — put the M16 there, and then `seed`
-- would overwrite slot 1 with the Axe. The player would have paid Robux for a gun that vanished before
-- they ever saw it, with nothing in the log.
local function awaitSeeded(player: Player): boolean
	if player:GetAttribute("InvSeeded") == true then
		return true
	end
	local t0 = os.clock()
	while player.Parent ~= nil and player:GetAttribute("InvSeeded") ~= true and os.clock() - t0 < 30 do
		task.wait(0.1)
	end
	return player:GetAttribute("InvSeeded") == true
end

-- Arm this weapon for this run, if the player is entitled to it and does not already have it.
--
-- ⚠️ MUST NOT YIELD. It is called from two attribute-changed signals, and the guard at the top is only
-- an effective lock if nothing between it and the write can yield. `Profiles.getRunGrant`,
-- `Profiles.takeRunGrant` and `InventoryService.grant` are all synchronous; keep it that way, or two
-- signals arriving together will both pass the guard and grant twice.
local function tryGrant(player: Player, g: any)
	if player:GetAttribute(grantedAttr(g.key)) == true then
		-- 🔴 THE IDEMPOTENCY GUARD, and it is load-bearing rather than defensive.
		-- `MonetizationServer` sets `Owns_<key>` a SECOND time on `PromptGamePassPurchaseFinished`, so a
		-- mid-run pass purchase fires our watcher twice. `InventoryService.grant` does not error on a
		-- repeat — it quietly tops the ammo up by `ammoOnLoot` — so without this the player would get
		-- **60 rounds instead of 30**, and it would present as a rounds bug rather than a purchase bug.
		return
	end

	-- A dead player is out for the run: `RunServer` sets `CharacterAutoLoads = false` and destroys the
	-- body 1.5 s after death, so `onCharacterAdded` never fires again and the held visual would never be
	-- built. Writing slot attributes for a spectator would burn the charge for nothing, so leave it
	-- banked — they keep it for their next run.
	if player:GetAttribute("Dead") == true then
		return
	end

	local owns = g.passKey ~= nil and player:GetAttribute("Owns_" .. tostring(g.passKey)) == true

	local spent = false
	if not owns then
		if not Profiles.isReady(player) then
			return -- too early; the RunGrant_* publish on profile load will call us back
		end
		if Profiles.getRunGrant(player, g.key) <= 0 then
			return -- not entitled: no pass, no charge
		end
		spent = Profiles.takeRunGrant(player, g.key)
		if not spent then
			return
		end
	end

	-- Marked BEFORE the grant, so a second signal arriving cannot race past the guard above.
	player:SetAttribute(grantedAttr(g.key), true)

	if not InventoryService.grant(player, g.itemId) then
		-- Loadout full. Give the charge back and clear the flag, so freeing a slot lets them try again —
		-- the alternative is charging someone for a gun they never receive.
		player:SetAttribute(grantedAttr(g.key), nil)
		if spent then
			Profiles.addRunGrant(player, g.key, 1)
		end
		warn(("[RifleGrant] %s: loadout full, %s not granted (charge refunded: %s)")
			:format(player.Name, tostring(g.itemId), tostring(spent)))
		return
	end

	print(("[RifleGrant] %s -> %s (%s)")
		:format(player.Name, tostring(g.itemId), if owns then "lifetime pass" else "per-run charge"))
end

local function setup(player: Player)
	task.spawn(function()
		if not awaitSeeded(player) then
			warn(("[RifleGrant] %s: loadout never seeded — no paid weapon granted"):format(player.Name))
			return
		end
		for _, g in ipairs(MonetizationDefs.RunGrants) do
			-- ⚠️ BOTH of these are WATCHED, not sampled, because both arrive late and neither is
			-- guaranteed to have landed by now:
			--   · `Owns_<pass>` — `MonetizationServer.checkPasses` waits up to 20 s for the profile before
			--     it even calls `UserOwnsGamePassAsync`, so it reliably lands AFTER `seed`. Sampling it
			--     once would hand every pass owner an empty loadout. (`ItemDefs.slotsFor` documents the
			--     same rule for `Owns_extraSlots`.) Watching it is also what makes a pass bought at the
			--     kiosk arm the gun immediately instead of next run.
			--   · `RunGrant_<key>` — published by `Profiles._publish` on profile load, and again the
			--     instant a receipt is granted. One signal therefore covers BOTH "bought in the lobby,
			--     arriving with the player" and "bought thirty seconds ago at the kiosk".
			if g.passKey then
				player:GetAttributeChangedSignal("Owns_" .. tostring(g.passKey)):Connect(function()
					tryGrant(player, g)
				end)
			end
			player:GetAttributeChangedSignal("RunGrant_" .. g.key):Connect(function()
				tryGrant(player, g)
			end)
			tryGrant(player, g) -- in case either already landed while we waited on InvSeeded
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	setup(p)
end
Players.PlayerAdded:Connect(setup)

print("[RifleGrant] paid-weapon grants online")
