# TODO 0059: MOBILE GUI OVERLAP PASS — real-phone screenshot shows the lobby HUD colliding badly (incl. 2 regressions from Job #095)

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-18)
**Created:** 2026-08-18 17:15:10

Source: user's real-phone screenshot of the LOBBY, 2026-08-18. Aspect looks ~2.16:1 (a modern 19.5:9 phone in landscape). REQUIREMENT FROM USER: invoke ALL GUI skills for this task (roblox-ui, jungle-style, plus roblox-optimization/roblox-dev as needed) - do not treat it as a quick nudge.

WHAT THE SCREENSHOT SHOWS (top-left to bottom-right):
 1. REGRESSION (Job #095): the EntryBar rail is now TOO TALL and runs off the TOP of the screen - the first item (BOAT/wrench) is cut off at y=0, and SKILLS sits under the Roblox core chrome. #095 raised the rail MinSize height 240 -> 420 to clear the 58px thumb floor. On a 16:9 test preset that fit; on a real 2.16:1 phone the viewport is proportionally much shorter and 420px no longer fits.
 2. REGRESSION (Job #095): the LobbyHint text is CLIPPED - reads 'STEP ON A LAUNCH PAD TO' and 'First on a pad leads - hold Start to launch the', both cut mid-sentence. #095 narrowed that panel 0.44 -> 0.32 to clear the TopBar. It cleared the overlap and broke the text.
 3. Roblox CORE UI (logo, menu, chat, voice) overlaps BOTH the TopBar identity panel and the top of the rail. Our ScreenGuis use CoreUISafeInsets, so this needs investigating - either the inset is not being honoured or our elements start above it.
 4. TopBar identity panel overlaps the SKILLS rail button on the left.
 5. Roblox player-list / leaderboard ('Castaway / Mekky008 0') overlaps the rail and the identity panel.
 6. The ROBUX SHOP ProximityPrompt overlaps the in-world shop sign and is half off the readable area.

ROOT CAUSE OF THE MISS: Job #094/#095/#097 swept 1136x640, 1334x750, 1620x1080, 1920x1080 - a MAXIMUM aspect of 1.78:1. Modern phones are 19.5:9 (2.17) or 20:9 (2.22). The whole mobile pass never tested the aspect real players actually have. tools/hud-overlap-audit.luau's VIEWPORTS table must gain 2.17:1 and 2.22:1 entries, and every earlier conclusion should be re-run against them.

ALSO: the harness only ever measured OUR ScreenGuis against each other. It never accounted for Roblox's own CoreGui (topbar, chat, player list), which items 3 and 5 show is a real collider. GetGuiInset / CoreUISafeInsets behaviour needs verifying on a real device, not assumed.

---

## RESOLUTION (Job #099, 2026-08-18) — and a correction to this todo's own diagnosis

Promoted into **[Job #099](../Jobs/099/)**. Both regressions fixed, but **this todo blamed the wrong
cause**:

- It said the aspect matrix (1.78:1 tested vs 2.16:1 real) was the root cause. That gap is real, but it
  is NOT what broke the rail. Measured at the exact reported phone dimensions, the rail was clear at
  every aspect.
- The actual cause is **DPI**: a *pixel* `MinSize` does not scale with the device's GUI coordinate
  space, which on a high-DPI phone can be far smaller than the screenshot resolution. #095's hard
  `420px` floor becomes ~87% of the canvas on a device reporting ~1200×540.
- The hint clipping was **vertical**, not horizontal: `applyText`'s 12px `MinTextSize` floor means text
  wraps rather than shrinking, and #095's narrowing pushed the title to two lines in a one-line box.

Fixed by removing the dependence on absolute pixel sizes rather than by picking better numbers — the
rail now sizes from the canvas (≤62%, badge 58 degrading to 44), and the hint has room for two wrapped
lines. Verified with no overlaps across six canvases including a DPI-scaled one.

**Still open elsewhere:** a real-device screenshot to confirm, folded into todo #0058.
