# Weapon checkpoint v2 — read-only native PASS127

Actual accepted48 source remains unchanged: 486 pins. This is an isolated helper,
not a production save/load feature or authorization to restore owners.

`runs/native05`: 127 checks PASS, exit0/stderr0, 11.1413802 seconds.
Eight actual phases preserve all 14 item UIDs. Native TT input consumes exactly
one cartridge (896 → 895 total); capture retains the reduced magazine and shot
sequence. Native R starts a real reload; nonzero reloadRemaining roundtrips
before the real reload finishes. Subsequent ground drop/pickup/trunk store/take
retain the same UID partition and 895 cartridges. These phases use ordinary48
main, original player/three NPC/vehicle and native owner APIs plus engine input.

Capture now rejects pending LMB/R input before advance and a held trigger.
It does not consume, cancel or serialize a pending input as settled state.
Active projectiles and unresolved owner transactions remain rejected.

Codec corrections:

- Plaintext dictionaries cannot contain reserved `@f64` keys, including nested
  containers. The old codec collision and dictionary-to-float mutation are
  reproduced with the exact previous helper on the actual captured document.
- Integer values remain integers until validation. Integers outside the exact
  JSON-safe domain are rejected before any conversion to float.
- Plain depth16 and wire container depth17 agree, including the fractional
  float tag. The deepest admitted nested float roundtrips; one extra level fails.

Earlier v2 native01/02/03 retain one QA failure: dot assignment of a new `extra`
field created a StringName key, correctly rejected by the plain String-key
validator. Native04 uses explicit String keys and passes94 checks. Native05
adds the real spent-ammo/reload boundary and depth regression. No failed receipt
was overwritten. All per-run frozen helpers are preserved.

Capture observations in native05: 3.009–3.971 ms on the restricted two-CPU
headless lane. This is not a full-scene FPS/save-pause acceptance; capture is
event-bound and must not run per frame.

Limits: capture/codec/plan only, effects_applied=0, restore_authorized=false,
server_grants=0. Remaining TTL is relative to capture, not a restart clock.
Strict trusted-adoption validation of all fire fields and fresh owner binding
belong to the separate `coordinator27_weapon_restore49` implementation.
This helper does not touch real user save slots, credentials, server state,
NPC persistence, bank balances, businesses or world restoration.

Reproduction uses the existing private unchanged48 game:
`python -B outputs/coordinator27_weapon_checkpoint_v2/runner.py run --label FRESH_LABEL`.
Scheduler0194 is pinned; the original v1 game cache is read-only during this test.
