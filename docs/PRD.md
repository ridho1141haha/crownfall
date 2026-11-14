# CROWNFALL: THE LAST LIGHT
# PRODUCT REQUIREMENTS DOCUMENT (PRD)

**Document Version:** 1.3
**Product:** CROWNFALL: THE LAST LIGHT
**Platform:** Windows PC
**Engine:** Godot 4
**Product Stage:** M0–M8 Vertical Slice Prototype Implemented (`Godot 4.7.2.stable`)
**Development Model:** Solo Developer + AI Assistance
**Source of Truth:** `docs/REVISED_PROJECT_BASELINE.md`

> **Scope authority:** This PRD is aligned with the Revised Project Baseline v1.3 & `docs/DECISIONS_M2_M8.md`, GDD v1.3, SYSTEMS v1.3, and TDD v1.3. The first playable target is a single-player vertical slice. Online multiplayer remains a long-term product goal, but is not part of the first slice or its acceptance criteria.

---

# 1. PRODUCT VISION

## 1.1 Vision Statement

CROWNFALL: THE LAST LIGHT is a 2D side-scrolling medieval fantasy kingdom-building and survival adventure. Players restore a settlement in a fallen world, gather resources, recruit villagers, construct defenses, explore the remains of Aetherion, and prepare for creatures that emerge after sunset.

The long-term experience combines accessible controls with meaningful kingdom decisions, exploration, survival pressure, and atmospheric environmental storytelling.

## 1.2 Product Goals

Long-term product goals:

1. Make kingdom development feel tangible and rewarding.
2. Make exploration reveal useful discoveries and traces of the fallen world.
3. Create readable, fair survival pressure that rewards preparation.
4. Build a distinctive original pixel-art identity.
5. Expand the world through separate islands and meaningful progression.
6. Introduce online cooperative play for up to four players after the core game loop is validated.
7. Establish a maintainable technical and content foundation for future development.

First vertical-slice goals:

1. Prove that movement and interaction feel understandable.
2. Prove that gathering and spending resources create meaningful decisions.
3. Prove that recruitment and construction form a readable kingdom loop.
4. Prove that Builder behavior supports construction and preparation.
5. Prove that one night encounter creates understandable survival pressure.
6. Save and restore the resulting local kingdom state reliably.

## 1.3 Target Audience

Primary long-term audience:
- Players interested in 2D indie kingdom-building games.
- Players who enjoy exploration and survival systems.
- Fans of atmospheric medieval fantasy and pixel-art presentation.
- Players interested in cooperative progression (future multiplayer scope).

Secondary audience:
- Casual exploration players.
- Strategy and resource-management enthusiasts.
- Players who enjoy environmental storytelling.

The first vertical slice is intended for internal development and playtesting. It is not a public-market release.

---

# 2. PRODUCT POSITIONING

## 2.1 Design References

| Reference | Design inspiration |
|---|---|
| Kingdom: New Lands | Minimalist side-scrolling kingdom management |
| Kingdom Two Crowns | Shared kingdom fantasy and cooperative potential |
| Stardew Valley | Readable progression and world interaction |
| Eastward | Atmospheric pixel-art presentation |
| To the Moon | Emotional environmental and narrative storytelling |

These are references for analysis only. CROWNFALL must use original characters, worldbuilding, art, audio, mechanics, and writing.

## 2.2 Long-Term Unique Value Proposition

**Restore a kingdom, explore forgotten islands, and protect the last light of a dying world.**

The intended differentiators are:
- Side-scrolling kingdom development integrated with exploration.
- Preparation-focused survival rather than action-heavy combat.
- Separate islands with distinct environments and discoveries.
- Environmental storytelling that rewards curiosity.
- A future shared-kingdom cooperative mode with independent player cameras.

## 2.3 Product Pillars

1. **Build:** establish, protect, and improve a settlement through resource decisions.
2. **Explore:** travel through the world, discover resources, and uncover traces of Aetherion's past.
3. **Prepare and Survive:** use daylight wisely, prepare defenses, and survive threats after sunset.

All first-slice features must support at least one of these pillars.

---

# 3. PRODUCT SCOPE AND PRIORITIES

## 3.1 Priority Definitions

