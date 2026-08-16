--!strict
-- HeldPose.local.luau — the carry pose for whatever you are holding (Job #079).
--
-- ── Why this is a CLIENT script ───────────────────────────────────────────────────────────────────
-- 🔴 A PLAYER'S CHARACTER ANIMATOR IS OWNED BY THAT PLAYER'S CLIENT. Playing an animation on it from
-- the server "works" in the sense that the server's own `GetPlayingAnimationTracks()` lists the track —
-- and it never renders for the player it belongs to. That was the first attempt at this and it was
-- measured, not guessed: the server reported `507768375 w1.00 Idle` while the owning client's track list
-- held only the default idle, and on screen the arm still hung at the hip with the torch lying flat.
--
-- Playing it here fixes both directions at once: the local player sees the pose, and because the client
-- owns the Animator, the track replicates OUT to the server and to everyone else's screen. The reverse
-- never happens.
--
-- ── Why not just ship a real `Tool`? ──────────────────────────────────────────────────────────────
-- Roblox's default `Animate` script poses the arm only when the character holds a **`Tool` that is a
-- direct child of the Character AND has a child named `Handle`**:
--     local tool = Character:FindFirstChildOfClass("Tool")
--     if tool and tool:FindFirstChild("Handle") then animateTool() ... else stopToolAnimations()
-- Our held item is a welded Part, so that branch never ran. Converting to a real Tool would work, but it
-- drags in Roblox's Backpack UI (which `IntroHudGate` re-enables after the intro, so it WOULD render
-- under our own hotbar), drop-on-Backspace, and `Tool.Activated` racing `MeleeClient`'s input. We play
-- the same asset ourselves and pay none of that.
--
-- ⚠️ The hold ANGLES in `WeaponAssets.holdAngles` are solved against this exact pose. Change the
-- animation and every one of them has to be re-solved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local player = Players.LocalPlayer

local track: AnimationTrack? = nil
local currentChar: Model? = nil

-- Loads once per character. A fresh `LoadAnimation` on every slot switch leaks a track per keypress,
-- which at hotbar speed adds up fast — the same reason `MeleeServer` caches its slash tracks.
local function trackFor(char: Model): AnimationTrack?
	if currentChar == char and track then
		return track
	end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	local animator = hum and hum:FindFirstChildWhichIsA("Animator")
	if not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = ItemDefs.HOLD_ANIM
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not loaded then
		-- Everything degrades: no pose just means the old arms-down hold, not a broken character.
		warn("[HeldPose] carry pose failed to load — held items keep the arms-down hold")
		return nil
	end
	-- `Idle` is the priority the default `Animate` script uses for `toolnone`, which is what lets the
	-- Action-priority swing animations play over the top of it instead of fighting it.
	loaded.Priority = Enum.AnimationPriority.Idle
	loaded.Looped = true
	track = loaded
	currentChar = char
	return loaded
end

local function apply()
	local char = player.Character
	if not char then
		return
	end
	local t = trackFor(char)
	if not t then
		return
	end
	-- Empty hands => no pose, so an empty slot stands normally instead of miming a weapon.
	local id = player:GetAttribute("ActiveItem") :: string?
	local holding = id ~= nil and id ~= ""
	if holding then
		if not t.IsPlaying then
			t:Play(0.15)
		end
	elseif t.IsPlaying then
		t:Stop(0.15)
	end
end

player:GetAttributeChangedSignal("ActiveItem"):Connect(apply)

player.CharacterAdded:Connect(function(char)
	-- drop the old character's track rather than keep a handle to a destroyed rig
	track = nil
	currentChar = nil
	char:WaitForChild("Humanoid", 10)
	task.wait(0.2) -- let the default Animate script start, so our Play isn't immediately stomped
	apply()
end)

if player.Character then
	apply()
end
