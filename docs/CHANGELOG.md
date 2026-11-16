# CROWNFALL: THE LAST LIGHT
# CHANGELOG

All notable project and documentation changes are recorded here in reverse chronological order.

This changelog records repository changes that actually occurred. Planned features and unimplemented work belong in the PRD, GDD, SYSTEMS, TDD, or roadmap sections—not as completed changelog entries.

---

---

## [2026-11-16] Progression Phase 2.1 — Strict Save Migration Validation Fix

**Type:** Save Migration Correctness (small review fix on top of Phase 2; no gameplay, balance, or schema changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `133` checks across `7` suites — all green)

### Summary
Code-review fix for a migration validation gap: `SaveManager._backfill_progression_fact()` read the field with `get("progression_facts", null)`, which cannot distinguish a genuinely absent field (legitimate legacy save; deterministic backfill intended) from an explicitly stored `null` (malformed payload). An explicit `"progression_facts": null` combined with `shipwreck_stage == 3` (or `era_id == "stone_age"`) was therefore silently repaired into a valid fact array and accepted, violating the strict malformed-save rejection policy. The backfill now uses an explicit `Dictionary.has()` presence check: a genuinely absent field is backfilled exactly as before (legacy Stone Age evidence and Stage-3 vessel readiness preserved; legacy `iron_age` without Eldergrove evidence still downgraded; migration stays deterministic and idempotent), while any explicitly present value that is not a valid fact array (`null`, string, number, dictionary, invalid array) is left untouched so `validate_payload` rejects the payload wholesale — no backfill, no partial application to live state. Valid arrays keep the existing strict checks (known IDs, duplicates, structure). Save schema stays version 2.

### Key Changes
- **`scripts/save/SaveManager.gd`:** `_backfill_progression_fact` distinguishes field absence from an explicitly present malformed value via `Dictionary.has()`; doc comment updated. No other migration, gameplay, or schema behavior changed.
- **`tests/test_progression_phase2_era_correction.gd`:** new suite "Strict Malformed Facts Rejection" (26 checks) covering absent-field migration success (Stage-3 vessel backfill intact), legacy `iron_age` without fact field still downgraded, valid Eldergrove evidence still retaining Iron Age, explicit `progression_facts: null` rejected (alone, combined with `shipwreck_stage == 3`, and on a `stone_age` save — with no backfill applied), explicit malformed string/dictionary rejected untouched, rejection mutating neither the caller's payload nor live progression state, failed malformed-file load leaving live state intact, and deterministic/idempotent rejection. Verified to fail against the pre-fix implementation and pass after the fix; suite count 6 -> 7, checks 107 -> 133.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 12 now documents the absent vs explicitly-null handling and the updated suite counts.

---

## [2026-11-16] Progression Phase 2 — Era Progression Correction & Conservative Legacy Save Migration

**Type:** Progression Correctness & Save Compatibility (deliberate era unlock semantics change; no gameplay balance changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, new Phase 2 suite `107` checks across `6` suites — all green)

### Summary
Implemented Phase 2 of `docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md`: Shipwreck Stage 3 no longer unlocks Iron Age. Completing the repair now records the durable voyage-readiness fact `forgotten_shore_vessel_ready` (idempotent, recorded only after the successful 6G 8W 4S transaction; repeated interactions keep the existing ISLAND_CLEARED / Set Sail path). Iron Age now unlocks only through the defined Eldergrove Forest milestone: the registered fact `eldergrove_reached` gates both the data-driven `iron_age_era` unlock definition (`data/unlocks.json`) and the new fail-closed `EraProgressionManager.notify_eldergrove_milestone(progression)` (replaces `notify_vessel_ready()`). Because no Forgotten Shore gameplay path records the Eldergrove fact, Iron Age is unreachable while playing on Forgotten Shore; the Eldergrove gameplay event itself ships with the future multi-island phase. Legacy saves with `era_id = "iron_age"` (previously reachable from Shipwreck Stage 3 alone) follow a documented conservative migration: saves carrying the Eldergrove fact keep Iron Age; all other legacy `iron_age` saves are downgraded to the era their real evidence proves (`stone_wall` building -> `stone_age`, otherwise `wood_age`), gain the vessel fact when `shipwreck_stage == 3`, and never receive a fabricated Eldergrove fact. Schema stays version 2.

