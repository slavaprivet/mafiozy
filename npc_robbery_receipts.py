"""Durable immutable receipts for civilian NPC robberies.

The legacy npc_robberies row remains the per-NPC cooldown slot.  This additive
ledger owns idempotency across later legal cycles, reports and reconnects.
"""

import math


ACTIVE_STATUSES = ('unreported', 'active')


def _coordinate(value):
    try:
        value = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return value if math.isfinite(value) else None


def _receipt(row):
    if not row:
        return None
    return {
        'npc_id': str(row[0]), 'robbery_id': str(row[1]), 'amount': int(row[2]),
        'cooldown_until': int(row[3]), 'interrogation_arrest': bool(row[4]),
        'status': str(row[5]), 'created_at': int(row[6]), 'resolved_at': int(row[7]),
        'crime_r': None if row[8] is None else float(row[8]),
        'crime_c': None if row[9] is None else float(row[9]),
        'cash_after': None if row[10] is None else int(row[10]),
    }


async def ensure_schema(db):
    await db.execute("""
        CREATE TABLE IF NOT EXISTS npc_robbery_receipts (
            uid INTEGER NOT NULL,
            robbery_id TEXT NOT NULL,
            npc_id TEXT NOT NULL,
            amount INTEGER NOT NULL,
            cooldown_until INTEGER NOT NULL,
            interrogation_arrest INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'unreported',
            created_at INTEGER NOT NULL,
            resolved_at INTEGER NOT NULL DEFAULT 0,
            crime_r REAL,
            crime_c REAL,
            cash_after INTEGER,
            PRIMARY KEY (uid, robbery_id)
        )
    """)
    await db.execute(
        "CREATE INDEX IF NOT EXISTS ix_npc_robbery_receipts_active "
        "ON npc_robbery_receipts(uid,status,created_at DESC)")
    # Existing installs retain their current case/cooldown state. Historical
    # rows cannot recover old coordinates, so migration leaves them NULL.
    await db.execute("""
        INSERT OR IGNORE INTO npc_robbery_receipts(
            uid,robbery_id,npc_id,amount,cooldown_until,interrogation_arrest,
            status,created_at,resolved_at,crime_r,crime_c,cash_after)
        SELECT uid,robbery_id,npc_id,amount,cooldown_until,interrogation_arrest,
               status,created_at,resolved_at,NULL,NULL,NULL
          FROM npc_robberies
         WHERE status NOT LIKE 'threatened_%'
    """)


async def _get(db, uid, robbery_id):
    row = await (await db.execute(
        "SELECT npc_id,robbery_id,amount,cooldown_until,interrogation_arrest,"
        "status,created_at,resolved_at,crime_r,crime_c,cash_after "
        "FROM npc_robbery_receipts WHERE uid=? AND robbery_id=?",
        (int(uid), str(robbery_id)))).fetchone()
    return _receipt(row)


async def begin(db, *, uid, npc_id, robbery_id, amount, cooldown_until,
                interrogation_arrest, created_at, crime_r, crime_c):
    """Create one payout or replay its immutable receipt inside a transaction."""
    old = await _get(db, uid, robbery_id)
    if old:
        if old['npc_id'] != str(npc_id):
            return {'ok': False, 'reason': 'id_conflict',
                    'robbery_id': str(robbery_id), 'npc_id': str(npc_id)}
        cash_row = await (await db.execute(
            "SELECT cash FROM characters WHERE telegram_id=?", (int(uid),))).fetchone()
        return {**old, 'ok': True, 'replayed': True,
                'cash': int((cash_row or [old['cash_after'] or 0])[0] or 0)}
    slot = await (await db.execute(
        "SELECT cooldown_until FROM npc_robberies WHERE uid=? AND npc_id=?",
        (int(uid), str(npc_id)))).fetchone()
    slot_until = int((slot or [0])[0] or 0)
    if slot_until > int(created_at):
        return {'ok': False, 'reason': 'cooldown', 'robbery_id': str(robbery_id),
                'npc_id': str(npc_id), 'cooldown_until': slot_until}
    crime_r, crime_c = _coordinate(crime_r), _coordinate(crime_c)
    await db.execute(
        "INSERT INTO npc_robberies(uid,npc_id,robbery_id,amount,cooldown_until,"
        "interrogation_arrest,status,created_at,resolved_at) VALUES(?,?,?,?,?,?,'unreported',?,0) "
        "ON CONFLICT(uid,npc_id) DO UPDATE SET robbery_id=excluded.robbery_id,"
        "amount=excluded.amount,cooldown_until=excluded.cooldown_until,"
        "interrogation_arrest=excluded.interrogation_arrest,status='unreported',"
        "created_at=excluded.created_at,resolved_at=0",
        (int(uid), str(npc_id), str(robbery_id), int(amount), int(cooldown_until),
         1 if interrogation_arrest else 0, int(created_at)))
    await db.execute("UPDATE characters SET cash=cash+? WHERE telegram_id=?",
                     (int(amount), int(uid)))
    cash_row = await (await db.execute(
        "SELECT cash FROM characters WHERE telegram_id=?", (int(uid),))).fetchone()
    cash = int((cash_row or [0])[0] or 0)
    await db.execute(
        "INSERT INTO npc_robbery_receipts(uid,robbery_id,npc_id,amount,cooldown_until,"
        "interrogation_arrest,status,created_at,resolved_at,crime_r,crime_c,cash_after) "
        "VALUES(?,?,?,?,?,?,'unreported',?,0,?,?,?)",
        (int(uid), str(robbery_id), str(npc_id), int(amount), int(cooldown_until),
         1 if interrogation_arrest else 0, int(created_at), crime_r, crime_c, cash))
    return {'ok': True, 'replayed': False, 'npc_id': str(npc_id),
            'robbery_id': str(robbery_id), 'amount': int(amount),
            'cash': cash, 'cooldown_until': int(cooldown_until),
            'interrogation_arrest': bool(interrogation_arrest),
            'status': 'unreported', 'created_at': int(created_at), 'resolved_at': 0,
            'crime_r': crime_r, 'crime_c': crime_c, 'cash_after': cash}


