--!strict
-- AdminServer.server.luau — allowlisted admin grants (Job 031). Supersedes the Studio-only DevGrant: works
-- live, grants to yourself OR a chosen player. EVERY action re-checks the allowlist server-side. Grants
-- persist via the profile. Actions are printed (simple audit).
--
-- ⚠️ THE HEADER USED TO SAY "IDENTICAL copy in both trees". IT WAS NOT TRUE, and Job #117 corrected it
-- rather than leaving a claim that invites someone to "restore" byte-identity by copying one over the
-- other. The GAME copy carries ~280 lines the lobby place cannot support — `tpFirstCamp` (Job #107),
-- `tpEndBase` (Job #114) and the Job #112 cheat toggles all need `Workspace.EndBase`, the boat, or the
-- run. What MUST stay in step is the SHARED GRANTS: gold, river score, salvage, modules, skills, and the
-- Job #117 `m16Charge`. Never copy either file over the other wholesale.

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
		elseif kind == "m16Charge" then
			-- Job #117: bank a per-run M16 charge, exactly as a 30 R$ receipt would.
			--
			-- ⚠️ THIS EXISTS BECAUSE THE PURCHASE PATH CANNOT BE TESTED. `Profiles.recordPurchase` refuses
			-- unless `Profiles.isPersisting` is true, and `MarketplaceService` prompts never complete in
			-- Studio at all — so without this button the whole lobby → run half of the feature (buy a
			-- charge here, receive the gun over there) would ship having never once been exercised.
			-- SHARED, therefore, and present in both trees: banking it in the LOBBY and then launching is
			-- precisely the path that needs proving.
			Profiles.addRunGrant(target, "m16", math.max(1, amount))
		else
			return { error = "bad-kind" }
		end
		print(("[Admin] %s → %s: %s %s"):format(plr.Name, target.Name, tostring(kind), tostring(amount)))
		return { ok = true }
	elseif action == "tpFirstCamp" then
		-- self-teleport to the first landing's camp (game-only; the lobby has no ForceFirstCamp → no-op). Job 053
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
