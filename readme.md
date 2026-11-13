# CROWNFALL: THE LAST LIGHT

<p align="center">
  <strong>A Medieval Fantasy Pixel-Art Kingdom Adventure</strong>
</p>

<p align="center">
  <em>Build your kingdom. Explore the unknown. Survive the darkness. Together.</em>
</p>

---

## About The Game

**CROWNFALL: THE LAST LIGHT** is a 2D pixel-art medieval fantasy adventure game inspired by the atmosphere, side-scrolling exploration, and kingdom-building mechanics of *Kingdom: New Lands* and *Kingdom Two Crowns*.

The game combines three main gameplay pillars:

- **Kingdom Building:** Establish settlements, construct buildings, manage resources, and expand your kingdom.
- **Exploration:** Discover mysterious islands, ancient ruins, hidden treasures, and forgotten civilizations.
- **Survival:** Protect your kingdom from mysterious creatures that emerge after sunset.

The game is designed around online cooperative multiplayer, allowing players to explore and build a shared kingdom together.

The ultimate goal is to create an original experience with atmospheric storytelling, cinematic pixel art, meaningful exploration, and cooperative survival.

---

## Project Information

| Category | Specification |
|---|---|
| Project Name | CROWNFALL: THE LAST LIGHT |
| Genre | Survival, Kingdom Building, Exploration, Adventure |
| Engine | Godot 4 |
| Programming Language | GDScript |
| Rendering | 2D |
| Art Style | Detailed Cinematic Pixel Art |
| Camera | Side-scrolling, independent player cameras |
| World Structure | Separate Islands |
| Multiplayer | Online Cooperative |
| Player Count | 1–4 Players |
| Networking | Host-authoritative |
| Development Team | Solo Developer + AI Assistance |
| Initial Platform | Windows PC |
| Target Framerate | 60 FPS |
| Base Resolution | 1280 × 720 |

## Core Design Philosophy

### 1. Build a Kingdom

Players establish and expand their own kingdom through:

- Constructing walls and defensive structures.
- Developing villages and settlements.
- Managing gold and resources.
- Recruiting villagers.
- Upgrading buildings.
- Establishing economic infrastructure.

### 2. Explore the Unknown

The world consists of multiple separate islands, each containing unique environments, resources, and mysteries.

Players can discover:

- Ancient ruins.
- Forgotten settlements.
- Hidden caves.
- Special resources.
- Legendary artifacts.
- New characters and quests.

### 3. Survive Together

Survival is based on preparation, resource management, and cooperation rather than direct combat.

Players must:

- Prepare defenses before sunset.
- Protect villagers.
- Manage kingdom resources.
- Respond to enemy attacks.
- Cooperate during dangerous events.

---

# Story & World

## The World of Aetherion

Aetherion was once a prosperous world protected by an ancient source of energy known as **The First Light**.

For centuries, this mysterious light maintained the balance between the human world and the realm of darkness.

However, an event known as **The Great Eclipse** caused the source of light to disappear.

Kingdoms collapsed, civilizations vanished, and mysterious creatures began spreading across the land.

Players take the role of the last descendants of the ancient guardians of light.

Through an ancient crown, they gain the ability to rebuild civilization and uncover the truth behind The Great Eclipse.

## Main Story Chapters

| Chapter | Title | Description |
|---|---|---|
| I | The Forgotten Shore | Establish the first settlement |
| II | The Lost Kingdom | Discover the ruins of an ancient kingdom |
| III | Beyond the Forest | Explore new regions and civilizations |
| IV | The Hollow Crown | Discover the secrets of the ancient crown |
| V | The Last Light | Determine the future of Aetherion |

Storytelling will use environmental storytelling, NPC dialogue, ancient inscriptions, hidden journals, and world events.

---

# World Design

The game uses a side-scrolling world structure with multiple separate islands.

## Planned Biomes

