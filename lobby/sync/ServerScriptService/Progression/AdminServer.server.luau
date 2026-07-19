--!strict
-- AdminServer.server.luau — allowlisted admin grants (Job 031). Supersedes the Studio-only DevGrant: works
-- live, grants to yourself OR a chosen player. EVERY action re-checks the allowlist server-side. Grants
-- persist via the profile. Actions are printed (simple audit). IDENTICAL copy in both trees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any

local rf = Instance.new("RemoteFunction")
rf.Name = "Admin"
rf.Parent = ReplicatedStorage

rf.OnServerInvoke = function(plr: Player, action: string?, arg: any)
	if not AdminDefs.isAdmin(plr.UserId) then
		return { error = "denied" }
	end
	if action == "players" then
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			list[#list + 1] = { name = p.DisplayName, userId = p.UserId }
		end
		return { players = list }
	elseif action == "give" then
		if typeof(arg) ~= "table" then
			return { error = "bad-arg" }
		end
		local target = Players:GetPlayerByUserId(arg.targetUserId)
		if not target or not Profiles.isReady(target) then
			return { error = "no-target" }
		end
		local kind = arg.kind
		local amount = tonumber(arg.amount) or 0
		if kind == "gold" then
			Profiles.addGold(target, amount)
		elseif kind == "score" then
			Profiles.addRiverScore(target, amount)
		elseif kind == "salvage" then
			target:SetAttribute("Salvage", ((target:GetAttribute("Salvage") :: number?) or 0) + amount)
		elseif kind == "allModules" then
			local prof = Profiles.get(target)
			if prof then
				for _, id in ipairs(ModuleDefs.Order) do
					prof.modules[id] = true
				end
			end
		elseif kind == "maxSkills" then
			local prof = Profiles.get(target)
			if prof then
				for _, id in ipairs(SkillDefs.Order) do
					prof.skills[id] = SkillDefs.MAX_LEVEL
				end
			end
		else
			return { error = "bad-kind" }
		end
		print(("[Admin] %s → %s: %s %s"):format(plr.Name, target.Name, tostring(kind), tostring(amount)))
		return { ok = true }
	elseif action == "tpFirstCamp" then
		-- self-teleport to the first landing's camp (game-only; the lobby has no ForceFirstCamp → no-op). Job 054
		local forceCamp = ServerStorage:FindFirstChild("ForceFirstCamp")
		local pos = forceCamp and (forceCamp :: BindableFunction):Invoke()
		if typeof(pos) ~= "Vector3" then
			return { error = "no-camp" }
		end
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return { error = "no-char" }
		end
		root.CFrame = CFrame.new((pos :: Vector3) + Vector3.new(0, 3, 0))
		print(("[Admin] %s → teleported to first camp"):format(plr.Name))
		return { ok = true }
	end
	return { error = "bad-action" }
end

print("[Admin] panel server online (allowlisted)")
