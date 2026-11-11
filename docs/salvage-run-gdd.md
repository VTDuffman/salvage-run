# Salvage Run — Game Design Document
**Version:** 0.5
**Status:** Concept / Pre-Production
**Last Updated:** November 2026
**Previous Working Title:** Dead Reckoning

---

## 1. Overview

**Salvage Run** is a solo pixel art roguelike deck-builder in which the player assembles a scrappy, cobbled-together spaceship and sends it on increasingly dangerous cargo runs across a hostile galaxy. Named for the navigation technique of committing to a course using only known speed, heading, and elapsed time — no external guidance — the game captures that same spirit: you build your ship, lock in your route, and live with the results.

### Elevator Pitch
You're not a hero. You're a hauler trying to make rent. Assemble your ship from whatever parts you can afford, hire whatever crew will work for you, and fly your rust bucket across the galaxy hoping your decisions were good enough.

### Tone & Aesthetic
- **Visual:** Pixel art. Warm, worn, imperfect.
- **Tone:** Firefly, not Star Trek. Scrappy and functional over sleek and heroic. Parts look mismatched because they are.
- **Feel:** The ship is held together with stubbornness and duct tape. The crew has history. Nothing is guaranteed.

---

## 2. Core Pillars

1. **Build, then commit.** The player's skill is expressed entirely in the build phase. Runs are passive — you watch your decisions play out.
2. **Every run tells a story.** Cascading failures, unexpected rescues, a crew member lost mid-run. Players retell these moments.
3. **The ship is a puzzle.** Spatial grid-based assembly means placement matters as much as part selection.
4. **Exploration is rewarded.** Taking harder or longer routes unlocks technology and crew that money can't buy.

---

## 3. Core Game Loop

```
Select Mission
     ↓
Choose Hull Framework
     ↓
Assemble Ship (Grid Puzzle)
     ↓
Hire/Assign Crew to Quarters
     ↓
Watch the Run (Passive — Challenge Cards resolve automatically)
     ↓
Collect payment / Assess damage / Lose crew
     ↓
Visit Shop / Unlock new parts, crew, hulls
     ↓
Select next Mission
```

**Key mechanic:** Once the run begins, the player has no input. All decisions were made during assembly. This makes the build phase feel like solving a puzzle under pressure, and the run itself feel like watching your math get tested.

---

## 4. Galaxy Map

### Structure
The galaxy is represented as a **node-based map** with branching paths — similar in structure to Slay the Spire's map. Each run begins at a starting node and ends at a destination node. The player chooses their route at each fork.

### Rules
- **Runs are one-way.** Once a fork is chosen, there is no backtracking.
- **Nodes are visible** but their contents may not be fully revealed (unknown systems show as question marks).
- **Each run** traverses a set number of nodes before reaching the destination.

### Node Types

| Node | Description |
|------|-------------|
| **Mission** | The primary cargo/delivery/combat encounter. Core gameplay loop. |
| **Shop** | Buy parts with earned money. Inventory varies by run. |
| **Unknown System** | Randomized: alien tech cache, hazard, abandoned ship, or nothing. Risk/reward. |
| **Event** | Text-based encounter. Distress signals, shady merchants, faction offers. Primary crew recruitment source. |
| **Repair Dock** | Restore damaged or destroyed hull sections. |
| **Faction Outpost** | Complete faction-specific missions to earn reputation and unlock military surplus parts. |

### Fork Decisions (Examples)
- Safe route with a shop vs. unknown system with possible alien tech
- Long high-pay mission vs. short mission through a badly needed repair dock
- Faction mission (low pay, high reputation) vs. standard cargo run

---

## 5. Hull Frameworks

The hull is the foundation of the ship — it determines the shape and size of the grid the player assembles parts into. Hull type is **chosen per run** based on mission objectives and player strategy.

Hull frameworks are **unlocked through play milestones**, not purchased.

### Hull Types

#### Cruiser
- **Grid:** Balanced, square layout
- **Strengths:** No major weaknesses. Flexible build options.
- **Weaknesses:** No specialization bonuses.
- **Best for:** Mixed objectives, learning runs, uncertain threat profiles.
- **Unlock:** Starting hull — available from the beginning.

