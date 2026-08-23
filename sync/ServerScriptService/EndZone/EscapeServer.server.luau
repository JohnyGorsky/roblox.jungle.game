--!strict
-- EscapeServer.server.luau — the extraction endgame (Job #111).
--
-- WHAT THIS REPLACES: the run used to win on DISTANCE — `BoatDistance >= END_DISTANCE` — against a
-- non-colliding gold Neon bar (`RiverBootstrap.placeEnd`) with nothing behind it. The win fired at the
-- river mouth, the boat kept its throttle into unwritten world, and the crew fell to their deaths
-- behind a VICTORY screen. Both the bar and the distance win are gone; the run now ends because the
-- crew is physically EXTRACTED from the end zone.
--
-- The end zone (`Workspace.EndBase`, Job #110) is hand-built content and holds an editor-placed
-- marker at `Objects.Plane.Escape`. This script finds it BY NAME — the same contract every other
-- editor-placed fitting in this game uses — and generates the pad on it, so the editor zone stays
-- pure content with no scripted geometry baked into the place file.
--
--   · Step onto the pad → that player is INVINCIBLE while they wait for the rest of the crew.
--   · Every LIVING crew member aboard → extraction fires immediately.
--   · Majority aboard → anyone on the pad can hold the prompt and leave the stragglers behind.
--
-- On extraction it stamps `Workspace.EscapeReached`. RunServer reads that and runs the existing
-- win → results → return-to-lobby path completely unchanged. Server-authoritative.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

-- ── tuning ──────────────────────────────────────────────────────────────────────────────────────
local PAD_RADIUS = 9 -- horizontal studs from pad centre that count as "aboard" (matches the lobby pads)
local PAD_Y_BELOW, PAD_Y_ABOVE = -3, 10 -- vertical band, so nobody counts from the plane wing overhead
local TICK = 0.25
local HOLD_DURATION = 1.2 -- force-launch prompt hold

-- Trailing protection after stepping OFF. The occupancy loop re-stamps every TICK, so the deadline is
-- always ~this far out while you stand there; leaving simply lets it lapse. A flat "clear it now" would
-- flicker protection on and off for anyone shuffling on the pad edge.
local PAD_GRACE = 2.0
-- Protection through the results screen. RunServer holds that for RETURN_TIMEOUT (30 s) before the
-- teleport, so this only has to outlast that.
local WIN_GRACE = 300

-- ── the editor-placed marker ────────────────────────────────────────────────────────────────────
local endBase = Workspace:WaitForChild("EndBase", 30)
local marker: BasePart? = nil
if endBase then
	local found = endBase:FindFirstChild("Escape", true)
	if found and found:IsA("BasePart") then
		marker = found
	end
end
if not marker then
	warn("[Escape] HALTED — no BasePart named 'Escape' under Workspace.EndBase. "
		.. "The extraction pad is placed on that marker; without it the run has NO win condition.")
	return
end
local anchorPart: BasePart = marker :: BasePart

-- Sit the pad on whatever the crew actually WALKS ON under the marker, not at the marker's own Y — it is
-- a hand-placed 4x1x2 nub floating ~3 studs up, and building there leaves a step nobody can climb.
--
-- ⚠️ "Ground" here is NOT terrain. The first version filtered the raycast to `Workspace.Terrain` on the
-- reasoning that props must not be mistaken for the floor, and that was wrong in the one place it had to
-- be right: the marker sits on the RUNWAY, whose slab top is 3 studs above the terrain beneath it. The
-- pad was built to the terrain and ended up buried in the concrete with only its ring showing.
-- So: cast against everything, excluding only the marker itself and the pad we are about to build.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = { anchorPart }
groundParams.IgnoreWater = true
local padCentre = anchorPart.Position
do
	local hit = Workspace:Raycast(padCentre + Vector3.new(0, 60, 0), Vector3.new(0, -400, 0), groundParams)
	if hit then
		padCentre = Vector3.new(padCentre.X, hit.Position.Y, padCentre.Z)
		print(("[Escape] pad seated on %s at y=%.1f"):format(hit.Instance:GetFullName(), hit.Position.Y))
	else
		warn("[Escape] nothing solid under the Escape marker — building the pad at the marker's own height")
	end
end

-- ── pad geometry (generated, not editor content) ────────────────────────────────────────────────
-- A PART-FOR-PART REPLICA of the lobby's launch pad (`LOBBY_GREYBOX.Stations.PartyPad_*`), measured off
-- the real model rather than eyeballed, so the extraction pad reads as the same object the player
-- already knows how to use. Every offset below is the lobby's, relative to its `Center` plate.
--
-- Two deliberate departures:
--   · GOLD, not the lobby's per-pad identity colour — STYLEGUIDE §4 reserves gold for progression and
--     this pad IS the run's payoff.
--   · a far bigger LIGHT COLUMN. The lobby's is 5 studs across and 3.6 tall because you walk past it
--     indoors; this one is the only wayfinding in the end zone and has to be picked out from the dock
--     219 studs away, through jungle, at any hour of the day/night cycle.
--
-- The lobby's discs are Cylinders laid on their side (a Roblox cylinder's axis runs along X), hence the
-- Z-rotation on every one.
local pad = Instance.new("Model")
pad.Name = "ExtractionPad"

-- Height of the Center plate above the terrain. The lobby stack puts the Base's underside 2.0 below
-- Center, so this seats the Base flush on the ground and leaves the walkable Deck top 1.9 up — the same
-- step the lobby pad has, and comfortably inside what a Humanoid will walk onto without jumping.
local CENTER_Y = 2.0

local function disc(name: string, thickness: number, diameter: number, offset: number, colour: Color3, material: Enum.Material, transparency: number, collide: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter)
	p.CFrame = CFrame.new(padCentre + Vector3.new(0, CENTER_Y + offset, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = collide
	p.Color = colour
	p.Material = material
	p.Transparency = transparency
	p.Parent = pad
	return p
end

--                     name           thick  dia   offset  colour                  material                      transp collide
local base   = disc("Base",        1.40,  22,  -1.30,  Theme.color.metalDark, Enum.Material.DiamondPlate, 0,    true)
disc("Deck",        0.50,  19,  -0.35,  Theme.color.woodDark,  Enum.Material.WoodPlanks,   0,    true)
disc("AccentRing",  0.35,  12,  -0.15,  Theme.color.gold,      Enum.Material.Neon,         0,    false)
local centre = disc("Center",      0.50,   9,   0.00,  Theme.color.metalDark, Enum.Material.Metal,        0,    false)

local column = disc("LightColumn", 34.0,  14,  16.00,  Theme.color.gold,      Enum.Material.Neon,         0.72, false)
column.CastShadow = false

-- eight edge lights on a radius-9 ring, exactly the lobby's spacing
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2
	local e = Instance.new("Part")
	e.Name = "EdgeLight"
	e.Size = Vector3.new(0.7, 0.6, 0.7)
	e.CFrame = CFrame.new(padCentre + Vector3.new(math.cos(a) * 9, CENTER_Y + 0.05, math.sin(a) * 9))
	e.Anchored = true
	e.CanCollide = false
	e.CastShadow = false
	e.Color = Theme.color.gold
	e.Material = Enum.Material.Neon
	e.Parent = pad
end

local glow = Instance.new("PointLight")
glow.Name = "PadGlow"
glow.Color = Theme.color.gold
glow.Brightness = 2.4
glow.Range = 20
glow.Shadows = false
glow.Parent = centre

local fx = Instance.new("Attachment")
fx.Name = "PadFX"
fx.Position = Vector3.new(0.4, 0, 0) -- local +X is UP on a Z-rotated cylinder
fx.Parent = centre
local motes = Instance.new("ParticleEmitter")
motes.Name = "PadMotes"
motes.Rate = 6
motes.Lifetime = NumberRange.new(2, 3.5)
motes.Speed = NumberRange.new(1, 2.5)
motes.Color = ColorSequence.new(Theme.color.gold)
motes.LightEmission = 1
motes.LightInfluence = 0
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
motes.SpreadAngle = Vector2.new(22, 22)
motes.Acceleration = Vector3.new(0, 3, 0)
motes.Rotation = NumberRange.new(0, 360)
-- ⚠️ Right, not Top. The lobby model says Top, but its Center is Z-rotated the same way this one is, so
-- local +X is world-up and Top emits sideways there. Copying that would have copied the bug.
motes.EmissionDirection = Enum.NormalId.Right
motes.Parent = fx

-- ── sign + force-launch prompt ──────────────────────────────────────────────────────────────────
local signAnchor = Instance.new("Part")
signAnchor.Name = "SignAnchor"
signAnchor.Size = Vector3.one
signAnchor.Position = padCentre + Vector3.new(0, 9, 0)
signAnchor.Anchored = true
signAnchor.CanCollide = false
signAnchor.Transparency = 1
signAnchor.Parent = pad

local bb = Instance.new("BillboardGui")
bb.Name = "ExtractionSign"
-- 11 studs wide was too narrow — TextScaled WRAPS before it shrinks, so even a single word like
-- "EXTRACTING…" broke across two lines. 24 then overcorrected: with only one short line to draw,
-- TextScaled grew it to fill the whole box and the sign became a billboard you stand inside. The pair
-- that actually works is a moderate box PLUS a MaxTextSize cap — the cap stops the one-line case from
-- inflating, the width stops the four-line case from wrapping.
bb.Size = UDim2.fromScale(18, 6)
bb.AlwaysOnTop = true
bb.MaxDistance = 260 -- readable from the dock; this is the objective, not clutter
bb.Parent = signAnchor

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Theme.color.panel
label.BackgroundTransparency = 0.2
label.TextColor3 = Theme.color.cream
label.Font = Theme.font.button
label.TextScaled = true
label.RichText = true
label.Text = ""
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Color = Theme.color.wood
stroke.Thickness = 2
stroke.Parent = label
local textCap = Instance.new("UITextSizeConstraint")
textCap.MaxTextSize = 38
textCap.Parent = label
local uipad = Instance.new("UIPadding")
uipad.PaddingTop = UDim.new(0, 6)
uipad.PaddingBottom = UDim.new(0, 6)
uipad.PaddingLeft = UDim.new(0, 8)
uipad.PaddingRight = UDim.new(0, 8)
uipad.Parent = label
label.Parent = bb

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "LaunchPrompt"
prompt.ActionText = "Leave without them"
prompt.ObjectText = "Extraction"
prompt.HoldDuration = HOLD_DURATION
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = PAD_RADIUS + 3
prompt.Enabled = false
prompt.Parent = base

pad.PrimaryPart = base
pad.Parent = Workspace

local function playAtPad(soundKey: string, volume: number)
	local id = (Theme.sound :: { [string]: string })[soundKey]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMaxDistance = 140
	s.Parent = centre
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

-- ── crew state ──────────────────────────────────────────────────────────────────────────────────
local extracted = false

-- A player is LIVING until RunServer marks them Dead (permadeath — they are spectating and can never
-- reach the pad, so counting them would softlock the extraction). A DOWNED player still counts: they
-- are not out yet, and the majority force-launch is the release valve for a crew that cannot revive
-- them in time.
local function living(): { Player }
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("Dead") ~= true then
			out[#out + 1] = plr
		end
	end
	return out
end

local function onPad(plr: Player): boolean
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = root.Position - padCentre
	return Vector3.new(d.X, 0, d.Z).Magnitude <= PAD_RADIUS and d.Y > PAD_Y_BELOW and d.Y < PAD_Y_ABOVE
end

-- ⚠️ `InvincibleUntil` IS SHARED WITH THE REVIVE GRACE (PlayerCombat). Both damage paths — EnemyServer's
-- target selection and ExcursionServer's tickGuard — read this one attribute, which is exactly why the
-- pad reuses it instead of inventing a second flag that those paths would not know to check.
--
-- Two rules keep the two writers from stepping on each other:
--   · never SHORTEN someone else's deadline — take the max, so a fresh 10 s revive grace outlives our
--     2 s rolling stamp;
--   · only clear a deadline WE wrote — compare against the exact value we last stamped, the same guard
--     PlayerCombat uses on its own expiry. Otherwise walking off the pad would cancel a revive grace
--     that had seconds left on it.
local stamped: { [Model]: number } = {}

local function protect(plr: Player, seconds: number)
	local char = plr.Character
	if not char then
		return
	end
	local deadline = Workspace:GetServerTimeNow() + seconds
	local current = (char:GetAttribute("InvincibleUntil") :: number?) or 0
	if deadline > current then
		char:SetAttribute("InvincibleUntil", deadline)
		stamped[char] = deadline
	end
end

local function unprotect(plr: Player)
	local char = plr.Character
	if not char then
		return
	end
	local mine = stamped[char]
	if mine and char:GetAttribute("InvincibleUntil") == mine then
		char:SetAttribute("InvincibleUntil", nil)
	end
	stamped[char] = nil
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterRemoving:Connect(function(char)
		stamped[char] = nil
	end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	plr.CharacterRemoving:Connect(function(char)
		stamped[char] = nil
	end)
end

-- ── extraction ──────────────────────────────────────────────────────────────────────────────────
local function extract(reason: string)
	if extracted then
		return
	end
	extracted = true

	-- Everyone still alive rides the results screen out, including anyone left behind by a force-launch.
	-- A crocodile killing a straggler during the 30 s results countdown would not change the outcome,
	-- but it would be a death animation playing behind a VICTORY panel.
	for _, plr in ipairs(living()) do
		protect(plr, WIN_GRACE)
	end

	prompt.Enabled = false
	label.Text = "<b>EXTRACTING…</b>"
	playAtPad("launch", 0.9)
	print(("[Escape] EXTRACTION — %s"):format(reason))

	Workspace:SetAttribute("EscapeReached", true) -- RunServer owns the results/teleport from here
end

prompt.Triggered:Connect(function(plr)
	if extracted or not onPad(plr) then
		return
	end
	local crew = living()
	local aboard = 0
	for _, p in ipairs(crew) do
		if onPad(p) then
			aboard += 1
		end
	end
	if aboard * 2 > #crew then
		extract(("forced by %s with %d/%d aboard"):format(plr.Name, aboard, #crew))
	end
end)

-- ── occupancy loop ──────────────────────────────────────────────────────────────────────────────
local wasAboard: { [Player]: boolean } = {}

print(("[Escape] extraction pad online at %d, %d, %d (radius %d)")
	:format(padCentre.X, padCentre.Y, padCentre.Z, PAD_RADIUS))

while not extracted do
	local runLive = Workspace:GetAttribute("RunStarted") == true and Workspace:GetAttribute("RunEnded") ~= true
	if runLive then
		local crew = living()
		local aboard: { Player } = {}
		for _, plr in ipairs(crew) do
			if onPad(plr) then
				aboard[#aboard + 1] = plr
				protect(plr, PAD_GRACE)
				if not wasAboard[plr] then
					wasAboard[plr] = true
					playAtPad("joinPad", 0.5)
				end
			elseif wasAboard[plr] then
				wasAboard[plr] = nil
				unprotect(plr)
			end
		end

		local n, total = #aboard, #crew
		local canForce = total > 1 and n > 0 and n * 2 > total and n < total
		prompt.Enabled = canForce

		if total > 0 and n >= total then
			extract(("full crew aboard (%d/%d)"):format(n, total))
		else
			local names = {}
			for i, plr in ipairs(aboard) do
				names[i] = "• " .. plr.DisplayName
			end
			local status = if n == 0
				then "Step onto the pad"
				elseif canForce then "Hold to leave without them"
				else "Waiting for the crew"
			label.Text = ("<b>EXTRACTION</b>\n%d/%d aboard\n%s\n%s"):format(n, total, table.concat(names, "\n"), status)
		end
	else
		prompt.Enabled = false
		label.Text = "<b>EXTRACTION</b>\nReach this pad to escape"
	end
	task.wait(TICK)
end
