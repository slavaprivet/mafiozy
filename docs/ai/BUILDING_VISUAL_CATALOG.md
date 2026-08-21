# Authoritative 3D building visual catalog

Source of truth: `three_preview.js` on GitHub `main` at the start of each slice.
Collision, doors and interaction anchors remain authoritative in `world.html`.

## Generic archetypes

| Family | District pools | Existing roof form | Slice 1 status |
|---|---|---|---|
| `brick` | poor, industrial, countryside, Chinatown, downtown/rich fallback | hipped masonry | upgraded: corbel sills, lintels, corner quoins, parapet |
| `limestone` | downtown, rich, coast, countryside, Chinatown | classical crown | upgraded: pediments, deep sills, quoins, balustrade |
| `glass` | downtown, nightlife, rich, coast | terraced glass | upgraded: shadow-box glazing, mullions, roof screen |
| `concrete` | every urban pool | mechanical step | queued |
| `deco` | downtown, nightlife, rich, coast, Chinatown | deco tiers | queued |
| `industrial` | industrial, docks, poor fallback | sawtooth plant | queued |

The deterministic `architectureFamilyPools` mapping chooses a generic family.
The `buildingVisualProfileCatalog` is the authoritative visual profile table.

## Authored landmarks

Bank, jail/police complex, lair, mafia HQ, mansion, hospital, fire station,
casino, market, factory, gas stations, race track, port and black markets use
their own landmark/themed builders. Generic slices must not replace them.

## Fixed business skins

`coffee`, `carwash`, `barbershop`, `pizza`, `garage`, `bar`, `club`,
`warehouse`, `casino` and `port` use `businessExteriorSpecs` plus their
authored exterior details. Converted holdings remain driven by persisted
`operation_type`; generic archetype work must not infer or rewrite purpose.

## Budget contract

Slice 1 adds build-time static geometry only for `brick`, `limestone` and
`glass`. The existing spatial merge consumes it. It adds no frame allocations,
frame scans, lights or materials and does not change collision footprints,
roads, doors, POIs, shadows, rain or circadian lighting authority.
