# Bounded registration guard — CPU PASS 11/11

Use this helper in a **new owner adapter** for the existing release48-style runner. Do not edit frozen runtime, scheduler, old runners or old receipts. It starts no engine, changes no scheduler state, and never stops an external process.

The observed failure is `outputs/coordinator26_frames45/runs/c4_release48_fast8_02/RUN.json`: graphical PID34324 was stopped by its owner at14.914s after NPC headless PID15936 appeared. The latter was accepted by the post-run inventory. In scheduler SHA `6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9`, `register_child()` performs a CIM query with timeout15s before publishing `children`. The old guard allows only one0.5s pause and a second inventory. This is an admission timing failure, not gameplay evidence.

`guard.py` waits **for registration**; it does not permit a pending process. Waiting is available only in a functional lane and only for the exact pinned engine, unambiguous `--headless --path`, and a matching already-issued empty headless lease whose direct parent PID+creation identity is still alive. Editor/import/export requires a write lease. Registry publication must subsequently match PID, creation time, exact command and executable; unknown process/no lease, parent or child identity change, duplicate editor/manager, failed inventory, disappearance before registration, timeout or perf mode fails closed. No PID-only exception or process-name allowlist is added.

The registry is read through its existing atomic JSON publication; the helper does not hold the scheduler mutex while the other owner registers. It retains the runner's exact editor/manager allowance. The owned process additionally requires its actual registered identity.

## Minimal owner integration

Load `guard.py` under a checked SHA using the runner's existing source loader. Install in the privately loaded runner globals, or construct `RegistrationGuard(globals(), ...)` in the new adapter. Preserve the existing pinned `SCHEDULE`, `ENGINE`, `EDITOR_COMMAND/TITLE`, `MANAGER_EXE/COMMAND/TITLE`, and `ACTIVE_MODE` values; the owner still verifies engine and source hashes.

```python
# Before source/inventory checks; run_name must not be __main__.
helper = load(GUARD_HELPER, GUARD_HELPER_SHA, "owner_registration_guard")
registration = helper["RegistrationGuard"](globals(), lambda: time.monotonic() + 16)
inventory, classify = registration.inventory, registration.classify

# At the EXISTING engine start timestamp, immediately before Popen:
started = time.monotonic()
registration.deadline = lambda: started + timeout

# Keep the original Popen -> lease.register_child -> bounded run unchanged.
# Before each final RUN write, including failures:
receipt["registration_guard_sha256"] = GUARD_HELPER_SHA
receipt["registration_waits"] = registration.events
```

For `runpy.run_path` owners, `helper["install"](runner_namespace, deadline_callback)` changes only the function globals of that private load and returns the same guard object. Bind its deadline at the existing start point as above. Its richer inventory adds `ParentProcessId` and `CreationFiletime` but keeps the old fields; preserve the actual rows in receipts. Do not renew the engine deadline on each poll or grant16s on top of the original watchdog. The wait ends at the earlier of that deadline and16s. Fresh CIM queries are individually capped at2s and the remaining budget. A failed wait remains `WAITING_FOR_REGISTRATION` in evidence; only a completed identity check changes it to `REGISTERED`.

## Frozen verification

`python outputs/coordinator27_test_scheduler/registration_guard/test_guard.py`

`CPU_RESULT.json` and `CPU_TESTS.log`: **11 tests, 0 errors, 0 failures, 23.497s**. Actual ordinary Python children and private real scheduler Lease/register_child exercise delayed publication, CIM identity, affinity2 and atomic registry writes. Negatives cover no-registration expiry, unchanged outer watchdog, no issued lease, reused parent/child creation identity, parent drift while waiting, child exit before publication, wrong project, perf refusal and import without write access. No Godot or GPU was started; this is not gameplay evidence. The scheduler source stayed unchanged.

- helper SHA: `512f0e65558b095f355e41e80fa716b183f64c733721d4fbb94dbb609edd19f7`
- test SHA: `12b825a95687ed3c31298fefbfa1f30aa8ceeb0752a1f37c7fa9a16fafd94a49`
- reviewed old capture adapter SHA: `c7cdb41e1075f6463b8f1f22eff2d294c2b619b8bc8d38fc17472001500adfd7`

This fixes the demonstrated private legacy guard path when owners adopt it; it does not change scheduler registration itself. F5 has an analogous short window: it reads inventory, then `Get-CurrentTestProcesses`, which can still precede publication. The launcher was deliberately not changed in this task. Perf continues to exclude other tests and the user's game; this helper supplies no performance acceptance.
