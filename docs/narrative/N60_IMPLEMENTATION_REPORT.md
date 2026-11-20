# N6.0 Implementation Report — Eldergrove First Playable Slice

**Status:** IMPLEMENTED (`feature/n60-eldergrove-first-playable-slice`)
**Base `main` SHA:** `1ea114111a667aa6f7527c7a82ef0fc4a4def21b`
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Files Changed

- `scripts/world/ResourceNodeManager.gd`
- `scripts/world/EldergroveForestArrival.gd`
- `scenes/world/EldergroveForest.tscn`
- `tests/test_n60_eldergrove_playable.gd`
- `tests/run_all.sh`
- `.github/workflows/godot-ci.yml`
- `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`
- `docs/narrative/N60_IMPLEMENTATION_REPORT.md`
- `docs/CHANGELOG.md`

## 2. Architecture & Systems Reused

- **Player & Camera:** Reuses `scenes/player/Player.tscn` and `scripts/player/Player.gd` (`PlayerController`) with existing `move_left`, `move_right`, `interact` (`[E]`), and `save_game` (`[K]`) input bindings.
- **Interaction Resolution:** Reuses `scripts/player/InteractionResolver.gd` (`InteractionResolver.resolve_nearest()`) with Eldergrove's `ResourceNodeManager` instance (passing out-of-bounds sentinel coordinates for Forgotten Shore-only landmarks).
- **Resource Gathering & Economy:** Reuses `scripts/economy/EconomyLedger.gd` and `scripts/world/ResourceNodeManager.gd` (extended with a minimal `configure_nodes()` helper so Eldergrove defines its own clearing nodes without duplicating manager code).
- **Pause & Scene Exit:** Reuses `scripts/ui/PauseMenu.gd` (`[Esc]` pause, Save Game, Settings, and Return to Main Menu with unsaved-progress confirmation).
- **Progression & Persistence:** Reuses `ProgressionState`, `EraProgressionManager`, `EldergroveHandoffBridge`, and `SaveManager` schema v2 untouched (`SaveManager.SCHEMA_VERSION == 2`). Eldergrove node collection flags are merged into `progression_flags["node_states"]` (String -> bool) under `eldergrove_*` keys alongside updated `resources` and `player` position/facing.

## 3. Gameplay Implemented

- **Bounded Traversable Clearing:** `EldergroveForest.tscn` provides solid ground collision, east/west wall bounds (`-760..760`), camera limits (`-800..800`), and intentional landing spawn (`x = -320`, beside the moored vessel).
- **Meaningful Clearing Interactions:** Three interactable clearing nodes (`eldergrove_fallen_timber_01` +4W, `eldergrove_mossy_stone_01` +3S, `eldergrove_foraged_supply_01` +3G) with visual markers, live `[E]` proximity prompts, resource HUD readout, and duplicate-collection guards.
- **Save, Exit & Re-Entry:** Players can save via `[K]` or `PauseMenu -> Save Game`, exit to `Main.tscn`, and re-enter via `Continue` directly into Eldergrove with restored resources, collected node states, and player position without replaying N5.5 voyage/arrival or duplicating progression facts.

## 4. Tests Added & Results

- `tests/test_n60_eldergrove_playable.gd` (registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`) covers:
  - Scene initialization, spawn validity, camera limits, `PlayerController` movement, and boundary clamping.
  - Out-of-range rejection, `InteractionResolver` targeting, resource collection into `EconomyLedger`, and duplicate collection rejection.
  - Failed-save and unsafe-path protection, schema v2 manual save, exit to `Main.tscn`, and `Continue` re-entry preserving resources, node states, player position, and exact progression fact count without N5.5 replay.
  - Legacy Forgotten Shore Continue and New Game / Skip Prologue regressions.
- Runtime execution is verified in Google Colab (`Godot 4.7.2`) and GitHub Actions CI (`bash tests/run_all.sh`).

## 5. Known Limitations

- No Eldergrove building plots, NPCs, night raids, crafting, or return-to-Forgotten-Shore travel yet (intentionally out of scope for N6.0).
- Eldergrove clearing resource markers use simple colored `ColorRect` placeholders + world labels pending dedicated Island 2 art assets.
- `SaveManager` schema v2 remains unchanged; Eldergrove saves preserve the underlying Forgotten Shore base payload fields (buildings, NPCs, night encounter) carried across from arrival.

## 6. Manual Verification Steps

1. Start from a Forgotten Shore save at Shipwreck Stage 3, interact (`[E]`) to Set Sail, and complete the voyage into `EldergroveForest.tscn`.
2. Confirm player spawns at `x = -320` beside the moored vessel, moves smoothly with `A/D`, and stops at both clearing edges.
3. Walk east to each clearing node, press `[E]` to gather Timber/Stone/Crate, confirm resources increment and markers disappear, and confirm pressing `[E]` again does not double-collect.
4. Press `[K]` (or `[Esc]` -> **Save Game**), then choose **Return to Main Menu**.
5. Click **Continue Saved Reign** and confirm the game loads directly into Eldergrove with your saved resources, position, and collected nodes intact — with no voyage or arrival replay.

## 7. Design Assumptions for Owner Visibility

- Added `ResourceNodeManager.configure_nodes(custom_nodes)` as the minimal extension needed to reuse `ResourceNodeManager` on Eldergrove without duplicating resource-gathering logic or modifying Forgotten Shore's `DEFAULT_NODES`.
- Stored Eldergrove clearing node states under `eldergrove_*` keys inside existing `SaveManager` v2 `progression_flags["node_states"]` to avoid any save schema migration.
