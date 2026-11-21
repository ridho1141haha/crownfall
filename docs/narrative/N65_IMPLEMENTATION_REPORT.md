# N6.5 Implementation Report — Eldergrove Threat Encounters & Pixel-Art Presentation

**Status:** IMPLEMENTED (`feature/n65-eldergrove-threat-encounters`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Visual Direction:** 2D side-scrolling pixel art (Kingdom: New Lands / Kingdom Two Crowns reference)

---

## 1. Gameplay & Presentation Changes

- Added `scripts/survival/EldergroveThreatPresenter.gd`, a decoupled side-view pixel-art presentation adapter wired into `scenes/world/EldergroveForest.tscn` (`WorldObjects/ThreatPresenter`) and synchronized from `scripts/world/EldergroveForestArrival.gd`.
- `scripts/survival/EldergroveNightSurvival.gd` remains the sole authoritative simulation — zero gameplay logic was duplicated or altered in the visual layer.
- During active night encounters, threats emerge at `threat_x` on the ground baseline (`y = 0.0`), face the player in side view, visibly stop outside First Camp's protected perimeter (`[-4.0, 164.0]`) when `ThreatClass.ORDINARY` is blocked, visibly cross inside only when `ThreatClass.BREACH_CAPABLE` breaches, and hide immediately upon encounter resolution or sunrise.

## 2. Existing Assets Reused & Placeholders

- **Reused Existing Assets:**
  - `res://assets/enemies/first_enemy/enemy_greedling_raider_sheet.png` (`128x32`, `hframes = 4`, `32x32` frames, nearest-neighbor filtering, `offset = Vector2(-16, -32)`) for `ThreatClass.ORDINARY` (`"raider"`).
  - `res://assets/buildings/camp/building_vagrant_tent.png` (`48x32`) for First Camp shelter.
- **Documented Temporary Placeholders:**
  - `ThreatClass.BREACH_CAPABLE` (`"brute"`) reuses the verified `32x32` pixel-art sheet at exact `2x` integer scale (`Vector2(2, 2)`) with a crimson-shadow tint (`Color(0.72, 0.42, 0.56, 1.0)`), swappable cleanly via `set_visual_profile("brute", {...})`.
  - First Camp protection perimeter markers use minimal `4x22` px integer-aligned ward stakes (`ColorRect`) at `x = -4.0` and `x = 164.0`.
- Full replacement contract documented in [`docs/assets/N65_ASSET_MANIFEST.md`](../assets/N65_ASSET_MANIFEST.md).

## 3. Tests & Results

- `tests/test_n65_eldergrove_threat_encounters.gd` (registered in `tests/run_all.sh`) verifies:
  - Threat visibility strictly bounded to active encounters; hidden on resolution/sunrise.
  - Authoritative position mirroring, ground baseline (`y = 0.0`), nearest-neighbor filtering, and side-view facing direction.
  - Ordinary threat visual stopping outside First Camp boundary; Breach visual crossing only when simulation confirms breach + HUD feedback.
  - Placeholder replacement independence from gameplay rules and fail-safe handling of missing visual resources.
  - Verified sprite sheet asset loading (`128x32`) and full N6.4 rest/sunrise + `SaveManager` schema v2 compatibility.

## 4. Known Limitations & Future Replacement

- Dedicated Gloom Brute pixel-art sprite sheet, combat counter-actions, health/damage systems, and animated camp ward art are deferred to future milestones; see `docs/assets/N65_ASSET_MANIFEST.md` for the drop-in asset contract.
