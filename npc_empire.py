"""Server-authoritative autonomous crime empires for the shared city.

The simulation is deliberately event/tick based.  Nineteen leaders may own
headquarters and holdings without adding work to the rendering or movement
loops.  Every mutating operation uses BEGIN IMMEDIATE so treasury, relations,
ownership and assault rewards cannot be applied twice.
"""

from __future__ import annotations

import hashlib
import json
import random
import secrets
import time
from dataclasses import dataclass, replace

import aiosqlite


TICK_SECONDS = 300
MAX_OFFLINE_TICKS = 72
ASSAULT_SECONDS = 20 * 60
COMEBACK_MIN_SECONDS = 30 * 60
COMEBACK_MAX_SECONDS = 90 * 60
RELATION_MIN = -100
RELATION_MAX = 100
NPC_OWNER_BASE = -900_000
PLAYER_WAR_FIRST_STRIKE_SECONDS = 5 * 60
PLAYER_WAR_BUSINESS_BLOCK_SECONDS = 10 * 60
PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS = 10 * 60
VISIBLE_ACTIVITY_SECONDS = 75
NPC_EMPIRE_MAX_FIGHTERS = 20
RECRUITMENT_SECONDS = 0


@dataclass(frozen=True)
class EmpireProfile:
    leader_id: str
    leader_name: str
    title: str
    gang_name: str
    hq_key: str
    color: str
    accent: str
    emblem: str
    weapon_id: str
    weapon_name: str
    weapon_base: str
    aggression: int
    commerce: int
    diplomacy: int
    loyalty: int
    starting_cash: int


PROFILES = (
    EmpireProfile('leila','Лейла','Врач','Красный полумесяц','2,1','#f1f4f7','#d73b58','cross','leila_mercy','Последний аргумент','pistol_heavy',28,72,78,84,8800),
    EmpireProfile('rustam','Рустам','Механик','Железные волки','8,6','#264d58','#e58b32','gear','rustam_wrench','Сварщик','shotgun',52,76,42,82,7600),
    EmpireProfile('marco','Марко','Водитель','Ночные колёса','5,7','#6f1d2b','#f0c85b','wheel','marco_road','Дорожный Томми','tommy_gun',58,62,48,70,6200),
    EmpireProfile('vera','Вера','Адвокат','Белые перчатки','2,5','#30234f','#b58cff','scales','vera_verdict','Вердикт','pistol_gold',24,88,92,64,11200),
    EmpireProfile('arsen','Арсен','Оружейник','Чёрная кузня','11,2','#4a3d2b','#d18b42','anvil','arsen_forge','Кузнечный гром','rifle',74,66,32,88,8200),
    EmpireProfile('damir','Дамир','Вербовщик','Зелёный круг','13,5','#174b3e','#79d6a8','ring','damir_oath','Клятва','smg',46,58,82,94,7000),
    EmpireProfile('marat','Марат','Начальник охраны','Стальной щит','6,2','#263448','#65a8dc','shield','marat_wall','Стена','shotgun',62,48,38,96,9200),
    EmpireProfile('zara','Зара','Управляющая','Золотая книга','10,6','#8a3d17','#f1b05e','ledger','zara_dividend','Дивиденд','pistol_gold',30,98,76,72,14800),
    EmpireProfile('niko','Нико','Разведчик','Тихие глаза','4,7','#35533a','#9ad06f','eye','niko_whisper','Шёпот','sniper',42,54,68,60,5700),
    EmpireProfile('alisa','Алиса','Информатор','Синяя сеть','12,7','#1d4d70','#62c7ef','web','alisa_signal','Сигнал','smg',38,70,88,56,6800),
    EmpireProfile('boris','Борис','Эвакуаторщик','Жёлтые крюки','8,7','#c06b16','#ffe06d','hook','boris_tow','Буксир','shotgun',68,64,28,78,6500),
    EmpireProfile('inga','Инга','Риелтор','Розовый ключ','1,7','#b24b72','#ffd0df','key','inga_deed','Документ','pistol_heavy',22,94,84,58,12500),
    EmpireProfile('timur','Тимур','Курьер','Синие стрелы','9,3','#3d6eaa','#ffcf4d','arrow','timur_express','Экспресс','smg',55,68,50,74,6100),
    EmpireProfile('emil','Эмиль','Тренер','Красный ринг','6,7','#8f2525','#f5e7d0','fist','emil_champion','Чемпион','pistol_heavy',82,38,30,92,7200),
    EmpireProfile('roman','Роман','Бронник','Серые пластины','10,4','#535c66','#bcd0dc','armor','roman_plate','Пробойник','rifle',64,60,36,90,8300),
    EmpireProfile('sofia','София','Журналист','Жёлтая пресса','3,3','#d7c33e','#fff4a1','press','sofia_headline','Заголовок','pistol',18,74,96,44,5200),
    EmpireProfile('viktor','Виктор «Тень»','Налётчик','Бесшумные','12,1','#211f27','#9d76c9','shadow','viktor_night','Тень','sniper',96,34,16,68,9600),
    EmpireProfile('yana','Яна','Диспетчер','Бирюзовая линия','7,5','#17666a','#6de0d7','radio','yana_frequency','Частота','smg',36,82,86,76,8900),
    EmpireProfile('musa','Муса','Снабженец','Золотой караван','13,6','#6b5125','#e6c56a','crate','musa_caravan','Караван','rifle',48,92,64,86,13600),
)

MAFIA_BOSS_NAMES = {
    'leila':'Лейла Беллини', 'rustam':'Билли Капоне', 'marco':'Марко Моретти',
    'vera':'Вера Фальконе', 'arsen':'Энцо Барзини', 'damir':'Дамиано Коста',
    'marat':'Марчелло Рицци', 'zara':'Джина Беллуччи', 'niko':'Нико Скарлетти',
    'alisa':'Алисия Романо', 'boris':'Бруно Манчини', 'inga':'Ингрид Вентури',
    'timur':'Тони Лучано', 'emil':'Эмилио Гамбино', 'roman':'Роман Витале',
    'sofia':'София Кастеллано', 'viktor':'Виктор Ломбарди',
    'yana':'Джанна Марино', 'musa':'Муса Карбоне',
}
PROFILES = tuple(replace(profile, leader_name=MAFIA_BOSS_NAMES[profile.leader_id])
                 for profile in PROFILES)

PROFILE_BY_ID = {p.leader_id: p for p in PROFILES}

# Boss Brain v2.  Statistics still describe what a family is good at; a
# doctrine describes how its leader turns the same city state into a plan.
# Keeping this declarative makes all nineteen personalities testable without
# cloning the economy tick or introducing per-boss background loops.
BOSS_DOCTRINES = {
    'leila':  {'id':'triage','label':'Полевая медицина','signature':'triage','orders':('regroup','hold','withdraw'),'retreat_hp':.34,'preferred_range':7.0,'focus':'wounded','strategy_bias':{'recover':24,'recruit':10,'fortify':12}},
    'rustam': {'id':'ambush','label':'Засада в тесном месте','signature':'trap','orders':('hold','flank','press'),'retreat_hp':.16,'preferred_range':1.3,'focus':'nearest','strategy_bias':{'expand':12,'fortify':8,'retaliate':8}},
    'marco':  {'id':'mobile','label':'Мобильный обход','signature':'drive_by','orders':('flank','press','withdraw'),'retreat_hp':.22,'preferred_range':6.5,'focus':'isolated','strategy_bias':{'expand':18,'retaliate':9}},
    'vera':   {'id':'negotiator','label':'Контролируемая эскалация','signature':'false_target','orders':('hold','regroup','focus'),'retreat_hp':.30,'preferred_range':8.0,'focus':'leader','strategy_bias':{'consolidate':18,'acquire':10,'fortify':8}},
    'arsen':  {'id':'denial','label':'Огневое перекрытие','signature':'fire_lane','orders':('hold','focus','press'),'retreat_hp':.18,'preferred_range':9.0,'focus':'armored','strategy_bias':{'retaliate':16,'fortify':10}},
    'damir':  {'id':'rally','label':'Круг верности','signature':'rally','orders':('regroup','press','focus'),'retreat_hp':.24,'preferred_range':5.5,'focus':'leader','strategy_bias':{'recruit':24,'retaliate':8}},
    'marat':  {'id':'fortress','label':'Стальная линия','signature':'shield_wall','orders':('hold','regroup','focus'),'retreat_hp':.28,'preferred_range':4.5,'focus':'nearest_boss','strategy_bias':{'fortify':28,'consolidate':8}},
    'zara':   {'id':'investor','label':'Война по расчёту','signature':'paid_backup','orders':('hold','focus','withdraw'),'retreat_hp':.32,'preferred_range':7.5,'focus':'valuable','strategy_bias':{'acquire':30,'consolidate':14,'retaliate':-10}},
    'niko':   {'id':'recon','label':'Дальняя разведка','signature':'mark_target','orders':('focus','flank','withdraw'),'retreat_hp':.26,'preferred_range':12.5,'focus':'exposed','strategy_bias':{'retaliate':12,'consolidate':8}},
    'alisa':  {'id':'disrupt','label':'Срыв управления','signature':'jam','orders':('flank','focus','regroup'),'retreat_hp':.27,'preferred_range':6.5,'focus':'shooter','strategy_bias':{'consolidate':10,'acquire':10,'retaliate':8}},
    'boris':  {'id':'controller','label':'Силовое вытягивание','signature':'hook_pull','orders':('focus','press','hold'),'retreat_hp':.19,'preferred_range':6.0,'focus':'isolated','strategy_bias':{'retaliate':18,'fortify':6}},
    'inga':   {'id':'landlord','label':'Подготовленная территория','signature':'bleed_trap','orders':('hold','flank','regroup'),'retreat_hp':.31,'preferred_range':7.0,'focus':'intruder','strategy_bias':{'acquire':24,'fortify':16}},
    'timur':  {'id':'logistics','label':'Мобильное снабжение','signature':'resupply','orders':('flank','regroup','press'),'retreat_hp':.23,'preferred_range':8.5,'focus':'isolated','strategy_bias':{'recruit':14,'expand':14}},
    'emil':   {'id':'duelist','label':'Ближняя дуэль','signature':'combo','orders':('press','focus','hold'),'retreat_hp':.12,'preferred_range':1.1,'focus':'shooter','strategy_bias':{'retaliate':26,'recruit':8}},
    'roman':  {'id':'armored','label':'Бронированное прикрытие','signature':'intercept','orders':('hold','regroup','press'),'retreat_hp':.25,'preferred_range':8.0,'focus':'armored','strategy_bias':{'fortify':22,'retaliate':10}},
    'sofia':  {'id':'exposure','label':'Информационное давление','signature':'expose','orders':('focus','withdraw','flank'),'retreat_hp':.36,'preferred_range':6.5,'focus':'leader','strategy_bias':{'consolidate':20,'acquire':10,'retaliate':-8}},
    'viktor': {'id':'predator','label':'Охота из тени','signature':'vanish','orders':('flank','focus','withdraw'),'retreat_hp':.20,'preferred_range':13.5,'focus':'isolated','strategy_bias':{'retaliate':30,'expand':12}},
    'yana':   {'id':'coordinator','label':'Синхронный приказ','signature':'sync_volley','orders':('regroup','focus','flank'),'retreat_hp':.27,'preferred_range':6.5,'focus':'threat','strategy_bias':{'fortify':14,'recruit':12,'consolidate':8}},
    'musa':   {'id':'attrition','label':'Война на истощение','signature':'supply_cache','orders':('hold','regroup','press'),'retreat_hp':.29,'preferred_range':8.5,'focus':'wounded','strategy_bias':{'consolidate':18,'fortify':16,'acquire':12}},
}


def boss_doctrine(leader_id: str) -> dict:
    """Return a copy-safe doctrine for API clients and deterministic tests."""
    doctrine = BOSS_DOCTRINES[str(leader_id)]
    return {**doctrine, 'orders': list(doctrine['orders']),
            'strategy_bias': dict(doctrine['strategy_bias'])}
