--!strict
-- PilotIdle.server.luau — loops the pilot's idle animation (lobby NPC by the plane).
-- Skinned Meshy rig: plays via AnimationController/Animator (no Humanoid). Server-play replicates
-- to all clients through the Animator (don't also play it client-side). LOBBY-scoped.
-- Animation asset: "Pilot idle" 71254620030056 (registry: audio? no — animations.md).

local Workspace = game:GetService("Workspace")
local IDLE_ID = "rbxassetid://71254620030056"

-- Find the pilot anywhere in Workspace (it may be nested, e.g. under LOBBY_GREYBOX.Scenery) —
-- a Model named "Pilot" or one containing the skinned "char1" mesh, with an AnimationController.
local function findPilot(): Instance?
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") and (d.Name == "Pilot" or d:FindFirstChild("char1")) and d:FindFirstChildWhichIsA("AnimationController") then
			return d
		end
	end
	return nil
end
local pilot: Instance? = nil
local t0 = os.clock()
repeat
	pilot = findPilot()
	if pilot then break end
	task.wait(0.5)
until os.clock() - t0 > 20
if not pilot then warn("[PilotIdle] Pilot model not found in Workspace") return end

local ac = pilot:FindFirstChildWhichIsA("AnimationController")
local animator = ac and ac:FindFirstChildWhichIsA("Animator")
if not animator then warn("[PilotIdle] AnimationController/Animator missing on Pilot") return end

local anim = Instance.new("Animation")
anim.AnimationId = IDLE_ID

local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
if not ok or not track then warn("[PilotIdle] failed to load idle animation:", track) return end

track.Looped = true
track.Priority = Enum.AnimationPriority.Idle
track:Play()
print("[PilotIdle] idle playing (length "..string.format("%.1f", track.Length).."s)")
