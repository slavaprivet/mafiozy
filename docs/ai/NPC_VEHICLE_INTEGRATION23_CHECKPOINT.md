# NPC vehicle integration checkpoint — 23 September 2026

This checkpoint connects the reviewed local vehicle incoming-fire, physical road
access, police detention routing, occupant explosion and seat-presentation work.
Authenticated explosion authority remains disabled; no server deployment occurs.

## Behavior

- Police fire at an occupied local fleet car uses the actual glass, body and
  passenger geometry. Fourteen local vehicle families are supported. Missing
  precise geometry blocks vehicle hits; ordinary on-foot perception remains live.
  Source-world car incoming damage is a separate, unapplied proposal.
- NPC lane access uses the issued route authority and physical parking surfaces.
  Player-driven source cars retain physical traversal independent of NPC lanes.
  Detention convoys follow their actual building access route, reverse segments
  and crossing controls, and cancel outstanding routes when their driver is lost.
- A local fleet explosion snapshots the player and physically seated crew before
  the existing death callbacks run. A receipt applies once per vehicle/life.
  Fatal crew state survives reload and ordinary medic revival is blocked until
  hospital discharge. Hospital/removal releases the physical seat; a later blast
  cannot damage that discharged remote occupant. Real local player death/recovery
  hooks also invalidate old-life receipts without depending on renderer sampling.
- Dead passengers keep a bounded seated pose until authoritative removal. Saved
  legacy poses remain compatible. Living and dead seat poses follow the complete
  car orientation, including pitch and roll, while preserving the source root.
- The QA vehicle selector retains the actual DOM select and lists the loaded fleet.

## Verification and limits

Portable tests exercise the actual source owners and tracked vehicle/character
models. They cover incoming loading and all fourteen car families, the current
three detention routes, canonical route cancellation, physical surfaces, fatal
save/reload, hospital/removal and seat reuse, old-life receipt rejection, cold and
warm seated corpses, legacy saved poses, and 1,640 seat-basis assertions.
Current road/parking fixtures are regenerated from tracked production inputs;
no test needs a snapshot from `outputs`.

Root's one browser tab confirmed the fixed fourteen-option selector, actual
hold-E entry and three crew boarding in Easton S. Previous Kingswell LIVE also
confirmed eight real defensive crew hits against an attacking officer. The new
explosion/hospital lifecycle and general-scene performance still require the
next LIVE run. CPU checks are not an FPS result.

The user's remaining weapon-visibility issue is reproducible: READY weapons
can be outside the window yet hidden by the passenger's large head from the
normal rear camera. An isolated pose improvement is still under review; this
checkpoint does not claim that silhouette issue fixed. Fire/tow native depot
anchors, source-car body damage and the service-shop activation remain separate.
