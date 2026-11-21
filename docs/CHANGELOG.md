# CROWNFALL: THE LAST LIGHT
# CHANGELOG

All notable project and documentation changes are recorded here in reverse chronological order.

This changelog records repository changes that actually occurred. Planned features and unimplemented work belong in the PRD, GDD, SYSTEMS, TDD, or roadmap sections—not as completed changelog entries.

---

## [2026-11-21] N6.7: First Camp Breach Damage & Repair

**Type:** Gameplay milestone slice (N6.7)
**Branch:** `feature/n67-first-camp-integrity-repair`

- Added deterministic First Camp structural integrity (`MAX_CAMP_INTEGRITY = 3`, `BREACH_DAMAGE = 1` once per breach event) and zero-integrity protection loss in `scripts/survival/EldergroveNightSurvival.gd`.
- Added `[F]` First Camp repair interaction (`2 Wood` via `EconomyLedger` -> `+1` integrity, clamped to `3`, debounced) wired through existing `PlayerController.repair_wall_requested` in `scripts/world/EldergroveForestArrival.gd`, plus damaged/compromised visuals in `EldergroveForestArrival.gd` and `EldergroveThreatPresenter.gd`.
- Persisted camp integrity inside existing `SaveManager` schema v2 `progression_flags["node_states"]` using strict boolean keys with safe legacy fallback and malformed-data protection.
- Added `tests/test_n67_first_camp_integrity_repair.gd` (registered in `tests/run_all.sh`), `docs/narrative/N67_IMPLEMENTATION_REPORT.md`, and updated roadmap.

## [2026-11-21] N6.6: First Camp Active Defense & Player Response

**Type:** Gameplay milestone slice (N6.6)
**Branch:** `feature/n66-first-camp-active-defense`

- Added **First Camp Ward Pulse** (`[Space]` via existing `PlayerController.kindle_flare_requested`) in `scripts/world/EldergroveForestArrival.gd` and authoritative pushback/stagger/cooldown rules in `scripts/survival/EldergroveNightSurvival.gd` (`1 Wood` cost, `8.0s` cooldown, `84px` camp range).
- Added restrained pixel-art pulse & staggered threat feedback in `scripts/survival/EldergroveThreatPresenter.gd`, strictly observing authoritative simulation state.
- Added `tests/test_n66_first_camp_active_defense.gd` (registered in `tests/run_all.sh`), `docs/narrative/N66_IMPLEMENTATION_REPORT.md`, and updated roadmap while preserving `SaveManager` schema v2 and all N6.0–N6.5 / Forgotten Shore regressions.

## [2026-11-21] N6.5: Eldergrove Threat Encounters & Pixel-Art Presentation

**Type:** Gameplay & pixel-art presentation milestone slice (N6.5)
**Branch:** `feature/n65-eldergrove-threat-encounters`

- Added decoupled `scripts/survival/EldergroveThreatPresenter.gd` and wired `WorldObjects/ThreatPresenter` into `scenes/world/EldergroveForest.tscn` and `scripts/world/EldergroveForestArrival.gd` to reflect authoritative N6.4 `EldergroveNightSurvival` state in 2D side-scrolling pixel art (nearest-neighbor filtering, ground baseline `y = 0.0`).
- Reused verified `assets/enemies/first_enemy/enemy_greedling_raider_sheet.png` (`128x32`, 4 frames) for Ordinary threats and configured a swappable 2x integer-scaled placeholder profile for Breach-Capable threats, plus First Camp perimeter ward posts (`[-4.0, 164.0]`).
- Added `docs/assets/N65_ASSET_MANIFEST.md`, `docs/narrative/N65_IMPLEMENTATION_REPORT.md`, and `tests/test_n65_eldergrove_threat_encounters.gd` (registered in `tests/run_all.sh`), preserving `SaveManager` schema v2 and all N6.0–N6.4 and Forgotten Shore regressions.

## [2026-11-21] N6.4: Eldergrove Night Survival & First Camp Defense