| Priority | Meaning |
|---|---|
| P0 | Required for the single-player vertical slice (M0–M8) |
| P1 | Planned after vertical-slice validation: multiplayer prototype and initial content expansion (M9–M10) |
| P2 | Future vision; not committed to the current production plan |

A priority indicates planned scope, not implementation status. A feature is not complete until its acceptance criteria have been tested in the actual project.

## 3.2 First Playable Product

The first playable product is a **single-player vertical slice on Forgotten Shore**.

It must demonstrate this complete loop:

1. Start a new local game.
2. Move the Monarch across the island.
3. Collect a small amount of Gold, Wood, and Stone.
4. Recruit a Villager.
5. Place and fund a Wooden Wall construction.
6. Allow or assign the Builder behavior to complete or repair the wall.
7. Advance through daylight, sunset, and night.
8. Face one basic enemy archetype attacking through one predictable route.
9. Survive until sunrise.
10. Preserve the resulting kingdom state through local save/load.

The slice should be small enough to build and test incrementally. It does not need a complete story chapter, multiple islands, or multiplayer to prove its core loop.

## 3.3 P0 — First Vertical Slice Requirements

### Feature Group A — Project and Player

| ID | Requirement | Priority |
|---|---|---|
| CORE-001 | A Godot 4 project opens and runs on the selected Windows development environment | P0 |
| CORE-002 | The player can move horizontally left and right | P0 |
| CORE-003 | Player movement respects collision and world boundaries | P0 |
| CORE-004 | A local Camera2D follows the player | P0 |
| CORE-005 | The player can issue context-appropriate interaction requests | P0 |
| CORE-006 | Basic movement feedback is present; placeholder animation is acceptable during mechanics validation | P0 |

Acceptance:
- The project launches without parser or runtime errors in the selected Godot version.
- The player can move in both directions.
- The player cannot pass through the test floor or leave the playable bounds.
- The camera follows the local player.
- Interaction requests do not directly mutate UI-owned state.

### Feature Group B — World and Time

| ID | Requirement | Priority |
|---|---|---|
| WORLD-001 | One playable island named Forgotten Shore exists | P0 |
| WORLD-002 | The island uses side-scrolling 2D terrain | P0 |
| WORLD-003 | Playable world boundaries prevent unintended travel outside the slice | P0 |
| WORLD-004 | A day/night clock advances through daylight, sunset, night, and sunrise | P0 |
| WORLD-005 | Phase changes emit clear events for dependent gameplay systems | P0 |
| WORLD-006 | The first-slice world state can be saved and restored | P0 |

Acceptance:
- The player can traverse the intended test area.
- Time advances deterministically according to the configured tuning values.
- Each phase transition occurs once per cycle and can be observed by dependent systems.
- The first slice does not require background simulation of other islands.

The current 12-minute cycle (8 minutes daylight, 1 minute sunset, 3 minutes night) is a provisional tuning target, not a fixed final balance requirement.

### Feature Group C — Economy and Resources

| ID | Requirement | Priority |
|---|---|---|
| ECO-001 | The kingdom ledger stores Gold | P0 |
| ECO-002 | The kingdom ledger stores Wood | P0 |
| ECO-003 | The kingdom ledger stores Stone | P0 |
| ECO-004 | The player can collect the resource amounts required by the slice | P0 |
| ECO-005 | Valid resource costs can be spent through the economy service | P0 |
| ECO-006 | Failed or invalid transactions leave all balances unchanged | P0 |

Acceptance:
- Resource balances are held in one kingdom ledger, not in HUD nodes.
- Balances cannot become negative.
- Zero, negative, or unknown resource requests are rejected.
- Multi-resource spending is all-or-nothing.
- The UI displays confirmed ledger state and cannot independently change balances.

Out of scope for P0: personal coin-pouch capacity, physical coin-drop inventory, complex crafting, trading, and additional resource types.

### Feature Group D — Kingdom and Building

