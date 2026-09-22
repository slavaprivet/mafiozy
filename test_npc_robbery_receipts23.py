"""Durable robbery receipt contracts against isolated in-memory SQLite.

Run: python -B -m unittest -v test_npc_robbery_receipts23
Only npc_robbery_receipts is imported from the application. No backend,
credentials, real database, network, or production initialization is used.
Amounts, identities and time are trusted caller inputs; packet authentication
and police wanted-level changes outside this helper are out of scope.
"""

from contextlib import asynccontextmanager
import sqlite3
import sys
import unittest
import uuid

import aiosqlite

sys.dont_write_bytecode = True
import npc_robbery_receipts as receipts


# Same legacy table constraints as the current init_db, without importing it.
LEGACY_SCHEMA = """
CREATE TABLE characters (
    telegram_id INTEGER PRIMARY KEY,
    cash INTEGER NOT NULL,
    wanted_stars REAL DEFAULT 0
);
CREATE TABLE npc_robberies (
    uid INTEGER NOT NULL,
    npc_id TEXT NOT NULL,
    robbery_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    cooldown_until INTEGER NOT NULL,
    interrogation_arrest INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active',
    created_at INTEGER NOT NULL,
    resolved_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (uid,npc_id),
    UNIQUE (uid,robbery_id)
);
INSERT INTO characters VALUES (101,100,0),(202,200,0);
"""


