# Crownfall — N4.4 Architecture Design (ADR)

**Status:** PROPOSED (planning only). Every "Proposed responsibility" below is a design recommendation awaiting the owner's N4.4 approval; the "Current owner" column describes the verified N4.3-C baseline on `main` @ `3ba7b62`.
**Narrative source:** [N44_PREPRODUCTION_REPORT.md](N44_PREPRODUCTION_REPORT.md) (requirement matrix R1–R25 — only APPROVED/DERIVED rows drive this document).
**Companion:** [N44_TEST_STRATEGY.md](N44_TEST_STRATEGY.md) · [N44_IMPLEMENTATION_ROADMAP.md](N44_IMPLEMENTATION_ROADMAP.md) · [N44_OWNER_DECISIONS.md](N44_OWNER_DECISIONS.md).

> Design principle (mission §1.2): reuse first, narrow extension second, N4.4-specific component third, generic infrastructure **never without a demonstrated need**. The verified repo pattern for extending the exploration stage without bloating it is the stage-owned child component (N4.3-B's `PrologueMarkInspectables`).

---

## 1. Architecture decision record — summary table

| System | Current owner (N4.3-C) | Proposed N4.4 responsibility | Reuse without modification | Narrow extension | New N4.4-specific component | Generic infra |
|---|---|---|---|---|---|---|
| NarrativeState | PrologueShell (sole writer) | Unchanged: shell validates + records pl_05/pl_06 exactly once | ✅ | — | — | — |
| PrologueShell beat chain | Shell (ends at N4.3 boundary) | Extend the exploration segment: pl_04 completion activates pl_05; pl_05 completion activates pl_06; pl_06 completion ends the segment at the **N4.4 boundary** | ✅ lifecycle/skip/cancel/exit machinery | `active_exploration_beat` progression + boundary text + `n43_segment_complete` → N4.4 naming | — | — |
| PrologueExplorationStage | Stage (road pl_03/pl_04 branches, D5 gate, stage-owned lock, one-shot requests) | Own the N4.4 world continuation: extended bounds, zone states, altar/crown interaction polling, vision presentation hosting | ✅ layout/build/teardown/lock/gate skeleton | per-beat `_process` branches for pl_05/pl_06; bounds extension; boundary naming | — | — |
| Ruins zones + altar/crown presentation | — (does not exist) | Zone art states, chamber reveal, altar/crown props + eligibility, awakening/vision placeholder presentation | — | — | ✅ `PrologueRuinsEnvironment` — a stage-owned child component (the proven N4.3-B component pattern), built atomically fail-closed | — |
| PrologueExplorer | Explorer (movement/anim/camera) | Unchanged contract; larger authored band | ✅ | authored constants only (no logic change) | — | — |
| PrologueMarkInspectables | Component (pl_04 props) | Unchanged for pl_04; NOT reused for the altar (different contract: single fixed interaction point + completion arming, not id-counting) | ✅ (pl_04 untouched) | — | altar/crown eligibility lives in the new component instead | — |
| PrologueBeats | Authored content | Add exploration text/cue data for pl_05/pl_06 + the authored `pl_06_vision` runner sequence (cues/waits/finish only) | ✅ validation/format | new authored data + vision sequence | — | — |
| SequenceRunner | Runner (cinematic sequences) | Play the vision sequence exactly once per pl_06 interaction | ✅ ops/guards/skip/cancel | — (no new ops in the placeholder design) | — | camera-focus op stays PROPOSED (D9/O3) |
| DialoguePanel | Panel (CanvasLayer 100) | Post-vision candidate lines | ✅ | — | — | — |
| PlayerControlLock | Runner lock (shell) + stage lock (explorer), coexisting | Same two-lock arrangement during the vision | ✅ | — | — | — |
| Shell UI (UICanvasLayer) | Camera-immune CanvasLayer (N4.3-C) | Unchanged; boundary text updated | ✅ | text constants | — | — |
| Vision/awakening presentation | — | Fullscreen labelled placeholder states over the chamber | — | — | inside `PrologueRuinsEnvironment` | — |

**Verdict:** one new N4.4-specific component (stage-owned child, mirroring `PrologueMarkInspectables`), narrow extensions to the shell and stage, **zero generic frameworks**, zero new runner ops in the baseline design.

---

## 2. Key architecture decisions (alternatives considered)

### 2.1 Spatial model: one continuous world vs a second stage

| Option | Description | Advantages | Disadvantages | Verdict |
|---|---|---|---|---|
| **A — continuous world (RECOMMENDED)** | Extend the exploration stage's authored bounds eastward; the road visually continues into ruin exterior → interior → chamber (placeholder zone states; cf. breakdown "N (multi-state)") | Maximum reuse (explorer, camera contract, gate, lock, shell handshake all unchanged); no scene reload at the pl_04→pl_05 handoff (matches "the ruins are the destination the road leads to"); one teardown path; smallest diff surface | The stage class grows (mitigated by §2.2's child component); N43A camera/bounds assertions need deliberate updates (owned by slice A) | ✅ recommended |
| B — second stage instance | New ruins scene + stage swap at the pl_04 boundary | Clean isolation of N4.4 layout | Duplicates stage plumbing (setup/teardown/lock/gate) or forces parameterizing the existing stage (refactor of stable code); needs a scene transition inside the segment (new failure/cancel surface); contradicts "reuse first" | rejected |
| C — extract a shared exploration base class | Generalize stage infrastructure for N stages | Would serve N4.5 too | **Generic framework without a demonstrated two-consumer need** (mission §1.2 default: avoid); refactor risk to the verified N4.3 contract | rejected (revisit only if N4.5 proves the need) |