| Island | Environment | Resources |
|---|---|---|
| Forgotten Shore | Forest, beach, abandoned settlement | Wood, Stone, Gold |
| Eldergrove Forest | Dense forest and ancient ruins | Wood, Herbs, Food |
| Frostveil Highlands | Snowy mountains | Iron, Crystal |
| Ashen Wastes | Volcanic and ruined lands | Ancient Relics |
| The Hollow Depths | Underground caves | Rare Minerals |
| Crownlands | Former royal capital | Legendary Materials |

### World Progression

Players unlock new islands by:

1. Developing their current kingdom.
2. Gathering required resources.
3. Discovering ancient relics.
4. Completing story objectives.
5. Unlocking transportation routes.

### Island Architecture

Each island contains its own:

- Unique ID.
- Biome definition.
- Terrain.
- Resource nodes.
- NPC population.
- Building states.
- Enemy spawn points.
- Quest progression.
- World events.
- Save data.

For the initial MVP, all players must travel to the same island together.

Independent island simulation will be considered for a later development phase.

---

# Gameplay Systems

## Core Gameplay Loop

```text
EXPLORE
   |
   v
COLLECT RESOURCES
   |
   v
BUILD KINGDOM
   |
   v
RECRUIT VILLAGERS
   |
   v
DEVELOP ECONOMY
   |
   v
PREPARE DEFENSES
   |
   v
SURVIVE THE NIGHT
   |
   v
EXPAND AND DISCOVER
```

## Kingdom Building

Planned building categories:

### Defensive Structures
- Wooden Wall
- Stone Wall
- Watchtower
- Defensive Gate

### Economic Structures
- Houses
- Market
- Blacksmith
- Storage

### Food Production
- Farm
- Fishing Dock
- Hunting Camp
- Mill

### Special Structures
- Shrine
- Library
- Barracks
- Ancient Altar

Each building will have construction costs, upgrade levels, construction duration, and specific functionality.

## Economy System

| Resource | Function |
|---|---|
| Gold | Primary currency |
| Wood | Basic construction |
| Stone | Building upgrades |
| Iron | Advanced technology and defense |
| Food | Population needs |
| Crystal | Ancient technology and story progression |

Resource sources include farming, hunting, fishing, trading, treasure chests, and quest rewards.

All economy transactions must be validated by the multiplayer host.

## Survival System

The game uses a shared world simulation clock.

| Time | Gameplay |
|---|---|
| Morning | Villagers begin working |
| Afternoon | Exploration and construction |
| Evening | Defense preparation |
| Night | Enemy attacks |

Initial time configuration:

- Full in-game day: 12 minutes.
- Daylight: 8 minutes.
- Sunset: 1 minute.
- Night: 3 minutes.

These values are initial balancing targets and may change during testing.

## Enemy Types

| Enemy | Behavior |
|---|---|
| Greedling | Attempts to steal coins |
| Crawler | Fast enemy targeting villagers |
| Brute | Heavy enemy attacking defensive structures |
| Night Herald | Special event-based enemy |

Combat should emphasize defensive preparation, strategic positioning, and cooperation.

---

# Multiplayer Architecture

## Online Cooperative Mode

CROWNFALL supports 1–4 players in a shared kingdom.

### Multiplayer Features

- Create Room.
- Join Room.
- Private Room Code.
- Shared Kingdom.
- Shared Economy.
- Shared Inventory.
- Cooperative Building.
- Shared Quests.
- Player Synchronization.
- Reconnection Handling.
- Cooperative Survival.

## Player Specializations

Players can develop different responsibilities.

| Role | Focus |
|---|---|
| Monarch | Kingdom leadership and progression |
| Steward | Economy and construction |
| Warden | Defense and population protection |
| Seeker | Exploration and ancient discoveries |

These are gameplay specializations, not restrictive character classes.

## Networking Architecture

The project uses a host-authoritative networking model.

### Technical Components

