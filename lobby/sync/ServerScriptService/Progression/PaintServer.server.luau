--!strict
-- PaintServer.server.luau — LOBBY hull-livery picker backend (Job 067).
--
-- The Boat Paint Pack was live on the Creator Hub and delivered nothing — no code in either tree read
-- `Owns_boatPaint` (Job 067 finding 1). This is the half that lets a buyer actually choose a livery; the
-- boats read the result through the `BoatPaint` player attribute (Profiles._publish).
--
-- Server-authoritative in exactly the way that matters: a client can ask for any livery id it likes, and
-- the id is re-validated AND the pass re-checked here. `BoatPaint.DEFAULT` never needs the pass, so a
-- player who refunds can always get back to a boat they're allowed to have.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local BoatPaint = require(ReplicatedStorage:WaitForChild("Boat"):WaitForChild("BoatPaint"))

local rf = Instance.new("RemoteFunction")
rf.Name = "BoatPaint"
rf.Parent = ReplicatedStorage

rf.OnServerInvoke = function(plr: Player, action: string?, id: string?)
	if not Profiles.isReady(plr) then
		return { error = "loading" }
	end
	local ownsPass = plr:GetAttribute("Owns_boatPaint") == true

	if action == "list" then
		return { current = Profiles.getPaint(plr), owned = ownsPass }
	elseif action == "set" then
		if type(id) ~= "string" or BoatPaint.get(id) == nil then
			return { error = "unknown", current = Profiles.getPaint(plr), owned = ownsPass }
		end
		if BoatPaint.requiresPass(id) and not ownsPass then
			return { error = "locked", current = Profiles.getPaint(plr), owned = ownsPass }
		end
		if not Profiles.setPaint(plr, id) then
			return { error = "loading" }
		end
		-- Reuse the module-shop revision counter: LobbyBoat already rebuilds the showroom boat when this
		-- bumps, so picking a livery repaints the moored boat while the player watches. One mechanism, and
		-- LobbyBoat stays decoupled from both shops.
		plr:SetAttribute("ModulesRev", ((plr:GetAttribute("ModulesRev") :: number?) or 0) + 1)
		return { ok = true, current = id, owned = ownsPass }
	end
	return { error = "bad-action" }
end

print("[BoatPaint] lobby livery picker server online")
