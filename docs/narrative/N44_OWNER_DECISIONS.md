# Crownfall — N4.4 Owner Decision Register

**Status:** Every decision below is **OPEN until the project owner explicitly approves it**. Nothing in the N4.4 design package implements any of these; all affected values ship as labelled placeholders with the documented fallback. **Exception: O6 is APPROVED (owner ruling, 2026-11-18, Option A — skip chain continues); all other decisions below remain OPEN.**
**Related:** [N44_PREPRODUCTION_REPORT.md](N44_PREPRODUCTION_REPORT.md) (R-matrix) · [N44_ARCHITECTURE_DESIGN.md](N44_ARCHITECTURE_DESIGN.md) · [N44_IMPLEMENTATION_ROADMAP.md](N44_IMPLEMENTATION_ROADMAP.md) (gating graph).

---

## U2 — Final visual design of the recurring mark

### Current approved status
OPEN (Story Design §10: "Royal symbol's exact design — OPEN; visual consistency required; meaning remains mysterious"). N4.3-B ships ONE identical labelled two-rect placeholder glyph on all three props (consistency verified by tests).

### Existing evidence
Story §2 bullet ("the same unresolved royal symbol appears repeatedly"), §7 ("One consistent royal-symbol design"), Beat 04 ("symbol's visual design must be consistent"), Beat 06 (the symbol reappears in the vision), N43B design (identical-glyph contract + tests).

### Why this decision matters to N4.4
The symbol appears in **three new N4.4 contexts**: carved on ruin surfaces (R3 clues), at the altar/crown area (R5/R21), and inside the vision fragments (R12). If the owner changes the design, every surface updates together — knowing the decision BEFORE slice A avoids re-touching the ruins component after it ships.

### Option A — Keep the current placeholder glyph for N4.4
- **Description:** the two-rect labelled placeholder continues on all surfaces.
- **Advantages:** zero rework; consistency already tested; implementation never blocks.
- **Disadvantages:** final art still owed before release.
- **Technical consequences:** none (placeholder contract unchanged).
- **Narrative consequences:** none (meaning stays mysterious).

### Option B — Approve the final design now
- **Description:** owner supplies/describes the mark; implementation renders it once (one shared glyph builder) across road props, ruins, altar, vision.
- **Advantages:** visual continuity locked across the whole Prologue in one pass.
- **Disadvantages:** blocks slice A on art approval unless phased; requires the glyph to remain meaning-neutral.
- **Technical consequences:** single shared renderer so future changes stay one-line; no new systems.
- **Narrative consequences:** the mark becomes a fixed visual canon element.

### Recommendation
**Option A for N4.4 implementation, with a standing offer of B:** if the owner approves a design during N4.4, the single-renderer approach makes the swap cheap. N4.4 must not block on this.

### Owner approval
OPEN — placeholder continues unless explicitly approved otherwise.

---

## U4 — Exact prop placement and staging values (N4.3 road)

### Current approved status
OPEN for the *final* values; the N4.3 implementation ships authored placeholder staging (positions/bounds verified by tests).

### Existing evidence
N43B design register (U4); N43A layout contract (bounds == camera band; containment-tested).

### Why this decision matters to N4.4
**Weakly.** N4.4 does not move the road props; it adds NEW staging east of them. The road's placeholder values remain authoritative unless the owner wants a holistic pass. Per the mission instruction, the dependency is not forced: N4.4 proceeds on its own placeholder staging (new decision O7).

### Option A — Leave U4 scoped to the N4.3 road (recommended)
- **Description:** U4 stays a road-only decision; N4.4 staging is tracked separately (O7).
- **Advantages:** honest scoping; no artificial coupling.
- **Disadvantages:** two staging approvals eventually.
- **Technical consequences:** none.
- **Narrative consequences:** none.

### Option B — One holistic staging pass covering road + ruins
- **Description:** owner reviews all Prologue staging coordinates together after N4.4 lands.
- **Advantages:** single review; consistent spacing rhythm.
- **Disadvantages:** delays a final pass until N4.4 exists; no implementation impact.
- **Technical consequences:** constants centralized already (authored constants pattern).
- **Narrative consequences:** none.

### Recommendation
**Option A** now; B as a later polish activity.

### Owner approval
OPEN (no change proposed by N4.4).

---

## U5 — Final interaction prompt wording

