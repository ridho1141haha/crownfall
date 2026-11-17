# CROWNFALL — N4.3-B "Repeated Mark Inspection" Technical Design Report

**Revision 2 (owner review incorporated).** Documentation-only revision of the Rev 1 audit + design: no gameplay code, scene, asset, test, or project configuration was written by this task. Rev 1's verified audit findings, architecture boundaries, and file references are preserved; the owner-approved decisions D1–D6 below are now reflected consistently throughout this document. **Rev 2.2 (H10 semantic correction):** H8 remains unchanged. H10 now distinguishes natural stage emissions from harness-injected signal deliveries, defines shell acceptance only for a stage completion request, and tracks the skip path separately as `S` (skip handled). This corrects the prior conflation of skip handling with acceptance. D1–D6, the architecture boundaries, the B1–B3 slice scope, and the N4.3-C exclusion remain unchanged.
**Baseline (re-verified at revision time):** branch `main`, HEAD `e55617c120474dcfebe3915fa9a27b5c397474aa` (= `origin/main`), working tree **clean** (`git status --porcelain` = 0 entries) — identical to the Rev 1 audit tree, so every source reference below still points at the same code.
**Godot:** 4.7.2.stable. **Authorities:** `docs/narrative/N4_3_PLANNING.md` (scope/interaction rules/orchestration contract), `docs/narrative/PROLOGUE_STORY_DESIGN.md` (story content), `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (runtime contract).

## Owner-approved decisions incorporated in this revision

| # | Decision (owner-approved, binding for implementation) | Where reflected |
|---|---|---|
| D1 | Inspecting ONE object does **not** open dialogue: first inspection records the object id in per-run stage state; re-inspecting the same object is an idempotent no-op; no individual dialogue/notification/lore response. Recognition dialogue only after two DISTINCT objects. | §4 (item 5), §8, §9 (H1, H11), §11 (U1/U3 APPROVED) |
| D2 | Recognition dialogue lifecycle: disable movement input → acquire stage-owned `PlayerControlLock` → open approved recognition line via existing `DialoguePanel` → wait for normal completion → validate generation/lifecycle → release lock safely → emit completion request exactly once → shell validates and records → end segment. No new dialogue systems, no `SequenceRunner`; only the already-approved story text. | §4 (item 6), §7, §8 |
| D3 | Final acceptance state after normal completion is the ENDED/frozen state (panel closed, lock released, completion emitted+recorded exactly once, segment ended, input disabled, explorer frozen, prompt hidden, no stale coroutine/callback) — matching the existing pl_04 skip terminal state. The coroutine's brief input restore before the shell ends the segment is transient and is NOT the acceptance condition. Corrects Rev 1 test H6. | §7 (step 6 note), §8, §9 (H6) |
| D4 | Three authored objects; two DISTINCT are sufficient; the third is optional; completion must never require all three; inspecting A repeatedly never counts as two. Proposed placements stay tunable proposals. | §4 (item 8), §6, §9 (H10, H11) |
| D5 | Inspection polling gate: active beat is pl_04 · stage not torn down · segment not ended · movement input enabled · dialogue panel not open · stage lock not held · eligible object in authored range · `interact` just pressed. A held `interact` key must NOT trigger repeated inspection after the dialogue closes; `DialoguePanel` input consumption must not be relied upon to suppress polling. | §3 (risk 1), §7, §9 (H5, H14) |
| D6 | Fail-closed setup validation: non-empty table, ≥2 valid objects, non-empty unique ids, positions within authored movement bounds, prop/glyph/prompt constructible; on failure report invalid setup, expose no partially functional inspection, fail stage setup safely, keep the shell fallback/idle boundary intact, record nothing. Validation stays proportional — no defensive abstractions for impossible conditions. | §5, §8, §9 (H9) |

---

## 1. Baseline Verification

| Check | Result | Evidence |
|---|---|---|
| Current branch | `main` | `git branch --show-current` |
| HEAD | `e55617c120474dcfebe3915fa9a27b5c397474aa` | `git rev-parse HEAD` |
| `origin/main` | `e55617c120474dcfebe3915fa9a27b5c397474aa` (identical) | `git rev-parse origin/main` after `git fetch` |
| Working tree | Clean — 0 modified/untracked entries; nothing stashed, reset, or discarded | `git status --porcelain \| wc -l` → 0 |
| N4.3-A present | Yes: `scripts/narrative/PrologueExplorationStage.gd`, `scripts/narrative/PrologueExplorer.gd`, exploration wiring in `scripts/narrative/PrologueShell.gd` (header §"N4.3-A INTEGRATION", lines 39–56) | file listing + grep |
| Local changes | None found; no user work needed preserving | `git status` |
| Docs read | N4_3_PLANNING.md (full), NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md (full), PROLOGUE_STORY_DESIGN.md (full), NARRATIVE_IMPLEMENTATION_ROADMAP.md + PROLOGUE_PRODUCTION_BREAKDOWN.md (N4.3 rows) | — |

Test-status honesty: **no tests were run in this task or in the Rev 2 revision** (documentation-only). The last actually-executed verification of this exact tree (`e55617c` content at `fd487f6`) was the N4.3-A merge gate earlier the same day: `tests/run_all.sh` ALL SUITES PASSED, `verify_repo_integrity.py` 243/243, CI run on `fd487f6` success, and a windowed (Xvfb) visual inspection of the exploration stage across six window sizes — those results are prior evidence for N4.3-A, not claims of these design tasks.

Source-reference verification (Rev 2): the anchors cited throughout this document were re-checked against the unchanged tree (same HEAD, clean status), including `PrologueExplorer.gd:105-112` (`freeze()` block), `PrologueShell.gd:379-386/:444-445/:449-454/:463-470`, `PrologueExplorationStage.gd:125-132/:139-144/:151-158/:165-180/:231-251`, `DialoguePanel.gd:133-141`, `NarrativeState.gd:21-25`, `project.godot:42-44` (`interact`), the N4.3-A test harness anchors, and the planning-document anchors — all still point at the same responsibilities. Rev 2.1 additionally inspected, for the H8/H10 contracts: `PlayerControlLock.gd` in full (`extends RefCounted` :2; `unlock()` :45-52; `_release_locked_target()` :56-61; `is_locked()` :64-65), `PrologueExplorationStage.gd:55-64/:83/:139-144/:165-180/:215-224/:246-251` (private `_dialogue_lock`, release paths, emission/generation guards), `PrologueShell.gd:97/:160-162/:343-360/:396-417/:436-454` (`NarrativeState` ownership + public getter, acceptance handler, skip path, segment getters), `NarrativeState.gd:1-33` (`RefCounted`, idempotent `mark_completed`, `completed_count()`), and the N4.3-A direct-unload precedent `tests/test_n43a_exploration_stage.gd:87-91/:767-796` (stages 34/35: pre-unload captures, `change_scene_to_file` unload, post-unload survivor assertions).

---

## 2. Existing Architecture Findings

Answers to the eight audit questions, with exact references into the audited tree.

### Q1 — Who currently owns exploration input?

Three layers, deliberately split:

1. **The actor executes movement only when told.** `PrologueExplorer._physics_process` polls `Input.get_axis("move_left", "move_right")` exclusively behind the `_input_enabled` flag (`scripts/narrative/PrologueExplorer.gd:79-91`; gate at :83-84; setter `set_input_enabled` :97-99). It defines **no** `_unhandled_input` handler — nothing else about input touches the actor.
2. **The stage owns the enable/disable policy.** `PrologueExplorationStage` disables input while the intro dialogue plays (`PrologueExplorationStage.gd:239`), enables it when the intro line closes (:251) and on pl_04 activation (:131-132), and disables it on `end_segment()` (:157) and `teardown()` (:173).
3. **The stage-owned `PlayerControlLock` is the hard gate.** During dialogue it disables the explorer's `_physics_process` entirely (`PrologueExplorationStage.gd:238` → `PlayerControlLock.gd:38-39`), so held movement keys cannot move the actor even though `Input.get_axis` would still report the axis (the planning's own warning, N4_3_PLANNING.md:133).

### Q2 — Who owns actor movement and movement bounds?

The actor owns execution; the stage owns the authored numbers.

- Clamp every physics frame: `position.x = clampf(position.x + direction * MOVE_SPEED * delta, _min_x, _max_x)` — `PrologueExplorer.gd:90`. No gravity; the road is authored flat (header contract `PrologueExplorer.gd:12-15`).
- Bounds are injected via the constructor and authored as a **separate seam** from camera limits (`PrologueExplorer.gd:47-54`, `_init` signature :54; stage passes `ROAD_MIN_X/MAX_X` for movement and the same values plus `VIEW_TOP/BOTTOM` for camera limits — `PrologueExplorationStage.gd:89-98`). Authored values: `ROAD_MIN_X=-800`, `ROAD_MAX_X=800`, `VIEW_TOP=-240`, `VIEW_BOTTOM=240`, `GROUND_Y=200` (`PrologueExplorationStage.gd:33-37`).

### Q3 — Who owns beat completion and NarrativeState recording?

**`PrologueShell` is the sole writer.**

- The stage never records; it emits exactly one request signal per interval (`exploration_handoff_reached`, declared `PrologueExplorationStage.gd:29`, emitted once behind the `_handoff_emitted` guard at :222-224).
- The shell records through `_record_exploration_beat` (`PrologueShell.gd:411-417`) → `NarrativeState.mark_completed` (idempotent, returns true only on the first call — `NarrativeState.gd:21-25`).
- The skip path records through the same single function (`PrologueShell.gd:442`).
- `SequenceRunner` records only its own authored sequences in `_finalize_completion` (`SequenceRunner.gd:222-234`) and **cannot** see the exploration beats: `PrologueBeats.BEAT_IDS` ends at pl_02 (`PrologueBeats.gd:37-40`), `is_exploration_beat` ids never enter the runner (`PrologueBeats.gd:77-78`), and the shell's chain handler filters on `PrologueBeats.is_beat` (`PrologueShell.gd:306-308`).

### Q4 — How does PrologueShell receive and validate exploration completion?

- Request channel: the stage's single signal → shell handler `_on_exploration_handoff_reached` (`PrologueShell.gd:396-405`). Validation ladder: (1) reject if an exit started or the stage is gone (:397); (2) reject if the request's beat is not the ACTIVE exploration beat (:399-402); (3) record idempotently — a duplicate is a rejected no-op that only warns (:403, :411-417); (4) on success activate the next beat (:405, :421-425).
- The alternate validated completion path is `skip_current_exploration_beat()` (`PrologueShell.gd:436-454`): refuses when the segment ended/exit started/beat inactive, records exactly once through the same `_record_exploration_beat`, and for pl_04 ends the segment at the defined boundary (:449-454).
- The request itself fires only under strict preconditions in the stage's `_physics_process` (`PrologueExplorationStage.gd:215-224`): not torn down / segment not ended / not already emitted, active beat is pl_03, movement input enabled, actor `x >= HANDOFF_X` (680). A placed-but-not-controllable actor can therefore never complete a beat.

### Q5 — How are control locks acquired and released?

`PlayerControlLock` (`PlayerControlLock.gd:26-52`): `lock(target)` snapshots the target's current `is_physics_processing()` / `is_processing_unhandled_input()` (:35-36) and disables both (:38-39); re-locking the same target is a no-op, switching targets releases the previous one first (:29-33); `unlock()` restores exactly the snapshotted state and is freed-safe via `is_instance_valid` (:45-52).

Two lock instances exist and must stay separate:

| Instance | Target | Acquired | Released |
|---|---|---|---|
| Runner's own lock (`SequenceRunner.gd:59-60`) | The shell itself (no actor in pl_01/pl_02 — `PrologueShell.gd:135-142`) | `lock_control` op (:150-151) | `unlock_control` op (:152), `_cleanup` (:250-251), `_exit_tree` (:257-264) |
| Stage-owned exploration lock (`PrologueExplorationStage.gd:83`) | `PrologueExplorer` | `_present_intro_dialogue` (:238) | Normal close (:250), and on **every** other path via `close_active_dialogue()` (:139-144), which is called by `end_segment()` (:155), `teardown()` (:171), and the shell's skip path (`PrologueShell.gd:444-445`) |

### Q6 — What happens when a scene is unloaded during an active exploration or dialogue?

Godot frees the whole shell subtree; each owner cleans up in `_exit_tree` with no reliance on an explicit cancel call:

- `DialoguePanel._exit_tree` drops open-line state **without emitting** `dialogue_finished` into a dying tree (`DialoguePanel.gd:144-149`).
- `SequenceRunner._exit_tree` cancels a running run: panel closed, control restored, generation invalidated (`SequenceRunner.gd:257-264`).
- `PrologueExplorationStage._exit_tree` → `teardown()` (`PrologueExplorationStage.gd:177-180` → :165-174): bumps `_dialogue_generation` first (a resumed `await` observes stale state and returns before re-enabling input, :246-247), closes the panel, releases the stage lock, disables input, freezes the explorer.
- `PrologueExplorer.freeze()` stops all processing regardless of lock state and cannot be re-enabled accidentally (restoration requires an explicit stage call — `PrologueExplorer.gd:105-112`).
- Nothing is recorded on unload (shell `_record_exploration_beat` is only reachable from validated requests; the per-run `NarrativeState` dies with the scene — non-resumable per the runtime D1/D4 decisions).
- This exact path is regression-covered: "a DIRECT scene unload while the exploration dialogue is open … releases the lock, records nothing, produces no coroutine or invalid-access errors" (`tests/test_n43a_exploration_stage.gd:37-39`, test stage 34 harness vars :87-91).

### Q7 — Which existing interaction-related mechanisms can be reused safely?

| Mechanism | Reference | Reuse for N4.3-B |
|---|---|---|
| `interact` input action | `project.godot:42-44` (physical keycode 69 = E) | Already defined; currently consumed only by gameplay scenes (`scripts/player/Player.gd:41`, `scripts/world/ForgottenShoreSession.gd:586`), never loaded in the Prologue — zero input conflict. Planning mandates it (`N4_3_PLANNING.md:75`). |
| `DialoguePanel.open_lines/advance/close` + `dialogue_finished` | `DialoguePanel.gd:79-112` | The recognition-line presentation channel (mandated: `N4_3_PLANNING.md:119`). |
| Stage-owned lock + generation-guarded dialogue coroutine | `PrologueExplorationStage.gd:231-251` | Reusable verbatim as the pattern for the recognition dialogue (same lock instance, same guard discipline). |
| Exactly-once completion handshake | stage request signal → shell validates active beat → idempotent record (`PrologueExplorationStage.gd:222-224`, `PrologueShell.gd:396-417`) | Same pattern for the pl_04 inspection completion request. |
| Gated per-frame condition check in the stage's `_physics_process` | `PrologueExplorationStage.gd:215-224` | The natural home for proximity/eligibility + `interact` polling (same gating style; see §7). |
| Fail-closed atomic setup with fallback | `PrologueExplorationStage.gd:75-102` + shell fallback `PrologueShell.gd:379-386` | The inspectable set's validation plugs into the same setup contract. |
| Headless test harness conventions | `tests/test_n43a_exploration_stage.gd:42-66` (metas, isolated fixtures, `_check`, `MAX_WAIT_FRAMES`), registration `tests/run_all.sh:38`, CI `godot-ci.yml:162-164` | Template for the N4.3-B suite. |

### Q8 — Which existing mechanisms should NOT be reused for this beat?

- **`SequenceRunner`** — exploration beats must never become runner sequences or runner ops (`N4_3_PLANNING.md:119,124,135`; the `BEAT_IDS` discipline exists precisely to keep the runner from chaining past the player-driven interval, `PrologueBeats.gd:28-35`). No `wait_for_interaction`/`inspect_object` op.
- **`scripts/player/Player.gd` interaction handling** (`Player.gd:41`) — it belongs to the gameplay `InteractionResolver` path and drags world commands along; planning forbids attaching it (`N4_3_PLANNING.md:107-108`). Its `_unhandled_input`-driven style also composes badly here: `DialoguePanel` consumes all unhandled input while open (`DialoguePanel.gd:133-141`), so an explorer `_unhandled_input` handler would be silently dead during dialogue — action polling in the stage's physics step avoids that class of bug.
- **`InteractionResolver`, `ForgottenShoreSession`, economy/save/NPC systems** — forbidden attachments (`N4_3_PLANNING.md:107`).
- **The runner's `PlayerControlLock` instance** — bound to the shell as control target for pl_01/pl_02 (`PrologueShell.gd:132-138`); the exploration actor must keep using the stage-owned lock (`NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md:113`).
- **A `camera_focus` op or pause-world op** — PROPOSED, not implemented (`NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md:103,172-173`); do not add.
- **Generic frameworks** — no quest/objective/branching-dialogue systems, no EventBus (`NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md:69`; `N4_3_PLANNING.md:9,82`).

---

## 3. Current Risks and Limitations

1. **`interact` polling bypasses input routing (D5).** `Input.is_action_just_pressed` reads raw action state, not routed input, so `DialoguePanel`'s input consumption (`DialoguePanel.gd:133-141`) does **not** suppress it — and the design must not pretend otherwise. The poll must gate on the full D5 condition list ("dialogue not open and stage lock not held" via `PrologueExplorationStage.gd:191-192` + `_panel.is_open()`, plus the beat/teardown/segment/input conditions), exactly like the handoff check gates on input-enabled. Risk if ignored: inspection firing during the recognition dialogue. The held-key edge (hold E through dialogue closure) is covered mechanically in §7 and by test H14.
2. **The stage's `_physics_process` keeps running while the explorer is lock-frozen.** The lock targets the explorer node only (`PlayerControlLock.gd:38-39`); the stage's own physics step is untouched. All pl_04 logic therefore needs its own explicit gates (same as the existing handoff gates at `PrologueExplorationStage.gd:216-221`).
3. **pl_04 begins at the road's east end.** pl_03 completes at `HANDOFF_X = 680` (`PrologueExplorationStage.gd:40`), so the pl_04 actor starts near x≈680–800. Object placement must put at least two inspectables within a short walk of that point, or the "short interaction range" experience becomes a long forced backtrack.
4. **The current pl_04 UI explicitly says inspection is not implemented** (`PrologueShell.gd:486` — "Mark inspection is not implemented yet (N4.3-B)"); this text must be updated in the same change or the shell will lie to the player.
5. **The skip path must keep working while the recognition dialogue is open.** `skip_current_exploration_beat()` already calls `close_active_dialogue()` before ending the segment (`PrologueShell.gd:444-445`), and `close_active_dialogue` invalidates the dialogue generation (`PrologueExplorationStage.gd:140`) — the design below relies on exactly this guard so that a skip during the recognition line can never double-complete pl_04 (the resumed coroutine returns at :246-247 before its completion emission).
6. **`NarrativeState` guards by id, not by beat semantics.** `mark_completed("pl_04_repeated_mark")` is idempotent (`NarrativeState.gd:21-25`), but "recorded exactly once" additionally depends on the shell's active-beat validation and the stage's one-shot emission flag — three layers that must all be present in the new path, not just the state's own guard.
7. **No art exists for the mark or props.** Everything must ship as labelled placeholder geometry under the established no-lore discipline (`PrologueExplorationStage.gd:24-27`; `PROLOGUE_STORY_DESIGN.md:217`). The symbol's design is an OPEN decision (`PROLOGUE_STORY_DESIGN.md:253`).
8. **A transient restore window exists between dialogue close and segment end (D3).** On the normal path the recognition coroutine releases the lock and re-enables input before emitting the completion request; the shell handler then ends the segment within the same resume. The actor may therefore be *transiently* restored for that instant. Acceptance asserts the FINAL terminal state (frozen, input-disabled), never the transient — see §8 and H6.

---

## 4. Proposed N4.3-B Behavior

Smallest behavior set that satisfies `N4_3_PLANNING.md` §2 pl_04 + §3 interaction rules, with no invented canon:

1. **Props.** Three authored placeholder objects stand along/beside the road, each carrying the *identical* placeholder mark shape (only surface condition/size/placement vary — planning §2 "Object variety", :65-70). They are built at stage setup, visible during pl_03 as scenery (environmental storytelling), but **inert**: no prompt, no inspection.
2. **Activation.** When the shell activates pl_04 (existing `set_active_beat`, `PrologueExplorationStage.gd:125-132`), inspection becomes enabled. Movement stays enabled (already the case, :131-132).
3. **Eligibility.** While pl_04 is active, dialogue closed, lock not held, and movement input enabled, the stage computes the nearest object with `abs(explorer.x − object.x) ≤ INSPECT_RANGE` (a 1-D check; the road has no vertical movement — `PrologueExplorer.gd:12-15`). At most one object is eligible at a time (nearest wins — planning :77).
4. **Prompt.** One contextual prompt (placeholder text, e.g. `[E] Inspect`) is shown only when an object is eligible, positioned at that object; it identifies the target spatially and disappears the moment eligibility is lost (planning :76; acceptance "prompt appears only within range and identifies only the eligible target", :158).
5. **Individual inspection — APPROVED (D1): silent.** Pressing `interact` while an object is eligible inspects exactly that nearest object. First inspection records its authored id in per-run stage state. Re-inspecting the same object is an idempotent no-op. **No individual dialogue, notification, or invented lore response is added** — the previously OPEN decision U1 is now owner-approved exactly this way. Recognition dialogue appears only after two DISTINCT objects.
6. **Recognition + completion lifecycle — APPROVED (D2), in this exact order:**
   1. Disable explorer movement input.
   2. Acquire the existing stage-owned `PlayerControlLock`.
   3. Open the approved recognition line using the existing `DialoguePanel` (only the already-approved story text — `PROLOGUE_STORY_DESIGN.md:107-109`; no new lore, character history, or symbol origin).
   4. Wait for normal dialogue completion (player advances through all lines).
   5. Validate the dialogue generation and lifecycle state (the generation guard, §8 layer 2).
   6. Release the lock safely (freed-safe `unlock`, `PlayerControlLock.gd:45-52`).
   7. Emit the completion request `mark_inspection_completed()` exactly once (one-shot flag).
   8. `PrologueShell` validates (active beat, exit guard) and records `pl_04_repeated_mark` exactly once.
   9. End the exploration segment (shell terminal sequence, below).
   No new dialogue systems; this beat never routes through `SequenceRunner`. Completion therefore requires the explicit interact action + two distinct objects + the narrative line — never mere approach.
7. **Ordering rule (record-after-dialogue).** The completion request is emitted *after* the recognition dialogue closes normally (D2 steps 4→7), not when the second object is inspected. Reason: the acceptance criteria demand that cancel/exit/teardown never mark the beat complete (`N4_3_PLANNING.md:152`); recording only after a normal close guarantees a dev-exit or unload during the recognition line records nothing, while the dialogue-first ordering still "triggers the recognition line exactly once and completes pl_04" (planning :118) within the same interaction.
8. **Repeat safety and object count (D4).** After the request is emitted (or the segment ended), further inspections are inert: the stage gates on the one-shot flag + `_segment_ended`, the shell ignores requests for a non-active beat (`PrologueShell.gd:399-402` pattern), and `NarrativeState` rejects duplicates (`NarrativeState.gd:21-25`). Three independent layers, matching "Repeated inspection must not accidentally complete the beat multiple times". Two DISTINCT objects (A+B) are sufficient and complete the beat; A+B+C is also valid; the third object never blocks or is required; inspecting A repeatedly never counts as two.
9. **Input gating (D5).** Inspection polling requires ALL of: active beat is `pl_04_repeated_mark`; stage not torn down; segment not ended; explorer movement input enabled; dialogue panel not open; stage-owned dialogue/control lock not held; an eligible object within the authored range; `interact` just pressed. A held `interact` key must not trigger repeated inspection after the dialogue closes (mechanism + test in §7/H14).
10. **Skip.** `skip_current_exploration_beat()` needs **no signature change**: for pl_04 it already records once, closes any active dialogue (including the new recognition line), releases the stage lock, and ends the segment (`PrologueShell.gd:436-454`; planning :127). The generation guard makes a later coroutine resume a no-op.
11. **Cancel/exit/teardown.** Existing paths already release the lock, disable input, freeze the actor and record nothing (`PrologueExplorationStage.gd:165-180`, `PrologueShell.gd:463-470`, `PrologueShell.gd:586-589`). N4.3-B adds only: hide the prompt and invalidate the inspection presentation under the same calls.
12. **Lore discipline.** The mark is recognisable and recurring; its origin/meaning stay unknown. No name, dynasty, or history appears anywhere (`PROLOGUE_STORY_DESIGN.md:111`; planning :9).

---

## 5. Recommended Architecture

**Recommendation: a small Prologue-specific inspection component (`PrologueMarkInspectables`, one new script) + condition/completion ownership kept in the existing stage/shell handshake.** No existing interaction mechanism is reused beyond the ones listed in Q7; no new framework, registry, state machine, resource, or manager.

### Why the component (and why not stage-inline or an existing script)

- **Why not stage-inline:** `PrologueExplorationStage.gd` is already 302 lines carrying environment building, the pl_03 condition, and the dialogue presentation. The planning's own responsibility table splits "inspectable placements" (stage row, `N4_3_PLANNING.md:95`) from "three mark objects and their proximity/inspection affordance" (`PrologueInspectables` row, :97). Inlining would mix two beat conditions in one script, complicate teardown review, and make the eligibility math harder to unit-test.
- **Why not `PrologueExplorer`:** its header explicitly reserves inspection out ("no interaction logic (N4.3-B adds inspection through the stage, not here)" — `PrologueExplorer.gd:7-8`), and it must stay a pure movement/animation/camera node.
- **Why not reuse `Player.gd`/`InteractionResolver`:** see Q8.
- **Why one component and not a per-object script:** the objects are static placeholder rectangles; per-object scripts would be three copies of nothing. One node owns the authored object table, geometry, the shared prompt, and idempotent per-id state. That is the whole abstraction surface.

### Stability contract (owner-confirmed; do not redesign)

| Responsibility | Owner |
|---|---|
| Inspectable objects, glyphs, prompt, per-ID inspected state | `PrologueMarkInspectables` (new) |
| pl_04 activation, proximity/input gating, recognition dialogue, lock lifecycle | `PrologueExplorationStage` |
| Active-beat validation, `NarrativeState` recording, segment boundary | `PrologueShell` |
| Recognition dialogue content | `PrologueBeats` |
| Actor movement | `PrologueExplorer` |
| Dialogue presentation | Existing `DialoguePanel` |

Fixed: `SequenceRunner` must not own pl_04; `NarrativeState`, `PlayerControlLock`, `DialoguePanel`, `PrologueExplorer` remain unchanged; `project.godot` remains unchanged (`interact` already exists, :42-44); `PrologueShell.tscn` remains unchanged (stage and inspectable geometry are code-built); no gameplay `Player.gd`/`InteractionResolver`/`ForgottenShoreSession`/economy/NPC/save/profile systems; no generic interaction framework, quest framework, EventBus, registry, or state machine. Every boundary above is implementable against the verified Rev 1 audit — none is technically impossible.

### Responsibilities after N4.3-B

| Node/script | Gains | Keeps unchanged |
|---|---|---|
| `PrologueMarkInspectables` (new) | Authored object table + ids; placeholder prop/mark geometry; range query (`nearest_eligible_id(at_x)`); idempotent `mark_inspected(id) -> bool`; distinct-count; shared prompt label; fail-closed atomic `build()` validation (D6) | Nothing existing |
| `PrologueExplorationStage` | pl_04 gating + interact polling in the existing `_physics_process` (D5 gate list); recognition-dialogue presentation per D2 (clone of :231-251 with the same generation guard); one new request signal `mark_inspection_completed()`; prompt/inspection disable in `end_segment`/`teardown` | Handoff logic, lock ownership, teardown semantics, environment |
| `PrologueShell` | One new handler `_on_mark_inspection_completed()` (validate active beat → record once → end segment); pl_04 detail-label text update | Sole-writer recording, skip path (no signature change), exit guards |
| `PrologueBeats` | New static `exploration_recognition_lines()` returning the approved candidate text (`PROLOGUE_STORY_DESIGN.md:107-109`) | `BEAT_IDS` discipline — pl_04 still never becomes a runner sequence |
| `PrologueExplorer`, `DialoguePanel`, `SequenceRunner`, `NarrativeState`, `PlayerControlLock`, `project.godot`, `PrologueShell.tscn` | **No changes** | — |

The `.tscn` needs no edit: the exploration stage is code-built at runtime (`PrologueShell.gd:372-390`), and all placeholder geometry is code-built (`PrologueExplorationStage.gd:267-302`). The new component is added as a stage child in `setup()`.

**D6 atomic-build structure (proportional, not a test seam):** `build()` validates the authored table first (empty table, fewer than two objects, empty/duplicate ids, positions outside `[ROAD_MIN_X, ROAD_MAX_X]` all fail before anything is created), then constructs the prop geometry, the mark glyph, and the shared prompt through three small factory methods (`_create_prop`, `_create_mark_glyph`, `_create_prompt`). Construction is committed to the tree only after every node is verified non-null; any failure frees partials and reports invalid setup (`is_valid() == false`). These three methods are ordinary construction structure — they exist because the builder needs them, and they incidentally allow the H9 construction-failure simulation via a test-only subclass (§9).

---

## 6. Scene Tree Proposal

Runtime tree during exploration (only `PrologueMarkInspectables` is new):

```
PrologueShell (Control, scenes/narrative/PrologueShell.tscn)
├── Background, StageBackdrop(+StageCaption), CenterContainer(VBox: Title/Status/Detail/DevExitButton)   [unchanged]
├── PrologueExplorationStage (Node2D, inserted at UI index 2 — PrologueShell.gd:87,377-378)
│   ├── RoadBackdrop / RoadBand / RoadEdge / Remnant1..4 / HandoffAreaMarker      [existing ColorRects, PrologueExplorationStage.gd:267-302]
│   ├── PrologueMarkInspectables (NEW, Node2D)
│   │   ├── MarkStoneA      (Node2D at x≈430)  → prop ColorRect(s) + MarkGlyph (identical shape) 
│   │   ├── MarkFragmentB   (Node2D at x≈630)  → prop ColorRect(s) + MarkGlyph (same shape, weathered variant)
│   │   ├── MarkArtifactC   (Node2D at x≈-280) → prop ColorRect(s) + MarkGlyph (same shape, obscured variant)
│   │   └── InspectPrompt   (Label, world-space, repositioned above the eligible object)
│   └── PrologueExplorer (Node2D — sprite + camera, existing)
└── DialoguePanel (CanvasLayer layer 100, existing — PrologueShell.gd:129-130)
```

Notes:
- A `Label` under a `Node2D` renders in world space and moves with the camera — exactly the wanted "prompt above the object" behavior with zero new layers (DialoguePanel's layer-100 CanvasLayer stays the only overlay surface that matters).
- Proposed positions: A ≈ 430, B ≈ 630, C ≈ −280 (D4: tunable proposals, not fixed canon; the existing planning specifies only "three distinct ancient objects along or just beside the road", :53-57). Rationale: pl_04 starts with the actor at the east end (risk #3), so two objects sit within a short walk of the handoff area and the third is the optional far-west reinforcement (planning :80-81).
- The mark glyph: one small identical shape per prop (e.g. a 2-rect key/chevron placeholder ~14×20 px), tinted per surface condition but geometrically identical — satisfies "one consistent placeholder mark" (planning :146) without converting the OPEN mark design into canon (U2 stays OPEN, §11).

---

## 7. Input and Interaction Flow

**Player → inspection (happy path):**

1. Player holds A/D — the explorer moves, clamped to bounds (`PrologueExplorer.gd:90`).
2. Every physics frame the stage's `_physics_process` runs its existing guard block, then — only when `_active_beat == PL_04_REPEATED_MARK` — applies the **full D5 gate list** before anything else: not torn down; segment not ended; movement input enabled; `not _panel.is_open()`; `not is_dialogue_locked()` (risk #1/#2 — the panel's input consumption is never relied upon); then asks `inspectables.nearest_eligible_id(_explorer.position.x)`.
3. If an id returns, the prompt becomes visible at that object; otherwise hidden. No other UI, no HUD, no quest marker (planning :41, :82).
4. On `Input.is_action_just_pressed("interact")` **with** an eligible id: the stage calls `inspectables.mark_inspected(id)`. First time → true, distinct count grows; repeat → false, nothing changes (D1: silent; planning :78-79).
5. When the distinct count reaches 2 and the one-shot flag is clear, the D2 sequence starts **in the same physics frame as the accepting press**: the stage disables movement input, locks the actor with the stage-owned lock, bumps the dialogue generation, opens `PrologueBeats.exploration_recognition_lines()` through the shared panel, and awaits `dialogue_finished` — structurally identical to `_present_intro_dialogue` (`PrologueExplorationStage.gd:231-251`).
6. Normal close → the coroutine's guard passes → lock released, input re-enabled (transient — see note), then the one-shot completion request `mark_inspection_completed()` is emitted once; the shell handler (step 7) runs synchronously in that resume and immediately ends the segment. **D3: this brief restore is transient code state, not the acceptance condition** — the final state is the ended/frozen boundary state of §8. The restore-before-end ordering is kept only so the recognition path is structurally identical to the pl_03 intro path (one code shape to review, not two).
7. Shell `_on_mark_inspection_completed()`: rejects when exit started/stage gone/beat inactive; records `pl_04_repeated_mark` once via `_record_exploration_beat`; calls `stage.end_segment()`; sets `_exploration_beat = ""`, `_n43_segment_ended = true`, shows the N4.3 boundary status — the same terminal sequence as the pl_04 skip (`PrologueShell.gd:449-454`).

**Held-key safety (D5):** a held `interact` key cannot retrigger. Two independent facts make this hold: (a) `Input.is_action_just_pressed` fires only on the press frame — a held key stays "pressed" but never "just pressed" again; (b) on the accepting press, the gate list itself flips to a rejecting state before the next poll (dialogue open + lock held + input disabled), and after the shell ends the segment the segment/teardown gates reject permanently. The dialogue never relies on panel input consumption to suppress the poll (risk #1). Test H14 proves the composed behavior end-to-end.

**Interaction range and eligibility (authored constants, proposal):** `INSPECT_RANGE_X = 64.0` world px (≈ half the explorer sprite width — a genuine "short interaction range", planning :55); eligibility strictly `abs(dx) <= INSPECT_RANGE_X`; ties impossible because objects are spaced ≫ range apart. All three authored positions are inside `[ROAD_MIN_X, ROAD_MAX_X]` and are validated at build (D6, fail-closed).

**How the symbol communicates inspectability:** the prompt only (planning :76 mandates the prompt; a range highlight/hover tint is explicitly *not* included — it is presentation polish the planning does not require, and placeholder geometry makes it meaningless right now).

**How dialogue is displayed:** the existing `DialoguePanel`, opened by the stage with the stage-owned lock — the exact contract decided in `N4_3_PLANNING.md:119`. No new panel, no runner sequence, no synthetic sequence id.

**How control is locked and restored:** stage-owned `PlayerControlLock` on the explorer (lock disables the explorer's `_physics_process`, so polling cannot move it — `PlayerControlLock.gd:38-39`); released per D2 step 6 on the normal path, on skip via `close_active_dialogue` (`PrologueShell.gd:444-445`), and on cancel/exit/teardown (`PrologueExplorationStage.gd:171`, `PrologueShell.gd:466`, `:589`). Unchanged from N4.3-A; N4.3-B only reuses it a second time.

---

## 8. Completion and Teardown Lifecycle

**Completion validation chain (exactly-once, four independent layers):**

1. Stage one-shot flag `_inspection_completed` (mirrors `_handoff_emitted`, `PrologueExplorationStage.gd:64`) — the request can never re-emit.
2. Dialogue generation guard — skip/teardown during the recognition line invalidates the pending coroutine, so its post-close completion emission never runs (`PrologueExplorationStage.gd:236-247` pattern).
3. Shell active-beat validation — requests for a non-active beat are ignored (`PrologueShell.gd:399-402` pattern); after the segment ends `_exploration_beat` is `""`, so late requests die there (:451).
4. `NarrativeState.mark_completed` idempotence (`NarrativeState.gd:21-25`).

Event mapping for the H10 contract (Rev 2.2): layer 1 gates the natural stage EMISSION (`E_stage`); layers 2–3 gate shell ACCEPTANCE (`A`) of that stage request; layer 4 guards the RECORDING (`R`). Harness-injected signal deliveries (`E_injected`) are tracked separately and are never counted as natural stage emissions. The skip path is tracked independently as `S` (skip handled), not as `A`, because it does not accept a stage completion request. These observables are never conflated (§9, H10 contract detail).

**Normal completion lifecycle and FINAL state (D3):** 2nd distinct inspect → lock + recognition line → normal close → guard passes → lock released (transient) → request emitted once → shell records pl_04 once → `end_segment()` → shell marks `_n43_segment_ended` and shows the defined N4.3 boundary — identical terminal state to the pl_04 skip (`PrologueShell.gd:449-454`; planning :120: the milestone ends in a defined idle/boundary state, no pl_05 fabrication). The acceptance criteria are ALL of:

- Dialogue panel closed.
- Stage-owned control lock released.
- Completion request emitted exactly once.
- `pl_04_repeated_mark` recorded exactly once by `PrologueShell`.
- Stage segment ended (`_segment_ended`, `_n43_segment_ended`).
- Explorer movement input disabled.
- Explorer frozen.
- Prompt hidden.
- No stale coroutine or callback remains active.

The actor's brief restoration by the dialogue coroutine before `end_segment()` (§7 step 6) is transient and must NOT be asserted as the final state; H6 asserts the terminal list above.

**Skip during the recognition line:** `skip_current_exploration_beat()` records pl_04 once (the beat IS completed by skip, planning :127) → `close_active_dialogue()` bumps the generation and closes the panel → `end_segment()` → boundary. The invalidated coroutine resumes, sees stale generation/torn-down state, and returns before emitting — no double record (layers 2+3+4 above). This is precisely the already-tested N4.3-A path (`tests/test_n43a_exploration_stage.gd:27-28`, contract item 11). In the H10 event vocabulary (Rev 2.2): `E_stage=0`, `E_injected=0`, `A=0`, `S=1`, and `R=1` exactly once. The skip is handled by its own path; it is not acceptance of a stage completion request (§9, scenario B).

**Cancel / dev exit / scene unload during inspection or recognition dialogue:**

- `cancel_sequence()` → `_abort_exploration_segment(true)` (`PrologueShell.gd:209-214,463-470`) → `stage.teardown()`: generation bumped, panel closed, lock released, input disabled, actor frozen, prompt hidden (the one new teardown line), **nothing recorded**. Two distinct windows, both covered by tests (H7a/H7b): cancel *before* any recognition dialogue opens, and cancel *while the recognition dialogue is open* — neither records completion.
- Dev exit → `_begin_exit(..., true)` → same abort path (`PrologueShell.gd:577-589`).
- Direct scene unload → stage `_exit_tree` → same `teardown()` (`PrologueExplorationStage.gd:177-180`); panel `_exit_tree` emits nothing (`DialoguePanel.gd:144-149`); runner `_exit_tree` handles any pl_01/pl_02 run (`SequenceRunner.gd:257-264`). Covered with the recognition dialogue open (H8); H8 verifies the lock release directly on the surviving `PlayerControlLock` reference — never by dereferencing the freed stage or explorer (§9, H8 contract detail).
- Failed setup (D6) → the component refuses to build (`is_valid() == false`, no props/prompt/state, partials freed) and the stage fails setup like a texture failure → shell frees the stage and falls back to the idle boundary (`PrologueShell.gd:379-386`) — no actor, no lock, no partial inspection system, no recording.

**Post-boundary inertness:** after `_n43_segment_ended`, the stage's physics block returns early (the `PrologueExplorationStage.gd:216` gate pattern), the shell rejects all requests, and the actor is frozen — repeated `interact` presses, third-object inspections, and late/duplicate completion requests are unobservable no-ops (H10 scenarios B–C: no new natural stage emission, no additional injected delivery, no additional acceptance, no additional skip handling, and no additional recording).

---

## 9. Test Plan

New suite `tests/test_n43b_mark_inspection.gd` (SceneTree, same harness conventions as `tests/test_n43a_exploration_stage.gd:42-114`: Engine-meta isolation under `user://n43b_test/`, `_check`, byte-exact real-profile/save non-mutation, final `PASS: All … N43B Mark Inspection` line) registered in `tests/run_all.sh` (style of :38) and `.github/workflows/godot-ci.yml` (style of :162-164). Drive the actor with `Input.action_press/release("move_left"/"move_right")` and inspect with `Input.action_press("interact")` + a frame wait — both work headless (the N4.3-A suite already proves action-press driving at :197-208). **No test has been run for this design document** — this plan is an acceptance contract for implementation (B2/B3). Completion/skip behavior is specified with separate observables: natural stage emission (`E_stage`), harness-injected delivery (`E_injected`), shell acceptance of a stage request (`A`), skip handling (`S`), and NarrativeState recording (`R`). `E_stage`, `E_injected`, and `R` are observed directly; `A` through its two externally visible effects; `S` through the skip method result and its terminal boundary effects. All observability is test-side: no production API, getter, or signal is added to make testing easier.

