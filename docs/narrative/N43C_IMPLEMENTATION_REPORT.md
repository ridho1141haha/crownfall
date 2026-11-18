# N4.3-C Implementation Report — Full-Flow Integration & Regression

**Working progress document** (mission tracking; the official criteria live in
[N4_3_PLANNING.md](N4_3_PLANNING.md) §5 and the runtime contract in
[NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md](NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md)).
This report records phase status, findings, decisions, files changed, executed
verification, and known limitations. It is not a substitute for the planning
documents.

**Branch:** `feature/n43c-full-flow-integration-regression`
**Baseline:** `main` @ `27a0ba0` (merge of PR #20 — N4.3-B).

## Phase status

| Phase | Objective | Status |
| --- | --- | --- |
| 0 | Repository reconnaissance | DONE |
| 1 | Integration design (matrix + test plan) | DONE |
| 2 | Full-flow test implementation | DONE (`tests/test_n43c_full_flow.gd`, 176 checks) |
| 3 | Integration defect investigation / fixes | DONE (one demonstrated production defect fixed; see §3) |
| 4 | Full regression + 10× stability | DONE (10/10 consecutive PASS, twice — before and after the fix) |
| 5 | Windowed visual verification | DONE (Xvfb windowed run + 7 screenshots, before AND after the fix) |
| 6 | Documentation synchronization | DONE |
| 7 | Final independent diff review | DONE (1 P1 fixed in-flight; no open P0/P1) |
| 8 | Git delivery (branch, push, Draft PR) | DONE |

## 1. Phase 0 — reconnaissance findings (2026-11-18)

- `main` HEAD: `27a0ba0` — **PR #20 (N4.3-B) is merged**; the N4.3-B stack
  (`ebef683` B1, `2e69a47` B2, `1c7df9c` B3, `c1a9c41` test-driver reliability
  fix) is present in `main` history. Working tree clean on checkout.
- Baseline sanity on the working branch (before any N4.3-C change):
  - `python3 tests/verify_repo_integrity.py` → `PASS: All 247 ... checks succeeded!`
  - `test_n43b_mark_inspection.gd` → `PASS: All 193 N43B Mark Inspection checks` (the mission's "reportedly 193" is verified exact)
  - `test_n43a_exploration_stage.gd` → `PASS: All 106 N43A Exploration Stage checks`
- Implementation files inspected on current main (not from reports):
  `PrologueShell.gd` (chain + exploration segment + skip/cancel/exit),
  `PrologueExplorationStage.gd` (layout, intro/recognition dialogue, D5 gate,
  one-shot emissions), `PrologueExplorer.gd`, `PrologueMarkInspectables.gd`,
  `PrologueBeats.gd`, `SequenceRunner.gd`, `NarrativeData.gd`,
  `NarrativeState.gd`, `PlayerControlLock.gd`, `DialoguePanel.gd`.
- Test registration: `tests/run_all.sh` (19 suite entries + verifier + import)
  and `.github/workflows/godot-ci.yml` (per-suite steps). N4.3-C adds one
  entry to both.
- **Integration coverage gaps** (what no existing suite covers):
  1. No suite drives the COMPLETE experience as one continuous shell —
     pl_01 advance → pl_02 advance → pl_03 intro → genuine movement to the
     handoff → pl_04 prompt/inspection → recognition → completion → boundary —
     with state assertions at every transition (N4.3-A stops at a pl_04 skip;
     N4.3-B drives shells but its shells are per-contract, not one continuous
     matrix).
  2. Skip-during-recognition ordering (skip closes the panel, the resumed
     dialogue coroutine must NOT emit a completion request) is only covered at
     cancel level in N4.3-B; the SKIP-while-recognition-open path is uncovered.
  3. Skip of pl_04 AFTER exactly one inspection (recognition never opened)
     is uncovered.
  4. Cue presentation ordering across pl_01/pl_02 (and its absence on skip)
     is only weakly covered (N4.2 covers cues per-beat; the observer-based
     ordering across the chain plus exploration is not asserted end-to-end).
  5. Late/post-boundary inertness (re-emitted stage requests, held interact
     through the recognition window, post-boundary interact press) is covered
     per-contract in N4.3-B but not across a full uninterrupted flow.
- **Architectural inconsistencies found:** none in code. Documentation
  staleness only (recorded in §6: PROLOGUE_STORY_DESIGN.md status line,
  roadmap §3 prose, status headers that predate the PR #20 merge).
- Docs recon: N4.3-C criteria = planning §7 slice C bullets + §5 acceptance
  checklist; skip/cancel contract = planning §4; terminal state = N4.3-B
  design D3 nine-item list; U2/U4/U5 remain OPEN; pl_05 stays unimplemented.

## 2. Phase 1 — integration matrix (test plan)

Central question: *can the entire Prologue transition from pl_01 through the
N4.3 exploration boundary without broken ownership, duplicate completion,
stuck controls, or stale callbacks?* Suite: `tests/test_n43c_full_flow.gd`
(SceneTree stage machine, same conventions as N4.3-A/N4.3-B: fail-fast
`_check`, Engine-meta fixture isolation under `user://n43c_test/`, byte-exact
real-file snapshots, cleanup on every path).

### Shell A — normal full flow (continuous, production defaults)

| # | Scenario | Driver | Expected transitions / state | NarrativeState | Input/control | Emissions | Method |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | pl_01 auto-starts | Main → PrologueShell (autostart ON) | panel open, narrator text, cue `stage_pl01_prosperity` | count 0 | runner lock held on shell (no actor exists) | — | headless |
| A2 | pl_01 cue order | advance dialogue; cue observer | prosperity → eclipse → ruins in order | — | — | — | headless |
| A3 | pl_01 → pl_02 chain | advance | pl_02 panel, cues childhood → resonance; completions `[pl_01]` | count 1 | still cinematic | runner completion exactly once | headless |
| A4 | pl_02 → exploration handoff | advance | `in_exploration`, beat pl_03, `prologue_reached_end`, runner idle, stage built, explorer at authored start, intro line open (approved text), lock held, input disabled | count 2 | actor frozen by stage lock | no runner completion for pl_03/pl_04 ever | headless |
| A5 | held movement during intro | hold move_right 20 frames | actor x unchanged (lock + input gate) | — | — | — | headless |
| A6 | control at intended point | advance intro to close | lock released, input enabled, physics on | — | movement available only now | — | headless |
| A7 | genuine movement + handoff | drive right (position-based wait) | handoff fires once at `HANDOFF_X`; pl_03 recorded once; pl_04 activates; no pl_04 dialogue | count 3 (pl_01..pl_03) | movement stays enabled | `exploration_handoff_reached` exactly once; runner completions stay `[pl_01, pl_02]` | headless |
| A8 | prompt range + nearest-only | teleport near A / between A & B / far | prompt visible only in range; target = nearest eligible; hidden during pl_03 and out of range | — | — | — | headless |
| A9 | first + repeated inspection | interact at A twice | count 1 after both (D1 idempotent); no dialogue after either | — | — | no recognition | headless (press+await driver, N4.3-B conventions) |
| A10 | second distinct → recognition | hold interact at B (held-input window preserved) | recognition opens exactly once with approved text; input disabled, lock held, actor still | count 3 | movement blocked during recognition | — | headless |
| A11 | dialogue closure → completion | advance recognition to close | pl_04 recorded once; segment ends (input disabled, actor frozen, prompt hidden, `n43_segment_complete`, boundary status); held key added no second inspection | count 4 | frozen boundary (D3 list) | `mark_inspection_completed` exactly once; no new runner completions | headless |
| A12 | post-boundary inertness | re-emit stage signals + press interact after end | nothing changes (no re-inspection, no duplicate record, no pl_05) | count 4 | frozen | no new emissions | headless |
| A13 | exit from boundary | `request_main_menu_return()` | exactly one Main transition | count 4 | no leaks (hygiene checks) | — | headless |

### Shell B — skip matrix

| # | Scenario | Expected |
| --- | --- | --- |
| B1 | skip pl_01 (runner skip) | completes once, no cues staged, chains pl_02 |
| B2 | skip pl_02 | exploration begins directly; runner completions `[pl_01, pl_02]`; exploration beats never runner-skipped |
| B3 | skip pl_03 while intro open | records pl_03 once; dialogue closed; lock released; input enabled; pl_04 active, NOT skipped |
| B4 | skip pl_04 before any inspection | records pl_04 once; segment ends; recognition never opened; prompt hidden; duplicate skip rejected |
| B5 | skip pl_04 after ONE inspection | records pl_04 once; recognition never opened (1 < 2 distinct); segment ends; third object irrelevant |
| B6 | skip pl_04 while recognition open | panel closed by skip; resumed coroutine observes stale generation and never emits the completion request; pl_04 recorded once (by skip); lock released; no duplicate after settle |
| B7 | duplicate skip after end | rejected; no new records; no pl_05 fabrication; profile fixture byte-exact |

### Shell C — cancellation / teardown matrix

| # | Scenario | Expected |
| --- | --- | --- |
| C1 | cancel during pl_01 | nothing recorded; panel closed; runner idle; chain restartable (non-resumable per-run state) |
| C2 | cancel during pl_03 intro | nothing recorded (count 2); stage torn down; lock released; input disabled; cancelled status |
| C3 | cancel during pl_04 after one inspection | nothing recorded (count 3); stage torn down; no recognition path can fire |
| C4 | cancel DURING recognition dialogue | ordering contract: stage teardown (generation bump + torn-down flag) runs BEFORE the runner closes the shared panel; resumed await observes stale state; NO completion request; pl_04 NOT recorded; count stays 3; no errors |
| C5 | dev exit during recognition | same as C4 + exactly one exit transition; nothing recorded |
| C6 | direct scene unload during recognition (no cancel path) | stage `_exit_tree` teardown releases lock/closes dialogue; nothing recorded; no invalid access after unload |

### Shell D — failed setup (fail-closed, atomic)

Bad texture meta → no exploration state, no lock, no records, structural end
stays true, defined idle boundary status, runner idle. (Compressed re-proof
end-to-end; full matrix lives in N4.3-A.)

### Headless vs windowed

Headless (all shells above): state transitions, ownership, emissions, control
locks, input gates, records, hygiene. Windowed (Phase 5): Adult Monarch
visibility/scale, framing, road coverage, prompt readability, recognition
readability, actor stillness during recognition, no stale prompt, terminal
presentation.

### Explicit non-goals in the matrix

No new narrative content; no pl_05; no new production API; no generic
framework; existing N4.3-A/B suites remain the per-contract authority (H8,
H10, H14, D1–D6 live there and stay intact).

## 3. Phase 3 — integration defect findings

### 3.1 Production defect (P1, presentation) — FOUND AND FIXED

**Finding (windowed visual pass, Phase 5):** during the entire exploration
segment (pl_03, pl_04) and at the terminal boundary, the shell's CenterContainer
UI (status labels + the development exit button) was displaced outside the
viewport — invisible and unreachable — while the exploration camera was active
(screenshots `01–07` in the pre-fix run show no UI at all during exploration).

- **Reproduction:** run the game windowed and enter the exploration segment;
  the status labels and the dev exit button disappear. Reproduced headlessly by
  computing the button's true screen rect through the viewport's canvas
  transform: the exploration camera's transform pushes it outside the viewport.
- **Root cause:** the shell's CenterContainer was a plain Control on the
  default canvas. The exploration `Camera2D` transforms the default canvas, so
  screen-space UI is displaced by the camera. The `DialoguePanel` was immune
  because it already extends `CanvasLayer` (layer 100).
- **Contract violated:** planning §5 "Cancel, exit, teardown, and failed setup
  leave no stuck input lock or stale prompt" + "the development exit button
  stays reachable during exploration" (shell header comment) — the button was
  unreachable by mouse for the whole segment, and the boundary status text
  (the defined idle boundary presentation) was invisible. The N4.3-B changelog
  had already noted the camera-transformed labels and explicitly deferred the
  UI change; N4.3-C (integration & stabilization) is the slice that owns it.
- **Fix (narrowest safe correction):** the shell UI renders on the new
  `UICanvasLayer` CanvasLayer (layer 1, camera-immune — the same mechanism the
  panel uses). World rendering, the camera contract, and every narrative
  behavior are unchanged. Files: `scenes/narrative/PrologueShell.tscn`
  (UI moved under `UICanvasLayer`), `scripts/narrative/PrologueShell.gd`
  (8 UI lookups updated + contract comment), and the shell-UI path lookups in
  `test_n41/test_n42/test_n43a/test_n43b/test_n43c` (Main.tscn lookups
  untouched).
- **Regression proof:** `test_n43c_full_flow.gd` asserts the button's TRUE
  screen rect stays inside the viewport during exploration (A8) and at the
  boundary (A11) while the world actor IS camera-displaced (contrast proof the
  camera is active). Verified visually: post-fix screenshots show the status
  text and the button in every exploration phase (§5). Full regression green
  after the fix (§5).

### 3.2 Test-driver defects (6, all in the new suite — no production change)

1. Cue observer wired after the auto-start fired the first cue → Shell A uses
   the explicit `start_prologue()` production entry (auto-start itself stays
   covered by the N4.3-A suite).
2. Wrong authored id in an assertion (`mark_stone_b` → `mark_fragment_b`).
3. Wrong cue-skip expectation: the chain advances synchronously, so the next
   beat's opening cue fires before a skip can land — the contract is "no cues
   AFTER the skip point", now asserted correctly.
4. Missing explicit `start_prologue()` in the autostart-off shells (runner
   idle forever → timeout).
5. Per-frame re-wiring of shell observers in looping stages (duplicate signal
   handlers + repeated starts) → identity guard wires/starts each shell once.
6. Sidecar snapshot/hygiene list mismatch (`.bak` on the profile sidecars) →
   aligned with the N4.3-A convention.

### 3.3 Production files changed

`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd`
(the UI-layer fix above). No other production file changed.

## 4. Phase 2/3 — test implementation and execution evidence

- Added `tests/test_n43c_full_flow.gd` (176 checks; registered in
  `tests/run_all.sh` as "N43C full flow" and in
  `.github/workflows/godot-ci.yml`).
- Result: `PASS: All 176 N43C Full Flow checks completed with 0 failures.`
- The shell-A hold-through-recognition window re-proves the H14 held-input
  contract inside the uninterrupted flow; the N4.3-B suite remains the H14
  authority and is untouched (its assertions are unchanged; only the shell-UI
  path prefix updated for the fix).

## 5. Phase 4 — full regression and stability

Executed commands and results (Godot `4.7.2.stable`, binary
`Godot_v4.7.2-stable_linux.x86_64`; every line below was actually executed):

| Command | Result | Reproduced |
| --- | --- | --- |
| `--headless --script res://tests/test_n43c_full_flow.gd` ×10 (pre-UI-fix) | PASS — All 173 checks, 10/10, exit 0, 0 errors | yes |
| `--headless --script res://tests/test_n43c_full_flow.gd` ×10 (post-UI-fix) | PASS — All 176 checks, 10/10, exit 0, 0 errors | yes |
| `test_n43a_exploration_stage.gd` | PASS — All 106 checks, exit 0 | 3× (baseline, post-fix ×2) |
| `test_n43b_mark_inspection.gd` | PASS — All 193 checks, exit 0 | 3× (baseline, post-fix ×2) |
| `test_n41_prologue_shell.gd` | PASS — All 87 checks, exit 0 | post-fix |
| `test_n42_prologue_beats.gd` | PASS — All 113 checks, exit 0 | post-fix |
| `python3 tests/verify_repo_integrity.py` | PASS — All 251 integrity/scene-graph/CI-lock checks | baseline + final |
| `tests/run_all.sh` (full: import + 19 suites + verifier) | **ALL SUITES PASSED, exit 0** (20 entries) | final |
| Profile/save integrity | real `user://player_profile.json` / `save_slot_0.json` + sidecars byte-exact untouched (asserted inside N43A/B/C suites every run) | every run |

No intermittent failure, no leaked input state, no stale dialogue locks, no
duplicate completion, no invalid-object errors, no order-dependent failures in
either stability round. Intermediate failed runs during development were
driver-side defects (§3.2), investigated and fixed, then re-run clean — not
hidden by retries.

## 6. Phase 6 — documentation synchronization

Updated (after acceptance passed):
- `docs/narrative/N4_3_PLANNING.md` — slice C marked implemented; status line
  refreshed for the merged N4.3-B (PR #20, 193-check suite) + N4.3-C.
- `docs/NARRATIVE_IMPLEMENTATION_ROADMAP.md` — status header, §3 stale prose,
  §5 N4 paragraph, §10 next tasks (next milestone = N4.4).
- `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` — status header +
  baseline, §E new UI-layering guard bullet, N0 implemented-beats note.
- `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md` — header + N4.3 slice row.
- `docs/narrative/PROLOGUE_STORY_DESIGN.md` — stale status line corrected
  (pl_01–pl_04 implemented; pl_05–pl_09 not).
- `docs/CHANGELOG.md` — new `[2026-11-18] N4.3-C` entry in the house format,
  including the production fix record.
- pl_05/N4.4+ remain explicitly NOT implemented; U2/U4/U5 remain OPEN; visual
  decisions remain labelled placeholders (no art approval claimed).

## 7. Phase 7 — final review findings

Independent diff review (P0–P3):
- **P1 (fixed in-flight):** the exploration-camera UI displacement (§3.1) —
  demonstrated by the visual pass, fixed, regression-tested, re-verified.
- **P2 (considered, declined):** the pre-existing duplicated D8/D9 rows in the
  runtime design's decision-record table — a pre-existing documentation glitch
  unrelated to N4.3; not touched to keep the diff scoped.
- No P0/P1 findings remain. No test weakened; no N4.3-B assertion changed; no
  unused production API added (the fix only moves existing UI nodes); no
  generic framework; no pl_05; no save/profile behavior change.

## 8. Phase 8 — Git delivery

- Branch: `feature/n43c-full-flow-integration-regression` (from `main` @ `27a0ba0`).
- Commits: (1) test plan report + integration suite, (2) suite registration
  (run_all.sh + CI), (3) production fix: camera-immune shell UI layer + path
  updates + regression assertions, (4) docs synchronization + visual-pass
  harness.
- Push + Draft PR: executed against `main`; merge decision left to the owner.

## 9. Known limitations

- Visual/art approval (U2 mark design, U4 staging values, U5 prompt wording)
  remains OPEN — placeholders unchanged, verified only as placeholders.
- The windowed pass ran under Xvfb with software GL (`gl_compatibility`); it
  verifies presentation presence, framing, and readability, not subjective art
  quality or audio (none ships).
- Screenshot evidence ships with the delivery (7 PNGs); the harness
  (`scripts/tools/n43c_visual_pass.gd`) is committed so the pass is
  reproducible.
