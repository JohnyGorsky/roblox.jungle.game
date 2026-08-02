--!strict
-- GameSoundscape.server.luau — the GAME place's ambient bed                            [Job #073]
-- ============================================================================================
-- Ported from `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` and made DAY/NIGHT-AWARE,
-- because unlike the static-afternoon lobby the game runs a real clock (`DayNightServer`).
--
-- Before this, the game place had NO ambient audio whatsoever — SoundService had zero children and no
-- SoundGroups; only the loading screen and the plane-crash intro touched sound at all.
--
-- Legacy Sound API on purpose (reliable, mobile-friendly), matching the lobby. Idempotent: rebuilds
-- cleanly each run.
--
-- ── THREE THINGS THAT ARE DIFFERENT FROM THE LOBBY, AND WHY ─────────────────────────────────
--
-- 1. NO LOOPING MUSIC BED. `lobby_intro_music` is the lobby's signature theme and stays there. The run
--    is scored by the jungle itself plus two stingers on the day/night flip, so tension stays readable
--    and nothing loops over a fast clock.
--
-- 2. THE MIX CROSSFADES AT DUSK AND DAWN. We only own *day* ambience beds (birds + insects), so night
--    is made by ducking the birds almost out and bringing the cicadas up. Night reads as night with no
--    new asset sourcing.
--
--    ⚠️ THE CICADAS ARE A CROSSFADING BED, NOT ONE-SHOTS — and that was a measured correction. The
--    lobby fires `cicadas` as an "occasional one-shot" every 18–44 s, but the clip is **71.4 s long**
--    (read live in Play). So each one is still playing when the next two start: the lobby is already
--    stacking ~2 copies, and the plan for this place — one-shots every 6–16 s at night — would have
--    layered SIX OR SEVEN concurrent 71-second cicada loops into a wall of noise.
--
--    Treating it as a fourth bed that fades up at night is cheaper (one Sound, not N), cannot stack,
--    and is what a night jungle actually sounds like. NOTE: the same latent stacking exists in
--    `LobbySoundscape` — different place, not touched from here.
--
-- 3. IT HOLDS SILENT THROUGH THE COLD OPEN. Job #072 already shipped this bug once — "plane sound
--    started to play through loading screen". Jungle birdsong under a plane cabin, or over the loading
--    mask, is the same mistake, so nothing plays until `Workspace.IntroWake`. If there is no intro at
--    all (direct Studio Play with no PlaneServer), it starts immediately instead of hanging silent.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Audio (registry `audio.md` → Jungle / Last River). Ids live in ONE table; nothing below writes an
-- asset id inline, mirroring `PlaneServer` and the way the lobby resolves everything through
-- `Theme.sound`.
local SFX = {
	ambience1 = "rbxassetid://116462724806689", -- Jungle day ambience 1   2D loop, birds+insects bed
	ambience2 = "rbxassetid://120011248667884", -- Jungle day ambience 2   2D loop, bed variant
	wind = "rbxassetid://93331028777865", -- wind-breeze             2D loop
	cicadas = "rbxassetid://128204240690640", -- cicadas                 2D one-shots
	water = "rbxassetid://115704936377395", -- water-splashes          positional @ dock
	morning = "rbxassetid://98066971477923", -- morning_starts          2D stinger, Phase → day
	night = "rbxassetid://99602574849976", -- night_starts            2D stinger, Phase → night
}
-- NOTE: `battle_starts` (79506043370965) is uploaded and owned but deliberately NOT wired here.
-- `EnemyServer` is a continuous trickle spawner — spawn interval escalates with distance and phase, and
-- there is no wave, encounter or aggro-start concept to hang a combat stinger on. Wiring it means
-- inventing encounter detection inside the combat system, which is a gameplay change, not an ambient
-- one. Filed in Planned/.

local ROOT_NAME = "GameSoundscape"
local FADE = TweenInfo.new(6, Enum.EasingStyle.Sine) -- dusk/dawn crossfade; slower than the eye's
local WAKE_FADE = 2 -- seconds to fade the bed in as the crew comes round

