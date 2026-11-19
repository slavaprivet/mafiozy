NON-BLOCKER — for this castle junction fix only, not for 50x50/100-actor acceptance.

The 0.10m floor overlap and 4.86cm deck overlap appear intentional, measured closing overlaps rather than accidental collision/support regressions. Architecture support, pass2 support, single-brick destruction, gate breach, and zero basis-axis leak all passing covers the main support/collision risks. Disabling random visual jitter for walk/parapet/gate-bypass groups improves mesh-to-axis-aligned-collision agreement. No added cells, materials, buckets, or draw calls, and three stable GTX980 runs support release of this specific fix.

Residual validation: explicitly check the eight widened junctions and 112 deck seams for coplanar z-fighting at near/mid distances and oblique angles. Close shots show continuity but do not by themselves prove no z-fighting. Also confirm overlapped cells are not double-counted by support/damage logic. If those visual/support checks are clean, release this junction fix.

Do not treat this as 50x50 acceptance: no 100-actor benchmark exists, so broader scale/performance acceptance remains unproven.