### 2.2 Where the ruins logic lives: stage bloat vs child component

| Option | Description | Verdict |
|---|---|---|
| Inline in `PrologueExplorationStage` | Add pl_05/pl_06 branches + zone art directly | Rejected: the stage would grow ~2× and mix three responsibilities (road, ruins, vision) — maintainability risk |
| **Child component `PrologueRuinsEnvironment` (RECOMMENDED)** | Stage-owned child built atomically fail-closed during setup (the exact N4.3-B `PrologueMarkInspectables` pattern): owns zone states, chamber reveal, altar/crown props + eligibility, awakening/vision placeholder presentation. The stage keeps polling/gating/lock/request ownership; the shell keeps record ownership | ✅ recommended — proven repo pattern, testable in isolation, keeps the D6 atomic-contract discipline |
| New autoload/global ruins manager | — | Rejected: per-run state must die with the stage; no global narrative state exists (D1) |

### 2.3 Vision presentation (constraint: no new runner ops in the baseline)

| Option | Description | Consequences |
|---|---|---|
| **A — fullscreen placeholder states (RECOMMENDED baseline)** | The vision sequence authors `play_cue` fragments; the shell's cue pipeline (existing `set_cue_player` seam) + the new component render labelled fullscreen placeholder states; waits pace the fragments; `finish` ends abruptly | No runner change; deterministic; cancel-safe via the existing generation guards; matches the pl_01/02 caption precedent; keeps D9 deferred |
| B — camera-focus op (D9/O3 approval) | New runner op moves/framed-zooms the explorer camera onto the crown, then fragment overlays | Nicer reveal ("close on crown", breakdown); new op = schema/CI/test work + owner approval; can be layered on A later without rework |
| C — scene-level cutscene scene | Separate vision scene + transitions | New failure/cancel surface; overkill for placeholder-first | 

Recommendation: implement A; B remains available behind O3 without invalidating A's authored data (cues/waits survive).

### 2.4 Completion request wiring (exactly-once, unchanged ownership)

