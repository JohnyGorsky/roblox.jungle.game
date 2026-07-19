--!strict
-- ModulesServer.server.luau — LOBBY boat-module shop (Job 025). Buy one-time boat modules with Gold;
-- they persist in the profile (profile.modules) and are applied to the boat in-game (BoatModules).
-- Server-authoritative: cost + affordability + ownership all validated here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any

local rf = Instance.new("RemoteFunction")
rf.Name = "BoatModules"
rf.Parent = ReplicatedStorage

local function ownedCopy(prof: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if prof and prof.modules then
		for id, v in pairs(prof.modules) do
			if v then
				out[id] = true
			end
		end
	end
	return out
end

rf.OnServerInvoke = function(plr: Player, action: string?, id: string?)
	if not Profiles.isReady(plr) then
		return { error = "loading" }
	end
	local prof = Profiles.get(plr)
	if action == "list" then
		return { gold = Profiles.getGold(plr), owned = ownedCopy(prof) }
	elseif action == "buy" then
		local def = id and ModuleDefs.get(id)
		if not def or not id then
			return { error = "unknown" }
		end
		if prof.modules[id] then
			return { error = "owned", gold = Profiles.getGold(plr), owned = ownedCopy(prof) }
		end
		if not Profiles.trySpendGold(plr, def.cost) then
			return { error = "poor", gold = Profiles.getGold(plr), owned = ownedCopy(prof) }
		end
		prof.modules[id] = true
		return { ok = true, gold = Profiles.getGold(plr), owned = ownedCopy(prof) }
	end
	return { error = "bad-action" }
end

print("[BoatModules] lobby shop server online")
