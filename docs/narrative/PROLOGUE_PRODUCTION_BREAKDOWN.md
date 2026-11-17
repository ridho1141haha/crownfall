# Crownfall — Prologue Production Breakdown (N4 preparation)

**Status:** Production readiness inventory ONLY. Nothing here is implemented, and nothing here converts an OPEN story detail into canon.  
**Story source:** [`PROLOGUE_STORY_DESIGN.md`](PROLOGUE_STORY_DESIGN.md) — beats, character direction, and lore boundaries.  
**Runtime source:** [`NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`](NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md) — N1–N3 foundation (dialogue panel, sequence runner, control lock).  
**Baseline:** `main` @ `eb82ae4d63a33a5c0fb9bb3f17f4bf832860c79a` (after PR #11 merge; N1–N3 runtime is implemented).

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

Entry/exit contract: New Game → pl_01…pl_09 → `scenes/world/ForgottenShore.tscn` (fresh session). Continue bypasses everything (technical design §A). No mid-Prologue save.

## 2. Per-beat production needs

### pl_01 — The Lost World
- **Environment:** Aetherion prosperity → eclipse transition → ruins. **N** (new background art, 2–3 states + transition shader/tint).
- **Characters:** none. **E/N** (no new character work).
- **Audio:** opening music prosperity→loss; ambient. **N**.
- **Camera:** slow pan / static framing with fades. **N** (framing data; runner `change_scene`/wait already exist).
- **Animation:** none. **—**.
- **Test criteria:** plays once on New Game; skippable per policy; reveals no Great Eclipse cause.

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
| Voice acting | **FUTURE / OPTIONAL** | Initial implementation may use text-only dialogue; no voice recording is required |

## 4. Suggested implementation order (post-foundation)

1. Scene shell + entry routing (New Game → pl_01; handoff to Forgotten Shore) with the runner's change_scene op.
2. pl_01 + pl_02 cinematic pass with placeholder art/audio (labelled).
3. pl_03 + pl_04 interactive pass (movement, inspect, dialogue panel).
4. pl_05 + pl_06 (chamber, altar, crown interaction, vision) — highest risk; do last in art but first in design review.
5. pl_07 + pl_08 + pl_09 handoff; wire fresh Forgotten Shore session and save policy.
6. Polish, skip policy, windowed inspection.

No step above may ship an OPEN detail as canon. All placeholder assets must be visibly labelled/removable.

## 5. Test criteria per beat (summary)

Every beat must pass: plays exactly once per run in order; skip/cancel per policy restores control; no dialogue/sequence input leaks into movement or world commands; completion is recorded exactly once; scene transitions happen at most once; no `SCRIPT ERROR`/`Parser Error` in logs; windowed inspection confirms framing, text readability, and control handoff (pl_09).
