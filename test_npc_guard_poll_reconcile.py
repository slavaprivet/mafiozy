"""Guard plans change on transitions, never while a stable state is polled."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_000_900_000


async def _assignments(path: str, leader_id: str):
    async with aiosqlite.connect(path) as db:
        return await (await db.execute(
            "SELECT holding_ref,assigned,living,updated_at "
            "FROM npc_empire_guard_assignments WHERE owner_kind='npc' "
            "AND owner_id=? ORDER BY holding_ref", (leader_id,)
        )).fetchall()


async def _assert_invariants(path: str, leader_id: str) -> None:
    async with aiosqlite.connect(path) as db:
        members = int((await (await db.execute(
            "SELECT members FROM npc_empires WHERE leader_id=?", (leader_id,)
        )).fetchone())[0])
        wars = int((await (await db.execute(
            "SELECT COUNT(*) FROM npc_empire_diplomacy WHERE pact='war' "
            "AND (leader_a=? OR leader_b=?)", (leader_id, leader_id)
        )).fetchone())[0])
        wars += int(bool(await (await db.execute(
            "SELECT 1 FROM npc_empire_player_wars WHERE leader_id=? LIMIT 1",
            (leader_id,))).fetchone()))
        rows = await (await db.execute(
            "SELECT holding_ref,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id=?", (leader_id,)
        )).fetchall()
        owned = {f'{row[0]}:{row[1]}' for row in await (await db.execute(
            "SELECT kind,holding_id FROM npc_empire_holdings WHERE leader_id=?",
            (leader_id,))).fetchall()}
    living = sum(int(row[1]) for row in rows)
    reserve = min(max(2, wars * 2 + 1), max(2, members))
    assert living <= members and members - living >= min(members, reserve)
    assert all(str(row[0]) in owned for row in rows)


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='npc_guard_poll_', suffix='.db')
    os.close(handle)
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute(
                "UPDATE npc_empires SET last_tick=?,next_action_at=?,members=12 "
                "WHERE leader_id='leila'", (NOW, NOW + ne.TICK_SECONDS),
            )
            await db.execute(
                "UPDATE npc_empires SET last_tick=?,next_action_at=?",
                (NOW, NOW + ne.TICK_SECONDS),
            )
            await db.execute(
                "UPDATE npc_empire_diplomacy SET last_event_at=?", (NOW,))
            for key, income in (('4,4', 900), ('4,5', 500), ('4,6', 100)):
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_holdings"
                    "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                    "VALUES('building',?,'leila',?,60,?,'beer_bar',16)",
                    (key, income, NOW - 1000),
                )
            await ne._reconcile_npc_guards(db, 'leila', NOW)
            await db.executescript("""
                CREATE TABLE guard_write_audit(op TEXT NOT NULL);
                CREATE TRIGGER guard_audit_insert AFTER INSERT ON npc_empire_guard_assignments
                  BEGIN INSERT INTO guard_write_audit VALUES('insert'); END;
                CREATE TRIGGER guard_audit_update AFTER UPDATE ON npc_empire_guard_assignments
                  BEGIN INSERT INTO guard_write_audit VALUES('update'); END;
                CREATE TRIGGER guard_audit_delete AFTER DELETE ON npc_empire_guard_assignments
                  BEGIN INSERT INTO guard_write_audit VALUES('delete'); END;
            """)
            await db.execute("DELETE FROM guard_write_audit")
            await db.commit()

        stable_before = await _assignments(path, 'leila')
        snapshots = await asyncio.wait_for(asyncio.gather(*(
            ne.state_for(path, 10_000 + index, NOW + 1) for index in range(50)
        )), timeout=30)
        stable_after = await _assignments(path, 'leila')
        async with aiosqlite.connect(path) as db:
            writes = int((await (await db.execute(
                "SELECT COUNT(*) FROM guard_write_audit"
            )).fetchone())[0])
        assert len(snapshots) == 50 and all(len(item['empires']) == 19 for item in snapshots)
        assert writes == 0 and stable_after == stable_before

        # Idempotent reconcile itself also produces no writes.
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            await ne._reconcile_npc_guards(db, 'leila', NOW + 2)
            await db.commit()
        async with aiosqlite.connect(path) as db:
            assert int((await (await db.execute(
                "SELECT COUNT(*) FROM guard_write_audit"
            )).fetchone())[0]) == 0

        # Transition matrix: roster shrink, war reserve, ownership removal and
        # growth all reconcile immediately without calling state_for as repair.
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            await db.execute(
                "UPDATE npc_empires SET members=5 WHERE leader_id='leila'")
            await ne._reconcile_npc_guards(db, 'leila', NOW + 3)
            await db.commit()
        await _assert_invariants(path, 'leila')

        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            left, right = sorted(('leila', 'rustam'))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET pact='war',score=-100 "
                "WHERE leader_a=? AND leader_b=?", (left, right))
            await ne._reconcile_npc_guards(db, 'leila', NOW + 4)
            await db.commit()
        await _assert_invariants(path, 'leila')

        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            await db.execute(
                "DELETE FROM npc_empire_holdings "
                "WHERE leader_id='leila' AND kind='building' AND holding_id='4,4'")
            await ne._reconcile_npc_guards(db, 'leila', NOW + 5)
            await db.execute(
                "UPDATE npc_empires SET members=14 WHERE leader_id='leila'")
            await ne._reconcile_npc_guards(db, 'leila', NOW + 6)
            await db.commit()
        await _assert_invariants(path, 'leila')
        assert all(row[0] != 'building:4,4'
                   for row in await _assignments(path, 'leila'))
        print('npc guard polling: 50 stable snapshots, zero guard writes, transition invariants OK')
    finally:
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