### Key Changes
- **Facts (`scripts/progression/ProgressionState.gd`):** registry grew to exactly three facts — `forgotten_shore_first_stone_wall_tier_2` (unchanged), `forgotten_shore_vessel_ready` (new, recorded by the session after the Stage-3 repair succeeds), and `eldergrove_reached` (new, the defined Iron Age gate; registered for the unlock definition and future saves, with no current recording path).
- **Era gate (`scripts/world/EraProgressionManager.gd`):** `notify_vessel_ready()` removed; `notify_eldergrove_milestone(progression)` advances to Iron Age only when the passed progression state already contains `eldergrove_reached` — fail-closed on a missing fact or null state. Stone Age advancement and era save/restore behavior are unchanged.
- **Shipwreck session (`scripts/world/ForgottenShoreSession.gd`):** Stage 3 now emits "The vessel is ready to set sail from Forgotten Shore." instead of the Iron Age message; the vessel fact is recorded after the successful transaction. Stage costs, floating text, payment feedback, `ISLAND_CLEARED` repeat behavior, and the victory banner are untouched.
- **Unlock definitions (`data/unlocks.json`, `data/eras.json`):** added `forgotten_shore_voyage_ready` (all_of the vessel fact) and `iron_age_era` (all_of `eldergrove_reached`) beside the unchanged `stone_age_era`; the iron_age era description no longer claims the ship Stage 3 trigger.
- **Legacy migration (`scripts/save/SaveManager.gd`):** `migrate_payload` now (1) keeps Iron Age only when the save's valid fact array contains `eldergrove_reached`, (2) otherwise revokes Iron Age and recomputes the era from real evidence (`stone_wall` -> `stone_age`, else `wood_age`, matching the existing era-inference rule), (3) backfills `forgotten_shore_vessel_ready` whenever `shipwreck_stage == 3` (genuine evidence, any era), (4) keeps the Phase 1 stone-fact backfill for `stone_age` (also applying to freshly downgraded saves), and (5) sorts valid backfilled arrays to match the `to_save_array()` contract while leaving invalid arrays untouched for `validate_payload` to reject. Shared `_backfill_progression_fact()` helper keeps the backfills deterministic and idempotent. Malformed facts keep the Phase 1 behavior: rejected wholesale, never repaired mid-load. An invalid array containing `eldergrove_reached` never counts as evidence.
- **Tests & CI:** new `tests/test_progression_phase2_era_correction.gd` (107 checks, 6 suites) covering fresh-start era, the real wall/shipwreck command paths with exact balance regression, failed-transaction milestones, notification idempotency, the fail-closed Iron Age gate, the intended Eldergrove unlock path end-to-end (including an `iron_age` payload round-trip), every legacy migration branch with determinism/idempotency proof, malformed-data rejection, and unlock-definition data-contract guards; registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml` (new "Run Phase 2 Era Correction Tests" step). `test_progression_foundation.gd` (139 checks) and `test_unit_m2_m7.gd` (144 checks) updated where they asserted the removed vessel -> Iron Age trigger or used `eldergrove_reached` as an unknown-ID example.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` (status, baseline, section 8 correction marked implemented, new section 12 with the shipped boundary and the exact legacy migration policy), `PROGRESSION_IMPLEMENTATION_ROADMAP.md` (Phase 2 marked implemented, exit criteria met), `ROADMAP.md` (era correction implemented; Eldergrove/multi-island still future work), `GDD.md` era-progression bullet synced.

## [2026-11-16] Progression Foundation Phase 1 — Facts, Unlock Definitions & Save Compatibility

**Type:** Architecture & Infrastructure (no gameplay balance changes)  
**Engine Verified:** `Godot 4.7.2.stable` (local headless run: static verifier `182` checks, world clock `5` checks, P0 unit `142` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, new progression suite `137` checks across `6` suites — all green)

### Summary
Implemented the Phase 1 progression foundation from `docs/PROGRESSION_FOUNDATION_DESIGN.md` / `docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md` without changing any gameplay balance, era trigger, or player-facing behavior: a durable progression-fact service with stable snake_case IDs and a known-fact registry (`scripts/progression/ProgressionState.gd`), a strict all-or-nothing data-driven unlock definition loader/validator over the new `data/unlocks.json` (`scripts/progression/ProgressionUnlockCatalog.gd`), a deterministic fail-closed `all_of`/`any_of` evaluator that never mutates progression state (`scripts/progression/ProgressionUnlockEvaluator.gd`), and the Stone Age milestone now recorded as the durable fact `forgotten_shore_first_stone_wall_tier_2` after a successful Stone Wall Tier 2 upgrade transaction (idempotent, era ownership unchanged in `EraProgressionManager`).

