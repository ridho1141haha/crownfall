# CROWNFALL: THE LAST LIGHT
# PRODUCT REQUIREMENTS DOCUMENT (PRD)

**Document Version:** 1.0  
**Product:** CROWNFALL: THE LAST LIGHT  
**Platform:** Windows PC  
**Engine:** Godot 4  
**Product Stage:** Pre-production  
**Development Model:** Solo Developer + AI Assistance

---

# 1. PRODUCT VISION

## 1.1 Vision Statement

CROWNFALL: THE LAST LIGHT aims to create an atmospheric medieval fantasy adventure where players collaboratively rebuild a fallen civilization, explore mysterious islands, and survive the growing darkness.

The product combines accessible side-scrolling gameplay with meaningful kingdom management, exploration, survival, and cooperative storytelling.

## 1.2 Product Goals

1. Deliver an enjoyable kingdom-building experience.
2. Provide meaningful exploration and island progression.
3. Create challenging but fair survival gameplay.
4. Support online cooperative play for up to four players.
5. Establish a distinctive cinematic pixel-art identity.
6. Deliver an engaging first story chapter.
7. Build a scalable foundation for future content.

## 1.3 Target Audience

Primary audience:
- Players interested in 2D indie games.
- Fans of kingdom-building mechanics.
- Fans of atmospheric pixel-art adventures.
- Players who enjoy cooperative survival.
- Players who enjoy environmental storytelling.

Secondary audience:
- Casual exploration players.
- Strategy and resource management enthusiasts.
- Medieval fantasy fans.

---

# 2. PRODUCT POSITIONING

## 2.1 Reference Products

| Game | Inspiration |
|---|---|
| Kingdom: New Lands | Minimalist kingdom management |
| Kingdom Two Crowns | Cooperative side-scrolling gameplay |
| Stardew Valley | Progression and world interaction |
| Eastward | Atmospheric pixel-art presentation |
| To the Moon | Narrative-focused storytelling |

These products serve as design references only.

CROWNFALL must maintain its own original characters, setting, assets, mechanics, and story.

## 2.2 Unique Value Proposition

**Build a kingdom together, explore forgotten islands, and uncover the last light of a dying world.**

Key differentiators:
- Independent player cameras.
- Shared cooperative kingdom.
- Separate island progression.
- Narrative-driven exploration.
- Minimal direct combat.
- Atmospheric environmental storytelling.

---

# 3. PRODUCT SCOPE

## 3.1 Initial Product

The first playable product is a cooperative survival and kingdom-building prototype featuring one complete island.

It must demonstrate the core gameplay loop before expanding into additional content.

## 3.2 MVP Features

### Feature Group A — Core Gameplay

| ID | Requirement | Priority |
|---|---|---|
| CORE-001 | Horizontal player movement | P0 |
| CORE-002 | Idle and walking animations | P0 |
| CORE-003 | Independent player camera | P0 |
| CORE-004 | Interaction system | P0 |
| CORE-005 | Basic player states | P0 |

### Feature Group B — World

| ID | Requirement | Priority |
|---|---|---|
| WORLD-001 | Forgotten Shore island | P0 |
| WORLD-002 | Side-scrolling terrain | P0 |
| WORLD-003 | Environment objects | P0 |
| WORLD-004 | Island boundaries | P0 |
| WORLD-005 | Day/night cycle | P0 |
| WORLD-006 | World state persistence | P0 |

### Feature Group C — Economy

| ID | Requirement | Priority |
|---|---|---|
| ECO-001 | Gold currency | P0 |
| ECO-002 | Wood resource | P0 |
| ECO-003 | Stone resource | P0 |
| ECO-004 | Resource collection | P0 |
| ECO-005 | Resource spending | P0 |
| ECO-006 | Shared multiplayer treasury | P0 |

### Feature Group D — Kingdom Building

| ID | Requirement | Priority |
|---|---|---|
| BUILD-001 | Town Center | P0 |
| BUILD-002 | Wooden Wall | P0 |
| BUILD-003 | Watchtower | P0 |
| BUILD-004 | Farm | P0 |
| BUILD-005 | Workshop | P0 |
| BUILD-006 | Storage | P0 |
| BUILD-007 | Construction progress | P0 |
| BUILD-008 | Building upgrades | P0 |

