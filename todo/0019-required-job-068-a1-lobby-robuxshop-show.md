# TODO 0019: REQUIRED (Job 068 A1): Lobby RobuxShop shows a buy button for passes the player already owns

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:30

Audit Job 068, gap A1. RobuxShop.local.luau:100 gates each pass row on `gamePassId > 0` -- "does this product exist", never "does this player own it". MonetizationServer already sets Owns_<key> on the player and this screen never reads it, so an owner of Armored Boat still sees a live R$ 499 button; only Roblox dialog tells them. It is the ONLY lobby shop with no owned state (ModulesShop=OWNED, SkillShop=MAX, RetentionClient=CLAIMED, PaintShop locks swatches). The `check` icon was sourced for exactly this (ASSETS.md 1.9 row 8). Open question: disable the row with a check badge, or hide owned passes entirely?
