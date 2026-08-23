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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Job #103: the grace glow is palette-tinted like everything else — no hand-picked Color3s.
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local MAX_HP = 100
-- 🔴 Job #103 — REVIVE_HP IS GONE. A revive returns you to FULL health, both routes.
--
-- Reported: *"when i revive i must be full health not just half (with robux) ... Now you respawn by
-- robux and instantly killed."* It was 50, and the Combat Medic skill added 2.5/level on top.
--
-- That HP bonus was the skill's entire effect on this path and it is now dead — there is nothing left to
-- add to a full bar. Its OTHER effect, a shorter revive hold (see `PromptButtonHoldBegan` below), still
-- works. Recorded here rather than left to be discovered: if Combat Medic is ever sold or described on
-- the strength of "revived ally comes up with more HP", that copy is now wrong, and the natural
-- replacement is to have it grant extra GRACE SECONDS instead of extra HP.
local REVIVE_GRACE = 10 -- seconds of invincibility after standing back up
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
		char:SetAttribute("HP", MAX_HP)

		-- 🔴 Job #103 — THE GRACE WINDOW, AND WHY IT IS NOT OPTIONAL POLISH.
		--
		-- *"Now you respawn by robux and instantly killed."* A revive puts the player back on the exact
		-- spot they went down, and nothing else moves: the guards that downed them are still standing over
		-- them, still aggroed, and their bite cooldowns have been counting down the entire time the player
		-- was on the floor. The first bite can therefore land on the frame they stand up. Full health alone
		-- does not fix that — it buys a couple more bites. What was missing is a window to MOVE in.
		--
		-- ⚠️ `os.time()` (wall clock), NOT `os.clock()`, and deliberately: the CLIENT renders a countdown
		-- from this attribute, and `os.clock()` is per-process time that means nothing on another machine.
		-- Same reasoning, same units as `BleedOutAt` below — keep the two consistent.
		--
		-- ⚠️ EVERY PATH THAT DAMAGES A PLAYER MUST CHECK THIS. There is no single chokepoint: player health
		-- is the `HP` character attribute and two separate scripts write damage to it (`EnemyServer`'s
		-- `applyBite` for river creatures, `ExcursionServer`'s `tickGuard` for camp guards). Enforcing it by
		-- reverting the attribute after the fact was rejected — it would fight the Medic-station and
		-- campfire heal loops writing to the same attribute. If you add a new way to hurt a player, guard it
		-- here too, or the grace silently has a hole in it.
		local graceUntil = os.time() + REVIVE_GRACE
		char:SetAttribute("InvincibleUntil", graceUntil)

		-- The glow is built on the SERVER so it replicates to everyone, not just to the protected player.
		-- A teammate needs to see why their covering fire is not being answered and why the guards are
		-- swinging at someone who is not going down — a client-only effect would leave the rest of the crew
		-- reading the fight wrong. Gold because §4 reserves it for progression/positive; red would say
		-- danger, which is the opposite of what this means.
		local old = char:FindFirstChild("ReviveGrace")
		if old then
			old:Destroy() -- a second revive inside the window replaces the glow rather than stacking two
		end
		local glow = Instance.new("Highlight")
		glow.Name = "ReviveGrace"
		glow.FillColor = Theme.color.gold
		glow.OutlineColor = Theme.color.gold
		glow.FillTransparency = 0.72
		glow.OutlineTransparency = 0.15
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Adornee = char
		glow.Parent = char
		Debris:AddItem(glow, REVIVE_GRACE)
		-- Cleared on expiry so the HUD indicator and the highlight have something to switch off, and only
		-- if a LATER revive has not already pushed the deadline out.
		task.delay(REVIVE_GRACE, function()
			if char:GetAttribute("InvincibleUntil") == graceUntil then
				char:SetAttribute("InvincibleUntil", nil)
			end
		end)

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
