# Crownfall — Narrative Runtime Technical Design

**Status:** Technical contract for the implemented N1–N3 runtime + N0 production contract (story/entry-flow items remain DECIDED / PROPOSED / OPEN as marked). N4.0 (entry gate + player profile) is implemented; the Prologue content slices N4.1–N4.6 are not.  
**Baseline:** N4.0 verified against `main` @ `a34e5b3` (PR #12 merge), Godot `4.7.2.stable`.  
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
- `scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd` (N4.0) — clearly labelled, inert placeholder route target (no beats, no dialogue, no handoff, no completion marking; only "Return to Main Menu"). N4.1 replaces the scene content at the same path (or updates `Main.PROLOGUE_ROUTE_SCENE` in the same PR); the routing decision does not change. Headless tests observe routing via `Main.set_route_transition(Callable)` and Engine metas `crownfall_profile_path` / `crownfall_menu_save_path` (same contract style as `crownfall_load_on_start`).
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
