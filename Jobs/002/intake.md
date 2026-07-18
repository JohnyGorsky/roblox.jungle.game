# Job #002: P0 — Set up Jungle project (Rojo project, analyzer, sourcemap, skill)

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: In progress

## Goal

Complete the technical foundation so we can build gameplay: give the project a Rojo mapping and a
working luau-lsp analyzer, and turn the `jungle-project` skill from a stub into the real source of
truth. (Roadmap phase **P0**; unblocks P1+.)

## Already done (by the user)

- The on-disk **`sync/` structure exists** and **sync is verified working** — all six auto-sync
  services round-trip disk↔Studio (checked live via the Studio MCP, 2026-07-18): `ReplicatedFirst`,
  `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, and both `StarterPlayer/
  StarterCharacterScripts` + `StarterPlayerScripts`. Also `assets/` and `manual/` folders exist.

## Steps

1. **`default.project.json`** — Rojo mapping of `sync/<Service>` → services (for sourcemap; Studio's
   own sync already handles the live round-trip).
2. **`.vscode/settings.json`** — luau-lsp config (roblox platform, sourcemap from the Rojo project).
3. **`tools/luau-analyze.sh`** — analyzer wrapper (mirrors Defender's), targets the `sync/` roots.
4. **`sourcemap.json`** — generate via Rojo; confirm the analyzer runs clean on the demo files.
5. **`jungle-project` skill** — unstub: confirmed sync table, analyzer command, Rojo suffix
   convention (`*.server.luau`/`*.local.luau`/`*.luau`), folder map (`sync/`, `assets/`, `manual/`).

## Verification

- [ ] `rojo sourcemap` produces `sourcemap.json`.
- [ ] `bash tools/luau-analyze.sh` runs and reports diagnostics (clean on the `print("Hello world!")` demos).
- [ ] `jungle-project` skill no longer marked STUB.
