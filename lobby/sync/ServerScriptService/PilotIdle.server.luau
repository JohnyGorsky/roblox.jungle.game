--!strict
-- PilotIdle.server.luau — loops the pilot's idle animation (lobby NPC by the plane).
-- Skinned Meshy rig: plays via AnimationController/Animator (no Humanoid). Server-play replicates
-- to all clients through the Animator (don't also play it client-side). LOBBY-scoped.
-- Animation asset: "Pilot idle" 71254620030056 (registry: audio? no — animations.md).

local Workspace = game:GetService("Workspace")
local IDLE_ID = "rbxassetid://71254620030056"

local pilot = Workspace:WaitForChild("Pilot", 30)
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
