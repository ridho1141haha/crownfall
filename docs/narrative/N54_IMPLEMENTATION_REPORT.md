# N5.4 Implementation Report — Vessel Readiness Narrative (`ch1_07_prepare_vessel`)

**Status:** IMPLEMENTED & VERIFIED (feature branch `feature/n54-vessel-readiness-narrative`; not merged)
**Base `main` SHA:** `5abf2d117b8404c6ada56d3ae801c2f3143bac83`
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf`

---

## 1. Beat Identity & Exact Dialogue Line
- **Beat ID:** `ch1_07_prepare_vessel`
- **Speaker:** `"Monarch"`
- **Text:** `"The repairs are complete. The vessel is ready to leave this shore."`

## 2. Fact-Before-Signal Ordering & Live-vs-Historical Detection
- `ForgottenShoreSession._on_player_interact_shipwreck()` calls `progression.record_fact(ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)` *before* `fact_recorded` emits synchronously, so `has_fact(...)` is already `true` inside `_on_progression_fact_recorded()`.
- `_refresh_historical_flags()` sets `_vessel_ready_historical_passed = true` **only** during `setup()` and `end_save_restore(true)`.
- During live dispatch, when `fact_recorded(FACT_FORGOTTEN_SHORE_VESSEL_READY)` arrives with `_vessel_ready_historical_passed == false`, the handler sets `_vessel_ready_historical_passed = true` *before* enqueueing/presenting, preventing duplicate display while preserving live triggers.

## 3. Contention, Non-Gating & Scope Guarantees
- **Fixed 5-slot pending priority:** `first_night → vessel_ready → scientist_discovery → scientist_recruitment → first_research` (zero unbounded queues, zero save fields).
- Repair and Set Sail remain completely non-gating: Set Sail (`ReignState.ISLAND_CLEARED`) works with or without Scientist/research and even while the readiness panel is open.
- **Explicit boundary:** N5.4 never records `FACT_ELDERGROVE_REACHED`; Stage-3 readiness != Set Sail != voyage != Eldergrove arrival.
- `SaveManager.SCHEMA_VERSION == 2` and serialized payloads are unchanged.

## 4. Verification Results
- **Godot Import:** PASS (`rc=0`)
- **N5.4 Suite (`tests/test_n54_vessel_readiness_narrative.gd`):** `PASS: All 35 N54 Vessel Readiness Narrative checks completed with 0 failures.`
- **N5.0–N5.3 Regressions:** PASS (`rc=0`; `PASS: All 57 N53 Scientist Research Narrative checks completed with 0 failures.`)
- **Aggregate Runner (`bash tests/run_all.sh`):** `SUMMARY: passed=37 failed=0 skipped=0` — `ALL SUITES PASSED`
- **Static Verifier (`python3 tests/verify_repo_integrity.py`):** `PASS: All 307 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`
- **CI Status:** Pending (registered in `.github/workflows/godot-ci.yml`).
- **Manual / Visual Verification:** NOT RUN (headless verification only).

## 5. Deferred Scope
- N5.5 (voyage & Eldergrove Forest arrival, `FACT_ELDERGROVE_REACHED`) and `D-N5-05` remain deferred/OPEN.
