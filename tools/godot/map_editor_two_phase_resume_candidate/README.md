# Editor exit v2 candidate — source only, not integrated

`two_phase_resume.gd` refuses to exit with the current main, population and
navigation APIs. It requires exact paused receipts, neutral input, and a new
composite owner API; the current `pause_workspace.gd` has no such API. No
production file is changed. No Godot import, native run or LIVE check has run.

Why this is necessary: the current `PreviewPopulation.end_editor_pause` checks
resident, policy and nav `can_end_editor_pause` only after the tree is
unpaused. It then releases navigation, policy, residents in sequence. The
navigation host releases its queue before its backend; the backend can still
refuse late. `pause_workspace._resume_gameplay` resumes the melee clock before
unpausing. If a later owner refuses, gameplay may be partially resumed. Merely
calling every `can_end` first is not atomic: leases can change between calls,
and a preflight does not reserve an infallible commit. Existing `can_end`
requires the tree unpaused, so it is not an adequate paused preflight.

The root owner must add `editor_resume_contract_version() -> int` returning 2,
`prepare_editor_resume_atomic(main_receipt, population, population_receipt,
document, ground) -> Dictionary`, `abort_editor_resume_atomic(ticket) ->
Dictionary`, `commit_editor_resume_atomic(ticket,
main_receipt, population_receipt, document, ground) -> Dictionary`, and
`editor_resume_postcondition(ticket) -> bool`. The prepare call must be
read-only, pin exact identities and mutation revisions, reserve all component
commit capabilities and fail before any release. Abort must revoke that
reservation without releasing an editor lease. The commit must synchronously
release all owners while keeping callback replay and physics blocked, switch
the tree to live only when *all* components are committed, then drain deferred
callbacks in a guaranteed no-fail phase or with a rollback journal. A late
refusal (including nav backend after queue release) must either restore **all**
owners exactly or remain terminal HOLD without running gameplay. A mere version
method or optimistic `ok` return is not proof of that owner implementation.

Before connecting K, the owner needs true monotonic revisions/write leases for
resident bodies/queue and interior door commands: current-state comparison
misses an A→B→A mutation. The full default population and all gameplay owners,
not only the three-resident fixture, need receipts. Then native negative tests
must inject refusal at every release boundary and prove no tick, callback,
clock, resident or navigation work leaks through; perform one owner-coordinated
LIVE/performance pass afterward. This candidate deliberately fails closed
until those APIs and proofs exist.
