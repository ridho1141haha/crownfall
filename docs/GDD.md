# CROWNFALL: THE LAST LIGHT
# GAME DESIGN DOCUMENT (GDD)

**Document Version:** 1.0  
**Project Type:** 2D Pixel-Art Online Cooperative Adventure  
**Engine:** Godot 4  
**Platform:** Windows PC  
**Players:** 1–4  
**Status:** Pre-production

---

# 1. GAME OVERVIEW

## 1.1 Game Description

CROWNFALL: THE LAST LIGHT is a 2D side-scrolling medieval fantasy game combining kingdom building, exploration, survival, and narrative adventure.

Inspired by the atmospheric presentation and gameplay philosophy of Kingdom: New Lands and Kingdom Two Crowns, the game introduces an original world, story, characters, progression systems, and cooperative multiplayer experience.

Players control monarchs who travel across forgotten islands, establish settlements, gather resources, recruit villagers, construct defensive structures, and uncover the mystery behind an ancient catastrophe.

The world is shared between players, but each player has an independent camera.

## 1.2 Core Pillars

### Pillar 1: Kingdom Building
- Establish settlements.
- Construct and upgrade buildings.
- Manage gold and resources.
- Recruit villagers.
- Develop the economy.
- Expand defensive capabilities.

### Pillar 2: Exploration
- Discover separate islands.
- Explore forests, ruins, caves, and abandoned settlements.
- Find hidden treasures.
- Unlock ancient technologies.
- Discover environmental storytelling.

### Pillar 3: Cooperative Survival
- Prepare defenses before sunset.
- Protect villagers and structures.
- Manage shared resources.
- Survive enemy attacks.
- Coordinate activities with other players.

## 1.3 Design Principles

1. Simple controls, meaningful decisions.
2. Minimal direct combat.
3. Preparation is more important than reaction.
4. Exploration must reward curiosity.
5. The environment communicates the story.
6. Cooperative play must feel natural.
7. The world must feel alive.
8. UI should remain minimal.
9. Every resource should have a purpose.
10. Progression should feel earned.

---

# 2. GAME SPECIFICATIONS

| Category | Specification |
|---|---|
| Genre | Survival, Kingdom Building, Exploration |
| Perspective | 2D Side-scrolling |
| Art Style | Detailed Cinematic Pixel Art |
| Setting | Medieval Fantasy |
| Engine | Godot 4 |
| Language | GDScript |
| Players | 1–4 |
| Multiplayer | Online Co-op |
| Camera | Independent per player |
| World | Separate Islands |
| Target Platform | Windows PC |
| Target FPS | 60 |
| Base Resolution | 1280×720 |

---

# 3. STORY AND LORE

## 3.1 World: Aetherion

Aetherion was once a prosperous world protected by an ancient energy source called The First Light.

This source maintained the balance between the human world and the realm of darkness.

Civilizations flourished under its protection.

However, an event known as The Great Eclipse caused The First Light to disappear.

The kingdoms collapsed, settlements were abandoned, and creatures from the darkness began spreading across the islands.

Centuries later, the last descendants of the ancient guardians discovered a mysterious crown.

The crown possesses the ability to restore ancient structures and reconnect the world to The First Light.

Players become the new guardians of Aetherion.

## 3.2 Main Narrative

The story follows the restoration of civilization and the discovery of the true cause of The Great Eclipse.

The narrative should gradually reveal that the ancient crown is connected to the catastrophe itself.

The player must eventually decide the fate of the remaining kingdoms.

## 3.3 Story Chapters

| Chapter | Title | Main Objective |
|---|---|---|
| I | The Forgotten Shore | Establish the first settlement |
| II | The Lost Kingdom | Discover the ancient kingdom |
| III | Beyond the Forest | Explore new civilizations |
| IV | The Hollow Crown | Uncover the crown's origin |
| V | The Last Light | Determine Aetherion's future |

Only Chapter I is included in the initial MVP.

## 3.4 Storytelling Methods

- Environmental storytelling.
- NPC conversations.
- Ancient inscriptions.
- Forgotten journals.
- Ruins and abandoned buildings.
- World events.
- Main quests.
- Optional side quests.

Avoid excessive cutscenes. Players should discover the story naturally through exploration.

---

# 4. WORLD DESIGN

## 4.1 World Structure

Aetherion consists of multiple separate islands.

Each island contains its own environment, resources, enemies, NPCs, and narrative elements.

Islands are connected through a transportation system, initially using ships.

## 4.2 Planned Islands

### Island 01 — Forgotten Shore

Starting island.

Environment:
- Green forests.
- Beaches.
- Small rivers.
- Abandoned settlements.
- Ancient ruins.

Resources:
- Wood.
- Stone.
- Gold.
- Food.

Gameplay purpose:
- Tutorial.
- Basic construction.
- Resource gathering.
- First recruitment.
- First survival encounter.

