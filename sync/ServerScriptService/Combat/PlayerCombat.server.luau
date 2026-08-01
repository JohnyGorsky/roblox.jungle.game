--!strict
-- PlayerCombat.server.luau — player health, downed state, bandage revive (Job 008).
--
-- Players carry an "HP" attribute on their character (threats reduce it — see EnemyServer). At 0 HP a
-- player goes DOWNED instead of dying: can't move, a bleed-out timer runs, and a teammate can revive
-- them by holding a ProximityPrompt (costs one scarce bandage). Bleed-out expiry = real death/respawn.
-- Server-authoritative.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local MAX_HP = 100
local REVIVE_HP = 50
local BLEEDOUT = 30 -- seconds downed before dying
local REVIVE_HOLD = 3 -- seconds a teammate must hold to revive
local START_BANDAGES = 3
local REVIVE_RANGE = 12

-- ── paid self-revive (Job 067) ───────────────────────────────────────────────────────────────────
-- The downed state has always had this hole in it: a teammate can revive you, and GAME.md promised a paid
-- self-revive as "the monetized safety net", but nothing implemented it (Job 067 finding 4).
--
-- Kept honest as CONVENIENCE, not power: it does exactly what a teammate's bandage does, at the same HP,
-- and it can ONLY be used while downed — so it can never be a combat advantage. It's for the player who
-- goes down with nobody in reach.
--
-- Each downed character registers its own revive closure here and clears it the moment it comes back up
-- or dies. MonetizationServer invokes the hook when the receipt clears; if this map has no entry (already
-- revived, already dead, wrong place) we return false, MonetizationServer returns NotProcessedYet, and
-- Roblox retries rather than charging for nothing.
local pendingRevive: { [Player]: () -> () } = {}

local function grantSelfRevive(player: Player): boolean
	local fn = pendingRevive[player]
	if not fn then
		return false
	end
	fn()
	return true
end

task.spawn(function()
	local hook = ServerScriptService:WaitForChild("GrantProduct", 30)
	if not hook or not hook:IsA("BindableFunction") then
		warn("[PlayerCombat] no GrantProduct hook — paid self-revive will not be grantable")
		return
	end
	hook.OnInvoke = function(player: Player, key: string): boolean
		if key == "selfRevive" then
			return grantSelfRevive(player)
		end
		return false
	end
end)

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	local walk, jump = hum.WalkSpeed, hum.JumpHeight

	-- spawn placement — the world is a regenerated river, so the default spawn point is over the void.
	-- Before the run starts (staging): spawn at the crash-site HUB. After it starts: ON the boat (so
	-- mid-run respawns land back on the boat). See StagingServer (Job 016).
	task.spawn(function()
		-- during the plane intro (Job 044), PlaneServer owns placement (crew rides the plane) — don't yank
		-- them to the hub. It clears IntroActive when it drops the crew at the hub.
		if Workspace:GetAttribute("IntroActive") then
			return
		end
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

	local function revive(reviver: Player?)
		if not char:GetAttribute("Downed") then
			return
		end
		char:SetAttribute("Downed", false)
		-- Combat Medic (Job 029): revived ally comes up with more HP
		local medic = (reviver and (reviver:GetAttribute("SkillMedic") :: number?)) or 0
		char:SetAttribute("HP", math.min(MAX_HP, REVIVE_HP + 2.5 * medic))
		hum.WalkSpeed, hum.JumpHeight = walk, jump
		local prompt = root:FindFirstChild("RevivePrompt")
		if prompt then
			prompt:Destroy()
		end
		clearBleed()
		-- back up: the paid revive has nothing left to grant, and the HUD's countdown stops
		pendingRevive[player] = nil
		char:SetAttribute("BleedOutAt", nil)
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

		-- MEDIC role (Job 057): while a Medic mans the station, revives reach FURTHER + you bleed slower
		-- (snapshot at down-time), and the hold is faster (live, stacks with the per-reviver Combat Medic skill).
		local boatNow = Workspace:FindFirstChild("Boat")
		local medicAboard = boatNow ~= nil and boatNow:GetAttribute("StationMedic") == true

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = REVIVE_HOLD
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = if medicAboard then REVIVE_RANGE * 2 else REVIVE_RANGE
		prompt.Parent = root

		-- Combat Medic skill (Job 029) + Medic role station (Job 057): a skilled reviver / a manned station
		-- both shorten the hold (set per-reviver as they start).
		prompt.PromptButtonHoldBegan:Connect(function(reviver: Player)
			local medic = (reviver:GetAttribute("SkillMedic") :: number?) or 0
			local b2 = Workspace:FindFirstChild("Boat")
			local stationMul = if b2 ~= nil and b2:GetAttribute("StationMedic") == true then 0.6 else 1
			prompt.HoldDuration = math.max(0.4, REVIVE_HOLD * (1 - 0.04 * medic) * stationMul)
		end)

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
			revive(reviver)
		end)

		local bleedFor = if medicAboard then BLEEDOUT * 1.6 else BLEEDOUT
		-- Job 067: publish the deadline so the DOWNED HUD can count down. `os.time()` (wall clock, seconds)
		-- rather than os.clock(), because os.clock() is per-machine process time and means nothing on the
		-- client that has to render the number.
		char:SetAttribute("BleedOutAt", os.time() + bleedFor)

		-- Job 067: arm the paid self-revive for as long as this player is down. Cleared in revive() and on
		-- bleed-out, so a receipt that arrives late finds nothing to grant and is retried rather than
		-- silently consumed.
		pendingRevive[player] = function()
			revive(nil) -- nil reviver = no Combat Medic bonus; you get the plain REVIVE_HP, same as a bandage
		end

		bleedThread = task.delay(bleedFor, function()
			if char:GetAttribute("Downed") then
				pendingRevive[player] = nil
				char:SetAttribute("BleedOutAt", nil)
				hum.Health = 0 -- bled out → death. During a run RunServer disables respawn → PERMADEATH + spectate (Job 018)
			end
		end)
	end

	char:GetAttributeChangedSignal("HP"):Connect(function()
		if not char:GetAttribute("Downed") and ((char:GetAttribute("HP") :: number?) or MAX_HP) <= 0 then
			enterDowned()
		end
	end)

	hum.Died:Connect(function()
		clearBleed()
		pendingRevive[player] = nil -- dead is dead: never grant a paid revive against a corpse
	end)
end

Players.PlayerRemoving:Connect(function(plr)
	pendingRevive[plr] = nil
end)

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
