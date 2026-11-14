# CROWNFALL: THE LAST LIGHT
# FIRST VERTICAL SLICE — APPROVED DESIGN & TECHNICAL DECISIONS (OD-01 to OD-10)

**Document Version:** 1.2  
**Date:** 2026-11-14  
**Baseline Reference:** `docs/REVISED_PROJECT_BASELINE.md` (Section 15)  
**Verified Engine:** Godot `4.7.2.stable`

---

## Resolved Open Decisions (M0–M8 Vertical Slice)

In accordance with Section 15 of `REVISED_PROJECT_BASELINE.md`, all open decisions required for Milestones M0 through M8 are formally resolved and recorded below before implementation:

| ID | Decision Topic | Approved First-Slice Resolution | Owning System / File |
|---|---|---|---|
| **OD-01** | Gold, Wood, and Stone sources & collection | Four deterministic single-use world caches on Forgotten Shore interacted via `[E]` within `72 px`: `cache_gold_west` (+4 Gold at `x=-480`), `timber_pile_west` (+5 Wood at `x=-110`), `stone_outcrop_east` (+3 Stone at `x=190`), and `shrine_cache_far_west` (+3 Gold at `x=-780`). | `ForgottenShoreSession.gd` |
| **OD-02** | Starting balances & recruitment cost | Starting ledger balances: `2 Gold, 2 Wood, 1 Stone`. Recruiting the Villager at the Vagrant Camp (`x=-220`) costs `2 Gold` via `[R]` (or contextual `[E]`). | `EconomyLedger.gd`, `NPCBuilderAgent.gd` |
| **OD-03** | Stone's concrete first-slice purpose | Stone is required to reinforce the Wooden Wall foundation (`2 Gold, 4 Wood, 2 Stone` build cost; `2 Wood, 1 Stone` repair cost), granting `150` max durability to withstand the first night. | `BuildingManager.gd` |
| **OD-04** | Wooden Wall placement, cost, duration, repair, refund | Fixed strategic eastern defense plot at `x=360.0` (`±96 px` interaction range). Build cost: `2G, 4W, 2S`; build duration: `4.0s` of Builder work; repair cost: `2W, 1S` (or Builder automatic repair at `18 HP/s` during daylight). No demolition refund in P0. | `BuildingManager.gd` |
| **OD-05** | Builder internal representation | Represented as a single persistent actor (`NPCBuilderAgent` with `id="npc_01"`, `recruited: bool`, `role: "villager" -> "builder"`, and explicit state machine `UNRECRUITED -> IDLE -> MOVING_TO_TASK -> WORKING / RETURNING_TO_SAFETY`). | `NPCBuilderAgent.gd` |
| **OD-06** | First enemy identity, behavior, tuning, spawn | **Greedling Raider** spawns at `x=820.0` strictly on `night_started`, marches west at `95 px/s`, attacks the Wooden Wall (`15 dmg/s` while taking `10 thorn dmg/hit`, `60 HP`), and resolves at `sunrise_reached`. | `NightEncounterManager.gd` |
| **OD-07** | Wall destruction, breach, and failure outcomes | Non-destructive recovery in P0: if the wall is unbuilt or destroyed (`0 HP`), the raider marches to `TownCenter` (`x=0.0`) and sets `settlement_breached = true` without permanent game-over, allowing the player to rebuild on the next day. | `NightEncounterManager.gd` |
| **OD-08** | Minimal exploration reward / POI interaction | Far-western **Forgotten Shrine** (`x=-780.0`) rewards `+3 Gold` upon exploration and interaction (`[E]`) without requiring a quest framework. | `ForgottenShoreSession.gd` |
| **OD-09** | Persistent NPC fields & final save payload | `schema_version: 1` JSON at `user://save_slot_0.json` storing `world_id`, `island_id`, `day_count`, `world_time`, `world_phase`, `resources`, `buildings` (`id, state, progress, durability, max_durability`), `npcs` (`id, recruited, role, state, position_x`), and `progression_flags` (`first_night_survived`, `collected_nodes`). | `SaveManager.gd` |
| **OD-10** | Exact Godot stable patch & project settings | Locked and verified on **Godot `4.7.2.stable`** (`1280x720`, `gl_compatibility`, nearest-neighbor pixel filtering). | `project.godot`, `TDD.md` |
