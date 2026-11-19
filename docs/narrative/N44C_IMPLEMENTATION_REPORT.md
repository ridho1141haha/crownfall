# Crownfall — N4.4-C Implementation Report

- **Base commit:** `main` @ `fa3206d3dee8ac89caacf7afc01db669a62d59c7`
- **Branch:** `feature/n44c-crown-interaction`
- **Scope:** Crown eligibility & provisional `O5` prompt (`PrologueRuinsEnvironment`), D5-gated `pl_06` handshake, stage-owned `_awakening_lock`, generation-guarded rejection/retry (`PrologueExplorationStage`), `test_n44c_crown_interaction.gd`, epoch-scoped 1-line update in `test_n44b_chamber_presentation.gd`, runner/CI registration, and docs sync.
- **Deferred (N4.4-D):** `pl_06_vision` playback, post-vision dialogue, `pl_06` completion recording, `O4` skip policy, N4.4 boundary, `pl_07+`.
- **Governance:** `O2/O3/O4/O5/O6` unchanged (`O5` remains OPEN); R12 five fragments and `CUE_PL06_AWAKENING` unchanged; `PrologueShell`, `SequenceRunner`, `NarrativeData`, `PlayerProfile`, `SaveManager` untouched.