### Current approved status
OPEN (`[E] Inspect` is the explicitly provisional N4.3-B placeholder).

### Existing evidence
N43B design register (U5); `PrologueMarkInspectables.PROMPT_TEXT` comment; N43C visual checks verify the placeholder as a placeholder.

### Why this decision matters to N4.4
Two prompts exist in N4.4: the pl_04 inspect prompt (this decision) and the **new altar/crown prompt** (new decision O5, same wording family). Approving U5 first makes O5 a one-line derivative.

### Option A — Keep `[E] Inspect` through N4.4 (recommended)
- **Description:** placeholder continues; O5 uses the same provisional family (`[E] …`) for the altar.
- **Advantages:** consistent placeholder language; no blocking.
- **Disadvantages:** final wording still owed.
- **Technical consequences:** none (constant).
- **Narrative consequences:** none.

### Option B — Approve final inspect wording now
- **Description:** owner fixes the inspect verb/phrase; altar wording derived in O5.
- **Advantages:** one approval covers both prompts.
- **Disadvantages:** may prematurely canonize phrasing before the altar context is played.
- **Technical consequences:** constant swap + test-text updates (listed in slice C).
- **Narrative consequences:** prompt text becomes canon.

### Recommendation
**Option A** for implementation; bundle U5+O5 into one owner review after slice B's storyboard exists.

### Owner approval
OPEN — placeholder continues unless explicitly approved otherwise.

---

## O1 — Ruins environment identity (name & visual language)

### Current approved status
OPEN (Story §10: "Name of the ruins — OPEN (may remain unnamed)"); no visual identity approved.

### Existing evidence
Story Beat 05 ("a larger ancient ruin"; environmental storytelling only); breakdown pl_05 environment row ("N multi-state or P"); §7 asset list ("Ruin exterior, hidden chamber, altar, and crown").

### Why this decision matters to N4.4
Zone presentation needs a coherent visual language (silhouette, materials, tint family) even at placeholder level, and the implementation must not imply a name/kingdom (R20 fence).

### Option A — Unnamed, neutral ancient-royal placeholder language (recommended baseline)
- **Description:** grey/weathered stone family, recurring glyph only, no text, no banners with words, no name anywhere.
- **Advantages:** zero lore risk; matches the "clues, not answers" pillar; implementation proceeds.
- **Disadvantages:** less atmosphere until art approval.
- **Technical consequences:** none (code-built placeholders).
- **Narrative consequences:** none (name stays OPEN).