### Key Changes
- **Progression facts (`scripts/progression/ProgressionState.gd`):** idempotent `record_fact`, registry-validated IDs (malformed or unknown IDs rejected), `fact_recorded` signal emitted only on the absent -> present transition, defensive `get_fact_ids`, sorted deterministic serialization, transactional `apply_save_state` (null clears, valid array replaces atomically, invalid array rejected with zero mutation).
- **Unlock definitions (`scripts/progression/ProgressionUnlockCatalog.gd`, `data/unlocks.json`):** `stone_age_era` definition requires the stone-wall fact via `all_of`; loader rejects missing/malformed files, duplicate definition IDs, unknown requirement fact IDs, and empty requirement groups with reported reasons; any validation error leaves the catalog empty so malformed data can never grant unlocks. No script expressions or eval.
- **Unlock evaluation (`scripts/progression/ProgressionUnlockEvaluator.gd`):** `all_of` / `any_of` / combined semantics; empty, missing, or unknown requirement groups never unlock even for definitions that bypass the catalog; evaluation is a pure read.
- **Stone Age integration (`ForgottenShoreSession.gd`):** `progression` service member; the milestone fact is recorded only after `request_upgrade_wall` succeeds (east or west wall), repeating the milestone never duplicates progression, era messages/HUD behavior unchanged.
- **Save compatibility (`SaveManager.gd`):** new optional `progression_flags.progression_facts` array (schema stays v2, matching how `tree_states`/`hearth_boost_remaining` were introduced); strict validation rejects unknown/malformed fact IDs from saves; `migrate_payload` deterministically and idempotently backfills the stone-wall fact when `era_id == "stone_age"` (era is only reachable via that milestone) and never infers it for `iron_age` saves (the vessel-ready path can skip stone walls); malformed fact arrays are rejected, not repaired.
- **Tests & CI:** new `tests/test_progression_foundation.gd` (137 checks, 6 suites) covering the 16 required Phase 1 scenarios; registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml` (new "Run Progression Foundation Tests (Phase 1)" step).
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` status updated to implemented-for-Phase-1 with a new section 11 recording the shipped boundary (code-level fact registry instead of a second data file, no gameplay wiring of the catalog until an availability consumer exists, locked/available only); `PROGRESSION_IMPLEMENTATION_ROADMAP.md` Phase 1 marked implemented, Phases 2+ still planning only.

## [2026-11-15] Baseline v1.4.3 — Data-Driven Building Config, Transactional Load, Era Progression & Payment Feedback

**Type:** Configuration Correctness, Save Robustness, UX Safety & New Progression Feature  
**Engine Verified:** `Godot 4.7.2.stable` (local headless run: static verifier `176` checks, world clock `5` checks, P0 unit `142` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks — all green; CI test-regression on run `#39` fixed)

### Summary
Made `data/buildings.json` the actual source of truth for every plot (including `wall_east_01`, whose JSON entry used to be skipped because the plot was pre-registered in `_init()`), so `upgrade.cost`, `upgrade.max_durability`, `cost_label`, and `title` are now read and drive cost/HP/thorn labels and the upgrade result message; hardened save/load (full transactional rollback on partial-load failure plus `current_day_number` backfill from `day_count` so a v1 save taken mid-Night 2 no longer replays Night 1 waves); removed the duplicate unvalidated `lighting.json` loader in `NightEncounterManager` in favor of the validated `HearthSystem` loader; added an explicit unsaved-progress confirmation before "Return to Main Menu" (manual save is locked at night and autosave only fires at sunrise); shipped flying resource/gold payment feedback; and introduced the staged Era progression (`Wood Age` -> `Stone Age` -> `Iron Age`) that never appears all at once on the first island.

