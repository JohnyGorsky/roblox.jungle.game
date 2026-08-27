--!strict
-- SalvageServer.server.luau — in-run Salvage currency + dock shop (Job 023, design Job 020 §3).
-- Salvage is a per-player attribute, earned during a run (distance drip + loot, awarded by ExcursionServer)
-- and RESET each run — it never persists. Here we own the reset, the distance drip, and the dock-shop buy
-- handler. Server-authoritative. Game-only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DRIP_STUDS = 60 -- 1 Salvage per this many studs travelled (~300 over an 18k run)

-- ── remotes FIRST, requires after ────────────────────────────────────────────────────────────────
-- (created here; the village trading-post prompt + the client WaitForChild these)
--
-- 🔴 Job #104: THE ORDER MATTERS, AND IT DID NOT USED TO. `ExcursionServer` opens with a top-level
-- `ReplicatedStorage:WaitForChild("OpenShop")` — so anything that can stall this script BEFORE these two
-- lines takes the entire excursion system with it: no camps, no loot crates, no docks. `ShopDefs` used to
-- have zero dependencies, but it now requires `ItemDefs` (to read `ammoPerCrate` rather than hand-copy
-- it), which is a second `WaitForChild` that could hang on a broken tree. Publishing the remotes before
-- requiring anything makes that failure mode local to the shop instead of fatal to the world.
local openShop = Instance.new("RemoteEvent")
openShop.Name = "OpenShop"
openShop.Parent = ReplicatedStorage
local shopRF = Instance.new("RemoteFunction")
shopRF.Name = "DockShop"
shopRF.Parent = ReplicatedStorage

local ShopDefs = require(ReplicatedStorage:WaitForChild("Economy"):WaitForChild("ShopDefs")) :: any
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService")) :: any
-- Job #109: "you received X". This file owns the shop, and a purchase is a thing you receive.
local RewardFeed = require(script.Parent:WaitForChild("RewardFeed"))

local function getSalvage(plr: Player): number
	return (plr:GetAttribute("Salvage") :: number?) or 0
end
local function setSalvage(plr: Player, n: number)
	plr:SetAttribute("Salvage", math.max(0, math.floor(n)))
end

