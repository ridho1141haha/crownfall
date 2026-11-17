# CROWNFALL: THE LAST LIGHT
# CHANGELOG

All notable project and documentation changes are recorded here in reverse chronological order.

This changelog records repository changes that actually occurred. Planned features and unimplemented work belong in the PRD, GDD, SYSTEMS, TDD, or roadmap sections—not as completed changelog entries.

---

## [2026-11-17] N4.2 The Lost World + A Faint Resonance (beats pl_01 + pl_02)

**Type:** Prologue story content (two authored beats + shell auto-start/chaining; no SaveManager/schema change, no PlayerProfile writes, no new runner ops, no art/audio assets)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 16 suites passed, 0 failure markers; repository static verifier 238 checks)

### Summary
Implements roadmap slice **N4.2**: the Prologue's first two story beats are now authored and playable through the real New Game entry flow. `scripts/narrative/PrologueBeats.gd` (new content module, data only) authors `pl_01_lost_world` ("The Lost World") and `pl_02_faint_resonance` ("A Faint Resonance") as NarrativeData-validated sequences in the existing typed, allowlisted op format — no new runner ops, no quest/cinematic framework, no JSON-driven scripting. pl_01 uses the Story Design Beat 01 candidate narration verbatim and never states the cause of the Great Eclipse; pl_02 depicts exactly one small, uncontrolled childhood manifestation (one resonance cue, one narration line, then failed attempts to repeat it) with no spellcasting, no power origin, an unnamed stone location (OPEN decision preserved), and no crown in either beat. The shell (`PrologueShell.gd`) stays lifecycle-only: it auto-plays the first uncompleted beat on route load (production default, matching pl_01's "New Game start" entry condition; headless suites override via the Engine meta `crownfall_prologue_autostart`, same injection convention as `crownfall_load_on_start`), chains pl_01 → pl_02 exactly-once via `sequence_completed`, stages beat cues on a labelled placeholder stage (`[Placeholder art]` captions through the existing `play_cue` op), and marks the N4.2 boundary only when next-beat discovery finds no next authored beat after the completed beat — every playback refusal (exit started, busy runner, already-completed next beat, invalid data, `play()` rejection) keeps the boundary FALSE and is reported explicitly; no scene transition (the shore handoff remains N4.5), no completion marking, and the development-only exit remains the only way out. Dialogue stays text-only English (DECIDED language).

