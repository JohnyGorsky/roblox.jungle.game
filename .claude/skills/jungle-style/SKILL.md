---
name: jungle-style
description: Last River (Jungle) art & UI design system — the game's colors, typography, art-direction principles, UI/HUD rules, lighting/materials, and hard do/don't rules for the "stylized tropical jungle expedition" look. Use when building or restyling ANY GUI/HUD, menu, panel, button, model, prop, sign, boat, VFX, lighting, or scene for Roblox Jungle (Last River), so it matches the game's look. The full reference is the repo-root STYLEGUIDE.md. (What the game needs + what's used lives in the root ASSETS.md asset bible; concrete asset IDs live in the shared registry — not here.)
---

# Last River (Jungle) — Art & UI Style System

The design system for **Roblox Jungle (working title: Last River)**. Use it whenever you create or
modify anything visual so the result matches the game's **stylized tropical jungle expedition** look.

> This is the Jungle-specific design skill (all games' skills load at once — this one is for
> **Jungle/Last River**, not Defender). It is the umbrella over the engine skills (`roblox-ui`,
> `roblox-vfx`, `roblox-audio`, `roblox-terrain`, …): those say *how* to build in Roblox; this says
> *what Last River should look and feel like*.

## How to use

1. **Read the authoritative full guide first:** [../../../STYLEGUIDE.md](../../../STYLEGUIDE.md)
   (repo root). It is the single source of truth — 14 sections: pillars, art direction, full palette,
   typography, the complete UI/HUD kit, iconography, lighting/VFX, audio, materials, naming, do/don't
   rules, references, and the quality checklist.
2. **Apply the quick reference below** for the essentials, then confirm details against the full guide.
3. **Run the quality checklist** (§14 of the full guide) before delivering any visual work.
4. If a value you need isn't defined, **ask via the wizard** — don't invent brand values.

## Scope

- **This skill / STYLEGUIDE.md = the design system:** colors, principles, typography, UI rules,
  lighting/materials, do/don't. Stable, rarely changes.
- **Concrete assets are OUT of scope here** but have a fixed home: **what the game needs + what's used +
  sourcing status** lives in the game-wide asset bible **[../../../ASSETS.md](../../../ASSETS.md)**
  (always reference & update it when an asset is used); **exact asset IDs / license / scan state** live in
  the shared **registry** `../../../../roblox.workspace/Assets/registry/` (see `roblox-assets`). This
  guide defines the *style/vocabulary* of icons etc.; it does not hold their IDs.

## Quick reference

**Art direction** — Stylized Tropical Jungle Expedition (Vietnam-era jungle, old airfield, military
outpost). **Detailed-stylized, NOT flat low-poly:** chunky readable silhouettes + weathered
meshes/materials + warm cinematic light. Target mix 70% stylized Roblox / 20% cinematic / 10% realism.
Everything worn/handmade; environmental storytelling; **world test** — *"could this exist in a lost
jungle expedition outpost?"*

**Key colors** (full palette in §4; all via `Color3.fromRGB()`):
- Jungle: Main `#31552B` · Palm Leaf `#47713A` — use *several* greens, never one flat/neon green.
- Sand/dirt: Main Sand `#C8A36A` — mix sand/dirt/mud/grass, never flat.
- Wood: Weathered `#72502D` · Planks `#806142` (also the UI border tone).
- Military/metal: Olive `#59613B` · Dark Metal `#353A35` — faded, never glossy.
- Water: Tropical River `#247786` — saturated turquoise-blue, not beach-blue.
- UI panels: Dark UI `#24352D` / Dark Navy `#243542`; **text = Cream `#F3E6C2`** (never pure white) + dark stroke.
- Accents (mean *something*, use sparingly): **Gold `#D69B22`** = progression · **Green `#4B7A2B`** =
  boat/mechanical & primary buttons · **Blue `#356B9A`** = utility & secondary · **Red `#A84B3C`** =
  danger/cancel · **Yellow `#D5A12B`** = warning.

**Fonts** (Roblox `FontFace`, no upload): **Builder Sans** (all UI) · **Oswald** (poster headings) ·
**Special Elite** + **Permanent Marker** (physical world signs/labels only) · **Roboto Mono**
(optional HUD numbers). Headings ALL CAPS; body normal case.

**UI style** — match the physical world (military/crate/wood/metal): rounded rectangles, thick
borders, slight bevel, subtle texture. **No futuristic glass, no heavy gradients.** Buttons: Primary
(green) · Secondary (blue) · Gold · Danger (red), cream text + dark stroke, with hover/pressed/disabled
states.

**Mobile-first & quiet HUD (hard rules)** — `UDim2` scale not pixels; safe-area aware; thumb-sized
targets; test on a phone. **In-game show ONLY mandatory info** (health, coins, fuel, ammo). Every
other panel is **closable (`X` + tap-outside) AND collapsible**; heavy panels (daily tasks, shop)
**default collapsed** during play; one primary panel open at a time; a panel never covers the core
HUD; notifications auto-dismiss. Keep the screen uncluttered — no noise while playing.

**Juice — audio + VFX on every action (hard principle).** This is an **audio-rich, VFX-rich** game.
*Every meaningful action has a sound* (shoot/reload/empty/melee/hit/enemy attack/engine/dock/pickup/
UI/level-up) and matching **particles/emitters** — boat engine smoke, bow wake & side waves, **water
splash when shots hit water**, muzzle flash + tracer, impact bursts (water/wood/metal/flesh), dust,
fireflies, upgrade bursts. Build effects as **pooled, palette-tinted, distance-LOD'd, off-screen-
culled, budget-capped** templates; 3D-positioned sound with rolloff, mixed so key cues cut through.
Juice, not noise. (Full VFX + SFX vocabulary in §8/§9.)

**Lighting/materials** — warm cinematic late-afternoon; play area brighter than jungle; night = warm
pools of light (lanterns/torches), never evenly lit. Materials weathered & readable (Wood/Metal/
CorrodedMetal/Sand/Rock/Grass + MaterialVariants), not high-frequency PBR. Respect the mobile-perf
budget (cap dynamic lights + concurrent particles/sounds, cull, sensible tri/texture budget).

**Never** — sci-fi/glass UI, clean/glossy/modern/symmetrical builds, photoreal **or** flat-cartoon
assets, neon everywhere, random props, tiny unreadable objects, pixel-fixed UI, or a crowded/covered
in-game HUD.
