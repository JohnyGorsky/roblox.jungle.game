--!strict
-- BunkerServer.server.luau — wires the world's bunkers (Job #116).
--
-- All the behaviour lives in `Bunkers.luau`; this is just the boot, for the same reason `GeneratorServer`
-- is: the module stays a module, so a later spawner can `require` it without inheriting a startup scan.
--
-- Two ways in, the same two Job #115 established:
--   1. THE EDITOR-PLACED ONES, found under Workspace by STRUCTURE — a Model whose child `BunkerDoors` is
--      itself a Model. Not by name: `Workspace.EndBase.Bunker` is a Folder called Bunker holding a Model
--      called Bunker holding a MeshPart called Bunker, and a name match would take all three.
--   2. THE TAG, for anything spawned later. `Bunkers.spawn` tags internally, so both paths converge and
--      `attach` is idempotent to make the overlap harmless.
--
-- ⚠️ SCANNED FROM WORKSPACE, NOT FROM SERVERSTORAGE. `AssetLibrary.Structures.Bunker` matches the same
-- structural signature; wiring it would leave a lamp and an alarm on the template and hand every future
-- clone a duplicate set. See `Bunkers.attachAll`'s own warning.

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Bunkers = require(ServerScriptService:WaitForChild("World"):WaitForChild("Bunkers"))

local wired = Bunkers.attachAll(Workspace)

CollectionService:GetInstanceAddedSignal(Bunkers.TAG):Connect(function(inst: Instance)
	if inst:IsA("Model") then
		Bunkers.attach(inst)
	end
end)

-- A new run re-locks everything: doors shut, lamp red, hoard gone. Without this, an admin-forced second
-- run in the same server walks into an open bunker whose gold is already claimed. `SalvageServer` resets
-- off exactly this attribute, and for exactly this reason.
Workspace:GetAttributeChangedSignal("RunStarted"):Connect(function()
	if Workspace:GetAttribute("RunStarted") == true then
		local n = Bunkers.resetAll()
		if n > 0 then
			print(("[Bunker] run started — %d bunker(s) re-locked"):format(n))
		end
	end
end)

local lines = {}
for _, model in ipairs(Bunkers.all()) do
	local down, total = Bunkers.progress(model)
	table.insert(lines, ("%s (%d/%d keys down)"):format(model:GetFullName(), down, total))
end
table.sort(lines)
print(("[Bunker] %d wired (%s) — %ds door slide, %d Gold + %d Salvage per crew share"):format(
	wired,
	if #lines > 0 then table.concat(lines, "; ") else "none found",
	Bunkers.OPEN_SECONDS,
	Bunkers.GOLD_PER_SHARE,
	Bunkers.SALVAGE_PER_SHARE))