#### Freighter
- **Grid:** Wide, with dedicated cargo rows that cannot be repurposed for weapons or crew quarters.
- **Strengths:** Highest cargo capacity in the game.
- **Weaknesses:** Large target, limited combat ability.
- **Best for:** High-volume delivery missions.
- **Unlock:** Complete first successful delivery mission.

#### Battleship
- **Grid:** Reinforced front section with built-in weapon hardpoints that amplify gun damage.
- **Strengths:** Superior combat. Built-in front armor.
- **Weaknesses:** Limited cargo space. Expensive to operate.
- **Best for:** Combat escort missions, hostile route runs.
- **Unlock:** Complete first combat escort mission.

#### Smuggler's Sloop
- **Grid:** Small, narrow layout with hidden compartment slots not visible to customs inspections.
- **Strengths:** Stealth. Hidden cargo capacity. Fast.
- **Weaknesses:** Fragile. Low raw cargo capacity.
- **Best for:** Contraband runs, short high-risk routes.
- **Unlock:** Complete first contraband delivery.

---

## 6. Ship Grid System

### The Grid
The ship is assembled on a **spatial grid matrix**. Part placement determines both function and vulnerability.

### Grid Sizing (Progression)
| Stage | Grid Size | Notes |
|-------|-----------|-------|
| Early Game | 3×3 | Constrained — teaches prioritization |
| Mid Game | 4×4 | Synergies and specialization become viable |
| Late Game | 5×5 | Maximum complexity, deepest build variety |

Grid size upgrades are unlocked through game progression. Hull framework shape may vary even at the same grid size (e.g., a 4×4 Freighter is wide; a 4×4 Sloop is narrow).

### Spatial Rules

**Damage propagation:** Challenges hit from a direction (front, flank, rear). Damage moves inward through the grid, hitting the outermost exposed parts first.

**Adjacency:** Parts adjacent to each other can have interactions — both positive (bonuses) and negative (collateral damage).

**Placement logic:**
- Thrusters belong at the rear
- Guns at the front
- Cargo holds in the center
- Crew quarters protected behind hull and shields

Deviating from this has consequences. A cargo hold on the exposed flank is vulnerable. A crew quarter on the front row is the first thing pirates breach.

### Hull Damage
Hull sections can be **destroyed mid-run**, removing those grid squares from play. A 4×4 ship that takes a catastrophic hit may become an irregular 4×3 with a hole where critical systems used to be. The player must complete the run with whatever remains.

### Part Shapes
Parts vary in grid footprint:
- **1×1:** Most standard parts (guns, sensors, crew quarters)
- **2×1:** Larger systems (extended fuel tanks, reinforced shields)
- **L-shaped / 2×2:** Rare alien tech, capital-grade components

Fitting parts into the grid is a Tetris-style spatial puzzle layered on top of strategic selection.

---

## 7. Parts System

### Acquisition
Parts are acquired through two distinct tracks:

**Money Track (Shop Nodes)**
- Standard and military surplus parts purchased with run earnings
- Reliable, known quantities — you know exactly what you're buying
- Inventory rotates between runs

**Exploration Track (Unknown Systems)**
- Alien technology discovered in unexplored systems
- More powerful and exotic than standard parts
- Unpredictable: may have side effects, unusual interactions, or adjacency bonuses
- Cannot always be repaired if damaged — when it's gone, it's gone

### Part Tiers
| Tier | Source | Reliability | Power |
|------|--------|-------------|-------|
| Standard | Shop | Predictable | Baseline |
| Military Surplus | Faction reputation | Predictable | Above baseline |
| Alien Tech | Exploration | Unpredictable | High ceiling, unusual behavior |

### Part Categories

#### Thrusters
Maneuverability and speed. Counter navigation-based challenges. Higher-tier thrusters reduce fuel burn on evasive maneuvers.

#### Fuel Tanks
Run range. Redundant tanks counter fuel leak events. Larger tanks allow longer routes and more node choices.

#### Cargo Holds
Cargo capacity and protection. Quality holds protect fragile goods. Specialty holds include refrigerated (perishables) and reinforced (high-value goods).

#### Shields
Active damage absorption. Rechargeable between encounters. Counter directed energy attacks and solar events. Placement on the grid determines which facing is protected.

#### Hull Plating
Passive damage absorption. Not rechargeable — raw HP. Different from shields. Counter physical impacts, debris, boarding attempts.

