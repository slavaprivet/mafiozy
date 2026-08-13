# AI project memory

This directory contains durable engineering context for agents working on
Mafiozi. Read the smallest relevant memory before changing code:

- [`GANG_SYSTEM_MEMORY.md`](GANG_SYSTEM_MEMORY.md) — gangs, the 19 NPC
  empires, diplomacy, economy, holdings, guards, business raids and indoor
  assaults.
- [`OPTIMIZATION_MEMORY.md`](OPTIMIZATION_MEMORY.md) — mandatory performance
  and rendering constraints for every 3D change.
- [`TASK_FOR_CLAUDE.md`](TASK_FOR_CLAUDE.md) — task hand-off template.

The memory files describe invariants and verified contracts, not a substitute
for reading the current implementation. Always start from fresh GitHub `main`,
confirm names in source, and update the relevant memory when a contract changes.
