# Mobile boat controls (custom touch UI)

> ## ✅ DELIVERED — Job #075 (2026-08-02)
> Built as `sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau`: two-thumb button
> clusters (steer ◀▶ bottom-left, throttle ▲▼ bottom-right), scale-based, safe-area aware, shown only on
> touch devices and only while seated in the DriverSeat. Writes `SteerFloat`/`ThrottleFloat` at a late
> render step, so PC keys are untouched and no new remote exists.
>
> **The open question below is answered: BUTTONS, not a joystick.** `VehicleSeat.Steer` is tri-state
> (-1/0/1), so a joystick's analogue precision quantises to the same three values while being harder to
> hit without looking — and the driver is watching the river. Reasoning is in the file header.
>
> ⚠️ **One thing left to confirm on a real device:** whether Roblox's own default VehicleSeat touch
> D-pad still draws alongside ours. `HeadsUpDisplay` (the speed gauge) is now off; the D-pad has no
> documented toggle. See `findings/`.

**Source:** Job 003 (P1) follow-up. **Depends:** P1 boat controller (#003).

P1 shipped driving on the `VehicleSeat` **default** touch controls — functional on a phone, but not the
custom, scale-based UI P1's success test really wants.

## Scope
- On-screen **steer** (left/right) + **throttle/reverse** touch controls, `UDim2` scale-based,
  safe-area aware, mapping to the same `VehicleSeat` actions (and PC keys stay working).
- Mobile-first sizing (`UIScale`/`UIAspectRatioConstraint`); respect GUI insets.
- Lives under `manual/StarterGui/` (not auto-synced) or built programmatically in a client script.

## Open questions
- On-screen buttons vs a virtual joystick for steering? (Test which reads best on a phone.)
- Reuse for other vehicles later (plane in P?), or boat-specific for now?

## Why it matters
Fully closes P1's "runs on a phone with touch controls" success criterion with a purpose-built UI.

→ Promote to a job.
