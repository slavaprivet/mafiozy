import asyncio
import json
import math
import random
import secrets
from pathlib import Path
import time
from aiohttp import web

BASE_DIR = Path(__file__).resolve().parent


players = {}
preview_pending_lair_shots = []
PREVIEW_LAIR_WEAPON_SPEED = {
    "pistol": 14.0, "pistol_heavy": 13.0, "pistol_gold": 14.0,
    "shotgun": 11.0, "smg": 16.0, "uzi": 16.0,
    "rifle": 20.0, "sniper": 32.0, "rpg": 8.0,
}
PREVIEW_LAIR_DODGE_RADIUS = 1.3
gang_player_invites = {}  # target_uid -> {from_uid, expires_at}
race_best = {}
race_day = ""
next_civ_car_id = 1
clients = set()
TAXI_COST = 50
TAXI_DESTINATIONS = {
    "beach": (145, 40), "blackmarket": (6, 36), "gym": (26, 26),
    "job": (36, 16), "hospital": (26, 46), "police": (76, 76),
    "arena": (36, 66), "market": (16, 16), "port": (165, 38),
    "casino": (13, 45), "industrial": (46, 56), "firestation": (56, 26),
    "lair": (120, 40), "bank:small": (7, 17), "bank:medium": (17, 57),
    "bank:large": (57, 37),
}
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
    "northside":  {"bounds":(0,39,0,39), "hq":(20.,20.), "intel":(11.,20.), "sabotage":((14.,12.),(20.,29.),(29.,18.)), "escape":(35.,20.), "name":"Норт-Сайд", "boss_name":"Мясник Морелло", "icon":"🏪", "income":400, "color":"#4aa3df"},
    "downtown":   {"bounds":(0,39,40,79), "hq":(20.,60.), "intel":(11.,60.), "sabotage":((15.,49.),(19.,70.),(30.,58.)), "escape":(35.,60.), "name":"Даунтаун", "boss_name":"Винсент Крысолов", "icon":"🏙", "income":600, "color":"#e0b94a"},
    "southside":  {"bounds":(40,99,0,39), "hq":(70.,20.), "intel":(53.,20.), "sabotage":((60.,10.),(72.,30.),(83.,18.)), "escape":(95.,20.), "name":"Саутсайд", "boss_name":"Тони Кувалда", "icon":"🎰", "income":500, "color":"#9b59b6"},
    "industrial": {"bounds":(40,99,40,79), "hq":(70.,60.), "intel":(53.,60.), "sabotage":((60.,49.),(72.,70.),(83.,58.)), "escape":(95.,60.), "name":"Промзона", "boss_name":"Борис Шлак", "icon":"🏭", "income":550, "color":"#d2691e"},
    "coast":      {"bounds":(150,199,0,79), "hq":(156.,40.), "intel":(165.,40.), "sabotage":((157.,14.),(158.,65.),(178.,40.)), "escape":(196.,40.), "name":"Побережье", "boss_name":"Капитан Риццо", "icon":"⚓", "income":450, "color":"#2ecc71"},
}
district_owners = {}
district_captures = {}
district_loot = {}
world_c4 = {}
next_world_c4_id = 1
PREVIEW_GANG_NESTS = [{
    "id": "preview_nest_1", "r": 26.0, "c": 26.0,
    "state": "guard", "expires_in": 3600, "bots_alive": 4,
}]
PREVIEW_BUSINESS_POS = {
    "coffee": (13.0, 33.0), "carwash": (25.0, 23.0),
    "barbershop": (23.0, 53.0), "pizza": (53.0, 53.0),
    "garage": (63.0, 13.0), "bar": (33.0, 43.0),
    "club": (53.0, 63.0), "warehouse": (23.0, 73.0),
    "casino": (45.0, 13.0), "port": (31.0, 181.0),
}
PREVIEW_BOX_DROPOFFS = [
    ("coffee", "Кофейня", *PREVIEW_BUSINESS_POS["coffee"]),
    ("carwash", "Автомойка", *PREVIEW_BUSINESS_POS["carwash"]),
    ("barbershop", "Парикмахерская", *PREVIEW_BUSINESS_POS["barbershop"]),
    ("pizza", "Пиццерия", *PREVIEW_BUSINESS_POS["pizza"]),
    ("garage", "Автосервис", *PREVIEW_BUSINESS_POS["garage"]),
    ("bar", "Бар «Чёрная вдова»", *PREVIEW_BUSINESS_POS["bar"]),
    ("club", "Подпольный клуб", *PREVIEW_BUSINESS_POS["club"]),
    ("warehouse", "Склад", *PREVIEW_BUSINESS_POS["warehouse"]),
    ("casino", "Казино", *PREVIEW_BUSINESS_POS["casino"]),
    ("port", "Порт", *PREVIEW_BUSINESS_POS["port"]),
]
PREVIEW_NPC_CAPTURE_COOLDOWN = 2 * 3600
preview_business_nests = {}
preview_business_capture_cooldown = {}
preview_business_next_capture_at = time.time() + 20.0
PREVIEW_MAJOR_OBJECTS = {
    "casino": {"r": 46.0, "c": 16.0, "name": "Казино",
               "boss": "Сальваторе «Фишка» Моретти",
               "guards": 20, "total": 40, "income": 2400},
    "market": {"r": 16.0, "c": 16.0, "name": "Рынок",
               "boss": "Рафаэль «Весы» Конти",
               "guards": 20, "total": 34, "income": 1200},
    "factory": {"r": 46.0, "c": 56.0, "name": "Промзона",
                "boss": "Бруно «Пресс» Ферретти",
                "guards": 24, "total": 40, "income": 3000},
    "mansion": {"r": 66.0, "c": 36.0, "name": "Резиденция",
                "boss": "Дон Эмилио Витале",
                "guards": 28, "total": 40, "income": 4200},
    "port": {"r": 165.0, "c": 38.0, "name": "Порт",
             "boss": "Марко «Якорь» Беллини",
             "guards": 22, "total": 38, "income": 2600},
}
preview_major_raids = {}
preview_major_owners = {}


def preview_major_payload():
    now = time.time()
    for object_id, owner in list(preview_major_owners.items()):
        if float(owner.get("expires_at") or 0) <= now:
            preview_major_owners.pop(object_id, None)
    result = {}
    for object_id, cfg in PREVIEW_MAJOR_OBJECTS.items():
        owner = preview_major_owners.get(object_id)
        raid = preview_major_raids.get(object_id)
        result[object_id] = {
            "name": cfg["name"], "boss_name": cfg["boss"],
            "owner_uid": owner.get("owner_uid") if owner else None,
            "owner_name": owner.get("owner_name") if owner else cfg["boss"],
            "expires_in": max(
                0, int(float(owner.get("expires_at") or 0) - now)
            ) if owner else 0,
            "income": int(cfg["income"]),
            "raid": ({
                "phase": raid.get("phase"),
                "participant_uids": list(raid.get("participants") or []),
                "alive": sum(
                    1 for guard in raid.get("guards", [])
                    if guard.get("alive")),
                "spawned": int(raid.get("spawned") or 0),
                "total": int(cfg["total"]),
                "pressure": int(raid.get("pressure") or 0),
            } if raid else None),
        }
    return result


def preview_bandit_bot(bot_id, x, y, kind="aggro_grunt", weapon="pistol_heavy", hp=100, level=None):
    if level is None:
        level = 25 if kind == "aggro_boss" else (
            random.randint(10, 20) if kind == "aggro_elite" else random.randint(1, 18))
    level = max(1, min(25, int(level)))
    scaled_hp = int(round(hp * (1.0 + (level - 1) * 0.05)))
    base_damage = 24 if kind == "aggro_boss" else 18
    return {
        "id": bot_id, "x": float(x), "y": float(y), "ang": 0.0,
        "hp": scaled_hp, "max_hp": scaled_hp, "level": level,
        "kind": kind, "weapon": weapon,
        "damage": int(round(base_damage * (1.0 + (level - 1) * 0.03))), "act": "idle",
        "home_x": float(x), "home_y": float(y), "patrol_x": float(x), "patrol_y": float(y),
        "patrol_until": 0.0, "shot_at": 0.0, "threat": "", "threat_until": 0.0,
        "chatter_at": time.time() + random.uniform(3.0, 9.0), "alive": True,
        "look": {"gender":0, "skin":1 + (sum(map(ord, bot_id)) % 3),
                 "body":2, "face":1, "hair":0, "hat":4, "gang":1},
    }


def preview_ignite_bandit(bot, shooter, data):
    now = time.time()
    try:
        fire_x = float(data.get("fire_x"))
        fire_y = float(data.get("fire_y"))
    except (TypeError, ValueError):
        fire_x = float(shooter.get("x", 0))
        fire_y = float(shooter.get("y", 0))
    if (not math.isfinite(fire_x) or not math.isfinite(fire_y)
            or math.hypot(fire_x-float(shooter.get("x", 0)),
                          fire_y-float(shooter.get("y", 0))) > 7.5
            or math.hypot(fire_x-float(bot.get("x", 0)),
                          fire_y-float(bot.get("y", 0))) > 5.0):
        fire_x = float(shooter.get("x", 0))
        fire_y = float(shooter.get("y", 0))
    if now >= float(bot.get("fire_flee_until") or 0):
        dx, dy = float(bot["x"])-fire_x, float(bot["y"])-fire_y
        if math.hypot(dx, dy) < .08:
            angle = (sum(map(ord, str(bot.get("id") or ""))) % 360) * math.pi / 180
        else:
            angle = math.atan2(dy, dx)
        seed = sum(map(ord, str(bot.get("id") or "")))
        angle += ((seed % 9)-4)*.13
        distance = 6.5 + seed % 4
        bot["fire_flee_x"] = max(1.5, min(78.5, bot["x"]+math.cos(angle)*distance))
        bot["fire_flee_y"] = max(1.5, min(198.5, bot["y"]+math.sin(angle)*distance))
    bot["burn_until"] = max(float(bot.get("burn_until") or 0), now+4.8)
    bot["fire_flee_until"] = max(float(bot.get("fire_flee_until") or 0), now+3.8)
    bot["burning"] = True
    bot["act"] = "walk"
    bot["threat"] = "Горю! Врассыпную!"
    bot["threat_until"] = now+1.8


def preview_tick_fire_flee(bot, now, dt, bounds=None):
    bot["burning"] = now < float(bot.get("burn_until") or 0)
    if now >= float(bot.get("fire_flee_until") or 0):
        return False
    dx = float(bot.get("fire_flee_x", bot["x"]))-bot["x"]
    dy = float(bot.get("fire_flee_y", bot["y"]))-bot["y"]
    dist = math.hypot(dx, dy)
    if dist < .18:
        bot["fire_flee_until"] = now
        return False
    step = min(dist, 3.6*max(0.0, dt))
    direct = math.atan2(dy, dx)
    for turn in (0., .38, -.38, .76, -.76, 1.14, -1.14):
        angle = direct+turn
        nx, ny = bot["x"]+math.cos(angle)*step, bot["y"]+math.sin(angle)*step
        if bounds and not (bounds[0] <= nx <= bounds[1] and bounds[2] <= ny <= bounds[3]):
            continue
        bot["x"], bot["y"], bot["ang"], bot["act"] = nx, ny, angle, "walk"
        return True
    return True


PREVIEW_LAIR_BOTS = [
    preview_bandit_bot("preview_lair_boss", 40.0, 120.0, "aggro_boss", "uzi", 240),
]
for _lair_i in range(20):
    _lair_ring = _lair_i // 5
    _lair_ang = (_lair_i % 5) * math.tau / 5 + _lair_ring * 0.43
    _lair_radius = (4.5, 8.0, 11.5, 15.0)[_lair_ring]
    _lair_elite = _lair_i < 4
    _lair_bot = preview_bandit_bot(
        f"preview_lair_{_lair_i + 1}",
        40.0 + math.cos(_lair_ang) * _lair_radius,
        120.0 + math.sin(_lair_ang) * _lair_radius,
        kind="aggro_elite" if _lair_elite else "aggro_grunt",
        weapon=("shotgun", "rifle", "pistol_heavy", "smg")[_lair_i % 4]
               if _lair_elite else ("pistol_heavy", "smg", "rifle")[_lair_i % 3],
        hp=162 if _lair_elite else 100,
    )
    if _lair_elite:
        _lair_bot["look"].update({"body":3, "hat":3})
    PREVIEW_LAIR_BOTS.append(_lair_bot)
PREVIEW_NEST_BOTS = [
    preview_bandit_bot("cgbot_preview_nest_1", 24.5, 23.5),
    preview_bandit_bot("cgbot_preview_nest_2", 27.5, 23.5, weapon="smg"),
    preview_bandit_bot("cgbot_preview_nest_3", 23.5, 26.5),
    preview_bandit_bot("cgbot_preview_nest_4", 23.5, 28.5, weapon="rifle"),
]
preview_lair_warned = {}


def tick_preview_lair(now, dt):
    events = []
    pending = []
    for shot in preview_pending_lair_shots:
        if now < float(shot["apply_at"]):
            pending.append(shot)
            continue
        target = players.get(str(shot["target_uid"]))
        if not target or target.get("dead"):
            continue
        miss = math.hypot(
            float(target.get("x", 0)) - float(shot["tx"]),
            float(target.get("y", 0)) - float(shot["ty"]),
        ) > PREVIEW_LAIR_DODGE_RADIUS
        damage = 0 if miss else int(shot["damage"])
        if damage:
            target["hp"] = max(0, int(target.get("hp", 100)) - damage)
        killed = bool(damage and target["hp"] <= 0)
        if killed:
            target["dead"] = True
            target["respawn_at"] = now + 5
        events.append({
            "kind":"aggro_apply","tid":"preview_lair","bot_id":shot["bot_id"],
            "target_uid":str(shot["target_uid"]),"weapon":shot["weapon"],
            "miss":miss,"dmg":damage,"killed":killed,
            "sx":shot["sx"],"sy":shot["sy"],"tx":shot["tx"],"ty":shot["ty"],
        })
    preview_pending_lair_shots[:] = pending
    for index, bot in enumerate(list(PREVIEW_LAIR_BOTS)):
        if bot.get("alive") or now-float(bot.get("dead_at") or now) < 45.0:
            continue
        # Новая жизнь — новый бросок уровня и заново рассчитанные HP/урон.
        # Босс остаётся финальным противником 25 уровня.
        replacement = preview_bandit_bot(
            bot["id"], bot.get("home_x", 40.0), bot.get("home_y", 120.0),
            kind=bot.get("kind") or "aggro_grunt",
            weapon=bot.get("weapon") or "pistol_heavy",
            hp=240 if bot.get("kind") == "aggro_boss" else (
                162 if bot.get("kind") == "aggro_elite" else 100))
        if bot.get("kind") == "aggro_elite":
            replacement["look"].update({"body":3, "hat":3})
        PREVIEW_LAIR_BOTS[index] = replacement
        preview_lair_warned.clear()
    in_zone = {
        str(uid): p for uid, p in players.items()
        if not p.get("dead") and (p.get("_mode") or "pvp") != "pve"
        and abs(float(p.get("x", 0))-40.0) <= 20
        and abs(float(p.get("y", 0))-120.0) <= 20
    }
    for uid in list(preview_lair_warned):
        if uid not in in_zone:
            preview_lair_warned.pop(uid, None)
            if players.get(uid): players[uid]["lair_hostile"] = False
    for uid, p in in_zone.items():
        if uid not in preview_lair_warned:
            preview_lair_warned[uid] = now
            events.append({"kind":"aggro_warn","tid":"preview_lair",
                           "bot_id":"preview_lair_boss","target_uid":uid,
                           "text":"Не ищи проблем. Уходи из логова."})
        elif now-preview_lair_warned[uid] >= 3.0 and not p.get("lair_hostile"):
            p["lair_hostile"] = True
            events.append({"kind":"aggro_hostile","tid":"preview_lair","target_uid":uid,
                           "text":"Ты не ушёл. Теперь пеняй на себя!"})
    for bot in PREVIEW_LAIR_BOTS:
        if not bot.get("alive"):
            continue
        if preview_tick_fire_flee(bot, now, dt, (20.0, 60.0, 100.0, 140.0)):
            continue
        targets=[p for p in in_zone.values() if p.get("lair_hostile")]
        target=min(targets,key=lambda p:(p["x"]-bot["x"])**2+(p["y"]-bot["y"])**2) if targets else None
        bot["act"]="idle"
        if target:
            dx,dy=float(target["x"])-bot["x"],float(target["y"])-bot["y"]
            dist=math.hypot(dx,dy)+1e-6;bot["ang"]=math.atan2(dy,dx)
            if dist>4.2:
                step=min(dist,(1.35 if bot["kind"]=="aggro_boss" else 1.05)*dt)
                bot["x"]+=dx/dist*step;bot["y"]+=dy/dist*step;bot["act"]="walk"
            if dist<=9 and now-float(bot.get("shot_at") or 0)>=1.0:
                bot["shot_at"]=now
                damage=int(bot.get("damage") or 18)
                weapon=str(bot.get("weapon") or "pistol_heavy")
                speed=float(PREVIEW_LAIR_WEAPON_SPEED.get(weapon,14.0))
                target_uid=str(target.get("uid") or "")
                sx,sy=float(bot["x"]),float(bot["y"])
                tx,ty=float(target["x"]),float(target["y"])
                preview_pending_lair_shots.append({
                    "bot_id":bot["id"],"target_uid":target_uid,"weapon":weapon,
                    "damage":damage,"sx":sx,"sy":sy,"tx":tx,"ty":ty,
                    "apply_at":now+dist/max(1.0,speed),
                })
                events.append(
                    {"kind":"aggro_shot","tid":"preview_lair","bot_id":bot["id"],
                     "target_uid":target_uid,"weapon":weapon,"bullet_speed":speed,
                     "sx":sx,"sy":sy,"tx":tx,"ty":ty}
                )
        else:
            if now>=float(bot.get("patrol_until") or 0):
                a=random.random()*math.tau;r=random.uniform(2.0,17.0)
                bot["patrol_x"]=40+math.cos(a)*r;bot["patrol_y"]=120+math.sin(a)*r
                bot["patrol_until"]=now+random.uniform(5,10)
            dx,dy=bot["patrol_x"]-bot["x"],bot["patrol_y"]-bot["y"];dist=math.hypot(dx,dy)
            if dist>.2:
                step=min(dist,.72*dt);bot["x"]+=dx/dist*step;bot["y"]+=dy/dist*step
                bot["ang"]=math.atan2(dy,dx);bot["act"]="walk"
            if now>=float(bot.get("chatter_at") or 0):
                bot["threat"]=random.choice(["Это наша земля.","Чего уставился?","Проходи мимо.","Где моё пиво?"])
                bot["threat_until"]=now+2.4;bot["chatter_at"]=now+random.uniform(7,14)
            if now>float(bot.get("threat_until") or 0):bot["threat"]=""
    return events
PREVIEW_STREET_GANGS = [
    ("preview_city_gang_1", 12.0, 33.0),
    ("preview_city_gang_2", 52.0, 63.0),
]
PREVIEW_START_X = 66.0
PREVIEW_START_Y = 162.5
PREVIEW_HOSPITAL_X = 43.0
PREVIEW_HOSPITAL_Y = 23.0
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
preview_bank_bags = {}
preview_businesses = {}
preview_business_closures = {}
preview_business_aggro = {}
preview_business_rob_cycles = {}
preview_business_rob_sessions = {}
preview_business_last_robs = {}
PREVIEW_ROB_PERSONAL_COOLDOWN_S = 3600
PREVIEW_ROB_GUARDS = {
    "coffee":1, "carwash":2, "barbershop":2, "pizza":3, "garage":4,
    "bar":4, "club":5, "warehouse":6, "casino":8, "port":10,
}
PREVIEW_ROB_INTERIOR_WIDTHS = {
    "coffee":16, "carwash":18, "barbershop":18, "pizza":19, "garage":21,
    "bar":21, "club":23, "warehouse":25, "casino":28, "port":30,
}