- pl_05: the stage emits its **one** request when the altar trigger is reached (the same single-shot guard pattern as the pl_03 handoff signal; not the pl_04 id-count signal). The shell validates `active_exploration_beat == pl_05`, records once, activates pl_06.
- pl_06: the stage arms the completion at crown contact but emits its **one** request only after the post-vision dialogue closed normally and the generation guards pass (the exact N4.3-B record-after-dialogue ordering). The shell validates the active beat, records once, ends the segment.
- Skip (per O4/O6 outcomes): skip records the active beat once, closes the dialogue, releases the lock, and — for pl_06 — ends the segment; the resumed vision coroutine observes a stale generation and emits nothing (the N4.3-B cancel/skip-during-recognition contract, now covering the vision sequence too).
- Cancel/exit/unload: teardown first (generation bump + torn-down flag), runner cleanup second; nothing recorded; no late emission (N4.3 contract, regression-tested).

### 2.5 Camera and UI safety (N4.3-C correction explicitly accounted for)

- All N4.4 world content renders on the default canvas under the explorer camera; **all** N4.4 UI (prompts, boundary text, vision caption overlays that need screen anchoring) renders on CanvasLayers (the existing `UICanvasLayer` for shell UI; the DialoguePanel stays at 100; any new fullscreen overlay belongs on its own CanvasLayer, not the default canvas — the N4.3-C defect must not be reintroduced).
- The new component's prompt/overlay positions are authored in world coordinates (world-space props, like N4.3-B's prompt) — camera displacement affects the world as intended; only screen-space UI must be camera-immune.
- Regression: the N4.3-C screen-rect containment assertion pattern is extended to the altar prompt + boundary text in the N4.4 suites (test strategy §3).

### 2.6 Asset architecture

- Placeholder-first: zone art/altar/crown/vision fragments are code-built labelled geometry (the verified N4.2/N4.3 pattern); `assets/` gains **nothing** until the owner approves art (breakdown §3 "Use clearly labelled, replaceable placeholders until visual/audio assets are approved").
- Resource-loading conventions: the stage already fails closed on a missing explorer texture (`STAGE_TEXTURE_META` injection contract, N4.3-A); the new component follows the same fail-closed build discipline — a missing/unloadable placeholder resource must fail the whole ruins build, leaving the segment at the fallback boundary (no partial ruins).
- Audio: no audio files exist for ambience/motifs (`assets/audio/` holds 6 gameplay SFX only); N4.4 ships silent or visually-labelled placeholder presentation; the audio need is registered (O8) and blocked on owner asset approval, not on code.

---

## 3. Component contracts (implementation-ready)

### 3.1 `PrologueRuinsEnvironment` (new, stage-owned child)

- **Inputs (construction):** authored table (zone descriptors, chamber trigger x, altar x, crown staging, vision caption data) + bounds/ground from the stage; `build()` validates the whole table first, constructs under a non-tree staging parent, verifies, commits — **atomic fail-closed (D6 discipline)**; rejects a second successful build.
- **Outputs:** zone-state signals (e.g. `zone_changed(zone_id)`, `chamber_revealed()`, `altar_reached()` — names finalized at slice A review). **Ownership clarification:** these are internal eligibility/presentation signals consumed by the stage — the stage remains the SOLE emitter of the one-shot completion requests (mirroring how `PrologueMarkInspectables` exposes inspection state while the stage polls and emits), so exactly-once emission stays at the same ownership layer as N4.3.
- **State ownership:** per-run zone/inspection-of-none state dies with the node; nothing serialized.
- **Preconditions:** stage built, segment live; pl_05/pl_06 active for interaction/presentation branches.
- **Postconditions:** on teardown — presentation hidden, prompt hidden, no signal state, freed-safe.
- **Failure behavior:** any build failure ⇒ component invalid + empty ⇒ stage setup fails ⇒ shell falls back to the defined boundary (records nothing) — identical to the N4.3-A/B fallback chain.
- **Cancellation behavior:** presentation states are pushed only behind the stage's generation guard; a cancelled/ended segment renders nothing.
- **Cleanup responsibilities:** `_exit_tree` mirrors the stage teardown (freed-safe).
- **Testing strategy:** dedicated suite (build matrix, zone transitions, eligibility gates, atomic-failure subclasses — the N4.3-B H9a/H9b pattern) + integration via the full-flow suite.

### 3.2 Shell chain extension (narrow)