### Feature Group E — NPC

| ID | Requirement | Priority |
|---|---|---|
| NPC-001 | Villager recruitment | P0 |
| NPC-002 | Villager movement | P0 |
| NPC-003 | Job assignment | P0 |
| NPC-004 | Farmer role | P0 |
| NPC-005 | Archer role | P0 |
| NPC-006 | NPC survival behavior | P0 |

### Feature Group F — Survival

| ID | Requirement | Priority |
|---|---|---|
| SUR-001 | Day/night cycle | P0 |
| SUR-002 | Enemy spawning | P0 |
| SUR-003 | Greedling | P0 |
| SUR-004 | Crawler | P0 |
| SUR-005 | Brute | P0 |
| SUR-006 | Defensive structures | P0 |
| SUR-007 | Enemy attack behavior | P0 |
| SUR-008 | Night survival event | P0 |

### Feature Group G — Multiplayer

| ID | Requirement | Priority |
|---|---|---|
| MP-001 | Create online session | P0 |
| MP-002 | Join online session | P0 |
| MP-003 | Maximum four players | P0 |
| MP-004 | Player spawning | P0 |
| MP-005 | Player synchronization | P0 |
| MP-006 | Independent cameras | P0 |
| MP-007 | Shared economy | P0 |
| MP-008 | Shared building state | P0 |
| MP-009 | NPC synchronization | P0 |
| MP-010 | Enemy synchronization | P0 |
| MP-011 | Disconnect handling | P0 |

### Feature Group H — Narrative

| ID | Requirement | Priority |
|---|---|---|
| STORY-001 | Dialogue system | P0 |
| STORY-002 | Quest system | P0 |
| STORY-003 | Shared quest progression | P0 |
| STORY-004 | First chapter | P0 |
| STORY-005 | Environmental storytelling | P0 |

### Feature Group I — Persistence

| ID | Requirement | Priority |
|---|---|---|
| SAVE-001 | Save player progression | P0 |
| SAVE-002 | Save kingdom state | P0 |
| SAVE-003 | Save economy | P0 |
| SAVE-004 | Save building states | P0 |
| SAVE-005 | Save NPC states | P0 |
| SAVE-006 | Save quest progression | P0 |
| SAVE-007 | Versioned save format | P0 |

---

# 4. USER STORIES

## 4.1 Player Movement

As a player, I want to move freely through the island so that I can explore and interact with the environment.

Acceptance criteria:
- Left and right movement work.
- Character animation reflects movement.
- Camera follows the local player.
- Movement respects world boundaries.

## 4.2 Kingdom Building

As a player, I want to construct defensive structures so that I can protect my settlement.

Acceptance criteria:
- Building costs are displayed.
- Insufficient resources prevent construction.
- Valid construction creates a building.
- Other players see the same building.

## 4.3 Resource Management

As a player, I want to gather and spend resources so that I can develop my kingdom.

Acceptance criteria:
- Resource counts update correctly.
- Transactions are validated.
- Shared inventory is consistent.
- Duplicate transactions are rejected.

## 4.4 Cooperative Play

As a player, I want to invite friends into my kingdom so that we can develop and protect it together.

Acceptance criteria:
- Host can create a session.
- Client can connect.
- Player characters spawn correctly.
- Each player has an independent camera.
- Shared world changes synchronize.

## 4.5 Survival

As a player, I want to prepare for nighttime attacks so that my kingdom can survive.

Acceptance criteria:
- Nighttime starts at the correct time.
- Enemies spawn through host authority.
- Defenses interact with enemies.
- All clients see consistent battle states.

## 4.6 Exploration

As a player, I want to discover hidden locations and story elements so that exploration feels rewarding.

Acceptance criteria:
- Locations have discoverable elements.
- Exploration can trigger quests.
- Story progression is shared.
- Discovered progress is saved.

---

# 5. USER EXPERIENCE REQUIREMENTS

## 5.1 First-Time Experience

The first-time player experience must introduce:

