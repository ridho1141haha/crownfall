# CROWNFALL — NARRATIVE IMPLEMENTATION ROADMAP

**Status (updated 2026-11-17):** N1–N3, N4.0, N4.1, and N4.2 are implemented and merged. N4.2 delivers pl_01 *The Lost World* and pl_02 *A Faint Resonance*, including Prologue shell auto-start/chaining. N4.3–N4.6 remain unimplemented. The Prologue is partially playable, not complete. Chapter I (N5) remains in design planning. Its core progression decisions have been approved; remaining dialogue, transition staging, and lore details remain open.  
**Baseline inspected:** `main` at `539f8564f2417aefc22a1636f885dc45cea1b818` (2026-11-17, after PR #15 / N4.2 merge). This is the source baseline for the N4.3 planning work; the PR branch changes documentation only.  
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
| [N4.3 Planning](narrative/N4_3_PLANNING.md) | Approved planning direction, interactive beat scope, technical boundary, acceptance criteria, and implementation slices for pl_03–pl_04 |

If a story detail is marked OPEN, preserve that uncertainty. If a technical decision is not covered, inspect the current implementation and propose options before changing architecture.

## 3. Verified baseline

This is a static source inspection of `main` at the baseline SHA above. It is not a claim that narrative behavior was runtime-tested.

### Current entry flow
- `scenes/main/Main.tscn` provides Start New Game, Continue Saved Reign, and Exit Game.
- Start New Game keeps the existing overwrite confirmation for a valid world save, then consults the N4.0 player-profile gate: first playthrough routes to the functional Prologue shell (no Skip); after one recorded full-Prologue completion it offers Play Prologue Again / Skip; Skip enters a fresh Forgotten Shore session without touching the profile.
- Start New Game and Skip set `crownfall_load_on_start = false`; Continue sets it to `true` and never reads the profile.
- `ForgottenShoreSession` consumes the pending-load flag and owns the active world/save orchestration.

### Existing persistence
- `SaveManager` uses schema version 2 and validates the kingdom/world payload.
- The world session saves resources, buildings, NPCs, night state, research, and progression flags/facts.
- The inspected save contract has no narrative chapter, sequence, or dialogue state.
- Existing saves must continue to load. Any new narrative persistence requires an explicit compatibility and migration decision.

### Existing presentation and tests
- The merged presentation split includes `ShoreView` and `ShoreFX`; these are world presentation helpers, not a narrative or cutscene runtime.
- The merged gameplay harness covers new game, movement, resource collection, building, wall upgrade, Scientist, research, shrine, buff, and save/load scenarios.
- **Narrative runtime foundation (PR #11, merged as `eb82ae4`):** N1–N3 are implemented on `main`: `NarrativeState` (in-memory), `NarrativeData` validation, `DialoguePanel`, `PlayerControlLock`, `SequenceRunner`, `dialogue_advance`, and the New Game overwrite confirmation. Automated narrative suites and headless CI passed for the merge commit.
- **Entry gate + profile (N4.0):** `PlayerProfile`, the profile gate, the returning-player choice, the Prologue route placeholder, and the N4.0 suite are implemented; full headless suite green (see §5 N4 status).
- The runtime is connected to the first two authored Prologue beats. `PrologueShell` auto-starts and chains pl_01 → pl_02 using `PrologueBeats`; the shell then stops at the N4.2 boundary. The Prologue is only partially playable: pl_03–pl_09, the Forgotten Shore handoff, and full-completion marking are not implemented. There is still no NPC conversation integration, chapter progression system, quest/objective framework, or narrative save state. `SaveManager` remains schema v2.

**Implication:** The technical foundation and opening two Prologue beats are implemented. The next Prologue implementation milestone is N4.3 (pl_03 The Wanderer and pl_04 The Repeated Mark); N4.3 planning is documented separately. N5 design may continue in parallel, but Chapter I implementation must respect the Prologue/Chapter I boundary and approved sequencing.

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
- Finalize only production details needed to build it: visual design of the repeated symbol, staging of the childhood manifestation, visual language of the vision, and minimum ship-to-island transition. Authored dialogue uses English as its default/source language; localization and voice acting are not N4 blockers.
- Keep unnecessary lore explanations OPEN.
- Decide New Game / Continue / legacy-save behavior (section 6).
- Keep GDD and ROADMAP explicit that the Prologue is partially implemented (pl_01–pl_02) but not complete; do not describe it as wholly unimplemented or as a finished experience.

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
- Implement the approved New Game menu gate: first-ever Prologue cannot be skipped; after one successful completion, offer Skip or Play Again. Keep menu-level whole-Prologue Skip distinct from per-sequence `SequenceRunner.skip()`; required handoff actions must execute exactly once.
- Ensure pause, exit, and scene changes cannot leave input locked or duplicate events.
- Do not build a general-purpose cinematic editor or arbitrary scripting language.

**Exit criteria:** A small sequence runs, interrupts/skips according to policy, cleans up reliably, and passes headless plus windowed tests.

### N4 — Prologue content integration

**Status: N4.0–N4.2 implemented and merged (entry/profile gate, functional shell, and first two authored beats).** `scripts/narrative/PlayerProfile.gd` (`user://player_profile.json`, `{"schema_version": 1, "prologue_completed_once": false}`, strict validation, atomic writes, fail-safe "not completed" default), the New Game entry gate with the returning-player Play Prologue Again / Skip choice, and Continue independence are implemented and covered by `tests/test_n40_profile_entry_gate.gd` (101 checks). **N4.1** replaces the inert placeholder with the functional shell at the same route path (`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd`): the shell owns a per-run `NarrativeState` plus a `DialoguePanel` and a `SequenceRunner` configured with an allowlisted sequence scene transition (`res://scenes/world/ForgottenShore.tscn` only, the future N4.5 handoff channel), exposes `play_sequence` / `skip_sequence` / `cancel_sequence` for future beat content, and guards all exits/handoffs behind a single-transition guard (duplicate requests are ignored); exit semantics are split — the development exit cancels a running sequence (completes nothing) while a sequence-driven handoff lets the finishing sequence complete exactly once (`sequence_completed` + `NarrativeState`); a clearly labelled development-only exit button returns to the main menu. Entering, running, or exiting the shell never touches `PlayerProfile` — completion marking stays an N4.5 contract, nothing in the runtime flow sets the completion flag. Covered by `tests/test_n41_prologue_shell.gd` (87 checks). **N4.2** authors the first two story beats in `scripts/narrative/PrologueBeats.gd` (`pl_01_lost_world` "The Lost World" + `pl_02_faint_resonance` "A Faint Resonance" — NarrativeData-validated data only: pl_01 uses the Story Design candidate narration verbatim and never states the Eclipse cause; pl_02 shows exactly one small uncontrolled childhood manifestation, no spellcasting, no power origin, and the crown never appears in either beat) and wires the shell's content lifecycle: the shell auto-plays the first uncompleted beat on route load (Engine meta `crownfall_prologue_autostart` override for headless suites, same injection convention as `crownfall_load_on_start`), chains pl_01 → pl_02 exactly-once via `sequence_completed`, stages cues on a labelled placeholder stage through the existing `play_cue` op (no new runner ops, no art/audio assets), and marks the N4.2 boundary ONLY when next-beat discovery finds no next authored beat after the completed beat — every playback refusal (exit started, busy runner, already-completed beat, invalid data, `play()` rejection) keeps the boundary false and is reported explicitly — no scene transition (the shore handoff stays N4.5), no completion marking, and the development exit remains the only way out. Covered by `tests/test_n42_prologue_beats.gd` (113 checks). The remaining beats pl_03–pl_09 are NOT implemented; N4.3–N4.6 remain not implemented and the Prologue is not yet a complete story experience (its opening two beats now play on New Game).

The N4.0 entry contract for N4.1 is fulfilled: the shell lives at `res://scenes/narrative/PrologueShell.tscn` (route constant unchanged); Main routes to it with `crownfall_load_on_start = false`; routing decisions remain observable headlessly via `Main.set_route_transition(Callable)` and the `crownfall_profile_path` / `crownfall_menu_save_path` Engine metas (shell exits are observable via `PrologueShell.set_exit_transition(Callable)`). N4.5 wires the completion marker (`PlayerProfile.mark_prologue_completed()`, called only after the pl_09 handoff commits) and the fresh-shore handoff.

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

This is a separate content milestone, not part of Prologue completion. Design preparation may proceed before N4 implementation, but Chapter I content implementation follows the Prologue-to-shore handoff contract.

Current planning artifact: [`CHAPTER_01_BEAT_SHEET.md`](CHAPTER_01_BEAT_SHEET.md). Its core progression decisions were approved by the project owner on 2026-11-17: Chapter I ends on arrival at Eldergrove; the first night is mandatory but recoverable; Scientist recruitment is optional, while research and specialist-dependent upgrades require recruitment. Remaining dialogue, transition staging, and lore details are still open.

Tasks:
- Refine the approved Chapter I beat sheet's remaining open details; do not implement candidate dialogue as canon before dialogue/content approval.
- Integrate story beats with existing survival, settlement, Scientist, research, shipwreck, and exploration gameplay where appropriate.
- Keep the mandatory first-night milestone and both recovery outcomes stable. Preserve the optional Scientist path and specialist-dependent research/upgrade gates.
- Keep the Forgotten Shrine and Shrine of Growth distinct until an explicit lore decision; leave Ancient Relic and Greedling/Greed Portal origins unresolved.

**Exit criteria:** Chapter I has an owner-approved beat sheet, agreed chapter boundary/ending, and separately scoped implementation tasks.

## 6. New Game, Continue, and save compatibility

The current menu entry flow is implemented: Start New Game routes through the Prologue gate, while Continue bypasses the Prologue and loads the existing world save.

### Approved policy (owner decision, 2026-11-17)
- **First-ever Start New Game:** always play the Prologue. Do not display a Skip option.
- **Later Start New Game:** if and only if the player profile records one successful full Prologue completion, offer the choice to Skip or Play Prologue again.
- **Continue:** bypass the Prologue and load the existing Forgotten Shore world save, including legacy saves with no narrative metadata.
- **Completion marker:** persist `prologue_completed_once` in a minimal global player profile separate from world saves. Set it only after the complete Prologue reaches its successful completion/handoff path; skipping never sets the flag.
- **Profile safety:** missing, invalid, or unreadable profile data defaults to first-playthrough behavior (Skip locked), without blocking New Game or invalidating world saves.
- **Prologue interruption:** no mid-Prologue save/resume. Exiting mid-Prologue restarts at pl_01 on the next New Game.
- **After landing or eligible skip:** enter a fresh Forgotten Shore session; the existing world session and SaveManager own kingdom progress. Do not load or overwrite an unrelated old save accidentally.

This policy is approved. N4.0 implements the entry routing and fail-safe profile gate; N4.5 is responsible for setting `prologue_completed_once` only after the successful full-Prologue handoff. Until then, the profile flag remains false and returning-player Skip stays locked.

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
- First-ever New Game starts the Prologue and offers no Skip.
- After one successful full Prologue completion, a later New Game offers Skip or Play Again.
- The completion flag survives New Game/world-save replacement and is not set by skipping.
- Missing/corrupt profile data safely locks Skip without blocking New Game.
- Continue bypasses the Prologue and loads a valid old save.
- Prologue completion/eligible skip transfers control exactly once to a fresh Forgotten Shore session.
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

## 10. Next tasks for the coding agent

**No gameplay or narrative runtime code is authorized by this documentation milestone.** N1–N3 and N4.0–N4.2 are already implemented and merged. Next:

1. Review the N4.3 plan in [`narrative/N4_3_PLANNING.md`](narrative/N4_3_PLANNING.md) against the current source contracts before implementation.
2. Start with N4.3-A: a technical spike for the isolated Prologue exploration stage, dedicated Monarch actor, movement bounds, camera, input isolation, and handoff from pl_02. Do not add the repeated-mark interaction until the orchestration works without changing generic `SequenceRunner` / `NarrativeData` semantics.
3. After N4.3-A is independently reviewed, proceed to N4.3-B (three authored inspectables, distinct-object tracking, and pl_04 recognition dialogue), then N4.3-C integration/regression.
4. Keep Chapter I design work separate. Its approved progression decisions and remaining open questions are tracked in [`CHAPTER_01_BEAT_SHEET.md`](CHAPTER_01_BEAT_SHEET.md); Chapter I implementation remains downstream of the Prologue handoff.
5. Keep subsequent code work in separate PRs with tests and windowed inspection.

The objective remains a small, testable story experience, not a speculative narrative framework.

## 11. Audit-aligned technical findings (refreshed after PR #15)

This section reflects the source baseline after N4.2 / PR #15 (`539f8564`). It distinguishes implemented runtime infrastructure, implemented Prologue beats, and remaining narrative content.

### Runtime facts
- N1–N3 are implemented and merged: in-memory `NarrativeState`, `NarrativeData` validation, `DialoguePanel`, `PlayerControlLock`, and `SequenceRunner`.
- `PrologueShell` is the active New Game route and auto-plays the authored pl_01 and pl_02 beats through `PrologueBeats`; it does not yet provide the interactive exploration, inspectable objects, or later Prologue scenes.
- pl_03–pl_09, the pl_09 Forgotten Shore handoff, and successful full-Prologue completion marking remain unimplemented. No NPC conversation integration, quest/objective framework, chapter progression runtime, or narrative save fields exist.
- `SaveManager` remains schema v2. Do not add narrative persistence without a separate design and migration decision.
- `ClockHUD.FeedbackLabel` remains gameplay feedback only; dialogue uses its own panel.

### Existing gameplay constraints
- `ShoreView` / `ShoreFX` remain presentation helpers; `ForgottenShoreSession` remains the world orchestrator.
- `TimeManager` phase signals are transition-time events, not per-frame ticks. Narrative listeners must be connected once, idempotent, and silent during save restoration.
- Chapter I should reuse existing settlement, first-night, Scientist/research, exploration, and ship-repair systems rather than create parallel mechanics. The approved endpoint is arrival at Eldergrove; voyage/arrival content is future implementation.

### Lore boundaries that remain OPEN
- Forgotten Shrine (x=-780) and Shrine of Growth (x=820) remain separate until an explicit lore decision.
- Ancient Relic artifact-vs-cache identity remains OPEN.
- Greedlings and the Greed Portal origins/purpose remain OPEN and must not be invented in Chapter I dialogue.
- Prologue protected mysteries remain protected: crown origin, power source, dynasty/ancestor, ancient kingdom name, and Great Eclipse cause.

### Documentation hygiene
- This roadmap's baseline and companion audit snapshots must be updated whenever source evidence changes. The current baseline is `539f8564` (after PR #15); do not copy the older N4.0/PR #12 baseline (`a34e5b3`) into current-status headers.
- Older first-slice values in other project documents (node counts, wall/watchtower positions, save schema, NPC/enemy scope) are outside this narrative-only PR unless directly needed for a story beat. Verify source data before authoring details.

---

**END OF DOCUMENT**
