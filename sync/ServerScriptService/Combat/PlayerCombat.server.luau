--!strict
-- PlayerCombat.server.luau — player health, downed state, bandage revive (Job 008).
--
-- Players carry an "HP" attribute on their character (threats reduce it — see EnemyServer). At 0 HP a
-- player goes DOWNED instead of dying: can't move, a bleed-out timer runs, and a teammate can revive
-- them by holding a ProximityPrompt (costs one scarce bandage). Bleed-out expiry = real death/respawn.
-- Server-authoritative.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAX_HP = 100
local REVIVE_HP = 50
local BLEEDOUT = 30 -- seconds downed before dying
local REVIVE_HOLD = 3 -- seconds a teammate must hold to revive
local START_BANDAGES = 3
local REVIVE_RANGE = 12

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	local walk, jump = hum.WalkSpeed, hum.JumpHeight

	-- spawn placement — the world is a regenerated river, so the default spawn point is over the void.
	-- Before the run starts (staging): spawn at the crash-site HUB. After it starts: ON the boat (so
	-- mid-run respawns land back on the boat). See StagingServer (Job 016).
	task.spawn(function()
		if not Workspace:GetAttribute("RunStarted") then
			-- wait briefly for StagingServer to publish the hub spawn point
			local t0 = os.clock()
			while Workspace:GetAttribute("HubSpawn") == nil
				and not Workspace:GetAttribute("RunStarted")
				and os.clock() - t0 < 10 do
				task.wait(0.1)
			end
			local hub = Workspace:GetAttribute("HubSpawn")
			if hub and not Workspace:GetAttribute("RunStarted") and root.Parent then
				root.CFrame = CFrame.new(hub :: Vector3)
				return
			end
		end
		local boatModel = Workspace:WaitForChild("Boat", 15)
		local h = boatModel and boatModel:FindFirstChild("Hull")
		if h and h:IsA("BasePart") and root.Parent then
			root.CFrame = h.CFrame * CFrame.new(0, 5, 0)
		end
	end)

	char:SetAttribute("MaxHP", MAX_HP)
	char:SetAttribute("HP", MAX_HP)
	char:SetAttribute("Downed", false)

	local bleedThread: thread? = nil

	local function clearBleed()
		if bleedThread then
			task.cancel(bleedThread)
			bleedThread = nil
		end
	end

	local function revive()
		if not char:GetAttribute("Downed") then
			return
		end
		char:SetAttribute("Downed", false)
		char:SetAttribute("HP", REVIVE_HP)
		hum.WalkSpeed, hum.JumpHeight = walk, jump
		local prompt = root:FindFirstChild("RevivePrompt")
		if prompt then
			prompt:Destroy()
		end
		clearBleed()
	end

	local function enterDowned()
		if char:GetAttribute("Downed") then
			return
		end
		char:SetAttribute("Downed", true)
		char:SetAttribute("HP", 0)
		-- immobilize but keep the Humanoid ALIVE and upright, so it floats in water / stays on land
		-- (no PlatformStand ragdoll → doesn't slide off the boat or sink through the water)
		hum.WalkSpeed, hum.JumpHeight = 0, 0

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = REVIVE_HOLD
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = REVIVE_RANGE
		prompt.Parent = root

		prompt.Triggered:Connect(function(reviver: Player)
			if reviver == player then
				return -- no self-revive (that's the paid revive, P8)
			end
			local rc = reviver.Character
			if not rc or rc:GetAttribute("Downed") then
				return
			end
			local bandages = (reviver:GetAttribute("Bandages") :: number?) or 0
			if bandages <= 0 then
				return
			end
			reviver:SetAttribute("Bandages", bandages - 1)
			revive()
		end)

		bleedThread = task.delay(BLEEDOUT, function()
			if char:GetAttribute("Downed") then
				hum.Health = 0 -- bled out → death. During a run RunServer disables respawn → PERMADEATH + spectate (Job 018)
			end
		end)
	end

	char:GetAttributeChangedSignal("HP"):Connect(function()
		if not char:GetAttribute("Downed") and ((char:GetAttribute("HP") :: number?) or MAX_HP) <= 0 then
			enterDowned()
		end
	end)

	hum.Died:Connect(clearBleed)
end

local function setupPlayer(player: Player)
	player:SetAttribute("Bandages", START_BANDAGES)
	if player.Character then
		setupCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)
