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
	Ambience2      = "rbxassetid://120011248667884", -- Jungle day ambience 2 (bed variant, layered under 1)
	Wind           = "rbxassetid://93331028777865",  -- wind-breeze
	Water          = "rbxassetid://115704936377395", -- water-splashes (positional @ dock/shore)
	Campfire       = "rbxassetid://113774133604878", -- crackle-campfire (positional @ fire pits)
	Cicadas        = "rbxassetid://128204240690640", -- cicadas (occasional one-shots)
	RopeCreak      = "rbxassetid://99642631685891",  -- rope_creak (positional @ watchtowers)
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

-- TWO ambience beds, layered (Job #069). Bed 2 was uploaded long ago and read by nothing while
-- ASSETS.md claimed both were wired.
--
-- ⚠️ VOLUME IS THE KNOB, AND IT IS DELIBERATELY LOPSIDED. Bed 2 sits well under bed 1 (0.14 vs
-- 0.22) so it THICKENS the bed rather than doubling the birdsong — two full-volume wildlife loops
-- read as two tracks fighting, not as a richer jungle. The two loops are different lengths, so they
-- drift in and out of phase; that is what keeps the bed from sounding like a short repeating clip,
-- but it also means the mix is never identical twice. If it ever sounds busy, drop bed 2 first.
local ambience = makeSound(ID.Ambience1, { Volume = 0.22, SoundGroup = ambientGroup })
ambience.Name = "Ambience1"; ambience.Parent = root; ambience:Play()

local ambience2 = makeSound(ID.Ambience2, { Volume = 0.14, SoundGroup = ambientGroup })
ambience2.Name = "Ambience2"; ambience2.Parent = root; ambience2:Play()

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

local waterCount, fireCount, ropeCount = 0, 0, 0
if scenery then
	-- water at the dock pier.
	-- RECURSIVE find (Job 069, audit Job 068 gap E2). This was a NON-recursive
	-- `dock:FindFirstChild("Pier")`, which returned nil and meant the water loop was NEVER created —
	-- the lobby had no dock water sound at all, while ASSETS.md §1.11 recorded it as wired.
	-- The greybox dock had `Pier` as a direct child; the Store dock that replaced it nests one level
	-- deeper (`Scenery.Dock.Dock.Pier`). That double-`Dock` is an artifact of how the asset was
	-- inserted, not a contract, so search by NAME at any depth rather than hardcoding the path — this
	-- keeps working if the dock is swapped or re-nested again.
	local dock = scenery:FindFirstChild("Dock")
	local pier = dock and dock:FindFirstChild("Pier", true)
	if pier and pier:IsA("BasePart") then
		attachPositional(pier, ID.Water, 0.5)
		waterCount += 1
	else
		warn("[LobbySoundscape] no BasePart named 'Pier' under Scenery.Dock — no dock water sound")
	end
	-- campfire crackle at each fire pit
	for _, p in ipairs(scenery:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "FirePit" then
			attachPositional(p, ID.Campfire, 0.6)
			fireCount += 1
		end
	end
	-- Subtle rope/rigging creak at EVERY watchtower (Job 069, audit Job 068 gap E3).
	--
	-- This was a hardcoded { "Watchtower_NW", "Watchtower_NE" } driven by FindFirstChild, which returns
	-- only the FIRST match per name. The place has FOUR towers and THREE of them are named
	-- "Watchtower_NW" (two flank the southern approach) — so two towers were silent, and which one got
	-- the sound depended on child order.
	--
	-- Scanning by name PREFIX fixes that without renaming or moving anything: the towers are intended
	-- scenery and are left untouched. It also means a fifth tower placed in the editor creaks
	-- automatically with no script edit — the same find-by-name-and-attach rule the rest of the lobby
	-- follows (memory: lobby-editor-placed-not-scripted).
	for _, m in ipairs(scenery:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Watchtower") then
			local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
			if part then
				attachPositional(part, ID.RopeCreak, 0.25)
				ropeCount += 1
			end
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

print(("[LobbySoundscape] ready — music+ambience×2+wind (2D), water×%d, campfire×%d, rope×%d, cicadas looping")
	:format(waterCount, fireCount, ropeCount))
