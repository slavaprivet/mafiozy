# Dent copy-ownership experiment — PERFORMANCE REJECTED

Frozen candidate f565b993324f10f19fe6643d541e963fcc0f35b86007d998c57507ab6a89af31.
Production883a4559 remains byte-identical. Exact files in accompanying MANIFEST.
88author+88parent source/lifecycle/prepared cost PASS; independent19+parent19
finite/transaction/private buffer checks PASS. All vertices and finite guards retained.

Final experiment only eliminates redundant copies: output positions have sole
caller ownership and are not retained by provider; private pending base/offset
move into committed ownership, while caller receives duplicates. Source Float32,
private token/abort/reset and malformed/outside/last-vertex safeguards preserved.
Full loop fusion was rejected and not retained: author sequential actual p95
16.139->19.981ms and90k108.058->137.814ms, despite exact parity.

Parent sequential same-prepared geometry,8warm+32samples each, v0163/25752vertices:
baseline p50/p9515.951/18.351ms; candidate16.152/17.494ms.
90k all-inside baseline98.251/104.502ms; candidate99.326/109.368ms.
Author order-swapped repeats showed actual p50 4.8–7.2%/p95 7.4–11.3% reductions,
but independent parent median/max-size regressions mean no stable gain claim.
Parent candidate-only actual p9516.487ms,90k116.849ms. These are pure position
stage+commit costs, excluding normal/bounds/sphere/upload/hulls/preparation.
No full-sceneFPS/aggregateCPU/combined worker qualification or main/LIVE adoption.

Status PERFORMANCE REJECTED / DO NOT ADOPT. Root seam and token limitations
remain TRANSPORT_LOCAL_DENT_HANDOFF.md: actual committed geometry must be verified
by host; opaque token alone proves private stage identity. No WorkerThreadPool in
this candidate, so do not attribute its CPU cost to global pool contention.
No geometry cuts, event deferral, foreign runtime, Git or GPU changes.
