--!strict
-- StartShopServer.server.luau — the crash-site Robux shop kiosk (Job 046; REWIRED Job 074).
--
-- Walking up + holding the ProximityPrompt fires OpenRobuxShop to that client, which opens the Robux
-- shop panel (RobuxShop.local). Purchases go through MarketplaceService client-side; receipts are
-- handled by MonetizationServer.
--
-- ── Job 074 (todo 0043): THIS SCRIPT NO LONGER BUILDS THE KIOSK. ──────────────────────────────────
-- It used to spawn a green 4x5x2 SmoothPlastic box with a "ROBUX SHOP" billboard, positioned by
-- raycasting down from HubSpawn on the far side of the plane wreck (Job 072's fix for the kiosk landing
-- INSIDE the 88x94 fuselage). All of that is gone. The camp is hand-built now, so the shop is too: it's
-- the real Meshy kiosk hut, editor-placed at Workspace.SpawnBase.Stands.RobuxShop, and this script
-- FINDS it and attaches the prompt.
--
-- That retires the wreck-avoidance logic on purpose — a hand-placed hut cannot collide with a
-- hand-placed wreck, and its position is now a build decision you can drag in the editor rather than a
-- raycast's opinion. The cost is that a missing/renamed placement means no shop at all, so the lookup
-- warns loudly instead of failing silently.
--
-- Deliberately the same shape as the lobby's LobbyStations (findStation / promptHost / bounding-box
-- reach), and it finds the station by the SAME `Station` attribute, so the two places stay greppable
-- together. This is the first thing in the game tree to read that attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Theme is tokens only (no instances), safe on the server; keeps asset ids out of this file
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local STATION = "RobuxShop"
local TITLE = "ROBUX SHOP"

-- client opens the panel on this event (fired to the triggering player)
local openRemote = Instance.new("RemoteEvent")
openRemote.Name = "OpenRobuxShop"
openRemote.Parent = ReplicatedStorage

local function findStation(kind: string): Instance?
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:GetAttribute("Station") == kind then
			return d
		end
	end
	return nil
end

-- Where the prompt lives. The editor model carries a dedicated invisible `Anchor` part for exactly this
-- (copied over from the lobby station), so the prompt sits at the counter rather than at the mesh's
-- centroid — which, on a 15 x 18.8 x 20 hut, is somewhere inside the roof.
local function promptHost(inst: Instance): BasePart?
	local a = inst:FindFirstChild("Anchor")
	if a and a:IsA("BasePart") then
		return a
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	if inst:IsA("BasePart") then
		return inst :: BasePart
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

-- The camp is editor content, so it is there from the first frame — but StreamingEnabled and a slow
-- place load can both put this script ahead of it, and the old code already waited 20s on HubSpawn for
-- the same reason. Poll briefly rather than assume.
local station: Instance? = nil
local t0 = os.clock()
repeat
	station = findStation(STATION)
	if station then
		break
	end
	task.wait(0.2)
until os.clock() - t0 > 15

if not station then
	warn(('[StartShop] no editor station with attribute Station="%s" — kiosk prompt NOT attached, the '
		.. "Robux shop is unreachable in this place. Expected Workspace.SpawnBase.Stands.RobuxShop."):format(STATION))
	return
end

local host = promptHost(station)
if not host then
	warn("[StartShop] station " .. station:GetFullName() .. " has no BasePart to host the prompt")
	return
end

-- Size the activation radius to the WHOLE building plus a walk-up margin, measured from the model, so
-- the prompt triggers anywhere around the hut instead of at one exact spot. Same rule as the lobby's.
local reach = 20
if station:IsA("Model") then
	local _, sz = station:GetBoundingBox()
	reach = math.max(math.max(sz.X, sz.Z) / 2 + 10, 20)
end

local dup = host:FindFirstChild("RobuxShopPrompt")
if dup then
	dup:Destroy()
end

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RobuxShopPrompt"
prompt.ActionText = "Open"
prompt.ObjectText = TITLE
prompt.HoldDuration = 0.2
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = reach
prompt.Parent = host

-- §12 juice: the kiosk answers when you walk up to it. Positional on the station itself, so it reads as
-- the building responding rather than a UI blip. Id from Theme.sound — same cue as the lobby kiosks.
local promptSound = Instance.new("Sound")
promptSound.Name = "PromptCue"
promptSound.SoundId = Theme.sound.prompt
promptSound.Volume = 0.4
promptSound.RollOffMode = Enum.RollOffMode.InverseTapered
promptSound.RollOffMinDistance = 6
promptSound.RollOffMaxDistance = 45
promptSound.Parent = host

prompt.PromptShown:Connect(function()
	promptSound:Play()
end)

prompt.Triggered:Connect(function(plr: Player)
	openRemote:FireClient(plr, "start")
end)

print(("[StartShop] %s -> %s (reach %.0f)"):format(TITLE, station:GetFullName(), reach))