| ID | Requirement | Priority |
|---|---|---|
| BUILD-001 | A Town Center acts as the starting settlement anchor and safe-area reference | P0 |
| BUILD-002 | The player can select a valid Wooden Wall construction location | P0 |
| BUILD-003 | Placement validation occurs before resources are deducted | P0 |
| BUILD-004 | A valid funded placement creates a construction blueprint/state | P0 |
| BUILD-005 | Construction progress is advanced by Builder behavior | P0 |
| BUILD-006 | The Wooden Wall can receive damage from the first enemy encounter | P0 |
| BUILD-007 | The wall can be repaired when the required conditions and resources are met | P0 |

Acceptance:
- Invalid placement is rejected without charging the player.
- Insufficient resources prevent construction.
- A valid construction cost is deducted exactly once.
- Construction follows an explicit state transition: placeholder/blueprint → under construction → completed → damaged/destroyed as applicable.
- Construction progress belongs to gameplay simulation, not presentation or HUD scripts.
- Interrupted valid work does not silently duplicate costs or progress.

The Town Center is the starting anchor. The Wooden Wall is the primary construction target for the first slice. Additional buildings are deferred unless they are necessary to validate the core loop.

### Feature Group E — Villager and Builder

| ID | Requirement | Priority |
|---|---|---|
| NPC-001 | The player can recruit at least one Villager | P0 |
| NPC-002 | A recruited Villager can move between relevant world locations | P0 |
| NPC-003 | Builder behavior can acquire a valid construction or repair task | P0 |
| NPC-004 | Builder behavior validates its target and task before working | P0 |
| NPC-005 | Builder behavior prioritizes safety when sunset begins | P0 |
| NPC-006 | Invalid, completed, or cancelled tasks are released cleanly | P0 |

Acceptance:
- Recruitment deducts its cost only after validation.
- The NPC has a stable identity and a defined gameplay state.
- Builder behavior cannot work on a missing, completed, cancelled, or unreachable task.
- At sunset, optional work is interrupted and the Builder returns toward the designated safe area when a valid path exists.
- An unreachable safe area is reported as a failure; the NPC is not silently teleported.

Approved representation (`OD-05`): Recruiting the Villager at the Vagrant Camp (`x=-220.0`, cost `2 Gold`) transitions the persistent `NPCBuilderAgent` (`id="npc_01"`) from `role: "villager"` to `role: "builder"`.

Farmer, Archer, Knight, Guard, and advanced job progression are not P0.

### Feature Group F — First-Night Survival

| ID | Requirement | Priority |
|---|---|---|
| SUR-001 | One basic enemy archetype spawns during the night phase | P0 |
| SUR-002 | The first enemy follows one predictable route toward the settlement | P0 |
| SUR-003 | The enemy can attack the Wooden Wall | P0 |
| SUR-004 | The wall's state reflects valid damage and repair | P0 |
| SUR-005 | The player can survive the encounter until sunrise | P0 |
| SUR-006 | Sunrise resolves the encounter and advances the world state | P0 |

Acceptance:
- The enemy does not spawn before its configured phase.
- Its route and target selection are deterministic enough to test.
- Wall defense has a meaningful effect on the encounter.
- The encounter can end at sunrise without requiring a full combat system.
- Approved breach rule (`OD-07`): If the wall falls and a raider reaches Town Center (`x=0.0`), `settlement_breached` is recorded without permanent game-over so the player can recover on the next day.

The first enemy archetype and its tuning are provisional. Multiple enemy families, bosses, and complex combat are deferred.

### Feature Group G — Local Save and Persistence

| ID | Requirement | Priority |
|---|---|---|
| SAVE-001 | The game can serialize the required vertical-slice state locally | P0 |
| SAVE-002 | Save data contains an explicit schema version | P0 |
| SAVE-003 | The game validates required fields and supported schema versions on load | P0 |
| SAVE-004 | Save writes use a temporary file and preserve a previous valid backup | P0 |
| SAVE-005 | The game can recover from a corrupt primary save when a valid backup exists | P0 |

Acceptance:
- A save/load round trip preserves resource balances, day/time, buildings, NPC persistent state, island ID, and required progression flags.
- Unsupported or malformed save data is rejected safely.
- A failed write does not destroy the previous valid save.
- Recovery from backup is reported.
- Transient visual nodes, animation frames, and particles are not serialized as authoritative game state.

### Feature Group H — Minimal User Experience