- `ENetMultiplayerPeer`
- `MultiplayerAPI`
- `@rpc`
- `MultiplayerSynchronizer`
- `MultiplayerSpawner`

### Authority Rules

| System | Authority |
|---|---|
| Player Input | Local Client |
| Player Movement Result | Host |
| Economy Transactions | Host |
| Building Placement | Host |
| NPC AI | Host |
| Enemy AI | Host |
| Enemy Damage | Host |
| World Clock | Host |
| Quest Progression | Host |
| Island State | Host |
| Camera | Local Client |
| UI | Local Client |

### Camera Architecture

Each player has an independent local camera.

All players exist in the same shared world, but each client renders its own camera perspective.

No split-screen rendering is required.

The camera must follow the locally controlled player and respect island boundaries.

### Networking Limitations

The initial implementation uses host-based sessions.

Dedicated servers, cloud persistence, relay services, and host migration are outside the initial MVP scope.

If the host disconnects, the session should terminate safely and provide a recovery option using the latest available save.

---

# Technical Stack

| Component | Technology |
|---|---|
| Game Engine | Godot 4 |
| Programming | GDScript |
| Rendering | Godot 2D |
| Networking | ENet |
| Multiplayer API | Godot Multiplayer API |
| Animation | AnimatedSprite2D / AnimationPlayer |
| Tile System | TileMapLayer |
| Data Storage | Resource / JSON |
| Save System | Custom Save Serializer |
| Pixel Art | Aseprite |
| Version Control | Git |
| Repository Hosting | GitHub |

---

# Project Structure

```text
CROWNFALL/
│
├── project.godot
│
├── assets/
│   ├── characters/
│   │   ├── players/
│   │   ├── villagers/
│   │   └── animals/
│   │
│   ├── enemies/
│   ├── environment/
│   ├── buildings/
│   ├── items/
│   ├── mounts/
│   ├── effects/
│   ├── ui/
│   └── audio/
│
├── scenes/
│   ├── main/
│   ├── world/
│   │   ├── islands/
│   │   └── environment/
│   ├── player/
│   ├── npc/
│   ├── enemies/
│   ├── buildings/
│   ├── multiplayer/
│   └── ui/
│
├── scripts/
│   ├── core/
│   ├── player/
│   ├── world/
│   ├── kingdom/
│   ├── economy/
│   ├── npc/
│   ├── survival/
│   ├── networking/
│   ├── narrative/
│   ├── save/
│   └── ui/
│
├── resources/
│   ├── buildings/
│   ├── items/
│   ├── enemies/
│   ├── islands/
│   └── quests/
│
├── data/
│   ├── balance/
│   ├── localization/
│   └── world/
│
├── shaders/
│
├── tests/
│   ├── economy/
│   ├── networking/
│   ├── save/
│   └── gameplay/
│
└── docs/
    ├── GDD.md
    ├── TDD.md
    ├── SYSTEMS.md
    ├── ASSET_GUIDELINES.md
    └── CHANGELOG.md
```

## Autoload Managers

The following systems should be configured as Godot Autoloads:

| Singleton | Responsibility |
|---|---|
| GameManager | Game and session state |
| NetworkManager | Multiplayer connections |
| EventBus | Global event communication |
| SaveManager | Save and load |
| SceneManager | Scene transitions |
| AudioManager | Music and sound effects |

Other managers should belong to their respective game sessions or world scenes.

---

# Development Roadmap

Development will follow a milestone-based workflow.

## Phase 0 — Project Foundation

- [ ] Initialize Godot 4 project.
- [ ] Configure rendering settings.
- [ ] Create project folder structure.
- [ ] Create Main Menu.
- [ ] Create GameSession.
- [ ] Create WorldRoot.
- [ ] Implement GameManager.
- [ ] Implement EventBus.
- [ ] Initialize Git repository.

**Deliverable:** Functional project foundation.

## Phase 1 — Player & Camera

