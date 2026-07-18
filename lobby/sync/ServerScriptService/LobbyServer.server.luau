--!strict
-- LobbyServer.server.luau — the LOBBY place: greybox airfield + launch-pad party + reserved teleport (Job 017).
--
-- Players spawn in the lobby, step onto one of N launch PADS to form a party (first on an empty pad = the
-- LEADER), and the leader presses Start → a short countdown → the whole pad group is teleported TOGETHER
-- into one private RESERVED gameplay server. Server-authoritative. Greybox (art later). Teleport only runs
-- LIVE (not in Studio) — with a placeholder Place ID it logs a warning and unlocks instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local PAD_COUNT = LobbyConfig.PAD_COUNT
local MAX = LobbyConfig.MAX_PER_PAD
local COUNTDOWN = LobbyConfig.COUNTDOWN
local GAME_PLACE = LobbyConfig.GAMEPLAY_PLACE_ID

local GROUND_Y = 0
local rng = Random.new()

-- ── greybox airfield (PLACEHOLDER — replace with a hand-built departure hangar) ───────────────
local lobby = Instance.new("Folder")
lobby.Name = "LobbyWorld"
lobby.Parent = Workspace

local function block(name: string, size: Vector3, color: Color3, pos: Vector3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Position = pos
	p.Parent = lobby
	return p
end

block("Ground", Vector3.new(240, 2, 240), Color3.fromRGB(90, 95, 90), Vector3.new(0, GROUND_Y - 1, 0), Enum.Material.Concrete)
block("Runway", Vector3.new(40, 0.4, 200), Color3.fromRGB(60, 60, 66), Vector3.new(0, GROUND_Y + 0.2, 0), Enum.Material.Asphalt)
block("Hangar", Vector3.new(60, 30, 40), Color3.fromRGB(120, 120, 130), Vector3.new(0, GROUND_Y + 15, -90), Enum.Material.Metal)

-- spawn point so players land in the lobby (not the void)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Color = Color3.fromRGB(80, 140, 90)
spawn.Position = Vector3.new(0, GROUND_Y + 0.5, 70)
spawn.Neutral = true
spawn.Parent = lobby

-- ── pads ──────────────────────────────────────────────────────────────────────────────────────
type Pad = {
	index: number,
	part: Part,
	prompt: ProximityPrompt,
	label: TextLabel,
	occupants: { Player },
	launching: boolean,
	countdown: number,
}

local pads: { Pad } = {}
local PAD_SIZE = Vector3.new(14, 1, 14)
local PAD_SPACING = 26

local PAD_COLORS = { Color3.fromRGB(200, 120, 60), Color3.fromRGB(70, 140, 200), Color3.fromRGB(150, 90, 190) }

local function makePad(index: number): Pad
	local x = (index - (PAD_COUNT + 1) / 2) * PAD_SPACING
	local part = block("LaunchPad" .. index, PAD_SIZE, PAD_COLORS[((index - 1) % #PAD_COLORS) + 1], Vector3.new(x, GROUND_Y + 0.5, 20))
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35

	-- floating sign above the pad
	local signPart = Instance.new("Part")
	signPart.Name = "Sign"
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.Transparency = 1
	signPart.Size = Vector3.new(1, 1, 1)
	signPart.Position = part.Position + Vector3.new(0, 7, 0)
	signPart.Parent = part
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadSign"
	bb.Size = UDim2.fromScale(9, 6)
	bb.StudsOffset = Vector3.new(0, 0, 0)
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
	pad.label.Text = string.format("<b>LAUNCH PAD %d</b>\n%d/%d\n%s\n%s", pad.index, #pad.occupants, MAX, table.concat(names, "\n"), status)
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
	return math.abs(d.X) <= PAD_SIZE.X / 2 + 1 and math.abs(d.Z) <= PAD_SIZE.Z / 2 + 1 and d.Y > -2 and d.Y < 10
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
	local opt = Instance.new("TeleportOptions")
	opt.ReservedServerAccessCode = code
	opt:SetTeleportData({ seed = rng:NextInteger(1, 2147483646) }) -- PUBLIC data only (shared river seed)
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
		-- if we reach here the teleport didn't take (placeholder/failed) → unlock so testing continues
		pad.launching = false
		updateSign(pad)
	end)
end

for i = 1, PAD_COUNT do
	local pad = makePad(i)
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
		-- drop players who left the pad (or the game)
		for i = #pad.occupants, 1, -1 do
			local plr = pad.occupants[i]
			if plr.Parent == nil or not onPad(plr, pad) then
				table.remove(pad.occupants, i)
				changed = true
			end
		end
		-- add players newly standing on the pad (append → preserves arrival order)
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

print(("[Lobby] airfield + %d launch pads online (gameplay place = %s)"):format(PAD_COUNT, GAME_PLACE > 0 and tostring(GAME_PLACE) or "NOT SET"))
