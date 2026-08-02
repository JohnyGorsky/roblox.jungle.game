# TODO 0030: OPTIONAL (Job 068 B8): Countdown / launch music layer on the party pad

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — CLOSED AS DECLINED -- user decision 2026-08-02 (Job 069). The launch moment is NOT silent: timer_countdown fires positionally on the pad each second and teleport_woosh plays with the launch VFX, both verified wired. The deciding argument is length: LobbyConfig.COUNTDOWN is 3 SECONDS. A rising music layer cannot establish itself in 3s before the teleport cuts it -- games that do this well build over 10+ seconds -- so the feature would only be worth having if the countdown were lengthened, and that is a gameplay change (every party waits longer to start a run) nobody has asked for in exchange for an audio flourish. ASSETS.md 1.13 already marked this optional and pending an upload that was never made. If it is ever revisited, the cheap version needing NO new asset is to duck the lobby music during the countdown and cut it on the whoosh.
**Created:** 2026-08-02 10:51:16

Audit Job 068, gap B8. ASSETS.md 1.13, pending, and marked optional in the doc itself -- not yet uploaded. The launch moment is NOT silent today: teleport_woosh fires with the launch VFX and timer_countdown ticks every second, both positional on the pad. This would be an extra musical layer on top.
