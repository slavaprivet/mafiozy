import asyncio
import json
import math
import random
import os
from pathlib import Path
import time
from aiohttp import web
import npc_empire


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
    "northside":  {"bounds":(0,39,0,39), "hq":(20.,20.), "intel":(11.,20.), "sabotage":((14.,12.),(20.,29.),(29.,18.)), "escape":(35.,20.), "name":"Норт-Сайд", "boss_name":"Мясник Морелло", "icon":"🏪", "income":400, "color":"#4aa3df"},
    "downtown":   {"bounds":(0,39,40,79), "hq":(20.,60.), "intel":(11.,60.), "sabotage":((15.,49.),(19.,70.),(30.,58.)), "escape":(35.,60.), "name":"Даунтаун", "boss_name":"Винсент Крысолов", "icon":"🏙", "income":600, "color":"#e0b94a"},
    "southside":  {"bounds":(40,99,0,39), "hq":(70.,20.), "intel":(53.,20.), "sabotage":((60.,10.),(72.,30.),(83.,18.)), "escape":(95.,20.), "name":"Саутсайд", "boss_name":"Тони Кувалда", "icon":"🎰", "income":500, "color":"#9b59b6"},
    "industrial": {"bounds":(40,99,40,79), "hq":(70.,60.), "intel":(53.,60.), "sabotage":((60.,49.),(72.,70.),(83.,58.)), "escape":(95.,60.), "name":"Промзона", "boss_name":"Борис Шлак", "icon":"🏭", "income":550, "color":"#d2691e"},
    "coast":      {"bounds":(150,199,0,79), "hq":(156.,40.), "intel":(165.,40.), "sabotage":((154.,18.),(158.,65.),(178.,40.)), "escape":(196.,40.), "name":"Побережье", "boss_name":"Капитан Риццо", "icon":"⚓", "income":450, "color":"#2ecc71"},
}
district_owners = {}
district_captures = {}
district_loot = {}
world_c4 = {}
next_world_c4_id = 1
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
preview_npc_robberies = {}
preview_business_claims = {}
preview_business_sabotage = {}
preview_business_wars = {}
preview_empire_relations = {}
preview_empire_hospitals = {}
preview_connections = {}
preview_apartments = {}
preview_custom_gangs = {}
preview_custom_gang_by_uid = {}
preview_custom_gang_seq = 0
preview_custom_gang_npc_seq = 0
custom_gang_player_invites = {}
gang_player_invites = {}
CUSTOM_GANG_FLAG_COLORS = {
    "#9b1f2d", "#cf303d", "#e77b28", "#e0b83e", "#287f55", "#2386a8",
    "#3154a5", "#6438a8", "#a23482", "#151922", "#ece5d5", "#7a4b2a",
}
CUSTOM_GANG_FLAG_EMBLEMS = {"crown", "skull", "diamond", "wolf", "eagle", "star"}
preview_bank_robs = {}
preview_bank_bags = {}
preview_businesses = {}
preview_business_owners = {}
preview_police_rewards = set()
PREVIEW_MAJOR = {
    "casino":{"r":46,"c":16,"name":"Казино","boss":"Сальваторе Беллини","guards":20,"total":40,"income":2400},
    "market":{"r":16,"c":16,"name":"Рынок","boss":"Риккардо Торри","guards":20,"total":34,"income":1200},
    "factory":{"r":46,"c":56,"name":"Промзона","boss":"Борис Шлак","guards":24,"total":40,"income":3000},
    "mansion":{"r":136,"c":16,"name":"Резиденция","boss":"Дон Витторио","guards":28,"total":40,"income":4200},
    "port":{"r":165,"c":38,"name":"Порт","boss":"Капитан Риццо","guards":22,"total":38,"income":2600},
}
preview_major_raids = {}
preview_major_owners = {}
preview_city_gangs = [
    {"id":"preview_purple","faction":"purple","bots":[{
        "id":f"preview_purple_{i}","x":10.0+i*.9,"y":20.0+(i%2)*.8,
        "ang":0.0,"hp":100,"max_hp":100,"kind":"aggro_grunt","weapon":"pistol",
        "faction":"purple","look":{"gender":0,"skin":1+i%3,"body":2,
        "face":i%3,"hair":i%4,"hat":4,"gang":1,"suit":"#512d73"}}
        for i in range(5)]},
    {"id":"preview_yellow","faction":"yellow","bots":[{
        "id":f"preview_yellow_{i}","x":19.0+i*.9,"y":20.0+(i%2)*.8,
        "ang":math.pi,"hp":100,"max_hp":100,"kind":"aggro_grunt","weapon":"pistol",
        "faction":"yellow","look":{"gender":0,"skin":1+i%3,"body":2,
        "face":i%3,"hair":i%4,"hat":4,"gang":2,"suit":"#d2a719"}}
        for i in range(5)]},
    # Локальное превью должно отдавать ту же опасную банду Логова, что и
    # основной сервер. Раньше здесь были только две уличные банды, поэтому
    # красная зона и лагерь рисовались пустыми.
    {"id":"lair","faction":"lair","bots":[{
        "id":f"preview_lair_{i}",
        "x":(37.0,40.0,43.0,35.5,44.5,37.0,40.0,43.0)[i],
        "y":(117.0,116.0,118.0,121.0,121.0,124.0,123.0,124.0)[i],
        "ang":(i/8)*math.tau,"hp":150,"max_hp":150,
        "kind":"aggro_elite" if i < 2 else "aggro_grunt",
        "weapon":("shotgun","rifle","pistol_heavy","smg")[i%4],
        "faction":"lair","look":{"gender":0,"skin":1+i%3,
        "body":3 if i < 2 else 2,"face":i%3,"hair":i%4,
        "hat":3 if i < 2 else 4,"gang":1,"suit":"#512d73"}}
        for i in range(8)] + [{
        "id":"preview_lair_boss","x":40.0,"y":120.0,"ang":0.0,
        "hp":360,"max_hp":360,"kind":"aggro_boss","weapon":"uzi",
        "faction":"lair","look":{"gender":0,"skin":1,"body":3,
        "face":1,"hair":0,"hat":4,"gang":1,"boss":1,"suit":"#351b48"}}]},
]
PREVIEW_NPC_BUSINESS_CONTROLS = {
    "coffee": {"biz_id":"coffee", "faction":"purple", "mafia_family":"bellini",
               "gang_name":"Фиолетовые Короли", "color":"#b887ff",
               "guard_gid":"preview_purple", "guarded":True,
               "defense_level":2,
               "captured_at":time.time()},
    "carwash": {"biz_id":"carwash", "faction":"yellow", "mafia_family":"moretti",
                "gang_name":"Жёлтые Псы", "color":"#ffe34d",
                "guard_gid":"preview_yellow", "guarded":True,
                "defense_level":1,
                "captured_at":time.time()},
}
for _gang in preview_city_gangs:
    for _bot in _gang["bots"]:
        _bot.update({"home_x":_bot["x"], "home_y":_bot["y"], "alive":True,
                     "act":"walk", "damage":8, "shot_at":0.0,
                     "threat":"", "threat_until":0.0, "respawn_at":0.0})

_preview_city_gang_tick_at = 0.0
_CITY_GANG_PHRASES = ("Эй, это наша улица!", "Кошелёк на землю!",
                      "Зря ты сюда пришёл!", "Вали из нашего района!")

def _turn_towards(current, desired, max_step):
    delta = math.atan2(math.sin(desired-current), math.cos(desired-current))
    return current + max(-max_step, min(max_step, delta))

def tick_preview_city_gangs(now, dt):
    """Live AI for local-preview street gangs and the Lair gang."""
    global _preview_city_gang_tick_at
    if now - _preview_city_gang_tick_at < 0.04:
        return []
    dt = min(.12, max(.01, now - _preview_city_gang_tick_at)) if _preview_city_gang_tick_at else dt
    _preview_city_gang_tick_at = now
    events = []
    live_players = [(str(uid), p) for uid, p in players.items() if not p.get("dead")]
    for gang in preview_city_gangs:
        for bot_index, bot in enumerate(gang["bots"]):
            if not bot.get("alive") or bot.get("hp", 0) <= 0:
                if now >= float(bot.get("respawn_at") or 0):
                    bot.update({"alive":True, "hp":bot.get("max_hp",100),
                                "x":bot["home_x"], "y":bot["home_y"], "act":"walk"})
                else:
                    continue
            target_uid, target, dist = "", None, 999.0
            for candidate_uid, candidate in live_players:
                d = math.hypot(candidate.get("x",0)-bot["x"], candidate.get("y",0)-bot["y"])
                if d < dist:
                    target_uid, target, dist = candidate_uid, candidate, d
            if target is not None and dist <= 9.0:
                dx, dy = target.get("x",0)-bot["x"], target.get("y",0)-bot["y"]
                # В упор направление из микроскопической сетевой дельты
                # нестабильно. Сохраняем прежний прицел и доворачиваем плавно.
                desired_ang = math.atan2(dy, dx) if dist > .55 else bot.get("aim_ang", bot.get("ang",0.0))
                bot["aim_ang"] = desired_ang
                bot["ang"] = _turn_towards(bot.get("ang",desired_ang), desired_ang, 3.2*dt)
                # Гистерезис не даёт прыгать walk/shoot на границе 3.2 тайла.
                chasing = bool(bot.get("chasing"))
                chasing = dist > (2.9 if chasing else 3.7)
                bot["chasing"] = chasing
                if chasing:
                    step = 1.35 * dt
                    bot["x"] += math.cos(desired_ang)*step; bot["y"] += math.sin(desired_ang)*step
                    bot["act"] = "walk"
                else:
                    bot["act"] = "shoot"
                if now >= float(bot.get("threat_until") or 0):
                    bot["threat"] = random.choice(_CITY_GANG_PHRASES)
                    bot["threat_until"] = now + random.uniform(3.5, 5.5)
                    events.append({"kind":"city_gang_threat", "bot_id":bot["id"],
                                   "faction":gang["faction"], "text":bot["threat"]})
                if dist <= 7.5 and now-float(bot.get("shot_at") or 0) >= 1.25:
                    bot["shot_at"] = now
                    damage = int(bot.get("damage") or 8)
                    target["hp"] = max(0, int(target.get("hp",100))-damage)
                    killed = target["hp"] <= 0
                    if killed:
                        target["dead"] = True; target["respawn_at"] = now+5.0
                    events.extend([
                        {"kind":"aggro_shot", "tid":gang["id"], "bot_id":bot["id"],
                         "target_uid":target_uid, "weapon":bot["weapon"],
                         "sx":round(bot["x"],2), "sy":round(bot["y"],2),
                         "tx":round(target.get("x",0),2), "ty":round(target.get("y",0),2)},
                        {"kind":"aggro_apply", "tid":gang["id"], "bot_id":bot["id"],
                         "target_uid":target_uid, "weapon":bot["weapon"],
                         "miss":False, "dmg":damage, "killed":killed}
                    ])
            else:
                # Небольшой живой патруль вокруг точки появления.
                phase = now*.42 + bot_index*.9
                tx = bot["home_x"] + math.cos(phase)*2.1
                ty = bot["home_y"] + math.sin(phase)*1.4
                dx, dy = tx-bot["x"], ty-bot["y"]
                d = math.hypot(dx,dy)
                if d > .12:
                    desired_ang=math.atan2(dy,dx)
                    bot["ang"]=_turn_towards(bot.get("ang",desired_ang),desired_ang,2.2*dt)
                    step = min(d, .72*dt)
                    bot["x"] += dx/d*step; bot["y"] += dy/d*step
                    bot["act"] = "walk"
                else:
                    bot["act"] = "idle"
                bot["threat"] = ""
    return events