**Headless-automatable:**

| # | Test | Asserts |
|---|---|---|
| H1 | Inspect within valid range accepted (D1) | Drive to object A (dist < range), press interact → A recorded in per-run inspected state, distinct count 1, beat still active, **no dialogue opened**, no completion |
| H2 | Inspection rejected outside valid range | Park beyond range of every object, press interact → no id counted, no prompt, no dialogue, no completion |
| H3 | Approach without interaction does not complete | Walk the full road past all objects during pl_04 → pl_04 still active, no completion request, `NarrativeState` has no `pl_04_repeated_mark` |
| H4 | Same-object repeats never increase distinct count; two distinct objects trigger recognition exactly once (D1/D4) | Inspect A, A, A → distinct count stays 1 and no dialogue; inspect B → recognition dialogue opens **exactly once** with the approved lines; `exploration_recognition_lines()` non-empty with the approved text and the `MONARCH` speaker convention (`PrologueBeats.gd:47,96-102`) |
| H5 | Interact input during recognition is rejected | During the recognition line, press interact repeatedly → dialogue state unchanged, no duplicate emission, no inspection counted; completion still exactly once after close (D5 gate: panel open + lock held) |
| H6 | FINAL actor state after normal completion is frozen and input-disabled (D3 — corrects Rev 1 H6) | Advance through the recognition line, wait for the shell to end the segment, then assert the full terminal list of §8: panel closed; lock released (`is_dialogue_locked() == false`); completion emitted exactly once; `pl_04_repeated_mark` recorded exactly once; `_segment_ended`/`_n43_segment_ended` true; explorer input disabled (`is_input_enabled() == false`); explorer frozen (physics processing off, per `PrologueExplorer.gd:105-112`); prompt hidden; boundary status shown. **Must NOT assert restored physics processing or enabled movement** — the coroutine's transient restore is not the acceptance condition |
| H7a | Cancel BEFORE recognition records nothing | Cancel during pl_04 before any recognition dialogue has opened: no dialogue was ever opened, nothing recorded, `NarrativeState` unchanged, terminal state clean (lock released, input disabled, prompt hidden, no stale state) |
| H7b | Cancel DURING recognition records nothing | Open the recognition dialogue, then `cancel_sequence()`: panel closed, generation invalidated (the resumed coroutine emits nothing), lock released, input disabled, actor frozen, prompt hidden, **nothing recorded**, `NarrativeState` unchanged |
| H8 | Direct scene unload during recognition: lock released, nothing recorded, no stale callback — never dereferencing a freed node | N4.3-A stage-34/35 mechanism (`tests/test_n43a_exploration_stage.gd:767-796`) applied to the recognition dialogue: capture the survivors BEFORE the unload (live-stage lock state, the `PlayerControlLock` reference itself, the pre-captured `NarrativeState`, shell/explorer refs for negative `is_instance_valid` checks only), unload via `change_scene_to_file`, wait several frames, then assert on survivors only. Full steps, rationale, and the documented limitation in the H8 contract detail below |
| H9 | Invalid configuration fails closed (D6) | Unit-construct `PrologueMarkInspectables` with: empty table; fewer than two objects; an empty id; duplicate ids; a position outside `[ROAD_MIN_X, ROAD_MAX_X]` → each case: `is_valid() == false`, no props/prompt children, no crash, no partial state. Shell-level: stage setup failure falls back to the idle boundary with zero recordings and no lock (mirror of the texture-failure path, `PrologueShell.gd:379-386`) |
| H9a | Prop construction failure fails safely | Test-only subclass whose `_create_prop` returns null → `build()` fails, `is_valid() == false`, partials freed, no children committed (D6 atomic-build contract) |
| H9b | Glyph/prompt construction failure fails safely | Test-only subclasses with `_create_mark_glyph` / `_create_prompt` returning null → same fail-closed result as H9a, respectively. (The factory methods are ordinary build structure per §5; the subclasses are test code only — no production test seam is added.) |
| H10 | Completion exactly-once with distinct natural emission (`E_stage`), injected delivery (`E_injected`), request acceptance (`A`), skip handling (`S`), and recording (`R`) observables — never conflate skip with request acceptance or injected deliveries with stage emissions (D3/D4) | Four separate cases A–D (normal completion; skip during recognition; duplicate/late injected request; cancellation/teardown), each asserting its own `(E_stage, E_injected, A, S, R)` values and, where applicable, the approved ended/frozen final state. Definitions, drivers, and expected values in the H10 contract detail below |
| H11 | Third object optional; completion never requires all three (D4) | Inspect A, B → completion fires without C ever inspected; A+B+C is also valid; C alone (A+C or B+C) also completes; C inspected after completion changes nothing |
| H12 | N4.3-A pl_03 behavior remains unaffected | Quick replay of the N4.3-A core stages (chain → pl_03 → intro line → movement → handoff → pl_04 activation) to prove the new component did not perturb slice A |
| H13 | Real profile/save files remain byte-exact unchanged | Snapshot comparison of real profile/save + sidecars before/after the suite (N4.3-A convention, `tests/test_n43a_exploration_stage.gd:40-46`) |
| H14 | Held `interact` across dialogue closure does not retrigger (D5) | Open the recognition dialogue via the accepting press and keep `Input.action_press("interact")` held through panel close and segment end → no second inspection recorded, no duplicate completion emission, terminal state identical to H6 |

