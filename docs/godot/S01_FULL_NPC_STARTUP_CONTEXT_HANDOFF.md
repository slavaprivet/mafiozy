# Full offline NPC placement context — frozen source package

Root21 approved a concrete offline NEW_SESSION boundary: finish the complete
deferred population callback, before any server snapshot and before native
resolver registration. Source clock0, game720, seed20260927 continued after
the original6356 factory draws, fixed Date2026-09-27T00:00:00.000Z is an explicit
config parameter. This is not the browser's asynchronous first-registration
snapshot, imported saved progress, server authority or native placement.

Frozen output directory:
`outputs/astra21_npc_full_startup/d3d0596340658f9e5238977e99d2c900ff7cdbbe40d09c4f3096aa46089880a8/`

`context.json` SHA
`a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c`,
379451bytes. `receipt.json` pins the config, all five implementation files and
every complete sibling audit file. The immutable original e926 packet and all
three original appearance descriptors/assets remain unchanged.

## Result and integration contract

326 placement objects:308 NPCS (the same288 ordinary residents plus20 actual
named source objects),18 city cops (12 accepted patrols plus6 prison staff),
and the actual initial worldCops=[] under the explicit before-server boundary.
All29 source CARS,8 PETS and the original player state are included. Source
parking changes exactly67 MAP cells to9; post-parking MAP SHA
128837e8955b012ce07d18e137d9a85761600587d9886129f5c134c685c6a2b0.
The building collision cache remains unchanged; no guessed rebuild was applied.

Use `context.objects` as an object-key table. Pool arrays contain keys into
that table. Named registry aliases reference those same keys, preserving the
source's shared object identity. Object keys are serialization references;
raw entity IDs remain unchanged and must not be replaced by these keys. Police
use actual finite y/x; residents use r/c. Preserve all raw eligibility fields,
dead/alive state, pending placement and vehicle/interior/owner flags.

The actual original initial-placement algorithm and13 source semantic checks
are preserved in `outputs/astra21_npc_initial_placement_context`. Collect all
NPCS/cityCops/worldCops in source order and deduplicate object references, not
IDs. Even ineligible nondead actors obstruct candidate spacing<.55sourcecells.
An original position that passes the source body query skips spacing entirely.
Do not search against a three-row subset or create new births/free coordinates.
Root owns actual native body/police queries, support, whole-row scheduling,
runtime updates, physical admission and scene insertion. This package does
not clear `_npcInitialPlacementPending` or establish a native-safe point.

Final RNG6798 draws/state4189433893 is included. Phase boundaries are ordinary
6356 → named6376 → traffic6431 → police/pets/spawn safety6798. Cars use the
actual native-null-resolver early return:36 moving attempts create no cars or
RNG draws. Twenty-five parked admission entries keep actual CARS references;
three gang cars and one taxi are original source initialization. No mock
physical provider or empty gameplay callback replaces original decisions.

## Files and executed verification

- `tools/godot/npc_startup_source_vm.mjs` b991c6b37ed6af05a05c427552e3f09709bf4d0e1ee356bbd54bb5e9453c7e4c
- `tools/godot/npc_startup_named.mjs` 835213e4b4eabb97ffa0bd7a73aa571f19beb49895aec3486eaaa16286d10b65
- `tools/godot/npc_startup_traffic.mjs` 5921df2d8968d9e2b821fded6e1117f916c076cb9117f31a97ff64a27775bdbb
- `tools/godot/npc_startup_police_pets.mjs` 7590a10eced3a123a1ab1f62e1a1b5a80c1004710932f2cffe36876749afb7f3
- `tools/godot/export_npc_initial_placement_context.mjs` 02ae986c9aef924d4ec4c00c6c5da26c029c2436401a1fad7bd717d495ae4de3

The new VM loads every original classic NPC/ambulance module before the main
world declarations; original road-exit/agenda functions are present. Each
source receipt is checked against actual current source bytes. Observation
wrappers are separately labelled and invoke unchanged source functions.
Exact original world SHA9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5.

Producer runs two fresh complete VMs and requires exact equality. Component
checks:109 named,17 traffic and20 police/pets PASS. Independent third isolated
VM:1592 checks PASS, every raw object/alias/MAP/RNG/audit receipt compared.
Ten isolated malformed-config/source-drift cases reject with exit1 and no
admissible output. Review: `outputs/astra21_npc_full_startup_review/REVIEW.md`.
The full reviewer authored the police/pets helper earlier; this is independent
execution/source inspection, not independent authorship of that helper.
Additional independently authored police/pets peer review:7603 byte/offset,
closure, raw-context and RNG checks PASS. Report
`outputs/astra21_npc_full_startup_police_peer_review/REVIEW.md` SHA
8c574322b9950e9480a63f284b1a8fdb8e25da28f8a7edf424eefd58bece8591.
All30 stage and226 complete source receipts match original bytes; optional
prison/pedestrian targets are present. Earlier42540 original fresh-staff/RNG
checks are explicitly reused rather than relabelled as a new full-VM run.

Actual Godot4.7.2 headless native JSON/identity checks:1357PASS. The packet
decodes into326 raw dictionaries, preserving source coordinate conventions and
aliases. `outputs/astra21_npc_full_startup/NATIVE_JSON_RESULT.json` records CPU
parse p50/p95 14.993/16.150ms, max17.411ms,20samples. Parse once during startup;
do not reparse it per frame. If admission is triggered while playing, root
must stage or move decoding off the interactive main thread. This cost has
not been eliminated, and is not a loaded-scene FPS measurement.

Large698046 named-query records and full source byte/code/draw evidence remain
in sibling audit files, with hashes/counts in the receipt. Those files are
offline evidence and must not be loaded into an interactive update loop.
No content is removed to reduce the runtime context's decoding cost.

Reproduction:
`node tools/godot/export_npc_initial_placement_context.mjs --config outputs/astra21_npc_full_startup/config.json`

All dataset/descriptor IDs, source pending state, sourceHP and birth semantics
are preserved. GPU/LIVE, physical relocation, autonomous agenda, phone reports,
police authority, service merchants/stockrooms and full-city FPS remain open.
