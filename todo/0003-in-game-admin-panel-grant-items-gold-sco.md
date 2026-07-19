# TODO 0003: In-game admin panel (grant items/gold/score to users)

**Project:** `roblox.jungle`
**Status:** resolved (2026-07-19) — promoted to a job
**Created:** 2026-07-19 14:01:16

Replace the Studio-only DevGrant hack with a proper ADMIN PANEL: a GUI accessible only to authorized users (allowlist of UserIds / group rank). From it, an admin can grant gold, River Score, modules, items, etc. to themselves OR to other players (pick a target). Server-authoritative with the allowlist checked server-side (never trust client). Useful for live moderation, support, testing, events. Supersedes DevGrant.server.luau (Studio-only). Consider audit logging of admin actions.