### Key Changes
- **Data-driven plots (`BuildingManager.gd`, `data/buildings.json`):** `apply_data_configs()` now applies JSON config to already-registered plots (`wall_east_01` included) without resetting runtime state, registers missing JSON plots when `register_forgotten_shore_expansion_plots()` runs, safe-casts cost dictionaries (a malformed `build_cost` can no longer break the loader), stores `title`/`cost_label`/`upgrade_*` per plot, and `request_upgrade_wall()` spends `upgrade_cost` and sets `upgrade_max_durability`/`upgrade_target_type` from data with the old constants kept only as fallback. UI helpers `get_plot_title/get_plot_cost_label/get_plot_upgrade_cost(_label)` replace hardcoded strings in `_get_plot_nodes`, the wall labels, and the `.tscn` statics (synced at `_ready`).
- **Save robustness (`SaveManager.gd`, `ForgottenShoreSession.gd`):** `load_game_state()` snapshots the live payload first and fully rolls back on any partial apply failure (no more half-applied state behind a "starting a fresh reign" message); `migrate_payload()` backfills `night_encounter.current_day_number` from `day_count` for pre-v2 saves and validates `current_day_number <= day_count`.
- **Single lighting loader (`HearthSystem.gd`, `NightEncounterManager.gd`):** HearthSystem owns the static, validation-gated tier cache (`get_validated_tiers()`); NightEncounterManager's duplicate `_load_hearth_tiers()` static cache and hardcode fallback were removed and now delegate to it.
- **UX safety (`PauseMenu.gd`, `ForgottenShoreSession.gd`):** "Return to Main Menu" now compares a progress signature (payload minus volatile `world_time`) against the last save/load/autosave and asks for explicit confirmation when progress would be lost.
- **Payment feedback (`ForgottenShoreSession.gd`):** `_spawn_payment_fly()` sends colored per-resource particles flying from the paying actor to the target (build, repair, Stone Wall upgrade, Hearth upgrade/stoke, recruit, Shrine Offering, Kindle Flare, Shipwreck stages).
- **Era progression (`data/eras.json`, `EraProgressionManager.gd`, `ClockHUD.gd`):** `Wood Age` from the start, `Stone Age` on the first `Stone Wall Tier 2`, `Iron Age` at `Shipwreck Stage 3`; persisted as `progression_flags.era_id` with strict validation and old-save inference (`stone_wall` present -> `Stone Age`); HUD clock line shows the current era.
- **UI strings from data:** the hardcoded `"Upgraded to Stone Wall Tier 2 (260 HP, 20 thorn dmg)!"` and `"Dawn of Day 3+! ..."` messages are now data-driven/dynamic (`Dawn of Day %d`).
- **Repo hygiene & docs:** orphan `tests/test_vertical_slice.gd.uid` removed (`.gd` was already gone); GDD wall position synced to `x=380` (three places), resource node count corrected to five (two single-use caches + three renewable) with `stone_deposit_west` (`x=-600`) added; `readme.md` documents `Q`, `Space`, and `Esc` controls; `docs/ROADMAP.md` added as the home for planned features (archer perch permanence, leader-role Monarch, scattered vagrant camps, rare mountable steed, wandering merchant, building tier matrix `Lvl 1-3` wood / `Lvl 4-5` stone, Iron Age heavy equipment, Greedling variants with secret-item carriers, extended settings, and the post-Night 3 difficulty-plateau observation).
- **CI:** run `#39` (commit `9571e23`) failed because the new actionable-plot test at `x=125` was answered by the nearer `stone_outcrop_east` resource node (`65 px` vs Watchtower `85 px`) — the resolver's cross-category nearest-wins behavior is intended. The test now collects the stone node first and additionally pins `get_nearest_actionable_plot_id()` directly.
 — Night Balance, Archer Flank Defense, Auto-Chop & Feedback Pass

**Type:** Gameplay Logic Audit (Combat, Economy & UI/UX), Balance Rebuild & Documentation Sync  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Rebuilt the Night 1 defense math (Wooden Wall Lv.1 thorn `15 -> 5`, so passive-only defense now breaches and the free first `Archer` becomes the intended answer), gave the `Archer` full combat behavior (1s volley cadence, Watchtower perch `x2` damage, west-flank pursuit of Day 2+ West Scouts), made idle `Builders` auto-chop Wood, added the renewable west `Stone Quarry` (`x=-600, +3S`), locked `ISLAND_CLEARED` behind `Shipwreck Stage 3` (removed the Day-2 auto-win), and shipped a feedback pass (population/vagrant HUD, victory banner, floating text at actor positions, `building_attacked` signals for wall hits and tramples, adaptive sunset/night warnings).

