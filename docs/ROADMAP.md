# CROWNFALL: THE LAST LIGHT — ROADMAP & BACKLOG

**Status:** Planned / unimplemented ideas only.
Per the CHANGELOG policy, this file is the single home for planned features and
unimplemented work. Nothing in this document is shipped; entries move to
`docs/CHANGELOG.md` only after they are actually implemented and verified.

Source: development review notes (2026-11-15) — user-provided feature ideas and
design observations for future islands and long-session play.

---

## Progression foundation planning

The staged progression architecture and implementation sequence are documented in:

- [`PROGRESSION_FOUNDATION_DESIGN.md`](PROGRESSION_FOUNDATION_DESIGN.md) — progression facts, unlock evaluation, ownership boundaries, and save compatibility.
- [`PROGRESSION_IMPLEMENTATION_ROADMAP.md`](PROGRESSION_IMPLEMENTATION_ROADMAP.md) — phased implementation, tests, acceptance criteria, and risk controls.

These documents are planning references for everything that is still unimplemented: multiple islands, shrine/statue buffs, and mounts remain future work, and Eldergrove Forest gameplay (Island 2) itself does not exist yet. Implemented so far: the era correction (Shipwreck Stage 3 unlocks the voyage; Iron Age requires the Eldergrove milestone; see `docs/CHANGELOG.md` and `PROGRESSION_FOUNDATION_DESIGN.md` section 12), the specialist domain foundation (validated roster, derived lifecycle, Scientist discover/recruit path with data-driven housing on Forgotten Shore; Blacksmith/Architect/Scholar definitions exist and fail closed until their islands ship), and the research system foundation (two Forgotten Shore technologies gated on the recruited Scientist, transactional costs, authoritative world-time progress, exactly-once completion with real gameplay effects; see `PROGRESSION_FOUNDATION_DESIGN.md` sections 13-14).

---

## 1. Units & Defense

- **Permanent Archer garrison:** Archers stationed on the Watchtower become a
  persistent perch assignment; if a garrisoned Archer falls, another recruited
  unit takes over the perch automatically.
- **The Monarch does not chop:** The King acts as a leader and stops felling
  trees personally. Tree chopping is delegated to `Builder` NPCs with explicit
  process durations (small tree: `3s`, large tree: `5–10s`).

## 2. Environment & Exploration

- **Scattered Vagrant Camps:** Split the single Vagrant Camp into several
  smaller camps distributed through the forest belt.
- **Mountable steed:** The Monarch can ride a mount. Mounts must be found by
  the player on the map and are intentionally rare. Swappable once discovered.
- **Wandering merchant NPC:** A travelling trader that appears along the shore
  line with a rotating offer.

## 3. Building Tiers & Era-Deep Progression

- **Building level tiers:** Structures gain level tiers, e.g. `Lvl 1–3` use
  Wood while `Lvl 4–5` use Stone.
- **Wood Age:** buildings and resource needs are wood-only.
- **Stone Age:** wooden buildings become upgradeable using Stone.
  (Shipped in v1.4.3 as the era *unlock* state; the per-building tier upgrade
  matrix above remains future work.)
- **Iron Age:** dedicated to equipment, weapons and heavy gear — battering-ram
  carts, a giant catapult, or giant bolts hauled by multiple builders.

## 4. Enemy Variation (Greedlings)

- New Greedling variants: small, medium, large, flying, and armed types.
- Rare carriers that drop a random secret item when defeated.

## 5. Game Settings

- Graphics options (beyond the current Master Volume / Fullscreen in the pause
  menu) and gameplay options (e.g. clock speed defaults, screen-shake toggles).

## 6. Difficulty Curve Observation (Design Note)

Night difficulty plateaus from Night 3 onward (`4 waves`, `Brute`, `2 West
Scouts`). This is acceptable while the target is the Shipwreck escape, but it
can feel repetitive for long play sessions. Consider escalating composition or
cadence after Night 3 when future islands land — without disturbing the shipped
first-island balance (`Night 1` passive-breach teaching moment and `Night 2`
both-shores escalation stay as-is).