-- ── reset each run ──────────────────────────────────────────────────────────────────────────────
local dripBaseline = 0 -- boat distance already paid out
local function resetAll()
	dripBaseline = (Workspace:GetAttribute("BoatDistance") :: number?) or 0
	for _, p in ipairs(Players:GetPlayers()) do
		setSalvage(p, 0)
		-- Job #123: the shop-stock high-water mark resets with the currency it gates. Strictly this is
		-- belt and braces — a game server hosts exactly one run (see `RifleGrant`'s header), so a Player
		-- attribute is per-run for free. It is here because `NuggetsSpawned` is the one run-scoped value
		-- that DOESN'T reset and that inconsistency is already logged as a todo; no need for a second.
		p:SetAttribute("ShopStop", 0)
	end
end

Players.PlayerAdded:Connect(function(p)
	if p:GetAttribute("Salvage") == nil then
		setSalvage(p, 0)
	end
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p:GetAttribute("Salvage") == nil then
		setSalvage(p, 0)
	end
end

if Workspace:GetAttribute("RunStarted") == true then
	resetAll()
end
Workspace:GetAttributeChangedSignal("RunStarted"):Connect(function()
	if Workspace:GetAttribute("RunStarted") == true then
		resetAll()
	end
end)

-- ── distance drip (all crew earn as the boat makes progress) ──────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(1)
		if Workspace:GetAttribute("RunStarted") == true and Workspace:GetAttribute("RunEnded") ~= true then
			local dist = (Workspace:GetAttribute("BoatDistance") :: number?) or 0
			local gained = math.floor((dist - dripBaseline) / DRIP_STUDS)
			if gained > 0 then
				dripBaseline += gained * DRIP_STUDS
				for _, p in ipairs(Players:GetPlayers()) do
					setSalvage(p, getSalvage(p) + gained)
				end
			end
		end
	end
end)

-- ── dock-shop buy handler ─────────────────────────────────────────────────────────────────────────
local function cargoTotal(boat: Instance): number
	return ((boat:GetAttribute("Gasoline") :: number?) or 0)
		+ ((boat:GetAttribute("Metal") :: number?) or 0)
		+ ((boat:GetAttribute("Ammo") :: number?) or 0)
end

-- apply an item's effect; returns true on success, or false + reason
-- `def` is the `ShopDefs` entry the caller already resolved (Job #104: the ammo branch reads `ammoFor`
-- and `amount` off it, rather than re-looking-up or re-deriving numbers the catalog already owns).
local function applyItem(plr: Player, id: string, def: any): (boolean, string?)
	local boat = Workspace:FindFirstChild("Boat")
	if id == "bandage" then
		plr:SetAttribute("Bandages", ((plr:GetAttribute("Bandages") :: number?) or 0) + 1)
		RewardFeed.notify(plr, "resource", "Bandage", 1)
		return true
	elseif def and def.grants then
		-- ── Job #123: WEAPON ROWS, keyed off `grants` rather than an id list ──────────────────────
		-- Was `id == "pistol" or id == "shotgun"` with the ItemDefs id derived by capitalising it. That
		-- worked for exactly two rows and would have needed editing for the M16 and the Bazooka — the
		-- same trap `ammoFor` was introduced to get out of in Job #104. Four weapon rows now, and this
		-- branch did not have to learn about any of them.
		--
		-- ⚠️ CHECKED BEFORE THE `ammoFor` BRANCH BELOW so the ordering reads gun-then-ammo, but the two
		-- are mutually exclusive in the catalog: no row sets both.
		if InventoryService.grant(plr, def.grants) then
			RewardFeed.notify(plr, "weapon", def.grants)
			return true
		end
		return false, "invfull"
	elseif def and def.ammoFor then
		-- ── Job #104: handheld gun ammo ────────────────────────────────────────────────────────────
		-- ⚠️ CHECKED BEFORE THE RESOURCE BRANCH BELOW, and keyed off `ammoFor` rather than a hardcoded
		-- id list, so adding a third gun's ammo to `ShopDefs` needs no change here.
		--
		-- You must OWN the gun. Not a UI nicety: `addAmmo` writes a Player attribute, so without this a
		-- player could pay 90 salvage for shells that sit on a counter no gun of theirs will ever read.
		-- The client mutes the row for the same reason, but a client gate is a suggestion — this one is
		-- the rule. Returning false here means the caller never deducts the cost (see `shopRF` below).
		if not InventoryService.owns(plr, def.ammoFor) then
			return false, "nogun"
		end
		InventoryService.addAmmo(plr, def.ammoFor, def.amount or 0)
		-- ⚠️ The one shop row whose effect is otherwise INVISIBLE: ammo lands on a Player attribute the
		-- gun reads, with nothing on screen to say it arrived. Reported as part of Job #109's "now you
		-- just guess".
		RewardFeed.notify(plr, "ammo", def.ammoFor .. " Ammo", def.amount or 0)
		return true
	elseif id == "fuel" or id == "ammo" or id == "repair" then
		if not boat then
			return false, "noboat"
		end
		local cap = (boat:GetAttribute("CargoMax") :: number?) or 10
		if cargoTotal(boat) >= cap then
			return false, "cargofull"
		end
		local resource = id == "fuel" and "Gasoline" or (id == "ammo" and "Ammo" or "Metal")
		boat:SetAttribute(resource, ((boat:GetAttribute(resource) :: number?) or 0) + 1)
		RewardFeed.notify(plr, "resource", resource, 1)
		return true
	end
	return false, "unknown"
end

shopRF.OnServerInvoke = function(plr: Player, action: string?, id: string?)
	if action == "list" then
		-- Job #123: `stop` rides along so the panel can hide rows this post does not stock. The client
		-- already invokes this on every open, so there is nothing to keep in sync — and deliberately NOT
		-- passed as an argument on the `OpenShop` fire: one authority for the value, and it is this one.
		-- If this call fails the client falls back to stop 1 and hides the locked rows, which is the safe
		-- direction to fail in (a hidden row beats a visible row the server then refuses).
		return { salvage = getSalvage(plr), stop = (plr:GetAttribute("ShopStop") :: number?) or 1 }
	elseif action == "buy" then
		if Workspace:GetAttribute("RunStarted") ~= true then
			return { error = "norun" }
		end
		local def = id and ShopDefs.get(id)
		if not def or not id then
			return { error = "unknown" }
		end
		-- ── 🔴 Job #123: IS THIS ROW EVEN STOCKED WHERE THIS PLAYER IS? ────────────────────────────
		-- The client hides a locked row, and that is a suggestion, not the rule — this remote is callable
		-- from anywhere at any time, so without this check the M16 is buyable from the boat before the
		-- crew has ever seen a second landing. Exactly the reasoning the `ammoFor` "nogun" gate below
		-- carries, and the same reason it is duplicated here rather than trusted to the UI.
		--
		-- `ShopStop` is written ONLY by the server (`ExcursionServer`, on a trading-post prompt) as the
		-- highest landing this player has reached. A client can scribble on its own local copy of a
		-- Player attribute, but that write never replicates — so what is read here is the server's value.
		local stop = (plr:GetAttribute("ShopStop") :: number?) or 1
		if not ShopDefs.stockedAt(id, stop) then
			return { error = "locked", salvage = getSalvage(plr) }
		end
		if getSalvage(plr) < def.cost then
			return { error = "poor", salvage = getSalvage(plr) }
		end
		local ok, reason = applyItem(plr, id, def)
		if not ok then
			return { error = reason or "failed", salvage = getSalvage(plr) }
		end
		setSalvage(plr, getSalvage(plr) - def.cost)
		return { ok = true, salvage = getSalvage(plr) }
	end
	return { error = "bad-action" }
end

-- (ExcursionServer WaitForChilds the OpenShop RemoteEvent and fires it from the village trading post.)

print("[Salvage] in-run currency + village shop online (drip 1/" .. DRIP_STUDS .. " studs)")