def preview_robber_at_cashier(player, biz_id):
    if not player or str(player.get("business_interior") or "") != str(biz_id):
        return False
    width = PREVIEW_ROB_INTERIOR_WIDTHS.get(str(biz_id))
    if not width:
        return False
    try:
        dx = float(player.get("interior_x", 0)) - width / 2
        dy = float(player.get("interior_y", 0)) - 2.9
    except (TypeError, ValueError):
        return False
    return dx * dx + dy * dy <= 16.0


preview_business_police_protection = {}
preview_business_owner_protection = {}
preview_police_rewards = set()
preview_gta_quests = {}
preview_box_quests = {}
PREVIEW_BOX_GROUND_TTL_S = 5 * 60


def preview_drop_box(owner_uid, reason="manual"):
    owner_uid = str(owner_uid)
    p = players.get(owner_uid)
    q = preview_box_quests.get(owner_uid)
    if not p or not q or q.get("state") not in ("carrying", "loaded"):
        return {"ok": False, "reason": "wrong_state"}
    business_id = str(p.get("business_interior") or "")
    if business_id:
        gx = float(p.get("interior_x") or 0)
        gy = float(p.get("interior_y") or 0)
        space = "business"
    else:
        gx = float(p.get("x") or 0)
        gy = float(p.get("y") or 0)
        space = "world"
    now = time.time()
    q.update({
        "state": "ground", "ground_x": gx, "ground_y": gy,
        "ground_space": space, "ground_business_id": business_id,
        "ground_dropped_at": now,
        "ground_expires_at": now + PREVIEW_BOX_GROUND_TTL_S,
        "ground_reason": str(reason or "manual")[:24],
    })
    q.pop("car_id", None)
    return {
        "ok": True, "state": "ground", "owner_uid": owner_uid,
        "ground_x": gx, "ground_y": gy, "ground_space": space,
        "ground_business_id": business_id,
        "expires_in": PREVIEW_BOX_GROUND_TTL_S,
        "reason": str(reason or "manual")[:24],
    }


def preview_pickup_box(uid, owner_uid=""):
    uid, owner_uid = str(uid), str(owner_uid or uid)
    p, q = players.get(uid), preview_box_quests.get(owner_uid)
    if not p or not q:
        return {"ok": False, "reason": "no_quest"}
    if q.get("state") == "ground":
        same_business = (
            q.get("ground_space") == "business" and
            str(p.get("business_interior") or "") ==
            str(q.get("ground_business_id") or "")
        )
        same_world = q.get("ground_space") == "world" and not p.get("business_interior")
        px = float(p.get("interior_x") or 0) if same_business else float(p.get("x") or 0)
        py = float(p.get("interior_y") or 0) if same_business else float(p.get("y") or 0)
        if not (same_business or same_world) or math.hypot(
                px-float(q.get("ground_x") or 0),
                py-float(q.get("ground_y") or 0)) > 2:
            return {"ok": False, "reason": "too_far"}
        if owner_uid != uid:
            return {"ok": False, "reason": "foreign_box", "owner_uid": owner_uid}
        q["state"] = "carrying"
        for key in ("ground_x", "ground_y", "ground_space",
                    "ground_business_id", "ground_dropped_at",
                    "ground_expires_at", "ground_reason"):
            q.pop(key, None)
        return {"ok": True, "state": "carrying", "source": "ground"}
    if owner_uid != uid:
        return {"ok": False, "reason": "foreign_box", "owner_uid": owner_uid}
    if q.get("state") != "pending":
        return {"ok": False, "reason": "wrong_state"}
    if math.hypot(float(p.get("x", 0))-float(q["pickup_x"]),
                  float(p.get("y", 0))-float(q["pickup_y"])) > 2:
        return {"ok": False, "reason": "too_far"}
    q["state"] = "carrying"
    return {"ok": True, "state": "carrying", "source": "pier"}