### Option B — Owner-approved identity now (name + palette + motif set)
- **Description:** owner defines the ruin's look (and optionally an internal, non-shown working name).
- **Advantages:** stronger environmental storytelling immediately.
- **Disadvantages:** blocks slice A/B on art direction; risks implying dynasty/era (fence R13-adjacent).
- **Technical consequences:** placeholder swap later (cheap if Option A's structure is kept).
- **Narrative consequences:** ruins identity becomes canon.

### Recommendation
**Option A** for N4.4; revisit identity with the broader art pass.

### Owner approval
OPEN.

---

## O2 — Fragmented-vision presentation language

### Current approved status
Content list APPROVED (R12: kingdom, silhouette, symbol, fading light, interrupted destruction); presentation language unapproved.

### Existing evidence
Story Beat 06 bullets 4–5; breakdown pl_06 "vision composition … N; visuals must NOT identify…"; architecture §2.3 options.

### Why this decision matters to N4.4
The vision is the emotional peak and the strictest lore fence; its placeholder rendering must be chosen deliberately so it can upgrade to approved art without rework.

### Option A — Fullscreen labelled caption states over the chamber (recommended baseline)
- **Description:** each fragment is a labelled fullscreen placeholder state (same family as pl_01's prosperity/eclipse captions), paced by runner waits, ended abruptly by `finish`.
- **Advantages:** no new ops; deterministic; cancel-safe; direct precedent; upgrades cleanly to art.
- **Disadvantages:** less cinematic until art exists.
- **Technical consequences:** none beyond the new component's presentation layer.
- **Narrative consequences:** none (fragments stay unnamed/silhouetted).

### Option B — Camera moves + in-world fragment staging (requires O3)
- **Description:** close-on-crown reveal, cuts between staged fragment scenes.
- **Advantages:** closer to the intended cinematic feel ("fades/short cuts").
- **Disadvantages:** new runner op (D9) + camera contract work + more failure surface; blocks D on approval.
- **Technical consequences:** schema/validation/test additions to the runner.
- **Narrative consequences:** none if fencing held.

### Option C — Dedicated vision scene + transitions
- Rejected: extra scene-transition surface for placeholder-stage content; contradicts reuse-first.

### Recommendation
**Option A now; B available later** without invalidating A's authored cue/wait data.

### Owner approval
OPEN (baseline A is the implementation default; B only on approval).

---

## O3 — Camera-focus operation (D9) activation

### Current approved status
PROPOSED, deferred (runtime design D9: "Camera-focus op and pause_world op — PROPOSED; not needed by foundation").

### Existing evidence
Breakdown pl_05/pl_06 camera rows ("reveal framing at the chamber"; "close on crown → vision sequence"); breakdown §3 ("Camera-focus op — PROPOSED; add only if beat staging requires it").

### Why this decision matters to N4.4
The reveal framing and close-on-crown beats are the first staging that *would* need it. The placeholder baseline (O2-A) does not require it.

### Option A — Keep deferred through N4.4 (recommended)
- **Description:** static explorer camera + fullscreen placeholders.
- **Advantages:** no runner growth; N4.4 stays within the verified contract.
- **Disadvantages:** flatter presentation until approved.
- **Technical consequences:** none.
- **Narrative consequences:** none.

### Option B — Approve and implement a minimal `camera_focus` op
- **Description:** one typed op (validated target/framing), stage/camera integration, full test matrix.
- **Advantages:** enables the authored reveal/close-up staging verbatim.
- **Disadvantages:** runner schema growth; new failure/cancel cases; slice-B scope grows.
- **Technical consequences:** new op in the allowlist + validation + tests (D5 discipline).
- **Narrative consequences:** none.

### Recommendation
**Option A** for N4.4; B remains a standalone, separately-reviewable proposal (never mixed into a content slice).

### Owner approval
OPEN.

---

## O4 — Skip granularity during the awakening/vision moment

### Current approved status
CONTRADICTION to resolve (recon finding #1): runtime beat table marks pl_06 Skip "Not allowed for the vision moment (PROPOSED)" while the breakdown says "skip policy respected" and the current mechanism is per-beat.

### Existing evidence
Runtime N0 table pl_06 row; breakdown pl_06 test row; the implemented per-beat `skip_current_exploration_beat()` contract.

### Why this decision matters to N4.4
The skip path is a distinct completion path (exactly-once rules §5.5-3); whether the vision can be skipped changes slice D's state machine and tests.

### Option A — Per-beat skip allowed anywhere in pl_06 (recommended)
- **Description:** skip records pl_06 once from any phase (contact/vision/dialogue); the vision is presentation-only, so skipping mid-vision closes it safely (the generation-guard contract already proven by cancel-during-recognition).
- **Advantages:** one consistent skip rule across beats; reuses the verified machinery; accessibility-friendly.
- **Disadvantages:** players can skip the emotional peak (acceptable — cinematic moments stay short by design).
- **Technical consequences:** the skip-during-vision ordering case joins the test matrices (already designed in N43C patterns).
- **Narrative consequences:** none.

### Option B — Vision moment is unskippable
- **Description:** skip refused while the vision runs (allowed before contact and during the post-vision dialogue).
- **Advantages:** preserves the peak for every player who triggered it.
- **Disadvantages:** a third skip rule to document/test; a refusal UX needs definition (silent ignore vs feedback); diverges from the per-beat precedent.
- **Technical consequences:** refusal branch + tests; status text nuance.
- **Narrative consequences:** none.

### Recommendation
**Option A** (consistency + proven machinery); B only if the owner wants the peak protected.

### Owner approval
**APPROVED (owner ruling, 2026-11-19 — Option A):** per-beat skip allowed at any point during `pl_06`, including during vision playback and post-vision dialogue; terminates sequence safely, releases locks, hides overlay/prompt, records `pl_06` once, never starts `pl_07`.

---

## O5 — Altar/crown interaction prompt wording

### Current approved status
OPEN (no approved wording exists; U5 governs only the inspect prompt).

### Existing evidence
Breakdown pl_06 "crown + altar interaction"; story Beat 06 bullet 1 ("approach and interact with the crown"); D5-gate prompt precedent.

### Why this decision matters to N4.4
Slice C needs prompt text; unapproved wording must not become canon.

### Option A — Provisional family placeholder (recommended)
- **Description:** e.g. `[E] Touch the crown` — explicitly labelled provisional, same family as U5's `[E] Inspect`.
- **Advantages:** consistent; non-canon; unblocks slice C.
- **Disadvantages:** final wording owed.
- **Technical consequences:** constant swap later.
- **Narrative consequences:** none while provisional.

### Option B — Decide together with U5 after slice B
- **Description:** one owner review fixes both prompt texts with the storyboard in hand.
- **Advantages:** context-informed wording; single review.
- **Disadvantages:** none (placeholders cover the gap).
- **Technical consequences:** two constant swaps (cheap).
- **Narrative consequences:** prompt text becomes canon at approval.

### Recommendation
**Option A now, resolved by B** in one bundled review.

### Owner approval
OPEN.

---

## O6 — Skip-chain extension & N4.4 boundary text (the pl_04-skip policy)

### Current approved status
Epoch-scoped contract: N4.3 planning §4 says pl_04 skip "ends the N4.3 segment… does not start pl_05" (written when pl_05 did not exist). The runtime beat table marks all beat Skips "Allowed (PROPOSED)".

### Existing evidence
N4_3_PLANNING.md §4; the per-beat skip precedent (pl_03 skip → pl_04, implemented + tested); the N4.3-C boundary status text assertion.

### Why this decision matters to N4.4
Slice A changes what happens after pl_04 completes OR is skipped. Keeping the epoch behavior would make N4.4 unreachable via skip — an inconsistency the full-flow suite would surface as a designed dead-end.

### Option A — Extend the chain: pl_04 skip → pl_05 (recommended)
- **Description:** the skip chain continues (pl_01→pl_02→pl_03→pl_04→pl_05→pl_06); the "defined boundary" moves to post-pl_06; the boundary status text is updated to name the N4.4 boundary.
- **Advantages:** consistent with the implemented pl_03 precedent; no dead-end; one rule for the whole segment.
- **Disadvantages:** deliberately supersedes an N4.3-era sentence (documented as such, not silently).
- **Technical consequences:** shell skip path + N43C/N44 test text updates (explicitly listed; no weakening).
- **Narrative consequences:** none (skipping still records each beat once).

### Option B — Keep the N4.3 epoch behavior (skip ends the segment after pl_04)
- **Description:** skipping pl_04 leaves the segment at the old boundary; pl_05+ only via normal completion.
- **Advantages:** zero change to N4.3 behavior/tests.
- **Disadvantages:** inconsistent UX (skip pl_03 → continue; skip pl_04 → dead end); the boundary text would then be correct again but the flow asymmetric.
- **Technical consequences:** slice A's chain extension applies only to normal completion.
- **Narrative consequences:** none.

### Recommendation
**Option A**, documented as a superseding decision with the N4.3 sentence annotated.

### Owner approval
**APPROVED (owner ruling, 2026-11-18).**
- **Approved default skip-chain policy:** skipping `pl_04` continues directly to `pl_05` (Forgotten Ruins) — **Option A**, as recommended. This behavior is intentional and is the approved default for N4.4; the N4.3-epoch sentence ("pl_04 skip ends the segment… does not start pl_05") is superseded by this explicit ruling, not silently rewritten.
- The context, options, evidence, and recommendation above are preserved unchanged as the decision's original record.
- Implementation note: N4.4-A shipped exactly this behavior (skip chain continues: pl_04 skip → pl_05, pl_05 skip → dormant pl_06; pl_06 skip remains N4.4-D/O4 scope) — the implemented behavior now matches an approved decision with no code change required. The boundary TEXT part of this decision (the post-pl_06 N4.4 boundary wording) stays with slice D/N4.4-E.

---

## O7 — N4.4 staging values (ruins zones, chamber, altar/crown)

### Current approved status
OPEN (new decision; the N4.4 counterpart of U4).

### Existing evidence
Breakdown pl_05/pl_06 rows (environment/crown/altar "N"); preproduction scene specs §3 (placeholder coordinates proven feasible at the N4.3 scale).

### Why this decision matters to N4.4
Zone widths, chamber/altar positions, and reveal framing are authored placeholders; final values are an owner pass.

### Option A — Ship authored placeholders; final pass later (recommended)
- **Description:** feasible-scale constants now; one owner staging pass after slice E.
- **Advantages:** never blocks; tests protect the invariants (bounds == band, containment).
- **Disadvantages:** final pass still owed.
- **Technical consequences:** constants only.
- **Narrative consequences:** none.

### Option B — Owner approves staging before slice A
- **Description:** values fixed up-front.
- **Advantages:** one pass total.
- **Disadvantages:** blocks implementation on art judgment without a playable context.
- **Technical consequences:** none.
- **Narrative consequences:** none.

### Recommendation
**Option A.**

### Owner approval
OPEN.

---

## O8 — Audio scope for N4.4 (ambience, motifs, vision audio)

### Current approved status
APPROVED as a *need* (breakdown rows: ruin ambience/low drone; stronger resonance motif; fragmented/distorted vision audio); **OPEN** as production (no audio assets exist for it; voice acting FUTURE per breakdown §3).

### Existing evidence
Story §7 audio list; breakdown pl_05/pl_06 audio rows; `assets/audio/` inventory (6 gameplay SFX only — verified).

### Why this decision matters to N4.4
Decides whether slices ship silent placeholders (current N4.2/N4.3 precedent: no audio shipped) or whether a minimal audio hook is added.

### Option A — Silent placeholder presentation through N4.4 (recommended)
- **Description:** no audio in N4.4; the needs stay registered; audio arrives with the broader art/audio pass (N4.6 presentation QA).
- **Advantages:** consistent with shipped slices; no audio pipeline decisions forced early.
- **Disadvantages:** motif recall (R11) is carried visually only for now.
- **Technical consequences:** none.
- **Narrative consequences:** none (motif design remains OPEN).

### Option B — Minimal audio hook + placeholder clips
- **Description:** a cue-player audio branch with generated/placeholder clips.
- **Advantages:** audible feedback earlier.
- **Disadvantages:** audio pipeline decisions (channels, buses) are explicitly TBD in the breakdown; placeholder audio risks canonizing tone.
- **Technical consequences:** new audio path in the presentation layer + tests.
- **Narrative consequences:** motif tone becomes de-facto canon.

### Recommendation
**Option A.**

### Owner approval
OPEN.

---

## Register summary

| ID | Decision | Blocks implementation? | Blocks a merge? | Default while OPEN |
|---|---|---|---|---|
| U2 | Mark visual design | No (placeholder) | No | two-rect labelled glyph |
| U4 | Road prop staging | No (road untouched) | No | authored N4.3 values |
| U5 | Inspect prompt wording | No (placeholder) | No | `[E] Inspect` |
| O1 | Ruins identity | No (placeholder) | No | unnamed neutral stone family |
| O2 | Vision presentation | No (baseline A) | No | fullscreen labelled states |
| O3 | Camera-focus op | No (not needed by baseline) | No | deferred (D9) |
| O4 | Vision-moment skip | No (Option A default) | Slice D flagged | per-beat skip allowed |
| O5 | Altar prompt wording | No (placeholder) | No | `[E] Touch the crown` (provisional) |
| O6 | Skip-chain extension & boundary text | No (APPROVED — Option A) | No (merge gate RESOLVED 2026-11-18) | approved: skip chain continues |
| O7 | N4.4 staging values | No (placeholder) | No | feasible-scale constants |
| O8 | Audio scope | No (silent) | No | silent placeholders |

**Rule in force:** no OPEN item becomes canon through implementation; every default above is visibly labelled and revertible.


---

## N4.4-B implementation review-gate note — 2026-11-19

The owner-approved Rev 4 implementation plan preserves the following decisions
as OPEN; the implementation must not silently convert the placeholders into
canon or add deferred runtime systems:

- **O2 — Vision presentation language:** remains OPEN. N4.4-B uses labelled,
  fullscreen placeholder captions only; no vision sequence is executed.
- **O3 — Camera-focus operation (D9):** remains OPEN and deferred. No changes
  to `SequenceRunner.gd` or `NarrativeData.gd`.
- **O5 — Altar/crown prompt wording:** remains OPEN. The implementation adds
  only the provisional `ALTAR_PROMPT_PROPOSAL_TEXT` constant
  (`[E] Touch the crown`); no prompt node, input polling, or interaction
  wiring is introduced.

These notes record implementation scope, not a new owner decision.
