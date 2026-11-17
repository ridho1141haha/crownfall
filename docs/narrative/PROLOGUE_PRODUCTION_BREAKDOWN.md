# Crownfall — Prologue Production Breakdown (N4 preparation)

**Status:** N4.0 (entry + profile gate), N4.1 (functional Prologue shell), and N4.2 (beats pl_01 + pl_02 with shell auto-start/chaining) are IMPLEMENTED and verified. The remaining Prologue beats (N4.3–N4.6) remain production-readiness inventory ONLY — nothing else here is implemented, and nothing here converts an OPEN story detail into canon.  
**Story source:** [`PROLOGUE_STORY_DESIGN.md`](PROLOGUE_STORY_DESIGN.md) — beats, character direction, and lore boundaries.  
**Runtime source:** [`NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`](NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md) — N1–N3 foundation (dialogue panel, sequence runner, control lock).  
**Baseline:** N4.0 verified against `main` @ `a34e5b3` (PR #12 merge; N1–N3 runtime implemented).

Legend for asset status: **E** = Existing, **R** = Reusable with modification, **M** = Missing, **P** = Placeholder acceptable (labelled, non-canon), **N** = Requires new production. Complexity: **S** / **M** / **L**.

---

## 1. Scene sequence and dependencies

| # | Beat | Scene type | Depends on | Complexity |
|---|---|---|---|---|
| 01 | The Lost World | Cinematic (no control) | — | M |
| 02 | A Faint Resonance | Cinematic flashback (no control) | pl_01 | S–M |
| 03 | The Wanderer | Interactive (movement/observation) | pl_02 | M |
| 04 | The Repeated Mark | Interactive (inspect props) | pl_03 | M |
| 05 | The Forgotten Ruins | Interactive (exploration → chamber) | pl_04 | L |
| 06 | The Crown's Call | Interaction then cinematic (vision) | pl_05 | L |
| 07 | The Unfinished Journey | Limited/cinematic transition | pl_06 | S |
| 08 | The Shipwreck | Cinematic (storm → fade) | pl_07 | M |
| 09 | Forgotten Shore | Interactive handoff → existing gameplay scene | pl_08 | M |

Entry/exit contract: New Game → Prologue (unless previously completed and player chooses Skip) → pl_01…pl_09 → `scenes/world/ForgottenShore.tscn` (fresh session). Continue bypasses everything and loads the existing world save. Skip is unavailable on the first-ever playthrough; after one successful completion, it is offered on later New Game starts. Completion eligibility is stored in a small global player profile, separate from world saves. No mid-Prologue save.

## 2. Per-beat production needs

### pl_01 — The Lost World
- **Environment:** Aetherion prosperity → eclipse transition → ruins. **N** (new background art, 2–3 states + transition shader/tint).
- **Characters:** none. **E/N** (no new character work).
- **Audio:** opening music prosperity→loss; ambient. **N**.
- **Camera:** slow pan / static framing with fades. **N** (framing data; runner `change_scene`/wait already exist).
- **Animation:** none. **—**.
- **Test criteria:** first-ever New Game cannot skip; later New Game may skip only after one successful Prologue completion; Continue bypasses; profile eligibility survives New Game/world-save replacement; invalid/missing profile safely locks Skip; reveals no Great Eclipse cause.

### pl_02 — A Faint Resonance
- **Environment:** old stone wall/ruin fragment. **N** (simple backdrop) or **P**.
- **Characters:** child Monarch. **N** (new sprite/silhouette; identity consistent with adult per Story Design §7).
- **Crown/altar/vision:** none. **—**.
- **Audio:** resonance motif (quiet). **N**.
- **Camera:** static close framing. **N**.
- **Animation:** small golden-light cracks, brief. **N** or **P**.
- **Test criteria:** exactly one small uncontrolled manifestation; no control/spellcasting shown.

### pl_03 — The Wanderer
- **Environment:** travel montage / sparse path. **P** acceptable.
- **Characters:** adult Monarch (walk). **R** (`player_monarch_sheet.png` walk cycle) or **N**.
- **Audio:** exploration ambience. **R/P**.
- **Camera:** follow player. **E** (`Camera2D` pattern).
- **Animation:** walk/idle. **E/R**.
- **Test criteria:** movement + observation work; internal line advances via dialogue panel; no world systems leak in.

### pl_04 — The Repeated Mark
- **Environment:** 2–3 props (pillar, mossy stone, broken artifact). **N** or **P**.
- **Symbol asset:** ONE consistent royal-symbol design — **OPEN** (Story Design §10); use a labelled placeholder only. **P**.
- **Audio:** subtle discovery sting (optional). **N/P**.
- **Camera:** player-follow; inspect prompt near props. **E/R**.
- **Animation:** none. **—**.
- **Test criteria:** same symbol appears on all props; meaning stays unexplained; inspection uses the existing interaction/dialogue path.

### pl_05 — The Forgotten Ruins
- **Environment:** ruin exterior → interior → hidden chamber with altar. **N** (multi-state) or **P**.
- **Characters:** adult Monarch. **R/N**.
- **Crown/altar:** altar prop **N**; crown prop **N** (visual continuity object only — no inventory).
- **Audio:** ruin ambience, low drone. **N**.
- **Camera:** player-follow + reveal framing at the chamber. **R/N**.
- **Animation:** door/entry transition (optional). **P**.
- **Test criteria:** no NPC explains the history; route is environmental; altar interaction starts pl_06.

### pl_06 — The Crown's Call
- **Environment:** hidden chamber (reuse pl_05). **R**.
- **Characters:** Monarch hand/close-up (optional). **N/P**.
- **Crown/altar:** crown + altar interaction. **N**.
- **Vision composition:** ancient kingdom, ruler silhouette, recurring symbol, fading light, interrupted destruction. **N**; visuals must NOT identify the ruler/dynasty/kingdom/power source.
- **Audio:** stronger resonance motif + fragmented/distorted vision audio. **N**.
- **Camera:** close on crown → vision sequence (fades/short cuts). **N** (uses runner waits/fades when available).
- **Animation:** awakening flash, vision fragments. **N**.
- **Test criteria:** vision excludes protected mysteries; ends abruptly; skip policy respected; completion recorded exactly once.

### pl_07 — The Unfinished Journey
- **Environment:** shore/departure backdrop. **P**.
- **Audio:** transition music. **N/P**.
- **Camera:** limited or cinematic. **R**.
- **Test criteria:** destination/ship origin not stated; transitions into pl_08.

### pl_08 — The Shipwreck
- **Environment:** ship deck, storm sky, waves. **N** (concise cinematic only; no sailing sim).
- **Audio:** wind/waves/storm, then calm. **N**.
- **Camera:** cinematic, fade out before excess. **N**.
- **Animation:** ship rocking/damage (brief). **N/P**.
- **Test criteria:** storm-cause relation to crown stays unknown; no controllable ship; no overlong sequence.

### pl_09 — Forgotten Shore
- **Environment:** beach + wreckage; reuse Forgotten Shore shoreline identity. **N/R**.
- **Characters:** Monarch waking; crown shown briefly. **R/N**.
- **Audio:** calm beach ambience. **N/P**.
- **Camera:** player-follow, prompt control handoff. **E**.
- **Animation:** wake/idle. **E/R**.
- **Test criteria:** control returns promptly; crown continuity shown without dialogue; handoff enters a fresh Forgotten Shore session; world saves begin only here.

## 3. Cross-cutting needs

| Category | Status | Notes |
|---|---|---|
| Dialogue panel | **Implemented (N2)** | Speaker/body/advance; consumes input; no portraits/choices |
| Sequence runner | **Implemented (N3)** | Typed ops incl. change_scene (allowlisted) and wait; skip/cancel |
| Control lock | **Implemented (N2)** | Physics + unhandled input lock/unlock |
| Camera-focus op | **PROPOSED** | Not in N3; add only if beat staging requires it |
| Pause-world op | **PROPOSED** | Prologue scenes have no world simulation, so not needed yet |
| Title card / text overlay | **M** | pl_09 title card “CHAPTER I — FORGOTTEN SHORE” needs a small overlay (reuse banner pattern) |
| Royal symbol design | **OPEN / P** | Use one labelled placeholder until approved |
| Crown/altar props | **M/N** | Must not imply unapproved lore; placeholder first |
| Audio pipeline | **R** | `assets/audio/*.wav` + SFX player exist; music/ambience channels TBD |
| Dialogue source language | **DECIDED** | English is the default/source language for all authored in-game dialogue. Keep dialogue data ready for future localization without building a localization framework now |
| Localization pipeline | **FUTURE** | Additional languages are out of current N4 scope; do not block Prologue implementation |
| First-playthrough completion flag | **DECIDED** | Store `prologue_completed_once` in a minimal global player profile separate from world-save schema v2; only successful full completion unlocks Skip |
| Voice acting | **FUTURE / OPTIONAL** | Initial implementation may use text-only dialogue; no voice recording is required |

## 4. Suggested implementation order (post-foundation)

1. Scene shell + entry routing (New Game → pl_01; handoff to Forgotten Shore) with the runner's change_scene op.
2. pl_01 + pl_02 cinematic pass with placeholder art/audio (labelled).
3. pl_03 + pl_04 interactive pass (movement, inspect, dialogue panel).
4. pl_05 + pl_06 (chamber, altar, crown interaction, vision) — highest risk; do last in art but first in design review.
5. pl_07 + pl_08 + pl_09 handoff; wire fresh Forgotten Shore session and save policy.
6. Implement the approved first-playthrough gate and persistent profile flag; test first run, completed run, skip, Continue, and corrupted/missing profile.
7. Polish, windowed inspection.

No step above may ship an OPEN detail as canon. All placeholder assets must be visibly labelled/removable.

## 5. N4 implementation slices (proposed PR boundaries)

Keep N4 incremental. Each slice is a separate PR with one coherent responsibility, focused tests, and no Chapter I runtime work.

| Slice | Scope | Main deliverable | Must pass before next slice |
|---|---|---|---|
| N4.0 — Entry + profile gate | **IMPLEMENTED.** Minimal global `PlayerProfile`; New Game/Continue routing; first-playthrough Skip gate; overwrite confirmation compatibility | New Game enters the labelled Prologue route placeholder (`PrologueShell`); Continue loads world save; Skip hidden until one successful full completion; profile survives New Game and world-save replacement | Profile missing/corrupt fallback, atomic-write failure, first-run/returning-run/Continue tests (`tests/test_n40_profile_entry_gate.gd`, 66 checks); existing v1/v2 world saves and full gameplay suite remain green |
| N4.1 — Prologue shell | **IMPLEMENTED.** Functional shell at the same route path (`PrologueShell.tscn`/`PrologueShell.gd`): per-run `NarrativeState` + `DialoguePanel` + `SequenceRunner` owned by the shell, `play_sequence`/`skip_sequence`/`cancel_sequence` API for future beats (no sequence data authored), allowlisted `change_scene` (ForgottenShore only) through a single-transition exit guard, idempotent runtime init, labelled development-only menu-return exit. Exit semantics split: the development exit cancels a running sequence (completes nothing); a sequence-driven handoff lets the finishing sequence complete exactly once (`sequence_completed` + `NarrativeState`) | A playable vertical shell that can load and run a sequence without yet authoring all nine beats | Scene transitions allowlisted; input isolation and cleanup; no runtime errors; no canon details invented |
| N4.2 — Lost World + Faint Resonance | **IMPLEMENTED.** `scripts/narrative/PrologueBeats.gd` authors `pl_01_lost_world` + `pl_02_faint_resonance` (validated data only; pl_01 narration = Story Design candidate text verbatim; pl_02 = exactly one small uncontrolled manifestation; no Eclipse cause, no power origin, no crown); the shell auto-plays the first beat on route load (Engine meta `crownfall_prologue_autostart` override), chains pl_01 → pl_02 exactly-once, stages cues on a labelled placeholder stage via the existing `play_cue` op, and stops at the N4.2 boundary with no scene transition and no completion marking | Opening cinematic and childhood flashback playable on New Game through English narration (text-only panel + labelled placeholder captions; no art/audio assets shipped) | First-playthrough flow unchanged (N4.0 gate); skip eligibility untouched; Great Eclipse cause remains unknown; exactly one manifestation; no spellcasting/control shown; suite `tests/test_n42_prologue_beats.gd` (89 checks) |
| N4.3 — Wanderer + Repeated Mark | Beats pl_03 and pl_04 | Short interactive exploration and repeated-symbol inspection | Movement/inspect controls isolated correctly; symbol consistency; no premature lore explanation |
| N4.4 — Forgotten Ruins + Crown's Call | Beats pl_05 and pl_06 | Hidden chamber, altar interaction, awakening, fragmented vision | Protected mysteries remain hidden; crown is a persistent visual story object, not an inventory item |
| N4.5 — Unfinished Journey → Shipwreck → Forgotten Shore | Beats pl_07–pl_09 and fresh-world handoff | Sea departure, shipwreck, landing, Chapter I title card, control handoff | Profile completion flag set exactly once only after successful full completion; fresh shore session; no old save loaded accidentally |
| N4.6 — Integration + presentation QA | Whole Prologue, audio/polish, windowed testing, regression | Release-ready N4 Prologue experience | Full headless suite, first-time/returning-player matrix, windowed inspection, no input leaks or duplicate transitions |

### N4.0 profile and entry-flow contract

**Implemented (verified).** The concrete, as-built facts:

- Keep `SaveManager` and world-save schema v2 unchanged. ✅ (no SaveManager/session/schema edits)
- Profile: `scripts/narrative/PlayerProfile.gd`, stored at `user://player_profile.json` with schema `{"schema_version": 1, "prologue_completed_once": false}`. Strict validation (exact two-key shape, exact int schema version, bool flag; unknown/missing/unsupported data rejected). Atomic write: `.tmp` → re-read verify → staged rename with `.old` rollback. API: `load_profile(path) -> {ok, error}`, `is_prologue_completed_once() -> bool`, `mark_prologue_completed(path) -> bool` (reports persistence success; no Skip-related setter exists).
- Treat missing, malformed, unsupported-version, or unreadable profile data as **not completed** (Skip locked); it never blocks New Game or Continue. ✅
- Write the completion flag only after pl_09 completes successfully and the handoff to a fresh Forgotten Shore session is committed (N4.5). Never set it when the player chooses Skip. N4.0's runtime flow never calls `mark_prologue_completed`; only tests exercise it directly.
- If the player skips on an eligible later New Game, hand off to a fresh Forgotten Shore session (`crownfall_load_on_start = false`) without replaying Prologue beats. ✅
- Continue always bypasses Prologue and uses the existing world save (including legacy v1 saves); it never reads the profile. ✅
- Preserve the existing Start New Game overwrite confirmation (wording unchanged; the Cancel button is now named `CancelNewGameButton` for tests). The profile flag is never deleted when the world save is replaced. ✅
- No general profile/settings framework: one durable eligibility fact, no signals, no autoload. ✅
- Prologue route target: `res://scenes/narrative/PrologueShell.tscn` (`scripts/narrative/PrologueShell.gd`). Since N4.1 this is the **functional shell** (per-run `NarrativeState` + `DialoguePanel` + `SequenceRunner`, allowlisted sequence transitions, single-transition exit guard, labelled development-only menu-return exit). Since N4.2 the shell also auto-plays the authored opening beats from `scripts/narrative/PrologueBeats.gd` (headless override: Engine meta `crownfall_prologue_autostart`), observes their cues on a labelled placeholder stage, and chains them until the N4.2 boundary. Main's routing, gate, and overlays are unchanged; routing is observed headlessly via `Main.set_route_transition(Callable)` plus Engine metas `crownfall_profile_path` / `crownfall_menu_save_path`, shell exits via `PrologueShell.set_exit_transition(Callable)`, and beat cues via `PrologueShell.set_cue_player(Callable)`.
- Tests: `tests/test_n40_profile_entry_gate.gd` (66 checks: profile matrix, entry flow, fresh-session and legacy-save Continue behavior, placeholder sanity, real-file non-mutation), registered in `tests/run_all.sh` and the CI workflow; M8 integration slice now reaches Forgotten Shore through the real Skip path (39 checks).

### Cross-slice guardrails

- English is the authored source language for every dialogue line. No localization framework or voice acting is required in N4.
- Use clearly labelled, replaceable placeholders until visual/audio assets are approved.
- Do not implement Chapter I narrative beats as part of N4.
- Do not add quest systems, branching dialogue, chapter managers, cinematic editors, or arbitrary script execution.
- Every slice updates its tests and docs; no slice is merged with known parser/runtime errors or a failing gameplay regression suite.

## 6. Test criteria per beat (summary)

Every beat must pass: plays exactly once per run in order; skip/cancel per policy restores control; no dialogue/sequence input leaks into movement or world commands; completion is recorded exactly once; scene transitions happen at most once; no `SCRIPT ERROR`/`Parser Error` in logs; windowed inspection confirms framing, text readability, and control handoff (pl_09).
