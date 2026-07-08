import asyncio
import json
from pathlib import Path
import time
from aiohttp import web


players = {}
race_best = {}
PREVIEW_START_X = 66.0
PREVIEW_START_Y = 162.5
RACE_SLOTS = [
    {"id": "race_preview_1", "model": "ferrari_f40", "x": 64.2, "y": 162.8, "ang": 1.5708},
    {"id": "race_preview_2", "model": "lambo_countach", "x": 66.0, "y": 162.8, "ang": 1.5708},
    {"id": "race_preview_3", "model": "porsche_911", "x": 67.8, "y": 162.8, "ang": 1.5708},
]
quest_cars = {}


def reset_race_cars():
    quest_cars.clear()
    for slot in RACE_SLOTS:
        quest_cars[slot["id"]] = {
            **slot,
            "owner_uid": None,
            "driver_uid": None,
            "passenger_uids": [],
            "vx": 0.0,
            "vy": 0.0,
            "hp": 1000,
            "max_hp": 1000,
            "wrecked": False,
            "civilian": True,
        }


def race_car_payload():
    return [
        {
            "id": car["id"],
            "model": car["model"],
            "owner_uid": car.get("owner_uid"),
            "driver_uid": car.get("driver_uid"),
            "passenger_uids": car.get("passenger_uids", []),
            "x": round(car["x"], 2),
            "y": round(car["y"], 2),
            "ang": round(car.get("ang", 0.0), 3),
            "vx": round(car.get("vx", 0.0), 3),
            "vy": round(car.get("vy", 0.0), 3),
            "hp": int(car.get("hp", 1000)),
            "max_hp": int(car.get("max_hp", 1000)),
            "wrecked": bool(car.get("wrecked")),
            "civilian": True,
        }
        for car in quest_cars.values()
    ]


reset_race_cars()


def release_player_cars(uid):
    for slot in RACE_SLOTS:
        car = quest_cars.get(slot["id"])
        if not car or str(car.get("driver_uid")) != str(uid):
            continue
        car.update({
            "x": slot["x"],
            "y": slot["y"],
            "ang": slot["ang"],
            "vx": 0.0,
            "vy": 0.0,
            "owner_uid": None,
            "driver_uid": None,
            "passenger_uids": [],
            "wrecked": False,
            "hp": 1000,
        })


def race_top():
    rows = sorted(race_best.values(), key=lambda row: row["ms"])[:5]
    return [{"uid": row["uid"], "name": row["name"], "ms": row["ms"]} for row in rows]


def cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return resp


async def options(_req):
    return cors(web.Response(status=204))


async def inv_list(_req):
    return cors(web.json_response({
        "ok": True,
        "items": [
            {"id": "pistol", "item_id": "pistol", "type": "weapon", "count": 1},
            {"id": "shotgun", "item_id": "shotgun", "type": "weapon", "count": 1},
        ],
    }))


async def leaderboard(_req):
    return cors(web.json_response({"ok": True, "items": []}))


async def coop_api(_req):
    return cors(web.json_response({"base": "http://127.0.0.1:8080"}))


async def preview_world(_req):
    html = Path("world.html").read_text(encoding="utf-8", errors="replace")
    html = html.replace(
        "https://slavaprivet.github.io/mafiozi-battle/coop_api.json?t=",
        "http://127.0.0.1:8080/coop_api.json?t=",
    )
    return web.Response(text=html, content_type="text/html")


def snap(uid):
    p = players.setdefault(uid, {
        "x": PREVIEW_START_X,
        "y": PREVIEW_START_Y,
        "ang": 0.0,
        "walking": False,
        "name": "Demo",
    })
    return {
        "t": "snap",
        "d": {
            "me": {
                "x": round(p["x"], 2),
                "y": round(p["y"], 2),
                "ang": round(p.get("ang", 0.0), 2),
                "walking": bool(p.get("walking")),
                "hp": 100,
                "max_hp": 100,
                "dead": False,
                "respawn_in": 0,
                "kills": 0,
                "deaths": 0,
                "cash": 100000,
                "diamonds": 0,
                "wanted": 0,
                "wanted_gangs": 0,
                "jail_in": 0,
            },
            "others": [],
            "cops": [],
            "event": None,
            "territories": {},
            "active_captures": {},
            "aggro": {},
            "quest_cars": race_car_payload(),
            "beachgoers": [],
            "michael_guards": [],
            "gang_nests": [],
            "district_owners": {},
            "district_captures": {},
        },
    }


