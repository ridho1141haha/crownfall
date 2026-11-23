# N6.10 Implementation Report — Player Threat Vulnerability & Retreat Recovery

**Status:** IMPLEMENTED (`feature/n610-player-threat-vulnerability`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `4889580021658b7acd75424d4d3fa86790368790` (N6.9 merge)

---

## 1. Identified Gameplay Gap & Rationale

- Through N6.9, `EldergroveNightSurvival.player_threatened` detected contact (`<= 28px`) but had no gameplay consequence — the player could stand directly on top of a Raider outside First Camp or face-tank Gloom Brute without risk, undercutting positioning, Ward Pulse (`[Space]`), and melee reach (`64px`).
- N6.10 closes this loop conservatively in the Kingdom: New Lands / Kingdom Two Crowns style (non-graphic knockback, vitality, and coin-drop retreat rather than permadeath or save loss).

## 2. Implemented Mechanics & Values

- **Player Vitality:** `PLAYER_MAX_VITALITY = 3` (transient per-night state owned authoritatively by `EldergroveNightSurvival.gd`; resets to `3/3` at Sunrise and on Continue; displayed on HUD `ResourcesLabel`).
- **Contact Strike:** Active, non-staggered, non-defeated threats within `THREAT_CONTACT_RANGE` (`28.0px`) of an unprotected player deal `1` vitality damage, apply `48.0px` integer-aligned side-view knockback away from the threat, trigger `1.2s` hit invulnerability (`PLAYER_HIT_INVULN_SEC`), and show a `0.2s` pixel-art hit flash on `Player/Sprite2D`.
- **Camp & Stagger Safety:** Players inside an intact First Camp are shielded from Ordinary Threats; staggered and defeated threats cannot strike the player.
- **Overwhelmed Retreat (`0/3`):** Emits `player_overwhelmed` once, retreats the player to First Camp (`CAMP_SITE_X`, or `PLAYER_SPAWN_X` if unbuilt), drops `1 Gold` via `EconomyLedger.try_spend({"gold": 1})` if affordable (safe no-op at `0 Gold`), and restores `3/3` vitality with `2.0s` recovery invulnerability.

## 3. Compatibility & Persistence

- **SaveManager Schema v2 Unchanged:** `SCHEMA_VERSION` remains `2`; dropped Gold persists naturally via `EconomyLedger`, while vitality/invulnerability remain transient.
- **N6.0–N6.9 & Forgotten Shore Untouched:** All existing gathering, construction, day cycle, rest, Ward Pulse, First Camp integrity/repair, and Gloom Brute melee combat values remain unchanged.

## 4. Files Changed, Tests & Deferred Work

- **Files Changed:** `scripts/survival/EldergroveNightSurvival.gd`, `scripts/world/EldergroveForestArrival.gd`, `tests/test_n610_player_threat_vulnerability.gd`, `tests/run_all.sh`, `.github/workflows/godot-ci.yml`, `docs/narrative/N610_IMPLEMENTATION_REPORT.md`, `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, `docs/CHANGELOG.md`.
- **Tests:** `tests/test_n610_player_threat_vulnerability.gd` (registered in `tests/run_all.sh`) verifies vitality, camp shielding, contact knockback/invulnerability/hit flash, Ward Pulse stagger immunity, Sunrise vitality recovery, overwhelmed retreat + `1 Gold` drop, `0 Gold` safety, defeated Brute immunity, and SaveManager v2 Continue persistence.
- **Deferred Work:** Audio SFX for player hits/retreat, dedicated retreat animation frames, and Ordinary Threat melee combat remain deferred to future milestones.
