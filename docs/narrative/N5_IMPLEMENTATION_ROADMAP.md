# Crownfall — N5 Chapter I Implementation Roadmap

**Status (updated 2026-11-20):** N5.0 and N5.1 are IMPLEMENTED & MERGED on `main` @ `90058ec47eeeef3a957f9c023446ab5ea5c32c4f`; N5.2 (`ch1_03_first_night`, with `ch1_04_after_dawn` folded in per `D-N5-02` Option A) is IMPLEMENTED on `feature/n52-first-night-resolution` (unmerged; see [`N52_IMPLEMENTATION_REPORT.md`](N52_IMPLEMENTATION_REPORT.md)). N5.3–N5.5 remain pending; `D-N5-05` remains OPEN/deferred.
**Base `main` SHA audited:** `90058ec47eeeef3a957f9c023446ab5ea5c32c4f` (2026-11-20)
**Owner decisions docket:** [`N5_OWNER_DECISIONS.md`](N5_OWNER_DECISIONS.md)
**Candidate beat sheet (DRAFT / NON-CANON):** [`../CHAPTER_01_BEAT_SHEET.md`](../CHAPTER_01_BEAT_SHEET.md)

---

## 1. Source-Audited Chapter I Gameplay Anchor Matrix (CP1)

All anchors below were verified directly against `scripts/world/ForgottenShoreSession.gd`, `ProgressionState.gd`, `TimeManager.gd`, `NightEncounterManager.gd`, `SpecialistDomain.gd`, `ResearchManager.gd`, `BuildingManager.gd`, and `data/specialists.json`.

| Beat ID | Gameplay anchor | Trigger | Authoritative owner | Idempotency | Save/load behavior | Player control | Recovery | Smallest missing integration | Risk |
|---|---|---|---|---|---|---|---|---|---|
| `ch1_01_arrival` | `PrologueShell` (`pl_09`) → `PrologueHandoffBridge` → `ForgottenShoreSession._ready()` | Fresh session init (`is_session_initialized() == true`, `was_loaded_from_save_on_start() == false`) | `PrologueHandoffBridge` + `ForgottenShoreSession` | One-shot token consumed on ack | Suppressed on Continue (`_loaded_from_save_on_start == true`) | Normal after `pl_09` handoff | Unload/cancel invalidates token | None (already covered by N4.5-C) | Duplicate intro if added again |
| `ch1_02_foothold` | `BuildingManager.wall_state_changed`, `WALL_ID = "wall_east_01"`, `NPCPopulationManager` | Pending `D-N5-01` (rec: `wall_east_01` reaches `STANDING`) | `BuildingManager` | In-session `NarrativeState` + existing wall state check | Silent on Continue when wall already standing / `day_count > 1` | Normal or brief `DialoguePanel` lock | Wall damaged/rebuilt does not re-fire | Narrow N5.0 observer in `ForgottenShoreSession` | Firing on load if not gated by `_is_restoring_save` |
| `ch1_03_first_night` | `TimeManager` (`sunset_started`/`night_started`/`sunrise_reached`), `NightEncounterManager.night_encounter_resolved(survived, wall_held)` | Day 1 night resolution (`completed_day == 1` sunrise) | `TimeManager` + `NightEncounterManager` | Checked once per Day 1 resolution; `NarrativeState.mark_completed()` | Silent on Continue when `day_count >= 2` | Unchanged during combat; brief non-blocking/skippable resolution | Both `survived=true` and `BREACH_PENALTY` advance (no soft-lock) | Connect `night_encounter_resolved` in N5.0 observer | Soft-lock or duplicate state machine if copied |
| `ch1_04_after_dawn` | `ForgottenShoreSession._on_sunrise_reached()` & `_on_night_resolved()` (`ReignState.ACTIVE` / `BREACH_PENALTY`) | Day 1 sunrise outcome (pending `D-N5-02`: fold into `ch1_03` vs separate `daylight_started(2)`) | `ForgottenShoreSession` | Single firing on Day 1 dawn | Silent on Continue when `day_count >= 2` | Normal (must not trap player after breach) | Autosave already runs on sunrise; reload resumes Day 2 | None if folded into `ch1_03` (`D-N5-02` Option A) | Duplicate HUD banner + dialogue fatigue |
| `ch1_05_scientist` | `SpecialistDomain` (`specialist_discovered`/`specialist_recruited`), `ProgressionState` (`FACT_SCIENTIST_DISCOVERED`/`RECRUITED`), `world_x = -1010.0`, `hut_scientist_01` | `specialist_discovered("scientist")` / `specialist_recruited("scientist")` | `SpecialistDomain` + `ProgressionState` | `ProgressionState.record_fact()` is idempotent | Silent on Continue when facts already present | Normal / brief skippable line | Optional — leaving without Scientist stays valid | Narrow listener on `SpecialistDomain` signals | Accidentally gating ship repair on Scientist |
| `ch1_06_research` | `ResearchManager` (`research_started`/`research_completed`), gated by `FACT_SCIENTIST_RECRUITED` | First `research_started` / `research_completed` | `ResearchManager` | `ResearchManager.is_completed()` + `NarrativeState` | Silent on Continue when `get_completed_tech_ids().size() > 0` | Normal | Optional — never blocks ship repair/departure | Narrow listener on `ResearchManager` signals | Creating hidden research requirement for ship |
| `ch1_07_prepare_vessel` | `ForgottenShoreSession._on_player_interact_shipwreck()` (`SHIPWRECK_X = -1350`, `shipwreck_stage` 0→3), `ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY` | `ProgressionState.fact_recorded(FACT_FORGOTTEN_SHORE_VESSEL_READY)` | `ForgottenShoreSession` + `ProgressionState` | `record_fact` idempotent at `shipwreck_stage >= 3` | Silent on Continue when `has_fact(FACT_FORGOTTEN_SHORE_VESSEL_READY)` | Normal | Readiness != departure != Chapter I end | Listen to `progression.fact_recorded` for vessel-ready fact | Treating vessel readiness as Chapter I completion |
| `ch1_08_departure` | `ForgottenShoreSession._on_player_interact_shipwreck()` (`shipwreck_stage >= 3` → `ReignState.ISLAND_CLEARED`), `ProgressionState.FACT_ELDERGROVE_REACHED` | Set Sail → voyage → Eldergrove arrival & control handoff | `ForgottenShoreSession` + future Eldergrove handoff | One-shot handoff token (mirroring N4.5-C) | Must not record `FACT_ELDERGROVE_REACHED` before arrival init | Locked during voyage, restored on Eldergrove arrival | Failed load/cancel leaves Forgotten Shore save intact | Dedicated voyage + Eldergrove arrival slice (N5.5) | Recording Chapter I complete at Set Sail instead of arrival |

