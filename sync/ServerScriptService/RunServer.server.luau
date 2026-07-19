--!strict
-- RunServer.server.luau — run lifecycle: permadeath, win/lose, results, return-to-lobby (Job 018).
--
-- Closes the POC loop. Once the run has started (StagingServer sets Workspace.RunStarted), this owns the
-- ENDING: during a run there is NO respawn — bleeding out (PlayerCombat) is permanent, and the dead player
-- spectates (RunClient). The run ends on WIN (boat reaches the river end) or LOSE (whole crew dead, or the
-- boat destroyed). On end it broadcasts results (win/lose, distance, reward) and returns the party to the
-- lobby. Server-authoritative. Runs on the reserved GAME server. Greybox results UI is client-side.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local RankDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("RankDefs")) :: any

-- global leaderboards (Job 026): lifetime River Score + best distance. Integer values only.
local scoreBoard = DataStoreService:GetOrderedDataStore(RankDefs.BOARD_RIVERSCORE)
local distBoard = DataStoreService:GetOrderedDataStore(RankDefs.BOARD_DISTANCE)
local function writeBoards(userId: number, riverScore: number, bestDist: number)
	task.spawn(function()
		pcall(function()
			scoreBoard:SetAsync(tostring(userId), math.floor(riverScore))
		end)
		pcall(function()
			distBoard:SetAsync(tostring(userId), math.floor(bestDist))
		end)
	end)
end

local LOBBY_PLACE_ID = 114309626266505 -- "Last River COOP lobby" (players return here after a run)
local RETURN_TIMEOUT = 30 -- seconds on the results screen before auto-return to the lobby
local DEV_WIN_DISTANCE = 0 -- >0 overrides the win distance for testing (0 = use the real river end)

-- Gold reward (Job 022, design Job 020 §2) — RARE, finish-weighted. Zone-stepped by fraction of the
-- river reached (checkpoints at 25/50/75/100%); a partial run still pays, a full finish pays a premium.
-- The 6→10 jump at the finish IS the "+4 completion premium" (makes finishing the goal, not farming).
local FINISH_GOLD = 10 -- reaching the end
local ZONE_GOLD = { 1, 2, 4, 6 } -- <25% / 25–50 / 50–75 / 75–99%

local function goldForRun(distance: number, endDist: number, won: boolean): number
	if won or (endDist > 0 and distance >= endDist) then
		return FINISH_GOLD
	end
	local frac = endDist > 0 and (distance / endDist) or 0
	local step = math.clamp(math.floor(frac / 0.25) + 1, 1, 4) -- 1..4
	return ZONE_GOLD[step]
end

local function zoneReached(distance: number, endDist: number): number
	local frac = endDist > 0 and (distance / endDist) or 0
	return math.clamp(math.floor(frac * 4), 0, 4) -- 0..4
end

-- permadeath: we control character loading so a mid-run death stays dead
Players.CharacterAutoLoads = false

local runEndedRemote = Instance.new("RemoteEvent")
runEndedRemote.Name = "RunEnded"
runEndedRemote.Parent = ReplicatedStorage
local returnRemote = Instance.new("RemoteEvent")
returnRemote.Name = "ReturnToLobby"
returnRemote.Parent = ReplicatedStorage

local ended = false
local returning = false

local function isRunStarted(): boolean
	return Workspace:GetAttribute("RunStarted") == true
end

-- a player counts as OUT when marked Dead (bled out / died) during the run
local function alivePlayers(): number
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("Dead") ~= true then
			n += 1
		end
	end
	return n
end

local function winDistance(): number
	if DEV_WIN_DISTANCE > 0 then
		return DEV_WIN_DISTANCE
	end
	return (Workspace:GetAttribute("RiverEndDistance") :: number?) or 18000
end

-- ── death policy ────────────────────────────────────────────────────────────────────────────
local function onDied(player: Player)
	if not isRunStarted() then
		-- pre-start (staging) death shouldn't happen, but if it does, just respawn
		task.defer(function()
			if player.Parent then
				pcall(function()
					player:LoadCharacterAsync()
				end)
			end
		end)
		return
	end
	player:SetAttribute("Dead", true) -- out for the run (no reload → spectate); wipe checked in the loop
	-- clear the dead body so it doesn't linger; the client then spectates (no character)
	task.delay(1.5, function()
		local char = player.Character
		if char then
			char:Destroy()
		end
	end)
