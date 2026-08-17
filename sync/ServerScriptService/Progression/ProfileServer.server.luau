--!strict
-- ProfileServer.server.luau — profile lifecycle (Job 021, rewired to ProfileStore in Job 089). SERVER.
-- PlayerAdded (leaderstats + load) -> PlayerRemoving (final save + end session).
-- IDENTICAL copy in sync/ and lobby/sync/ (runs in both places; DataStore is experience-wide).
--
-- ⛔ THE AUTOSAVE LOOP AND THE BindToClose BLOCK WERE DELETED IN JOB 089. Do not add them back.
--
--   · Autosave — ProfileStore auto-saves every active profile every 300 s on its own. The old 60 s
--     loop calling Profiles.save() would just be five times the DataStore writes for no extra safety,
--     which is the opposite of what ProfileStore's longer period is for (~10x fewer calls).
--   · Shutdown — ProfileStore registers its OWN game:BindToClose (ProfileStore.luau:2208) which saves
--     and releases every active profile and yields until the writes finish. Ours would be a second
--     handler racing the first over the same profiles.
--
-- If either ever looks missing, it is because something else owns it now. Read Profiles.luau first.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any

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
	Profiles.load(player) -- yields until the session starts (or is cancelled because they left)
end

Players.PlayerAdded:Connect(onAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onAdded, p) -- catch players already present (Studio start / hot reload)
end

Players.PlayerRemoving:Connect(function(player)
	-- Ends the session as well as saving. This is what lets the DESTINATION server pick the profile up
	-- immediately on the lobby -> game teleport instead of waiting out a conflict.
	Profiles.save(player, true)
	Profiles.unload(player)
end)

print("[Profiles] persistence online (ProfileStore session locking; autosave owned by ProfileStore)")
