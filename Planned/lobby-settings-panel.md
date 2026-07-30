# Settings panel (lobby + game)

**Raised:** 2026-07-30, during Job #065 (lobby GUI restyle). Deliberately kept OUT of #065 — that job
is a restyle, and settings is new functionality with its own persistence design.

## Why

No settings panel exists anywhere in the game. `GUI_PATTERN.png`'s bottom bar shows a settings icon,
and mobile players expect at least a volume control — the lobby has a full soundscape (music, jungle
ambience, wind, water, campfires, cicadas) with no way to turn it down.

## Scope sketch

- **Music volume · SFX volume** — the two that matter; the soundscape and `UISound` layer both read them.
- Possibly: graphics/quality hint for low-end phones, and a mute-on-background toggle.
- **Persistence question (the real design work):** stored in the player profile (`ProfileConfig`, so it
  survives across places and sessions) or client-local? Profile is the better player experience but
  costs a schema field + migration.
- Uses the **slider** and **toggle** components from `GUI_PATTERN.png` §UI ELEMENTS — the only place in
  the game that needs them, which is why #065 doesn't build them.

## Depends on

Job #065's `Theme` / `Components` modules — build this after, so it inherits the design system for free.
