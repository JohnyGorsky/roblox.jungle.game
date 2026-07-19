--!strict
-- ObjectiveServer.server.luau — per-run objectives (Job 061). Tracks progress from replicated run state,
-- awards the whole crew on completion (Salvage in-run + River Score / Gold via the profile), and publishes
-- ObjDone_<id> / ObjProg_<id> Workspace attributes for the HUD. Resets each run. Server-authoritative.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ObjectiveDefs = require(ReplicatedStorage:WaitForChild("Objectives"):WaitForChild("ObjectiveDefs"))
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

local done: { [string]: boolean } = {}
local sawNight = false

local function defById(id: string): ObjectiveDefs.Objective?
	for _, d in ObjectiveDefs.List do
		if d.id == id then
			return d
		end
	end
	return nil
end

local function complete(id: string)
	if done[id] then
		return
	end
	local def = defById(id)
	if not def then
		return
	end
	done[id] = true
	Workspace:SetAttribute("ObjDone_" .. id, true)
	Workspace:SetAttribute("ObjProg_" .. id, def.target)
	-- reward the whole crew
	for _, plr in ipairs(Players:GetPlayers()) do
		if def.salvage > 0 then
			plr:SetAttribute("Salvage", ((plr:GetAttribute("Salvage") :: number?) or 0) + def.salvage)
		end
		if Profiles.isReady(plr) then
			if def.score > 0 then
				Profiles.addRiverScore(plr, def.score)
			end
			if def.gold > 0 then
				Profiles.addGold(plr, def.gold)
			end
		end
	end
	print(("[Objective] complete: %s (+%d salvage, +%d score, +%d gold ea)"):format(id, def.salvage, def.score, def.gold))
end

local function resetRun()
	table.clear(done)
	sawNight = false
	Workspace:SetAttribute("RunKills", 0)
	for _, d in ObjectiveDefs.List do
		Workspace:SetAttribute("ObjDone_" .. d.id, false)
		Workspace:SetAttribute("ObjProg_" .. d.id, 0)
	end
end

resetRun()

-- discrete events -----------------------------------------------------------
Workspace:GetAttributeChangedSignal("RunStarted"):Connect(function()
	if Workspace:GetAttribute("RunStarted") == true then
		resetRun()
	end
end)

-- survive a night: saw a night this run, then dawn broke while the run is still going
Workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	if Workspace:GetAttribute("RunStarted") ~= true or Workspace:GetAttribute("RunEnded") == true then
		return
	end
	local ph = Workspace:GetAttribute("Phase")
	if ph == "night" then
		sawNight = true
	elseif ph == "day" and sawNight then
		complete("nightOwl")
	end
end)

-- finish the run
Workspace:GetAttributeChangedSignal("RunResult"):Connect(function()
	if Workspace:GetAttribute("RunResult") == "win" then
		complete("finisher")
	end
end)

-- continuous progress -------------------------------------------------------
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.4 then
		return
	end
	acc = 0
	if Workspace:GetAttribute("RunStarted") ~= true then
		return
	end
	-- reach The Rapids (zone 3)
	if ((Workspace:GetAttribute("Zone") :: number?) or 0) >= 3 then
		complete("reachRapids")
	end
	-- take down 15 threats
	local kills = (Workspace:GetAttribute("RunKills") :: number?) or 0
	if not done.hunter then
		Workspace:SetAttribute("ObjProg_hunter", math.min(kills, 15))
		if kills >= 15 then
			complete("hunter")
		end
	end
end)

print("[Objective] per-run objectives online (" .. #ObjectiveDefs.List .. ")")
