import asyncio
import json
import math
from pathlib import Path
import time
from aiohttp import web


players = {}
race_best = {}
race_day = ""
next_civ_car_id = 1
clients = set()
DIST_HQ_RAD = 6.0
DIST_ACTION_RAD = 2.8
DIST_OPERATION_TTL_S = 12 * 60
DIST_MAX_ACTIVE_PER_PLAYER = 1
DIST_C4_FUSE_S = 4.0
WORLD_C4_FUSE_S = 3.0
WORLD_C4_LETHAL_R = 4.0
WORLD_C4_MAX_ACTIVE = 3
DIST_BOSS_HP = 420
DIST_GUARD_HP = 180
DIST_C4_NOTICE_R = 7.0
DIST_C4_SAFE_R = 5.25
DIST_C4_FLEE_SPEED = 5.2
DIST_CONTROL_TTL_S = 30 * 60
DIST_INCOME_DELAY_S = 60
DIST_INCOME_TICK_S = 120
DISTRICTS = {
    "northside":  {"hq":(20.,20.), "intel":(11.,20.), "sabotage":((14.,12.),(20.,29.),(29.,18.)), "escape":(35.,20.), "name":"Норт-Сайд", "boss_name":"Мясник Морелло", "icon":"🏪", "income":400, "color":"#4aa3df"},
    "downtown":   {"hq":(20.,60.), "intel":(11.,60.), "sabotage":((15.,49.),(19.,70.),(30.,58.)), "escape":(35.,60.), "name":"Даунтаун", "boss_name":"Винсент Крысолов", "icon":"🏙", "income":600, "color":"#e0b94a"},
    "southside":  {"hq":(70.,20.), "intel":(53.,20.), "sabotage":((60.,10.),(72.,30.),(83.,18.)), "escape":(95.,20.), "name":"Саутсайд", "boss_name":"Тони Кувалда", "icon":"🎰", "income":500, "color":"#9b59b6"},
    "industrial": {"hq":(70.,60.), "intel":(53.,60.), "sabotage":((60.,49.),(72.,70.),(83.,58.)), "escape":(95.,60.), "name":"Промзона", "boss_name":"Борис Шлак", "icon":"🏭", "income":550, "color":"#d2691e"},
    "coast":      {"hq":(156.,40.), "intel":(165.,40.), "sabotage":((154.,18.),(158.,65.),(178.,40.)), "escape":(196.,40.), "name":"Побережье", "boss_name":"Капитан Риццо", "icon":"⚓", "income":450, "color":"#2ecc71"},
}
district_owners = {}
district_captures = {}
district_loot = {}
world_c4 = {}
next_world_c4_id = 1
PREVIEW_START_X = 66.0
PREVIEW_START_Y = 162.5
PREVIEW_BEACHGOERS = [
    {"id": "preview_bg1", "x": 51.5, "y": 153.0, "ang": 0.3, "act": "walk", "gender": 0, "outfit": "#e74c3c", "skin": 1, "hair": 1},
    {"id": "preview_bg2", "x": 58.5, "y": 156.0, "ang": 2.1, "act": "idle", "gender": 1, "outfit": "#2ebbd1", "skin": 0, "hair": 2},
    {"id": "preview_bg3", "x": 61.0, "y": 152.5, "ang": 1.2, "act": "drink", "gender": 0, "outfit": "#f0b52d", "skin": 2, "hair": 3},
    {"id": "preview_bg4", "x": 48.5, "y": 157.0, "ang": 0.8, "act": "walk", "gender": 1, "outfit": "#9b69d8", "skin": 3, "hair": 0},
    {"id": "preview_bg5", "x": 63.5, "y": 155.0, "ang": 3.0, "act": "idle", "gender": 0, "outfit": "#38b96b", "skin": 0, "hair": 2},
    {"id": "preview_bg6", "x": 54.0, "y": 159.0, "ang": 1.7, "act": "icecream", "gender": 1, "outfit": "#ef6f9a", "skin": 1, "hair": 1},
]
RACE_SLOTS = [
    {"id": "race_preview_1", "model": "ferrari_f40", "x": 64.2, "y": 162.8, "ang": 1.5708},
    {"id": "race_preview_2", "model": "lambo_countach", "x": 66.0, "y": 162.8, "ang": 1.5708},
    {"id": "race_preview_3", "model": "porsche_911", "x": 67.8, "y": 162.8, "ang": 1.5708},
]
quest_cars = {}
preview_accounts = {}
preview_apartments = {}
preview_bank_robs = {}
PREVIEW_BANK_REWARD = {"small": 1200, "medium": 2500, "large": 5000}
PREVIEW_SHOP_WEAPONS = {
    "nagan":    {"name": "Наган",        "price": 250,   "canonical": "nagan"},
    "sawn_off": {"name": "Обрез",        "price": 600,   "canonical": "shotgun"},
    "uzi":      {"name": "Узи",          "price": 1500,  "canonical": "smg"},
    "revolver": {"name": "Револьвер",    "price": 5000,  "canonical": "pistol_heavy"},
    "m16":      {"name": "М-16",         "price": 42000, "canonical": "rifle"},
    "sniper":   {"name": "Снайперка",    "price": 32000, "canonical": "sniper"},
    "rpg":      {"name": "Базука",       "price": 50000, "canonical": "rpg"},
}
PREVIEW_SHOP_AMMO = {
    "ammo_9mm":    {"name": "Патроны 9 мм", "price": 120, "ammo_type": "9mm",    "rounds": 60},
    "ammo_magnum": {"name": ".357 Magnum",  "price": 180, "ammo_type": "magnum", "rounds": 24},
    "ammo_shell":  {"name": "12 калибр",    "price": 160, "ammo_type": "shell",  "rounds": 24},
    "ammo_rifle":  {"name": "5.56 мм",      "price": 260, "ammo_type": "rifle",  "rounds": 60},
    "ammo_sniper": {"name": "7.62 точные",  "price": 300, "ammo_type": "sniper", "rounds": 15},
    "ammo_rocket": {"name": "Заряды РПГ",   "price": 650, "ammo_type": "rocket", "rounds": 3},
}
PREVIEW_SHOP_CONSUMABLES = {
    "c4": {"name": "🧨 Заряд C4", "price": 350},
}


