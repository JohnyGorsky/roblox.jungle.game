--!strict
-- UIBus.luau — client-side panel-open bus (Job 065).
--
-- WHY THIS EXISTS: `ReplicatedStorage.OpenPanel` is a RemoteEvent the SERVER fires at a client when a
-- player walks up to a kiosk (LobbyStations). It is server→client only, so one client script cannot use
-- it to open a panel owned by another client script — and after Job 065 several do exactly that: the
-- top bar's `+` opens the Robux shop, and the shared entry bar opens all four panels.
--
-- Round-tripping through the server just to talk between two local scripts would add latency and an
-- exploitable remote for no reason. This module is a purely local BindableEvent instead.
--
-- Panel ids match the LobbyStations table: "modules" | "skills" | "robux" | "weekly".
-- A panel script listens with UIBus.onOpen; anything can request one with UIBus.open.
-- Kiosk opens still arrive on the RemoteEvent — panels listen to both.

local UIBus = {}

local event = Instance.new("BindableEvent")
event.Name = "UIBusOpen"

-- Ask for a panel to open. No-op if nothing is listening for that id.
function UIBus.open(id: string)
	event:Fire(id)
end

-- Listen for open requests. `fn` receives the panel id.
function UIBus.onOpen(fn: (id: string) -> ()): RBXScriptConnection
	return event.Event:Connect(function(id: string)
		fn(id)
	end)
end

return UIBus