end

local function setupPlayer(player: Player)
	player:SetAttribute("Dead", false)
	local function hookChar(char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
		if hum:IsA("Humanoid") then
			hum.Died:Connect(function()
				onDied(player)
			end)
		end
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then
		hookChar(player.Character)
	else
		task.spawn(function() -- auto-loads are off; spawn them once on join
			pcall(function()
				player:LoadCharacterAsync()
			end)
		end)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

-- ── return to lobby (button or auto-timeout, whichever first) ─────────────────────────────────
local function returnToLobby()
	if returning then
		return
	end
	returning = true
	local group = Players:GetPlayers()
	if #group == 0 then
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(LOBBY_PLACE_ID, group)
		end)
		if ok then
			return
		end
		warn("[Run] return TeleportAsync attempt " .. attempt .. " failed: " .. tostring(err))
		task.wait(1)
	end
end
returnRemote.OnServerEvent:Connect(function()
	returnToLobby()
end)

-- ── end the run ───────────────────────────────────────────────────────────────────────────────
local function endRun(won: boolean)
	if ended then
		return
	end
	ended = true
	Workspace:SetAttribute("RunEnded", true)
	Workspace:SetAttribute("RunResult", won and "win" or "lose")

	local distance = (Workspace:GetAttribute("BoatDistance") :: number?) or 0
	local endDist = winDistance()
	local goldEarned = goldForRun(distance, endDist, won)
	local zone = zoneReached(distance, endDist)
	local survivors = alivePlayers()

	-- lifetime River Score for this run (Job 026 §8 POC subset: distance + depth + finish)
	local runScore = math.floor(distance / 100) + zone * 50 + (won and 300 or 0)

	-- credit every crew member (incl. the dead who are spectating) + fold in run stats + rank + boards
	for _, plr in ipairs(Players:GetPlayers()) do
		if Profiles.isReady(plr) then
			Profiles.addGold(plr, goldEarned)
			local newScore = Profiles.addRiverScore(plr, runScore)
			local prof = Profiles.get(plr)
			if prof then
				local s = prof.stats
				s.totalRuns += 1
				if won then
					s.runsFinished += 1
				end
				s.totalDistance += distance
				if distance > (s.bestDistance or 0) then
					s.bestDistance = distance
				end
				if zone > (s.farthestZone or 0) then
					s.farthestZone = zone
				end
				-- weekly objective progress (Job 028): finish / travel / zone
				local w = prof.weekly
				if type(w) ~= "table" then
					w = { finish = 0, travel = 0, zone = 0 }
					prof.weekly = w
				end
				if won then
					w.finish = (w.finish or 0) + 1
				end
				w.travel = (w.travel or 0) + distance
				if zone > (w.zone or 0) then
					w.zone = zone
				end
				writeBoards(plr.UserId, newScore, s.bestDistance)
			end
		end
	end

	print(("[Run] ENDED — %s | distance=%d zone=%d gold=+%d survivors=%d"):format(won and "WIN" or "LOSE", distance, zone, goldEarned, survivors))

	runEndedRemote:FireAllClients({
		won = won,
		distance = distance,
		reward = goldEarned, -- results screen shows this as Gold
		survivors = survivors,
		returnIn = RETURN_TIMEOUT,
	})

	task.delay(RETURN_TIMEOUT, returnToLobby) -- auto-return fallback
end

-- ── end-condition monitor ──────────────────────────────────────────────────────────────────────
task.spawn(function()
	while not ended do
		if isRunStarted() then
			local dist = (Workspace:GetAttribute("BoatDistance") :: number?) or 0
			if dist >= winDistance() then
				endRun(true)
			elseif Workspace:GetAttribute("BoatDestroyed") == true then
				endRun(false)
			elseif alivePlayers() == 0 then
				endRun(false) -- whole crew wiped
			end
		end
		task.wait(0.3)
	end
end)

print("[Run] lifecycle manager online (permadeath during run; win@" .. tostring(winDistance()) .. ")")
