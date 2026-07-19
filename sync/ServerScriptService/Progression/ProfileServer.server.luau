--!strict
-- ProfileServer.server.luau — profile lifecycle: the save trio (Job 021). SERVER.
-- PlayerAdded (leaderstats + load) -> autosave heartbeat -> PlayerRemoving (release) -> BindToClose.
-- IDENTICAL copy in sync/ and lobby/sync/ (runs in both places; DataStore is experience-wide).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local ProfileConfig =
	require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ProfileConfig")) :: any

-- Dev/testing hook (server command bar): _G.LR_Profiles.addGold(game.Players.NAME, 100)
_G.LR_Profiles = Profiles

local function setupLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = 0
	gold.Parent = ls
	ls.Parent = player
end

local function onAdded(player: Player)
	setupLeaderstats(player)
	Profiles.load(player)
end

Players.PlayerAdded:Connect(onAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onAdded, p) -- catch players already present (Studio start / hot reload)
end

Players.PlayerRemoving:Connect(function(player)
	Profiles.save(player, true) -- final save + release lock
	Profiles.unload(player)
end)

-- Autosave heartbeat (also refreshes the session lock).
task.spawn(function()
	while true do
		task.wait(ProfileConfig.AUTOSAVE_INTERVAL)
		for _, p in ipairs(Players:GetPlayers()) do
			if Profiles.isReady(p) then
				Profiles.save(p, false)
			end
		end
	end
end)

-- Save everyone still in the server during the ~30s shutdown window (in parallel).
game:BindToClose(function()
	local players = Players:GetPlayers()
	local pending = #players
	if pending == 0 then
		return
	end
	for _, p in ipairs(players) do
		task.spawn(function()
			Profiles.save(p, true)
			Profiles.unload(p)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		task.wait(0.2)
		waited += 0.2
	end
end)

print("[Profiles] persistence online (session-locked; autosave " .. ProfileConfig.AUTOSAVE_INTERVAL .. "s)")