### Key Changes
- **`scripts/narrative/PrologueBeats.gd` (new):** authored beat data — `BEAT_IDS` order, `get_beat(id)` (deep-copied, fail-closed for unknown ids), `stage_caption(cue_id)` (labelled placeholder captions), `is_beat(id)`. Content lives here; the shell authors no story text.
- **`scripts/narrative/PrologueShell.gd`:** `start_prologue()` + auto-start on `_ready` (meta-gated), beat chaining from `sequence_completed` (runner idle at emit time; generation guards keep the finished run stale) with **next-beat discovery (`_next_beat_id`) separated from next-beat playback (`_play_next_beat`)** — the chain handler marks the N4.2 boundary only when discovery finds no next authored beat; a next beat that exists but cannot start (exit started, busy runner, already-completed beat, invalid data, `play()` rejection) keeps the boundary FALSE, is reported via `push_warning`, and leaves the shell in a defined idle state the development exit can leave and `start_prologue()` can retry. Plus `_on_sequence_cue` placeholder staging + `set_cue_player(Callable)` observability hook, `current_beat_id()` / `prologue_reached_end()` accessors, stage hide on completion/cancel/failure, and boundary status text. Non-beat sequences (e.g. the N4.1 suite's plumbing fixtures) still play via `play_sequence` and never trigger chaining.
- **`scenes/narrative/PrologueShell.tscn`:** `StageBackdrop` + `StageCaption` labelled placeholder stage nodes (hidden by default) and N4.2 status text.
- **`scripts/narrative/SequenceRunner.gd`:** `sequence_started` / `sequence_completed` / `sequence_failed` ids are now snapshotted into locals before emission — the shell's chain handler starts the next beat from inside the completion emission, which reassigns `_current_id`, and later listeners must still observe the id the signal is about (latent N3 quirk made visible by chaining; regression-covered by the N4.2 suite). Plus a read-only `is_control_locked()` accessor.
- **`tests/test_n42_prologue_beats.gd` (new, 113 checks):** both beats load and validate fail-closed (single sequences + whole payload with unique ids); real entry flow (first New Game → shell); explicit `start_prologue` on an idle shell and the production auto-start flow; dialogue progression/completion through the panel; control lock engagement and restoration; NarrativeState records both completions exactly once; chain order pl_01 → pl_02 and the N4.2 boundary with NO premature boundary after pl_01 (no shore transition, no chain advance on cancellation, non-beat completions never chain); cue order across both beats (exactly one manifestation); invalid payloads fail closed; cancellation/dev-exit cleanup without completion; skip fast-forwards a beat and still completes exactly once; **boundary strictness (review fix)** — discovery matrix (`""` → pl_01, pl_01 → pl_02, pl_02 → `""` as the only boundary trigger, unknown → `""`), busy-runner refusal, already-completed next-beat refusal (out-of-band `NarrativeState.mark_completed` + end-to-end chain refusal), boundary FALSE after every refusal, unchanged boundary status text, retry semantics, and the development exit from the refusal idle state; profile/world-save fixtures byte-exact untouched (plus the developer's real files, sidecars included).
- **`tests/test_n40_profile_entry_gate.gd` + `tests/test_n41_prologue_shell.gd`:** one Engine-meta line each (`crownfall_prologue_autostart = false`) so their lifecycle assertions keep running against an idle shell; no other changes (101/87 checks unchanged).
- **`tests/run_all.sh` + `.github/workflows/godot-ci.yml`:** N4.2 suite registered after N4.1.
- **Docs:** roadmap §4/§5, `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (status, §A, §E emission-snapshot guard, N0 implemented-beats note), `PROLOGUE_PRODUCTION_BREAKDOWN.md` (status, §3 N4.2 row, §5 route-target note), audit header note.

### Lore discipline (accepted constraints)
No Eclipse cause, no power origin, no dynasty/kingdom/Crown invention, no crown appearance in pl_01/pl_02, exactly one manifestation, placeholder captions only (labelled, no implied canon), dialogue in English. The childhood stone location and the narration copy remain owner-reviewable (candidate text labelled in the breakdown).

---

## [2026-11-17] N4.1 Prologue Shell (lifecycle only — story beats NOT included)

**Type:** New narrative infrastructure (functional scene shell; no Prologue content, no canon dialogue, no SaveManager/schema change)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 15 suites passed, 0 failure markers; repository static verifier 234 checks)

### Summary
Implements roadmap slice **N4.1**: the labelled N4.0 route placeholder becomes the functional Prologue shell at the same path (`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd`). The shell owns its runtime state — a per-run `NarrativeState`, a `DialoguePanel`, and a `SequenceRunner` whose `change_scene` op is allowlisted to `res://scenes/world/ForgottenShore.tscn` (the future N4.5 handoff channel) — and exposes `play_sequence` / `skip_sequence` / `cancel_sequence` as the presentation contract for the N4.2–N4.5 beats (no sequence data is authored or shipped; the nine beats and any completion marking remain future work). Runtime initialization is idempotent per scene instance, and every exit/handoff passes a single-transition guard (`_begin_exit` / `is_exit_started`), so duplicate exit or duplicate sequence scene-change requests are safely ignored. Exit semantics are split: a **development exit** cancels a running sequence (deterministic cleanup, completes nothing), while a **sequence-driven handoff** never cancels the finishing sequence — the runner is inside its `change_scene` op and still runs `_finalize_completion()`, so `sequence_completed` fires exactly once and the `NarrativeState` records the sequence (regression-tested). The one exit available today is a clearly labelled **development-only** "Return to Main Menu (Development Exit)" button: it never touches `PlayerProfile`, never writes the profile or any world save, and the per-run narrative state is discarded with the scene (the Prologue stays non-resumable per the technical design). Entering, running, or exiting the shell does not mark `prologue_completed_once`. `Main.gd` routing, the N4.0 entry gate, Continue behavior, and SaveManager schema v2 are unchanged.

### Key Changes
- **`scripts/narrative/PrologueShell.gd` (replaced placeholder):** functional shell — idempotent `_initialize_runtime()` (builds `NarrativeState` + `DialoguePanel` + `SequenceRunner` exactly once), `play_sequence` (fail-closed via `NarrativeData.validate_sequence`, exactly-once completion in the N3 runner), `skip_sequence` / `cancel_sequence` (N3 semantics), `set_exit_transition(Callable)` test-observability hook (same convention as `Main.set_route_transition`), guarded `request_main_menu_return()` / sequence-driven `_on_sequence_scene_transition()` with split exit semantics (`_begin_exit(scene_path, cancel_running_sequence)`: dev exit cancels a running sequence and completes nothing; a sequence handoff leaves the finishing sequence untouched so its completion still fires), and the development-only exit button handler.
- **`scenes/narrative/PrologueShell.tscn`:** status text stating the N4.1 shell is active and story sequences (N4.2–N4.5) are not implemented; `DevExitButton` ("Return to Main Menu (Development Exit)") replaces the N4.0 `ReturnToMenuButton` (the non-dead-end contract is unchanged; the N4.0 suite assertion was updated to the new control name).
- **`tests/test_n41_prologue_shell.gd` (new, 87 checks):** scene load/instantiate + script identity; runtime ownership and idempotent init; allowlisted text-only sequence plumbing (play → dialogue presentation → advance → exactly-once completion; cancel → no completion, panel closed); sequence-driven handoff regression (change_scene through the shell's own callback: single transition, exactly-once `sequence_completed`, `NarrativeState` record, duplicate handoff ignored, dev-exit-while-running cancels without completion); enter/run/exit never creates or mutates profile fixtures (byte-exact); duplicate exit ignored (single transition); no stale runtime state after exit and a fresh instance starts clean; N4.0 routing contract preserved (first New Game → shell, Play Again → shell, Skip → fresh Forgotten Shore without touching the profile flag, Cancel stays in the menu and revokes the pending confirmation, Continue bypasses the Prologue and consumes the injected day-2 save). Fixtures under `user://n41_test/` via the Engine-meta injection contract; the developer's real `player_profile.json` / `save_slot_0.json` / sidecars are proven byte-unchanged; fixture sidecars are cleaned before/after the run.
- **`tests/test_n40_profile_entry_gate.gd`:** stage-28 shell assertions updated from the removed `ReturnToMenuButton` to the renamed `DevExitButton` (same non-dead-end and no-completion claims; suite is 101 checks).
- **`tests/run_all.sh` + `.github/workflows/godot-ci.yml`:** N4.1 suite registered after N4.0.
- **Docs:** roadmap §5 (N4.0 + N4.1 implemented, N4.2–N4.6 not), `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A (as-built shell lifecycle and contracts), `PROLOGUE_PRODUCTION_BREAKDOWN.md` §3/§5 (N4.1 slice marked implemented), audit snapshot note.

---

## [2026-11-17] N4.0 Player Profile & Entry Gate (Prologue content NOT included)

**Type:** New narrative infrastructure + entry-flow change (no Prologue content, no canon dialogue, no SaveManager/schema change)
**Engine Verified:** `Godot 4.7.2.stable.official.ed1daf0bf` (local headless run of the full `tests/run_all.sh`: all 14 suites passed, 0 failure markers; repository static verifier 231 checks)

### Summary
Implements roadmap slice **N4.0** decided in `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A/B: a minimal persistent `PlayerProfile` holding exactly one durable fact — `prologue_completed_once` — and the New Game / Continue entry gate. First-ever Start New Game routes to the labelled Prologue route placeholder with Skip locked; after one recorded completion, Start New Game offers **Play Prologue Again / Skip Prologue**; Skip enters a fresh Forgotten Shore session without touching the profile; Continue bypasses the Prologue entirely and keeps loading existing world saves (including legacy v1). `SaveManager`, `ProgressionState`, world-save schema v2, and `ForgottenShoreSession` are unchanged. **The nine Prologue beats are NOT implemented**: `scenes/narrative/PrologueShell.tscn` is a clearly labelled, inert N4.0 placeholder (no beats, dialogue, handoff, or completion marking), and nothing in the runtime flow sets the completion flag. N4.1–N4.6 remain not implemented.

### Key Changes
- **`scripts/narrative/PlayerProfile.gd` (new):** global profile at `user://player_profile.json`, schema `{"schema_version": 1, "prologue_completed_once": false}`. Strict fail-closed validation (exact two-key shape, exact-int schema version, bool flag; missing/malformed/unsupported-version/unreadable data all read as "not completed" and never block New Game or Continue). Atomic persistence (`.tmp` → re-read verify → staged rename with `.old` rollback, SaveManager convention; no SaveManager code reuse or modification). API: `load_profile(path) -> {ok, error}`, `is_prologue_completed_once() -> bool`, `mark_prologue_completed(path) -> bool` (reports persistence success). Unsafe paths rejected; no signals, no autoload, no settings framework.
- **`scripts/core/Main.gd`:** after the existing (unchanged-wording) overwrite confirmation, the profile gate routes Start New Game: `prologue_completed_once == false` → Prologue route (`crownfall_load_on_start = false`, no Skip offered); `true` → returning-player choice overlay (**Play Prologue Again** / **Skip Prologue** / Cancel; Cancel stays in the menu). Skip and Play Again are single-transition guarded (`_route_started`); the confirm-overlay Cancel button is now named `CancelNewGameButton`. Continue is untouched and never reads the profile.
- **`scenes/narrative/PrologueShell.tscn` + `scripts/narrative/PrologueShell.gd` (new):** N4.0 placeholder route target for `Main.PROLOGUE_ROUTE_SCENE`; inert except a Return to Main Menu button so the build cannot dead-end. **N4.1 replaces the scene content at the same path** (or updates the constant in the same PR); the routing decision does not change.
- **Tests:** `tests/test_n40_profile_entry_gate.gd` (new, 66 checks): profile behavior matrix (missing/false/true/malformed/missing-field/unsupported-version/unreadable/write-failure/reload), entry flow (first-ever routing, no Skip, choice, cancel paths, repeated-press single-transition guard), Skip → fresh Forgotten Shore (previous day-2 save left intact, default ledger), Continue independence (v2 + legacy v1 loads, corrupted profile does not disable Continue), placeholder sanity, and byte-exact proof that the developer's real `user://player_profile.json` is never mutated. Registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
- **`tests/test_integration_m8_slice.gd`:** entry stage adapted to the new gate — it runs as a returning player via an injected pre-completed profile and reaches Forgotten Shore through the real Skip path; all 39 gameplay/save/continue checks are unchanged in behavior (overlay visibility now uses `is_visible_in_tree()` so hidden overlays are never re-pressed).
- **Docs:** roadmap §3/§5 (N4.0 implemented, N4.1–N4.6 not), `NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` §A (verified implementation + N4.1/N4.5 contract), `PROLOGUE_PRODUCTION_BREAKDOWN.md` §5 (as-built profile/entry contract), audit snapshot note.

---

## [2026-11-16] Narrative Runtime Foundation (N1–N3, test fixtures only)

**Type:** New narrative systems (minimal foundation; no Prologue content, no canon dialogue, no save-schema change)
**Engine Verified:** `Godot 4.7.2.stable` (local headless runs: repository verifier, full `tests/run_all.sh`, and the three new suites below)

### Summary
Implements the roadmap N1–N3 foundation decided in `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md`: in-memory `NarrativeState`, fail-closed `NarrativeData` validator, `DialoguePanel` + `PlayerControlLock` input isolation, `SequenceRunner` with typed allowlisted operations, the `dialogue_advance` input action, and a Start New Game overwrite confirmation. **No narrative persistence was added** (linear non-resumable Prologue policy, decisions D1/D2): `SaveManager`, `ProgressionState`, and schema v2 are unchanged. All dialogue fixtures are explicitly non-canon.

### Key Changes
- **`scripts/narrative/NarrativeState.gd` (new):** per-run, in-memory completion set; idempotent `mark_completed`; never serialized.
- **`scripts/narrative/NarrativeData.gd` (new):** fail-closed validator/loader for typed, allowlisted sequence steps (`dialogue`/`wait`/`lock_control`/`unlock_control`/`play_cue`/`change_scene`/`finish`) with strict bounds; unknown fields/ops rejected.
- **`scripts/narrative/DialoguePanel.gd` (new):** separate CanvasLayer (speaker/body/advance hint); consumes all unhandled input while open; advances only via `dialogue_advance`; emits `dialogue_finished` exactly once per session.
- **`scripts/narrative/PlayerControlLock.gd` (new):** disables/restores the control target's physics + unhandled-input processing (idempotent, freed-safe).
- **`scripts/narrative/SequenceRunner.gd` (new):** deterministic linear playback; frame-counted waits (no `Timer` nodes); injected cue/transition callables with scene allowlist; completion emitted exactly once per run; `skip()` fast-forwards (pending `change_scene` at most once) and still completes once; `cancel()` and `_exit_tree` always restore control.
- **`scripts/core/Main.gd`:** Start New Game asks for confirmation when a valid save exists (protects existing saves before Prologue wiring).
- **`project.godot`:** added `dialogue_advance` input action (Enter / Left Mouse Button).
- **Tests:** `tests/test_narrative_foundation.gd` (39 checks), `tests/test_dialogue_panel.gd` (19 checks), `tests/test_sequence_runner.gd` (31 checks); non-canon fixture `tests/fixtures/narrative_sequences.json`; all three registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`.
- **Docs:** `docs/narrative/NARRATIVE_RUNTIME_TECHNICAL_DESIGN.md` (ADR + N0 contract), `docs/narrative/PROLOGUE_PRODUCTION_BREAKDOWN.md` (N4 readiness), roadmap/audit/gap analysis synchronized.

### Deliberately Deferred
- Prologue content (N4), Chapter I content (N5), `camera_focus`/`pause_world` ops (PROPOSED), portraits/voice/localization, any narrative persistence, and all Prologue skip/staging decisions (OPEN).

---

## [2026-11-16] Shrine, Statue, Temple, Resource Access & Buff Foundation (Phase 5)

**Type:** New Gameplay Systems (structure domain + explicit resource access + buff foundation; save schema stays version 2 with zero new save keys)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and re-run after documentation changes: static verifier `204` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `188` checks across `7` suites, Phase 5 suite `209` checks across `8` suites — all green)

### Summary
Phase 5 adds the Shrine/Statue/Temple foundation, the explicit resource-access foundation, and a deliberately scoped buff system. Structures are validated data-driven definitions (`data/structures.json` + `StructureCatalog.gd`) with distinguishable categories, pinned `<id>_activated` activation facts, atomic EconomyLedger costs, and optional world placement; the derived lifecycle (`activated`/`not_present`/`available`/`locked`) comes from durable progression facts (no save fields of its own); unplaced and inactive-island structures report `not_present` and are never described as ready for activation. Resource access is separated from resource quantity (`data/resources.json` + `ResourceCatalog.gd` + `ResourceAccessState.gd`): gold/wood/stone ship as explicit `base_accessible` definitions so no existing gameplay path is broken, unlock-by-fact requirements support multiple `any_of` sources, evaluation never consults ledger balances, and unknown IDs fail closed. Buffs are validated definitions (`data/buffs.json` + `BuffCatalog.gd`) with a consumer-backed effect registry, additive stacking whitelist, permanent-only durations (timed definitions rejected fail-closed until a real consumer exists), and an authoritative derived aggregation (`BuffDomain.get_effect_total`) that makes duplicate application structurally impossible. The first playable structure is the Shrine of Growth on Forgotten Shore (`x=820`): requires the Stone Wall Tier 2 milestone and 4G 2W 3S, grants the `grove_timber_blessing` (+1 Wood to every island wood acquisition — player node collection, tree felling, villager auto-chop). The Statue and Temple definitions are registered and validated but intentionally unplaced (fail closed). Schema v2 keeps zero new save keys: activations ride the strictly validated `progression_facts` array, legacy saves never fabricate activations or access, loading replaces state (verified into non-empty Phase 5 sessions), and failed restores roll the whole session back.

### Key Changes
- **`scripts/structures/StructureCatalog.gd` + `data/structures.json` (new):** all-or-nothing validated loading (strict field sets, stable unique IDs, category/island whitelists, pinned registry-approved activation facts, positive EconomyLedger costs, bounded world positions, shared requirement-group validator, empty requirement groups rejected).
- **`scripts/structures/StructureDomain.gd` (new):** derived lifecycle queries (explicit `not_present` state for unplaced and inactive-island structures) and the authoritative activation transaction (validate -> duplicate guard before spend -> island/world presence -> finite actor position -> proximity -> requirements -> atomic spend -> record fact -> signal; duplicate activation never spends twice; non-finite actor coordinates (NaN/±inf) rejected before any proximity math or mutation; defensive refund on the unreachable fact-recording failure).
- **`scripts/resources/ResourceCatalog.gd` + `data/resources.json` (new):** resource definitions with exactly one access source each (explicit base access or fact-gated unlock; ambiguous or source-less definitions rejected).
- **`scripts/resources/ResourceAccessState.gd` (new):** deterministic fail-closed access queries derived from registered unlock conditions plus durable facts, never from balances; enforcement point added at player-initiated acquisition before any ledger mutation (no-op for base resources).
- **`scripts/buffs/BuffCatalog.gd` + `data/buffs.json` (new):** validated buff definitions (effect type registry with real consumers only, positive magnitudes, additive stacking whitelist, permanent-only durations, validated source-structure reference).
- **`scripts/buffs/BuffDomain.gd` (new):** authoritative additive aggregation derived per query from activation evidence (duplicate structure IDs collapsed; unknown effect types 0; nothing stored or re-applied on load).
- **`scripts/progression/ProgressionState.gd`:** three activation facts registered (`shrine_of_growth_activated`, `statue_of_the_first_sailor_activated`, `temple_of_the_dawn_activated`); only the Shrine has a gameplay recording path.
- **`scripts/world/ForgottenShoreSession.gd`:** structure domain + resource access members, `activate_structure` command with nearest-activatable fallback, programmatic dormant/awakened landmark visuals, resolver kind `structure`, proximity prompts, wood-blessing application to collection/felling/villager auto-chop (ledger-outcome-checked so feedback never claims ungranted wood), resource-access gate on acquisition, HUD blessings line.
- **`scripts/player/InteractionResolver.gd`:** structure targets for AVAILABLE structures (locked and already-activated structures offer no interaction).
- **`scripts/ui/ClockHUD.gd`:** passive structures/blessings status line (presentation only).
- **`scripts/tools/generate_pixel_assets.py` + `assets/environment/landmarks/env_shrine_structure.png` (new):** generated 2-frame dormant/awakened shrine landmark following the greed-portal precedent.
- **`tests/test_structure_buff_phase5.gd` (new, registered in `tests/run_all.sh` and CI):** 209 checks across 8 suites — catalog validation (all three catalogs), derived lifecycle (including `not_present` for unplaced and inactive-island structures), activation transactions (success/unknown/non-finite actor positions/out-of-range/insufficient-funds/future-island/duplicate without double spending), buff aggregation, resource access (zero-balance-unlocked, nonzero-balance-locked, unknown IDs, multiple unlock sources, legacy saves), real session command/resolver/blessing paths with exact balance math (including cap-exceeded fallback and villager auto-chop), save round-trips, legacy saves into Phase-5-active sessions, transactional rollback, malformed-fact rejection, and specialist/research/offering/building/economy/era regression guards.
- **Self-review fixes shipped with regression tests:** ledger-cap blessing fallback (UI agrees with authoritative state), villager auto-chop blessing coverage, activation refund on the unreachable fact-recording failure, catalog duplicate-ID message convention alignment.
- **Post-review hardening (this PR's fix commit):** non-finite actor positions (NaN, +inf, -inf) are rejected before any proximity math with a clear rejection reason and zero economy/fact mutation (a scratch pre-fix repro showed a NaN position fully activating the shrine and spending its cost); the derived structure lifecycle reports `not_present` for unplaced and inactive-island structures so it never claims readiness for activation (pre-fix repro returned `available`); both world resolvers pre-filter by island and world position, so resolver behavior is unchanged.

### Deliberately Deferred
- Timed buff runtime (no Phase 5 consumer; timed definitions are rejected fail-closed at load).
- Resource-unlock-by-structure gameplay (the access foundation supports fact-gated resources; no live locked resource ships to avoid breaking the Forgotten Shore slice).
- Statue and Temple world placement (definitions exist and fail closed until a future phase places them).
- Future-island structures and Eldergrove content.

---

---

## [2026-11-16] Research Phase 4.1 — Reset Research State When Loading Legacy Saves

**Type:** Save-Load Correctness (narrow fix on top of Phase 4; no new systems, no schema change, no migration change)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes: static verifier `195` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `188` checks across `7` suites — all green)

### Summary
Independent code review found a defect in `ForgottenShoreSession._apply_loaded_payload()`: research was restored only inside `if data.has("research")`, so loading an older schema-v2 save without the optional `research` key left the live session's in-memory `ResearchManager` state completely unchanged. A session that had completed a technology or had a project running would silently keep that research state even though the authoritative payload contained none — resurrection of state the save does not own, violating the documented contract (design section 14: "absent key = empty research state"; `ResearchManager` header doc). The fix adds a dedicated transactional `ResearchManager.reset_to_empty_state()` that routes through the existing validated `apply_save_dict` path (canonical empty payload `{"completed_techs": [], "active_research": null}`) and calls it from a new `else` branch when the key is absent. Missing key = empty research state; present valid key = restore that state; present malformed value (including explicit `"research": null`) = reject the save exactly as before; a failed load still rolls the whole session back through the existing snapshot mechanism. Strict validation is untouched, schema stays version 2, `migrate_payload` is untouched, and no resource is refunded or deducted by the reset.

### Key Changes
- **`scripts/research/ResearchManager.gd`:** new `reset_to_empty_state() -> bool` — transactional reset to the canonical empty research state, delegating to the same validated `apply_save_dict` path so replacement stays atomic with zero partial mutation. The bool return keeps the transactional contract uniform for the caller (a defensive failure aborts the load and triggers the session rollback); it cannot fail by construction.
- **`scripts/world/ForgottenShoreSession.gd`:** `_apply_loaded_payload()` now resets research to the empty state when the optional `research` key is absent (payload is the authority). The present-key branch (including explicit-null rejection) is unchanged. Both outcomes still participate in the existing whole-session rollback.
- **`tests/test_research_foundation.gd`:** new suite "Legacy Save Research Reset (Phase 4.1)" (58 checks) with the required regression cases: (A) legacy save after a completed technology loads and empties completed research, active project and derived effects (verified end-to-end through the real shrine-offering command path yielding the base +2 gold); (B) legacy save during an active project clears the project and elapsed progress with balances matching the payload exactly (no refund, no second deduction, advancing afterwards is a no-op); (C) a valid modern save with both completed and active research restores the completed set, the active ID and the exact elapsed progress over a non-empty live research state (replacement, not merge; no resource change; the restored project completes exactly once at its duration boundary); (D) explicit `"research": null` is rejected wholesale with the live research and progression state unchanged; (E) when research restoration succeeds but a later subsystem fails, the existing session rollback restores the previous research state, economy and roster (a fail-once `NPCPopulationManager` test double fails only the first apply call and delegates the rollback retry to the real implementation). Cases A and B were verified to fail against the pre-fix implementation (suite exit 1 at Case A; a scratch pre-fix repro confirmed `has_active_research() == true` after a legacy load for Case B). Research suite count 6 -> 7 suites, 130 -> 188 checks.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 14 acceptance evidence updated to the new suite counts; the Phase 4 summary phrase "old saves without the research key load untouched" in this changelog was corrected to the actual (now enforced) contract "load with an empty research state".

## [2026-11-16] Specialist & Research Foundations (Phases 3 & 4)

**Type:** New Gameplay Systems (specialist domain foundation + research system foundation; save schema stays version 2)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and again after the documentation changes: static verifier `195` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites, specialist suite `108` checks across `5` suites, research suite `130` checks across `6` suites — all green)

### Summary
Phase 3 adds the specialist domain foundation: a validated data-driven roster (`data/specialists.json` + `SpecialistCatalog.gd`) of the four established specialists, a four-state lifecycle (`undiscovered -> discovered -> recruitable -> recruited`) derived from durable progression facts plus live building state (no separate specialist save fields), discovery and recruitment as separate authoritative transactions (idempotent discovery; recruitment order validate -> atomic spend -> record fact -> signal; duplicate recruitment rejected; failed recruitment never mutates state), and a minimal housing requirement integrated with the data-driven building system via the new `hut_scientist_01` (`specialist_hut`) plot. The Scientist is the first playable specialist on Forgotten Shore: discover at `x=-1010`, build their hut at `x=-980`, recruit for `3G 2W`. All eight specialist fact IDs are registered; only the Scientist has a gameplay recording path, so no fact is fabricated for future islands.

Phase 4 makes the Scientist provide a real function: a validated technology catalog (`data/technologies.json` + `TechnologyCatalog.gd`) with prerequisite-cycle detection and an effect registry that rejects unimplemented effects, `ResearchManager.gd` with one active project, authoritative requirements (recruited Scientist, prerequisite technologies, Stone Age fact gate), transactional starts through the atomic `EconomyLedger`, world-clock-driven progress (the session's scaled sim delta — no UI timers or frame counting), exactly-once completion with derived effects, and persistence as the optional top-level `research` save key. Two Forgotten Shore technologies ship: `inscription_studies` (Shrine Offering +3 gold) and `improved_flares` (Kindle Flare +4s), the latter gated on the Stone Age milestone. No Iron Age content exists on Forgotten Shore; schema stays version 2 and old saves without the research key load with an empty research state (explicit null / unknown IDs / duplicate IDs are rejected wholesale with no partial mutation; the reset behavior itself shipped corrected in the Phase 4.1 entry below).

### Key Changes
- **`scripts/specialists/SpecialistCatalog.gd` + `data/specialists.json` (new):** fail-safe all-or-nothing definition loading with strict field sets, stable unique IDs, role/island whitelists, fact bindings pinned to the registered `<id>_discovered`/`<id>_recruited` pattern, positive EconomyLedger costs, and optional housing/world-position/requirement-fact fields; future-island specialists omit placement so discovery/recruitment fail closed.
- **`scripts/specialists/SpecialistDomain.gd` (new):** derived lifecycle queries, idempotent discovery, and the authoritative recruitment transaction; no save state of its own (facts + buildings carry everything).
- **`scripts/research/TechnologyCatalog.gd` + `data/technologies.json` (new):** validated technology definitions with cycles rejected and exactly the two scoped Forgotten Shore technologies.
- **`scripts/research/ResearchManager.gd` (new):** availability/progress/completion state, transactional starts, authoritative world-time advancement, exactly-once completion, derived completion effects, and transactional save restore (unknown/duplicate technology IDs rejected against a file-derived fail-closed static registry; active projects resume with exact elapsed time and never re-deduct costs; completed technologies never re-apply rewards).
- **`scripts/progression/ProgressionState.gd`:** registered the eight specialist facts (discovery/recruitment for scientist, blacksmith, architect, scholar).
- **`data/buildings.json` + `scripts/save/SaveManager.gd`:** new `hut_scientist_01` specialist-hut plot (data-driven) added to the strict save plot whitelist.
- **`scripts/world/ForgottenShoreSession.gd`:** specialist + research members and signal wiring; `discover_specialist` / `recruit_specialist` / `start_research` world commands (empty targets resolve deterministically); programmatic specialist-camp visuals and prompts; research advancement fed with the authoritative scaled sim delta; shrine offering and flare duration consume the aggregated research effects (fresh-session behavior unchanged); research state included in the save payload and restored transactionally on load.
- **`scripts/player/InteractionResolver.gd`:** specialist interaction block (discover / recruit prompts with data-defined cost text) and the research prompt (first available technology in stable ID order, offered at the recruited specialist's position).
- **`scripts/ui/ClockHUD.gd`:** research status line (`set_research_text`).
- **Tests:** new `tests/test_specialist_domain.gd` (108 checks, 5 suites) and `tests/test_research_foundation.gd` (130 checks, 6 suites); registered in `tests/run_all.sh` and the CI workflow. Existing Phase 1/Phase 2 suites updated only where they used `scientist_recruited` as the canonical UNKNOWN fact-ID example (now `mount_tamed`; the unknown-ID rejection intent is unchanged) — Phase 1 stays at 139 checks, Phase 2 at 162 checks.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` sections 13-14 (shipped Phase 3/4 boundaries), `PROGRESSION_IMPLEMENTATION_ROADMAP.md` (Phases 3-4 marked implemented with exit criteria met), `ROADMAP.md` (implemented-vs-future summary), `GDD.md` (specialist and research bullets in the settlement section).

### Deliberate boundaries
- Specialist and research states stay separate domains: specialists are not villager NPCs, research completion is not duplicated into progression facts (one source of truth), and the multiplayer command whitelist stays unchanged (remote peers cannot trigger the new commands until multiplayer scope defines them).
- Blacksmith/Architect/Scholar gameplay, additional technologies, research queues, and multi-island simulation are NOT implemented and are documented as future work.

---

## [2026-11-16] Progression Phase 2.2 — Reject Malformed Progression Data Before Migration

**Type:** Save Migration Correctness (narrow ordering fix on top of Phase 2.1; no gameplay, balance, or schema changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0 after the code changes and again after the documentation changes: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `162` checks across `8` suites — all green)

### Summary
Phase 2.1 made the fact-backfill helper itself strict, but the Phase 2 migration section could still partially mutate progression-related fields before `validate_payload` rejected an explicitly malformed `progression_facts` value: with `era_id = "iron_age"` plus an explicit `"progression_facts": null` (or any other malformed value such as a string, number, dictionary, or invalid array), the conservative legacy Iron Age correction still ran — its evidence check saw no valid Eldergrove array and rewrote `era_id` — so the migrated copy was already altered when the payload was rejected. `migrate_payload` now gates the whole progression migration section (era inference, Iron Age correction, vessel/Stone Age backfills, canonicalization) on an explicit `Dictionary.has("progression_facts")` presence check: a genuinely absent field keeps the valid legacy migration path; a present valid array keeps normal migration and canonicalization; a present-but-malformed value leaves the payload's progression data completely untouched (`era_id` unchanged, no backfills, no sorting, value never replaced or deleted) and is rejected wholesale by strict validation. The deep-copy behavior is preserved, the caller's input dictionary is never modified, and no live gameplay state changes on the rejection path. Save schema stays version 2.

### Key Changes
- **`scripts/save/SaveManager.gd`:** `migrate_payload` skips the entire progression migration section when `progression_facts` is explicitly present but not a valid fact array (`Dictionary.has()` guard plus `ProgressionState.is_valid_fact_array()`), leaving `era_id` and the malformed value untouched for `validate_payload` to reject. No other migration, gameplay, or schema behavior changed.
- **`tests/test_progression_phase2_era_correction.gd`:** new suite "Phase 2.2 Malformed Facts Migration Isolation" (29 checks) proving the required cases A-G: explicit null on a legacy `iron_age` + Stage 3 save keeps `era_id` and the explicit null untouched, is rejected, leaves the input dictionary unchanged, and fails the real file-load pipeline; malformed string and dictionary values with Iron Age + Stage 3 evidence are rejected untouched; unknown and duplicate fact IDs receive no era correction, backfill, deduplication, or sorting and are rejected; the absent-field legacy path (era correction + vessel + stone backfills) and the valid-array path (Eldergrove evidence retains Iron Age, deterministic sorting) keep their existing behavior; migration stays deterministic and idempotent for all three paths; rejected malformed values never partially mutate live progression state. Every case checks both the migrated copy and the original input dictionary. The existing mixed-case assertion (invalid array containing `eldergrove_reached`) was updated from "era is still downgraded" to the new contract "era stays untouched" — the payload is still rejected wholesale. Verified the new checks fail against the pre-fix implementation. Suite count 7 -> 8, checks 133 -> 162.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 12 now documents the three-case distinction (missing field = valid legacy migration; present valid array = normal migration and canonicalization; present malformed value = progression migration skipped, strict validation rejects) and the updated suite counts.

---

## [2026-11-16] Progression Phase 2.1 — Strict Save Migration Validation Fix

**Type:** Save Migration Correctness (small review fix on top of Phase 2; no gameplay, balance, or schema changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, Phase 2 suite `133` checks across `7` suites — all green)

### Summary
Code-review fix for a migration validation gap: `SaveManager._backfill_progression_fact()` read the field with `get("progression_facts", null)`, which cannot distinguish a genuinely absent field (legitimate legacy save; deterministic backfill intended) from an explicitly stored `null` (malformed payload). An explicit `"progression_facts": null` combined with `shipwreck_stage == 3` (or `era_id == "stone_age"`) was therefore silently repaired into a valid fact array and accepted, violating the strict malformed-save rejection policy. The backfill now uses an explicit `Dictionary.has()` presence check: a genuinely absent field is backfilled exactly as before (legacy Stone Age evidence and Stage-3 vessel readiness preserved; legacy `iron_age` without Eldergrove evidence still downgraded; migration stays deterministic and idempotent), while any explicitly present value that is not a valid fact array (`null`, string, number, dictionary, invalid array) is left untouched so `validate_payload` rejects the payload wholesale — no backfill, no partial application to live state. Valid arrays keep the existing strict checks (known IDs, duplicates, structure). Save schema stays version 2.

### Key Changes
- **`scripts/save/SaveManager.gd`:** `_backfill_progression_fact` distinguishes field absence from an explicitly present malformed value via `Dictionary.has()`; doc comment updated. No other migration, gameplay, or schema behavior changed.
- **`tests/test_progression_phase2_era_correction.gd`:** new suite "Strict Malformed Facts Rejection" (26 checks) covering absent-field migration success (Stage-3 vessel backfill intact), legacy `iron_age` without fact field still downgraded, valid Eldergrove evidence still retaining Iron Age, explicit `progression_facts: null` rejected (alone, combined with `shipwreck_stage == 3`, and on a `stone_age` save — with no backfill applied), explicit malformed string/dictionary rejected untouched, rejection mutating neither the caller's payload nor live progression state, failed malformed-file load leaving live state intact, and deterministic/idempotent rejection. Verified to fail against the pre-fix implementation and pass after the fix; suite count 6 -> 7, checks 107 -> 133.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` section 12 now documents the absent vs explicitly-null handling and the updated suite counts.

---

## [2026-11-16] Progression Phase 2 — Era Progression Correction & Conservative Legacy Save Migration

**Type:** Progression Correctness & Save Compatibility (deliberate era unlock semantics change; no gameplay balance changes)
**Engine Verified:** `Godot 4.7.2.stable` (local headless run of `tests/run_all.sh`, exit 0: static verifier `185` checks, world clock `5` checks, P0 unit `144` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, Phase 1 progression `139` checks across `6` suites, new Phase 2 suite `107` checks across `6` suites — all green)

### Summary
Implemented Phase 2 of `docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md`: Shipwreck Stage 3 no longer unlocks Iron Age. Completing the repair now records the durable voyage-readiness fact `forgotten_shore_vessel_ready` (idempotent, recorded only after the successful 6G 8W 4S transaction; repeated interactions keep the existing ISLAND_CLEARED / Set Sail path). Iron Age now unlocks only through the defined Eldergrove Forest milestone: the registered fact `eldergrove_reached` gates both the data-driven `iron_age_era` unlock definition (`data/unlocks.json`) and the new fail-closed `EraProgressionManager.notify_eldergrove_milestone(progression)` (replaces `notify_vessel_ready()`). Because no Forgotten Shore gameplay path records the Eldergrove fact, Iron Age is unreachable while playing on Forgotten Shore; the Eldergrove gameplay event itself ships with the future multi-island phase. Legacy saves with `era_id = "iron_age"` (previously reachable from Shipwreck Stage 3 alone) follow a documented conservative migration: saves carrying the Eldergrove fact keep Iron Age; all other legacy `iron_age` saves are downgraded to the era their real evidence proves (`stone_wall` building -> `stone_age`, otherwise `wood_age`), gain the vessel fact when `shipwreck_stage == 3`, and never receive a fabricated Eldergrove fact. Schema stays version 2.

### Key Changes
- **Facts (`scripts/progression/ProgressionState.gd`):** registry grew to exactly three facts — `forgotten_shore_first_stone_wall_tier_2` (unchanged), `forgotten_shore_vessel_ready` (new, recorded by the session after the Stage-3 repair succeeds), and `eldergrove_reached` (new, the defined Iron Age gate; registered for the unlock definition and future saves, with no current recording path).
- **Era gate (`scripts/world/EraProgressionManager.gd`):** `notify_vessel_ready()` removed; `notify_eldergrove_milestone(progression)` advances to Iron Age only when the passed progression state already contains `eldergrove_reached` — fail-closed on a missing fact or null state. Stone Age advancement and era save/restore behavior are unchanged.
- **Shipwreck session (`scripts/world/ForgottenShoreSession.gd`):** Stage 3 now emits "The vessel is ready to set sail from Forgotten Shore." instead of the Iron Age message; the vessel fact is recorded after the successful transaction. Stage costs, floating text, payment feedback, `ISLAND_CLEARED` repeat behavior, and the victory banner are untouched.
- **Unlock definitions (`data/unlocks.json`, `data/eras.json`):** added `forgotten_shore_voyage_ready` (all_of the vessel fact) and `iron_age_era` (all_of `eldergrove_reached`) beside the unchanged `stone_age_era`; the iron_age era description no longer claims the ship Stage 3 trigger.
- **Legacy migration (`scripts/save/SaveManager.gd`):** `migrate_payload` now (1) keeps Iron Age only when the save's valid fact array contains `eldergrove_reached`, (2) otherwise revokes Iron Age and recomputes the era from real evidence (`stone_wall` -> `stone_age`, else `wood_age`, matching the existing era-inference rule), (3) backfills `forgotten_shore_vessel_ready` whenever `shipwreck_stage == 3` (genuine evidence, any era), (4) keeps the Phase 1 stone-fact backfill for `stone_age` (also applying to freshly downgraded saves), and (5) sorts valid backfilled arrays to match the `to_save_array()` contract while leaving invalid arrays untouched for `validate_payload` to reject. Shared `_backfill_progression_fact()` helper keeps the backfills deterministic and idempotent. Malformed facts keep the Phase 1 behavior: rejected wholesale, never repaired mid-load. An invalid array containing `eldergrove_reached` never counts as evidence.
- **Tests & CI:** new `tests/test_progression_phase2_era_correction.gd` (107 checks, 6 suites) covering fresh-start era, the real wall/shipwreck command paths with exact balance regression, failed-transaction milestones, notification idempotency, the fail-closed Iron Age gate, the intended Eldergrove unlock path end-to-end (including an `iron_age` payload round-trip), every legacy migration branch with determinism/idempotency proof, malformed-data rejection, and unlock-definition data-contract guards; registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml` (new "Run Phase 2 Era Correction Tests" step). `test_progression_foundation.gd` (139 checks) and `test_unit_m2_m7.gd` (144 checks) updated where they asserted the removed vessel -> Iron Age trigger or used `eldergrove_reached` as an unknown-ID example.
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` (status, baseline, section 8 correction marked implemented, new section 12 with the shipped boundary and the exact legacy migration policy), `PROGRESSION_IMPLEMENTATION_ROADMAP.md` (Phase 2 marked implemented, exit criteria met), `ROADMAP.md` (era correction implemented; Eldergrove/multi-island still future work), `GDD.md` era-progression bullet synced.

## [2026-11-16] Progression Foundation Phase 1 — Facts, Unlock Definitions & Save Compatibility

**Type:** Architecture & Infrastructure (no gameplay balance changes)  
**Engine Verified:** `Godot 4.7.2.stable` (local headless run: static verifier `182` checks, world clock `5` checks, P0 unit `142` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks, new progression suite `137` checks across `6` suites — all green)

### Summary
Implemented the Phase 1 progression foundation from `docs/PROGRESSION_FOUNDATION_DESIGN.md` / `docs/PROGRESSION_IMPLEMENTATION_ROADMAP.md` without changing any gameplay balance, era trigger, or player-facing behavior: a durable progression-fact service with stable snake_case IDs and a known-fact registry (`scripts/progression/ProgressionState.gd`), a strict all-or-nothing data-driven unlock definition loader/validator over the new `data/unlocks.json` (`scripts/progression/ProgressionUnlockCatalog.gd`), a deterministic fail-closed `all_of`/`any_of` evaluator that never mutates progression state (`scripts/progression/ProgressionUnlockEvaluator.gd`), and the Stone Age milestone now recorded as the durable fact `forgotten_shore_first_stone_wall_tier_2` after a successful Stone Wall Tier 2 upgrade transaction (idempotent, era ownership unchanged in `EraProgressionManager`).

### Key Changes
- **Progression facts (`scripts/progression/ProgressionState.gd`):** idempotent `record_fact`, registry-validated IDs (malformed or unknown IDs rejected), `fact_recorded` signal emitted only on the absent -> present transition, defensive `get_fact_ids`, sorted deterministic serialization, transactional `apply_save_state` (null clears, valid array replaces atomically, invalid array rejected with zero mutation).
- **Unlock definitions (`scripts/progression/ProgressionUnlockCatalog.gd`, `data/unlocks.json`):** `stone_age_era` definition requires the stone-wall fact via `all_of`; loader rejects missing/malformed files, duplicate definition IDs, unknown requirement fact IDs, and empty requirement groups with reported reasons; any validation error leaves the catalog empty so malformed data can never grant unlocks. No script expressions or eval.
- **Unlock evaluation (`scripts/progression/ProgressionUnlockEvaluator.gd`):** `all_of` / `any_of` / combined semantics; empty, missing, or unknown requirement groups never unlock even for definitions that bypass the catalog; evaluation is a pure read.
- **Stone Age integration (`ForgottenShoreSession.gd`):** `progression` service member; the milestone fact is recorded only after `request_upgrade_wall` succeeds (east or west wall), repeating the milestone never duplicates progression, era messages/HUD behavior unchanged.
- **Save compatibility (`SaveManager.gd`):** new optional `progression_flags.progression_facts` array (schema stays v2, matching how `tree_states`/`hearth_boost_remaining` were introduced); strict validation rejects unknown/malformed fact IDs from saves; `migrate_payload` deterministically and idempotently backfills the stone-wall fact when `era_id == "stone_age"` (era is only reachable via that milestone) and never infers it for `iron_age` saves (the vessel-ready path can skip stone walls); malformed fact arrays are rejected, not repaired.
- **Tests & CI:** new `tests/test_progression_foundation.gd` (137 checks, 6 suites) covering the 16 required Phase 1 scenarios; registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml` (new "Run Progression Foundation Tests (Phase 1)" step).
- **Docs:** `PROGRESSION_FOUNDATION_DESIGN.md` status updated to implemented-for-Phase-1 with a new section 11 recording the shipped boundary (code-level fact registry instead of a second data file, no gameplay wiring of the catalog until an availability consumer exists, locked/available only); `PROGRESSION_IMPLEMENTATION_ROADMAP.md` Phase 1 marked implemented, Phases 2+ still planning only.

## [2026-11-15] Baseline v1.4.3 — Data-Driven Building Config, Transactional Load, Era Progression & Payment Feedback

**Type:** Configuration Correctness, Save Robustness, UX Safety & New Progression Feature  
**Engine Verified:** `Godot 4.7.2.stable` (local headless run: static verifier `176` checks, world clock `5` checks, P0 unit `142` checks across `17` suites, M8 integration `38` checks, P1 experimental `14` checks — all green; CI test-regression on run `#39` fixed)

### Summary
Made `data/buildings.json` the actual source of truth for every plot (including `wall_east_01`, whose JSON entry used to be skipped because the plot was pre-registered in `_init()`), so `upgrade.cost`, `upgrade.max_durability`, `cost_label`, and `title` are now read and drive cost/HP/thorn labels and the upgrade result message; hardened save/load (full transactional rollback on partial-load failure plus `current_day_number` backfill from `day_count` so a v1 save taken mid-Night 2 no longer replays Night 1 waves); removed the duplicate unvalidated `lighting.json` loader in `NightEncounterManager` in favor of the validated `HearthSystem` loader; added an explicit unsaved-progress confirmation before "Return to Main Menu" (manual save is locked at night and autosave only fires at sunrise); shipped flying resource/gold payment feedback; and introduced the staged Era progression (`Wood Age` -> `Stone Age` -> `Iron Age`) that never appears all at once on the first island.

### Key Changes
- **Data-driven plots (`BuildingManager.gd`, `data/buildings.json`):** `apply_data_configs()` now applies JSON config to already-registered plots (`wall_east_01` included) without resetting runtime state, registers missing JSON plots when `register_forgotten_shore_expansion_plots()` runs, safe-casts cost dictionaries (a malformed `build_cost` can no longer break the loader), stores `title`/`cost_label`/`upgrade_*` per plot, and `request_upgrade_wall()` spends `upgrade_cost` and sets `upgrade_max_durability`/`upgrade_target_type` from data with the old constants kept only as fallback. UI helpers `get_plot_title/get_plot_cost_label/get_plot_upgrade_cost(_label)` replace hardcoded strings in `_get_plot_nodes`, the wall labels, and the `.tscn` statics (synced at `_ready`).
- **Save robustness (`SaveManager.gd`, `ForgottenShoreSession.gd`):** `load_game_state()` snapshots the live payload first and fully rolls back on any partial apply failure (no more half-applied state behind a "starting a fresh reign" message); `migrate_payload()` backfills `night_encounter.current_day_number` from `day_count` for pre-v2 saves and validates `current_day_number <= day_count`.
- **Single lighting loader (`HearthSystem.gd`, `NightEncounterManager.gd`):** HearthSystem owns the static, validation-gated tier cache (`get_validated_tiers()`); NightEncounterManager's duplicate `_load_hearth_tiers()` static cache and hardcode fallback were removed and now delegate to it.
- **UX safety (`PauseMenu.gd`, `ForgottenShoreSession.gd`):** "Return to Main Menu" now compares a progress signature (payload minus volatile `world_time`) against the last save/load/autosave and asks for explicit confirmation when progress would be lost.
- **Payment feedback (`ForgottenShoreSession.gd`):** `_spawn_payment_fly()` sends colored per-resource particles flying from the paying actor to the target (build, repair, Stone Wall upgrade, Hearth upgrade/stoke, recruit, Shrine Offering, Kindle Flare, Shipwreck stages).
- **Era progression (`data/eras.json`, `EraProgressionManager.gd`, `ClockHUD.gd`):** `Wood Age` from the start, `Stone Age` on the first `Stone Wall Tier 2`, `Iron Age` at `Shipwreck Stage 3`; persisted as `progression_flags.era_id` with strict validation and old-save inference (`stone_wall` present -> `Stone Age`); HUD clock line shows the current era.
- **UI strings from data:** the hardcoded `"Upgraded to Stone Wall Tier 2 (260 HP, 20 thorn dmg)!"` and `"Dawn of Day 3+! ..."` messages are now data-driven/dynamic (`Dawn of Day %d`).
- **Repo hygiene & docs:** orphan `tests/test_vertical_slice.gd.uid` removed (`.gd` was already gone); GDD wall position synced to `x=380` (three places), resource node count corrected to five (two single-use caches + three renewable) with `stone_deposit_west` (`x=-600`) added; `readme.md` documents `Q`, `Space`, and `Esc` controls; `docs/ROADMAP.md` added as the home for planned features (archer perch permanence, leader-role Monarch, scattered vagrant camps, rare mountable steed, wandering merchant, building tier matrix `Lvl 1-3` wood / `Lvl 4-5` stone, Iron Age heavy equipment, Greedling variants with secret-item carriers, extended settings, and the post-Night 3 difficulty-plateau observation).
- **CI:** run `#39` (commit `9571e23`) failed because the new actionable-plot test at `x=125` was answered by the nearer `stone_outcrop_east` resource node (`65 px` vs Watchtower `85 px`) — the resolver's cross-category nearest-wins behavior is intended. The test now collects the stone node first and additionally pins `get_nearest_actionable_plot_id()` directly.
 — Night Balance, Archer Flank Defense, Auto-Chop & Feedback Pass

**Type:** Gameplay Logic Audit (Combat, Economy & UI/UX), Balance Rebuild & Documentation Sync  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Rebuilt the Night 1 defense math (Wooden Wall Lv.1 thorn `15 -> 5`, so passive-only defense now breaches and the free first `Archer` becomes the intended answer), gave the `Archer` full combat behavior (1s volley cadence, Watchtower perch `x2` damage, west-flank pursuit of Day 2+ West Scouts), made idle `Builders` auto-chop Wood, added the renewable west `Stone Quarry` (`x=-600, +3S`), locked `ISLAND_CLEARED` behind `Shipwreck Stage 3` (removed the Day-2 auto-win), and shipped a feedback pass (population/vagrant HUD, victory banner, floating text at actor positions, `building_attacked` signals for wall hits and tramples, adaptive sunset/night warnings).

### Key Changes
- **Combat (`NightEncounterManager.gd`, `BuildingManager.gd`, `NPCBuilderAgent.gd`):** Wooden Wall Lv.1 thorn `5` (Lv.2/Stone stay `20`), breach trample of interior buildings, `get_nearest_active_enemy`/`damage_nearest_enemy` west-lane API, `is_fully_operational` gate for Watchtower support and Archer perch, Archer pursuit at `190px` trailing gap (clamped west of `-600`), greedling tool confiscation at night.
- **Economy (`ResourceNodeManager.gd`, `NPCPopulationManager.gd`, `data/resource_nodes.json`):** `Stone Quarry` west node (`+3S`, renewable), Builder auto-chop (wood-only, daylight-only) with `auto_chop_collected`, `2` starting Vagrants, first Archer assignment free, `resource`/`renewable` node filters.
- **Win condition & UI (`ForgottenShoreSession.gd`, `ClockHUD.gd`, `ForgottenShore.tscn`):** `ISLAND_CLEARED` only on `Shipwreck Stage 3` with Victory Banner overlay, `PopulationLabel` (`NPCs / roles / Idle / Vagrants`), West Scout HP alerts, `building_attacked` floating feedback, post-victory calm nights, adaptive Night 2+ warnings.
- **Tests & Docs:** M6 scenarios A/D rebuilt around the new balance (passive breach, tower-held `15 HP`), M8 + vertical slice upgraded to 2-NPC Archer defense (`150 HP` wall) with simulated raid damage + repair flow, P0 compat fixes (`get_balance`, `apply_damage`), and GDD/PRD/SYSTEMS/DECISIONS/ASSET_GUIDELINES/REVISED_BASELINE thorn narratives synced to the shipped balance.

---

## [2026-11-14] Baseline v1.3.6 — Modular Architecture, Gold Anti-Softlock, West Defense & 2D Shaders

**Type:** Architecture Refactor (Task 1) & Gameplay/Visual Expansion (Task 2)  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Extracted `ResourceNodeManager`, `HearthSystem`, and `InteractionResolver` from `ForgottenShoreSession.gd`, added centralized `execute_world_command()`, separated `Watchtower` (`x=210`) and `WoodenWall` (`x=380`), added `+1G` enemy kill rewards and daily `Shrine Offering`, introduced `[Space]` *Kindle Flare* and `West Wall` (`x=-400`) for Day 2+ West Scouts, and added `gl_compatibility` 2D shaders (`day_night_atmosphere.gdshader`, `hit_flash.gdshader`).

### Key Changes
- **Task 1 Modularization:** `ResourceNodeManager.gd`, `HearthSystem.gd`, `InteractionResolver.gd`, `[Q]` `upgrade_tier`, and Save v2 fields (`hearth_level`, `reign_state` String, `node_states` Dictionary).
- **Task 2 Anti-Softlock & West Lane:** `+1G` enemy defeat reward, daily `Shrine Offering` (`4W + 2S -> +2G`), `NightEncounterManager` loading `data/enemies.json`, `[Space]` *Kindle Flare*, `wall_west_01` (`x=-400`), and Day 2+ West Scout waves.
- **Shaders & Feel:** `shaders/day_night_atmosphere.gdshader`, `shaders/hit_flash.gdshader`, randomized SFX pitch (`0.92..1.08`), and micro camera shake on wall impact.

---

## [2026-11-14] Baseline v1.3.5 — Multi-NPC, Core Light Mechanic, Shipwreck & Procedural SFX

**Type:** Feature Expansion (Priority 3–7), Polish & Regression Hardening  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Completed single-player expansion Priorities 3 through 7: multi-NPC population (`Villager`, `Builder`, `Farmer`, `Archer`) with `ToolStands` and task claiming locks, "The Last Light" 3-tier Town Center Hearth mechanic with radiant burn/weakening and `ClockHUD` Night Forecast, expanded `[-1600, 1600]` Forgotten Shore with 3-stage `Shipwreck` and `Greed Portal`, procedural `.wav` SFX, floating popups, hit flashes, and full Save v2 migration/regression tests.

### Key Changes
- **Priority 3 (`NPCPopulationManager.gd`, `NPCBuilderAgent.gd`, `BuildingManager.gd`):** Added multi-NPC roster (up to 6 NPCs), 3 `ToolStands` (`hammer_stand`, `scythe_stand`, `bow_stand`), `claimed_by_npc_id` task lock, and animated follower sprites.
- **Priority 4 (`NightEncounterManager.gd`, `ClockHUD.gd`, `data/lighting.json`, `data/enemies.json`):** Added 3-tier Hearth light radius (`180 -> 320 -> 460 px`), `Light Burn` DoT + `Weakened Strike`, `Shadow Crawler` & `Gloom Brute` escalation, Monarch `Shadow Stagger`, and `ForecastLabel`.
- **Priority 5 (`ForgottenShore.tscn`, `Player.gd`):** Expanded bounds to `[-1600, 1600]`, added 3-stage `Shipwreck` (`x=-1350`) and `Greed Portal` (`x=1350`) relic scavenge.
- **Priority 6 & 7 (`scripts/tools/generate_sfx_assets.py`, `ForgottenShoreSession.gd`, `tests/test_unit_m2_m7.gd`):** Added 6 procedural `.wav` SFX, `SFXPlayer`, floating text popups, damage-state-safe hit flash, and v2 regression unit tests.

---

## [2026-11-14] Baseline v1.3.4 — Pixel-Art Pipeline, Priority 1–2 Expansion & Test Suite Fixes

**Type:** Gameplay Expansion (Priority 1 & 2), Visual Integration & Test Hardening  
**Engine Verified:** `Godot 4.7.2.stable`

### Summary
Integrated 12 procedural pixel-art PNG spritesheets (`scripts/tools/generate_pixel_assets.py`), parallax mountain/forest layers, `SkyLayer` (`layer = -101`), proximity-gated interaction prompts, and Priority 1–2 gameplay systems (`Farm Plot`, `Watchtower`, `Stone Wall Tier 2`, renewable Wood/Stone nodes, and multi-day `ReignState`). Fixed literal `\t` indentation in `tests/test_time_manager.gd`, Stage 1 player save position in M8 integration tests, and strict tab validation in `tests/verify_repo_integrity.py`.

### Key Changes
- **Assets & Visuals (`generate_pixel_assets.py`, `ForgottenShore.tscn`):** Added 12 crisp Nearest PNGs (including `building_vagrant_tent.png`, `bg_mountains_far.png`, `bg_forest_mid.png`, `building_farm_plot_states.png`, and `building_watchtower_states.png`), moved `SkyBackground` into `SkyLayer` (`-101`) behind `ParallaxBackground`, and extended `DeepSoil` bottom bounds.
- **Priority 1 & 2 Gameplay (`BuildingManager.gd`, `ForgottenShoreSession.gd`, `NightEncounterManager.gd`):** Added renewable Wood/Stone nodes on Sunrise, `Farm Plot` (`x=-310`, `x=120`, `+2G/60s` during Daylight), `Watchtower` (`x=290`), `Stone Wall Lv.2` upgrade (`260 HP`, `20 thorn dmg`), nearest-plot `[E]/[B]/[F]` routing, and `BREACH_PENALTY` / `ISLAND_CLEARED` states.
- **Test & Verifier Fixes (`tests/*.gd`, `tests/verify_repo_integrity.py`):** Fixed literal `\t` parse error in `test_time_manager.gd`, added `session.player.global_position.x = 340.0` before Stage 1 save in `test_integration_m8_slice.gd` and `test_vertical_slice.gd`, and tightened ASCII-tab indentation checks.

---

## [2026-11-14] Baseline v1.3.3 — False-Green CI Elimination, M5/M8 Test Fixes & Full Doc Sync

**Type:** Test Runner Hardening, Bug Fix & Documentation Synchronization  
**Engine Verified in CI:** `Godot 4.7.2.stable.official.ed1daf0bf`

### Summary
Eliminated false-green headless test exits by replacing raw `assert()` calls in test suites with fail-fast `_check()` handlers (`quit(1)`) and adding log/exit-code traps in `.github/workflows/godot-ci.yml`. Fixed the M5 movement-vs-construction tick sequence, refactored `test_vertical_slice.gd` to use multi-frame `_initialize()` + `_process()` lifecycle, hardened M9 velocity-based anti-teleport, and synchronized `ASSET_GUIDELINES.md`, `TDD.md` Section 5.1 JSON schema, and `readme.md` to v1.3.

### Key Fixes
- **Test Runner Reliability (`tests/*.gd`, `.github/workflows/godot-ci.yml`):** Replaced `assert()` in test scripts with `_check()` that prints `TEST FAILURE:` and exits with code `1` immediately. Added `set -o pipefail` and `! grep -E "(SCRIPT ERROR:|Parser Error:|TEST FAILURE:)"` guards to every CI step.
- **M5 Unit Test Fix (`tests/test_unit_m2_m7.gd`):** Separated the 5-second movement phase (`x=-220` to `x=360`) from the 2-second construction phase (`progress = 0.5`), ensuring dusk safety override and blocked-path checks execute to completion.
- **Scene Lifecycle Fix (`tests/test_vertical_slice.gd`, `tests/test_integration_m8_slice.gd`):** Removed `_init()` scene instantiation so `@onready var time_manager` is always initialized by Godot before access, with a `MAX_WAIT_FRAMES = 120` timeout guard.
- **M9 Experimental Anti-Teleport (`scripts/networking/NetworkSessionManager.gd`):** Added `server_clock_sec` velocity bounds (`260 px/s`) and deferred `peer_positions` mutation until after `execute_command()` succeeds.
- **Documentation Sync (`docs/ASSET_GUIDELINES.md`, `docs/TDD.md`, `readme.md`):** Updated `ASSET_GUIDELINES.md` to v1.3, added `night_encounter` to `TDD.md` Section 5.1 JSON payload, and locked `readme.md` to Godot `4.7.2.stable`.

---

## [2026-11-14] M0–M8 — Single-Player Vertical Slice Implementation & Automated Test Suite

**Type:** Gameplay Implementation, Code Review & Automated Tests  
**Status:** Ready on `main` (Verified on Godot `4.7.2.stable`)

### Summary
Implemented and verified the complete single-player vertical slice on **Forgotten Shore** following `REVISED_PROJECT_BASELINE.md` v1.2, resolving Open Decisions `OD-01` through `OD-10` in `docs/DECISIONS_M2_M8.md`.

### Key Improvements & Modules Added
- **M0 & M1 (`project.godot`, `Player.gd`, `Player.tscn`, `Main.gd`, `Main.tscn`):** Locked Godot `4.7.2.stable`, added decoupled action signals (`interact`, `recruit_villager`, `build_wall`, `repair_wall`, `save_game`, `toggle_fast_clock`), walk bob feedback, and `Continue Saved Reign` button state check.
- **M2 (`scripts/world/TimeManager.gd`, `SkyAtmosphere.gd`):** Deterministic `Daylight -> Sunset -> Night -> Sunrise` clock with deferred initial signal emission and save/load state serialization.
- **M3 (`scripts/economy/EconomyLedger.gd`):** Atomic kingdom ledger for `gold`, `wood`, and `stone` enforcing all-or-nothing multi-resource spending and rejecting invalid/negative mutations.
- **M4 (`scripts/kingdom/BuildingManager.gd`):** Data-driven Wooden Wall state machine (`PLACEHOLDER -> UNDER_CONSTRUCTION -> COMPLETED -> DAMAGED -> DESTROYED`) with placement range validation and single-deduction guarantee.
- **M5 (`scripts/npc/NPCBuilderAgent.gd`):** Villager recruitment, Builder task priority queue (Dusk safety override > wall repair > wall construction > idle), and explicit path-failure signal without silent teleportation.
- **M6 (`scripts/survival/NightEncounterManager.gd`):** Phase-gated Greedling Raider encounter along the eastern approach route with wall durability combat and sunrise resolution.
- **M7 (`scripts/save/SaveManager.gd`):** Versioned JSON persistence (`user://save_slot_0.json`) with temporary file verification (`.tmp`), previous valid backup preservation (`.bak`), and automatic corrupt-save recovery.
- **M8 (`scripts/world/ForgottenShoreSession.gd`, `ClockHUD.gd`, `tests/test_vertical_slice.gd`):** Full vertical slice wiring on Forgotten Shore plus headless automated test suite covering M2–M7 invariants.

---

## [2026-11-13] Documentation Synchronization — Baseline v1.2

**Type:** Documentation-only update  
**Status:** Committed to the main branch  
**Implementation status:** No gameplay code, Godot project, production assets, or runtime tests were added by this documentation update.

### Summary

Synchronized the existing documentation set around the approved **single-player vertical slice on Forgotten Shore**.

The long-term online co-op vision remains planned for M9+, but is no longer presented as part of the first playable product or P0 requirements.

### Files Updated

| File | Version | Summary |
|---|---:|---|
| readme.md | 1.2 | Rewritten as the current project overview; distinguishes present repository status, P0 slice, deferred features, milestone gates, and documentation ownership |
| docs/REVISED_PROJECT_BASELINE.md | 1.2 | Updated cross-document authority, NPC scope, Stone's unresolved first-slice purpose, M0/M1 separation, and open-decision register |
| docs/PRD.md | 1.2 | Synchronized priorities and acceptance criteria; multiplayer is P1/M9, not P0; added design decisions and version references |
| docs/GDD.md | 1.2 | Clarified first-slice gameplay, long-term story scope, limited P0 content, and unresolved design choices |
| docs/SYSTEMS.md | 1.2 | Defined P0 system responsibilities, invariants, task behavior, persistence expectations, and test gates |
| docs/TDD.md | 1.2 | Corrected repository implementation status, reduced speculative architecture, clarified save validation and M0–M10 technical gates |
| docs/ASSET_GUIDELINES.md | 1.2 | Replaced the old oversized MVP asset list with P0 vertical-slice assets and deferred P1/P2 content |
| docs/CHANGELOG.md | — | Created this factual record of the documentation synchronization |

### Main Decisions Reinforced

- First playable target: one local player on Forgotten Shore.
- P0 economy: Gold, Wood, Stone in one kingdom ledger.
- P0 settlement: Town Center anchor and Wooden Wall construction target.
- P0 NPC scope: Villager recruitment and Builder behavior; Builder's internal representation remains an open decision.
- P0 survival: one basic enemy archetype and one predictable route.
- P0 persistence: versioned local save, validation, temporary write, backup, and recovery.
- Multiplayer: deferred to M9+, after vertical-slice validation.
- M0: create and launch the Godot project foundation.
- M1: add player movement, floor collision, bounds, and local camera.
- Placeholder art is acceptable during early mechanics validation.
- Repository status is documented honestly: no runnable Godot project or gameplay implementation is present yet.

### Open Decisions Kept Explicit

Resource sources and collection interactions, starting balances, recruitment cost/interaction, Stone's actual first-slice purpose, wall placement/cost/duration/repair/refund rules, Builder's representation, first-enemy behavior/tuning, failure consequences, exploration reward, and final persistent NPC fields remain open.

These decisions must be approved in the owning documents before their dependent milestones begin. This update does not invent answers for them.

### Verification

- Fetched updated files back from GitHub after writing.
- Checked document version headers and cross-document references.
- Checked that multiplayer requirements are P1/M9+, not P0.
- Checked that the old multi-enemy / multi-role / multi-building asset list is no longer P0.
- Checked that M0 and M1 have separate deliverables and acceptance gates.
- Checked that README and TDD distinguish placeholder folders from an actual runnable Godot project.

**Not performed:** Godot import, parser check, game launch, gameplay test, unit test, or asset integration. No implementation exists to run those checks against.

### Documentation Commits

| File | Commit |
|---|---|
| readme.md — initial synchronization | 20bdf09 |
| readme.md — M0/M1 and status correction | ecaebb3 |
| readme.md — documentation version alignment | db82171 |
| docs/GDD.md | 66c5c38 |
| docs/PRD.md — v1.1 initial scope sync | d5637d4 |
| docs/PRD.md — v1.2 open decisions and cross-references | 4afd9fc |
| docs/PRD.md — synchronized document-version references | c82e192 |
| docs/SYSTEMS.md | 58b84fb |
| docs/TDD.md | afc6f69 |
| docs/ASSET_GUIDELINES.md | 3b4d07c |
| docs/REVISED_PROJECT_BASELINE.md | 1db6f60, 481b20e |

---

## Change Entry Rules

For future entries:
- Record only changes that have been committed.
- State whether a change is documentation-only, implementation, asset, test, or release work.
- Link the relevant commit(s).
- Distinguish tests that were run from checks that were only reviewed.
- Record breaking scope or architecture decisions and their rationale.
- Do not mark a planned milestone complete before its acceptance criteria pass.