#### Guns
Combat. Counter pirate encounters and bounty hunters. Gunner crew amplifies effectiveness when quarters are adjacent to weapon systems.

#### Sensors / Navigation
Reveal unknown node contents before commitment. Allow routing around certain challenge types. Counter asteroid fields and gravitational anomalies at range.

#### Repair Systems
Auto-repair between encounters. Counter ongoing damage-over-time effects. Engineer crew amplifies when quarters are adjacent.

#### Crew Quarters
Required to carry crew. Crew is lost if their quarters are destroyed. Central placement and shield/hull protection are critical decisions.

#### Smuggling Compartments
Hidden cargo slots not visible to customs challenges. Visible grid shows no contraband. Counter inspection events without requiring crew intervention.

#### Comms Array
Negotiate, bribe, or call for assistance. Counter social challenges. Enables non-combat resolution of certain pirate encounters.

---

## 8. Crew System

### Overview
Crew members are the human (and sometimes not-human) layer of the game. They give the ship personality, provide passive counters to specific challenge types, and create narrative moments. Crew must be housed in quarters — if their quarters are destroyed, the crew member is lost.

### Unlock Mechanic
Crew are **not purchased in the shop**. They are unlocked through actions taken during runs:

| Crew Member | Unlock Trigger |
|-------------|---------------|
| Charismatic Captain | Complete a set number of successful runs |
| Engineer | Respond to a distress signal and rescue a stranded crew |
| Pilot | Navigate X asteroid fields or gravitational wells successfully |
| Gunner | Defeat a pirate crew in combat — one switches sides |
| Medic | Complete first passenger transport mission |
| Smuggler | Complete first contraband run successfully |

### Crew Specialties

| Crew Member | Counters |
|-------------|---------|
| **Charismatic Captain** | Customs inspections, bounty hunters, rival haulers, distress negotiations |
| **Engineer** | Fuel leaks, engine failure, system malfunctions |
| **Pilot** | Asteroid fields, gravitational wells, tight navigation challenges |
| **Gunner** | Pirate ambushes, combat encounters (amplified near weapon hardpoints) |
| **Medic** | Passenger missions, crew injury events |
| **Smuggler** | Contraband challenges, inspections (better at hiding, worse at talking than Captain) |

### Crew + Parts Synergy
Some challenges are countered *imperfectly* by either a part or a crew member alone, but *perfectly* when both are present. Example: A customs inspection is countered by smuggling compartments (hides the goods) or a charismatic captain (talks the way out) — but countered with no cost or damage only if both are aboard.

### Crew Loss
When crew quarters are destroyed mid-run, the crew member in those quarters is lost. This can cascade — losing the engineer means fuel leaks go uncountered, leading to fuel loss, leading to running out before the destination. These cascading failures create the most memorable moments in the game.

---

## 9. Challenge Cards

Challenge cards resolve automatically during the run. Each card has:
- **What hits you**
- **What counters it** (parts, crew, or both)
- **What happens if nothing counters it**

### Combat Challenges

| Challenge | Counter | Uncountered Result |
|-----------|---------|-------------------|
| Pirate Ambush | Guns (fight) or Comms (negotiate/bribe) | Cargo stolen or hull damage |
| Bounty Hunter | Smuggling compartments or Guns | Cargo seized, run ends |
| Rival Hauler | Comms or Thrusters (arrive faster) | Contract cut, reduced payout |

### Environmental Challenges

| Challenge | Counter | Uncountered Result |
|-----------|---------|-------------------|
| Asteroid Field | Sensors (route around) or Hull/Shields (absorb) | Hull damage |
| Solar Flare | Shields | Systems damage, parts temporarily disabled |
| Gravitational Well | Extra fuel tanks | Stranded — run ends |
| Debris Field | Thrusters or Hull | Moderate hull damage |

### Mechanical Challenges

| Challenge | Counter | Uncountered Result |
|-----------|---------|-------------------|
| Fuel Leak | Repair systems or redundant tanks | Fuel drains each subsequent card |
| Engine Failure | Spare thrusters | Run length increases, extra fuel burned |
| Cargo Shift | Quality cargo holds | Fragile cargo damaged |
| System Malfunction | Engineer crew | Random part goes offline for remainder of run |

### Social / Event Challenges

