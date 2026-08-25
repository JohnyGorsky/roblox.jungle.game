--!strict
-- BunkerClient.local.luau — the two halves of the bunker that only make sense per viewer (Job #116).
--
-- Both of these could have been done on the server, and both would have been worse there:
--
-- ── 1. THE STATUS LAMP'S PULSE ───────────────────────────────────────────────────────────────────
-- A server-side tween on a blinking light replicates two CHANGING properties every frame, forever, for
-- every bunker in the world. An attribute flip replicates once. So the server builds the lamp (it must
-- exist for everyone, and survive streaming) and stamps `Open` on the bulb; the pulse itself is local.
-- Same split `LootGlow.local.luau` makes, for the same reason.
--
-- ── 2. WHOSE GOLD IS WHOSE ───────────────────────────────────────────────────────────────────────
-- `ProximityPrompt.Enabled` is ONE replicated property. The server physically cannot show a prompt to one
-- player and hide it from the other five — so it ships every share disabled, and this enables only the
-- one carrying the local player's `OwnerUserId`. You walk into the bunker, see the whole crew's shares
-- labelled, and exactly one of them offers itself to you.
--
-- ⚠️ THIS IS PRESENTATION, NOT AUTHORITY. `Bunkers.luau` re-checks the owner inside `Triggered` and pays
-- nobody else, so a client that force-enables every prompt gets six refusals and no gold.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LAMP_TAG = "BunkerLamp"
local SHARE_TAG = "BunkerShare"

local player = Players.LocalPlayer

-- ── the lamp ────────────────────────────────────────────────────────────────────────────────────
-- Locked reads as URGENT and open reads as SETTLED, which is the whole point of a two-state lamp: you
-- should be able to tell across the base which one it is without reading the colour, from the rhythm
-- alone. (Colour-blind players get the cadence; everyone else gets both.)
local LOCKED = { period = 0.7, dimTransparency = 0.55, dimBrightness = 0.6 }
local OPEN = { period = 1.7, dimTransparency = 0.35, dimBrightness = 1.4 }
local BRIGHT = 4

local pulses: { [BasePart]: { Tween } } = {}

local function stop(bulb: BasePart)
	local running = pulses[bulb]
	if running then
		for _, t in ipairs(running) do
			t:Cancel()
		end
		pulses[bulb] = nil
	end
end

local function pulse(bulb: BasePart)
	stop(bulb)
	if not bulb:IsDescendantOf(workspace) then
		return
	end
	local shape = if bulb:GetAttribute("Open") == true then OPEN else LOCKED
	-- Reverses + RepeatCount -1 is the whole animation: two tweens, no Heartbeat, no per-frame work on
	-- the client either.
	local info = TweenInfo.new(shape.period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

	local made: { Tween } = {}
	bulb.Transparency = 0
	local bulbTween = TweenService:Create(bulb, info, { Transparency = shape.dimTransparency })
	bulbTween:Play()
	table.insert(made, bulbTween)

	local light = bulb:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Brightness = BRIGHT
		local lightTween = TweenService:Create(light, info, { Brightness = shape.dimBrightness })
		lightTween:Play()
		table.insert(made, lightTween)
	end
	pulses[bulb] = made
end

local function watchLamp(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local bulb = inst :: BasePart
	pulse(bulb)
	-- The server flips this the moment the alarm fires, so the lamp goes green as the doors start down
	-- rather than when they finish — which is what makes the green mean "you did it", not "you may enter".
	bulb:GetAttributeChangedSignal("Open"):Connect(function()
		pulse(bulb)
	end)
	bulb.Destroying:Connect(function()
		stop(bulb)
	end)
end

for _, inst in ipairs(CollectionService:GetTagged(LAMP_TAG)) do
	watchLamp(inst)
end
CollectionService:GetInstanceAddedSignal(LAMP_TAG):Connect(watchLamp)
CollectionService:GetInstanceRemovedSignal(LAMP_TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		stop(inst :: BasePart)
	end
end)

-- ── whose gold is whose ─────────────────────────────────────────────────────────────────────────
local function claimShare(inst: Instance)
	if inst:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
end

for _, inst in ipairs(CollectionService:GetTagged(SHARE_TAG)) do
	claimShare(inst)
end
CollectionService:GetInstanceAddedSignal(SHARE_TAG):Connect(claimShare)
