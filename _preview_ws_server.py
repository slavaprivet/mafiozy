import asyncio
import json
from pathlib import Path
import time
from aiohttp import web


players = {}


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
        "x": 40.0,
        "y": 40.0,
        "ang": 0.0,
        "walking": False,
        "name": "Demo",
    })
    others = []
    for oid, op in players.items():
        if oid == uid:
            continue
        others.append({
            "uid": oid,
            "name": op.get("name", "Demo"),
            "x": round(op.get("x", 40.0), 2),
            "y": round(op.get("y", 40.0), 2),
            "ang": round(op.get("ang", 0.0), 2),
            "walking": bool(op.get("walking")),
            "hp": 100,
            "max_hp": 100,
            "dead": False,
            "look": {},
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
            "others": others,
            "cops": [],
            "event": None,
            "territories": {},
            "active_captures": {},
            "aggro": {},
            "quest_cars": [],
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
        "x": 40.0,
        "y": 40.0,
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
            elif t == "race_top":
                await ws.send_str(json.dumps({"t": "race_top", "d": {"top": []}}))
            elif t == "respawn_status":
                await ws.send_str(json.dumps({
                    "t": "event",
                    "d": {"kind": "respawn_status", "ok": True, "point": "hospital"},
                }))
    finally:
        task.cancel()
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