async def world_ws(req):
    uid = req.query.get("uid", "1")
    players.setdefault(uid, {
        "x": PREVIEW_START_X,
        "y": PREVIEW_START_Y,
        "ang": 0.0,
        "walking": False,
        "name": "Demo",
    })
    ws = web.WebSocketResponse(heartbeat=20)
    await ws.prepare(req)
    await ws.send_str(json.dumps({
        "t": "hello",
        "d": {
            "your_uid": uid,
            "tick_hz": 15,
            "map_cols": 80,
            "map_rows": 200,
            "srv_now": round(time.time(), 2),
            "pvp": {"cd": 0.4, "range": 8, "max_hp": 100, "respawn": 5},
        },
    }))

    async def sender():
        while not ws.closed:
            await ws.send_str(json.dumps(snap(uid)))
            await asyncio.sleep(1 / 15)

    task = asyncio.create_task(sender())
    try:
        async for msg in ws:
            if msg.type != web.WSMsgType.TEXT:
                continue
            try:
                pkt = json.loads(msg.data)
            except Exception:
                continue
            t = pkt.get("t") or pkt.get("type")
            d = pkt.get("d") or {}
            if t == "input":
                p = players.setdefault(uid, {})
                p["x"] = float(d.get("x", p.get("x", 40.0)))
                p["y"] = float(d.get("y", p.get("y", 40.0)))
                p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                p["walking"] = bool(d.get("w", False))
            elif t == "gta_enter":
                car = quest_cars.get(str(d.get("car_id") or ""))
                if car:
                    car["driver_uid"] = uid
                    car["owner_uid"] = uid
                    car["passenger_uids"] = []
                    p = players.setdefault(uid, {})
                    p["x"] = car["x"]
                    p["y"] = car["y"]
                    p["ang"] = car.get("ang", 0.0)
            elif t == "gta_drive":
                car = quest_cars.get(str(d.get("car_id") or ""))
                if car and str(car.get("driver_uid")) == str(uid):
                    car["x"] = float(d.get("x", car["x"]))
                    car["y"] = float(d.get("y", car["y"]))
                    car["ang"] = float(d.get("ang", car.get("ang", 0.0)))
                    car["vx"] = float(d.get("vx", 0.0))
                    car["vy"] = float(d.get("vy", 0.0))
                    p = players.setdefault(uid, {})
                    p["x"] = car["x"]
                    p["y"] = car["y"]
                    p["ang"] = car["ang"]
            elif t == "gta_exit":
                car = quest_cars.get(str(d.get("car_id") or ""))
                if car and str(car.get("driver_uid")) == str(uid):
                    car["driver_uid"] = None
                    car["owner_uid"] = None
                    car["vx"] = 0.0
                    car["vy"] = 0.0
            elif t == "race_top":
                await ws.send_str(json.dumps({"t": "race_top", "d": {"top": race_top()}}))
            elif t == "race_lap":
                try:
                    lap_ms = int(d.get("ms") or 0)
                except Exception:
                    lap_ms = 0
                if 15000 <= lap_ms <= 1200000:
                    p = players.setdefault(uid, {})
                    cur = race_best.get(uid)
                    if cur is None or lap_ms < cur["ms"]:
                        race_best[uid] = {
                            "uid": uid,
                            "name": str(p.get("name") or "Demo")[:16],
                            "ms": lap_ms,
                        }
                await ws.send_str(json.dumps({"t": "race_top", "d": {"top": race_top()}}))
            elif t == "respawn_status":
                await ws.send_str(json.dumps({
                    "t": "event",
                    "d": {"kind": "respawn_status", "ok": True, "point": "hospital"},
                }))
    finally:
        task.cancel()
        release_player_cars(uid)
        players.pop(uid, None)
    return ws


app = web.Application()
app.router.add_route("OPTIONS", "/{tail:.*}", options)
app.router.add_get("/preview/world.html", preview_world)
app.router.add_get("/coop_api.json", coop_api)
app.router.add_get("/world/sim", world_ws)
app.router.add_get("/inv/{uid}/list", inv_list)
app.router.add_get("/world/leaderboard", leaderboard)


if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=8080)
