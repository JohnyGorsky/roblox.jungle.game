--!strict
-- CombatFx.luau — the one place a landed hit is announced to clients (Job #080, built in Job #084).
--
-- Every damage source in the game is SERVER-side and authoritative, which is the right place for a hit
-- to ORIGINATE — but the number and the particles must be DRAWN on the client. This module is the seam:
-- server code calls `CombatFx.hit(...)`, one RemoteEvent carries it, and `CombatFeedback.local.luau`
-- does all the rendering.
--
-- ⚠️ `FireAllClients`, deliberately. The user's call is that the whole crew's damage is visible to
-- everyone, weighted the same — a co-op boat should read as a co-op fight, not six private ones.
--
-- ⚠️ ONE EVENT PER TARGET PER SHOT, NOT PER PELLET. A shotgun is 6 pellets at 0.7 s and a full crew is
-- 6 players; per-pellet events would be 36 remotes and 36 labels for one volley. Callers accumulate
-- across pellets and call this once per enemy hit — see `WeaponServer`.
--
-- Damage numbers are PRESENTATION ONLY. Nothing here changes a damage value; Jobs 015/053/058 tuned
-- those and this job must not move them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFx = {}

-- `kind` decides the colour on the client:
--   "deal" → GREEN, damage dealt to an enemy by anyone on the crew
--   "take" → RED, damage taken by a player or by the boat
export type Kind = "deal" | "take"

local remote = ReplicatedStorage:FindFirstChild("CombatFeedback") :: RemoteEvent?
if not remote then
	local r = Instance.new("RemoteEvent")
	r.Name = "CombatFeedback"
	r.Parent = ReplicatedStorage
	remote = r
end
local event = remote :: RemoteEvent

-- Announce one landed hit. `pos` is where the number floats and the particles burst — the target's
-- position, not the shooter's.
function CombatFx.hit(pos: Vector3, amount: number, kind: Kind)
	local n = math.floor(amount + 0.5)
	if n <= 0 then
		return -- a 0 that rounds away is not feedback, it is noise
	end
	event:FireAllClients(pos, n, kind)
end

return CombatFx
