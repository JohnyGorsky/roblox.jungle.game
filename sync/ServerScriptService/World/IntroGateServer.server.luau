--!strict
-- IntroGateServer.server.luau — intro readiness gate (Job 043, step 2 of game-intro-sequence).
-- Holds the loading-screen reveal until the run is actually ready to begin:
--   (a) the whole party has JOINED this reserved server (expected size comes from the lobby's TeleportData), and
--   (b) the WORLD is built (WorldBuilt hook — inert until a generator sets it).
-- Server-authoritative: we own Workspace.IntroReady (bool) + Workspace.IntroStatus (text). The client loader
-- (GameLoading.local) holds while IntroReady == false and displays IntroStatus. Solo/Studio Play (no
-- TeleportData) resolves to an expected party of 1, so it never hangs; a timeout failsafe covers dropped
-- members so the gate always releases.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local JOIN_TIMEOUT = 25 -- max seconds to wait for the full crew before starting anyway (drops / slow joins)
local WORLD_TIMEOUT = 30 -- max seconds to wait for WorldBuilt before starting anyway

-- publish the gate as CLOSED as early as possible so the loader holds from the first frame
Workspace:SetAttribute("IntroReady", false)
Workspace:SetAttribute("IntroStatus", "Preparing your run...")

local function setStatus(text: string)
	Workspace:SetAttribute("IntroStatus", text)
end

-- expected party size from any joined player's TeleportData (all arrive via the lobby teleport).
-- Falls back to the current headcount (>=1) for solo / direct Studio Play with no teleport data.
local function expectedPartySize(): number
	for _, p in Players:GetPlayers() do
		local ok, data = pcall(function()
			return p:GetJoinData()
		end)
		if ok and data then
			local td = data.TeleportData
			if type(td) == "table" and type(td.partySize) == "number" then
				return math.max(1, math.floor(td.partySize))
			end
		end
	end
	-- test override: set Workspace.__DebugExpectedParty in Studio to exercise the "waiting for crew" path
	local dbg = Workspace:GetAttribute("__DebugExpectedParty")
	if type(dbg) == "number" then
		return math.max(1, math.floor(dbg))
	end
	return math.max(1, #Players:GetPlayers())
end

-- wait for at least one player so TeleportData is readable
if #Players:GetPlayers() == 0 then
	Players.PlayerAdded:Wait()
end

local expected = expectedPartySize()
print("[IntroGate] expecting a party of " .. expected)

-- (a) wait for the whole crew (or the timeout failsafe)
local waitStart = os.clock()
local function crewStatus()
	setStatus("Waiting for your crew (" .. #Players:GetPlayers() .. "/" .. expected .. ")...")
end
crewStatus()
local joinConn = Players.PlayerAdded:Connect(crewStatus)
while #Players:GetPlayers() < expected and (os.clock() - waitStart) < JOIN_TIMEOUT do
	task.wait(0.25)
end
joinConn:Disconnect()

-- (b) wait for the world to be built (inert unless a generator declares WorldBuilt=false at startup)
if Workspace:GetAttribute("WorldBuilt") == false then
	setStatus("Building the river...")
	local worldStart = os.clock()
	while Workspace:GetAttribute("WorldBuilt") ~= true and (os.clock() - worldStart) < WORLD_TIMEOUT do
		Workspace:GetAttributeChangedSignal("WorldBuilt"):Wait()
	end
end

-- ready → open the gate; the loader fades out and reveals the game
setStatus("Ready")
Workspace:SetAttribute("IntroReady", true)
print("[IntroGate] ready — " .. #Players:GetPlayers() .. "/" .. expected .. " aboard, gate open")
