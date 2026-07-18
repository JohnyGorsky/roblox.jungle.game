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

local LOBBY_PLACE_ID = 114309626266505 -- "Last River COOP lobby" (players return here after a run)
local REWARD_DIV = 10 -- reward = floor(distance / REWARD_DIV); distance is in studs (display-only for now)
local RETURN_TIMEOUT = 30 -- seconds on the results screen before auto-return to the lobby
local DEV_WIN_DISTANCE = 0 -- >0 overrides the win distance for testing (0 = use the real river end)

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
	local reward = math.floor(distance / REWARD_DIV)
	local survivors = alivePlayers()
	print(("[Run] ENDED — %s | distance=%d reward=%d survivors=%d"):format(won and "WIN" or "LOSE", distance, reward, survivors))

	runEndedRemote:FireAllClients({
		won = won,
		distance = distance,
		reward = reward,
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