def preview_account(uid):
    account = preview_accounts.setdefault(str(uid), {
        "cash": 100000,
        "exp": 0,
        "weapons": {
            "pistol": {"name": "Пистолет", "canonical": "pistol"},
            "shotgun": {"name": "Дробовик", "canonical": "shotgun"},
        },
        "consumables": {"c4": 0},
    })
    account.setdefault("consumables", {}).setdefault("c4", 0)
    return account


def reset_race_cars():
    quest_cars.clear()
    for slot in RACE_SLOTS:
        quest_cars[slot["id"]] = make_race_car(slot)


def make_race_car(slot):
    return {
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
            "parked_at": time.time(),
        }


def tick_race_cars():
    """Keep one preview race car in every pit, like the real server does."""
    now = time.time()
    for slot in RACE_SLOTS:
        car = quest_cars.get(slot["id"])
        if car is None:
            quest_cars[slot["id"]] = make_race_car(slot)
            continue
        if car.get("driver_uid") is not None:
            continue
        away = abs(car["x"] - slot["x"]) >= 1.2 or abs(car["y"] - slot["y"]) >= 1.2
        if car.get("wrecked") or (away and now - car.get("parked_at", now) >= 12.0):
            park_race_car(car)


def slot_by_car_id(car_id):
    for slot in RACE_SLOTS:
        if slot["id"] == car_id:
            return slot
    return None


def park_race_car(car):
    slot = slot_by_car_id(car["id"])
    if not slot:
        return
    occupied_ids = []
    for other in quest_cars.values():
        if other["id"] == car["id"]:
            continue
        if abs(other["x"] - slot["x"]) < 1.2 and abs(other["y"] - slot["y"]) < 1.2:
            occupied_ids.append(other["id"])
    for car_id in occupied_ids:
        quest_cars.pop(car_id, None)
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


def release_car(car):
    """Освободить машину и оставить её там, где игрок вышел."""
    parked_now = time.time()
    car.update({
        "vx": 0.0,
        "vy": 0.0,
        "driver_uid": None,
        "passenger_uids": [],
        "state": "idle",
        "parked_at": parked_now,
        "_last_drive_t": parked_now,
    })


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


def preview_civilian_carjack(uid, data):
    global next_civ_car_id
    p = players.setdefault(uid, {})
    car_id = f"civ_preview_{next_civ_car_id}"
    next_civ_car_id += 1
    x = float(data.get("x", p.get("x", PREVIEW_START_X)))
    y = float(data.get("y", p.get("y", PREVIEW_START_Y)))
    model = str(data.get("model") or "corvette_c3")
    car = {
        "id": car_id,
        "model": model,
        "owner_uid": None,
        "driver_uid": uid,
        "passenger_uids": [],
        "x": x,
        "y": y,
        "ang": float(p.get("ang", 0.0)),
        "vx": 0.0,
        "vy": 0.0,
        "hp": 220,
        "max_hp": 220,
        "wrecked": False,
        "civilian": True,
    }
    quest_cars[car_id] = car
    p["x"] = x
    p["y"] = y
    p["ang"] = car["ang"]
    return {
        "ok": True,
        "car_id": car_id,
        "model": model,
        "x": x,
        "y": y,
        "civilian": True,
    }


reset_race_cars()


def release_player_cars(uid):
    for car in list(quest_cars.values()):
        if str(car.get("driver_uid")) == str(uid):
            release_car(car)


def race_top():
    race_day_roll()
    rows = sorted(race_best.values(), key=lambda row: row["ms"])[:5]
    return [
        {"uid": row["uid"], "name": row["name"], "ms": row["ms"], "car": row.get("car", "машина")}
        for row in rows
    ]


def race_day_roll():
    global race_day, race_best
    today = time.strftime("%Y-%m-%d")
    if race_day != today:
        race_day = today
        race_best = {}


def cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return resp


def district_at(x, y):
    for did, dd in DISTRICTS.items():
        hy, hx = dd["hq"]
        if (x - hx) ** 2 + (y - hy) ** 2 <= DIST_HQ_RAD ** 2:
            return did
    return None


def near_point(player, point, radius=DIST_ACTION_RAD):
    py, px = point
    return (player.get("x", 0) - px) ** 2 + (player.get("y", 0) - py) ** 2 <= radius ** 2


def make_district_defenders(did, dd):
    row, col = dd["intel"]
    bots = [{
        "id": f"preview_{did}_boss", "x": col, "y": row,
        "ang": 0.0, "hp": DIST_BOSS_HP, "max_hp": DIST_BOSS_HP,
        "kind": "district_boss", "weapon": "uzi", "act": "walk",
        "boss_name": dd["boss_name"], "alive": True, "damage": 8,
    }]
    guard_offsets = ((1.4, 0.8), (-1.2, 1.0), (0.8, -1.4), (-1.5, -0.7))
    for i, (dx, dy) in enumerate(guard_offsets):
        bots.append({
            "id": f"preview_{did}_guard_{i}", "x": col + dx, "y": row + dy,
            "ang": 0.0, "hp": DIST_GUARD_HP, "max_hp": DIST_GUARD_HP,
            "kind": "district_guard", "weapon": "pistol_heavy",
            "act": "walk", "alive": True, "damage": 12,
        })
    return bots


