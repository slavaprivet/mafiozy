import asyncio
import json

from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as game


async def recv_kind(ws, kind, timeout=3):
    async def receive():
        while True:
            msg = await ws.receive()
            data = json.loads(msg.data)
            if data.get("t") == "event" and data.get("d", {}).get("kind") == kind:
                return data["d"]

    return await asyncio.wait_for(receive(), timeout)


async def send_world_input(ws, *, x, y, mafia=True, interior=None):
    payload = {
        "x": x,
        "y": y,
        "ang": 0,
        "w": False,
        "mafia": mafia,
        "police": False,
        "client_active": True,
        "weapon": "pistol_heavy",
    }
    if interior:
        payload["interior"] = interior
    await ws.send_json({"t": "input", "d": payload})
    await asyncio.sleep(0.03)


async def run_business_cycle(ws, uid, biz_id, expected_attempt, expected_guards):
    r, c = game.PREVIEW_BUSINESS_RC[biz_id]
    await send_world_input(ws, x=c, y=r)
    await ws.send_json({"t": "business_rob_prepare", "d": {"biz_id": biz_id}})
    prepared = await recv_kind(ws, "business_rob_prepare_reply")
    assert prepared["ok"], prepared
    assert prepared["attempt"] == expected_attempt
    assert prepared["guard_count"] == expected_guards

    token = prepared["rob_token"]
    width = game.PREVIEW_ROB_INTERIOR_WIDTHS[biz_id]
    await send_world_input(
        ws,
        x=c,
        y=r,
        interior={
            "kind": "business",
            "biz_id": biz_id,
            "x": width / 2,
            "y": 2.9,
        },
    )

    # Все смерти отправляются подряд: уникальные guard_id обязаны засчитаться
    # даже после взрыва или быстрого добивания нескольких целей.
    for guard_id in range(expected_guards):
        await ws.send_json({
            "t": "business_rob_guard_down",
            "d": {"biz_id": biz_id, "rob_token": token, "guard_id": guard_id},
        })
    # Повтор того же id не должен увеличивать счётчик.
    await ws.send_json({
        "t": "business_rob_guard_down",
        "d": {"biz_id": biz_id, "rob_token": token, "guard_id": 0},
    })
    await asyncio.sleep(0.05)
    session = game.preview_business_rob_sessions[str(uid)]
    assert len(session["guards_down"]) == expected_guards

    # Клиент и сервер используют одинаковый максимум 35 за попадание.
    for hit_seq, damage in enumerate((35, 35, 29), 1):
        await ws.send_json({
            "t": "business_rob_owner_hit",
            "d": {
                "biz_id": biz_id,
                "rob_token": token,
                "damage": damage,
                "hit_seq": hit_seq,
            },
        })
    await asyncio.sleep(0.05)
    assert session["owner_pressure"] == 99
    assert session["owner_hit_seq"] == 3

    # Не ждём реальное боевое время в автоматическом тесте.
    session["started_at"] -= max(4, expected_guards)
    cash_before = game.preview_account(uid)["cash"]
    await ws.send_json({
        "t": "shop_rob",
        "d": {"biz_id": biz_id, "rob_token": token},
    })
    result = await recv_kind(ws, "shop_rob_reply")
    assert result["ok"], result
    assert result["money"] == game.PREVIEW_ROB_PAYOUT[biz_id][0]
    assert game.preview_account(uid)["cash"] == cash_before + result["money"]

    # Для следующего шага трёхступенчатого сценария прокручиваем 5-минутный
    # кулдаун, не ослабляя его в самой игре.
    game.preview_business_closures.pop(biz_id, None)
    game.preview_business_last_robs.pop((str(uid), biz_id), None)
    return result


async def run_casino_capture(ws, uid):
    cfg = game.PREVIEW_MAJOR_OBJECTS["casino"]
    await send_world_input(ws, x=cfg["c"], y=cfg["r"])
    await ws.send_json({"t": "major_assault_start", "d": {"object_id": "casino"}})
    started = await recv_kind(ws, "major_assault_reply")
    assert started["ok"], started
    assert started["phase"] == "guards"

    await send_world_input(
        ws,
        x=cfg["c"],
        y=cfg["r"],
        interior={"kind": "major", "object_id": "casino", "x": 39, "y": 4},
    )
    while True:
        raid = game.preview_major_raids["casino"]
        guard = next((row for row in raid["guards"] if row.get("alive")), None)
        if not guard:
            break
        while guard["alive"]:
            await ws.send_json({
                "t": "major_guard_hit",
                "d": {
                    "object_id": "casino",
                    "guard_id": guard["id"],
                    "damage": 90,
                    "weapon": "pistol_heavy",
                },
            })
            hit = await recv_kind(ws, "major_guard_hit")
            assert hit["ok"], hit
    raid = game.preview_major_raids["casino"]
    assert raid["phase"] == "boss"
    assert raid["spawned"] == cfg["total"]

    safe = raid["safes"][0]
    await send_world_input(
        ws,
        x=cfg["c"],
        y=cfg["r"],
        interior={
            "kind": "major",
            "object_id": "casino",
            "x": safe["c"],
            "y": safe["r"],
        },
    )
    cash_before = game.preview_account(uid)["cash"]
    await ws.send_json({
        "t": "major_safe_open",
        "d": {"object_id": "casino", "safe_id": safe["id"]},
    })
    opened = await recv_kind(ws, "major_safe_open")
    assert opened["ok"], opened
    assert game.preview_account(uid)["cash"] == cash_before + safe["value"]

    await send_world_input(
        ws,
        x=cfg["c"],
        y=cfg["r"],
        interior={"kind": "major", "object_id": "casino", "x": 39, "y": 4},
    )
    pressure_steps = []
    for _ in range(5):
        await ws.send_json({
            "t": "major_boss_pressure",
            "d": {"object_id": "casino"},
        })
        pressure_steps.append(await recv_kind(ws, "major_boss_pressure"))
    assert [row["pressure"] for row in pressure_steps] == [20, 40, 60, 80, 100]
    assert pressure_steps[-1]["captured"]
    assert "casino" in game.preview_major_owners
    assert "casino" not in game.preview_major_raids


async def main():
    uid = "business-raid-test"
    game.players.clear()
    game.preview_accounts.clear()
    game.preview_business_rob_sessions.clear()
    game.preview_business_rob_cycles.clear()
    game.preview_business_last_robs.clear()
    game.preview_business_closures.clear()
    game.preview_major_raids.clear()
    game.preview_major_owners.clear()
    game.preview_major_props.clear()

    server = TestServer(game.app)
    client = TestClient(server)
    await client.start_server()
    ws = await client.ws_connect(f"/world/sim?uid={uid}")
    await ws.receive()
    try:
        results = []
        for attempt, guards in ((1, 2), (2, 5), (3, 8)):
            results.append(
                await run_business_cycle(ws, uid, "carwash", attempt, guards)
            )
        assert game.preview_business_rob_cycles[(uid, "carwash")] == 0
        assert sum(row["money"] for row in results) == 900

        await run_casino_capture(ws, uid)
    finally:
        await ws.close()
        await client.close()

    print("[OK] Бизнес: попытки 1/2/3, охрана 2/5/8, владелец 99%, выплаты 3/3")
    print("[OK] Казино: вся охрана, сейф, давление 20-100, захват и владелец")


if __name__ == "__main__":
    asyncio.run(main())