**Type:** Gameplay milestone slice (N6.4, revised per PR #50 review)
**Branch:** `feature/n64-eldergrove-night-survival`

- Added modular `scripts/survival/EldergroveNightSurvival.gd` with explicit `DayOutcome` semantics (`UNPROCESSED`, `PASSED_NO_ENCOUNTER`, `RESOLVED`, `RESTORED_RESOLVED`) and two threat classes: `ThreatClass.ORDINARY` (strictly blocked outside constructed First Camp's perimeter) and `ThreatClass.BREACH_CAPABLE` (explicitly able to penetrate camp protection on scheduled breach nights, `day % 5 == 0`, with player-visible HUD breach feedback).
- Updated `scripts/world/EldergroveForestArrival.gd` so Sunset and pre-activation Night rest never silently bypass encounters: Ordinary nights legitimately process the encounter against First Camp protection before Sunrise, Breach nights reject unattended Sunset/pre-activation rest, and Night rest at/past activation or during an active encounter is strictly rejected.
- Ensured `on_sunrise_reached()` never marks an unstarted night as resolved, preserving `SaveManager` schema v2 (`progression_flags["node_states"]`) without schema changes.
- Extended `tests/test_n64_eldergrove_night_survival.gd` across all rest-bypass, resolution, breach-feedback, and Continue regression scenarios while preserving N6.3 rest compatibility and `tests/run_all.sh`.
## [2026-11-21] N6.3: First Camp Rest & Time Skip

**Type:** Gameplay milestone slice (N6.3)
**Baseline:** `main` @ `02d6ed3cb88133d9806ee8fb6fc0c9040f6ddfbc`; branch `feature/n63-first-camp-rest`

- Integrated First Camp rest (`can_rest_at_camp()`, `try_rest_at_camp()`) into `scripts/world/EldergroveForestArrival.gd` via existing `InteractionResolver` and authoritative `TimeManager.advance_time()`.
- Enabled resting during Sunset or Night to advance cleanly to next Daylight, triggering existing N6.2 sunrise resource renewal exactly once without modifying `EconomyLedger` balances or `SaveManager` schema v2.
- Added `tests/test_n63_first_camp_rest.gd`, registered it in `tests/run_all.sh`, updated `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, and created `docs/narrative/N63_IMPLEMENTATION_REPORT.md`.

## [2026-11-21] N6.2: Eldergrove Day Cycle & Resource Renewal

**Type:** Gameplay milestone slice (N6.2)
**Baseline:** `main` @ `696f981034af0f0f24f973fd6fd24098705ddaa1` (PR #47); branch `feature/n62-eldergrove-day-cycle`

- Wired existing authoritative `TimeManager` into `scenes/world/EldergroveForest.tscn` and `scripts/world/EldergroveForestArrival.gd` with HUD clock/phase display (`ClockLabel`), restrained daylight/sunset/night sky & `CanvasModulate` lighting, and `[T]` fast-clock toggle.
- Enabled deterministic once-per-sunrise renewal (`ResourceNodeManager.refresh_renewable_nodes()`) for Eldergrove Fallen Timber (+4W) and Mossy Outcrop (+3S) while keeping Weathered Supply Crate (+3G) strictly non-renewable.
- Persisted `day_count`, `world_time`, `world_phase`, node states, and First Camp state through existing `SaveManager` schema v2 without schema changes.
- Added `tests/test_n62_eldergrove_day_cycle.gd`, registered it in `tests/run_all.sh`, updated `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, and created `docs/narrative/N62_IMPLEMENTATION_REPORT.md`.

## [2026-11-21] N6.1: Eldergrove First Camp Construction Loop

**Type:** Gameplay milestone slice (N6.1)
**Baseline:** `main` @ `28bc0638a6fc3bcd932afc47e050cd32f10572ad` (PR #45); branch `feature/n61-first-camp-construction`

- Added the First Camp construction site (`x = 80.0`, cost `4W 2S`) in `scenes/world/EldergroveForest.tscn` and `scripts/world/EldergroveForestArrival.gd`, reusing `EconomyLedger`, `InteractionResolver` (via backwards-compatible `custom_targets`), and `assets/buildings/camp/building_vagrant_tent.png`.
- Persisted `eldergrove_first_camp_built` inside existing `SaveManager` schema v2 `progression_flags["node_states"]` without modifying `SaveManager.gd` or bumping schema version.
- Added `tests/test_n61_first_camp_construction.gd`, registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, updated `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, and created `docs/narrative/N61_IMPLEMENTATION_REPORT.md`.

## [2026-11-20] N6.0: Eldergrove First Playable Slice

**Type:** Gameplay milestone slice (N6.0)
**Baseline:** `main` @ `1ea114111a667aa6f7527c7a82ef0fc4a4def21b`; branch `feature/n60-eldergrove-first-playable-slice`

- Upgraded `scenes/world/EldergroveForest.tscn` and `scripts/world/EldergroveForestArrival.gd` into the first playable Eldergrove clearing reusing `PlayerController`, `InteractionResolver`, `ResourceNodeManager`, `EconomyLedger`, `PauseMenu`, and `SaveManager` schema v2.
- Added `ResourceNodeManager.configure_nodes()` and three interactable Eldergrove clearing nodes with live proximity prompts, resource HUD, manual save (`[K]` / Pause Menu), and clean Main Menu exit/re-entry via N5.6 Continue without replaying N5.5 arrival.
- Added `tests/test_n60_eldergrove_playable.gd`, registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, updated `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, and created `docs/narrative/N60_IMPLEMENTATION_REPORT.md`.

## [2026-11-20] N5.6: Island-Aware Continue & Save Restoration

**Type:** Production milestone slice (N5.6)
**Baseline:** `main` @ `287feeb930870f39081740e373b097d81076f58c`; branch `feature/n56-island-aware-continue`

- Added Continue destination resolution in `scripts/core/Main.gd` routing validated saves carrying `ProgressionState.FACT_ELDERGROVE_REACHED` to `res://scenes/world/EldergroveForest.tscn` while preserving Forgotten Shore Continue, New Game, and Prologue gating.
- Added dedicated Continue save-restoration path in `scripts/world/EldergroveForestArrival.gd` separate from the N5.5 one-shot departure handoff, restoring progression facts and era without modifying `SaveManager` schema v2 or rewriting disk saves.
- Added `tests/test_n56_island_continue.gd`, registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, and added `docs/narrative/N56_IMPLEMENTATION_REPORT.md`.

## [2026-11-20] N5.5: Voyage & Eldergrove Arrival

**Type:** Production milestone slice (`D-N5-05` Option A)
**Baseline:** `main` @ `0cc3462934a96bc070ed7f947495c8e7a9309806`; branch `feature/n55-voyage-eldergrove-arrival`

- Replaced Stage-3+ Shipwreck terminal `ISLAND_CLEARED` banner with Set Sail -> ~4.0s skippable voyage transition -> `EldergroveForest.tscn` arrival handoff.
- Added `scripts/narrative/EldergroveHandoffBridge.gd`, `scenes/world/EldergroveForest.tscn`, `scripts/world/EldergroveForestArrival.gd`, and `tests/test_n55_eldergrove_handoff.gd`.
- Recorded `ProgressionState.FACT_ELDERGROVE_REACHED` and notified `EraProgressionManager` only after destination initialization and one-shot handoff acknowledgement.
- Preserved `SaveManager` schema v2 untouched and invalidated pending Eldergrove intents on New Game and Continue in `scripts/core/Main.gd`.

## [2026-11-20] N5.3: Optional Scientist & research narrative beats

**Type:** Narrative integration slice (N5.3; optional Scientist discovery/recruitment & first research start; SaveManager schema v2 unchanged)
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf` (`SUMMARY: passed=36 failed=0 skipped=0`; `PASS: All 304 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`)
**Baseline:** `main` @ `1285e13`; branch `feature/n53-scientist-research-narrative`

### Summary
- Wired existing `SpecialistDomain` and `ResearchManager` into `ChapterOneNarrativeAdapter` via `ForgottenShoreSession._setup_chapter1_narrative_adapter()`.
- Added non-gating, skippable `ch1_05_scientist_discovery`, `ch1_05_scientist_recruitment`, and `ch1_06_research` beats with a bounded 4-slot contention policy (`first_night → scientist_discovery → scientist_recruitment → first_research`) and restore-silent Continue checks.
- Added `tests/test_n53_scientist_research_narrative.gd`, registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, updated `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`, and created `docs/narrative/N53_IMPLEMENTATION_REPORT.md`.

---

## [2026-11-20] N5-A: Chapter I design lock, source-audited roadmap & documentation repair

**Type:** Documentation & implementation-readiness package (docs-only; zero `.gd`/`.tscn`/`.tres` or save-schema changes)
**Baseline:** `main` @ `eef5c5a`; branch `docs/n5-chapter-one-design-lock`

### Summary
- Created `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md` with a source-audited Chapter I gameplay anchor matrix, beat-by-beat readiness classification (`ch1_01_arrival` through `ch1_08_departure`), and small independently reviewable PR slices (`N5.0`–`N5.5`).
- Created `docs/narrative/N5_OWNER_DECISIONS.md` surfacing only genuinely blocking implementation decisions (`D-N5-01` through `D-N5-05`) with bounded options and recommended defaults while keeping all protected lore OPEN.
- Repaired remaining pre-N4.5-C present-tense contradictions across `docs/GDD.md`, `docs/CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/CHAPTER_01_BEAT_SHEET.md`, `docs/narrative/PROLOGUE_STORY_DESIGN.md`, and `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md` (preserving dated historical snapshots).

---

## [2026-11-20] N4.5-C: Forgotten Shore handoff lifecycle correction, pl_09 presentation & docs closure

**Type:** Lifecycle correction, real `pl_09` presentation, real-scene integration test & documentation sync (branch `fix/n45b-handoff-lifecycle-and-presentation` over `main` @ `7579bce`)
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf` (`SUMMARY: passed=32 failed=0 skipped=0`; `PASS: All 291 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`)

### Summary
- Added `scripts/narrative/PrologueHandoffBridge.gd` and moved `PlayerProfile.mark_prologue_completed()` to run ONLY after `ForgottenShoreSession._ready()` confirms valid fresh-session initialization (with one-shot token, destination, duplicate, stale, cancel, unload, Continue, and bounded persistence-failure guards).
- Replaced flat `pl_09` placeholder captions in `PrologueShell.gd` with `ShoreLandingLayer` reusing real Forgotten Shore assets (`bg_mountains_far.png`, `bg_forest_mid.png`, `terrain_shore_tile.png`, `building_shipwreck_stages.png`, `player_monarch_sheet.png`), temporary non-canon `ShoreCrownProp`, and exact `CHAPTER I — FORGOTTEN SHORE` title card.
- Added real destination-scene integration suite `tests/test_n45c_real_handoff_integration.gd` (registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`), updated `tests/test_n45b_forgotten_shore_handoff.gd`, synchronized stale narrative/GDD status docs, and added `docs/narrative/N45C_IMPLEMENTATION_REPORT.md`.

---

## [2026-11-20] N4.5-B: Forgotten Shore landing (pl_09) & Chapter I handoff

**Type:** Production milestone slice (N4.5-B; final Prologue beat `pl_09` + `PlayerProfile` completion marking + `ForgottenShore.tscn` handoff)
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf` (`tests/run_all.sh` ALL SUITES PASSED, 31/31; static verifier 287/287 PASS; 5/5 N4.5-B stability PASS)
**Baseline:** `main` @ `d30d215`; branch `feature/n45b-forgotten-shore-handoff`

### Summary
- Added `PL_09_FORGOTTEN_SHORE` and labelled placeholder cues (`stage_pl09_shore_wake`, `stage_pl09_crown_continuity`, `stage_pl09_chapter_title`) in `PrologueBeats.gd` with zero crown-survival dialogue.
- Added additive `start_shore_handoff()` and isolated `_handoff_runner` in `PrologueShell.gd`, persisting `PlayerProfile.prologue_completed_once` only on normal full completion (never on Skip/Cancel/Dev Exit/Unload) before a single handoff to `res://scenes/world/ForgottenShore.tscn`.
- Added `tests/test_n45b_forgotten_shore_handoff.gd` (36 checks), registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, and recorded `docs/narrative/N45B_IMPLEMENTATION_REPORT.md`.

---

## [2026-11-19] N4.5-A: Voyage & Shipwreck (`pl_07` + `pl_08`)

**Type:** Production milestone slice (N4.5-A; `pl_09` Forgotten Shore landing and `PlayerProfile.mark_prologue_completed()` remain N4.5-B scope)
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf` (`PASS: All 57 N45A Voyage Shipwreck checks completed with 0 failures.`; `bash tests/run_all.sh` `ALL SUITES PASSED`; `PASS: All 284 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`)
**Baseline:** `main` @ `933cf8e`; branch `feature/n45a-voyage-shipwreck`

- Authored `pl_07_unfinished_journey` and `pl_08_shipwreck` in `scripts/narrative/PrologueBeats.gd` using only existing allowlisted `SequenceRunner` ops and labelled `[Placeholder art]` captions (destination, ship origin, and storm cause remain OPEN).
- Wired dedicated `_voyage_runner` (empty `allowed_scenes`), camera-immune `VoyageOverlayLayer` (`MOUSE_FILTER_IGNORE`), `start_voyage_sequence()`, generation-guarded `pl_07 -> pl_08 -> N4.5-A boundary` chaining, and cancel/exit/unload cleanup in `scripts/narrative/PrologueShell.gd` without modifying N4.4 behavior.
- Added `tests/test_n45a_voyage_shipwreck.gd`, registered it in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`, and added `docs/narrative/N45A_IMPLEMENTATION_REPORT.md`.

---

## [2026-11-19] N4.4-E closure verification evidence

**Type:** Documentation & verification closure audit (no gameplay or production code changes)
**Engine Verified:** `4.7.2.stable.official.ed1daf0bf` (10/10 `test_n44_full_flow.gd` PASS; `bash tests/run_all.sh` `ALL SUITES PASSED`; `PASS: All 281 repository integrity, scene-graph, CI lock, and OD-01..OD-10 documentation checks succeeded!`)
**Baseline:** `main` @ `3e3fffb`; branch `test/n44e-closure-evidence`

- Synchronized `docs/narrative/N44E_IMPLEMENTATION_REPORT.md` and `docs/narrative/N44_IMPLEMENTATION_ROADMAP.md` with actual observed 10/10 stability, N4.4-A..D and N4.3-A/C regression results, real user-file byte-exact proof, and windowed visual verification status (`VERIFIED (6 windowed PNGs captured under Xvfb gl_compatibility)`).

---

## [2026-11-18] N4.4-A review fixes: ChamberOverlay geometry + documentation status refresh

**Type:** Review-fix pass on the open N4.4-A PR (no gameplay behavior change; no new content; O6 untouched)

- **ChamberOverlay width fix** (`PrologueRuinsEnvironment.gd`): the chamber zone overlay call passed the chamber's absolute EAST END (`_chamber_end_x(road_max_x)` = the world boundary, 2200) directly as `_create_zone_overlay`'s WIDTH parameter, so the overlay painted [1800, 4000] — 1800 px past the authored band — instead of [1800, 2200]. The call site now converts end→width (`_chamber_end_x(road_max_x) - INTERIOR_END_X`), mirroring the InteriorPassageOverlay's correct delta pattern; `_chamber_end_x` keeps its honest absolute-end contract with a docstring warning about the conversion. The companion unit suite grew 96 → 100 checks: the new assertions pin both overlays' left edge/width/right edge (ChamberOverlay right edge exactly ON the world boundary, both overlays inside the band with positive width) and were verified to FAIL against the old implementation (3 failures, exit 1) before the fix was restored. A repo-wide geometry audit found no other end-vs-width confusion (stage backdrop/road use correct delta sizing; inspectables/walls/altar use correct center-offset geometry).
- **Documentation status refresh:** the living status surfaces now distinguish the review-branch state (N4.4-A implemented, pl_05 playable, pl_06 dormant) from merged main and future content (N4.4-B–E, N4.5–N4.6, pl_07–pl_09): `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (Status + Baseline), `NARRATIVE_IMPLEMENTATION_ROADMAP.md` (Status header, Current state, Implication, policy parenthetical; the historical N4.3-C account and the §11 N4.2-era audit kept verbatim with dated annotations), `PROLOGUE_PRODUCTION_BREAKDOWN.md` and `PROLOGUE_STORY_DESIGN.md` (status headers — the breakdown header no longer contradicts its own "A IMPLEMENTED" row), and `GDD.md` (scope clarification + narrative scope row). Historical milestone records (N43C report, older changelog entries) were deliberately left verbatim.
- **Validation:** full `tests/run_all.sh` ALL SUITES PASSED (verifier 256, N4.2 113, N43A 111, N43B 193, N43C 186, N44A 100); windowed Xvfb visual pass re-run for pl_05 (ChamberOverlay boundaries + reveal sequence reviewed by eye).

---

## [2026-11-18] N4.4-A: Forgotten Ruins foundation & pl_05 exploration

**Type:** Production milestone slice (N4.4-A; new narrative component + chain extension; no new scenes, assets, runner ops, or dialogue; pl_06 DORMANT — its content is N4.4-C/D)
**Engine Verified:** `Godot 4.7.2.stable` (headless suites + windowed Xvfb visual pass; full `tests/run_all.sh` ALL SUITES PASSED; static verifier PASS)
**Baseline:** `main` @ `5d10200` (after the PR #22 design-package merge); branch `feature/n44a-ruins-foundation`

### Summary
Implements slice N4.4-A of the merged N4.4 pre-production design package (PR #22), per its documented defaults:
- **New component** `scripts/narrative/PrologueRuinsEnvironment.gd`: placeholder ruin zones (exterior → interior passage → hidden chamber), one-way zone-state machine with the chamber-reveal trigger, hidden-until-revealed altar group with the labelled crown continuity placeholder, two identical U2-placeholder mark glyphs; D6 atomic fail-closed build (the proven `PrologueMarkInspectables` pattern; no production test seam).
- **Chain extension** (`PrologueShell.gd` + `PrologueExplorationStage.gd` + `PrologueBeats.gd`): pl_04 completion/skip activates pl_05 (no pl_05 dialogue — Beat 05 is environmental storytelling only); the authored band extends east (`ROAD_MAX_X` 800 → 2200, camera limits extend, containment guarantee unchanged); the stage's ONE `ruins_altar_reached` request records pl_05 exactly once at the altar threshold and activates pl_06 DORMANT (segment stays live — the slice-A terminal state); the per-beat skip chain extends (O6 documented default: pl_04 skip → pl_05, pl_05 skip → dormant pl_06; pl_06 skip NOT implemented — O4/N4.4-D scope); status texts for pl_05/pl_06; the N4.2 fallback text corrected to stop claiming "later beats are not implemented".
- **Demonstrated-defect fix:** a skip landing between the recognition opening and the next gated poll could leak the visible `[E] Inspect` prompt into pl_05 — `set_active_beat` now hides the inspection prompt on every non-pl_04 beat change (regression-tested).
- **Tests:** new `tests/test_n44a_ruins_foundation.gd` (96 checks: component D6 matrix + zone machine, full pl_01→pl_06-dormant flow, exactly-once altar boundary, wrong-beat rejection, cancel/unload/failed-setup, camera containment + camera-independent UI at the east bound, skip chain, byte-exact real files, input hygiene); N4.2/N43A/N43B/N43C expectation updates to the documented N4.4-A contract (all listed in the report; no assertion weakening — N43C's A-scenario EXTENDS to the altar, +10 checks); registered in `tests/run_all.sh` + CI.
- **Evidence:** 10 consecutive N44A suite runs exit 0; full `run_all.sh` ALL SUITES PASSED (N4.2 113, N43A 111, N43B 193, N43C 186, N44A 96, verifier 256); windowed visual pass `scripts/tools/n44a_visual_pass.gd` — 9 screenshots + contact sheets reviewed (entry, exterior, interior, chamber reveal, altar approach, dormant boundary, camera-independent UI).
- **Owner decision status (updated 2026-11-18):** **O6 APPROVED** by the owner (Option A — skip chain continues: pl_04 skip → pl_05) after this slice shipped exactly that documented default, so no production change was required; the ruling is recorded in `docs/narrative/N44_OWNER_DECISIONS.md` (O6 → Owner approval) with the original context preserved. O1/O2/O3/O4/O5/O7/O8 and U2/U4/U5 remain OPEN (labelled placeholders only).

**Report:** `docs/narrative/N44A_IMPLEMENTATION_REPORT.md` (scope, traceability, defects, verification, N4.4-B handoff, findings).

---

## [2026-11-18] N4.4 Pre-Production: Forgotten Ruins & Crown's Call design package

**Type:** Documentation only (planning/design; no production code, scene, test, asset, or configuration changes; N4.4 NOT implemented)
**Verification:** docs-only diff reviewed; repository static verifier PASS on the exact tree

### Summary
New PROPOSED design package for N4.4 (pl_05 The Forgotten Ruins + pl_06 The Crown's Call), grounded in the approved story documents and the verified N4.3-C baseline (`main` @ `3ba7b62`):
- `docs/narrative/N44_PREPRODUCTION_REPORT.md` — post-merge reconnaissance, pl_05/pl_06 narrative requirement audit with a fully sourced requirement matrix (APPROVED/DERIVED/PROPOSED/OPEN), scene-level specifications, and the player-experience flowchart.
- `docs/narrative/N44_ARCHITECTURE_DESIGN.md` — architecture decision record (reuse vs narrow extension vs the one new stage-owned component), technical contracts, state machines, and binding exactly-once rules extending the N4.3 ownership model.
- `docs/narrative/N44_TEST_STRATEGY.md` — failure-mode-to-coverage mapping (F1–F18), planned suite layers, full-flow matrix, visual verification plan, and the N4.3 regression guarantees that must stay green.
- `docs/narrative/N44_IMPLEMENTATION_ROADMAP.md` — five independently reviewable slices (A–E) with per-slice scope/acceptance/negative-path criteria, the dependency graph, and the decision-gating analysis.
- `docs/narrative/N44_OWNER_DECISIONS.md` — decision packets for U2/U4/U5 plus eight new N4.4 decisions (O1–O8: ruins identity, vision presentation, camera-focus op, vision-moment skip granularity, altar prompt, skip-chain extension, staging values, audio scope); every decision remains OPEN with a documented placeholder default.
- `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md` §10 — navigation pointer to the package (implementation gated on decision disposition).

No lore invented; all PROPOSED content labelled; pl_05–pl_09 remain NOT implemented.

---

## [2026-11-18] N4.3-C: Full-Flow Integration & Regression

**Type:** Integration & regression milestone (new integration suite + one demonstrated-defect production fix; no narrative content, no pl_05)
**Engine Verified:** `Godot 4.7.2.stable` (headless suites + windowed Xvfb visual pass; full `tests/run_all.sh` ALL SUITES PASSED; static verifier PASS)

### Summary
1. **Integration suite.** New `tests/test_n43c_full_flow.gd` (176 checks) drives the complete experience as ONE continuous shell — pl_01 advance → pl_02 advance → pl_03 intro → genuine movement to the handoff → pl_04 prompt/inspection → recognition → completion → defined boundary — then walks the skip matrix (runner skips stage no cues after the skip point; pl_03 Skip while the intro is open; pl_04 Skip before any inspection / after exactly one / WHILE the recognition dialogue is open — the resumed coroutine emits nothing, the recording belongs to the Skip), the cancellation/teardown matrix (cancel during pl_01 / the pl_03 intro / pl_04 after one inspection / DURING the recognition — the N4.3-B ordering contract holds end to end — plus the dev exit during recognition and a direct scene unload during recognition), failed exploration setup, post-boundary inertness, and input/file hygiene. Ownership is asserted throughout: the runner never records exploration beats, the shell is the sole `NarrativeState` writer, each beat records exactly once. Registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
2. **Production fix (demonstrated by the windowed visual pass; deferred since N4.3-B).** The shell's CenterContainer UI (status labels + the development exit button) sat on the default canvas, which the exploration Camera2D transforms: during pl_03/pl_04 and at the boundary the whole shell UI was displaced outside the viewport (status invisible, dev exit unreachable — while the status text itself claimed "The development exit remains available"). The N4.3-B changelog had noted the camera-transformed labels and deferred the UI change to a later slice. The fix moves the shell UI onto the new `UICanvasLayer` CanvasLayer (layer 1, camera-immune — the same mechanism the DialoguePanel already used at layer 100); world rendering, the camera contract, and all narrative behavior are unchanged. Regression-tested headlessly (the button's true screen rect stays inside the viewport during exploration while the world actor is camera-displaced — contrast proof) and visually (before/after screenshots).

### Key Changes
- `tests/test_n43c_full_flow.gd` (+ `.uid`): new N4.3-C full-flow integration suite.
- `tests/run_all.sh`, `.github/workflows/godot-ci.yml`: N43C suite registered.
- `scenes/narrative/PrologueShell.tscn`: shell UI moved under the new `UICanvasLayer` CanvasLayer.
- `scripts/narrative/PrologueShell.gd`: shell-UI lookups updated to the `UICanvasLayer` paths + in-code contract comment; no behavioral change beyond the fix.
- `tests/test_n41_prologue_shell.gd`, `tests/test_n42_prologue_beats.gd`, `tests/test_n43a_exploration_stage.gd`, `tests/test_n43b_mark_inspection.gd`: shell-UI path lookups updated (Main.tscn lookups untouched).
- `scripts/tools/n43c_visual_pass.gd` (+ `.uid`): the reproducible windowed visual-pass harness (7 screenshots as evidence).
- Docs status sync: `docs/narrative/N4_3_PLANNING.md`, `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md`, `docs/narrative/PROLOGUE_STORY_DESIGN.md` (stale status line), and the new `docs/narrative/N43C_IMPLEMENTATION_REPORT.md`.

### Verified
- `tests/test_n43c_full_flow.gd`: **PASS: All 176 N43C Full Flow checks … 0 failures** (exit 0; 10 consecutive runs before AND 10 after the UI fix).
- Regression after the UI fix: N43A 106, N43B 193, N42 113, N41 87 — all exit 0.
- Full `tests/run_all.sh`: **ALL SUITES PASSED** (exit 0, 20 entries); static verifier PASS.
- Windowed visual verification (Xvfb, 1280x720): 7 screenshots (pl_01 cinematic, pl_02, pl_03 intro/road start + walking, prompt at object A, recognition dialogue, terminal boundary) — Adult Monarch visible and correctly placed; road fully covered with no out-of-bounds exposure; the mark glyph identical on the props; the shell UI (status + development exit) now visible during exploration and at the boundary (fixed); no pl_05 content; no stale prompt.
- Real `user://player_profile.json` / `user://save_slot_0.json` byte-exact unchanged (suite hygiene checks).

---

## [2026-11-17] N4.3-B: Repeated Mark Inspection (slices B1 + B2 + B3)

**Type:** Feature implementation (N4.3-B only — N4.3-C integration/regression is NOT started)
**Engine Verified:** `Godot 4.7.2.stable` (headless suites + windowed Xvfb visual pass; full `tests/run_all.sh` ALL SUITES PASSED; static verifier PASS)

### Summary
1. **B1 — Inspectable set.** New `scripts/narrative/PrologueMarkInspectables.gd`: the three authored placeholder mark objects (identical two-rect placeholder glyph; only the tint varies with the surface condition — mark design U2 and placements U4 stay OPEN), a fail-closed atomic `build()` (validate the whole authored table → construct props/glyph/prompt under a non-tree staging parent → verify every node → commit; any failure frees partials and leaves the component empty, D6), the nearest-in-range query, idempotent per-id inspection state (D1), and the shared provisional `[E] Inspect` prompt (U5). The stage builds the component during setup BEFORE the actor (a failed build fails setup → the shell falls back to its idle boundary) and renders the props as pl_03 scenery; prompt visibility is driven per physics frame in pl_04 behind the presentation gates.
2. **B2 — Interaction, recognition, completion.** The stage polls the existing `interact` action (physical E, `project.godot` unchanged) in its pl_04 physics branch behind the FULL D5 gate (active beat pl_04 · not torn down · segment not ended · movement input enabled · panel not open · stage lock not held · eligible object in range · `interact` just pressed); a first inspection is silent (no dialogue/notification — owner decision D1), repeats are no-ops, and two DISTINCT objects open the approved Story Design Beat 04 recognition line ("I've seen this mark before..." / "Why does it keep appearing?", `PrologueBeats.exploration_recognition_lines()`, data only) through the existing DialoguePanel with the stage-owned lock and the same generation-guard discipline as the intro line. A one-shot `mark_inspection_completed` request is emitted only after a normal close (record-after-dialogue ordering); `PrologueShell._on_mark_inspection_completed()` validates the ACTIVE exploration beat, records `pl_04_repeated_mark` exactly once, and ends the segment at the same defined boundary as the skip. The pl_04 detail label no longer claims "Mark inspection is not implemented yet".
3. **B3 — Registration, regression, CI, visual verification, docs.** The new suite is registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`; the full regression + static verifier are green; a windowed (Xvfb, 1280x720) visual pass captured 12/12 contract checks with screenshots (prompt at range / follows nearest object / hidden out of range / absent during pl_03 / actor stationary under a held movement key during the recognition / boundary reached).

### Production fix (found by the new suite, fixed in `PrologueShell.cancel_sequence()`)
`cancel_sequence()` now aborts the exploration segment BEFORE the runner cleanup. `SequenceRunner._cleanup()` closes the shared DialoguePanel unconditionally as part of its own bookkeeping — with the previous order, a cancellation during the N4.3-B recognition dialogue resumed the waiting coroutine while every stage guard was still disarmed, so the coroutine took its normal-completion path, emitted the completion request, and the shell recorded pl_04 for a beat the user had just CANCELLED (planning: cancel is never a skip). `teardown()` now arms the dialogue-generation/torn-down guards before any shared-panel close, so a cancelled recognition can never record anything. (The N4.3-A intro line had the same exposure with no recording consequence — its normal path only restores input.)

### Key Changes
- `scripts/narrative/PrologueMarkInspectables.gd` (+ `.uid`): new component (authored table, D6 validation, atomic build, three factory methods, range query, per-id state, shared prompt).
- `scripts/narrative/PrologueExplorationStage.gd`: inspectable build in `setup()` (fail-closed, before the actor); `_physics_process` dispatches pl_03/pl_04 (pl_03 handoff semantics unchanged); pl_04 branch = prompt gating + full-D5 interact polling + two-distinct recognition trigger; `mark_inspection_completed` one-shot signal; prompt hidden on `end_segment`/`teardown`.
- `scripts/narrative/PrologueShell.gd`: `_on_mark_inspection_completed()` handler + signal connection; pl_04 detail label updated; `cancel_sequence()` ordering fix (documented in-place).
- `scripts/narrative/PrologueBeats.gd`: `exploration_recognition_lines()` (approved candidate text verbatim; `SequenceRunner` still never sees exploration beats).
- `tests/test_n43b_mark_inspection.gd` (+ `.uid`): new suite — D6 validation matrix, H9/H9a/H9b atomic construction failures, range/prompt/state units, pl_03-unchanged regression, H1/H3/H4/H5/H6/H7a/H7b/H8/H10 (scenarios A–D with separate E/A/R observables)/H11/H14, byte-exact real-file hygiene.
- `tests/run_all.sh`, `.github/workflows/godot-ci.yml`: N43B suite registered.
- Docs status sync: `docs/narrative/N4_3_PLANNING.md`, `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md`.

### Verified
- `tests/test_n43b_mark_inspection.gd`: **PASS: All 191 N43B Mark Inspection checks … 0 failures** (exit 0; two consecutive runs for stability).
- Full `tests/run_all.sh`: **ALL SUITES PASSED** (exit 0, 19 entries); static verifier PASS (all repository integrity/scene-graph/CI-lock checks).
- Regression: N43A 106, N42 113, N41 87, SequenceRunner 60, DialoguePanel 41 — all exit 0.
- Windowed visual verification (Xvfb, 1280x720): **PASS: All 12 N43B visual checks … 0 failures** with six screenshots. Note: the shell's status/detail labels render camera-transformed during exploration (pre-existing N4.3-A behavior — the exploration camera transforms the shell's canvas-layer-0 UI); the label CONTENT was verified programmatically and no UI file changed in this slice.
- Real `user://player_profile.json` / `user://save_slot_0.json` byte-exact unchanged (suite hygiene checks).

---

## [2026-11-17] N4.3-A review fixes (camera visible-area containment, Skip-UI wording, direct-unload regression)

**Type:** Review-fix pass on the N4.3-A slice (three review findings; no scope change — still N4.3-A only, no N4.3-B/C)
**Engine Verified:** `Godot 4.7.2.stable` (headless; full `tests/run_all.sh` ALL SUITES PASSED; static verifier 243 checks)

### Summary
1. **Camera visible-area containment (P1).** A diagnostic probe on 4.7.2 showed `Camera2D.limit_left/right` does clamp the visible viewport edges (at the road start the visible left edge rests exactly on `-800`; the reported "camera sees x = -1126" scenario does not occur), **but `Camera2D.offset` is applied AFTER limit clamping** — the previous `offset = (0, -80)` pushed the actually visible band to `y ∈ [-320, 160]` against authored limits `[-240, 240]`, an 80-px empty strip above the backdrop for the whole segment. The explorer camera now uses **no offset** (the authored vertical band is exactly the reference viewport's world height, so framing is fixed without it), the movement-bounds vs camera-limit seams are authored as **separate parameters**, the backdrop and road art extend **4096 px past the limit band on every side** so no viewport configuration can expose empty space, and the regression suite now **measures the actual visible rect** (`get_screen_center_position()` ± viewport/zoom) at the road start, the west bound, and the east bound and asserts containment (measured values are printed in the PASS lines; all three rest exactly inside the band).
2. **Skip-UI wording (P2).** The pl_04 detail text claimed "The per-beat skip ... remain[s] available", but N4.3-A ships no Skip button/input binding (the per-beat skip is a scripted/API path only, same as the N4.2 `skip_sequence`). The text now names only the development exit; no new UI was added.
3. **Direct scene-unload regression (P3).** New suite stages: with the exploration intro dialogue open and the actor locked, the shell is unloaded via a direct scene change (no `cancel_sequence`, no dev-exit path) — asserts the shell is freed, the `NarrativeState` (kept alive by the suite) recorded nothing, and no coroutine/invalid-access errors occur (a SCRIPT ERROR anywhere still fails the suite through the run_all log trap). Coverage now matches the claimed contract.

### Key Changes
- `scripts/narrative/PrologueExplorer.gd`: camera offset removed (documented why), `_init` takes separate movement bounds and camera-limit parameters.
- `scripts/narrative/PrologueExplorationStage.gd`: `BACKDROP_MARGIN = 4096` — backdrop + road band/edge extend past the limit band on every side; explorer constructed with the separated seams.
- `scripts/narrative/PrologueShell.gd`: pl_04 detail text no longer claims player-facing Skip availability.
- `tests/test_n43a_exploration_stage.gd`: `_visible_rect()` measurement helper; containment checks at the road start (in-motion), west bound, and east bound; direct scene-unload stages 32-35; suite now **106 checks** (was 95).

### Verified
- `tests/test_n43a_exploration_stage.gd`: **PASS: All 106 N43A Exploration Stage checks … 0 failures** (exit 0).
- Full `tests/run_all.sh`: **ALL SUITES PASSED** (exit 0, 17 entries); static verifier **243/243**; `--import` clean; real profile byte-exact unchanged.

---

## [2026-11-17] N4.3-A Technical Spike & Exploration Stage (pl_03/pl_04 orchestration; no mark props)

**Type:** Prologue interactive milestone slice A (dedicated exploration stage + actor + Prologue-specific beat-state/completion handshake; no SaveManager/schema change, no PlayerProfile writes, no new runner ops, no mark objects — N4.3-B is intentionally NOT included)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 17 suites passed, 0 failure markers; repository static verifier 243 checks)

### Summary
Implements **N4.3-A only** per `N4_3_PLANNING.md` §7: the structural chain end after pl_02 becomes the exploration handoff. `scripts/narrative/PrologueExplorationStage.gd` (new) owns the small bounded ancient-road environment (labelled placeholder ColorRect geometry), the stage bounds, the east-end exploration handoff area, and the narrow presentation path for pl_03's approved Story Design internal line through the existing `DialoguePanel`; `scripts/narrative/PrologueExplorer.gd` (new) owns only movement (existing `move_left`/`move_right` actions, bounds-clamped every frame), the idle/walk sprite animation of the existing `player_monarch_sheet.png`, and a gameplay-pattern `Camera2D` (zoom 1.5, smoothing, limits == authored bounds). `PrologueShell` remains the sole owner of authoritative `NarrativeState.mark_completed()` calls for the exploration beats `pl_03_wanderer` / `pl_04_repeated_mark` (new id constants in `PrologueBeats`; deliberately NOT in `BEAT_IDS`, so `SequenceRunner` can never chain or record them): the stage emits one validated handoff-area completion request for pl_03, the shell validates the ACTIVE beat, records it exactly once, and immediately activates pl_04. The stage owns a dedicated `PlayerControlLock` for its dialogue (the runner keeps the shell as control target for pl_01/pl_02 — their no-control behavior is unchanged); dialogue movement gating is proven by tests (the panel alone would not stop `_physics_process`). `skip_current_exploration_beat()` is the narrow per-beat Skip path (pl_03 skip starts pl_04 normally; pl_04 skip ends the N4.3 segment at a defined idle boundary without fabricating pl_05). Cancellation, the development exit, scene unload, and failed setup are NOT skip: nothing is recorded, owned locks are released (freed-safe), exploration input is disabled, and the shell falls back to defined idle states. No quest marker, objective HUD, interact usage, combat, inventory, economy, or lore additions; the recurring mark stays unrepresented (N4.3-B).

### Key Changes
- **`scripts/narrative/PrologueExplorationStage.gd` (new):** bounded road stage (1600x480 authored world band, ground line, labelled placeholder remnants + handoff-area marker), fail-closed atomic `setup()` (no actor/lock on failure), `begin_beat(PL_03)` intro-line presentation with a generation-guarded coroutine, `set_active_beat(PL_04)`, `close_active_dialogue()`, `end_segment()`, freed-safe `teardown()`, and the exactly-once `exploration_handoff_reached` request (fires only while pl_03 is active with movement enabled and the actor crosses the handoff area).
- **`scripts/narrative/PrologueExplorer.gd` (new):** dedicated Node2D actor — no gravity/physics body (flat authored road), bounds-clamped movement, frames 0-3 idle / 4-7 walk with flip (same convention as the gameplay `Player.gd`), `Camera2D` with limits matching the stage bounds, `set_input_enabled` / `freeze()` lifecycle gates. Deliberately does NOT reuse the gameplay `PlayerController` (which carries world commands).
- **`scripts/narrative/PrologueShell.gd`:** N4.3-A exploration segment — Engine metas `crownfall_prologue_exploration` (default ON; the N4.2 suite sets it false to keep its terminal-boundary contract) and `crownfall_prologue_stage_texture` (failed-setup injection), structural-chain-end handoff into exploration, `in_exploration()` / `active_exploration_beat()` / `n43_segment_complete()` / `exploration_stage()` accessors, validated exactly-once completion recording, `skip_current_exploration_beat()`, cancellation/exit aborts, beat-aware status texts (exploration, N4.3 boundary, cancelled, N4.2 fallback).
- **`scripts/narrative/PrologueBeats.gd`:** `pl_03_wanderer` / `pl_04_repeated_mark` exploration beat ids (outside `BEAT_IDS`), the `Monarch` speaker, `exploration_beat_title()`, and pl_03's approved candidate internal line (`exploration_intro_lines()`); pl_04's recognition line intentionally absent (N4.3-B).
- **`tests/test_n43a_exploration_stage.gd` (new, 95 checks):** pl_01→pl_02 flow intact; pl_02→pl_03 exploration entry; actor presentation + movement gated by dialogue (frozen while locked, responsive after close, stopped on release); west/east bound clamps incl. hold-at-bound; camera/geometry validity; handoff-area completion recorded exactly once; duplicate requests ignored; pl_04 activation; pl_03 Skip (including while the intro dialogue is open) activating pl_04 without skipping it; pl_04 Skip ending at the N4.3 boundary with profile fixture byte-exact unchanged; cancellation/dev-exit/freed-actor/failed-setup semantics; real files byte-exact untouched.
- **`tests/test_n42_prologue_beats.gd`:** one Engine-meta line (`crownfall_prologue_exploration = false`) so the N4.2 terminal-boundary contract keeps its dedicated coverage; 113 checks unchanged.
- **`tests/run_all.sh` + `.github/workflows/godot-ci.yml`:** N43A suite registered after N4.2 (suite label "N43A" — the CI workflow forbids a literal "4.3" substring).
- **Docs:** roadmap §5, `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (§A shell paragraph, §E control-lock note, N0 implemented-beats note), `PROLOGUE_PRODUCTION_BREAKDOWN.md` (§3 N4.3 row), `N4_3_PLANNING.md` status header.

### Isolation note (pre-existing, unchanged)
The full-suite regression creates `user://save_slot_0.json` (+`.bak`) via the M8 integration slice's simulated session autosave (`tests/test_integration_m8_slice.gd` "Sunrise Day 2 autosave" through ContinueButton) — behavior byte-identical to the branch base `539f856` (no diff in the M8 test, `SaveManager`, or `ForgottenShoreSession`). It is not caused by N4.3-A; every narrative suite still proves non-mutation of the developer's real files via start-of-suite byte snapshots (all green).

---

## [2026-11-17] N4.2 The Lost World + A Faint Resonance (beats pl_01 + pl_02)

**Type:** Prologue story content (two authored beats + shell auto-start/chaining; no SaveManager/schema change, no PlayerProfile writes, no new runner ops, no art/audio assets)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 16 suites passed, 0 failure markers; repository static verifier 238 checks)

### Summary
Implements roadmap slice **N4.2**: the Prologue's first two story beats are now authored and playable through the real New Game entry flow. `scripts/narrative/PrologueBeats.gd` (new content module, data only) authors `pl_01_lost_world` ("The Lost World") and `pl_02_faint_resonance` ("A Faint Resonance") as NarrativeData-validated sequences in the existing typed, allowlisted op format — no new runner ops, no quest/cinematic framework, no JSON-driven scripting. pl_01 uses the Story Design Beat 01 candidate narration verbatim and never states the cause of the Great Eclipse; pl_02 depicts exactly one small, uncontrolled childhood manifestation (one resonance cue, one narration line, then failed attempts to repeat it) with no spellcasting, no power origin, an unnamed stone location (OPEN decision preserved), and no crown in either beat. The shell (`PrologueShell.gd`) stays lifecycle-only: it auto-plays the first uncompleted beat on route load (production default, matching pl_01's "New Game start" entry condition; headless suites override via the Engine meta `crownfall_prologue_autostart`, same injection convention as `crownfall_load_on_start`), chains pl_01 → pl_02 exactly-once via `sequence_completed`, stages beat cues on a labelled placeholder stage (`[Placeholder art]` captions through the existing `play_cue` op), and marks the N4.2 boundary only when next-beat discovery finds no next authored beat after the completed beat — every playback refusal (exit started, busy runner, already-completed next beat, invalid data, `play()` rejection) keeps the boundary FALSE and is reported explicitly; no scene transition (the shore handoff remains N4.5), no completion marking, and the development-only exit remains the only way out. Dialogue stays text-only English (DECIDED language).

### Key Changes
- **`scripts/narrative/PrologueBeats.gd` (new):** authored beat data — `BEAT_IDS` order, `get_beat(id)` (deep-copied, fail-closed for unknown ids), `stage_caption(cue_id)` (labelled placeholder captions), `is_beat(id)`. Content lives here; the shell authors no story text.
- **`scripts/narrative/PrologueShell.gd`:** `start_prologue()` + auto-start on `_ready` (meta-gated), beat chaining from `sequence_completed` (runner idle at emit time; generation guards keep the finished run stale) with **next-beat discovery (`_next_beat_id`) separated from next-beat playback (`_play_next_beat`)** — the chain handler marks the N4.2 boundary only when discovery finds no next authored beat; a next beat that exists but cannot start (exit started, busy runner, already-completed beat, invalid data, `play()` rejection) keeps the boundary FALSE, is reported via `push_warning`, and leaves the shell in a defined idle state the development exit can leave and `start_prologue()` can retry. Plus `_on_sequence_cue` placeholder staging + `set_cue_player(Callable)` observability hook, `current_beat_id()` / `prologue_reached_end()` accessors, stage hide on completion/cancel/failure, and boundary status text. Non-beat sequences (e.g. the N4.1 suite's plumbing fixtures) still play via `play_sequence` and never trigger chaining.
- **`scenes/narrative/PrologueShell.tscn`:** `StageBackdrop` + `StageCaption` labelled placeholder stage nodes (hidden by default) and N4.2 status text.
- **`scripts/narrative/SequenceRunner.gd`:** `sequence_started` / `sequence_completed` / `sequence_failed` ids are now snapshotted into locals before emission — the shell's chain handler starts the next beat from inside the completion emission, which reassigns `_current_id`, and later listeners must still observe the id the signal is about (latent N3 quirk made visible by chaining; regression-covered by the N4.2 suite). Plus a read-only `is_control_locked()` accessor.
- **`tests/test_n42_prologue_beats.gd` (new, 113 checks):** both beats load and validate fail-closed (single sequences + whole payload with unique ids); real entry flow (first New Game → shell); explicit `start_prologue` on an idle shell and the production auto-start flow; dialogue progression/completion through the panel; control lock engagement and restoration; NarrativeState records both completions exactly once; chain order pl_01 → pl_02 and the N4.2 boundary with NO premature boundary after pl_01 (no shore transition, no chain advance on cancellation, non-beat completions never chain); cue order across both beats (exactly one manifestation); invalid payloads fail closed; cancellation/dev-exit cleanup without completion; skip fast-forwards a beat and still completes exactly once; **boundary strictness (review fix)** — discovery matrix (`""` → pl_01, pl_01 → pl_02, pl_02 → `""` as the only boundary trigger, unknown → `""`), busy-runner refusal, already-completed next-beat refusal (out-of-band `NarrativeState.mark_completed` + end-to-end chain refusal), boundary FALSE after every refusal, unchanged boundary status text, retry semantics, and the development exit from the refusal idle state; profile/world-save fixtures byte-exact untouched (plus the developer's real files, sidecars included).
- **`tests/test_n40_profile_entry_gate.gd` + `tests/test_n41_prologue_shell.gd`:** one Engine-meta line each (`crownfall_prologue_autostart = false`) so their lifecycle assertions keep running against an idle shell; no other changes (101/87 checks unchanged).
- **`tests/run_all.sh` + `.github/workflows/godot-ci.yml`:** N4.2 suite registered after N4.1.
- **Docs:** roadmap §4/§5, `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (status, §A, §E emission-snapshot guard, N0 implemented-beats note), `PROLOGUE_PRODUCTION_BREAKDOWN.md` (status, §3 N4.2 row, §5 route-target note), audit header note.

### Lore discipline (accepted constraints)
No Eclipse cause, no power origin, no dynasty/kingdom/Crown invention, no crown appearance in pl_01/pl_02, exactly one manifestation, placeholder captions only (labelled, no implied canon), dialogue in English. The childhood stone location and the narration copy remain owner-reviewable (candidate text labelled in the breakdown).

---

## [2026-11-17] N4.1 Prologue Shell (lifecycle only — story beats NOT included)

**Type:** New narrative infrastructure (functional scene shell; no Prologue content, no canon dialogue, no SaveManager/schema change)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 15 suites passed, 0 failure markers; repository static verifier 234 checks)

### Summary
Implements roadmap slice **N4.1**: the labelled N4.0 route placeholder becomes the functional Prologue shell at the same path (`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd`). The shell owns its runtime state — a per-run `NarrativeState`, a `DialoguePanel`, and a `SequenceRunner` whose `change_scene` op is allowlisted to `res://scenes/world/ForgottenShore.tscn` (the future N4.5 handoff channel) — and exposes `play_sequence` / `skip_sequence` / `cancel_sequence` as the presentation contract for the N4.2–N4.5 beats (no sequence data is authored or shipped; the nine beats and any completion marking remain future work). Runtime initialization is idempotent per scene instance, and every exit/handoff passes a single-transition guard (`_begin_exit` / `is_exit_started`), so duplicate exit or duplicate sequence scene-change requests are safely ignored. Exit semantics are split: a **development exit** cancels a running sequence (deterministic cleanup, completes nothing), while a **sequence-driven handoff** never cancels the finishing sequence — the runner is inside its `change_scene` op and still runs `_finalize_completion()`, so `sequence_completed` fires exactly once and the `NarrativeState` records the sequence (regression-tested). The one exit available today is a clearly labelled **development-only** "Return to Main Menu (Development Exit)" button: it never touches `PlayerProfile`, never writes the profile or any world save, and the per-run narrative state is discarded with the scene (the Prologue stays non-resumable per the technical design). Entering, running, or exiting the shell does not mark `prologue_completed_once`. `Main.gd` routing, the N4.0 entry gate, Continue behavior, and SaveManager schema v2 are unchanged.

### Key Changes
- **`scripts/narrative/PrologueShell.gd` (replaced placeholder):** functional shell — idempotent `_initialize_runtime()` (builds `NarrativeState` + `DialoguePanel` + `SequenceRunner` exactly once), `play_sequence` (fail-closed via `NarrativeData.validate_sequence`, exactly-once completion in the N3 runner), `skip_sequence` / `cancel_sequence` (N3 semantics), `set_exit_transition(Callable)` test-observability hook (same convention as `Main.set_route_transition`), guarded `request_main_menu_return()` / sequence-driven `_on_sequence_scene_transition()` with split exit semantics (`_begin_exit(scene_path, cancel_running_sequence)`: dev exit cancels a running sequence and completes nothing; a sequence handoff leaves the finishing sequence untouched so its completion still fires), and the development-only exit button handler.
- **`scenes/narrative/PrologueShell.tscn`:** status text stating the N4.1 shell is active and story sequences (N4.2–N4.5) are not implemented; `DevExitButton` ("Return to Main Menu (Development Exit)") replaces the N4.0 `ReturnToMenuButton` (the non-dead-end contract is unchanged; the N4.0 suite assertion was updated to the new control name).
- **`tests/test_n41_prologue_shell.gd` (new, 87 checks):** scene load/instantiate + script identity; runtime ownership and idempotent init; allowlisted text-only sequence plumbing (play → dialogue presentation → advance → exactly-once completion; cancel → no completion, panel closed); sequence-driven handoff regression (change_scene through the shell's own callback: single transition, exactly-once `sequence_completed`, `NarrativeState` record, duplicate handoff ignored, dev-exit-while-running cancels without completion); enter/run/exit never creates or mutates profile fixtures (byte-exact); duplicate exit ignored (single transition); no stale runtime state after exit and a fresh instance starts clean; N4.0 routing contract preserved (first New Game → shell, Play Again → shell, Skip → fresh Forgotten Shore without touching the profile flag, Cancel stays in the menu and revokes the pending confirmation, Continue bypasses the Prologue and consumes the injected day-2 save). Fixtures under `user://n41_test/` via the Engine-meta injection contract; the developer's real `player_profile.json` / `save_slot_0.json` / sidecars are proven byte-unchanged; fixture sidecars are cleaned before/after the run.
- **`tests/test_n40_profile_entry_gate.gd`:** stage-28 shell assertions updated from the removed `ReturnToMenuButton` to the renamed `DevExitButton` (same non-dead-end and no-completion claims; suite is 101 checks).
- **`tests/run_all.sh` + `.github/workflows/godot-ci.yml`:** N4.1 suite registered after N4.0.
- **Docs:** roadmap §5 (N4.0 + N4.1 implemented, N4.2–N4.6 not), `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A (as-built shell lifecycle and contracts), `PROLOGUE_PRODUCTION_BREAKDOWN.md` §3/§5 (N4.1 slice marked implemented), audit snapshot note.

---

## [2026-11-17] N4.0 Player Profile & Entry Gate (Prologue content NOT included)

**Type:** New narrative infrastructure + entry-flow change (no Prologue content, no canon dialogue, no SaveManager/schema change)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 14 suites passed, 0 failure markers; repository static verifier 231 checks)

### Summary
Implements roadmap slice **N4.0** decided in `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A/B: a minimal persistent `PlayerProfile` holding exactly one durable fact — `prologue_completed_once` — and the New Game / Continue entry gate. First-ever Start New Game routes to the labelled Prologue route placeholder with Skip locked; after one recorded completion, Start New Game offers **Play Prologue Again / Skip Prologue**; Skip enters a fresh Forgotten Shore session without touching the profile; Continue bypasses the Prologue entirely and keeps loading existing world saves (including legacy v1). `SaveManager`, `ProgressionState`, world-save schema v2, and `ForgottenShoreSession` are unchanged. **The nine Prologue beats are NOT implemented**: `scenes/narrative/PrologueShell.tscn` is a clearly labelled, inert N4.0 placeholder (no beats, dialogue, handoff, or completion marking), and nothing in the runtime flow sets the completion flag. N4.1–N4.6 remain not implemented.

### Key Changes
- **`scripts/narrative/PlayerProfile.gd` (new):** global profile at `user://player_profile.json`, schema `{"schema_version": 1, "prologue_completed_once": false}`. Strict fail-closed validation (exact two-key shape, exact-int schema version, bool flag; missing/malformed/unsupported-version/unreadable data all read as "not completed" and never block New Game or Continue). Atomic persistence (`.tmp` → re-read verify → staged rename with `.old` rollback, SaveManager convention; no SaveManager code reuse or modification). API: `load_profile(path) -> {ok, error}`, `is_prologue_completed_once() -> bool`, `mark_prologue_completed(path) -> bool` (reports persistence success). Unsafe paths rejected; no signals, no autoload, no settings framework.
- **`scripts/core/Main.gd`:** after the existing (unchanged-wording) overwrite confirmation, the profile gate routes Start New Game: `prologue_completed_once == false` → Prologue route (`crownfall_load_on_start = false`, no Skip offered); `true` → returning-player choice overlay (**Play Prologue Again** / **Skip Prologue** / Cancel; Cancel stays in the menu). Skip and Play Again are single-transition guarded (`_route_started`); the confirm-overlay Cancel button is now named `CancelNewGameButton`. Continue is untouched and never reads the profile.
- **`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd` (new):** N4.0 placeholder route target for `Main.PROLOGUE_ROUTE_SCENE`; inert except a Return to Main Menu button so the build cannot dead-end. **N4.1 replaces the scene content at the same path** (or updates the constant in the same PR); the routing decision does not change.
- **Tests:** `tests/test_n40_profile_entry_gate.gd` (new, 66 checks): profile behavior matrix (missing/false/true/malformed/missing-field/unsupported-version/unreadable/write-failure/reload), entry flow (first-ever routing, no Skip, choice, cancel paths, repeated-press single-transition guard), Skip → fresh Forgotten Shore (previous day-2 save left intact, default ledger), Continue independence (v2 + legacy v1 loads, corrupted profile does not disable Continue), placeholder sanity, and byte-exact proof that the developer's real `user://player_profile.json` is never mutated. Registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
- **`tests/test_integration_m8_slice.gd`:** entry stage adapted to the new gate — it runs as a returning player via an injected pre-completed profile and reaches Forgotten Shore through the real Skip path; all 39 gameplay/save/continue checks are unchanged in behavior (overlay visibility now uses `is_visible_in_tree()` so hidden overlays are never re-pressed).
- **Docs:** roadmap §3/§5 (N4.0 implemented, N4.1–N4.6 not), `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A (verified implementation + N4.1/N4.5 contract), `PROLOGUE_PRODUCTION_BREAKDOWN.md` §5 (as-built profile/entry contract), audit snapshot note.

---

## [2026-11-16] Narrative Runtime Foundation (N1–N3, test fixtures only)

**Type:** New narrative systems (minimal foundation; no Prologue content, no canon dialogue, no save-schema change)
**Engine Verified:** `Godot 4.7.2.stable` (local headless runs: repository verifier, full `tests/run_all.sh`, and the three new suites below)

### Summary
Implements the roadmap N1–N3 foundation decided in `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`: in-memory `NarrativeState`, fail-closed `NarrativeData` validator, `DialoguePanel` + `PlayerControlLock` input isolation, `SequenceRunner` with typed allowlisted operations, the `dialogue_advance` input action, and a Start New Game overwrite confirmation. **No narrative persistence was added** (linear non-resumable Prologue policy, decisions D1/D2): `SaveManager`, `ProgressionState`, and schema v2 are unchanged. All dialogue fixtures are explicitly non-canon.

### Key Changes
- **`scripts/narrative/NarrativeState.gd` (new):** per-run, in-memory completion set; idempotent `mark_completed`; never serialized.
- **`scripts/narrative/NarrativeData.gd` (new):** fail-closed validator/loader for typed, allowlisted sequence steps (`dialogue`/`wait`/`lock_control`/`unlock_control`/`play_cue`/`change_scene`/`finish`) with strict bounds; unknown fields/ops rejected.
- **`scripts/narrative/DialoguePanel.gd` (new):** separate CanvasLayer (speaker/body/advance hint); consumes all unhandled input while open; advances only via `dialogue_advance`; emits `dialogue_finished` exactly once per session.
- **`scripts/narrative/PlayerControlLock.gd` (new):** disables/restores the control target's physics + unhandled-input processing (idempotent, freed-safe).
- **`scripts/narrative/SequenceRunner.gd` (new):** deterministic linear playback; frame-counted waits (no `Timer` nodes); injected cue/transition callables with scene allowlist; completion emitted exactly once per run; `skip()` fast-forwards (pending `change_scene` at most once) and still completes once; `cancel()` and `_exit_tree` always restore control.
- **`scripts/core/Main.gd`:** Start New Game asks for confirmation when a valid save exists (protects existing saves before Prologue wiring).
- **`project.godot`:** added `dialogue_advance` input action (Enter / Left Mouse Button).
- **Tests:** `tests/test_narrative_foundation.gd` (39 checks), `tests/test_dialogue_panel.gd` (19 checks), `tests/test_sequence_runner.gd` (31 checks); non-canon fixture `tests/fixtures/narrative_sequences.json`; all three registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
- **Docs:** `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (ADR + N0 contract), `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md` (N4 readiness), roadmap/audit/gap analysis synchronized.

### Deliberately Deferred
- Prologue content (N4), Chapter I content (N5), `camera_focus`/`pause_world` ops (PROPOSED), portraits/voice/localization, any narrative persistence, and all Prologue skip/staging decisions (OPEN).

---

## [2026-11-16] Shrine, Statue, Temple, Resource Access & Buff Foundation (Phase 5)

**Type:** New Gameplay Systems (structure domain + explicit resource access + buff foundation; save schema stays version 2 with zero new save keys)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and re-run after documentation changes: static verifier `204` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `188` checks across `7` suites, Phase 5 suite `209` checks across `8` suites — all green)

### Summary
Phase 5 adds the Shrine/Statue/Temple foundation, the explicit resource-access foundation, and a deliberately scoped buff system. Structures are validated data-driven definitions (`data/structures.json` + `StructureCatalog.gd`) with distinguishable categories, pinned `<id>_activated` activation facts, atomic EconomyLedger costs, and optional world placement; the derived lifecycle (`activated`/`not_present`/`available`/`locked`) comes from durable progression facts (no save fields of its own); unplaced and inactive-island structures report `not_present` and are never described as ready for activation. Resource access is separated from resource quantity (`data/resources.json` + `ResourceCatalog.gd` + `ResourceAccessState.gd`): gold/wood/stone ship as explicit `base_accessible` definitions so no existing gameplay path is broken, unlock-by-fact requirements support multiple `any_of` sources, evaluation never consults ledger balances, and unknown IDs fail closed. Buffs are validated definitions (`data/buffs.json` + `BuffCatalog.gd`) with a consumer-backed effect registry, additive stacking whitelist, permanent-only durations (timed definitions rejected fail-closed until a real consumer exists), and an authoritative derived aggregation (`BuffDomain.get_effect_total`) that makes duplicate application structurally impossible. The first playable structure is the Shrine of Growth on Forgotten Shore (`x=820`): requires the Stone Wall Tier 2 milestone and 4G 2W 3S, grants the `grove_timber_blessing` (+1 Wood to every island wood acquisition — player node collection, tree felling, villager auto-chop). The Statue and Temple definitions are registered and validated but intentionally unplaced (fail closed). Schema v2 keeps zero new save keys: activations ride the strictly validated `progression_facts` array, legacy saves never fabricate activations or access, loading replaces state (verified into non-empty Phase 5 sessions), and failed restores roll the whole session back.

### Key Changes
- **`scripts/structures/StructureCatalog.gd` + `data/structures.json` (new):** all-or-nothing validated loading (strict field sets, stable unique IDs, category/island whitelists, pinned registry-approved activation facts, positive EconomyLedger costs, bounded world positions, shared requirement-group validator, empty requirement groups rejected).
- **`scripts/structures/StructureDomain.gd` (new):** derived lifecycle queries (explicit `not_present` state for unplaced and inactive-island structures) and the authoritative activation transaction (validate -> duplicate guard before spend -> island/world presence -> finite actor position -> proximity -> requirements -> atomic spend -> record fact -> signal; duplicate activation never spends twice; non-finite actor coordinates (NaN/±inf) rejected before any proximity math or mutation; defensive refund on the unreachable fact-recording failure).
- **`scripts/resources/ResourceCatalog.gd` + `data/resources.json` (new):** resource definitions with exactly one access source each (explicit base access or fact-gated unlock; ambiguous or source-less definitions rejected).
- **`scripts/resources/ResourceAccessState.gd` (new):** deterministic fail-closed access queries derived from registered unlock conditions plus durable facts, never from balances; enforcement point added at player-initiated acquisition before any ledger mutation (no-op for base resources).
- **`scripts/buffs/BuffCatalog.gd` + `data/buffs.json` (new):** validated buff definitions (effect type registry with real consumers only, positive magnitudes, additive stacking whitelist, permanent-only durations, validated source-structure reference).
- **`scripts/buffs/BuffDomain.gd` (new):** authoritative additive aggregation derived per query from activation evidence (duplicate structure IDs collapsed; unknown effect types 0; nothing stored or re-applied on load).
- **`scripts/progression/ProgressionState.gd`:** three activation facts registered (`shrine_of_growth_activated`, `statue_of_the_first_sailor_activated`, `temple_of_the_dawn_activated`); only the Shrine has a gameplay recording path.
- **`scripts/world/ForgottenShoreSession.gd`:** structure domain + resource access members, `activate_structure` command with nearest-activatable fallback, programmatic dormant/awakened landmark visuals, resolver kind `structure`, proximity prompts, wood-blessing application to collection/felling/villager auto-chop (ledger-outcome-checked so feedback never claims ungranted wood), resource-access gate on acquisition, HUD blessings line.
- **`scripts/player/InteractionResolver.gd`:** structure targets for AVAILABLE structures (locked and already-activated structures offer no interaction).
- **`scripts/ui/ClockHUD.gd`:** passive structures/blessings status line (presentation only).
- **`scripts/tools/generate_pixel_assets.py` + `assets/environment/landmarks/env_shrine_structure.png` (new):** generated 2-frame dormant/awakened shrine landmark following the greed-portal precedent.
- **`tests/test_structure_buff_phase5.gd` (new, registered in `tests/run_all.sh` and CI):** 209 checks across 8 suites — catalog validation (all three catalogs), derived lifecycle (including `not_present` for unplaced and inactive-island structures), activation transactions (success/unknown/non-finite actor positions/out-of-range/insufficient-funds/future-island/duplicate without double spending), buff aggregation, resource access (zero-balance-unlocked, nonzero-balance-locked, unknown IDs, multiple unlock sources, legacy saves), real session command/resolver/blessing paths with exact balance math (including cap-exceeded fallback and villager auto-chop), save round-trips, legacy saves into Phase-5-active sessions, transactional rollback, malformed-fact rejection, and specialist/research/offering/building/economy/era regression guards.
- **Self-review fixes shipped with regression tests:** ledger-cap blessing fallback (UI agrees with authoritative state), villager auto-chop blessing coverage, activation refund on the unreachable fact-recording failure, catalog duplicate-ID message convention alignment.
- **Post-review hardening (this PR's fix commit):** non-finite actor positions (NaN, +inf, -inf) are rejected before any proximity math with a clear rejection reason and zero economy/fact mutation (a scratch pre-fix repro showed a NaN position fully activating the shrine and spending its cost); the derived structure lifecycle reports `not_present` for unplaced and inactive-island structures so it never claims readiness for activation (pre-fix repro returned `available`); both world resolvers pre-filter by island and world position, so resolver behavior is unchanged.

### Deliberately Deferred
- Timed buff runtime (no Phase 5 consumer; timed definitions are rejected fail-closed at load).
- Resource-unlock-by-structure gameplay (the access foundation supports fact-gated resources; no live locked resource ships to avoid breaking the Forgotten Shore slice).
- Statue and Temple world placement (definitions exist and fail closed until a future phase places them).
- Future-island structures and Eldergrove content.

---

---

## [2026-11-16] Research Phase 4.1 — Reset Research State When Loading Legacy Saves

**Type:** Save-Load Correctness (narrow fix on top of Phase 4; no new systems, no schema change, no migration change)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes: static verifier `195` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `188` checks across `7` suites — all green)

### Summary
Independent code review found a defect in `ForgottenShoreSession._apply_loaded_payload()`: research was restored only inside `if data.has("research")`, so loading an older schema-v2 save without the optional `research` key left the live session's in-memory `ResearchManager` state completely unchanged. A session that had completed a technology or had a project running would silently keep that research state even though the authoritative payload contained none — resurrection of state the save does not own, violating the documented contract (design section 14: "absent key = empty research state"; `ResearchManager` header doc). The fix adds a dedicated transactional `ResearchManager.reset_to_empty_state()` that routes through the existing validated `apply_save_dict` path (canonical empty payload `{"completed_techs": [], "active_research": null}`) and calls it from a new `else` branch when the key is absent. Missing key = empty research state; present valid key = restore that state; present malformed value (including explicit `"research": null`) = reject the save exactly as before; a failed load still rolls the whole session back through the existing snapshot mechanism. Strict validation is untouched, schema stays version 2, `migrate_payload` is untouched, and no resource is refunded or deducted by the reset.

### Key Changes
- **`scripts/research/ResearchManager.gd`:** new `reset_to_empty_state() -> bool` — transactional reset to the canonical empty research state, delegating to the same validated `apply_save_dict` path so replacement stays atomic with zero partial mutation. The bool return keeps the transactional contract uniform for the caller (a defensive failure aborts the load and triggers the session rollback); it cannot fail by construction.
- **`scripts/world/ForgottenShoreSession.gd`:** `_apply_loaded_payload()` now resets research to the empty state when the optional `research` key is absent (payload is the authority). The present-key branch (including explicit-null rejection) is unchanged. Both outcomes still participate in the existing whole-session rollback.
- **`tests/test_research_foundation.gd`:** new suite "Legacy Save Research Reset (Phase 4.1)" (58 checks) with the required regression cases: (A) legacy save after a completed technology loads and empties completed research, active project and derived effects (verified end-to-end through the real shrine-offering command path yielding the base +2 gold); (B) legacy save during an active project clears the project and elapsed progress with balances matching the payload exactly (no refund, no second deduction, advancing afterwards is a no-op); (C) a valid modern save with both completed and active research restores the completed set, the active ID and the exact elapsed progress over a non-empty live research state (replacement, not merge; no resource change; the restored project completes exactly once at its duration boundary); (D) explicit `"research": null` is rejected wholesale with the live research and progression state unchanged; (E) when research restoration succeeds but a later subsystem fails, the existing session rollback restores the previous research state, economy and roster (a fail-once `NPCPopulationManager` test double fails only the first apply call and delegates the rollback retry to the real implementation). Cases A and B were verified to fail against the pre-fix implementation (suite exit 1 at Case A; a scratch pre-fix repro confirmed `has_active_research() == true` after a legacy load for Case B). Research suite count 6 -> 7 suites, 130 -> 188 checks.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 14 acceptance evidence updated to the new suite counts; the Phase 4 summary phrase "old saves without the research key load untouched" in this changelog was corrected to the actual (now enforced) contract "load with an empty research state".

## [2026-11-16] Specialist & Research Foundations (Phases 3 & 4)

**Type:** New Gameplay Systems (specialist domain foundation + research system foundation; save schema stays version 2)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and again after the documentation changes: static verifier `195` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `130` checks across `6` suites — all green)

### Summary
Phase 3 adds the specialist domain foundation: a validated data-driven roster (`data/specialists.json` + `SpecialistCatalog.gd`) of the four established specialists, a four-state lifecycle (`undiscovered -> discovered -> recruitable -> recruited`) derived from durable progression facts plus live building state (no separate specialist save fields), discovery and recruitment as separate authoritative transactions (idempotent discovery; recruitment order validate -> atomic spend -> record fact -> signal; duplicate recruitment rejected; failed recruitment never mutates state), and a minimal housing requirement integrated with the data-driven building system via the new `hut_scientist_01` (`specialist_hut`) plot. The Scientist is the first playable specialist on Forgotten Shore: discover at `x=-1010`, build their hut at `x=-980`, recruit for `3G 2W`. All eight specialist fact IDs are registered; only the Scientist has a gameplay recording path, so no fact is fabricated for future islands.

Phase 4 makes the Scientist provide a real function: a validated technology catalog (`data/technologies.json` + `TechnologyCatalog.gd`) with prerequisite-cycle detection and an effect registry that rejects unimplemented effects, `ResearchManager.gd` with one active project, authoritative requirements (recruited Scientist, prerequisite technologies, Stone Age fact gate), transactional starts through the atomic `EconomyLedger`, world-clock-driven progress (the session's scaled sim delta — no UI timers or frame counting), exactly-once completion with derived effects, and persistence as the optional top-level `research` save key. Two Forgotten Shore technologies ship: `inscription_studies` (Shrine Offering +3 gold) and `improved_flares` (Kindle Flare +4s), the latter gated on the Stone Age milestone. No Iron Age content exists on Forgotten Shore; schema stays version 2 and old saves without the research key load with an empty research state (explicit null / unknown IDs / duplicate IDs are rejected wholesale with no partial mutation; the reset behavior itself shipped corrected in the Phase 4.1 entry below).

### Key Changes
- **`scripts/specialists/SpecialistCatalog.gd` + `data/specialists.json` (new):** fail-safe all-or-nothing definition loading with strict field sets, stable unique IDs, role/island whitelists, fact bindings pinned to the registered `<id>_discovered`/`<id>_recruited` pattern, positive EconomyLedger costs, and optional housing/world-position/requirement-fact fields; future-island specialists omit placement so discovery/recruitment fail closed.
- **`scripts/specialists/SpecialistDomain.gd` (new):** derived lifecycle queries, idempotent discovery, and the authoritative recruitment transaction; no save state of its own (facts + buildings carry everything).
- **`scripts/research/TechnologyCatalog.gd` + `data/technologies.json` (new):** validated technology definitions with cycles rejected and exactly the two scoped Forgotten Shore technologies.
- **`scripts/research/ResearchManager.gd` (new):** availability/progress/completion state, transactional starts, authoritative world-time advancement, exactly-once completion, derived completion effects, and transactional save restore (unknown/duplicate technology IDs rejected against a file-derived fail-closed static registry; active projects resume with exact elapsed time and never re-deduct costs; completed technologies never re-apply rewards).
- **`scripts/progression/ProgressionState.gd`:** registered the eight specialist facts (discovery/recruitment for scientist, blacksmith, architect, scholar).
- **`data/buildings.json` + `scripts/save/SaveManager.gd`:** new `hut_scientist_01` specialist-hut plot (data-driven) added to the strict save plot whitelist.
- **`scripts/world/ForgottenShoreSession.gd`:** specialist + research members and signal wiring; `discover_specialist` / `recruit_specialist` / `start_research` world commands (empty targets resolve deterministically); programmatic specialist-camp visuals and prompts; research advancement fed with the authoritative scaled sim delta; shrine offering and flare duration consume the aggregated research effects (fresh-session behavior unchanged); research state included in the save payload and restored transactionally on load.
- **`scripts/player/InteractionResolver.gd`:** specialist interaction block (discover / recruit prompts with data-defined cost text) and the research prompt (first available technology in stable ID order, offered at the recruited specialist's position).
- **`scripts/ui/ClockHUD.gd`:** research status line (`set_research_text`).
- **Tests:** new `tests/test_specialist_domain.gd` (108 checks, 5 suites) and `tests/test_research_foundation.gd` (130 checks, 6 suites); registered in `tests/run_all.sh` and the CI workflow. Existing Phase 1/Phase 2 suites updated only where they used `scientist_recruited` as the canonical UNKNOWN fact-ID example (now `mount_tamed`; the unknown-ID rejection intent is unchanged) — Phase 1 stays at 139 checks, Phase 2 at 162 checks.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` sections 13-14 (shipped Phase 3/4 boundaries), `PROGRESSION_IMPLEMENTATION_ROADMAP.md` (Phases 3-4 marked implemented with exit criteria met), `ROADMAP.md` (implemented-vs-future summary), `GDD.md` (specialist and research bullets in the settlement section).

### Deliberate boundaries
- Specialist and research states stay separate domains: specialists are not villager NPCs, research completion is not duplicated into progression facts (one source of truth), and the multiplayer command whitelist stays unchanged (remote peers cannot trigger the new commands until multiplayer scope defines them).
- Blacksmith/Architect/Scholar gameplay, additional technologies, research queues, and multi-island simulation are NOT implemented and are documented as future work.

---

## [2026-11-16] Progression Phase 2.2 — Reject Malformed Progression Data Before Migration

**Type:** Save Migration Correctness (narrow ordering fix on top of Phase 2.1; no gameplay, balance, or schema changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and again after the documentation changes: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites — all green)

### Summary
Phase 2.1 made the fact-backfill helper itself strict, but the Phase 2 migration section could still partially mutate progression-related fields before `validate_payload` rejected an explicitly malformed `progression_facts` value: with `era_id = "iron_age"` plus an explicit `"progression_facts": null` (or any other malformed value such as a string, number, dictionary, or invalid array), the conservative legacy Iron Age correction still ran — its evidence check saw no valid Eldergrove array and rewrote `era_id` — so the migrated copy was already altered when the payload was rejected. `migrate_payload` now gates the whole progression migration section (era inference, Iron Age correction, vessel/Stone Age backfills, canonicalization) on an explicit `Dictionary.has("progression_facts")` presence check: a genuinely absent field keeps the valid legacy migration path; a present valid array keeps normal migration and canonicalization; a present-but-malformed value leaves the payload's progression data completely untouched (`era_id` unchanged, no backfills, no sorting, value never replaced or deleted) and is rejected wholesale by strict validation. The deep-copy behavior is preserved, the caller's input dictionary is never modified, and no live gameplay state changes on the rejection path. Save schema stays version 2.

### Key Changes
- **`scripts/save/SaveManager.gd`:** `migrate_payload` skips the entire progression migration section when `progression_facts` is explicitly present but not a valid fact array (`Dictionary.has()` guard plus `ProgressionState.is_valid_fact_array()`), leaving `era_id` and the malformed value untouched for `validate_payload` to reject. No other migration, gameplay, or schema behavior changed.
- **`tests/test_progression_phase2_era_correction.gd`:** new suite "Phase 2.2 Malformed Facts Migration Isolation" (29 checks) proving the required cases A-G: explicit null on a legacy `iron_age` + Stage 3 save keeps `era_id` and the explicit null untouched, is rejected, leaves the input dictionary unchanged, and fails the real file-load pipeline; malformed string and dictionary values with Iron Age + Stage 3 evidence are rejected untouched; unknown and duplicate fact IDs receive no era correction, backfill, deduplication, or sorting and are rejected; the absent-field legacy path (era correction + vessel + stone backfills) and the valid-array path (Eldergrove evidence retains Iron Age, deterministic sorting) keep their existing behavior; migration stays deterministic and idempotent for all three paths; rejected malformed values never partially mutate live progression state. Every case checks both the migrated copy and the original input dictionary. The existing mixed-case assertion (invalid array containing `eldergrove_reached`) was updated from "era is still downgraded" to the new contract "era stays untouched" — the payload is still rejected wholesale. Verified the new checks fail against the pre-fix implementation. Suite count 7 -> 8, checks 133 -> 162.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 12 now documents the three-case distinction (missing field = valid legacy migration; present valid array = normal migration and canonicalization; present malformed value = progression migration skipped, strict validation rejects) and the updated suite counts.

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