### Key Changes
- **Combat (`NightEncounterManager.gd`, `BuildingManager.gd`, `NPCBuilderAgent.gd`):** Wooden Wall Lv.1 thorn `5` (Lv.2/Stone stay `20`), breach trample of interior buildings, `get_nearest_active_enemy`/`damage_nearest_enemy` west-lane API, `is_fully_operational` gate for Watchtower support and Archer perch, Archer pursuit at `190px` trailing gap (clamped west of `-600`), greedling tool confiscation at night.
- **Economy (`ResourceNodeManager.gd`, `NPCPopulationManager.gd`, `data/resource_nodes.json`):** `Stone Quarry` west node (`+3S`, renewable), Builder auto-chop (wood-only, daylight-only) with `auto_chop_collected`, `2` starting Vagrants, first Archer assignment free, `resource`/`renewable` node filters.
- **Win condition & UI (`ForgottenShoreSession.gd`, `ClockHUD.gd`, `ForgottenShore.tscn`):** `ISLAND_CLEARED` only on `Shipwreck Stage 3` with Victory Banner overlay, `PopulationLabel` (`NPCs / roles / Idle / Vagrants`), West Scout HP alerts, `building_attacked` floating feedback, post-victory calm nights, adaptive Night 2+ warnings.
- **Tests & Docs:** M6 scenarios A/D rebuilt around the new balance (passive breach, tower-held `15 HP`), M8 + vertical slice upgraded to 2-NPC Archer defense (`150 HP` wall) with simulated raid damage + repair flow, P0 compat fixes (`get_balance`, `apply_damage`), and GDD/PRD/SYSTEMS/DECISIONS/ASSET_GUIDELINES/REVISED_BASELINE thorn narratives synced to the shipped balance.

---

## [2026-11-14] Baseline v1.3.6 — Modular Architecture, Gold Anti-Softlock, West Defense & 2D Shaders

**Type:** Architecture Refactor (Task 1) & Gameplay/Visual Expansion (Task 2)  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Extracted `ResourceNodeManager`, `HearthSystem`, and `InteractionResolver` from `ForgottenShoreSession.gd`, added centralized `execute_world_command()`, separated `Watchtower` (`x=210`) and `WoodenWall` (`x=380`), added `+1G` enemy kill rewards and daily `Shrine Offering`, introduced `[Space]` *Kindle Flare* and `West Wall` (`x=-400`) for Day 2+ West Scouts, and added `gl_compatibility` 2D shaders (`day_night_atmosphere.gdshader`, `hit_flash.gdshader`).

### Key Changes
- **Task 1 Modularization:** `ResourceNodeManager.gd`, `HearthSystem.gd`, `InteractionResolver.gd`, `[Q]` `upgrade_tier`, and Save v2 fields (`hearth_level`, `reign_state` String, `node_states` Dictionary).
- **Task 2 Anti-Softlock & West Lane:** `+1G` enemy defeat reward, daily `Shrine Offering` (`4W + 2S -> +2G`), `NightEncounterManager` loading `data/enemies.json`, `[Space]` *Kindle Flare*, `wall_west_01` (`x=-400`), and Day 2+ West Scout waves.
- **Shaders & Feel:** `shaders/day_night_atmosphere.gdshader`, `shaders/hit_flash.gdshader`, randomized SFX pitch (`0.92..1.08`), and micro camera shake on wall impact.

---

## [2026-11-14] Baseline v1.3.5 — Multi-NPC, Core Light Mechanic, Shipwreck & Procedural SFX

**Type:** Feature Expansion (Priority 3–7), Polish & Regression Hardening  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Completed single-player expansion Priorities 3 through 7: multi-NPC population (`Villager`, `Builder`, `Farmer`, `Archer`) with `ToolStands` and task claiming locks, "The Last Light" 3-tier Town Center Hearth mechanic with radiant burn/weakening and `ClockHUD` Night Forecast, expanded `[-1600, 1600]` Forgotten Shore with 3-stage `Shipwreck` and `Greed Portal`, procedural `.wav` SFX, floating popups, hit flashes, and full Save v2 migration/regression tests.

