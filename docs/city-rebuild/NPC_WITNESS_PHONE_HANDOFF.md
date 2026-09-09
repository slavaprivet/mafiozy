# Source-world witnesses and phone completion

Owner: Artist14 subagent. 2026-09-09. These changes run in the existing `world.html` simulation; no second AI, WebSocket, wanted counter, or server protocol was added.

## Applied

- `triggerWitnessChain`: a nearby civilian must have the existing world-map line of sight to identify the crime. Hearing panic remains separate and can reach behind walls. District reputation changes only when an eligible witness actually sees the event. The two-caller cap excludes dead, downed, stunned, fighting and cuffed actors.
- `_npcWitnessAble`, `_npcCancelInterruptedWitness`: incapacitation cancels an unfinished call before `updateNpcs` takes its dead/downed early exits. Recovery cannot resume an interrupted call and retrospectively report it.
- `_npcFinishWitnessCall`: the finite phone timer now sends the existing `open_fire` witness report, then leaves the calling state. No arrival at the police station is required. A rate-limited or disconnected attempt stays pending, bounded by the existing 60-second witness lifetime. Legacy station-running witnesses still use the same report path and retry rather than silently losing a throttled report.
- `_snitchReport`: only a successful send on an open socket advances the 2.5-second throttle. Its toast states that a report was sent; it no longer claims a server-approved wanted increase.
- `_npcBeginPanic`: equal-priority repeated events extend flight duration without restarting freeze/cower/initial reaction deadlines. A higher priority can interrupt; a lower priority cannot replace the current incident. Panic interrupts social conversation as well as helping. Hearing-only reaction speech no longer pretends to make a police call.
- Existing snapshot `phoneCalling` consumes the real finite calling state, including retries, and stops when reported or interrupted.

## Validation

`node test_npc_witness_reactions.mjs` executes extracted source functions and verifies LOS, distance, no false reputation change, caller-slot release, no report before timer completion, exactly one report, incapacity interruption, throttle/offline retries, and non-restarting automatic-fire panic phases. Running against the saved pre-change source fails the first through-wall witness assertion.

Existing `test_npc_life_system.py`, `test_police_murder_custody_transport.py`, and `test_police_murder_custody_stress.py` pass when run directly. Pytest is not installed; these files provide their own executable test entry points. Browser visual checks remain the parent task's responsibility.

## Remaining authority/design gaps (not changed here)

- `_murderSceneWitnesses` currently selects nearby surviving civilians at interview time. It does not store who saw the killing at event time, and does not itself filter visibility. A bystander arriving later can therefore be interviewed as a witness. A proper extension needs captured event-time observations, while preserving existing corpse discovery and investigation dispatch.
- `_registerMurderIncident` and `_onAnyNpcKilledByPlayer` already wake patrols independently of phone completion. This change does not suppress that existing murder-response mechanic.
- Server `open_fire` derives the shooter position from server state and owns wanted decisions, but its existing cop/player witness checks use radius, and client-side resident reports use the existing `witness` flag. This patch does not claim cryptographic/server verification of a resident's observation or change that authority boundary.
- Phone reports use the existing source protocol, which evaluates current server player position. Remembered crime location is not a new trusted server field.
- Routine destination, buildings, benches and driving changes belong to the parent/other owner; these edits touch only witness helpers and their update hooks.
