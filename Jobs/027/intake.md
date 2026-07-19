# Job #027: Robux monetization: Gold packs + Armored Boat + skin

**Project**: `roblox.jungle`
**Created**: 2026-07-19 11:41:18
**Status**: Requirements Gathering (intake)

## Requirements / goal

POC lean launch. Developer product Gold packs (ProcessReceipt idempotency) at Bonds-parity prices; Armored Boat premium vehicle game pass (Robux-only, +20pct hull HP and +20pct mounted-weapon damage - the one exclusive-power item); one cosmetic Boat Paint pass. Depends on Persistence foundation (Gold credit) and Boat modules (boat variants). Design source: Job 020 section 6.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created (`implementation-plan.md`)
- [x] Implementation completed — armored-boat effect + receipt-mapping/idempotency + shop UI verified in
      Studio; real Robux prompts pending a published place; analyzer-clean
- [x] Final summary + changelog written (incl. Creator Hub product checklist)
- [x] **Human step:** products created on Creator Hub + IDs pasted into `MonetizationDefs` (both trees)
      — Gold packs 3610663250/288/341/385; passes Armored 1919001295, Paint 1919355255, Cosmetic 1918077339
- [ ] **Remaining:** publish the places + live-test a real purchase (Studio can't complete transactions)
