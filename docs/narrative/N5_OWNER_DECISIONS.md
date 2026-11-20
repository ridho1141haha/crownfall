# Crownfall — N5 Chapter I Owner Decision Docket

**Status:** OPEN — decisions below materially shape Chapter I implementation slices. Protected lore (Crown origin, dynasty/ancestor, ancient kingdom name, power source, Great Eclipse cause, Greedling/Portal/Relic origins, Forgotten Shrine vs. Shrine of Growth identity) is deliberately **excluded** and remains OPEN.
**Baseline audited:** `main` @ `eef5c5a9100edbee403e0592b80e783e25ca6eb8` (2026-11-20)
**Companion roadmap:** [`N5_IMPLEMENTATION_ROADMAP.md`](N5_IMPLEMENTATION_ROADMAP.md)

---

## D-N5-01 — Exact early-game foothold milestone (`ch1_02_foothold`)
- **Exact question:** Which existing early-game gameplay milestone should complete `ch1_02_foothold`?
- **Why source inspection cannot resolve it:** `ForgottenShoreSession.gd` tracks resource collection (`EconomyLedger`), recruitment (`NPCPopulationManager`), and construction (`BuildingManager.wall_state_changed`), but no single authoritative "foothold established" fact exists in `ProgressionState.gd`.
- **Bounded options:**
  - **Option A (Recommended default):** First completed eastern wooden wall (`BuildingManager.WALL_ID == "wall_east_01"` reaching `WallState.STANDING`).
  - **Option B:** First villager recruited **and** first wall construction started (`BUILDING` or `STANDING`).
  - **Option C:** Any first structure built (`wall_east_01`, `wall_west_01`, `farm_west_01`, `farm_east_01`, or `watchtower_east_01`).
- **Recommended default:** **Option A** — directly prepares the player for the mandatory first night (`ch1_03_first_night`) using one unambiguous existing signal (`BuildingManager.wall_state_changed`).
- **Player-facing consequence:** Gives a single clear survival goal before dusk without adding a quest list.
- **Technical consequence:** Zero new gameplay state; one-shot listener in the narrow N5.0 boundary.
- **Blocking status:** **Blocks N5.1**; does **not** block N5.0 (integration boundary).

## D-N5-02 — `ch1_04_after_dawn` as separate beat vs. first-night resolution
- **Exact question:** Should `ch1_04_after_dawn` be implemented as its own narrative beat or folded into `ch1_03_first_night` sunrise resolution?
- **Why source inspection cannot resolve it:** `ForgottenShoreSession._on_sunrise_reached()` and `_on_night_resolved(survived, wall_held)` already emit distinct survival vs. breach-recovery feedback and trigger sunrise autosave; whether a separate beat is warranted is a pacing decision.
- **Bounded options:**
  - **Option A (Recommended default):** Fold `ch1_04_after_dawn` into `ch1_03_first_night` resolution (short outcome-aware line on Day 1 sunrise only, keeping control responsive after breach).
  - **Option B:** Keep `ch1_04_after_dawn` as a separate beat triggered on `TimeManager.daylight_started(2)` after sunrise autosave.
- **Recommended default:** **Option A** — avoids duplicate HUD/dialogue messaging and prevents heavy dialogue interruption right after a breach penalty.
- **Player-facing consequence:** Snappier Day 2 recovery; player immediately sees outcome and keeps control.
- **Technical consequence:** Eliminates a redundant trigger state between `sunrise_reached` and `daylight_started`.
- **Blocking status:** **Blocks N5.2** (first-night slice).

## D-N5-03 — Dialogue presentation & NPC dialogue scope in first coding slices
- **Exact question:** Should initial Chapter I slices (N5.0–N5.2) reuse the existing text-only `DialoguePanel` with short Monarch internal lines (no NPC dialogue required yet), or require authored NPC dialogue up front?
- **Why source inspection cannot resolve it:** `docs/CHAPTER_01_BEAT_SHEET.md` is DRAFT/NON-CANON with zero owner-approved dialogue lines; `DialoguePanel.gd` is already tested and ready for text-only lines.
- **Bounded options:**
  - **Option A (Recommended default):** Reuse existing text-only `DialoguePanel` with short, owner-approved placeholder/minimal Monarch lines in N5.1–N5.2; defer Scientist/NPC dialogue lines to N5.3.
  - **Option B:** Block N5.1–N5.2 until full Chapter I Monarch + NPC dialogue script is written and approved.
- **Recommended default:** **Option A** — keeps PRs small, testable, and unblocked without inventing NPC canon.
- **Player-facing consequence:** Clean, non-intrusive text beats using familiar Prologue UI.
- **Technical consequence:** Zero changes to `DialoguePanel.gd` or `SequenceRunner.gd`.
- **Blocking status:** **Blocks N5.1** content text; does **not** block N5.0.

## D-N5-04 — Skippable / replayable Chapter I beat policy
- **Exact question:** Should Chapter I in-world narrative beats be skippable via the existing `DialoguePanel` / `SequenceRunner` skip path and suppressed on Continue save loads?
- **Why source inspection cannot resolve it:** Prologue uses per-run `NarrativeState` with no mid-Prologue saves, whereas Forgotten Shore supports Continue/autosave (`SaveManager` schema v2).
- **Bounded options:**
  - **Option A (Recommended default):** Every short Chapter I beat is skippable (`skip_allowed: true`), never replays during silent `load_game_state()` / Continue restoration, and derives already-passed state from authoritative gameplay state (`day_count`, `building_mgr`, `progression`, `shipwreck_stage`) so `SaveManager` schema v2 stays unchanged.
  - **Option B:** Persist explicit per-beat Chapter I flags in `SaveManager` (requires schema v2 evaluation/approval).
- **Recommended default:** **Option A** — preserves SaveManager schema v2 untouched and prevents replay spam on Continue.
- **Player-facing consequence:** Loading a save drops the player directly into gameplay without replaying old beats.
- **Technical consequence:** Zero SaveManager schema changes; idempotency derived from authoritative gameplay state + in-session `NarrativeState`.
- **Blocking status:** **Blocks N5.0** (defines save/load non-replay contract).

## D-N5-05 — Eldergrove Forest arrival staging (`ch1_08_departure` / N5.5)
- **Exact question:** What minimal arrival staging completes Chapter I when the player presses Set Sail on the repaired vessel?
- **Why source inspection cannot resolve it:** `ForgottenShoreSession._on_player_interact_shipwreck()` currently sets `ReignState.ISLAND_CLEARED` and shows a victory banner; no voyage scene or Eldergrove Forest scene exists yet, and `ProgressionState.FACT_ELDERGROVE_REACHED` is defined but unrecorded.
- **Bounded options:**
  - **Option A (Recommended default, deferred to N5.5):** Short sea-voyage transition cue sequence → minimal Eldergrove Forest arrival scene recording `FACT_ELDERGROVE_REACHED` only after destination `_ready()` confirms control handoff (mirroring N4.5-C `PrologueHandoffBridge`).
  - **Option B:** Hold N5.5 until full Island 2 gameplay scene is implemented.
- **Recommended default:** **Option A (deferred to N5.5)**.
- **Player-facing consequence:** Cleanly fulfills the approved rule that Chapter I ends on Eldergrove arrival, not at Set Sail.
- **Technical consequence:** Reuses the proven N4.5-C two-stage handoff pattern.
- **Blocking status:** **Deferred — blocks N5.5 only** (does not block N5.0–N5.4).