### H8 contract detail — valid lock-release observability after unload (Rev 2.1)

**Why the Rev 2 wording was invalid:** after the unload, the stage and the explorer are freed — `stage.is_dialogue_locked()` and any explorer query can no longer be called, and "a surviving stage reference" does not exist. The valid observable is the stage-owned `PlayerControlLock` object itself, per the ACTUAL implementation:

- `PlayerControlLock` is `RefCounted` (`PlayerControlLock.gd:2`), not a tree node: the scene unload does not free it, and a reference captured by the harness before the unload keeps it alive (RefCounted semantics — the same reason the pre-captured `NarrativeState` survives in the stage-34/35 precedent, `tests/test_n43a_exploration_stage.gd:87-91`).
- `is_locked()` exists (`PlayerControlLock.gd:64-65`); `unlock()` is the only method that clears `_locked` on this path (`:45-52`; `_release_locked_target()` :56-61 fires only on a target switch, which never happens here), and the stage releases the lock during `teardown()` via `close_active_dialogue()` (`PrologueExplorationStage.gd:143-144`; teardown :165-174; `_exit_tree` :177-180 runs synchronously inside the unload).
- **Documented limitation and smallest viable strategy:** the stage exposes lock state only through `is_dialogue_locked()` on a LIVE stage (`PrologueExplorationStage.gd:191-192`); there is no public getter for the lock object. Smallest viable test-side strategy: capture the lock reference from the live stage with `Object.get("_dialogue_lock")` before the unload (a plain member read — no production API, no script change, no new seam) and assert on that surviving RefCounted afterwards. No `is_locked()`-style API is added to production; if the private member is ever renamed, the capture assert fails loudly (`lock_ref == null`), an acceptable test-side coupling.

