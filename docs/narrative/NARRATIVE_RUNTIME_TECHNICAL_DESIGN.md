# Crownfall — Narrative Runtime Technical Design

**Status:** Technical contract for the implemented N1–N3 runtime + N0 production contract (story/entry-flow items remain DECIDED / PROPOSED / OPEN as marked). N4.0 (entry gate + player profile), N4.1 (functional Prologue shell), N4.2 (beats pl_01 + pl_02 with shell auto-start/chaining), N4.3-A (exploration stage + actor + pl_03/pl_04 orchestration), N4.3-B (three mark inspectables, silent per-id inspection, two-distinct recognition line, exactly-once pl_04 completion), and N4.3-C (full-flow integration & regression) are implemented; N4.4–N4.6 are not.  
**Baseline (updated 2026-11-18):** branch `feature/n43c-full-flow-integration-regression` (based on `main` @ `27a0ba0`, the PR #20 N4.3-B merge), Godot `4.7.2.stable`. N4.0–N4.2 and N4.3-A/B/C are implemented; N4.4–N4.6 are not. Earlier baseline references are historical.  
**Story source:** [`PROLOGUE_STORY_DESIGN.md`](PROLOGUE_STORY_DESIGN.md) — content authority for the Prologue.  
**Implementation plan:** [`../NARRATIVE_IMPLEMENTATION_ROADMAP.md`](../NARRATIVE_IMPLEMENTATION_ROADMAP.md) phases N0–N5. This document owns the *technical* decisions for the N1–N3 runtime foundation; the roadmap owns phase sequencing.

> No lore is invented here. Visual/story details not yet approved are labelled PROPOSED/OPEN. The coding agent must not convert an OPEN item into canon.

---

## A. New Game / Continue entry flow

### Current implementation (verified)

- `scripts/core/Main.gd` — Start New Game first keeps the DECIDED (D3) overwrite confirmation when a valid world save exists (Cancel stays in the menu). After the confirmation point it consults the global player profile (entry gate): if `prologue_completed_once` is false (including missing/corrupt data), it routes to `res://scenes/narrative/PrologueShell.tscn` with `crownfall_load_on_start = false` and offers no Skip; if true, it offers **Play Prologue Again** / **Skip Prologue** / Cancel. Play Prologue Again routes to the same Prologue route target; Skip starts a fresh Forgotten Shore session (`crownfall_load_on_start = false`, profile flag untouched). Continue sets `crownfall_load_on_start = true` and goes straight to Forgotten Shore — it never reads the profile.
- `scripts/world/ForgottenShoreSession.gd` (`_consume_pending_load_if_requested`) loads the existing save silently when the flag is set. The session owns the load path and is unchanged in N4.0.
- `SaveManager` uses schema v2; the world save lives at `user://save_slot_0.json`.
- `scripts/narrative/PlayerProfile.gd` (N4.0) — minimal global profile at `user://player_profile.json`: `{"schema_version": 1, "prologue_completed_once": false}`. API: `load_profile(path) -> Dictionary {ok, error}`, `is_prologue_completed_once() -> bool`, `mark_prologue_completed(path) -> bool` (reports persistence success). Strict validation; any missing/malformed/unsupported-version/unreadable data reads as "not completed"; atomic `.tmp` → verify → staged rename with rollback; unsafe paths rejected. `SaveManager` and schema v2 are unchanged.
- `scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd` — **N4.1 functional shell** at the N4.0 route target: owns a per-run `NarrativeState` (in-memory, discarded with the scene — non-resumable per §A/B), a `DialoguePanel`, and a `SequenceRunner` whose `change_scene` op is allowlisted to `res://scenes/world/ForgottenShore.tscn` (the future N4.5 handoff) and routed through `PrologueShell.set_exit_transition(Callable)` / `Main.set_route_transition(Callable)` for headless observation. `play_sequence` / `skip_sequence` / `cancel_sequence` are the presentation contract for N4.2+ beat content (no sequence data is authored or shipped in N4.1). A single-transition exit guard (`_begin_exit` + `is_exit_started`) makes duplicate exit/handoff requests no-ops; runtime init is idempotent per scene instance. Exit semantics are split: a **development exit** cancels a running sequence (deterministic cleanup, completes nothing), while a **sequence-driven handoff** never cancels the finishing sequence — the runner is inside its `change_scene` op and must still run `_finalize_completion()`, so `sequence_completed` fires exactly once and the `NarrativeState` records the sequence (regression-tested). A labelled **development-only** "Return to Main Menu (Development Exit)" button keeps the build from dead-ending: it never marks completion, never writes the profile, and never touches world saves. N4.2 wires the first authored beats (`scripts/narrative/PrologueBeats.gd`, NarrativeData-validated data only): the shell auto-plays the first uncompleted beat on route load (Engine meta `crownfall_prologue_autostart` override for headless suites), chains pl_01 → pl_02 exactly-once via `sequence_completed` with next-beat discovery (`_next_beat_id`) separated from next-beat playback (`_play_next_beat`), stages cues on a labelled placeholder stage through the existing `play_cue` op (no new runner ops, no assets), and marks the N4.2 boundary ONLY when discovery finds no next authored beat after the completed beat — N4.3-A extends the shell with the exploration segment (Engine meta `crownfall_prologue_exploration`, default ON; `crownfall_prologue_stage_texture` for failed-setup injection): the structural chain end after pl_02 hands off to `PrologueExplorationStage` + `PrologueExplorer` on the bounded ancient road; the shell routes `pl_03_wanderer`/`pl_04_repeated_mark` as shell-orchestrated exploration beats (deliberately outside `BEAT_IDS`, so the runner can never chain or record them), stays the sole writer of their `NarrativeState.mark_completed()` records (one validated stage request per interval, duplicates ignored), presents pl_03's approved internal line through the DialoguePanel with the stage-owned `PlayerControlLock` on the actor, and exposes the narrow `skip_current_exploration_beat()` path; cancellation, dev exit, unload, and failed setup record nothing and release locks (freed-safe). Routing, gate, and overlays are unchanged from N4.0. N4.3-B adds the pl_04 mark-inspection handshake on the same shell: the exploration stage polls the existing `interact` action behind the full beat/teardown/segment/input/panel/lock/range/just-pressed gate, and `_on_mark_inspection_completed()` validates the ACTIVE exploration beat and records `pl_04_repeated_mark` exactly once before ending the segment at the same defined boundary as the skip (duplicate, inactive-beat, and post-exit requests are ignored).
- N4.0 automated evidence: `tests/test_n40_profile_entry_gate.gd` (66 checks, profile behavior + entry flow + fresh-session + placeholder sanity), registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`; the M8 integration slice now enters Forgotten Shore through the real Skip path (pre-completed injected profile). The actual nine Prologue beats are NOT implemented; N4.0 does not mark completion anywhere in its runtime flow.

### Decision — DECIDED (foundation scope)

1. **Continue:** unchanged. Directly loads the existing world save. Existing saves are never forced to replay anything narrative.
2. **Start New Game:** for the foundation, still routes to Forgotten Shore (no Prologue wiring yet — Prologue entry is an N4 task). **New safety behavior:** if a valid world save exists, Start New Game shows a confirmation (“starting a new game replaces the saved reign on the next save”) before proceeding. This prevents silently destroying a valid save via a later autosave.
3. **Prologue routing (N4):** Start New Game runs the Prologue unless the player profile records a previously completed Prologue and the player chooses Skip. Continue bypasses the Prologue entirely and loads the existing world save. After completion or an eligible skip, enter a *fresh* Forgotten Shore session. **DECIDED — owner approval, 2026-11-17.**
4. **Prologue resumability:** linear, **non-resumable** — no mid-Prologue world save; exiting mid-Prologue restarts it on the next Start New Game. **DECIDED — owner approval, 2026-11-17.**
5. **Skip eligibility:** Skip is unavailable on the first-ever playthrough. It becomes available only after the player completes the Prologue once. Skipping does not itself grant or revoke eligibility. **DECIDED — owner approval, 2026-11-17.**

---

## B. Narrative state — is persistence needed?

### Analysis

- The Prologue is linear and non-resumable, but the player must be allowed to start a fresh world without replaying it after completing it once.
- The durable fact “this installation/profile has completed the Prologue at least once” must survive New Game replacing the world save. It cannot be inferred from the existence of `save_slot_0.json`.
- Per-run sequence completion remains in-memory in `NarrativeState`; the cross-run eligibility fact belongs to a small global player profile, separate from any world save.
- `SaveManager` schema v2 remains unchanged; no narrative fields are added to world-save data.

### Decision — DECIDED

1. Keep `SaveManager`, `ProgressionState`, and world-save schema v2 unchanged.
2. `NarrativeState` remains in-memory and records per-run sequence completion only; it is not serialized.
3. Add a minimal persistent **player-profile** flag (separate from world saves), e.g. `prologue_completed_once`, stored under `user://` with a small versioned/validated format and safe atomic writes. This is global first-playthrough metadata, not world progression.
4. Set the flag only after the full Prologue reaches its successful completion/handoff path. A skip must never set it.
5. If the profile file is missing, invalid, or unreadable, fail safely by treating the Prologue as not yet completed (Skip remains locked); do not block New Game or corrupt/overwrite a world save.
6. Exiting mid-Prologue loses only per-run progress; the next New Game starts the Prologue from the beginning. No resume checkpoint is stored.

---

## C. Narrative event and sequence ownership

### Decision — DECIDED ownership boundaries

| Owner | Responsibility | Does NOT |
|---|---|---|
| `Main` / menu | Entry routing + overwrite confirmation | Owns no dialogue or gameplay rules |
| `NarrativeData` (new) | Sequence/step schema validation, JSON loading, fail-closed data | Executes nothing |
| `NarrativeState` (new) | In-memory, per-run completed-sequence set | Persists nothing |
| `PlayerProfile` (new, minimal) | Global first-playthrough metadata; stores `prologue_completed_once` independently of world saves | Stores no kingdom/gameplay progress; does not replace `SaveManager` |
| `DialoguePanel` (new) | Speaker/body/advance presentation, input consumption, cleanup | Grants resources/unlocks; never touches gameplay state |
| `PlayerControlLock` (new) | Lock/unlock a character's physics + unhandled input | Owns world state |
| `SequenceRunner` (new) | Orchestrates typed, allowlisted steps; completion exactly once; skip/cancel cleanup | Implements gameplay rules |
| `ForgottenShoreSession` | Remains the world orchestrator | Gains no narrative responsibilities |
| `ShoreView` / `ShoreFX` | Remain world presentation helpers | Are not narrative controllers |

No global EventBus, no generic quest engine, no branching dialogue, no chapter manager. Local signals and direct references are sufficient.

---

## D. Dialogue input

### Decision — DECIDED

1. New input action **`dialogue_advance`** (Enter, Left Mouse Button). Added to `project.godot`; no existing action is repurposed.
2. `DialoguePanel` is a separate `CanvasLayer` (layer 100, `PROCESS_MODE_ALWAYS`) — never `ClockHUD.FeedbackLabel`, which stays the gameplay feedback channel (`scripts/ui/ClockHUD.gd:11,125`).
3. While open, the panel consumes **all** unhandled input (`set_input_as_handled()`) and advances only on `dialogue_advance`. It never forwards events to gameplay.
4. `PlayerControlLock` additionally disables the target's physics processing and unhandled-input processing while a sequence runs, so held movement and discrete action keys cannot move/build/collect/recruit during dialogue. Both are restored on close/cancel/scene unload.
5. Pause: panel runs with `PROCESS_MODE_ALWAYS`, so it remains interactive while the tree is paused; closing/unlocking after resume works deterministically.

First version: text-only (speaker, body, advance hint). No portraits, voice, choices, history. **PROPOSED** items for later N4/N5.

---

## E. Sequence runner

### Decision — DECIDED (typed, allowlisted operations)

Supported step operations (validated by `NarrativeData`, enforced by `SequenceRunner`):

| Op | Payload | Behavior |
|---|---|---|
| `dialogue` | `lines: [{speaker, text}]` | Opens the panel with the lines and waits until the player advances through all of them |
| `wait` | `seconds` (finite, 0–60) | Frame-counted wait (interruptible by skip/cancel; no `Timer` nodes) |
| `lock_control` | — | Locks the bound control target (idempotent) |
| `unlock_control` | — | Unlocks it (idempotent) |
| `play_cue` | `cue_id` | Calls the injected cue player callable (no-op if none configured) |
| `change_scene` | `scene_path` | Calls the injected transition callable (default: `get_tree().change_scene_to_file`) at most once per sequence; path must be in the runner's scene allowlist |
| `finish` | — | Ends the sequence |

Explicitly excluded (no arbitrary script execution, no eval, no JSON-driven GDScript, no camera scripting yet): `camera_focus` is **PROPOSED** for N4 staging and is not part of the foundation.

### Guards — DECIDED

- Data is schema-validated before playback; unknown ops/fields fail closed at load.
- Completion emits `sequence_completed` **exactly once** per run (guarded by `NarrativeState`).
- `SequenceRunner.skip()` remains a per-sequence runtime operation: it closes dialogue, executes pending `change_scene` at most once, restores control, then completes exactly once. Whole-Prologue Skip is a separate New Game menu decision: hidden on the first-ever playthrough and offered only after `PlayerProfile.prologue_completed_once` is true. Individual beat/cutscene skip flags remain content-level N4 decisions.
- `cancel()`: restores control and closes the panel without completion (used by scene unload/exit).
- `_exit_tree` always runs cleanup; no leaked state, no orphan timers (waits are frame-counted).
- Signal ids are snapshotted into locals before `sequence_started` / `sequence_completed` / `sequence_failed` emission: a handler that starts another run mid-emission (the shell's beat chain does exactly that on completion) reassigns `_current_id`, and later listeners must still observe the id the signal is about.
- N4.3-A exploration dialogue uses a dedicated stage-owned `PlayerControlLock` on `PrologueExplorer` (the runner keeps the shell as its control target for pl_01/pl_02): the lock disables the actor's physics + unhandled-input processing while the stage presents the intro line through the shared `DialoguePanel`, and it is released on completion, skip, cancel, exit, and teardown. The stage's presentation coroutine is generation-guarded and re-validates the explorer (`is_instance_valid`) after every `dialogue_finished` resume — a runner-side panel cleanup during an exit or a freed actor can never crash or re-enable movement (regression-tested). A direct scene unload with the dialogue open takes the same `teardown()` path via the stage's `_exit_tree` and records nothing (regression-tested without any cancel/dev-exit path). N4.3-B's recognition line reuses the same stage-owned lock and generation-guard discipline, and its completion request is emitted only after a normal close; `cancel_sequence()` aborts the exploration segment BEFORE the runner cleanup because the runner's `_cleanup()` closes the shared panel unconditionally — arming the stage guard first is what keeps a cancelled recognition from recording anything (regression-tested: cancel during the recognition dialogue records nothing, and no delayed emission follows).
- N4.3-A camera framing (review fix): movement bounds and camera limits are authored as separate explorer parameters, and the explorer camera uses **no `Camera2D.offset`** — Godot applies offset AFTER limit clamping (verified on 4.7.2: an offset of -80 produced a visible band of `[-320, 160]` against limits of `[-240, 240]`). `limit_left/right/top/bottom` do clamp the visible viewport edges while the limit band is larger than the view (at the road start the visible left edge rests exactly on the limit), and the stage backdrop/road art additionally extend 4096 px past the band on every side so no viewport configuration exposes empty space. The suite measures the actual visible rect (`get_screen_center_position()` ± viewport/zoom) at the road start, the west bound, and the east bound and asserts containment.
- N4.3-C UI layering (integration fix): the shell's CenterContainer UI (status labels + the development exit button) renders on the `UICanvasLayer` CanvasLayer instead of the default canvas. The exploration Camera2D transforms the default canvas, which displaced the whole shell UI outside the viewport during pl_03/pl_04 and at the boundary (demonstrated by the N4.3-C windowed pass: status labels and the dev exit invisible/unreachable during exploration — the N4.3-B changelog had noted the camera-transformed labels and deferred the UI change to this slice). The DialoguePanel already used a CanvasLayer (layer 100); the shell UI now uses layer 1 (above the world canvas, below the panel). The N4.3-C suite asserts the button's true screen rect stays inside the viewport during exploration while the world actor is camera-displaced (contrast proof), in addition to the visual-pass screenshots.
- Bounds: ≤128 steps per sequence, ≤256 dialogue lines, wait ≤60s, text ≤512 chars, speaker ≤64 chars — no unbounded hangs.

---

## F. Simulation and pause

### Decision — DECIDED

1. **Prologue scenes (future N4)** will be standalone scenes *before* Forgotten Shore: no `TimeManager`, no night encounter, no economy ticking. World simulation therefore does not run during the Prologue by construction.
2. **Gameplay-embedded dialogue (future N5)** policy: world simulation **continues** while dialogue is open; sequences that need the world paused must request it explicitly (a `pause_world` op is **PROPOSED**, not implemented in the foundation). Tests use `auto_advance = false` for determinism.
3. `get_tree().paused` (player pause menu) pauses the world as today; the dialogue panel remains interactive under `PROCESS_MODE_ALWAYS`, and the runner is paused with the tree unless it is explicitly marked otherwise (foundation: runner inherits, so player pause freezes sequence timers — documented, deterministic).

---

## N0 — Production contract (beat table)

Source: `PROLOGUE_STORY_DESIGN.md` §4/§6. All content is PROPOSED until owner approval; IDs are stable for tooling.

| Beat ID | Beat title | Entry condition | Player control | Narrative content | Expected outcome | Exit condition | Skip | Save | Test requirement |
|---|---|---|---|---|---|---|---|---|---|
| `pl_01_lost_world` | The Lost World | New Game start | Locked | Opening cinematic: former glory → Great Eclipse → ruin (narration candidate exists) | Player understands Aetherion fell | Cinematic ends | Allowed (PROPOSED) | None (non-resumable) | Runs once on New Game; Continue skips; vision content does not reveal protected mysteries |
| `pl_02_faint_resonance` | A Faint Resonance | pl_01 finished | Locked | Childhood flashback: one small uncontrolled manifestation | Resonant motif established | Scene ends | Allowed (PROPOSED) | None | One manifestation only; no spellcasting/control shown |
| `pl_03_wanderer` | The Wanderer | pl_02 finished | Interactive | Movement + observation; sparse internal line | Search motivation established | Reach exit/trigger | Allowed (PROPOSED) | None | Movement works; no gameplay systems leak in |
| `pl_04_repeated_mark` | The Repeated Mark | pl_03 finished | Interactive | Inspect repeated royal symbol on 2–3 props | Pattern recognized | Inspect all marks | Allowed (PROPOSED) | None | Symbol identical across props; meaning stays mysterious |
| `pl_05_forgotten_ruins` | The Forgotten Ruins | pl_04 finished | Interactive | Explore ruin → hidden chamber → altar | Crown found on altar | Reach altar | Allowed (PROPOSED) | None | No NPC explains history; environment does the work |
| `pl_06_crowns_call` | The Crown's Call | pl_05 finished | Interaction then cinematic | Touch crown → awakening + fragmented vision | Power awakens; vision raises questions | Vision ends abruptly | Not allowed for the vision moment (PROPOSED) | None | Vision excludes ruler identity, dynasty, power source, crown origin, Eclipse cause |
| `pl_07_unfinished_journey` | The Unfinished Journey | pl_06 finished | Limited/cinematic | Departure to sea | Search continues | Transition ends | Allowed (PROPOSED) | None | Destination/ship origin not stated |
| `pl_08_shipwreck` | The Shipwreck | pl_07 finished | Locked | Storm + wreck, fade before excess | Stranded | Fade out | Allowed (PROPOSED) | None | Storm-cause link to crown stays unknown |
| `pl_09_forgotten_shore` | Forgotten Shore | pl_08 finished | Interactive (handoff) | Wake on beach, wreckage, crown continuity, title card “CHAPTER I — FORGOTTEN SHORE” | Control returns; Chapter I begins | Player control returned | Not applicable | World save begins only after landing | Crown shown, not explained; handoff into existing Forgotten Shore session |

Additional contract rows (DECIDED unless marked):

- **Implemented beats:** `pl_01_lost_world` and `pl_02_faint_resonance` are implemented as of N4.2 (see §A); as of N4.3-A, `pl_03_wanderer` and `pl_04_repeated_mark` play as shell-orchestrated exploration beats (bounded movement + handoff-area completion), and as of N4.3-B pl_04 adds the three mark inspectables with silent idempotent per-id inspection and the two-distinct recognition line completing the beat exactly once; N4.3-C adds no beats — it verifies the pl_01–pl_04 flow end to end; pl_05–pl_09 remain future work.

- **New Game behavior:** confirmation when a valid world save exists; run Prologue if `PlayerProfile.prologue_completed_once` is false. If true, offer Skip or Play Prologue; Skip is never shown on the first playthrough.
- **Continue behavior:** direct world-save load; never replays the Prologue.
- **Exit/restart:** exiting mid-Prologue discards per-run progress (non-resumable); next New Game restarts it from pl_01.
- **Completion marker:** set `PlayerProfile.prologue_completed_once = true` only on successful completion/handoff. Preserve it across world-save deletion/replacement and New Game.
- **Pause:** allowed; dialogue panel stays interactive; sequence waits freeze with the tree.
- **Scene transition:** explicit, allowlisted `change_scene` op; handoff to Forgotten Shore creates a fresh session and starts world saves only then.
- **Input ownership:** dialogue consumes all unhandled input while open; control lock disables movement/commands; both restored on close/cancel/skip/unload.
- **Crown continuity:** crown is a visual continuity element only; no inventory system; its survival is never explained in dialogue.

### Decision record summary

| # | Decision | Status | Rationale |
|---|---|---|---|
| D1 | Per-run `NarrativeState` remains in-memory; one global profile completion flag persists separately | DECIDED | Skip eligibility must survive New Game replacing world saves |
| D2 | SaveManager/ProgressionState/world schema v2 unchanged | DECIDED | Prologue completion is profile metadata, not kingdom progression |
| D3 | New Game overwrite confirmation | DECIDED | Protects existing saves before Prologue wiring exists |
| D4 | `dialogue_advance` action (Enter/LMB); panel consumes input; control lock | DECIDED | Input isolation without touching gameplay handlers |
| D5 | Typed allowlisted sequence ops; frame-counted waits; injected cue/transition callables | DECIDED | Deterministic, testable, no eval/scripting, no leaked timers |
| D6 | Skip completes exactly once; change_scene at most once; cancel without completion | DECIDED | Idempotence + cleanup safety |
| D7 | New Game → Prologue; Continue bypasses; non-resumable Prologue | DECIDED | Owner approval, 2026-11-17 |
| D8 | Skip locked until one successful Prologue completion; completion flag stored in separate player profile | DECIDED | Owner approval, 2026-11-17; flag survives New Game and is not set by skipping |
| D9 | Camera-focus op and pause_world op | PROPOSED | Deferred; not needed by foundation tests |
| D10 | All Prologue content/staging details | PROPOSED/OPEN | Per `PROLOGUE_STORY_DESIGN.md` §10 OPEN table |
| D8 | Camera-focus op and pause_world op | PROPOSED | Deferred; not needed by foundation tests |
| D9 | All Prologue content/staging details | PROPOSED/OPEN | Per `PROLOGUE_STORY_DESIGN.md` §10 OPEN table |