def preview_major_payload():
    now=time.time()
    for oid,own in list(preview_major_owners.items()):
        if own["expires_at"]<=now: preview_major_owners.pop(oid,None)
    return {oid:{"name":cfg["name"],"boss_name":cfg["boss"],
        "owner_uid":(preview_major_owners.get(oid) or {}).get("owner_uid"),
        "owner_name":(preview_major_owners.get(oid) or {}).get("owner_name",cfg["boss"]),
        "expires_in":max(0,int((preview_major_owners.get(oid) or {}).get("expires_at",0)-now)),
        "income":cfg["income"],
        "raid":({"phase":raid["phase"],"alive":sum(1 for g in raid["guards"] if g["alive"]),
                 "participant_uids":list(raid.get("participants") or []),
                 "spawned":raid["spawned"],"total":cfg["total"],"pressure":raid["pressure"]}
                if (raid:=preview_major_raids.get(oid)) else None)}
        for oid,cfg in PREVIEW_MAJOR.items()}
PREVIEW_BUSINESSES = {
    "coffee": (3000,150,200,"☕","Кофейня «У Дона»"), "carwash": (5000,220,300,"🚗","Автомойка"),
    "barbershop": (7500,300,400,"💈","Парикмахерская"), "pizza": (12000,450,600,"🍕","Пиццерия"),
    "garage": (18000,650,900,"🔧","Гараж-СТО"), "bar": (28000,1000,1400,"🍸","Бар «Чёрная вдова»"),
    "club": (45000,1600,2200,"🎰","Подпольный клуб"), "warehouse": (70000,2400,3300,"📦","Склад"),
    "casino": (120000,4000,5500,"🎲","Казино"), "port": (200000,6500,9000,"⚓","Порт"),
}
PREVIEW_BIZ_MULT = {1:1.0,2:1.35,3:1.75,4:2.25,5:3.0}
PREVIEW_BIZ_UP = {2:.45,3:.75,4:1.15,5:1.70}
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


