# N6.11 Implementation Report — Ordinary Threat Melee Combat

**Status:** IMPLEMENTED (`feature/n611-ordinary-threat-combat`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `f5757f3a5d1716a74780a9fe9a88b3c49bafe0c4` (N6.10 merge, CI run `45113388775`)

---

## 1. Source Audit Findings

- `scripts/survival/EldergroveNightSurvival.gd` previously restricted `can_player_attack()` to `ThreatClass.BREACH_CAPABLE` (`"brute"`, `3 HP`) and initialized `threat_hp = 0` for `ThreatClass.ORDINARY` (`"raider"`).
- `data/enemies.json` establishes `raider` (`45 HP`) as significantly lighter than `brute` (`160 HP`).
- Existing `[J]` attack input (`PlayerController.attack_requested`), reach (`64.0px`), damage (`1`), cooldown (`0.45s`), and N6.9 pixel-art presentation cues (`PlayerAttackCue`, `HitImpactCue`, HP bar, recoil) already supported target-agnostic melee presentation.

## 2. Implemented Behavior & Balance Values

- **Ordinary Threat Max HP:** `ORDINARY_MAX_HP = 2` (conservative default: 2 hits at `PLAYER_ATTACK_DAMAGE = 1`, lighter than Gloom Brute's `3 HP`, so both hit feedback and defeat are distinct).
- **Eligibility & Stagger Rule:** Ordinary Threats respect existing reach (`64.0px`), facing direction, cooldown (`0.45s`), active encounter, and defeat checks. Staggered Ordinary Threats (`is_threat_staggered()`) reject melee damage cleanly (`staggered: true`).
- **Gloom Brute & N6.10 Unchanged:** `BRUTE_MAX_HP = 3`, Brute combat rules (including N6.9 post-Ward-Pulse hit flow), First Camp protection/integrity/repair, and N6.10 player vitality/retreat/Gold loss remain completely unchanged.
- **Presentation:** Reuses N6.9 `PlayerAttackCue`, `HitImpactCue`, `4px` hit recoil, dynamically positioned pixel-aligned HP bar above 1x Raider / 2x Brute sprites, and target-specific HUD feedback (`"Hit Night Raider! (HP 1/2)"`, `"Night Raider defeated! Night N secured."`).
- **Superseded N6.8 Check Updated:** Updated the single N6.8 test assertion in `tests/test_n68_gloom_brute_combat.gd` that previously expected Ordinary Threat melee rejection, preserving all Gloom Brute checks and exact check count.

## 3. Save Compatibility, Files Changed & Deferred Work

- **SaveManager Schema v2:** Unchanged (`SCHEMA_VERSION == 2`).
- **Files Changed:** `scripts/survival/EldergroveNightSurvival.gd`, `scripts/survival/EldergroveThreatPresenter.gd`, `scripts/world/EldergroveForestArrival.gd`, `tests/test_n68_gloom_brute_combat.gd`, `tests/test_n611_ordinary_threat_combat.gd`, `tests/run_all.sh`, `.github/workflows/godot-ci.yml`, `docs/narrative/N611_IMPLEMENTATION_REPORT.md`, `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, `docs/CHANGELOG.md`.
- **Deferred Work:** Multi-threat simultaneous waves, melee audio SFX, and dedicated player attack sprite frames remain deferred beyond N6.11.
