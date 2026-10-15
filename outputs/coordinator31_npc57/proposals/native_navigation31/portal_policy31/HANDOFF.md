# Concurrent doorway permissions — scoped native PASS

The old ledger granted the door only to queue[0] until the complete inbound room
arrival or physical exit. Native NPC passage exceptions could therefore work while
other visitors still waited artificially in PORTAL_WAIT. This patch permits every
reserved room holder to cross a doorway whose geometry is actually supported by
NpcPassage31. Unsupported venues retain the serial behavior.

Only three production candidates are supplied; restaurant visit and door source are
unchanged. Signatures of existing portal_request/release calls remain unchanged.
Registry.entry derives capability from the actual live Passage zone, and the
avoidance doorway hint uses the same portal_owner predicate as admission.

| Source | Exact accepted57 SHA256 | Candidate SHA256 |
|---|---|---|
| scripts/venues/npc_venue_capacity29.gd | eb5d09e0fef396e7619fef29ab60783b9f0775d0549db4605cddb98099b82e66 | d830ac4a76af0f50ff6fa36f47bae0eed9d6dfd24378ddb3aa09d49eda5bf55f |
| scripts/venues/npc_venue_registry29.gd | 234b2a336b4e7aa94789fc50b716da16b7422b3345b01b20a3254be7a72818a8 | eee16f8836df089a52fc6625938d38171de1a531c2702a2bcc00cd0bf9c33adf |
| scripts/navigation/npc_passage31.gd | 49ab9e218f37aac086dfe2fd3817f08b759cf2ecb1dc41091cce97c29a5b518e | 4fb0fa9f35fe030628e45a5802ca1ca12cae642f57a0ea6eff2697a25e73e4c9 |

`runs/candidate02` passes25 checks. Four real Visit controllers share the actual
compact shop. The first outgoing visitor remains under attention_hold, preserving
its room claim and physical position. The other outgoing visitor and two incoming
visitors finish their native entry/exit cycles in8.7667 simulated seconds and8.7610
wall seconds. Maximum concurrent portal owners4; opposing capsule centres approach
to0.001609m; maximum native step0.030775m. No teleport, collision-mask change or
synthetic account completion occurs. Physics60Hz and context checks pass.

The matched `runs/baseline02` is an expected clean failure: only one owner, zero of
the other three complete or enter after15seconds. Both runs use identical SOURCE
and HARNESS, archived exact scripts, registered scheduler children, exit0, stderr0
and zero source/harness/control drift. Baseline errors are semantic, not parse or
runtime errors. `candidate01` is preserved as an invalid setup: one paused actor
initially occupied another room's destination; candidate02 places the already-inside
actors at their own measured distinct room slots before starting the experiment.

Additional native checks preserve four room slots with a fifth client waiting,
cross-venue rejection, portal-release without room-release, release promotion,
single-cashier FIFO, serial unsupported venues, lifecycle cleanup and venue closure.
Payments and medical authority are not touched. Their full service regressions still
belong in the integrated acceptance run.

Root integration: verify each target against the base SHA, apply only these three
files or CHANGE.patch into the new candidate, then combine with the independent
QA restaurant/door fix. Do not copy to frozen57. Run services/doorway/attention and
the extended first10+12 soak before release. Performance remains unaccepted here.

This patch does not solve a roaming NPC physically blocking the door leaf arc; the
QA owner is handling that separately. It also retains the existing centre-zone
boundary and32-member cap. See the parent package's PASSAGE_POLICY_AUDIT.md. Do not
merge the RVO prototype or unrelated micro-optimization proposals into this fix.