### Key Changes
- **Priority 3 (`NPCPopulationManager.gd`, `NPCBuilderAgent.gd`, `BuildingManager.gd`):** Added multi-NPC roster (up to 6 NPCs), 3 `ToolStands` (`hammer_stand`, `scythe_stand`, `bow_stand`), `claimed_by_npc_id` task lock, and animated follower sprites.
- **Priority 4 (`NightEncounterManager.gd`, `ClockHUD.gd`, `data/lighting.json`, `data/enemies.json`):** Added 3-tier Hearth light radius (`180 -> 320 -> 460 px`), `Light Burn` DoT + `Weakened Strike`, `Shadow Crawler` & `Gloom Brute` escalation, Monarch `Shadow Stagger`, and `ForecastLabel`.
- **Priority 5 (`ForgottenShore.tscn`, `Player.gd`):** Expanded bounds to `[-1600, 1600]`, added 3-stage `Shipwreck` (`x=-1350`) and `Greed Portal` (`x=1350`) relic scavenge.
- **Priority 6 & 7 (`scripts/tools/generate_sfx_assets.py`, `ForgottenShoreSession.gd`, `tests/test_unit_m2_m7.gd`):** Added 6 procedural `.wav` SFX, `SFXPlayer`, floating text popups, damage-state-safe hit flash, and v2 regression unit tests.

---

## [2026-11-14] Baseline v1.3.4 — Pixel-Art Pipeline, Priority 1–2 Expansion & Test Suite Fixes

**Type:** Gameplay Expansion (Priority 1 & 2), Visual Integration & Test Hardening  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Integrated 12 procedural pixel-art PNG spritesheets (`scripts/tools/generate_pixel_assets.py`), parallax mountain/forest layers, `SkyLayer` (`layer = -101`), proximity-gated interaction prompts, and Priority 1–2 gameplay systems (`Farm Plot`, `Watchtower`, `Stone Wall Tier 2`, renewable Wood/Stone nodes, and multi-day `ReignState`). Fixed literal `\t` indentation in `tests/test_time_manager.gd`, Stage 1 player save position in M8 integration tests, and strict tab validation in `tests/verify_repo_integrity.py`.

### Key Changes
- **Assets & Visuals (`generate_pixel_assets.py`, `ForgottenShore.tscn`):** Added 12 crisp Nearest PNGs (including `building_vagrant_tent.png`, `bg_mountains_far.png`, `bg_forest_mid.png`, `building_farm_plot_states.png`, and `building_watchtower_states.png`), moved `SkyBackground` into `SkyLayer` (`-101`) behind `ParallaxBackground`, and extended `DeepSoil` bottom bounds.
- **Priority 1 & 2 Gameplay (`BuildingManager.gd`, `ForgottenShoreSession.gd`, `NightEncounterManager.gd`):** Added renewable Wood/Stone nodes on Sunrise, `Farm Plot` (`x=-310`, `x=120`, `+2G/60s` during Daylight), `Watchtower` (`x=290`), `Stone Wall Lv.2` upgrade (`260 HP`, `20 thorn dmg`), nearest-plot `[E]/[B]/[F]` routing, and `BREACH_PENALTY` / `ISLAND_CLEARED` states.
- **Test & Verifier Fixes (`tests/*.gd`, `tests/verify_repo_integrity.py`):** Fixed literal `\t` parse error in `test_time_manager.gd`, added `session.player.global_position.x = 340.0` before Stage 1 save in `test_integration_m8_slice.gd` and `test_vertical_slice.gd`, and tightened ASCII-tab indentation checks.

---

## [2026-11-14] Baseline v1.3.3 — False-Green CI Elimination, M5/M8 Test Fixes & Full Doc Sync

**Type:** Test Runner Hardening, Bug Fix & Documentation Synchronization  
**Engine Verified in CI:** `Godot 4.7.2.stable.official.ed1daf0bf`

### Summary
Eliminated false-green headless test exits by replacing raw `assert()` calls in test suites with fail-fast `_check()` handlers (`quit(1)`) and adding log/exit-code traps in `.github/workflows/godot-ci.yml`. Fixed the M5 movement-vs-construction tick sequence, refactored `test_vertical_slice.gd` to use multi-frame `_initialize()` + `_process()` lifecycle, hardened M9 velocity-based anti-teleport, and synchronized `ASSET_GUIDELINES.md`, `TDD.md` Section 5.1 JSON schema, and `readme.md` to v1.3.