1. Basic movement.
2. Interaction.
3. Resource collection.
4. First construction.
5. NPC recruitment.
6. Nighttime preparation.
7. First survival encounter.

Tutorials should be contextual and unobtrusive.

## 5.2 Main Menu Requirements

The main menu must provide:
- New Game.
- Continue.
- Multiplayer.
- Settings.
- Credits.
- Exit Game.

## 5.3 Multiplayer Lobby Requirements

The lobby must provide:
- Create Room.
- Join Room.
- Room Code.
- Connected Player List.
- Connection Status.
- Ready Status.
- Start Game.

## 5.4 HUD Requirements

Display:
- Gold.
- Available resources.
- Day number.
- Time phase.
- Current quest.
- Player status.

The HUD must not overwhelm the environment.

---

# 6. PRODUCT NON-FUNCTIONAL REQUIREMENTS

## 6.1 Performance

| Requirement | Target |
|---|---|
| FPS | 60 |
| Base Resolution | 1280×720 |
| Concurrent Players | 4 |
| NPC Count | 50–100 |
| Enemy Count | 20–40 |
| Network Tick | 20–30 Hz |

Targets must be validated through profiling.

## 6.2 Reliability

- No critical crash during normal gameplay.
- Save data must be validated.
- Failed transactions must not corrupt resources.
- Disconnections must be handled safely.
- Invalid multiplayer requests must be rejected.

## 6.3 Usability

- Controls must be easy to understand.
- Important information must be readable.
- Menus must provide clear navigation.
- Error messages must explain connection failures.
- Visual effects must not obscure gameplay.

## 6.4 Compatibility

Initial target:
- Windows 10/11 64-bit.

Additional platforms are future scope.

## 6.5 Security

- Host validates world-changing actions.
- Clients cannot modify authoritative resources.
- Network requests are validated.
- Save data is checked during loading.
- Session connections are managed safely.

---

# 7. PRODUCT PRIORITIZATION

Use the MoSCoW prioritization method.

## MUST HAVE

Required for MVP:
- Player movement.
- Camera.
- One island.
- Resource collection.
- Economy.
- Building.
- NPC recruitment.
- Day/night cycle.
- Enemy AI.
- Online multiplayer.
- Shared kingdom.
- First story chapter.
- Save/load.

## SHOULD HAVE

Important after core MVP:
- More building upgrades.
- Better NPC behavior.
- Improved quest presentation.
- Mount system.
- Additional environmental events.
- Advanced visual effects.

## COULD HAVE

Optional future features:
- Multiple mount types.
- Weather system.
- Advanced trading.
- More enemy variants.
- Additional story branches.
- Special crown abilities.

## WON'T HAVE IN INITIAL MVP

Explicitly excluded:
- Dedicated servers.
- Public matchmaking.
- Host migration.
- PvP.
- Independent island simulation.
- Six fully developed islands.
- Procedural world generation.
- Multiple playable campaigns.
- Cross-platform multiplayer.
- Console support.

These features may be reconsidered after MVP validation.

---

# 8. MVP PRODUCT CONTENT

## 8.1 World

- One island: Forgotten Shore.
- One playable biome.
- One settlement.
- One exploration route.
- One ancient ruin.

## 8.2 Players

- 1–4 players.
- Two initial character variants.
- Independent cameras.
- Shared kingdom.

## 8.3 NPC

- Villager.
- Farmer.
- Archer.

## 8.4 Enemies

- Greedling.
- Crawler.
- Brute.

## 8.5 Buildings

- Town Center.
- Wooden Wall.
- Watchtower.
- Farm.
- Workshop.
- Storage.

## 8.6 Quests

1. The First Settlement.
2. Gather the Wood.
3. Raise the Walls.
4. The First Night.
5. Beyond the Shore.

## 8.7 Story

One complete introductory chapter.

---

# 9. DEVELOPMENT MILESTONES

| Milestone | Deliverable | Priority |
|---|---|---|
| M0 | Project Foundation | P0 |
| M1 | First Movement | P0 |
| M2 | First Island | P0 |
| M3 | First Kingdom | P0 |
| M4 | First Night | P0 |
| M5 | First Multiplayer | P0 |
| M6 | First Story Chapter | P0 |
| M7 | Save/Load | P0 |
| M8 | Playable MVP | P0 |
| M9 | Additional Content | P1 |
| M10 | Release Preparation | P1 |

