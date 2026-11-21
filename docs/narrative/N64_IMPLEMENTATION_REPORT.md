# N6.4 Implementation Report — Eldergrove Night Survival & First Camp Defense

**Status:** IMPLEMENTED (`feature/n64-eldergrove-night-survival`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Implemented Gameplay Behavior

- Added `scripts/survival/EldergroveNightSurvival.gd`, a modular Eldergrove-specific survival controller driven by the existing `TimeManager` without duplicating Forgotten Shore walls, lanes, or settlement assumptions.
- Night encounters activate deterministically at `45.0s` into `TimeManager.Phase.NIGHT` (preserving early-night rest windows and N6.3 regressions) and resolve cleanly at sunrise or explicit resolution.

## 2. First Camp Protection Rules & Threat Classes

- **First Camp Protective Boundary:** Active only when First Camp is constructed (`CAMP_CENTER_X = 80.0`, `CAMP_PROTECTION_RADIUS = 84.0`, covering `[-4.0, 164.0]`). Unbuilt camp provides zero protection.
- **Ordinary Threats (`ThreatClass.ORDINARY` / `"raider"`):** Scheduled on standard nights (`day % 3 != 0`). `can_penetrate_camp_protection()` is deterministically `false`; movement is clamped strictly outside the protected perimeter with no random or fallback bypass.
- **Breach-Capable Threats (`ThreatClass.BREACH_CAPABLE` / `"brute"`):** Scheduled deterministically every 3rd night (`day % 3 == 0`). `can_penetrate_camp_protection()` is explicitly `true`, allowing entry into the protected zone and emitting `camp_protection_breached`. Does not permanently destroy First Camp or silently deduct resources.

## 3. Rest Interaction Behavior

- When no encounter is active and rest is otherwise allowed, N6.3 rest-until-sunrise works unchanged (`TimeManager.advance_time()`).
- While a night encounter is active and unresolved, `can_rest_at_camp()` returns `false`, the prompt shows `"First Camp — Threat active (Rest blocked)"`, and `try_rest_at_camp()` rejects with `"Cannot rest while a night threat is active."`.

## 4. Persistence Behavior

- `SaveManager` schema v2 (`SCHEMA_VERSION == 2`) is unchanged.
- Resolved night days are persisted as boolean entries (`eldergrove_night_resolved_day_<N>: true`) inside existing `progression_flags["node_states"]` (validated strictly as `String -> bool` by `SaveManager.validate_payload()`).
- Continue restores resolved-day flags and First Camp protection without replaying already-resolved encounters; malformed or missing entries fail safely.

## 5. Tests & Results

- `tests/test_n64_eldergrove_night_survival.gd` (registered in `tests/run_all.sh`) verifies unbuilt protection, ordinary threat blocking, breach-capable penetration, rest rejection during active encounter, sunrise resolution and single resource renewal, save/load persistence, no Continue replay of resolved encounters, rest without active encounter, malformed save fail-safety, and Forgotten Shore Continue regression.
- Local static verifier (`python3 tests/verify_repo_integrity.py`) passed; full Godot 4.7.2 `bash tests/run_all.sh` runs in Google Colab and GitHub Actions CI.

## 6. Known Limitations & Deferred Work

- Threat visuals/combat counter-actions, health/damage systems, and multi-building defenses are intentionally deferred beyond N6.4.
