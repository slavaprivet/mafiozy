# Native vehicle navigation: actual road/stop CPU audit — 2026-09-12

Scope: npc_vehicle_navigation.mjs only; no walk hospital entry edits, no GPU. Tests load current topology_for_placement, buildings_placement.v1, decor_placement.v1, detention_native_sites.v1 and detention_destinations.v1. 373 authored collision bodies are passed through production createCarWorld/carFits at4.1m/source tile. Sedan/interceptor/ambulance GLBs are parsed and built with createArtistVehicle, so footprint sizes are the actual adapted model profiles, not guessed source-model sizes.

## Routes and result

12 simultaneous fixed-order requests: each of3 vehicle profiles to the3 registry detention stops and a clear ambulance bay at the actual hospital's authored entry.roadProbeRC (r5.8414634146,c164,angle0). Three clear starts near each destination are found on actual roadMask, then one is assigned to each vehicle model.

All12 routes READY. Every returned edge is re-swept against actual static bodies. Explicit test asserts no later request waits8frames to get first work.

Before:18frames total; last request first serviced frame17. CPU update p50 3.2214ms, p95/max3.6873ms.
After final rerun:22frames total; last request first serviced frame3. CPU p50 2.9904ms, p95 3.3639ms,max3.6824ms. Another after run had a7.928ms outlier; time budget is soft at one collision expansion granularity and JS/GC scheduling can exceed it. These short CPU batches are not warmed scene FPS acceptance. Fair service is improved at the cost of a few extra frames until the entire queue finishes.

Machine-readable report: outputs/npc_native_vehicle_route_audit_20260912.json.

## Concrete fixes and regression

- Route cache key now isolates source carId, requestId, exact origin/heading and destination/heading. Changing source origin or using another service's identical requestId cannot return an earlier path.
- Road-target cache includes min/max radius, heading and actual shape. minDistance:0/maxDistance:0 are respected (previous Math.max/|| silently changed them to2–3/40).
- Four short route slices are selected by least-recent service at beginFrame. lastRequested excludes abandoned pending jobs so they cannot retain slots indefinitely. Total shared budget remains3ms; a single atomic collision expansion can overshoot.
- Target scans also receive at most one quarter budget per call, retaining shared total accounting.

PASS test_npc_vehicle_navigation_cache.mjs (changed radius/origin/car; exact service_ and city_bus self exclusion; other vehicle collision). PASS original test_npc_vehicle_navigation.mjs (water/solids/detour/stale path dynamicblockade). PASS actual route audit and existing actual carCanGo native-vs-legacy regression from ambient test.

## Limits

Generated forest/environment/fence colliders, moving rail, loaded buildings' interactive door state, and dynamic vehicle-scene population are not instantiated by this bounded CPU test. Landscape water is supplied, but these tested routes stay within the city; native topology water is rejected by createCarWorld surface and verified separately in helper tests. Hospital parking-to-door stretcher corridor and actual door entry are root's separate hook/QA, not proved by this road-bay routing result. No full-scene FPS claim.
