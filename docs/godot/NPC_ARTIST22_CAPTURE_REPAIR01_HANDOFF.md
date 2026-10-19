# Artist22 capture repair 01 — actual run01 failure

Root22's run01 `outputs/coordinator22_source_capture/run01/RUN.json` is an
immutable failed diagnostic. Thirteen original HTTP probes matched source bytes;
the browser fulfilled `/walk`, `walk_entry.mjs`, and transformed `world.html`.
The runner then polled the `/walk` JavaScript context while its original
`location.replace()` was switching to `/world.html`. `page.evaluate` failed with
`Execution context was destroyed`; the collector had zero events. The resulting
status is `CAPTURE_INCOMPLETE_HOLD`, with no roster/frame/NPC result.

The browser parent exited after ownership-gated kill. The source server did not:
the old identity marker was a Cyrillic-containing absolute path, while Windows
PowerShell output decoded it into replacement characters. Independent Root22
process inspection stopped only that owned server and restored the sole checked
game as PID17312. The old GO has expired and cannot authorize another run.

## Exact repair

`tools/godot/capture_npc_unpaused.mjs` now waits for the one expected original
same-origin transition `/walk` →
`/world.html?direct=1&previewcity=1&render=3d&renderer=walk` through
`DOMContentLoaded` before reading the collector. It records every main-frame
document URL and requires exactly those two URLs. A third navigation, alternate
query, foreign origin or wrong final URL stops as HOLD. The transformed world
response must be fulfilled exactly once with its reviewed SHA. The final world's
own collector must exist, be unsealed and fault-free. Subsequent polling and
snapshot recheck the document history, so a reload cannot turn a new collector
into apparent continuation of the old registration.

The original source monitor's ownership marker is now the ASCII command segment
`city_rebuild_monitor.py --port 18538`, which remains visible even if PowerShell
misdecodes non-ASCII path characters. Cleanup is a shared production function;
an error or unconfirmed parent exit downgrades final status to HOLD. Root still
must independently inventory browser descendants before restoring the game.

The observed original source, 13 response routes, collector, transformer, reader,
static source data, NPC component pins and native game are unchanged. The new
runner hash creates a distinct canonical plan and requires a **new Root22 GO**.
Preparation alone opens no HTTP, browser, GPU, server, or game.

## Checks and new profile

New `outputs/artist22_unpaused_profile_fix01/PLAN.json` is the only reviewed GO
target after this repair. Its canonical SHA and all exact files are in
`outputs/artist22_capture_repair/RECEIPT.json`. CPU checks:

- 11 route/source-entry checks against the real original `walk_entry.mjs`,
  including wrong origin/query/reload and missing second document.
- 51 independent runner guards rerun against the repaired runner.
- 54 separate independent navigation/cleanup and saved run01 identity checks.
- 7 checks in a real CLI CPU test: start the original Python monitor on isolated
  port19139, serve its actual Walk page, inject a failure, run the same production
  cleanup function, verify the ownership-gated Windows tree kill and child exit.

This tests the navigation rule and failed-server cleanup, not Chrome/Playwright
runtime or the full source boot. Run01 remains the negative browser evidence.
The next source capture can start only in Root22's next sequential GPU window.

## Minimum for visible residents

The current observer records naturally visited primitive registration, placement
and query events. Its roster is pre-queue placement rows, without a complete birth
record, source appearance, current HP/agenda, finished all-326 placement or all
current dynamic colliders. It cannot alone satisfy
`npc_preview_source_provider.gd`/`preview_resident_host.gd` admission.

For the existing bounded three-resident host, Root needs a complete and independently
bound source session packet: original resident birth counts and exact IDs/raw rows,
bridge IDs/look/descriptors and full roster hash; current session/clock/RNG boundary;
all-326 registered placement completion with source-order positions; exact source
ground, body, water, rail, fleet, logical and mercenary state used by visited
admission queries; and a current owner/generation, support/physical-clear lease.
The host already checks source ID and visual ownership, support rays/shape overlap,
route admission and disposal. Root owns its main hookup, navigation pump, renderer,
single game and LIVE cost. Missing source state stays HOLD; frozen a05ad startup is
an offline static prerequisite and cannot be renamed as this new session.

Even a successful repaired diagnostic capture proves only its observed values.
Server authority, real player saves, combat/HP and city FPS remain separate gates.