PREVIEW_SHOP_CONSUMABLES.update({
    "grenade":{"name":"Граната","price":50},
    "molotov":{"name":"Коктейль Молотова","price":130},
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
            "shotgun": {"name": "Дробовик", "canonical": "shotgun"},
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
    # Возврат болида в бокс не имеет права удалять припаркованную машину
    # игрока. Ждём освобождения слота вместо уничтожения чужого объекта.
    if occupied_ids:
        car["parked_at"] = time.time()
        return
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
            "state": str(car.get("state") or "idle"),
            "paint": car.get("paint"),
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
    allowed_models = {
        "sedan", "taxi", "sport", "pickup", "van", "coupe", "hatch_blue",
        "supercar", "lambo", "ferrari", "porsche", "truck", "minivan",
        "hatch", "limo", "suv_black", "suv_white", "jeep_safari",
        "jeep_sand", "muscle_blue", "muscle_org", "roadster", "classic",
        "classic2", "corvette_c3", "mustang_67", "cadillac_eldo", "delorean",
        "jaguar_e", "harley_chopper", "ducati_750",
    }
    requested_model = str(data.get("model") or "")
    model = requested_model if requested_model in allowed_models else "corvette_c3"
    requested_paint = data.get("paint") if isinstance(data.get("paint"), dict) else {}
    def valid_color(value):
        value = str(value or "").lower()
        return value if (len(value) == 7 and value[0] == "#" and
                         all(ch in "0123456789abcdef" for ch in value[1:])) else None
    primary = valid_color(requested_paint.get("primary"))
    paint = ({"primary":primary,
              "secondary":valid_color(requested_paint.get("secondary")) or primary,
              "roof":valid_color(requested_paint.get("roof"))}
             if primary else None)
    car = {
        "id": car_id,
        "model": model,
        "owner_uid": uid,
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
        "paint": paint,
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
        "paint": paint,
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
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
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
        boss_alive = any(b.get("alive") and b.get("kind") == "district_boss"
                         for b in cap.get("defenders") or [])
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
                for turn in (0., .48, -.48, .9, -.9, 1.35, -1.35):
                    ang = direct + turn
                    nx = bot["x"] + math.cos(ang)*step
                    ny = bot["y"] + math.sin(ang)*step
                    if preview_district_patrol_ok(did, nx, ny):
                        bot["x"], bot["y"], bot["ang"] = nx, ny, ang
                        break
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
            visible.append(out)
        result[f"preview_district_{did}"] = {
            "state": "patrol", "bots": visible, "covers": [],
            "cap_left": 0, "next_respawn": 0, "is_city_gang": True,
            "district_did": did,
        }
    for gang in preview_city_gangs:
        visible=[dict(bot) for bot in gang["bots"] if bot.get("hp",0)>0]
        if visible:
            is_lair = gang["id"] == "lair"
            result[gang["id"]]={"state":"alive" if is_lair else "patrol",
                "bots":visible,"covers":[],"cap_left":0,"next_respawn":0,
                "is_city_gang":not is_lair,
                "faction":gang["faction"]}
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
    for iid in ("grenade","molotov"):
        qty=int(account["consumables"].get(iid,0))
        if qty>0:
            items.append({"id":iid,"item_id":iid,"name":PREVIEW_SHOP_CONSUMABLES[iid]["name"],
                          "type":"throwable","qty":qty,"count":qty})
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
    account=preview_account(req.match_info.get("uid","1"))
    try:
        body=await req.json()
    except Exception:
        body={}
    iid=str(body.get("item_id") or "")
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
    return (r, c) if 0 <= r < 200 and 0 <= c < 200 else None


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


def preview_apartment_block_key(apt_key):
    coords = apartment_coords_from_key(apt_key)
    return f"{coords[0] // 10},{coords[1] // 10}" if coords else None


def preview_player_properties():
    rows = []
    for uid, owned in preview_apartments.items():
        gang = preview_custom_gangs.get(preview_custom_gang_by_uid.get(str(uid)))
        player = players.get(str(uid), {})
        family = str(player.get("mafia_family") or "")
        family_name = "Семья Моретти" if family == "moretti" else "Семья Беллини"
        for apt_key, info in owned.items():
            coords = apartment_coords_from_key(apt_key)
            if not coords: continue
            operation = npc_empire.BUILDING_OPERATIONS.get(str(info.get("operation_type") or ""), {})
            color, accent = (("#e7e1d4", "#aa823e") if family == "moretti" else ("#303c73", "#d2b15d"))
            if gang:
                family_name = gang["name"]; color = gang["flag"]["primary"]; accent = gang["flag"]["secondary"]
            rows.append({"owner_uid":str(uid),"owner_name":player.get("name","Игрок"),"apt_key":apt_key,
                "building_key":preview_apartment_block_key(apt_key),"r":coords[0],"c":coords[1],
                "property_kind":info.get("property_kind","hq"),"operation_type":info.get("operation_type",""),
                "operation_name":operation.get("name", ""),"operation_icon":operation.get("icon", ""),
                "income_per_minute":int(info.get("income_per_minute") or 0),"gang_name":family_name,
                "color":color,"accent":accent,"flag":gang.get("flag") if gang else None})
    return rows[:101]


async def apartment_state(req):
    return cors(web.json_response({
        "ok": True, "owned": preview_owned_apartments(req.match_info.get("uid", "1")),
        "properties": preview_player_properties(), "operations": npc_empire.BUILDING_OPERATIONS,
        "limit": None,
    }))


async def apartment_buy(req):
    uid = req.match_info.get("uid", "1")
    try:
        body = await req.json()
    except Exception:
        body = {}
    apt_key = str(body.get("apt_key") or "").strip()[:32]
    property_kind = str(body.get("property_kind") or "business").lower()
    operation_type = str(body.get("operation_type") or "").lower()
    shell_price = apartment_price_for_key(apt_key)
    if shell_price is None:
        return cors(web.json_response({"ok": False, "error": "bad apt"}, status=400))
    owned = preview_owned_apartments(uid)
    account = preview_account(uid)
    if apt_key in owned:
        return cors(web.json_response({"ok": True, "already": True, "cash": account["cash"], "owned": owned}))
    if property_kind not in ("business", "hq") or (property_kind == "business" and operation_type not in npc_empire.BUILDING_OPERATIONS):
        return cors(web.json_response({"ok": False, "error": "bad property kind"}, status=400))
    if property_kind == "hq" and (any(x.get("property_kind", "hq") == "hq" for x in owned.values()) or uid in preview_custom_gang_by_uid):
        return cors(web.json_response({"ok": False, "error": "hq limit"}, status=409))
    block_key = preview_apartment_block_key(apt_key)
    area = int(npc_empire.BUILDING_AREAS.get(block_key or "", 0))
    price = npc_empire.building_purchase_price(
        shell_price, property_kind, operation_type, area)
    occupied = {preview_apartment_block_key(key) for props in preview_apartments.values() for key in props}
    if not area or block_key in occupied:
        return cors(web.json_response({"ok": False, "error": "building occupied"}, status=409))
    if account["cash"] < price:
        return cors(web.json_response({
            "ok": False, "error": "no cash", "cash": account["cash"], "price": price,
        }))
    account["cash"] -= price
    owned[apt_key] = {
        "price": price, "bought_at": int(time.time()),
        "safe_level": 0, "weapon_rack_level": 0, "garage_level": 0,
        "property_kind": property_kind,
        "operation_type": operation_type if property_kind == "business" else "",
        "area": area,
        "income_per_minute": npc_empire.building_operation_income(operation_type, area) if property_kind == "business" else 0,
        "last_income_at": int(time.time()), "income_ready": 0,
        "cameras_level": 0, "repair_level": 0, "stolen_bags": 0,
    }
    return cors(web.json_response({
        "ok": True, "cash": account["cash"], "price": price,
        "shell_price": shell_price, "fitout_cost": price-shell_price, "owned": owned,
        "properties": preview_player_properties(),
    }))


async def apartment_collect(req):
    uid = req.match_info.get("uid", "1")
    body = await req.json()
    apt_key = str(body.get("apt_key") or "")[:32]
    info = preview_owned_apartments(uid).get(apt_key)
    if not info or info.get("property_kind") != "business":
        return cors(web.json_response({"ok": False, "error": "not business"}, status=409))
    now = int(time.time())
    elapsed = max(0, now - int(info.get("last_income_at") or now))
    minutes = min(1440, elapsed // 60)
    payout = minutes * min(200, int(info.get("income_per_minute") or 0))
    if minutes:
        info["last_income_at"] = now - elapsed % 60
        preview_account(uid)["cash"] += payout
    info["income_ready"] = 0
    return cors(web.json_response({"ok": True, "collected": payout, "minutes": minutes,
        "cash": preview_account(uid)["cash"], "owned": preview_owned_apartments(uid),
        "properties": preview_player_properties()}))


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
    removed_gang = False
    gid = preview_custom_gang_by_uid.get(str(uid))
    gang = preview_custom_gangs.get(gid)
    if gang and str(gang.get("leader_uid")) == str(uid) and gang.get("hq_apt_key") == apt_key:
        removed_gang = True
        for member_uid in list(gang.get("members") or []):
            preview_custom_gang_by_uid.pop(str(member_uid), None)
            member = players.get(str(member_uid))
            if member:
                for key in ("custom_gang_id", "custom_gang_name", "custom_gang_role",
                            "custom_gang_flag", "custom_gang_hq", "crew_id"):
                    member.pop(key, None)
        preview_custom_gangs.pop(gid, None)
    return cors(web.json_response({
        "ok": True, "refund": refund, "cash": account["cash"], "owned": owned,
        "gang": None if removed_gang else preview_custom_gang_payload(uid),
        "role_status": "civilian" if removed_gang else "",
        "headquarters": preview_custom_gang_hqs(),
    }))


def preview_custom_gang_payload(uid):
    gid = preview_custom_gang_by_uid.get(str(uid)); gang = preview_custom_gangs.get(gid)
    if not gang: return None
    coords = apartment_coords_from_key(gang["hq_apt_key"]) or (0, 0)
    members = [{"telegram_id": str(mid), "name": players.get(str(mid), {}).get("name", "Игрок"),
                "role": "leader" if str(mid) == str(gang["leader_uid"]) else "member"}
               for mid in gang["members"]]
    return {"id": gid, "name": gang["name"], "leader_uid": str(gang["leader_uid"]),
            "role": "leader" if str(uid) == str(gang["leader_uid"]) else "member",
            "hq_apt_key": gang["hq_apt_key"], "hq_r": coords[0], "hq_c": coords[1],
            "flag": gang["flag"], "members": members, "member_count": len(members),
            "max_members": 12, "treasury":int(gang.get("treasury",0)),
            "edited_at":int(gang.get("edited_at",0)),"edit_cost":1000,
            "edit_cooldown":3600,"npcs":list(gang.get("npcs") or []),
            "history":list(reversed((gang.get("history") or [])[-20:])),
            "created_at": gang["created_at"]}


def preview_custom_gang_hqs():
    out=[]
    for gid,g in preview_custom_gangs.items():
        coords=apartment_coords_from_key(g["hq_apt_key"])
        if coords: out.append({"id":gid,"name":g["name"],"leader_uid":str(g["leader_uid"]),
            "apt_key":g["hq_apt_key"],"r":coords[0],"c":coords[1],"member_count":len(g["members"]),"flag":g["flag"]})
    return out


async def custom_gang_state(req):
    uid=req.match_info.get("uid","1")
    return cors(web.json_response({"ok":True,"gang":preview_custom_gang_payload(uid),"headquarters":preview_custom_gang_hqs(),"properties":preview_player_properties()}))


async def custom_gang_create(req):
    global preview_custom_gang_seq
    uid=str(req.match_info.get("uid","1")); body=await req.json(); name=" ".join(str(body.get("name") or "").split())[:24]; apt_key=str(body.get("apt_key") or "")[:32]
    if len(name)<3 or preview_owned_apartments(uid).get(apt_key,{}).get("property_kind","hq")!="hq": return cors(web.json_response({"ok":False,"error":"bad name or hq"},status=409))
    if uid in preview_custom_gang_by_uid: return cors(web.json_response({"ok":False,"error":"already in gang"},status=409))
    if any(str(g["name"]).casefold()==name.casefold() for g in preview_custom_gangs.values()): return cors(web.json_response({"ok":False,"error":"name taken"},status=409))
    if any(g["hq_apt_key"]==apt_key for g in preview_custom_gangs.values()): return cors(web.json_response({"ok":False,"error":"hq taken"},status=409))
    preview_custom_gang_seq+=1;gid=preview_custom_gang_seq;flag=body.get("flag") if isinstance(body.get("flag"),dict) else {}
    primary=str(flag.get("primary") or "").strip().lower();secondary=str(flag.get("secondary") or "").strip().lower();emblem=str(flag.get("emblem") or "").strip().lower()
    if primary not in CUSTOM_GANG_FLAG_COLORS: primary="#9b1f2d"
    if secondary not in CUSTOM_GANG_FLAG_COLORS or secondary==primary: secondary="#e0b83e"
    if secondary==primary: secondary="#ece5d5" if primary!="#ece5d5" else "#151922"
    if emblem not in CUSTOM_GANG_FLAG_EMBLEMS: emblem="crown"
    flag={"primary":primary,"secondary":secondary,"emblem":emblem}
    now=int(time.time());preview_custom_gangs[gid]={"name":name,"leader_uid":uid,"hq_apt_key":apt_key,"flag":flag,"members":[uid],"treasury":0,"edited_at":0,"npcs":[],"history":[{"actor_uid":uid,"action":"create","details":{"name":name},"created_at":now}],"created_at":now};preview_custom_gang_by_uid[uid]=gid
    if uid in players: players[uid].update({"mafia":0,"mafia_family":"","custom_gang_id":gid,"custom_gang_name":name,"custom_gang_role":"leader","custom_gang_flag":flag,"custom_gang_hq":apt_key,"crew_id":f"cg:{gid}"})
    return cors(web.json_response({"ok":True,"gang":preview_custom_gang_payload(uid),"headquarters":preview_custom_gang_hqs(),"properties":preview_player_properties()}))


async def custom_gang_leave(req):
    uid=str(req.match_info.get("uid","1"));gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g or str(g["leader_uid"])==uid:return cors(web.json_response({"ok":False,"error":"leader must disband"},status=409))
    g["members"].remove(uid);preview_custom_gang_by_uid.pop(uid,None)
    if uid in players:
        for k in ("custom_gang_id","custom_gang_name","custom_gang_role","custom_gang_flag","custom_gang_hq","crew_id"):players[uid].pop(k,None)
    return cors(web.json_response({"ok":True,"gang":None,"headquarters":preview_custom_gang_hqs()}))


async def custom_gang_disband(req):
    uid=str(req.match_info.get("uid","1"));gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g or str(g["leader_uid"])!=uid:return cors(web.json_response({"ok":False,"error":"leader only"},status=409))
    for mid in list(g["members"]):
        preview_custom_gang_by_uid.pop(str(mid),None)
        if str(mid) in players:
            for k in ("custom_gang_id","custom_gang_name","custom_gang_role","custom_gang_flag","custom_gang_hq","crew_id"):players[str(mid)].pop(k,None)
    preview_custom_gangs.pop(gid,None)
    return cors(web.json_response({"ok":True,"gang":None,"headquarters":preview_custom_gang_hqs()}))


def _preview_gang_action(g, uid, action, details=None):
    g.setdefault("history", []).append({"actor_uid":str(uid),"action":action,
        "details":details or {},"created_at":int(time.time())})


async def custom_gang_kick(req):
    uid=str(req.match_info.get("uid","1"));body=await req.json();target=str(body.get("target_uid") or "")
    gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g or str(g["leader_uid"])!=uid:return cors(web.json_response({"ok":False,"error":"leader only"},status=409))
    if target==uid:return cors(web.json_response({"ok":False,"error":"cannot kick self"},status=409))
    if target not in g["members"]:return cors(web.json_response({"ok":False,"error":"member not found"},status=409))
    g["members"].remove(target);g["npcs"]=[n for n in g.get("npcs",[]) if str(n.get("owner_uid"))!=target];preview_custom_gang_by_uid.pop(target,None);_preview_gang_action(g,uid,"kick",{"target_uid":target})
    if target in players:
        for key in ("custom_gang_id","custom_gang_name","custom_gang_role","custom_gang_flag","custom_gang_hq","crew_id"):players[target].pop(key,None)
    return cors(web.json_response({"ok":True,"gang":preview_custom_gang_payload(uid),"headquarters":preview_custom_gang_hqs()}))


async def custom_gang_transfer(req):
    uid=str(req.match_info.get("uid","1"));body=await req.json();target=str(body.get("target_uid") or "")
    gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g or str(g["leader_uid"])!=uid:return cors(web.json_response({"ok":False,"error":"leader only"},status=409))
    if target not in g["members"]:return cors(web.json_response({"ok":False,"error":"member not found"},status=409))
    g["leader_uid"]=target;_preview_gang_action(g,uid,"transfer",{"target_uid":target})
    for mid in g["members"]:
        if str(mid) in players:players[str(mid)]["custom_gang_role"]="leader" if str(mid)==target else "member"
    return cors(web.json_response({"ok":True,"gang":preview_custom_gang_payload(uid),"headquarters":preview_custom_gang_hqs()}))


async def custom_gang_treasury(req):
    uid=str(req.match_info.get("uid","1"));body=await req.json();amount=int(body.get("amount") or 0)
    gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid);account=preview_account(uid)
    if not g:return cors(web.json_response({"ok":False,"error":"not in gang"},status=409))
    if not amount or abs(amount)>1000000:return cors(web.json_response({"ok":False,"error":"bad amount"},status=409))
    if amount>0:
        if account["cash"]<amount:return cors(web.json_response({"ok":False,"error":"not enough cash"},status=409))
        account["cash"]-=amount;g["treasury"]+=amount;action="deposit"
    else:
        take=-amount
        if str(g["leader_uid"])!=uid:return cors(web.json_response({"ok":False,"error":"leader only"},status=409))
        if g["treasury"]<take:return cors(web.json_response({"ok":False,"error":"not enough treasury"},status=409))
        g["treasury"]-=take;account["cash"]+=take;action="withdraw"
    _preview_gang_action(g,uid,action,{"amount":abs(amount)})
    return cors(web.json_response({"ok":True,"cash":account["cash"],"gang":preview_custom_gang_payload(uid)}))


async def custom_gang_edit(req):
    uid=str(req.match_info.get("uid","1"));body=await req.json();name=" ".join(str(body.get("name") or "").split())[:24]
    gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g or str(g["leader_uid"])!=uid:return cors(web.json_response({"ok":False,"error":"leader only"},status=409))
    if len(name)<3:return cors(web.json_response({"ok":False,"error":"bad name"},status=400))
    if int(time.time())<int(g.get("edited_at",0))+3600:return cors(web.json_response({"ok":False,"error":"edit cooldown"},status=409))
    if g.get("treasury",0)<1000:return cors(web.json_response({"ok":False,"error":"not enough treasury"},status=409))
    if any(oid!=gid and str(other["name"]).casefold()==name.casefold() for oid,other in preview_custom_gangs.items()):return cors(web.json_response({"ok":False,"error":"name taken"},status=409))
    raw=body.get("flag") if isinstance(body.get("flag"),dict) else {};primary=str(raw.get("primary") or "").lower();secondary=str(raw.get("secondary") or "").lower();emblem=str(raw.get("emblem") or "").lower()
    if primary not in CUSTOM_GANG_FLAG_COLORS:primary="#9b1f2d"
    if secondary not in CUSTOM_GANG_FLAG_COLORS or secondary==primary:secondary="#e0b83e"
    if secondary==primary:secondary="#ece5d5" if primary!="#ece5d5" else "#151922"
    if emblem not in CUSTOM_GANG_FLAG_EMBLEMS:emblem="crown"
    g.update({"name":name,"flag":{"primary":primary,"secondary":secondary,"emblem":emblem},"edited_at":int(time.time()),"treasury":g["treasury"]-1000});_preview_gang_action(g,uid,"edit",{"name":name})
    for mid in g["members"]:
        if str(mid) in players:players[str(mid)].update({"custom_gang_name":name,"custom_gang_flag":g["flag"]})
    return cors(web.json_response({"ok":True,"gang":preview_custom_gang_payload(uid),"headquarters":preview_custom_gang_hqs()}))


async def custom_gang_npc_sync(req):
    uid=str(req.match_info.get("uid","1"));body=await req.json();gid=preview_custom_gang_by_uid.get(uid);g=preview_custom_gangs.get(gid)
    if not g:return cors(web.json_response({"ok":False,"error":"not in gang"},status=409))
    incoming={str(n.get("id")):n for n in (body.get("npcs") or [])[:5] if isinstance(n,dict)}
    kept=[]
    for npc in g.get("npcs",[]):
        if str(npc.get("owner_uid"))!=uid:kept.append(npc);continue
        raw=incoming.get(str(npc.get("id")))
        if raw:
            npc.update({"hp":max(0,int(raw.get("hp") or 0)),"max_hp":max(1,int(raw.get("max_hp") or 80)),"level":max(1,min(25,int(raw.get("level") or 1))),"fighter_xp":max(0,int(raw.get("fighterXp") or 0)),"kills":max(0,int(raw.get("kills") or 0)),"damage_done":max(0,int(raw.get("damageDone") or 0))});kept.append(npc)
    g["npcs"]=kept
    return cors(web.json_response({"ok":True,"npcs":list(g["npcs"])}))

def preview_owned_businesses(uid):
    return preview_businesses.setdefault(str(uid), {})


def preview_business_row(biz_id, info=None):
    price, low, high, emoji, name = PREVIEW_BUSINESSES[biz_id]
    level = max(1, min(5, int((info or {}).get("level", 1)))) if info else 0
    mult = PREVIEW_BIZ_MULT.get(level, 1.0)
    pending = 0
    if info:
        elapsed = max(0, time.time() - float(info.get("last_collect") or time.time()))
        pending = int(elapsed * ((low + high) / 2) * mult / 86400)
    next_level = level + 1
    owner = preview_business_owners.get(biz_id) or {}
    return {
        "biz_id": biz_id,
        "bought_at": int((info or {}).get("bought_at") or 0),
        "id": biz_id, "name": name, "emoji": emoji, "desc": "Стабильный городской бизнес.",
        "price": price, "owned": bool(info), "status": "ok", "blocked_until": 0,
        "level": level, "income_multiplier": mult,
        "daily_min": round(low * mult), "daily_max": round(high * mult), "pending": pending,
        "upgrade_cost": round(price * PREVIEW_BIZ_UP[next_level]) if info and next_level <= 5 else 0,
        "guards": int((info or {}).get("guards") or 0),
        "property_owner_uid": str(owner.get("uid") or ""),
        "property_owner_name": str(owner.get("name") or ""),
        "property_protected_until": int(owner.get("protected_until") or 0),
        "available_for_purchase": not bool(owner),
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
    uid = req.match_info.get("uid", "1")
    try: body = await req.json()
    except Exception: body = {}
    biz_id = str(body.get("biz_id") or "")
    if biz_id not in PREVIEW_BUSINESSES:
        return cors(web.json_response({"ok": False, "error": "unknown biz"}, status=400))
    owned, account = preview_owned_businesses(uid), preview_account(uid)
    current_owner = preview_business_owners.get(biz_id)
    if current_owner:
        return cors(web.json_response({"ok": False, "error": "owned by player",
            "owner_uid":str(current_owner.get("uid") or ""),
            "owner_name":str(current_owner.get("name") or "Игрок")}))
    price = PREVIEW_BUSINESSES[biz_id][0]
    if account["cash"] < price:
        return cors(web.json_response({"ok": False, "error": "no cash", "cash": account["cash"], "price": price}))
    account["cash"] -= price
    now = time.time()
    owned[biz_id] = {"level": 1, "guards":0, "last_collect": now, "bought_at": now}
    preview_business_owners[biz_id] = {"uid":str(uid),"name":f"Игрок {uid}",
                                        "protected_until":now+300}
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
    owner = preview_business_owners.get(biz_id) or {}
    if not info or str(owner.get("uid") or "") != str(uid):
        return cors(web.json_response({"ok":False,"error":"not owned"}))
    guards=max(0,min(6,int(info.get("guards") or 0)))
    if guards>=6:
        return cors(web.json_response({"ok":False,"error":"guard limit"}))
    account=preview_account(uid)
    if int(account.get("cash") or 0)<100:
        return cors(web.json_response({"ok":False,"error":"no cash"}))
    account["cash"]-=100; guards+=1; info["guards"]=guards
    return cors(web.json_response({"ok":True,"cash":account["cash"],"guards":guards}))


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
    # Keep HTTP and WebSocket on the same preview origin. The old hard-coded
    # :8080 left a page served from :8081 with ws=NULL and hid every live flag.
    return cors(web.json_response({"base": f"{req.scheme}://{req.host}"}))


async def preview_world(_req):
    html = Path("world.html").read_text(encoding="utf-8", errors="replace")
    html = html.replace(
        "https://slavaprivet.github.io/mafiozi-battle/coop_api.json?t=",
        f"{_req.scheme}://{_req.host}/coop_api.json?t=",
    )
    return web.Response(text=html, content_type="text/html")


async def preview_three_module(_req):
    """Serve the local 3D renderer next to /preview/world.html.

    The relative module URL in world.html resolves under /preview/ during the
    integrated backend run. Without this explicit route aiohttp returned 404
    and browser QA silently exercised the 2D fallback instead of Three.js.
    """
    return web.FileResponse(Path("three_preview.js"))


async def preview_character_module(_req):
    """Serve the 3D portrait renderer used by dossiers and empire cards."""
    return web.FileResponse(Path("character_3d_preview.js"))


def _preview_empire_text(value):
    value = str(value or "")
    try:
        return value.encode("cp1251").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return value


def _preview_empire_activity(profile, now):
    activity = npc_empire._visible_activity(
        profile, {'hq_key': profile.hq_key}, [], int(now))
    activity['summary'] = _preview_empire_text(activity.get('summary'))
    return activity


async def npc_empire_state(req):
    uid = str(req.match_info.get("uid") or "1")
    now = int(time.time())
    empires = []
    for rank, profile in enumerate(npc_empire.PROFILES, 1):
        relation, pact = preview_empire_relations.get((uid, profile.leader_id), (0, "none"))
        hq_r, hq_c = npc_empire._hq_coords(profile.hq_key)
        hospital = preview_empire_hospitals.get(profile.leader_id) or {}
        hospital_until = int(hospital.get('hospital_until') or 0)
        if hospital_until <= now:
            hospital_until = 0
            preview_empire_hospitals.pop(profile.leader_id, None)
        empires.append({
            "leader_id": profile.leader_id,
            "leader_name": _preview_empire_text(profile.leader_name),
            "title": _preview_empire_text(profile.title),
            "gang_name": _preview_empire_text(profile.gang_name),
            "color": profile.color, "accent": profile.accent, "emblem": profile.emblem,
            "weapon_id": profile.weapon_id, "weapon_name": _preview_empire_text(profile.weapon_name),
            "weapon_base": profile.weapon_base, "treasury": profile.starting_cash,
            "doctrine": npc_empire.boss_doctrine(profile.leader_id),
            "members": 8 + rank % 7, "strength": 90 + rank * 3, "status": "active",
            "hq_key": profile.hq_key, "hq_r": hq_r, "hq_c": hq_c,
            "relation": relation, "relation_band": npc_empire.relation_band(relation),
            "pact": pact, "holdings": [{"kind": "hq", "holding_id": profile.hq_key,
                                           "income": 0, "defense": 80}],
            "activity": _preview_empire_activity(profile, now),
            "rank": rank, "wins": rank % 4, "losses": rank % 3, "knockouts": rank % 2,
            "comebacks": 0, "dominance_score": 25 + rank, "district_count": rank % 3,
            "peak_power": 140 + rank * 4, "war_pressure": None,
            "hospital_until": hospital_until,
            "hospital_id": str(hospital.get('hospital_id') or '') if hospital_until else '',
        })
        preview_row = {
            'treasury': profile.starting_cash, 'members': 8 + rank % 7,
            'strength': 90 + rank * 3, 'status': 'active',
            'hospital_until': hospital_until,
        }
        empires[-1]['memory'] = []
        empires[-1]['brain'] = npc_empire._boss_brain(
            profile, preview_row, empires[-1]['holdings'], [], now,
            active_wars=1 if rank <= 2 else 0,
            neutral_buildings=8, affordable_businesses=3,
        )
    # The local preview always keeps one deterministic NPC-family war alive so
    # the physical sandbox (convergence, squads, bullets and retreats) can be
    # inspected without waiting for a five-minute production economy tick.
    diplomacy = []
    if len(empires) >= 2:
        left, right = empires[0], empires[1]
        slot = now // npc_empire.VISIBLE_ACTIVITY_SECONDS
        left["activity"] = {"kind": "gang_war", "target_id": right["leader_id"],
            "target_r": right["hq_r"], "target_c": right["hq_c"], "phase": "engage",
            "stance": "assault", "force": 3,
            "created_at": slot * npc_empire.VISIBLE_ACTIVITY_SECONDS,
            "summary": f'{left["gang_name"]} идут на {right["gang_name"]}'}
        right["activity"] = {"kind": "gang_war", "target_id": left["leader_id"],
            "target_r": left["hq_r"], "target_c": left["hq_c"], "phase": "engage",
            "stance": "defend", "force": 3,
            "created_at": slot * npc_empire.VISIBLE_ACTIVITY_SECONDS,
            "summary": f'{right["gang_name"]} отвечают {left["gang_name"]}'}
        a, b = sorted((left["leader_id"], right["leader_id"]))
        diplomacy.append({"leader_a": a, "leader_b": b, "score": -100,
                          "pact": "war", "tension": 80, "last_event_at": now})
    return cors(web.json_response({"ok": True, "empires": empires,
        "leaderboard": [e["leader_id"] for e in empires], "districts": [],
        "diplomacy": diplomacy, "events": [], "player_war_events": [], "server_time": now}))


async def npc_empire_diplomacy(req):
    uid = str(req.match_info.get("uid") or "1")
    body = await req.json()
    leader_id, action = str(body.get("leader_id") or ""), str(body.get("action") or "")
    if leader_id not in npc_empire.PROFILE_BY_ID:
        return cors(web.json_response({"ok": False, "error": "unknown leader"}, status=400))
    score, pact = preview_empire_relations.get((uid, leader_id), (0, "none"))
    rules = {"respect": (0, 3), "gift": (500, 12), "apologize": (0, 8),
             "compensation": (1500, 30), "insult": (0, -10), "threaten": (0, -18),
             "street_attack": (0, -12),
             "truce": (300, 8), "alliance": (1000, 5), "break_pact": (0, -20)}
    if action == "declare_war":
        if score >= 0:
            return cors(web.json_response({"ok": False, "error": "war requires negative relation"}, status=409))
        score, pact, cost = -100, "war", 0
    elif action in rules:
        cost, delta = rules[action]
        account = preview_account(uid)
        if account["cash"] < cost:
            return cors(web.json_response({"ok": False, "error": "no cash"}, status=409))
        account["cash"] -= cost
        score = npc_empire.clamp_relation(score + delta)
        if action == "street_attack": score, pact = min(-1, score), "war"
        if action == "truce" or (action == "compensation" and pact == "war" and score >= -60): pact = "truce"
        elif action == "alliance": pact = "alliance"
        elif action == "break_pact": pact = "none"
    else:
        return cors(web.json_response({"ok": False, "error": "bad action"}, status=400))
    preview_empire_relations[(uid, leader_id)] = (score, pact)
    cash = preview_account(uid)["cash"]
    return cors(web.json_response({"ok": True, "leader_id": leader_id, "action": action,
        "relation": score, "relation_band": npc_empire.relation_band(score),
        "pact": pact, "cost": cost, "cash": cash}))


async def npc_empire_hospitalize(req):
    body = await req.json()
    leader_id = str(body.get('leader_id') or '')
    hospital_id = str(body.get('hospital_id') or 'hospital')
    if leader_id not in npc_empire.PROFILE_BY_ID:
        return cors(web.json_response({'ok': False, 'error': 'unknown_leader'}, status=400))
    if hospital_id not in ('hospital', 'hospital_east'):
        hospital_id = 'hospital'
    now = int(time.time())
    existing = preview_empire_hospitals.get(leader_id) or {}
    until = int(existing.get('hospital_until') or 0)
    if until <= now:
        until = now + 60
        preview_empire_hospitals[leader_id] = {'hospital_id': hospital_id, 'hospital_until': until}
    return cors(web.json_response({'ok': True, 'leader_id': leader_id,
        'hospital_id': hospital_id, 'hospital_until': until, 'duration': max(0, until-now)}))


def preview_online_gang(uid):
    p=players.get(str(uid)) or {};crew=str(p.get("crew_id") or "")
    if not crew:return None
    members=[]
    for member_uid,member in players.items():
        if str(member.get("crew_id") or "")!=crew:continue
        members.append({"uid":str(member_uid),"name":member.get("name","Игрок"),
                        "npc_count":len(member.get("gang") or []),
                        "leader":str(member_uid)==crew})
    return {"id":crew,"members":members,"max_players":12 if crew.startswith("cg:") else 3}


def preview_leave_online_gang(uid):
    p=players.get(str(uid)) or {};crew=str(p.get("crew_id") or "")
    if not crew or crew.startswith("cg:"):return
    p.pop("crew_id",None)
    left=[member for member in players.values() if str(member.get("crew_id") or "")==crew]
    if len(left)<2:
        for member in left:member.pop("crew_id",None)


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
    me_apt = str(p.get("apartment_key") or "")
    me_private = bool(p.get("business_private"))
    visible_others = []
    for other_uid, other in players.items():
        if str(other_uid) == str(uid):
            continue
        other_biz = str(other.get("business_interior") or "")
        other_apt = str(other.get("apartment_key") or "")
        other_private = bool(other.get("business_private"))
        if me_apt:
            if other_apt != me_apt:continue
            ox,oy=float(other.get("interior_x",0)),float(other.get("interior_y",0))
        elif me_biz:
            if me_private or other_biz != me_biz or other_private:
                continue
            ox, oy = float(other.get("interior_x", 0)), float(other.get("interior_y", 0))
        else:
            if other_biz or other_apt:
                continue
            ox, oy = float(other.get("x", 0)), float(other.get("y", 0))
            if (ox-float(p.get("x", 0)))**2 + (oy-float(p.get("y", 0)))**2 > 45**2:
                continue
        visible_others.append({
            "uid": str(other_uid), "name": other.get("name", "Demo"),
            "look": other.get("look", {}), "x": round(ox, 2), "y": round(oy, 2),
            "ang": round(float(other.get("ang", 0)), 2), "w": bool(other.get("walking")),
            "hp": int(other.get("hp", 100)), "dead": bool(other.get("dead", False)),
            "wanted": int(other.get("wanted", 0)), "gangs": 0, "mode": "pvp",
            "jail_in": max(0, int(float(other.get("jail_until", 0))-now)),
            "weapon": other.get("weapon", "pistol"),
            "swimming": bool(other.get("swimming", False)),
            "police": bool(other.get("police", False)),
            "custom_gang_id": int(other.get("custom_gang_id", 0)),
            "custom_gang_name": str(other.get("custom_gang_name", "")),
            "custom_gang_role": str(other.get("custom_gang_role", "")),
            "custom_gang_flag": dict(other.get("custom_gang_flag") or {}),
            "police_cuffed": bool(other.get("police_cuffed_by")),
            "police_stunned_in": max(0, float(other.get("police_stunned_until", 0))-now),
            "police_escort": other.get("police_escort"),
            "interior": ({"kind":"apartment","apartment_key":other_apt}
                          if other_apt else ({"kind": "business", "biz_id": other_biz,
                          "private": other_private} if other_biz else None)),
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
                "police_xp": int(preview_account(uid).get("police_xp", 0)),
                "mafia_xp": int(preview_account(uid).get("mafia_xp", 0)),
                "custom_gang": preview_custom_gang_payload(uid),
                "online_gang": preview_online_gang(uid),
                "apartment_hosts":[{"owner_uid":str(owner_uid),"owner_name":owner.get("name","Игрок"),"apartment_key":str(owner.get("apartment_key"))}
                    for owner_uid,owner in players.items() if str(owner_uid)!=str(uid) and owner.get("apartment_key")
                    and str(owner.get("crew_id") or "")==str(p.get("crew_id") or "") and p.get("crew_id")
                    and (float(owner.get("x",0))-float(p.get("x",0)))**2+(float(owner.get("y",0))-float(p.get("y",0)))**2<=3.2**2],
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
            "aggro": preview_aggro_payload(),
            "major_objects": preview_major_payload(),
            "bank_vault_raids": {
                str(rob.get("bank_id") or ""): {
                    "robber_uid": str(robber_uid),
                    "started_at": float(rob.get("started_at") or 0),
                }
                for robber_uid, rob in preview_bank_robs.items()
                if rob.get("vault_open") and rob.get("bank_id")
            },
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
            "beachgoers": PREVIEW_BEACHGOERS,
            "michael_guards": [],
            "gang_nests": [],
            "npc_business_controls": PREVIEW_NPC_BUSINESS_CONTROLS,
            "npc_business_dominance": {
                faction: sum(1 for control in PREVIEW_NPC_BUSINESS_CONTROLS.values()
                              if control.get("faction") == faction)
                for faction in ("purple", "yellow")
            },
            "npc_gang_economy": {
                "purple": {"faction":"purple", "treasury":620, "businesses":1,
                           "earned":980, "spent":360, "doctrine":"Оборона и укрепление"},
                "yellow": {"faction":"yellow", "treasury":410, "businesses":1,
                           "earned":840, "spent":430, "doctrine":"Налёты и экспансия"},
            },
            "npc_business_operations": [
                {"gid":"preview_yellow", "biz_id":"bar", "faction":"yellow",
                 "phase":"travel", "strength":5, "morale":.92,
                 "started_at":now-12},
            ],
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
    global preview_custom_gang_npc_seq
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
    if req.query.get("spawn_r") is not None and req.query.get("spawn_c") is not None:
        try:
            p0["y"] = max(0.0, min(199.0, float(req.query["spawn_r"])))
            p0["x"] = max(0.0, min(79.0, float(req.query["spawn_c"])))
        except (TypeError, ValueError):
            pass
    if req.query.get("mafia_test") == "1":
        p0["mafia"] = True
    saved_custom_gang = preview_custom_gang_payload(uid)
    if saved_custom_gang:
        p0.update({"custom_gang_id":saved_custom_gang["id"],
                   "custom_gang_name":saved_custom_gang["name"],
                   "custom_gang_role":saved_custom_gang["role"],
                   "custom_gang_flag":saved_custom_gang["flag"],
                   "custom_gang_hq":saved_custom_gang["hq_apt_key"],
                   "crew_id":f"cg:{saved_custom_gang['id']}"})
    try:
        p0["wanted"] = max(int(p0.get("wanted", 0)), min(3, int(req.query.get("wanted", 0))))
    except Exception:
        pass
    ws = web.WebSocketResponse(heartbeat=20)
    await ws.prepare(req)
    old_ws = preview_connections.get(str(uid))
    preview_connections[str(uid)] = ws
    if old_ws is not None and old_ws is not ws:
        try:
            await old_ws.close(code=4000, message=b"replaced")
        except Exception:
            pass
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
            for gang_event in tick_preview_city_gangs(now, 1/15):
                await broadcast_event(gang_event)
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
            if t == "business_rob_prepare":
                biz_id = str(d.get("biz_id") or "")
                owner = preview_business_owners.get(biz_id) or {}
                protection = max(0, int(float(owner.get("protected_until") or 0)-time.time()))
                if str(owner.get("uid") or "") == str(uid):
                    await ws.send_str(json.dumps({"t":"event","d":{"kind":"business_rob_prepare_reply",
                        "ok":False,"reason":"own","biz_id":biz_id}},ensure_ascii=False)); continue
                if protection:
                    await ws.send_str(json.dumps({"t":"event","d":{"kind":"business_rob_prepare_reply",
                        "ok":False,"reason":"property_protected","protected_s":protection,
                        "biz_id":biz_id}},ensure_ascii=False)); continue
                guards = {"coffee":1,"carwash":2,"barbershop":2,"pizza":3,
                          "garage":4,"bar":4,"club":5,"warehouse":6,
                          "casino":8,"port":10}.get(biz_id, 1)
                old_owner_business=preview_owned_businesses(owner.get("uid","")).get(biz_id,{}) if owner else {}
                guards += int(old_owner_business.get("guards") or 0)
                await ws.send_str(json.dumps({"t":"event","d":{
                    "kind":"business_rob_prepare_reply","ok":True,
                    "biz_id":biz_id,"attempt":1,"guard_bonus":0,
                    "guard_count":guards,"rob_token":f"preview-{uid}-{biz_id}"
                }}, ensure_ascii=False))
                continue
            if t == "shop_rob":
                biz_id = str(d.get("biz_id") or "coffee")
                if d.get("preview_choice"):
                    preview_account(uid)["consumables"]["c4"] = max(
                        3, int(preview_account(uid)["consumables"].get("c4", 0)))
                money = {"coffee":600,"carwash":900,"barbershop":1200,"pizza":1500,
                         "garage":1800,"bar":2200,"club":2000,"warehouse":3200,
                         "casino":5000,"port":8000}.get(biz_id,600)
                choice_token = f"preview-choice-{uid}-{biz_id}-{time.time_ns()}"
                preview_business_claims[str(uid)] = {
                    "token": choice_token, "biz_id": biz_id,
                    "money": money, "expires_at": time.time() + 90,
                }
                robber = players.get(str(uid), {})
                robber_family = str(robber.get("mafia_family") or "")
                can_capture = bool(robber.get("mafia") and
                                   robber_family in ("bellini", "moretti"))
                preview_account(uid)["cash"] += money
                await ws.send_str(json.dumps({"t":"event","d":{
                    "kind":"shop_rob_reply","ok":True,"biz_id":biz_id,
                    "money":money,"difficulty":1,"closed_s":300,
                    "mafia_family":robber_family,"family_points_gain":10 if can_capture else 0,
                    "business_choice_token":choice_token,
                    "business_choice_s":90,"can_capture":can_capture,"sabotage_s":720
                }}, ensure_ascii=False))
                continue
            if t == "business_war_choice":
                action = str(d.get("action") or "cash")
                claim = preview_business_claims.get(str(uid)) or {}
                token = str(d.get("token") or "")
                account = preview_account(uid)
                if (action not in ("cash", "sabotage", "capture") or not token
                        or token != str(claim.get("token") or "")
                        or float(claim.get("expires_at") or 0) <= time.time()):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"business_war_choice_reply","ok":False,
                        "reason":"invalid_choice","biz_id":str(claim.get("biz_id") or "")
                    }}, ensure_ascii=False))
                    continue
                player = players.get(str(uid), {})
                family = str(player.get("mafia_family") or "")
                if action == "capture" and not (
                        player.get("mafia") and family in ("bellini", "moretti")):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"business_war_choice_reply","ok":False,
                        "reason":"no_family","biz_id":str(claim.get("biz_id") or "")
                    }}, ensure_ascii=False))
                    continue
                # Reserve before side effects: duplicated packets/tabs cannot spend twice.
                preview_business_claims.pop(str(uid), None)
                if action == "sabotage" and int(account["consumables"].get("c4", 0)) <= 0:
                    preview_business_claims[str(uid)] = claim
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"business_war_choice_reply","ok":False,
                        "reason":"no_c4","biz_id":"coffee"
                    }}, ensure_ascii=False))
                    continue
                sabotage_kind = str(d.get("sabotage_kind") or "shutdown")
                sabotage_durations = {"shutdown":720, "arson":1200, "alarm":1200}
                if sabotage_kind not in sabotage_durations:
                    sabotage_kind = "shutdown"
                if action == "sabotage":
                    account["consumables"]["c4"] -= 1
                choice_biz_id = str(claim.get("biz_id") or "coffee")
                choice_money = max(1, int(claim.get("money") or 600))
                income_per_member = max(1, choice_money // 10)
                property_transfer = {}
                reply_action = action
                if action == "sabotage":
                    preview_business_sabotage[choice_biz_id] = {
                        "biz_id": choice_biz_id, "family": family,
                        "actor_uid": str(uid), "kind": sabotage_kind,
                        "until_at": time.time() + sabotage_durations[sabotage_kind],
                    }
                if action == "capture":
                    old_owner = preview_business_owners.get(choice_biz_id) or {}
                    old_uid = str(old_owner.get("uid") or "")
                    old_family = str(old_owner.get("mafia_family") or "")
                    if old_family == family:
                        preview_business_claims[str(uid)] = claim
                        await ws.send_str(json.dumps({"t":"event","d":{
                            "kind":"business_war_choice_reply","ok":False,
                            "reason":"same_family_owner","biz_id":choice_biz_id
                        }}, ensure_ascii=False))
                        continue
                    if old_family and old_family != family:
                        preparation_s = 20
                        preview_business_wars[choice_biz_id] = {
                            "biz_id": choice_biz_id, "attacker_family": family,
                            "previous_family": old_family,
                            "preparing_until": time.time() + preparation_s,
                        }
                        reply_action = "preparation"
                    else:
                        old_info = preview_owned_businesses(old_uid).pop(choice_biz_id, {}) if old_uid else {}
                        preview_owned_businesses(uid)[choice_biz_id] = {
                            "level":max(1,int(old_info.get("level") or 1)),"guards":0,
                            "last_collect":time.time(),"bought_at":time.time()}
                        preview_business_owners[choice_biz_id] = {
                            "uid":str(uid),"name":players.get(str(uid),{}).get("name",f"Игрок {uid}"),
                            "mafia_family":family,"protected_until":time.time()+120}
                        property_transfer={"old_owner_uid":old_uid,
                            "old_owner_name":str(old_owner.get("name") or ""),
                            "new_owner_uid":str(uid),"new_owner_name":preview_business_owners[choice_biz_id]["name"]}
                await ws.send_str(json.dumps({"t":"event","d":{
                    "kind":"business_war_choice_reply","ok":True,
                    "action":reply_action,"biz_id":choice_biz_id,"money":choice_money,
                    "income_per_member":income_per_member if action == "capture" else 0,
                    "family":family,
                    "c4_left":int(account["consumables"].get("c4", 0)),
                    "sabotage_kind":sabotage_kind,
                    "sabotage_s":sabotage_durations[sabotage_kind],
                    "preparation_s":20 if reply_action == "preparation" else 0,
                    "biz_name":PREVIEW_BUSINESSES.get(choice_biz_id,(0,0,0,"",choice_biz_id))[4],
                    "property_transfer":property_transfer
                }}, ensure_ascii=False))
                if action == "sabotage":
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"business_sabotaged","ok":True,"action":action,
                        "biz_id":choice_biz_id,
                        "biz_name":PREVIEW_BUSINESSES.get(choice_biz_id,(0,0,0,"",choice_biz_id))[4],
                        "actor_name":"Игрок","sabotage_kind":sabotage_kind,
                        "sabotage_label":"заведение выведено из строя",
                        "sabotage_s":sabotage_durations[sabotage_kind]
                    }}, ensure_ascii=False))
                continue
            if t == "input":
                p = players.setdefault(uid, {})
                if p.get("dead"):
                    continue
                if p.get("police_cuffed_by"):
                    continue
                was_police = bool(p.get("police"))
                was_mafia = bool(p.get("mafia"));old_family=str(p.get("mafia_family") or "")
                p["police"] = bool(d.get("police", False))
                requested_family = str(d.get("mafia_family") or "")
                wants_mafia=bool(d.get("mafia",False)) and not p["police"] and not p.get("custom_gang_id") and requested_family in ("bellini","moretti")
                if wants_mafia and time.time()<float(p.get("mafia_traitor_until",0)) and requested_family!=old_family:wants_mafia=False
                if wants_mafia and not was_mafia:
                    same=sum(1 for q in players.values() if q.get("mafia") and q.get("mafia_family")==requested_family)
                    if same>=10:wants_mafia=False
                if was_mafia and not wants_mafia:
                    preview_leave_online_gang(uid)
                    if not p["police"]:p["mafia_traitor_until"]=time.time()+300
                p["mafia"]=wants_mafia;p["mafia_family"]=requested_family if wants_mafia else ""
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
                apartment_key=str((interior or {}).get("apartment_key") or "")[:32]
                if (interior or {}).get("kind") in ("building","apartment") and apartment_key:
                    p["apartment_key"]=apartment_key;p["apartment_owner_uid"]=str((interior or {}).get("apartment_owner_uid") or uid)
                    p["interior_x"]=max(0.0,min(60.0,float((interior or {}).get("x",d.get("x",0)))))
                    p["interior_y"]=max(0.0,min(60.0,float((interior or {}).get("y",d.get("y",0)))))
                    p["ang"]=float(d.get("ang",p.get("ang",0.0)));p["walking"]=bool(d.get("w",False));p["gang"]=list(d.get("gang") or [])[:7]
                    continue
                p.pop("apartment_key",None);p.pop("apartment_owner_uid",None)
                major_id = str((interior or {}).get("object_id") or "")[:24]
                if (interior or {}).get("kind") == "major" and major_id in PREVIEW_MAJOR:
                    p["major_interior"] = major_id
                    p["interior_x"] = max(0.0, min(60.0, float(d.get("x", 0))))
                    p["interior_y"] = max(0.0, min(60.0, float(d.get("y", 0))))
                    p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                    p["walking"] = bool(d.get("w", False))
                    p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
                    continue
                p.pop("major_interior", None)
                biz_id = str((interior or {}).get("biz_id") or "")[:32]
                if (interior or {}).get("kind") == "business" and biz_id:
                    p["business_interior"] = biz_id
                    p["business_private"] = biz_id in preview_owned_businesses(uid)
                    p["interior_x"] = max(0.0, min(60.0, float(d.get("x", 0))))
                    p["interior_y"] = max(0.0, min(60.0, float(d.get("y", 0))))
                    p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                    p["walking"] = bool(d.get("w", False))
                    p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
                    continue
                p.pop("business_interior", None)
                p.pop("business_private", None)
                p.pop("interior_x", None)
                p.pop("interior_y", None)
                p["x"] = float(d.get("x", p.get("x", 40.0)))
                p["y"] = float(d.get("y", p.get("y", 40.0)))
                p["ang"] = float(d.get("ang", p.get("ang", 0.0)))
                p["walking"] = bool(d.get("w", False))
                p["weapon"] = str(d.get("weapon") or p.get("weapon") or "pistol")[:32]
                p["swimming"] = bool(d.get("swimming", False))
                p["gang"] = list(d.get("gang") or [])[:7]
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
            elif t == "apartment_guest_enter":
                owner_uid=str(d.get("owner_uid") or "");apt_key=str(d.get("apartment_key") or "")
                guest=players.get(uid) or {};owner=players.get(owner_uid) or {};reason=None
                if not owner or str(owner.get("apartment_key") or "")!=apt_key:reason="owner_left"
                elif not guest.get("crew_id") or str(guest.get("crew_id"))!=str(owner.get("crew_id") or ""):reason="not_crew"
                elif (float(guest.get("x",0))-float(owner.get("x",0)))**2+(float(guest.get("y",0))-float(owner.get("y",0)))**2>3.2**2:reason="too_far"
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"apartment_guest_reply","ok":not reason,"reason":reason,"owner_uid":owner_uid,"owner_name":owner.get("name","Игрок"),"apartment_key":apt_key,"r":float(guest.get("y",0)),"c":float(guest.get("x",0))}},ensure_ascii=False))
            elif t == "gang_player_invite":
                target_uid=str(d.get("target_uid") or "");inviter=players.get(uid) or {};target=players.get(target_uid);reason=None
                crew=str(inviter.get("crew_id") or uid);members=[q for q in players.values() if str(q.get("crew_id") or "")==crew]
                if not inviter.get("mafia"):reason="mafia_only"
                elif not target:reason="offline"
                elif not target.get("mafia") or target.get("mafia_family")!=inviter.get("mafia_family"):reason="family_conflict"
                elif target.get("crew_id"):reason="already_in_party"
                elif len(members)>=3:reason="full"
                elif (float(inviter.get("x",0))-float(target.get("x",0)))**2+(float(inviter.get("y",0))-float(target.get("y",0)))**2>3.2**2:reason="too_far"
                if reason:await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_reply","ok":False,"reason":reason}}))
                else:
                    gang_player_invites[target_uid]={"from_uid":str(uid),"expires_at":time.time()+25};target_ws=preview_connections.get(target_uid)
                    if target_ws:await target_ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_invite","from_uid":str(uid),"from_name":inviter.get("name","Игрок")}},ensure_ascii=False))
                    await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_player_reply","ok":True,"pending":True,"target_name":target.get("name","Игрок")}},ensure_ascii=False))
            elif t == "gang_player_answer":
                inv=gang_player_invites.pop(str(uid),None);inviter=players.get(str((inv or {}).get("from_uid"))) if inv else None;accept=bool(d.get("accept"));ok=False
                if inv and inviter and time.time()<=float(inv.get("expires_at",0)) and accept:
                    crew=str(inviter.get("crew_id") or inv.get("from_uid"));members=[q for q in players.values() if str(q.get("crew_id") or "")==crew]
                    target=players.get(uid) or {};ok=bool(inviter.get("mafia") and target.get("mafia") and inviter.get("mafia_family")==target.get("mafia_family") and len(members)<3)
                    if ok:inviter["crew_id"]=crew;target["crew_id"]=crew
                event=json.dumps({"t":"event","d":{"kind":"gang_player_changed","accepted":bool(ok)}},ensure_ascii=False)
                for member_uid in {str(uid),str((inv or {}).get("from_uid") or "")}:
                    target_ws=preview_connections.get(member_uid)
                    if target_ws:await target_ws.send_str(event)
            elif t in ("gang_player_leave","gang_player_kick"):
                actor=players.get(uid) or {};crew=str(actor.get("crew_id") or "");target_uid=str(d.get("target_uid") or uid) if t=="gang_player_kick" else str(uid);target=players.get(target_uid)
                if crew and not crew.startswith("cg:") and target and str(target.get("crew_id") or "")==crew:
                    target.pop("crew_id",None);left=[q for q in players.values() if str(q.get("crew_id") or "")==crew]
                    if len(left)<2:
                        for q in left:q.pop("crew_id",None)
            elif t == "custom_gang_player_invite":
                target_uid=str(d.get("target_uid") or "");inviter=players.get(uid) or {};target=players.get(target_uid);gang=preview_custom_gang_payload(uid);reason=None
                if not gang or gang.get("role")!="leader":reason="leader_only"
                elif not target:reason="offline"
                elif target_uid==str(uid):reason="self"
                elif preview_custom_gang_by_uid.get(target_uid):reason="already_in_gang"
                elif target.get("mafia") or target.get("police"):reason="faction_conflict"
                elif (float(inviter.get("x",0))-float(target.get("x",0)))**2+(float(inviter.get("y",0))-float(target.get("y",0)))**2>3.2**2:reason="too_far"
                if reason:await ws.send_str(json.dumps({"t":"event","d":{"kind":"custom_gang_player_reply","ok":False,"reason":reason}}))
                else:
                    custom_gang_player_invites[target_uid]={"from_uid":str(uid),"gang_id":gang["id"],"expires_at":time.time()+25};target_ws=preview_connections.get(target_uid)
                    if target_ws:await target_ws.send_str(json.dumps({"t":"event","d":{"kind":"custom_gang_player_invite","from_uid":str(uid),"from_name":inviter.get("name","Игрок"),"gang_name":gang["name"],"flag":gang["flag"]}},ensure_ascii=False))
                    await ws.send_str(json.dumps({"t":"event","d":{"kind":"custom_gang_player_reply","ok":True,"pending":True,"target_name":target.get("name","Игрок")}},ensure_ascii=False))
            elif t == "custom_gang_player_answer":
                inv=custom_gang_player_invites.pop(str(uid),None);accept=bool(d.get("accept"));ok=False;error="expired"
                gang=preview_custom_gangs.get(int((inv or {}).get("gang_id") or 0));target=players.get(uid)
                if inv and gang and target and time.time()<=float(inv.get("expires_at",0)):
                    if accept and not (target.get("mafia") or target.get("police") or preview_custom_gang_by_uid.get(str(uid))) and len(gang["members"])<12:
                        gang["members"].append(str(uid));preview_custom_gang_by_uid[str(uid)]=int(inv["gang_id"]);target.update({"custom_gang_id":int(inv["gang_id"]),"custom_gang_name":gang["name"],"custom_gang_role":"member","custom_gang_flag":gang["flag"],"custom_gang_hq":gang["hq_apt_key"],"crew_id":f"cg:{int(inv['gang_id'])}"});_preview_gang_action(gang,int(inv["from_uid"]),"join",{"target_uid":str(uid)});ok=True;error=""
                    elif not accept:ok=True;error=""
                    else:error="faction conflict"
                event=json.dumps({"t":"event","d":{"kind":"custom_gang_player_changed","accepted":bool(accept and ok),"ok":ok,"error":error}},ensure_ascii=False)
                for member_uid in {str(uid),str((inv or {}).get("from_uid") or "")}:
                    target_ws=preview_connections.get(member_uid)
                    if target_ws:await target_ws.send_str(event)
            elif t == "gang_hire_bot":
                target_id = str(d.get("bot_id") or "")
                found = None; found_did = None
                found_gang = None
                for city_gang in preview_city_gangs:
                    found = next((b for b in city_gang["bots"]
                                  if b.get("hp",0)>0 and str(b.get("id"))==target_id),None)
                    if found: found_gang=city_gang;break
                for did, cap in district_captures.items():
                    if found: break
                    found = next((b for b in cap.get("defenders") or []
                                  if b.get("alive") and str(b.get("id")) == target_id), None)
                    if found: found_did = did; break
                p=players.get(uid,{})
                account=preview_account(uid)
                is_boss=bool(found and (found.get("boss") or found.get("is_boss") or "boss" in str(found.get("kind") or "")))
                hire_cost=800 if is_boss else 500
                role_ok=bool(p.get("mafia") or p.get("custom_gang_id"))
                close_enough=bool(found and math.hypot(float(p.get("x",0))-found["x"],float(p.get("y",0))-found["y"])<=4.4)
                jailed=float(p.get("jail_until") or 0)>time.time()
                ok=bool(found and found_gang and not jailed and not p.get("police") and role_ok and close_enough)
                npc=None;reason=None
                if ok and int(account.get("cash",0))<hire_cost:ok=False;reason="cash"
                if ok and p.get("custom_gang_id"):
                    custom=preview_custom_gangs.get(int(p.get("custom_gang_id") or 0))
                    owned=[n for n in (custom or {}).get("npcs",[]) if str(n.get("owner_uid"))==str(uid)]
                    if not custom or len(owned)>=5:
                        ok=False;reason="custom_gang_npc_full"
                    else:
                        preview_custom_gang_npc_seq+=1;max_hp=int(found.get("max_hp") or found.get("hp") or 100)
                        npc={"id":str(preview_custom_gang_npc_seq),"owner_uid":str(uid),
                             "name":random.choice(("Тони","Вито","Марко","Рико","Бруно","Энцо")),
                             "look":dict(found.get("look") or {}),"weapon":found.get("weapon") or "pistol",
                             "faction":found_gang.get("faction"),"hp":max_hp,"max_hp":max_hp,
                             "level":max(1,int(found.get("level") or 1)),"fighter_xp":0,"kills":0,
                             "damage_done":0,"is_boss":is_boss,"source_bot_id":target_id,
                             "updated_at":int(time.time())};custom.setdefault("npcs",[]).append(npc);_preview_gang_action(custom,uid,"hire_npc",{"npc_id":npc["id"],"name":npc["name"]})
                if ok: found["hp"]=0;account["cash"]-=hire_cost
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"gang_hire_reply",
                    "ok":ok,"bot_id":target_id,"is_boss":is_boss,
                    "look":dict(found.get("look") or {}) if ok else None,
                    "weapon":found.get("weapon") if ok else None,
                    "hp":int(found.get("hp") or 100) if ok else None,
                    "max_hp":int(found.get("max_hp") or found.get("hp") or 100) if ok else None,
                    "level":max(1,int(found.get("level") or 1)) if ok else None,
                    "faction":found_gang.get("faction") if ok else None,
                    "x":found.get("x") if ok else None,"y":found.get("y") if ok else None,
                    "npc":npc,"cost":hire_cost,"cash":account["cash"],"reason":None if ok else (reason or ("jailed" if jailed else "district_defender" if found_did else "police_service" if p.get("police") else "not_mafia" if found and not role_ok else "too_far" if found and not close_enough else "gone"))}}, ensure_ascii=False))
            elif t == "major_assault_start":
                oid=str(d.get("object_id") or "")[:24];cfg=PREVIEW_MAJOR.get(oid);p=players.get(uid,{})
                own=preview_major_owners.get(oid);raid=preview_major_raids.get(oid)
                if not cfg: reply={"kind":"major_assault_reply","ok":False,"reason":"bad_object"}
                elif own and own["expires_at"]>time.time(): reply={"kind":"major_assault_reply","ok":False,"reason":"protected","object_id":oid,"owner_name":own["owner_name"],"expires_in":int(own["expires_at"]-time.time())}
                elif raid:
                    raid.setdefault("participants",set()).add(uid)
                    reply={"kind":"major_assault_reply","ok":True,"resume":True,"joined":True,
                           "object_id":oid,"phase":raid.get("phase"),"guards":[dict(g) for g in raid.get("guards",[]) if g.get("alive")],
                           "total":cfg["total"],"boss_name":cfg["boss"],"participants":list(raid["participants"]),"safes":raid.get("safes",[])}
                else:
                    guards=[{"id":f"preview_major_{oid}_{i}","hp":140 if i<4 else 100,"max_hp":140 if i<4 else 100,"alive":True,"weapon":"pistol","wave":1,"slot":i} for i in range(cfg["guards"])]
                    safes=[{"id":f"{oid}_safe_{i+1}","opened":False,"value":250*(i+1)} for i in range(3 if oid!="mansion" else 4)]
                    raid={"object_id":oid,"by_uid":uid,"by_name":p.get("name","Demo"),"participants":{uid},"phase":"guards","guards":guards,"spawned":len(guards),"pressure":0,"safes":safes}
                    preview_major_raids[oid]=raid
                    reply={"kind":"major_assault_reply","ok":True,"object_id":oid,"phase":"guards","guards":guards,"total":cfg["total"],"boss_name":cfg["boss"],"participants":[uid],"safes":safes}
                await broadcast_event(reply)
            elif t == "major_guard_hit":
                oid=str(d.get("object_id") or "")[:24];gid=str(d.get("guard_id") or "");raid=preview_major_raids.get(oid);cfg=PREVIEW_MAJOR.get(oid)
                g=next((x for x in (raid or {}).get("guards",[]) if x["id"]==gid and x["alive"]),None)
                if g:
                    g["hp"]=max(0,g["hp"]-34);new_guard=None
                    if g["hp"]<=0:
                        g["alive"]=False
                        if raid["spawned"]<cfg["total"]:
                            i=raid["spawned"];new_guard={"id":f"preview_major_{oid}_{i}","hp":110,"max_hp":110,"alive":True,"weapon":"pistol","wave":2+i//10,"slot":i}
                            raid["guards"].append(new_guard);raid["spawned"]+=1
                        elif not any(x["alive"] for x in raid["guards"]):raid["phase"]="boss"
                    await broadcast_event({"kind":"major_guard_hit","ok":True,"object_id":oid,"guard_id":gid,"hp":g["hp"],"alive":g["alive"],"new_guard":new_guard,"spawned":raid["spawned"],"phase":raid["phase"]})
            elif t == "major_boss_pressure":
                oid=str(d.get("object_id") or "")[:24];raid=preview_major_raids.get(oid);cfg=PREVIEW_MAJOR.get(oid)
                if raid and raid["phase"]=="boss":
                    raid["pressure"]=min(100,raid["pressure"]+20);captured=raid["pressure"]>=100
                    reply={"kind":"major_boss_pressure","ok":True,"object_id":oid,"pressure":raid["pressure"],"phrase":"Объект ваш!" if captured else "Я ничего вам не отдам!","captured":captured}
                    if captured:
                        preview_major_owners[oid]={"owner_uid":uid,"owner_name":players.get(uid,{}).get("name","Demo"),"expires_at":time.time()+3600}
                        preview_major_raids.pop(oid,None);reply.update({"owner_name":preview_major_owners[oid]["owner_name"],"income":cfg["income"],"expires_in":3600})
                    await broadcast_event(reply)
            elif t == "major_safe_open":
                oid=str(d.get("object_id") or "")[:24];sid=str(d.get("safe_id") or "")[:64];raid=preview_major_raids.get(oid)
                safe=next((s for s in (raid or {}).get("safes",[]) if s["id"]==sid),None)
                if raid and raid["phase"]=="boss" and safe and not safe["opened"]:
                    safe["opened"]=True
                    await broadcast_event({"kind":"major_safe_open","ok":True,"object_id":oid,"safe_id":sid,"value":safe["value"],"awards":[{"uid":uid,"amount":safe["value"]}]})
            elif t == "aggro_shoot":
                target_id = str(d.get("target") or "")
                found = None
                found_did = None
                found_city_gang = None
                for city_gang in preview_city_gangs:
                    found = next((bot for bot in city_gang["bots"]
                                  if bot.get("alive") and str(bot.get("id")) == target_id), None)
                    if found:
                        found_city_gang = city_gang
                        break
                for did, cap in district_captures.items():
                    if found:
                        break
                    for bot in cap.get("defenders") or []:
                        if bot.get("alive") and str(bot.get("id")) == target_id:
                            found, found_did = bot, did
                            break
                    if found:
                        break
                if found:
                    cap = district_captures.get(found_did) if found_did else None
                    # Только подтверждённое попадание разворачивает всю охрану
                    # на конкретного стрелка. На других игроков не переключаемся.
                    if cap:
                        cap["hostile_uid"] = str(uid)
                        cap["hostile_until"] = time.time() + 30.0
                    damage = 42
                    found["hp"] = max(0, int(found["hp"]) - damage)
                    killed = found["hp"] <= 0
                    if killed:
                        found["alive"] = False
                        found["respawn_at"] = time.time() + 14.0
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
                    if killed and is_boss and cap:
                        preview_drop_district_dossier(found_did, cap, found, time.time())
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
                if (target and shooter.get("police") and not target.get("police") and
                        int(target.get("wanted", 0)) > 0 and not shooter.get("dead") and
                        not target.get("dead") and not shooter.get("business_interior") and
                        not target.get("business_interior") and
                        (float(shooter.get("x",0))-float(target.get("x",0)))**2 +
                        (float(shooter.get("y",0))-float(target.get("y",0)))**2 <= 8.5**2):
                    weapon = str(d.get("weapon") or "pistol")
                    damage = {"shotgun":55,"rifle":42,"sniper":100,"pistol":28}.get(weapon,32)
                    target["hp"] = max(0, int(target.get("hp",100))-damage)
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
            elif t == "npc_cash_action":
                account = preview_account(uid)
                action = str(d.get("action") or "")[:32]
                amount = {"give25": 25, "give10": 10}.get(action, 0)
                if not amount:
                    reply = {"kind":"npc_cash_action_reply","ok":False,"reason":"invalid","action":action,"amount":0}
                elif account["cash"] < amount:
                    reply = {"kind":"npc_cash_action_reply","ok":False,"reason":"cash","action":action,"amount":amount,"cash":account["cash"]}
                else:
                    account["cash"] -= amount
                    reply = {"kind":"npc_cash_action_reply","ok":True,"action":action,"amount":amount,"cash":account["cash"]}
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
            elif t == "npc_robbery_state":
                robbery_state = preview_npc_robberies.setdefault(str(uid), {})
                outstanding = robbery_state.setdefault("outstanding", {})
                meta = robbery_state.setdefault("meta", {})
                active = [dict(meta[rid]) for rid in outstanding if rid in meta]
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"npc_robbery_state_reply","ok":True,"active":active}}, ensure_ascii=False))
            elif t == "npc_robbery":
                account = preview_account(uid); p = players.setdefault(uid, {})
                robbery_state = preview_npc_robberies.setdefault(str(uid), {})
                npc_id = str(d.get("npc_id") or "")[:96]
                robbery_id = str(d.get("robbery_id") or "")[:160]
                now_t = time.time(); cooldowns = robbery_state.setdefault("cooldowns", {})
                until = float(cooldowns.get(npc_id) or 0)
                if not npc_id or not robbery_id:
                    reply = {"kind":"npc_robbery_reply","ok":False,"reason":"invalid","robbery_id":robbery_id}
                elif until > now_t:
                    reply = {"kind":"npc_robbery_reply","ok":False,"reason":"cooldown","robbery_id":robbery_id,"cooldown_until":int(until)}
                else:
                    amount = random.randint(1, 10)
                    interrogation_arrest = random.random() < 0.8
                    until = now_t + 3600; cooldowns[npc_id] = until
                    robbery_state.setdefault("outstanding", {})[robbery_id] = amount
                    robbery_state.setdefault("meta", {})[robbery_id] = {"npc_id":npc_id,"robbery_id":robbery_id,"amount":amount,"cooldown_until":int(until),"created_at":int(now_t),"interrogation_arrest":interrogation_arrest}
                    account["cash"] += amount; account["wanted"] = max(1, int(account.get("wanted") or 0)); p["wanted"] = account["wanted"]
                    reply = {"kind":"npc_robbery_reply","ok":True,"robbery_id":robbery_id,"amount":amount,"cash":account["cash"],"cooldown_until":int(until),"interrogation_arrest":interrogation_arrest}
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
            elif t == "npc_robbery_confiscate":
                account = preview_account(uid); robbery_id = str(d.get("robbery_id") or "")[:160]
                robbery_state = preview_npc_robberies.setdefault(str(uid), {})
                stored = robbery_state.setdefault("outstanding", {}).pop(robbery_id, None)
                robbery_state.setdefault("meta", {}).pop(robbery_id, None)
                if stored is None: reply = {"kind":"npc_robbery_confiscate_reply","ok":False,"reason":"missing","robbery_id":robbery_id}
                else:
                    amount = max(0, min(10, int(stored))); account["cash"] = max(0, account["cash"] - amount)
                    reply = {"kind":"npc_robbery_confiscate_reply","ok":True,"robbery_id":robbery_id,"amount":amount,"cash":account["cash"]}
                await ws.send_str(json.dumps({"t":"event","d":reply}, ensure_ascii=False))
            elif t == "npc_robbery_resolve":
                account = preview_account(uid); p = players.setdefault(uid, {})
                robbery_id = str(d.get("robbery_id") or "")
                robbery_state = preview_npc_robberies.setdefault(str(uid), {})
                meta = robbery_state.setdefault("meta", {}).get(robbery_id)
                released = bool(meta) and not bool(meta.get("interrogation_arrest"))
                if released:
                    robbery_state.setdefault("outstanding", {}).pop(robbery_id, None)
                    robbery_state.setdefault("meta", {}).pop(robbery_id, None)
                    account["wanted"] = max(0, int(account.get("wanted") or 0) - 1); p["wanted"] = account["wanted"]
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"npc_robbery_resolve_reply","ok":released,"robbery_id":robbery_id,"wanted":account["wanted"]}}, ensure_ascii=False))
            elif t == "citycop_arrest":
                p = players.setdefault(uid, {}); account = preview_account(uid)
                booking = bool(d.get("booking")); voluntary = bool(d.get("voluntary")); robbery = bool(d.get("robbery"))
                wanted = max(float(p.get("wanted") or 0), float(account.get("wanted") or 0))
                ok = (booking and float(p.get("jail_until") or 0) > time.time()) or wanted >= (1 if (voluntary or robbery) else 2)
                if ok:
                    p["wanted"] = 0; account["wanted"] = 0; p["jail_until"] = time.time() + 60
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"citycop_arrest_reply","ok":ok,"reason":"" if ok else "not_wanted","booking":booking,"jail_s":60}}, ensure_ascii=False))
            elif t == "brigadir_take":
                p=players.setdefault(uid,{})
                reply={"kind":"brigadir_take_reply","ok":not p.get("dead"),
                       "payout":700,"stealth_mul":1.5,"left":3}
                await ws.send_str(json.dumps({"t":"event","d":reply},ensure_ascii=False))
            elif t == "brigadir_kill":
                p=players.setdefault(uid,{})
                stealth=bool(d.get("stealth"));reward=int(700*(1.5 if stealth else 1))
                p["brigadir_pending"]={"reward":reward,"stealth":stealth}
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"brigadir_kill_reply",
                    "ok":True,"reward":reward,"stealth":stealth,"claim_at_brigadir":True}},ensure_ascii=False))
            elif t == "brigadir_claim":
                p=players.setdefault(uid,{});pending=p.pop("brigadir_pending",None)
                await ws.send_str(json.dumps({"t":"event","d":{"kind":"brigadir_claim_reply",
                    "ok":bool(pending),"reward":int((pending or {}).get("reward") or 0),
                    "stealth":bool((pending or {}).get("stealth")),"left":2,
                    "reason":None if pending else "no_pending"}},ensure_ascii=False))
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
                        "paint": reply.get("paint"),
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
                    release_car(car)
                    await ws.send_str(json.dumps({
                        "t": "event",
                        "d": {"kind": "gta_exit_reply", "ok": True,
                              "delivered": False, "car_id": car["id"],
                              "model":car.get("model"),"owner_uid":car.get("owner_uid"),
                              "x":car.get("x"),"y":car.get("y"),"ang":car.get("ang",0),
                              "hp":car.get("hp",220),"max_hp":car.get("max_hp",220),
                              "paint":car.get("paint"),
                              "civilian":bool(car.get("civilian",True)),
                              "police_patrol":bool(car.get("police_patrol")),
                              "police_stolen":bool(car.get("police_stolen"))},
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
                if p.get("police"):
                    await ws.send_str(json.dumps({"t":"event","d":{
                        "kind":"bank_rob_start_reply", "ok":False,
                        "reason":"police_on_duty"}}, ensure_ascii=False))
                elif bank_id in PREVIEW_BANK_REWARD:
                    preview_bank_robs[str(uid)] = {
                        "bank_id": bank_id, "carried": 0, "bags_loaded": 0,
                        "started_at": time.time(), "vault_open": False,
                    }
            elif t == "bank_rob_announce":
                rob = preview_bank_robs.get(str(uid))
                if rob and rob.get("bank_id") == str(d.get("bank_id") or ""):
                    rob["vault_open"] = True
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
                    preview_bank_bags[bag_id] = {
                        "id":bag_id, "bank_id":bank_id, "value":value,
                        "x":float(p.get("x",0)), "y":float(p.get("y",0)),
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
        if preview_connections.get(str(uid)) is ws:
            preview_connections.pop(str(uid), None)
            leaving = players.get(uid) or {}
            preview_leave_online_gang(uid)
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
            players.pop(uid, None)
    return ws


app = web.Application()
app.router.add_route("OPTIONS", "/{tail:.*}", options)
app.router.add_get("/preview/world.html", preview_world)
app.router.add_get("/preview/three_preview.js", preview_three_module)
app.router.add_get("/preview/character_3d_preview.js", preview_character_module)
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
app.router.add_post("/apartment/{uid}/collect", apartment_collect)
app.router.add_post("/apartment/{uid}/upgrade", apartment_upgrade)
app.router.add_post("/apartment/{uid}/sell", apartment_sell)
app.router.add_get("/custom-gang/{uid}/state", custom_gang_state)
app.router.add_post("/custom-gang/{uid}/create", custom_gang_create)
app.router.add_post("/custom-gang/{uid}/leave", custom_gang_leave)
app.router.add_post("/custom-gang/{uid}/disband", custom_gang_disband)
app.router.add_post("/custom-gang/{uid}/kick", custom_gang_kick)
app.router.add_post("/custom-gang/{uid}/transfer", custom_gang_transfer)
app.router.add_post("/custom-gang/{uid}/treasury", custom_gang_treasury)
app.router.add_post("/custom-gang/{uid}/edit", custom_gang_edit)
app.router.add_post("/custom-gang/{uid}/npcs/sync", custom_gang_npc_sync)
app.router.add_get("/npc-empires/{uid}/state", npc_empire_state)
app.router.add_post("/npc-empires/{uid}/diplomacy", npc_empire_diplomacy)
app.router.add_post("/npc-empires/{uid}/hospitalize", npc_empire_hospitalize)
app.router.add_get("/biz/{uid}/list", business_list)
app.router.add_post("/biz/{uid}/buy", business_buy)
app.router.add_post("/biz/{uid}/upgrade", business_upgrade)
app.router.add_post("/biz/{uid}/guards/hire", business_guard_hire)
app.router.add_post("/biz/{uid}/collect", business_collect)
app.router.add_post("/biz/{uid}/said/hire", said_hire)
app.router.add_post("/biz/{uid}/said/fire", said_fire)
app.router.add_get("/skill/{uid}/state", skill_state)
app.router.add_post("/skill/{uid}/upgrade", skill_upgrade)


if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=int(os.getenv("MAFIOZI_PREVIEW_PORT", "8081")))
