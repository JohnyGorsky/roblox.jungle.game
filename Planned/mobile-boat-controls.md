# Mobile boat controls (custom touch UI)

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