PREVIEW_BUSINESSES = {
    "coffee": (3000,150,200,"☕","Кофейня «У Дона»"), "carwash": (5000,220,300,"🚗","Автомойка"),
    "barbershop": (7500,300,400,"💈","Парикмахерская"), "pizza": (12000,450,600,"🍕","Пиццерия"),
    "garage": (18000,650,900,"🔧","Гараж-СТО"), "bar": (28000,1000,1400,"🍸","Бар «Чёрная вдова»"),
    "club": (45000,1600,2200,"🎰","Подпольный клуб"), "warehouse": (70000,2400,3300,"📦","Склад"),
    "casino": (120000,4000,5500,"🎲","Казино"), "port": (200000,6500,9000,"⚓","Порт"),
}
PREVIEW_BUSINESS_RC = {
    "coffee":(33,13), "carwash":(23,25), "barbershop":(53,23),
    "pizza":(53,53), "garage":(13,63), "bar":(43,33), "club":(63,53),
    "warehouse":(73,23), "casino":(13,45),
    "port":(181,31),
}
PREVIEW_ROB_PAYOUT = {
    "coffee":(200,1), "carwash":(300,1), "barbershop":(400,1),
    "pizza":(600,1), "garage":(900,2), "bar":(1300,2), "club":(2000,2),
    "warehouse":(3200,2), "casino":(5000,3),
    "port":(8000,3),
}
PREVIEW_BIZ_MULT = {1:1.0,2:1.35,3:1.75,4:2.25,5:3.0}
PREVIEW_BIZ_UP = {2:.45,3:.75,4:1.15,5:1.70}
PREVIEW_BANK_REWARD = {"small": 1200, "medium": 2500, "large": 5000}
PREVIEW_SHOP_WEAPONS = {
    "nagan":    {"name": "Наган",        "price": 250,   "canonical": "nagan"},
    "sawn_off": {"name": "Обрез",        "price": 600,   "canonical": "shotgun"},
    "uzi":      {"name": "Узи",          "price": 1500,  "canonical": "smg"},
    "revolver": {"name": "Мафиозный револьвер", "price": 5000, "canonical": "revolver"},
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


PREVIEW_SHOP_CONSUMABLES.update({
    "grenade":{"name":"Граната","price":50},
    "molotov":{"name":"Коктейль Молотова","price":130},
    "medkit_small":{"name":"Малая аптечка","price":25,"type":"potion","heal":55},
    "medkit_medium":{"name":"Аптечка","price":60,"type":"potion","heal":130},
    "medkit_large":{"name":"Большая аптечка","price":120,"type":"potion","heal":280},
})
PREVIEW_SHOP_ARMOR = {
    "leather_jacket":{"name":"Кожанка","price":180,"defense_bonus":12},
    "bulletproof":{"name":"Бронежилет","price":450,"defense_bonus":28},
    "kevlar_vest":{"name":"Кевларовый жилет","price":1200,"defense_bonus":38},
    "tactical_vest":{"name":"Тактический жилет","price":2500,"defense_bonus":50},
    "army_armor":{"name":"Армейская броня","price":5000,"defense_bonus":62},
    "swat_suit":{"name":"Костюм спецназа","price":9000,"defense_bonus":78},
    "composite_armor":{"name":"Композитный доспех","price":16000,"defense_bonus":95},
    "exo_armor":{"name":"Экзо-броня","price":28000,"defense_bonus":120},
}


def preview_account(uid):
    account = preview_accounts.setdefault(str(uid), {
        # Тестовый баланс локального превью. Реальные аккаунты и база бота
        # этим сервером не используются.
        "cash": 1000000,
        "hp": 45,
        "max_hp": 100,
        "exp": 0,
        # Превью используется для проверки открытых полицейских способностей.
        "police_xp": 2800,
        "mafia_xp": 0,
        "skills": {"safecracker": 0, "marksman": 0, "stealth": 0, "toughness": 0, "hustler": 0},
        "said_hired": False,
        "said_hired_at": 0,
        "said_paid_until": 0,
        "weapons": {
            "pistol": {"name": "Пистолет", "canonical": "pistol"},
        },
        "consumables": {"c4": 0, "grenade": 12, "molotov": 12},
        "armor": {}, "equipped_armor": None,
        "found": {}, "wanted": 0,
    })
    account.setdefault("consumables", {}).setdefault("c4", 0)
    account["consumables"].setdefault("grenade", 12)
    account["consumables"].setdefault("molotov", 12)
    account.setdefault("armor", {})
    account.setdefault("found", {})
    account.setdefault("skills", {"safecracker": 0, "marksman": 0, "stealth": 0, "toughness": 0, "hustler": 0})
    return account


def preview_bandit_kill_reward(uid, target_level, base_exp=8):
    """Server-authoritative preview reward for a career bandit kill."""
    player = players.get(str(uid)) or {}
    account = preview_account(uid)
    level = max(1, min(25, int(target_level or 1)))
    career_gain = 5 + level * 2
    main_gain = max(int(base_exp or 0), 3 + level)
    account["exp"] = int(account.get("exp", 0)) + main_gain
    result = {"exp": main_gain, "target_level": level}
    if player.get("police"):
        old = int(account.get("police_xp", 0))
        account["police_xp"] = min(2800, old + career_gain)
        result.update({"police_xp": account["police_xp"],
                       "police_xp_gain": account["police_xp"] - old})
    elif player.get("mafia"):
        old = int(account.get("mafia_xp", 0))
        account["mafia_xp"] = min(4000, old + career_gain)
        result.update({"mafia_xp": account["mafia_xp"],
                       "mafia_xp_gain": account["mafia_xp"] - old})
    return result


PREVIEW_SKILL_COSTS = [0, 500, 2000, 5000, 12000, 30000]
PREVIEW_SKILL_IDS = {"safecracker", "marksman", "stealth", "toughness", "hustler"}


async def skill_state(req):
    account = preview_account(req.match_info.get("uid", "1"))
    return cors(web.json_response({"ok": True, "cash": account["cash"], "skills": account["skills"],
        "costs": PREVIEW_SKILL_COSTS}))


async def skill_upgrade(req):
    account = preview_account(req.match_info.get("uid", "1"))
    try:
        body = await req.json()
    except Exception:
        body = {}
    skill = str(body.get("skill") or "")
    if skill not in PREVIEW_SKILL_IDS:
        return cors(web.json_response({"ok": False, "error": "unknown skill"}, status=400))
    current = max(0, min(5, int(account["skills"].get(skill, 0))))
    if current >= 5:
        return cors(web.json_response({"ok": False, "error": "maxed"}))
    cost = PREVIEW_SKILL_COSTS[current + 1]
    if account["cash"] < cost:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"]}))
    account["cash"] -= cost
    account["skills"][skill] = current + 1
    return cors(web.json_response({"ok": True, "cash": account["cash"], "level": current + 1,
        "skills": account["skills"], "costs": PREVIEW_SKILL_COSTS}))


def preview_police_daily_state(uid):
    account = preview_account(uid)
    day = time.strftime("%Y-%m-%d", time.localtime())
    if account.get("police_daily_day") != day:
        account["police_daily_day"] = day
        account["police_daily_count"] = 0
    xp = max(0, int(account.get("police_xp", 0)))
    level = 1 + sum(1 for threshold in (300, 800, 1600, 2800) if xp >= threshold)
    limit = (3, 6, 9, 12, None)[level-1]
    return account, int(account.get("police_daily_count", 0)), limit


def preview_claim_police_arrest(uid):
    account, count, limit = preview_police_daily_state(uid)
    if limit is not None and count >= limit:
        return {"ok":False,"error":"daily_limit","count":count,"limit":limit}
    count += 1
    account["police_daily_count"] = count
    return {"ok":True,"count":count,"limit":limit}


def preview_said_state(uid):
    account = preview_account(uid)
    now = time.time()
    charged = 0
    auto_fired = False
    if account.get("said_hired") and now >= float(account.get("said_paid_until") or 0):
        paid_until = float(account.get("said_paid_until") or now)
        periods = int((now - paid_until) // 86400) + 1
        due = periods * 500
        if account["cash"] >= due:
            account["cash"] -= due
            account["said_paid_until"] = paid_until + periods * 86400
            charged = due
        else:
            account["said_hired"] = False
            account["said_hired_at"] = 0
            account["said_paid_until"] = 0
            auto_fired = True
    return {"hired": bool(account.get("said_hired")), "salary": 500,
        "hired_at": int(account.get("said_hired_at") or 0),
        "next_salary_at": int(account.get("said_paid_until") or 0),
        "salary_charged": charged, "auto_fired": auto_fired, "cash": account["cash"]}


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
        "owner_uid": uid,
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
    if car.get("police_patrol") and not car.get("police_stolen"):
        car["owner_uid"] = None
        car["siren"] = False


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
            "civilian": bool(car.get("civilian", True)),
            "police_patrol": bool(car.get("police_patrol", False)),
            "police_stolen": bool(car.get("police_stolen", False)),
            "siren": bool(car.get("siren", False)),
            "tires_punctured": bool(car.get("tires_punctured", False)),
            "called_patrol": bool(car.get("called_patrol", False)),
            "expires_at": float(car.get("expires_at", 0)),
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


def preview_police_patrol(uid):
    global next_civ_car_id
    cop = players.get(uid, {})
    if not cop.get("police"):
        return {"ok": False, "error": "not_police"}
    cooldown_left = 180 - (time.time() - float(cop.get("police_patrol_called_at", 0)))
    if cooldown_left > 0:
        return {"ok": False, "error": "cooldown", "cooldown_left": round(cooldown_left, 1)}
    for car in quest_cars.values():
        if str(car.get("driver_uid") or "") == str(uid):
            return {"ok": False, "error": "already_driving"}
    free = [car for car in quest_cars.values() if car.get("police_patrol")
            and not car.get("police_stolen") and not car.get("driver_uid") and not car.get("wrecked")]
    if free:
        nearest = min(free, key=lambda car: (float(car.get("x", 0))-float(cop.get("x", PREVIEW_START_X)))**2
                                           +(float(car.get("y", 0))-float(cop.get("y", PREVIEW_START_Y)))**2)
        if (nearest["x"]-float(cop.get("x", PREVIEW_START_X)))**2 + (nearest["y"]-float(cop.get("y", PREVIEW_START_Y)))**2 <= 18**2:
            cop["police_patrol_called_at"] = time.time()
            return {"ok": True, "existing": True, "car_id": nearest["id"], "x": nearest["x"], "y": nearest["y"]}
    car_id = f"police_patrol_preview_{next_civ_car_id}"
    next_civ_car_id += 1
    ang = float(cop.get("ang", 0.0))
    x = float(cop.get("x", PREVIEW_START_X)) + math.cos(ang) * 1.8
    y = float(cop.get("y", PREVIEW_START_Y)) + math.sin(ang) * 1.8
    quest_cars[car_id] = {
        "id": car_id, "model": "cruiser", "owner_uid": None, "driver_uid": None,
        "passenger_uids": [], "x": x, "y": y, "ang": ang, "vx": 0.0, "vy": 0.0,
        "hp": 350, "max_hp": 350, "wrecked": False, "civilian": True,
        "police_patrol": True, "police_stolen": False, "siren": False, "tires_punctured": False,
        "called_patrol": True, "expires_at": time.time() + 60,
        "state": "idle", "_last_drive_t": 0.0,
    }
    cop["police_patrol_called_at"] = time.time()
    return {"ok": True, "car_id": car_id, "x": x, "y": y}


def preview_career_vehicle(uid, data):
    """Create the police/mafia career vehicle used by the local game preview."""
    global next_civ_car_id
    p = players.get(uid, {})
    if not p or p.get("dead") or p.get("business_interior"):
        return {"ok": False, "error": "dead" if p and p.get("dead") else "interior"}
    role = "police" if p.get("police") else ("mafia" if p.get("mafia") else "")
    if not role:
        return {"ok": False, "error": "not_employed"}
    if str(data.get("role") or role) != role:
        return {"ok": False, "error": "wrong_role"}
    account = preview_account(uid)
    xp = int(account.get("police_xp" if role == "police" else "mafia_xp", 0))
    thresholds = (300, 800, 1600, 2800) if role == "police" else (250, 700, 1500, 2800)
    level = 1 + sum(1 for threshold in thresholds if xp >= threshold)
    kind = "air" if str(data.get("kind") or "ground") == "air" else "ground"
    if kind == "air":
        if level < 5:
            return {"ok": False, "error": "level_locked"}
        model, hp = (("police_heli", 650) if role == "police" else ("mafia_heli", 650))
    else:
        tiers = ({1:("cruiser",350),3:("paddyvan",520),5:("swat_truck",800)} if role == "police"
                 else {1:("harley_chopper",240),3:("gold_limo",480),5:("mafia_armored",760)})
        unlocked = max(tier for tier in tiers if level >= tier)
        model, hp = tiers[unlocked]
    cooldown_key = "career_air_called_at" if kind == "air" else "career_ground_called_at"
    now = time.time()
    cooldown_left = 65 - (now - float(p.get(cooldown_key, 0)))
    if cooldown_left > 0:
        return {"ok": False, "error": "cooldown", "cooldown_left": round(cooldown_left, 1)}
    car_id = f"career_{role}_{kind}_{next_civ_car_id}"
    next_civ_car_id += 1
    ang = float(p.get("ang", 0.0)); x = float(p.get("x", PREVIEW_START_X)) + math.cos(ang)*2.2; y = float(p.get("y", PREVIEW_START_Y)) + math.sin(ang)*2.2
    quest_cars[car_id] = {"id":car_id,"model":model,"owner_uid":uid,"driver_uid":None,"passenger_uids":[],
        "x":x,"y":y,"ang":ang,"vx":0.0,"vy":0.0,"hp":hp,"max_hp":hp,"wrecked":False,
        "civilian":False,"career_vehicle":True,"career_role":role,"career_owner_uid":uid,
        "police_patrol":role=="police","police_stolen":False,"siren":False,"tires_punctured":False,
        "expires_at":now+300,"state":"idle","_last_drive_t":0.0}
    p[cooldown_key] = now
    return {"ok":True,"car_id":car_id,"model":model,"role":role,"level":level,"vehicle_kind":kind,"x":x,"y":y}


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


def preview_district_patrol_ok(did, x, y):
    """Упрощённая копия серверной проходимости для районной банды."""
    x, y = round(float(x), 2), round(float(y), 2)
    dd = DISTRICTS.get(str(did), {})
    r0, r1, c0, c1 = dd.get("bounds", (1, 198, 1, 78))
    if str(did) == "coast":
        r1 = min(r1, 164.99)  # ниже начинается вода и гоночный комплекс
    if not (c0 + .5 <= x <= c1 + .499 and r0 + .5 <= y <= r1 + .499):
        return False
    ri, ci = int(y), int(x)
    if ri >= 140:
        return ri < 165  # песчаная пешеходная полоса Побережья
    rm, cm = ri % 10, ci % 10
    if rm <= 4 or rm == 9 or cm <= 4 or cm == 9:
        return True
    h = ((ri // 10) * 17 + (ci // 10) * 31) % 11
    return h in (0, 7)  # парк; остальные внутренности квартала — здания


def nearest_preview_district_point(did, x, y):
    if preview_district_patrol_ok(did, x, y):
        return float(x), float(y)
    for radius in range(1, 48):
        for dr in range(-radius, radius + 1):
            for dc in range(-radius, radius + 1):
                if abs(dr) != radius and abs(dc) != radius:
                    continue
                nx, ny = int(x) + dc + .5, int(y) + dr + .5
                if preview_district_patrol_ok(did, nx, ny):
                    return nx, ny
    hy, hx = DISTRICTS.get(str(did), {}).get("hq", (20., 20.))
    return float(hx), float(hy)


def make_district_defenders(did, dd):
    row, col = dd["intel"]
    col, row = nearest_preview_district_point(did, col, row)
    bots = [{
        "id": f"preview_{did}_boss", "x": col, "y": row,
        "ang": 0.0, "hp": DIST_BOSS_HP, "max_hp": DIST_BOSS_HP,
        "kind": "district_boss", "weapon": "uzi", "act": "walk",
        "boss_name": dd["boss_name"], "alive": True, "damage": 8,
        "home_x": col, "home_y": row, "patrol_phase": 0.0,
        "patrol_turn_sign": random.choice((-1, 1)), "patrol_stuck": 0,
    }]
    guard_offsets = ((1.4, 0.8), (-1.2, 1.0), (0.8, -1.4), (-1.5, -0.7))
    for i, (dx, dy) in enumerate(guard_offsets):
        gx, gy = nearest_preview_district_point(did, col + dx, row + dy)
        bots.append({
            "id": f"preview_{did}_guard_{i}", "x": gx, "y": gy,
            "ang": 0.0, "hp": DIST_GUARD_HP, "max_hp": DIST_GUARD_HP,
            "kind": "district_guard", "weapon": "pistol_heavy",
            "act": "walk", "alive": True, "damage": 12,
            "home_x": col, "home_y": row, "patrol_phase": (i + 1) * math.tau / 4,
            "patrol_turn_sign": random.choice((-1, 1)), "patrol_stuck": 0,
        })
    return bots


def preview_drop_district_dossier(did, cap, bot, now):
    for loot_id, loot in list(district_loot.items()):
        if loot.get("kind") == "dossier" and str(loot.get("did") or "") == str(did):
            district_loot.pop(loot_id, None)
    loot_id = f"preview_dossier_{did}_{int(now*1000)}"
    district_loot[loot_id] = {
        "id": loot_id, "kind": "dossier", "did": did,
        "x": float(bot["x"]), "y": float(bot["y"]), "expires_at": now + 120.0,
    }
    cap["boss_dead"] = True
    cap["phase"] = "dossier"
    cap["dossier_id"] = loot_id
    cap["respawn_at"] = now + 125.0


def ensure_preview_district_bosses(now):
    for did, dd in DISTRICTS.items():
        cap = district_captures.get(did)
        if did in district_owners:
            if cap and cap.get("phase") in ("boss_patrol", "dossier"):
                district_captures.pop(did, None)
            continue
        if not cap:
            district_captures[did] = {
                "by_uid": "", "by_name": "", "color": dd["color"],
                "started_at": now, "expires_at": now + 365 * 86400,
                "phase": "boss_patrol", "done": [], "charges": {},
                "boss_id": f"preview_{did}_boss", "boss_dead": False,
                "boss_name": dd["boss_name"], "defenders": make_district_defenders(did, dd),
            }
            continue
        if cap.get("phase") not in ("boss_patrol", "dossier"):
            continue
        dossier_exists = any(q.get("kind") == "dossier" and str(q.get("did") or "") == did
                             for q in district_loot.values())
        boss = next((
            b for b in cap.get("defenders") or []
            if str(b.get("id") or "") == str(cap.get("boss_id") or "")
            or b.get("kind") == "district_boss"
        ), None)
        boss_alive = bool(boss and boss.get("alive") and int(boss.get("hp") or 0) > 0)
        # Fire and other periodic damage may kill between two network snapshots.
        # Always reconcile that dead boss into a physical dossier before respawn.
        if not dossier_exists and boss is not None and not boss_alive:
            preview_drop_district_dossier(did, cap, boss, now)
            continue
        if dossier_exists or boss_alive or now < float(cap.get("respawn_at") or 0):
            continue
        cap.update({"phase":"boss_patrol", "boss_dead":False, "started_at":now,
                    "expires_at":now + 365 * 86400,
                    "boss_id":f"preview_{did}_boss", "defenders":make_district_defenders(did, dd)})
        cap.pop("dossier_id", None)


def tick_district_defenders(now, dt):
    """Preview AI: охрана отвечает только на попадание или установленный C4."""
    events = []
    for did, cap in district_captures.items():
        defenders = [b for b in (cap.get("defenders") or []) if b.get("alive")]
        boss = next((b for b in defenders if b.get("kind") == "district_boss"), None)
        dd = DISTRICTS.get(did, {})
        waypoint = cap.get("patrol_wp")
        if boss and "patrol_progress_at" not in cap:
            cap["patrol_progress_at"] = now
            cap["patrol_progress_xy"] = (boss["x"], boss["y"])
        if boss and now - float(cap.get("patrol_progress_at") or now) >= 3.0:
            px, py = cap.get("patrol_progress_xy") or (boss["x"], boss["y"])
            if math.hypot(boss["x"]-px, boss["y"]-py) < 0.55:
                cap["patrol_wp_until"] = 0.0
            cap["patrol_progress_xy"] = (boss["x"], boss["y"])
            cap["patrol_progress_at"] = now
        if boss and (not waypoint or math.hypot(waypoint[0]-boss["x"], waypoint[1]-boss["y"]) < 1.35
                     or now >= float(cap.get("patrol_wp_until") or 0)):
            r0,r1,c0,c1 = dd.get("bounds", (0,199,0,79))
            for _ in range(80):
                tx,ty = random.uniform(c0+3,c1-3),random.uniform(r0+3,r1-3)
                if (math.hypot(tx-boss["x"],ty-boss["y"]) >= 12
                        and preview_district_patrol_ok(did, tx, ty)):
                    waypoint=(tx,ty);cap["patrol_wp"]=waypoint;cap["patrol_wp_until"]=now+random.uniform(22,34);break
        noticed = cap.setdefault("noticed_world_c4", set())
        # Само участие в операции, доверие и уровень не дают агро.
        for bot_i, bot in enumerate(defenders):
            r0, r1, c0, c1 = dd.get("bounds", (0, 199, 0, 79))
            if preview_tick_fire_flee(bot, now, dt, (c0 + 1, c1 - 1, r0 + 1, r1 - 1)):
                bot["evading_c4"] = False
                continue
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
                    nx = bot["x"] + math.cos(flee_ang)*step
                    ny = bot["y"] + math.sin(flee_ang)*step
                    if preview_district_patrol_ok(did, nx, ny):
                        bot["x"], bot["y"], bot["ang"] = nx, ny, flee_ang
                        bot["evading_c4"] = True
                        continue
            target = players.get(str(cap.get("hostile_uid") or ""))
            if (not target or target.get("dead")
                    or (target.get("_mode") or "pvp") == "pve"
                    or now > float(cap.get("hostile_until") or 0)):
                cap.pop("hostile_uid", None)
                cap.pop("hostile_until", None)
                # Босс ведёт группу к общей далёкой точке по всему району;
                # охрана сохраняет строй, а не вращается каждый по своей орбите.
                tx,ty = waypoint if waypoint else (bot["x"],bot["y"])
                if bot_i:
                    formation=(bot_i-1)*math.tau/max(1,len(defenders)-1)
                    tx+=math.cos(formation)*1.65;ty+=math.sin(formation)*1.35
                dx, dy = tx-bot["x"], ty-bot["y"]
                dist = math.hypot(dx,dy)+1e-6
                step = min(dist, 1.05*dt)
                direct = math.atan2(dy, dx)
                turn_sign = int(bot.get("patrol_turn_sign") or 1)
                turns = (0., turn_sign*.42, turn_sign*.82, turn_sign*1.22,
                         -turn_sign*.42, -turn_sign*.82, -turn_sign*1.22)
                moved = False
                for turn in turns:
                    ang = direct + turn
                    nx = bot["x"] + math.cos(ang)*step
                    ny = bot["y"] + math.sin(ang)*step
                    if preview_district_patrol_ok(did, nx, ny):
                        bot["x"], bot["y"], bot["ang"] = nx, ny, ang
                        bot["patrol_stuck"] = 0
                        moved = True
                        break
                if not moved:
                    bot["patrol_stuck"] = int(bot.get("patrol_stuck") or 0) + 1
                    if bot["patrol_stuck"] > 18:
                        cap["patrol_wp_until"] = 0.0
                        bot["patrol_turn_sign"] = -turn_sign
                        bot["patrol_stuck"] = 0
                continue
            dx = target.get("x", 0)-bot["x"]; dy = target.get("y", 0)-bot["y"]
            dist = math.hypot(dx, dy)+1e-6
            bot["ang"] = math.atan2(dy, dx)
            if dist > 6.0:
                step = 1.5*dt
                direct = math.atan2(dy, dx)
                for turn in (0., .42, -.42, .82, -.82, 1.25, -1.25):
                    ang = direct + turn
                    nx = bot["x"] + math.cos(ang)*step
                    ny = bot["y"] + math.sin(ang)*step
                    if preview_district_patrol_ok(did, nx, ny):
                        bot["x"], bot["y"], bot["ang"] = nx, ny, ang
                        break
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
    preview_tick_business_captures()
    for did, cap in district_captures.items():
        visible = []
        for i, bot in enumerate(cap.get("defenders") or []):
            if not bot.get("alive"):
                continue
            out = {k: v for k, v in bot.items() if k != "alive"}
            # Координаты уже меняет полноценный patrol AI. Старое декоративное
            # вращение поверх них могло визуально столкнуть NPC в стену/воду.
            out["x"] = round(bot["x"], 2); out["y"] = round(bot["y"], 2)
            out["ang"] = round(bot.get("ang", 0), 2)
            out["damage"] = int(bot.get("damage") or 0)
            out["evading_c4"] = bool(bot.get("evading_c4"))
            out["burning"] = now < float(bot.get("burn_until") or 0)
            out["fleeing_fire"] = now < float(bot.get("fire_flee_until") or 0)
            visible.append(out)
        result[f"preview_district_{did}"] = {
            "state": "patrol", "bots": visible, "covers": [],
            "cap_left": 0, "next_respawn": 0, "is_city_gang": True,
            "district_did": did,
        }
    result["preview_lair"] = {
        "state": "alive", "bots": [
            dict(bot,
                 burning=now < float(bot.get("burn_until") or 0),
                 fleeing_fire=now < float(bot.get("fire_flee_until") or 0))
            for bot in PREVIEW_LAIR_BOTS
        ],
        "covers": [], "cap_left": 0, "next_respawn": 0,
    }
    result["preview_nest_1"] = {
        "state": "guard", "bots": [dict(bot, act="idle") for bot in PREVIEW_NEST_BOTS],
        "covers": [], "cap_left": 0, "next_respawn": 0, "is_nest": True,
    }
    for bid, nest in preview_business_nests.items():
        result[nest["id"]] = {
            "state": nest["state"],
            "bots": [dict(
                        bot,
                        act=bot.get("act") if (nest["state"] == "hostile"
                                              or now < float(bot.get("fire_flee_until") or 0)) else "idle",
                        burning=now < float(bot.get("burn_until") or 0),
                        fleeing_fire=now < float(bot.get("fire_flee_until") or 0))
                     for bot in nest["bots"] if bot.get("alive")],
            "covers": [], "cap_left": 0, "next_respawn": 0,
            "is_nest": True, "faction": nest["faction"],
        }
    patrol = now * 0.32
    for gang_i, (gang_id, base_x, base_y) in enumerate(PREVIEW_STREET_GANGS):
        faction = "yellow" if gang_i % 2 else "purple"
        phase = patrol + gang_i * math.pi
        center_x = base_x + math.sin(phase) * 6.0
        direction = 0.0 if math.cos(phase) >= 0 else math.pi
        bots = []
        for i in range(3):
            bot = preview_bandit_bot(
                f"cgbot_preview_street_{gang_i}_{i}",
                center_x - i * 1.15, base_y + (i - 1) * 0.45,
                weapon=("pistol_heavy", "smg", "rifle")[i],
            )
            bot["ang"] = direction
            if faction == "yellow":
                bot["look"].update({"skin": (0, 2, 3)[i], "body": 4,
                                    "hat": 2, "gang": 2})
            bots.append(bot)
        result[gang_id] = {
            "state": "patrol", "bots": bots, "covers": [],
            "cap_left": 0, "next_respawn": 0, "is_city_gang": True,
            "faction": faction,
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
    for iid in ("grenade","molotov","medkit_small","medkit_medium","medkit_large"):
        qty=int(account["consumables"].get(iid,0))
        if qty>0:
            items.append({"id":iid,"item_id":iid,"name":PREVIEW_SHOP_CONSUMABLES[iid]["name"],
                          "type":PREVIEW_SHOP_CONSUMABLES[iid].get("type","throwable"),"qty":qty,"count":qty,
                          "heal":PREVIEW_SHOP_CONSUMABLES[iid].get("heal")})
    for item_id, item in account["armor"].items():
        items.append({"id":item_id,"item_id":item_id,"name":item["name"],"type":"armor",
                      "qty":1,"count":1,"defense_bonus":item.get("defense_bonus",0)})
    found_defs={"lost_phone":("Потерянный телефон",180),"lost_wallet":("Потерянный кошелёк",120),"lost_keys":("Связка чужих ключей",70)}
    for item_id,qty in account["found"].items():
        if qty>0:
            name,price=found_defs[item_id];items.append({"id":item_id,"item_id":item_id,"name":name,"type":"thing","qty":qty,"count":qty,"sell_price":price})
    return cors(web.json_response({
        "ok": True,
        "items": items,
        "cash": account["cash"],
        "equipped_armor": account.get("equipped_armor"),
    }))


async def inv_equip(req):
    account=preview_account(req.match_info.get("uid","1"))
    try:
        body=await req.json()
    except Exception:
        body={}
    item_id=str(body.get("item_id") or "")
    if item_id and item_id not in account["armor"]:
        return cors(web.json_response({"ok":False,"error":"not in inventory"},status=400))
    account["equipped_armor"]=item_id or None
    return cors(web.json_response({"ok":True,"equipped_armor":account["equipped_armor"]}))


async def inv_consume(req):
    uid=str(req.match_info.get("uid","1"))
    account=preview_account(uid)
    try:
        body=await req.json()
    except Exception:
        body={}
    iid=str(body.get("item_id") or "")
    medkits={"medkit_small":55,"medkit_medium":130,"medkit_large":280}
    if iid in medkits:
        player=players.get(uid)
        if player and (player.get("dead") or float(player.get("combat_until",0))>time.time()):
            return cors(web.json_response({"ok":False,"error":"in combat"},status=409))
        hp=int(player.get("hp",account["hp"])) if player else int(account["hp"])
        max_hp=int(player.get("max_hp",account["max_hp"])) if player else int(account["max_hp"])
        if hp>=max_hp:return cors(web.json_response({"ok":False,"error":"full hp"},status=409))
        if int(account["consumables"].get(iid,0))<=0:return cors(web.json_response({"ok":False,"error":"not in inventory"},status=400))
        healed=min(medkits[iid],max_hp-hp);hp+=healed;account["hp"]=hp;account["max_hp"]=max_hp;account["consumables"][iid]-=1
        if player:player["hp"]=hp
        return cors(web.json_response({"ok":True,"item_id":iid,"hp":hp,"max_hp":max_hp,"healed":healed,"left":account["consumables"][iid]}))
    if iid not in ("grenade","molotov") or int(account["consumables"].get(iid,0))<=0:
        return cors(web.json_response({"ok":False,"error":"not in inventory"},status=400))
    account["consumables"][iid]-=1
    return cors(web.json_response({"ok":True,"left":account["consumables"][iid]}))


async def inv_found(req):
    account=preview_account(req.match_info.get("uid","1"))
    try: body=await req.json()
    except Exception: body={}
    iid={"phone":"lost_phone","wallet":"lost_wallet","keys":"lost_keys"}.get(str(body.get("kind") or ""))
    if not iid:return cors(web.json_response({"ok":False,"error":"bad item"},status=400))
    account["found"][iid]=int(account["found"].get(iid,0))+1
    prices={"lost_phone":180,"lost_wallet":120,"lost_keys":70}
    return cors(web.json_response({"ok":True,"item":{"id":iid,"type":"thing","qty":account["found"][iid],"sell_price":prices[iid]}}))


async def inv_sell_found(req):
    account=preview_account(req.match_info.get("uid","1"))
    try: body=await req.json()
    except Exception: body={}
    iid=str(body.get("item_id") or "");prices={"lost_phone":180,"lost_wallet":120,"lost_keys":70}
    if iid not in prices or int(account["found"].get(iid,0))<=0:return cors(web.json_response({"ok":False,"error":"not in inventory"},status=400))
    account["found"][iid]-=1;account["cash"]+=prices[iid]
    return cors(web.json_response({"ok":True,"cash":account["cash"],"item_id":iid,"price":prices[iid],"caught":False,"wanted":account.get("wanted",0),"return_streak":0}))


async def shop_buy(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    item_id = str(body.get("item_id", ""))
    item = (PREVIEW_SHOP_WEAPONS.get(item_id) or PREVIEW_SHOP_AMMO.get(item_id)
            or PREVIEW_SHOP_CONSUMABLES.get(item_id) or PREVIEW_SHOP_ARMOR.get(item_id))
    if not item:
        return cors(web.json_response({"ok": False, "error": "unknown item"}, status=400))
    account = preview_account(uid)
    is_weapon = item_id in PREVIEW_SHOP_WEAPONS
    is_armor = item_id in PREVIEW_SHOP_ARMOR
    owned_classes = {w["canonical"] for w in account["weapons"].values()}
    if (is_weapon and item["canonical"] in owned_classes) or (is_armor and item_id in account["armor"]):
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
    elif is_armor:
        account["armor"][item_id] = dict(item)
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
    # Только фактическое состояние симуляции. Раньше здесь всегда печатались
    # Demo/Vito и выдуманное ограбление, поэтому превью маскировало поломку
    # реальной газеты. Активные владельцы районов являются источником истины.
    items = []
    for did, owner in sorted(
            district_owners.items(),
            key=lambda row: float(row[1].get("captured_at") or 0), reverse=True):
        expires_at = float(owner.get("expires_at") or 0)
        if expires_at and expires_at <= time.time():
            continue
        dd = DISTRICTS.get(did, {})
        owner_name = str(owner.get("owner_name") or "Неизвестный игрок")[:40]
        income = int(owner.get("income") or dd.get("income") or 0)
        control_left = max(0, int(expires_at - time.time())) if expires_at else 0
        items.append({
            "id": f"district:{did}:{owner.get('owner_uid')}",
            "kind": "district_captured", "icon": dd.get("icon") or "🏴",
            "headline": f"{owner_name} контролирует район «{dd.get('name') or did}»",
            "summary": (f"Фракция: мафиози. Доход: ${income} за выплату. "
                        f"До конца контроля: {control_left // 60} мин."),
            "actor_uid": str(owner.get("owner_uid") or ""),
            "district_id": str(did), "owner_name": owner_name,
            "faction": "mafia", "income": income,
            "created_at": int(owner.get("captured_at") or now),
        })
    return cors(web.json_response({
        "ok": True,
        "edition": time.strftime("%d.%m.%Y", time.localtime(now)),
        "generated_at": now,
        "hours": 24,
        "items": items[:12],
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
APARTMENT_DISTRICT_PRICES = {
    "poor": 3500, "lair": 5500, "industrial": 7000,
    "countryside": 8500, "nightlife": 14000, "downtown": 18000,
    "coast": 24000, "rich": 32000, "standard": 6500,
}


def apartment_coords_from_key(apt_key):
    try:
        if apt_key.startswith("tile:"):
            r_text, c_text = apt_key[5:].split(",", 1)
            r, c = int(r_text), int(c_text)
        else:
            br_text, bc_text = apt_key.split(",", 1)
            r, c = int(br_text) * 10 + 6, int(bc_text) * 10 + 6
    except (AttributeError, TypeError, ValueError):
        return None
    return (r, c) if 0 <= r < 200 and 0 <= c < 80 else None


def apartment_district_id(r, c):
    if 0 <= r <= 39 and 40 <= c <= 79: return "downtown"
    if 0 <= r <= 39 and 0 <= c <= 39: return "poor"
    if 40 <= r <= 59 and 0 <= c <= 39: return "nightlife"
    if 60 <= r <= 79 and 0 <= c <= 39: return "rich"
    if 80 <= r <= 99 and 0 <= c <= 39: return "countryside"
    if 40 <= r <= 99 and 40 <= c <= 79: return "industrial"
    if 100 <= r <= 149 and 0 <= c <= 79: return "lair"
    if 150 <= r <= 199 and 0 <= c <= 79: return "coast"
    return "standard"


def apartment_price_for_key(apt_key):
    coords = apartment_coords_from_key(apt_key)
    return None if coords is None else APARTMENT_DISTRICT_PRICES[apartment_district_id(*coords)]


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
    price = apartment_price_for_key(apt_key)
    if price is None:
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
        return cors(web.json_response({
            "ok": False, "error": "no cash", "cash": account["cash"], "price": price,
        }))
    account["cash"] -= price
    owned[apt_key] = {
        "price": price, "bought_at": int(time.time()),
        "safe_level": 0, "weapon_rack_level": 0, "garage_level": 0,
        "cameras_level": 0, "repair_level": 0, "stolen_bags": 0,
    }
    return cors(web.json_response({
        "ok": True, "cash": account["cash"], "price": price, "owned": owned,
    }))


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
    return cors(web.json_response({
        "ok": True, "cash": account["cash"], "price": price, "owned": owned,
    }))


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


def preview_owned_businesses(uid):
    return preview_businesses.setdefault(str(uid), {})


def preview_tick_business_captures():
    global preview_business_next_capture_at
    now = time.time()
    for bid, nest in list(preview_business_nests.items()):
        guards = [guard for guard in nest.get("guards", []) if guard.get("alive")]
        bots = [bot for bot in nest["bots"] if bot.get("alive")]
        if guards and bots and now >= float(nest.get("combat_at", 0)):
            guard, bot = random.choice(guards), random.choice(bots)
            bot["hp"] = max(0, int(bot.get("hp", 100)) - random.randint(22, 31))
            if bot["hp"] <= 0:
                bot["alive"] = False
            bots = [item for item in nest["bots"] if item.get("alive")]
            if bots:
                target = random.choice(guards)
                target["hp"] = max(0, int(target.get("hp", 100)) - random.randint(16, 25))
                if target["hp"] <= 0:
                    target["alive"] = False
                    owner = preview_owned_businesses(nest.get("owner_uid"))
                    if bid in owner:
                        owner[bid]["guards"] = max(0, int(owner[bid].get("guards", 0)) - 1)
            nest["combat_at"] = now + .8
        if any(bot.get("alive") for bot in nest["bots"]):
            continue
        preview_business_nests.pop(bid, None)
        cooldown_until = now + PREVIEW_NPC_CAPTURE_COOLDOWN
        preview_business_capture_cooldown[bid] = cooldown_until
        for rows in preview_businesses.values():
            if bid in rows:
                rows[bid]["npc_capture_cooldown_until"] = cooldown_until
    for rows in preview_businesses.values():
        for bid, info in rows.items():
            until = float(info.get("npc_capture_cooldown_until") or 0)
            if until > now:
                preview_business_capture_cooldown[bid] = max(
                    until, float(preview_business_capture_cooldown.get(bid, 0)))
    for bid, until in list(preview_business_capture_cooldown.items()):
        if until <= now:
            preview_business_capture_cooldown.pop(bid, None)
    if now < preview_business_next_capture_at:
        return
    owned = {bid for rows in preview_businesses.values() for bid in rows}
    candidates = [bid for bid in owned if bid in PREVIEW_BUSINESS_POS
                  and bid not in preview_business_nests
                  and float(preview_business_capture_cooldown.get(bid, 0)) <= now]
    preview_business_next_capture_at = now + 90.0
    if not candidates:
        return
    bid = random.choice(candidates)
    x, y = PREVIEW_BUSINESS_POS[bid]
    faction = "yellow" if len(preview_business_nests) % 2 == 0 else "purple"
    owner_uid, guard_count = None, 0
    for candidate_uid, rows in preview_businesses.items():
        count = max(0, min(6, int(rows.get(bid, {}).get("guards", 0))))
        if count > guard_count:
            owner_uid, guard_count = candidate_uid, count
    bots = []
    for i in range(4):
        ang = i * math.tau / 4
        bot = preview_bandit_bot(
            f"preview_biz_{bid}_{int(now)}_{i}",
            x + math.cos(ang) * 2.7, y + math.sin(ang) * 2.7,
            weapon=("pistol_heavy", "smg", "rifle", "shotgun")[i])
        if faction == "yellow":
            bot["look"].update({"skin": (0, 2, 3, 2)[i], "body": 4,
                                "hat": 2, "gang": 2})
        bots.append(bot)
    preview_business_nests[bid] = {
        "id": f"preview_biz_nest_{bid}", "business_id": bid,
        "faction": faction, "r": y, "c": x, "state": "guard",
        "expires_at": now + 3600.0, "bots": bots, "owner_uid": owner_uid,
        "combat_at": now + .8,
        "guards": [{
            "id": f"preview_guard_{bid}_{i}", "x": x + math.cos(i * math.tau / max(1, guard_count)) * 1.5,
            "y": y + math.sin(i * math.tau / max(1, guard_count)) * 1.5,
            "ang": 0.0, "hp": 100, "max_hp": 100, "alive": True,
            "weapon": "pistol_heavy",
        } for i in range(guard_count)],
    }


def tick_preview_business_raiders(now, dt):
    """NPC raiders retaliate against the player who attacked their business siege."""
    events = []
    for nest in preview_business_nests.values():
        anchor_x, anchor_y = float(nest.get("c", 0)), float(nest.get("r", 0))
        for burning_bot in nest.get("bots", []):
            if burning_bot.get("alive"):
                preview_tick_fire_flee(
                    burning_bot, now, dt,
                    (anchor_x - 9.0, anchor_x + 9.0,
                     anchor_y - 9.0, anchor_y + 9.0),
                )
        if nest.get("state") != "hostile":
            continue
        target_uid = str(nest.get("target_uid") or "")
        target = players.get(target_uid)
        if (not target or target.get("dead")
                or (target.get("_mode") or "pvp") == "pve"
                or now > float(nest.get("hostile_until") or 0)):
            nest["state"] = "guard"
            nest["target_uid"] = ""
            continue
        if math.hypot(float(target.get("x", 0))-anchor_x,
                      float(target.get("y", 0))-anchor_y) > 14:
            nest["state"] = "guard"
            nest["target_uid"] = ""
            continue
        for bot in nest.get("bots", []):
            if not bot.get("alive"):
                continue
            if now < float(bot.get("fire_flee_until") or 0):
                continue
            dx = float(target.get("x", 0))-float(bot["x"])
            dy = float(target.get("y", 0))-float(bot["y"])
            dist = math.hypot(dx, dy)+1e-6
            bot["ang"] = math.atan2(dy, dx)
            bot["act"] = "idle"
            if dist > 5 and math.hypot(bot["x"]-anchor_x, bot["y"]-anchor_y) < 6:
                step = min(dist, 1.05*dt)
                bot["x"] += dx/dist*step
                bot["y"] += dy/dist*step
                bot["act"] = "walk"
            if dist <= 9 and now-float(bot.get("shot_at") or 0) >= 1.05:
                bot["shot_at"] = now
                damage = int(bot.get("damage") or 12)
                target["hp"] = max(0, int(target.get("hp", 100))-damage)
                killed = target["hp"] <= 0
                if killed:
                    target["dead"] = True
                    target["respawn_at"] = now+5
                events.extend([
                    {"kind":"aggro_shot", "tid":nest["id"], "bot_id":bot["id"],
                     "target_uid":target_uid, "weapon":bot["weapon"],
                     "sx":bot["x"], "sy":bot["y"],
                     "tx":target.get("x", 0), "ty":target.get("y", 0)},
                    {"kind":"aggro_apply", "tid":nest["id"], "bot_id":bot["id"],
                     "target_uid":target_uid, "weapon":bot["weapon"],
                     "miss":False, "dmg":damage, "killed":killed},
                ])
                if killed:
                    break
    return events


def preview_business_row(biz_id, info=None):
    preview_tick_business_captures()
    price, low, high, emoji, name = PREVIEW_BUSINESSES[biz_id]
    level = max(1, min(5, int((info or {}).get("level", 1)))) if info else 0
    mult = PREVIEW_BIZ_MULT.get(level, 1.0)
    pending = 0
    occupied = bool(info and biz_id in preview_business_nests)
    cooldown_until = int((info or {}).get("npc_capture_cooldown_until") or 0)
    if info and not occupied:
        elapsed = max(0, time.time() - float(info.get("last_collect") or time.time()))
        pending = int(elapsed * ((low + high) / 2) * mult / 86400)
    next_level = level + 1
    return {
        "biz_id": biz_id,
        "bought_at": int((info or {}).get("bought_at") or 0),
        "id": biz_id, "name": name, "emoji": emoji, "desc": "Стабильный городской бизнес.",
        "price": price, "owned": bool(info),
        "status": "gang_occupied" if occupied else "ok", "blocked_until": 0,
        "npc_occupied": occupied,
        "npc_capture_cooldown_until": cooldown_until,
        "npc_capture_cooldown_left": max(0, cooldown_until - int(time.time())),
        "notice": ("Бизнес захвачен вражеской бандой и не может приносить прибыль"
                   if occupied else None),
        "level": level, "income_multiplier": mult,
        "guards": max(0, min(6, int((info or {}).get("guards", 0)))) if info else 0,
        "daily_min": round(low * mult), "daily_max": round(high * mult), "pending": pending,
        "upgrade_cost": round(price * PREVIEW_BIZ_UP[next_level]) if info and next_level <= 5 else 0,
    }


async def business_list(req):
    uid = req.match_info.get("uid", "1")
    said = preview_said_state(uid)
    owned = preview_owned_businesses(uid)
    rows = [preview_business_row(biz_id, owned.get(biz_id)) for biz_id in PREVIEW_BUSINESSES]
    return cors(web.json_response({"ok": True, "businesses": rows,
        "cash": preview_account(uid)["cash"], "said": said}))


async def said_hire(req):
    uid = req.match_info.get("uid", "1")
    account, owned = preview_account(uid), preview_owned_businesses(uid)
    if not owned:
        return cors(web.json_response({"ok": False, "error": "no business"}))
    state = preview_said_state(uid)
    if state["hired"]:
        return cors(web.json_response({"ok": True, "cash": account["cash"], "said": state}))
    if account["cash"] < 500:
        return cors(web.json_response({"ok": False, "error": "no cash"}))
    now = time.time()
    account["cash"] -= 500
    account["said_hired"] = True
    account["said_hired_at"] = now
    account["said_paid_until"] = now + 86400
    return cors(web.json_response({"ok": True, "cash": account["cash"],
        "said": preview_said_state(uid)}))


async def said_fire(req):
    uid = req.match_info.get("uid", "1")
    account = preview_account(uid)
    account["said_hired"] = False
    account["said_hired_at"] = 0
    account["said_paid_until"] = 0
    return cors(web.json_response({"ok": True, "cash": account["cash"],
        "said": preview_said_state(uid)}))


async def business_buy(req):
    global preview_business_next_capture_at
    uid = req.match_info.get("uid", "1")
    try: body = await req.json()
    except Exception: body = {}
    biz_id = str(body.get("biz_id") or "")
    if biz_id not in PREVIEW_BUSINESSES:
        return cors(web.json_response({"ok": False, "error": "unknown biz"}, status=400))
    owned, account = preview_owned_businesses(uid), preview_account(uid)
    if biz_id in owned:
        return cors(web.json_response({"ok": False, "error": "already owned"}))
    price = PREVIEW_BUSINESSES[biz_id][0]
    if account["cash"] < price:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"], "price": price}))
    account["cash"] -= price
    now = time.time()
    owned[biz_id] = {"level": 1, "last_collect": now, "bought_at": now, "guards": 0}
    preview_business_next_capture_at = min(preview_business_next_capture_at, now + 5.0)
    return cors(web.json_response({"ok": True, "cash": account["cash"], "level": 1}))


async def business_upgrade(req):
    uid = req.match_info.get("uid", "1")
    try: body = await req.json()
    except Exception: body = {}
    biz_id = str(body.get("biz_id") or "")
    info = preview_owned_businesses(uid).get(biz_id)
    if not info or biz_id not in PREVIEW_BUSINESSES:
        return cors(web.json_response({"ok": False, "error": "not owned"}))
    level = max(1, min(5, int(info.get("level", 1))))
    if level >= 5:
        return cors(web.json_response({"ok": False, "error": "max level", "level": level}))
    price, low, high, _, _ = PREVIEW_BUSINESSES[biz_id]
    next_level, account = level + 1, preview_account(uid)
    cost = round(price * PREVIEW_BIZ_UP[next_level])
    if account["cash"] < cost:
        return cors(web.json_response({"ok": False, "error": "no cash", "cost": cost, "cash": account["cash"]}))
    account["cash"] -= cost
    info["level"] = next_level
    mult = PREVIEW_BIZ_MULT[next_level]
    next_cost = round(price * PREVIEW_BIZ_UP[next_level + 1]) if next_level < 5 else 0
    return cors(web.json_response({"ok": True, "cash": account["cash"], "level": next_level,
        "income_multiplier": mult, "daily_min": round(low * mult), "daily_max": round(high * mult),
        "upgrade_cost": next_cost, "next_upgrade_cost": next_cost}))


async def business_guard_hire(req):
    uid = req.match_info.get("uid", "1")
    try: body = await req.json()
    except Exception: body = {}
    biz_id = str(body.get("biz_id") or "")
    info = preview_owned_businesses(uid).get(biz_id)
    if not info or biz_id not in PREVIEW_BUSINESSES:
        return cors(web.json_response({"ok": False, "error": "not owned"}))
    guards = max(0, min(6, int(info.get("guards", 0))))
    if guards >= 6:
        return cors(web.json_response({"ok": False, "error": "guard limit", "guards": guards}))
    account = preview_account(uid)
    if account["cash"] < 100:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"]}))
    account["cash"] -= 100
    info["guards"] = guards + 1
    nest = preview_business_nests.get(biz_id)
    if nest and nest.get("owner_uid") in (None, str(uid)):
        angle = info["guards"] * math.tau / 6
        nest["owner_uid"] = str(uid)
        nest.setdefault("guards", []).append({
            "id": f"preview_guard_{biz_id}_{info['guards']}",
            "x": nest["c"] + math.cos(angle) * 1.5,
            "y": nest["r"] + math.sin(angle) * 1.5,
            "ang": angle, "hp": 100, "max_hp": 100, "alive": True,
            "weapon": "pistol_heavy",
        })
    return cors(web.json_response({"ok": True, "biz_id": biz_id,
        "guards": info["guards"], "guard_limit": 6, "price": 100, "cash": account["cash"]}))


async def business_collect(req):
    uid = req.match_info.get("uid", "1")
    try: body = await req.json()
    except Exception: body = {}
    biz_id = str(body.get("biz_id") or "")
    owned = preview_owned_businesses(uid)
    if biz_id:
        info = owned.get(biz_id)
        if not info or biz_id not in PREVIEW_BUSINESSES:
            return cors(web.json_response({"ok": False, "error": "not owned"}))
        targets = [(biz_id, info)]
    else:
        if not preview_said_state(uid)["hired"]:
            return cors(web.json_response({"ok": False, "error": "said not hired"}))
        targets = list(owned.items())
    pay, account = 0, preview_account(uid)
    for target_id, info in targets:
        pay += int(preview_business_row(target_id, info)["pending"])
        info["last_collect"] = time.time()
    account["cash"] += pay
    return cors(web.json_response({"ok": True, "collected": pay, "cash": account["cash"], "events": []}))


async def coop_api(req):
    return cors(web.json_response({"base": f"{req.scheme}://{req.host}"}))


async def preview_world(req):
    # Always serve the world that lives next to this server file.  Previously a
    # launch from another working directory silently served a stale world.html
    # from that directory and looked like a massive rollback.
    html = (BASE_DIR / "world.html").read_text(
        encoding="utf-8", errors="replace")
    origin = f"{req.scheme}://{req.host}"
    html = html.replace(
        "https://slavaprivet.github.io/mafiozi-battle/coop_api.json?t=",
        f"{origin}/coop_api.json?t=",
    )
    return web.Response(text=html, content_type="text/html")


def snap(uid):
    tick_race_cars()
    now = time.time()
    for car_id, car in list(quest_cars.items()):
        if car.get("called_patrol") and now >= float(car.get("expires_at", 0)):
            quest_cars.pop(car_id, None)
    p = players.setdefault(uid, {
        "x": PREVIEW_START_X,
        "y": PREVIEW_START_Y,
        "ang": 0.0,
        "walking": False,
        "name": "Demo",
    })
    crew_id = str(p.get("crew_id") or "")
    crew_members = [{"uid":str(u), "name":q.get("name","Игрок"), "npc_count":len(q.get("gang") or [])}
                    for u,q in players.items() if crew_id and str(q.get("crew_id") or "")==crew_id]
    now = time.time()
    # Ограниченный серверный конвой: 20 секунд максимум, освобождение при
    # гибели/выходе копа. Задержанный следует в 0.7 тайла позади.
    for target_uid, target in list(players.items()):
        cop_uid = str(target.get("police_cuffed_by") or "")
        if not cop_uid:
            continue
        cop = players.get(cop_uid)
        if (not cop or not cop.get("police") or cop.get("dead") or
                now >= float(target.get("police_cuff_until", 0))):
            if target.pop("police_death_arrest", False):
                target["dead"] = False; target["hp"] = max(25, int(target.get("hp", 0)))
                target["wanted"] = 0
            target.pop("police_cuffed_by", None); target.pop("police_cuff_until", None)
            if cop: cop.pop("police_escort_uid", None)
            continue
        ang = float(cop.get("ang", 0))
        target["x"] = float(cop.get("x", 0)) - math.sin(ang) * .72
        target["y"] = float(cop.get("y", 0)) - math.cos(ang) * .72
        target["ang"] = ang; target["walking"] = bool(cop.get("walking"))
    me_biz = str(p.get("business_interior") or "")
    me_private = bool(p.get("business_private"))
    business_under_attack = bool(me_biz and any(
        bid == me_biz and until > now for (_attacker_uid,bid),until in preview_business_aggro.items()))
    visible_others = []
    for other_uid, other in players.items():
        if str(other_uid) == str(uid):
            continue
        other_biz = str(other.get("business_interior") or "")
        other_private = bool(other.get("business_private"))
        if me_biz:
            if other_biz != me_biz or ((me_private or other_private) and not business_under_attack):
                continue
            ox, oy = float(other.get("interior_x", 0)), float(other.get("interior_y", 0))
        else:
            if other_biz:
                continue
            ox, oy = float(other.get("x", 0)), float(other.get("y", 0))
            if (ox-float(p.get("x", 0)))**2 + (oy-float(p.get("y", 0)))**2 > 45**2:
                continue
        visible_others.append({
            "uid": str(other_uid), "name": other.get("name", "Demo"),
            "look": other.get("look", {}), "x": round(ox, 2), "y": round(oy, 2),
            "business_attacker": bool(me_biz and preview_business_aggro.get((str(other_uid),me_biz),0) > now),
            "ang": round(float(other.get("ang", 0)), 2), "w": bool(other.get("walking")), "swimming": bool(other.get("swimming")),
            "hp": int(other.get("hp", 100)), "dead": bool(other.get("dead", False)),
            "wanted": int(other.get("wanted", 0)), "gangs": 0, "mode": "pvp",
            "jail_in": max(0, int(float(other.get("jail_until", 0))-now)),
            "weapon": other.get("weapon", "pistol"),
            "police": bool(other.get("police", False)),
            "mafia": bool(other.get("mafia", False)),
            "crew_mate": bool(crew_id and str(other.get("crew_id") or "")==crew_id),
            "police_cuffed": bool(other.get("police_cuffed_by")),
            "police_stunned_in": max(0, float(other.get("police_stunned_until", 0))-now),
            "police_escort": other.get("police_escort"),
            "interior": ({"kind": "business", "biz_id": other_biz,
                          "private": other_private} if other_biz else None),
        })
    ground_boxes = []
    for owner_uid, box in preview_box_quests.items():
        if box.get("state") != "ground":
            continue
        box_biz = str(box.get("ground_business_id") or "")
        if me_biz:
            if box.get("ground_space") != "business" or box_biz != me_biz:
                continue
        else:
            if box.get("ground_space") != "world":
                continue
            if math.hypot(float(box.get("ground_x") or 0)-float(p.get("x") or 0),
                          float(box.get("ground_y") or 0)-float(p.get("y") or 0)) > 45:
                continue
        ground_boxes.append({
            "owner_uid": str(owner_uid),
            "owner_name": (players.get(str(owner_uid)) or {}).get("name", "Игрок"),
            "r": round(float(box.get("ground_y") or 0), 2),
            "c": round(float(box.get("ground_x") or 0), 2),
            "mine": str(owner_uid) == str(uid),
            "expires_in": max(0, int(float(box.get("ground_expires_at") or now)-now)),
        })
    own_box = preview_box_quests.get(str(uid))
    box_quest = dict(own_box) if own_box else None
    if box_quest and box_quest.get("state") == "ground":
        box_quest["expires_in"] = max(
            0, int(float(box_quest.get("ground_expires_at") or now) - now))
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
                "police_xp": int(preview_account(uid).get("police_xp", 0)),
                "mafia_xp": int(preview_account(uid).get("mafia_xp", 0)),
                "spray_cans": int(p.get("spray_cans",0)),
                "online_gang": {"crew_id":crew_id,"members":crew_members,"max_players":3} if crew_id else None,
                "police_arrests_today": preview_police_daily_state(uid)[1],
                "police_arrest_limit": preview_police_daily_state(uid)[2],
                "police_spikes_cd": max(0.0, round(
                    25-(now-float(p.get("police_spikes_at",0))), 2)),
                "police_patrol_cd": max(0.0, round(
                    180-(now-float(p.get("police_patrol_called_at",0))), 1)),
                "police_backup_cd": max(0.0, round(
                    90-(now-float(p.get("police_backup_at",0))), 1)),
                "diamonds": 0,
                "wanted": int(p.get("wanted", 0)),
                "wanted_gangs": 0,
                "jail_in": max(0, int(float(p.get("jail_until", 0))-now)),
                "police_stunned_in": max(0, float(p.get("police_stunned_until", 0))-now),
                "police_arrest": ({"role":"detainee", "cop_uid":str(p.get("police_cuffed_by")),
                    "cop_name":players.get(str(p.get("police_cuffed_by")),{}).get("name","Полицейский"),
                    "left":max(0,int(float(p.get("police_cuff_until",0))-now))}
                    if p.get("police_cuffed_by") else
                    ({"role":"cop", "target_uid":str(p.get("police_escort_uid")),
                      "target_name":players.get(str(p.get("police_escort_uid")),{}).get("name","Задержанный"),
                      "left":max(0,int(float(players.get(str(p.get("police_escort_uid")),{}).get("police_cuff_until",0))-now))}
                     if p.get("police_escort_uid") else None)),
                "police_downed": ({"role":"target", "cop_uid":str(p.get("police_downed_by")),
                    "cop_name":players.get(str(p.get("police_downed_by")),{}).get("name","Полицейский"),
                    "left":max(0,float(p.get("police_downed_until",0))-now)}
                    if p.get("dead") and p.get("police_downed_by") else
                    ({"role":"cop", "target_uid":str(p.get("police_downed_target")),
                      "target_name":players.get(str(p.get("police_downed_target")),{}).get("name","Разыскиваемый"),
                      "wanted":int(players.get(str(p.get("police_downed_target")),{}).get("wanted",0)),
                      "left":max(0,float(players.get(str(p.get("police_downed_target")),{}).get("police_downed_until",0))-now)}
                     if p.get("police_downed_target") else None)),
                "police_evidence_bag": ({
                    "id": str(p["police_evidence_bag"].get("id") or ""),
                    "bank_id": str(p["police_evidence_bag"].get("bank_id") or ""),
                    "value": int(p["police_evidence_bag"].get("value") or 0),
                } if p.get("police_evidence_bag") else None),
            },
            "others": visible_others,
            "wanted_board": ([{
                "uid": str(tuid), "name": tp.get("name", "Игрок"),
                "wanted": int(tp.get("wanted", 0)), "x": round(float(tp.get("x",0)),1),
                "y": round(float(tp.get("y",0)),1),
                "selected": str(p.get("police_online_target") or "") == str(tuid),
                "detained": bool(tp.get("police_cuffed_by")),
                "first_reward": str(tuid) not in preview_police_rewards,
            } for tuid,tp in players.items() if str(tuid)!=str(uid) and int(tp.get("wanted",0))>0
                and not tp.get("dead") and float(tp.get("jail_until",0))<=now] if p.get("police") else []),
            "cops": [],
            "event": None,
            "territories": {},
            "active_captures": {},
            "major_objects": preview_major_payload(),
            "aggro": preview_aggro_payload(),
            "quest_cars": race_car_payload(),
            "dropped_bags": [{
                "id": str(bag["id"]), "bank_id": str(bag.get("bank_id") or ""),
                "value": int(bag.get("value") or 0),
                "r": round(float(bag.get("y") or 0), 2),
                "c": round(float(bag.get("x") or 0), 2),
            } for bag in preview_bank_bags.values()
              if now - float(bag.get("dropped_at") or now) <= 300
              and (float(bag.get("x") or 0)-float(p.get("x") or 0))**2
                + (float(bag.get("y") or 0)-float(p.get("y") or 0))**2 <= 42**2],
            "ground_boxes": ground_boxes,
            "box_quest": box_quest,
            "beachgoers": PREVIEW_BEACHGOERS,
            "michael_guards": [],
            "gang_nests": PREVIEW_GANG_NESTS + [{
                "id": nest["id"], "r": nest["r"], "c": nest["c"],
                "state": nest["state"],
                "expires_in": max(0, int(nest["expires_at"] - now)),
                "bots_alive": sum(1 for bot in nest["bots"] if bot.get("alive")),
                "faction": nest["faction"], "business_id": bid,
                "guards": [guard for guard in nest.get("guards", []) if guard.get("alive")],
                "guards_alive": sum(
                    1 for guard in nest.get("guards", []) if guard.get("alive")),
            } for bid, nest in preview_business_nests.items()],
            "business_closures": {
                bid: max(0, int(until-now)) for bid,until in preview_business_closures.items()
                if until > now
            },
            "business_aggro": {
                bid: max(0, int(until-now)) for (aggro_uid,bid),until in preview_business_aggro.items()
                if str(aggro_uid) == str(uid) and until > now
            },
            "business_police_protection": {
                bid:max(0,int(until-now)) for (protected_uid,bid),until in preview_business_police_protection.items()
                if str(protected_uid)==str(uid) and until>now
            },
            "business_owner_protection": {
                bid:max(0,int(until-now)) for (protected_uid,bid),until in preview_business_owner_protection.items()
                if str(protected_uid)==str(uid) and until>now
            },
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
    p0 = players.setdefault(uid, {
        "x": PREVIEW_START_X,
        "y": PREVIEW_START_Y,
        "ang": 0.0,
        "walking": False,
        "name": "Demo",
        "hp": 100,
        "dead": False,
    })
    p0["uid"] = str(uid)
    try:
        p0["wanted"] = max(int(p0.get("wanted", 0)), min(3, int(req.query.get("wanted", 0))))
    except Exception:
        pass
    ws = web.WebSocketResponse(heartbeat=20)
    await ws.prepare(req)
    p0["_ws"] = ws
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
            ensure_preview_district_bosses(now)
            for owner_uid, q in list(preview_box_quests.items()):
                owner = players.get(str(owner_uid))
                if q.get("state") in ("carrying", "loaded") and owner and owner.get("dead"):
                    rep = preview_drop_box(owner_uid, "death")
                    if rep.get("ok"):
                        await broadcast_event({"kind": "box_dropped", **rep})
                elif (q.get("state") == "ground" and
                      now >= float(q.get("ground_expires_at") or 0)):
                    preview_box_quests.pop(str(owner_uid), None)
                    await broadcast_event({
                        "kind": "box_expired", "owner_uid": str(owner_uid),
                        "reason": "timeout",
                    })
            for p in players.values():
                if p.get("dead") and now >= float(p.get("respawn_at", now + 1)):
                    cop_uid = str(p.pop("police_downed_by", "") or "")
                    p.pop("police_downed_until", None)
                    if cop_uid and players.get(cop_uid):
                        players[cop_uid].pop("police_downed_target", None)
                    p["dead"] = False
                    p["hp"] = 100
                    p["wanted"] = 0
                    # После смерти игрок выходит у входа в больницу, как на
                    # основном сервере. Стартовая точка находится на пляже и
                    # не должна повторно использоваться для возрождения.
                    p["x"], p["y"] = PREVIEW_HOSPITAL_X, PREVIEW_HOSPITAL_Y
            for defender_event in tick_district_defenders(now, 1/15):
                await broadcast_event(defender_event)
            for lair_event in tick_preview_lair(now, 1/15):
                await broadcast_event(lair_event)
            for raider_event in tick_preview_business_raiders(now, 1/15):
                await broadcast_event(raider_event)
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
                            preview_drop_district_dossier(did, cap, bot, now)
                await broadcast_event({"kind":"world_c4_exploded","id":charge_id,
                    "by_uid":charge["owner_uid"],"by_name":charge["owner_name"],
                    "x":charge["x"],"y":charge["y"],"lethal_r":WORLD_C4_LETHAL_R,
                    "victims":victims,"npc_victims":npc_victims})
            for loot_id, loot in list(district_loot.items()):
                if now >= float(loot.get("expires_at") or 0):
                    district_loot.pop(loot_id, None)
                    if loot.get("kind") == "dossier":
                        cap = district_captures.get(str(loot.get("did") or ""))
                        if cap and cap.get("phase") == "dossier":
                            cap["respawn_at"] = now + 2.0
                    continue
                for picker_uid, picker in players.items():
                    if picker.get("dead") or math.hypot(picker.get("x",0)-loot["x"], picker.get("y",0)-loot["y"]) > 1.25:
                        continue
                    if loot.get("kind") == "dossier":
                        if picker.get("police"):
                            continue
                        did = str(loot.get("did") or "")
                        cap = district_captures.get(did)
                        if not cap or cap.get("phase") != "dossier" or did in district_owners:
                            continue
                        own_active = sum(1 for active in district_captures.values()
                                         if str(active.get("by_uid") or "") == str(picker_uid))
                        if own_active >= DIST_MAX_ACTIVE_PER_PLAYER:
                            continue
                        district_loot.pop(loot_id, None)
                        dd = DISTRICTS[did]
                        cap.update({"by_uid":str(picker_uid),
                                    "by_name":picker.get("name","Player")[:24],
                                    "color":dd["color"], "started_at":now,
                                    "expires_at":now + DIST_OPERATION_TTL_S,
                                    "phase":"sabotage", "done":[], "charges":{},
                                    "boss_dead":True, "defenders":[]})
                        cap.pop("dossier_id",None); cap.pop("respawn_at",None)
                        await broadcast_event({"kind":"district_operation_started","did":did,
                            "by_uid":str(picker_uid),"by_name":cap["by_name"],"color":cap["color"],
                            "name":dd["name"],"icon":dd["icon"],"expires_in":DIST_OPERATION_TTL_S})
                        break
                    district_loot.pop(loot_id, None)
                    if loot.get("kind") == "ammo":
                        await broadcast_event({"kind":"gang_ammo_picked","loot_id":loot_id,
                            "picker_uid":str(picker_uid),"picker_name":picker.get("name","Игрок"),
                            "ammo_type":loot.get("ammo_type","9mm"),"rounds":int(loot.get("rounds") or 0)})
                    else:
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
            current = players.get(uid) or {}
            if t == "input" and d.get("client_active"):
                current["_ws"] = ws
            if current.get("_ws") is not ws:
                continue
            if t == "input":
                p = players.setdefault(uid, {})
                if p.get("dead"):
                    continue
                if p.get("police_cuffed_by"):
                    continue
                was_police = bool(p.get("police"))
                requested_police = bool(d.get("police", False))
                requested_mafia = bool(d.get("mafia", False))
                was_mafia = bool(p.get("mafia"))
                if requested_police and was_mafia:
                    requested_police, requested_mafia = False, True
                elif requested_mafia and was_police:
                    requested_police, requested_mafia = True, False
                p["police"] = requested_police
                p["mafia"] = requested_mafia and not p["police"]
                if "gang" in d:
                    p["gang"] = d.get("gang")[:7] if isinstance(d.get("gang"), list) else []
                if not p["mafia"]:
                    crew_id=str(p.pop("crew_id","") or "")
                    if crew_id:
                        left=[q for q in players.values() if str(q.get("crew_id") or "")==crew_id]
                        if len(left)<2:
                            for q in left:q.pop("crew_id",None)
                if p["police"] and not was_police:
                    for did, own in list(district_owners.items()):
                        if str(own.get("owner_uid")) == str(uid): district_owners.pop(did, None)
                    for did, cap in list(district_captures.items()):
                        if str(cap.get("by_uid")) == str(uid) and cap.get("phase") not in ("boss_patrol","dossier"):
                            district_captures.pop(did, None)
                escort = d.get("police_escort") if isinstance(d.get("police_escort"), dict) else None
                if escort:
                    p["police_escort"] = {"r": max(0.0, min(120.0, float(escort.get("r", 0)))), "c": max(0.0, min(120.0, float(escort.get("c", 0)))), "ang": float(escort.get("ang", 0)), "name": str(escort.get("name") or "Задержанный")[:32], "look": escort.get("look") if isinstance(escort.get("look"), dict) else {}, "waiting": bool(escort.get("waiting"))}
                else:
                    p["police_escort"] = None
                interior = d.get("interior") if isinstance(d.get("interior"), dict) else None
                biz_id = str((interior or {}).get("biz_id") or "")[:32]
                interior_kind = str((interior or {}).get("kind") or "")
                major_id = str((interior or {}).get("object_id") or "")[:24]
                if interior_kind == "major" and major_id in PREVIEW_MAJOR_OBJECTS:
                    p["major_interior"] = major_id
                    p.pop("business_interior", None)
                    p.pop("business_private", None)
                    p["interior_x"] = max(
                        0.0, min(60.0, float(interior.get("x", 0))))
                    p["interior_y"] = max(
                        0.0, min(60.0, float(interior.get("y", 0))))
                    p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                    p["walking"] = bool(d.get("w", False))
                    p["weapon"] = str(
                        d.get("weapon") or p.get("weapon") or "pistol")[:32]
                    p["in_interior"] = True
                    continue
                p.pop("major_interior", None)
                if interior_kind == "business" and biz_id:
                    p["business_interior"] = biz_id
                    p["business_private"] = biz_id in preview_owned_businesses(uid)
                    p["interior_x"] = max(0.0, min(60.0, float(interior.get("x", 0))))
                    p["interior_y"] = max(0.0, min(60.0, float(interior.get("y", 0))))
                    p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                    p["walking"] = bool(d.get("w", False))
                    p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
                    p["in_interior"] = True
                    continue
                if interior_kind in ("bank", "building"):
                    p.pop("business_interior", None)
                    p.pop("business_private", None)
                    p.pop("interior_x", None)
                    p.pop("interior_y", None)
                    p["in_interior"] = True
                    p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                    p["walking"] = False
                    p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
                    continue
                p.pop("business_interior", None)
                p.pop("business_private", None)
                p.pop("interior_x", None)
                p.pop("interior_y", None)
                p["in_interior"] = False
                p["x"] = float(d.get("x", p.get("x", 40.0)))
                p["y"] = float(d.get("y", p.get("y", 40.0)))
                p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                p["walking"] = bool(d.get("w", False))
                p["swimming"] = bool(d.get("swimming", False))
                p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
            elif t == "business_aggro":
                biz_id = str(d.get("biz_id") or "")
                p = players.get(uid) or {}
                if (biz_id in PREVIEW_BUSINESS_RC and not p.get("police") and
                        preview_business_police_protection.get((str(uid),biz_id),0)<=time.time() and
                        preview_business_owner_protection.get((str(uid),biz_id),0)<=time.time()):
                    preview_business_aggro[(str(uid), biz_id)] = time.time() + 300
                    if len(preview_business_aggro) > 500:
                        cutoff = time.time()
                        for key, until in list(preview_business_aggro.items()):
                            if until <= cutoff:
                                preview_business_aggro.pop(key, None)
            elif t == "business_rob_prepare":
                biz_id = str(d.get("biz_id") or "")
                p = players.get(uid) or {}
                now_rob=time.time()
                protected_left=max(0,int(preview_business_police_protection.get((str(uid),biz_id),0)-now_rob))
                defended_left=max(0,int(preview_business_owner_protection.get((str(uid),biz_id),0)-now_rob))
                closed_left=max(0,int(preview_business_closures.get(biz_id,0)-now_rob))
                last_rob=float(preview_business_last_robs.get((str(uid),biz_id),0))
                cooldown_left=max(0,int(PREVIEW_ROB_PERSONAL_COOLDOWN_S-(now_rob-last_rob))) if last_rob else 0
                completed = max(0, min(2, int(preview_business_rob_cycles.get((str(uid),biz_id),0))))
                rc=PREVIEW_BUSINESS_RC.get(biz_id)
                close_enough=preview_robber_at_cashier(p,biz_id)
                owns=biz_id in preview_owned_businesses(uid)
                ok_prepare=bool(
                    rc and p and not p.get("dead") and not p.get("police") and
                    not protected_left and not defended_left and not closed_left and
                    not cooldown_left and close_enough and not owns
                )
                guard_count=int(PREVIEW_ROB_GUARDS.get(biz_id,1))+completed*3
                token=""
                if ok_prepare:
                    token=secrets.token_urlsafe(24)
                    preview_business_rob_sessions[str(uid)]={
                        "token":token,"biz_id":biz_id,"started_at":now_rob,
                        "expires_at":now_rob+600,"guard_count":guard_count,
                        "guards_down":set(),"owner_pressure":0.0,
                        "last_guard_at":0.0,"owner_hit_seq":0,
                    }
                else:
                    preview_business_rob_sessions.pop(str(uid),None)
                reason=("police" if p.get("police") else
                        "protected" if protected_left else
                        "defended" if defended_left else
                        "cooldown" if cooldown_left else
                        "closed" if closed_left else
                        "own" if owns else
                        "too_far" if not close_enough else "dead")
                await ws.send_str(json.dumps({"t":"event","d":{
                    "kind":"business_rob_prepare_reply","ok":ok_prepare,
                    "reason":"" if ok_prepare else reason,
                    "protected_s":protected_left or defended_left,
                    "cooldown_s":cooldown_left,"closed_s":closed_left,
                    "biz_id":biz_id,"attempt":completed+1,"guard_bonus":completed*3,
                    "guard_count":guard_count,"rob_token":token,
                }}, ensure_ascii=False))
            elif t in ("business_rob_guard_down","business_rob_owner_hit"):
                payload=d if isinstance(d,dict) else {}
                session=preview_business_rob_sessions.get(str(uid))
                token=str(payload.get("rob_token") or "")
                now_rob=time.time()
                if (not session or not token or
                        not secrets.compare_digest(token,str(session.get("token") or "")) or
                        now_rob>float(session.get("expires_at") or 0)):
                    preview_business_rob_sessions.pop(str(uid),None)
                    continue
                if t=="business_rob_guard_down":
                    try: guard_id=int(payload.get("guard_id"))
                    except (TypeError,ValueError): continue
                    if (0<=guard_id<int(session["guard_count"]) and
                            guard_id not in session["guards_down"] and
                            now_rob-float(session.get("last_guard_at") or 0)>=.35):
                        session["guards_down"].add(guard_id)
                        session["last_guard_at"]=now_rob
                else:
                    if len(session["guards_down"])<int(session["guard_count"]): continue
                    try:
                        damage=max(0.0,min(35.0,float(payload.get("damage") or 0)))
                        hit_seq=int(payload.get("hit_seq") or 0)
                    except (TypeError,ValueError): continue
                    expected_seq=int(session.get("owner_hit_seq") or 0)+1
                    if damage and hit_seq==expected_seq:
                        session["owner_pressure"]=min(99.0,float(session.get("owner_pressure") or 0)+damage)
                        session["owner_hit_seq"]=hit_seq
            elif t == "shop_rob":
                p = players.get(uid) or {}
                biz_id = str(d.get("biz_id") or "")
                rc = PREVIEW_BUSINESS_RC.get(biz_id)
                reward = PREVIEW_ROB_PAYOUT.get(biz_id)
                now = time.time()
                session=preview_business_rob_sessions.get(str(uid))
                rob_token=str(d.get("rob_token") or "")
                session_ok=bool(
                    session and rob_token and
                    secrets.compare_digest(rob_token,str(session.get("token") or "")) and
                    session.get("biz_id")==biz_id and now<=float(session.get("expires_at") or 0)
                )
                reply = {"kind":"shop_rob_reply", "ok":False, "reason":"bad_biz"}
                if rc and reward:
                    closed_until = float(preview_business_closures.get(biz_id) or 0)
                    if p.get("police"):
                        reply.update(reason="police")
                    elif preview_business_police_protection.get((str(uid),biz_id),0)>now:
                        reply.update(reason="protected",biz_id=biz_id,
                                     protected_s=int(preview_business_police_protection[(str(uid),biz_id)]-now))
                    elif preview_business_owner_protection.get((str(uid),biz_id),0)>now:
                        reply.update(reason="defended",biz_id=biz_id,
                                     protected_s=int(preview_business_owner_protection[(str(uid),biz_id)]-now))
                    elif closed_until > now:
                        reply.update(reason="closed", closed_s=int(closed_until-now), biz_id=biz_id)
                    elif biz_id in preview_owned_businesses(uid):
                        reply.update(reason="own")
                    elif not session_ok:
                        reply.update(reason="invalid_session")
                    elif (len(session["guards_down"])<int(session["guard_count"]) or
                          float(session.get("owner_pressure") or 0)<70 or
                          now-float(session.get("started_at") or 0)<max(3.0,int(session["guard_count"])*.75)):
                        reply.update(reason="not_pressured")
                    elif not preview_robber_at_cashier(p,biz_id):
                        reply.update(reason="too_far")
                    else:
                        money, stars = reward
                        preview_account(uid)["cash"] += money
                        p["wanted"] = max(int(p.get("wanted",0)), stars)
                        preview_business_closures[biz_id] = now + 300
                        key = (str(uid), biz_id)
                        preview_business_last_robs[key] = now
                        preview_business_rob_cycles[key] = (int(preview_business_rob_cycles.get(key,0)) + 1) % 3
                        preview_business_rob_sessions.pop(str(uid),None)
                        reply = {"kind":"shop_rob_reply", "ok":True, "biz_id":biz_id,
                                 "money":money, "stars":stars, "closed_s":300}
                        if p.get("mafia") and not p.get("police"):
                            account = preview_account(uid)
                            old_xp = int(account.get("mafia_xp", 0))
                            account["mafia_xp"] = min(4000, old_xp + 25)
                            reply.update(mafia_xp=account["mafia_xp"],
                                         mafia_xp_gain=account["mafia_xp"]-old_xp,
                                         mafia_reason="Успешное ограбление бизнеса")
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
            elif t == "district_capture_try":
                p = players.get(uid) or {}
                did = str(d.get("did") or "")
                dd = DISTRICTS.get(did)
                owner = district_owners.get(did)
                if not dd:
                    continue
                if p.get("police"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                        "reason":"police_forbidden"}}, ensure_ascii=False))
                    continue
                if owner:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                        "reason":"already_controlled","by_name":owner.get("owner_name", ""),
                        "wait_s":max(0, int(float(owner.get("expires_at") or time.time())-time.time()))}}))
                    continue
                cap = district_captures.get(did)
                if not cap:
                    ensure_preview_district_bosses(time.time())
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                        "reason":"boss_alive","boss_name":dd["boss_name"]}}))
                    continue
                if cap.get("phase") in ("boss_patrol", "dossier"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"district_capture_denied","did":did,"by_uid":str(uid),
                        "reason":"dossier_pending" if cap.get("phase")=="dossier" else "boss_alive",
                        "boss_name":dd["boss_name"]}}))
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
                    account = preview_account(uid)
                    if not p.get("police"):
                        account["mafia_xp"] = min(4000, int(account.get("mafia_xp", 0)) + 350)
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
                                           "control_ttl_s":DIST_CONTROL_TTL_S,
                                           "mafia_xp":account.get("mafia_xp", 0),
                                           "mafia_xp_gain":0 if p.get("police") else 350,
                                           "mafia_reason":"Захват района"})
            elif t == "district_c4_plant":
                p = players.get(uid) or {}
                did = str(d.get("did") or "")
                dd = DISTRICTS.get(did)
                cap = district_captures.get(did)
                reason = None
                target_idx = None
                if p.get("police"):
                    reason = "police_forbidden"
                elif not dd or not cap or str(cap.get("by_uid")) != str(uid):
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
            elif t == "taxi_ride":
                destination = str(d.get("destination") or "")
                account = preview_account(uid)
                ok = destination in TAXI_DESTINATIONS and int(account.get("cash", 0)) >= TAXI_COST
                if ok:
                    account["cash"] -= TAXI_COST
                await ws.send_str(json.dumps({"t":"event","d":{
                    "kind":"taxi_ride_reply", "ok":ok,
                    "reason":"" if ok else ("destination" if destination not in TAXI_DESTINATIONS else "cash"),
                    "destination":destination, "cash":int(account.get("cash", 0)),
                }}, ensure_ascii=False))
            elif t == "spray_can_buy":
                account=preview_account(uid);p=players.get(uid) or {}
                if int(account.get("cash",0))<5: reply={"ok":False,"reason":"cash"}
                else:
                    account["cash"]-=5;p["spray_cans"]=int(p.get("spray_cans",0))+1;reply={"ok":True}
                reply.update({"kind":"spray_can_buy_reply","cash":account["cash"],"spray_cans":int(p.get("spray_cans",0))})
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
            elif t == "brigadir_take":
                p=players.get(uid) or {};near=(float(p.get("x",0))-34)**2+(float(p.get("y",0))-44)**2<=36
                reply={"kind":"brigadir_take_reply","ok":False,"reason":"too_far"}
                if near and not p.get("brigadir_active") and not p.get("brigadir_pending"):
                    reply={"kind":"brigadir_take_reply","ok":True,"payout":700,"left":3}
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
            elif t == "brigadir_accept":
                p=players.get(uid) or {};target_id=str((d or {}).get("target_id") or "")[:96]
                ok=bool(target_id and not p.get("brigadir_pending"))
                if ok:
                    p["brigadir_active"]=True;p["brigadir_target_id"]=target_id
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"brigadir_accept_reply","ok":ok}},ensure_ascii=False))
            elif t == "brigadir_decline":
                p=players.get(uid) or {}
                if not p.get("brigadir_pending"):
                    p.pop("brigadir_active",None);p.pop("brigadir_target_id",None)
            elif t == "brigadir_kill":
                p=players.get(uid) or {};target_id=str((d or {}).get("target_id") or "")
                ok=bool(p.get("brigadir_active") and target_id and target_id==str(p.get("brigadir_target_id") or ""))
                if ok:
                    p.pop("brigadir_active",None);p.pop("brigadir_target_id",None);p["brigadir_pending"]={"reward":700}
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"brigadir_kill_reply","ok":ok,"reason":"none" if ok else "no_contract","reward":700}},ensure_ascii=False))
            elif t == "brigadir_claim":
                p=players.get(uid) or {};near=(float(p.get("x",0))-34)**2+(float(p.get("y",0))-44)**2<=36;pending=p.get("brigadir_pending")
                ok=bool(near and pending);reward=int((pending or {}).get("reward",0))
                if ok:
                    p.pop("brigadir_pending",None);preview_account(uid)["cash"]+=reward
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"brigadir_claim_reply","ok":ok,"reason":"too_far" if not near else "none","reward":reward,"left":2,"cash":preview_account(uid)["cash"]}},ensure_ascii=False))
            elif t == "gang_player_invite":
                target_uid=str(d.get("target_uid") or ""); target=players.get(target_uid); inviter=players.get(uid) or {}
                crew_id=str(inviter.get("crew_id") or uid); members=[q for q in players.values() if str(q.get("crew_id") or "")==crew_id]
                reason=None
                if not inviter.get("mafia") or not target or not target.get("mafia"): reason="mafia_only"
                elif target_uid==str(uid): reason="self"
                elif target.get("crew_id"): reason="already_in_gang"
                elif len(members)>=3: reason="full"
                elif math.hypot(float(inviter.get("x",0))-float(target.get("x",0)),float(inviter.get("y",0))-float(target.get("y",0)))>3.2: reason="too_far"
                if reason: await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_reply","ok":False,"reason":reason}}))
                else:
                    gang_player_invites[target_uid]={"from_uid":str(uid),"expires_at":time.time()+25}
                    tws=target.get("_ws")
                    if tws and not tws.closed: await tws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_invite","from_uid":str(uid),"from_name":inviter.get("name","Игрок")}},ensure_ascii=False))
                    await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_reply","ok":True,"pending":True,"target_name":target.get("name","Игрок")}},ensure_ascii=False))
            elif t == "gang_player_answer":
                inv=gang_player_invites.pop(str(uid),None); accept=bool(d.get("accept")); inviter=players.get(str(inv.get("from_uid"))) if inv else None
                if not inv or time.time()>float(inv.get("expires_at",0)) or not inviter: continue
                if accept and p0.get("mafia") and inviter.get("mafia"):
                    crew_id=str(inviter.get("crew_id") or inv.get("from_uid")); members=[q for q in players.values() if str(q.get("crew_id") or "")==crew_id]
                    if len(members)<3: inviter["crew_id"]=crew_id;p0["crew_id"]=crew_id
                for q in (inviter,p0):
                    qws=q.get("_ws")
                    if qws and not qws.closed: await qws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_changed","accepted":accept}},ensure_ascii=False))
            elif t in ("gang_player_leave","gang_player_kick"):
                actor=players.get(uid) or {}; crew_id=str(actor.get("crew_id") or ""); target_uid=str(d.get("target_uid") or uid) if t=="gang_player_kick" else str(uid); target=players.get(target_uid)
                if crew_id and target and str(target.get("crew_id") or "")==crew_id:
                    target.pop("crew_id",None)
                    left=[q for q in players.values() if str(q.get("crew_id") or "")==crew_id]
                    if len(left)<2:
                        for q in left:q.pop("crew_id",None)
            elif t == "gang_hire_bot":
                target_id = str(d.get("bot_id") or "")
                p = players.get(uid) or {}
                street_bot = next((b for b in PREVIEW_NEST_BOTS
                                   if str(b.get("id")) == target_id), None)
                business_id = ""
                raid_bot = None
                for candidate_bid, candidate_nest in preview_business_nests.items():
                    raid_bot = next((b for b in candidate_nest.get("bots", [])
                                     if b.get("alive") and str(b.get("id")) == target_id), None)
                    if raid_bot:
                        business_id = str(candidate_bid)
                        break
                target_bot = raid_bot or street_bot
                target_level = int((target_bot or {}).get("level") or 1)
                mafia_xp = int(preview_account(uid).get("mafia_xp") or 0)
                mafia_level = 5 if mafia_xp >= 4000 else (
                    4 if mafia_xp >= 2300 else (3 if mafia_xp >= 1100 else (
                        2 if mafia_xp >= 400 else 1)))
                if target_level >= 10 and mafia_level < 4:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"gang_hire_reply","ok":False,"bot_id":target_id,
                        "reason":"mafia_level"}}, ensure_ascii=False))
                    continue
                if raid_bot and p.get("mafia") and not p.get("police"):
                    if math.hypot(float(p.get("x", 0))-float(raid_bot.get("x", 0)),
                                  float(p.get("y", 0))-float(raid_bot.get("y", 0))) > 3.2:
                        await ws.send_str(json.dumps({"t":"event","d":{
                            "kind":"gang_hire_reply","ok":False,"bot_id":target_id,
                            "reason":"too_far"}}, ensure_ascii=False))
                        continue
                    raid_bot["hp"] = 0
                    raid_bot["alive"] = False
                    raid_bot["hired_by"] = str(uid)
                    business_cleared = not any(
                        member.get("alive")
                        for member in (candidate_nest.get("bots") or []))
                    cooldown_until = 0
                    if business_cleared and business_id:
                        cooldown_until = int(
                            time.time() + PREVIEW_NPC_CAPTURE_COOLDOWN)
                        preview_business_nests.pop(business_id, None)
                        preview_business_capture_cooldown[business_id] = cooldown_until
                        for rows in preview_businesses.values():
                            if business_id in rows:
                                rows[business_id][
                                    "npc_capture_cooldown_until"] = cooldown_until
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"gang_hire_reply","ok":True,"bot_id":target_id,
                        "is_boss":False,"level":target_level,"did":"",
                        "business_id":business_id,
                        "business_cleared":business_cleared,
                        "cooldown_until":cooldown_until}}, ensure_ascii=False))
                    continue
                if target_id.startswith("cgbot_preview_street_") and p.get("mafia") and not p.get("police"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"gang_hire_reply","ok":True,"bot_id":target_id,
                        "is_boss":False,"level":target_level,"did":""}}, ensure_ascii=False))
                    continue
                found = None; found_did = None
                for did, cap in district_captures.items():
                    found = next((b for b in cap.get("defenders") or []
                                  if b.get("alive") and str(b.get("id")) == target_id), None)
                    if found: found_did = did; break
                ok = False
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_hire_reply",
                    "ok":ok,"bot_id":target_id,"is_boss":bool(found),
                    "reason":"district_defender" if found else "gone"}}, ensure_ascii=False))
            elif t == "major_assault_start":
                object_id = str(d.get("object_id") or "")[:24]
                cfg = PREVIEW_MAJOR_OBJECTS.get(object_id)
                actor = players.get(uid) or {}
                owner = preview_major_owners.get(object_id)
                raid = preview_major_raids.get(object_id)
                was_existing = bool(raid)
                if not cfg:
                    reply = {"kind": "major_assault_reply", "ok": False,
                             "reason": "bad_object"}
                elif actor.get("police") or not actor.get("mafia"):
                    reply = {"kind": "major_assault_reply", "ok": False,
                             "reason": "mafia_only", "object_id": object_id}
                elif math.hypot(
                        float(actor.get("x", 0)) - float(cfg["c"]),
                        float(actor.get("y", 0)) - float(cfg["r"])) > 7.0:
                    reply = {"kind": "major_assault_reply", "ok": False,
                             "reason": "too_far", "object_id": object_id}
                elif owner and float(owner.get("expires_at") or 0) > time.time():
                    reply = {
                        "kind": "major_assault_reply", "ok": False,
                        "reason": "protected", "object_id": object_id,
                        "owner_name": owner.get("owner_name"),
                        "expires_in": int(owner["expires_at"] - time.time()),
                    }
                elif raid and str(uid) not in raid.get("participants", set()):
                    reply = {"kind": "major_assault_reply", "ok": False,
                             "reason": "busy", "object_id": object_id,
                             "by_name": raid.get("by_name")}
                else:
                    if not raid:
                        participants = {
                            str(player_uid) for player_uid, player in players.items()
                            if player.get("mafia") and not player.get("police")
                            and not player.get("dead")
                            and math.hypot(
                                float(player.get("x", 0)) -
                                float(actor.get("x", 0)),
                                float(player.get("y", 0)) -
                                float(actor.get("y", 0))) <= 10.0
                        }
                        participants.add(str(uid))
                        guards = [{
                            "id": f"preview_major_{object_id}_{i}",
                            "hp": 140 if i < 4 else 100,
                            "max_hp": 140 if i < 4 else 100,
                            "alive": True, "weapon": "pistol_heavy",
                            "wave": 1, "slot": i,
                        } for i in range(int(cfg["guards"]))]
                        raid = {
                            "object_id": object_id, "by_uid": str(uid),
                            "by_name": actor.get("name", "Demo"),
                            "participants": participants, "phase": "guards",
                            "guards": guards, "spawned": len(guards),
                            "pressure": 0,
                            "safes": [{
                                "id": f"{object_id}_safe_{i + 1}",
                                "opened": False, "value": 250 * (i + 1),
                            } for i in range(
                                4 if object_id == "mansion" else 3)],
                        }
                        preview_major_raids[object_id] = raid
                    reply = {
                        "kind": "major_assault_reply", "ok": True,
                        "resume": was_existing,
                        "object_id": object_id, "phase": raid["phase"],
                        "guards": [dict(guard) for guard in raid["guards"]
                                   if guard.get("alive")],
                        "total": int(cfg["total"]), "boss_name": cfg["boss"],
                        "participants": list(raid["participants"]),
                        "safes": [dict(safe) for safe in raid["safes"]],
                    }
                await broadcast_event(reply)
            elif t == "major_guard_hit":
                object_id = str(d.get("object_id") or "")[:24]
                guard_id = str(d.get("guard_id") or "")[:64]
                raid = preview_major_raids.get(object_id)
                cfg = PREVIEW_MAJOR_OBJECTS.get(object_id)
                actor = players.get(uid) or {}
                guard = next((
                    row for row in (raid or {}).get("guards", [])
                    if row.get("id") == guard_id and row.get("alive")), None)
                if (not raid or not cfg
                        or str(uid) not in raid.get("participants", set())
                        or actor.get("major_interior") != object_id):
                    reply = {"kind": "major_guard_hit", "ok": False,
                             "reason": "not_participant",
                             "object_id": object_id}
                elif not guard:
                    reply = {"kind": "major_guard_hit", "ok": False,
                             "reason": "bad_target", "object_id": object_id}
                else:
                    damage = max(1, min(90, int(d.get("damage") or 34)))
                    guard["hp"] = max(0, int(guard["hp"]) - damage)
                    new_guard = None
                    if guard["hp"] <= 0:
                        guard["alive"] = False
                        if int(raid["spawned"]) < int(cfg["total"]):
                            slot = int(raid["spawned"])
                            new_guard = {
                                "id": f"preview_major_{object_id}_{slot}",
                                "hp": 110, "max_hp": 110, "alive": True,
                                "weapon": "pistol_heavy",
                                "wave": 2 + slot // 10, "slot": slot,
                            }
                            raid["guards"].append(new_guard)
                            raid["spawned"] = slot + 1
                        elif not any(row.get("alive")
                                     for row in raid["guards"]):
                            raid["phase"] = "boss"
                    reply = {
                        "kind": "major_guard_hit", "ok": True,
                        "object_id": object_id, "guard_id": guard_id,
                        "hp": guard["hp"], "alive": guard["alive"],
                        "new_guard": new_guard, "spawned": raid["spawned"],
                        "phase": raid["phase"],
                    }
                await broadcast_event(reply)
            elif t == "major_boss_pressure":
                object_id = str(d.get("object_id") or "")[:24]
                raid = preview_major_raids.get(object_id)
                cfg = PREVIEW_MAJOR_OBJECTS.get(object_id)
                actor = players.get(uid) or {}
                if (not raid or not cfg or raid.get("phase") != "boss"
                        or str(uid) not in raid.get("participants", set())
                        or actor.get("major_interior") != object_id):
                    reply = {"kind": "major_boss_pressure", "ok": False,
                             "reason": "guards_alive",
                             "object_id": object_id}
                else:
                    raid["pressure"] = min(
                        100, int(raid.get("pressure") or 0) + 20)
                    captured = raid["pressure"] >= 100
                    reply = {
                        "kind": "major_boss_pressure", "ok": True,
                        "object_id": object_id,
                        "pressure": raid["pressure"],
                        "phrase": ("Объект ваш!" if captured
                                   else "Я ничего вам не отдам!"),
                        "captured": captured,
                    }
                    if captured:
                        preview_major_owners[object_id] = {
                            "owner_uid": str(uid),
                            "owner_name": actor.get("name", "Demo"),
                            "expires_at": time.time() + 3600,
                        }
                        preview_major_raids.pop(object_id, None)
                        reply.update({
                            "owner_name": actor.get("name", "Demo"),
                            "income": int(cfg["income"]),
                            "expires_in": 3600,
                        })
                await broadcast_event(reply)
            elif t == "major_safe_open":
                object_id = str(d.get("object_id") or "")[:24]
                safe_id = str(d.get("safe_id") or "")[:64]
                raid = preview_major_raids.get(object_id)
                safe = next((
                    row for row in (raid or {}).get("safes", [])
                    if row.get("id") == safe_id), None)
                if (not raid or raid.get("phase") != "boss"
                        or str(uid) not in raid.get("participants", set())
                        or not safe or safe.get("opened")):
                    reply = {
                        "kind": "major_safe_open", "ok": False,
                        "reason": "guards_alive" if raid else "not_participant",
                        "object_id": object_id, "safe_id": safe_id,
                    }
                else:
                    safe["opened"] = True
                    value = int(safe.get("value") or 0)
                    preview_account(uid)["cash"] += value
                    reply = {
                        "kind": "major_safe_open", "ok": True,
                        "object_id": object_id, "safe_id": safe_id,
                        "value": value,
                        "awards": [{"uid": str(uid), "amount": value}],
                    }
                await broadcast_event(reply)
            elif t == "aggro_shoot":
                target_id = str(d.get("target") or "")
                shooter = players.get(uid) or {}
                try:
                    gang_member = int(d.get("member")) if "member" in d else None
                except (TypeError, ValueError):
                    gang_member = None
                gang_rows = shooter.get("gang") if isinstance(shooter.get("gang"), list) else []
                gang_data = (gang_rows[gang_member] if gang_member is not None
                             and 0 <= gang_member < len(gang_rows) else {})
                fighter_level = max(1, min(25, int(gang_data.get("lvl") or 1)))
                fighter_mult = 1.0 + (fighter_level - 1) * .03
                lair_bot = next((b for b in PREVIEW_LAIR_BOTS
                                 if b.get("alive") and str(b.get("id")) == target_id), None)
                if lair_bot:
                    shooter=players.get(uid) or {}
                    if abs(float(shooter.get("x",0))-40)<=20 and abs(float(shooter.get("y",0))-120)<=20:
                        damage=round({"shotgun":76,"rifle":42,"sniper":132,"pistol":28,
                                "pistol_heavy":86,"smg":15,"uzi":15,
                                "grenade":95,"molotov_fire":12}.get(
                                    str(d.get("weapon") or "pistol"),28)*fighter_mult)
                        lair_bot["hp"]=max(0,int(lair_bot["hp"])-damage)
                        if str(d.get("weapon") or "") == "molotov_fire" and lair_bot["hp"] > 0:
                            preview_ignite_bandit(lair_bot, shooter, d)
                        killed=lair_bot["hp"]<=0
                        if killed:
                            lair_bot["alive"]=False
                            lair_bot["dead_at"]=time.time()
                        shooter["lair_hostile"]=True
                        await broadcast_event({"kind":"aggro_hit","tid":"preview_lair",
                            "bot_id":target_id,"hp":lair_bot["hp"],"damage":damage,"dmg":damage,
                            "killed":killed,"sx":shooter.get("x",0),"sy":shooter.get("y",0),
                            "tx":lair_bot["x"],"ty":lair_bot["y"],
                            "is_boss":lair_bot["kind"]=="aggro_boss",
                            "shooter_uid":str(uid),"gang_member":gang_member,
                            "target_level":int(lair_bot.get("level") or 1)})
                        if killed:
                            reward = preview_bandit_kill_reward(
                                uid, lair_bot.get("level"), 0)
                            await ws.send_str(json.dumps({"t":"event","d":{
                                "kind":"aggro_killed", "bot_id":target_id,
                                "is_boss":lair_bot["kind"]=="aggro_boss",
                                "cash":0, **reward}}))
                    continue
                business_nest = None
                business_bot = None
                for candidate in preview_business_nests.values():
                    business_bot = next((b for b in candidate["bots"]
                                         if b.get("alive") and str(b.get("id")) == target_id), None)
                    if business_bot:
                        business_nest = candidate
                        break
                if business_bot and business_nest:
                    shooter = players.get(uid) or {}
                    if math.hypot(float(shooter.get("x", 0)) - business_bot["x"],
                                  float(shooter.get("y", 0)) - business_bot["y"]) <= 18:
                        damage = round({"shotgun":76, "rifle":42, "sniper":132, "pistol":28,
                                  "pistol_heavy":86, "smg":15, "uzi":15,
                                  "grenade":95, "molotov_fire":12}.get(
                                      str(d.get("weapon") or "pistol"), 28)*fighter_mult)
                        business_bot["hp"] = max(0, int(business_bot["hp"]) - damage)
                        if str(d.get("weapon") or "") == "molotov_fire" and business_bot["hp"] > 0:
                            preview_ignite_bandit(business_bot, shooter, d)
                        killed = business_bot["hp"] <= 0
                        if killed:
                            business_bot["alive"] = False
                        business_nest["state"] = "hostile"
                        business_nest["target_uid"] = str(uid)
                        business_nest["hostile_until"] = time.time() + 60.0
                        for ally in business_nest.get("bots", []):
                            if ally.get("alive"):
                                ally["threat"] = random.choice([
                                    "Он стреляет! Ответить!",
                                    "За бизнес! Огонь!",
                                    "Убрать его!",
                                ])
                                ally["threat_until"] = time.time() + 2.5
                        await broadcast_event({
                            "kind":"aggro_hit", "tid":business_nest["id"],
                            "bot_id":target_id, "hp":business_bot["hp"],
                            "damage":damage, "dmg":damage, "killed":killed,
                            "sx":shooter.get("x",0), "sy":shooter.get("y",0),
                            "tx":business_bot["x"], "ty":business_bot["y"],
                            "is_nest":True,"shooter_uid":str(uid),"gang_member":gang_member,
                            "target_level":int(business_bot.get("level") or 1),
                        })
                        if killed:
                            reward = preview_bandit_kill_reward(
                                uid, business_bot.get("level"), 8)
                            await ws.send_str(json.dumps({
                                "t":"event",
                                "d":{
                                    "kind":"aggro_killed",
                                    "bot_id":target_id,
                                    "is_boss":False,
                                    "is_nest":True,
                                    "cash":50,
                                    **reward,
                                },
                            }, ensure_ascii=False))
                        preview_tick_business_captures()
                    continue
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
                    cap = district_captures[found_did]
                    # Только подтверждённое попадание разворачивает всю охрану
                    # на конкретного стрелка. На других игроков не переключаемся.
                    cap["hostile_uid"] = str(uid)
                    cap["hostile_until"] = time.time() + 30.0
                    damage = round({
                        "shotgun":76, "rifle":42, "sniper":132, "pistol":28,
                        "pistol_heavy":86, "smg":15, "uzi":15,
                        "grenade":95, "molotov_fire":12,
                    }.get(str(d.get("weapon") or "pistol"), 28) * fighter_mult)
                    found["hp"] = max(0, int(found["hp"]) - damage)
                    if str(d.get("weapon") or "") == "molotov_fire" and found["hp"] > 0:
                        preview_ignite_bandit(found, shooter, d)
                    killed = found["hp"] <= 0
                    if killed:
                        found["alive"] = False
                        weapon=str(d.get("weapon") or "pistol")
                        ammo_map={"pistol":"9mm","pistol_gold":"9mm","smg":"9mm","tommy_gun":"9mm",
                            "nagan":"magnum","pistol_heavy":"magnum","shotgun":"shell","rifle":"rifle",
                            "sniper":"sniper","rpg":"rocket"}
                        round_map={"9mm":12,"magnum":6,"shell":6,"rifle":15,"sniper":3,"rocket":1}
                        ammo_type=ammo_map.get(weapon,"9mm")
                        ammo_id=f"preview_ammo_{int(time.time()*1000)}"
                        district_loot[ammo_id]={"id":ammo_id,"kind":"ammo","x":float(found["x"]),
                            "y":float(found["y"]),"ammo_type":ammo_type,"rounds":round_map[ammo_type],
                            "expires_at":time.time()+90.0}
                    is_boss = found.get("kind") == "district_boss"
                    if killed and is_boss:
                        preview_drop_district_dossier(found_did, cap, found, time.time())
                    p = players.get(uid) or {}
                    await broadcast_event({
                        "kind": "aggro_hit", "bot_id": target_id,
                        "hp": found["hp"], "damage": damage, "killed": killed,
                        "sy": p.get("y", 0), "sx": p.get("x", 0),
                        "ty": found["y"], "tx": found["x"],
                        "district_boss": is_boss, "did": found_did,
                        "shooter_uid":str(uid),"gang_member":gang_member,
                        "target_level":int(found.get("level") or 1),
                    })
                    if killed:
                        reward = preview_bandit_kill_reward(
                            uid, found.get("level"), 0)
                        await ws.send_str(json.dumps({"t": "event", "d": {
                            "kind": "aggro_killed", "bot_id": target_id,
                            "is_boss": is_boss, "cash": 0, **reward,
                        }}))
            elif t == "district_capture_cancel":
                for did, cap in list(district_captures.items()):
                    if str(cap.get("by_uid")) == str(uid):
                        district_captures.pop(did, None)
                        await broadcast_event({"kind": "district_capture_cancelled", "did": did,
                                               "by_uid": str(uid), "reason": "cancelled"})
                        break
            elif t == "police_resign":
                account = preview_account(uid)
                cop = players.get(uid, {})
                cop["police"] = False
                cop["police_escort_uid"] = None
                cop["police_online_target"] = None
                cop["police_taser_ammo"] = 0
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"police_xp_reply","ok":True,"resigned":True,"police_xp":int(account.get("police_xp", 0))}}, ensure_ascii=False))
            elif t == "police_xp_sync":
                account = preview_account(uid)
                account["police_xp"] = min(2800, max(int(account.get("police_xp", 0)), max(0, int(d.get("xp") or 0))))
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"police_xp_reply","ok":True,"police_xp":account["police_xp"]}}, ensure_ascii=False))
            elif t == "police_npc_reward":
                cop = players.get(uid, {})
                xp = int(d.get("xp") or 0)
                mission_id = str(d.get("mission_id") or "")[:96]
                rewarded = cop.setdefault("police_npc_rewards", set())
                ok = bool(cop.get("police") and mission_id and xp in (65, 180, 300) and mission_id not in rewarded)
                daily = preview_claim_police_arrest(uid) if ok else None
                if ok and daily.get("ok"):
                    rewarded.add(mission_id)
                    account = preview_account(uid)
                    account["police_xp"] = min(2800, int(account.get("police_xp", 0)) + xp)
                elif ok:
                    ok = False
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"police_xp_reply","ok":ok,
                    "error":("" if ok else ((daily or {}).get("error") or "invalid")),
                    "mission_id":mission_id,"police_xp":int(preview_account(uid).get("police_xp",0)),
                    "daily_count":((daily or {}).get("count",preview_police_daily_state(uid)[1])),
                    "daily_limit":((daily or {}).get("limit",preview_police_daily_state(uid)[2]))}}, ensure_ascii=False))
            elif t == "career_vehicle_spawn":
                reply = preview_career_vehicle(uid, d)
                reply["kind"] = "career_vehicle_reply"
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
            elif t in ("police_patrol_spawn", "police_spikes", "police_backup"):
                cop = players.get(uid, {})
                account = preview_account(uid)
                now = time.time()
                if t == "police_patrol_spawn":
                    reply = preview_police_patrol(uid)
                    reply["kind"] = "police_patrol_reply"
                elif not cop.get("police"):
                    reply = {"ok": False, "error": "not_police"}
                elif int(account.get("police_xp", 0)) < 1600:
                    reply = {"ok": False, "error": "level_locked"}
                elif t == "police_spikes" and now - float(cop.get("police_spikes_at", 0)) < 25:
                    reply = {"ok": False, "error": "cooldown",
                             "cooldown_left": round(25-(now-float(cop.get("police_spikes_at",0))),2)}
                elif t == "police_backup" and now - float(cop.get("police_backup_at", 0)) < 90:
                    reply = {"ok": False, "error": "cooldown",
                             "cooldown_left": round(90-(now-float(cop.get("police_backup_at",0))),1)}
                elif t == "police_spikes":
                    cop["police_spikes_at"] = now
                    reply = {"ok": True, "kind": "police_spikes_reply",
                             "id": f"spikes_{uid}_{int(now*1000)}",
                             "r": float(cop.get("y", 0)), "c": float(cop.get("x", 0)),
                             "ang": float(cop.get("ang", 0)), "cop_uid": uid, "life_s": 45}
                else:
                    cop["police_backup_at"] = now
                    reply = {"ok": True, "kind": "police_backup_reply", "cop_uid": uid, "life_s": 45}
                reply.setdefault("kind", "police_spikes_reply" if t == "police_spikes" else "police_backup_reply")
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
                if t == "police_spikes" and reply.get("ok"):
                    deployed = dict(reply); deployed["kind"] = "police_spikes_deployed"
                    await broadcast_event(deployed)
            elif t == "player_shoot":
                shooter = players.get(uid, {})
                target_uid = str(d.get("target_uid") or "")
                target = players.get(target_uid)
                now_shot = time.time()
                biz_id = str(shooter.get("business_interior") or "")
                same_biz = bool(target and biz_id and str(target.get("business_interior") or "") == biz_id)
                shooter_attacker=preview_business_aggro.get((str(uid),biz_id),0)>now_shot
                target_attacker=preview_business_aggro.get((target_uid,biz_id),0)>now_shot
                business_defense = bool(same_biz and (
                    (shooter.get("business_private") and target_attacker) or
                    (target.get("business_private") and shooter_attacker)))
                business_police_fight=bool(same_biz and ((shooter.get("police") and target_attacker) or
                                                         (target.get("police") and shooter_attacker)))
                if target and (business_defense or business_police_fight) and not shooter.get("dead") and not target.get("dead"):
                    sx,sy=float(shooter.get("interior_x",0)),float(shooter.get("interior_y",0))
                    tx,ty=float(target.get("interior_x",0)),float(target.get("interior_y",0))
                    if (sx-tx)**2+(sy-ty)**2 <= 10**2:
                        weapon=str(d.get("weapon") or "pistol")
                        damage={"shotgun":30,"rifle":26,"sniper":45,"pistol":18,"pistol_heavy":22,"smg":14}.get(weapon,18)
                        target["hp"]=max(0,int(target.get("hp",100))-damage); killed=target["hp"]<=0
                        shooter["combat_until"]=now_shot+10
                        target["combat_until"]=now_shot+10
                        prevented=bool(killed and shooter.get("police") and target_attacker)
                        defended=bool(killed and business_defense and shooter.get("business_private") and target_attacker)
                        reward={}
                        if killed:
                            target["dead"]=True; target["respawn_at"]=now_shot+5
                        if prevented:
                            preview_business_police_protection[(target_uid,biz_id)]=now_shot+300
                            preview_business_aggro.pop((target_uid,biz_id),None)
                            account=preview_account(uid);account["cash"]+=150
                            old_xp=int(account.get("police_xp",0));account["police_xp"]=min(4000,old_xp+35)
                            old_hp=int(shooter.get("hp",100));shooter["hp"]=min(100,old_hp+25)
                            reward={"business_prevented":True,"business_id":biz_id,"cash_reward":150,
                                    "police_xp":account["police_xp"],"police_xp_gain":account["police_xp"]-old_xp,
                                    "hp_reward":shooter["hp"]-old_hp}
                        elif defended:
                            preview_business_owner_protection[(target_uid,biz_id)]=now_shot+300
                            preview_business_aggro.pop((target_uid,biz_id),None)
                            reward={"business_defended":True,"business_id":biz_id}
                        await broadcast_event({"kind":"pvp_shot","shooter_uid":str(uid),"target_uid":target_uid,
                            "shooter_name":shooter.get("name","Защитник"),"target_name":target.get("name","Грабитель"),
                            "sx":sx,"sy":sy,"tx":tx,"ty":ty,"dmg":damage,"killed":killed,"weapon":weapon,**reward})
                elif (target and shooter.get("police") and not target.get("police") and
                        int(target.get("wanted", 0)) > 0 and not shooter.get("dead") and
                        not target.get("dead") and not shooter.get("business_interior") and
                        not target.get("business_interior") and
                        not shooter.get("in_interior") and not target.get("in_interior") and
                        (float(shooter.get("x",0))-float(target.get("x",0)))**2 +
                        (float(shooter.get("y",0))-float(target.get("y",0)))**2 <= 8.5**2):
                    weapon = str(d.get("weapon") or "pistol")
                    damage = {"shotgun":55,"rifle":42,"sniper":100,"pistol":28}.get(weapon,32)
                    target["hp"] = max(0, int(target.get("hp",100))-damage)
                    shooter["combat_until"]=now_shot+10
                    target["combat_until"]=now_shot+10
                    killed = target["hp"] <= 0
                    if killed:
                        old_uid = str(shooter.get("police_downed_target") or "")
                        if old_uid and players.get(old_uid):
                            players[old_uid].pop("police_downed_by",None)
                            players[old_uid].pop("police_downed_until",None)
                        target["dead"] = True; target["respawn_at"] = time.time()+5
                        target["police_downed_by"] = str(uid)
                        target["police_downed_until"] = time.time()+5
                        shooter["police_downed_target"] = target_uid
                    await broadcast_event({"kind":"pvp_shot","shooter_uid":str(uid),
                        "target_uid":target_uid,"shooter_name":shooter.get("name","Коп"),
                        "target_name":target.get("name","Игрок"),"sx":shooter.get("x",0),
                        "sy":shooter.get("y",0),"tx":target.get("x",0),"ty":target.get("y",0),
                        "dmg":damage,"killed":killed,"police_downed":killed,
                        "decision_until":target.get("police_downed_until",0),"weapon":weapon})
            elif t in ("police_online_select", "police_online_stun", "police_online_taser", "police_online_cuff", "police_downed_arrest", "police_online_turnin"):
                cop = players.get(uid, {})
                target_uid = str(d.get("target_uid") or cop.get("police_escort_uid") or "")
                target = players.get(target_uid)
                reply = {"ok": False, "error": "not_police"}
                if cop.get("police"):
                    if t == "police_online_select":
                        if target and int(target.get("wanted", 0)) > 0 and not target.get("dead"):
                            cop["police_online_target"] = target_uid
                            reply = {"ok":True,"target_uid":target_uid,"name":target.get("name","Игрок")}
                        else: reply = {"ok":False,"error":"not_wanted"}
                    elif t == "police_online_stun":
                        if not target or str(cop.get("police_online_target") or "") != target_uid:
                            reply = {"ok":False,"error":"not_selected"}
                        elif cop.get("business_interior") or target.get("business_interior"):
                            reply = {"ok":False,"error":"interior"}
                        elif (float(cop.get("x",0))-float(target.get("x",0)))**2 + (float(cop.get("y",0))-float(target.get("y",0)))**2 > 2.15**2:
                            reply = {"ok":False,"error":"too_far"}
                        elif int(target.get("wanted",0)) <= 0 or target.get("dead"):
                            reply = {"ok":False,"error":"not_wanted"}
                        elif target.get("police_cuffed_by"):
                            reply = {"ok":False,"error":"already_cuffed"}
                        else:
                            target["police_stunned_until"] = time.time()+5
                            reply = {"ok":True,"target_uid":target_uid,"until":target["police_stunned_until"]}
                    elif t == "police_online_taser":
                        now = time.time()
                        if int(preview_account(uid).get("police_xp", 0)) < 2800:
                            reply = {"ok":False,"error":"taser_locked"}
                        elif not target or str(cop.get("police_online_target") or "") != target_uid:
                            reply = {"ok":False,"error":"not_selected"}
                        elif cop.get("business_interior") or target.get("business_interior"):
                            reply = {"ok":False,"error":"interior"}
                        elif (float(cop.get("x",0))-float(target.get("x",0)))**2 + (float(cop.get("y",0))-float(target.get("y",0)))**2 > 7.5**2:
                            reply = {"ok":False,"error":"too_far"}
                        elif now-float(cop.get("police_taser_at",0)) < 1.2:
                            reply = {"ok":False,"error":"cooldown"}
                        elif int(target.get("wanted",0)) <= 0 or target.get("dead"):
                            reply = {"ok":False,"error":"not_wanted"}
                        elif target.get("police_cuffed_by"):
                            reply = {"ok":False,"error":"already_cuffed"}
                        else:
                            cop["police_taser_at"] = now
                            target["police_stunned_until"] = now+5
                            reply = {"ok":True,"target_uid":target_uid,"until":target["police_stunned_until"]}
                    elif t == "police_online_cuff":
                        if not target or str(cop.get("police_online_target") or "") != target_uid:
                            reply = {"ok":False,"error":"not_selected"}
                        elif cop.get("police_escort_uid"):
                            reply = {"ok":False,"error":"already_escorting"}
                        elif int(target.get("wanted",0)) <= 0 or target.get("dead"):
                            reply = {"ok":False,"error":"not_wanted"}
                        elif cop.get("business_interior") or target.get("business_interior"):
                            reply = {"ok":False,"error":"interior"}
                        elif target.get("police_cuffed_by"):
                            reply = {"ok":False,"error":"already_cuffed"}
                        elif float(target.get("police_stunned_until",0)) < time.time():
                            reply = {"ok":False,"error":"not_stunned"}
                        elif (float(cop.get("x",0))-float(target.get("x",0)))**2 + (float(cop.get("y",0))-float(target.get("y",0)))**2 > 2.15**2:
                            reply = {"ok":False,"error":"too_far"}
                        else:
                            target["police_cuffed_by"] = uid; target["police_cuff_until"] = time.time()+20
                            cop["police_escort_uid"] = target_uid
                            reply = {"ok":True,"target_uid":target_uid,"cop_uid":uid,"until":target["police_cuff_until"]}
                    elif t == "police_downed_arrest":
                        now=time.time()
                        if not target or target.get("police"):
                            reply={"ok":False,"error":"not_online"}
                        elif cop.get("police_escort_uid"):
                            reply={"ok":False,"error":"already_escorting"}
                        elif int(target.get("wanted",0)) <= 0:
                            reply={"ok":False,"error":"not_wanted"}
                        elif (not target.get("dead") or str(target.get("police_downed_by") or "") != str(uid)
                              or now > float(target.get("police_downed_until",0))):
                            reply={"ok":False,"error":"decision_expired"}
                        elif (float(cop.get("x",0))-float(target.get("x",0)))**2 + (float(cop.get("y",0))-float(target.get("y",0)))**2 > 2.15**2:
                            reply={"ok":False,"error":"too_far"}
                        else:
                            target.pop("police_downed_by",None); target.pop("police_downed_until",None)
                            cop.pop("police_downed_target",None)
                            target["dead"]=False; target["hp"]=1; target.pop("respawn_at",None)
                            target["wanted"]=0; target["police_cuffed_by"]=str(uid)
                            target["police_cuff_until"]=now+20; target["police_death_arrest"]=True
                            cop["police_escort_uid"]=target_uid
                            reply={"ok":True,"target_uid":target_uid,"cop_uid":str(uid),
                                   "until":target["police_cuff_until"],"death_arrest":True}
                    else:
                        if not target or str(target.get("police_cuffed_by") or "") != str(uid):
                            reply = {"ok":False,"error":"no_escort"}
                        elif (float(cop.get("x",0))-76)**2 + (float(cop.get("y",0))-76)**2 > 5.2**2:
                            reply = {"ok":False,"error":"not_at_station"}
                        else:
                            daily=preview_claim_police_arrest(uid)
                            if not daily.get("ok"):
                                target.pop("police_cuffed_by",None);target.pop("police_cuff_until",None)
                                target.pop("police_death_arrest",None);target["hp"]=max(25,int(target.get("hp",0)))
                                cop.pop("police_escort_uid",None)
                                reply={"ok":False,"error":"daily_limit","daily_count":daily["count"],"daily_limit":daily["limit"]}
                            else:
                                first=target_uid not in preview_police_rewards
                                preview_police_rewards.add(target_uid)
                                if first: preview_account(uid)["cash"] += 700
                                preview_account(uid)["police_xp"] = min(2800, int(preview_account(uid).get("police_xp",0)) + 75)
                                target["wanted"]=0; target["jail_until"]=time.time()+30
                                target["x"],target["y"]=76.5,76.5
                                target.pop("police_death_arrest",None)
                                target.pop("police_cuffed_by",None); target.pop("police_cuff_until",None)
                                cop.pop("police_escort_uid",None); cop.pop("police_online_target",None)
                                reply={"ok":True,"target_uid":target_uid,"target_name":target.get("name","Игрок"),
                                       "first_reward":first,"cash":700 if first else 0,"exp":75 if first else 0,
                                       "police_xp_gain":75,"police_xp":preview_account(uid)["police_xp"],
                                       "daily_count":daily["count"],"daily_limit":daily["limit"]}
                reply["kind"] = t + "_reply"
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
                if reply.get("ok"):
                    action=dict(reply); action["kind"]=t
                    await broadcast_event(action)
            elif t == "gta_status":
                q=preview_gta_quests.get(str(uid));await ws.send_str(json.dumps({"t":"event","d":{"kind":"gta_status","ok":True,"count_today":1 if q else 0,"limit":2,"reset_in_s":0,"sc_lvl":5,"active":q}},ensure_ascii=False))
            elif t == "gta_take":
                p=players.get(uid) or {};q=preview_gta_quests.get(str(uid))
                if q:reply={"kind":"gta_take_reply","ok":False,"reason":"has_active","model":q["model"]}
                elif (float(p.get("x",0))-42)**2+(float(p.get("y",0))-183)**2>16:reply={"kind":"gta_take_reply","ok":False,"reason":"too_far"}
                else:
                    car_id=f"michael_preview_{uid}";car={"id":car_id,"model":"ferrari_f40","owner_uid":str(uid),"x":49.0,"y":158.0,"ang":0.0,"vx":0,"vy":0,"driver_uid":None,"hp":180,"reward":650}
                    quest_cars[car_id]=car;q={"car_id":car_id,"model":car["model"],"reward":car["reward"],"x":car["x"],"y":car["y"],"state":"idle"};preview_gta_quests[str(uid)]=q;reply={"kind":"gta_take_reply","ok":True,**q}
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
            elif t == "box_status":
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_status","ok":True,"count_today":0,"limit":5,"reset_in_s":0,"fail_cd_s":0,"active":preview_box_quests.get(str(uid))}},ensure_ascii=False))
            elif t == "box_take":
                p=players.get(uid) or {};q=preview_box_quests.get(str(uid))
                if q:reply={"kind":"box_take_reply","ok":False,"reason":"has_active"}
                elif (float(p.get("x",0))-42)**2+(float(p.get("y",0))-183)**2>16:reply={"kind":"box_take_reply","ok":False,"reason":"too_far"}
                else:
                    business_id,addr,dx,dy=random.choice(PREVIEW_BOX_DROPOFFS);q={"pickup_x":40.,"pickup_y":166.,"dropoff_x":dx,"dropoff_y":dy,"business_id":business_id,"addr":addr,"reward":350,"state":"pending"};preview_box_quests[str(uid)]=q;reply={"kind":"box_take_reply","ok":True,**q}
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
            elif t == "box_pickup":
                reply=preview_pickup_box(uid,d.get("owner_uid") if isinstance(d,dict) else "")
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_pickup_reply",**reply}},ensure_ascii=False))
            elif t == "box_load":
                q=preview_box_quests.get(str(uid));car_id=str(d.get("car_id") or "")[:96]
                ok=bool(q and q.get("state")=="carrying" and car_id)
                if ok:q["state"]="loaded";q["car_id"]=car_id
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_load_reply","ok":ok,"state":"loaded" if ok else None,"car_id":car_id,"reason":None if ok else "wrong_state"}},ensure_ascii=False))
            elif t == "box_unload":
                q=preview_box_quests.get(str(uid));car_id=str(d.get("car_id") or "")[:96]
                ok=bool(q and q.get("state")=="loaded" and str(q.get("car_id") or "")==car_id)
                reply=preview_drop_box(uid,"unload") if ok else {"ok":False,"reason":"wrong_car"}
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_unload_reply",**reply}},ensure_ascii=False))
            elif t == "box_drop":
                reply=preview_drop_box(uid,"manual")
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_drop_reply",**reply}},ensure_ascii=False))
            elif t == "box_deliver":
                p=players.get(uid) or {};q=preview_box_quests.get(str(uid))
                state_ok=bool(q and q.get("state")=="carrying")
                right_business=bool(state_ok and str(p.get("business_interior") or "")==str(q.get("business_id") or ""))
                ok=bool(right_business and preview_robber_at_cashier(p,q.get("business_id")))
                reward=int(q.get("reward",0)) if ok else 0;addr=q.get("addr") if q else ""
                if ok:preview_account(uid)["cash"]+=reward;preview_box_quests.pop(str(uid),None)
                reason=None if ok else ("no_quest" if not q else ("wrong_state" if not state_ok else ("wrong_business" if not right_business else "too_far_npc")))
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_deliver_reply","ok":ok,"reason":reason,"reward":reward,"addr":addr,"business_id":q.get("business_id") if q else None}},ensure_ascii=False))
            elif t == "box_abandon":
                ok=preview_box_quests.pop(str(uid),None) is not None;await ws.send_str(json.dumps({"t":"event","d":{"kind":"box_abandon_reply","ok":ok,"wait_s":600}},ensure_ascii=False))
            elif t == "gta_enter":
                car = quest_cars.get(str(d.get("car_id") or ""))
                reason = None
                p = players.setdefault(uid, {})
                if not car:
                    reason = "gone"
                elif car.get("police_patrol"):
                    driver_uid = str(car.get("driver_uid") or "")
                    is_police = bool(p.get("police"))
                    is_stolen_owner = bool(car.get("police_stolen")) and str(car.get("owner_uid") or "") == str(uid)
                    if driver_uid and driver_uid != str(uid):
                        if not is_police:
                            reason = "police_only"
                        elif len(car.setdefault("passenger_uids", [])) >= 1:
                            reason = "full"
                        else:
                            car["passenger_uids"].append(str(uid))
                    elif not is_police and not is_stolen_owner and not bool(d.get("police_lockpicked")):
                        reason = "police_locked"
                    else:
                        car["driver_uid"] = uid
                        car["owner_uid"] = uid
                        car["passenger_uids"] = []
                        car["state"] = "driving"
                        car["police_stolen"] = not is_police
                else:
                    car["driver_uid"] = uid
                    car["owner_uid"] = uid
                    car["passenger_uids"] = []
                if car and not reason:
                    p["x"] = car["x"]
                    p["y"] = car["y"]
                    p["ang"] = car.get("ang", 0.0)
                elif reason:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"gta_drive_reject","ok":False,"reason":reason,
                        "car_id":str(d.get("car_id") or "")}}, ensure_ascii=False))
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
                    speed = math.hypot(car["vx"], car["vy"])
                    cap = 5.9 if car.get("tires_punctured") else 14.0
                    if speed > cap:
                        car["vx"] *= cap / speed; car["vy"] *= cap / speed
                    p = players.setdefault(uid, {})
                    p["x"] = car["x"]
                    p["y"] = car["y"]
                    p["ang"] = car["ang"]
            elif t in ("gta_siren", "gta_tires_punctured"):
                car = quest_cars.get(str(d.get("car_id") or ""))
                if car and str(car.get("driver_uid") or "") == str(uid):
                    if t == "gta_siren" and car.get("police_patrol"):
                        car["siren"] = bool(d.get("enabled")); await broadcast_event({"kind":t,"ok":True,"car_id":car["id"],"siren":car["siren"]})
                    elif t == "gta_tires_punctured":
                        car["tires_punctured"] = True; await broadcast_event({"kind":t,"ok":True,"car_id":car["id"],"tires_punctured":True})
            elif t == "gta_exit":
                car = quest_cars.get(str(d.get("car_id") or ""))
                if car and str(car.get("driver_uid")) == str(uid):
                    if car.get("model") in ("police_heli", "mafia_heli") and not bool(d.get("landing_ok")):
                        await ws.send_str(json.dumps({"t":"event","d":{
                            "kind":"gta_exit_reply","ok":False,"reason":"unsafe_landing",
                            "car_id":car["id"],"model":car.get("model")}},ensure_ascii=False))
                        continue
                    release_car(car)
                    delivered = (37 <= float(car.get("x", 0)) <= 43 and
                                 167 <= float(car.get("y", 0)) <= 173 and
                                 str(car.get("owner_uid") or "") == str(uid))
                    reward = int(car.get("reward") or 0) if delivered else 0
                    if delivered:
                        preview_account(uid)["cash"] += reward
                        preview_gta_quests.pop(str(uid), None)
                        quest_cars.pop(str(car.get("id") or ""), None)
                    await ws.send_str(json.dumps({
                        "t": "event",
                        "d": {"kind": "gta_exit_reply", "ok": True,
                              "delivered": delivered, "reward": reward,
                              "car_id": car["id"], "model": car.get("model"),
                              "owner_uid": car.get("owner_uid"),
                              "x": round(float(car.get("x", 0)), 3),
                              "y": round(float(car.get("y", 0)), 3),
                              "ang": round(float(car.get("ang", 0)), 3),
                              "hp": int(car.get("hp", 220)),
                              "max_hp": int(car.get("max_hp", 220)),
                              "civilian": bool(car.get("civilian", not delivered)),
                              "police_patrol": bool(car.get("police_patrol", False)),
                              "police_stolen": bool(car.get("police_stolen", False))},
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
            elif t == "bank_enter":
                p["in_interior"] = True
            elif t == "bank_exit":
                p["in_interior"] = False
            elif t == "bank_rob_start":
                bank_id = str(d.get("bank_id") or "")
                if p.get("police"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"bank_rob_start_reply", "ok":False,
                        "reason":"police_on_duty"}}, ensure_ascii=False))
                elif not p.get("mafia"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"bank_rob_start_reply", "ok":False,
                        "reason":"mafia_only"}}, ensure_ascii=False))
                elif bank_id in PREVIEW_BANK_REWARD:
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
                evidence = p.get("police_evidence_bag")
                was_carried = bool(rob and rob.get("carried"))
                if rob:
                    rob["carried"] = 0
                    if d.get("confiscated"):
                        preview_bank_robs.pop(str(uid), None)
                if not d.get("confiscated") and (evidence or was_carried):
                    bank_id = str((evidence or {}).get("bank_id") or (rob or {}).get("bank_id") or "")
                    value = int((evidence or {}).get("value") or PREVIEW_BANK_REWARD.get(bank_id, 0))
                    bag_id = str(d.get("bag_id") or "")[:80]
                    if not bag_id.startswith("bag_") or bag_id in preview_bank_bags:
                        bag_id = f"bag_preview_{time.time_ns()}"
                    try:
                        drop_x = float(d.get("c"))
                        drop_y = float(d.get("r"))
                        if not (math.isfinite(drop_x) and math.isfinite(drop_y)):
                            raise ValueError
                        if not (0 <= drop_x < 80 and 0 <= drop_y < 200):
                            raise ValueError
                    except (TypeError, ValueError):
                        drop_x = float(p.get("x", 0))
                        drop_y = float(p.get("y", 0))
                    preview_bank_bags[bag_id] = {
                        "id":bag_id, "bank_id":bank_id, "value":value,
                        "x":drop_x, "y":drop_y,
                        "dropped_at":time.time(), "robber_uid":str(uid),
                    }
                    p.pop("police_evidence_bag", None)
            elif t == "police_bank_bag_pickup":
                bag_id = str(d.get("bag_id") or "")[:80]
                bag = preview_bank_bags.get(bag_id)
                reason = None
                if not p.get("police"): reason = "not_police"
                elif p.get("dead"): reason = "dead"
                elif p.get("police_evidence_bag"): reason = "hands_full"
                elif not bag: reason = "gone"
                elif (float(p.get("x",0))-float(bag.get("x",0)))**2 + (float(p.get("y",0))-float(bag.get("y",0)))**2 > 2.5**2:
                    reason = "too_far"
                if reason:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"police_bank_bag_pickup_reply","ok":False,
                        "reason":reason,"bag_id":bag_id}}, ensure_ascii=False))
                else:
                    preview_bank_bags.pop(bag_id, None)
                    p["police_evidence_bag"] = dict(bag)
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"police_bank_bag_pickup_reply","ok":True,
                        "bag_id":bag_id,"bank_id":bag.get("bank_id"),
                        "value":int(bag.get("value") or 0)}}, ensure_ascii=False))
            elif t == "police_bank_bag_turnin":
                bag = p.get("police_evidence_bag")
                reason = None
                if not p.get("police"): reason = "not_police"
                elif p.get("dead"): reason = "dead"
                elif not bag: reason = "no_evidence"
                elif (float(p.get("x",0))-76)**2 + (float(p.get("y",0))-76)**2 > 5.2**2:
                    reason = "not_at_station"
                if reason:
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"police_bank_bag_turnin_reply","ok":False,
                        "reason":reason}}, ensure_ascii=False))
                else:
                    reward = int(bag.get("value") or 0)
                    account = preview_account(uid); account["cash"] += reward
                    p.pop("police_evidence_bag", None)
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"police_bank_bag_turnin_reply","ok":True,
                        "reward":reward,"cash":account["cash"],
                        "bank_id":bag.get("bank_id")}}, ensure_ascii=False))
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
                    if not p.get("police"):
                        account["mafia_xp"] = min(4000, int(account.get("mafia_xp", 0)) + 120)
                    apartment = preview_owned_apartments(uid)[apt_key]
                    apartment["stolen_bags"] = max(0, int(apartment.get("stolen_bags") or 0)) + 1
                    preview_bank_robs.pop(str(uid), None)
                    await ws.send_str(json.dumps({"t": "event", "d": {
                        "kind": "bank_rob_finished", "bank_id": bank_id,
                        "ok": True, "payout": payout, "bags": 1,
                        "cash": account["cash"], "place": "apartment",
                        "apt_key": apt_key, "stolen_bags": apartment["stolen_bags"],
                        "mafia_xp": account.get("mafia_xp", 0),
                        "mafia_xp_gain": 0 if p.get("police") else 120,
                        "mafia_reason": "Мешок доставлен в квартиру",
                    }}, ensure_ascii=False))
    finally:
        task.cancel()
        clients.discard(ws)
        leaving = players.get(uid) or {}
        if leaving.get("_ws") is ws:
            if (preview_box_quests.get(str(uid)) or {}).get("state") in ("carrying", "loaded"):
                preview_drop_box(uid, "disconnect")
            evidence = leaving.get("police_evidence_bag")
            if evidence:
                bag_id = f"bag_preview_{time.time_ns()}"
                preview_bank_bags[bag_id] = {
                    "id":bag_id, "bank_id":str(evidence.get("bank_id") or ""),
                    "value":int(evidence.get("value") or 0),
                    "x":float(leaving.get("x",0)), "y":float(leaving.get("y",0)),
                    "dropped_at":time.time(), "robber_uid":str(uid),
                }
            release_player_cars(uid)
            crew_id=str(leaving.get("crew_id") or "")
            players.pop(uid, None)
            if crew_id:
                left=[q for q in players.values() if str(q.get("crew_id") or "")==crew_id]
                if len(left)<2:
                    for q in left:q.pop("crew_id",None)
            gang_player_invites.pop(str(uid),None)
            for target_uid,inv in list(gang_player_invites.items()):
                if str(inv.get("from_uid") or "")==str(uid):gang_player_invites.pop(target_uid,None)
    return ws