- [ ] Player scene.
- [ ] Character movement.
- [ ] Idle animation.
- [ ] Walking animation.
- [ ] Camera follow.
- [ ] Camera boundaries.
- [ ] Interaction system.

**Deliverable:** First Movement Prototype.

## Phase 2 — World & Island

- [ ] WorldRoot.
- [ ] IslandManager.
- [ ] Forgotten Shore.
- [ ] Terrain.
- [ ] Parallax background.
- [ ] Environment props.
- [ ] Island boundaries.
- [ ] Day/night clock.

**Deliverable:** First playable environment.

## Phase 3 — Economy & Building

- [ ] Gold system.
- [ ] Resource inventory.
- [ ] Collection mechanics.
- [ ] Building data.
- [ ] Building placement.
- [ ] Construction progress.
- [ ] Building upgrades.
- [ ] Economy HUD.

**Deliverable:** First functional kingdom.

## Phase 4 — NPC & Survival

- [ ] Villager spawning.
- [ ] NPC job assignment.
- [ ] NPC AI.
- [ ] Day/night cycle.
- [ ] Enemy spawning.
- [ ] Enemy AI.
- [ ] Defense mechanics.
- [ ] Night attack events.

**Deliverable:** Functional kingdom survival gameplay.

## Phase 5 — Multiplayer

- [ ] Create room.
- [ ] Join room.
- [ ] Player spawning.
- [ ] Player synchronization.
- [ ] Independent player cameras.
- [ ] Shared economy.
- [ ] Shared building.
- [ ] NPC synchronization.
- [ ] Enemy synchronization.
- [ ] Disconnect handling.

**Deliverable:** Playable online cooperative prototype.

## Phase 6 — Island Progression

- [ ] Island selection.
- [ ] Island unlocking.
- [ ] Travel system.
- [ ] Island persistence.
- [ ] Ship transportation.
- [ ] New biome support.

**Deliverable:** Multiple explorable islands.

## Phase 7 — Story & Content

- [ ] Dialogue system.
- [ ] Quest system.
- [ ] Story events.
- [ ] Ancient ruins.
- [ ] Special NPCs.
- [ ] First story chapter.
- [ ] Mini boss.

**Deliverable:** First playable story chapter.

## Phase 8 — Polish & Testing

- [ ] Final pixel art.
- [ ] Character animations.
- [ ] Sound effects.
- [ ] Music.
- [ ] Lighting and atmosphere.
- [ ] UI refinement.
- [ ] Performance optimization.
- [ ] Multiplayer stress testing.
- [ ] Save/load testing.
- [ ] Windows build.

**Deliverable:** MVP release candidate.

---

# Minimum Viable Product (MVP)

The first playable version must contain:

| Feature | MVP Target |
|---|---|
| Biomes | 1 |
| Players | 1–4 |
| Character Variants | 2 |
| NPC Types | 3 |
| Enemy Types | 3 |
| Building Types | 6 |
| Mounts | 1 |
| Resources | 3 + Gold |
| Day/Night Cycle | Yes |
| Quests | 5 |
| Story Chapters | 1 |
| Mini Boss | 1 |
| Save System | Functional |
| Multiplayer | Online Cooperative |

### MVP Completion Criteria

The MVP is considered complete when players can:

1. Create or join an online session.
2. Explore the Forgotten Shore.
3. Collect resources and gold.
4. Recruit villagers.
5. Construct and upgrade buildings.
6. Manage the kingdom economy.
7. Survive multiple nights.
8. Complete the first story chapter.
9. Save and restore their progress.

---

# Art Direction

The game aims for detailed cinematic pixel art inspired by the visual atmosphere of Kingdom.

### Visual Guidelines

- Detailed pixel-art environments.
- Consistent pixel density.
- Limited color palettes per biome.
- Atmospheric lighting.
- Dynamic day/night transitions.
- Multi-layer parallax backgrounds.
- Smooth character animations.
- Minimalist user interface.

