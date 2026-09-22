# Durable robbery receipts — checkpoint validation

2026-09-23. **READY: helper contract tests, 17 PASS.**

Added `test_npc_robbery_receipts23.py`. No production changes. Run from repo root:

```text
python -B -m unittest -v test_npc_robbery_receipts23
```

Observed: 17 tests passed in 3.684 seconds, Python 3.14.4, real aiosqlite and
SQLite using a unique shared-memory URI per test. SQLite `PRAGMA database_list`
confirms an empty filename, including the separate reconnect connection.
The only imported project module is `npc_robbery_receipts`; the suite asserts
that neither backend module was imported. No real database, credentials,
backend startup, or network was accessed.

Verified behavioral contracts:

- Additive migration preserves legacy status/cooldown and money; repeated
  migration is unchanged. Threat-only slots retain cooldown without becoming
  robbery payout receipts. Terminal legacy cases do not reopen.
- Duplicate `begin` before/at/after cooldown never pays again or rewrites
  original amount, arrest decision, coordinates, created time or cash receipt.
  Replay returns current account cash separately from historical `cash_after`.
- A legal second robbery of the same NPC at cooldown expiry preserves R1;
  late report/replay/confiscation of R1 does not overwrite R2's current slot.
- Cross-NPC reuse of an ID is rejected; identical IDs for different UIDs remain
  isolated. One player's report/confiscation does not change another player.
- Active cases survive connection replacement, filter terminal/unreported
  cases, preserve coordinates, sort by creation time and respect limits.
- Report retries retain wanted level; reports and begin retries cannot reopen
  released/bribed/confiscated receipts or add wanted stars for terminal cases.
- Confiscation debits once and cannot make cash negative. Release requires an
  active, non-arrest case and cannot succeed twice.
- `bribe_latest` resolves the latest active case, excludes unreported/other-UID
  cases and preserves already closed receipt metadata. Once none remain,
  another invocation is a no-op.
- Nonfinite/invalid crime coordinates become NULL; finite signed values remain.
- Real SQLite trigger failures after intermediate writes roll back payout,
  cooldown slot, case states and cash. Retry works after the injected failure
  is removed. A caller failure after successful helper work also rolls back,
  demonstrating that the helper does not commit behind its caller.

Limits: this validates the helper with caller-owned transactions and trusted
server inputs. It does not validate WebSocket authentication, packet admission,
the preview backend, live deployment/migration, or the real account database.
Wanted-level decrease after release/bribe is owned by the caller. The helper
`bribe_latest` has no command ID: with multiple active cases, another call
resolves the next active case. These tests do not claim whole-command replay
idempotency for a repeated bribe network packet. Preview repeated-resolve fixes
remain owned by Checker2; this task did not edit those files.

Audited SHA-256:

```text
01ef45d78576f8b9537bbb4deffc764dd863104ee97f580cf8647c6b2a1a0aa6  npc_robbery_receipts.py
4d6be0531f44cdfb984f5d6122cb25ec4422473b3fc6b360ee7eea3a3b3fa815  test_npc_robbery_receipts23.py
```

Include the new test and this handoff with the receipt helper checkpoint.
The previously reported absence of direct helper tests is resolved for the
above source hash; the separate LIVE/server integration limits remain.