### Key Fixes
- **Test Runner Reliability (`tests/*.gd`, `.github/workflows/godot-ci.yml`):** Replaced `assert()` in test scripts with `_check()` that prints `TEST FAILURE:` and exits with code `1` immediately. Added `set -o pipefail` and `! grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)"` guards to every CI step.
- **M5 Unit Test Fix (`tests/test_unit_m2_m7.gd`):** Separated the 5-second movement phase (`x=-220` to `x=360`) from the 2-second construction phase (`progress = 0.5`), ensuring dusk safety override and blocked-path checks execute to completion.
- **Scene Lifecycle Fix (`tests/test_vertical_slice.gd`, `tests/test_integration_m8_slice.gd`):** Removed `_init()` scene instantiation so `@onready var time_manager` is always initialized by Godot before access, with a `MAX_WAIT_FRAMES = 120` timeout guard.
- **M9 Experimental Anti-Teleport (`scripts/networking/NetworkSessionManager.gd`):** Added `server_clock_sec` velocity bounds (`260 px/s`) and deferred `peer_positions` mutation until after `execute_command()` succeeds.
- **Documentation Sync (`docs/ASSET_GUIDELINES.md`, `docs/TDD.md`, `readme.md`):** Updated `ASSET_GUIDELINES.md` to v1.3, added `night_encounter` to `TDD.md` Section 5.1 JSON payload, and locked `readme.md` to Godot `4.7.2.stable`.

---

## [2026-11-14] M0–M8 — Single-Player Vertical Slice Implementation & Automated Test Suite

**Type:** Gameplay Implementation, Code Review & Automated Tests  
**Status:** Ready on `main` (Verified on Godot `4.7.2.stable`)

### Summary
Implemented and verified the complete single-player vertical slice on **Forgotten Shore** following `REVISED_PROJECT_BASELINE.md` v1.2, resolving Open Decisions `OD-01` through `OD-10` in `docs/DECISIONS_M2_M8.md`.

### Key Improvements & Modules Added
- **M0 & M1 (`project.godot`, `Player.gd`, `Player.tscn`, `Main.gd`, `Main.tscn`):** Locked Godot `4.7.2.stable`, added decoupled action signals (`interact`, `recruit_villager`, `build_wall`, `repair_wall`, `save_game`, `toggle_fast_clock`), walk bob feedback, and `Continue Saved Reign` button state check.
- **M2 (`scripts/world/TimeManager.gd`, `SkyAtmosphere.gd`):** Deterministic `Daylight -> Sunset -> Night -> Sunrise` clock with deferred initial signal emission and save/load state serialization.
- **M3 (`scripts/economy/EconomyLedger.gd`):** Atomic kingdom ledger for `gold`, `wood`, and `stone` enforcing all-or-nothing multi-resource spending and rejecting invalid/negative mutations.
- **M4 (`scripts/kingdom/BuildingManager.gd`):** Data-driven Wooden Wall state machine (`PLACEHOLDER -> UNDER_CONSTRUCTION -> COMPLETED -> DAMAGED -> DESTROYED`) with placement range validation and single-deduction guarantee.
- **M5 (`scripts/npc/NPCBuilderAgent.gd`):** Villager recruitment, Builder task priority queue (Dusk safety override > wall repair > wall construction > idle), and explicit path-failure signal without silent teleportation.
- **M6 (`scripts/survival/NightEncounterManager.gd`):** Phase-gated Greedling Raider encounter along the eastern approach route with wall durability combat and sunrise resolution.
- **M7 (`scripts/save/SaveManager.gd`):** Versioned JSON persistence (`user://save_slot_0.json`) with temporary file verification (`.tmp`), previous valid backup preservation (`.bak`), and automatic corrupt-save recovery.
- **M8 (`scripts/world/ForgottenShoreSession.gd`, `ClockHUD.gd`, `tests/test_vertical_slice.gd`):** Full vertical slice wiring on Forgotten Shore plus headless automated test suite covering M2–M7 invariants.

---

## [2026-11-13] Documentation Synchronization — Baseline v1.2

**Type:** Documentation-only update  
**Status:** Committed to the main branch  
**Implementation status:** No gameplay code, Godot project, production assets, or runtime tests were added by this documentation update.