- `_on_mark_inspection_completed()` (pl_04) → record pl_04 → **activate pl_05** (was: end segment).
- New handler for the stage's pl_05 request → record pl_05 → activate pl_06.
- pl_06 request → record pl_06 → end segment at the N4.4 boundary (input disable, freeze, lock release, prompt hidden, boundary status text per O6).
- `skip_current_exploration_beat()`: pl_05 skip → record once + activate pl_06 (pl_03-skip precedent); pl_04 skip → per O6; pl_06 skip → per O4 (vision-moment granularity).
- Boundary naming: `n43_segment_complete`-equivalent naming updated or aliased; the user-visible status text stops claiming "N4.4+ not implemented" (text content per O6).

### 3.3 Vision sequence (`pl_06_vision`, authored data in `PrologueBeats`)

- **Inputs:** none (triggered by the shell after the crown-contact handshake).
- **Ops:** `lock_control`, `play_cue` (fragments R12), `wait` (frame-counted), `finish` — all existing, validated ops; abrupt end = the sequence simply finishes (R14).
- **Outputs:** `sequence_completed(pl_06_vision)` exactly once (existing runner guard); cue emissions observed by the shell's cue seam.
- **State ownership:** authored data is deep-copied per play (existing contract); no new runner state.
- **Failure:** invalid sequence ⇒ `play()` rejected fail-closed ⇒ stage holds the lock-closed state? **No** — the handshake must treat a rejected vision play as a failed presentation path: release the actor lock, do NOT arm completion, keep the segment live (player can retry the interact) — logged explicitly. (Rejected plays must never leave a stuck lock; mirrors the shell's refusal-reporting contract.)
- **Cancellation:** `cancel_sequence()` semantics unchanged; the stage's generation guard makes any resumed vision/dlg coroutine a no-op.
- **Testing:** runner-level (sequence validates, completes once, skip/cancel matrices — existing suite conventions) + integration (contact → vision → dialogue → record exactly once; cancel mid-vision records nothing).

### 3.4 Extended stage bounds + camera

- Authored constants extended (bounds, camera limits, zone triggers, altar/crown staging) — **no logic change** to the explorer; the N4.3 containment guarantees (limits == band, no offset, backdrop margin coverage) extend mechanically with the constants.
- N43A/N43C assertion updates are **explicit roadmap items** (slice A), never silent.

---

## 4. Lifecycle, cancellation, and failure behavior (segment-level)

| Event | Behavior |
|---|---|
| pl_04 completes (normal or approved skip) | Shell activates pl_05; zone states initialize; no dialogue |
| Cancel during pl_05/pl_06 (any phase incl. vision) | `cancel_sequence()` → stage teardown FIRST (generation bump, lock release, input disable, presentation cleared) → runner cancel second → nothing recorded → defined idle state; non-resumable |
| Dev exit / menu return | Same ordering via `_begin_exit`; exactly one transition (single-transition guard unchanged) |
| Direct scene unload mid-vision/mid-dialogue | Stage `_exit_tree` teardown (freed-safe); suspended coroutines die with the panel; nothing recorded (H8 contract) |
| Failed ruins build / missing staging texture | Fail-closed fallback: no exploration state, no records, defined boundary status; runner idle+unlocked |
| Duplicate/late completion requests | Ignored by shell active-beat validation + one-shot emission guards (both levels) |
| Vision `play()` rejection | No lock left behind; completion NOT armed; segment stays live; refusal reported (no silent state) |

---

## 5. State machines (PROPOSED — final naming at slice reviews)

### 5.1 N4.4 segment state machine (shell-owned beat progression)

```mermaid
stateDiagram-v2
    [*] --> N43Boundary: main @ 3ba7b62 (pl_04 recorded once)
    N43Boundary --> PL05Active: pl_04 completion OR approved skip path (O6)
    PL05Active --> PL05Active: zone movement / clues (no records)
    PL05Active --> PL05Recorded: altar trigger → ONE shell-validated request
    PL05Recorded --> PL06Active: shell activates pl_06
    PL06Active --> Awakening: interact (D5 gate) at crown
    PL06Active --> PL06Active: approach/explore (no records)
    Awakening --> Vision: handshake (lock actor, arm completion)
    Vision --> PostVisionDialogue: sequence finishes (abrupt)
    PostVisionDialogue --> N44Boundary: normal close -> ONE request -> shell records pl_06
    PostVisionDialogue --> N44Boundary: skip (O4 policy) -> records once
    Awakening --> Cancelled: cancel/exit/unload
    Vision --> Cancelled: cancel/exit/unload
    PostVisionDialogue --> Cancelled: cancel/exit/unload
    PL05Active --> Cancelled: cancel/exit/unload
    Cancelled --> [*]: NOTHING recorded; locks released; non-resumable
    N44Boundary --> [*]: dev exit only; pl_07 NOT started
```

Invalid transitions (rejected no-ops, never state-changing): completion requests for a non-active beat; second completion for a recorded beat; interact during dialogue/vision; zone advance while torn down; vision trigger while pl_05 still active.

### 5.2 pl_05 exploration states (stage-owned, per-run)

`EXTERIOR → INTERIOR_PASSAGE → CHAMBER_REVEALED → ALTAR_REACHED`

- Triggers: authored zone x-thresholds; chamber trigger flips presentation + reveal; altar trigger emits the completion request (allowed source states: `CHAMBER_REVEALED`, movement enabled, not torn down, segment live, beat pl_05 active).
- Side effects: presentation states only; the request is one-shot; narrative recording happens ONLY in the shell.
- Invalid transition behavior: ignored (no state change, no emission); backtracking west is allowed visually but never un-reveals or re-fires.

### 5.3 Altar/crown interaction states (stage-owned)

`IDLE → PROMPT_ELIGIBLE (in range, beat pl_06) → AWAKENING (lock + arm) → VISION (runner sequence live) → DIALOGUE (post-vision lines) → COMPLETED_REQUEST_EMITTED`

- Guards: full D5 gate at `PROMPT_ELIGIBLE → AWAKENING` (beat, not torn down, segment not ended, input enabled, panel closed, lock not held, in range, `interact` just pressed).
- Exit edges: skip (per O4) from `AWAKENING/VISION/DIALOGUE` → record-once + segment end; cancel from any state → teardown, nothing recorded.
- The completion request exists only on the `DIALOGUE → COMPLETED_REQUEST_EMITTED` edge (normal close) — the skip path records **without** this edge (N4.3-B distinction: skip ≠ normal completion emission).

### 5.4 pl_06 awakening/vision sequence states (runner-owned run state)

`IDLE → RUNNING (gen N) → {COMPLETED (gen N), SKIPPED (gen N), CANCELLED (gen N)}` — generation token invalidates all late continuations (existing runner contract, unchanged).

### 5.5 Exactly-once rules (binding for implementation)

1. The stage emits **at most one** request per beat per segment (one-shot guard; re-emission impossible by construction, not by convention).
2. The shell records only against the ACTIVE beat and only on the first request (`NarrativeState` idempotence is the second belt).
3. Skip records via the shell's skip path and must never pass through the normal-completion emission edge — the two are distinct, observable paths (H10-style observability retained).
4. Cancel/exit/unload/failed-setup record nothing and leave no armed state behind (generation guards + teardown flags).
5. A completion after scene unload is impossible: the emitter is freed with the stage; the suspended coroutine dies with the panel (H8 contract).
6. `pl_06_vision` completes/skips/cancels exactly once per run via the runner's `_completion_emitted` + generation guards.

---

## 6. Dependency and risk notes

- Dependencies: shell chain ⇄ stage requests (existing handshake); component ⇄ stage (construction + polling); vision sequence ⇄ shell cue seam + runner (existing). No circular dependencies: component → (stage, authored data); shell → (stage, runner, state); runner → (panel, lock, state).
- Highest technical risk: bounds/zone extension touching N4.3 camera assertions — mitigated by explicit slice-A test updates and the unchanged containment guarantees.
- Highest narrative risk: vision fencing (R13) — mitigated by the placeholder-only presentation + a content-review checklist in the roadmap (slice D gate).
