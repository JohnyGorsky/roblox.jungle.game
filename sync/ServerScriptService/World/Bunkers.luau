--!strict
-- Bunkers.luau — the locked bunker: doors, status lamp, alarm, and the crew's share of the gold
-- (Job #116). SERVER ONLY, and deliberately REUSABLE in the same shape as `Generators.luau`: the end
-- zone's bunker is wired by `BunkerServer.server.luau`, and a later job that spawns bunkers in a camp or
-- a ruin gets identical behaviour for free.
--
-- ── The loop it exists to close ──────────────────────────────────────────────────────────────────
-- Job #115 made the three end-zone generators destructible and left one seam behind on purpose:
-- `Generators.onDisabled(fn)` plus a per-model `Disabled` attribute, so that "wiring the bunker doors to
-- them" would need no new code in the combat path. This is that wiring. Nothing here touches
-- MeleeServer/WeaponServer/GunServer, and nothing here polls: a bunker reacts to its keys going down.
--
--     kill every generator  →  alarm + lamp turns green  →  doors slide 10 s into the ground  →  loot
--
-- ── ⚠️ A BUNKER IS NOT FOUND BY NAME ────────────────────────────────────────────────────────────
-- Three nested instances in the end zone are called `Bunker`: a Folder, the Model inside it, and the
-- shell MeshPart inside that. `Generators`' "name prefix" contract would match all three and the
-- AssetLibrary template besides. So the signature here is STRUCTURAL — *a Model that has a `BunkerDoors`
-- child*. That is also the one thing a spawned bunker cannot be missing, since it is the thing that moves.
--
-- ── ⚠️ EVERY OFFSET IS DERIVED FROM THE MODEL'S OWN BOUNDS ───────────────────────────────────────
-- The library holds `Structures.BunkerDoors` at 34 x 26.73 x 14.14 and the end zone's placed copy at
-- exactly HALF that (17 x 13.36 x 7.07) — the same half-scale trap `Generator3` sprang on Job #115. So
-- the door travel, the lamp size, the light range and the loot layout are all read off `GetBoundingBox`
-- at attach time. There is not one hard-coded stud offset below, and there must never be.
--
-- ── ⚠️ THE DOORS MODEL MUST NEVER BE GIVEN A PrimaryPart ─────────────────────────────────────────
-- A Model's PrimaryPart silently overrides its `WorldPivot`, so `GetPivot` would start answering from a
-- different reference point than the one measured at attach and the 10-second tween would move the doors
-- to the wrong place. `Generators.attach` sets a PrimaryPart (it needs one for MeleeServer's hit FX);
-- this file deliberately does the opposite.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Library models arrive with pivots up to 107 studs outside their own geometry; this repairs them once
-- per VM. `PivotTo` is how the chest is seated, so it has to run before anything is cloned.
require(ServerScriptService:WaitForChild("World"):WaitForChild("AssetPivots"))

local Generators = require(ServerScriptService:WaitForChild("World"):WaitForChild("Generators"))
local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local RewardFeed = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("RewardFeed"))
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local Bunkers = {}

-- ── the contract other files rely on ────────────────────────────────────────────────────────────
Bunkers.TAG = "Bunker" -- anything tagged is wired; `BunkerServer` listens for it
Bunkers.DOORS_NAME = "BunkerDoors" -- ...and this child is what MAKES a Model a bunker
Bunkers.LAMP_TAG = "BunkerLamp" -- the client pulses these; see `BunkerClient.local.luau`
Bunkers.SHARE_TAG = "BunkerShare" -- ...and enables only the local player's prompt on these
Bunkers.LIBRARY_PATH = { "AssetLibrary", "Structures", "Bunker" } -- under ServerStorage

-- Marker parts the user places inside the bunker model. All optional except the doors: a bunker with no
-- `LightLocation` simply has no lamp rather than failing to wire.
local MARKER = {
	light = "LightLocation",
	chest = "ChestLocation",
	-- `KeyPadLocation` / `NumberLocation` are deliberately untouched — a future keypad mechanic.
}

-- ── tuning ──────────────────────────────────────────────────────────────────────────────────────
Bunkers.OPEN_SECONDS = 10 -- the user's number: "lets say 10 seconds slide down"
Bunkers.GOLD_PER_SHARE = 3 -- for scale: the `finisher` objective pays 5, a rare camp nugget pays 1
Bunkers.SALVAGE_PER_SHARE = 150
local SHARES_PER_ROW = 3 -- the hoard lays out 3 across, then a second row, then a third...
-- ⚠️ A FRACTION OF THE ROOM, NOT A SCALE FACTOR. See `seatChest` — `Model:ScaleTo` is absolute, and
-- `GoldChest` ships from the importer at `GetScale() == 6`, so the obvious `ScaleTo(0.65)` produces an
-- 11%-size toy. Sizing the chest against the headroom the bunker actually has cannot be fooled by that.
local CHEST_HEIGHT_FRACTION = 0.42 -- of the interior headroom → 4.8 studs in the end-zone bunker
local NUGGET_SCALE = 2.2 -- ...so a share reads as a bar (4.4 x 2.8 x 3.1), not the 2-stud pebble it is

-- ── audio (registry `audio.md` → Jungle / GAME place; user upload 2026-08-25) ────────────────────
-- ⚠️ `alarm` is 8.05 s, MEASURED in Studio. That is why it is a one-shot and not a loop: it covers the
-- 10-second slide almost exactly and leaves the doors settling in silence. Looping an 8 s klaxon under a
-- 10 s door would restart it 2 s before the doors land, which reads as a bug rather than an alarm.
local SFX = {
	alarm = "rbxassetid://103190295733089", -- alarm  8.05 s — one-shot, at the moment the doors start down
}
local ALARM_VOLUME = 0.85
-- The furthest key (Generator2) is 155 studs from the doors. Whoever lands the killing blow has to hear
-- the thing they just unlocked, so the tail comfortably outruns the base.
local ALARM_MAX_DISTANCE = 300

-- ── the lamp's signal colours ───────────────────────────────────────────────────────────────────
-- ⚠️ A KNOWING DEPARTURE FROM THE UI PALETTE, recorded so it does not read as an oversight.
-- `Theme.color.red` (#A84B3C) and `.green` (#4B7A2B) are muted panel accents, chosen to sit behind cream
-- text. On a `Neon` bulb they render as dull brick and olive — which is the one thing a status lamp may
-- not be. These are the same hues pushed to signal saturation: the lamp is a physical warning light, not
-- a piece of UI.
local LAMP_RED = Color3.fromRGB(235, 45, 35)
local LAMP_GREEN = Color3.fromRGB(60, 220, 85)

-- ── module state ────────────────────────────────────────────────────────────────────────────────
type DoorPart = { part: BasePart, collide: boolean }
type Rig = {
	model: Model,
	doors: Model,
	doorParts: { DoorPart },
	closedPivot: CFrame,
	travel: number,
	keys: { Model },
	alarm: Sound?,
	bulb: BasePart?,
	light: PointLight?,
	hoard: Folder?,
	open: boolean,
	opening: boolean,
	openToken: number,
}
local rigs: { [Model]: Rig } = {}
local openedListeners: { (Model) -> () } = {}

-- ── helpers ─────────────────────────────────────────────────────────────────────────────────────

local function markerOf(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

-- The doors sub-model. This is the structural signature of a bunker, so a nil here means "not a bunker"
-- rather than "a broken bunker".
local function doorsOf(model: Model): Model?
	local d = model:FindFirstChild(Bunkers.DOORS_NAME)
	if d and d:IsA("Model") then
		return d
	end
	return nil
end

local function firstPart(model: Model): BasePart?
	return model:FindFirstChildWhichIsA("BasePart", true)
end

-- Every `Generator*` Model that sits under the bunker's OWN parent.
--
-- This is the whole "which generators unlock me" contract, and it is deliberately positional rather than
-- configured: the end zone already keeps `Bunker` + `Generator1/2/3` in one folder, and a spawner that
-- drops a bunker and its keys into one folder inherits the wiring with nothing to fill in. Two bunkers in
-- two folders cannot steal each other's keys, which a proximity search could not promise.
local function siblingKeys(model: Model): { Model }
	local parent = model.Parent
	local out: { Model } = {}
	if not parent then
		return out
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child ~= model and child:IsA("Model") and child.Name:sub(1, #Generators.NAME_PREFIX) == Generators.NAME_PREFIX then
			table.insert(out, child)
		end
	end
	return out
end

-- ⚠️ A key that has left the DataModel counts as DOWN. A generator someone deleted (or that a future
-- spawner culled) can never fire `Disabled`, and a door held shut forever by a prop that no longer exists
-- is a locked run with no way out of it.
local function keyIsDown(key: Model): boolean
	if not key:IsDescendantOf(Workspace) then
		return true
	end
	return key:GetAttribute("Disabled") == true
end

local function keysDown(rig: Rig): number
	local n = 0
	for _, key in ipairs(rig.keys) do
		if keyIsDown(key) then
			n += 1
		end
	end
	return n
end

-- ── the lamp ────────────────────────────────────────────────────────────────────────────────────
-- Built here so it exists for every viewer and survives streaming; PULSED on the client
-- (`BunkerClient.local.luau`), because a server-side tween replicates two changing properties every
-- frame, forever, per bunker — for a light whose whole job is to blink.
-- How far off the marker the bulb has to sit before a player standing outside can actually SEE it.
--
-- ⚠️ THIS IS NOT DEFENSIVE PADDING, IT IS A MEASURED FIX. Seated exactly on the user's marker, the
-- end-zone bulb sits under the bunker's projecting roof lip: line-of-sight from a player at the door
-- (10–30 studs out, eye height at the threshold) is BLOCKED, and all you see is a red pool on the sand
-- with no lamp attached to it — verified from a Play screenshot at the player's own camera. A status
-- light you cannot see is not a status light.
--
-- So the offset is searched for against the bunker's own geometry rather than typed in, which also means
-- a differently-shaped bunker gets its own answer instead of this one's.
local function lampOffset(rig: Rig, marker: BasePart): number
	local doorPart = rig.doorParts[1] and rig.doorParts[1].part
	if not doorPart then
		return 0
	end
	local outward = -marker.CFrame.LookVector -- the marker faces INTO the building
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { rig.model }
	params.RespectCanCollide = true

	-- `closedPivot.Y` is the door's own bottom edge — i.e. the threshold the crew walks over — so
	-- "+2" is a standing player's eye without a single hard-coded world height.
	local eyeY = rig.closedPivot.Position.Y + 2
	local needed, blind = 0, false
	for _, dist in ipairs({ 10, 18, 30 }) do
		local ahead = doorPart.Position + doorPart.CFrame.LookVector * dist
		local eye = Vector3.new(ahead.X, eyeY, ahead.Z)
		local found: number? = nil
		for step = 0, 12 do
			local push = step * 0.5
			local target = marker.Position + outward * push
			if not Workspace:Raycast(eye, target - eye, params) then
				found = push
				break
			end
		end
		if found then
			needed = math.max(needed, found)
		else
			blind = true
		end
	end
	if blind then
		warn(("[Bunker] %s: the lamp at `%s` has no line of sight from the door within 6 studs — "
			.. "it will read as a glow rather than a lamp. Move the marker clear of the roof line."):format(
			rig.model:GetFullName(), marker.Name))
	end
	return needed
end

local function buildLamp(rig: Rig, marker: BasePart)
	local unit = math.max(marker.Size.X, marker.Size.Y, marker.Size.Z)
	local push = lampOffset(rig, marker)
	local outward = -marker.CFrame.LookVector

	-- A dark plate on the wall, at the marker itself — the mount stays where the user put it even when
	-- the bulb has to stand off it.
	local housing = Instance.new("Part")
	housing.Name = "LampHousing"
	housing.Size = Vector3.new(unit * 1.25, unit * 0.5, unit * 1.25)
	housing.CFrame = marker.CFrame * CFrame.new(0, 0, unit * 0.45)
	housing.Anchored = true
	housing.CanCollide = false
	housing.CanQuery = false
	housing.CanTouch = false
	housing.Color = Theme.color.metalDark
	housing.Material = Enum.Material.DiamondPlate
	housing.Parent = marker

	-- ...and a bracket bridging the gap, so a stood-off bulb reads as mounted on an arm rather than
	-- floating in front of the wall. Skipped when the bulb sits flush, where an arm would be a stub.
	if push >= 0.4 then
		local arm = Instance.new("Part")
		arm.Name = "LampArm"
		arm.Size = Vector3.new(unit * 0.22, unit * 0.22, push)
		arm.CFrame = CFrame.lookAt(marker.Position + outward * (push / 2), marker.Position + outward)
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.Color = Theme.color.metalDark
		arm.Material = Enum.Material.Metal
		arm.Parent = marker
	end

	local bulb = Instance.new("Part")
	bulb.Name = "LampBulb"
	bulb.Shape = Enum.PartType.Ball
	bulb.Size = Vector3.new(unit * 0.9, unit * 0.9, unit * 0.9)
	bulb.CFrame = marker.CFrame + outward * push
	bulb.Anchored = true
	bulb.CanCollide = false
	bulb.CanQuery = false
	bulb.CanTouch = false
	bulb.Material = Enum.Material.Neon
	bulb.Color = LAMP_RED

	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = LAMP_RED
	light.Brightness = 4
	-- ⚠️ 7 units, not 9. At 9 (18 studs here) the pool reached the ground and washed the ENTIRE 37-stud
	-- facade — screenshotted in Play, red when locked and green when open, which is the "lit evenly"
	-- failure STYLEGUIDE §8 forbids ("small pools of light"). The bulb is `Neon`, so what carries at
	-- distance is the bulb itself; the light only has to prove it is a lamp and not a sticker.
	light.Range = math.clamp(unit * 7, 8, 30)
	light.Shadows = false
	light.Enabled = true
	-- ⚠️ NOT tagged `NightLight`. This is a status readout, not a practical: `LightController` switches
	-- every `NightLight` off at dawn, and a lock indicator that only works after 17:30 is not one.
	light.Parent = bulb

	-- The client reads this ONE attribute to pick red-urgent or green-calm. Set on the bulb rather than
	-- the bunker so the client never has to walk up the tree from a tagged instance.
	bulb:SetAttribute("Open", false)

	-- ⚠️ PARENT LAST, TAG AFTER. The client's handler reaches straight for the bulb's `PointLight`, so the
	-- bulb has to arrive with the light already inside it — an instance parented into the world before its
	-- children replicates on its own, and the handler would fire on a lamp that has no light yet.
	bulb.Parent = marker
	CollectionService:AddTag(bulb, Bunkers.LAMP_TAG)

	rig.bulb = bulb
	rig.light = light
end

local function paintLamp(rig: Rig, open: boolean)
	local colour = if open then LAMP_GREEN else LAMP_RED
	if rig.bulb then
		rig.bulb.Color = colour
		rig.bulb.Transparency = 0
		rig.bulb:SetAttribute("Open", open)
	end
	if rig.light then
		rig.light.Color = colour
		rig.light.Brightness = 4
	end
end

-- ── the loot ────────────────────────────────────────────────────────────────────────────────────

local function libraryModel(path: { string }): Instance?
	local node: Instance? = ServerStorage
	for _, step in ipairs(path) do
		node = node and node:FindFirstChild(step)
	end
	return node
end

-- Floor under `pos`, measured against the BUNKER'S OWN geometry.
--
-- ⚠️ Not terrain. The interior floor here is the shell mesh at y 22.10 while the terrain under the whole
-- structure is at 18.00 — a terrain-filtered cast would bury the hoard four studs under the floor the
-- crew walks on. Same mistake `EscapeServer` made with the runway, and its comment says so.
local function floorUnder(model: Model, pos: Vector3, up: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true -- the four invisible marker parts are CanCollide off; skip them
	local hit = Workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -(up + 30), 0), params)
	return hit and hit.Position.Y or nil
end

-- Is this slot standing inside the bunker's geometry rather than on it?
local function slotBlocked(model: Model, pos: Vector3, size: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local parts = Workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0, size * 0.6, 0)), Vector3.new(size, size, size), params)
	return #parts > 0
end

-- Build the hoard: the chest as the thing you see when the doors drop, and one named share per crew member.
--
-- ⚠️ EVERY SLOT IS VALIDATED, not computed and trusted. The clear direction inside this bunker is FORWARD,
-- toward the doors (40+ studs), against 6.86 studs to the right wall and 7.62 behind the chest — so a
-- slot that lands in geometry is nudged toward the doors rather than left inside a wall.
local function buildHoard(rig: Rig)
	if rig.hoard then
		return
	end
	local model = rig.model
	local marker = markerOf(model, MARKER.chest)
	if not marker then
		warn(("[Bunker] %s has no `%s` — the doors open onto an empty room"):format(model:GetFullName(), MARKER.chest))
		return
	end

	local doorPart = rig.doorParts[1] and rig.doorParts[1].part
	if not doorPart then
		return
	end

	local hoard = Instance.new("Folder")
	hoard.Name = "BunkerHoard"
	hoard.Parent = model
	rig.hoard = hoard

	-- Face the chest at the doors, and take "forward"/"right" from that same frame so the layout below
	-- cannot disagree with the way the chest is pointing.
	local base = marker.Position
	local floorY = floorUnder(model, base, 8) or base.Y
	local flat = Vector3.new(doorPart.Position.X - base.X, 0, doorPart.Position.Z - base.Z)
	local toDoors = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(Vector3.new(base.X, floorY, base.Z), Vector3.new(base.X, floorY, base.Z) + toDoors)

	-- ── the chest: dressing only, no prompt, no gold ───────────────────────────────────────────
	local chestDepth = 6 -- fallback if the library is missing; overwritten from the real bounds below
	local template = libraryModel({ "AssetLibrary", "Props", "GoldChest" })
	if template and template:IsA("Model") then
		local chest = (template :: Model):Clone()
		chest.Name = "GoldChest"
		chest:ScaleTo(CHEST_SCALE)
		local _, size = chest:GetBoundingBox()
		chestDepth = size.Z
		chest:PivotTo(frame * CFrame.new(0, size.Y / 2, 0))
		for _, d in ipairs(chest:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		chest.Parent = hoard
	else
		warn("[Bunker] ServerStorage.AssetLibrary.Props.GoldChest is missing — no hero prop, shares only")
	end

	-- ── the shares: one per player IN THE SERVER, reserved by UserId ───────────────────────────
	-- Not "per living player": this game revives, and a pile stranded because its owner happened to be
	-- downed in the second the doors opened is not what "each gold is for each player" means. A pile
	-- whose owner LEAVES is destroyed instead — see `Players.PlayerRemoving` at the bottom of this file.
	local nuggetTemplate = libraryModel({ "AssetLibrary", "Props", "GoldNugget" })
	if not (nuggetTemplate and nuggetTemplate:IsA("BasePart")) then
		warn("[Bunker] ServerStorage.AssetLibrary.Props.GoldNugget is missing — NO SHARES SPAWNED")
		return
	end

	local crew = Players:GetPlayers()
	local colGap = 4.2
	local rowGap = 4.2
	local firstRow = chestDepth / 2 + 2.5

	for i, player in ipairs(crew) do
		local col = ((i - 1) % SHARES_PER_ROW) - (SHARES_PER_ROW - 1) / 2
		local row = math.floor((i - 1) / SHARES_PER_ROW)
		local forward = firstRow + row * rowGap

		-- Validate the footprint, then nudge toward the doors (the only clear direction) if it is bad.
		local found: Vector3? = nil
		for attempt = 0, 3 do
			local try = (frame * CFrame.new(col * colGap, 0, forward + attempt * 3)).Position
			local y = floorUnder(model, try, 6)
			if y and not slotBlocked(model, Vector3.new(try.X, y, try.Z), 2.5) then
				found = Vector3.new(try.X, y, try.Z)
				break
			end
		end
		if not found then
			warn(("[Bunker] share %d for %s had no clear slot — seated at the chest line"):format(i, player.Name))
		end
		-- Never drop a player's share silently: an unplaceable slot falls back to the chest's own floor
		-- line, which is measured ground, and the warning above says it happened.
		local pos: Vector3 = found or (frame * CFrame.new(col * colGap, 0, forward)).Position

		local nug = (nuggetTemplate :: BasePart):Clone()
		nug.Name = "GoldShare"
		nug.Size = nug.Size * NUGGET_SCALE
		nug.Anchored = true
		-- A collidable pebble underfoot is a trip hazard and it is collected by prompt anyway — the same
		-- call `ExcursionServer` made for the camp nugget.
		nug.CanCollide = false
		-- Seated ON the measured slot floor, wearing the chest's facing plus a deterministic per-slot yaw.
		-- Varied so six identical meshes do not read as a shop display; not random, because a rebuild
		-- after a run reset should look like the same room.
		nug.CFrame = CFrame.new(pos + Vector3.new(0, nug.Size.Y / 2, 0))
			* (frame - frame.Position)
			* CFrame.Angles(0, math.rad(i * 37), 0)
		nug:SetAttribute("OwnerUserId", player.UserId)

		local gui = Instance.new("BillboardGui")
		gui.Name = "ShareLabel"
		gui.Adornee = nug
		gui.Size = UDim2.fromOffset(150, 26)
		gui.StudsOffsetWorldSpace = Vector3.new(0, nug.Size.Y / 2 + 1.8, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 60
		gui.Parent = nug

		local label = Instance.new("TextLabel")
		label.Name = "Owner"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Theme.font.button
		label.TextScaled = true
		label.TextColor3 = Theme.color.gold
		label.TextStrokeColor3 = Theme.color.stroke
		label.TextStrokeTransparency = 0.15 -- readable with no panel behind it
		label.Text = ("%s's share"):format(player.DisplayName)
		label.Parent = gui

		-- ⚠️ DISABLED ON THE SERVER ON PURPOSE. `ProximityPrompt.Enabled` is one replicated property, so
		-- the server cannot show a prompt to one player and hide it from five. `BunkerClient.local.luau`
		-- enables only the local player's own share — so you walk in and exactly one pile offers itself.
		-- The ownership check below is the authority; the client toggle is only presentation.
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SharePrompt"
		prompt.ActionText = "Take Your Share"
		prompt.ObjectText = ("%d Gold"):format(Bunkers.GOLD_PER_SHARE)
		prompt.HoldDuration = 0.6
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.Enabled = false
		prompt.Parent = nug

		-- ⚠️ PARENTED INTO THE WORLD LAST, TAGGED AFTER THAT. The client handler reaches for this share's
		-- prompt the instant the tag arrives; parenting the bare mesh first would replicate a pile whose
		-- prompt does not exist yet, and the owner's share would silently never light up.
		nug.Parent = hoard
		-- The bunker is dark inside; `LootGlow` outlines anything tagged `Lootable` in gold, which is
		-- exactly the affordance six small bars on a concrete floor need.
		CollectionService:AddTag(nug, "Lootable")
		CollectionService:AddTag(nug, Bunkers.SHARE_TAG)

		prompt.Triggered:Connect(function(who: Player)
			if not nug.Parent then
				return
			end
			if who.UserId ~= player.UserId then
				return -- server is the authority; a client that force-enabled the prompt gets nothing
			end
			nug:Destroy()
			if Profiles.isReady(who) then
				Profiles.addGold(who, Bunkers.GOLD_PER_SHARE)
			end
			who:SetAttribute("Salvage", ((who:GetAttribute("Salvage") :: number?) or 0) + Bunkers.SALVAGE_PER_SHARE)
			-- Two rewards, two lines — Job #109's rule. The Gold is the rare half and must not be
			-- swallowed by the Salvage.
			RewardFeed.notify(who, "gold", "Gold", Bunkers.GOLD_PER_SHARE)
			RewardFeed.notify(who, "salvage", "Salvage", Bunkers.SALVAGE_PER_SHARE)

			-- Crew news: the hoard is a shared objective even though the shares are not. Fired only if the
			-- feed exists, so this file never becomes a reason `ExcursionServer` has to have booted first.
			local crewToast = ReplicatedStorage:FindFirstChild("CrewToast")
			if crewToast and crewToast:IsA("RemoteEvent") then
				crewToast:FireAllClients({
					icon = "coin",
					text = ("%s took their share of the bunker gold"):format(who.DisplayName),
					detail = ("+%d"):format(Bunkers.GOLD_PER_SHARE),
				})
			end
			print(("[Bunker] %s claimed %d Gold + %d Salvage"):format(who.Name, Bunkers.GOLD_PER_SHARE, Bunkers.SALVAGE_PER_SHARE))
		end)
	end

	print(("[Bunker] hoard placed: 1 chest + %d named share(s)"):format(#crew))
end

-- ── opening and closing ─────────────────────────────────────────────────────────────────────────

local function setDoorsCollide(rig: Rig, on: boolean)
	for _, entry in ipairs(rig.doorParts) do
		-- Restore each part's ORIGINAL setting rather than blanket-true: a door model may legitimately
		-- carry a non-colliding detail part, and a blanket restore would make it solid.
		entry.part.CanCollide = on and entry.collide or false
	end
end

function Bunkers.open(model: Model): boolean
	local rig = rigs[model]
	if not rig or rig.open or rig.opening then
		return false
	end
	rig.opening = true
	rig.openToken += 1
	local mine = rig.openToken

	-- TWO attributes, because they are two different facts and something will eventually need both:
	-- `Unlocked` flips NOW (the alarm is sounding, the lamp is green, the doors are moving) and
	-- `DoorsOpen` flips in 10 seconds, when you can actually walk through.
	model:SetAttribute("Unlocked", true)
	paintLamp(rig, true)
	if rig.alarm then
		rig.alarm.TimePosition = 0
		rig.alarm:Play()
	end
	-- Placed as the doors begin to drop, so the hoard is REVEALED by them rather than popping in behind
	-- an already-open doorway.
	buildHoard(rig)

	-- One `CFrameValue` driving `PivotTo`, rather than a tween per door part. A future two-leaf door
	-- model then works unchanged, and the model's pivot stays the single reference point.
	local proxy = Instance.new("CFrameValue")
	proxy.Value = rig.closedPivot
	local openPivot = rig.closedPivot - Vector3.new(0, rig.travel, 0)
	local conn = proxy.Changed:Connect(function(cf: CFrame)
		if rig.openToken == mine and rig.doors.Parent then
			rig.doors:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(
		proxy,
		-- Sine/InOut: a blast door this heavy should lean into the drop and settle out of it, not start
		-- and stop at full speed.
		TweenInfo.new(Bunkers.OPEN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = openPivot }
	)
	tween.Completed:Connect(function()
		conn:Disconnect()
		proxy:Destroy()
		if rig.openToken ~= mine then
			return -- a run reset overtook this slide; `close` already put the doors back
		end
		rig.doors:PivotTo(openPivot)
		setDoorsCollide(rig, false) -- buried, but nothing should be able to bump a slab underground
		rig.open = true
		rig.opening = false
		model:SetAttribute("DoorsOpen", true)
		print(("[Bunker] %s OPEN (dropped %.2f studs over %ds)"):format(model:GetFullName(), rig.travel, Bunkers.OPEN_SECONDS))
		for _, fn in ipairs(openedListeners) do
			task.spawn(fn, model)
		end
	end)
	tween:Play()

	print(("[Bunker] %s UNLOCKED — %d/%d generators down; alarm + doors going down"):format(
		model:GetFullName(), keysDown(rig), #rig.keys))
	return true
end

-- Put the bunker back the way the editor left it. Called at attach ("ensure doors are closed") and on
-- every new run.
function Bunkers.close(model: Model): boolean
	local rig = rigs[model]
	if not rig then
		return false
	end
	rig.openToken += 1 -- orphans any slide in flight; its Completed handler sees the token move and bails
	rig.open = false
	rig.opening = false
	rig.doors:PivotTo(rig.closedPivot)
	setDoorsCollide(rig, true)
	paintLamp(rig, false)
	if rig.alarm then
		rig.alarm:Stop()
	end
	if rig.hoard then
		rig.hoard:Destroy()
		rig.hoard = nil
	end
	model:SetAttribute("Unlocked", false)
	model:SetAttribute("DoorsOpen", false)
	return true
end

local function evaluate(rig: Rig)
	if rig.open or rig.opening then
		return
	end
	if #rig.keys == 0 then
		return -- warned at attach; a bunker with no keys stays shut rather than failing open
	end
	if keysDown(rig) >= #rig.keys then
		Bunkers.open(rig.model)
	end
end

-- ── public API ──────────────────────────────────────────────────────────────────────────────────

function Bunkers.all(): { Model }
	local out = {}
	for model in pairs(rigs) do
		out[#out + 1] = model
	end
	return out
end

function Bunkers.isOpen(model: Instance): boolean
	local rig = rigs[model :: Model]
	return rig ~= nil and rig.open
end

--- How many of this bunker's keys are down, and how many there are. For a HUD or an objective.
function Bunkers.progress(model: Instance): (number, number)
	local rig = rigs[model :: Model]
	if not rig then
		return 0, 0
	end
	return keysDown(rig), #rig.keys
end

--- Called with the model each time a bunker finishes opening.
function Bunkers.onOpened(fn: (Model) -> ())
	table.insert(openedListeners, fn)
end

--- Re-lock every bunker: doors shut, lamp red, hoard gone. Wired to `Workspace.RunStarted` by the boot.
function Bunkers.resetAll(): number
	local n = 0
	for model in pairs(rigs) do
		Bunkers.close(model)
		n += 1
	end
	return n
end

-- Wire ONE bunker. Idempotent, which is what makes the boot scan and the tag-added signal safe to both
-- fire for the same model.
--
-- `keys` overrides the sibling scan — for a spawner that wants a bunker and its generators in different
-- parents.
function Bunkers.attach(model: Model, keys: { Model }?): boolean
	if rigs[model] then
		return false
	end
	local doors = doorsOf(model)
	if not doors then
		return false -- not a bunker; see the header. Silent on purpose: `attachAll` walks every Model.
	end
	local doorPart = firstPart(doors)
	if not doorPart then
		warn(("[Bunker] %s has a `%s` with no BasePart — not wired"):format(model:GetFullName(), Bunkers.DOORS_NAME))
		return false
	end

	-- ⚠️ Measured, never typed. `GetPivot` here and nowhere else, and no PrimaryPart is ever set on the
	-- doors model — see the header. `+0.5` clears the door's top under the interior floor rather than
	-- level with it, so no sliver survives.
	local _, doorBox = doors:GetBoundingBox()
	local closedPivot = doors:GetPivot()
	local travel = doorBox.Y + 0.5

	local doorParts: { DoorPart } = {}
	for _, d in ipairs(doors:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(doorParts, { part = d, collide = d.CanCollide })
		end
	end

	local rig: Rig = {
		model = model,
		doors = doors,
		doorParts = doorParts,
		closedPivot = closedPivot,
		travel = travel,
		keys = keys or siblingKeys(model),
		alarm = nil,
		bulb = nil,
		light = nil,
		hoard = nil,
		open = false,
		opening = false,
		openToken = 0,
	}
	rigs[model] = rig

	-- ── the alarm, positional on the doors themselves ──────────────────────────────────────────
	local alarm = Instance.new("Sound")
	alarm.Name = "DoorAlarm"
	alarm.SoundId = SFX.alarm
	alarm.Volume = ALARM_VOLUME
	alarm.Looped = false
	alarm.RollOffMode = Enum.RollOffMode.InverseTapered
	alarm.RollOffMinDistance = 15
	alarm.RollOffMaxDistance = ALARM_MAX_DISTANCE
	alarm.Parent = doorPart
	rig.alarm = alarm

	local lightMarker = markerOf(model, MARKER.light)
	if lightMarker then
		buildLamp(rig, lightMarker)
	else
		warn(("[Bunker] %s has no `%s` — no status lamp"):format(model:GetFullName(), MARKER.light))
	end

	-- "Ensure that doors are closed" — asserted, not assumed. The editor copy may have been nudged, and a
	-- re-attach after a reset must land on the same pivot the travel was measured from.
	Bunkers.close(model)

	if #rig.keys == 0 then
		-- ⚠️ Fails CLOSED and says so. A bunker with no keys cannot be opened by play, and silently
		-- opening one would hand the crew the loot for free — the empty slot has to announce itself.
		warn(("[Bunker] %s found NO generators under %s — it can never be opened. "
			.. "Put its `Generator*` models in the same parent, or pass them to `Bunkers.attach`."):format(
			model:GetFullName(), model.Parent and model.Parent:GetFullName() or "nil"))
	end

	-- Two paths into `evaluate`, so boot order between this and `GeneratorServer` cannot matter:
	--   · the hook Job #115 exposed, for keys that die during play;
	--   · a re-read right now, for keys that were already down when we attached.
	Generators.onDisabled(function(dead: Model)
		local mine = false
		for _, key in ipairs(rig.keys) do
			if key == dead then
				mine = true
				break
			end
		end
		if mine then
			print(("[Bunker] %s: %d/%d generators down"):format(model.Name, keysDown(rig), #rig.keys))
			evaluate(rig)
		end
	end)

	model.Destroying:Connect(function()
		rigs[model] = nil
	end)

	-- Added LAST, so nothing can react to a half-built bunker.
	if not CollectionService:HasTag(model, Bunkers.TAG) then
		CollectionService:AddTag(model, Bunkers.TAG)
	end

	evaluate(rig)
	return true
end

-- Wire every bunker under `root`. Returns how many were newly wired.
--
-- ⚠️ Call this on WORKSPACE, never on ServerStorage. `AssetLibrary.Structures.Bunker` matches the same
-- structural signature, and wiring it would give the template a lamp, an alarm and a set of door
-- bookkeeping that every future clone would then arrive carrying.
function Bunkers.attachAll(root: Instance): number
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		-- ⚠️ BOTH must be Models. The doors sub-model contains a MESHPART that is also called
		-- `BunkerDoors`, so a class-blind `FindFirstChild` matches the doors themselves and would try to
		-- wire the doors as if they were a bunker.
		local sub = d:IsA("Model") and d:FindFirstChild(Bunkers.DOORS_NAME) or nil
		if sub and sub:IsA("Model") then
			if Bunkers.attach(d :: Model) then
				n += 1
			end
		end
	end
	return n
end

-- Clone a bunker out of the AssetLibrary, place it, and wire it. The entry point for a later spawner.
--
-- `keys` is optional: leave it nil and drop the bunker into a folder that already holds its generators,
-- and the sibling contract does the rest.
function Bunkers.spawn(cframe: CFrame, parent: Instance?, scale: number?, keys: { Model }?): Model?
	local node = libraryModel(Bunkers.LIBRARY_PATH)
	if not (node and node:IsA("Model")) then
		warn(("[Bunker] ServerStorage.%s is missing — cannot spawn"):format(table.concat(Bunkers.LIBRARY_PATH, ".")))
		return nil
	end

	local clone = (node :: Model):Clone()
	clone.Name = "Bunker"
	-- Order matters: scale and place FIRST, attach second. `attach` measures the door pivot and its
	-- travel, and both are wrong if the model moves afterwards.
	if scale and scale ~= 1 then
		clone:ScaleTo(scale)
	end
	clone:PivotTo(cframe)
	clone.Parent = parent or Workspace
	Bunkers.attach(clone, keys)
	return clone
end

-- A share belongs to one player. If they leave, it is dead weight: nobody can claim it, and a locked pile
-- with an absent player's name over it reads as a bug. (They cannot come back to the same run.)
Players.PlayerRemoving:Connect(function(player: Player)
	for _, rig in pairs(rigs) do
		local hoard = rig.hoard
		if hoard then
			for _, share in ipairs(hoard:GetChildren()) do
				if share:GetAttribute("OwnerUserId") == player.UserId then
					share:Destroy()
				end
			end
		end
	end
end)

return Bunkers
