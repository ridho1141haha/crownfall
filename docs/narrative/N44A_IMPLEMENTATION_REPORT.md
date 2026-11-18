# Crownfall — N4.4-A Implementation Report (Forgotten Ruins Foundation & pl_05)

**Status:** IMPLEMENTED on `feature/n44a-ruins-foundation` (from `main` @ `5d10200`, the PR #22 merge). Under review — NOT merged; pl_06 content remains unimplemented (dormant), pl_07–pl_09 remain future work.
**Slice:** N4.4-A per [N44_IMPLEMENTATION_ROADMAP.md](N44_IMPLEMENTATION_ROADMAP.md) — ruins foundation + pl_05 playable + the altar completion boundary.
**Design contract:** [N44_PREPRODUCTION_REPORT.md](N44_PREPRODUCTION_REPORT.md) · [N44_ARCHITECTURE_DESIGN.md](N44_ARCHITECTURE_DESIGN.md) · [N44_TEST_STRATEGY.md](N44_TEST_STRATEGY.md) · [N44_OWNER_DECISIONS.md](N44_OWNER_DECISIONS.md).

---

## 1. Scope delivered

- The exploration chain continues past pl_04: **pl_04 completion/skip now activates pl_05** (the runtime beat table's pl_05 entry condition) and **reaching the authored altar threshold completes pl_05 exactly once and activates pl_06 DORMANT** (no pl_06 content in slice A — the crown interaction is N4.4-C, the awakening/vision N4.4-D).
- New stage-owned child component **`PrologueRuinsEnvironment`** (`scripts/narrative/PrologueRuinsEnvironment.gd`): placeholder ruin zones (exterior → interior passage → hidden chamber), the one-way zone-state machine with the chamber-reveal trigger, the hidden-until-revealed altar group with the labelled crown continuity placeholder, and TWO identical U2-placeholder mark glyphs on ruin surfaces (environmental scenery, deliberately NOT inspectable).
- Authored band extension: `PrologueExplorationStage.ROAD_MAX_X` `800 → 2200` (the road path physically continues into the ruins as its floor; camera limits extend with the band; the limits == bounds containment guarantee is unchanged).
- The O6 documented default skip chain: pl_03 skip → pl_04; **pl_04 skip → pl_05**; **pl_05 skip → dormant pl_06**; pl_06 skip deliberately NOT implemented in N4.4-A (O4/N4.4-D scope).
- Status texts for pl_05 and dormant pl_06 (honest about the slice); the N4.2 fallback text corrected to stop claiming "later beats are not implemented".

## 2. Design traceability (requirement → implementation)

| Source ID | Implementation | Verified by |
|---|---|---|
| R6 (pl_05 exit = reach altar) | stage `_process_pl_05` one-shot `ruins_altar_reached` at `_ruins.altar_x()` | N44A suite shell A |
| R9 (pl_06 entry = pl_05 finished) | shell `_on_ruins_altar_reached` → record pl_05 once → activate pl_06 | N44A + N43C A11b |
| R3/R5 (route + chamber + altar) | component zone table (1400/1800/2050 thresholds, O7 placeholders) | N44A unit + shell A + visual pass |
| R4 (environmental storytelling only) | NO pl_05 dialogue (Beat 05 has no approved line), no NPC, no prompt in A | N44A shell A ("no pl_05 dialogue opens") |
| R20 (ruins name OPEN) | no name anywhere; "[Placeholder art]" labels only | visual pass + N44A status assertions |
| R21/U2 (symbol consistency) | identical two-rect glyph geometry on both ruin glyphs (same shape as the N4.3-B props) | N44A unit (measured geometry equality) |
| R16 (exactly-once) | one-shot stage guard + shell active-beat validation + NarrativeState idempotence | N44A shells A/E + N43C A12 |
| R19 (crown = visual continuity, no inventory) | `CrownPlaceholder` ColorRect, no interaction path in the component | component purity greps + N44A |
| O6 default (skip chain continues) | `skip_current_exploration_beat` pl_04→pl_05, pl_05→pl_06 | N44A shell B + N43C B4/B5 |
| Architecture §2.1 Option A (continuous world) | band extension, no second stage, no scene reload | N43A containment (unmodified guarantees) |
| Architecture §2.2 child component | `PrologueRuinsEnvironment` stage-owned, atomic fail-closed build | N44A D6 matrix |
| Architecture §2.3 Option A (no new runner ops) | zero `SequenceRunner` changes in this slice | diff review |

## 3. Architecture result

- **Reuse without modification:** PrologueExplorer (bounds via constructor args), DialoguePanel, PlayerControlLock, SequenceRunner (zero changes), PrologueMarkInspectables (pl_04 untouched except the out-of-bounds test probe moving with the band).
- **Narrow extension:** PrologueShell (chain + skip + status texts), PrologueExplorationStage (constants, component build, pl_05 branch, `set_active_beat` prompt hygiene), PrologueBeats (pl_05/pl_06 ids + titles).
- **New N4.4-A component:** `PrologueRuinsEnvironment` (the proven `PrologueMarkInspectables` pattern: instance-method threshold table, D6 validation before construction, staging-parent commit, test-only failure subclasses, no production test seam).
- **Zero generic infrastructure, zero new runner ops, zero new scenes, zero new assets** (all presentation is labelled code-built placeholder geometry; `assets/` untouched).

## 4. Defects found and fixed during implementation

1. **Stale-prompt leak across the beat change (F16-class, real production defect):** a skip landing between the recognition opening and the next gated poll could carry a visible `[E] Inspect` prompt into pl_05 (the old flow hid it via `end_segment()`, which no longer runs). Fixed in `set_active_beat`: only pl_04 polls the prompt; every other beat hides it. Regression-tested ("the pl_04 inspection prompt NEVER leaks into the post-pl_04 beats") and caught first by the N43B suite — the test found the bug before the visual pass did.
2. **Dormant-status text overflow:** the first dormant pl_06 detail text (~170 chars) overflowed the unwrapped placeholder label layout (measured 1318px on a 1280 viewport). Shortened to an honest one-liner; both labels are now measured on-screen in the N44A suite.

## 5. Verification evidence

### 5.1 Automated (exact commands)

- Suite: `godot --headless --script res://tests/test_n44a_ruins_foundation.gd` → **PASS: All 96 N44A Ruins Foundation checks** (exit 0), registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
- Stability: **10 consecutive runs, all exit 0** (`PASS: All 96 …` every time; logs `/tmp/n44a_run_1..10.log`).
- Full regression: `bash tests/run_all.sh` → **ALL SUITES PASSED (exit 0)**: verifier **256** checks, world clock, P0 unit, M8, P1, progression ×3, specialists, research, structures, gameplay ×10, narrative foundation, dialogue, runner, **N4.0 66, N4.1 87, N4.2 113, N43A 111, N43B 193, N43C 186, N44A 96**.
- Real files: profile/save + sidecars byte-exact untouched (asserted in-suite, every run); no input state leaks.

### 5.2 Windowed visual pass (genuinely performed)

`scripts/tools/n44a_visual_pass.gd` under Xvfb (1280x720, gl_compatibility) — **10 screenshots** in `/home/z/my-project/download/n44a_visual/` (one redundant near-duplicate removed → 9 kept + contact sheets): pl_04 recognition, pl_05 entry, exterior threshold (natural walk), exterior walls + glyph, interior passage, hidden-chamber reveal (altar+crown appear), altar approach, dormant-pl_06 completion boundary, east-bound camera-independent UI. Reviewed by a human (this agent) against the checklist: camera framing correct at every position, actor visible, layout coherent, placeholders labelled, UI readable and never displaced, no clipping, no missing resources, no error overlays.

## 6. N4.4-B handoff (what B can safely build on)

- **Component exists and is owned:** `PrologueRuinsEnvironment` (stage-owned child; `ruins()` accessor on the stage). B adds presentation polish INSIDE this component — no ownership redesign needed.
- **Zone states are live:** `zone_state()` / `zone_state_changed` / `chamber_revealed()` are ready as B's presentation triggers; the reveal currently shows the hidden altar group (B replaces/refines this presentation per O2/O3).
- **Altar group nodes:** `AltarGroup/ChamberGlow`, `AltarGroup/AltarStone`, `AltarGroup/CrownPlaceholder` (hidden until reveal) — B's reveal presentation and C's interaction prompt anchor to these authored names.
- **Lifecycle seams:** the stage's pl_05 branch polls only `update_explorer_x` + the altar threshold; B can extend the component's presentation without touching the completion contract. The two-lock arrangement and generation guards are untouched and regression-covered.
- **Data B must receive:** the vision data freeze (R12 fragment set, R13 fence) is B's own gate (O2 baseline = fullscreen labelled states; no camera-focus op required — O3 stays OPEN).
- **A deliberately does NOT implement:** the altar/crown prompt (C, O5), the interact handshake (C), awakening/vision/completion (D, O4), any pl_07 content, any audio (O8).
- **Known technical risks for B:** the component's presentation nodes are plain ColorRects (B replaces visuals, keep node names or update the N44A structural assertions); the reveal is threshold-driven — any B-side camera work must keep the measured containment contract (N44A stage 11 + N43A suite).

## 7. Known limitations and review findings (P0–P3)

- **P0/P1:** none found (independent diff review + full regression clean).
- **P2 (documented, decision-gated):** O6 remains OPEN — the implemented pl_04-skip behavior is the documented default (skip → pl_05) and the PR flags it for owner review; flipping to the N4.3-epoch behavior is a one-branch change in `skip_current_exploration_beat` (the roadmap's "explicit reviewable constant" was implemented as a documented branch instead, because pre-writing the epoch branch would have preserved its now-false boundary text; the flip diff is one branch + one status-text decision).
- **P3:** `scripts/tools/n43c_visual_pass.gd`'s terminal wait (`n43_segment_complete`) is unsatisfiable under the N4.4-A chain — it is superseded for N4.4-A by `n44a_visual_pass.gd` and should be updated/retired in N4.4-E (left untouched here: historical N4.3 evidence tooling).
- **P3:** the runtime design's decision-record table still carries its pre-existing duplicate D8/D9 rows (recon finding #4 — unrelated to this slice, untouched).
- **P3:** the visual harness captured one redundant near-duplicate frame (removed from the evidence set; the harness guard is a convenience, not a contract).
- **Design-doc refinements recorded (narrow, non-owner):** `set_active_beat` now owns prompt hygiene on beat changes (architecture §3.2's activation contract extended by the defect fix above); the N4.2 fallback text is now accurate — both are recorded here and in the PR rather than silently editing the merged design documents.

## 8. Owner decisions touched

- **O6 — still OPEN.** Implemented the documented default only; no ruling made. **This is the one decision the PR asks the owner to confirm** (its ambiguity affects the pl_04-skip contract; everything else proceeds on placeholders).
- **O7 (staging values), O1 (ruins identity), U2 (mark design):** placeholders only — thresholds 1400/1800/2050, unnamed grey-stone family, identical two-rect glyph. No canon created.
- **O2/O3/O4/O5/O8:** untouched — no vision, no camera op, no pl_06 skip, no altar prompt, no audio.