BUSINESS_INCOME = {
    'coffee': 175, 'carwash': 260, 'barbershop': 350, 'pizza': 525,
    'garage': 775, 'bar': 1200, 'club': 1900, 'warehouse': 2850,
    'casino': 4750, 'port': 7750,
}
BUSINESS_PRICE = {
    'coffee':3000, 'carwash':5000, 'barbershop':7500, 'pizza':12000,
    'garage':18000, 'bar':28000, 'club':45000, 'warehouse':70000,
    'casino':120000, 'port':200000,
}
BUSINESS_COORDS = {
    'coffee': (33, 13), 'carwash': (23, 25), 'barbershop': (53, 23),
    'pizza': (53, 53), 'garage': (13, 63), 'bar': (43, 33),
    'club': (63, 53), 'warehouse': (73, 23), 'casino': (13, 45),
    'port': (181, 31),
}
DISTRICTS = {
    'poor': 'Бедный район', 'downtown': 'Центр', 'nightlife': 'Ночная улица',
    'rich': 'Богатый район', 'countryside': 'Пригород',
    'industrial': 'Промзона', 'lair': 'Логово', 'coast': 'Побережье',
}
BUSINESS_DISTRICTS = {
    'coffee':'poor', 'carwash':'poor', 'barbershop':'downtown',
    'pizza':'nightlife', 'garage':'industrial', 'bar':'nightlife',
    'club':'downtown', 'warehouse':'industrial', 'casino':'downtown', 'port':'coast',
}
BUILDING_AREAS = dict((
    ('0,3',16),('0,4',4),('0,5',16),('0,6',16),('0,7',16),('0,11',20),('0,15',20),
    ('1,0',16),('1,2',16),('1,11',27),('1,12',20),('1,13',27),('1,15',27),('1,16',20),('1,17',27),
    ('2,0',16),('2,3',16),('2,7',16),('2,13',20),('2,17',20),('3,2',16),('3,5',16),('3,7',16),
    ('3,10',20),('3,11',27),('3,13',27),('3,14',20),('3,15',27),('3,17',27),
    ('4,0',16),('4,2',16),('4,4',16),('4,6',16),('4,11',20),('4,15',20),
    ('5,0',16),('5,1',16),('5,11',27),('5,12',20),('5,13',27),('5,15',27),('5,16',20),('5,17',27),
    ('6,0',16),('6,1',16),('6,3',16),('6,4',16),('6,6',16),('6,13',20),('6,17',20),
    ('7,0',16),('7,3',16),('7,4',16),('7,6',12),('7,10',20),('7,11',27),('7,13',27),('7,14',20),('7,15',27),('7,17',27),
    ('8,0',16),('8,1',16),('8,3',16),('8,5',16),('8,11',20),('8,15',20),
    ('9,0',16),('9,1',16),('9,2',16),('9,4',16),('9,11',27),('9,12',20),('9,13',27),('9,15',27),('9,16',20),('9,17',27),
    ('10,0',16),('10,1',16),('10,13',20),('10,17',20),
    ('11,1',16),('11,6',16),('11,7',16),('11,10',20),('11,11',27),('11,13',27),('11,14',20),('11,15',27),('11,17',27),
    ('12,0',16),('12,6',16),('12,11',20),('12,15',20),
    ('13,0',16),('13,7',16),('13,11',27),('13,12',20),('13,13',27),('13,15',27),('13,16',20),('13,17',27),
))
GENERIC_BUILDINGS = tuple(BUILDING_AREAS)
BUILDING_OPERATIONS = {
    'beer_bar': {'name': 'Пивной бар', 'icon': '🍺', 'base_income': 70},
    'pawnshop': {'name': 'Скупка краденого', 'icon': '💎', 'base_income': 85},
    'bookmaker': {'name': 'Букмекерская', 'icon': '🎟️', 'base_income': 95},
    'strip_club': {'name': 'Стрип-клуб', 'icon': '💃', 'base_income': 120},
    'gun_shop': {'name': 'Оружейная лавка', 'icon': '🔫', 'base_income': 130},
    'chop_shop': {'name': 'Авторазборка', 'icon': '🔧', 'base_income': 145},
    'poker_club': {'name': 'Подпольный покер', 'icon': '♠️', 'base_income': 160},
    'print_shop': {'name': 'Фальшивая типография', 'icon': '🖨️', 'base_income': 175},
}


def building_operation_income(operation_type: str, area: int) -> int:
    base = int(BUILDING_OPERATIONS.get(operation_type, BUILDING_OPERATIONS['beer_bar'])['base_income'])
    return min(200, base + round(max(0, min(27, int(area or 4)) - 4) * 25 / 23))


def choose_building_operation(profile: EmpireProfile, building_key: str,
                              capture_nonce: int = 0) -> str:
    preferred = ('gun_shop','chop_shop','poker_club','strip_club') if profile.aggression >= 70 else ('print_shop','poker_club','strip_club','bookmaker') if profile.commerce >= 84 else tuple(BUILDING_OPERATIONS)
    seed = int.from_bytes(hashlib.sha256(f'{profile.leader_id}:{building_key}:{capture_nonce}'.encode()).digest()[:4], 'big')
    return preferred[seed % len(preferred)]


async def _player_owned_building_keys(db) -> set[str]:
    """Reserve apartment blocks bought by players; older databases may lack the table."""
    try:
        rows = await (await db.execute("SELECT apt_key FROM apartments_owned")).fetchall()
    except Exception:
        return set()
    occupied = set()
    for row in rows:
        key = str(row[0] or '')
        try:
            if key.startswith('tile:'):
                r_text, c_text = key[5:].split(',', 1)
                occupied.add(f'{int(r_text) // 10},{int(c_text) // 10}')
            else:
                br_text, bc_text = key.split(',', 1)
                occupied.add(f'{int(br_text)},{int(bc_text)}')
        except (TypeError, ValueError):
            continue
    return occupied

# Public stops deliberately cover both halves of the city, the bridge-side
# avenues and the southern coast. They are movement targets, not ownership
# records: the normal empire tick remains authoritative for actual captures.
EMPIRE_PUBLIC_ROAM_POINTS = (
    ('east_north_1', 12, 102), ('east_north_2', 32, 142),
    ('east_bridge_1', 52, 122), ('east_bridge_2', 52, 162),
    ('east_mid_1', 72, 102), ('east_mid_2', 92, 142),
    ('east_south_1', 112, 122), ('east_south_2', 132, 162),
    ('coast_west', 154, 18), ('coast_centre', 158, 52),
    ('coast_east', 154, 102), ('port_approach', 168, 40),
)

# Every family recruits at the Lair. A paid hire becomes an armed family member
# immediately, but its visible reinforcement still starts at the crowded
# northern camp instead of spawning beside a distant boss out of thin air.
RECRUITMENT_VENUE = ('Логово', 106, 40, 101, 40)


def _recruitment_venue(profile: EmpireProfile) -> tuple[str, int, int, int, int]:
    del profile
    return RECRUITMENT_VENUE


def _row_field(row, key: str, default=0):
    try:
        value = row[key]
    except (KeyError, IndexError, TypeError):
        return default
    return default if value is None else value


def _recruitment_state(profile: EmpireProfile, row, now: int) -> dict | None:
    pending = max(0, int(_row_field(row, 'pending_recruits', 0)))
    ready_at = max(0, int(_row_field(row, 'recruit_ready_at', 0)))
    last_count = max(0, int(_row_field(row, 'last_recruit_count', 0)))
    last_at = max(0, int(_row_field(row, 'last_recruit_at', 0)))
    visible_completed = last_count > 0 and now < last_at + VISIBLE_ACTIVITY_SECONDS
    if (pending <= 0 or ready_at <= now) and not visible_completed:
        return None
    venue, source_r, source_c, meeting_r, meeting_c = _recruitment_venue(profile)
    return {
        'pending': pending, 'started_at': last_at if visible_completed else int(_row_field(row, 'recruit_started_at', 0)),
        'ready_at': ready_at, 'completed': visible_completed,
        'count': last_count if visible_completed else pending, 'venue': venue,
        'source_r': source_r, 'source_c': source_c,
        'meeting_r': meeting_r, 'meeting_c': meeting_c,
    }


def npc_owner_uid(leader_id: str) -> int:
    """Stable negative uid that cannot collide with Telegram ids."""
    pos = next((i for i, p in enumerate(PROFILES) if p.leader_id == leader_id), None)
    if pos is None:
        raise KeyError(leader_id)
    return NPC_OWNER_BASE - pos


def clamp_relation(value: int) -> int:
    return max(RELATION_MIN, min(RELATION_MAX, int(value)))


def relation_band(score: int) -> str:
    score = clamp_relation(score)
    if score <= -61: return 'enemy'
    if score <= -21: return 'hostile'
    if score <= 20: return 'neutral'
    if score <= 60: return 'friendly'
    return 'ally'


def _hq_coords(key: str) -> tuple[int, int]:
    br, bc = (int(x) for x in key.split(',', 1))
    return br * 10 + 6, bc * 10 + 6


def _district_for_block(key: str) -> str:
    r, c = _hq_coords(key)
    if r >= 150: return 'coast'
    if r >= 100: return 'lair'
    if r >= 60 and c < 40: return 'rich'
    if r >= 40 and c < 40: return 'nightlife'
    if r >= 40: return 'industrial'
    if c >= 40: return 'downtown'
    return 'poor'


def _citywide_roam_target(profile: EmpireProfile, slot: int) -> dict:
    """Choose a deterministic public destination across the complete map."""
    west_targets = [
        {'target_id': key, 'target_r': _hq_coords(key)[0],
         'target_c': _hq_coords(key)[1], 'target_kind': 'building'}
        for key in GENERIC_BUILDINGS
    ]
    west_targets.extend(
        {'target_id': bid, 'target_r': coords[0], 'target_c': coords[1],
         'target_kind': 'business'}
        for bid, coords in BUSINESS_COORDS.items() if bid != 'port'
    )
    east_targets = [
        {'target_id': f'roam:{key}', 'target_r': r, 'target_c': c,
         'target_kind': 'street'}
        for key, r, c in EMPIRE_PUBLIC_ROAM_POINTS
        if key.startswith('east_')
    ]
    south_targets = [
        {'target_id': f'roam:{key}', 'target_r': r, 'target_c': c,
         'target_kind': 'street'}
        for key, r, c in EMPIRE_PUBLIC_ROAM_POINTS
        if not key.startswith('east_')
    ]
    port_r, port_c = BUSINESS_COORDS['port']
    south_targets.append({'target_id': 'port', 'target_r': port_r,
                          'target_c': port_c, 'target_kind': 'business'})
    seed = int.from_bytes(hashlib.sha256(
        f'{profile.leader_id}:citywide:{slot}'.encode()).digest()[:4], 'big')
    profile_index = next(i for i, item in enumerate(PROFILES)
                         if item.leader_id == profile.leader_id)
    targets = (west_targets, east_targets, south_targets)[(profile_index + slot) % 3]
    return dict(targets[seed % len(targets)])


def _holding_district(kind: str, holding_id: str) -> str:
    return BUSINESS_DISTRICTS.get(holding_id, 'downtown') if kind == 'business' else _district_for_block(holding_id)