| Challenge | Counter | Uncountered Result |
|-----------|---------|-------------------|
| Customs Inspection | Smuggling compartments or Comms (bribe) | Contraband seized |
| Distress Signal | Choice: respond (fuel/time cost, possible crew recruit) or ignore (reputation loss) | — |
| Boarding Party | Guns + Hull (repel boarders) | Crew quarters targeted, possible crew loss |

---

## 10. Mission Types & Difficulty

### Mission Types
- **Cargo Delivery** — deliver goods from A to B. Volume and fragility vary.
- **Passenger Transport** — keep people alive. Life support and Medic crew matter.
- **Contraband Run** — illegal goods, inspections, bounty hunters. Sloop optimal.
- **Combat Escort** — protect a convoy. Battleship optimal.
- **Salvage Run** — pick up debris mid-route. Sensors and cargo holds critical.
- **Multi-Stop Delivery** — drop partial cargo at waypoints, more exposure per leg.

### Difficulty Levers
Missions combine multiple constraints:

| Variable | Effect |
|----------|--------|
| Distance (node count) | More challenges, more fuel required |
| Cargo volume | Requires more cargo holds |
| Cargo type | Fragile, perishable, contraband, or live passengers each add constraints |
| Route danger | Lawless space = more pirates; asteroid belts = more debris |
| Delivery deadline | Fuel efficiency matters, evasion costs more |

The most challenging missions combine two or more constraints — *long distance AND fragile cargo AND a deadline* forces a very specific build.

---

## 11. Progression System

### Money
Earned from completing missions. Used to buy parts at shop nodes. Lost runs still pay partial rewards based on how far the player got.

### Unlocks
| What | How |
|------|-----|
| New crew members | Actions taken during runs (rescues, combat, mission types) |
| New hull frameworks | Completing mission type milestones |
| Alien technology parts | Visiting unexplored systems on the galaxy map |
| Military surplus parts | Building faction reputation at faction outpost nodes |

### Emotional Arc
Early runs: lonely, mechanically hard, ship feels fragile.
Mid runs: crew starts to appear, synergies emerge, the ship has personality.
Late runs: a full crew with history, deep part synergies, mastery of the build phase.

---

## 12. Win & Loss Conditions

### Per-Run Loss Conditions
- **Ship destroyed** — hull damage accumulates until the ship is gone
- **Out of fuel** — stranded, run ends
- **Objective failed** — cargo destroyed, passengers lost, contraband seized (mission-dependent)

### Per-Run Win Condition
- Reach the destination with the objective intact

### Meta-Progression Win
TBD — likely a campaign structure with an overarching narrative goal or a "final run" milestone.

---

## 13. Open Design Questions

These items are identified but not yet decided:

1. **Campaign structure** — is there an overarching narrative goal, or is it endless roguelike runs?
2. **Crew personality conflicts** — do certain crew members have negative synergies with each other?
3. **Positive event cards** — should lucky/beneficial events exist, or is it purely a gauntlet?
4. **Crew upkeep** — do crew cost fuel or money per run, adding resource pressure?
5. **Part condition** — do parts degrade over multiple runs, requiring maintenance spending?
6. **Alien tech side effects** — what are the specific mechanics for unpredictable alien part behavior?
7. **Meta-progression resets** — roguelike death: does losing a run reset everything, or just the current route?

---

## 14. Technical Notes

- **Target platforms:** Steam (Windows/Mac/Linux) and Mobile (iOS/Android)
- **Engine:** Godot 4 — single codebase exports to all target platforms
- **Language:** GDScript (Python-adjacent, Godot 4 syntax — always specify Godot 4 when prompting Claude Code)
- **Art style:** Pixel art (configure texture filtering and viewport snap settings at project start)
- **Perspective:** Top-down — ship grid reads as a schematic/blueprint; damage direction maps to cardinal facing (front = top of grid)
- **UI consideration:** Design touch targets and mouse/keyboard inputs in parallel from the start — retrofitting mobile UI is painful
- **Similar games for reference:** Galaxy Trucker, Slay the Spire, FTL: Faster Than Light, Balatro
- **Competitive awareness:** Void Salvage (Steam, Early Access 2026) — pixel art space roguelite with ship module building and branching node map. Autobattler focused on combat rather than hauling/cargo. Different enough mechanically but close in aesthetic and genre. Monitor for positioning.

---

