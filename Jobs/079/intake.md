# Job #079: Axe melee weapon — reuse Defender's model, animations and sounds

**Project**: `roblox.jungle`
**Created**: 2026-08-15
**Status**: **Audited + decided — ready to plan.** Scope grew to ALL FOUR held items; see "Decisions".

## Requirements / goal

Replace Jungle's greybox melee with the **Rusty Axe from roblox.defender**, reusing its Tool model, its
`axeSlash` animations and its `AxeSwing` / `AxeChop` / `Equip` sounds. Same cross-game reuse route that
gave Jungle its Wolf, Bandit and Boar for zero credits in Job #078.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Audit done — both sides measured, all ids captured (below)
- [x] Open questions answered (wizard) — see "Decisions taken"
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written

---

# The audit

## What Jungle has today — measured from the code

| Thing | State |
|---|---|
| The weapon | `ItemDefs.Items.Sword` — `kind = "Melee"`, damage **15**, `meleeRange` **9**, `swingInterval` **0.6** |
| The visual | `InventoryService.updateHeldVisual` builds a **coloured Part**: `0.25 × 4 × 0.25`, SmoothPlastic, welded to `RightHand`. Comment calls it "the greybox held-item visual". |
| The swing | `MeleeServer.server.luau` — client fires the `SwordSwing` remote (no hit claim), server validates holder + cooldown + range and applies damage. Server-authoritative and fine. |
| **Animation** | **NONE.** Nothing anywhere plays a swing animation. |
| **Sound** | **NONE.** `MeleeServer` has no `Sound` at all — hitting an enemy is silent. |
| Who gets it | `InventoryService` gives **every player** a `Sword` in slot 1 and a `Torch` in slot 2 on spawn. |

> ⚠️ **The greybox held-item system covers guns and the torch too**, and all four are now IN SCOPE.
> `updateHeldVisual` builds a `0.4 × 0.6 × 1.2` "barrel" for Pistol, `0.4 × 0.6 × 2.4` for Shotgun, and a
> Neon tip + PointLight for the Torch. One function, one class of problem — which is exactly why the
> scope was widened.

## What Defender has ready — captured live from the place

| Asset | Where / id |
|---|---|
| Tool model | `ServerStorage.Assets.Weapons.Items.Axe` — a `Tool` with `Handle` (**0.40 × 3.00 × 0.80**), a `ToolScript`, and a bundled `Equip` Sound |
| `AxeSwing` | `rbxassetid://210946558` |
| `AxeChop` (hit) | `rbxassetid://8936215056` |
| `Equip` | `rbxassetid://2304904662` (bundled inside the Tool) |
| Animations | `axeSlash.slash1` **567480700** · `axeSlash.slash2` **567479941** — Defender alternates the two |
| Defender stats | damage **20**, stagger **0.2**, knockback **50**, `hitEffects = "Axe"` (heavy chop + wood debris) |

Wiring reference: `ToolDefinitions.SetUpRustyAxe` →
`PrepareToolAndInsertInstance("axe", "Rusty axe", 1, "Axe", "AxeChop", "AxeSwing", "axeSlash", …)`.

> ⚠️ **Two near-duplicate sound pairs exist in Defender and only one is the axe's.** `ReplicatedStorage.Sounds`
> also holds `SwingAxe` (541909763) and `HitAxe` (201858024), both at **volume 10.0**. Those are the
> generic block's names, NOT what `SetUpRustyAxe` passes. Take **`AxeSwing`/`AxeChop`**.

## What actually has to be built

1. **Model** — import/copy the `Axe` Tool into `ServerStorage.AssetLibrary` (a `Weapons` group), strip
   Defender's `ToolScript`, and swap the melee branch of `updateHeldVisual` from a Part to a clone of the
   real handle, welded to `RightHand` as it is now.
2. **Animation** — load `slash1`/`slash2` onto the **player character's own Animator** and alternate them
   per swing. Unlike Job #078's creatures, players are real Humanoids, so this is the easy case: no rig
   work, no joint swinging.
3. **Sound** — `AxeSwing` on every swing, `AxeChop` only on a landed hit, `Equip` on selecting the slot.
   Positional, on the handle, per the `GameSoundscape` rule.
4. **Where it fires from.** `MeleeServer` is the authority and already knows swing-vs-hit, so it is the
   natural place — but animation is best played on the client that owns the character. Decide once and
   write it down; a swing that animates on the server and sounds on the client will drift.

