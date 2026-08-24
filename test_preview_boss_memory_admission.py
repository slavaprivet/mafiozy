"""Adversarial bounds for local boss-memory fixture admission."""

import asyncio

import aiosqlite

import _preview_ws_server as preview


def _reset():
    preview.preview_boss_memory_profiles.clear()
    preview.preview_boss_memory_sessions.clear()
    preview.preview_boss_memory_locks.clear()
    preview.preview_boss_memory_failures.clear()
    preview.preview_boss_memory_pending.clear()


async def run():
    original_seed = preview._preview_boss_memory_seed
    passed = []
    try:
        _reset()
        seed_calls = []

        async def bounded_seed(uid):
            seed_calls.append(uid)
            await asyncio.sleep(0.01)
            return {"uid": uid, "path": f"D:/fixture-{uid}.db", "generation": str(uid)}

        preview._preview_boss_memory_seed = bounded_seed
        replies = await asyncio.gather(*[
            preview._preview_boss_memory_profile(uid) for uid in range(100, 112)
        ], return_exceptions=True)
        successes = [item for item in replies if isinstance(item, dict)]
        failures = [item for item in replies if isinstance(item, RuntimeError)]
        assert len(successes) == preview._PREVIEW_FIXTURE_MAX_PROFILES == 4
        assert len(failures) == 8 and len(seed_calls) == 4
        assert not preview.preview_boss_memory_pending
        assert not preview.preview_boss_memory_locks
        passed.append("atomic-cross-uid-cap")

        rejected = await asyncio.gather(*[
            preview._preview_boss_memory_profile(uid) for uid in range(1000, 1200)
        ], return_exceptions=True)
        assert all(isinstance(item, RuntimeError) for item in rejected)
        assert not preview.preview_boss_memory_locks
        passed.append("rejected-uids-no-lock-leak")

        _reset()
        same_calls = 0

        async def same_seed(uid):
            nonlocal same_calls
            same_calls += 1
            await asyncio.sleep(0.01)
            return {"uid": uid, "path": "D:/same.db", "generation": "same"}

        preview._preview_boss_memory_seed = same_seed
        same = await asyncio.gather(*[
            preview._preview_boss_memory_profile(501) for _ in range(20)
        ])
        assert same_calls == 1 and all(item is same[0] for item in same)
        assert not preview.preview_boss_memory_pending
        assert not preview.preview_boss_memory_locks
        passed.append("same-uid-one-seed")

        _reset()
        broken_calls = 0

        async def broken_seed(_uid):
            nonlocal broken_calls
            broken_calls += 1
            raise aiosqlite.OperationalError("forced sqlite failure")

        preview._preview_boss_memory_seed = broken_seed
        failed = await asyncio.gather(*[
            preview._preview_boss_memory_profile(777) for _ in range(20)
        ], return_exceptions=True)
        second = await asyncio.gather(
            preview._preview_boss_memory_profile(777), return_exceptions=True)
        assert all(isinstance(item, RuntimeError) for item in failed + second)
        assert broken_calls == 1 and 777 in preview.preview_boss_memory_failures
        assert 777 not in preview.preview_boss_memory_pending
        assert 777 not in preview.preview_boss_memory_locks
        passed.append("concurrent-sqlite-failure-locked-once")

        _reset()
        cancel_started = 0
        all_started = asyncio.Event()
        never_finish = asyncio.Event()

        async def cancelled_seed(_uid):
            nonlocal cancel_started
            cancel_started += 1
            if cancel_started == preview._PREVIEW_FIXTURE_MAX_PROFILES:
                all_started.set()
            await never_finish.wait()

        preview._preview_boss_memory_seed = cancelled_seed
        cancelled = [asyncio.create_task(
            preview._preview_boss_memory_profile(uid)) for uid in range(800, 804)]
        await asyncio.wait_for(all_started.wait(), timeout=1)
        for task in cancelled:
            task.cancel()
        results = await asyncio.gather(*cancelled, return_exceptions=True)
        assert all(isinstance(item, asyncio.CancelledError) for item in results)
        assert not preview.preview_boss_memory_pending
        assert not preview.preview_boss_memory_locks

        preview._preview_boss_memory_seed = bounded_seed
        after_cancel = await preview._preview_boss_memory_profile(900)
        assert after_cancel["uid"] == 900
        passed.append("cancellation-releases-admission")

        _reset()
        preview.preview_boss_memory_sessions.update({
            "a" * 48: {"uid": 1, "generation": "a", "expires_at": 1},
            "b" * 48: {"uid": 2, "generation": "b", "expires_at": 9_999_999_999},
        })
        preview._preview_boss_memory_sweep(now=2)
        assert "a" * 48 not in preview.preview_boss_memory_sessions
        assert "b" * 48 in preview.preview_boss_memory_sessions
        passed.append("global-expiry-sweep")

        assert len(passed) == 6, passed
        print("preview boss memory admission: 6/6 gates OK — " + ", ".join(passed))
    finally:
        preview._preview_boss_memory_seed = original_seed
        _reset()


if __name__ == "__main__":
    asyncio.run(run())
