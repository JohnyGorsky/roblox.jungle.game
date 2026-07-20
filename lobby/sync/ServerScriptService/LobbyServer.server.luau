--!strict
-- LobbyServer.server.luau — LOBBY party/launch + reserved teleport (Job 017; REWIRED Job 064).
--
-- The lobby world is EDITOR-PLACED (memory: lobby-editor-placed-not-scripted). This script NO LONGER
-- builds ground/runway/hangar/spawn/pads. It FINDS the editor launch pads (Models with attribute
-- Station = "PartyPad") and drives the party → countdown → reserved-server teleport on them. The spawn
-- is the editor SpawnLocation. ALL matchmaking/teleport logic is unchanged from the original.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local MAX = LobbyConfig.MAX_PER_PAD
local COUNTDOWN = LobbyConfig.COUNTDOWN
local GAME_PLACE = LobbyConfig.GAMEPLAY_PLACE_ID

local rng = Random.new()
local PAD_RADIUS = 9 -- how close a player must stand to count as "on" the editor pad

type Pad = {
	index: number,
	part: BasePart,
	prompt: ProximityPrompt,
	label: TextLabel,
	occupants: { Player },
	launching: boolean,
	countdown: number,
}

-- ── find the editor launch pads (Station="PartyPad"), stable order by name ──────────────────────
local function findPadParts(): { BasePart }
	local models = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:GetAttribute("Station") == "PartyPad" then
			table.insert(models, d)
		end
	end
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	local parts = {}
	for _, m in ipairs(models) do
		local p = m:FindFirstChild("Center")
			or m:FindFirstChild("Anchor")
			or (m:IsA("Model") and m.PrimaryPart)
			or m:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	return parts
end

local padParts: { BasePart } = {}
local t0 = os.clock()
repeat
	padParts = findPadParts()
	if #padParts > 0 then
		break
	end
	task.wait(0.2)
until os.clock() - t0 > 15
if #padParts == 0 then
	warn('[Lobby] no editor launch pads (Station="PartyPad") found — party system offline')
	return
end

local pads: { Pad } = {}

local function makePad(index: number, part: BasePart): Pad
	-- floating sign above the pad (runtime UI attachment, not geometry)
	local signPart = part:FindFirstChild("PadSignAnchor") :: BasePart?
	if not signPart then
		local s = Instance.new("Part")
		s.Name = "PadSignAnchor"
		s.Anchored = true
		s.CanCollide = false
		s.Transparency = 1
		s.Size = Vector3.one
		s.Position = part.Position + Vector3.new(0, 7, 0)
		s.Parent = part
		signPart = s
	end
	local oldBB = signPart:FindFirstChild("PadSign")
	if oldBB then
		oldBB:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadSign"
	bb.Size = UDim2.fromScale(9, 6)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	bb.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.RichText = true
	label.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local pad2 = Instance.new("UIPadding")
	pad2.PaddingTop = UDim.new(0, 6)
	pad2.PaddingBottom = UDim.new(0, 6)
	pad2.PaddingLeft = UDim.new(0, 8)
	pad2.PaddingRight = UDim.new(0, 8)
	pad2.Parent = label
	label.Parent = bb

	local existing = part:FindFirstChild("StartPrompt")
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartPrompt"
	prompt.ActionText = "Start Expedition"
	prompt.ObjectText = "Launch Pad " .. index
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Enabled = false
	prompt.Parent = part

	return { index = index, part = part, prompt = prompt, label = label, occupants = {}, launching = false, countdown = 0 }
end

local function updateSign(pad: Pad)
	local names = {}
	for i, plr in ipairs(pad.occupants) do
		names[i] = (if i == 1 then "★ " else "• ") .. plr.DisplayName
	end
	local status: string
	if pad.launching then
		status = "<b>Launching in " .. pad.countdown .. "…</b>"
	elseif #pad.occupants == 0 then
		status = "Step on to join"
	else
		status = "Leader: hold Start"
	end
	pad.label.Text =
		string.format("<b>LAUNCH PAD %d</b>\n%d/%d\n%s\n%s", pad.index, #pad.occupants, MAX, table.concat(names, "\n"), status)
	pad.prompt.Enabled = (#pad.occupants > 0) and not pad.launching
end

-- true if a player's character is standing on this pad
local function onPad(player: Player, pad: Pad): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = root.Position - pad.part.Position
	return (Vector3.new(d.X, 0, d.Z)).Magnitude <= PAD_RADIUS and d.Y > -3 and d.Y < 10
end

local function removeFromAll(player: Player)
	for _, pad in ipairs(pads) do
		local idx = table.find(pad.occupants, player)
		if idx then
			table.remove(pad.occupants, idx)
			updateSign(pad)
		end
	end
end

-- ── launch ──────────────────────────────────────────────────────────────────────────────────
local function launch(pad: Pad)
	local group = table.clone(pad.occupants)
	if #group == 0 then
		return
	end
	if GAME_PLACE <= 0 then
		warn("[Lobby] set LobbyConfig.GAMEPLAY_PLACE_ID — cannot teleport yet (Studio/placeholder).")
		return
	end
	local okCode, code = pcall(function()
		return TeleportService:ReserveServerAsync(GAME_PLACE)
	end)
	if not okCode then
		warn("[Lobby] ReserveServerAsync failed: " .. tostring(code))
		return
	end
	local members = {}
	for _, p in group do
		table.insert(members, p.UserId)
	end
	local opt = Instance.new("TeleportOptions")
	opt.ReservedServerAccessCode = code
	opt:SetTeleportData({
		seed = rng:NextInteger(1, 2147483646),
		partySize = #group,
		members = members,
	})
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(GAME_PLACE, group, opt)
		end)
		if ok then
			return
		end
		warn("[Lobby] TeleportAsync attempt " .. attempt .. " failed: " .. tostring(err))
		task.wait(1)
	end
end

local function startCountdown(pad: Pad, leader: Player)
	if pad.launching then
		return
	end
	if pad.occupants[1] ~= leader then
		return -- leader only (server-authoritative)
	end
	pad.launching = true
	task.spawn(function()
		for c = COUNTDOWN, 1, -1 do
			pad.countdown = c
			updateSign(pad)
			if #pad.occupants == 0 then
				pad.launching = false
				updateSign(pad)
				return
			end
			task.wait(1)
		end
		if #pad.occupants == 0 then
			pad.launching = false
			updateSign(pad)
			return
		end
		launch(pad)
		pad.launching = false
		updateSign(pad)
	end)
end

for i, part in ipairs(padParts) do
	local pad = makePad(i, part)
	pad.prompt.Triggered:Connect(function(player: Player)
		startCountdown(pad, player)
	end)
	updateSign(pad)
	pads[i] = pad
end

-- ── occupancy tick (order = arrival; occupants[1] = leader) ─────────────────────────────────
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.3 then
		return
	end
	acc = 0
	for _, pad in ipairs(pads) do
		local changed = false
		for i = #pad.occupants, 1, -1 do
			local plr = pad.occupants[i]
			if plr.Parent == nil or not onPad(plr, pad) then
				table.remove(pad.occupants, i)
				changed = true
			end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if onPad(plr, pad) and not table.find(pad.occupants, plr) then
				table.insert(pad.occupants, plr)
				changed = true
			end
		end
		if changed then
			updateSign(pad)
		end
	end
end)

Players.PlayerRemoving:Connect(removeFromAll)

print(("[Lobby] party system bound to %d editor launch pads (gameplay place = %s)"):format(#pads, GAME_PLACE > 0 and tostring(GAME_PLACE) or "NOT SET"))