### Summary

Synchronized the existing documentation set around the approved **single-player vertical slice on Forgotten Shore**.

The long-term online co-op vision remains planned for M9+, but is no longer presented as part of the first playable product or P0 requirements.

### Files Updated

| File | Version | Summary |
|---|---:|---|
| readme.md | 1.2 | Rewritten as the current project overview; distinguishes present repository status, P0 slice, deferred features, milestone gates, and documentation ownership |
| docs/REVISED_PROJECT_BASELINE.md | 1.2 | Updated cross-document authority, NPC scope, Stone's unresolved first-slice purpose, M0/M1 separation, and open-decision register |
| docs/PRD.md | 1.2 | Synchronized priorities and acceptance criteria; multiplayer is P1/M9, not P0; added design decisions and version references |
| docs/GDD.md | 1.2 | Clarified first-slice gameplay, long-term story scope, limited P0 content, and unresolved design choices |
| docs/SYSTEMS.md | 1.2 | Defined P0 system responsibilities, invariants, task behavior, persistence expectations, and test gates |
| docs/TDD.md | 1.2 | Corrected repository implementation status, reduced speculative architecture, clarified save validation and M0–M10 technical gates |
| docs/ASSET_GUIDELINES.md | 1.2 | Replaced the old oversized MVP asset list with P0 vertical-slice assets and deferred P1/P2 content |
| docs/CHANGELOG.md | — | Created this factual record of the documentation synchronization |

### Main Decisions Reinforced

- First playable target: one local player on Forgotten Shore.
- P0 economy: Gold, Wood, Stone in one kingdom ledger.
- P0 settlement: Town Center anchor and Wooden Wall construction target.
- P0 NPC scope: Villager recruitment and Builder behavior; Builder's internal representation remains an open decision.
- P0 survival: one basic enemy archetype and one predictable route.
- P0 persistence: versioned local save, validation, temporary write, backup, and recovery.
- Multiplayer: deferred to M9+, after vertical-slice validation.
- M0: create and launch the Godot project foundation.
- M1: add player movement, floor collision, bounds, and local camera.
- Placeholder art is acceptable during early mechanics validation.
- Repository status is documented honestly: no runnable Godot project or gameplay implementation is present yet.

### Open Decisions Kept Explicit

Resource sources and collection interactions, starting balances, recruitment cost/interaction, Stone's actual first-slice purpose, wall placement/cost/duration/repair/refund rules, Builder's representation, first-enemy behavior/tuning, failure consequences, exploration reward, and final persistent NPC fields remain open.

These decisions must be approved in the owning documents before their dependent milestones begin. This update does not invent answers for them.

### Verification

- Fetched updated files back from GitHub after writing.
- Checked document version headers and cross-document references.
- Checked that multiplayer requirements are P1/M9+, not P0.
- Checked that the old multi-enemy / multi-role / multi-building asset list is no longer P0.
- Checked that M0 and M1 have separate deliverables and acceptance gates.
- Checked that README and TDD distinguish placeholder folders from an actual runnable Godot project.

**Not performed:** Godot import, parser check, game launch, gameplay test, unit test, or asset integration. No implementation exists to run those checks against.

### Documentation Commits

| File | Commit |
|---|---|
| readme.md — initial synchronization | 20bdf09 |
| readme.md — M0/M1 and status correction | ecaebb3 |
| readme.md — documentation version alignment | db82171 |
| docs/GDD.md | 66c5c38 |
| docs/PRD.md — v1.1 initial scope sync | d5637d4 |
| docs/PRD.md — v1.2 open decisions and cross-references | 4afd9fc |
| docs/PRD.md — synchronized document-version references | c82e192 |
| docs/SYSTEMS.md | 58b84fb |
| docs/TDD.md | afc6f69 |
| docs/ASSET_GUIDELINES.md | 3b4d07c |
| docs/REVISED_PROJECT_BASELINE.md | 1db6f60, 481b20e |

---

## Change Entry Rules

For future entries:
- Record only changes that have been committed.
- State whether a change is documentation-only, implementation, asset, test, or release work.
- Link the relevant commit(s).
- Distinguish tests that were run from checks that were only reviewed.
- Record breaking scope or architecture decisions and their rationale.
- Do not mark a planned milestone complete before its acceptance criteria pass.
