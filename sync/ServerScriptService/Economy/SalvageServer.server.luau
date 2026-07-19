--!strict
-- SalvageServer.server.luau — in-run Salvage currency + dock shop (Job 023, design Job 020 §3).
-- Salvage is a per-player attribute, earned during a run (distance drip + loot, awarded by ExcursionServer)
-- and RESET each run — it never persists. Here we own the reset, the distance drip, and the dock-shop buy
-- handler. Server-authoritative. Game-only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ShopDefs = require(ReplicatedStorage:WaitForChild("Economy"):WaitForChild("ShopDefs")) :: any
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService")) :: any

local DRIP_STUDS = 60 -- 1 Salvage per this many studs travelled (~300 over an 18k run)

-- remotes (created here; DockServer + the client WaitForChild these)
local openShop = Instance.new("RemoteEvent")
openShop.Name = "OpenDockShop"
openShop.Parent = ReplicatedStorage
local shopRF = Instance.new("RemoteFunction")
shopRF.Name = "DockShop"
shopRF.Parent = ReplicatedStorage

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
local function applyItem(plr: Player, id: string): (boolean, string?)
	local boat = Workspace:FindFirstChild("Boat")
	if id == "bandage" then
		plr:SetAttribute("Bandages", ((plr:GetAttribute("Bandages") :: number?) or 0) + 1)
		return true
	elseif id == "pistol" or id == "shotgun" then
		local grantId = id == "pistol" and "Pistol" or "Shotgun"
		if InventoryService.grant(plr, grantId) then
			return true
		end
		return false, "invfull"
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
		return true
	end
	return false, "unknown"
end

shopRF.OnServerInvoke = function(plr: Player, action: string?, id: string?)
	if action == "list" then
		return { salvage = getSalvage(plr) }
	elseif action == "buy" then
		if Workspace:GetAttribute("RunStarted") ~= true then
			return { error = "norun" }
		end
		local def = id and ShopDefs.get(id)
		if not def or not id then
			return { error = "unknown" }
		end
		if getSalvage(plr) < def.cost then
			return { error = "poor", salvage = getSalvage(plr) }
		end
		local ok, reason = applyItem(plr, id)
		if not ok then
			return { error = reason or "failed", salvage = getSalvage(plr) }
		end
		setSalvage(plr, getSalvage(plr) - def.cost)
		return { ok = true, salvage = getSalvage(plr) }
	end
	return { error = "bad-action" }
end

-- (DockServer WaitForChilds the OpenDockShop RemoteEvent and fires it when its shop prompt is triggered.)

print("[Salvage] in-run currency + dock shop online (drip 1/" .. DRIP_STUDS .. " studs)")