### Island 02 — Eldergrove Forest

Environment:
- Dense forests.
- Ancient trees.
- Hidden shrines.
- Overgrown ruins.

Resources:
- Wood.
- Herbs.
- Food.
- Rare natural materials.

### Island 03 — Frostveil Highlands

Environment:
- Snowy mountains.
- Frozen rivers.
- Abandoned fortresses.

Resources:
- Iron.
- Crystal.
- Rare minerals.

### Island 04 — Ashen Wastes

Environment:
- Volcanic terrain.
- Ash-covered forests.
- Destroyed settlements.

Resources:
- Ancient relics.
- Rare minerals.

### Island 05 — The Hollow Depths

Environment:
- Underground caves.
- Ancient machinery.
- Crystal formations.

Resources:
- Rare crystals.
- Ancient materials.

### Island 06 — Crownlands

Environment:
- Former royal capital.
- Large castles.
- Ancient monuments.

Gameplay purpose:
- Endgame exploration.
- Final story progression.
- The Last Light.

## 4.3 MVP World Scope

The MVP includes only Forgotten Shore.

Other islands remain planned content and must not be represented as completed gameplay.

---

# 5. CORE GAMEPLAY

## 5.1 Core Gameplay Loop

EXPLORE
→ COLLECT
→ BUILD
→ RECRUIT
→ DEVELOP
→ PREPARE
→ SURVIVE
→ EXPAND

## 5.2 Exploration

Players can move horizontally through the island.

Exploration activities:
- Discover resources.
- Locate abandoned settlements.
- Find NPCs.
- Unlock structures.
- Discover ancient ruins.
- Complete exploration objectives.

Exploration must not require constant combat.

## 5.3 Resource Gathering

Players can collect resources from:
- Trees.
- Rocks.
- Treasure chests.
- Hunting.
- Fishing.
- Farming.
- Trading.
- Quest rewards.

Some resource collection activities are performed by NPCs rather than directly by the player.

## 5.4 Kingdom Building

Players can construct buildings by spending shared resources.

Initial building list:

| Building | Purpose |
|---|---|
| Town Center | Kingdom development |
| Wooden Wall | Basic defense |
| Watchtower | Defensive observation |
| Farm | Food production |
| Workshop | Construction support |
| Storage | Resource management |

Each building supports upgrades where applicable.

## 5.5 Population

Villagers are essential to kingdom development.

NPC roles:

**Villager**
- Basic population unit.
- Can receive job assignments.

**Farmer**
- Produces food.
- Works at farms.

**Archer**
- Defends settlements.
- Participates in hunting and defense.

Villagers must have a valid job, movement behavior, and survival state.

## 5.6 Economy

Gold is the primary currency.

Additional resources:

| Resource | Purpose |
|---|---|
| Gold | Currency |
| Wood | Basic construction |
| Stone | Structural upgrades |
| Iron | Advanced construction |
| Food | Population support |
| Crystal | Ancient progression |

The initial MVP uses gold, wood, and stone. Additional resources are planned for later progression.

## 5.7 Survival

The world operates through a day/night cycle.

| Phase | Gameplay |
|---|---|
| Morning | NPC work begins |
| Afternoon | Exploration and building |
| Sunset | Defense preparation |
| Night | Enemy attacks |

Initial time configuration:
- Daylight: 8 minutes.
- Sunset: 1 minute.
- Night: 3 minutes.

Total: 12 minutes per in-game day.

These values are adjustable during balancing.

---

# 6. ENEMY DESIGN

## 6.1 Greedling

Role: Basic enemy.

Behavior:
- Approaches the kingdom.
- Attempts to steal gold.
- Retreats when carrying stolen resources.

## 6.2 Crawler

Role: Fast attacker.

Behavior:
- Moves quickly.
- Targets vulnerable villagers.
- Can bypass certain defensive weaknesses.

## 6.3 Brute

Role: Heavy attacker.

Behavior:
- High health.
- Slow movement.
- Attacks defensive structures.
- Requires coordinated defense.

## 6.4 Night Herald

Role: Special enemy.

Behavior:
- Appears during specific world events.
- Has unique attack patterns.
- Introduces narrative encounters.

Night Herald is not required for the MVP.

---

# 7. MULTIPLAYER DESIGN

## 7.1 Cooperative Mode

Players share a kingdom and economy.

Maximum players: 4.

Each player:
- Controls an independent monarch.
- Has an independent camera.
- Can explore the shared world.
- Can construct buildings.
- Can collect resources.
- Can cooperate on quests.

## 7.2 Player Specializations

Specializations are optional gameplay identities, not restrictive classes.

**Monarch**
- Leadership.
- Kingdom progression.

**Steward**
- Economy.
- Construction.

**Warden**
- Defense.
- Population protection.

**Seeker**
- Exploration.
- Ancient discoveries.

## 7.3 Multiplayer Rules