---

## 2. Beat-by-Beat Readiness Classification (CP2)

| Beat ID | Candidate Name | Classification | Notes |
|---|---|---|---|
| `ch1_01_arrival` | The Stranded | **ALREADY COVERED BY EXISTING GAMEPLAY** | N4.5-C `pl_09` + two-stage handoff already returns control on Forgotten Shore. |
| `ch1_02_foothold` | A Place to Survive | **NEEDS OWNER DECISION** | Blocked on `D-N5-01` (exact early-game trigger) and `D-N5-03` (text scope). |
| `ch1_03_first_night` | The First Night | **READY FOR IMPLEMENTATION** | Authoritative `NightEncounterManager.night_encounter_resolved` supports both defense & breach recovery. |
| `ch1_04_after_dawn` | After the Night | **FOLDED INTO N5.2** | `D-N5-02` Option A approved (2026-11-20): folded into `ch1_03_first_night` Day 1 sunrise resolution; no separate `daylight_started(2)` trigger. |
| `ch1_05_scientist` | A Different Kind of Knowledge | **OPTIONAL / NON-BLOCKING** | Anchored on `SpecialistDomain` signals & `ProgressionState` facts; never required to finish Chapter I. |
| `ch1_06_research` | Signs of the Past | **OPTIONAL / NON-BLOCKING** | Anchored on `ResearchManager`; specialist-gated, never required for ship repair/departure. |
| `ch1_07_prepare_vessel` | The Way Forward | **READY FOR IMPLEMENTATION** | Anchored on `FACT_FORGOTTEN_SHORE_VESSEL_READY`; distinct from Set Sail and Chapter I end. |
| `ch1_08_departure` | Beyond the Shore | **SEPARATE FUTURE SLICE** | Requires Eldergrove arrival scene & two-stage handoff (`D-N5-05`, Slice N5.5). |

---

## 3. Small-PR N5 Implementation Slices (CP4)

Every slice below is independently reviewable, preserves `SaveManager` schema v2, avoids generic quest/event frameworks, and forbids firing narrative beats during silent save restoration.

### Slice N5.0 — Chapter I Narrative Integration Boundary (**IMPLEMENTED & MERGED** on `main` @ `ba2deb2`, see [`N50_IMPLEMENTATION_REPORT.md`](N50_IMPLEMENTATION_REPORT.md))
- **Objective:** Add a narrow, session-owned narrative observer (`scripts/narrative/ChapterOneNarrativeAdapter.gd`, instantiated by `ForgottenShoreSession`) wired to existing `DialoguePanel` + `NarrativeState` with a strict `restore_silent` guard during `load_game_state()`.
- **Files likely to change:** new `scripts/narrative/ChapterOneNarrativeAdapter.gd`, minimal hook in `scripts/world/ForgottenShoreSession.gd`, new `tests/test_n50_chapter1_boundary.gd`, `tests/run_all.sh`, `.github/workflows/godot-ci.yml`.
- **Authoritative state/signal:** `ForgottenShoreSession._is_restoring_save` (or `load_game_state` guard), `NarrativeState`.
- **Tests:** Adapter attaches cleanly, suppresses all triggers during Continue/reload, releases `PlayerControlLock` on teardown/unload, zero SaveManager schema changes, real user files byte-exact.
- **Out of scope:** Authored story beats, quest journal, event bus, save schema changes.
- **Dependencies:** `D-N5-04` (recommended default Option A).

