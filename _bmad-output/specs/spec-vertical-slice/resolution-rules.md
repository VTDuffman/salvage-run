# Resolution Rules

The damage model is a starting proposal. Tune it freely, but keep it in pure logic.

## Hits

- A directional hit enters from its side and travels inward along one row or column (its lane). It strikes the first occupied cell.
- Empty cells, including cells of destroyed parts, are passed through. A lane with no parts is a miss.
- Each hit deals 1 damage.

## Shields

- Coverage is the shield's orthogonal neighbors only, not its own cell: a shield can be hit and destroyed like any other part. Only working (not destroyed) shields cover.
- When a cell struck by a directional hit is inside any coverage, the damage is drawn from shield capacity instead of the part.
- Each shield has 2 capacity per card, refreshed at the start of every card.
- When a cell is covered by more than one shield, damage is drawn from the shield with the most capacity remaining.
- When no covering shield has capacity left, the part takes the damage.
- **Solar Flare ignores capacity.** A part inside any working shield's coverage takes no flare damage, however much capacity is left, and the flare draws no capacity. A part outside all coverage takes 1 damage.

## Damage and destruction

- A part at 0 HP is destroyed and its cell is removed from the grid.
- A destroyed part loses its function immediately. This is how failures cascade.
- Destroying a fuel tank caps the fuel pool at working tanks × 4. This can drain fuel immediately.

## Run

- Starting fuel = working tanks × 4.
- The run seed shuffles the 8-card pool; each card appears exactly once. The seed also picks the random lanes. The same seed gives the same card order.
- Per card, in order:
  1. Refresh shield capacity.
  2. Apply the card's countered or uncountered effect.
  3. Burn 1 fuel.
  4. Check for loss. The run ends at the first loss.
- Playback shows one card at a time, with a short animation and one log line per card.

## Win / loss

- **Loss** (checked after every card), on any of these:
  - no working thruster (none in the rear row)
  - fuel would go below 0
  - fewer intact cargo holds than the mission requires
- **Win:** the final card resolves with no loss. Ending at exactly 0 fuel is fine.

## After the run

- **Retry same seed:** keeps the seed.
- **Rebuild:** generates a new seed.
- Both return to the build screen with the previous layout. The next launch runs the current ship, including any edits.
