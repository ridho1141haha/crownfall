# CROWNFALL: THE LAST LIGHT
# CHANGELOG

All notable project and documentation changes are recorded here in reverse chronological order.

This changelog records repository changes that actually occurred. Planned features and unimplemented work belong in the PRD, GDD, SYSTEMS, TDD, or roadmap sections—not as completed changelog entries.

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
| README.md | 1.1 | Rewritten as the current project overview; distinguishes present repository status, P0 slice, deferred features, milestone gates, and documentation ownership |
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
| README.md — initial synchronization | 20bdf09 |
| README.md — M0/M1 and status correction | ecaebb3 |
| docs/GDD.md | 66c5c38 |
| docs/PRD.md — v1.1 initial scope sync | d5637d4 |
| docs/PRD.md — v1.2 open decisions and cross-references | 4afd9fc |
| docs/PRD.md — synchronized document-version references | c82e192 |
| docs/SYSTEMS.md | 58b84fb |
| docs/TDD.md | afc6f69 |
| docs/ASSET_GUIDELINES.md | 3b4d07c |
| docs/REVISED_PROJECT_BASELINE.md | 1db6f60 |

---

## Change Entry Rules

For future entries:
- Record only changes that have been committed.
- State whether a change is documentation-only, implementation, asset, test, or release work.
- Link the relevant commit(s).
- Distinguish tests that were run from checks that were only reviewed.
- Record breaking scope or architecture decisions and their rationale.
- Do not mark a planned milestone complete before its acceptance criteria pass.