| ID | Requirement | Priority |
|---|---|---|
| UX-001 | The player can start a new local game | P0 |
| UX-002 | The player can see the resource balances needed for the slice | P0 |
| UX-003 | The player can identify the current day/night phase | P0 |
| UX-004 | Important interaction and construction feedback is understandable | P0 |

Acceptance:
- Essential information is readable.
- HUD values reflect authoritative gameplay state.
- The slice can be played without a multiplayer lobby, quest log, or complex menu system.
- Placeholder UI is acceptable during early validation.

## 3.4 P1 — Later Milestones

P1 features are not part of the first vertical slice acceptance criteria.

### Multiplayer Prototype (M9)

| ID | Requirement | Priority |
|---|---|---|
| MP-001 | Create and join a test online session | P1 |
| MP-002 | Support up to four connected players in the target design | P1 |
| MP-003 | Spawn and synchronize player characters | P1 |
| MP-004 | Give each player an independent local camera | P1 |
| MP-005 | Keep kingdom economy and world-changing actions host-authoritative | P1 |
| MP-006 | Synchronize building, NPC, and enemy state | P1 |
| MP-007 | Handle disconnects and session failures safely | P1 |

Multiplayer acceptance begins with a two-peer external test. Four-player capacity is a later validation target, not an assumption that networking will work without further design and testing.

### Initial Content Expansion (M10)

Potential P1 content, subject to post-slice validation:
- Additional buildings and upgrades.
- Additional NPC roles such as Farmer and Archer.
- Additional enemy variants.
- More exploration points and island content.
- A larger first narrative chapter.
- Improved presentation and usability.

Each feature must be separately prioritized before entering an implementation milestone.

## 3.5 P2 — Future Vision

Possible future features, not current commitments:
- Multiple fully developed islands.
- Independent simulation of inactive islands.
- Knight/Guard roles and mounted combat.
- Additional mounts and special abilities.
- Weather and advanced environmental events.
- Complex trading and crafting.
- Branching storylines and multiple campaigns.
- Procedural world generation.
- Dedicated servers, relay services, host migration, and public matchmaking.
- Cross-platform and console support.

---

## 3.6 Approved P0 Design & Balance Decisions (`OD-01` to `OD-10`)

All P0 balancing and interaction decisions are resolved and documented in [`docs/DECISIONS_M2_M8.md`](DECISIONS_M2_M8.md):

| Decision | Approved P0 Specification |
|---|---|
| Resource sources & collection (`OD-01`) | 4 single-use caches on Forgotten Shore (`[E]` within `72 px`) |
| Starting balances & recruitment (`OD-02`) | Start `2G, 2W, 1S`; recruit Villager at Camp (`x=-220`) for `2G` |
| Stone purpose & Wall rules (`OD-03`, `OD-04`) | East plot `x=360`; build cost `2G, 4W, 2S` (`4.0s`, `150 HP`); repair `2W, 1S` |
| Builder data model (`OD-05`) | Persistent `NPCBuilderAgent` (`id="npc_01"`, `role: "villager" -> "builder"`) |
| First-night enemy tuning (`OD-06`) | 3 Greedling Raider waves (`0s, 55s, 110s`), `45 HP`, `15 dmg/hit`, `15 thorn dmg/hit` |
| Breach outcome (`OD-07`) | Non-destructive `settlement_breached = true` at Town Center (`x=0.0`) |
| Exploration POI (`OD-08`) | Forgotten Shrine at `x=-780.0` granting `+3 Gold` |
| Save payload (`OD-09`, `OD-10`) | `schema_version: 1` JSON with multi-plot `buildings[]`, `npcs[]`, and `night_encounter` on Godot `4.7.2.stable` |

# 4. USER STORIES AND ACCEPTANCE

## 4.1 Movement and Exploration

As a player, I want to move across Forgotten Shore so that I can reach resources, settlement locations, and points of interest.

Acceptance:
- Left/right movement works.
- Collision and boundaries behave consistently.
- The local camera follows the player.
- At least one exploration route or point of interest is present in the slice.
- Exploration content does not require a quest framework to function.

## 4.2 Resource Collection

As a player, I want to collect Gold, Wood, and Stone so that I can make kingdom-development decisions.

