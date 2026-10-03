# Private local weapon restore 49

Accepted48 source: 486 pinned files. This candidate restores only the coherent local weapon domain: inventory, finite fire state, item identity, ground drops and vehicle cargo. It is not migration of NPC/player HP, economy, server ownership or all transport state. No production/user storage is touched.

The parent test service captures from a trusted native child, pins the resulting bytes, exits that process, and grants a single attempt in a fresh child. The JSON document cannot mint a capability. The coordinator binds its opaque capability by object identity to fresh owner instances; a grant is consumed before prepare and cannot be replayed. Parent attempt ledger rejects a second adoption of the same grant. Local disk rollback outside this private parent process is not solved and cannot be presented as server acknowledgement.

Startup uses a staged, hidden, disabled scene. Resume binds the saved logical session and actor/vehicle life references to fresh native bodies without invoking the new-session vehicle factory or minting the default arsenal. Owners prepare all data and presentation before a synchronous, non-yielding commit. Failure leaves inventory/cargo unadopted and the staged scene unpublished. JSON validation and source pins precede scene creation.

Clock policy: LOCAL OFFLINE FREEZE. Inventory runs on a local simulation millisecond clock resumed at capture time; downtime does not consume ground TTL, cooldown or reload duration. Original deadlines are preserved in this explicit clock domain. This is not wall time, server time, or a rewarded offline simulation. Pending input, shots, explosives, transfers and non-on-foot ownership require reconciliation and are rejected.

Missing APIs are implemented only in private copies of weapon_inventory.gd, preview_weapons.gd, preview_transport.gd and transport_trunk_cargo_store.gd. Parent approved private owner changes after notifying transport owner. The checkpoint v2 helper is copied with its SHA and only adapted to the explicit local clock domain. No configure/equip normalization is used to adopt weapon state.