### Environment Layers

1. Sky and atmosphere.
2. Distant mountains.
3. Background forests.
4. Gameplay environment.
5. Foreground details.

### Initial Rendering Settings

| Parameter | Target |
|---|---|
| Base Resolution | 1280 × 720 |
| Texture Filtering | Nearest |
| Target FPS | 60 |
| Tile Size | 16×16 or 32×32 |
| Character Sprite | 32–64 px initial target height |
| Animation | Approximately 8–12 FPS |

These values are production starting points and can be adjusted after visual and performance testing.

---

# Quality & Performance Standards

| Metric | Initial Target |
|---|---|
| Frame Rate | 60 FPS |
| Concurrent Players | 4 |
| Active NPCs | 50–100 |
| Active Enemies | 20–40 |
| Network Tick | 20–30 Hz |
| World Simulation | Host-authoritative |

Performance targets must be validated through profiling on actual target hardware.

### Development Rules

1. Keep scripts modular.
2. Separate game data from gameplay logic.
3. Avoid unnecessary hardcoded values.
4. Validate all authoritative multiplayer actions on the host.
5. Use unique IDs for persistent game objects.
6. Test each feature before integration.
7. Maintain project documentation.
8. Commit stable milestones to Git.
9. Never overwrite existing working systems without inspecting dependencies.
10. Prioritize a playable MVP over unnecessary features.

---

# AI-Assisted Development Workflow

CROWNFALL is developed by a solo developer with AI coding assistance.

The AI development workflow follows:

1. Architecture Planning.
2. Feature Specification.
3. Implementation.
4. Static Code Inspection.
5. Runtime Testing.
6. Integration.
7. Documentation Update.

Every development task must include:

- Objective.
- Technical requirements.
- Files to create or modify.
- Implementation details.
- Testing requirements.
- Expected deliverables.
- Known limitations.

AI agents must not implement future phases without explicit instruction.

---

# Current Development Status

**Project Status:** Pre-production / Initial Foundation

| Milestone | Status |
|---|---|
| Game Concept | Defined |
| Game Design Document | Defined |
| Technical Design Document | Defined |
| Engine Selection | Confirmed |
| Networking Architecture | Planned |
| Camera Architecture | Planned |
| World Architecture | Planned |
| Project Foundation | Pending |
| Player Prototype | Pending |
| First Kingdom | Pending |
| Multiplayer Prototype | Pending |
| MVP | Pending |

---

# First Development Task

## TASK 001 — Project Foundation & First Movement Prototype

The first implementation must include:

1. Godot 4 project initialization.
2. Clean project structure.
3. Main Menu.
4. GameSession.
5. WorldRoot.
6. Player scene.
7. Horizontal character movement.
8. Idle and walking states.
9. Independent local Camera2D.
10. Basic terrain and collision.
11. Pixel rendering configuration.
12. Main Menu to gameplay transition.

### Acceptance Criteria

- Project opens without parser errors.
- No missing scene or script references.
- Main Menu launches the game.
- Player can move left and right.
- Idle and walking animations work.
- Camera follows the local player.
- Pixel rendering is consistent.
- Project can be tested and run on Windows.

Do not implement the entire game in this task.

Complete Task 001, verify it, document the result, and only then proceed to the next milestone.

---

# Project Vision

CROWNFALL: THE LAST LIGHT aims to deliver a memorable medieval fantasy experience where players build kingdoms, explore forgotten islands, discover ancient mysteries, and survive the darkness together.

**A kingdom is not built by one crown alone.**

<p align="center">
  <strong>CROWNFALL: THE LAST LIGHT</strong><br/>
  <em>Build. Explore. Survive. Together.</em>
</p>

---

*Documentation Version: 1.0*  
*Project: CROWNFALL: THE LAST LIGHT*  
*Engine: Godot 4*  
*Document Type: Main Project README*