Steps (recognition dialogue OPEN, reached per H4):

1. Capture while every object is alive: `lock_ref := stage.get("_dialogue_lock")`; assert `lock_ref != null` and `lock_ref.is_locked()` and `stage.is_dialogue_locked()` (mirrors the stage-34 pre-unload check, `tests/test_n43a_exploration_stage.gd:775`); capture `state_ref := shell.call("narrative_state")` (public getter, `PrologueShell.gd:160-162`); capture shell and explorer references ONLY for negative validity checks.
2. Unload exactly as the precedent does: `change_scene_to_file(MAIN_SCENE)` (`:781`), then wait several process frames.
3. Assert on survivors only — never dereference the freed shell/stage/explorer: `not is_instance_valid(unloaded_shell)` and `not is_instance_valid(explorer_ref)` (negative checks, precedent `:790`); `lock_ref.is_locked() == false` — direct evidence that `unlock()` ran during the unload's synchronous teardown, because nothing except `unlock()` clears `_locked` and the unload itself never touches the surviving RefCounted; `state_ref.completed_count()` unchanged and `not state_ref.is_completed("pl_04_repeated_mark")` (precedent `:791`); and across those frames no further emission or recording occurs — any stale-callback activity or invalid access would surface as script errors in the run output under the suite's zero-error convention (the stage-34/35 precedent asserts the same class of outcome).

