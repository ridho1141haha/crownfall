# N6.7 Implementation Report — First Camp Breach Damage & Repair

**Status:** IMPLEMENTED (`feature/n67-first-camp-integrity-repair`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `beb4502d8a61cc6e42ee9e3cbc5531b19a6262e3` (N6.6 merge)

---

## 1. Selected Values & Economy Balance

- **Maximum & Initial Integrity:** `MAX_CAMP_INTEGRITY = 3` (set on First Camp construction).
- **Breach Damage:** `BREACH_DAMAGE = 1` per distinct Breach-Capable penetration event (applied once when `camp_breached` transitions `false -> true` inside `EldergroveNightSurvival.tick()`, never repeated per frame or on sunrise/resolution).
- **Repair Cost & Amount:** `CAMP_REPAIR_COST = {"wood": 2}`, `CAMP_REPAIR_AMOUNT = 1` (clamped to `3`). Chosen to sit cleanly between Ward Pulse (`1W`) and full camp construction (`4W + 2S`), sustainable via Eldergrove's renewable Fallen Timber (`+4W` per day).

## 2. Protection Behavior at Zero Integrity

- `is_camp_protection_active(camp_built)` requires `camp_built and camp_integrity > 0`.
- Full (`3/3`) and damaged (`1/3`, `2/3`) camps preserve normal protection against Ordinary Threats.
- At `0/3` integrity, First Camp is structurally compromised: normal protection is disabled (Ordinary Threats are no longer blocked), protective perimeter ward posts hide, and resting on an unresolved night is rejected until repaired with `[F]` (`2W`).

## 3. Repair Interaction & Eligibility

- Triggered via existing `repair_wall` input (`[F]`, `PlayerController.repair_wall_requested`) -> `EldergroveForestArrival.try_repair_first_camp(player_x)`.
- Requires active Eldergrove session, built First Camp, player within `CAMP_INTERACT_RANGE` (`68px`), `camp_integrity < 3`, and `2 Wood` in `EconomyLedger` (`try_spend()`). Protected against duplicate spending via `_repair_in_progress` and `120ms` debounce.

## 4. Persistence Strategy (SaveManager Schema v2 Unchanged)

- `SaveManager.SCHEMA_VERSION` remains `2` with zero top-level schema changes.
- Encoded strictly as `String -> bool` keys inside `progression_flags["node_states"]`: `eldergrove_camp_integrity_tracked` + `eldergrove_camp_integrity_1..3`.
- Missing legacy keys safely initialize a constructed camp to `3/3`; malformed, non-bool, out-of-range, or non-contiguous entries fail safely to `3/3`; saved `0/3` remains compromised across Continue until repaired.

## 5. Files Changed, Tests & Known Limitations

- **Files Changed:** `scripts/survival/EldergroveNightSurvival.gd`, `scripts/survival/EldergroveThreatPresenter.gd`, `scripts/world/EldergroveForestArrival.gd`, `tests/test_n67_first_camp_integrity_repair.gd`, `tests/run_all.sh`, `docs/narrative/N67_IMPLEMENTATION_REPORT.md`, `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, `docs/CHANGELOG.md`.
- **Tests:** `tests/test_n67_first_camp_integrity_repair.gd` (registered in `tests/run_all.sh`) verifies damage, zero-integrity protection loss, repair economy/debounce, partial/zero/legacy/malformed persistence, and schema v2.
- **Known Limitations:** Visual camp damage states use restrained tinting + HUD/label status rather than dedicated multi-frame damaged tent art (replaceable without changing gameplay logic).
