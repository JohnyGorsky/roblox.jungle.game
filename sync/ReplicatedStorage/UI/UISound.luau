--!strict
-- UISound.luau — the lobby's UI sound layer (Job 065). Client-side, 2D.
--
-- One call site for every interface sound: `UISound.play("open")`. Keys are Theme.sound keys, so a
-- screen never touches an asset id. Sounds are created once and reused (no per-click Instance churn).
--
-- 2D vs positional: UI sounds are 2D and live here. World cues (pad join, prompt, campfire) stay
-- POSITIONAL on their part — see LobbySoundscape / LobbyServer. Don't route those through this module.
--
-- STYLEGUIDE §12 / jungle-style "juice": every meaningful action gets a sound AND matching VFX. This
-- module is only half of that — pair each call with the matching effect.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local UISound = {}

-- Default volume per cue, so one loud asset can't dominate the mix. 1.0 unless listed.
local VOLUME: { [string]: number } = {
	click = 0.35,
	open = 0.5,
	close = 0.5,
	prompt = 0.4,
	purchase = 0.7,
	fail = 0.55,
	upgrade = 0.7,
	rank = 0.75,
	launch = 0.8,
}

-- Minimum seconds between two plays of the SAME cue. Stops a rapid tap turning into a buzz.
local DEBOUNCE = 0.06

local container = Instance.new("Folder")
container.Name = "UISounds"
container.Parent = SoundService

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

local function get(key: string): Sound?
	local existing = cache[key]
	if existing then
		return existing
	end

	local id = (Theme.sound :: { [string]: string })[key]
	if not id then
		warn(`[UISound] unknown sound key "{key}" — check Theme.sound`)
		return nil
	end
	-- A DECLARED but not-yet-sourced cue (Job #075 placeholders): silently skip rather than build a
	-- Sound with an empty SoundId. Call sites stay wired and start working the moment the id lands.
	-- Distinct from the unknown-key case above, which is a typo and must stay loud.
	if id == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = id
	sound.Volume = VOLUME[key] or 1
	sound.Parent = container
	cache[key] = sound
	return sound
end

-- Play a UI cue. Safe to call on every button press.
function UISound.play(key: string)
	local sound = get(key)
	if not sound then
		return
	end

	local now = os.clock()
	local last = lastPlayed[key]
	if last and (now - last) < DEBOUNCE then
		return
	end
	lastPlayed[key] = now

	sound:Play()
end

-- Convenience for the two most common pairs, so screens read clearly.
function UISound.panelOpened()
	UISound.play("open")
end

function UISound.panelClosed()
	UISound.play("close")
end

-- Purchase outcome in one call — `ok` picks success vs failure.
function UISound.purchase(ok: boolean)
	UISound.play(ok and "purchase" or "fail")
end

-- Warm the cache so the first click isn't silent while the asset loads.
function UISound.preload()
	local ContentProvider = game:GetService("ContentProvider")
	local list = {}
	for key in pairs(Theme.sound :: { [string]: string }) do
		local sound = get(key)
		if sound then
			table.insert(list, sound)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return UISound
