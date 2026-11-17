# Crownfall — N4.3 Planning: The Wanderer & The Repeated Mark

**Status:** Owner-approved planning direction; implementation NOT started.  
**Planning baseline:** `main` at `539f8564` (2026-11-17, after PR #15 / N4.2 merge).  
**Story authority:** [Prologue Story Design](PROLOGUE_STORY_DESIGN.md).  
**Production inventory:** [Prologue Production Breakdown](PROLOGUE_PRODUCTION_BREAKDOWN.md).  
**Runtime contract:** [Narrative Runtime Technical Design](NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md).

> This document scopes N4.3 only. It does not authorize new lore, a generic interaction framework, a quest system, or changes to world-save/profile contracts. Any item marked OPEN must remain unresolved until inspected or approved.

---

## 1. Direction

N4.3 uses **an ancient road leading toward the forgotten ruins**.

The player first experiences Monarch as a traveller who has spent time searching for an explanation. The road provides a small, readable exploration space. The recurring mark is then discovered along that route, giving the player a concrete reason to follow the clues toward the larger ruins in pl_05.

This gives the beats distinct jobs:

- **pl_03 — The Wanderer:** establish adult Monarch, his search, and controlled movement/observation.
- **pl_04 — The Repeated Mark:** let the player recognize the same visual mark on separate ancient objects and understand that the appearances are connected.
- **pl_05 — The Forgotten Ruins:** becomes the destination suggested by the clues; it is not part of N4.3 implementation.

The road is a proposed staging choice, not a canon place name or a newly established historical location.

## 2. Player-facing beat outline

### pl_03 — The Wanderer

**Purpose:** introduce adult Monarch through movement and environmental storytelling rather than exposition.

1. Transition from the end of pl_02 to adult Monarch on a quiet, weathered ancient road.
2. Give the player movement control early.
3. Let the player traverse a small bounded area and observe travel-worn details.
4. Use a short internal line, at a calm moment:

   > Some things are difficult to forget.  
   > Especially the things you cannot explain.

5. The road subtly guides the player toward the first marked remnant. Do not use a quest marker or objective HUD.

**Visual/environmental language**
- A narrow old road, worn stone or packed earth, sparse vegetation, weathered remnants.
- Signs that Monarch has travelled before may appear through worn equipment or a small field-note prop; do not add a collectible journal or inventory.
- Keep the area compact. It is an introduction to movement, not a large explorable level.
- Avoid establishing a precise real-world-like region, kingdom, dynasty, or named location.

### pl_04 — The Repeated Mark

**Purpose:** turn environmental observation into a recognizable mystery.

1. Place three distinct ancient objects along or just beside the road.
2. Each object carries the exact same placeholder mark design.
3. The player can inspect each object from a short interaction range.
4. Inspecting two **different** objects is sufficient to establish the pattern.
5. A third object is optional reinforcement; it is not required for completion.
6. Once the second distinct object is inspected, show Monarch's short internal line:

   > I've seen this mark before...  
   > Why does it keep appearing?

7. Complete pl_04 and let the next beat (pl_05, implemented in a later milestone) take over when available.

**Object variety**
- Object A: a standing stone or pillar with the mark clearly visible.
- Object B: a broken stone fragment with the same mark partly weathered.
- Object C: a damaged artifact or wall fragment with the same mark partly obscured.

These are staging suggestions, not fixed canon props. The mark must remain visually identical in shape; only surface condition, scale, and placement may vary.

## 3. Interaction rules

- Movement is limited to the authored road area; the player cannot wander into an unbuilt chapter or leave the stage bounds.
- Use the existing `interact` input action for inspection. It is already defined in `project.godot` and mapped to physical E; do not introduce a second action unless a concrete input conflict is found.
- Show a small contextual prompt only when an inspectable is in range.
- One inspect action inspects the nearest eligible object; do not inspect multiple objects at once.
- An object's inspection is idempotent. Repeating the same object does not increase progress.
- Progress is based on distinct authored object IDs, not number of button presses.
- Two distinct objects complete the required observation.
- The third object is optional and must not block completion.
- No combat, resource collection, NPC dialogue, building, economy, survival loop, quest tracker, journal, inventory, or reward.

## 4. Proposed technical boundary

### Preferred architecture

Use a **dedicated Prologue exploration stage and actor**, isolated from Forgotten Shore gameplay.

Responsibilities:

| Component | Responsibility |
|---|---|
| PrologueShell | Owns Prologue lifecycle, beat routing, dialogue panel, and per-run narrative state |
| PrologueExplorationStage | Owns the small road layout, bounds, inspectable placements, and pl_03/pl_04 exploration completion |
| PrologueExplorer | Owns only movement, animation, and its camera; no kingdom/gameplay commands |
| PrologueInspectables | Small authored set of three mark objects and their proximity/inspection affordance |
| PrologueBeats | Holds narrative text and approved sequence data; no scene orchestration |

The exact scene tree and script boundaries must be confirmed against the current `PrologueShell.tscn`, UI layering, and existing art assets before implementation.

### Reuse policy

- The Monarch sprite sheet already exists at `assets/characters/player/player_monarch_sheet.png`. `scenes/player/Player.tscn` uses it as an 8-frame horizontal `Sprite2D`; `scripts/player/Player.gd` treats frames 0–3 as idle and 4–7 as walking. Verify the rendered appearance and scale in the Prologue stage before deciding whether the asset needs modification.
- `scenes/player/Player.tscn` also provides an existing `CharacterBody2D` + `Camera2D` reference (zoom 1.5, vertical offset, smoothing). Reuse the camera approach selectively; do not instance the full gameplay player scene unchanged.
- Reuse `DialoguePanel`, `SequenceRunner`, `PlayerControlLock`, and `NarrativeState` where their existing contracts fit.
- Do **not** attach `ForgottenShoreSession`, `InteractionResolver`, economy, resource, building, NPC, research, time, or save systems to the Prologue stage.
- Do not use the full gameplay `PlayerController` unchanged if it carries world commands or gameplay input actions. Extract no broad abstraction merely for this slice; a small dedicated actor is preferred.

### Important orchestration issue — must be designed before coding

N4.2 currently chains authored sequences automatically when `SequenceRunner.sequence_completed` fires. pl_03/pl_04 introduce a player-driven interval, so they cannot simply be authored as ordinary short sequences and allowed to auto-chain immediately.

The N4.3 orchestration contract is DECIDED:

1. After pl_02 completes, the shell enters a Prologue-specific exploration state and presents the dedicated actor on the ancient road. This begins pl_03; movement is enabled only after the handoff is ready.
2. pl_03 completes when the actor reaches the authored exploration handoff area. The stage emits one completion request; the shell validates the active beat, records `pl_03` in `NarrativeState` exactly once, and immediately activates pl_04. Reaching the handoff area is the sole normal completion trigger; do not add a timer, quest marker, or extra confirmation dialog.
3. pl_04 becomes active at the same stage. The three inspectables are available along the road. Inspecting two distinct object IDs triggers the recognition line exactly once and completes pl_04. The third object is optional.
4. The stage owns exploration conditions and distinct-object tracking. `PrologueShell` is the sole owner of authoritative `NarrativeState.mark_completed()` calls for pl_03/pl_04. `SequenceRunner` remains responsible for its own authored cinematic/dialogue sequences and must not also record these exploration beats. The pl_04 recognition line is presented directly through the existing `DialoguePanel`, not as a separate `SequenceRunner` sequence; the exploration stage owns a dedicated `PlayerControlLock` instance for this short dialogue and releases it on every completion/cancel/teardown path. This avoids creating a synthetic narrative completion ID for a one-line interaction. All completion requests are validated against the active beat and ignored after the first accepted completion.
5. After pl_04 completes, the current milestone ends in a defined idle/boundary state. Do not fabricate pl_05 or auto-advance into content that has not been implemented.

**Skip and cancellation policy**

- Exploration beats are not active `SequenceRunner` runs, so `SequenceRunner.skip()` is not their skip mechanism.
- Provide a narrow Prologue-specific `skip_current_exploration_beat()` path for the existing/future per-beat Skip affordance; do not add a new global shortcut, generic skip framework, or UI redesign as part of N4.3-A.
- Skipping pl_03 records pl_03 once and starts pl_04 normally. It does not skip pl_04.
- Skipping pl_04 records pl_04 once and ends the N4.3 segment at its defined boundary. It does not start pl_05. If the recognition dialogue is already open, Skip closes the panel and releases the stage-owned actor lock before ending the beat.
- Skip never marks `prologue_completed_once`, changes a world save, or skips the entire Prologue. The full-Prologue menu Skip remains a separate N4.0 returning-player choice.
- Cancel, development exit, scene unload, or failed setup are not Skip: they do not record the active exploration beat as completed. The Prologue remains non-resumable, so a later New Game starts again from pl_01.

**Control-lock contract**

The current `PrologueShell._initialize_runtime()` configures `SequenceRunner` with the shell itself as `control_target`, because N4.1/N4.2 have no gameplay Monarch actor. Before any actor-controlled dialogue, N4.3 must bind the runner/lock path to the dedicated exploration actor (or use an equally narrow, explicitly tested Prologue-specific lock path). A dialogue sequence must actually lock that actor; `DialoguePanel` consuming unhandled input alone does not stop `_physics_process` movement. Exploration input is enabled only in the exploration state and disabled during dialogue, transitions, cancellation, exit, and teardown. Cleanup must restore the actor's original processing state even if the actor is freed or setup fails. Preserve the no-control behavior of pl_01/pl_02.

Do not add generic `wait_for_interaction`, `move_player`, or `inspect_object` operations to `NarrativeData` / `SequenceRunner`. Keep the state machine and completion handshake Prologue-specific.

## 5. Acceptance criteria

### Narrative and progression
- [ ] pl_01 and pl_02 still play in order and retain their current content.
- [ ] Adult Monarch appears after pl_02 in the ancient-road stage.
- [ ] The player receives movement control at the intended point in pl_03.
- [ ] pl_03 completes only when the actor reaches the authored exploration handoff area, or when its explicit per-beat Skip path is invoked.
- [ ] The pl_03 completion request is accepted and recorded exactly once by PrologueShell/NarrativeState before pl_04 becomes active.
- [ ] pl_04 becomes active after pl_03; it does not depend on SequenceRunner auto-chaining an exploration interval.
- [ ] The three inspectables use one consistent placeholder mark.
- [ ] Inspecting the same object repeatedly counts only once.
- [ ] Inspecting two distinct objects triggers the pl_04 recognition line exactly once and requests pl_04 completion.
- [ ] Repeated inspection of one object never satisfies the two-object requirement.
- [ ] The third object is optional.
- [ ] Explicitly skipping pl_04 completes it once without requiring inspections; no pl_05 content is fabricated or pulled into N4.3.
- [ ] Cancel, exit, teardown, or failed setup does not mark pl_03/pl_04 complete.
- [ ] All dialogue uses the existing DialoguePanel and approved candidate lines unless separately approved.

### Controls and presentation
- [ ] Movement is bounded to the small road stage.
- [ ] Camera follows the actor without exposing empty/out-of-bounds space.
- [ ] Interaction prompt appears only within range and identifies only the eligible target.
- [ ] Movement and inspection input are blocked during dialogue.
- [ ] Control is restored after normal dialogue completion.
- [ ] Per-beat Skip follows the pl_03/pl_04 rules above; it is separate from full-Prologue menu Skip.
- [ ] Cancel, exit, teardown, and failed setup leave no stuck input lock or stale prompt and do not complete the active exploration beat.
- [ ] No duplicate completion or duplicate inspection progress occurs.

### Isolation and regression
- [ ] Prologue actor/stage has no dependency on Forgotten Shore gameplay systems.
- [ ] No PlayerProfile, SaveManager, save schema v2, or world-save behavior changes.
- [ ] No new generic quest, inventory, journal, or interaction framework.
- [ ] Existing N4.0, N4.1, N4.2, narrative runtime, and gameplay regression suites pass.
- [ ] Godot import and headless test suite pass.
- [ ] Real user save/profile files remain untouched by tests.

## 6. Out of scope

- The Forgotten Ruins (pl_05), hidden chamber, altar, or crown.
- Final royal-symbol design, name, meaning, dynasty, or historical context.
- New lore about the ancient road or its builders.
- Combat, enemies, NPCs, collectibles, inventory, journal, quests, rewards, or progression systems.
- Changes to Chapter I / Forgotten Shore gameplay.
- New save data, Prologue resumability, or profile schema changes.
- Broad refactoring of PlayerController, InteractionResolver, SequenceRunner, or NarrativeData.

## 7. Implementation slices

Keep N4.3 reviewable and avoid one oversized PR.

### N4.3-A — Technical spike and exploration stage
- Inspect actor art, current player input bindings, camera pattern, shell scene layering, NarrativeState API, and beat chaining.
- Implement the isolated exploration stage, dedicated actor, and the smallest Prologue-specific beat-state/completion handshake.
- Prove the pl_02 → pl_03 handoff, bounded movement, camera, actor control lock/unlock, pl_03 handoff-area completion, and pl_03 → pl_04 activation.
- Prove per-beat Skip and cancellation semantics with headless tests, without adding final mark props.
- Do not begin mark inspection progression until this orchestration contract is verified.

### N4.3-B — Repeated Mark interaction
- Add the three authored mark props and simple proximity inspection.
- Track distinct object IDs in per-run stage state only.
- Complete pl_04 after two unique objects and route the recognition line through the existing DialoguePanel with the actor locked.
- Verify explicit pl_04 Skip, cancel/exit behavior, and exactly-once completion.

### N4.3-C — Integration and regression
- Verify full pl_01 → pl_02 → pl_03 → pl_04 flow.
- Verify cancellation, skip, exit, and dialogue control restoration.
- Run the full project regression suite and inspect the final diff independently.

A PR must state which slice it implements. Do not begin N4.3-B until N4.3-A proves the interactive orchestration works without changing generic narrative runtime semantics.

## 8. Open decisions

The following remain intentionally OPEN:
- Final visual design of the recurring mark.
- Exact road background, palette, prop art, and environment composition.
- Whether travel-worn details use equipment, a note prop, or environmental clues.
- Final visual suitability/scale of the existing Monarch sprite sheet in the Prologue composition.
- Exact actor scene tree and camera framing, pending the N4.3-A spike and windowed inspection.

The beat transition, Skip, cancellation, and completion-ownership rules above are DECIDED and are not open for the implementation agent to reinterpret. Visual details may remain labelled placeholders; they must not block the technical spike.
