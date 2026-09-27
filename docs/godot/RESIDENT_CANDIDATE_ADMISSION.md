# Resident placement consumer

Root-owned `preview_resident_host.gd` now accepts completed source placement
proposals separately from the immutable accepted birth packet. This removes the
old integration limitation where every retry used the same raw birth r/c.

Call `bind_placement_source(receipt, current_validator)` once before any actor is
admitted. The receipt pins full-context/source/session/phase and BODY provider.
The trusted in-process validator receives a private event copy, raw source ID and
life generation. It must prove the complete 326-row solve, exact object-key/raw-ID
association, delivered candidate and current source/scene/provider leases.
Receipt strings alone cannot establish those conditions. After binding,
`admit_next()` cannot bypass the solver by reverting to raw birth coordinates.

`admit_candidate(event, life_generation)` accepts only original/relocated
resident events with physical_admission=false. Final coordinate conversion is
r/c float64 to scene metres, once. It retains source ID, separate bridge ID,
descriptor, heading, HP/birth fields and owner generation. It invokes current
source access plus five-point support and full-body overlap checks; loading an
appearance grants no permission to skip final revalidation. The aggregate lease
validator runs after the last source-access callback, so that callback cannot
revoke the captured placement lease and still commit a spawn. A live actor cannot
be duplicated or relocated through this startup method. Diagnostic route-clear
commands in the source event are never executed against live routes.

Callback reentry is denied. A dispose requested inside a callback invalidates
admission and completes after the outer operation unwinds. Queued/departed
scenes cannot receive a new actor. Freed bodies are handled in diagnostics.

Author test `scripts/tests/test_resident_candidate_admission.gd` uses an explicit
TEST_ONLY completed-placement validator with actual source identities/models
and actual main native support/overlap. It proves consumer behavior, not that the
real full-source provider is ready. Existing host73 checks and new consumer28
checks pass headlessly. Independent adversarial review passes83 checks on final
host0aae0402, including actual scene deletion/queued deletion, disposal inside a
callback, stale life/provider, candidate copying and late source revocation.

Default population remains disabled. Actual placement solver/BODY provider,
complete current primitive evidence and full batch validation must be wired by
the population coordinator before NPCs can become playable. The frozen BODY
helper's reproduced JS whitespace discrepancy is fixed in candidate0a7dadd9:
root rerun of the original independent66 checks passes. Real source pedestrian
cache/provider extraction is still under way. No synthetic all-clear callback
is installed in main.
