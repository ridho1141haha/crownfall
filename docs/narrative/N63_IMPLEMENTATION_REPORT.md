# N6.3 Implementation Report — First Camp Rest & Time Skip

**Status:** IMPLEMENTED (`feature/n63-first-camp-rest`)
**Base `main` SHA:** `02d6ed3cb88133d9806ee8fb6fc0c9040f6ddfbc`
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Source Audit Findings

- `scripts/world/TimeManager.gd` exposes `advance_time(delta)`, `get_current_phase_duration()`, `phase_elapsed`, and `night_duration`, emitting `night_started`, `sunrise_reached(completed_day)`, and `daylight_started(current_day)` through `_transition_to_next_phase()`.
- `scripts/world/EldergroveForestArrival.gd` already routes First Camp interactions through `InteractionResolver.resolve_nearest()` (`CAMP_SITE_ID = "eldergrove_first_camp"`, `x = 80.0`, `range = 68.0`) and handles deterministic once-per-sunrise renewal in `_on_sunrise_reached(completed_day)`.
- `tests/test_n61_first_camp_construction.gd` checks that repeated First Camp interaction in Daylight returns `ok: false` and `already_built: true`. Preserving `already_built: true` on Daylight rest rejection keeps N6.1 regression tests 100% green.

## 2. Architecture & Interaction Flow

- **Unified First Camp interaction:** When unbuilt, `primary_command` remains `&"build_camp"`. Once built, `primary_command` switches to `&"rest_camp"` with contextual prompts (`"First Camp (Built) — Rest available at Sunset/Night"` during Daylight; `"[E] Rest until Sunrise"` during Sunset/Night).
- **Authoritative clock advancement:** `try_rest_at_camp(actor_x)` computes remaining phase time (`remaining_sunset + night_duration + 0.001` during Sunset; `remaining_night + 0.001` during Night) and calls `time_manager.advance_time(advance_sec)`. Normal phase transitions and `sunrise_reached` fire once, triggering the existing N6.2 renewal handler without directly modifying `EconomyLedger` or day counters.
- **No extra rest persistence state needed:** Because resting immediately transitions `TimeManager` into `Phase.DAYLIGHT`, repeated resting is naturally prevented without adding any rest flags or changing `SaveManager` schema v2 (`SCHEMA_VERSION == 2`).

## 3. Files Changed

- `scripts/world/EldergroveForestArrival.gd`
- `tests/test_n63_first_camp_rest.gd`
- `tests/run_all.sh`
- `.github/workflows/godot-ci.yml`
- `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`
- `docs/narrative/N63_IMPLEMENTATION_REPORT.md`
- `docs/CHANGELOG.md`

## 4. Test Coverage & Results

- `tests/test_n63_first_camp_rest.gd` (registered in `tests/run_all.sh`) verifies:
  - Rest rejected before First Camp construction (even during Sunset) and during Daylight.
  - Existing First Camp construction preserved.
  - Sunset rest traverses Night to next Daylight; Night rest advances to next Daylight.
  - `sunrise_reached` and N6.2 renewal fire exactly once per rest; renewable Timber/Stone refresh while non-renewable Supply Crate remains collected.
  - Repeated interaction in Daylight produces no duplicate sunrise events or rewards, and resting never modifies `EconomyLedger` balances directly.
  - Save/Continue restores eligible Night save and allows immediate post-Continue resting; Forgotten Shore Continue remains unchanged; missing `TimeManager` fails safely.
- Local static verifier (`python3 tests/verify_repo_integrity.py`) passed; full Godot 4.7.2 `bash tests/run_all.sh` runs in Google Colab and GitHub Actions CI.

## 5. Known Limitations

- Rest transitions instantly to sunrise without a fade/sleep cutscene (kept minimal for N6.3).
- No health/stamina/food mechanics or night raids (explicitly out of scope).
