# TODO 0035: Job 068: three ASSETS.md rows claim more than the code delivers -- correct them

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — Done in Job 069, 2026-08-02. All ASSETS.md corrections applied and verified (grep confirms no stale claim remains). Changes: (1) 1.11 split "Jungle day ambience 1 & 2 wired" into ambience 1 = wired and ambience 2 = uploaded-but-NOT-wired. (2) 1.6 Weekly placeholder row KEPT (the doc was right) but annotated that it is editor-placed, which is why a source grep finds nothing -- the exact trap that produced the false finding. (3) 1.9 screen list corrected: GoldHud was REPLACED by TopBar in Job 065, and PaintShop/EntryBar/AdminClient were missing. (4) 1.3 sign-board row marked done (all 4 stations verified), and the two station rows that omitted "entry sign" now mention it, with a note that a row omitting something is not evidence the thing is missing. (5) 1.8 airfield star marked done-by-design. (6) 1.11 water row: now records that it NEVER played until Job 069 despite reading "wired", and gives the real path Dock.Dock.Pier. (7) 1.6 watchtower count 2 -> 4, with the duplicate-name warning and the prefix-matching rule. (8) 1.11 rope-creak row: reached 2 of 4 until Job 069. PLUS: 1.8 runway row records that greybox RunwayMarkings is kept deliberately; a pointer to the new LOBBY-ASSET-INVENTORY.md was added to the "How this file works" section; and a standing warning was added at the top -- THIS FILE DESCRIBES INTENT, THE PLACE IS GROUND TRUTH -- naming the editor-placed trap that caused all four false findings.
**Created:** 2026-08-02 10:51:17

Audit Job 068, doc corrections needed regardless of which gaps get built. (1) Section 1.11 says "Jungle day ambience 1 AND 2 -- wired"; only ambience 1 is wired (see gap B4 todo). (2) Section 1.6 says Weekly = "coming soon" placeholder; there is no placeholder in code, the board is empty (see gap B1 todo). (3) Section 1.9 lists the lobby screens as GoldHud/RobuxShop/SkillShop/ModulesShop/RetentionClient -- it omits PaintShop, TopBar, AdminClient and EntryBar, which all exist and consume icons (and GoldHud was REPLACED by TopBar in Job 065).

## Updated by the Job #068 live sweep + user rulings (2026-08-02)

Item (2) above is **WRONG and must not be actioned** — the sweep found the placeholder does exist
(`Leaderboard_Weekly.Board.BoardGui` → "WEEKLY TOP RUNS" + "coming soon"). It is editor-placed, which
is why no script references it. §1.6 was accurate. See `todo/0021`.

**Corrections to make, revised list:**

1. §1.11 — *"Jungle day ambience 1 **& 2** ✅ wired"* → **only ambience 1 is wired.** (`todo/0026`)
2. ~~§1.6 Weekly placeholder~~ — **withdrawn, the doc was right.**
3. §1.9 — screen list omits `PaintShop`, `TopBar`, `AdminClient`, `EntryBar`; and `GoldHud` was
   replaced by `TopBar` in Job 065.
4. **§1.3 last row** — *"Sign boards (per station) · 4+ · ▫ queued"* → **done.** All four stations have
   a real 3-D `EntrySign` (Board 8×3×0.4 on two Posts). Also make the four §1.3 station rows
   consistent: two mention "entry sign" in their notes and two don't, which is exactly what caused the
   audit to report a false gap. See `todo/0018`.
5. **§1.8 "Airfield star (spawn)"** — currently *"⏸ pending (you)"* → **done by design.** User ruled
   2026-08-02 that the existing cream disc IS the intended spawn marker; no painted star decal is
   needed. Same for the runway markings. See `todo/0022` / `todo/0036`.
6. **§1.11 water row** — *"Water lapping @ `Dock.Pier` ✅ wired"* → it **never attached** (wrong lookup
   path). Fixed in Job 069 (`todo/0037`); the row is now true, but note the real path is
   `Scenery.Dock.Dock.Pier` and the lookup is recursive.
7. **§1.6 "Watchtower | 2"** → **4.** The place has four towers and the user confirmed all four are
   intended (2026-08-02). Note in the row that three of them are *named* `Watchtower_NW` — the two
   southern ones kept that name deliberately, and `LobbySoundscape` now finds towers by the
   `^Watchtower` name prefix rather than by exact name, so the duplication is harmless.
   See `todo/0038`.
8. **§1.11 rope-creak row** — currently *"@ watchtowers"*; it attached to **2 of 4** until Job 069.
   Now all four.