Acceptance:
- Each resource has a defined source and interaction in the first slice.
- Collection changes the kingdom ledger only after validation.
- The HUD reflects the committed balance.
- Repeated interaction cannot duplicate a single-use resource reward.

Approved resource sources (`OD-01`, `OD-02`, `OD-03`): Player starts with `2G, 2W, 1S` and collects 4 deterministic caches (`cache_gold_west` `+4G`, `timber_pile_west` `+5W`, `stone_outcrop_east` `+3S`, `shrine_cache_far_west` `+3G`) via `[E]` within `72 px`.

## 4.3 Recruitment and Construction

As a player, I want to recruit a Villager and build a Wooden Wall so that I can prepare the settlement for nighttime threats.

Acceptance:
- Recruitment has a clear cost and result.
- Construction location and cost are validated.
- The Builder can acquire and complete a valid construction task.
- The player receives clear feedback when an action is rejected.

## 4.4 First-Night Survival

As a player, I want to prepare before sunset so that my construction and Builder decisions affect whether the settlement survives the first night.

Acceptance:
- The phase transition is communicated.
- Builder safety behavior is observable.
- The enemy attacks the intended defense target.
- The encounter resolves at sunrise.
- The outcome is reflected in persistent kingdom state.

## 4.5 Save and Continue

As a player, I want the game to preserve my kingdom so that I can continue after closing the game.

Acceptance:
- Required state is saved in a versioned format.
- Valid data can be loaded.
- Corrupt primary data does not overwrite or destroy a valid backup.
- The game communicates when recovery is used or loading fails.

---

# 5. USER EXPERIENCE REQUIREMENTS

## 5.1 First-Time Experience

The first slice should introduce the following in a natural order:

1. Movement and camera.
2. Interaction with the world.
3. Resource collection.
4. Villager recruitment.
5. Wooden Wall placement and construction.
6. Builder task behavior.
7. Sunset warning and preparation.
8. First-night encounter.
9. Sunrise and save result.

Tutorial guidance should be contextual and minimal. A full quest/dialogue system is not required.

## 5.2 Menus

P0 menu scope:
- Start New Game.
- Continue, when a valid save exists.
- Basic Settings only if needed for controls/audio.
- Exit Game.

Deferred:
- Multiplayer lobby.
- Room code UI.
- Player invite flow.
- Ready states and online session browser.

## 5.3 HUD

P0 HUD should display:
- Gold, Wood, and Stone balances.
- Current day.
- Current time phase or a clear phase indicator.
- Contextual interaction/construction feedback.

Deferred:
- Quest tracker.
- Multiplayer player list.
- Network status.
- Advanced inventory.
- Detailed NPC management panels.

The HUD must remain readable and must not become the source of truth for gameplay data.

---

# 6. NON-FUNCTIONAL REQUIREMENTS

## 6.1 Performance

Initial development targets:

| Requirement | Target |
|---|---|
| Platform | Windows 10/11 64-bit |
| Base resolution | 1280×720 |
| Frame rate | Target 60 FPS on selected test hardware |
| Players in first slice | 1 local player |
| NPC count | Only the small number required by the slice |
| Enemy count | One basic enemy archetype for the first encounter |

Performance targets must be measured in the actual build. Do not optimize for speculative NPC/player counts before profiling.

## 6.2 Reliability

- No known critical crash during the tested vertical-slice flow.
- Failed economy transactions do not mutate balances.
- Invalid construction requests do not consume resources.
- Invalid NPC tasks are released safely.
- Save writes preserve the last known valid save.
- Invalid save data is rejected or recovered from backup when possible.

## 6.3 Usability and Accessibility

- Controls are easy to understand and documented.
- Essential HUD information is readable at the target resolution.
- Important state changes have clear visual or audio feedback.
- Visual effects must not obscure critical gameplay information.
- Input remapping and broader accessibility options may be considered after the core loop is validated.

## 6.4 Compatibility

Initial target:
- Windows 10/11 64-bit.
- Godot 4 stable release, with the exact engine version recorded when the project is initialized.

Other operating systems and platforms are future scope.

## 6.5 Technical and Data Integrity

- Gameplay state is not owned by presentation nodes.
- State changes pass through validated gameplay services/commands.
- Persistent objects use stable IDs.
- Save data has an explicit schema version.
- Future multiplayer seams must not introduce networking dependencies into P0.

