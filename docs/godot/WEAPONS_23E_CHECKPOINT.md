# 23e: Walk reticle, softer UI, surface marks and current NPC shooting

30 September 2026. This checkpoint is a playable integration, not completion of
Walk migration or acceptance of the user's latest NPC physics requests.

The Q arsenal and contextual cards use a quieter graphite/ivory palette. Fourteen
weapon thumbnails were rebaked from the original models with neutral reflected
light; weapon materials and geometry were not recolored. The original Walk
center point and four dynamic crosshair arms replace the middot. Accuracy spread
includes movement, stance, aiming and firing. Sniper retains the original optic.
The connected-world initial camera distance is 5.119570294468082 m. Ordinary
RMB FOV38 is explicit user-requested stronger zoom; original Walk uses42.

Surface marks use four shared irregular core/bevel meshes at the original size,
lifetime, attachment and bounded72-slot capacity. Their normal material features
are assigned during configuration. A reproducible first-impact pipeline stall
was removed: the previous first mark took42.095 ms while SURFACE compilations
rose50→54; the updated first mark took5.716 ms with SURFACE52 unchanged. The
comparison used20 actual shots per build and no synthetic warmup hits or draws.

Cargo targeting now asks each original mesh for its shared triangle cache only
after its AABB intersects the ray, instead of cloning all car triangle buffers.
Geometry,268 occlusion parts, native collision and14-item capacity are preserved.
Mutation/replacement/freed-reference/singular-transform cases were checked.

Artist23's exact combined package adds local new-session damage from13 firearms,
including one aggregated transaction for a completed seven-pellet shot; bounded
blood and closed original eyes after final death. The projectile terminal queue
retains112 shared bullet/RPG slots and external RPG token retirement. NPC identity,
original source rigs and population preload remain intact. The export is a union
of selected resources and retains the original raw NPC receipt exporter.

## Evidence and limits

- Source oracle and actual player/camera/reticle:1784 checks; material art636;
  cargo lazy cache1770; normal preassignment303. These component checks are not
  full-scene FPS measurements.
- Compiled merged pack without project fallback:13 firearms×3 original rigs,
  743 checks. Actual input→muzzle/ammo→native impact→medical fall→final death:
  26 GPU checks and3 screenshots. This appearance fixture uses stationary NPCs,
  a QA observer camera and a deterministic source survival choice.
- Native camera/UI:17 screenshots and160 checks in visual07pack. Open original
  facade impacts:4 screenshots and80 checks in openmarks23e. A previous near-window
  fixture exposed physical-envelope/rendered-trim mismatch and was not accepted
  as a clear wall-art comparison. Original hit/HP/collision logic was not changed
  to hide it. Closed eyes have exact resource/lifecycle checks; a corpse facing
  away in the wide screenshot is not a close-up visual proof of its eyelids.
- Comparable compiled23c→23e,1280×720 Forward+,same3 NPC/8 buildings/377 collision
  bodies and shapes,14 cargo weapons100/100. p95 wall milliseconds: idle
  3.629→3.734; active AK5.767→5.772; full trunk5.722→5.526. GPU p95:2.298→2.312,
  2.887→2.882,3.144→3.127. Static memory reduced39.7–40.3 MiB. The rendering camera
  was matched for the benchmark; native camera behavior was checked separately.
  These are short-quarter results, not whole-city performance or post-hit
  ragdoll/blood-load acceptance. Exact approved14 NPC dependency changes were
  pinned; unknown source differences fail the comparator.

Final play export differs from the tested23e-check pack only in the five-item
user-facing update list, which explicitly identifies unfinished NPC work.
PCK SHA256:023070fe6b1895cfc7571d9bb402d5c324577f84cccf74a73ec823c9e963f2bc.
Build receipts accompany godot/mafiozi_walk/exports/win64/s01-20260930-quality23e-play.
Runtime revision:s01-20260930-quality23e. Current root shortcut points there.

## Still required

User's later requests remain open: persistent skinned bullet marks/cloth damage,
source ground blood, directional physical bullet impulse with lethal headshots,
natural reactions without sliding, and nudging corpses with the player's feet.
Source audit confirms the current4 temporary wound emitters are not the missing
24 persistent skinned marks. Source burst count already matches Walk; increasing
particles arbitrarily does not repair missing effects. Artist23 owns NPC changes;
root's optional player contact sampler is an outputs-only proposal, not enabled.
Actual final-dead NPC bodies remain physical; stop_preserve belongs to recovery,
not the active corpse path. No sleep or mask workaround has been enabled.

RPG blast damage, strong impulse, detached limbs, additional penetrating targets,
complete server/save/social authority, medical transport, cover/passenger firing
and full-world migration are not completed by this checkpoint. Preserve future
owner packages and do not replace them with this older frozen baseline.
