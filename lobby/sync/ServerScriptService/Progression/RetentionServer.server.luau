--!strict
-- RetentionServer.server.luau — LOBBY daily rewards + weekly objectives (Job 028, design Job 020 §9).
-- On join: reset weekly objectives if the UTC week rolled over, then grant the daily login reward (once
-- per UTC day) with a forgiving streak. Weekly objectives are progressed in-game (RunServer) and CLAIMED
-- here. Server-authoritative. Grants persist via the profile (#021).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local RetentionDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("RetentionDefs")) :: any

local dailyRemote = Instance.new("RemoteEvent")
dailyRemote.Name = "DailyReward"
dailyRemote.Parent = ReplicatedStorage
local weeklyRF = Instance.new("RemoteFunction")
weeklyRF.Name = "Weekly"
weeklyRF.Parent = ReplicatedStorage

local function onJoin(plr: Player)
	local t = 0
	while not Profiles.isReady(plr) and t < 20 do
		task.wait(0.25)
		t += 0.25
	end
	local prof = Profiles.get(plr)
	if not prof then
		return
	end

	-- weekly reset on UTC-week rollover
	local wk = RetentionDefs.weekNumber()
	if prof.weekId ~= wk then
		prof.weekId = wk
		prof.weekly = { finish = 0, travel = 0, zone = 0 }
		prof.weeklyClaimed = {}
	end

	-- daily reward (once per UTC day, forgiving streak)
	local today = RetentionDefs.dayNumber()
	if prof.lastLoginDay ~= today then
		local last = (prof.lastLoginDay :: number?) or 0
		local gap = today - last
		if last == 0 or gap > RetentionDefs.GRACE_DAYS then
			prof.loginStreak = 1
		else
			prof.loginStreak = ((prof.loginStreak :: number?) or 0) + 1
		end
		prof.lastLoginDay = today
		local gold, dayIdx = RetentionDefs.dailyReward(prof.loginStreak)
		Profiles.addGold(plr, gold)
		dailyRemote:FireClient(plr, { streak = prof.loginStreak, day = dayIdx, gold = gold })
	end
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(onJoin, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

local function progressFor(prof: any, id: string): number
	local w = prof.weekly or {}
	return (w[id] :: number?) or 0
end

weeklyRF.OnServerInvoke = function(plr: Player, action: string?, id: string?)
	if not Profiles.isReady(plr) then
		return { error = "loading" }
	end
	local prof = Profiles.get(plr)
	if action == "list" then
		local objs = {}
		for _, def in ipairs(RetentionDefs.WEEKLY) do
			objs[#objs + 1] = {
				id = def.id,
				name = def.name,
				target = def.target,
				gold = def.gold,
				score = def.score,
				progress = progressFor(prof, def.id),
				claimed = prof.weeklyClaimed[def.id] == true,
			}
		end
		return { objectives = objs }
	elseif action == "claim" then
		for _, def in ipairs(RetentionDefs.WEEKLY) do
			if def.id == id then
				if prof.weeklyClaimed[def.id] then
					return { error = "claimed" }
				end
				if progressFor(prof, def.id) < def.target then
					return { error = "incomplete" }
				end
				prof.weeklyClaimed[def.id] = true
				Profiles.addGold(plr, def.gold)
				Profiles.addRiverScore(plr, def.score)
				return { ok = true, gold = Profiles.getGold(plr) }
			end
		end
		return { error = "unknown" }
	end
	return { error = "bad-action" }
end

print("[Retention] daily rewards + weekly objectives online")