---

# 7. OUT OF SCOPE FOR THE FIRST VERTICAL SLICE

The following must not be added to P0 unless a documented change is approved:

- Online multiplayer, ENet, RPCs, lobbies, room codes, relay services.
- NetworkManager implementation or networking Autoload.
- More than one playable island.
- Background simulation of inactive islands.
- Multiple enemy families, bosses, or complex combat.
- Farmer, Archer, Knight, Guard, or mount systems.
- Full quest, dialogue, branching narrative, or chapter framework.
- Complex crafting, trading, personal inventory, or equipment systems.
- Procedural world generation.
- Weather simulation and advanced environmental systems.
- Dedicated servers, matchmaking, host migration, or cross-platform support.

The long-term vision is not cancelled by this exclusion. It is deliberately separated from the first proof of the core gameplay loop.

---

# 8. DEVELOPMENT MILESTONES

Milestones are sequential gates, not calendar promises.

| Milestone | Scope | Exit condition | Priority |
|---|---|---|---|
| M0 — Godot Foundation | Project configuration, main scene, input, basic world | Project opens and runs without errors | P0 |
| M1 — Player Prototype | Movement, collision, placeholder animation, camera | Movement is reliable in a test area | P0 |
| M2 — World Clock | Forgotten Shore blockout, boundaries, day/night | Phase changes are deterministic | P0 |
| M3 — Economy | Gold/Wood/Stone ledger, collection, spending | Economy acceptance tests pass | P0 |
| M4 — Building | Wooden Wall placement and construction | Valid construction loop works | P0 |
| M5 — NPC | Recruit Villager, Builder task behavior, safety | Builder behavior is predictable | P0 |
| M6 — First Night | One enemy, wall defense, sunrise | First-night loop is playable | P0 |
| M7 — Save/Load | Versioned atomic local save | Round-trip and recovery tests pass | P0 |
| M8 — Vertical Slice Polish | Feedback, tuning, bug fixing | A fresh tester can complete the slice | P0 |
| M9 — Multiplayer Prototype | ENet, host authority, replication | Two-peer external test works | P1 |
| M10 — Content Expansion | More buildings, roles, enemies, exploration/story content | Added content does not destabilize the core loop | P1 |

## 8.1 Milestone Acceptance

A milestone is complete only when:
- Its agreed requirements are implemented.
- Acceptance criteria pass.
- Relevant automated or repeatable tests have been run.
- Runtime behavior is checked in the actual Godot project when appropriate.
- No known critical regression remains.
- Documentation is updated.
- Changes are committed with a focused commit message.

A generated script, a static code review, or an opened project folder is not proof that a gameplay feature works at runtime.

---

# 9. SUCCESS CRITERIA

## 9.1 Vertical-Slice Success

The first vertical slice is successful when a fresh tester can:

1. Start a local game on Forgotten Shore.
2. Understand movement and interaction.
3. Collect and spend the three core resources.
4. Recruit a Villager.
5. Fund and construct a Wooden Wall through Builder behavior.
6. Understand the approach of sunset.
7. Observe the wall and Builder affecting the first-night encounter.
8. Reach sunrise.
9. Save and reload the resulting kingdom state.

The loop should communicate a clear relationship between daytime decisions and nighttime consequences.

## 9.2 Internal Quality Targets

These are proposed internal targets for playtesting, not commercial guarantees:

| Metric | Target |
|---|---|
| First complete slice session | Approximately 10–15 minutes, subject to tuning |
| Core-slice acceptance criteria | 100% pass before declaring M8 complete |
| Known critical gameplay bugs | 0 at M8 sign-off |
| Save/load test cases | 100% of defined required cases pass |
| Performance | Target 60 FPS on selected test hardware, verified by profiling |

Qualitative playtest questions:
- Is the core loop understandable without extensive instructions?
- Does gathering lead to meaningful choices?
- Does construction feel useful and rewarding?
- Is Builder behavior predictable?
- Does sunset create enough preparation pressure?
- Does the first-night outcome feel connected to player decisions?
- Does exploration give the player a reason to move beyond the starting point?

---

# 10. RISKS AND MITIGATION

