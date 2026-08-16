--!strict
-- CampfireHeal.server.luau — sit by a fire to recover (Job #084).
--
-- ⚠️ BEFORE THIS, NOTHING IN THE GAME HEALED A PLAYER. `PlayerCombat` sets HP to 100 on spawn and every
-- other write to it subtracts; the only increase in the whole codebase is the revive at
-- `PlayerCombat:112`, which requires being downed first. Bandages do not help — they are spent by the
-- REVIVER on someone else, and cannot be found in the world at any price but 50 Salvage at the trading
-- post. So a run was a one-way ratchet from 100 to dead across 18,000 studs.
--
-- ── The shape is Defender's `AIHealingPad` ────────────────────────────────────────────────────────
-- Same proven pattern, deliberately: a CollectionService tag marks the heal sources, a slow polling loop
-- (NOT a per-frame Heartbeat — healing at 0.5 s granularity is indistinguishable from healing at 60 Hz)
-- checks who is inside a radius, and a particle attachment on the character shows it is working.
-- Proximity rather than `Touched`, for the same reason Defender gives: it keeps working while the player
-- is seated or standing on a prop, where contact tests fail.
--
-- ── Contested fires ───────────────────────────────────────────────────────────────────────────────
-- A fire always heals, but only trickles while the camp's guards are alive (user call). Full rate is the
-- reward for clearing; the trickle means a player who limps into a defended camp is never simply denied.
-- With Job #084's day-cycle guard respawns, a fire you are resting at CAN be taken back off you — the
-- rate drops rather than the healing stopping, which reads as pressure instead of a bug.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CampDefs = require(ServerScriptService:WaitForChild("World"):WaitForChild("CampDefs"))

local HEAL = CampDefs.HEAL

-- ── the healing cue ───────────────────────────────────────────────────────────────────────────────
-- Built, not sourced: Jungle has no `ParticleEmmiters` folder to clone from the way Defender does, and a
-- rising warm mote column is a few properties. One emitter per character, ENABLED/DISABLED rather than
-- created and destroyed — `GameSoundscape`'s stacking lesson applies to VFX too, and the poll runs twice
-- a second, which is exactly the rate at which create/destroy churn becomes visible.
local function healAttachment(char: Model): ParticleEmitter?
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end
	local existing = torso:FindFirstChild("HealAura")
	if existing then
		return existing:FindFirstChildOfClass("ParticleEmitter")
	end
	local att = Instance.new("Attachment")
	att.Name = "HealAura"
	att.Position = Vector3.new(0, -1.48, 0) -- same offset Defender uses; sits at the waist, reads on R15
	att.Parent = torso

	local p = Instance.new("ParticleEmitter")
	p.Name = "Heal"
	-- warm ember-green: it has to read as the FIRE helping, not as a potion effect
	p.Color = ColorSequence.new(Color3.fromRGB(150, 220, 130), Color3.fromRGB(255, 215, 140))
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Size = NumberSequence.new(0.35, 0.05)
	p.Lifetime = NumberRange.new(0.7, 1.1)
	p.Rate = 14
	p.Speed = NumberRange.new(2.5, 4)
	p.SpreadAngle = Vector2.new(18, 18)
	p.Acceleration = Vector3.new(0, 4, 0) -- drifts UP: recovery, not damage
	p.LightEmission = 0.6
	p.LockedToPart = false
	p.Enabled = false
	p.Parent = att
	return p
end

local function setAura(char: Model, on: boolean)
	local p = healAttachment(char)
	if p then
		p.Enabled = on
	end
end

-- The nearest tagged fire to a position, and whether it is contested. Returns nil when out of range of
-- every fire, so the caller can switch the aura off in one place.
local function fireAt(pos: Vector3): (BasePart?, boolean)
	for _, core in CollectionService:GetTagged(CampDefs.TAG.campfire) do
		if core:IsA("BasePart") and core.Parent then
			if (core.Position - pos).Magnitude <= HEAL.radius then
				-- contested = a living camp guard still near this fire. Guards are culled with their
				-- camp, so a cleared camp's fire has none left to find.
				local contested = false
				for _, guard in CollectionService:GetTagged("CampGuard") do
					if guard:IsA("Model") and guard.Parent then
						local body = guard.PrimaryPart
						local hp = (guard:GetAttribute("HP") :: number?) or 0
						if body and hp > 0 and (body.Position - core.Position).Magnitude <= HEAL.guardRange then
							contested = true
							break
						end
					end
				end
				return core, contested
			end
		end
	end
	return nil, false
end

task.spawn(function()
	while true do
		task.wait(HEAL.interval)
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not char or not root then
				continue
			end
			-- ⚠️ A DOWNED player is NOT healed back up. Bleeding out is a teammate's problem to solve
			-- with a bandage (`PlayerCombat`); a fire that quietly undid the downed state would delete
			-- the whole revive mechanic.
			if char:GetAttribute("Downed") then
				setAura(char, false)
				continue
			end

			local hp = (char:GetAttribute("HP") :: number?) or 0
			local maxHp = (char:GetAttribute("MaxHP") :: number?) or 100
			local core, contested = fireAt(root.Position)

			if core and hp > 0 and hp < maxHp then
				local rate = if contested then HEAL.contestedRate else HEAL.rate
				char:SetAttribute("HP", math.min(maxHp, hp + rate * HEAL.interval))
				setAura(char, true)
			else
				-- aura still shows at a fire when already full, so "this is a rest point" stays legible
				setAura(char, core ~= nil and hp > 0)
			end
		end
	end
end)

print("[Campfire] rest-and-heal online (" .. HEAL.rate .. " HP/s clear · " .. HEAL.contestedRate .. " HP/s contested)")