## 9.1 Milestone Acceptance

A milestone is complete only when:
- Required features are implemented.
- Acceptance criteria pass.
- No known critical bugs remain.
- Project opens correctly.
- Runtime testing is performed.
- Documentation is updated.
- Changes are committed to Git.

---

# 10. MVP SUCCESS METRICS

The following are proposed internal playtesting targets, not guaranteed commercial performance metrics.

| Metric | Target |
|---|---|
| First playable session | 10–15 minutes |
| Cooperative capacity | 4 players |
| Successful session join | At least 95% in controlled testing |
| Critical gameplay bugs | 0 known |
| Save/load validation | 100% of test cases |
| Core gameplay completion | 100% of MVP acceptance criteria |
| Frame rate | Target 60 FPS on selected test hardware |

Additional qualitative feedback:
- Does building feel rewarding?
- Is nighttime sufficiently tense?
- Is resource management understandable?
- Does cooperation improve the experience?
- Is exploration interesting?
- Is the first chapter satisfying?

---

# 11. RISKS AND MITIGATION

| Risk | Impact | Mitigation |
|---|---|---|
| Scope expansion | High | Strict MVP |
| Multiplayer complexity | High | Host-authoritative architecture |
| Camera synchronization | Medium | Local camera ownership |
| NPC performance | Medium | AI update intervals |
| Save corruption | High | Versioned save and backups |
| Pixel art inconsistency | Medium | Asset guidelines |
| AI-generated code errors | High | Runtime testing |
| Network connectivity | High | Early external connection tests |
| Insufficient testing | High | Milestone acceptance criteria |

---

# 12. RELEASE STRATEGY

## Stage 1 — Internal Prototype

Audience:
- Developer.
- Local testing.

Purpose:
- Verify movement.
- Verify world.
- Verify building.
- Verify survival.

## Stage 2 — Multiplayer Prototype

Audience:
- Developer and invited testers.

Purpose:
- Verify online connectivity.
- Verify synchronization.
- Test cooperative gameplay.
- Test disconnect scenarios.

## Stage 3 — Closed Playtest

Audience:
- Small group of external players.

Purpose:
- Evaluate gameplay balance.
- Evaluate user experience.
- Find multiplayer bugs.
- Collect feedback.

## Stage 4 — MVP Candidate

Requirements:
- All MVP features implemented.
- Core acceptance criteria passed.
- Save/load stable.
- Multiplayer playable.
- Windows build tested.

Public release timing will be decided after playtesting.

---

# 13. PRODUCT CHANGE MANAGEMENT

Any new feature request must include:

1. Feature description.
2. User benefit.
3. Priority.
4. Technical impact.
5. Dependencies.
6. Development estimate.
7. Testing requirements.
8. Scope impact.

Changes affecting the approved architecture must also update the TDD.

Changes affecting gameplay rules must update the GDD or SYSTEMS.md.

Changes affecting product scope must update the PRD.

---

# 14. FINAL PRODUCT DEFINITION

CROWNFALL: THE LAST LIGHT MVP is a playable online cooperative medieval fantasy experience in which up to four players can:

- Explore Forgotten Shore.
- Gather shared resources.
- Develop a kingdom.
- Recruit villagers.
- Construct defensive buildings.
- Survive nighttime attacks.
- Complete the introductory story chapter.
- Save and restore their progression.

The MVP must demonstrate that the central gameplay loop is enjoyable before expanding the game into a larger world.

---

# 15. PRODUCT SUCCESS DEFINITION

The product is successful at the MVP stage when players can experience a complete gameplay cycle, cooperate meaningfully, make kingdom management decisions, survive environmental threats, and feel motivated to explore the next island.

The product must be technically stable enough to support future development without requiring a complete architectural rewrite.

---

**END OF PRD**

Project: CROWNFALL: THE LAST LIGHT  
Document: PRD.md  
Version: 1.0