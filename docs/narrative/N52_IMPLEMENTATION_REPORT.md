# N5.2 Implementation Report — Mandatory First-Night Resolution (`ch1_03_first_night`)

**Status:** IMPLEMENTED & VERIFIED (feature branch `feature/n52-first-night-resolution`; not merged)
**Base `main` SHA:** `90058ec47eeeef3a957f9c023446ab5ea5c32c4f`
**Approved Decisions:** `D-N5-02` Option A (2026-11-20), `D-N5-03` Option A, `D-N5-04` Option A
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf`

---

## 1. Signal & Lifecycle Audit (Day 1 Identity)
- `TimeManager._transition_to_next_phase()` increments `current_day` from `1` to `2` **before** emitting `sunrise_reached(1)`, so `TimeManager.current_day` cannot be used to test Day 1 identity.
- `NightEncounterManager.on_night_started(day_num)` sets `current_day_number = maxi(1, day_num)` and keeps `current_day_number == 1` when `ForgottenShoreSession._on_sunrise_reached(1)` calls `night_mgr.on_sunrise_reached(building_mgr)` and emits `night_encounter_resolved(survived, wall_held)`.
- `ChapterOneNarrativeAdapter` gates N5.2 on `_night_mgr.current_day_number == 1` and `reign_state != ForgottenShoreSession.ReignState.ISLAND_CLEARED`, with zero changes to gameplay, time, encounter, or save systems.

## 2. Exact Outcome Lines & Branch Conditions
Speaker: `"Monarch"` (non-gating `DialoguePanel`, no `PlayerControlLock`, no `SceneTree.paused`):
- **`survived == true` and `wall_held == true`:** `"Dawn. The wall held through the first night—we can build from here."`
- **`survived == true` and `wall_held == false`:** `"The wall didn't survive the night, but dawn broke in time. We rebuild."`
- **`survived == false` (`ReignState.BREACH_PENALTY`):** `"They broke through and cost us dearly, but the settlement still stands. We'll recover before dusk."`

## 3. Dialogue Contention, Idempotency & Restore-Silent Policy
- Single in-memory pending N5.2 outcome (`_pending_first_night`) prevents overwriting an open N5.1 foothold panel at sunrise and displays once immediately when N5.1 closes/skips.
- `ch1_03_first_night` is recorded once in `NarrativeState`; Day 2+ sunrises, duplicates, `ISLAND_CLEARED`, startup Continue (Day 2+), and in-session restores stay completely silent.
- `teardown()` while active or pending disconnects owned signals, closes the panel, clears pending state, and records no completion.
- `SaveManager.SCHEMA_VERSION == 2` and all persisted payloads are **unchanged** (zero per-beat fields).

## 4. Verification Results
- **Godot Import (`--headless --import`):** PASS (`rc=0`)
- **N5.2 First Night (`tests/test_n52_first_night_narrative.gd`):** `PASS: All 33 N52 First Night Narrative checks completed with 0 failures.`
- **N5.1 Foothold (`tests/test_n51_foothold_beat.gd`):** `PASS: All 29 N51 First Foothold checks completed with 0 failures.`
- **N5.0 Boundary (`tests/test_n50_chapter1_boundary.gd`):** `PASS: All 23 N50 Chapter I Boundary checks completed with 0 failures.`
- **Aggregate Runner (`bash tests/run_all.sh`):** `SUMMARY: passed=35 failed=0 skipped=0` — `ALL SUITES PASSED`
- **Static Verifier (`python3 tests/verify_repo_integrity.py`):** `PASS: All 301 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`
- **Visual / Manual Gameplay Verification:** NOT RUN (headless automated verification only).

## 5. Limitations & Remaining Scope
- N5.3 (Scientist/research), N5.4 (vessel readiness), and N5.5 (voyage/Eldergrove arrival, `D-N5-05`) remain unimplemented.
