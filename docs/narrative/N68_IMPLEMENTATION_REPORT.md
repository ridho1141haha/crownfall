# N6.8 Implementation Report — Gloom Brute Combat & Threat Defeat

**Status:** IMPLEMENTED (`feature/n68-gloom-brute-combat`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `e94f8b58ac83f0b4b4a0ecf3a9e587a49decc3fd` (N6.7 merge)

---

## 1. Combat Values & Input Mapping

- **Input Action:** `attack` mapped to **`[J]`** (`physical_keycode: 74`, `unicode: 106`) in `project.godot`, emitted via `PlayerController.attack_requested(player_x, facing_dir)` with `allow_echo = false` (one press = at most one attack; all existing `[A/D]`, `[E]`, `[F]`, `[Space]` mappings untouched).
- **Gloom Brute Max HP:** `3` (`BRUTE_MAX_HP = 3`).
- **Player Attack Damage:** `1` (`PLAYER_ATTACK_DAMAGE = 1`, HP clamped `>= 0`).
- **Attack Reach:** `64.0 px` (`PLAYER_ATTACK_REACH = 64.0`).
- **Attack Cooldown:** `0.45 s` (`PLAYER_ATTACK_COOLDOWN_SEC = 0.45`).
- **Valid Target:** Active `ThreatClass.BREACH_CAPABLE` (`"brute"`) only; Ordinary Threats are rejected.

## 2. Eligibility, Damage & Defeat Lifecycle

- `EldergroveNightSurvival.can_player_attack()` and `apply_player_attack()` enforce: active encounter, non-defeated `BREACH_CAPABLE` target, cooldown expired, `absf(threat_x - player_x) <= 64.0`, and player facing toward the Brute.
- Accepted hits deal `1` damage, start `0.45s` cooldown, trigger a `0.2s` hit-flash visual, and emit `threat_health_changed`.
- At `0 HP`, `threat_is_defeated` becomes `true`, `threat_defeated` emits once, and `resolve_encounter(true)` resolves the night encounter once (stopping movement, hiding presentation + HP bar, and preventing duplicate sunrise resolution).

## 3. Ward Pulse, First Camp & Persistence Integration

- **Ward Pulse (N6.6):** Unchanged (`[Space]`, `1 Wood`, `8s` cooldown, pushback + stagger, zero damage; cannot affect a defeated Brute).
- **First Camp Damage & Repair (N6.7):** Defeating the Brute before breach prevents camp damage; defeating it after breach preserves existing integrity loss; `[F]` repair (`2 Wood` -> `+1` integrity) remains unchanged.
- **Persistence (SaveManager Schema v2 Unchanged):** Combat HP/cooldowns are transient; resolved-day persistence (`eldergrove_night_resolved_day_<N>`) prevents Continue from replaying defeated encounters. `SCHEMA_VERSION` remains `2`.

## 4. Files Changed, Tests & Known Limitations

- **Files Changed:** `project.godot`, `scripts/player/Player.gd`, `scripts/survival/EldergroveNightSurvival.gd`, `scripts/survival/EldergroveThreatPresenter.gd`, `scripts/world/EldergroveForestArrival.gd`, `tests/test_n68_gloom_brute_combat.gd`, `tests/run_all.sh`, `docs/narrative/N68_IMPLEMENTATION_REPORT.md`, `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, `docs/CHANGELOG.md`.
- **Tests:** `tests/test_n68_gloom_brute_combat.gd` (registered in `tests/run_all.sh`) covers input mapping, echo suppression, eligibility, damage/defeat, pre- and post-breach camp integrity, Ward Pulse zero-damage compatibility, N6.7 repair, single resolution across sunrise, Continue no-replay, and schema v2.
- **Known Limitations:** Melee combat applies to Gloom Brute only (Ordinary Threats, player HP/counter-attacks, and dedicated player attack animation frames are deferred beyond N6.8).
