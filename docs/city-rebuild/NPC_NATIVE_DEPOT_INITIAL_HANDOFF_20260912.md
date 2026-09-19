# Native fire/tow depot and BUS initial admission — 2026-09-12

## Finding: actual depot entries do not exist

Current buildings_placement.v1.json contains no fire_station or junkyard instance. Its deferred records explicitly say:
- poi:firestation — planned_full_footprint_or_public_route_does_not_fit
- asset:fire_station — no_safe_district_frontage_fit
- poi:junkyard — no_semantically_matching_ready_model_bound

Therefore native fire/tow depots cannot honestly use a loaded authored entry today. No residential building or legacy coordinate was substituted. Architecture/placement files were not edited.

## Changes

`native_service_initial_source.js` is mirrored at NATIVE_SERVICE_INITIAL_START/END in world. It reads the actual current building placement (one async refresh at most each15s), resolves only explicit matching instance.entry.anchorRC, and waits otherwise. New native service fleet creation waits for bridge readiness and real entries, uses full-footprint clear road bays, checks spacing, and never repeats bay0 to fill missing slots. Existing serviceVehicles identities/positions remain intact.

BUS receives a one-time initial pose admission before its first native snapshot and driver assignment. The current pose is retained when physically clear. Otherwise only the never-presented BUS can choose a nearby clear road pose. Missing geometry waits without exposing it; already presented BUS is never relocated. Its subsequent driver/route adapter and existing passenger lifecycle are unchanged.

## Validation

PASS test_native_service_initial.mjs with actual topology and373 building/decor/detention collision bodies:
- missing fire/tow entries return waiting-for-authored-native-entry;
- no empty-bay stack/fallback and no mutation of an existing visible vehicle;
- actual BUS initial point r21.5,c15.5,angle0 is clear for conservative source halfLength1.65/halfWidth.65;
- BUS admission succeeds in1 frame (cold CPU1.276ms), then cached ready state avoids repeat scanning;
- already presented BUS cannot be relocated.

PASS existing ambient/fire/tow/BUS source tests and full world inline syntax. No GPU/FPS measurement. Generated environmental obstacles and dynamic scene layout were not instantiated by this CPU fixture. Native new fire/tow fleet intentionally remains waiting until actual depot entries are authored; this is not a claim of a completed physical depot.

## LIVE-discovered regression corrected

The initial bay replacement also matched _ensurePoliceResponseFleet and inserted `_nativeServiceBayAdmit(kind,bay)` where no `kind` variable exists. This caused a ReferenceError in dispatchEmergencyServices and aborted the world update. The police function's original bay lookup was restored with a function-scoped patch. Fire/tow admission now appears only once, inside _ensurePermanentServiceFleet.

Added actual _ensurePoliceResponseFleet VM smoke in native mode:3 vehicles created, original vehicle identity retained, second call does not duplicate fleet, and a deliberately throwing fire/tow hook is never called by police. Test and full inline syntax PASS. This corrects the earlier insufficient syntax-only coverage; root's next LIVE run remains required.
