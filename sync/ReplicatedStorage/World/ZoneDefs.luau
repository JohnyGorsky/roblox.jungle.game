--!strict
-- ZoneDefs.luau — the river's zone list (extracted from ZoneServer in Job #075).
--
-- WHY IT MOVED: the names and the zone count lived as locals inside `ZoneServer.server.luau`, which is a
-- server script. The river progress bar has to draw a tick per zone and name the one you're in, so the
-- client needed the same list — and the alternative was a second hand-maintained copy that would drift.
-- No behaviour change: ZoneServer requires this and reads the same values it used to declare.
--
-- Zone boundaries are EVEN fractions of RiverEndDistance (zone = floor(dist/end * COUNT) + 1). That's
-- how ZoneServer has always computed them; it is not a per-zone distance table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local ZoneDefs = {}

ZoneDefs.COUNT = 4
ZoneDefs.Names = { "Headwaters", "Croc Country", "The Rapids", "Lost Delta" }

-- Announce banner colours. Previously a raw `Color3.fromRGB(90, 200, 230)` cyan that appears nowhere in
-- STYLEGUIDE §4 — now on-palette (Job #075): zones read as utility/information, nightfall as warning.
ZoneDefs.zoneColor = Theme.color.blue
ZoneDefs.nightColor = Theme.color.yellow
ZoneDefs.dayColor = Theme.color.gold

-- Which zone a distance falls in (1..COUNT).
function ZoneDefs.zoneFor(distance: number, endDistance: number): number
	local frac = if endDistance > 0 then (distance / endDistance) else 0
	return math.clamp(math.floor(frac * ZoneDefs.COUNT) + 1, 1, ZoneDefs.COUNT)
end

function ZoneDefs.nameFor(zone: number): string
	return ZoneDefs.Names[zone] or ""
end

return ZoneDefs
