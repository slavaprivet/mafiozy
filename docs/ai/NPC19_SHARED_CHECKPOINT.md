# Shared development checkpoint — 20 September 2026

Requested by the user so the five Astra chats can inspect the current game
instead of the older GitHub main from 10 September (`3442bf0`). This is a
development source checkpoint, not acceptance of the completed living city.

Canonical project: shared Desktop/Мафиози, served on localhost18538. See
NPC19_TEAM_BOARD.md for current authors, scopes and integration protocol.
Do not overwrite shared files with an older worktree or assume an agent chat
has filesystem access from a pathname. Supply the exact commit and relevant
source excerpts. Report findings against that revision.

## Included state

Current integrated city/character/vehicle/interior modules and their local
dependencies, NPC activity agenda and capacity reservations, physical route
search, source transport and existing crime/police/boss systems. Latest NPC19
changes include fair route cohorts, lazy native wander, optional-activity
ownership and continued pending boss route searches. Transport includes
parking preflight and the assigned-car final-door approach correction.

The performance instrumentation separates health sync, player HUD and
mercenary updates. It does not itself improve frame rate. The proposed
visibility-only picking experiment is not integrated and is excluded.

The separate b60d robbery/cash/phone package is NOT in this checkpoint. Its
author confirmed no shared edits yet; it requires a later addressed merge.
Databases, credentials, local conversation exports, screenshots and bulky
generated analysis dumps are not part of this publication.

## Evidence and remaining work

See NPC_ROUTE_COHORT19_HANDOFF.md, NPC_WANDER_LAZY19_HANDOFF.md,
NPC_ACTIVITY_OWNERSHIP19_HANDOFF.md and NPC_EMPIRE_WALK_AUDIT19.md for scoped
tests and limitations. Root observed the first route/transport package in the
real browser: actual walking animation, purchases and vehicle boarding/driving.
Long waits still occur, and the city is NOT accepted as complete.

The later boss pending, activity ownership and final vehicle approach fixes
passed source tests but still require the next browser reload and observation.
Boss target/HQ mapping from old World coordinates remains a separate issue.
Authenticated crime/server integration and all-world police behavior are not
proven by the offline preview. Overall scene performance remains poor and is
being diagnosed; uncontrolled GPU activity prevents a clean FPS A/B claim.
