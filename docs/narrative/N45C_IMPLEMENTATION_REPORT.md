# N4.5-C Implementation Report — Prologue Handoff Lifecycle Correction, pl_09 Presentation & Documentation Closure

**Status:** IMPLEMENTED & VERIFIED
**Base `main` SHA:** `7579bceb4cc6c579e57e7bb34ba749eec906c2f4`
**Branch:** `fix/n45b-handoff-lifecycle-and-presentation`
**Engine:** `4.7.2.stable.official.ed1daf0bf`

## 1. Root-Cause Findings Addressed
1. **Premature profile completion write:** PR #35 called `PlayerProfile.mark_prologue_completed()` inside `PrologueShell._on_handoff_runner_completed()` before `ForgottenShore.tscn` loaded.
2. **Missing real destination integration test:** PR #35 only observed an injected `set_exit_transition()` callback.
3. **Placeholder `pl_09` presentation:** PR #35 rendered flat `ColorRect` tints and `[Placeholder art]` captions instead of the beach wake, crown continuity detail, and exact `CHAPTER I — FORGOTTEN SHORE` title card.
4. **Stale documentation & overstated report:** Multiple living docs still reported `pl_07`–`pl_09` unimplemented.

## 2. Corrected Two-Stage Handoff Architecture
- Added `scripts/narrative/PrologueHandoffBridge.gd` (static `Engine`-meta bridge, zero autoloads, zero schema changes).
- `PrologueShell._on_handoff_runner_completed()` records `pl_09` once in-memory, authorizes a one-shot token via `PrologueHandoffBridge.authorize_fresh_handoff(FORGOTTEN_SHORE_SCENE, profile_path)` (forcing `crownfall_load_on_start = false`), and calls `change_scene_to_file()`.
- `ForgottenShoreSession._ready()` validates required gameplay nodes and fresh-session mode, then calls `PrologueHandoffBridge.acknowledge_destination_ready(...)`.
- **Exact point where `prologue_completed_once` is persisted:** inside `PrologueHandoffBridge.acknowledge_destination_ready()` ONLY after `ForgottenShoreSession._ready()` confirms initialization (bounded 2-attempt write; persistence failure logs warning and keeps the player in the playable world).
- `Main.gd` invalidates any stale pending intent on New Game, Continue, Skip, and Replay.

## 3. pl_09 Presentation & Asset Notes
- `ShoreLandingLayer` (`CanvasLayer`, `layer = 1`, `MOUSE_FILTER_IGNORE`) composes real assets from `ForgottenShore.tscn`: `bg_mountains_far.png`, `bg_forest_mid.png`, `terrain_shore_tile.png`, `building_shipwreck_stages.png`, and `player_monarch_sheet.png`.
- **Asset limitation (honest disclosure):** No dedicated Crown sprite exists in `assets/`; `ShoreCrownProp` is a minimal temporary non-canon golden crown marker placed beside Monarch for continuity only (no dialogue or lore).
- Title card renders exact string `CHAPTER I — FORGOTTEN SHORE` (`36px`, centered, unclipped) before transitioning to the fresh gameplay session.

## 4. Verification Results
- **Godot Import:** PASS (`rc=0`)
- **N4.5-B Unit & Lifecycle Suite (`tests/test_n45b_forgotten_shore_handoff.gd`):** `PASS: All 34 N45B Forgotten Shore Handoff checks completed with 0 failures.`
- **N4.5-C Real Scene Integration (`tests/test_n45c_real_handoff_integration.gd`):** `PASS: All 18 N45C Real Handoff Integration checks completed with 0 failures.`
- **N4.5-A / N4.4 Full Flow / N4.0 Entry Gate:** PASS (`rc=0`)
- **Aggregate Runner (`bash tests/run_all.sh`):** `SUMMARY: passed=32 failed=0 skipped=0` — `ALL SUITES PASSED`
- **Static Verifier (`python3 tests/verify_repo_integrity.py`):** `PASS: All 291 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`
- **Visual Verification:** Xvfb gl_compatibility visual pass executed (rc=0, 5 PNGs in /tmp/crownfall_n45c_visual: 01_pl09_monarch_wakes_shore.png, 02_pl09_crown_continuity.png, 03_pl09_chapter_title_card.png, 04_forgotten_shore_fresh_session.png, 05_forgotten_shore_hud_and_control.png).

## 5. Persistence Safety & Remaining Work
- `SaveManager` schema v2 and `PlayerProfile` schema v1 are unchanged; real `user://player_profile.json` and `user://save_slot_0.json` verified byte-exact untouched.
- Remaining work: dedicated art/audio production pass for Crown prop and cinematics; Chapter I narrative beats (N5) remain separate and unimplemented; all OPEN lore remains unresolved.
