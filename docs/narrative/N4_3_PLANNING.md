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
- Use one simple inspect input (prefer the existing project interaction convention only after confirming its current binding).
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

- Reuse the existing Monarch walk/idle art if the actual asset is present and suitable; verify the asset path and animation frames first.
- Reuse the established camera-follow approach if it can be isolated cleanly.
- Reuse `DialoguePanel`, `SequenceRunner`, `PlayerControlLock`, and `NarrativeState` where their existing contracts fit.
- Do **not** attach `ForgottenShoreSession`, `InteractionResolver`, economy, resource, building, NPC, research, time, or save systems to the Prologue stage.
- Do not use the full gameplay `PlayerController` unchanged if it carries world commands or gameplay input actions. Extract no broad abstraction merely for this slice; a small dedicated actor is preferred.

### Important orchestration issue — must be designed before coding

N4.2 currently chains authored sequences automatically when `SequenceRunner.sequence_completed` fires. pl_03/pl_04 introduce a player-driven interval, so they cannot simply be authored as ordinary short sequences and allowed to auto-chain immediately.

Before implementation, inspect the actual `NarrativeState`, `PrologueBeats`, and `PrologueShell` contracts and choose the smallest Prologue-specific orchestration that:

1. starts the exploration stage after pl_02;
2. keeps player control available during the exploration interval;
3. prevents the shell from auto-advancing past pl_03/pl_04 before the required observations;
4. records each beat completion exactly once;
5. routes the post-inspection dialogue through the existing dialogue panel;
6. restores control after dialogue, cancellation, scene exit, or failure.

Do not solve this by adding a generic `wait_for_interaction`, `move_player`, or `inspect_object` operation to `NarrativeData` / `SequenceRunner` unless a separate architecture review proves a reusable operation is necessary. A Prologue-specific controller/state transition is preferred.

The current shell configures `SequenceRunner` with the shell as control target. The implementation must deliberately choose the exploration actor as the control target for interactive dialogue, while preserving the no-control behavior of pl_01/pl_02. Do not leave the actor movable during dialogue.

## 5. Acceptance criteria

### Narrative and progression
- [ ] pl_01 and pl_02 still play in order and retain their current content.
- [ ] Adult Monarch appears after pl_02 in the ancient-road stage.
- [ ] The player receives movement control at the intended point in pl_03.
- [ ] pl_03 does not auto-complete into pl_04 before the exploration handoff is ready.
- [ ] The three inspectables use one consistent placeholder mark.
- [ ] Inspecting the same object repeatedly counts only once.
- [ ] Inspecting two distinct objects triggers the pl_04 recognition line exactly once.
- [ ] The third object is optional.
- [ ] pl_04 completes once; no pl_05 content is fabricated or pulled into N4.3.
- [ ] All dialogue uses the existing DialoguePanel and approved candidate lines unless separately approved.

### Controls and presentation
- [ ] Movement is bounded to the small road stage.
- [ ] Camera follows the actor without exposing empty/out-of-bounds space.
- [ ] Interaction prompt appears only within range and identifies only the eligible target.
- [ ] Movement and inspection input are blocked during dialogue.
- [ ] Control is restored after normal dialogue completion.
- [ ] Skip, cancel, exit, and failed playback leave no stuck input lock or stale prompt.
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
- Implement the smallest isolated exploration stage and dedicated actor.
- Prove movement bounds, camera, input isolation, and clean handoff from pl_02.
- Do not add the three final mark objects or complete pl_04 progression until the orchestration contract is verified.

### N4.3-B — Repeated Mark interaction
- Add the three authored mark props and simple proximity inspection.
- Track distinct object IDs in per-run stage state only.
- Complete the observation after two unique objects.
- Trigger pl_04 dialogue exactly once and hand off cleanly.

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
- Exact key binding for inspection, pending confirmation of current input map.
- Exact actor scene node type and scene tree, pending inspection of reusable art and current shell layering.

These open details must not block the planning document, but must be resolved or explicitly left as labelled placeholders before implementation.
