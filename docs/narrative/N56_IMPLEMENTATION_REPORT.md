# N5.6 Implementation Report — Island-Aware Continue & Save Restoration

**Status:** IMPLEMENTED (`feature/n56-island-aware-continue`)
**Source Baseline (`main`):** `287feeb930870f39081740e373b097d81076f58c` (PR #43 merge commit)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Files Changed

- `scripts/core/Main.gd`
- `scripts/world/EldergroveForestArrival.gd`
- `tests/test_n56_island_continue.gd`
- `tests/run_all.sh`
- `.github/workflows/godot-ci.yml`
- `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`
- `docs/narrative/N56_IMPLEMENTATION_REPORT.md`
- `docs/CHANGELOG.md`

## 2. Continue Routing Behavior (Before vs. After)

- **Before N5.6:** `Main._on_continue_button_pressed()` unconditionally routed to `res://scenes/world/ForgottenShore.tscn`, even when the saved progression contained `FACT_ELDERGROVE_REACHED`.
- **After N5.6:** `Main.resolve_continue_destination()` inspects the validated `SaveManager` v2 payload and routes to `res://scenes/world/EldergroveForest.tscn` **only** when `progression_flags["progression_facts"]` contains `ProgressionState.FACT_ELDERGROVE_REACHED`. Legacy Forgotten Shore saves, `era_id == "iron_age"` without the arrival fact, missing `progression_flags`, and malformed saves all fail safely to `ForgottenShore.tscn`.

## 3. Restoration Lifecycle

- **Separated from N5.5 departure handoff:** Continue does not fake or reuse a one-shot `EldergroveHandoffBridge` token. Instead, `Main.gd` sets `crownfall_load_on_start = true`, and `EldergroveForestArrival._ready()` branches into `_restore_from_continue_save()`, invalidating any stray departure intent.
- **Authoritative read-only restore:** Loads via `SaveManager.load_state()`, confirms `FACT_ELDERGROVE_REACHED`, applies facts via `ProgressionState.apply_save_state()` (without re-emitting `fact_recorded`) and era via `EraProgressionManager.apply_save_era()`, never rewrites the save file on disk, and restores player control on both success and failure.

## 4. Save Compatibility & Schema v2 Confirmation

- **Confirmed:** `scripts/save/SaveManager.gd` was not modified and `SaveManager.SCHEMA_VERSION` remains `2`. No schema fields, versions, or migrations were introduced.
- Existing Forgotten Shore saves, `PlayerProfile` Prologue gating, New Game, and Skip Prologue remain unchanged.

## 5. Tests Executed

- `tests/test_n56_island_continue.gd` covers destination resolution (legacy, Eldergrove, `iron_age` without fact, malformed, missing `progression_flags`), Eldergrove Continue restoration (without handoff token, facts + era restored, no duplicate recording, save untouched, failure safety), and menu regressions.
- Verified via `godot --headless --path . -s tests/test_n56_island_continue.gd`, `bash tests/run_all.sh`, `python3 tests/verify_repo_integrity.py`, and `git diff --check`.

## 6. Known Limitations

- `EldergroveForest.tscn` remains a minimal arrival scene; full Island 2 gameplay, return travel, and Island 2 save mechanics remain future Chapter II work.