### H10 contract detail — natural emission, injected delivery, request acceptance, skip handling, and recording (Rev 2.2)

Five distinct observables, all test-side; no production observability API is added:

- **`E_stage` — natural stage emission count.** A harness listener connected to the stage's `mark_inspection_completed` request signal increments `E_stage` only when the harness is NOT inside its explicit injection helper. The helper sets an `_injecting_completion_request` guard before calling `.emit()` and clears it immediately afterwards; the listener ignores deliveries while that guard is set. Thus only emissions initiated by the stage increment `E_stage`, while direct test injections increment `E_injected` at their call site.
- **`E_injected` — harness-injected signal delivery count.** Test code that directly invokes `stage.mark_inspection_completed.emit()` increments a separate harness counter at the injection site. These deliveries exercise the shell boundary but are NOT emissions produced by the stage and MUST NOT be added to `E_stage`.
- **`A` — shell acceptance count for stage completion requests.** `A` means only that the shell accepts a `mark_inspection_completed` request from the stage while the beat is active and records/ends it through the normal request handler. The shell exposes no acceptance signal; an exact per-call counter would require a test-only shell subclass or a new production signal, both rejected. Acceptance is therefore observed through its ONLY two externally visible effects, asserted together: the segment-state transition (`active_exploration_beat()` → `""`, `n43_segment_complete()` → true, boundary status; public getters `PrologueShell.gd:343-360`) and the recording it triggers (`R`). For a request delivery after the beat is already ended, `A` does not increase.
- **`S` — skip-path handling count.** `S` means `skip_current_exploration_beat()` successfully handles the skip and reaches its defined terminal boundary. It is observed through the method's true return value plus the boundary/recording effects. A skip is NOT a stage completion request, so it MUST NOT increment `A`.
- **`R` — NarrativeState recording count/delta.** The pre-captured `NarrativeState` reference (RefCounted, survives freed scenes — precedent `tests/test_n43a_exploration_stage.gd:87-91`) supplies `is_completed("pl_04_repeated_mark")` and `completed_count()` deltas (`NarrativeState.gd:21-25`).

