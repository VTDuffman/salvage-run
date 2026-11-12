# Parts and Cards

Starting values. All of them live in data files and will change during tuning. Grid orientation: front = top row, rear = bottom row, flanks = left/right columns. "Working" means not destroyed and, for Thruster and Gun, in the required row.

## Parts (all 1×1, unlimited copies, cells may stay empty)

| Part | Function | Starting HP |
|------|----------|-------------|
| Thruster | Required to launch. Works only in the rear row. Outside it, it is inert but still occupies the cell and absorbs hits. | 2 |
| Fuel Tank | Adds 4 fuel to a shared pool. When a tank is destroyed, the pool is capped at working tanks × 4. | 2 |
| Cargo Hold | Holds 1 cargo unit. The mission requires a set number intact. | 2 |
| Shield | Covers its orthogonal neighbors only, not its own cell. Absorbs up to 2 damage per card; capacity refreshes every card. Solar Flare ignores capacity: covered parts take no flare damage. | 2 |
| Hull Plating | No function. Pure protection. | 4 |
| Gun | Cancels Pirate Ambush when in the front row. Outside it, it is inert but still occupies the cell and absorbs hits. | 2 |

## Challenge cards

The shuffled 8-card pool is the run: each card appears exactly once. Every hit deals 1 damage and can be absorbed by shield coverage (`resolution-rules.md`).

| Card | Direction | Counter | Uncountered |
|------|-----------|---------|-------------|
| Pirate Ambush | Front | A working Gun in the front row cancels the whole card | One hit down each of the 3 front columns |
| Asteroid Field | Front | Shield coverage on struck cells | 2 hits down random front columns (picked independently) |
| Debris Strike | Random flank | Shield coverage on struck cell | 1 hit down a random row from that flank |
| Rear Raider | Rear | Shield coverage on struck cell | 1 hit up a random rear column |
| Solar Flare | All | Shield coverage on each part (capacity ignored) | 1 damage to every part outside shield coverage |
| Fuel Leak | Internal | 2+ working Fuel Tanks | Lose 2 extra fuel |
| Gravity Well | Internal | 2+ working Thrusters (rear row) | Lose 1 extra fuel |
| Calm Space | — | — | Nothing happens (pacing) |

## Mission

One mission: deliver N cargo across the 8 cards. N is a data value.