-- ── the day and night mixes ─────────────────────────────────────────────────────────────────
-- ⚠️ THE DAY VOLUMES ARE DELIBERATELY LOPSIDED, and that is inherited from the lobby (Job #069): bed 2
-- sits well under bed 1 so it THICKENS the bed rather than doubling the birdsong. Two full-volume
-- wildlife loops read as two tracks fighting, not as a richer jungle. If it ever sounds busy, drop
-- bed 2 first. The loops are different lengths (154.2 s vs 70.2 s) so they drift and never audibly
-- repeat — which also means the mix is never identical twice.
local MIX = {
	day = {
		ambience1 = 0.22,
		ambience2 = 0.14,
		wind = 0.15,
		cicadas = 0.04, -- barely there by day; the birds are the story
	},
	night = {
		-- the birds go to almost nothing rather than to zero: a hard cut to silence at 19:00 is very
		-- audible, and a whisper of the bed keeps the jungle feeling occupied
		ambience1 = 0.06,
		ambience2 = 0.03,
		wind = 0.20, -- wind comes forward to carry the bed the birds were carrying
		cicadas = 0.34, -- and the cicadas take over — this is what makes night read as night
	},
}

local function mixFor(): typeof(MIX.day)
	return if Workspace:GetAttribute("Phase") == "night" then MIX.night else MIX.day
end

-- ── SoundGroups (volume buses) ──────────────────────────────────────────────────────────────
local function ensureGroup(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	local g: SoundGroup
	if existing and existing:IsA("SoundGroup") then
		g = existing
	else
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = volume
	return g
end

local musicGroup = ensureGroup("GameMusic", 0.6)
local ambientGroup = ensureGroup("GameAmbient", 0.7)
local sfxGroup = ensureGroup("GameSFX", 0.8)

-- ── helpers ─────────────────────────────────────────────────────────────────────────────────
type SoundProps = {
	Looped: boolean?,
	Volume: number?,
	SoundGroup: SoundGroup?,
	RollOffMode: Enum.RollOffMode?,
	RollOffMinDistance: number?,
	RollOffMaxDistance: number?,
}

local function makeSound(id: string, props: SoundProps): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = props.Looped ~= false
	s.Volume = props.Volume or 0.5
	if props.RollOffMode then s.RollOffMode = props.RollOffMode end
	if props.RollOffMinDistance then s.RollOffMinDistance = props.RollOffMinDistance end
	if props.RollOffMaxDistance then s.RollOffMaxDistance = props.RollOffMaxDistance end
	if props.SoundGroup then s.SoundGroup = props.SoundGroup end
	return s
end

-- ── (re)build the root holder for the 2D beds ───────────────────────────────────────────────
local old = SoundService:FindFirstChild(ROOT_NAME)
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = SoundService

-- Built at volume 0 and faded in at the wake. They are PLAYING from the start so the loops are already
-- streamed and mid-phrase by the time anyone hears them — a loop that starts from sample 0 at the wake
-- announces itself as a recording.
local bed1 = makeSound(SFX.ambience1, { Volume = 0, SoundGroup = ambientGroup })
bed1.Name = "Ambience1"
bed1.Parent = root
bed1:Play()

local bed2 = makeSound(SFX.ambience2, { Volume = 0, SoundGroup = ambientGroup })
bed2.Name = "Ambience2"
bed2.Parent = root
bed2:Play()

local wind = makeSound(SFX.wind, { Volume = 0, SoundGroup = ambientGroup })
wind.Name = "Wind"
wind.Parent = root
wind:Play()

local cicadas = makeSound(SFX.cicadas, { Volume = 0, SoundGroup = ambientGroup })
cicadas.Name = "Cicadas"
cicadas.Parent = root
cicadas:Play()

-- ── positional water at the dock ────────────────────────────────────────────────────────────
-- ⚠️ The lobby finds this anchor with `Dock:FindFirstChild("Pier", true)`. That CANNOT work here: the
-- game's dock model is 60-odd parts every one of which is literally named "Part", so there is no name
-- to search for. `Dock.BoatPlace` is the one stable, named, editor-placed part on the waterline (it is
-- what BoatServer moors the boat to, Job #072), so the water loop rides that instead. Move the marker
-- in the editor and the sound follows — same find-by-name-and-attach rule the lobby follows.
local waterCount = 0
do
	local spawnBase = Workspace:WaitForChild("SpawnBase", 10)
	local dock = spawnBase and spawnBase:FindFirstChild("Dock")
	local anchor = dock and dock:FindFirstChild("BoatPlace")
	if anchor and anchor:IsA("BasePart") then
		for _, c in anchor:GetChildren() do
			if c:IsA("Sound") and c:GetAttribute("GameSoundscape") then c:Destroy() end
		end
		local s = makeSound(SFX.water, {
			Volume = 0.5,
			SoundGroup = sfxGroup,
			RollOffMode = Enum.RollOffMode.InverseTapered,
			RollOffMinDistance = 10,
			RollOffMaxDistance = 120,
		})
		s.Name = "DockWater"
		s:SetAttribute("GameSoundscape", true)
		s.Parent = anchor
		s:Play()
		waterCount = 1
	else
		warn("[GameSoundscape] no BasePart 'SpawnBase.Dock.BoatPlace' — no dock water sound")
	end
end

-- ── hold silent through the cold open ───────────────────────────────────────────────────────
-- `IntroActive` is claimed by PlaneServer at its very first line, so if it is nil after a short grace
-- period there is no intro in this place and we should just start.
local function waitForWake()
	local t0 = os.clock()
	while Workspace:GetAttribute("IntroActive") == nil and os.clock() - t0 < 5 do
		task.wait(0.1)
	end
	if Workspace:GetAttribute("IntroActive") ~= true then
		return -- no intro (or already over) → start now
	end
	-- IntroWake goes true at the moment the crew comes round in the wreckage, and false again when the
	-- intro releases. Either that, or IntroActive dropping, means we are clear to be heard.
	while Workspace:GetAttribute("IntroActive") == true and Workspace:GetAttribute("IntroWake") ~= true do
		task.wait(0.2)
	end
end

local live = false

local function applyMix(fadeInfo: TweenInfo?)
	if not live then return end
	local m = mixFor()
	local info = fadeInfo or FADE
	TweenService:Create(bed1, info, { Volume = m.ambience1 }):Play()
	TweenService:Create(bed2, info, { Volume = m.ambience2 }):Play()
	TweenService:Create(wind, info, { Volume = m.wind }):Play()
	TweenService:Create(cicadas, info, { Volume = m.cicadas }):Play()
end

-- ── stingers on the day/night flip ──────────────────────────────────────────────────────────
-- `morning_starts` / `night_starts` have been uploaded and owned since Job #064 and read by nothing;
-- the registry and LobbySoundscape both record them as belonging to THIS place. This is that wiring.
local function stinger(id: string)
	local s = makeSound(id, { Looped = false, Volume = 0.5, SoundGroup = musicGroup })
	s.Name = "PhaseStinger"
	s.Parent = root
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

Workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = Workspace:GetAttribute("Phase")
	applyMix()
	-- Don't sting over the cold open. The crash lands at 06:30 and DayNightServer publishes the first
	-- Phase before the plane has even taken off, so an unguarded stinger would play a triumphant
	-- sunrise cue underneath a stalling engine.
	if not live then return end
	if phase == "night" then
		stinger(SFX.night)
	elseif phase == "day" then
		stinger(SFX.morning)
	end
end)

-- ── go live ─────────────────────────────────────────────────────────────────────────────────
task.spawn(function()
	waitForWake()
	live = true
	applyMix(TweenInfo.new(WAKE_FADE, Enum.EasingStyle.Sine))
	print(("[GameSoundscape] live — birds×2 + wind + cicadas (2D beds), water×%d, phase stingers armed (%s)")
		:format(waterCount, tostring(Workspace:GetAttribute("Phase"))))
end)