## ⚠️ Balance — SETTLED, and this job must not move it

Defender's axe does **20**; Jungle's melee does **15**. Enemy HP:
`Piranha 15 · Boar 40 · Crocodile 40 · Wolf 55 · Bandit 55 · RiverHippo 120`.

**Decision: stay at 15.** At 15 a Wolf/Bandit takes 4 hits, a Boar 3, a Crocodile 3. At 20 those become
3 and 2 — a real difficulty change to the on-foot camp raid that Jobs 015 and 058 tuned. `meleeRange` 9
and `swingInterval` 0.6 are unchanged too. **Do not import Defender's 20 along with its art.**

---

# Decisions taken (2026-08-15)

| | |
|---|---|
| **Role** | The **Axe is the STARTING weapon** — it replaces `Sword` outright, everyone spawns with it in slot 1, and every other weapon is an upgrade on it. |
| **Damage** | **Keep 15.** A pure art/audio port with no difficulty change: a Wolf/Bandit still takes 4 hits, a Boar 3, a Crocodile 3. Melee stays 25 DPS against Pistol 91 and Shotgun 103, so "everything else is better" holds by a wide margin. Jobs 015 and 058 tuned the on-foot raid against these numbers and this job must not move them. |
| **Scope** | **ALL FOUR held items** — Axe, Pistol, Shotgun and Torch. `updateHeldVisual` is one function and they are one class of problem, so nothing in your hands stays a coloured box. |
| **Stagger / knockback** | **Left out.** They are new combat mechanics, not part of a model port, and Jungle's enemies are kinematic (`PivotTo`, not physics) so knockback would have to be written from scratch against the leash and bite-range logic Jobs 006–009 and 053 tuned. |

# ⚠️ What the expanded scope actually costs — audited live in the Defender place

**Defender has NO firearms and NO torches.** Its `ServerStorage.Assets.Weapons.Items` holds **11 Tools
and every one is melee**: `Axe`, `SimpleSword`, `LightningSword`, `IceDragonSword`, `Dark Sword`,
`WolfMace`, `TitanHammer`, and three sticks. A search of the whole of `ServerStorage` for
gun/pistol/rifle/shotgun/torch/lantern/lamp returns **nothing**.

So the four items split cleanly:

| Item | Model | Sound | Animation |
|---|---|---|---|
| **Axe** | ✅ reuse Defender's Tool | ✅ `AxeSwing` 210946558 · `AxeChop` 8936215056 · `Equip` 2304904662 | ✅ `axeSlash` 567480700 / 567479941 |
| **Pistol** | ❌ **must be sourced** | ✅ `gun_shot` **138178318678571** already uploaded + owned, **never wired** (ASSETS.md §3.2) | — |
| **Shotgun** | ❌ **must be sourced** | ✅ shares `gun_shot`; a heavier variant would be better | — |
| **Torch** | ❌ **must be sourced or BUILT** | — | — |

### Recommended sourcing

- **Pistol / Shotgun** — Meshy, same route as the creatures. Small props, low tri budget, seen only in
  first/third person at the hip.
- **Torch — BUILD it, don't source it.** It is a stick plus a flame, and Job #077 already established
  the recipe (`Campfire.luau`: rock/log dressing + `Fire` + ember `ParticleEmitter` + `PointLight`).
  The torch branch of `updateHeldVisual` already creates the `PointLight` and tags it `NightLight` for
  `LightController` — so building it means reusing wiring that is already correct, and it stays
  on-palette without a single credit.

### Sound gaps this opens

- `gun_shot` is uploaded and unwired — this job is where it lands. It wants to be **positional on the
  barrel with a fire-rate-aware cooldown**, or sustained fire stacks one `Sound` per bullet (the same
  stacking trap `GameSoundscape` documents for the cicadas).
- `empty_gun.mp3` exists locally at `assets/GameObjects/Sounds/empty_gun.mp3` and is **not uploaded** —
  the dry-fire click. Worth uploading in the same sitting.
- The Torch has no sound at all; a soft flame crackle could reuse `crackle-campfire` 113774133604878,
  already owned and already used by the camps.

## Still open

Nothing blocking. The plan should decide where animation is played (client-owned character vs server)
and settle it once — a swing that animates on the server and sounds on the client will drift.
