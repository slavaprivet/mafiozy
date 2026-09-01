"""Focused boundaries for atomic Lair admission and bounded retry liveness."""

import asyncio
import os
import random
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:lair-retry-contract")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent


def _tick(world, now):
    with patch.object(game.time, "time", return_value=float(now)):
        return asyncio.run(world._tick_aggro_async(.05))


def _fresh_world():
    world = game.WorldSim()
    world.aggro.clear()
    world.aggro_covers.clear()
    if hasattr(world, "_aggro_spawn_retry_at"):
        world._aggro_spawn_retry_at.clear()
    return world


def _successful_spawn(world, now, seed):
    random.seed(seed)
    packets = _tick(world, now)
    assert [packet["kind"] for packet in packets] == ["aggro_spawned"]
    return packets


def run():
    # Initial admission failure is atomic and never aborts the caller. The
    # downstream sentinel proves the shared world cycle can keep advancing.
    initial = _fresh_world()
    initial_id = initial._next_bot_id
    downstream = []

    async def initial_cycle(now):
        with patch.object(game.time, "time", return_value=float(now)):
            packets = await initial._tick_aggro_async(.05)
        downstream.append("continued")
        return packets

    with patch.object(game, "_world_bandit_nearest_point", return_value=None):
        assert asyncio.run(initial_cycle(100.0)) == []
    assert downstream == ["continued"]
    assert "lair" not in initial.aggro
    assert "lair" not in initial.aggro_covers
    assert initial._next_bot_id == initial_id
    assert initial._aggro_spawn_retry_at == {"lair": 115.0}

    # Half-open boundary: zero admission work before 15.000 seconds, exactly
    # one retry at the deadline, then one new window after another failure.
    admission_calls = []

    def reject_admission(*_args, **_kwargs):
        admission_calls.append(1)
        return None

    with patch.object(game, "_world_bandit_nearest_point",
                      side_effect=reject_admission):
        assert _tick(initial, 114.999) == []
        assert admission_calls == []
        assert _tick(initial, 115.0) == []
        assert len(admission_calls) == 1
        assert initial._aggro_spawn_retry_at["lair"] == 130.0
        assert _tick(initial, 129.999) == []
        assert len(admission_calls) == 1
        assert _tick(initial, 130.0) == []
        assert len(admission_calls) == 2
        assert initial._aggro_spawn_retry_at["lair"] == 145.0
    assert "lair" not in initial.aggro
    assert "lair" not in initial.aggro_covers
    assert initial._next_bot_id == initial_id

    # A later success publishes one full generation, one ID range and one
    # event. Replaying the same tick cannot create a duplicate generation.
    before_success_id = initial._next_bot_id
    packets = _successful_spawn(initial, 145.0, seed=130013)
    actor_count = initial.AGGRO_BOTS_COUNT + 1
    bot_ids = [bot["id"] for bot in initial.aggro["lair"]["bots"]]
    assert packets[0]["count"] == actor_count
    assert len(bot_ids) == actor_count and len(set(bot_ids)) == actor_count
    assert initial._next_bot_id == before_success_id + actor_count
    assert "lair" in initial.aggro_covers
    assert "lair" not in initial._aggro_spawn_retry_at
    assert _tick(initial, 145.0) == []
    assert initial._next_bot_id == before_success_id + actor_count

    # Cleared-state respawn uses the same bounded contract. A late failure
    # retains the old roster/covers/IDs until one complete replacement exists.
    cleared = _fresh_world()
    _successful_spawn(cleared, 1000.0, seed=130014)
    old_state = cleared.aggro["lair"]
    old_covers = cleared.aggro_covers["lair"]
    old_bot_ids = [bot["id"] for bot in old_state["bots"]]
    for bot in old_state["bots"]:
        bot["alive"] = False
    old_state["last_respawn_at"] = 1000.0
    due = 1000.0 + cleared.AGGRO_RESPAWN_S
    before_respawn_id = cleared._next_bot_id
    with patch.object(game, "_world_bandit_nearest_point", return_value=None):
        assert _tick(cleared, due) == []
    assert cleared.aggro["lair"] is old_state
    assert cleared.aggro_covers["lair"] is old_covers
    assert [bot["id"] for bot in old_state["bots"]] == old_bot_ids
    assert cleared._next_bot_id == before_respawn_id
    assert cleared._aggro_spawn_retry_at["lair"] == due + 15.0

    respawn_calls = []

    def count_without_admission(*_args, **_kwargs):
        respawn_calls.append(1)
        return None

    with patch.object(game, "_world_bandit_nearest_point",
                      side_effect=count_without_admission):
        assert _tick(cleared, due + 14.999) == []
    assert respawn_calls == []

    respawn = _successful_spawn(cleared, due + 15.0, seed=130015)
    new_bot_ids = [bot["id"] for bot in cleared.aggro["lair"]["bots"]]
    assert cleared.aggro["lair"] is not old_state
    assert len(new_bot_ids) == actor_count and len(set(new_bot_ids)) == actor_count
    assert set(new_bot_ids).isdisjoint(old_bot_ids)
    assert cleared._next_bot_id == before_respawn_id + actor_count
    assert "lair" not in cleared._aggro_spawn_retry_at
    assert _tick(cleared, due + 15.0) == []
    assert cleared._next_bot_id == before_respawn_id + actor_count

    world_source = (ROOT / "world.html").read_text(encoding="utf-8")
    assert "mafiozy-lair-spawn-scheduler-contract" in world_source

    print("lair spawn retry liveness: initial/cleared/boundaries/exactly-once OK")


if __name__ == "__main__":
    run()