`A` and `S` are mutually distinct route observables: normal stage-request completion increments `A`; successful skip increments `S`. Both routes can result in `R=1`, but the recording alone does not identify which route handled the beat.

Scenarios (each a separate case; D1–D6 and the §8 chain unchanged):

| Scenario | Driver | `E_stage` | `E_injected` | `A` | `S` | `R` | Final state |
|---|---|---:|---:|---:|---:|---:|---|
| A — normal recognition completion | Inspect two distinct objects (H1/H4 flow); natural-emission listener attached before the accepting press | 1 — only after the recognition panel closed (listener asserts `not panel.is_open()` at emission time: record-after-dialogue ordering, §4 item 7) | 0 | 1 — one stage request accepted and one transition to the ended boundary | 0 | 1 — `completed_count()` +1, contains pl_04 | H6 terminal list (frozen, input-disabled) |
| B — skip during recognition dialogue | Open the recognition dialogue, then call `skip_current_exploration_beat()` while the panel is open | 0 — stage never emits its normal completion request on this path; assert across several frames to catch stale-coroutine emission | 0 | 0 — no stage completion request is accepted | 1 — skip method returns true and reaches the boundary | 1 — exactly once through skip; duplicate skip is rejected and records nothing (`tests/test_n43a_exploration_stage.gd:525-526`) | Ended/frozen boundary (H6 terminal list) |
| C — duplicate or late injected completion request | After A or B has completed the beat, directly force-deliver `stage.mark_inspection_completed.emit()` twice; optionally inject a third after `request_main_menu_return()` while the test exit-transition hook holds the scene in place | 0 additional — the stage itself emits nothing after completion | 2 (plus optional third) — counted only by the harness at each forced injection site, never as natural stage output | 0 additional — inactive-beat / segment-ended / exit guards reject every injected delivery (`PrologueShell.gd:397-402` pattern; `_exploration_beat` is `""`) | 0 additional | 0 additional — recording remains exactly 1 total | Boundary unchanged; subsequent inert probes remain unchanged |
| D — cancellation or teardown before completion | H7a (cancel before recognition), H7b (cancel during recognition), H8 (direct unload during recognition) | 0 before cancellation/unload and still 0 afterwards | 0 | 0 | 0 | 0 — pre-captured `NarrativeState` unchanged, readable post-unload via surviving ref | H7 terminal state / H8 survivor assertions; no freed object dereferenced |

