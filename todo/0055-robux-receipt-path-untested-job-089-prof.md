# TODO 0055: Robux receipt path untested (Job 089 ProfileStore rewrite)

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-17 16:25:20

BEFORE PUBLIC. Job #089 rewrote processReceipt onto ProfileStore's official PurchaseIdCheckAsync pattern - grant into memory, then YIELD inside ProcessReceipt until Profile.LastSavedData proves the write landed. It is the strictest and most-changed code in that job, and the 2026-08-17 playtest confirmed saving/teleport but made NO purchase, so the money path has never run. Three deliberate checks: (1) buy a Gold pack - Gold appears immediately, receipt settles once; (2) buy the same pack again - a second purchase must grant again; (3) Studio with API services OFF - the purchase must be REFUSED, not consumed, because ProfileStore silently swaps in an in-memory mock store there and a receipt eaten into it is gone. Live product ids: gold packs 3610663250/288/341/385, selfRevive 3612677893.