| Risk | Impact | Mitigation |
|---|---|---|
| Scope expansion | High | Keep P0 limited to the first vertical slice; approve changes explicitly |
| Solo development capacity | High | Build sequential milestones and validate one loop at a time |
| AI-generated code errors | High | Review generated changes and run tests/runtime checks |
| Economy exploits or state corruption | High | Centralize transactions and test invariants |
| NPC task complexity | Medium | Start with one Builder behavior and explicit task states |
| Save corruption | High | Versioned schema, temporary write, backup, recovery tests |
| Art production overhead | Medium | Use placeholders until mechanics are validated |
| Multiplayer complexity | High | Defer networking until M9 and test with two peers first |
| Unclear gameplay rules | High | Resolve GDD/SYSTEMS decisions before implementing affected features |
| Performance uncertainty | Medium | Profile actual builds before setting larger entity-count targets |

---

# 11. RELEASE AND VALIDATION STRATEGY

## Stage 1 — Internal Prototype (M0–M5)

Audience:
- Developer.
- Local testing.

Purpose:
- Validate project foundation, movement, world clock, economy, building, and NPC behavior.

## Stage 2 — First-Night Validation (M6–M7)

Audience:
- Developer and invited local testers.

Purpose:
- Validate preparation/survival loop.
- Validate save/load and recovery.
- Identify major usability and balance problems.

## Stage 3 — Vertical-Slice Playtest (M8)

Audience:
- Small invited group.

Purpose:
- Observe whether a fresh player can complete the loop.
- Collect qualitative feedback.
- Fix critical issues before expanding scope.

## Stage 4 — Multiplayer Prototype (M9, conditional)

Audience:
- Developer and invited network testers.

Purpose:
- Validate session connection, authority, synchronization, disconnect handling, and two-peer gameplay.

This stage begins only after the single-player slice is stable enough to justify networking work.

## Stage 5 — Content Expansion (M10, conditional)

Purpose:
- Add selected content based on vertical-slice feedback.
- Revalidate the core loop after each significant system addition.

Public release timing and distribution strategy will be decided after playtesting and feasibility review.

---

# 12. PRODUCT CHANGE MANAGEMENT

Any proposed change to the approved scope must include:

1. Feature description.
2. Player benefit and relationship to the product pillars.
3. Priority (P0/P1/P2).
4. Dependencies.
5. Technical and content impact.
6. Development and testing impact.
7. Effect on the current milestone and scope.

Rules:
- A new feature does not become P0 merely because it is desirable.
- Changes to gameplay rules update GDD and/or SYSTEMS.
- Changes to architecture update TDD.
- Changes to product scope, priorities, or acceptance criteria update this PRD.
- Changes to art production standards update ASSET_GUIDELINES.
- Approved decisions with lasting architectural or product consequences should be recorded as ADRs when the ADR structure is introduced.
- If documents conflict, the Revised Project Baseline v1.3 (`docs/DECISIONS_M2_M8.md`) governs the decisions it explicitly defines until all documents are synchronized.

---

# 13. FINAL PRODUCT DEFINITION

## 13.1 First Vertical Slice

The first CROWNFALL playable vertical slice is a single-player 2D side-scrolling kingdom-building and survival experience on Forgotten Shore.

The player moves through the island, gathers Gold/Wood/Stone, recruits a Villager, constructs a Wooden Wall with Builder behavior, prepares for one basic nighttime threat, reaches sunrise, and preserves the resulting state through local save/load.

The slice proves the relationship between exploration, resource decisions, construction, and survival.

## 13.2 Long-Term Product

The long-term CROWNFALL vision expands this foundation into a larger medieval fantasy adventure across multiple islands, with deeper kingdom systems, additional NPC roles and threats, environmental storytelling, and online cooperative play for up to four players.

These long-term goals must be validated and prioritized incrementally. They are not implied commitments for the first vertical slice.

---

**END OF PRD**

Project: CROWNFALL: THE LAST LIGHT  
Document: PRD.md  
Version: 1.3


---

> **v1.3 Synchronization Note:** All P0 vertical-slice open decisions (`OD-01` through `OD-10`) referenced in this document have been formally resolved and approved in [`docs/DECISIONS_M2_M8.md`](DECISIONS_M2_M8.md).
