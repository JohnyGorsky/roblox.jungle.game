--!strict
-- LobbySoundscape.server.luau — builds the Jungle Airfield lobby soundscape.
-- LOBBY-scoped (lobby place). Finds editor-placed props by name and attaches sound.
-- Asset IDs are our own uploads (see roblox.workspace/Assets/registry/audio.md + /ASSETS.md §1.11–1.13).
-- Idempotent: rebuilds cleanly each run. Uses the legacy Sound API (reliable, mobile-friendly);
-- could be migrated to the modern AudioPlayer/AudioEmitter API later if we want richer routing.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- ---- asset IDs ----
local ID = {
	LobbyMusic     = "rbxassetid://135826546197884", -- lobby_intro_music
	Ambience1      = "rbxassetid://116462724806689", -- Jungle day ambience 1 (birds+insects bed)
	Wind           = "rbxassetid://93331028777865",  -- wind-breeze
	Water          = "rbxassetid://115704936377395", -- water-splashes (positional @ dock/shore)
	Campfire       = "rbxassetid://113774133604878", -- crackle-campfire (positional @ fire pits)
	Cicadas        = "rbxassetid://128204240690640", -- cicadas (occasional one-shots)
}
-- NOTE: morning_starts / night_starts / battle_starts are day-night/combat cues for the GAME place,
-- not the static-afternoon lobby — intentionally not used here.

local ROOT_NAME = "LobbySoundscape"

-- ---- SoundGroups (volume buses) ----
local function ensureGroup(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	;(g :: SoundGroup).Volume = volume
	return g :: SoundGroup
end

local musicGroup   = ensureGroup("LobbyMusic", 0.6)
local ambientGroup = ensureGroup("LobbyAmbient", 0.7)
local sfxGroup     = ensureGroup("LobbySFX", 0.8)

-- ---- helpers ----
local function makeSound(id: string, props: {[string]: any}): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = props.Looped ~= false
	s.Volume = props.Volume or 0.5
	if props.RollOffMinDistance then s.RollOffMinDistance = props.RollOffMinDistance end
	if props.RollOffMaxDistance then s.RollOffMaxDistance = props.RollOffMaxDistance end
	if props.RollOffMode then s.RollOffMode = props.RollOffMode end
	if props.SoundGroup then s.SoundGroup = props.SoundGroup end
	return s
end

-- ---- (re)build root holder for the 2D beds ----
local old = SoundService:FindFirstChild(ROOT_NAME)
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = SoundService

-- 2D music + ambient beds (parented under SoundService → non-positional, heard everywhere)
local music = makeSound(ID.LobbyMusic, { Volume = 0.35, SoundGroup = musicGroup })
music.Name = "Music"; music.Parent = root; music:Play()

local ambience = makeSound(ID.Ambience1, { Volume = 0.22, SoundGroup = ambientGroup })
ambience.Name = "Ambience"; ambience.Parent = root; ambience:Play()

local wind = makeSound(ID.Wind, { Volume = 0.15, SoundGroup = ambientGroup })
wind.Name = "Wind"; wind.Parent = root; wind:Play()

-- ---- positional emitters (attach to editor-placed props by name) ----
local greybox = Workspace:WaitForChild("LOBBY_GREYBOX", 10)
local scenery = greybox and greybox:FindFirstChild("Scenery")

local function clearTagged(part: BasePart)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("Sound") and c:GetAttribute("LobbySoundscape") then c:Destroy() end
	end
end

local function attachPositional(part: BasePart, id: string, volume: number)
	clearTagged(part)
	local s = makeSound(id, {
		Volume = volume,
		SoundGroup = sfxGroup,
		RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 10,
		RollOffMaxDistance = 120,
	})
	s.Name = "LobbySound"
	s:SetAttribute("LobbySoundscape", true)
	s.Parent = part
	s:Play()
end

local waterCount, fireCount = 0, 0
if scenery then
	-- water at the dock pier
	local dock = scenery:FindFirstChild("Dock")
	local pier = dock and dock:FindFirstChild("Pier")
	if pier and pier:IsA("BasePart") then
		attachPositional(pier, ID.Water, 0.5)
		waterCount += 1
	end
	-- campfire crackle at each fire pit
	for _, p in ipairs(scenery:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "FirePit" then
			attachPositional(p, ID.Campfire, 0.6)
			fireCount += 1
		end
	end
end

-- ---- occasional cicada one-shots (2D) ----
task.spawn(function()
	while root.Parent do
		task.wait(18 + math.random() * 26) -- every ~18–44s
		if not root.Parent then break end
		local one = makeSound(ID.Cicadas, { Looped = false, Volume = 0.28, SoundGroup = ambientGroup })
		one.Name = "CicadaOneShot"
		one.Parent = root
		one:Play()
		one.Ended:Once(function() one:Destroy() end)
	end
end)

print(("[LobbySoundscape] ready — music+ambience+wind (2D), water×%d, campfire×%d, cicadas looping")
	:format(waterCount, fireCount))