app = web.Application()
app.router.add_route("OPTIONS", "/{tail:.*}", options)
app.router.add_get("/preview/world.html", preview_world)
app.router.add_get("/coop_api.json", coop_api)
app.router.add_get("/world/sim", world_ws)
app.router.add_get("/inv/{uid}/list", inv_list)
app.router.add_post("/inv/{uid}/equip", inv_equip)
app.router.add_post("/inv/{uid}/consume", inv_consume)
app.router.add_post("/inv/{uid}/found", inv_found)
app.router.add_post("/inv/{uid}/sell-found", inv_sell_found)
app.router.add_post("/shop/{uid}/buy", shop_buy)
app.router.add_get("/world/leaderboard", leaderboard)
app.router.add_get("/world/newspaper", newspaper)
app.router.add_get("/world/district_status/{uid}", district_status)
app.router.add_get("/apartment/{uid}/state", apartment_state)
app.router.add_post("/apartment/{uid}/buy", apartment_buy)
app.router.add_post("/apartment/{uid}/upgrade", apartment_upgrade)
app.router.add_post("/apartment/{uid}/sell", apartment_sell)
app.router.add_get("/biz/{uid}/list", business_list)
app.router.add_post("/biz/{uid}/buy", business_buy)
app.router.add_post("/biz/{uid}/guards/hire", business_guard_hire)
app.router.add_post("/biz/{uid}/upgrade", business_upgrade)
app.router.add_post("/biz/{uid}/collect", business_collect)
app.router.add_post("/biz/{uid}/said/hire", said_hire)
app.router.add_post("/biz/{uid}/said/fire", said_fire)
app.router.add_get("/skill/{uid}/state", skill_state)
app.router.add_post("/skill/{uid}/upgrade", skill_upgrade)


if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=8082)