class RobberyReceiptContracts23(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.assertNotIn("mafiozi_bot", sys.modules)
        self.assertNotIn("_preview_ws_server", sys.modules)
        self.uri = "file:npc_receipts23_" + uuid.uuid4().hex + "?mode=memory&cache=shared"
        self.db = await aiosqlite.connect(self.uri, uri=True)
        # SQLite itself confirms that the attached main database has no file.
        databases = await self.rows("PRAGMA database_list")
        self.assertEqual(databases[0][1:], ("main", ""))
        await self.db.executescript(LEGACY_SCHEMA)
        await receipts.ensure_schema(self.db)
        await self.db.commit()

    async def asyncTearDown(self):
        await self.db.close()
        self.assertNotIn("mafiozi_bot", sys.modules)
        self.assertNotIn("_preview_ws_server", sys.modules)

    async def rows(self, query, params=(), db=None):
        async with (db or self.db).execute(query, params) as cursor:
            return await cursor.fetchall()

    async def character(self, uid=101):
        return (await self.rows(
            "SELECT cash,wanted_stars FROM characters WHERE telegram_id=?", (uid,)))[0]

    async def snapshot(self):
        return {
            "characters": await self.rows("SELECT * FROM characters ORDER BY telegram_id"),
            "slots": await self.rows("SELECT * FROM npc_robberies ORDER BY uid,npc_id"),
            "receipts": await self.rows(
                "SELECT * FROM npc_robbery_receipts ORDER BY uid,robbery_id"),
        }

    async def persisted(self, robbery_id, uid=101):
        async with self.db.execute(
            "SELECT * FROM npc_robbery_receipts WHERE uid=? AND robbery_id=?",
            (uid, robbery_id),
        ) as cursor:
            row = await cursor.fetchone()
            return None if row is None else dict(zip((d[0] for d in cursor.description), row))

    @asynccontextmanager
    async def transaction(self):
        await self.db.execute("BEGIN IMMEDIATE")
        try:
            yield
        except BaseException:
            await self.db.rollback()
            raise
        else:
            await self.db.commit()

    async def invoke(self, name, **args):
        async with self.transaction():
            return await getattr(receipts, name)(self.db, **args)

    async def begin(self, *, robbery_id="r1", npc_id="resident_a", uid=101,
                    amount=7, created_at=1000, cooldown_until=None,
                    interrogation_arrest=0, crime_r=12.25, crime_c=-3.5):
        return await self.invoke(
            "begin", uid=uid, npc_id=npc_id, robbery_id=robbery_id, amount=amount,
            created_at=created_at,
            cooldown_until=created_at + 3600 if cooldown_until is None else cooldown_until,
            interrogation_arrest=interrogation_arrest, crime_r=crime_r, crime_c=crime_c)

    async def report(self, robbery_id="r1", uid=101):
        return await self.invoke("report", uid=uid, robbery_id=robbery_id)

    async def test_migration_preserves_legacy_statuses_and_is_repeatable(self):
        statuses = ("unreported", "active", "released", "bribed", "confiscated", "threatened_waiting")
        for i, status in enumerate(statuses):
            await self.db.execute(
                "INSERT INTO npc_robberies VALUES(?,?,?,?,?,?,?,?,?)",
                (101, "legacy_" + status, "old_" + status, i + 1, 9000 + i,
                 i % 2, status, 100 + i, 500 if status in statuses[2:5] else 0))
        await self.db.commit()
        old_slots = await self.rows("SELECT * FROM npc_robberies ORDER BY npc_id")
        cash_before = await self.character()
        async with self.transaction():
            await receipts.ensure_schema(self.db)
        for status in statuses[:-1]:
            row = await self.persisted("old_" + status)
            self.assertEqual(row["status"], status)
            self.assertIsNone(row["crime_r"])
            self.assertIsNone(row["crime_c"])
            self.assertIsNone(row["cash_after"])
        self.assertIsNone(await self.persisted("old_threatened_waiting"))
        self.assertEqual(await self.character(), cash_before)
        self.assertEqual(await self.rows("SELECT * FROM npc_robberies ORDER BY npc_id"), old_slots)
        self.assertEqual([r["robbery_id"] for r in await receipts.active(self.db, 101)], ["old_active"])
        migrated = await self.snapshot()
        async with self.transaction():
            await receipts.ensure_schema(self.db)
        self.assertEqual(await self.snapshot(), migrated)
        for status in ("released", "bribed", "confiscated"):
            reply = await self.report("old_" + status)
            self.assertFalse(reply["case_active"])
            self.assertTrue(reply["replayed"])
        self.assertEqual(await self.snapshot(), migrated)

    async def test_legacy_cooldown_survives_even_when_threat_is_not_a_receipt(self):
        await self.db.execute(
            "INSERT INTO npc_robberies VALUES(101,'resident_a','threat',0,5000,1,'threatened_waiting',1000,0)")
        await self.db.commit()
        async with self.transaction():
            await receipts.ensure_schema(self.db)
        before = await self.snapshot()
        denied = await self.begin(created_at=4999)
        self.assertEqual((denied["ok"], denied["reason"], denied["cooldown_until"]), (False, "cooldown", 5000))
        self.assertEqual(await self.snapshot(), before)
        admitted = await self.begin(created_at=5000)
        self.assertTrue(admitted["ok"])
        self.assertFalse(admitted["replayed"])
        self.assertEqual((await self.character())[0], 107)

    async def test_duplicate_before_and_after_cooldown_never_pays_again(self):
        first = await self.begin()
        self.assertEqual((first["ok"], first["replayed"], first["cash"]), (True, False, 107))
        original = await self.persisted("r1")
        for now in (1001, 4600, 50000):
            with self.subTest(now=now):
                before = await self.snapshot()
                replay = await self.begin(created_at=now, amount=10, crime_r=99, crime_c=88,
                                          interrogation_arrest=1)
                self.assertTrue(replay["ok"] and replay["replayed"])
                self.assertEqual((replay["amount"], replay["crime_r"], replay["crime_c"]), (7, 12.25, -3.5))
                self.assertEqual(replay["cash_after"], 107)
                self.assertEqual(await self.snapshot(), before)
        self.assertEqual(await self.persisted("r1"), original)
        await self.db.execute("UPDATE characters SET cash=41 WHERE telegram_id=101")
        await self.db.commit()
        replay = await self.begin(created_at=60000)
        self.assertEqual((replay["cash"], replay["cash_after"]), (41, 107))
        self.assertEqual(await self.persisted("r1"), original)

    async def test_second_legal_cycle_retains_first_id_and_original_crime(self):
        await self.begin()
        before = await self.snapshot()
        early = await self.begin(robbery_id="r2", created_at=4599)
        self.assertEqual(early["reason"], "cooldown")
        self.assertEqual(await self.snapshot(), before)
        second = await self.begin(robbery_id="r2", created_at=4600, amount=3, crime_r=60, crime_c=70)
        self.assertTrue(second["ok"] and not second["replayed"])
        self.assertEqual(second["cash"], 110)
        slot2 = await self.rows("SELECT * FROM npc_robberies WHERE uid=101 AND npc_id='resident_a'")
        original2 = await self.persisted("r2")
        first_report = await self.report("r1")
        self.assertEqual((first_report["crime_r"], first_report["crime_c"], first_report["amount"]), (12.25, -3.5, 7))
        self.assertEqual(await self.rows("SELECT * FROM npc_robberies WHERE uid=101 AND npc_id='resident_a'"), slot2)
        replay = await self.begin(created_at=9000, amount=10, crime_r=0, crime_c=0)
        self.assertTrue(replay["replayed"])
        self.assertEqual(replay["cash"], 110)
        self.assertEqual(await self.persisted("r2"), original2)
        confiscated = await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=9100)
        self.assertEqual(confiscated["cash"], 103)
        self.assertEqual(await self.persisted("r2"), original2)
        self.assertEqual(await self.rows("SELECT * FROM npc_robberies WHERE uid=101 AND npc_id='resident_a'"), slot2)
        await self.report("r2")
        self.assertEqual([r["robbery_id"] for r in await receipts.active(self.db, 101)], ["r2"])

    async def test_cross_npc_id_conflict_cannot_rebind_or_pay(self):
        await self.begin()
        for now in (1001, 8000):
            before = await self.snapshot()
            reply = await self.begin(npc_id="resident_b", created_at=now, amount=10)
            self.assertEqual((reply["ok"], reply["reason"]), (False, "id_conflict"))
            self.assertEqual(await self.snapshot(), before)

    async def test_same_id_is_isolated_between_authenticated_uids(self):
        await self.begin(robbery_id="shared", uid=101)
        await self.begin(robbery_id="shared", uid=202, amount=4, crime_r=8, crime_c=9)
        await self.report("shared", uid=101)
        self.assertEqual(await self.character(101), (107, 1))
        self.assertEqual(await self.character(202), (204, 0))
        before = await self.snapshot()
        self.assertIsNone(await self.invoke("confiscate", uid=202, robbery_id="shared", resolved_at=2000))
        self.assertIsNone(await self.report("absent", uid=202))
        self.assertEqual(await self.snapshot(), before)
        await self.invoke("confiscate", uid=101, robbery_id="shared", resolved_at=2000)
        self.assertEqual(await self.character(101), (100, 1))
        self.assertEqual(await self.character(202), (204, 0))
        self.assertEqual((await self.persisted("shared", 202))["status"], "unreported")

    async def test_report_replay_preserves_wanted_and_immutable_fields(self):
        await self.begin()
        first = await self.report()
        self.assertFalse(first["replayed"])
        self.assertTrue(first["case_active"])
        await self.db.execute("UPDATE characters SET wanted_stars=4 WHERE telegram_id=101")
        await self.db.commit()
        before = await self.snapshot()
        duplicate = await self.report()
        self.assertTrue(duplicate["replayed"] and duplicate["case_active"])
        self.assertEqual(await self.snapshot(), before)

    async def test_terminal_receipts_never_reopen_on_report_or_begin_retry(self):
        for status in ("released", "bribed", "confiscated"):
            with self.subTest(status=status):
                rid = "terminal_" + status
                await self.begin(robbery_id=rid, npc_id=rid)
                await self.report(rid)
                if status == "released":
                    self.assertTrue(await self.invoke("resolve_released", uid=101, robbery_id=rid, resolved_at=2000))
                elif status == "bribed":
                    self.assertEqual(await self.invoke("bribe_latest", uid=101, resolved_at=2000), rid)
                else:
                    self.assertIsNotNone(await self.invoke("confiscate", uid=101, robbery_id=rid, resolved_at=2000))
                # Wanted-level resolution is owned by the caller, not the helper.
                await self.db.execute("UPDATE characters SET wanted_stars=0 WHERE telegram_id=101")
                await self.db.commit()
                before = await self.snapshot()
                report = await self.report(rid)
                self.assertFalse(report["case_active"])
                self.assertEqual(report["status"], status)
                replay = await self.begin(robbery_id=rid, npc_id=rid, created_at=10000, amount=10)
                self.assertTrue(replay["replayed"])
                self.assertEqual(replay["status"], status)
                self.assertEqual(await self.snapshot(), before)

    async def test_active_reconnect_reads_durable_order_filter_limit_and_uid(self):
        for i in range(6):
            rid = "case_" + str(i)
            await self.begin(robbery_id=rid, npc_id=rid, created_at=1000 + i * 10, crime_r=i, crime_c=-i)
            if i != 5:
                await self.report(rid)
        await self.invoke("resolve_released", uid=101, robbery_id="case_3", resolved_at=2000)
        await self.begin(robbery_id="other_uid", npc_id="other_uid", uid=202, created_at=9000)
        await self.report("other_uid", uid=202)
        before = await self.snapshot()
        async with aiosqlite.connect(self.uri, uri=True) as reconnected:
            self.assertEqual((await self.rows("PRAGMA database_list", db=reconnected))[0][1:], ("main", ""))
            active = await receipts.active(reconnected, 101)
            self.assertEqual([r["robbery_id"] for r in active], ["case_4", "case_2", "case_1", "case_0"])
            self.assertEqual((active[0]["crime_r"], active[0]["crime_c"]), (4, -4))
            self.assertEqual([r["robbery_id"] for r in await receipts.active(reconnected, 101, 2)], ["case_4", "case_2"])
            self.assertEqual(await receipts.active(reconnected, 101, 0), [])
            self.assertEqual([r["robbery_id"] for r in await receipts.active(reconnected, 202)], ["other_uid"])
        self.assertEqual(await self.snapshot(), before)

    async def test_confiscation_is_once_and_never_makes_cash_negative(self):
        await self.begin(amount=10)
        before = await self.snapshot()
        self.assertIsNone(await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=2000))
        self.assertEqual(await self.snapshot(), before)
        await self.report()
        await self.db.execute("UPDATE characters SET cash=3 WHERE telegram_id=101")
        await self.db.commit()
        result = await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=2100)
        self.assertEqual((result["cash"], result["amount"]), (0, 10))
        after = await self.snapshot()
        self.assertIsNone(await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=9999))
        self.assertEqual(await self.snapshot(), after)
        self.assertEqual((await self.persisted("r1"))["resolved_at"], 2100)

    async def test_release_requires_active_non_arrest_case_and_is_once(self):
        await self.begin()
        before = await self.snapshot()
        self.assertFalse(await self.invoke("resolve_released", uid=101, robbery_id="r1", resolved_at=2000))
        self.assertEqual(await self.snapshot(), before)
        await self.report()
        self.assertTrue(await self.invoke("resolve_released", uid=101, robbery_id="r1", resolved_at=2100))
        after = await self.snapshot()
        self.assertFalse(await self.invoke("resolve_released", uid=101, robbery_id="r1", resolved_at=9000))
        self.assertEqual(await self.snapshot(), after)
        await self.begin(robbery_id="arrest", npc_id="arrest", interrogation_arrest=1)
        await self.report("arrest")
        before = await self.snapshot()
        self.assertFalse(await self.invoke("resolve_released", uid=101, robbery_id="arrest", resolved_at=2200))
        self.assertEqual(await self.snapshot(), before)

    async def test_bribe_targets_latest_active_and_terminal_retry_does_not_mutate(self):
        for rid, at in (("older", 1000), ("latest", 1100), ("unreported", 1200)):
            await self.begin(robbery_id=rid, npc_id=rid, created_at=at)
            if rid != "unreported":
                await self.report(rid)
        await self.begin(robbery_id="foreign", npc_id="foreign", uid=202, created_at=1300)
        await self.report("foreign", uid=202)
        self.assertEqual(await self.invoke("bribe_latest", uid=101, resolved_at=2000), "latest")
        self.assertEqual((await self.persisted("older"))["status"], "active")
        self.assertEqual((await self.persisted("foreign", 202))["status"], "active")
        latest = await self.persisted("latest")
        # A second bribe_latest command resolves another active case by design:
        # this API has no command id. It must not rewrite the already closed one.
        self.assertEqual(await self.invoke("bribe_latest", uid=101, resolved_at=2100), "older")
        self.assertEqual(await self.persisted("latest"), latest)
        before = await self.snapshot()
        self.assertEqual(await self.invoke("bribe_latest", uid=101, resolved_at=2200), "")
        self.assertEqual(await self.snapshot(), before)
        self.assertFalse((await self.report("latest"))["case_active"])
        self.assertEqual(await self.snapshot(), before)

    async def test_nonfinite_crime_coordinates_do_not_escape_into_receipts(self):
        cases = ((float("nan"), float("inf"), None, None),
                 ("-12.5", "0", -12.5, 0.0),
                 (None, "not-a-number", None, None))
        for i, (r, c, expected_r, expected_c) in enumerate(cases):
            rid = "coordinates_" + str(i)
            reply = await self.begin(robbery_id=rid, npc_id=rid, crime_r=r, crime_c=c)
            self.assertEqual((reply["crime_r"], reply["crime_c"]), (expected_r, expected_c))
            row = await self.persisted(rid)
            self.assertEqual((row["crime_r"], row["crime_c"]), (expected_r, expected_c))

    async def test_begin_write_failure_rolls_back_payout_slot_and_receipt(self):
        await self.db.execute("""CREATE TRIGGER reject_new_receipt BEFORE INSERT ON npc_robbery_receipts
            WHEN NEW.robbery_id='fail' BEGIN SELECT RAISE(ABORT,'receipt insert rejected'); END""")
        await self.db.commit()
        before = await self.snapshot()
        with self.assertRaisesRegex(sqlite3.IntegrityError, "receipt insert rejected"):
            await self.begin(robbery_id="fail")
        self.assertEqual(await self.snapshot(), before)
        await self.db.execute("DROP TRIGGER reject_new_receipt")
        await self.db.commit()
        retry = await self.begin(robbery_id="fail")
        self.assertEqual((retry["cash"], retry["replayed"]), (107, False))

    async def test_confiscation_write_failure_rolls_back_cash_then_allows_retry(self):
        await self.begin()
        await self.report()
        await self.db.execute("""CREATE TRIGGER reject_confiscation BEFORE UPDATE ON npc_robbery_receipts
            WHEN NEW.status='confiscated' BEGIN SELECT RAISE(ABORT,'case update rejected'); END""")
        await self.db.commit()
        before = await self.snapshot()
        with self.assertRaisesRegex(sqlite3.IntegrityError, "case update rejected"):
            await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=2000)
        self.assertEqual(await self.snapshot(), before)
        await self.db.execute("DROP TRIGGER reject_confiscation")
        await self.db.commit()
        self.assertEqual((await self.invoke("confiscate", uid=101, robbery_id="r1", resolved_at=2000))["cash"], 100)

    async def test_report_write_failure_rolls_back_both_case_statuses(self):
        await self.begin()
        await self.db.execute("""CREATE TRIGGER reject_wanted BEFORE UPDATE OF wanted_stars ON characters
            BEGIN SELECT RAISE(ABORT,'wanted update rejected'); END""")
        await self.db.commit()
        before = await self.snapshot()
        with self.assertRaisesRegex(sqlite3.IntegrityError, "wanted update rejected"):
            await self.report()
        self.assertEqual(await self.snapshot(), before)
        await self.db.execute("DROP TRIGGER reject_wanted")
        await self.db.commit()
        self.assertTrue((await self.report())["case_active"])

    async def test_helper_leaves_commit_control_with_caller(self):
        before = await self.snapshot()
        with self.assertRaisesRegex(RuntimeError, "caller failed after payout"):
            async with self.transaction():
                result = await receipts.begin(
                    self.db, uid=101, npc_id="resident_a", robbery_id="caller-abort",
                    amount=7, cooldown_until=4600, interrogation_arrest=0,
                    created_at=1000, crime_r=12.25, crime_c=-3.5)
                self.assertTrue(result["ok"])
                raise RuntimeError("caller failed after payout")
        self.assertEqual(await self.snapshot(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
