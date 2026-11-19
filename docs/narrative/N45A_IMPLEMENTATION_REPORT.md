# N4.5-A Implementation Report — Voyage & Shipwreck

**Status:** IMPLEMENTED & VERIFIED (N4.5-A; N4.5-B `pl_09` & completion marking remain unimplemented)
**Baseline (`main`):** `933cf8eb8d30ec4cacf43281ad7d832d73d8731e` (expected `933cf8eb8d30ec4cacf43281ad7d832d73d8731e`)
**Feature Branch:** `feature/n45a-voyage-shipwreck`
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf`

---

## 1. Architecture Decisions
- **Zero changes to `SequenceRunner.gd`, `NarrativeData.gd`, `SaveManager.gd`, or `PlayerProfile.gd`:** `pl_07_unfinished_journey` and `pl_08_shipwreck` use only existing allowlisted ops (`lock_control`, `play_cue`, `wait`, `finish`).
- **Sole-writer ownership & transition safety:** `PrologueShell` owns a dedicated `_voyage_runner` configured with an isolated `NarrativeState.new()` and empty `allowed_scenes = []`, so `PrologueShell` remains the sole writer of authoritative `NarrativeState` and accidental transitions to `ForgottenShore.tscn` are structurally blocked.
- **Camera-immune placeholder presentation:** Added a lightweight N4.5-specific `VoyageOverlayLayer` (`CanvasLayer`, `layer = 0`, `MOUSE_FILTER_IGNORE`) so `pl_07`/`pl_08` labelled `[Placeholder art]` visuals stay viewport-aligned even after `pl_06`'s displaced exploration camera without consuming gameplay input.
- **N4.4 preservation:** `_finish_n44_boundary()` is untouched; `start_voyage_sequence()` activates `pl_07` only from the N4.4 boundary, chains `pl_07 -> pl_08 -> _finish_n45a_boundary()`, and rejects early or duplicate calls.

## 2. Verification Results (Actual Observed Outputs)
- **Godot Project Import (`--headless --import`):** PASS (`rc=0`)
- **N4.5-A (`tests/test_n45a_voyage_shipwreck.gd`):** `PASS: All 57 N45A Voyage Shipwreck checks completed with 0 failures.`
- **N4.4 Full Flow (`tests/test_n44_full_flow.gd`):** `PASS: All 120 N44 Full Flow checks completed with 0 failures.`
- **N4.4-A (`tests/test_n44a_ruins_foundation.gd`):** `PASS: All 101 N44A Ruins Foundation checks completed with 0 failures.`
- **N4.4-B (`tests/test_n44b_chamber_presentation.gd`):** `PASS: All 77 N44B Chamber Presentation checks completed with 0 failures.`
- **N4.4-C (`tests/test_n44c_crown_interaction.gd`):** `PASS: All 53 N44C Crown Interaction checks completed with 0 failures.`
- **N4.4-D (`tests/test_n44d_vision_sequence.gd`):** `PASS: All 29 N44D Vision Sequence checks completed with 0 failures.`
- **N4.3-A (`tests/test_n43a_exploration_stage.gd`):** `PASS: All 111 N43A Exploration Stage checks completed with 0 failures.`
- **N4.3-B (`tests/test_n43b_mark_inspection.gd`):** `PASS: All 193 N43B Mark Inspection checks completed with 0 failures.`
- **N4.3-C (`tests/test_n43c_full_flow.gd`):** `PASS: All 188 N43C Full Flow checks completed with 0 failures.`
- **Aggregate Runner (`bash tests/run_all.sh`):** `ALL SUITES PASSED`
- **Repository Verifier (`python3 tests/verify_repo_integrity.py`):** `PASS: All 284 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`

## 3. Windowed Visual Verification
- **Status:** `VERIFIED (4 windowed PNGs captured under Xvfb gl_compatibility)`
- **Evidence / Limitation:** Windowed Xvfb gl_compatibility pass captured 4 PNGs in /tmp/crownfall_n45a_visual: 01_pl07_unfinished_journey.png, 02_pl08_shipwreck_storm.png, 03_pl08_shipwreck_fade.png, 04_n45a_terminal_boundary.png.

## 4. Remaining Work for N4.5-B & Open Decisions
- **N4.5-B scope:** `pl_09` Forgotten Shore landing, Chapter I title card, crown visual continuity without dialogue, `PlayerProfile.mark_prologue_completed()` on successful full completion only, and fresh `ForgottenShore.tscn` session handoff.
- **OPEN story details preserved:** Voyage destination, ship origin, storm cause / crown connection, and all unresolved N4.4 owner decisions remain OPEN.
