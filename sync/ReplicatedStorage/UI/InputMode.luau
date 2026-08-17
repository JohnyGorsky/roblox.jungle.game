--!strict
-- InputMode.luau — who owns the mouse right now (Job #092). CLIENT USE ONLY.
--
-- Two first-person problems share one piece of state, so they share one module rather than two scripts
-- fighting over `UserInputService`:
--
--   · *"if we switch to first person then mouse and cursor is in same place"* — the OS mouse icon is
--     drawn on top of the game's crosshair.
--   · *"if you are in first person and open shop then mouse not working to close shop"* — you cannot
--     move the pointer onto the close button at all.
--
-- ── ⚠️ WHY THE SHOP FIX HAS TO LEAVE FIRST PERSON ────────────────────────────────────────────────
-- The obvious fix — set `UserInputService.MouseBehavior = Default` while a panel is open — DOES NOT
-- WORK, and it is worth writing down so nobody spends an afternoon on it. Roblox's own PlayerModule
-- camera re-asserts `LockCenter` every frame while the camera is in first person. An external write is
-- overwritten on the next frame, so the cursor stays pinned to the middle of the screen and the panel
-- stays unclosable. Writing it every RenderStep just means fighting the camera script for the pointer.
--
-- The reliable lever is the CAMERA, not the mouse: raise `Player.CameraMinZoomDistance` so the camera
-- is forced out of first person for as long as the panel is open, then put it back. Roblox then frees
-- the mouse itself, because it is no longer in first person. The view pops out to third person while a
-- panel is up — which is what most Roblox games with a first-person mode do, and it also means the
-- player can see the panel without their own weapon in the way.
--
-- ── Reference-counted on purpose ─────────────────────────────────────────────────────────────────
-- `pushUI`/`popUI` count rather than toggle: the shop can be open while a confirmation panel opens
-- over it, and a naive boolean would hand the mouse back the moment the INNER one closed. The zoom
-- settings are captured on the first push and restored on the last pop.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local InputMode = {}

-- Below this the camera is effectively inside the character's head. Roblox's own first-person
-- threshold is 0.5 studs of zoom; measuring camera-to-head is more robust than reading zoom state,
-- because it is also correct while the camera is mid-tween between the two.
local FIRST_PERSON_DIST = 2

-- How far out to force the camera while a panel is open. Must be > the first-person threshold by a
-- clear margin, or the camera can sit on the boundary and flicker in and out.
local UI_MIN_ZOOM = 8

local uiCount = 0
local savedMinZoom: number? = nil

-- Is the local camera in first person RIGHT NOW? Distance-based, so it is true whether the player got
-- there by scrolling in or because something forced `CameraMode`.
function InputMode.isFirstPerson(): boolean
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not cam or not head or not head:IsA("BasePart") then
		return false
	end
	return (cam.CFrame.Position - head.Position).Magnitude < FIRST_PERSON_DIST
end

-- True while any modal panel is open — the mouse belongs to the UI, not to aiming.
function InputMode.uiOpen(): boolean
	return uiCount > 0
end

function InputMode.pushUI()
	uiCount += 1
	if uiCount ~= 1 then
		return -- already released; a nested panel must not re-capture the saved zoom
	end
	savedMinZoom = player.CameraMinZoomDistance
	-- ⚠️ Never push Min past Max, or the camera is left in an impossible state and Roblox clamps
	-- unpredictably. A player who has deliberately capped their zoom keeps their cap.
	player.CameraMinZoomDistance = math.min(UI_MIN_ZOOM, player.CameraMaxZoomDistance)
	UserInputService.MouseIconEnabled = true
end

function InputMode.popUI()
	if uiCount == 0 then
		return -- defensive: a double-close must not drive the count negative and strand the camera
	end
	uiCount -= 1
	if uiCount > 0 then
		return
	end
	if savedMinZoom ~= nil then
		player.CameraMinZoomDistance = savedMinZoom
		savedMinZoom = nil
	end
	-- The icon is handed straight back to FirstPersonClient, which decides frame by frame whether it
	-- should be shown. Deliberately not forced here: this module owns "who has the mouse", not "how
	-- the pointer looks".
end

return InputMode
