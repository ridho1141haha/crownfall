# Crownfall — N4.4 Test Strategy

**Status:** PROPOSED (planning only — no test code is written or modified in this mission).
**Scope:** what must be tested when N4.4 is implemented, and which existing guarantees must remain green.
**Sources:** [N44_PREPRODUCTION_REPORT.md](N44_PREPRODUCTION_REPORT.md) (R-matrix) · [N44_ARCHITECTURE_DESIGN.md](N44_ARCHITECTURE_DESIGN.md) (contracts, state machines, exactly-once rules §5.5) · [PROLOGUE_PRODUCTION_BREAKDOWN.md](PROLOGUE_PRODUCTION_BREAKDOWN.md) (per-beat test criteria pl_05/pl_06).

> Governing principle (unchanged from N4.3-C): every test protects a meaningful contract; no test-count inflation; N4.3-A/B/C coverage is preserved verbatim except for explicitly listed, ownership-preserving updates (bounds/camera constants, boundary text).

---

## 1. Failure-mode analysis → required coverage

| # | Failure mode | Design prevention (architecture ref) | Required coverage |
|---|---|---|---|
| F1 | Scene/stage load failure (missing explorer texture, failed ruins build) | Fail-closed atomic build (D6); shell fallback boundary | Suite: failed-setup matrix — no exploration state, no records, boundary status, runner idle+unlocked |
| F2 | Missing required node at runtime | Stage-owned construction + verification before commit | Component build matrix incl. verified-commit assertions |
| F3 | Missing resource (future art/audio hooks) | Placeholder-first (no external resource dependency in N4.4 baseline) | Build matrix asserts zero external-asset reads |
| F4 | Failed actor initialization | Unchanged explorer init path | Existing N43A actor tests stay green (no modification) |
| F5 | Failed interaction setup (component invalid) | Component invalid ⇒ stage gate never opens | Integration: no prompt/interact effect after an induced failed build |
| F6 | Duplicate signal connections (looped wiring) | Identity-guard wiring (the N4.3-C suite's own lesson) | Full-flow suite drives all beats in one shell; assertion set counts emissions, not connections |
| F7 | Stale callbacks after cancel/unload | Generation guards + torn-down flags (stage + runner) | Cancel-mid-vision, unload-mid-vision, cancel-mid-dialogue matrices: settle windows assert no late emission/recording |
| F8 | Cancellation during dialogue | N4.3-B ordering contract (teardown before runner cleanup) | Full-flow cancel-during-post-vision-dialogue case (mirrors the N43C C4 shell) |
| F9 | Cancellation during an interaction (awakening window) | Guard list + generation bump at teardown | Cancel between contact and vision start: no completion, lock released, actor frozen |
| F10 | Scene unload during an asynchronous sequence | `_exit_tree` teardown; coroutine dies with panel (H8) | Direct-unload-during-vision case; captured-state assertions post-unload |
| F11 | Player input leakage (movement/interact during vision/dialogue/boundary) | Stage lock + D5 gate + segment-ended gate | Control-lifecycle matrix across every phase incl. held-input through the vision window (H14 pattern) |
| F12 | PlayerControlLock leakage (stuck lock on any terminal path) | Lock release on completion/skip/cancel/exit/teardown; freed-safe unlock | Lock-state assertions on every terminal path of every shell in the full-flow suite |
| F13 | Duplicate completion | One-shot emission guard + shell active-beat validation + NarrativeState idempotence | Late re-emission + duplicate interact + double-skip cases: state count unchanged |
| F14 | Invalid scene transition | Shell single-transition guard; no new transition added by N4.4 | Exit transitions counted exactly once from pl_05/pl_06/vision/boundary states |
| F15 | Camera-dependent UI regression (the N4.3-C defect) | All N4.4 UI on CanvasLayers | Screen-rect containment assertions for the altar prompt + boundary text while the camera is displaced (contrast proof) |
| F16 | Prompt visibility errors (wrong range, wrong target, stale prompt) | Eligibility query in the component; prompt hidden on completion/teardown | Range/target matrix (in/out of range, chamber vs altar); prompt-hidden at boundary + after teardown |
| F17 | State ownership violations (stage/runner recording beats) | Shell sole-writer contract | Full-flow asserts runner completions == [pl_01, pl_02] throughout; every exploration record happens once, by the shell |
| F18 | Vision content fencing breach (R13) | Authored data review checklist; placeholder-only presentation | Vision-content assertions: fragment caption set ⊆ approved list; no dialogue during vision; no new lore strings (data-level test) |

---

## 2. Coverage layers (planned suites — names indicative)

| Layer | Planned artifact | Protects |
|---|---|---|
| Unit — component | `tests/test_n44_ruins_environment.gd` (new; mirrors the N43B component-suite conventions): build matrix incl. H9a/H9b-style failure subclasses, zone state machine, eligibility gates, prompt visibility, freed-safe teardown | F2, F5, F16 + component contracts §3.1 |
| Unit — authored data | Extension of narrative-foundation conventions: `pl_06_vision` validates; fragment cue set == approved list; no protected-mystery strings | F18, R12/R13 |
| Component integration | Extension of the exploration-stage suite conventions (N43A style): bounds/zone/camera containment updates + pl_05/pl_06 stage branches + handshake requests | F15, §3.4, R6/R9 |
| Full-flow integration | `tests/test_n44_full_flow.gd` (new; the N43C pattern continued): one continuous shell pl_01→…→pl_06→N4.4 boundary + skip/cancel/teardown/failed-setup matrices + vision cancel/unload + exactly-once ownership + input/file hygiene | F6–F14, F17, R16 |
| Regression (must remain green, unmodified) | N43A 106 · N43B 193 · N43C 176 (path/bounds-constant updates owned and listed explicitly by slice A — no assertion weakening) · N42 113 · N41 87 · N40 66 · narrative foundation + runner + dialogue suites | everything |

Registration: new suites land in `tests/run_all.sh` + `.github/workflows/godot-ci.yml` per slice (same as N43B/N43C).

## 3. Full-flow coverage matrix (the N4.4 centerpiece)

| Shell | Scenario | Key assertions |
|---|---|---|
| A | Normal full flow pl_01→pl_06 in one continuous shell | cue ordering across beats; control handoff at each dialogue close; zone transitions; chamber reveal; pl_05/pl_06 recorded exactly once each; vision fragments exactly the approved set; boundary state complete; dev exit once |
| B | Skip matrix | pl_05 skip (records once, activates pl_06); pl_04 skip per O6; pl_06 skip before contact / after contact / during vision / during post-vision dialogue per O4; duplicate skips rejected; no skip-marks-profile-flag |
| C | Cancel/teardown matrix | cancel during pl_05, during awakening, during vision, during post-vision dialogue; dev exit during vision; direct unload during vision — nothing recorded, no late emissions, locks released |
| D | Failed setup | bad texture meta / induced component-build failure → fallback boundary, nothing recorded |
| E | Control lifecycle & hygiene | input unavailable→enabled→blocked→restored→frozen across all phases; held interact through the vision adds nothing; no leaks between shells; real user files byte-exact |

## 4. Visual verification plan (windowed, at slice D/E gates)

- Xvfb + the committed visual-pass harness pattern (N4.3-C precedent), screenshotting: ruin exterior, interior passage, chamber reveal, altar+prompt, awakening flash, vision fragments, post-vision dialogue, N4.4 boundary.
- Checklist: zone art is visibly labelled placeholder; prompt only at the altar in range; actor visibly still during awakening/vision; boundary status text updated and on-screen (camera-immune); no pl_07 content; no stale prompt/UI.
- Honest-evidence rule carries over: only actually-inspected screenshots are claimed.

## 5. Stability and integrity requirements (carried over)

- 10 consecutive full-flow runs, exit 0, no intermittent failures, no leaked input/locks, no duplicate completions, no order dependence.
- Real `user://player_profile.json` / `save_slot_0.json` + sidecars byte-exact untouched (in-suite snapshots, every run).
- Static verifier + full `tests/run_all.sh` green at every slice boundary; no `SCRIPT ERROR`/`Parser Error` in any log.