- Host owns world simulation.
- Clients send gameplay requests.
- Host validates important actions.
- Economy is shared.
- Building progression is shared.
- Quest progression is shared.
- World time is shared.
- Cameras are local.
- Player movement is synchronized.

## 7.4 MVP Multiplayer Limitations

- All players remain on the same island.
- No independent island simulation.
- No host migration.
- No public matchmaking.
- No persistent dedicated servers.

---

# 8. PLAYER EXPERIENCE

## 8.1 Controls

| Action | Default Input |
|---|---|
| Move Left | A |
| Move Right | D |
| Interact | E |
| Build | F |
| Inventory | Tab |
| World Map | M |
| Pause | Escape |
| Emote | G |

Controls must be configurable through the settings menu in a later milestone.

## 8.2 Player Progression

Progression is based on:
- Kingdom development.
- Story completion.
- Island exploration.
- Ancient discoveries.
- Equipment and mount unlocks.
- Special crown abilities.

## 8.3 Mount System

Mounts provide:
- Faster travel.
- Different movement characteristics.
- Special abilities.
- Exploration advantages.

Initial MVP includes one horse.

---

# 9. ART DIRECTION

## 9.1 Visual Identity

CROWNFALL uses detailed cinematic pixel art inspired by the atmospheric visual presentation of Kingdom.

Visual priorities:
- Rich environment details.
- Consistent pixel density.
- Layered landscapes.
- Atmospheric lighting.
- Dynamic weather and time transitions.
- Minimalist UI.
- Smooth character animations.

## 9.2 Color Direction

Forgotten Shore:
- Deep forest green.
- Warm sunlight.
- Natural brown.
- Muted blue water.

Eldergrove:
- Dark green.
- Moss.
- Muted gold.
- Deep shadows.

Frostveil:
- Cool blue.
- White.
- Grey.
- Pale cyan.

Ashen Wastes:
- Dark brown.
- Ash grey.
- Muted orange.
- Deep red.

## 9.3 Animation Requirements

Player:
- Idle.
- Walk.
- Run.
- Ride.
- Interact.
- Build.
- Damage.
- Death.

NPC:
- Idle.
- Walk.
- Work.
- Attack.
- Flee.
- Death.

Enemy:
- Idle.
- Walk.
- Attack.
- Damage.
- Death.

---

# 10. AUDIO DESIGN

Audio must reinforce atmosphere and gameplay feedback.

### Ambient Audio
- Wind.
- Birds.
- Water.
- Forest ambience.
- Fire.
- Village activity.

### Music
- Morning ambient.
- Exploration.
- Sunset.
- Night tension.
- Ancient ruins.
- Boss encounters.
- Emotional story themes.

### Gameplay Sound Effects
- Footsteps.
- Coins.
- Construction.
- Resource gathering.
- Enemy attacks.
- Building destruction.
- Quest completion.

---

# 11. USER INTERFACE

The interface should remain minimal.

HUD:
- Gold.
- Day number.
- Time phase.
- Kingdom status.
- Quest notification.
- Player indicators.

Main menu:
- New Game.
- Continue.
- Multiplayer.
- Settings.
- Credits.

Multiplayer lobby:
- Create Room.
- Join Room.
- Room Code.
- Player List.
- Ready Status.
- Start Game.

---

# 12. MVP SCOPE

The first MVP includes:

| Feature | Required |
|---|---|
| Forgotten Shore | Yes |
| 1–4 Players | Yes |
| Player Movement | Yes |
| Independent Cameras | Yes |
| Gold System | Yes |
| Wood and Stone | Yes |
| Building System | Yes |
| NPC Recruitment | Yes |
| 3 NPC Types | Yes |
| 3 Enemy Types | Yes |
| Day/Night Cycle | Yes |
| 6 Building Types | Yes |
| One Horse | Yes |
| Five Quests | Yes |
| Chapter I | Yes |
| Save/Load | Yes |
| Online Co-op | Yes |

---

# 13. GAME DESIGN SUCCESS CRITERIA

The game design is successful when:

1. Players understand the basic gameplay without extensive tutorials.
2. Building decisions have meaningful consequences.
3. Resource management creates interesting choices.
4. Exploration consistently rewards curiosity.
5. Night survival creates tension without becoming frustrating.
6. Multiplayer cooperation feels useful and natural.
7. The world communicates its history through visual storytelling.
8. The first chapter has a satisfying beginning and conclusion.

---

# 14. DESIGN CONSTRAINTS

- Do not copy copyrighted characters, artwork, maps, music, or assets from Kingdom.
- Develop original characters and world lore.
- Keep the initial scope small.
- Avoid unnecessary combat complexity.
- Prioritize the first island.
- Do not introduce unfinished features as completed content.
- All new gameplay features must be reviewed against the GDD.

---

**END OF GDD**

Project: CROWNFALL: THE LAST LIGHT  
Document: GDD.md  
Version: 1.0