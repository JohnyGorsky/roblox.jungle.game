--!strict
-- InventoryServer.server.luau — seeds each player's loadout and handles equip/drop commands (Job 015).
--
-- Thin wrapper around InventoryService (the authoritative state). Every player starts with a Sword in
-- slot 1; guns are looted into free slots at camps (see ExcursionServer). One remote, validated server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))

-- TEMP dev toggle: give every player a Pistol + Shotgun (with ammo) on spawn so guns can be tested
-- without driving to a camp. Set false (or delete) once camp weapon-crate looting is the real path.
local DEV_STARTER_GUNS = false -- players start Sword+Torch; guns are looted at camps (the real path)

local remote = Instance.new("RemoteEvent")
remote.Name = "InventoryCmd"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(function(player: Player, action: any, slot: any)
	if action == "equip" then
		InventoryService.equip(player, slot)
	elseif action == "drop" then
		InventoryService.drop(player, slot)
	end
end)

local function setupPlayer(player: Player)
	InventoryService.seed(player)
	if DEV_STARTER_GUNS then
		InventoryService.grant(player, "Pistol")
		InventoryService.grant(player, "Shotgun")
	end
	if player.Character then
		InventoryService.onCharacterAdded(player)
	end
	player.CharacterAdded:Connect(function()
		InventoryService.onCharacterAdded(player)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

print("[Inventory] loadout service online")