def tick_district_defenders(now, dt):
    """Preview AI: охрана замечает C4, выбегает из радиуса и отвечает огнём."""
    events = []
    for did, cap in district_captures.items():
        defenders = [b for b in (cap.get("defenders") or []) if b.get("alive")]
        noticed = cap.setdefault("noticed_world_c4", set())
        for bot_i, bot in enumerate(defenders):
            nearest = None
            nearest_dist = 1e9
            for charge in world_c4.values():
                dist = math.hypot(bot["x"]-charge["x"], bot["y"]-charge["y"])
                if dist <= DIST_C4_NOTICE_R and dist < nearest_dist:
                    nearest, nearest_dist = charge, dist
            bot["evading_c4"] = False
            if nearest is not None:
                cap["hostile_uid"] = str(nearest.get("owner_uid") or "")
                cap["hostile_until"] = now + 30.0
                charge_id = str(nearest.get("id") or "")
                if charge_id and charge_id not in noticed:
                    noticed.add(charge_id)
                    events.append({"kind":"district_guard_c4_evade",
                                   "gid":f"preview_district_{did}", "did":did,
                                   "charge_id":charge_id,
                                   "target_uid":cap["hostile_uid"]})
                if nearest_dist < DIST_C4_SAFE_R:
                    if nearest_dist < 0.05:
                        flee_ang = bot_i / max(1, len(defenders)) * math.tau
                    else:
                        flee_ang = math.atan2(bot["y"]-nearest["y"], bot["x"]-nearest["x"])
                    step = min(DIST_C4_FLEE_SPEED*dt, DIST_C4_SAFE_R-nearest_dist+0.35)
                    bot["x"] += math.cos(flee_ang)*step
                    bot["y"] += math.sin(flee_ang)*step
                    bot["ang"] = flee_ang
                    bot["evading_c4"] = True
                    continue
            target = players.get(str(cap.get("hostile_uid") or ""))
            if not target or target.get("dead") or now > float(cap.get("hostile_until") or 0):
                continue
            dx = target.get("x", 0)-bot["x"]; dy = target.get("y", 0)-bot["y"]
            dist = math.hypot(dx, dy)+1e-6
            bot["ang"] = math.atan2(dy, dx)
            if dist > 6.0:
                step = 1.5*dt
                bot["x"] += dx/dist*step; bot["y"] += dy/dist*step
            if dist <= 8.0 and now-float(bot.get("shot_at") or 0) >= (0.6 if bot["kind"]=="district_boss" else 1.1):
                bot["shot_at"] = now
                damage = int(bot.get("damage") or 8)
                target["hp"] = max(0, int(target.get("hp", 100))-damage)
                killed = target["hp"] <= 0
                if killed:
                    target["dead"] = True; target["respawn_at"] = now+5.0
                events.append({"kind":"aggro_shot", "tid":f"preview_district_{did}",
                               "bot_id":bot["id"], "target_uid":str(cap.get("hostile_uid") or ""),
                               "weapon":bot["weapon"], "sx":round(bot["x"],2), "sy":round(bot["y"],2),
                               "tx":round(target.get("x",0),2), "ty":round(target.get("y",0),2)})
                events.append({"kind":"aggro_apply", "tid":f"preview_district_{did}",
                               "bot_id":bot["id"], "target_uid":str(cap.get("hostile_uid") or ""),
                               "weapon":bot["weapon"], "miss":False, "dmg":damage, "killed":killed})
        noticed.intersection_update({str(q.get("id") or "") for q in world_c4.values()})
    return events


def preview_aggro_payload():
    result = {}
    now = time.time()
    for did, cap in district_captures.items():
        visible = []
        for i, bot in enumerate(cap.get("defenders") or []):
            if not bot.get("alive"):
                continue
            # Небольшой патруль вокруг точки сбора — в превью босс не стоит статуей.
            phase = now * 0.35 + i * 1.2
            out = {k: v for k, v in bot.items() if k != "alive"}
            if bot.get("evading_c4") or cap.get("hostile_uid"):
                out["x"] = round(bot["x"], 2); out["y"] = round(bot["y"], 2)
                out["ang"] = round(bot.get("ang", 0), 2)
            else:
                out["x"] = round(bot["x"] + 0.35 * math.cos(phase), 2)
                out["y"] = round(bot["y"] + 0.35 * math.sin(phase), 2)
                out["ang"] = round(phase + 1.57, 2)
            out["damage"] = int(bot.get("damage") or 0)
            out["evading_c4"] = bool(bot.get("evading_c4"))
            visible.append(out)
        result[f"preview_district_{did}"] = {
            "state": "patrol", "bots": visible, "covers": [],
            "cap_left": 0, "next_respawn": 0, "is_city_gang": True,
            "district_did": did,
        }
    return result


async def broadcast_event(data):
    blob = json.dumps({"t": "event", "d": data}, ensure_ascii=False)
    for client in list(clients):
        if not client.closed:
            try:
                await client.send_str(blob)
            except Exception:
                pass


async def options(_req):
    return cors(web.Response(status=204))


async def inv_list(req):
    account = preview_account(req.match_info.get("uid", "1"))
    items = [
        {"id": item_id, "item_id": item_id, "name": item["name"],
         "type": "weapon", "count": 1}
        for item_id, item in account["weapons"].items()
    ]
    c4_count = int(account["consumables"].get("c4", 0))
    if c4_count:
        items.append({"id": "c4", "item_id": "c4", "name": "🧨 Заряд C4",
                      "type": "throwable", "qty": c4_count, "count": c4_count})
    return cors(web.json_response({
        "ok": True,
        "items": items,
        "cash": account["cash"],
    }))