async def report(db, *, uid, robbery_id):
    receipt = await _get(db, uid, robbery_id)
    if not receipt:
        return None
    if receipt['status'] not in ACTIVE_STATUSES:
        return {**receipt, 'case_active': False, 'replayed': True}
    replayed = receipt['status'] == 'active'
    if receipt['status'] == 'unreported':
        await db.execute(
            "UPDATE npc_robbery_receipts SET status='active' WHERE uid=? AND robbery_id=? AND status='unreported'",
            (int(uid), str(robbery_id)))
        await db.execute(
            "UPDATE npc_robberies SET status='active' WHERE uid=? AND robbery_id=? AND status='unreported'",
            (int(uid), str(robbery_id)))
        receipt['status'] = 'active'
    await db.execute(
        "UPDATE characters SET wanted_stars=MAX(1,COALESCE(wanted_stars,0)) WHERE telegram_id=?",
        (int(uid),))
    return {**receipt, 'case_active': True, 'replayed': replayed}


async def active(db, uid, limit=5):
    rows = await (await db.execute(
        "SELECT npc_id,robbery_id,amount,cooldown_until,interrogation_arrest,"
        "status,created_at,resolved_at,crime_r,crime_c,cash_after "
        "FROM npc_robbery_receipts WHERE uid=? AND status='active' "
        "ORDER BY created_at DESC LIMIT ?", (int(uid), int(limit)))).fetchall()
    return [_receipt(row) for row in rows]


async def confiscate(db, *, uid, robbery_id, resolved_at):
    receipt = await _get(db, uid, robbery_id)
    if not receipt or receipt['status'] != 'active':
        return None
    amount = max(0, min(10, int(receipt['amount'])))
    await db.execute("UPDATE characters SET cash=MAX(0,cash-?) WHERE telegram_id=?",
                     (amount, int(uid)))
    await db.execute(
        "UPDATE npc_robbery_receipts SET status='confiscated',resolved_at=? "
        "WHERE uid=? AND robbery_id=? AND status='active'",
        (int(resolved_at), int(uid), str(robbery_id)))
    await db.execute(
        "UPDATE npc_robberies SET status='confiscated',resolved_at=? "
        "WHERE uid=? AND robbery_id=? AND status='active'",
        (int(resolved_at), int(uid), str(robbery_id)))
    cash_row = await (await db.execute(
        "SELECT cash FROM characters WHERE telegram_id=?", (int(uid),))).fetchone()
    return {**receipt, 'status': 'confiscated', 'amount': amount,
            'cash': int((cash_row or [0])[0] or 0)}


async def resolve_released(db, *, uid, robbery_id, resolved_at):
    receipt = await _get(db, uid, robbery_id)
    if not receipt or receipt['status'] != 'active' or receipt['interrogation_arrest']:
        return False
    cur = await db.execute(
        "UPDATE npc_robbery_receipts SET status='released',resolved_at=? "
        "WHERE uid=? AND robbery_id=? AND status='active' AND interrogation_arrest=0",
        (int(resolved_at), int(uid), str(robbery_id)))
    await db.execute(
        "UPDATE npc_robberies SET status='released',resolved_at=? "
        "WHERE uid=? AND robbery_id=? AND status='active' AND interrogation_arrest=0",
        (int(resolved_at), int(uid), str(robbery_id)))
    return cur.rowcount > 0


async def bribe_latest(db, *, uid, resolved_at):
    row = await (await db.execute(
        "SELECT robbery_id FROM npc_robbery_receipts WHERE uid=? AND status='active' "
        "ORDER BY created_at DESC LIMIT 1", (int(uid),))).fetchone()
    robbery_id = str((row or [''])[0] or '')
    if robbery_id:
        await db.execute(
            "UPDATE npc_robbery_receipts SET status='bribed',resolved_at=? "
            "WHERE uid=? AND robbery_id=? AND status='active'",
            (int(resolved_at), int(uid), robbery_id))
        await db.execute(
            "UPDATE npc_robberies SET status='bribed',resolved_at=? "
            "WHERE uid=? AND robbery_id=? AND status='active'",
            (int(resolved_at), int(uid), robbery_id))
    return robbery_id