**Important interpretation rule:** Scenario C's direct `.emit()` calls are test-forced deliveries at the shell boundary. They test rejection of duplicate/late requests; they do not prove that the stage naturally emitted twice. The stage's one-shot guard is separately covered by `E_stage` remaining unchanged. If the harness cannot distinguish signal origin at the listener, it MUST count injections at the explicit test call sites rather than merging them into the natural-emission listener.

Trust-boundary note (unchanged): the shell's acceptance guards validate the active beat, exit state, and idempotence — not the dialogue lifecycle. The "emit only after a normal close" discipline is owned by the stage's one-shot flag (§8 layer 1), which scenario A asserts (`E_stage` fires only after the panel closes). A request force-emitted while the recognition dialogue is still open would therefore be accepted by the shell — the same trust the pl_03 handshake already grants (`PrologueShell.gd:396-405`); that is a forced delivery, not a duplicate/late case, and is not asserted as rejected.

**Manual / windowed-only (Xvfb or real display; NOT claimable from headless runs):**

- Prompt appears/disappears exactly at the range boundary on approach and retreat, and sits above the nearest object when two objects are near.
- Mark glyph renders identically (shape) on all three props at zoom 1.5 in both walking directions.
- No prompt and no "[E]" affordance during pl_03.
- Recognition line visually holds the actor still (no drift while locked).
- The pl_04 detail label no longer claims "Mark inspection is not implemented yet".

