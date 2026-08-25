--!strict
-- AdminClient.local.luau — admin panel UI (Job 031, on the design system in Job #075). Only builds for
-- allowlisted users. Pick a target (yourself or another player) and grant Gold / River Score / Salvage /
-- all modules / max skills. The server re-checks the allowlist on every action.
--
-- ⚠️ THE TWO TREES HAVE DIVERGED, ON PURPOSE. This file and `lobby/sync/...` were once required to be
-- byte-identical, but the GAME-ONLY actions landed here alone: `tpFirstCamp` (rewired in Job #107),
-- the Job #112 cheat toggles, and `tpEndBase` (Job #114) all need `Workspace.EndBase` / the boat /
-- the run, none of which exist in the lobby place. So the shared grants (gold, score, modules,
-- skills) are the part that must stay in step — NEVER copy the lobby copy over this one wholesale.
--
-- Styled like everything else, but deliberately kept PLAIN: it is a dev tool, not a player-facing
-- screen, so it gets the design system's components and none of its flourish — no burst, no toast, no
-- celebratory sound on a grant. It should never be mistaken for something a player is meant to find.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
if not AdminDefs.isAdmin(player.UserId) then
	return -- not an admin → no UI at all
end

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local rf = ReplicatedStorage:WaitForChild("Admin") :: RemoteFunction

-- ── open button ──────────────────────────────────────────────────────────────────────────────────

-- ⚠️ Job #099 — on touch this script builds NOTHING and stops here.
--
-- Admin is allowlist-gated dev UI, and on a phone its button sits bottom-right, which belongs to the
-- jump button and the player's right thumb. Disabling the ScreenGui after creating it was NOT enough:
-- `IntroHudGate` lists "AdminLauncher" among the HUDs it hides for the cold open and then calls
-- `setHudEnabled(true)` when the intro ends — which turned it straight back on. Returning early leaves
-- nothing for anything else to re-enable. Desktop is unchanged.
if game:GetService("UserInputService").TouchEnabled then
	return
end

local launcher = Components.screen("AdminLauncher", player:WaitForChild("PlayerGui"))
launcher.DisplayOrder = 60

local openHolder = Instance.new("Frame")
openHolder.Name = "Holder"
openHolder.AnchorPoint = Vector2.new(1, 1)
-- Raised off the bottom-right corner: in the GAME place that corner is the driver's throttle cluster
-- (TouchControls). Sitting above it keeps an admin from fat-fingering a grant while steering.
openHolder.Position = UDim2.fromScale(0.98, 0.78)
openHolder.Size = UDim2.fromScale(0.1, 0.045)
openHolder.BackgroundTransparency = 1
openHolder.BorderSizePixel = 0

local openClamp = Instance.new("UISizeConstraint")
openClamp.MinSize = Vector2.new(90, 32)
openClamp.MaxSize = Vector2.new(170, 48)
openClamp.Parent = openHolder

openHolder.Parent = launcher

-- ── panel ────────────────────────────────────────────────────────────────────────────────────────

local panel = Components.panel({
	name = "AdminPanel",
	title = "Admin panel",
	icon = "wrench",
	size = UDim2.fromScale(0.46, 0.62),
	parent = player.PlayerGui,
})
panel.gui.DisplayOrder = 61

-- ── target selector (cycles Me + current players) ────────────────────────────────────────────────

local targets: { { name: string, userId: number } } = {}
local targetIdx = 1

local targetButton = Components.button({
	text = "TARGET: (LOADING…)",
	variant = "secondary",
	icon = "crew",
	size = UDim2.fromScale(1, 0.12),
	parent = panel.content,
	onActivated = function()
		if #targets == 0 then
			return
		end
		targetIdx = (targetIdx % #targets) + 1
	end,
})
targetButton.instance.Position = UDim2.fromScale(0, 0)

local function showTarget()
	local t = targets[targetIdx]
	targetButton.setText(if t then ("TARGET: %s  ›"):format(string.upper(t.name)) else "TARGET: —")
end

-- rebuilt each open: the player list changes between openings
local function refreshTargets()
	targets = { { name = player.DisplayName .. " (me)", userId = player.UserId } }
	local ok, res = pcall(function()
		return rf:InvokeServer("players")
	end)
	if ok and type(res) == "table" and res.players then
		for _, p in ipairs(res.players) do
			if p.userId ~= player.UserId then
				targets[#targets + 1] = { name = p.name, userId = p.userId }
			end
		end
	end
	if targetIdx > #targets then
		targetIdx = 1
	end
	showTarget()
end

-- The cycle handler above changes the index; the label follows it here rather than inside the handler,
-- so both the cycle and a refresh go through one place.
targetButton.instance.Activated:Connect(showTarget)

-- ── actions ──────────────────────────────────────────────────────────────────────────────────────

-- Three shapes share this list: a targeted GRANT (`kind` + `amount`), a self ACTION (`action`), and a
-- state TOGGLE (`toggle`, Job #112). A toggle differs from the other two in that it reads back — its
-- button is labelled from server state when the panel opens, not from whatever it last did.
type AdminAction = { label: string, icon: string, kind: string?, amount: number?, action: string?, toggle: string? }

local actions: { AdminAction } = {
	{ label = "+1000 Gold", icon = "coin", kind = "gold", amount = 1000 },
	{ label = "+10000 River Score", icon = "trophy", kind = "score", amount = 10000 },
	{ label = "+1000 Salvage (in-run)", icon = "salvage", kind = "salvage", amount = 1000 },
	{ label = "Unlock ALL Modules", icon = "boat", kind = "allModules", amount = 0 },
	{ label = "MAX ALL Skills", icon = "star", kind = "maxSkills", amount = 0 },
	-- Job #117 - the M16, in two halves, because they test different things and both need testing:
	--   - "Give M16" arms the gun NOW, for the burst itself (2 s of fire, one round, the 2 s lockout).
	--   - "Bank M16 charge" fakes the 30 R$ receipt, for the LOBBY -> RUN handover. Real Robux prompts do
	--     not complete in Studio, so without this the purchase half is untestable - see AdminServer.
	{ label = "Give M16 + 30 rounds", icon = "rifle", kind = "m16", amount = 30 },
	{ label = "Bank M16 charge (next run)", icon = "rifle", kind = "m16Charge", amount = 1 },
	-- Job #118 - the Bazooka, split the same two ways and for the same two reasons:
	--   - "Give Bazooka" arms it NOW, for the 4 s flight, the ground ring, the blast and the 5 s reload.
	--   - "Bank Bazooka charge" fakes the 80 R$ receipt, for the LOBBY -> RUN handover.
	{ label = "Give Bazooka + 6 rockets", icon = "bazooka", kind = "bazooka", amount = 6 },
	{ label = "Bank Bazooka charge (next run)", icon = "rocketAmmo", kind = "bazookaCharge", amount = 1 },
	{ label = "TP to First Camp", icon = "pin", action = "tpFirstCamp" }, -- self-teleport (no target); Job 053
	-- Job #114: the other end of the run. Game-only (the lobby tree has no `Workspace.EndBase`), and
	-- it force-starts the run on arrival so the extraction pad is actually live — see AdminServer.
	{ label = "TP to Endgame", icon = "flag", action = "tpEndBase" },
	-- Job #112 test switches. `godPlayer` follows the target selector above; the boat ones are global
	-- because there is only ever one boat.
	{ label = "God Mode — Character", icon = "heart", toggle = "godPlayer" },
	{ label = "God Mode — Boat", icon = "boat", toggle = "godBoat" },
	{ label = "Infinite Fuel", icon = "fuel", toggle = "infiniteFuel" },
}

-- Current server-side toggle state, refreshed whenever the panel opens. Labels are driven from THIS,
-- never from a local guess about what the last click did — a click that the server refused (no boat
-- spawned yet, for instance) must not leave the button claiming the cheat is on.
local cheatState: { [string]: boolean } = {}
local toggleButtons: { [string]: any } = {}

local function paintToggle(key: string, label: string)
	local btn = toggleButtons[key]
	if not btn then
		return
	end
	local on = cheatState[key] == true
	btn.setText(string.upper(label) .. (on and "  ·  ON" or "  ·  OFF"))
	btn.setMuted(not on)
end

local list = Instance.new("ScrollingFrame")
list.Name = "Actions"
list.Position = UDim2.fromScale(0, 0.16)
list.Size = UDim2.fromScale(1, 0.84)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Theme.color.wood
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel.content

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.sm)
layout.Parent = list

for i, a in ipairs(actions) do
	local button
	button = Components.button({
		text = string.upper(a.label),
		variant = "gold",
		icon = a.icon,
		size = UDim2.new(1, 0, 0, 44),
		layoutOrder = i,
		parent = list,
		onActivated = function()
			button.setEnabled(false)
			button.setText("…")

			if a.toggle then
				local tgt = targets[targetIdx]
				local ok, res = pcall(function()
					return rf:InvokeServer("cheat", {
						kind = a.toggle,
						on = not (cheatState[a.toggle] == true),
						targetUserId = tgt and tgt.userId,
					})
				end)
				button.setEnabled(true)
				if ok and typeof(res) == "table" and res.ok == true and typeof(res.state) == "table" then
					cheatState = res.state
					paintToggle(a.toggle, a.label)
				else
					-- Refused (usually "no-boat" before the boat exists). Say so, then repaint from the
					-- state we still believe — never flip the label on a request the server rejected.
					local why = if ok and typeof(res) == "table" and res.error then tostring(res.error) else "failed"
					button.setText(string.upper(why))
					task.delay(2.5, function()
						paintToggle(a.toggle :: string, a.label)
					end)
				end
				return
			end

			-- Self-actions (e.g. teleport) take no target and close the panel so you see the result.
			--
			-- ⚠️ Job #107: the result is READ now. This used to be a bare `pcall(InvokeServer)` that threw
			-- the return value away and closed the panel regardless — so a jump that failed (no camp
			-- built, no landing, terrain not generated) was indistinguishable from one that worked: the
			-- panel shut and nothing happened. The panel only closes on success; a failure keeps it open
			-- and says why on the button.
			if a.action then
				local ok, res = pcall(function()
					return rf:InvokeServer(a.action)
				end)
				button.setEnabled(true)
				local failed = (not ok) or typeof(res) ~= "table" or res.ok ~= true
				if failed then
					local why = if ok and typeof(res) == "table" and res.error then tostring(res.error) else "failed"
					button.setText(string.upper(why))
					-- leave the panel OPEN so the message is readable, and restore the label after a beat
					task.delay(2.5, function()
						button.setText(string.upper(a.label))
					end)
					return
				end
				button.setText(string.upper(a.label))
				panel.setOpen(false)
				return
			end

			local tgt = targets[targetIdx]
			if tgt then
				pcall(function()
					rf:InvokeServer("give", { targetUserId = tgt.userId, kind = a.kind, amount = a.amount })
				end)
			end
			button.setText(string.upper(a.label))
			button.setEnabled(true)
		end,
	})
	if a.toggle then
		toggleButtons[a.toggle] = button
		paintToggle(a.toggle, a.label)
	end
end

-- Pull the real state on open. Without this the toggles would read OFF after a panel reopen even though
-- the cheat is still running on the server.
local function refreshCheats()
	local tgt = targets[targetIdx]
	local ok, res = pcall(function()
		return rf:InvokeServer("cheats", { targetUserId = tgt and tgt.userId })
	end)
	if ok and typeof(res) == "table" and typeof(res.state) == "table" then
		cheatState = res.state
		for _, a in ipairs(actions) do
			if a.toggle then
				paintToggle(a.toggle, a.label)
			end
		end
	end
end

-- The panel owns its own way out (X + tap-outside), so opening is all that's left to wire.
Components.button({
	text = "ADMIN",
	variant = "secondary",
	size = UDim2.fromScale(1, 1),
	parent = openHolder,
	onActivated = function()
		refreshTargets() -- the player list changes between openings
		refreshCheats() -- and the cheats may have been left on from a previous opening
		panel.setOpen(true)
	end,
})