async def shop_buy(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    item_id = str(body.get("item_id", ""))
    item = (PREVIEW_SHOP_WEAPONS.get(item_id) or PREVIEW_SHOP_AMMO.get(item_id)
            or PREVIEW_SHOP_CONSUMABLES.get(item_id))
    if not item:
        return cors(web.json_response({"ok": False, "error": "unknown item"}, status=400))
    account = preview_account(uid)
    is_weapon = item_id in PREVIEW_SHOP_WEAPONS
    owned_classes = {w["canonical"] for w in account["weapons"].values()}
    if is_weapon and item["canonical"] in owned_classes:
        return cors(web.json_response({
            "ok": False, "error": "already owned", "cash": account["cash"],
        }))
    if account["cash"] < item["price"]:
        return cors(web.json_response({
            "ok": False, "error": "no cash", "cash": account["cash"],
        }))
    account["cash"] -= item["price"]
    if is_weapon:
        account["weapons"][item_id] = {
            "name": item["name"], "canonical": item["canonical"],
        }
    elif item_id in PREVIEW_SHOP_CONSUMABLES:
        account["consumables"][item_id] = int(account["consumables"].get(item_id, 0)) + 1
    return cors(web.json_response({
        "ok": True, "cash": account["cash"], "item_id": item_id,
        "ammo_type": item.get("ammo_type"), "rounds": item.get("rounds"),
    }))


async def leaderboard(_req):
    return cors(web.json_response({"ok": True, "items": []}))


async def newspaper(_req):
    now = int(time.time())
    return cors(web.json_response({
        "ok": True,
        "edition": time.strftime("%d.%m.%Y", time.localtime(now)),
        "generated_at": now,
        "hours": 24,
        "items": [
            {"id": 1, "kind": "district_captured", "icon": "🏙",
             "headline": "Demo захватил крупный район «Даунтаун»",
             "summary": "Над кварталом подняты новые цвета. Контроль приносит $600 за выплату.",
             "created_at": now - 7 * 60},
            {"id": 2, "kind": "bank_robbed", "icon": "🏦",
             "headline": "Неизвестные ограбили Центральный банк",
             "summary": "Очевидцы сообщают о мешках с наличными и машине без номеров. Полиция перекрыла мосты.",
             "created_at": now - 43 * 60},
            {"id": 3, "kind": "race_record", "icon": "🏁",
             "headline": "Vito установил рекорд трассы «Прибой»",
             "summary": "Ferrari F40: 1:24.38. Соперники уже готовят ответный заезд.",
             "created_at": now - 2 * 60 * 60},
            {"id": 4, "kind": "gang_nest_cleared", "icon": "💥",
             "headline": "Бандитское гнездо уничтожено",
             "summary": "После ночной перестрелки улицы ненадолго стали тише.",
             "created_at": now - 5 * 60 * 60},
        ],
    }))


async def district_status(req):
    uid = str(req.match_info.get("uid", "1"))
    now = time.time()
    rows = []
    for did, owner in district_owners.items():
        if str(owner.get("owner_uid")) != uid:
            continue
        dd = DISTRICTS.get(did, {})
        expires_at = float(owner.get("expires_at") or 0)
        if expires_at <= now:
            continue
        rows.append({
            "did": did, "name": dd.get("name", did), "icon": dd.get("icon", "🏴"),
            "captured_at": owner.get("captured_at", now), "expires_at": expires_at,
            "remaining_s": max(0, int(round(expires_at - now))),
            "income": int(dd.get("income") or 400),
            "income_xp": max(1, int(dd.get("income") or 400) // 20),
        })
    rows.sort(key=lambda row: row["remaining_s"])
    return cors(web.json_response({
        "ok": True, "uid": uid, "online": uid in players,
        "controls": bool(rows), "districts": rows, "server_time": int(now),
    }))


def preview_owned_apartments(uid):
    return preview_apartments.setdefault(str(uid), {})


APARTMENT_OWNERSHIP_LIMIT = 5


async def apartment_state(req):
    return cors(web.json_response({
        "ok": True, "owned": preview_owned_apartments(req.match_info.get("uid", "1")),
    }))


async def apartment_buy(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    apt_key = str(body.get("apt_key") or "").strip()[:32]
    price = max(1, int(body.get("price") or 0))
    if not apt_key or "," not in apt_key:
        return cors(web.json_response({"ok": False, "error": "bad apt"}, status=400))
    owned = preview_owned_apartments(uid)
    account = preview_account(uid)
    if apt_key in owned:
        return cors(web.json_response({"ok": True, "already": True, "cash": account["cash"], "owned": owned}))
    if len(owned) >= APARTMENT_OWNERSHIP_LIMIT:
        return cors(web.json_response({
            "ok": False, "error": "apartment limit",
            "count": len(owned), "limit": APARTMENT_OWNERSHIP_LIMIT, "owned": owned,
        }))
    if account["cash"] < price:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"]}))
    account["cash"] -= price
    owned[apt_key] = {
        "price": price, "bought_at": int(time.time()),
        "safe_level": 0, "weapon_rack_level": 0, "garage_level": 0,
        "cameras_level": 0, "repair_level": 0,
    }
    return cors(web.json_response({"ok": True, "cash": account["cash"], "owned": owned}))


async def apartment_upgrade(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    apt_key = str(body.get("apt_key") or "").strip()[:32]
    upgrade = str(body.get("upgrade") or "")
    cost = max(1, int(body.get("cost") or 0))
    cols = {"safe": "safe_level", "weapon_rack": "weapon_rack_level", "garage": "garage_level",
            "cameras": "cameras_level", "repair": "repair_level"}
    owned = preview_owned_apartments(uid)
    if apt_key not in owned:
        return cors(web.json_response({"ok": False, "error": "not owned"}))
    if upgrade not in cols:
        return cors(web.json_response({"ok": False, "error": "bad upgrade"}))
    account = preview_account(uid)
    if account["cash"] < cost:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"]}))
    account["cash"] -= cost
    key = cols[upgrade]
    owned[apt_key][key] = min(3, int(owned[apt_key].get(key, 0)) + 1)
    return cors(web.json_response({"ok": True, "cash": account["cash"], "owned": owned}))


async def apartment_sell(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    apt_key = str(body.get("apt_key") or "").strip()[:32]
    owned = preview_owned_apartments(uid)
    info = owned.get(apt_key)
    if not info:
        return cors(web.json_response({"ok": False, "error": "not owned"}))
    refund = max(0, int(info.get("price") or 0) * 90 // 100)
    account = preview_account(uid)
    account["cash"] += refund
    del owned[apt_key]
    return cors(web.json_response({
        "ok": True, "refund": refund, "cash": account["cash"], "owned": owned,
    }))


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
    tick_race_cars()
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
                "hp": int(p.get("hp", 100)),
                "max_hp": 100,
                "dead": bool(p.get("dead", False)),
                "respawn_in": max(0, int(round(float(p.get("respawn_at", 0))-time.time()))) if p.get("dead") else 0,
                "kills": 0,
                "deaths": 0,
                "cash": preview_account(uid)["cash"],
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
            "aggro": preview_aggro_payload(),
            "quest_cars": race_car_payload(),
            "beachgoers": PREVIEW_BEACHGOERS,
            "michael_guards": [],
            "gang_nests": [],
            "districts": {
                "owners": district_owners,
                "captures": {
                    did: {
                        "by_uid": cap["by_uid"], "by_name": cap["by_name"],
                        "color": cap["color"], "phase": cap["phase"],
                        "done": list(cap.get("done") or []),
                        "charges": [
                            {"target_index": int(idx),
                             "fuse_left": max(0.0, charge["explode_at"] - time.time())}
                            for idx, charge in (cap.get("charges") or {}).items()
                        ],
                        "boss_id": cap.get("boss_id"),
                        "boss_dead": bool(cap.get("boss_dead")),
                        "boss_name": cap.get("boss_name"),
                        "elapsed": max(0.0, time.time() - cap["started_at"]),
                        "expires_in": max(0, int(cap["expires_at"] - time.time())),
                        "safe_x": cap.get("safe_x"), "safe_y": cap.get("safe_y"),
                    }
                    for did, cap in district_captures.items()
                },
                "loot": list(district_loot.values()),
            },
            "world_c4": [
                {"id": q["id"], "owner_uid": q["owner_uid"], "owner_name": q["owner_name"],
                 "x": q["x"], "y": q["y"],
                 "fuse_left": max(0.0, q["explode_at"]-time.time())}
                for q in world_c4.values()
            ],
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
        "hp": 100,
        "dead": False,
    })
    ws = web.WebSocketResponse(heartbeat=20)
    await ws.prepare(req)
    clients.add(ws)
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
            now = time.time()
            for p in players.values():
                if p.get("dead") and now >= float(p.get("respawn_at", now + 1)):
                    p["dead"] = False
                    p["hp"] = 100
                    p["x"], p["y"] = PREVIEW_START_X, PREVIEW_START_Y
            for defender_event in tick_district_defenders(now, 1/15):
                await broadcast_event(defender_event)
            for charge_id, charge in list(world_c4.items()):
                if now < charge["explode_at"]:
                    continue
                world_c4.pop(charge_id, None)
                victims = []
                npc_victims = []
                for victim_uid, victim in players.items():
                    if victim.get("dead"):
                        continue
                    if math.hypot(victim.get("x", 0)-charge["x"], victim.get("y", 0)-charge["y"]) <= WORLD_C4_LETHAL_R:
                        victim["hp"] = 0
                        victim["dead"] = True
                        victim["respawn_at"] = now + 5.0
                        victims.append({"uid":str(victim_uid),"name":victim.get("name", "Игрок")})
                for did, cap in district_captures.items():
                    for bot in cap.get("defenders") or []:
                        if not bot.get("alive") or math.hypot(bot["x"]-charge["x"], bot["y"]-charge["y"]) > WORLD_C4_LETHAL_R:
                            continue
                        bot["hp"] = 0; bot["alive"] = False
                        is_boss = bot.get("kind") == "district_boss"
                        npc_victims.append({"bot_id":str(bot.get("id") or ""), "kind":bot.get("kind"),
                                            "did":did, "boss":is_boss})
                        if is_boss:
                            cap["boss_dead"] = True
                            loot_id=f"preview_cash_{did}_{int(now*1000)}"
                            district_loot[loot_id]={"id":loot_id,"did":did,"x":float(bot["x"]),"y":float(bot["y"]),
                                                    "amount":200,"expires_at":now+120.0}
                            if cap.get("phase") == "boss": cap["phase"] = "hq"
                await broadcast_event({"kind":"world_c4_exploded","id":charge_id,
                    "by_uid":charge["owner_uid"],"by_name":charge["owner_name"],
                    "x":charge["x"],"y":charge["y"],"lethal_r":WORLD_C4_LETHAL_R,
                    "victims":victims,"npc_victims":npc_victims})
            for loot_id, loot in list(district_loot.items()):
                if now >= float(loot.get("expires_at") or 0):
                    district_loot.pop(loot_id, None)
                    continue
                for picker_uid, picker in players.items():
                    if picker.get("dead") or math.hypot(picker.get("x",0)-loot["x"], picker.get("y",0)-loot["y"]) > 1.25:
                        continue
                    district_loot.pop(loot_id, None)
                    account=preview_account(str(picker_uid));account["cash"]+=int(loot.get("amount") or 200)
                    await broadcast_event({"kind":"district_boss_cash_picked","loot_id":loot_id,
                        "did":loot.get("did"),"picker_uid":str(picker_uid),
                        "picker_name":picker.get("name","Игрок"),"amount":int(loot.get("amount") or 200),
                        "new_cash":account["cash"]})
                    break
            for did, cap in list(district_captures.items()):
                if now >= cap.get("expires_at", 0):
                    district_captures.pop(did, None)
                    await broadcast_event({"kind": "district_operation_expired", "did": did,
                                           "by_uid": str(cap["by_uid"]), "by_name": cap["by_name"]})
                    continue
                for idx, charge in list((cap.get("charges") or {}).items()):
                    if now < charge.get("explode_at", now + 1):
                        continue
                    cap["charges"].pop(idx, None)
                    done = set(cap.get("done") or [])
                    done.add(int(idx))
                    cap["done"] = sorted(done)
                    dd = DISTRICTS[did]
                    if len(done) >= len(dd["sabotage"]):
                        cap["phase"] = "hq" if cap.get("boss_dead") else "boss"
                    row, col = dd["sabotage"][int(idx)]
                    await broadcast_event({
                        "kind": "district_c4_exploded", "did": did,
                        "by_uid": str(cap["by_uid"]), "target_index": int(idx),
                        "done": len(done), "total": len(dd["sabotage"]),
                        "phase": cap["phase"], "r": row, "c": col,
                        "boss_name": dd["boss_name"],
                    })
                holder=players.get(str(cap.get("by_uid")))
                if cap.get("phase")=="escape" and holder and holder.get("dead"):
                    cap["phase"]="safe_dropped";cap["safe_x"]=float(holder.get("x",0));cap["safe_y"]=float(holder.get("y",0))
                    await broadcast_event({"kind":"district_operation_setback","did":did,
                        "by_uid":str(cap["by_uid"]),"by_name":cap["by_name"],"phase":"safe_dropped",
                        "x":cap["safe_x"],"y":cap["safe_y"]})
                if cap.get("phase")=="safe_dropped":
                    for picker_uid,picker in players.items():
                        if picker.get("dead") or math.hypot(picker.get("x",0)-cap["safe_x"],picker.get("y",0)-cap["safe_y"])>1.25:
                            continue
                        old_uid=cap["by_uid"];cap["by_uid"]=str(picker_uid);cap["by_name"]=picker.get("name","Игрок")
                        cap["phase"]="escape";cap.pop("safe_x",None);cap.pop("safe_y",None)
                        await broadcast_event({"kind":"district_safe_intercepted","did":did,
                            "old_uid":str(old_uid),"by_uid":str(picker_uid),"by_name":cap["by_name"],
                            "name":DISTRICTS[did]["name"]})
                        break
            for did, owner in list(district_owners.items()):
                dd = DISTRICTS.get(did, {})
                if now >= float(owner.get("expires_at") or 0):
                    district_owners.pop(did, None)
                    await broadcast_event({
                        "kind": "district_control_lost", "did": did,
                        "name": dd.get("name", did), "icon": dd.get("icon", "🏴"),
                        "owner_uid": str(owner["owner_uid"]),
                        "owner_name": owner["owner_name"],
                        "boss_name": dd.get("boss_name", "Босс района"),
                    })
                    continue
                if now - float(owner.get("captured_at") or now) < DIST_INCOME_DELAY_S:
                    continue
                if now - float(owner.get("last_payout_at") or now) < DIST_INCOME_TICK_S:
                    continue
                owner["last_payout_at"] = now
                amount = int(dd.get("income") or 400)
                xp = max(1, amount // 20)
                account = preview_account(owner["owner_uid"])
                account["cash"] += amount
                account["exp"] += xp
                await broadcast_event({
                    "kind": "district_income", "did": did,
                    "name": dd.get("name", did), "icon": dd.get("icon", "🏴"),
                    "owner_uid": str(owner["owner_uid"]), "owner_name": owner["owner_name"],
                    "amount": amount, "xp": xp,
                    "new_cash": account["cash"], "new_exp": account["exp"],
                })
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
                if p.get("dead"):
                    continue
                p["x"] = float(d.get("x", p.get("x", 40.0)))
                p["y"] = float(d.get("y", p.get("y", 40.0)))
                p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                p["walking"] = bool(d.get("w", False))
            elif t == "district_capture_try":
                p = players.get(uid) or {}
                did = str(d.get("did") or "")
                dd = DISTRICTS.get(did)
                owner = district_owners.get(did)
                if not dd:
                    continue
                if owner:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                        "reason":"already_controlled","by_name":owner.get("owner_name", ""),
                        "wait_s":max(0, int(float(owner.get("expires_at") or time.time())-time.time()))}}))
                    continue
                cap = district_captures.get(did)
                if not cap:
                    own_active = sum(1 for active in district_captures.values()
                                     if str(active.get("by_uid")) == str(uid))
                    if own_active >= DIST_MAX_ACTIVE_PER_PLAYER:
                        await ws.send_str(json.dumps({"t":"event","d":{
                            "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                            "reason":"mission_limit","limit":DIST_MAX_ACTIVE_PER_PLAYER}}))
                        continue
                    if not near_point(p, dd["intel"]):
                        continue
                    cap = {"by_uid": str(uid), "by_name": str(p.get("name") or "Demo")[:24],
                           "color": dd["color"], "started_at": time.time(),
                           "expires_at": time.time() + DIST_OPERATION_TTL_S,
                           "phase": "sabotage", "done": [], "charges": {},
                           "boss_id": f"preview_{did}_boss", "boss_dead": False,
                           "boss_name": dd["boss_name"],
                           "defenders": make_district_defenders(did, dd)}
                    district_captures[did] = cap
                    await broadcast_event({"kind": "district_operation_started", "did": did,
                                           "by_uid": str(uid), "by_name": cap["by_name"],
                                           "color": cap["color"], "name": dd["name"], "icon": dd["icon"]})
                    continue
                if str(cap.get("by_uid")) != str(uid):
                    await broadcast_event({"kind": "district_capture_denied", "did": did,
                                           "by_uid": str(uid), "reason": "operation_busy",
                                           "by_name": cap.get("by_name", "")})
                    continue
                if cap["phase"] == "sabotage":
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "district_c4_denied", "did": did, "reason": "c4_required",
                        "by_uid": str(uid),
                    }}))
                elif cap["phase"] == "boss":
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "district_capture_denied", "did": did, "reason": "boss_alive",
                    }}))
                elif cap["phase"] == "hq" and near_point(p, dd["hq"]):
                    cap["phase"] = "escape"
                    await broadcast_event({"kind": "district_safe_stolen", "did": did,
                                           "by_uid": str(uid), "by_name": cap["by_name"],
                                           "name": dd["name"], "icon": dd["icon"]})
                elif cap["phase"] == "escape" and near_point(p, dd["escape"]):
                    now = time.time()
                    district_owners[did] = {"owner_uid":str(uid), "owner_name":cap["by_name"],
                                            "color":cap["color"], "captured_at":now,
                                            "last_payout_at":now,
                                            "expires_at":now + DIST_CONTROL_TTL_S,
                                            "income":dd["income"],
                                            "income_tick_s":DIST_INCOME_TICK_S,
                                            "income_delay_s":DIST_INCOME_DELAY_S,
                                            "income_xp":max(1, int(dd["income"]) // 20),
                                            "control_ttl_s":DIST_CONTROL_TTL_S}
                    district_captures.pop(did, None)
                    await broadcast_event({"kind":"district_captured", "did":did,
                                            "by_uid":str(uid), "by_name":cap["by_name"], "color":cap["color"],
                                           "name":dd["name"], "icon":dd["icon"], "income":dd["income"],
                                           "income_xp":max(1, int(dd["income"]) // 20),
                                           "income_tick_s":DIST_INCOME_TICK_S,
                                           "control_ttl_s":DIST_CONTROL_TTL_S})
            elif t == "district_c4_plant":
                p = players.get(uid) or {}
                did = str(d.get("did") or "")
                dd = DISTRICTS.get(did)
                cap = district_captures.get(did)
                reason = None
                target_idx = None
                if not dd or not cap or str(cap.get("by_uid")) != str(uid):
                    reason = "no_operation"
                elif cap.get("phase") != "sabotage":
                    reason = "wrong_phase"
                else:
                    done = set(cap.get("done") or [])
                    charged = {int(x) for x in (cap.get("charges") or {})}
                    target_idx = next((i for i, point in enumerate(dd["sabotage"])
                                       if i not in done and i not in charged and near_point(p, point)), None)
                    if target_idx is None:
                        reason = "not_near_target"
                account = preview_account(uid)
                if not reason and int(account["consumables"].get("c4", 0)) <= 0:
                    reason = "no_c4"
                if reason:
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "district_c4_denied", "did": did, "reason": reason,
                        "by_uid": str(uid),
                    }}))
                    continue
                account["consumables"]["c4"] -= 1
                cap["charges"][int(target_idx)] = {
                    "explode_at": time.time() + DIST_C4_FUSE_S,
                }
                await broadcast_event({
                    "kind": "district_c4_planted", "did": did, "by_uid": str(uid),
                    "target_index": int(target_idx), "fuse_s": DIST_C4_FUSE_S,
                })
            elif t == "world_c4_plant":
                global next_world_c4_id
                p = players.get(uid) or {}
                account = preview_account(uid)
                reason = None
                if p.get("dead"):
                    reason = "dead"
                elif int(account["consumables"].get("c4", 0)) <= 0:
                    reason = "no_c4"
                elif sum(1 for q in world_c4.values() if q["owner_uid"] == str(uid)) >= WORLD_C4_MAX_ACTIVE:
                    reason = "too_many"
                if reason:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"world_c4_denied","by_uid":str(uid),"reason":reason}}))
                    continue
                account["consumables"]["c4"] -= 1
                charge_id = f"preview_c4_{next_world_c4_id}"
                next_world_c4_id += 1
                charge = {"id":charge_id,"owner_uid":str(uid),
                    "owner_name":str(p.get("name") or "Demo")[:24],
                    "x":round(float(p.get("x", PREVIEW_START_X)),2),
                    "y":round(float(p.get("y", PREVIEW_START_Y)),2),
                    "explode_at":time.time()+WORLD_C4_FUSE_S}
                world_c4[charge_id] = charge
                await broadcast_event({"kind":"world_c4_planted","id":charge_id,
                    "by_uid":str(uid),"by_name":charge["owner_name"],
                    "x":charge["x"],"y":charge["y"],"fuse_s":WORLD_C4_FUSE_S})
            elif t == "aggro_shoot":
                target_id = str(d.get("target") or "")
                found = None
                found_did = None
                for did, cap in district_captures.items():
                    for bot in cap.get("defenders") or []:
                        if bot.get("alive") and str(bot.get("id")) == target_id:
                            found, found_did = bot, did
                            break
                    if found:
                        break
                if found:
                    damage = 42
                    found["hp"] = max(0, int(found["hp"]) - damage)
                    killed = found["hp"] <= 0
                    if killed:
                        found["alive"] = False
                    is_boss = found.get("kind") == "district_boss"
                    if killed and is_boss:
                        cap = district_captures[found_did]
                        cap["boss_dead"] = True
                        loot_id=f"preview_cash_{found_did}_{int(time.time()*1000)}"
                        district_loot[loot_id]={"id":loot_id,"did":found_did,
                            "x":float(found["x"]),"y":float(found["y"]),"amount":200,
                            "expires_at":time.time()+120.0}
                        if cap.get("phase") == "boss":
                            cap["phase"] = "hq"
                    p = players.get(uid) or {}
                    await broadcast_event({
                        "kind": "aggro_hit", "bot_id": target_id,
                        "hp": found["hp"], "damage": damage, "killed": killed,
                        "sy": p.get("y", 0), "sx": p.get("x", 0),
                        "ty": found["y"], "tx": found["x"],
                        "district_boss": is_boss, "did": found_did,
                    })
                    if killed:
                        await ws.send_str(json.dumps({"t": "event", "d": {
                            "kind": "aggro_killed", "bot_id": target_id,
                            "is_boss": is_boss, "cash": 0, "exp": 0,
                        }}))
            elif t == "district_capture_cancel":
                for did, cap in list(district_captures.items()):
                    if str(cap.get("by_uid")) == str(uid):
                        district_captures.pop(did, None)
                        await broadcast_event({"kind": "district_capture_cancelled", "did": did,
                                               "by_uid": str(uid), "reason": "cancelled"})
                        break
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
            elif t == "civilian_carjack":
                reply = preview_civilian_carjack(uid, d)
                await ws.send_str(json.dumps({"t": "event", "d": {**reply, "kind": "civilian_hijack_reply"}}))
                if reply.get("ok"):
                    spawn_pkt = json.dumps({"t": "event", "d": {
                        "kind": "quest_car_spawned",
                        "car_id": reply["car_id"],
                        "model": reply["model"],
                        "reward": 0,
                        "lock_lvl": 0,
                        "civilian": True,
                        "by_uid": uid,
                        "x": reply["x"],
                        "y": reply["y"],
                    }})
                    for other in list(clients):
                        if not other.closed:
                            await other.send_str(spawn_pkt)
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
                    release_car(car)
                    await ws.send_str(json.dumps({
                        "t": "event",
                        "d": {"kind": "gta_exit_reply", "ok": True,
                              "delivered": False, "car_id": car["id"],
                              "civilian": True},
                    }))
            elif t == "race_top":
                await ws.send_str(json.dumps({"t": "race_top", "d": {"top": race_top()}}))
            elif t == "race_lap":
                try:
                    lap_ms = int(d.get("ms") or 0)
                except Exception:
                    lap_ms = 0
                if 3000 <= lap_ms <= 1200000:
                    race_day_roll()
                    p = players.setdefault(uid, {})
                    cur = race_best.get(uid)
                    if cur is None or lap_ms < cur["ms"]:
                        race_best[uid] = {
                            "uid": uid,
                            "name": str(p.get("name") or "Demo")[:16],
                            "ms": lap_ms,
                            "car": str(d.get("car") or "машина")[:24],
                        }
                await ws.send_str(json.dumps({"t": "race_top", "d": {"top": race_top()}}))
            elif t == "respawn_status":
                await ws.send_str(json.dumps({
                    "t": "event",
                    "d": {"kind": "respawn_status", "ok": True, "point": "hospital"},
                }))
            elif t == "bank_rob_start":
                bank_id = str(d.get("bank_id") or "")
                if bank_id in PREVIEW_BANK_REWARD:
                    preview_bank_robs[str(uid)] = {
                        "bank_id": bank_id, "carried": 0, "bags_loaded": 0,
                        "started_at": time.time(),
                    }
            elif t == "bank_rob_bag_loaded":
                rob = preview_bank_robs.get(str(uid))
                if rob and rob.get("bank_id") == str(d.get("bank_id") or ""):
                    rob["bags_loaded"] = max(0, int(d.get("bags") or 0))
                    rob["carried"] = 0
            elif t == "bank_rob_bag_carried":
                bank_id = str(d.get("bank_id") or "")
                rob = preview_bank_robs.get(str(uid))
                if rob and rob.get("bank_id") == bank_id:
                    rob["carried"] = 1
                    rob["bags_loaded"] = max(0, int(d.get("bags_loaded") or 0))
            elif t == "bank_bag_drop":
                rob = preview_bank_robs.get(str(uid))
                if rob:
                    rob["carried"] = 0
                    if d.get("confiscated"):
                        preview_bank_robs.pop(str(uid), None)
            elif t == "bank_rob_apartment_deliver":
                bank_id = str(d.get("bank_id") or "")
                apt_key = str(d.get("apt_key") or "").strip()[:32]
                rob = preview_bank_robs.get(str(uid))
                reason = None
                if not rob or rob.get("bank_id") != bank_id:
                    reason = "no_active_robbery"
                elif not rob.get("carried"):
                    reason = "no_carried_bag"
                elif apt_key not in preview_owned_apartments(uid):
                    reason = "not_owner"
                if reason:
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "bank_rob_finished", "bank_id": bank_id,
                        "ok": False, "reason": reason, "payout": 0,
                    }}))
                else:
                    payout = PREVIEW_BANK_REWARD.get(bank_id, 0)
                    account = preview_account(uid)
                    account["cash"] += payout
                    preview_bank_robs.pop(str(uid), None)
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "bank_rob_finished", "bank_id": bank_id,
                        "ok": True, "payout": payout, "bags": 1,
                        "cash": account["cash"], "place": "apartment",
                        "apt_key": apt_key,
                    }}, ensure_ascii=False))
    finally:
        task.cancel()
        clients.discard(ws)
        release_player_cars(uid)
        players.pop(uid, None)
    return ws


app = web.Application()
app.router.add_route("OPTIONS", "/{tail:.*}", options)
app.router.add_get("/preview/world.html", preview_world)
app.router.add_get("/coop_api.json", coop_api)
app.router.add_get("/world/sim", world_ws)
app.router.add_get("/inv/{uid}/list", inv_list)
app.router.add_post("/shop/{uid}/buy", shop_buy)
app.router.add_get("/world/leaderboard", leaderboard)
app.router.add_get("/world/newspaper", newspaper)
app.router.add_get("/world/district_status/{uid}", district_status)
app.router.add_get("/apartment/{uid}/state", apartment_state)
app.router.add_post("/apartment/{uid}/buy", apartment_buy)
app.router.add_post("/apartment/{uid}/upgrade", apartment_upgrade)
app.router.add_post("/apartment/{uid}/sell", apartment_sell)


if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=8080)
