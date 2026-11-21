# N6.1 Implementation Report — First Camp Construction Loop

**Status:** IMPLEMENTED (`feature/n61-first-camp-construction`)
**Base `main` SHA:** `28bc0638a6fc3bcd932afc47e050cd32f10572ad` (PR #45)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`

---

## 1. Files Changed

- `scripts/player/InteractionResolver.gd`
- `scenes/world/EldergroveForest.tscn`
- `scripts/world/EldergroveForestArrival.gd`
- `tests/test_n61_first_camp_construction.gd`
- `tests/run_all.sh`
- `.github/workflows/godot-ci.yml`
- `docs/narrative/N5_IMPLEMENTATION_ROADMAP.md`
- `docs/narrative/N61_IMPLEMENTATION_REPORT.md`
- `docs/CHANGELOG.md`

## 2. Architecture Reused

- **Economy Authority:** Reuses `EconomyLedger.can_afford()` and `EconomyLedger.try_spend()` for atomic resource validation and single-deduction spending (zero duplicate inventory).
- **Interaction Resolution:** Reuses `InteractionResolver.resolve_nearest()` via an optional, backwards-compatible `custom_targets` parameter so Eldergrove's First Camp site resolves alongside existing `ResourceNodeManager` nodes through the same nearest-distance pipeline.
- **Visual Assets:** Reuses `res://assets/buildings/camp/building_vagrant_tent.png` (48x32) for the completed shelter sprite, paired with a clearly marked unbuilt site indicator (`SiteMarker` + `CampLabel`).
- **Save & Continue:** Reuses `SaveManager` schema v2 (`SaveManager.SCHEMA_VERSION == 2` unchanged) and the N5.6 read-only Continue restoration path.

## 3. Construction Cost & Rationale

- **Cost:** `4 Wood + 2 Stone` (`CAMP_BUILD_COST = {"wood": 4, "stone": 2}`).
- **Rationale:** Eldergrove's N6.0 clearing nodes grant `+4 Wood` (`eldergrove_fallen_timber_01`) and `+3 Stone` (`eldergrove_mossy_stone_01`). A player arriving with `0W / 0S` cannot construct immediately, must gather both Timber and Stone nodes, and always has enough to complete the First Camp with `1 Stone` remaining.
- **Location:** `x = 80.0` (`CAMP_INTERACT_RANGE = 68.0`), centered in the clearing between Fallen Timber (`x = -60`) and Mossy Outcrop (`x = 220`) with zero interaction-range overlap.

## 4. Persistence Mechanism

- Persists `"eldergrove_first_camp_built": bool` inside existing `SaveManager` v2 `progression_flags["node_states"]` (validated strictly as `String -> bool` by `SaveManager.validate_payload()`).
- `ResourceNodeManager.apply_save_state()` ignores keys absent from its configured `nodes` table, keeping Forgotten Shore and Eldergrove resource nodes completely isolated.
- On Continue restoration, `_hydrate_gameplay_from_payload()` restores `_first_camp_built` and updates visuals without spending resources or rewriting the disk save.

## 5. Test Coverage & Results

- `tests/test_n61_first_camp_construction.gd` (registered in `tests/run_all.sh` and `.github/workflows/godot-ci.yml`) verifies:
  1. Construction site initialization and initial unbuilt visuals.
  2. `InteractionResolver` detection of `eldergrove_first_camp` and insufficient-resource prompt.
  3. Insufficient resources prevent construction and deduct zero resources.
  4. N6.0 Timber (`+4W`) and Stone (`+3S`) gathering works and enables construction.
  5. Exact `4W 2S` deduction once, state transition once, and completed shelter visual state.
  6. Repeated interaction is idempotent and never double-charges.
  7. Failed save returns false and preserves the previous save byte-exact.
  8. Save + Return to Main Menu + Continue restores built camp, shelter sprite, exact balances, and collected node states without re-charging or replaying N5.5 arrival.
  9. Legacy Forgotten Shore Continue remains unaffected.
- Local static verifier (`python3 tests/verify_repo_integrity.py`) passed; Godot 4.7.2 headless runtime tests and `bash tests/run_all.sh` run in Google Colab and GitHub Actions CI.

## 6. Known Limitations

- Single shelter structure only; multi-plot building, upgrades, NPCs, raids, and crafting remain future Chapter II work.
- Unbuilt site uses a simple `ColorRect` stake marker pending dedicated Island 2 construction-site art.
- Completed shelter reuses `building_vagrant_tent.png` as a clean existing camp visual.

## 7. Manual Gameplay Verification Steps

1. Load an Eldergrove save (or sail from Forgotten Shore).
2. Walk to `x = 80` (`Camp Site (4W 2S)`) before gathering; confirm `[E]` rejects with insufficient resources and deducts nothing.
3. Gather Fallen Timber (`x = -60`, `+4W`) and Mossy Outcrop (`x = 220`, `+3S`).
4. Return to `x = 80`, press `[E]` to construct First Camp; confirm `4W 2S` is deducted, the site marker hides, and the tent shelter appears with `"First Camp (Built)"`.
5. Press `[E]` again to verify no extra deduction occurs.
6. Press `[K]` (or `[Esc]` -> **Save Game**), return to Main Menu, click **Continue Saved Reign**, and confirm the tent remains built, resources match, and gathered nodes stay collected.
