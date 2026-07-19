--!strict
-- SkillServer.server.luau — LOBBY skill shop (Job 024). Buy skill levels (1..10) with Gold; they persist in
-- the profile (profile.skills) and are applied to the boat/crew in-game (BoatModules). Server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any

local rf = Instance.new("RemoteFunction")
rf.Name = "Skills"
rf.Parent = ReplicatedStorage

local function skillsCopy(prof: any): { [string]: number }
	local out: { [string]: number } = {}
	if prof and prof.skills then
		for id, lv in pairs(prof.skills) do
			out[id] = lv
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
		return { gold = Profiles.getGold(plr), skills = skillsCopy(prof) }
	elseif action == "buy" then
		local def = id and SkillDefs.get(id)
		if not def or not id then
			return { error = "unknown" }
		end
		local cur = (prof.skills[id] :: number?) or 0
		if cur >= SkillDefs.MAX_LEVEL then
			return { error = "maxed", gold = Profiles.getGold(plr), skills = skillsCopy(prof) }
		end
		local nextLv = cur + 1
		local cost = SkillDefs.cost(nextLv)
		if not Profiles.trySpendGold(plr, cost) then
			return { error = "poor", gold = Profiles.getGold(plr), skills = skillsCopy(prof) }
		end
		prof.skills[id] = nextLv
		return { ok = true, gold = Profiles.getGold(plr), skills = skillsCopy(prof) }
	end
	return { error = "bad-action" }
end

print("[Skills] lobby skill shop online")