---

## 10. Implementation Slices

Keep each step reviewable and green (`N4_3_PLANNING.md:185`). Ownership is fixed (owner review): **B1 owns no interaction input, no recognition dialogue, and no completion; B2 owns all three; B3 owns verification and documentation.**

1. **B1 — Inspectable set only (no interaction, no dialogue, no completion).** `PrologueMarkInspectables.gd`: authored table, fail-closed atomic `build()` (D6: table validation + three factory methods + commit-after-verify), placeholder props + identical mark glyph, range query, idempotent per-id marking state, shared prompt label; stage builds + renders it (pl_03 scenery, pl_04 activation hook), prompt gating in `_physics_process`. **Explicitly excluded: `interact` handling, distinct-two trigger, recognition dialogue, completion signal, shell changes.** Tests: H9/H9a/H9b, prompt gating unit checks, pl_03 unchanged (H12 start).
2. **B2 — Interaction input, recognition dialogue, and completion.** `interact` polling behind the full D5 gate in the stage's `_physics_process`; distinct-id tracking; the D2 recognition sequence (stage-owned lock + generation guard + approved text via `PrologueBeats.exploration_recognition_lines()`); one-shot `mark_inspection_completed()` request; shell `_on_mark_inspection_completed()` handler + terminal boundary end; prompt/inspection disable on `end_segment`/`teardown`; pl_04 detail-label text update. Tests: H1–H8, H10–H11, H14.
3. **B3 — Suite registration, full regression, CI, visual verification, documentation sync.** Register the new suite in `tests/run_all.sh` + `.github/workflows/godot-ci.yml`; run the full `run_all.sh` + verifier and report results as actually executed; perform the windowed visual pass (manual list in §9) and report only what was actually inspected; update the N4.3-B status lines in `docs/narrative/N4_3_PLANNING.md` (§Status/§7), `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (§A/§E + N0 implemented-beats row), `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md`, `docs/CHANGELOG.md` — the same doc set N4.3-A touched.

The PR states it implements N4.3-B (planning :205). **N4.3-C (full-flow integration/regression planning and implementation) stays out of scope for all three slices.**

---

## 11. Narrative Decisions

### Approved by owner review (binding; no longer OPEN)

| # | Decision | Authority | Consequence for implementation |
|---|---|---|---|
| D1 | Individual inspection is silent: no per-object dialogue, notification, or response; first inspection records the id; re-inspection is an idempotent no-op; recognition only after two DISTINCT objects | Owner review (Rev 2) | Resolves former U1 and U3. No per-object lines are authored; the component's per-id state is the only inspection feedback besides the prompt. No structure change would be needed if a per-object line were ever approved later. |
| D2 | Recognition dialogue lifecycle and text | Owner review + approved candidate text (`PROLOGUE_STORY_DESIGN.md:107-109`) | The nine-step sequence of §4 item 6 is binding; only the already-approved text may be used. Speaker presentation follows the existing exploration convention (`MONARCH`, `PrologueBeats.gd:47,96-102`), which settles the former U6 presentation question without inventing lore. |
| D3 | Final acceptance state is the ended/frozen boundary state | Owner review (Rev 2) | Corrects Rev 1 H6; see §7 step 6 and §8. |

### Remaining OPEN (must not become canon without owner approval)

| # | Decision | Status | Constraint |
|---|---|---|---|
| U2 | Mark visual design (shape, size, color) | OPEN (`PROLOGUE_STORY_DESIGN.md:253`; planning §8) | Labelled 2-rect placeholder glyph, geometrically identical on all three props; visual consistency required; meaning stays mysterious. |
| U4 | Prop placement values and exact prop staging | OPEN (staging suggestions only, planning :65-70) | The §6 positions (A≈430, B≈630, C≈−280) are tunable proposals; only "three distinct ancient objects along or just beside the road" is fixed. |
| U5 | Prompt wording | OPEN (not authored anywhere) | Placeholder `[E] Inspect` labelled as placeholder; final text owner-approved. |

No other narrative decision remains unresolved for N4.3-B. Lore discipline is unchanged: the symbol is recognizable and recurring; its origin and deeper meaning stay unknown (`PROLOGUE_STORY_DESIGN.md:111`; planning :9).

---

## 12. Files Expected to Change During Implementation

**New:**
- `scripts/narrative/PrologueMarkInspectables.gd` (+ `.uid`)
- `tests/test_n43b_mark_inspection.gd` (+ `.uid`)

**Modified:**
- `scripts/narrative/PrologueExplorationStage.gd` — inspectable wiring in `setup()`; pl_04 interact/proximity block in `_physics_process` (full D5 gate list); recognition-dialogue presentation per D2 (new, cloned from `_present_intro_dialogue` :231-251); one-shot completion flag + `mark_inspection_completed()` signal; prompt/inspection disable in `end_segment()`/`teardown()`
- `scripts/narrative/PrologueShell.gd` — `_on_mark_inspection_completed()` handler; pl_04 detail-label text (:486); no changes to skip/cancel/exit signatures
- `scripts/narrative/PrologueBeats.gd` — `exploration_recognition_lines()` (data only, lore-disciplined, approved text only)
- `tests/run_all.sh`, `.github/workflows/godot-ci.yml` — suite registration
- Docs status sync: `docs/narrative/N4_3_PLANNING.md`, `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`, `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md`, `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md`, `docs/CHANGELOG.md`

**Explicitly unchanged:** `project.godot` (`interact` already exists, :42-44), `scripts/narrative/NarrativeState.gd`, `scripts/narrative/PlayerControlLock.gd`, `scripts/narrative/DialoguePanel.gd`, `scripts/narrative/SequenceRunner.gd`, `scripts/narrative/PrologueExplorer.gd` (inspection polls in the stage; the actor stays movement-only), `scenes/narrative/PrologueShell.tscn` (stage and props are code-built), and everything under `scripts/player/`, `scripts/world/`, save/profile code.

---

**Document conflict check (Rev 2):** no conflict was found between this design and `docs/narrative/N4_3_PLANNING.md` (its §3 interaction rules, §4 orchestration/skip/lock contracts, and §7 slice definitions all remain satisfied — D1 matches planning :78-79, D2 matches :119, D3 matches the pl_04 boundary at :120/:127, D4 matches :55-57/:80-81, D5 matches :75-77 plus the input-isolation contract in `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §D, D6 matches the fail-closed setup convention at :170 and the texture-failure fallback already shipped in N4.3-A). No other planning document was modified.