## 15. Vertical Slice (First Build Target)

### Purpose
The slice exists to answer one question before anything else gets built:

> **Is it fun to build a ship and then watch a passive run play out?**

Everything in Sections 4–11 is layering on top of that bet. If the slice works, the rest is content and systems. If it doesn't, we learn that cheaply and adjust the core (for example, adding one small player decision mid-run) before investing further.

The slice is also the Godot 4 learning project: scenes, a grid, drag-and-drop, data-driven content, and a turn-by-turn resolution loop.

### In Scope

**One hull, one grid**
- Cruiser hull, 3×3 grid, top-down
- Front of the ship = top row; rear = bottom row; flanks = left and right columns

**Six parts (all 1×1, no shapes yet)**

| Part | Function in slice | Starting HP |
|------|------------------|-------------|
| Thruster | Required to launch. Must be in the rear row to function. | 2 |
| Fuel Tank | Holds fuel units. Each challenge card burns 1 fuel. | 2 |
| Cargo Hold | Holds 1 cargo unit. Mission requires a set number intact at the end. | 2 |
| Shield | Absorbs incoming damage for itself and orthogonally adjacent cells, a set amount per card. | 2 |
| Hull Plating | No function. High HP. Pure protection. | 4 |
| Gun | Counters Pirate Ambush if placed in the front row. | 2 |

**Eight challenge cards**

| Card | Direction | Counter | Uncountered |
|------|-----------|---------|-------------|
| Pirate Ambush | Front | Gun in front row | 2 damage to front row |
| Asteroid Field | Front | Shield on front facing | 2 hits, random front columns |
| Debris Strike | Random flank | Shield on that flank | 1 hit |
| Rear Raider | Rear | Shield on rear facing | 1 hit to rear row |
| Solar Flare | All | Any working Shield | 1 damage to every unshielded part |
| Fuel Leak | Internal | 2+ Fuel Tanks | Lose 2 extra fuel |
| Gravity Well | Internal | 2+ Thrusters | Lose 1 extra fuel |
| Calm Space | — | — | Nothing happens (pacing) |

**Damage model (starting proposal)**
- A directional hit travels inward from that side along a row or column and strikes the first occupied cell
- A part at 0 HP is destroyed and its cell is removed from the grid
- Destroyed parts lose their function immediately, which is how cascading failures happen

**The run**
- One mission: deliver N cargo across a fixed number of challenge cards (start with 8)
- Cards are drawn in random order from the pool, using a seed so a run can be replayed exactly
- Playback resolves one card at a time with a short animation and a text log line ("Pirate Ambush — your gun drove them off")
- Speed controls: play, pause, fast-forward

**Win / loss**
- Win: reach the final card with fuel ≥ 0 and the required cargo holds intact
- Loss: no working thruster, fuel runs out, or too few cargo holds remain

**Data-driven content**
- Parts, cards, and mission parameters live in data files (Godot Resources or JSON), not hard-coded
- Balance must be tunable without touching game logic

### Explicitly Out of Scope
- Crew and crew quarters
- Galaxy map, nodes, and routing
- Shop, money, and progression
- Other hulls (Freighter, Battleship, Smuggler's Sloop)
- Grid sizes other than 3×3
- Multi-cell part shapes
- Alien tech, factions, reputation
- Final pixel art (placeholder colored tiles and simple icons are fine)
- Mobile build (desktop only for the slice; keep the layout readable at a phone aspect ratio)
- Save/load and meta-progression

### Success Criteria
The slice is a success if, after a week of playing it:
1. You find yourself immediately rebuilding the ship to try again after a loss
2. You can explain why a run failed by watching the playback
3. At least three meaningfully different builds can win the mission
4. A full build-plus-run cycle takes roughly 1–2 minutes
5. At least one run produces a cascading failure that feels like a story

If criteria 1 and 2 fail, revisit the passive-run premise before building anything else.

### Suggested Build Order
1. Godot project skeleton with pixel-art settings and a 3×3 grid on screen
2. Part palette and drag-and-drop placement onto the grid
3. Part and card data files
4. Run resolver as pure logic, testable without visuals
5. Run playback scene with log and speed controls
6. Win/loss screen with "Rebuild" and "Retry same seed"
7. Tuning pass using the data files

---

*Document is a living design artifact. Update as decisions are made.*
