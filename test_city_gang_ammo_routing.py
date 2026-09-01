"""Focused durable routing contract for ordinary city-gang ammo pickups."""

import asyncio
import json
import os
import uuid
from pathlib import Path
from unittest.mock import AsyncMock, patch

os.environ.setdefault("BOT_TOKEN", "123456:city-gang-ammo-routing-regression")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
DB_ROOT = Path(r"D:\CodexTemp")
T0 = 1_920_000_000.0


class FakeWS:
    def __init__(self) -> None:
        self.closed = False
        self.sent: list[str] = []

    async def send_str(self, value: str) -> None:
        self.sent.append(value)

    async def close(self, **_kwargs) -> None:
        self.closed = True

    def events(self, kind: str) -> list[dict]:
        result = []
        for raw in self.sent:
            payload = json.loads(raw)
            if payload.get("t") == "event" and \
                    (payload.get("d") or {}).get("kind") == kind:
                result.append(payload["d"])
        return result


def fresh_world(uid: str, loot_id: str) -> tuple[game.WorldSim, FakeWS, dict]:
    world = game.WorldSim()
    world.players.clear()
    world.connections.clear()
    world.city_gangs.clear()
    world.cops.clear()
    world.district_loot.clear()
    world.add_or_update(uid, "Ammo picker", {})
    player = world.players[uid]
    player.update(
        x=12.0, y=13.0, dead=False, _mode="pvp",
        _jail_until=0.0, last_seen=T0,
    )
    loot = {
        "id": loot_id, "kind": "ammo", "x": 12.0, "y": 13.0,
        "ammo_type": "rifle", "rounds": 15, "expires_at": T0 + 90.0,
    }
    world.district_loot[loot_id] = dict(loot)
    ws = FakeWS()
    world.connections[uid] = ws
    world.alive = True
    return world, ws, loot


async def run_one_cycle(world: game.WorldSim,
                        grant_override=None) -> None:
    async def empty_async(*_args, **_kwargs):
        return []

    async def stop_after_tick(_delay):
        world.alive = False

    sync_empty = [
        "tick_gang_nests", "tick_city_gangs", "tick_box_quests",
        "tick_capture", "tick_major_objects",
    ]
    sync_none = ["tick_quest_cars", "tick_beachgoers", "tick_jail_release"]
    async_empty = [
        "_tick_online_arrests", "tick_event", "tick_cops", "tick_aggro",
        "tick_pending_bot_shots", "tick_michael_guards", "tick_world_c4",
        "tick_respawn",
    ]
    patches = []
    for name in sync_empty:
        patches.append(patch.object(game.WorldSim, name, return_value=[]))
    for name in sync_none:
        patches.append(patch.object(game.WorldSim, name, return_value=None))
    for name in async_empty:
        patches.append(patch.object(
            game.WorldSim, name, new=AsyncMock(return_value=[])))
    patches.extend([
        patch.object(game, "_tick_owned_business_income", new=empty_async),
        patch.object(game, "_tick_robbed_business_controls", new=empty_async),
        patch.object(game, "_tick_business_war_season", new=empty_async),
        patch.object(game, "_record_world_event_news", new=empty_async),
        patch.object(game.asyncio, "sleep", new=stop_after_tick),
        patch.object(game.time, "time", return_value=T0),
    ])
    if grant_override is not None:
        patches.append(patch.object(
            game, "grant_ammo_transaction", new=grant_override))
    entered = []
    try:
        for context in patches:
            context.__enter__()
            entered.append(context)
        await game._world_run_loop_cycle(world)
    finally:
        for context in reversed(entered):
            context.__exit__(None, None, None)


async def configure_db() -> Path:
    path = DB_ROOT / f"bands13_ammo_routing_{uuid.uuid4().hex}.db"
    game.DB_PATH = str(path)
    await game.init_db()
    return path


async def test_success_replay_and_reconnect() -> None:
    await configure_db()
    uid, loot_id = "92001", "gang-ammo-routing-success"
    world, ws, _loot = fresh_world(uid, loot_id)
    await run_one_cycle(world)

    state = await game.get_authoritative_ammo_state(int(uid))
    assert state["reserve"]["rifle"] == 15
    assert loot_id not in world.district_loot
    assert world.players[uid]["_ammo_state"] == state
    events = ws.events("gang_ammo_picked")
    assert len(events) == 1
    assert events[0]["rounds"] == 15
    assert events[0]["ammo_state"] == state
    assert "_loot_restore" not in events[0]

    ws.sent.clear()
    world.alive = True
    await run_one_cycle(world)
    replay_state = await game.get_authoritative_ammo_state(int(uid))
    assert replay_state == state
    assert ws.events("gang_ammo_picked") == []

    world.remove(uid)
    world.add_or_update(uid, "Ammo picker", {})
    world.players[uid]["_ammo_state"] = \
        await game.get_authoritative_ammo_state(int(uid))
    snapshot = world.snapshot_for(uid)
    assert snapshot["d"]["me"]["ammo_state"] == state
    assert loot_id not in {str(item.get("id"))
                           for item in snapshot["d"].get("district_loot", [])}


async def test_failure_restores_and_retry_commits() -> None:
    await configure_db()
    uid, loot_id = "92002", "gang-ammo-routing-retry"
    world, ws, loot = fresh_world(uid, loot_id)
    failed_grant = AsyncMock(return_value={"ok": False, "error": "db_down"})
    await run_one_cycle(world, failed_grant)

    assert failed_grant.await_count == 1
    assert world.district_loot[loot_id] == loot
    assert ws.events("gang_ammo_picked") == []
    assert "_loot_restore" not in world.district_loot[loot_id]
    failed_state = await game.get_authoritative_ammo_state(int(uid))
    assert failed_state["reserve"]["rifle"] == 0

    ws.sent.clear()
    world.alive = True
    await run_one_cycle(world)
    state = await game.get_authoritative_ammo_state(int(uid))
    events = ws.events("gang_ammo_picked")
    assert state["reserve"]["rifle"] == 15
    assert len(events) == 1
    assert events[0]["ammo_state"] == state
    assert loot_id not in world.district_loot


def test_source_and_world_marker() -> None:
    backend = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
    assert "for np in list(nest_pkts):" not in backend
    dist_start = backend.index(
        "dist_pkts = world.tick_district_capture(WORLD_TICK_DT) or []")
    grant_start = backend.index("for dp in list(dist_pkts):", dist_start)
    broadcast = backend.index("ev_pkts.extend(dist_pkts)", grant_start)
    assert dist_start < grant_start < broadcast
    marker = (
        '<meta name="mafiozy-city-gang-ammo-routing-contract" '
        'content="district-pickup-durable-v1">'
    )
    assert (ROOT / "world.html").read_text(encoding="utf-8").count(marker) == 1


async def main() -> None:
    await test_success_replay_and_reconnect()
    await test_failure_restores_and_retry_commits()
    test_source_and_world_marker()
    print("city gang ammo routing: 6/6 OK")


if __name__ == "__main__":
    asyncio.run(main())
