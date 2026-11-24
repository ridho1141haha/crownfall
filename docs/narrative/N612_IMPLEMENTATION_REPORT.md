# N6.12 Implementation Report — Deterministic Multi-Threat Night Encounters

**Status:** IMPLEMENTED (`feature/n612-multi-threat-encounters`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `158ca7ea5181607bdffc824013fa70442a71199b` (N6.11 merge)

---

## 1. Encounter Schedule & Multi-Threat State Ownership

- **Deterministic Schedule (`EldergroveNightSurvival.get_scheduled_threat_count()`):**
  - Day 1–2: `1` Ordinary Threat (`THREAT_SPAWN_X = 680.0`).
  - Day 3–4: `2` simultaneous Ordinary Threats (`680.0` and `SECONDARY_THREAT_SPAWN_X = 740.0`).
  - Every 5th day (`day % 5 == 0`): `1` Gloom Brute (`ThreatClass.BREACH_CAPABLE`, `680.0`).
  - Other non-breach days: `1` Ordinary Threat (`680.0`).
- **State Ownership:** `EldergroveNightSurvival.threats` (`Array[Dictionary]`) owns each threat's stable ID (`day_<N>_<archetype>_<idx>`), class, archetype, world `x`, `hp`/`max_hp`, `stagger_remaining`, `hit_flash_remaining`, `is_defeated`, `blocked`, `breached`, and `player_threatened`. Primary compatibility fields mirror the first active threat cleanly.

## 2. Melee Target Selection, Ward Pulse & Camp/Player Compatibility

- **Melee Target Selection (`[J]`):** `_select_attack_target()` evaluates all non-defeated threats within `64.0px` and in the player's facing direction (skipping staggered Ordinary Threats) and strikes the single nearest eligible target. Defeating one threat updates HUD with remaining threat count and only resolves the encounter once all threats are defeated.
- **Ward Pulse (`[Space]`):** Spends `1 Wood` once, sets `8.0s` cooldown, and applies pushback + stagger independently to all non-defeated threats while leaving defeated threats untouched.
- **First Camp & N6.10 Vulnerability:** Ordinary Threats remain strictly blocked outside intact First Camp protection; Gloom Brute breaches once per breach event; `player_invuln_remaining` (`1.2s`) is enforced immediately on contact so multiple threats in the same tick cannot deal multiple hits.
- **Presentation (`EldergroveThreatPresenter.gd`):** Renders independent side-view pixel-art actors, HP bars, hit flashes, and staggered/blocked/breached states keyed by threat ID, cleaning up stale slots on resolution.

## 3. Save Compatibility, Tests & Deferred Work

- **SaveManager Schema v2:** Unchanged (`SCHEMA_VERSION == 2`); transient multi-threat combat state is never serialized.
- **Tests:** `tests/test_n612_multi_threat_encounters.gd` (registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`) plus all 51 existing suites pass under Godot `4.7.2.stable.official.ed1daf0bf` (with schedule-aware expectation updates in `test_n64` and `test_n611`).
- **Deferred Work:** Mixed-archetype simultaneous waves (e.g., Raider + Brute together) and multi-direction flank spawns remain deferred beyond N6.12.
