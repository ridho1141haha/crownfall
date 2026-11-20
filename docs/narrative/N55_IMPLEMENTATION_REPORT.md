# N5.5 Implementation Report — Voyage & Eldergrove Arrival

**Status:** IMPLEMENTED & HARDENED (`feature/n55-voyage-eldergrove-arrival`)
**Base `main` SHA:** `0cc3462934a96bc070ed7f947495c8e7a9309806`
**Owner Decision:** `D-N5-05` — Option A APPROVED (2026-11-20)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Scope Implemented

- Replaced the terminal `ISLAND_CLEARED` victory-banner dead end on Stage-3+ Shipwreck interaction in `scripts/world/ForgottenShoreSession.gd` with a distinct Set Sail -> Voyage -> Eldergrove Forest arrival flow.
- Added `scripts/narrative/EldergroveHandoffBridge.gd` for one-shot, token-guarded Forgotten Shore -> Eldergrove arrival handoff with read-only context peek helpers.
- Added a short (~4.0s), skippable, non-pausing voyage transition overlay in `ForgottenShoreSession.gd`.
- Added minimal playable destination `scenes/world/EldergroveForest.tscn` + `scripts/world/EldergroveForestArrival.gd`.
- Updated `scripts/core/Main.gd` so New Game and Continue invalidate any pending Eldergrove handoff intent.
- Added `tests/test_n55_eldergrove_handoff.gd` and registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.

## 2. Fail-Closed Destination Validation & Status Distinction

`EldergroveForestArrival._ready()` validates required destination scene nodes, pending handoff identity/token, authoritative `ProgressionState`, authoritative `EraProgressionManager`, and persistence context (`SaveManager.is_safe_save_path()` + `SaveManager.validate_payload()`) **before** acknowledging and consuming the one-shot handoff. Missing or invalid context invalidates the pending intent and rejects acknowledgement without fabricating replacement objects or recording `FACT_ELDERGROVE_REACHED`.

Arrival outcomes explicitly distinguish three separate statuses:

1. **Handoff acknowledged (`is_handoff_acknowledged()`):** One-shot token and destination context validated and consumed.
2. **Runtime milestone recorded (`is_runtime_milestone_recorded()`):** `ProgressionState.FACT_ELDERGROVE_REACHED` recorded on the authoritative instance and `EraProgressionManager.notify_eldergrove_milestone()` notified.
3. **Durable persistence (`was_persisted_on_arrival()`):** Updated `progression_facts` and `era_id` written through `SaveManager.save_state()` (bounded to `MAX_PERSIST_ATTEMPTS = 2`). If persistence fails, the previous valid save on disk is preserved by `SaveManager`, the runtime fact is kept, `arrival_persistence_failed` + `get_persistence_failure_reason()` expose the failure explicitly, and player control is restored safely.

## 3. Known Limitations & SaveManager Schema v2 Confirmation

- **Schema v2 unchanged:** `SaveManager.SCHEMA_VERSION` remains `2`. No schema v2 fields, migrations, or per-beat save flags were added.
- **Scene routing limitation:** Although `FACT_ELDERGROVE_REACHED` and `iron_age` persist in the schema v2 save file when `SaveManager.save_state()` succeeds, schema v2 does not encode multi-island scene routing, so `Main.gd` Continue still loads `ForgottenShore.tscn`.
