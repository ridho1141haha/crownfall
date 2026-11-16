# Crownfall — Narrative Runtime Technical Design

**Status:** PROPOSED technical design + N0 production contract (decisions marked DECIDED / PROPOSED / OPEN).  
**Baseline:** `main` @ `6d209970170a9f1fa21946385c79ad02d5fb437d` (after PR #10 merge), Godot `4.7.2.stable`.  
**Story source:** [`PROLOGUE_STORY_DESIGN.md`](PROLOGUE_STORY_DESIGN.md) — content authority for the Prologue.  
**Implementation plan:** [`../NARRATIVE_IMPLEMENTATION_ROADMAP.md`](../NARRATIVE_IMPLEMENTATION_ROADMAP.md) phases N0–N5. This document owns the *technical* decisions for the N1–N3 runtime foundation; the roadmap owns phase sequencing.

> No lore is invented here. Visual/story details not yet approved are labelled PROPOSED/OPEN. The coding agent must not convert an OPEN item into canon.

---

## A. New Game / Continue entry flow

### Current implementation (verified)

- `scripts/core/Main.gd:18-27` — Start New Game sets `crownfall_load_on_start = false` and calls `change_scene_to_file("res://scenes/world/ForgottenShore.tscn")`; Continue sets it to `true` and does the same.
- `scripts/world/ForgottenShoreSession.gd:1252` (`_consume_pending_load_if_requested`) loads the existing save silently when the flag is set.
- `SaveManager` uses schema v2; the world save lives at `user://save_slot_0.json`.

### Decision — DECIDED (foundation scope)

1. **Continue:** unchanged. Directly loads the existing world save. Existing saves are never forced to replay anything narrative.
2. **Start New Game:** for the foundation, still routes to Forgotten Shore (no Prologue wiring yet — Prologue entry is an N4 task). **New safety behavior:** if a valid world save exists, Start New Game shows a confirmation (“starting a new game replaces the saved reign on the next save”) before proceeding. This prevents silently destroying a valid save via a later autosave.
3. **Prologue routing (N4):** Start New Game will run the Prologue scenes first and enter a *fresh* Forgotten Shore session after landing. Continue bypasses the Prologue entirely. **PROPOSED — owner approval required before wiring.**
4. **Prologue resumability:** linear, **non-resumable** — no mid-Prologue world save; exiting mid-Prologue restarts it on the next Start New Game. **PROPOSED — owner approval required.**

---

## B. Narrative state — is persistence needed?

### Analysis

- The first Prologue is linear and non-resumable. The only durable fact it needs (“Prologue completed / landed on Forgotten Shore”) is implicitly expressed by the **world save existing** — Continue only reaches a saved world, and a saved world only exists after landing.
- Per-run concerns (never run a one-shot sequence twice, skip exactly once, guard duplicate completion) are **in-memory** concerns.
- `ProgressionState` owns durable gameplay milestones/unlocks. The Prologue creates no gameplay unlock, so no new fact is needed.
- `SaveManager` schema v2 therefore needs **no new fields, no migration, no version bump**.

### Decision — DECIDED

1. **No persisted narrative state in the foundation.** No `SaveManager`, `ProgressionState`, or schema changes.
2. A minimal in-memory `NarrativeState` records completed sequence IDs for the current run (idempotent completion, duplicate-run guards, skip bookkeeping). It is explicitly **not serialized**.
3. Trade-off accepted: quitting mid-Prologue loses per-run progression (acceptable for a linear non-resumable Prologue; PROPOSED policy above).
4. Revisit only if a resumable Prologue is approved: then design a versioned narrative save object with strict validation and migration — not a silent schema bump.

---

## C. Narrative event and sequence ownership

### Decision — DECIDED ownership boundaries

| Owner | Responsibility | Does NOT |
|---|---|---|
| `Main` / menu | Entry routing + overwrite confirmation | Owns no dialogue or gameplay rules |
| `NarrativeData` (new) | Sequence/step schema validation, JSON loading, fail-closed data | Executes nothing |
| `NarrativeState` (new) | In-memory, per-run completed-sequence set | Persists nothing |
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
- `skip()`: closes dialogue, executes pending `change_scene` at most once, restores control, then completes exactly once. Skippable flags come from data (`skip_allowed`); the foundation does not add a whole-Prologue skip (cutscene skip vs gameplay-beat skip is an N4 decision — **OPEN**).
- `cancel()`: restores control and closes the panel without completion (used by scene unload/exit).
- `_exit_tree` always runs cleanup; no leaked state, no orphan timers (waits are frame-counted).
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

- **New Game behavior:** confirmation when a valid save exists; later routes through the Prologue (PROPOSED wiring, N4).
- **Continue behavior:** direct world-save load; never replays the Prologue.
- **Exit/restart:** exiting mid-Prologue discards per-run progress (non-resumable); no partial save.
- **Pause:** allowed; dialogue panel stays interactive; sequence waits freeze with the tree.
- **Scene transition:** explicit, allowlisted `change_scene` op; handoff to Forgotten Shore creates a fresh session and starts world saves only then.
- **Input ownership:** dialogue consumes all unhandled input while open; control lock disables movement/commands; both restored on close/cancel/skip/unload.
- **Crown continuity:** crown is a visual continuity element only; no inventory system; its survival is never explained in dialogue.

### Decision record summary

| # | Decision | Status | Rationale |
|---|---|---|---|
| D1 | No persisted narrative state; in-memory `NarrativeState` only | DECIDED | Linear non-resumable Prologue; world save = completion marker |
| D2 | SaveManager/ProgressionState/schema v2 unchanged | DECIDED | No durable narrative need; avoids migration risk |
| D3 | New Game overwrite confirmation | DECIDED | Protects existing saves before Prologue wiring exists |
| D4 | `dialogue_advance` action (Enter/LMB); panel consumes input; control lock | DECIDED | Input isolation without touching gameplay handlers |
| D5 | Typed allowlisted sequence ops; frame-counted waits; injected cue/transition callables | DECIDED | Deterministic, testable, no eval/scripting, no leaked timers |
| D6 | Skip completes exactly once; change_scene at most once; cancel without completion | DECIDED | Idempotence + cleanup safety |
| D7 | Prologue routing/resumability/skip policy | PROPOSED | Owner approval required before N4 wiring |
| D8 | Camera-focus op and pause_world op | PROPOSED | Deferred; not needed by foundation tests |
| D9 | All Prologue content/staging details | PROPOSED/OPEN | Per `PROLOGUE_STORY_DESIGN.md` §10 OPEN table |
