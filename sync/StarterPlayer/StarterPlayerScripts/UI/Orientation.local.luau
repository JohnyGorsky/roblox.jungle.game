--!strict
-- Orientation.local.luau — lock the game place to landscape on mobile (Job #094).
--
-- ── Why lock, rather than support portrait ────────────────────────────────────────────────────────
-- The in-run HUD is built around two thumbs at opposite bottom corners: steer bottom-left, throttle
-- bottom-right, vitals between them. Portrait does not have a "between them" — the corners are close
-- enough together that the two control clusters and the vitals block compete for the same strip.
--
-- It also breaks the layout outright, in a way worth recording because it is not obvious from reading
-- the scale values. Two independent failures:
--
--   1. The touch buttons are SQUARE (UIAspectRatioConstraint) inside a holder that is 0.19 wide and
--      0.16 tall. A button's width in scale-x is therefore 0.16 × H/W — so in portrait, where H > W,
--      two buttons plus padding exceed the 0.19 holder and overflow it.
--   2. `RiverProgress` carries `UISizeConstraint.MinSize = (210, 34)`. On a narrow viewport its 0.36
--      scale box is clamped UP: at 400px wide, 0.36 × 400 = 144px becomes 210px — 52% of the screen,
--      centred — and it collides with the right-aligned currency chips. The readability clamp is what
--      causes the collision, so it cannot be tuned away without making the bar unreadable instead.
--
-- Fixing both would mean an orientation-aware second layout for the whole HUD. That is a real piece of
-- design work, not a constraint tweak, so it is deliberately a separate job rather than a silent
-- expansion of this one. Locking landscape removes the failure mode instead of engineering around it.
--
-- ── Why here and not on StarterGui ────────────────────────────────────────────────────────────────
-- `StarterGui.ScreenOrientation` would be the natural home, but `StarterGui` is NOT in this repo's
-- auto-sync set (see the jungle-project skill: StarterGui/StarterPack/Workspace are manual-copy). A
-- property set there would live only in the .rbxl and would be invisible to code review and to git.
-- `PlayerGui.ScreenOrientation` is the same setting applied per player, from a script that DOES sync.
--
-- ⚠️ This covers the GAME place only. The LOBBY is a separate place with its own tree and needs the
-- same treatment; that is out of scope here and is logged as a follow-up.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- LandscapeSensor, not LandscapeLeft: the player still chooses which way up the phone is, we only
-- refuse portrait. Pinning one side would flip the screen for half the players holding it the "wrong"
-- way, which is a worse experience than the problem being solved.
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
