# N6.4 Implementation Report — Eldergrove Night Survival & First Camp Defense

**Status:** IMPLEMENTED (`feature/n64-eldergrove-night-survival`, revised per PR #50 review)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Implemented Gameplay Behavior

- Added `scripts/survival/EldergroveNightSurvival.gd`, a modular Eldergrove-specific survival controller driven by the existing `TimeManager` without duplicating Forgotten Shore walls, lanes, or settlement assumptions.
- Night encounters activate deterministically at `45.0s` into `TimeManager.Phase.NIGHT` and track explicit per-day outcomes (`DayOutcome`: `UNPROCESSED`, `PASSED_NO_ENCOUNTER`, `RESOLVED`, `RESTORED_RESOLVED`).
- Sunrise without an active or previously resolved encounter records `PASSED_NO_ENCOUNTER` and never falsely marks a day resolved or writes a resolved flag to save data.

## 2. First Camp Protection Rules & Threat Classes

- **First Camp Protective Boundary:** Active only when First Camp is constructed (`CAMP_CENTER_X = 80.0`, `CAMP_PROTECTION_RADIUS = 84.0`, covering `[-4.0, 164.0]`). Unbuilt camp provides zero protection.
- **Ordinary Threats (`ThreatClass.ORDINARY` / `"raider"`):** Scheduled on standard nights (`day % 5 != 0`). `can_penetrate_camp_protection()` is deterministically `false`; movement is clamped strictly outside the protected perimeter (`right_edge + 1.0` / `left_edge - 1.0`) with zero random or fallback bypass.
- **Breach-Capable Threats (`ThreatClass.BREACH_CAPABLE` / `"brute"`):** Scheduled deterministically every 5th night (`day % 5 == 0`). `can_penetrate_camp_protection()` is explicitly `true`, allowing entry into the protected zone, emitting `camp_protection_breached`, and displaying immediate player-visible HUD feedback (`"Night Threat: Breach Threat (Gloom Brute) BREACHED First Camp!"` and camp prompt `"First Camp — BREACHED! (Rest blocked)"`). Does not permanently destroy First Camp or silently deduct resources.

## 3. Rest Interaction Policy (Zero Silent Bypass)

- **Active or Due Encounter:** Resting during an active encounter — or during Night at/past the `45.0s` activation offset when the night's encounter is unresolved — activates the due encounter and rejects rest with `"Cannot rest while a night threat is active."`.
- **Ordinary Night Sunset / Pre-Activation Night Rest:** Preserves N6.3 rest-until-sunrise only by legitimately processing the Ordinary encounter through `TimeManager` + `EldergroveNightSurvival` (advancing to activation, starting the encounter, confirming First Camp holds the Ordinary threat outside the perimeter, and resolving it at Sunrise).
- **Breach Night Restriction:** Safe unattended rest cannot be guaranteed on Breach nights (`day % 5 == 0`). Sunset rest and pre-activation Night rest are rejected with `"Cannot rest before a breach night — First Camp cannot hold a breach threat unattended."` until the encounter is resolved.

## 4. Persistence Behavior

- `SaveManager` schema v2 (`SCHEMA_VERSION == 2`) is unchanged.
- Only legitimately resolved days (`RESOLVED` / `RESTORED_RESOLVED`) persist as boolean entries (`eldergrove_night_resolved_day_<N>: true`) inside existing `progression_flags["node_states"]`.
- Continue restores resolved days with `DayOutcome.RESTORED_RESOLVED` without replaying them; malformed or missing entries fail safely.

## 5. Tests & Results

- `tests/test_n64_eldergrove_night_survival.gd` (registered in `tests/run_all.sh`) verifies Sunset/pre-activation rest policies on both Ordinary and Breach nights, active/due Night rest rejection, sunrise without encounter (`PASSED_NO_ENCOUNTER`), sunrise with active encounter (single resolution + single renewal), Ordinary strict boundary blocking, Breach penetration + HUD feedback, Continue persistence without replay, malformed save fail-safety, and Forgotten Shore Continue regression.
- Existing `tests/test_n63_first_camp_rest.gd` remains intact and compatible.

## 6. Known Limitations & Deferred Work

- Threat visuals/combat counter-actions, health/damage systems, and multi-building defenses are intentionally deferred beyond N6.4.
