# CROWNFALL — NARRATIVE IMPLEMENTATION ROADMAP

**Status:** Planning + minimal foundation — Prologue content and Chapter I narrative are NOT implemented. Phases N1–N3 exist only as a tested, test-fixture-based runtime foundation (see §3).  
**Baseline inspected:** `main` at `6d209970170a9f1fa21946385c79ad02d5fb437d` (2026-11-16, after PR #10 merge).  
**Story design:** [Prologue Story Design](narrative/PROLOGUE_STORY_DESIGN.md)

> This roadmap defines implementation order and technical boundaries. The Prologue Story Design defines story beats. Neither document authorizes the coding agent to invent unresolved lore or change gameplay rules outside approved scope.

## 1. Goals

Introduce a focused narrative experience that leads into the existing Forgotten Shore gameplay while keeping the current vertical slice stable.

The first narrative delivery target is:
1. A short Prologue — **The Crown's Call**.
2. A reliable transition into the existing **Chapter I — Forgotten Shore**.
3. A safe New Game / Continue flow that does not force existing saves to replay the Prologue.
4. A small reusable foundation for dialogue and scripted sequences, limited to what the Prologue and the next approved narrative beats need.

This is not a plan to implement all chapters, a branching RPG dialogue framework, or a full quest-journal system.

## 2. Source-of-truth documents

| Document | Owns |
|---|---|
| [Prologue Story Design](narrative/PROLOGUE_STORY_DESIGN.md) | Prologue beats, character direction, candidate dialogue, visual intent, lore boundaries |
| [Narrative Implementation Roadmap](NARRATIVE_IMPLEMENTATION_ROADMAP.md) | Technical sequence, dependencies, acceptance gates, testing, scope |
| [GDD](GDD.md) | High-level player experience, game pillars, world and chapter direction |
| [Revised Project Baseline](REVISED_PROJECT_BASELINE.md) | Cross-project scope and architecture constraints |
| [TDD](TDD.md) and [SYSTEMS](SYSTEMS.md) | Technical conventions and gameplay ownership |
| [Narrative Implementation Audit](NARRATIVE_IMPLEMENTATION_AUDIT.md) | Source-audited implementation/readiness evidence |
| [Chapter I Narrative Gap Analysis](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md) | Chapter I beats, implemented vs missing, Prologue/Chapter I boundary |
| [Narrative Runtime Technical Design](narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md) | N1–N3 runtime architecture decisions + N0 production contract |
| [Prologue Production Breakdown](narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md) | N4 readiness inventory (scenes, assets, audio, test criteria) |

If a story detail is marked OPEN, preserve that uncertainty. If a technical decision is not covered, inspect the current implementation and propose options before changing architecture.

## 3. Verified baseline

This is a static source inspection of `main` at the baseline SHA above. It is not a claim that narrative behavior was runtime-tested.

### Current entry flow
- `scenes/main/Main.tscn` provides Start New Game, Continue Saved Reign, and Exit Game.
- `scripts/core/Main.gd` currently routes both Start New Game and Continue directly to `scenes/world/ForgottenShore.tscn`.
- Start New Game sets `crownfall_load_on_start = false`; Continue sets it to `true`.
- `ForgottenShoreSession` consumes the pending-load flag and owns the active world/save orchestration.

### Existing persistence
- `SaveManager` uses schema version 2 and validates the kingdom/world payload.
- The world session saves resources, buildings, NPCs, night state, research, and progression flags/facts.
- The inspected save contract has no narrative chapter, sequence, or dialogue state.
- Existing saves must continue to load. Any new narrative persistence requires an explicit compatibility and migration decision.

### Existing presentation and tests
- The merged presentation split includes `ShoreView` and `ShoreFX`; these are world presentation helpers, not a narrative or cutscene runtime.
- The merged gameplay harness covers new game, movement, resource collection, building, wall upgrade, Scientist, research, shrine, buff, and save/load scenarios.
- **Narrative runtime foundation (implemented on `feat/narrative-runtime-foundation`):** phases N1–N3 below are shipped as a minimal, test-fixture-only foundation — `NarrativeState` (in-memory), `NarrativeData` (validator), `DialoguePanel` + `PlayerControlLock`, `SequenceRunner`, the `dialogue_advance` input action, and a Start New Game overwrite confirmation. No Prologue content, no canon dialogue, no save-schema change.
- The inspected source tree previously contained no dedicated narrative state, dialogue, quest, chapter, or cutscene runtime; the foundation above is the only narrative runtime that now exists.

**Implication:** A dialogue panel, sequence runner, and in-memory state now exist as a foundation, but no narrative save object, cutscene controller, or Prologue scene exists. Reinspect latest `main` before each implementation phase.

## 4. Prologue scope

The beats are specified in [Prologue Story Design](narrative/PROLOGUE_STORY_DESIGN.md):

1. The Lost World — Aetherion, The First Light, and the Great Eclipse.
2. A Faint Resonance — one small, uncontrolled childhood manifestation.
3. The Wanderer — adult Monarch searches for an explanation.
4. The Repeated Mark — the same unresolved symbol appears on ancient remains.
5. The Forgotten Ruins — clues lead to a hidden chamber and altar.
6. The Crown's Call — the crown awakens inherited power and triggers a fragmented vision.
7. The Unfinished Journey — Monarch continues the search by sea.
8. The Shipwreck — a storm wrecks the ship; any connection to the crown remains unknown.
9. Forgotten Shore — Monarch wakes on the island with the crown still with him.

### Explicitly out of scope
- Controllable ship, naval combat, or sailing simulation.
- Complex dynamic weather built only for the shipwreck.
- Revealing the dynasty, ancestor, ancient kingdom name, crown origin, power source, or the cause of the Great Eclipse.
- Defining the origins or purpose of Greedlings, Greed Portal, Forgotten Shrine, or Ancient Relic.
- Complete Chapter I story, later chapters, branching narrative, or a large quest journal.

## 5. Implementation phases

Each phase should be a small, independently reviewable PR. Do not combine all phases into one large implementation.

### N0 — Narrative design lock and project alignment

**Documentation/design only. No gameplay code.**

Tasks:
- Review and approve the Prologue beats and candidate text.
- Finalize only production details needed to build it: visual design of the repeated symbol, staging of the childhood manifestation, visual language of the vision, and minimum ship-to-island transition.
- Keep unnecessary lore explanations OPEN.
- Decide New Game / Continue / legacy-save behavior (section 6).
- Keep GDD and ROADMAP explicit that the Prologue is planned but not implemented.

**Exit criteria:** Story beats, boundaries, entry-flow policy, and first playable scope are documented. No unresolved lore is silently converted into canon.

### N1 — Minimal narrative state and event foundation

**Status: implemented (foundation only).** In-memory `NarrativeState` (per-run completion, idempotent), `NarrativeData` fail-closed validator/loader, non-canon fixture + 39-check suite. **No persistence, no schema change** (technical design D1/D2).

**Technical foundation only. No Prologue scenes or dialogue UI in this phase.**

Tasks:
- Inspect latest menu/session/save ownership before designing APIs.
- Define stable IDs and a strictly validated representation for the narrative events/sequences actually needed.
- Introduce the smallest suitable narrative-state owner only if persistence is required by the approved player experience.
- Event recording must be idempotent and deterministic. Loading a save must not replay completed one-time events or fire triggers merely because a scene was restored.
- Keep narrative facts distinct from gameplay progression facts. `ProgressionState` owns durable gameplay milestones/unlocks. Do not duplicate the same fact in two stores; use an explicit bridge only when a story event must unlock gameplay.
- Use allowlisted data and typed operations. Do not execute arbitrary expressions or embedded scripts from narrative data.
- Test valid/invalid definitions, duplicate IDs, unknown references, once-only events, restoration, and failed-load atomicity where applicable.

**Save decision required before coding:** compare (1) a non-resumable linear Prologue with no in-progress save, and (2) a versioned, validated narrative save object with deterministic migration. Inspect full `SaveManager` validation/migration behavior first. Do not add a field or bump schema merely for convenience.

**Exit criteria:** Ownership, stable IDs, validation, deterministic behavior, tests, and save compatibility are documented. No dialogue UI or story scene is bundled here.

### N2 — Dialogue presentation

**Status: implemented (foundation only).** `DialoguePanel` (separate CanvasLayer, speaker/body/advance, consumes input while open), `PlayerControlLock`, `dialogue_advance` action, Start New Game overwrite confirmation; 19-check suite. No portraits/choices/voice/history.

Tasks:
- Add a reusable, minimal dialogue view for speaker and line text.
- Support advancing and closing lines deterministically.
- Ensure dialogue input cannot accidentally trigger movement, construction, recruitment, or world commands.
- Keep text/data separate from presentation where practical.
- Use short Prologue lines. Do not build branching choices until a real approved requirement needs them.
- Define text overflow, minimum resolution, pause, and accessibility behavior.

**Exit criteria:** Dialogue can show, advance, and close without mutating gameplay state or leaking input into the world.

### N3 — Minimal scripted sequence runner

**Status: implemented (foundation only).** `SequenceRunner` with typed allowlisted steps, frame-counted waits, injected cue/transition callables, exactly-once completion, skip/cancel/cleanup; 31-check suite. `camera_focus`/`pause_world` ops remain PROPOSED.

Tasks:
- Support only typed operations needed by the Prologue: show/hide dialogue, play an animation/effect, change camera framing, wait for a bounded duration/event, lock/unlock player control, and transition to an approved scene/state.
- Provide explicit cleanup paths so control is always restored.
- Define skip behavior if skip is approved; required handoff/completion actions must execute exactly once.
- Ensure pause, exit, and scene changes cannot leave input locked or duplicate events.
- Do not build a general-purpose cinematic editor or arbitrary scripting language.

**Exit criteria:** A small sequence runs, interrupts/skips according to policy, cleans up reliably, and passes headless plus windowed tests.

### N4 — Prologue content integration

Recommended independent sub-steps:
1. Opening and childhood resonance.
2. Adult wanderer and repeated-symbol exploration.
3. Hidden ruins, altar interaction, crown event, and fragmented vision.
4. Voyage transition and shipwreck cinematic.
5. Forgotten Shore landing and handoff to the existing gameplay scene.

Tasks:
- Add only scenes, props, and effects required by the approved beat sheet.
- Treat the crown as a narrative artifact/visual continuity element; do not invent an inventory system for it.
- Route Start New Game through the Prologue according to the approved policy.
- Keep Continue safe for existing saves.
- Keep `ForgottenShoreSession` authoritative for economy, NPCs, construction, survival, progression, and world saves.
- Return player control promptly after landing.

**Exit criteria:** A fresh run completes the Prologue and reaches Forgotten Shore; existing saves continue correctly; the gameplay regression suite remains green; the Prologue has been inspected in a windowed run.

### N5 — Chapter I narrative beats

This is a separate content milestone, not part of Prologue completion.

Tasks:
- Write and approve a Chapter I beat sheet before implementing dialogue or quests.
- Integrate story beats with existing survival, settlement, Scientist, research, shipwreck, and exploration gameplay where appropriate.
- Keep the current island mechanics stable unless a separate design change is approved.
- Do not conflate the existing Forgotten Shrine with the Shrine of Growth; preserve their separate identities until an explicit lore decision is made.

**Exit criteria:** Chapter I has an approved beat sheet and separately scoped implementation tasks.

## 6. New Game, Continue, and save compatibility

The current menu sends both Start New Game and Continue directly to Forgotten Shore. Adding the Prologue changes that entry flow and requires an explicit policy.

### Recommended initial policy — approval required
- **Start New Game:** start the Prologue, then create/enter a fresh Forgotten Shore session after landing.
- **Continue:** bypass the Prologue and load the existing Forgotten Shore save, including legacy saves with no narrative metadata.
- **Legacy save:** missing narrative metadata must never force an existing player to replay the Prologue or invalidate the save.
- **Prologue interruption:** for the first linear version, prefer no in-progress world save/resume during the Prologue. Exiting mid-Prologue restarts it on the next Start New Game. Confirm this UX before implementation.
- **After landing:** let the existing world session and SaveManager own the kingdom save. Do not create a parallel save system.
- **Skip:** if offered, skipping follows the same handoff to a fresh Forgotten Shore session; it must not load or overwrite an unrelated old save accidentally.

This is a recommendation, not an approved implementation contract until the project owner confirms it. If resumable Prologue playback is required, design and test the save representation first.

## 7. Ownership boundaries

- **Main/menu:** chooses whether to start a Prologue or continue a world save; it does not own dialogue or gameplay rules.
- **Narrative domain:** owns story event completion and required narrative checkpoints, not economy, building, era, or research.
- **Dialogue/sequence presentation:** displays content and coordinates input/camera/animation; it cannot directly grant resources or unlock gameplay.
- **ForgottenShoreSession:** remains the active Forgotten Shore world orchestrator. Narrative handoff should use a narrow entry contract.
- **ProgressionState / ProgressionUnlockEvaluator:** remain the authority for gameplay milestones and unlock requirements.
- **SaveManager:** remains the single authority for world-save validation, migration, rollback, and persistence.
- **ShoreView / ShoreFX:** remain world presentation helpers, not narrative controllers.

## 8. Quality gates

### Automated/headless
- Existing `bash tests/run_all.sh` remains green.
- New Game routing starts the Prologue according to policy.
- Continue bypasses the Prologue and loads a valid old save.
- Prologue completion/skip transfers control exactly once to a fresh Forgotten Shore session.
- Invalid narrative definitions fail closed without partial state mutation.
- One-time events do not duplicate after restore, repeated triggers, skip, or scene re-entry.
- Dialogue/cinematic input does not leak into player/world commands.
- Existing v1/v2 save compatibility remains intact; any approved new persistence has migration tests.
- Existing gameplay scenarios, including save/load, remain green.

### Windowed/manual
- Test at the supported resolution and at least one smaller window size.
- Inspect text readability, camera framing, transitions, and control handoff.
- Inspect childhood resonance, crown interaction, fragmented vision, storm, shipwreck, and crown continuity.
- Confirm the player regains control on Forgotten Shore.
- Capture and inspect screenshots. Headless tests alone do not prove visual correctness.

### PR discipline
- One logical narrative milestone per PR.
- Branch from verified latest `main`.
- List files to be changed and inspect ownership before coding.
- Keep unrelated gameplay/presentation refactors out of narrative PRs.
- No save-schema, lore, balance, or scene-flow change without rationale and tests.
- Keep planned work in this roadmap; update CHANGELOG only after verified implementation.

## 9. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Prologue breaks Continue or legacy saves | Keep Continue path direct and test old saves |
| Dialogue input triggers gameplay commands | Explicit input ownership and non-leakage tests |
| Interrupted sequence leaves controls locked | Single cleanup path; test pause/exit/skip/scene change |
| Agent invents lore | Explicit OPEN markers and fail-closed review |
| Framework grows before story is playable | Build only typed operations the Prologue needs |
| Prologue delays the game loop | Keep it short and return control promptly |
| Narrative and progression facts are duplicated | One source of truth and explicit bridge only |

## 10. First task for the coding agent

**Do not implement the Prologue yet.** Phases N1–N3 are implemented on `feat/narrative-runtime-foundation` (foundation only). The next tasks, in order:

1. Get owner approval for the N0 design-lock items and the New Game/Continue entry-flow policy (section 6).
2. On approval, prepare the N4 content proposal from `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md` (scene shells, placeholder assets, beat-by-beat tasks).
3. Do not edit code until the N0 approvals and the N4 proposal are reviewed.

The objective is a small, testable story foundation, not a speculative narrative framework.

## 11. Audit-aligned technical findings (PR #10 synchronization)

Source audit of `main` @ `b19d109` (see [`NARRATIVE_IMPLEMENTATION_AUDIT.md`](NARRATIVE_IMPLEMENTATION_AUDIT.md) and [`CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md`](CHAPTER_01_NARRATIVE_GAP_ANALYSIS.md)). These findings feed Phase N1 and do not change the N0–N5 phase structure.

### Confirmed absences (re-verified on latest main)
- No dialogue runtime, no scripted-sequence/cutscene runner, no chapter progression runtime, no narrative save fields. `SaveManager` remains schema v2 (`scripts/save/SaveManager.gd:8-9`).
- Save/load anchors: `build_save_payload` `scripts/world/ForgottenShoreSession.gd:1099`, `_apply_loaded_payload` `:1181`, `_consume_pending_load_if_requested` `:1252`.

### TimeManager signal semantics (corrected)
`daylight_started`, `sunset_started`, `night_started`, and `sunrise_reached` are **transition-time events, not per-frame ticks**: `_transition_to_next_phase` (`scripts/world/TimeManager.gd:137`) emits once per phase change, `_emit_initial_phase_if_needed` (`:130`) emits the initial daylight once, and `apply_save_dict` (`:99`) re-emits only on a non-silent restore (the session load path restores silently). Duplicate/trigger risk comes from connecting the same handler more than once and from triggers reacting during save-restore — use `is_connected` guards and idempotent, load-silent narrative events (N1).

### Presentation ownership
`ShoreView`/`ShoreFX` are merged (PR #8) and remain world presentation helpers, not narrative controllers (`ForgottenShoreSession.gd:86-87,148`). A dialogue/sequence presenter should follow the same separation.

### UI and data constraints
- `ClockHUD.FeedbackLabel` is a single overwritten line (`scripts/ui/ClockHUD.gd:11,125`); dialogue needs its own surface (N2).
- Specialist/structure/technology/era `description` fields are validated but never displayed; do not treat them as live dialogue.

### Lore identity items that stay unresolved
- “Forgotten Shrine” (x=-780 cache/offering) vs “Shrine of Growth” (x=820 structure): keep separate until an explicit lore decision (N5).
- “Ancient Relic” (Greed Portal loot) artifact-vs-cache: OPEN.
- Greedlings / Greed Portal origins and purpose: out of scope until approved (§4).

### Documentation drift to reconcile before authoring narrative text
- Node count wording (`DECISIONS_M2_M8.md:17`, `PRD.md:335` vs 5 shipped nodes in `data/resource_nodes.json`).
- East wall position (`x=360` in docs vs `380.0` in `data/buildings.json`/`BuildingManager`).
- Watchtower position (`x=290` in `docs/GDD.md:134` vs `210.0` in data/code).
- Save schema (`schema_version: 1` in `DECISIONS_M2_M8.md:25`/`PRD.md:342` vs v2 in `SaveManager.gd:9`).
- GDD first-slice NPC/enemy scope table is stale vs shipped Farmer/Archer and Crawler/Brute/West Scouts.

---

**END OF DOCUMENT**