### Slice N5.1 — First Foothold Milestone (`ch1_02_foothold`) — **IMPLEMENTED & MERGED** on `main` @ `90058ec` (see [`N51_IMPLEMENTATION_REPORT.md`](N51_IMPLEMENTATION_REPORT.md))
- **Objective:** Trigger one short, skippable foothold beat when the approved early-game milestone completes.
- **Files likely to change:** `scripts/narrative/ChapterOneNarrativeAdapter.gd`, `scripts/narrative/ChapterOneBeats.gd` (data-only), `tests/test_n51_foothold_beat.gd`, runner/CI.
- **Authoritative state/signal:** `BuildingManager.wall_state_changed` (if `D-N5-01` Option A approved).
- **Save/load & recovery:** Suppressed on Continue if `building_mgr.is_standing(WALL_ID)` or `day_count > 1`; wall destruction/rebuild never re-triggers.
- **Dependencies:** N5.0 + owner approval of `D-N5-01` and `D-N5-03`.

### Slice N5.2 — Mandatory First-Night Resolution (`ch1_03_first_night`; `ch1_04_after_dawn` folded in per `D-N5-02` Option A) — **IMPLEMENTED** on `feature/n52-first-night-resolution` (unmerged; see [`N52_IMPLEMENTATION_REPORT.md`](N52_IMPLEMENTATION_REPORT.md))
- **Objective:** Trigger exactly-once first-night resolution after Day 1 night ends, supporting both defense success (`survived=true`) and breach recovery (`ReignState.BREACH_PENALTY`) without soft-locking.
- **Files likely to change:** `ChapterOneNarrativeAdapter.gd`, `ChapterOneBeats.gd`, `tests/test_n52_first_night_narrative.gd`, runner/CI.
- **Authoritative state/signal:** `NightEncounterManager.night_encounter_resolved(survived, wall_held)` + `TimeManager.sunrise_reached(completed_day)`.
- **Save/load & recovery:** Suppressed on Continue when `day_count >= 2`; sunrise autosave & breach recovery remain untouched.
- **Dependencies:** N5.0 + owner approval of `D-N5-02`.

### Slice N5.3 — Optional Scientist & Research Integration (`ch1_05_scientist`, `ch1_06_research`)
- **Objective:** Wire optional discovery/recruitment (`SpecialistDomain`) and first-research (`ResearchManager`) beats without gating ship repair or inventing Scientist/Relic/Shrine lore.
- **Files likely to change:** `ChapterOneNarrativeAdapter.gd`, `ChapterOneBeats.gd`, `tests/test_n53_scientist_research_narrative.gd`, runner/CI.
- **Authoritative state/signal:** `SpecialistDomain.specialist_discovered`, `SpecialistDomain.specialist_recruited`, `ResearchManager.research_started`/`research_completed`, `ProgressionState` facts.
- **Tests:** Verify departure remains reachable with Scientist undiscovered/unrecruited and zero research completed; verify research remains gated behind `FACT_SCIENTIST_RECRUITED`.
- **Dependencies:** N5.0.

### Slice N5.4 — Vessel Readiness & Departure Setup (`ch1_07_prepare_vessel`)
- **Objective:** Acknowledge vessel readiness when `shipwreck_stage == 3` records `FACT_FORGOTTEN_SHORE_VESSEL_READY`, keeping readiness distinct from Set Sail and Chapter I completion.
- **Files likely to change:** `ChapterOneNarrativeAdapter.gd`, `ChapterOneBeats.gd`, `tests/test_n54_vessel_readiness_narrative.gd`, runner/CI.
- **Authoritative state/signal:** `ProgressionState.fact_recorded` (`FACT_FORGOTTEN_SHORE_VESSEL_READY`).
- **Save/load & recovery:** Suppressed on Continue when fact already exists; `FACT_ELDERGROVE_REACHED` remains false.
- **Dependencies:** N5.0.

### Slice N5.5 — Voyage & Eldergrove Forest Arrival (`ch1_08_departure`)
- **Objective:** Replace the current Set Sail victory-banner dead end with a distinct departure → voyage → Eldergrove Forest arrival handoff that records `FACT_ELDERGROVE_REACHED` and completes Chapter I **only** after the Eldergrove scene initializes and returns control.
- **Files likely to change:** `ForgottenShoreSession.gd`, narrow Eldergrove handoff bridge/scene, `tests/test_n55_eldergrove_handoff.gd`, runner/CI.
- **Save/load & recovery:** Failed transition or cancellation leaves Forgotten Shore save intact and never records `FACT_ELDERGROVE_REACHED`.
- **Dependencies:** N5.4 + owner approval of `D-N5-05`.