def _visible_activity(profile: EmpireProfile, row, holdings: list[dict], now: int,
                      brain: dict | None = None) -> dict:
    """Give the client one concrete, slowly changing destination for this boss."""
    recruitment = _recruitment_state(profile, row, now)
    if recruitment:
        return {
            'kind': 'recruit', 'target_id': f'recruit:{profile.leader_id}',
            'target_r': recruitment['meeting_r'], 'target_c': recruitment['meeting_c'],
            'phase': 'meeting', 'created_at': recruitment['started_at'],
            'summary': f'{profile.leader_name} проводит набор в семью: {recruitment["venue"]}',
        }
    strategy = str((brain or {}).get('strategy') or '')
    strategic_slot_at = (now // VISIBLE_ACTIVITY_SECONDS) * VISIBLE_ACTIVITY_SECONDS
    if strategy in {'recover', 'recruit'}:
        return {
            'kind': 'recruit', 'target_id': f'plan:{profile.leader_id}:lair',
            'target_r': 101, 'target_c': 40, 'phase': 'travel', 'created_at': strategic_slot_at,
            'summary': f'{profile.leader_name} едет в Логово искать надёжных людей',
        }
    if strategy == 'fortify' and holdings:
        target = min(holdings, key=lambda item: (int(item.get('defense') or 0),
                                                str(item.get('holding_id') or '')))
        target_id, target_kind = str(target.get('holding_id') or ''), str(target.get('kind') or '')
        target_r, target_c = (BUSINESS_COORDS.get(target_id, (0, 0))
                              if target_kind == 'business' else _hq_coords(target_id))
        return {
            'kind': 'defend', 'target_id': target_id, 'target_r': target_r,
            'target_c': target_c, 'phase': 'travel', 'created_at': strategic_slot_at,
            'summary': f'{profile.leader_name} лично проверяет слабое место обороны',
        }
    if strategy == 'acquire':
        owned = {str(item.get('holding_id') or '') for item in holdings}
        targets = [bid for bid in BUSINESS_PRICE if bid not in owned]
        if targets:
            target_id = max(targets, key=lambda bid: (BUSINESS_INCOME[bid] / BUSINESS_PRICE[bid], bid))
            target_r, target_c = BUSINESS_COORDS[target_id]
            return {
                'kind': 'invest', 'target_id': target_id, 'target_r': target_r,
                'target_c': target_c, 'phase': 'travel', 'created_at': strategic_slot_at,
                'summary': f'{profile.leader_name} оценивает бизнес перед сделкой',
            }
    if strategy == 'retaliate':
        hq_r, hq_c = _hq_coords(str(row['hq_key'] or profile.hq_key))
        return {
            'kind': 'attack', 'target_id': f'plan:{profile.leader_id}:revenge',
            'target_r': hq_r, 'target_c': hq_c, 'phase': 'rally', 'created_at': strategic_slot_at,
            'summary': f'{profile.leader_name} собирает семью для ответного удара',
        }
    slot = now // VISIBLE_ACTIVITY_SECONDS
    seed = int.from_bytes(hashlib.sha256(f'{profile.leader_id}:walk:{slot}'.encode()).digest()[:4], 'big')
    hq_r, hq_c = _hq_coords(str(row['hq_key'] or profile.hq_key))
    businesses = sorted(str(h['holding_id']) for h in holdings if str(h['kind']) == 'business')
    buildings = sorted(str(h['holding_id']) for h in holdings if str(h['kind']) == 'building')
    phase = seed % 7
    if phase == 0:
        return {'kind': 'return_hq', 'target_id': str(row['hq_key'] or profile.hq_key),
                'target_r': hq_r, 'target_c': hq_c, 'phase': 'travel',
                'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
                'summary': f'{profile.leader_name} возвращается в штаб'}
    owned = ([('business', target_id) for target_id in businesses] +
             [('building', target_id) for target_id in buildings])
    if phase == 1 and owned:
        target_kind, target_id = owned[(seed // 7) % len(owned)]
        if target_kind == 'business':
            target_r, target_c = BUSINESS_COORDS.get(target_id, (hq_r, hq_c))
            kind, label = 'collect', 'проверяет доход своего бизнеса'
        else:
            target_r, target_c = _hq_coords(target_id)
            kind, label = 'inspect', 'проверяет подконтрольное здание'
        return {'kind': kind, 'target_id': target_id,
                'target_r': target_r, 'target_c': target_c, 'phase': 'travel',
                'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
                'summary': f'{profile.leader_name} {label}'}
    target = _citywide_roam_target(profile, slot)
    kind = 'inspect' if target['target_kind'] in {'building', 'business'} else 'patrol'
    label = 'разведывает цель для захвата' if kind == 'inspect' else 'патрулирует дальний район'
    return {'kind': kind, 'target_id': target['target_id'],
            'target_r': target['target_r'], 'target_c': target['target_c'],
            'phase': 'travel', 'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
            'summary': f'{profile.leader_name} {label}'}


MEMORY_KINDS = {
    'player_attack': ('Личная обида', 'negative', 100),
    'player_business_bombed': ('Удар по бизнесу игрока', 'hostile', 82),
    'player_business_captured': ('Захваченный бизнес игрока', 'positive', 88),
    'war_lost': ('Неудачное нападение', 'negative', 78),
    'war_won': ('Победа в войне', 'positive', 74),
    'gang_destroyed': ('Уничтоженная семья', 'positive', 96),
    'empire_ruined': ('Разгром империи', 'negative', 100),
    'comeback': ('Возвращение со дна', 'positive', 92),
    'business_bought': ('Новый источник дохода', 'positive', 58),
    'expand': ('Новое владение', 'positive', 54),
    'recruit_completed': ('Новые бойцы', 'positive', 46),
    'hospitalized': ('Ранение босса', 'negative', 86),
}


def _boss_memory_cards(events: list[dict], now: int, limit: int = 5) -> list[dict]:
    """Turn the persistent event log into a small, useful long-term memory."""
    cards = []
    for event in events:
        kind = str(event.get('kind') or '')
        title, tone, importance = MEMORY_KINDS.get(kind, ('Событие семьи', 'neutral', 30))
        age = max(0, now - int(event.get('created_at') or now))
        effective = importance - min(importance - 12, age // 3600)
        if effective < 18:
            continue
        cards.append({
            'kind': kind, 'title': title, 'tone': tone,
            'importance': int(effective), 'summary': str(event.get('summary') or ''),
            'target_id': str(event.get('target_id') or ''),
            'created_at': int(event.get('created_at') or 0),
        })
    cards.sort(key=lambda item: (-item['importance'], -item['created_at'], item['kind']))
    return cards[:limit]


def _boss_adaptation(events: list[dict], now: int) -> dict:
    """Extract a bounded tactical lesson from recent persistent outcomes."""
    wins = {'war_won', 'gang_destroyed'}
    defeats = {'war_lost', 'empire_ruined'}
    recent = [event for event in events
              if max(0, now - int(event.get('created_at') or now)) <= 24 * 3600]
    recent.sort(key=lambda event: int(event.get('created_at') or 0), reverse=True)
    streak_kind = ''
    streak = 0
    for event in recent:
        kind = str(event.get('kind') or '')
        outcome = 'win' if kind in wins else 'loss' if kind in defeats else ''
        if not outcome:
            continue
        if not streak_kind:
            streak_kind = outcome
        if outcome != streak_kind:
            break
        streak += 1
    # Older clients wrote ``hospital`` while the learner originally expected
    # ``hospitalized``.  Accept both so real field defeats teach the boss.
    wounds = sum(1 for event in recent
                 if str(event.get('kind') or '') in {'hospital', 'hospitalized'})
    loss_streak = streak if streak_kind == 'loss' else 0
    win_streak = streak if streak_kind == 'win' else 0
    if loss_streak >= 2 or wounds >= 2:
        mode = 'cautious'
        lesson = (f'После {loss_streak} поражений подряд босс избегает нового фронта.'
                  if loss_streak >= 2 else
                  f'После {wounds} ранений босс бережёт себя и усиливает охрану.')
    elif win_streak >= 2:
        mode = 'bold'
        lesson = f'{win_streak} победы подряд убедили босса развивать успех.'
    else:
        mode = 'balanced'
        lesson = 'Недавние исходы не требуют менять привычный стиль.'
    return {
        'mode': mode, 'lesson': lesson, 'loss_streak': loss_streak,
        'win_streak': win_streak, 'recent_wounds': wounds,
    }


def _boss_brain(profile: EmpireProfile, row, holdings: list[dict], events: list[dict],
                now: int, *, active_wars: int = 0, neutral_buildings: int = 0,
                affordable_businesses: int = 0) -> dict:
    """Choose one explainable strategic priority instead of unrelated random actions."""
    treasury = max(0, int(row['treasury'] or 0))
    members = max(0, int(row['members'] or 0))
    strength = max(0, int(row['strength'] or 0))
    status = str(row['status'] or 'active')
    building_count = sum(1 for h in holdings if str(h['kind']) == 'building')
    business_count = sum(1 for h in holdings if str(h['kind']) == 'business')
    target_members = min(NPC_EMPIRE_MAX_FIGHTERS, 8 + (profile.aggression + profile.loyalty) // 10)
    memories = _boss_memory_cards(events, now)
    adaptation = _boss_adaptation(events, now)
    remembered = {memory['kind'] for memory in memories}
    recent_humiliation = sum(memory['importance'] for memory in memories
                             if memory['kind'] in {'player_attack', 'war_lost', 'empire_ruined', 'hospitalized'})
    doctrine = BOSS_DOCTRINES[profile.leader_id]
    scores = {
        'recover': (110 if status == 'rebuilding' else 0) + max(0, 5 - members) * 15 + max(0, 55 - strength) * .35,
        'recruit': max(0, target_members - members) * 7 + profile.loyalty * .24 + profile.aggression * .14,
        'fortify': active_wars * 32 + building_count * 2 + profile.loyalty * .27 + recent_humiliation * .18,
        'retaliate': active_wars * 38 + profile.aggression * .38 + recent_humiliation * .34,
        'acquire': profile.commerce * .48 + business_count * -5 + min(24, treasury / 1800),
        'expand': profile.aggression * .24 + profile.commerce * .20 + building_count * -4 + min(20, treasury / 2200),
        'consolidate': 22 + profile.diplomacy * .16 + len(holdings) * 2 + (18 if treasury < 1200 else 0),
    }
    for strategy_name, bias in doctrine['strategy_bias'].items():
        scores[strategy_name] += bias
    # Outcomes change future decisions instead of serving as decorative text.
    # Defeat streaks pull the family toward recovery and defense; a successful
    # streak creates controlled momentum without overriding hard constraints.
    loss_streak = int(adaptation['loss_streak'])
    win_streak = int(adaptation['win_streak'])
    wounds = int(adaptation['recent_wounds'])
    scores['recover'] += loss_streak * 20 + wounds * 9
    scores['recruit'] += loss_streak * 16 + wounds * 5
    scores['fortify'] += loss_streak * 18 + wounds * 8
    scores['retaliate'] -= loss_streak * 22 + wounds * 8
    scores['expand'] -= loss_streak * 15
    scores['retaliate'] += win_streak * 7
    scores['expand'] += win_streak * 12
    scores['acquire'] += win_streak * 4
    if int(row['hospital_until'] or 0) > now:
        scores['recover'] += 180
    if members >= target_members or treasury < 180 + members * 14:
        scores['recruit'] = -999
    if not holdings:
        scores['fortify'] -= 30
    if not active_wars and 'player_attack' not in remembered:
        scores['retaliate'] -= 28
    if not affordable_businesses or business_count >= 5:
        scores['acquire'] = -999
    if not neutral_buildings or building_count >= 8:
        scores['expand'] = -999
    ranked = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    strategy, best = ranked[0]
    second = ranked[1][1]
    confidence = max(52, min(96, int(58 + max(0, best - second) * .8)))
    power_per_member = strength / max(1, members)
    risk_value = (active_wars * 24 + max(0, 8 - members) * 5
                  + max(0, 11 - power_per_member) * 3
                  + loss_streak * 12 + wounds * 6 - win_streak * 4)
    risk = 'высокий' if risk_value >= 55 else 'средний' if risk_value >= 25 else 'низкий'
    labels = {
        'recover': 'Собрать семью заново', 'recruit': 'Усилить состав',
        'fortify': 'Удержать свои владения', 'retaliate': 'Ответить на угрозу',
        'acquire': 'Купить прибыльный бизнес', 'expand': 'Расширить территорию',
        'consolidate': 'Накопить казну',
    }
    dominant = max((('напор', profile.aggression), ('расчёт', profile.commerce),
                    ('переговоры', profile.diplomacy), ('верность', profile.loyalty)),
                   key=lambda item: item[1])[0]
    reasons = {
        'recover': f'После потерь {profile.leader_name} бережёт остатки семьи и восстанавливает силу.',
        'recruit': f'В строю {members} из желаемых {target_members}; без людей новый приказ слишком рискован.',
        'fortify': f'У семьи {len(holdings)} владений и {active_wars} активных войн: сначала нужна оборона.',
        'retaliate': f'Босс помнит недавнюю угрозу и считает, что без ответа авторитет семьи упадёт.',
        'acquire': f'В казне ${treasury:,}; коммерческая хватка подсказывает вложиться в доход, а не в перестрелку.',
        'expand': f'Сила {strength}, бойцов {members}: семья готова занять ближайшую удобную точку.',
        'consolidate': f'Сейчас выгоднее переждать, собрать доход и не открывать лишний фронт.',
    }
    return {
        'strategy': strategy, 'label': labels[strategy], 'reason': reasons[strategy],
        'confidence': confidence, 'risk': risk, 'temperament': dominant,
        'scores': [{'strategy': key, 'score': round(value, 1)} for key, value in ranked[:3]],
        'decided_at': now, 'memory_count': len(memories), 'adaptation': adaptation,
        'doctrine': boss_doctrine(profile.leader_id),
    }


def _war_activity(profile: EmpireProfile, row, enemy: dict, now: int) -> dict:
    """Expose one deterministic physical war order to every connected client."""
    slot = now // VISIBLE_ACTIVITY_SECONDS
    enemy_strength = max(1, int(enemy.get('strength') or 1))
    own_strength = max(1, int(row['strength'] or 1))
    stance = 'assault' if own_strength >= enemy_strength * .82 else 'harass'
    return {
        'kind': 'gang_war', 'target_id': str(enemy['leader_id']),
        'target_r': float(enemy.get('hq_r') or 0),
        'target_c': float(enemy.get('hq_c') or 0),
        'phase': 'engage', 'stance': stance,
        'force': min(NPC_EMPIRE_MAX_FIGHTERS, max(2, int(row['members'] or 1))),
        'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
        'summary': f'{profile.leader_name} ведёт {profile.gang_name} против {enemy["gang_name"]}',
    }


def _comeback_delay(profile: EmpireProfile, defeats: int) -> int:
    intelligence = (profile.commerce + profile.diplomacy + profile.loyalty) // 3
    span = COMEBACK_MAX_SECONDS - COMEBACK_MIN_SECONDS
    seed = int.from_bytes(hashlib.sha256(f'{profile.leader_id}:{defeats}'.encode()).digest()[:4], 'big')
    jitter = seed % max(1, span // 2)
    smart_discount = int(span * intelligence / 200)
    return max(COMEBACK_MIN_SECONDS, COMEBACK_MAX_SECONDS - smart_discount - jitter)


async def ensure_schema(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.executescript("""
        CREATE TABLE IF NOT EXISTS npc_empires (
            leader_id TEXT PRIMARY KEY,
            treasury INTEGER NOT NULL DEFAULT 0,
            members INTEGER NOT NULL DEFAULT 4,
            strength INTEGER NOT NULL DEFAULT 100,
            status TEXT NOT NULL DEFAULT 'active',
            hq_key TEXT,
            created_at INTEGER NOT NULL,
            last_tick INTEGER NOT NULL,
            next_action_at INTEGER NOT NULL DEFAULT 0,
            defeated_at INTEGER NOT NULL DEFAULT 0,
            defeated_by INTEGER,
            comeback_at INTEGER NOT NULL DEFAULT 0,
            comebacks INTEGER NOT NULL DEFAULT 0,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            knockouts INTEGER NOT NULL DEFAULT 0,
            dominance_score INTEGER NOT NULL DEFAULT 0,
            district_count INTEGER NOT NULL DEFAULT 0,
            peak_power INTEGER NOT NULL DEFAULT 0,
            hospital_until INTEGER NOT NULL DEFAULT 0,
            hospital_id TEXT NOT NULL DEFAULT '',
            pending_recruits INTEGER NOT NULL DEFAULT 0,
            recruit_started_at INTEGER NOT NULL DEFAULT 0,
            recruit_ready_at INTEGER NOT NULL DEFAULT 0,
            last_recruit_count INTEGER NOT NULL DEFAULT 0,
            last_recruit_at INTEGER NOT NULL DEFAULT 0,
            version INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS npc_empire_relations (
            leader_id TEXT NOT NULL,
            telegram_id INTEGER NOT NULL,
            score INTEGER NOT NULL DEFAULT 0,
            pact TEXT NOT NULL DEFAULT 'none',
            last_action_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (leader_id, telegram_id)
        );
        CREATE TABLE IF NOT EXISTS npc_empire_diplomacy (
            leader_a TEXT NOT NULL,
            leader_b TEXT NOT NULL,
            score INTEGER NOT NULL DEFAULT 0,
            pact TEXT NOT NULL DEFAULT 'none',
            tension INTEGER NOT NULL DEFAULT 0,
            last_event_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (leader_a,leader_b),
            CHECK (leader_a < leader_b)
        );
        CREATE TABLE IF NOT EXISTS npc_empire_holdings (
            kind TEXT NOT NULL,
            holding_id TEXT NOT NULL,
            leader_id TEXT NOT NULL,
            income INTEGER NOT NULL DEFAULT 0,
            defense INTEGER NOT NULL DEFAULT 0,
            acquired_at INTEGER NOT NULL,
            operation_type TEXT NOT NULL DEFAULT '',
            area INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (kind, holding_id)
        );
        CREATE INDEX IF NOT EXISTS ix_npc_empire_holdings_leader
            ON npc_empire_holdings(leader_id,kind);
        CREATE TABLE IF NOT EXISTS npc_empire_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            leader_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            target_id TEXT DEFAULT '',
            summary TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS ix_npc_empire_events_time
            ON npc_empire_events(created_at DESC);
        CREATE TABLE IF NOT EXISTS npc_empire_districts (
            district_id TEXT PRIMARY KEY,
            leader_id TEXT NOT NULL,
            score INTEGER NOT NULL DEFAULT 0,
            runner_up_id TEXT NOT NULL DEFAULT '',
            runner_up_score INTEGER NOT NULL DEFAULT 0,
            contested INTEGER NOT NULL DEFAULT 0,
            changed_at INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS npc_empire_assaults (
            token TEXT PRIMARY KEY,
            telegram_id INTEGER NOT NULL,
            leader_id TEXT NOT NULL,
            guard_hp_json TEXT NOT NULL,
            boss_hp INTEGER NOT NULL,
            boss_max_hp INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            started_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            last_hit_at REAL NOT NULL DEFAULT 0,
            resolution TEXT DEFAULT NULL
        );
        CREATE TABLE IF NOT EXISTS npc_empire_player_wars (
            leader_id TEXT NOT NULL,
            telegram_id INTEGER NOT NULL,
            next_attack_at INTEGER NOT NULL DEFAULT 0,
            attacks INTEGER NOT NULL DEFAULT 0,
            last_business_id TEXT NOT NULL DEFAULT '',
            last_attack_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (leader_id, telegram_id)
        );
        CREATE INDEX IF NOT EXISTS ix_npc_empire_player_wars_due
            ON npc_empire_player_wars(telegram_id,next_attack_at);
        """)
        now = int(time.time())
        columns = {str(r[1]) for r in await (await db.execute("PRAGMA table_info(npc_empires)")).fetchall()}
        migrations = {
            'comeback_at': "INTEGER NOT NULL DEFAULT 0", 'comebacks': "INTEGER NOT NULL DEFAULT 0",
            'wins': "INTEGER NOT NULL DEFAULT 0", 'losses': "INTEGER NOT NULL DEFAULT 0",
            'knockouts': "INTEGER NOT NULL DEFAULT 0", 'dominance_score': "INTEGER NOT NULL DEFAULT 0",
            'district_count': "INTEGER NOT NULL DEFAULT 0", 'peak_power': "INTEGER NOT NULL DEFAULT 0",
            'hospital_until': "INTEGER NOT NULL DEFAULT 0", 'hospital_id': "TEXT NOT NULL DEFAULT ''",
            'pending_recruits': "INTEGER NOT NULL DEFAULT 0",
            'recruit_started_at': "INTEGER NOT NULL DEFAULT 0",
            'recruit_ready_at': "INTEGER NOT NULL DEFAULT 0",
            'last_recruit_count': "INTEGER NOT NULL DEFAULT 0",
            'last_recruit_at': "INTEGER NOT NULL DEFAULT 0",
        }
        for name, declaration in migrations.items():
            if name not in columns:
                await db.execute(f"ALTER TABLE npc_empires ADD COLUMN {name} {declaration}")
        holding_columns = {str(r[1]) for r in await (await db.execute(
            "PRAGMA table_info(npc_empire_holdings)")).fetchall()}
        for name, declaration in {'operation_type': "TEXT NOT NULL DEFAULT ''", 'area': "INTEGER NOT NULL DEFAULT 0"}.items():
            if name not in holding_columns:
                await db.execute(f"ALTER TABLE npc_empire_holdings ADD COLUMN {name} {declaration}")
        legacy_buildings = await (await db.execute(
            "SELECT holding_id,leader_id,operation_type,area FROM npc_empire_holdings WHERE kind='building'"
        )).fetchall()
        for holding in legacy_buildings:
            key, leader_id = str(holding[0]), str(holding[1])
            area = int(holding[3] or BUILDING_AREAS.get(key, 4))
            profile = PROFILE_BY_ID.get(leader_id)
            operation = str(holding[2] or '')
            if operation not in BUILDING_OPERATIONS:
                operation = choose_building_operation(profile, key) if profile else 'beer_bar'
            await db.execute(
                "UPDATE npc_empire_holdings SET operation_type=?,area=?,income=? WHERE kind='building' AND holding_id=?",
                (operation, area, building_operation_income(operation, area), key),
            )
        await db.execute(
            "UPDATE npc_empires SET status='ruined',comeback_at=CASE WHEN comeback_at=0 THEN ? ELSE comeback_at END "
            "WHERE status='defeated'", (now + COMEBACK_MIN_SECONDS,)
        )
        await db.execute(
            "UPDATE npc_empire_relations SET score=0,pact='none' WHERE leader_id IN "
            "(SELECT leader_id FROM npc_empires WHERE status='ruined')"
        )
        await db.execute(
            "UPDATE npc_empire_diplomacy SET score=0,pact='none',tension=0 WHERE leader_a IN "
            "(SELECT leader_id FROM npc_empires WHERE status='ruined') OR leader_b IN "
            "(SELECT leader_id FROM npc_empires WHERE status='ruined')"
        )
        for profile in PROFILES:
            await db.execute(
                "INSERT OR IGNORE INTO npc_empires"
                "(leader_id,treasury,members,strength,status,hq_key,created_at,last_tick,next_action_at) "
                "VALUES(?,?,?,?, 'active',?,?,?,?)",
                (profile.leader_id, profile.starting_cash, 4 + profile.loyalty // 18,
                 90 + profile.aggression + profile.loyalty // 2, profile.hq_key,
                 now, now, now + TICK_SECONDS),
            )
            seeded = await (await db.execute(
                "SELECT status,hq_key FROM npc_empires WHERE leader_id=?", (profile.leader_id,)
            )).fetchone()
            if seeded and seeded[0] != 'ruined' and seeded[1]:
                await db.execute(
                    "INSERT OR IGNORE INTO npc_empire_holdings"
                    "(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('hq',?,?,?,?,?)",
                    (str(seeded[1]), profile.leader_id, 0,
                     80 + profile.loyalty + profile.aggression // 2, now),
                )
        for ai, left in enumerate(PROFILES):
            for right in PROFILES[ai+1:]:
                leader_a, leader_b = sorted((left.leader_id, right.leader_id))
                seed = int.from_bytes(hashlib.sha256(
                    f'{leader_a}:{leader_b}'.encode()).digest()[:2], 'big')
                score = seed % 31 - 15
                await db.execute(
                    "INSERT OR IGNORE INTO npc_empire_diplomacy"
                    "(leader_a,leader_b,score,pact,tension,last_event_at) VALUES(?,?,?,'none',0,?)",
                    (leader_a, leader_b, score, now),
                )
        await db.commit()


async def hospitalize_boss(db_path: str, leader_id: str, hospital_id: str = 'hospital',
                           now: int | None = None) -> dict:
    """Place a defeated empire boss in authoritative treatment for 60 seconds."""
    now = int(now or time.time())
    leader_id = str(leader_id or '').strip()
    hospital_id = str(hospital_id or 'hospital').strip()
    if leader_id not in PROFILE_BY_ID:
        return {'ok': False, 'error': 'unknown_leader'}
    if hospital_id not in ('hospital', 'hospital_east'):
        hospital_id = 'hospital'
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        row = await (await db.execute(
            "SELECT hospital_until,hospital_id,status FROM npc_empires WHERE leader_id=?", (leader_id,)
        )).fetchone()
        if not row or str(row['status']) == 'ruined':
            return {'ok': False, 'error': 'boss_unavailable'}
        current_until = int(row['hospital_until'] or 0)
        until = current_until if current_until > now else now + 60
        chosen = str(row['hospital_id'] or hospital_id) if current_until > now else hospital_id
        await db.execute(
            "UPDATE npc_empires SET hospital_until=?,hospital_id=?,version=version+1 WHERE leader_id=?",
            (until, chosen, leader_id),
        )
        if current_until <= now:
            profile = PROFILE_BY_ID[leader_id]
            await db.execute(
                "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                (leader_id, 'hospital', chosen,
                 f'{profile.leader_name} доставлен в больницу на 60 секунд', now),
            )
        await db.commit()
    return {'ok': True, 'leader_id': leader_id, 'hospital_id': chosen,
            'hospital_until': until, 'duration': max(0, until - now)}


def _decision_roll(leader_id: str, tick_at: int) -> random.Random:
    digest = hashlib.sha256(f'{leader_id}:{tick_at // TICK_SECONDS}'.encode()).digest()
    return random.Random(int.from_bytes(digest[:8], 'big'))


async def _collapse_empire(db, leader_id: str, now: int, defeated_by,
                           summary: str, preserve_businesses: bool = False) -> int:
    """Remove an empire from the board, but schedule its leader's comeback."""
    profile = PROFILE_BY_ID[leader_id]
    row = await (await db.execute(
        "SELECT losses FROM npc_empires WHERE leader_id=?", (leader_id,)
    )).fetchone()
    defeats = int(row['losses'] or 0) + 1
    comeback_at = now + _comeback_delay(profile, defeats)
    if not preserve_businesses:
        await db.execute(
            "DELETE FROM business_property_owners WHERE owner_uid=?", (npc_owner_uid(leader_id),)
        )
    await db.execute("DELETE FROM npc_empire_holdings WHERE leader_id=?", (leader_id,))
    await db.execute(
        "UPDATE npc_empires SET status='ruined',treasury=0,members=0,strength=0,hq_key=NULL,"
        "defeated_at=?,defeated_by=?,comeback_at=?,losses=losses+1,dominance_score=0,"
        "district_count=0,pending_recruits=0,recruit_started_at=0,recruit_ready_at=0,last_recruit_count=0,last_recruit_at=0,"
        "version=version+1 WHERE leader_id=?",
        (now, defeated_by, comeback_at, leader_id),
    )
    # A fall erases the boss's political capital. Every player and NPC meets
    # the returning leader on neutral terms.
    await db.execute(
        "UPDATE npc_empire_relations SET score=0,pact='none',last_action_at=? WHERE leader_id=?",
        (now, leader_id),
    )
    await db.execute(
        "UPDATE npc_empire_diplomacy SET score=0,pact='none',tension=0,last_event_at=? "
        "WHERE leader_a=? OR leader_b=?", (now, leader_id, leader_id),
    )
    await db.execute(
        "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
        (leader_id, 'empire_ruined', str(defeated_by or ''), summary, now),
    )
    return comeback_at


async def _revive_due_empires(db, now: int, events: list[dict]) -> None:
    due = await (await db.execute(
        "SELECT leader_id,comebacks FROM npc_empires WHERE status='ruined' AND comeback_at>0 AND comeback_at<=?",
        (now,),
    )).fetchall()
    used = {str(r[0]) for r in await (await db.execute(
        "SELECT holding_id FROM npc_empire_holdings WHERE kind IN ('hq','building')"
    )).fetchall()}
    used.update(await _player_owned_building_keys(db))
    for row in due:
        leader_id = str(row['leader_id']); profile = PROFILE_BY_ID[leader_id]
        candidates = [key for key in GENERIC_BUILDINGS if key not in used]
        if not candidates:
            continue
        comeback_no = int(row['comebacks'] or 0) + 1
        seed = int.from_bytes(hashlib.sha256(f'{leader_id}:return:{comeback_no}'.encode()).digest()[:4], 'big')
        hq_key = candidates[seed % len(candidates)]; used.add(hq_key)
        treasury = 250 + profile.commerce * 4
        strength = 35 + profile.loyalty // 3
        await db.execute(
            "UPDATE npc_empires SET status='rebuilding',treasury=?,members=2,strength=?,hq_key=?,"
            "comeback_at=0,comebacks=?,defeated_by=NULL,pending_recruits=0,recruit_started_at=0,"
            "recruit_ready_at=0,last_recruit_count=0,last_recruit_at=0,last_tick=?,next_action_at=?,version=version+1 "
            "WHERE leader_id=?",
            (treasury, strength, hq_key, comeback_no, now, now + TICK_SECONDS, leader_id),
        )
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_holdings"
            "(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('hq',?,?,?,?,?)",
            (hq_key, leader_id, 0, 45 + profile.loyalty // 2, now),
        )
        events.append({
            'leader_id': leader_id, 'kind': 'comeback', 'target_id': hq_key,
            'summary': f'{profile.leader_name} вернулся с нуля и основал новый штаб',
        })


async def _recompute_districts(db, now: int) -> None:
    scores: dict[str, dict[str, int]] = {district: {} for district in DISTRICTS}
    rows = await (await db.execute(
        "SELECT kind,holding_id,leader_id,income FROM npc_empire_holdings"
    )).fetchall()
    for row in rows:
        kind, holding_id, leader_id = str(row['kind']), str(row['holding_id']), str(row['leader_id'])
        district = _holding_district(kind, holding_id)
        weight = 10 if kind == 'hq' else (8 + int(row['income'] or 0) // 500 if kind == 'business' else 3)
        scores[district][leader_id] = scores[district].get(leader_id, 0) + weight
    await db.execute("UPDATE npc_empires SET dominance_score=0,district_count=0")
    for district_id in DISTRICTS:
        ranking = sorted(scores[district_id].items(), key=lambda item: (-item[1], item[0]))
        leader_id, score = ranking[0] if ranking else ('', 0)
        runner_id, runner_score = ranking[1] if len(ranking) > 1 else ('', 0)
        contested = int(bool(runner_id) and score - runner_score <= 3)
        old = await (await db.execute(
            "SELECT leader_id,changed_at FROM npc_empire_districts WHERE district_id=?", (district_id,)
        )).fetchone()
        changed_at = int(old['changed_at']) if old and str(old['leader_id']) == leader_id else now
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_districts"
            "(district_id,leader_id,score,runner_up_id,runner_up_score,contested,changed_at) VALUES(?,?,?,?,?,?,?)",
            (district_id, leader_id, score, runner_id, runner_score, contested, changed_at),
        )
        if leader_id:
            await db.execute(
                "UPDATE npc_empires SET dominance_score=dominance_score+?,district_count=district_count+1 "
                "WHERE leader_id=?", (score, leader_id),
            )
    await db.execute(
        "UPDATE npc_empires SET peak_power=MAX(peak_power, strength+members*10+dominance_score*8)"
    )


async def advance(db_path: str, now: int | None = None) -> list[dict]:
    """Apply bounded offline income, upkeep, recruitment and expansion."""
    now = int(now or time.time())
    events: list[dict] = []
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        await _revive_due_empires(db, now, events)
        rows = await (await db.execute(
            "SELECT * FROM npc_empires WHERE status IN ('active','rebuilding','vassal')"
        )).fetchall()
        # Candidates are not counted as fighters until their visible recruitment
        # window has elapsed. Completion is processed independently of the
        # five-minute economy tick so a state poll can finish the hiring on time.
        for row in rows:
            pending = max(0, int(row['pending_recruits'] or 0))
            if pending <= 0 or int(row['recruit_ready_at'] or 0) > now:
                continue
            leader_id = str(row['leader_id']); profile = PROFILE_BY_ID[leader_id]
            room = max(0, NPC_EMPIRE_MAX_FIGHTERS - int(row['members'] or 0))
            completed = min(pending, room)
            if completed:
                await db.execute(
                    "UPDATE npc_empires SET members=members+?,strength=strength+?,"
                    "pending_recruits=0,recruit_started_at=0,recruit_ready_at=0,version=version+1 "
                    "WHERE leader_id=?",
                    (completed, completed * (11 + profile.aggression // 12), leader_id),
                )
                events.append({'leader_id': leader_id, 'kind': 'recruit_completed',
                               'summary': f'{completed} новичков принесли клятву семье {profile.gang_name}'})
            else:
                await db.execute(
                    "UPDATE npc_empires SET pending_recruits=0,recruit_started_at=0,recruit_ready_at=0 "
                    "WHERE leader_id=?", (leader_id,),
                )
        rows = await (await db.execute(
            "SELECT * FROM npc_empires WHERE status IN ('active','rebuilding','vassal')"
        )).fetchall()
        empire_row_by_id = {str(row['leader_id']): row for row in rows}
        diplomacy_state = {}
        for relation in await (await db.execute(
            "SELECT leader_a,leader_b,pact,tension FROM npc_empire_diplomacy"
        )).fetchall():
            diplomacy_state[(str(relation['leader_a']), str(relation['leader_b']))] = (
                str(relation['pact'] or 'none'), int(relation['tension'] or 0))
        player_war_leaders = {str(row[0]) for row in await (await db.execute(
            "SELECT DISTINCT leader_id FROM npc_empire_player_wars"
        )).fetchall()}
        memory_rows = await (await db.execute(
            "SELECT leader_id,kind,target_id,summary,created_at FROM npc_empire_events "
            "ORDER BY id DESC LIMIT 240"
        )).fetchall()
        memories_by_leader: dict[str, list[dict]] = {profile.leader_id: [] for profile in PROFILES}
        for memory_row in memory_rows:
            memories_by_leader.setdefault(str(memory_row['leader_id']), []).append(dict(memory_row))
        building_owner = {str(r['holding_id']):str(r['leader_id']) for r in await (await db.execute(
            "SELECT holding_id,leader_id FROM npc_empire_holdings WHERE kind='building'"
        )).fetchall()}
        for player_key in await _player_owned_building_keys(db):
            building_owner.setdefault(player_key, 'player')
        business_owner = {str(r['holding_id']):str(r['leader_id']) for r in await (await db.execute(
            "SELECT holding_id,leader_id FROM npc_empire_holdings WHERE kind='business'"
        )).fetchall()}
        property_owned = {str(r[0]) for r in await (await db.execute(
            "SELECT biz_id FROM business_property_owners"
        )).fetchall()}
        ruined_this_tick: set[str] = set()
        for row in rows:
            leader_id = str(row['leader_id'])
            if leader_id in ruined_this_tick:
                continue
            profile = PROFILE_BY_ID[leader_id]
            elapsed = max(0, now - int(row['last_tick'] or now))
            ticks = min(MAX_OFFLINE_TICKS, elapsed // TICK_SECONDS)
            if ticks <= 0:
                continue
            holdings = await (await db.execute(
                "SELECT kind,holding_id,income,defense,operation_type,area FROM npc_empire_holdings WHERE leader_id=?",
                (leader_id,),
            )).fetchall()
            per_tick = 18 + profile.commerce // 3 + sum(int(h['income'] or 0) for h in holdings) // 288
            upkeep = max(4, int(row['members'] or 0) * 3)
            treasury = max(0, int(row['treasury'] or 0) + ticks * (per_tick - upkeep))
            members = max(1, int(row['members'] or 1))
            strength = max(20, int(row['strength'] or 20))
            pending_recruits = max(0, int(row['pending_recruits'] or 0))
            recruit_started_at = max(0, int(row['recruit_started_at'] or 0))
            recruit_ready_at = max(0, int(row['recruit_ready_at'] or 0))
            rng = _decision_roll(leader_id, int(row['last_tick']) + ticks * TICK_SECONDS)
            recruit_cost = 180 + members * 14
            # A successful boss can grow a full street army.  The hard cap is
            # shared with world.html so one leader never materialises more than
            # twenty armed followers around himself.
            target_members = min(
                NPC_EMPIRE_MAX_FIGHTERS,
                8 + (profile.aggression + profile.loyalty) // 10,
            )
            building_count = sum(1 for h in holdings if h['kind'] == 'building')
            owned_businesses = [h for h in holdings if h['kind'] == 'business']
            neutral_building_choices = [key for key in GENERIC_BUILDINGS
                                        if key not in building_owner and key != profile.hq_key]
            neutral_businesses = [bid for bid in BUSINESS_PRICE
                                  if bid not in property_owned and bid not in business_owner]
            affordable = [bid for bid in neutral_businesses
                          if treasury >= int(BUSINESS_PRICE[bid] * .65)]
            active_wars = sum(1 for pair, state in diplomacy_state.items()
                              if leader_id in pair and state[0] == 'war')
            if leader_id in player_war_leaders:
                active_wars += 1
            brain_row = {
                'treasury': treasury, 'members': members, 'strength': strength,
                'status': str(row['status']),
                'hospital_until': int(row['hospital_until'] or 0),
            }
            brain = _boss_brain(
                profile, brain_row, [dict(h) for h in holdings],
                memories_by_leader.get(leader_id, []), now,
                active_wars=active_wars,
                neutral_buildings=len(neutral_building_choices),
                affordable_businesses=len(affordable),
            )
            strategy = str(brain['strategy'])
            strategic_action_taken = False
            last_recruit_count = max(0, int(row['last_recruit_count'] or 0))
            last_recruit_at = max(0, int(row['last_recruit_at'] or 0))
            recruit_chance = .96 if strategy in {'recover', 'recruit', 'fortify'} else .22
            if pending_recruits == 0 and members < target_members and treasury >= recruit_cost and rng.random() < recruit_chance:
                hired = min(3, target_members - members, treasury // recruit_cost)
                if hired:
                    treasury -= hired * recruit_cost
                    members += hired
                    strength += hired * (11 + profile.aggression // 12)
                    last_recruit_count = hired
                    last_recruit_at = now
                    venue, _, _, _, _ = _recruitment_venue(profile)
                    events.append({'leader_id': leader_id, 'kind': 'recruit_completed',
                                   'summary': f'{profile.leader_name} сразу принял {hired} бойцов: {venue}'})
                    strategic_action_taken = True
            expansion_cost = 1100 + building_count * 650
            army_pressure = min(1.0, members / NPC_EMPIRE_MAX_FIGHTERS)
            expand_chance = .90 if strategy == 'expand' else .035
            if (not strategic_action_taken and treasury >= expansion_cost and building_count < 8
                    and rng.random() < expand_chance):
                choices = neutral_building_choices
                if choices:
                    anchors = [_hq_coords(str(row['hq_key'] or profile.hq_key))]
                    anchors.extend(_hq_coords(str(h['holding_id'])) for h in holdings
                                   if str(h['kind']) == 'building')
                    def building_utility(key: str) -> tuple:
                        target_r, target_c = _hq_coords(key)
                        distance = min(abs(target_r-r) + abs(target_c-c) for r, c in anchors)
                        tie = int.from_bytes(hashlib.sha256(
                            f'{leader_id}:{key}'.encode()).digest()[:2], 'big')
                        return distance, tie
                    key = min(choices, key=building_utility)
                    building_owner[key] = leader_id
                    area = BUILDING_AREAS[key]
                    operation = choose_building_operation(profile, key, now)
                    income = building_operation_income(operation, area)
                    defense = 35 + profile.loyalty // 2
                    await db.execute(
                        "INSERT OR REPLACE INTO npc_empire_holdings"
                        "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) VALUES('building',?,?,?,?,?,?,?)",
                        (key, leader_id, income, defense, now, operation, area),
                    )
                    treasury -= expansion_cost
                    events.append({'leader_id': leader_id, 'kind': 'expand', 'target_id': key,
                                   'summary': f"{profile.gang_name} захватили дом {key} и открыли «{BUILDING_OPERATIONS[operation]['name']}»"})
                    strategic_action_taken = True
            # A faction may buy a neutral business. Player-owned property is
            # never removed by an offline roll: attacking a player must create
            # a visible, defendable headquarters/business assault instead.
            acquire_chance = .92 if strategy == 'acquire' else .025
            if (not strategic_action_taken and neutral_businesses and len(owned_businesses) < 5
                    and rng.random() < acquire_chance):
                if affordable:
                    hq_r, hq_c = _hq_coords(str(row['hq_key'] or profile.hq_key))
                    def business_utility(bid: str) -> tuple:
                        income_yield = BUSINESS_INCOME[bid] / max(1, BUSINESS_PRICE[bid])
                        target_r, target_c = BUSINESS_COORDS[bid]
                        distance = abs(target_r-hq_r) + abs(target_c-hq_c)
                        score = income_yield * (150000 + profile.commerce * 1200) - distance * (2.2-profile.commerce/100)
                        return -score, bid
                    bid = min(affordable, key=business_utility)
                    cost = int(BUSINESS_PRICE[bid] * .65)
                    treasury -= cost
                    business_owner[bid] = leader_id; property_owned.add(bid)
                    await db.execute(
                        "INSERT OR REPLACE INTO npc_empire_holdings"
                        "(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('business',?,?,?,?,?)",
                        (bid, leader_id, BUSINESS_INCOME[bid], 60+profile.loyalty, now),
                    )
                    await db.execute(
                        "INSERT OR REPLACE INTO business_property_owners"
                        "(biz_id,owner_uid,owner_name,acquired_at,protected_until) VALUES(?,?,?,?,?)",
                        (bid, npc_owner_uid(leader_id), profile.gang_name, now, now+300),
                    )
                    events.append({'leader_id':leader_id,'kind':'business_bought','target_id':bid,
                                   'summary':f'{profile.gang_name} купили бизнес {bid}'})
                    strategic_action_taken = True
            if not strategic_action_taken and strategy == 'fortify' and holdings:
                fortify_cost = 420 + len(holdings) * 45
                if treasury >= fortify_cost:
                    weak = min(holdings, key=lambda item: (
                        int(item['defense'] or 0), -int(item['income'] or 0),
                        str(item['holding_id'])))
                    defense_gain = 10 + profile.loyalty // 8
                    await db.execute(
                        "UPDATE npc_empire_holdings SET defense=MIN(240,defense+?) "
                        "WHERE kind=? AND holding_id=? AND leader_id=?",
                        (defense_gain, str(weak['kind']), str(weak['holding_id']), leader_id),
                    )
                    treasury -= fortify_cost
                    events.append({
                        'leader_id': leader_id, 'kind': 'fortify',
                        'target_id': str(weak['holding_id']),
                        'summary': f'{profile.leader_name} усилил оборону владения {weak["holding_id"]}',
                    })
                    strategic_action_taken = True
            # Autonomous wars only move NPC-controlled holdings here. Battles
            # involving a player are created as explicit defendable sessions.
            # Large formations stop behaving like small raiding parties: once
            # the boss has a real army, it continually pressures rival assets.
            war_chance = .82 if strategy == 'retaliate' else (.018 + profile.aggression / 3000)
            if (not strategic_action_taken and leader_id not in player_war_leaders
                    and rng.random() < war_chance):
                holding_counts: dict[str, int] = {}
                for owner in list(building_owner.values()) + list(business_owner.values()):
                    holding_counts[owner] = holding_counts.get(owner, 0) + 1
                rivals = []
                for other in PROFILES:
                    if other.leader_id == leader_id or not holding_counts.get(other.leader_id):
                        continue
                    # Keep a boss physically available while a player has an
                    # unresolved personal war with that family.
                    if other.leader_id in player_war_leaders:
                        continue
                    rival_row = empire_row_by_id.get(other.leader_id)
                    if not rival_row or str(rival_row['status']) == 'ruined':
                        continue
                    pair = tuple(sorted((leader_id, other.leader_id)))
                    pact, tension = diplomacy_state.get(pair, ('none', 0))
                    if pact in {'alliance', 'truce', 'vassal'}:
                        continue
                    relative = int(rival_row['strength'] or 1) / max(1, strength)
                    if relative > 1.7 and pact != 'war':
                        continue
                    # Prefer an existing enemy, then a weaker but valuable family.
                    score = (0 if pact == 'war' else 3) + relative * 4 - holding_counts[other.leader_id] * .38 - tension * .012
                    score += rng.random() * .45
                    rivals.append((score, other))
                if not rivals:
                    rivals = []
                rivals.sort(key=lambda item: (item[0], item[1].leader_id))
                rival = rivals[0][1] if rivals else None
                target_rows = await (await db.execute(
                    "SELECT kind,holding_id,income,defense,operation_type,area FROM npc_empire_holdings "
                    "WHERE leader_id=? AND kind IN ('building','business') ORDER BY kind DESC",
                    (rival.leader_id if rival else '__none__',),
                )).fetchall()
                rival_state = await (await db.execute(
                    "SELECT strength,members,status FROM npc_empires WHERE leader_id=?",
                    (rival.leader_id if rival else '__none__',),
                )).fetchone()
                if target_rows and rival_state and rival_state['status'] in ('active','rebuilding','vassal') and rival.leader_id not in ruined_this_tick:
                    target = max(target_rows, key=lambda item: (
                        int(item['income'] or 0) * (1 + profile.commerce / 180)
                        - int(item['defense'] or 0) * (1.25 - profile.aggression / 180),
                        str(item['holding_id']),
                    ))
                    attack_power = strength * (.72 + rng.random()*.58) + profile.aggression
                    defense_power = int(rival_state['strength']) * (.78 + rng.random()*.52) + int(target['defense'])
                    casualty = max(1, int((attack_power+defense_power)/180))
                    strength = max(20, strength-casualty*4)
                    members = max(1, members-casualty//2)
                    a,b=sorted((leader_id,rival.leader_id))
                    await db.execute(
                        "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=MIN(100,tension+25),last_event_at=? WHERE leader_a=? AND leader_b=?",
                        (now,a,b),
                    )
                    if attack_power > defense_power:
                        await db.execute(
                            "UPDATE npc_empire_holdings SET leader_id=?,defense=?,acquired_at=? WHERE kind=? AND holding_id=?",
                            (leader_id,45+profile.loyalty//2,now,str(target['kind']),str(target['holding_id'])),
                        )
                        if target['kind']=='business':
                            business_owner[str(target['holding_id'])]=leader_id
                            await db.execute(
                                "UPDATE business_property_owners SET owner_uid=?,owner_name=?,acquired_at=?,protected_until=? WHERE biz_id=?",
                                (npc_owner_uid(leader_id),profile.gang_name,now,now+300,str(target['holding_id'])),
                            )
                        else: building_owner[str(target['holding_id'])]=leader_id
                        events.append({'leader_id':leader_id,'kind':'war_won','target_id':rival.leader_id,
                                       'summary':f'{profile.gang_name} отбили {target["kind"]} {target["holding_id"]} у {rival.gang_name}'})
                        await db.execute(
                            "UPDATE npc_empires SET wins=wins+1 WHERE leader_id=?", (leader_id,)
                        )
                        remaining = await (await db.execute(
                            "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=? "
                            "AND kind IN ('building','business')", (rival.leader_id,)
                        )).fetchone()
                        if int(remaining[0] or 0) == 0 and attack_power > defense_power * 1.45:
                            comeback_at = await _collapse_empire(
                                db, rival.leader_id, now, npc_owner_uid(leader_id),
                                f'{profile.gang_name} уничтожили штаб {rival.gang_name}; лидер начинает со дна',
                            )
                            ruined_this_tick.add(rival.leader_id)
                            await db.execute(
                                "UPDATE npc_empires SET knockouts=knockouts+1 WHERE leader_id=?", (leader_id,)
                            )
                            events.append({
                                'leader_id': leader_id, 'kind': 'gang_destroyed',
                                'target_id': rival.leader_id,
                                'summary': f'{profile.leader_name} разгромил {rival.leader_name}; '
                                           f'возвращение через {(comeback_at-now)//60} мин.',
                            })
                    else:
                        events.append({'leader_id':leader_id,'kind':'war_lost','target_id':rival.leader_id,
                                       'summary':f'{rival.gang_name} отбили нападение {profile.gang_name}'})
            next_status = 'active' if row['status'] == 'rebuilding' and (members >= 4 or treasury >= 1500) else str(row['status'])
            await db.execute(
                "UPDATE npc_empires SET treasury=?,members=?,strength=?,status=?,pending_recruits=?,"
                "recruit_started_at=?,recruit_ready_at=?,last_recruit_count=?,last_recruit_at=?,last_tick=?,next_action_at=?,version=version+1 WHERE leader_id=?",
                (treasury, members, strength, next_status, pending_recruits,
                 recruit_started_at, recruit_ready_at, last_recruit_count, last_recruit_at, int(row['last_tick']) + ticks*TICK_SECONDS,
                 now + TICK_SECONDS, leader_id),
            )
        for event in events:
            await db.execute(
                "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                (event['leader_id'], event['kind'], event.get('target_id',''), event['summary'], now),
            )
        await _recompute_districts(db, now)
        await db.execute("DELETE FROM npc_empire_assaults WHERE expires_at<?", (now - 3600,))
        await db.commit()
    return events


def _player_war_interval(profile: EmpireProfile) -> int:
    """Aggressive families strike more often, but never on a render/game loop."""
    return 20 * 60 + max(0, 100 - profile.aggression) * 12


async def _apply_player_war_pressure(db_path: str, telegram_id: int, now: int) -> list[dict]:
    """Resolve due, server-authoritative attacks against one player's businesses."""
    events: list[dict] = []
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        wars = await (await db.execute(
            "SELECT r.leader_id FROM npc_empire_relations r JOIN npc_empires e ON e.leader_id=r.leader_id "
            "WHERE r.telegram_id=? AND (r.pact='war' OR (r.score<0 AND r.pact NOT IN ('truce','alliance','vassal'))) "
            "AND e.status NOT IN ('ruined','vassal')",
            (telegram_id,),
        )).fetchall()
        active = {str(row['leader_id']) for row in wars}
        if active:
            await db.executemany(
                "INSERT OR IGNORE INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) VALUES(?,?,?)",
                [(leader_id, telegram_id, now + PLAYER_WAR_FIRST_STRIKE_SECONDS) for leader_id in active],
            )
        stale = await (await db.execute(
            "SELECT leader_id FROM npc_empire_player_wars WHERE telegram_id=?", (telegram_id,)
        )).fetchall()
        for row in stale:
            if str(row['leader_id']) not in active:
                await db.execute(
                    "DELETE FROM npc_empire_player_wars WHERE leader_id=? AND telegram_id=?",
                    (str(row['leader_id']), telegram_id),
                )
        has_businesses = bool(await (await db.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='player_businesses'"
        )).fetchone())
        businesses = []
        if has_businesses:
            businesses = await (await db.execute(
                "SELECT biz_id FROM player_businesses WHERE telegram_id=? ORDER BY biz_id", (telegram_id,)
            )).fetchall()
        due = await (await db.execute(
            "SELECT leader_id,attacks FROM npc_empire_player_wars "
            "WHERE telegram_id=? AND next_attack_at<=? ORDER BY next_attack_at,leader_id",
            (telegram_id, now),
        )).fetchall()
        for row in due:
            leader_id = str(row['leader_id'])
            if leader_id not in active:
                continue
            profile = PROFILE_BY_ID[leader_id]
            biz_id = ''
            if businesses:
                attack_no = int(row['attacks'] or 0)
                war_row = await (await db.execute(
                    "SELECT last_business_id FROM npc_empire_player_wars WHERE leader_id=? AND telegram_id=?",
                    (leader_id, telegram_id),
                )).fetchone()
                last_biz = str(war_row['last_business_id'] or '') if war_row else ''
                owned_ids = {str(item['biz_id']) for item in businesses}
                capture = attack_no % 2 == 1 and last_biz in owned_ids
                biz_id = last_biz if capture else str(businesses[(attack_no // 2) % len(businesses)]['biz_id'])
                if capture:
                    await db.execute(
                        "DELETE FROM player_businesses WHERE telegram_id=? AND biz_id=?",
                        (telegram_id, biz_id),
                    )
                    await db.execute(
                        "INSERT OR REPLACE INTO business_property_owners"
                        "(biz_id,owner_uid,owner_name,acquired_at,protected_until) VALUES(?,?,?,?,?)",
                        (biz_id, npc_owner_uid(leader_id), profile.gang_name, now, now + 300),
                    )
                    await db.execute(
                        "INSERT OR REPLACE INTO npc_empire_holdings"
                        "(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('business',?,?,?,?,?)",
                        (biz_id, leader_id, BUSINESS_INCOME.get(biz_id, 175), 60 + profile.loyalty, now),
                    )
                    businesses = [item for item in businesses if str(item['biz_id']) != biz_id]
                    summary = f'{profile.leader_name} и {profile.gang_name} захватили бизнес {biz_id}'
                    kind = 'player_business_captured'
                else:
                    blocked_until = now + PLAYER_WAR_BUSINESS_BLOCK_SECONDS
                    notice = f'{profile.gang_name} атаковала бизнес. Работа остановлена на 10 минут; следующий налёт может закончиться захватом.'
                    await db.execute(
                        "UPDATE player_businesses SET blocked_until=MAX(COALESCE(blocked_until,0),?),"
                        "last_event_at=?,pending_notice=? WHERE telegram_id=? AND biz_id=?",
                        (blocked_until, now, notice, telegram_id, biz_id),
                    )
                    summary = f'{profile.leader_name} и {profile.gang_name} разбомбили бизнес {biz_id}'
                    kind = 'player_business_bombed'
            else:
                summary = f'{profile.leader_name} прислал людей запугать игрока, но бизнесов у цели нет'
                kind = 'player_harassed'
            await db.execute(
                "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                (leader_id, kind, str(telegram_id), summary, now),
            )
            next_pressure_at = now + (PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS
                                      if kind == 'player_business_bombed'
                                      else _player_war_interval(profile))
            await db.execute(
                "UPDATE npc_empire_player_wars SET attacks=attacks+1,last_business_id=?,last_attack_at=?,"
                "next_attack_at=? WHERE leader_id=? AND telegram_id=?",
                (biz_id, now, next_pressure_at, leader_id, telegram_id),
            )
            events.append({'leader_id': leader_id, 'kind': kind, 'business_id': biz_id,
                           'summary': summary, 'created_at': now})
        await db.commit()
    return events


async def state_for(db_path: str, telegram_id: int, now: int | None = None) -> dict:
    now = int(now or time.time())
    await ensure_schema(db_path)
    # Resolve already-scheduled player pressure before the same timestamp's
    # global NPC tick can collapse that attacker in a separate family war.
    player_war_events = await _apply_player_war_pressure(db_path, telegram_id, now)
    await advance(db_path, now)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        rows = await (await db.execute("SELECT * FROM npc_empires ORDER BY leader_id")).fetchall()
        relations = {str(r['leader_id']): dict(r) for r in await (await db.execute(
            "SELECT * FROM npc_empire_relations WHERE telegram_id=?", (telegram_id,)
        )).fetchall()}
        holdings_rows = await (await db.execute(
            "SELECT kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area FROM npc_empire_holdings"
        )).fetchall()
        diplomacy_rows = [dict(r) for r in await (await db.execute(
            "SELECT leader_a,leader_b,score,pact,tension,last_event_at FROM npc_empire_diplomacy"
        )).fetchall()]
        recent = [dict(r) for r in await (await db.execute(
            "SELECT leader_id,kind,target_id,summary,created_at FROM npc_empire_events ORDER BY id DESC LIMIT 240"
        )).fetchall()]
        district_rows = [dict(r) for r in await (await db.execute(
            "SELECT district_id,leader_id,score,runner_up_id,runner_up_score,contested,changed_at "
            "FROM npc_empire_districts ORDER BY district_id"
        )).fetchall()]
        war_rows = {str(r['leader_id']): dict(r) for r in await (await db.execute(
            "SELECT leader_id,next_attack_at,attacks,last_business_id,last_attack_at "
            "FROM npc_empire_player_wars WHERE telegram_id=?", (telegram_id,)
        )).fetchall()}
    holdings: dict[str, list] = {p.leader_id: [] for p in PROFILES}
    for row in holdings_rows:
        item = dict(row)
        operation = str(item.get('operation_type') or '')
        if item.get('kind') == 'building' and operation in BUILDING_OPERATIONS:
            item['operation_name'] = BUILDING_OPERATIONS[operation]['name']
            item['operation_icon'] = BUILDING_OPERATIONS[operation]['icon']
            item['income_unit'] = 'minute'
            area = int(item.get('area') or 4)
            item['size_class'] = 'large' if area >= 24 else 'medium' if area >= 16 else 'small'
        holdings.setdefault(str(row['leader_id']), []).append(item)
    events_by_leader: dict[str, list[dict]] = {p.leader_id: [] for p in PROFILES}
    for event in recent:
        events_by_leader.setdefault(str(event.get('leader_id') or ''), []).append(event)
    owned_buildings = {str(item['holding_id']) for item in holdings_rows if str(item['kind']) == 'building'}
    owned_businesses = {str(item['holding_id']) for item in holdings_rows if str(item['kind']) == 'business'}
    result = []
    for row in rows:
        leader_id = str(row['leader_id'])
        profile = PROFILE_BY_ID[leader_id]
        relation = relations.get(leader_id, {})
        score = clamp_relation(relation.get('score', 0))
        hq_key = str(row['hq_key'] or '')
        hq_r, hq_c = _hq_coords(hq_key) if hq_key else (0, 0)
        leader_holdings = holdings.get(leader_id, [])
        recruitment = _recruitment_state(profile, row, now)
        leader_events = events_by_leader.get(leader_id, [])
        memory = _boss_memory_cards(leader_events, now)
        active_wars = sum(1 for pact_row in diplomacy_rows
                          if str(pact_row.get('pact') or '') == 'war'
                          and leader_id in {str(pact_row.get('leader_a')), str(pact_row.get('leader_b'))})
        if leader_id in war_rows:
            active_wars += 1
        neutral_buildings = sum(1 for key in GENERIC_BUILDINGS
                                if key not in owned_buildings and key != profile.hq_key)
        affordable_businesses = sum(1 for bid, price in BUSINESS_PRICE.items()
                                    if bid not in owned_businesses and int(row['treasury'] or 0) >= int(price * .65))
        brain = _boss_brain(
            profile, row, leader_holdings, leader_events, now,
            active_wars=active_wars, neutral_buildings=neutral_buildings,
            affordable_businesses=affordable_businesses,
        )
        result.append({
            'leader_id': leader_id, 'leader_name': profile.leader_name, 'title': profile.title,
            'gang_name': profile.gang_name, 'color': profile.color, 'accent': profile.accent,
            'emblem': profile.emblem, 'weapon_id': profile.weapon_id,
            'weapon_name': profile.weapon_name, 'weapon_base': profile.weapon_base,
            'traits': {'aggression':profile.aggression,'commerce':profile.commerce,
                       'diplomacy':profile.diplomacy,'loyalty':profile.loyalty,
                       'intelligence':(profile.commerce+profile.diplomacy+profile.loyalty)//3},
            'doctrine': boss_doctrine(leader_id),
            'treasury': int(row['treasury']), 'members': int(row['members']),
            'strength': int(row['strength']), 'status': str(row['status']),
            'hq_key': hq_key, 'hq_r': hq_r, 'hq_c': hq_c,
            'comeback_at': int(row['comeback_at'] or 0), 'comebacks': int(row['comebacks'] or 0),
            'wins': int(row['wins'] or 0), 'losses': int(row['losses'] or 0),
            'knockouts': int(row['knockouts'] or 0),
            'dominance_score': int(row['dominance_score'] or 0),
            'district_count': int(row['district_count'] or 0),
            'peak_power': int(row['peak_power'] or 0),
            'hospital_until': int(row['hospital_until'] or 0) if int(row['hospital_until'] or 0) > now else 0,
            'hospital_id': str(row['hospital_id'] or '') if int(row['hospital_until'] or 0) > now else '',
            'recruitment': recruitment,
            'relation': score, 'relation_band': relation_band(score),
            'pact': str(relation.get('pact') or 'none'),
            'war_pressure': war_rows.get(leader_id),
            'holdings': leader_holdings,
            'brain': brain,
            'memory': memory,
            'activity': _visible_activity(profile, row, leader_holdings, now, brain),
        })
    leaderboard = sorted(result, key=lambda e: (
        -e['district_count'], -e['dominance_score'], -e['strength'],
        -e['treasury'], e['leader_name'],
    ))
    for rank, empire in enumerate(leaderboard, 1):
        empire['rank'] = rank
    # A persistent NPC-vs-NPC war becomes a physical order in the shared city.
    # Target choice is deterministic inside the 75-second slot, so clients see
    # the same attacker, defender and stance without a render-loop database hit.
    empire_by_id = {str(empire['leader_id']): empire for empire in result}
    war_enemies: dict[str, list[dict]] = {leader_id: [] for leader_id in empire_by_id}
    for pact_row in diplomacy_rows:
        if str(pact_row.get('pact') or '') != 'war':
            continue
        left = empire_by_id.get(str(pact_row.get('leader_a') or ''))
        right = empire_by_id.get(str(pact_row.get('leader_b') or ''))
        if not left or not right or left['status'] == 'ruined' or right['status'] == 'ruined':
            continue
        war_enemies[left['leader_id']].append(right)
        war_enemies[right['leader_id']].append(left)
    row_by_id = {str(row['leader_id']): row for row in rows}
    for empire in result:
        enemies = war_enemies.get(empire['leader_id']) or []
        if not enemies:
            continue
        enemies.sort(key=lambda enemy: (
            int(enemy['strength']), -len(enemy.get('holdings') or []), enemy['leader_id']))
        slot = now // VISIBLE_ACTIVITY_SECONDS
        enemy = enemies[int.from_bytes(hashlib.sha256(
            f'{empire["leader_id"]}:war:{slot}'.encode()).digest()[:2], 'big') % len(enemies)]
        empire['activity'] = _war_activity(
            PROFILE_BY_ID[empire['leader_id']], row_by_id[empire['leader_id']], enemy, now)
    districts = [{
        **row, 'name': DISTRICTS.get(str(row['district_id']), str(row['district_id'])),
        'contested': bool(row['contested']),
    } for row in district_rows]
    return {'empires': result, 'leaderboard': [e['leader_id'] for e in leaderboard],
            'districts': districts, 'diplomacy': diplomacy_rows, 'events': recent[:60],
            'player_war_events': player_war_events,
            'server_time': now, 'tick_seconds': TICK_SECONDS}


async def diplomacy_action(db_path: str, telegram_id: int, leader_id: str,
                           action: str, now: int | None = None) -> dict:
    now = int(now or time.time())
    if leader_id not in PROFILE_BY_ID:
        return {'ok': False, 'error': 'unknown leader'}
    rules = {
        'respect': (0, 3, 3600),
        'gift': (500, 12, 0),
        'apologize': (0, 8, 3 * 3600),
        'compensation': (1500, 30, 0),
        'insult': (0, -10, 900),
        'threaten': (0, -18, 1800),
        'street_attack': (0, -12, 0),
        'declare_war': (0, -200, 0),
        'truce': (300, 8, 0),
        'alliance': (1000, 5, 0),
        'break_pact': (0, -20, 0),
    }
    if action not in rules:
        return {'ok': False, 'error': 'bad action'}
    await ensure_schema(db_path)
    cost, delta, cooldown = rules[action]
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        empire = await (await db.execute("SELECT status FROM npc_empires WHERE leader_id=?", (leader_id,))).fetchone()
        if not empire or empire['status'] == 'ruined':
            await db.rollback(); return {'ok': False, 'error': 'leader rebuilding'}
        rel = await (await db.execute(
            "SELECT score,pact,last_action_at FROM npc_empire_relations WHERE leader_id=? AND telegram_id=?",
            (leader_id, telegram_id),
        )).fetchone()
        score = int(rel['score'] if rel else 0); pact = str(rel['pact'] if rel else 'none')
        if cooldown and rel and now - int(rel['last_action_at'] or 0) < cooldown:
            await db.rollback(); return {'ok': False, 'error': 'cooldown', 'retry_after': cooldown-(now-int(rel['last_action_at']))}
        if action == 'alliance' and score < 60:
            await db.rollback(); return {'ok': False, 'error': 'relation too low', 'required': 60}
        if action == 'truce' and score < -60:
            await db.rollback(); return {'ok': False, 'error': 'relation too low', 'required': -60}
        if action == 'declare_war' and score >= 0:
            await db.rollback(); return {'ok': False, 'error': 'war requires negative relation', 'required': -1}
        if action == 'declare_war' and pact == 'war':
            await db.rollback(); return {'ok': False, 'error': 'already at war'}
        char = await (await db.execute("SELECT cash FROM characters WHERE telegram_id=?", (telegram_id,))).fetchone()
        cash = int(char['cash'] if char else 0)
        if cost and cash < cost:
            await db.rollback(); return {'ok': False, 'error': 'no cash', 'cost': cost, 'cash': cash}
        if cost:
            await db.execute("UPDATE characters SET cash=cash-? WHERE telegram_id=?", (cost, telegram_id))
        if action == 'declare_war': score = -100; pact = 'war'
        elif action == 'street_attack': score = min(-1, clamp_relation(score + delta)); pact = 'war'
        elif action == 'alliance': score = clamp_relation(score + delta); pact = 'alliance'
        elif action == 'truce': score = max(-20, clamp_relation(score + delta)); pact = 'truce'
        elif action == 'break_pact': score = clamp_relation(score + delta); pact = 'none'
        else:
            score = clamp_relation(score + delta)
            if action == 'compensation' and pact == 'war' and score >= -60: pact = 'truce'
            elif pact == 'war' and score > -21: pact = 'none'
        await db.execute(
            "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,?,?,?) "
            "ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=excluded.score,pact=excluded.pact,last_action_at=excluded.last_action_at",
            (leader_id, telegram_id, score, pact, now),
        )
        if pact == 'war':
            await db.execute(
                "INSERT INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) VALUES(?,?,?) "
                "ON CONFLICT(leader_id,telegram_id) DO NOTHING",
                (leader_id, telegram_id, now + PLAYER_WAR_FIRST_STRIKE_SECONDS),
            )
        else:
            await db.execute(
                "DELETE FROM npc_empire_player_wars WHERE leader_id=? AND telegram_id=?",
                (leader_id, telegram_id),
            )
        summary = (f'Игрок атаковал людей семьи: отношение {score:+d}'
                   if action == 'street_attack' else f'{action}: отношение {score:+d}')
        await db.execute(
            "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
            (leader_id, 'player_attack' if action == 'street_attack' else 'diplomacy',
             str(telegram_id), summary, now),
        )
        await db.commit()
    return {'ok': True, 'leader_id': leader_id, 'action': action, 'relation': score,
            'relation_band': relation_band(score), 'pact': pact, 'cost': cost, 'cash': cash-cost}


async def prepare_assault(db_path: str, telegram_id: int, leader_id: str,
                          player_r: float, player_c: float, now: int | None = None) -> dict:
    now = int(now or time.time())
    profile = PROFILE_BY_ID.get(leader_id)
    if not profile:
        return {'ok': False, 'error': 'unknown leader'}
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        row = await (await db.execute("SELECT * FROM npc_empires WHERE leader_id=?", (leader_id,))).fetchone()
        if not row or row['status'] == 'ruined' or not row['hq_key']:
            await db.rollback(); return {'ok': False, 'error': 'no headquarters'}
        hq_r, hq_c = _hq_coords(str(row['hq_key']))
        if (player_r-hq_r)**2 + (player_c-hq_c)**2 > 36:
            await db.rollback(); return {'ok': False, 'error': 'too far'}
        active = await (await db.execute(
            "SELECT token FROM npc_empire_assaults WHERE telegram_id=? AND leader_id=? AND status='active' AND expires_at>?",
            (telegram_id, leader_id, now),
        )).fetchone()
        if active:
            await db.execute("UPDATE npc_empire_assaults SET status='abandoned' WHERE token=?", (active['token'],))
        members = int(row['members']); strength = int(row['strength'])
        guard_count = max(4, min(14, 3 + members // 2))
        guard_max = 85 + strength // 8
        guards = [guard_max + (i % 3) * 14 for i in range(guard_count)]
        boss_max = 240 + strength + profile.aggression * 2
        token = secrets.token_urlsafe(18)
        await db.execute(
            "INSERT INTO npc_empire_assaults(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,status,started_at,expires_at) VALUES(?,?,?,?,?,?, 'active',?,?)",
            (token, telegram_id, leader_id, json.dumps(guards), boss_max, boss_max, now, now+ASSAULT_SECONDS),
        )
        await db.execute(
            "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,-100,'war',?) "
            "ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=-100,pact='war',last_action_at=excluded.last_action_at",
            (leader_id, telegram_id, now),
        )
        await db.execute(
            "INSERT INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) VALUES(?,?,?) "
            "ON CONFLICT(leader_id,telegram_id) DO NOTHING",
            (leader_id, telegram_id, now + PLAYER_WAR_FIRST_STRIKE_SECONDS),
        )
        await db.execute(
            "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
            (leader_id, 'assault_started', str(telegram_id), f'Начат штурм штаба {profile.gang_name}', now),
        )
        await db.commit()
    return {'ok': True, 'token': token, 'leader_id': leader_id, 'leader_name': profile.leader_name,
            'gang_name': profile.gang_name, 'hq_r': hq_r, 'hq_c': hq_c,
            'guards': [{'id':i,'hp':hp,'max_hp':hp,'weapon':profile.weapon_base} for i,hp in enumerate(guards)],
            'boss': {'hp':boss_max,'max_hp':boss_max,'weapon':profile.weapon_base,
                     'weapon_id':profile.weapon_id,'weapon_name':profile.weapon_name},
            'expires_at': now+ASSAULT_SECONDS}


async def assault_hit(db_path: str, telegram_id: int, token: str, target: str,
                      target_id: int | None, damage: int, now: float | None = None) -> dict:
    now_f = float(now or time.time()); now_i = int(now_f)
    damage = max(1, min(35, int(damage or 1)))
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        row = await (await db.execute("SELECT * FROM npc_empire_assaults WHERE token=? AND telegram_id=?", (token, telegram_id))).fetchone()
        if not row or row['status'] != 'active' or int(row['expires_at']) <= now_i:
            await db.rollback(); return {'ok': False, 'error': 'invalid assault'}
        if now_f - float(row['last_hit_at'] or 0) < .11:
            await db.rollback(); return {'ok': False, 'error': 'rate limit'}
        guards = [max(0, int(x)) for x in json.loads(row['guard_hp_json'])]
        boss_hp = int(row['boss_hp'])
        if target == 'guard':
            try: idx = int(target_id)
            except Exception: idx = -1
            if idx < 0 or idx >= len(guards) or guards[idx] <= 0:
                await db.rollback(); return {'ok': False, 'error': 'bad target'}
            guards[idx] = max(0, guards[idx] - damage)
        elif target == 'boss':
            if any(hp > 0 for hp in guards):
                await db.rollback(); return {'ok': False, 'error': 'guards alive'}
            boss_hp = max(0, boss_hp - damage)
        else:
            await db.rollback(); return {'ok': False, 'error': 'bad target'}
        await db.execute(
            "UPDATE npc_empire_assaults SET guard_hp_json=?,boss_hp=?,last_hit_at=? WHERE token=?",
            (json.dumps(guards), boss_hp, now_f, token),
        )
        await db.commit()
    return {'ok': True, 'guards': guards, 'boss_hp': boss_hp,
            'boss_max_hp': int(row['boss_max_hp']), 'victory': boss_hp <= 0}


async def resolve_assault(db_path: str, telegram_id: int, token: str,
                          choice: str, now: int | None = None) -> dict:
    """Resolve once: annex businesses, loot the treasury, or vassalize."""
    now = int(now or time.time())
    if choice not in {'annex','loot','vassalize'}:
        return {'ok': False, 'error': 'bad choice'}
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        assault = await (await db.execute("SELECT * FROM npc_empire_assaults WHERE token=? AND telegram_id=?", (token,telegram_id))).fetchone()
        if not assault or assault['status'] != 'active' or int(assault['boss_hp']) > 0:
            await db.rollback(); return {'ok': False, 'error': 'not won'}
        leader_id = str(assault['leader_id']); profile = PROFILE_BY_ID[leader_id]
        empire = await (await db.execute("SELECT * FROM npc_empires WHERE leader_id=?", (leader_id,))).fetchone()
        treasury = int(empire['treasury'] or 0); reward = 0; captured = []
        if choice == 'vassalize':
            await db.execute("UPDATE npc_empires SET status='vassal',members=MAX(2,members/2),strength=MAX(40,strength/2),treasury=treasury/2,defeated_by=?,version=version+1 WHERE leader_id=?", (telegram_id,leader_id))
            await db.execute("INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?, ?,80,'vassal',?) ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=80,pact='vassal',last_action_at=excluded.last_action_at", (leader_id,telegram_id,now))
            reward = treasury // 2
        else:
            reward = treasury if choice == 'loot' else treasury // 3
            business_rows = await (await db.execute("SELECT holding_id FROM npc_empire_holdings WHERE leader_id=? AND kind='business'", (leader_id,))).fetchall()
            if choice == 'annex':
                for item in business_rows:
                    biz_id = str(item['holding_id']); captured.append(biz_id)
                    await db.execute("DELETE FROM player_businesses WHERE biz_id=?", (biz_id,))
                    await db.execute("INSERT INTO player_businesses(telegram_id,biz_id,bought_at,last_collect,status,blocked_until,last_event_at,level,guards,pending_notice) VALUES(?,?,?,?, 'ok',0,0,1,0,?)", (telegram_id,biz_id,now,now,f'Отнят у банды {profile.gang_name}'))
                    await db.execute("INSERT OR REPLACE INTO business_property_owners(biz_id,owner_uid,owner_name,acquired_at,protected_until) VALUES(?,?,?,?,?)", (biz_id,telegram_id,'Победитель штаба',now,now+300))
            else:
                for item in business_rows:
                    await db.execute("DELETE FROM business_property_owners WHERE biz_id=? AND owner_uid=?", (str(item['holding_id']),npc_owner_uid(leader_id)))
            comeback_at = await _collapse_empire(
                db, leader_id, now, telegram_id,
                f'{profile.gang_name} разгромлены игроком; {profile.leader_name} начинает со дна',
                preserve_businesses=(choice == 'annex'),
            )
        if reward:
            await db.execute("UPDATE characters SET cash=cash+? WHERE telegram_id=?", (reward,telegram_id))
        await db.execute("UPDATE npc_empire_assaults SET status='resolved',resolution=? WHERE token=?", (choice,token))
        await db.execute("INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)", (leader_id,'assault_won',str(telegram_id),f'{profile.gang_name}: {choice}',now))
        char = await (await db.execute("SELECT cash FROM characters WHERE telegram_id=?", (telegram_id,))).fetchone()
        await db.commit()
    return {'ok': True, 'choice': choice, 'leader_id': leader_id, 'reward': reward,
            'comeback_at': comeback_at if choice != 'vassalize' else 0,
            'captured_businesses': captured, 'cash': int(char['cash'] if char else reward)}
