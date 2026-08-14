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
NPC_DIPLOMACY_PEACE_STEP_SECONDS = 6 * 60 * 60
ASSAULT_SECONDS = 20 * 60
COMEBACK_MIN_SECONDS = 30 * 60
COMEBACK_MAX_SECONDS = 90 * 60
RELATION_MIN = -100
RELATION_MAX = 100
NPC_PACT_LABELS = {
    'none': 'нейтралитет', 'war': 'война', 'truce': 'перемирие',
    'alliance': 'союз', 'vassal': 'подчинение',
}
NPC_OWNER_BASE = -900_000
PLAYER_WAR_FIRST_STRIKE_SECONDS = 5 * 60
PLAYER_WAR_BUSINESS_BLOCK_SECONDS = 10 * 60
PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS = 10 * 60
PLAYER_INTERIOR_RAID_MIN_SECONDS = 45
PLAYER_INTERIOR_RAID_HOLD_SECONDS = 20
PLAYER_INTERIOR_RAID_EXPIRES_SECONDS = 12 * 60
PLAYER_INTERIOR_RAID_MAX_ATTACKERS = 8
PLAYER_INTERIOR_RAID_MAX_DEFENDERS = 12
VISIBLE_ACTIVITY_SECONDS = 75
NPC_EMPIRE_MAX_FIGHTERS = 20
RECRUITMENT_SECONDS = 0
NPC_BUILDING_SABOTAGE_SECONDS = 5 * 60
NPC_MEMBER_UPKEEP_PER_TICK = 3
NPC_HOLDING_GUARD_UPKEEP_PER_TICK = 6
NPC_ACTIVE_WAR_UPKEEP_PER_TICK = 18
NPC_BANKRUPTCY_DESERTION_TICKS = 2
NPC_WAR_IDLE_TRUCE_SECONDS = 3 * 24 * 60 * 60
NPC_WAR_EXHAUSTION_TENSION = 100
NPC_TRUCE_SCORE = -35
NPC_OPERATING_RESERVE_TICKS = 12
NPC_RECOVERY_STIPEND_PER_TICK = 600
NPC_RECOVERY_STIPEND_TICKS = 12
NPC_HQ_FRONT_INCOME_PER_MINUTE = 24
NPC_LIQUIDITY_BUFFER_TICKS = 96
NPC_MIN_LIQUIDITY_CEILING = 75_000
NPC_EVENT_MEMORY_LIMIT = 80


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
# Six original headquarters sit inside the prison/lair clear zones, where the
# client deliberately has no building footprint.  Existing databases migrate
# both the empire row and its HQ holding through this explicit mapping.
HQ_KEY_MIGRATIONS = {
    'rustam': ('8,6', '8,2'),
    'arsen': ('11,2', '9,5'),
    'damir': ('13,5', '2,6'),
    'zara': ('10,6', '8,4'),
    'boris': ('8,7', '5,6'),
    'roman': ('10,4', '5,4'),
}
PROFILES = tuple(replace(
    profile,
    leader_name=MAFIA_BOSS_NAMES[profile.leader_id],
    hq_key=HQ_KEY_MIGRATIONS.get(profile.leader_id, ('', profile.hq_key))[1],
)
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

# Cognitive temperament used by both strategic scoring and the client combat
# planner.  Every triple is unique, so two leaders with the same immediate
# order still execute it with different patience, adaptability and courage.
BOSS_MINDSETS = {
    'leila': {'patience':.82,'adaptability':.76,'courage':.46},
    'rustam':{'patience':.48,'adaptability':.61,'courage':.88},
    'marco': {'patience':.34,'adaptability':.91,'courage':.74},
    'vera':  {'patience':.89,'adaptability':.83,'courage':.39},
    'arsen': {'patience':.72,'adaptability':.58,'courage':.81},
    'damir': {'patience':.61,'adaptability':.79,'courage':.69},
    'marat': {'patience':.94,'adaptability':.42,'courage':.72},
    'zara':  {'patience':.91,'adaptability':.68,'courage':.31},
    'niko':  {'patience':.86,'adaptability':.88,'courage':.52},
    'alisa': {'patience':.57,'adaptability':.96,'courage':.63},
    'boris': {'patience':.43,'adaptability':.66,'courage':.91},
    'inga':  {'patience':.84,'adaptability':.71,'courage':.55},
    'timur': {'patience':.64,'adaptability':.93,'courage':.67},
    'emil':  {'patience':.22,'adaptability':.54,'courage':.98},
    'roman': {'patience':.78,'adaptability':.49,'courage':.86},
    'sofia': {'patience':.93,'adaptability':.87,'courage':.28},
    'viktor':{'patience':.74,'adaptability':.94,'courage':.77},
    'yana':  {'patience':.69,'adaptability':.98,'courage':.62},
    'musa':  {'patience':.88,'adaptability':.73,'courage':.58},
}

# A strategic priority is not a literal 24/7 destination.  These field jobs
# make peaceful leaders execute the same high-level plan in recognisably
# different ways while the rotating execution window prevents all nineteen
# families from converging on one venue in the same visible activity slot.
BOSS_FIELD_JOBS = {
    'leila':'ПРОВЕРЯЕТ МЕДПУНКТЫ', 'rustam':'ГОТОВИТ ЗАСАДУ',
    'marco':'РАЗВЕДЫВАЕТ МАРШРУТ', 'vera':'ВЕДЁТ ПЕРЕГОВОРЫ',
    'arsen':'ПРОВЕРЯЕТ ОГНЕВЫЕ ТОЧКИ', 'damir':'ВСТРЕЧАЕТСЯ С ЛЮДЬМИ',
    'marat':'ПРОВЕРЯЕТ ОБОРОНУ', 'zara':'ОЦЕНИВАЕТ ДОХОДНОСТЬ',
    'niko':'ВЕДЁТ ДАЛЬНЮЮ РАЗВЕДКУ', 'alisa':'ПРОВЕРЯЕТ СВЯЗЬ',
    'boris':'ИЩЕТ СЛАБОЕ ЗВЕНО', 'inga':'ИЗУЧАЕТ ТЕРРИТОРИЮ',
    'timur':'ПРОВЕРЯЕТ СНАБЖЕНИЕ', 'emil':'ИЩЕТ СОПЕРНИКА',
    'roman':'ПРОВЕРЯЕТ БРОНЕПОСТЫ', 'sofia':'СОБИРАЕТ СВЕДЕНИЯ',
    'viktor':'ВЫСЛЕЖИВАЕТ ЦЕЛЬ', 'yana':'КООРДИНИРУЕТ ПОСТЫ',
    'musa':'ПРОВЕРЯЕТ МАРШРУТЫ СНАБЖЕНИЯ',
}


def boss_doctrine(leader_id: str) -> dict:
    """Return a copy-safe doctrine for API clients and deterministic tests."""
    doctrine = BOSS_DOCTRINES[str(leader_id)]
    return {**doctrine, 'orders': list(doctrine['orders']),
            'strategy_bias': dict(doctrine['strategy_bias']),
            'mindset': dict(BOSS_MINDSETS[str(leader_id)])}
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
    'northside': 'Норт-Сайд', 'downtown': 'Даунтаун',
    'southside': 'Саутсайд', 'industrial': 'Промзона',
    'eastside': 'Ист-Сайд', 'docklands': 'Доклендс',
    'lair': 'Логово', 'coast': 'Побережье',
}
BUSINESS_DISTRICTS = {
    'coffee':'northside', 'carwash':'northside', 'barbershop':'southside',
    'pizza':'southside', 'garage':'southside', 'bar':'southside',
    'club':'southside', 'warehouse':'southside', 'casino':'downtown', 'port':'coast',
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
    'beer_bar': {'name': 'Пивной бар', 'icon': '🍺', 'base_income': 70, 'fitout_cost': 2500},
    'pawnshop': {'name': 'Скупка краденого', 'icon': '💎', 'base_income': 85, 'fitout_cost': 3600},
    'bookmaker': {'name': 'Букмекерская', 'icon': '🎟️', 'base_income': 95, 'fitout_cost': 4800},
    'strip_club': {'name': 'Стрип-клуб', 'icon': '💃', 'base_income': 120, 'fitout_cost': 7200},
    'gun_shop': {'name': 'Оружейная лавка', 'icon': '🔫', 'base_income': 130, 'fitout_cost': 8500},
    'chop_shop': {'name': 'Авторазборка', 'icon': '🔧', 'base_income': 145, 'fitout_cost': 9800},
    'poker_club': {'name': 'Подпольный покер', 'icon': '♠️', 'base_income': 160, 'fitout_cost': 11000},
    'print_shop': {'name': 'Фальшивая типография', 'icon': '🖨️', 'base_income': 175, 'fitout_cost': 13500},
}
BUILDING_HQ_FITOUT_COST = 9000
CAPTURED_HQ_AREA = 27

BUILDING_DISTRICT_PRICES = {
    'poor': 3500, 'lair': 5500, 'industrial': 7000,
    'countryside': 8500, 'nightlife': 14000, 'downtown': 18000,
    'coast': 24000, 'rich': 32000, 'standard': 6500,
}


def building_operation_income(operation_type: str, area: int) -> int:
    base = int(BUILDING_OPERATIONS.get(operation_type, BUILDING_OPERATIONS['beer_bar'])['base_income'])
    return min(200, base + round(max(0, min(27, int(area or 4)) - 4) * 25 / 23))


def building_purchase_price(shell_price: int, property_kind: str,
                            operation_type: str = '', area: int = 4) -> int:
    """Authoritative shell + conversion cost; area adds a bounded contractor fee."""
    shell = max(0, int(shell_price or 0))
    if property_kind == 'hq':
        fitout = BUILDING_HQ_FITOUT_COST
    else:
        meta = BUILDING_OPERATIONS.get(str(operation_type or ''))
        if not meta:
            return 0
        fitout = int(meta['fitout_cost'])
    area_fee = max(0, min(27, int(area or 4)) - 4) * 90
    return shell + fitout + area_fee


def building_shell_price(building_key: str) -> int:
    """Mirror the generic-building district shell price from the world API."""
    try:
        br_text, bc_text = str(building_key).split(',', 1)
        r, c = int(br_text) * 10 + 6, int(bc_text) * 10 + 6
    except (TypeError, ValueError):
        return 0
    if 0 <= r <= 39 and 40 <= c <= 79: district = 'downtown'
    elif 0 <= r <= 39 and 0 <= c <= 39: district = 'poor'
    elif 40 <= r <= 59 and 0 <= c <= 39: district = 'nightlife'
    elif 60 <= r <= 79 and 0 <= c <= 39: district = 'rich'
    elif 80 <= r <= 99 and 0 <= c <= 39: district = 'countryside'
    elif 40 <= r <= 99 and 40 <= c <= 79: district = 'industrial'
    elif 100 <= r <= 149 and 0 <= c <= 79: district = 'lair'
    elif 150 <= r <= 199 and 0 <= c <= 79: district = 'coast'
    else: district = 'standard'
    return BUILDING_DISTRICT_PRICES[district]


def npc_building_sale_price(building_key: str, operation_type: str, area: int) -> int:
    base = building_purchase_price(
        building_shell_price(building_key), 'business', operation_type, area)
    return max(1, int(round(base * 1.6 / 10.0) * 10))


def npc_building_sale_chance(relation: int, pact: str = 'none') -> int:
    """Negative relations never sell; neutral is 50%, positive is 70-90%."""
    score = clamp_relation(relation)
    if score < 0 or str(pact or 'none') == 'war':
        return 0
    if score == 0:
        return 50
    if score < 40:
        return 70
    if score < 70:
        return 80
    return 90


def choose_building_operation(profile: EmpireProfile, building_key: str,
                              capture_nonce: int = 0) -> str:
    """Choose one of all eight skins with a replay-safe server random roll."""
    operations = tuple(BUILDING_OPERATIONS)
    seed = int.from_bytes(hashlib.sha256(f'{profile.leader_id}:{building_key}:{capture_nonce}'.encode()).digest()[:4], 'big')
    return operations[seed % len(operations)]


def choose_captured_building_operation(profile: EmpireProfile, building_key: str,
                                       previous_operation: str,
                                       capture_nonce: int = 0) -> str:
    """A takeover visibly rebrands the venue instead of inheriting its old skin."""
    chosen = choose_building_operation(profile, building_key, capture_nonce)
    previous = str(previous_operation or '')
    if chosen != previous:
        return chosen
    alternatives = [key for key in BUILDING_OPERATIONS if key != previous]
    seed = int.from_bytes(hashlib.sha256(
        f'rebrand:{profile.leader_id}:{building_key}:{capture_nonce}'.encode()
    ).digest()[:4], 'big')
    return alternatives[seed % len(alternatives)]


def empire_holding_income_per_tick(holdings) -> int:
    """Return authoritative revenue for one five-minute empire tick.

    Converted generic buildings advertise and store income per minute.  Legacy
    landmark businesses keep their older daily-scale values, so the two kinds
    must not be passed through the same divisor.
    """
    minutes = max(1, TICK_SECONDS // 60)
    building_income = sum(int(item['income'] or 0) for item in holdings
                          if str(item['kind']) in {'building', 'hq'})
    legacy_income = sum(int(item['income'] or 0) for item in holdings
                        if str(item['kind']) == 'business')
    return building_income * minutes + legacy_income // 288


def holding_open_ticks(last_tick: int, ticks: int, closed_from: int = 0,
                       closed_until: int = 0) -> int:
    """Count whole economy intervals that do not overlap a CLOSED window."""
    if ticks <= 0 or closed_until <= closed_from:
        return max(0, ticks)
    open_ticks = 0
    for offset in range(max(0, ticks)):
        interval_start = int(last_tick) + offset * TICK_SECONDS
        interval_end = interval_start + TICK_SECONDS
        if interval_end <= closed_from or interval_start >= closed_until:
            open_ticks += 1
    return open_ticks


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


async def _player_business_targets(db, telegram_id: int) -> list[dict]:
    """Return every server-owned player business in one stable target format.

    Legacy landmark businesses and converted generic buildings used to live in
    separate tables.  Player wars therefore saw only the former and ignored
    the eight operation types completely.
    """
    targets: list[dict] = []
    try:
        rows = await (await db.execute(
            "SELECT biz_id FROM player_businesses WHERE telegram_id=? ORDER BY biz_id",
            (telegram_id,),
        )).fetchall()
        targets.extend({
            'ref': f'business:{str(row[0])}', 'kind': 'business',
            'holding_id': str(row[0]), 'operation_type': '', 'area': 0,
            'income': int(BUSINESS_INCOME.get(str(row[0]), 175)),
        } for row in rows)
    except Exception:
        pass
    try:
        rows = await (await db.execute(
            "SELECT apt_key,operation_type,area,income_per_minute FROM apartments_owned "
            "WHERE telegram_id=? AND property_kind='business' ORDER BY apt_key",
            (telegram_id,),
        )).fetchall()
        for row in rows:
            building_key = _apartment_key_building_key(str(row[0]))
            operation = str(row[1] or '')
            if building_key not in BUILDING_AREAS or operation not in BUILDING_OPERATIONS:
                continue
            area = max(4, int(row[2] or BUILDING_AREAS[building_key]))
            targets.append({
                'ref': f'building:{building_key}', 'kind': 'building',
                'holding_id': building_key, 'apt_key': str(row[0]),
                'operation_type': operation, 'area': area,
                'income': building_operation_income(operation, area),
            })
    except Exception:
        pass
    # One indexed, player-scoped read supplies the exact defence snapshot used
    # by target selection. Guard assignment and raid creation both take an
    # IMMEDIATE transaction, so this score cannot race the persisted roster.
    try:
        guard_rows = await (await db.execute(
            "SELECT holding_ref,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id=?",
            (str(telegram_id),),
        )).fetchall()
        guards = {str(row[0]): max(0, int(row[1] or 0)) for row in guard_rows}
    except Exception:
        guards = {}
    for target in targets:
        target['guard_count'] = guards.get(str(target['ref']), 0)
    return sorted(targets, key=lambda item: (str(item['kind']), str(item['holding_id'])))


def _player_business_target_point(target: dict) -> tuple[float, float]:
    holding_id = str(target.get('holding_id') or '')
    if str(target.get('kind') or '') == 'business':
        return BUSINESS_COORDS.get(holding_id, (0.0, 0.0))
    return _hq_coords(holding_id)


def _select_player_business_target(targets: list[dict], attacks: int,
                                   last_ref: str = '') -> dict | None:
    if not targets:
        return None
    by_ref = {str(item['ref']): item for item in targets}
    # Compatibility with rows written before target kinds were namespaced.
    if last_ref and ':' not in last_ref:
        legacy = by_ref.get(f'business:{last_ref}') or by_ref.get(f'building:{last_ref}')
        if legacy:
            last_ref = str(legacy['ref'])
    if int(attacks or 0) % 2 == 1 and last_ref in by_ref:
        return by_ref[last_ref]
    return targets[(max(0, int(attacks or 0)) // 2) % len(targets)]


def allocate_physical_roster(*, side: str, roster_available: int, members: int,
                             strength: int, treasury: int, aggression: int,
                             guard_level: int = 0) -> dict:
    """Allocate only real roster slots to one bounded interior assault.

    The same contract works for NPC attackers/defenders and player hired gangs.
    Holding guards are a separate first line and never inflate the real roster.
    """
    available = max(0, min(int(roster_available), int(members)))
    if side == 'attacker':
        desired = 2 + min(6, (max(0, int(strength)) // 85
                              + max(0, int(aggression)) // 28
                              + max(0, int(treasury)) // 18_000))
        unit_cost = 70 + max(0, int(strength)) // 35 + max(0, int(aggression)) // 8
        count = min(PLAYER_INTERIOR_RAID_MAX_ATTACKERS, available, desired,
                    max(0, int(treasury)) // max(1, unit_cost))
        quality_score = min(100, (max(0, int(strength)) * 3
                                  // max(2, int(members) * 2))
                            + max(0, int(aggression)) // 2
                            + min(25, max(0, int(treasury)) // 4000))
    else:
        count = min(PLAYER_INTERIOR_RAID_MAX_DEFENDERS, available)
        unit_cost = 0
        quality_score = min(100, max(0, int(strength)) * 3
                            // max(2, int(members) * 2))
    tier = 1 + int(quality_score >= 38) + int(quality_score >= 66)
    weapon_budget = 180 + tier * 170 + max(0, quality_score - 30) * 5
    return {
        'count': count, 'cost': count * unit_cost,
        'tier': tier, 'quality': quality_score,
        'hp': 70 + tier * 20 + quality_score // 5,
        'accuracy': round(min(.86, .44 + tier * .08 + quality_score / 500), 3),
        'weapon_budget': min(950, weapon_budget),
        'guard_count': (1 + min(2, max(0, int(guard_level)) // 2)
                        if int(guard_level) >= 0 else 0),
    }


async def _npc_attack_allocation(db, leader_id: str) -> dict | None:
    """Return the paid, currently free assault roster for one family."""
    profile = PROFILE_BY_ID.get(str(leader_id))
    empire = await (await db.execute(
        "SELECT members,strength,treasury FROM npc_empires WHERE leader_id=?",
        (leader_id,))).fetchone()
    if not profile or not empire:
        return None
    assigned = await _assigned_guard_count(db, 'npc', leader_id)
    committed = int((await (await db.execute(
        "SELECT COALESCE(SUM(force),0) FROM npc_empire_interior_raids "
        "WHERE leader_id=? AND status='pending'", (leader_id,))).fetchone())[0] or 0)
    free_attackers = max(0, int(empire['members'] or 0) - assigned - committed)
    allocation = allocate_physical_roster(
        side='attacker', roster_available=free_attackers,
        members=int(empire['members'] or 0), strength=int(empire['strength'] or 0),
        treasury=int(empire['treasury'] or 0), aggression=profile.aggression)
    return {**allocation, 'free': free_attackers,
            'members': int(empire['members'] or 0),
            'strength': int(empire['strength'] or 0),
            'treasury': int(empire['treasury'] or 0)}


def score_player_business_target(target: dict, *, distance: float, guards: int,
                                 force: int, quality: int, relation: int,
                                 aggression: int) -> dict:
    """Estimate raid value and losses without inventing either side's roster."""
    force = max(0, int(force)); guards = max(0, int(guards))
    quality = max(0, min(100, int(quality)))
    hostility = max(0, -clamp_relation(relation))
    aggression = max(0, min(100, int(aggression)))
    unit_power = 80 + quality
    attack_power = force * unit_power
    defense_power = guards * 115
    expected_losses = (0 if not guards else
                       min(force, (defense_power + unit_power - 1) // unit_power))
    loss_budget = max(1, int(force * (
        .30 + aggression / 250 + hostility / 400))) if force else 0
    power_tolerance = 100 + aggression // 2 + hostility // 3
    feasible = (force >= 2 and expected_losses <= loss_budget
                and defense_power * 100 <= attack_power * power_tolerance)
    income = max(0, int(target.get('income') or 0))
    income_value = min(600, int(income ** .5 * 8))
    score = (income_value - int(max(0.0, float(distance)) * 1.5)
             - guards * 35 - expected_losses * 55
             + hostility // 4 + aggression // 5)
    return {'score': score, 'feasible': feasible,
            'expected_losses': expected_losses, 'loss_budget': loss_budget,
            'attack_power': attack_power, 'defense_power': defense_power,
            'distance': round(max(0.0, float(distance)), 2), 'guards': guards}


async def _select_player_business_target_smart(
        db, telegram_id: int, leader_id: str, targets: list[dict], attacks: int,
        last_ref: str = '') -> dict | None:
    """Pick a profitable reachable target, or defer an irrational assault."""
    if not targets:
        return None
    profile = PROFILE_BY_ID.get(str(leader_id))
    allocation = await _npc_attack_allocation(db, leader_id)
    if not profile or not allocation or int(allocation['count']) < 2:
        return None
    relation_row = await (await db.execute(
        "SELECT score FROM npc_empire_relations WHERE leader_id=? AND telegram_id=?",
        (leader_id, telegram_id))).fetchone()
    relation = int(relation_row[0] or 0) if relation_row else 0
    origin_points = [_hq_coords(profile.hq_key)]
    for row in await (await db.execute(
            "SELECT kind,holding_id FROM npc_empire_holdings WHERE leader_id=?",
            (leader_id,))).fetchall():
        kind, holding_id = str(row[0]), str(row[1])
        if kind == 'business':
            origin_points.append(BUSINESS_COORDS.get(holding_id, _hq_coords(profile.hq_key)))
        elif kind in {'building', 'hq'}:
            try:
                origin_points.append(_hq_coords(holding_id))
            except (TypeError, ValueError):
                pass
    ranked = []
    for target in targets:
        point = _player_business_target_point(target)
        distance = min(((point[0]-origin[0]) ** 2 + (point[1]-origin[1]) ** 2) ** .5
                       for origin in origin_points)
        metrics = score_player_business_target(
            target, distance=distance,
            guards=max(0, int(target.get('guard_count') or 0)),
            force=int(allocation['count']), quality=int(allocation['quality']),
            relation=relation, aggression=profile.aggression)
        ranked.append(({**target, '_raid': metrics}, metrics))
    feasible = [(target, metrics) for target, metrics in ranked if metrics['feasible']]
    if not feasible:
        return None
    feasible.sort(key=lambda item: (-int(item[1]['score']), str(item[0]['ref'])))
    best = feasible[0][0]
    by_ref = {str(target['ref']): (target, metrics) for target, metrics in feasible}
    if last_ref and ':' not in last_ref:
        last_ref = next((ref for ref in by_ref if ref.endswith(f':{last_ref}')), last_ref)
    previous = by_ref.get(str(last_ref))
    # A follow-up may stay on the damaged venue, but not when it became much
    # riskier or markedly worse than a newly available target.
    if int(attacks or 0) % 2 == 1 and previous:
        previous_target, previous_metrics = previous
        if int(previous_metrics['score']) >= int(best['_raid']['score']) - 70:
            return previous_target
    return best


async def assign_holding_guards(db_path: str, *, owner_kind: str, owner_id: str,
                                holding_ref: str, requested: int,
                                now: int | None = None) -> dict:
    """Atomically move living fighters between mobile reserve and one holding."""
    now = int(now or time.time()); requested = max(0, int(requested))
    if owner_kind not in {'npc', 'player'} or not owner_id or not holding_ref:
        return {'ok': False, 'error': 'bad assignment'}
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row; await db.execute('BEGIN IMMEDIATE')
        district_assigned = 0; district_ids: set[int] = set()
        if owner_kind == 'npc':
            row = await (await db.execute(
                "SELECT members FROM npc_empires WHERE leader_id=? AND status!='ruined'",
                (owner_id,))).fetchone()
            owned = await (await db.execute(
                "SELECT 1 FROM npc_empire_holdings WHERE leader_id=? "
                "AND kind||':'||holding_id=?", (owner_id, holding_ref))).fetchone()
            if not owned:
                await db.rollback(); return {'ok': False, 'error': 'holding not owned'}
            total = int(row['members'] or 0) if row else 0
        else:
            owned_refs = {str(item['ref']) for item in
                          await _player_business_targets(db, int(owner_id))}
            if holding_ref not in owned_refs:
                await db.rollback(); return {'ok': False, 'error': 'holding not owned'}
            try:
                living_rows = await (await db.execute(
                    "SELECT id FROM gang_members WHERE telegram_id=? "
                    "AND (current_hp IS NULL OR current_hp>0) ORDER BY id",
                    (int(owner_id),))).fetchall()
                living_ids = [int(row[0]) for row in living_rows]
                total = len(living_ids)
                try:
                    district_rows = await (await db.execute(
                        "SELECT guard_json FROM district_control WHERE telegram_id=?",
                        (int(owner_id),))).fetchall()
                    for district_row in district_rows:
                        district_ids.update(int(member_id) for member_id in
                                            json.loads(str(district_row[0] or '[]')))
                except (aiosqlite.Error, ValueError, TypeError, json.JSONDecodeError):
                    pass
                district_ids.intersection_update(living_ids)
                district_assigned = len(district_ids)
            except (ValueError, aiosqlite.Error):
                living_ids = []; total = 0
        current = await (await db.execute(
            "SELECT living FROM npc_empire_guard_assignments "
            "WHERE owner_kind=? AND owner_id=? AND holding_ref=?",
            (owner_kind, owner_id, holding_ref))).fetchone()
        current_living = int(current['living'] or 0) if current else 0
        elsewhere = int((await (await db.execute(
            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
            "WHERE owner_kind=? AND owner_id=? AND holding_ref<>?",
            (owner_kind, owner_id, holding_ref))).fetchone())[0] or 0)
        if requested + elsewhere + district_assigned > total:
            await db.rollback()
            return {'ok': False, 'error': 'insufficient free roster',
                    'total': total,
                    'assigned': current_living + elsewhere + district_assigned,
                    'free': max(0, total-current_living-elsewhere-district_assigned)}
        if owner_kind == 'player':
            await db.execute(
                "DELETE FROM npc_empire_player_guard_members WHERE member_id NOT IN "
                "(SELECT id FROM gang_members WHERE telegram_id=? "
                "AND (current_hp IS NULL OR current_hp>0))", (int(owner_id),))
            await db.execute(
                "DELETE FROM npc_empire_player_guard_members "
                "WHERE owner_uid=? AND holding_ref=?", (int(owner_id), holding_ref))
            occupied = {int(row[0]) for row in await (await db.execute(
                "SELECT member_id FROM npc_empire_player_guard_members"
            )).fetchall()}
            occupied.update(district_ids)
            free_ids = [member_id for member_id in living_ids if member_id not in occupied]
            if len(free_ids) < requested:
                await db.rollback()
                return {'ok': False, 'error': 'insufficient free roster',
                        'total': total, 'free': len(free_ids)}
            await db.executemany(
                "INSERT INTO npc_empire_player_guard_members"
                "(member_id,owner_uid,holding_ref,assigned_at) VALUES(?,?,?,?)",
                [(member_id, int(owner_id), holding_ref, now)
                 for member_id in free_ids[:requested]])
        if requested:
            await db.execute(
                "INSERT INTO npc_empire_guard_assignments"
                "(owner_kind,owner_id,holding_ref,assigned,living,updated_at) VALUES(?,?,?,?,?,?) "
                "ON CONFLICT(owner_kind,owner_id,holding_ref) DO UPDATE SET "
                "assigned=excluded.assigned,living=excluded.living,updated_at=excluded.updated_at",
                (owner_kind, owner_id, holding_ref, requested, requested, now))
        else:
            await db.execute(
                "DELETE FROM npc_empire_guard_assignments WHERE owner_kind=? AND owner_id=? AND holding_ref=?",
                (owner_kind, owner_id, holding_ref))
        await db.commit()
        return {'ok': True, 'total': total,
                'assigned': requested + elsewhere + district_assigned,
                'free': total-requested-elsewhere-district_assigned,
                'holding_guards': requested}


async def _assigned_guard_count(db, owner_kind: str, owner_id: str,
                                holding_ref: str = '') -> int:
    where = "owner_kind=? AND owner_id=?"
    params: list = [owner_kind, owner_id]
    if holding_ref:
        where += " AND holding_ref=?"; params.append(holding_ref)
    return int((await (await db.execute(
        f"SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments WHERE {where}",
        tuple(params))).fetchone())[0] or 0)


async def _clear_holding_guard_assignment(db, owner_kind: str, owner_id: str,
                                          holding_ref: str) -> int:
    """Release surviving assignees when a holding changes owner or is sold."""
    living = int((await (await db.execute(
        "SELECT living FROM npc_empire_guard_assignments "
        "WHERE owner_kind=? AND owner_id=? AND holding_ref=?",
        (owner_kind, owner_id, holding_ref))).fetchone() or [0])[0] or 0)
    if owner_kind == 'player':
        await db.execute(
            "DELETE FROM npc_empire_player_guard_members "
            "WHERE owner_uid=? AND holding_ref=?", (int(owner_id), holding_ref))
    await db.execute(
        "DELETE FROM npc_empire_guard_assignments "
        "WHERE owner_kind=? AND owner_id=? AND holding_ref=?",
        (owner_kind, owner_id, holding_ref))
    await db.execute(
        "UPDATE npc_empire_interior_raids SET status='resolved',resolution='ownership_changed',"
        "resolved_at=MAX(resolved_at,started_at) WHERE status='pending' "
        "AND target_ref=? AND ((?='player' AND telegram_id=?) OR (?='npc' AND leader_id=?))",
        (holding_ref, owner_kind, int(owner_id) if owner_kind == 'player' else -1,
         owner_kind, owner_id))
    return living


async def _rebalance_npc_holding_guards(db, leader_id: str, holdings,
                                        members: int, active_wars: int,
                                        now: int,
                                        threatened_refs: set[str] | None = None) -> int:
    """AI assigns actual roster slots by value while keeping a mobile reserve."""
    threatened_refs = threatened_refs or set()
    eligible = sorted((item for item in holdings
                       if str(item['kind']) in {'building', 'business'}),
                      key=lambda item: (
                          f"{item['kind']}:{item['holding_id']}" not in threatened_refs,
                          -int(item['income'] or 0),
                          str(item['kind']), str(item['holding_id'])))
    mobile_reserve = min(max(2, active_wars * 2 + 1), max(2, int(members)))
    available = max(0, int(members) - mobile_reserve)
    plan = {f"{item['kind']}:{item['holding_id']}": 0 for item in eligible}
    while available > 0 and eligible:
        changed = False
        for item in eligible:
            ref = f"{item['kind']}:{item['holding_id']}"
            if plan[ref] >= 3 or available <= 0:
                continue
            plan[ref] += 1; available -= 1; changed = True
        if not changed:
            break
    await db.execute(
        "DELETE FROM npc_empire_guard_assignments WHERE owner_kind='npc' AND owner_id=?",
        (leader_id,))
    await db.executemany(
        "INSERT INTO npc_empire_guard_assignments"
        "(owner_kind,owner_id,holding_ref,assigned,living,updated_at) "
        "VALUES('npc',?,?,?,?,?)",
        [(leader_id, ref, count, count, now) for ref, count in plan.items() if count])
    return sum(plan.values())


def _player_war_activity(profile: EmpireProfile, war: dict,
                         target: dict | None, now: int) -> dict:
    """Make a personal war a visible city order instead of dashboard text."""
    if not target:
        r, c = _hq_coords(profile.hq_key)
        target_id, target_kind = '', 'player'
    else:
        r, c = _player_business_target_point(target)
        target_id, target_kind = str(target['holding_id']), str(target['kind'])
    attacks = max(0, int(war.get('attacks') or 0))
    return {
        'kind': 'player_business_raid', 'intent': 'retaliate',
        'target_id': target_id, 'target_kind': target_kind,
        'target_r': float(r), 'target_c': float(c),
        'phase': 'capture' if attacks % 2 else 'approach',
        'stance': 'assault',
        'force': max(3, min(NPC_EMPIRE_MAX_FIGHTERS,
                            3 + profile.aggression // 10 + attacks)),
        'created_at': int(war.get('last_attack_at') or now),
        'next_attack_at': int(war.get('next_attack_at') or now),
        'ui_label': 'ИДУТ ОТЖИМАТЬ ТВОЙ БИЗНЕС',
    }

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
RECRUITMENT_MEETING_POINTS = ((97, 40), (99, 35), (99, 45), (103, 35))


def _recruitment_venue(profile: EmpireProfile) -> tuple[str, int, int, int, int]:
    venue, source_r, source_c, _, _ = RECRUITMENT_VENUE
    profile_index = next(i for i, item in enumerate(PROFILES)
                         if item.leader_id == profile.leader_id)
    # Recruitment waves contain profiles separated by five positions.  Using
    # the quotient gives every member of that wave its own nearby meeting spot.
    meeting_r, meeting_c = RECRUITMENT_MEETING_POINTS[
        (profile_index // 5) % len(RECRUITMENT_MEETING_POINTS)]
    return venue, source_r, source_c, meeting_r, meeting_c


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


def holding_guard_count(leader_id: str, kind: str, holding_id: str,
                        acquired_at: int) -> int:
    """Stable authoritative 1..3 guard roll for one captured property."""
    if str(kind) not in {'building', 'business'}:
        return 0
    seed = f'{leader_id}:{kind}:{holding_id}:{int(acquired_at or 0)}:guards'
    return 1 + hashlib.sha256(seed.encode()).digest()[0] % 3


def recruitment_cost(members: int) -> int:
    """Price one reinforcement consistently for scheduled and street hires."""
    return 180 + max(0, int(members)) * 14


def operating_reserve(members: int, guard_slots: int, active_wars: int) -> int:
    upkeep = (max(4, max(0, int(members)) * NPC_MEMBER_UPKEEP_PER_TICK)
              + max(0, int(guard_slots)) * NPC_HOLDING_GUARD_UPKEEP_PER_TICK
              + max(0, int(active_wars)) * NPC_ACTIVE_WAR_UPKEEP_PER_TICK)
    return upkeep * NPC_OPERATING_RESERVE_TICKS


def settle_operating_liquidity(treasury: int, income_per_tick: int, members: int,
                               guard_slots: int, active_wars: int) -> dict:
    """Keep bounded operating cash; distribute mature surplus to the family.

    Treasury is working capital, not an unbounded lifetime-score counter.  The
    ceiling scales with gross income and always remains above both the upkeep
    reserve and the most expensive generic-property conversion.
    """
    reserve = operating_reserve(members, guard_slots, active_wars)
    ceiling = max(NPC_MIN_LIQUIDITY_CEILING,
                  reserve + max(0, int(income_per_tick)) * NPC_LIQUIDITY_BUFFER_TICKS)
    cash = max(0, int(treasury)); distributed = max(0, cash - ceiling)
    return {'treasury': cash - distributed, 'ceiling': ceiling,
            'distributed': distributed}


def apply_operating_budget(profile: EmpireProfile, *, treasury: int, members: int,
                           strength: int, income_per_tick: int, guard_slots: int,
                           active_wars: int, ticks: int,
                           insolvent_ticks: int = 0,
                           recovery_ticks_remaining: int = 0,
                           income_schedule: list[int] | None = None) -> dict:
    """Apply bounded payroll, property security and war logistics expenses."""
    cash = max(0, int(treasury)); fighters = max(1, int(members))
    power = max(20, int(strength)); insolvency = max(0, int(insolvent_ticks))
    recovery_left = max(0, int(recovery_ticks_remaining)); paid = 0; stipend = 0
    for tick_index in range(max(0, min(MAX_OFFLINE_TICKS, int(ticks)))):
        scheduled_income = (income_schedule[tick_index]
                            if income_schedule and tick_index < len(income_schedule)
                            else income_per_tick)
        cash += max(0, int(scheduled_income))
        upkeep = (max(4, fighters * NPC_MEMBER_UPKEEP_PER_TICK)
                  + max(0, int(guard_slots)) * NPC_HOLDING_GUARD_UPKEEP_PER_TICK
                  + max(0, int(active_wars)) * NPC_ACTIVE_WAR_UPKEEP_PER_TICK)
        if (scheduled_income <= 0 and recovery_left > 0
                and cash < upkeep + operating_reserve(fighters, guard_slots, active_wars)):
            cash += NPC_RECOVERY_STIPEND_PER_TICK
            stipend += NPC_RECOVERY_STIPEND_PER_TICK
            recovery_left -= 1
        if cash >= upkeep:
            cash -= upkeep; paid += upkeep
            insolvency = max(0, insolvency - 1)
        else:
            cash = 0; insolvency += 1
            if (fighters > 1
                    and insolvency % NPC_BANKRUPTCY_DESERTION_TICKS == 0):
                fighters -= 1
                power = max(20, power - (11 + profile.aggression // 12))
    return {'treasury': cash, 'members': fighters, 'strength': power,
            'insolvent_ticks': insolvency, 'recovery_ticks_remaining': recovery_left,
            'upkeep_paid': paid, 'recovery_stipend': stipend}


def _hq_coords(key: str) -> tuple[int, int]:
    br, bc = (int(x) for x in key.split(',', 1))
    return br * 10 + 6, bc * 10 + 6


def _district_for_block(key: str) -> str:
    r, c = _hq_coords(key)
    if r >= 150: return 'coast'
    if c >= 100: return 'docklands' if r >= 75 else 'eastside'
    if r >= 100: return 'lair'
    if r >= 40: return 'southside' if c < 40 else 'industrial'
    return 'downtown' if c >= 40 else 'northside'


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
    profile_index = next(i for i, item in enumerate(PROFILES)
                         if item.leader_id == profile.leader_id)
    targets = (west_targets, east_targets, south_targets)[(profile_index + slot) % 3]
    # Leaders assigned to the same city sector have indices three positions
    # apart.  Round-robin within that sector keeps their destinations distinct
    # (the smaller southern pool may contain two), unlike independent hashes
    # which could put four families on the same street corner.
    return dict(targets[((profile_index // 3) + slot) % len(targets)])


def _strategy_execution_due(profile: EmpireProfile, strategy: str, slot: int) -> bool:
    """Bound simultaneous public executions of a shared strategic priority."""
    cadence = {
        'recover': 3, 'recruit': 5, 'fortify': 3,
        'acquire': 4, 'retaliate': 2,
    }.get(str(strategy), 1)
    profile_index = next(i for i, item in enumerate(PROFILES)
                         if item.leader_id == profile.leader_id)
    return (profile_index + int(slot)) % cadence == 0


def _holding_district(kind: str, holding_id: str) -> str:
    return BUSINESS_DISTRICTS.get(holding_id, 'downtown') if kind == 'business' else _district_for_block(holding_id)


def _diplomacy_pair(left: str, right: str) -> tuple[str, str]:
    return tuple(sorted((str(left), str(right))))


async def _change_npc_diplomacy(db, diplomacy_state: dict, left: str, right: str,
                                *, delta: int = 0, score: int | None = None,
                                pact: str | None = None, tension_delta: int = 0,
                                tension: int | None = None, now: int) -> dict:
    """Atomically change one boss-to-boss relationship and its tick cache."""
    pair = _diplomacy_pair(left, right)
    current = diplomacy_state.get(pair, {
        'score': 0, 'pact': 'none', 'tension': 0, 'last_event_at': now,
    })
    next_score = clamp_relation(score if score is not None
                                else int(current['score']) + int(delta))
    next_pact = str(pact if pact is not None else current['pact'])
    next_tension = max(0, min(100, int(tension if tension is not None
                                      else int(current['tension']) + int(tension_delta))))
    # A treaty cannot silently survive a relationship collapse.
    if next_pact == 'alliance' and next_score < 35:
        next_pact = 'none'
    if next_pact == 'truce' and next_score < -35:
        next_pact = 'none'
    await db.execute(
        "UPDATE npc_empire_diplomacy SET score=?,pact=?,tension=?,last_event_at=? "
        "WHERE leader_a=? AND leader_b=?",
        (next_score, next_pact, next_tension, now, pair[0], pair[1]),
    )
    updated = {'score': next_score, 'pact': next_pact,
               'tension': next_tension, 'last_event_at': now}
    diplomacy_state[pair] = updated
    return updated


def _common_enemy_gain(observer: EmpireProfile, captured: bool) -> int:
    """Personality-scaled respect: 3..8 for an attack, 8..15 for a capture."""
    if captured:
        return max(8, min(15, 8 + observer.diplomacy // 22
                           + observer.aggression // 35))
    return max(3, min(8, 3 + observer.diplomacy // 32
                      + observer.aggression // 55))


def _territorial_penalty(observer: EmpireProfile) -> int:
    """Commercial and loyal bosses react most sharply to incursions nearby."""
    return max(3, min(7, 2 + observer.commerce // 34
                      + observer.loyalty // 48))


async def _react_to_npc_attack(db, diplomacy_state: dict, attacker_id: str,
                               defender_id: str, now: int, events: list[dict],
                               *, captured_kind: str = '', captured_id: str = '') -> None:
    """Apply real third-party reactions to one autonomous family attack."""
    captured = bool(captured_kind and captured_id)
    pair = _diplomacy_pair(attacker_id, defender_id)
    previous = diplomacy_state.get(pair, {})
    next_tension = min(100, int(previous.get('tension') or 0) + 25)
    exhausted = (str(previous.get('pact') or '') == 'war'
                 and next_tension >= NPC_WAR_EXHAUSTION_TENSION)
    await _change_npc_diplomacy(
        db, diplomacy_state, attacker_id, defender_id,
        score=NPC_TRUCE_SCORE if exhausted else -100,
        pact='truce' if exhausted else 'war',
        tension=60 if exhausted else next_tension, now=now,
    )
    if exhausted:
        events.append({
            'leader_id': attacker_id, 'kind': 'truce_formed',
            'target_id': defender_id,
            'summary': f'{PROFILE_BY_ID[attacker_id].gang_name} и '
                       f'{PROFILE_BY_ID[defender_id].gang_name} истощили силы и заключили перемирие',
        })
    target_district = (_holding_district(captured_kind, captured_id)
                       if captured else '')
    district_claimants: set[str] = set()
    if target_district:
        holdings = await (await db.execute(
            "SELECT kind,holding_id,leader_id FROM npc_empire_holdings"
        )).fetchall()
        counts: dict[str, int] = {}
        for holding in holdings:
            if _holding_district(str(holding['kind']), str(holding['holding_id'])) == target_district:
                owner = str(holding['leader_id'])
                counts[owner] = counts.get(owner, 0) + 1
        district_row = await (await db.execute(
            "SELECT leader_id FROM npc_empire_districts WHERE district_id=?",
            (target_district,),
        )).fetchone()
        district_claimants = {owner for owner, count in counts.items() if count >= 2}
        if district_row and district_row[0]:
            district_claimants.add(str(district_row[0]))

    for observer in PROFILES:
        observer_id = observer.leader_id
        if observer_id in {attacker_id, defender_id}:
            continue
        enemy_relation = diplomacy_state.get(
            _diplomacy_pair(observer_id, defender_id), {})
        if str(enemy_relation.get('pact') or '') == 'alliance':
            await _change_npc_diplomacy(
                db, diplomacy_state, observer_id, attacker_id,
                score=-100, pact='war', tension_delta=35, now=now,
            )
            events.append({
                'leader_id': observer_id, 'kind': 'ally_defended',
                'target_id': attacker_id,
                'summary': f'{observer.leader_name} вступает в войну, защищая союзника',
            })
            # Alliance defense already describes the observer's response; it
            # cannot simultaneously be respect for attacking the same ally.
            continue
        hates_defender = (str(enemy_relation.get('pact') or '') == 'war'
                          or int(enemy_relation.get('score') or 0) <= -21)
        if hates_defender:
            gain = _common_enemy_gain(observer, captured)
            changed = await _change_npc_diplomacy(
                db, diplomacy_state, observer_id, attacker_id,
                delta=gain, tension_delta=-gain, now=now,
            )
            events.append({
                'leader_id': observer_id, 'kind': 'common_enemy_respect',
                'target_id': attacker_id,
                'summary': f'{observer.leader_name} уважает удар по общему врагу: +{gain}',
                'relation_score': changed['score'],
            })
        if captured and observer_id in district_claimants:
            penalty = _territorial_penalty(observer)
            changed = await _change_npc_diplomacy(
                db, diplomacy_state, observer_id, attacker_id,
                delta=-penalty, tension_delta=penalty, now=now,
            )
            events.append({
                'leader_id': observer_id, 'kind': 'territorial_dispute',
                'target_id': attacker_id,
                'summary': f'{observer.leader_name} считает захват в районе «{DISTRICTS[target_district]}» вторжением: −{penalty}',
                'relation_score': changed['score'],
            })


def _coalition_support_power(diplomacy_state: dict, empire_rows: dict,
                             leader_id: str, enemy_id: str) -> int:
    """Return bounded combat support from allies sharing the same war."""
    own_row = empire_rows.get(leader_id)
    own_strength = max(1, int(own_row['strength'] or 1)) if own_row else 1
    support = 0
    for ally_id, ally_row in empire_rows.items():
        if ally_id in {leader_id, enemy_id}:
            continue
        alliance = diplomacy_state.get(_diplomacy_pair(leader_id, ally_id), {})
        common_war = diplomacy_state.get(_diplomacy_pair(ally_id, enemy_id), {})
        if (alliance.get('pact') == 'alliance'
                and common_war.get('pact') == 'war'
                and str(ally_row['status']) not in {'ruined', 'vassal'}):
            support += max(4, int(ally_row['strength'] or 0) * 18 // 100)
    return min(support, max(8, own_strength * 45 // 100))


def _npc_holding_guard_power(profile: EmpireProfile, living: int) -> int:
    """Concrete assigned guards add bounded local power to their own holding."""
    return max(0, int(living)) * (8 + profile.loyalty // 12)


def _npc_war_losses(power_received: float, living_members: int) -> int:
    """Convert opposing power into bounded permanent roster casualties."""
    return min(max(0, int(living_members) - 1),
               max(1, int(max(0.0, float(power_received)) / 220)))


async def _advance_npc_alliances(db, diplomacy_state: dict, empire_rows: dict,
                                 now: int, events: list[dict]) -> None:
    """Form earned alliances and let them coordinate against the top threat."""
    active = {leader_id: row for leader_id, row in empire_rows.items()
              if str(row['status']) not in {'ruined', 'vassal'}}
    for pair, relation in list(diplomacy_state.items()):
        if pair[0] not in active or pair[1] not in active:
            continue
        if (relation['pact'] == 'none' and int(relation['score']) >= 60
                and int(relation['tension']) <= 20):
            await _change_npc_diplomacy(
                db, diplomacy_state, pair[0], pair[1],
                pact='alliance', tension=0, now=now,
            )
            events.append({
                'leader_id': pair[0], 'kind': 'alliance_formed',
                'target_id': pair[1],
                'summary': f'{PROFILE_BY_ID[pair[0]].gang_name} и {PROFILE_BY_ID[pair[1]].gang_name} заключили союз',
            })

    if not active:
        return
    strongest_id = max(active, key=lambda leader_id: (
        int(active[leader_id]['strength'] or 0)
        + int(active[leader_id]['dominance_score'] or 0) * 8,
        leader_id,
    ))
    alliances = [pair for pair, relation in diplomacy_state.items()
                 if relation['pact'] == 'alliance']
    for left, right in alliances:
        if strongest_id in {left, right}:
            continue
        for belligerent, partner in ((left, right), (right, left)):
            belligerent_war = diplomacy_state.get(
                _diplomacy_pair(belligerent, strongest_id), {})
            partner_relation = diplomacy_state.get(
                _diplomacy_pair(partner, strongest_id), {})
            if (belligerent_war.get('pact') == 'war'
                    and partner_relation.get('pact') not in {'war', 'alliance', 'truce'}):
                await _change_npc_diplomacy(
                    db, diplomacy_state, partner, strongest_id,
                    score=-100, pact='war', tension_delta=30, now=now,
                )
                events.append({
                    'leader_id': partner, 'kind': 'coalition_joined',
                    'target_id': strongest_id,
                    'summary': f'{PROFILE_BY_ID[partner].leader_name} поддерживает союзника против сильнейшей семьи города',
                })


async def _advance_npc_peace(db, diplomacy_state: dict, now: int,
                             events: list[dict]) -> None:
    """Cool grudges, goodwill and tension toward neutral during long peace."""
    for pair, relation in list(diplomacy_state.items()):
        pact = str(relation['pact'])
        if pact == 'war':
            elapsed = max(0, now - int(relation['last_event_at'] or now))
            if elapsed >= NPC_WAR_IDLE_TRUCE_SECONDS:
                await _change_npc_diplomacy(
                    db, diplomacy_state, pair[0], pair[1],
                    score=NPC_TRUCE_SCORE, pact='truce', tension=60, now=now,
                )
                events.append({
                    'leader_id': pair[0], 'kind': 'truce_formed',
                    'target_id': pair[1],
                    'summary': f'{PROFILE_BY_ID[pair[0]].gang_name} и '
                               f'{PROFILE_BY_ID[pair[1]].gang_name} прекратили затянувшуюся войну',
                })
            continue
        if pact in {'alliance', 'vassal'}:
            continue
        elapsed = max(0, now - int(relation['last_event_at'] or now))
        blocks = min(12, elapsed // NPC_DIPLOMACY_PEACE_STEP_SECONDS)
        if blocks <= 0:
            continue
        left, right = PROFILE_BY_ID[pair[0]], PROFILE_BY_ID[pair[1]]
        score = int(relation['score'])
        if score < 0:
            forgiveness = 1 + (left.diplomacy + right.diplomacy) // 100
            if pact == 'truce':
                forgiveness += 1
            next_score = min(0, score + blocks * forgiveness)
        elif score > 0:
            cooling = 1 + (left.aggression + right.aggression) // 135
            next_score = max(0, score - blocks * cooling)
        else:
            next_score = 0
        tension_cooling = 3 + (left.diplomacy + right.diplomacy) // 55
        next_tension = max(0, int(relation['tension']) - blocks * tension_cooling)
        next_pact = ('none' if pact == 'truce' and next_score >= -10
                     and next_tension <= 10 else pact)
        step_at = int(relation['last_event_at']) + blocks * NPC_DIPLOMACY_PEACE_STEP_SECONDS
        await _change_npc_diplomacy(
            db, diplomacy_state, pair[0], pair[1], score=next_score,
            pact=next_pact, tension=next_tension, now=step_at,
        )
        if pact == 'truce' and next_pact == 'none':
            events.append({
                'leader_id': pair[0], 'kind': 'peace_normalized',
                'target_id': pair[1],
                'summary': f'{left.gang_name} и {right.gang_name} завершили перемирие без новой войны',
            })
def _visible_activity(profile: EmpireProfile, row, holdings: list[dict], now: int,
                      brain: dict | None = None) -> dict:
    """Give the client one concrete, slowly changing destination for this boss."""
    if int(_row_field(row, 'hospital_until', 0) or 0) > now:
        hospital_id = str(_row_field(row, 'hospital_id', 'hospital') or 'hospital')
        return {
            'kind': 'hospital', 'target_id': hospital_id,
            'phase': 'treatment', 'created_at': now,
            'ui_label': 'БОСС НА ЛЕЧЕНИИ', 'intent': 'recover',
            'summary': f'{profile.leader_name} проходит лечение; семьёй временно руководят капо',
        }
    recruitment = _recruitment_state(profile, row, now)
    if recruitment:
        return {
            'kind': 'recruit', 'target_id': f'recruit:{profile.leader_id}',
            'target_r': recruitment['meeting_r'], 'target_c': recruitment['meeting_c'],
            'phase': 'meeting', 'created_at': recruitment['started_at'],
            'summary': f'{profile.leader_name} проводит набор в семью: {recruitment["venue"]}',
        }
    strategy = str((brain or {}).get('strategy') or '')
    slot = now // VISIBLE_ACTIVITY_SECONDS
    strategic_slot_at = slot * VISIBLE_ACTIVITY_SECONDS
    execute_strategy = _strategy_execution_due(profile, strategy, slot)
    if strategy in {'recover', 'recruit'} and execute_strategy:
        _, _, _, meeting_r, meeting_c = _recruitment_venue(profile)
        return {
            'kind': 'recruit', 'target_id': f'plan:{profile.leader_id}:lair',
            'target_r': meeting_r, 'target_c': meeting_c,
            'phase': 'travel', 'created_at': strategic_slot_at,
            'ui_label': 'ВЕРБУЕТ БОЙЦОВ', 'intent': strategy,
            'summary': f'{profile.leader_name} едет в Логово искать надёжных людей',
        }
    if strategy == 'fortify' and holdings and execute_strategy:
        target = min(holdings, key=lambda item: (int(item.get('defense') or 0),
                                                str(item.get('holding_id') or '')))
        target_id, target_kind = str(target.get('holding_id') or ''), str(target.get('kind') or '')
        target_r, target_c = (BUSINESS_COORDS.get(target_id, (0, 0))
                              if target_kind == 'business' else _hq_coords(target_id))
        return {
            'kind': 'defend', 'target_id': target_id, 'target_r': target_r,
            'target_c': target_c, 'phase': 'travel', 'created_at': strategic_slot_at,
            'ui_label': 'УКРЕПЛЯЕТ СЛАБЫЙ ПОСТ', 'intent': strategy,
            'summary': f'{profile.leader_name} лично проверяет слабое место обороны',
        }
    if strategy == 'acquire' and execute_strategy:
        owned = {str(item.get('holding_id') or '') for item in holdings}
        targets = [bid for bid in BUSINESS_PRICE if bid not in owned]
        if targets:
            target_id = max(targets, key=lambda bid: (BUSINESS_INCOME[bid] / BUSINESS_PRICE[bid], bid))
            target_r, target_c = BUSINESS_COORDS[target_id]
            return {
                'kind': 'invest', 'target_id': target_id, 'target_r': target_r,
                'target_c': target_c, 'phase': 'travel', 'created_at': strategic_slot_at,
                'ui_label': 'ОЦЕНИВАЕТ БИЗНЕС', 'intent': strategy,
                'summary': f'{profile.leader_name} оценивает бизнес перед сделкой',
            }
    if strategy == 'retaliate' and execute_strategy:
        hq_r, hq_c = _hq_coords(str(row['hq_key'] or profile.hq_key))
        return {
            'kind': 'attack', 'target_id': f'plan:{profile.leader_id}:revenge',
            'target_r': hq_r, 'target_c': hq_c, 'phase': 'rally', 'created_at': strategic_slot_at,
            'ui_label': 'ГОТОВИТ ОТВЕТНЫЙ УДАР', 'intent': strategy,
            'summary': f'{profile.leader_name} собирает семью для ответного удара',
        }
    seed = int.from_bytes(hashlib.sha256(f'{profile.leader_id}:walk:{slot}'.encode()).digest()[:4], 'big')
    hq_r, hq_c = _hq_coords(str(row['hq_key'] or profile.hq_key))
    businesses = sorted(str(h['holding_id']) for h in holdings if str(h['kind']) == 'business')
    buildings = sorted(str(h['holding_id']) for h in holdings if str(h['kind']) == 'building')
    phase = seed % 7
    if phase == 0:
        return {'kind': 'return_hq', 'target_id': str(row['hq_key'] or profile.hq_key),
                'target_r': hq_r, 'target_c': hq_c, 'phase': 'travel',
                'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
                'ui_label': 'ВОЗВРАЩАЕТСЯ В ШТАБ', 'intent': strategy,
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
                'ui_label': ('ПРОВЕРЯЕТ ДОХОД' if kind == 'collect'
                             else 'ИНСПЕКТИРУЕТ СВОЙ ПОСТ'),
                'intent': strategy,
                'summary': f'{profile.leader_name} {label}'}
    target = _citywide_roam_target(profile, slot)
    kind = 'inspect' if target['target_kind'] in {'building', 'business'} else 'patrol'
    label = 'разведывает цель для захвата' if kind == 'inspect' else 'патрулирует дальний район'
    return {'kind': kind, 'target_id': target['target_id'],
            'target_r': target['target_r'], 'target_c': target['target_c'],
            'phase': 'travel', 'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
            'ui_label': BOSS_FIELD_JOBS[profile.leader_id], 'intent': strategy,
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
    mindset = BOSS_MINDSETS[profile.leader_id]
    scores['fortify'] += mindset['patience'] * 12
    scores['consolidate'] += mindset['patience'] * 9
    scores['retaliate'] += mindset['courage'] * 13
    scores['expand'] += mindset['courage'] * 8
    scores['recruit'] += mindset['adaptability'] * 7
    scores['acquire'] += mindset['adaptability'] * 5
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
        'target_leader_name': str(enemy['leader_name']),
        'target_gang_name': str(enemy['gang_name']),
        'target_r': float(enemy.get('hq_r') or 0),
        'target_c': float(enemy.get('hq_c') or 0),
        'phase': 'engage', 'stance': stance,
        'force': min(NPC_EMPIRE_MAX_FIGHTERS, max(2, int(row['members'] or 1))),
        'created_at': slot * VISIBLE_ACTIVITY_SECONDS,
        'summary': f'{profile.leader_name} ведёт {profile.gang_name} против '
                   f'{enemy["leader_name"]} и семьи {enemy["gang_name"]}',
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
            insolvent_ticks INTEGER NOT NULL DEFAULT 0,
            recovery_ticks_remaining INTEGER NOT NULL DEFAULT 0,
            distributed_profit INTEGER NOT NULL DEFAULT 0,
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
        CREATE TABLE IF NOT EXISTS npc_empire_street_recruits (
            source_id TEXT PRIMARY KEY,
            leader_id TEXT NOT NULL,
            family TEXT NOT NULL,
            recruited_at INTEGER NOT NULL
        );
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
        CREATE TABLE IF NOT EXISTS npc_empire_interior_raids (
            token TEXT PRIMARY KEY,
            telegram_id INTEGER NOT NULL,
            leader_id TEXT NOT NULL,
            apt_key TEXT NOT NULL,
            target_ref TEXT NOT NULL,
            target_kind TEXT NOT NULL,
            holding_id TEXT NOT NULL,
            operation_type TEXT NOT NULL DEFAULT '',
            business_label TEXT NOT NULL DEFAULT '',
            force INTEGER NOT NULL,
            attacker_cost INTEGER NOT NULL,
            tier INTEGER NOT NULL,
            quality INTEGER NOT NULL,
            hp INTEGER NOT NULL,
            accuracy REAL NOT NULL,
            weapon_budget INTEGER NOT NULL,
            defender_ids_json TEXT NOT NULL DEFAULT '[]',
            guard_ids_json TEXT NOT NULL DEFAULT '[]',
            guard_count INTEGER NOT NULL DEFAULT 0,
            attack_no INTEGER NOT NULL DEFAULT 0,
            started_at INTEGER NOT NULL,
            hold_seconds INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            resolution TEXT NOT NULL DEFAULT '',
            resolved_at INTEGER NOT NULL DEFAULT 0
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ix_npc_empire_interior_raids_pending
            ON npc_empire_interior_raids(telegram_id,leader_id)
            WHERE status='pending';
        CREATE TABLE IF NOT EXISTS npc_empire_guard_assignments (
            owner_kind TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            holding_ref TEXT NOT NULL,
            assigned INTEGER NOT NULL DEFAULT 0,
            living INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(owner_kind,owner_id,holding_ref)
        );
        CREATE TABLE IF NOT EXISTS npc_empire_player_guard_members (
            member_id INTEGER PRIMARY KEY,
            owner_uid INTEGER NOT NULL,
            holding_ref TEXT NOT NULL,
            assigned_at INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS npc_empire_building_closures (
            holding_id TEXT PRIMARY KEY,
            leader_id TEXT NOT NULL,
            saboteur_uid INTEGER NOT NULL,
            closed_until INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS ix_npc_empire_building_closures_until
            ON npc_empire_building_closures(closed_until);
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
            'insolvent_ticks': "INTEGER NOT NULL DEFAULT 0",
            'recovery_ticks_remaining': "INTEGER NOT NULL DEFAULT 0",
            'distributed_profit': "INTEGER NOT NULL DEFAULT 0",
        }
        for name, declaration in migrations.items():
            if name not in columns:
                await db.execute(f"ALTER TABLE npc_empires ADD COLUMN {name} {declaration}")
        raid_columns = {str(r[1]) for r in await (await db.execute(
            "PRAGMA table_info(npc_empire_interior_raids)")).fetchall()}
        if 'guard_ids_json' not in raid_columns:
            await db.execute(
                "ALTER TABLE npc_empire_interior_raids "
                "ADD COLUMN guard_ids_json TEXT NOT NULL DEFAULT '[]'")
        holding_columns = {str(r[1]) for r in await (await db.execute(
            "PRAGMA table_info(npc_empire_holdings)")).fetchall()}
        for name, declaration in {'operation_type': "TEXT NOT NULL DEFAULT ''", 'area': "INTEGER NOT NULL DEFAULT 0"}.items():
            if name not in holding_columns:
                await db.execute(f"ALTER TABLE npc_empire_holdings ADD COLUMN {name} {declaration}")
        await db.execute(
            "UPDATE npc_empire_holdings SET income=? WHERE kind='hq' AND income<=0",
            (NPC_HQ_FRONT_INCOME_PER_MINUTE,),
        )
        for leader_id, (old_key, new_key) in HQ_KEY_MIGRATIONS.items():
            current = await (await db.execute(
                "SELECT hq_key FROM npc_empires WHERE leader_id=?", (leader_id,)
            )).fetchone()
            if not current or str(current[0] or '') != old_key:
                continue
            await db.execute(
                "UPDATE npc_empire_holdings SET holding_id=? "
                "WHERE kind='hq' AND holding_id=? AND leader_id=?",
                (new_key, old_key, leader_id),
            )
            await db.execute(
                "UPDATE npc_empires SET hq_key=? WHERE leader_id=? AND hq_key=?",
                (new_key, leader_id, old_key),
            )
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
                    (str(seeded[1]), profile.leader_id, NPC_HQ_FRONT_INCOME_PER_MINUTE,
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


async def recruit_street_fighter(db_path: str, leader_id: str, source_id: str,
                                 family: str, now: int | None = None) -> dict:
    """Persist one visible Bellini/Moretti fighter joining an NPC empire."""
    now = int(now or time.time()); leader_id = str(leader_id or '').strip()
    source_id = str(source_id or '').strip()[:96]; family = str(family or '').strip().lower()
    if leader_id not in PROFILE_BY_ID or not source_id or family not in {'bellini', 'moretti'}:
        return {'ok': False, 'error': 'bad recruit'}
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row; await db.execute('BEGIN IMMEDIATE')
        await db.execute("DELETE FROM npc_empire_street_recruits WHERE recruited_at<?", (now - 6 * 3600,))
        duplicate = await (await db.execute("SELECT leader_id FROM npc_empire_street_recruits WHERE source_id=?", (source_id,))).fetchone()
        if duplicate:
            owner = str(duplicate['leader_id'])
            existing = await (await db.execute("SELECT members,strength FROM npc_empires WHERE leader_id=?", (owner,))).fetchone()
            await db.rollback()
            if owner == leader_id and existing:
                return {'ok': True, 'duplicate': True, 'leader_id': owner,
                        'members': int(existing['members']), 'strength': int(existing['strength']), 'family': family}
            return {'ok': False, 'error': 'already recruited', 'leader_id': owner}
        row = await (await db.execute("SELECT treasury,members,strength,status,last_recruit_at FROM npc_empires WHERE leader_id=?", (leader_id,))).fetchone()
        if not row or str(row['status']) not in {'active', 'rebuilding', 'vassal'}:
            await db.rollback(); return {'ok': False, 'error': 'empire unavailable'}
        members = int(row['members'] or 0)
        if members >= NPC_EMPIRE_MAX_FIGHTERS:
            await db.rollback(); return {'ok': False, 'error': 'roster full', 'members': members}
        if now - int(row['last_recruit_at'] or 0) < 8:
            await db.rollback(); return {'ok': False, 'error': 'recruit cooldown'}
        profile = PROFILE_BY_ID[leader_id]; strength_gain = 11 + profile.aggression // 12
        cost = recruitment_cost(members); treasury = max(0, int(row['treasury'] or 0))
        holding_rows = await (await db.execute(
            "SELECT kind,holding_id,acquired_at FROM npc_empire_holdings WHERE leader_id=?",
            (leader_id,),
        )).fetchall()
        guard_slots = sum(holding_guard_count(
            leader_id, str(item['kind']), str(item['holding_id']),
            int(item['acquired_at'] or 0),
        ) for item in holding_rows)
        active_wars = int((await (await db.execute(
            "SELECT COUNT(*) FROM npc_empire_diplomacy "
            "WHERE pact='war' AND (leader_a=? OR leader_b=?)", (leader_id, leader_id)
        )).fetchone())[0] or 0)
        active_wars += int((await (await db.execute(
            "SELECT COUNT(*) FROM npc_empire_player_wars WHERE leader_id=?", (leader_id,)
        )).fetchone())[0] or 0)
        reserve = operating_reserve(members + 1, guard_slots, active_wars)
        if treasury - cost < reserve:
            await db.rollback()
            return {'ok': False, 'error': 'insufficient treasury',
                    'cost': cost, 'treasury': treasury, 'reserve': reserve,
                    'members': members}
        await db.execute("INSERT INTO npc_empire_street_recruits(source_id,leader_id,family,recruited_at) VALUES(?,?,?,?)", (source_id, leader_id, family, now))
        await db.execute("UPDATE npc_empires SET treasury=treasury-?,members=members+1,strength=strength+?,last_recruit_count=1,last_recruit_at=?,version=version+1 WHERE leader_id=?", (cost, strength_gain, now, leader_id))
        family_name = 'Моретти' if family == 'moretti' else 'Беллини'
        summary = f'Боец {family_name} встретил {profile.leader_name} в городе и вступил в {profile.gang_name}'
        await db.execute("INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)", (leader_id, 'street_recruit', source_id, summary, now))
        await db.commit()
        return {'ok': True, 'leader_id': leader_id, 'members': members + 1,
                'strength': int(row['strength'] or 0) + strength_gain,
                'treasury': treasury - cost, 'cost': cost,
                'family': family, 'summary': summary}


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
        "DELETE FROM npc_empire_guard_assignments WHERE owner_kind='npc' AND owner_id=?",
        (leader_id,))
    await db.execute(
        "UPDATE npc_empire_interior_raids SET status='resolved',resolution='owner_ruined',"
        "resolved_at=? WHERE leader_id=? AND status='pending'", (now, leader_id))
    await db.execute(
        "UPDATE npc_empires SET status='ruined',treasury=0,members=0,strength=0,hq_key=NULL,"
        "defeated_at=?,defeated_by=?,comeback_at=?,losses=losses+1,dominance_score=0,"
        "district_count=0,insolvent_ticks=0,recovery_ticks_remaining=0,pending_recruits=0,recruit_started_at=0,recruit_ready_at=0,last_recruit_count=0,last_recruit_at=0,"
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
            "UPDATE npc_empires SET status='rebuilding',treasury=?,members=2,strength=?,hq_key=?,insolvent_ticks=0,recovery_ticks_remaining=?,"
            "comeback_at=0,comebacks=?,defeated_by=NULL,pending_recruits=0,recruit_started_at=0,"
            "recruit_ready_at=0,last_recruit_count=0,last_recruit_at=0,last_tick=?,next_action_at=?,version=version+1 "
            "WHERE leader_id=?",
            (treasury, strength, hq_key, NPC_RECOVERY_STIPEND_TICKS,
             comeback_no, now, now + TICK_SECONDS, leader_id),
        )
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_holdings"
            "(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('hq',?,?,?,?,?)",
            (hq_key, leader_id, NPC_HQ_FRONT_INCOME_PER_MINUTE,
             45 + profile.loyalty // 2, now),
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
    placeholders = ','.join('?' for _ in DISTRICTS)
    await db.execute(
        f"DELETE FROM npc_empire_districts WHERE district_id NOT IN ({placeholders})",
        tuple(DISTRICTS),
    )
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
        # Preserve the bounded batch's closure intervals before pruning rows
        # that reopened between the last empire tick and this catch-up call.
        closure_windows = {
            str(row['holding_id']): (int(row['created_at'] or 0),
                                     int(row['closed_until'] or 0))
            for row in await (await db.execute(
                "SELECT holding_id,created_at,closed_until "
                "FROM npc_empire_building_closures"
            )).fetchall()
        }
        await db.execute("DELETE FROM npc_empire_building_closures WHERE closed_until<=?", (now,))
        closed_buildings = {
            holding_id for holding_id, (_, closed_until) in closure_windows.items()
            if closed_until > now
        }
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
            "SELECT leader_a,leader_b,score,pact,tension,last_event_at FROM npc_empire_diplomacy"
        )).fetchall():
            diplomacy_state[(str(relation['leader_a']), str(relation['leader_b']))] = {
                'score': int(relation['score'] or 0),
                'pact': str(relation['pact'] or 'none'),
                'tension': int(relation['tension'] or 0),
                'last_event_at': int(relation['last_event_at'] or now),
            }
        await _advance_npc_peace(db, diplomacy_state, now, events)
        await _advance_npc_alliances(
            db, diplomacy_state, empire_row_by_id, now, events,
        )
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
            # An earlier family in this same transaction may already have
            # inflicted casualties or captured one of this leader's holdings.
            # Never overwrite that result from the tick's opening snapshot.
            row = await (await db.execute(
                "SELECT * FROM npc_empires WHERE leader_id=?", (leader_id,)
            )).fetchone()
            if not row or str(row['status']) not in {'active', 'rebuilding', 'vassal'}:
                continue
            profile = PROFILE_BY_ID[leader_id]
            elapsed = max(0, now - int(row['last_tick'] or now))
            ticks = min(MAX_OFFLINE_TICKS, elapsed // TICK_SECONDS)
            if ticks <= 0:
                continue
            holdings = await (await db.execute(
                "SELECT kind,holding_id,income,defense,acquired_at,operation_type,area FROM npc_empire_holdings WHERE leader_id=?",
                (leader_id,),
            )).fetchall()
            non_buildings = [h for h in holdings if str(h['kind']) != 'building']
            base_income = empire_holding_income_per_tick(non_buildings)
            income_schedule = [base_income for _ in range(ticks)]
            last_tick = int(row['last_tick'] or now)
            for item in holdings:
                if str(item['kind']) != 'building':
                    continue
                closed_from, closed_until = closure_windows.get(str(item['holding_id']), (0, 0))
                building_tick_income = int(item['income'] or 0) * max(1, TICK_SECONDS // 60)
                for tick_index in range(ticks):
                    interval_start = last_tick + tick_index * TICK_SECONDS
                    interval_end = interval_start + TICK_SECONDS
                    if (closed_until <= closed_from or interval_end <= closed_from
                            or interval_start >= closed_until):
                        income_schedule[tick_index] += building_tick_income
            per_tick = base_income
            members = max(1, int(row['members'] or 1))
            strength = max(20, int(row['strength'] or 20))
            active_wars = sum(1 for pair, state in diplomacy_state.items()
                              if leader_id in pair and state['pact'] == 'war')
            if leader_id in player_war_leaders:
                active_wars += 1
            guard_slots = await _rebalance_npc_holding_guards(
                db, leader_id, holdings, members, active_wars, now,
                {f"building:{item['holding_id']}" for item in holdings
                 if str(item['kind']) == 'building'
                 and str(item['holding_id']) in closed_buildings})
            insolvent_before = max(0, int(row['insolvent_ticks'] or 0))
            recovery_before = max(0, int(row['recovery_ticks_remaining'] or 0))
            budget = apply_operating_budget(
                profile, treasury=int(row['treasury'] or 0), members=members,
                strength=strength, income_per_tick=per_tick,
                guard_slots=guard_slots, active_wars=active_wars, ticks=ticks,
                insolvent_ticks=insolvent_before,
                recovery_ticks_remaining=recovery_before,
                income_schedule=income_schedule,
            )
            treasury = int(budget['treasury']); members = int(budget['members'])
            strength = int(budget['strength']); insolvent_ticks = int(budget['insolvent_ticks'])
            recovery_ticks_remaining = int(budget['recovery_ticks_remaining'])
            if insolvent_before == 0 and insolvent_ticks > 0:
                events.append({
                    'leader_id': leader_id, 'kind': 'bankrupt',
                    'summary': f'{profile.gang_name} не смогла оплатить охрану и подкрепления',
                })
            elif insolvent_before > 0 and insolvent_ticks == 0:
                events.append({
                    'leader_id': leader_id, 'kind': 'solvency_recovered',
                    'summary': f'{profile.gang_name} снова покрывает расходы из своей казны',
                })
            pending_recruits = max(0, int(row['pending_recruits'] or 0))
            recruit_started_at = max(0, int(row['recruit_started_at'] or 0))
            recruit_ready_at = max(0, int(row['recruit_ready_at'] or 0))
            rng = _decision_roll(leader_id, int(row['last_tick']) + ticks * TICK_SECONDS)
            recruit_cost = recruitment_cost(members)
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
            boss_available = int(row['hospital_until'] or 0) <= now
            strategic_action_taken = False
            last_recruit_count = max(0, int(row['last_recruit_count'] or 0))
            last_recruit_at = max(0, int(row['last_recruit_at'] or 0))
            recruit_chance = .96 if strategy in {'recover', 'recruit', 'fortify'} else .22
            recruit_wave_due = _strategy_execution_due(
                profile, 'recruit', now // TICK_SECONDS)
            if (boss_available and recruit_wave_due and insolvent_ticks == 0
                    and pending_recruits == 0 and members < target_members
                    and treasury >= recruit_cost and rng.random() < recruit_chance):
                hired = max((count for count in range(1, min(3, target_members-members)+1)
                             if treasury - count * recruit_cost >= operating_reserve(
                                 members + count, guard_slots, active_wars)), default=0)
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
            army_pressure = min(1.0, members / NPC_EMPIRE_MAX_FIGHTERS)
            expand_chance = .90 if strategy == 'expand' else .035
            if (boss_available and not strategic_action_taken and building_count < 8
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
                    area = BUILDING_AREAS[key]
                    operation = choose_building_operation(profile, key, now)
                    expansion_cost = building_purchase_price(
                        building_shell_price(key), 'business', operation, area)
                    income = building_operation_income(operation, area)
                    defense = 35 + profile.loyalty // 2
                    next_guards = guard_slots + holding_guard_count(
                        leader_id, 'building', key, now)
                    if treasury - expansion_cost >= operating_reserve(
                            members, next_guards, active_wars):
                        building_owner[key] = leader_id
                        await db.execute(
                            "INSERT OR REPLACE INTO npc_empire_holdings"
                            "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) VALUES('building',?,?,?,?,?,?,?)",
                            (key, leader_id, income, defense, now, operation, area),
                        )
                        treasury -= expansion_cost; guard_slots = next_guards
                        events.append({'leader_id': leader_id, 'kind': 'expand', 'target_id': key,
                                       'summary': f"{profile.gang_name} купили дом {key} и открыли «{BUILDING_OPERATIONS[operation]['name']}»"})
                        strategic_action_taken = True
            # A faction may buy a neutral business. Player-owned property is
            # never removed by an offline roll: attacking a player must create
            # a visible, defendable headquarters/business assault instead.
            acquire_chance = .92 if strategy == 'acquire' else .025
            if (boss_available and not strategic_action_taken and neutral_businesses and len(owned_businesses) < 5
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
                    next_guards = guard_slots + holding_guard_count(
                        leader_id, 'business', bid, now)
                    if treasury - cost >= operating_reserve(
                            members, next_guards, active_wars):
                        treasury -= cost; guard_slots = next_guards
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
            if (boss_available and not strategic_action_taken
                    and strategy == 'fortify' and holdings):
                fortify_cost = 420 + len(holdings) * 45
                if treasury - fortify_cost >= operating_reserve(
                        members, guard_slots, active_wars):
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
            if (boss_available and not strategic_action_taken
                    and leader_id not in player_war_leaders
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
                    relation_state = diplomacy_state.get(pair, {})
                    pact = str(relation_state.get('pact') or 'none')
                    tension = int(relation_state.get('tension') or 0)
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
                target_rows = [item for item in target_rows if not (
                    str(item['kind']) == 'building' and
                    str(item['holding_id']) in closed_buildings)]
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
                    attack_support = _coalition_support_power(
                        diplomacy_state, empire_row_by_id, leader_id, rival.leader_id)
                    defense_support = _coalition_support_power(
                        diplomacy_state, empire_row_by_id, rival.leader_id, leader_id)
                    target_ref = f"{str(target['kind'])}:{str(target['holding_id'])}"
                    target_guards = int((await (await db.execute(
                        "SELECT living FROM npc_empire_guard_assignments "
                        "WHERE owner_kind='npc' AND owner_id=? AND holding_ref=?",
                        (rival.leader_id, target_ref),
                    )).fetchone() or [0])[0] or 0)
                    defender_members = max(1, int(rival_state['members'] or 1))
                    defender_strength = max(20, int(rival_state['strength'] or 20))
                    attack_power = (strength * (.72 + rng.random()*.58)
                                    + profile.aggression + attack_support)
                    guard_power = _npc_holding_guard_power(rival, target_guards)
                    defense_power = (defender_strength * (.78 + rng.random()*.52)
                                     + int(target['defense']) + defense_support
                                     + guard_power)
                    attacker_losses = _npc_war_losses(defense_power, members)
                    defender_losses = _npc_war_losses(attack_power, defender_members)
                    strength = max(20, strength - attacker_losses *
                                   (8 + rival.aggression // 20))
                    members = max(1, members - attacker_losses)
                    defender_strength = max(
                        20, defender_strength - defender_losses *
                        (8 + profile.aggression // 20))
                    defender_members = max(1, defender_members - defender_losses)
                    guard_losses = min(target_guards, defender_losses)
                    if guard_losses:
                        await db.execute(
                            "UPDATE npc_empire_guard_assignments "
                            "SET living=MAX(0,living-?),assigned=MAX(0,assigned-?),updated_at=? "
                            "WHERE owner_kind='npc' AND owner_id=? AND holding_ref=?",
                            (guard_losses, guard_losses, now,
                             rival.leader_id, target_ref),
                        )
                    await db.execute(
                        "UPDATE npc_empires SET members=?,strength=?,version=version+1 "
                        "WHERE leader_id=?",
                        (defender_members, defender_strength, rival.leader_id),
                    )
                    if attack_power > defense_power:
                        captured_kind=str(target['kind']);captured_id=str(target['holding_id'])
                        await _clear_holding_guard_assignment(
                            db, 'npc', rival.leader_id,
                            f'{captured_kind}:{captured_id}')
                        if captured_kind == 'building':
                            captured_area=max(4,int(target['area'] or BUILDING_AREAS.get(captured_id,4)))
                            captured_operation=choose_captured_building_operation(
                                profile,captured_id,str(target['operation_type'] or ''),
                                now+int(row['wins'] or 0))
                            await db.execute(
                                "UPDATE npc_empire_holdings SET leader_id=?,defense=?,acquired_at=?,operation_type=?,area=?,income=? WHERE kind='building' AND holding_id=?",
                                (leader_id,45+profile.loyalty//2,now,captured_operation,captured_area,
                                 building_operation_income(captured_operation,captured_area),captured_id),
                            )
                        else:
                            captured_operation=''
                            await db.execute(
                                "UPDATE npc_empire_holdings SET leader_id=?,defense=?,acquired_at=? WHERE kind=? AND holding_id=?",
                                (leader_id,45+profile.loyalty//2,now,captured_kind,captured_id),
                            )
                        if target['kind']=='business':
                            business_owner[str(target['holding_id'])]=leader_id
                            await db.execute(
                                "UPDATE business_property_owners SET owner_uid=?,owner_name=?,acquired_at=?,protected_until=? WHERE biz_id=?",
                                (npc_owner_uid(leader_id),profile.gang_name,now,now+300,str(target['holding_id'])),
                            )
                        else: building_owner[str(target['holding_id'])]=leader_id
                        await _react_to_npc_attack(
                            db, diplomacy_state, leader_id, rival.leader_id, now, events,
                            captured_kind=captured_kind, captured_id=captured_id,
                        )
                        conversion=(f' и открыли «{BUILDING_OPERATIONS[captured_operation]["name"]}»'
                                    if captured_operation else '')
                        events.append({'leader_id':leader_id,'kind':'war_won','target_id':rival.leader_id,
                                       'operation_type':captured_operation,
                                       'summary':f'{profile.gang_name} отбили {target["kind"]} {target["holding_id"]} у {rival.gang_name}{conversion}; потери {attacker_losses}:{defender_losses}'})
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
                            await db.execute(
                                "UPDATE npc_empires SET losses=losses+1 WHERE leader_id=?",
                                (rival.leader_id,),
                            )
                            events.append({
                                'leader_id': rival.leader_id, 'kind': 'war_lost',
                                'target_id': leader_id,
                                'summary': f'{rival.gang_name} потеряли {target["kind"]} '
                                           f'{target["holding_id"]} в бою с {profile.gang_name}; '
                                           f'потери {defender_losses}:{attacker_losses}',
                            })
                    else:
                        await _react_to_npc_attack(
                            db, diplomacy_state, leader_id, rival.leader_id, now, events,
                        )
                        events.append({'leader_id':leader_id,'kind':'war_lost','target_id':rival.leader_id,
                                       'summary':f'{rival.gang_name} отбили нападение {profile.gang_name}; потери {attacker_losses}:{defender_losses}'})
                        await db.execute(
                            "UPDATE npc_empires SET losses=losses+1 WHERE leader_id=?",
                            (leader_id,),
                        )
                        await db.execute(
                            "UPDATE npc_empires SET wins=wins+1 WHERE leader_id=?",
                            (rival.leader_id,),
                        )
                        events.append({
                            'leader_id': rival.leader_id, 'kind': 'war_won',
                            'target_id': leader_id,
                            'summary': f'{rival.gang_name} удержали {target["kind"]} '
                                       f'{target["holding_id"]} от {profile.gang_name}; '
                                       f'потери {defender_losses}:{attacker_losses}',
                        })
            next_status = 'active' if row['status'] == 'rebuilding' and (members >= 4 or treasury >= 1500) else str(row['status'])
            liquidity = settle_operating_liquidity(
                treasury, max(income_schedule, default=per_tick), members,
                guard_slots, active_wars)
            treasury = int(liquidity['treasury'])
            await db.execute(
                "UPDATE npc_empires SET treasury=?,distributed_profit=distributed_profit+?,members=?,strength=?,status=?,insolvent_ticks=?,recovery_ticks_remaining=?,pending_recruits=?,"
                "recruit_started_at=?,recruit_ready_at=?,last_recruit_count=?,last_recruit_at=?,last_tick=?,next_action_at=?,version=version+1 WHERE leader_id=?",
                (treasury, int(liquidity['distributed']), members, strength,
                 next_status, insolvent_ticks,
                 recovery_ticks_remaining, pending_recruits,
                 recruit_started_at, recruit_ready_at, last_recruit_count, last_recruit_at, int(row['last_tick']) + ticks*TICK_SECONDS,
                 now + TICK_SECONDS, leader_id),
            )
            # Budget pressure and combat can reduce the living roster after the
            # opening allocation. Recompute inside the same transaction so no
            # observer can see more guards than living members, and include any
            # property captured by this action immediately.
            final_holdings = await (await db.execute(
                "SELECT kind,holding_id,income,defense,acquired_at,operation_type,area "
                "FROM npc_empire_holdings WHERE leader_id=?", (leader_id,)
            )).fetchall()
            await _rebalance_npc_holding_guards(
                db, leader_id, final_holdings, members, active_wars, now,
                {f"building:{item['holding_id']}" for item in final_holdings
                 if str(item['kind']) == 'building'
                 and str(item['holding_id']) in closed_buildings})
        # Reactions created during this tick may cross the alliance threshold;
        # make that political result authoritative before publishing events.
        await _advance_npc_alliances(
            db, diplomacy_state, empire_row_by_id, now, events,
        )
        for event in events:
            await db.execute(
                "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                (event['leader_id'], event['kind'], event.get('target_id',''), event['summary'], now),
            )
        # Persistent memory is per-family and bounded. A busy rival must not
        # grow the database forever or evict another boss's entire history.
        for memory_leader in PROFILE_BY_ID:
            await db.execute(
                "DELETE FROM npc_empire_events WHERE leader_id=? AND id NOT IN "
                "(SELECT id FROM npc_empire_events WHERE leader_id=? "
                "ORDER BY id DESC LIMIT ?)",
                (memory_leader, memory_leader, NPC_EVENT_MEMORY_LIMIT),
            )
        await _recompute_districts(db, now)
        await db.execute("DELETE FROM npc_empire_assaults WHERE expires_at<?", (now - 3600,))
        await db.commit()
    return events


def _player_war_interval(profile: EmpireProfile) -> int:
    """Aggressive families strike more often, but never on a render/game loop."""
    return 20 * 60 + max(0, 100 - profile.aggression) * 12


async def _create_interior_raid(db, telegram_id: int, leader_id: str,
                                target: dict, attack_no: int, now: int) -> dict | None:
    profile = PROFILE_BY_ID[leader_id]
    allocation = await _npc_attack_allocation(db, leader_id)
    if not allocation or allocation['count'] < 2:
        return None
    apt_key = str(target.get('apt_key') or f"business:{target['holding_id']}")
    defender_ids = []
    try:
        defender_ids = [int(row[0]) for row in await (await db.execute(
            "SELECT pg.member_id FROM npc_empire_player_guard_members pg "
            "JOIN gang_members gm ON gm.id=pg.member_id AND gm.telegram_id=pg.owner_uid "
            "WHERE pg.owner_uid=? AND pg.holding_ref=? "
            "AND (gm.current_hp IS NULL OR gm.current_hp>0) ORDER BY pg.member_id",
            (telegram_id, str(target['ref'])))).fetchall()]
    except aiosqlite.Error:
        defender_ids = []
    defender_ids = defender_ids[:PLAYER_INTERIOR_RAID_MAX_DEFENDERS]
    # There is one actual assigned roster, not a second synthetic guard layer.
    # guard_count remains a legacy display alias for older clients.
    guard_ids: list[int] = []
    guard_count = len(defender_ids)
    defender_quality = allocate_physical_roster(
        side='defender', roster_available=len(defender_ids), members=len(defender_ids),
        strength=len(defender_ids) * 25, treasury=0, aggression=0,
        guard_level=max(0, guard_count * 2 - 1))
    token = secrets.token_urlsafe(18)
    r, c = _player_business_target_point(target)
    label = (BUILDING_OPERATIONS.get(str(target.get('operation_type') or ''), {}).get('name')
             or str(target.get('holding_id') or 'Бизнес'))
    await db.execute(
        "INSERT INTO npc_empire_interior_raids"
        "(token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,operation_type,"
        "business_label,force,attacker_cost,tier,quality,hp,accuracy,weapon_budget,"
        "defender_ids_json,guard_ids_json,guard_count,attack_no,started_at,hold_seconds,expires_at) "
        "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (token, telegram_id, leader_id, apt_key, str(target['ref']), str(target['kind']),
         str(target['holding_id']), str(target.get('operation_type') or ''), label,
         allocation['count'], allocation['cost'], allocation['tier'], allocation['quality'],
         allocation['hp'], allocation['accuracy'], allocation['weapon_budget'],
         json.dumps(defender_ids), json.dumps(guard_ids), guard_count, attack_no, now,
         PLAYER_INTERIOR_RAID_HOLD_SECONDS, now + PLAYER_INTERIOR_RAID_EXPIRES_SECONDS))
    await db.execute(
        "UPDATE npc_empires SET treasury=treasury-? WHERE leader_id=?",
        (allocation['cost'], leader_id))
    return {
        'token': token, 'apt_key': apt_key, 'business_label': label,
        'leader_id': leader_id, 'leader_name': profile.leader_name,
        'gang_name': profile.gang_name, 'target_r': float(r), 'target_c': float(c),
        'force': allocation['count'], 'quality': allocation['quality'],
        'tier': allocation['tier'], 'hp': allocation['hp'],
        'accuracy': allocation['accuracy'], 'weapon_budget': allocation['weapon_budget'],
        'defender_count': len(defender_ids),
        'guard_count': min(guard_count, PLAYER_INTERIOR_RAID_MAX_DEFENDERS),
        'started_at': now, 'hold_seconds': PLAYER_INTERIOR_RAID_HOLD_SECONDS,
        'expires_at': now + PLAYER_INTERIOR_RAID_EXPIRES_SECONDS,
    }


async def _apply_player_war_pressure(db_path: str, telegram_id: int, now: int,
                                     resolve_token: str = '') -> list[dict]:
    """Resolve due, server-authoritative attacks against one player's businesses."""
    events: list[dict] = []
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        # An abandoned browser must not pin a family forever. Expiry is handled
        # in the same bounded player-state transaction and creates no event.
        await db.execute(
            "UPDATE npc_empire_interior_raids SET status='resolved',"
            "resolution='expired',resolved_at=? WHERE telegram_id=? "
            "AND status='pending' AND expires_at<=?",
            (now, telegram_id, now),
        )
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
        businesses = await _player_business_targets(db, telegram_id)
        due = await (await db.execute(
            "SELECT leader_id,attacks FROM npc_empire_player_wars "
            "WHERE telegram_id=? AND next_attack_at<=? ORDER BY next_attack_at,leader_id",
            (telegram_id, now),
        )).fetchall()
        resolved_session = None
        if resolve_token:
            resolved_session = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=? AND telegram_id=?",
                (resolve_token, telegram_id))).fetchone()
        for row in due:
            leader_id = str(row['leader_id'])
            if resolved_session and leader_id != str(resolved_session['leader_id']):
                continue
            if leader_id not in active:
                continue
            profile = PROFILE_BY_ID[leader_id]
            biz_id = ''
            target_ref = ''
            target_kind = ''
            operation_type = ''
            if businesses:
                attack_no = int(row['attacks'] or 0)
                war_row = await (await db.execute(
                    "SELECT last_business_id FROM npc_empire_player_wars WHERE leader_id=? AND telegram_id=?",
                    (leader_id, telegram_id),
                )).fetchone()
                last_biz = str(war_row['last_business_id'] or '') if war_row else ''
                if not resolve_token:
                    existing = await (await db.execute(
                        "SELECT token,expires_at FROM npc_empire_interior_raids "
                        "WHERE telegram_id=? AND leader_id=? AND status='pending'",
                        (telegram_id, leader_id))).fetchone()
                    if existing:
                        # Check persisted work before rescoring. A reconnect can
                        # arrive after guards or the mobile roster changed, but
                        # neither may invalidate or duplicate the active raid.
                        await db.execute(
                            "UPDATE npc_empire_player_wars SET next_attack_at="
                            "MAX(next_attack_at,?) WHERE leader_id=? AND telegram_id=?",
                            (int(existing['expires_at'] or now) + 1,
                             leader_id, telegram_id),
                        )
                        continue
                target = await _select_player_business_target_smart(
                    db, telegram_id, leader_id, businesses, attack_no, last_biz)
                if resolved_session:
                    target = next((item for item in businesses
                                   if str(item['ref']) == str(resolved_session['target_ref'])), None)
                    if not target:
                        continue
                elif not target:
                    # The paid mobile roster cannot attack this defence with a
                    # plausible loss budget yet. Keep the war and reassess after
                    # reinforcement/upkeep rather than materialising free NPCs.
                    await db.execute(
                        "UPDATE npc_empire_player_wars SET next_attack_at=? "
                        "WHERE leader_id=? AND telegram_id=?",
                        (now + _player_war_interval(profile), leader_id, telegram_id))
                    continue
                target_ref = str(target['ref'])
                target_kind = str(target['kind'])
                biz_id = str(target['holding_id'])
                if not resolve_token:
                    raid = await _create_interior_raid(
                        db, telegram_id, leader_id, target, attack_no, now)
                    if raid:
                        summary = (f'{profile.leader_name} ведёт {raid["force"]} бойцов '
                                   f'на внутренний штурм «{raid["business_label"]}»')
                        await db.execute(
                            "INSERT INTO npc_empire_events"
                            "(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                            (leader_id, 'player_business_interior_raid', str(telegram_id),
                             summary, now))
                        await db.execute(
                            "UPDATE npc_empire_player_wars SET next_attack_at=? "
                            "WHERE leader_id=? AND telegram_id=?",
                            (int(raid['expires_at']) + 1, leader_id, telegram_id),
                        )
                        events.append({'leader_id': leader_id,
                                       'kind': 'player_business_interior_raid',
                                       'business_id': biz_id,
                                       'property_kind': target_kind,
                                       'operation_type': str(target.get('operation_type') or ''),
                                       'summary': summary, **raid})
                        continue
                    await db.execute(
                        "UPDATE npc_empire_player_wars SET next_attack_at=? "
                        "WHERE leader_id=? AND telegram_id=?",
                        (now + _player_war_interval(profile), leader_id, telegram_id))
                    continue
                capture = attack_no % 2 == 1 and last_biz in {target_ref, biz_id}
                if capture:
                    await _clear_holding_guard_assignment(
                        db, 'player', str(telegram_id), target_ref)
                    if target_kind == 'building':
                        operation_type = choose_captured_building_operation(
                            profile, biz_id, str(target.get('operation_type') or ''), now + attack_no)
                        area = max(4, int(target.get('area') or BUILDING_AREAS.get(biz_id, 4)))
                        income = building_operation_income(operation_type, area)
                        await db.execute(
                            "DELETE FROM apartments_owned WHERE telegram_id=? AND apt_key=?",
                            (telegram_id, str(target.get('apt_key') or biz_id)),
                        )
                        await db.execute(
                            "DELETE FROM npc_empire_building_closures WHERE holding_id=?", (biz_id,))
                        await db.execute(
                            "INSERT OR REPLACE INTO npc_empire_holdings"
                            "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                            "VALUES('building',?,?,?,?,?,?,?)",
                            (biz_id, leader_id, income, 45 + profile.loyalty // 2,
                             now, operation_type, area),
                        )
                    else:
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
                            (biz_id, leader_id, BUSINESS_INCOME.get(biz_id, 175),
                             60 + profile.loyalty, now),
                        )
                    businesses = [item for item in businesses if str(item['ref']) != target_ref]
                    summary = f'{profile.leader_name} и {profile.gang_name} захватили бизнес {biz_id}'
                    kind = 'player_business_captured'
                else:
                    blocked_until = now + PLAYER_WAR_BUSINESS_BLOCK_SECONDS
                    notice = f'{profile.gang_name} атаковала бизнес. Работа остановлена на 10 минут; следующий налёт может закончиться захватом.'
                    if target_kind == 'building':
                        await db.execute(
                            "INSERT INTO npc_empire_building_closures"
                            "(holding_id,leader_id,saboteur_uid,closed_until,created_at) VALUES(?,?,?,?,?) "
                            "ON CONFLICT(holding_id) DO UPDATE SET leader_id=excluded.leader_id,"
                            "saboteur_uid=excluded.saboteur_uid,closed_until=excluded.closed_until,"
                            "created_at=excluded.created_at",
                            (biz_id, leader_id, telegram_id, blocked_until, now),
                        )
                        # Move the accrual cursor to reopening time: otherwise a
                        # later collection would silently pay the closed period.
                        await db.execute(
                            "UPDATE apartments_owned SET last_income_at=MAX(COALESCE(last_income_at,0),?) "
                            "WHERE telegram_id=? AND apt_key=?",
                            (blocked_until, telegram_id, str(target.get('apt_key') or biz_id)),
                        )
                    else:
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
                (target_ref if kind == 'player_business_bombed' else '',
                 now, next_pressure_at, leader_id, telegram_id),
            )
            events.append({'leader_id': leader_id, 'kind': kind, 'business_id': biz_id,
                           'property_kind': target_kind, 'operation_type': operation_type,
                           'summary': summary, 'created_at': now})
        await db.commit()
    return events


async def resolve_interior_raid(db_path: str, telegram_id: int, token: str,
                                apt_key: str, outcome: str,
                                now: int | None = None,
                                attacker_casualties: list[int] | None = None,
                                defender_casualties: list[int] | None = None,
                                guard_casualties: list[int] | None = None) -> dict:
    """Resolve one physical interior raid once, then invoke the old war phase."""
    now = int(now or time.time()); outcome = str(outcome or '')
    if outcome not in {'defended', 'captured'}:
        return {'ok': False, 'error': 'bad outcome'}
    await ensure_schema(db_path)
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row; await db.execute('BEGIN IMMEDIATE')
        raid = await (await db.execute(
            "SELECT * FROM npc_empire_interior_raids WHERE token=? AND telegram_id=?",
            (token, telegram_id))).fetchone()
        if not raid or str(raid['apt_key']) != str(apt_key):
            await db.rollback(); return {'ok': False, 'error': 'raid not found'}
        if str(raid['status']) != 'pending':
            await db.rollback()
            return {'ok': True, 'duplicate': True, 'resolution': str(raid['resolution'])}
        force = max(0, int(raid['force'] or 0)); leader_id = str(raid['leader_id'])
        valid_attacker_slots = set(range(force))
        try:
            requested_attackers = {int(value) for value in (attacker_casualties or [])}
            requested_defenders = {int(value) for value in (defender_casualties or [])}
            requested_guards = {int(value) for value in (guard_casualties or [])}
        except (TypeError, ValueError):
            await db.rollback(); return {'ok': False, 'error': 'bad casualty payload'}
        if requested_attackers - valid_attacker_slots:
            await db.rollback(); return {'ok': False, 'error': 'bad attacker casualties'}
        elapsed = now - int(raid['started_at'] or now)
        required = (PLAYER_INTERIOR_RAID_MIN_SECONDS if outcome == 'defended'
                    else int(raid['hold_seconds'] or PLAYER_INTERIOR_RAID_HOLD_SECONDS))
        all_attackers_down = (outcome == 'defended' and attacker_casualties is not None
                              and requested_attackers == valid_attacker_slots)
        if elapsed < required and not all_attackers_down and now < int(raid['expires_at'] or 0):
            await db.rollback()
            return {'ok': False, 'error': 'raid still active', 'retry_after': required-elapsed}
        attacker_losses = (len(requested_attackers) if attacker_casualties is not None else
                           min(force, max(1, force // (2 if outcome == 'defended' else 4))))
        await db.execute(
            "UPDATE npc_empires SET members=MAX(1,members-?),"
            "strength=MAX(20,strength-?) WHERE leader_id=?",
            (attacker_losses, attacker_losses * 11, leader_id))
        defender_ids = [int(value) for value in json.loads(
            str(raid['defender_ids_json'] or '[]'))]
        if requested_defenders - set(defender_ids):
            await db.rollback(); return {'ok': False, 'error': 'bad defender casualties'}
        lost_defenders = (sorted(requested_defenders) if defender_casualties is not None else
                          defender_ids[:min(len(defender_ids),
                                           max(0, force-int(raid['guard_count'] or 0)) // 2)]
                          if outcome == 'captured' else [])
        defender_losses = len(lost_defenders)
        if defender_losses:
            marks = ','.join('?' for _ in lost_defenders)
            try:
                await db.execute(
                    f"UPDATE gang_members SET current_hp=0 WHERE telegram_id=? AND id IN ({marks})",
                    (telegram_id, *lost_defenders))
            except aiosqlite.Error:
                pass
            await db.execute(
                f"DELETE FROM npc_empire_player_guard_members WHERE member_id IN ({marks})",
                tuple(lost_defenders))
            await db.execute(
                "UPDATE npc_empire_guard_assignments SET living=MAX(0,living-?) "
                "WHERE owner_kind='player' AND owner_id=? AND holding_ref=?",
                (defender_losses, str(telegram_id), str(raid['target_ref'])))
        session_guard_ids = [int(value) for value in json.loads(
            str(raid['guard_ids_json'] or '[]'))]
        if requested_guards - set(session_guard_ids):
            await db.rollback(); return {'ok': False, 'error': 'bad guard casualties'}
        # Legacy guard layer is empty for new sessions; preserve exact lists for
        # old pending sessions regardless of the combat outcome.
        lost_guards = (sorted(requested_guards) if guard_casualties is not None else
                       session_guard_ids[:min(len(session_guard_ids), max(1, force // 3))]
                       if outcome == 'captured' else [])
        guard_losses = len(lost_guards)
        if guard_losses:
            marks = ','.join('?' for _ in lost_guards)
            try:
                await db.execute(
                    f"UPDATE gang_members SET current_hp=0 WHERE telegram_id=? AND id IN ({marks})",
                    (telegram_id, *lost_guards))
            except aiosqlite.Error:
                pass
            await db.execute(
                f"DELETE FROM npc_empire_player_guard_members WHERE member_id IN ({marks})",
                tuple(lost_guards))
            await db.execute(
                "UPDATE npc_empire_guard_assignments SET living=MAX(0,living-?) "
                "WHERE owner_kind='player' AND owner_id=? AND holding_ref=?",
                (guard_losses, str(telegram_id), str(raid['target_ref'])))
        await db.execute(
            "UPDATE npc_empire_interior_raids SET status='resolved',resolution=?,resolved_at=? "
            "WHERE token=? AND status='pending'", (outcome, now, token))
        if outcome == 'defended':
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? "
                "WHERE leader_id=? AND telegram_id=?",
                (now + _player_war_interval(PROFILE_BY_ID[leader_id]), leader_id, telegram_id))
        else:
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? "
                "WHERE leader_id=? AND telegram_id=?", (now, leader_id, telegram_id))
        await db.commit()
    phase_events = ([] if outcome == 'defended' else
                    await _apply_player_war_pressure(
                        db_path, telegram_id, now, resolve_token=token))
    return {'ok': True, 'resolution': outcome, 'attacker_losses': attacker_losses,
            'defender_losses': defender_losses, 'phase_events': phase_events}


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
        closure_rows = {str(r['holding_id']): dict(r) for r in await (await db.execute(
            "SELECT holding_id,leader_id,closed_until,created_at FROM npc_empire_building_closures WHERE closed_until>?",
            (now,),
        )).fetchall()}
        diplomacy_rows = [dict(r) for r in await (await db.execute(
            "SELECT leader_a,leader_b,score,pact,tension,last_event_at FROM npc_empire_diplomacy"
        )).fetchall()]
        for diplomacy in diplomacy_rows:
            diplomacy['relation_band'] = relation_band(int(diplomacy.get('score') or 0))
            diplomacy['pact_label'] = NPC_PACT_LABELS.get(
                str(diplomacy.get('pact') or 'none'), str(diplomacy.get('pact') or 'none'))
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
        raid_rows = [dict(r) for r in await (await db.execute(
            "SELECT * FROM npc_empire_interior_raids "
            "WHERE telegram_id=? AND status='pending' ORDER BY started_at,token",
            (telegram_id,))).fetchall()]
        holdings_by_leader = {profile.leader_id: [] for profile in PROFILES}
        for holding_row in holdings_rows:
            holdings_by_leader.setdefault(str(holding_row['leader_id']), []).append(holding_row)
        for empire_row in rows:
            guard_leader = str(empire_row['leader_id'])
            wars = sum(1 for pact_row in diplomacy_rows
                       if str(pact_row.get('pact') or '') == 'war'
                       and guard_leader in {str(pact_row.get('leader_a')),
                                            str(pact_row.get('leader_b'))})
            wars += int(guard_leader in war_rows)
            await _rebalance_npc_holding_guards(
                db, guard_leader, holdings_by_leader.get(guard_leader, []),
                int(empire_row['members'] or 0), wars, now,
                {f"building:{item['holding_id']}"
                 for item in holdings_by_leader.get(guard_leader, [])
                 if str(item['kind']) == 'building'
                 and str(item['holding_id']) in closure_rows})
        await db.commit()
        npc_guard_assignments = {
            (str(r['owner_id']), str(r['holding_ref'])): int(r['living'] or 0)
            for r in await (await db.execute(
                "SELECT owner_id,holding_ref,living FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc'"
            )).fetchall()}
        player_business_targets = await _player_business_targets(db, telegram_id)
        pending_by_leader = {
            str(raid.get('leader_id') or ''): raid for raid in raid_rows
        }
        smart_player_targets = {
            leader_id: await _select_player_business_target_smart(
                db, telegram_id, leader_id, player_business_targets,
                int(war.get('attacks') or 0),
                str(war.get('last_business_id') or ''))
            for leader_id, war in war_rows.items()
            if leader_id not in pending_by_leader
        }
    holdings: dict[str, list] = {p.leader_id: [] for p in PROFILES}
    for row in holdings_rows:
        item = dict(row)
        item['guard_count'] = npc_guard_assignments.get((
            str(row['leader_id']),
            f"{str(item.get('kind') or '')}:{str(item.get('holding_id') or '')}"), 0)
        operation = str(item.get('operation_type') or '')
        if item.get('kind') == 'building' and operation in BUILDING_OPERATIONS:
            item['operation_name'] = BUILDING_OPERATIONS[operation]['name']
            item['operation_icon'] = BUILDING_OPERATIONS[operation]['icon']
            item['income_unit'] = 'minute'
            area = int(item.get('area') or 4)
            item['size_class'] = 'large' if area >= 24 else 'medium' if area >= 16 else 'small'
            closure = closure_rows.get(str(item['holding_id']))
            item['closed_until'] = int(closure.get('closed_until') or 0) if closure else 0
            item['closed_s'] = max(0, item['closed_until'] - now)
            item['building_status'] = 'closed' if item['closed_s'] else 'open'
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
        for holding in leader_holdings:
            if str(holding.get('kind') or '') != 'building':
                continue
            holding['sale_price'] = npc_building_sale_price(
                str(holding.get('holding_id') or ''),
                str(holding.get('operation_type') or ''), int(holding.get('area') or 4))
            holding['sale_chance'] = npc_building_sale_chance(score, str(relation.get('pact') or 'none'))
        recruitment = _recruitment_state(profile, row, now)
        leader_events = events_by_leader.get(leader_id, [])
        memory = _boss_memory_cards(leader_events, now)
        active_wars = sum(1 for pact_row in diplomacy_rows
                          if str(pact_row.get('pact') or '') == 'war'
                          and leader_id in {str(pact_row.get('leader_a')), str(pact_row.get('leader_b'))})
        if leader_id in war_rows:
            active_wars += 1
        guard_slots = sum(int(holding.get('guard_count') or 0)
                          for holding in leader_holdings)
        income_per_tick = empire_holding_income_per_tick([
            holding for holding in leader_holdings
            if int(holding.get('closed_until') or 0) <= now
        ])
        upkeep_per_tick = (
            max(4, int(row['members'] or 0) * NPC_MEMBER_UPKEEP_PER_TICK)
            + guard_slots * NPC_HOLDING_GUARD_UPKEEP_PER_TICK
            + active_wars * NPC_ACTIVE_WAR_UPKEEP_PER_TICK
        )
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
            'insolvent_ticks': int(row['insolvent_ticks'] or 0),
            'recovery_ticks_remaining': int(row['recovery_ticks_remaining'] or 0),
            'distributed_profit': int(row['distributed_profit'] or 0),
            'economy': {
                'income_per_tick': income_per_tick,
                'member_upkeep': max(4, int(row['members'] or 0) * NPC_MEMBER_UPKEEP_PER_TICK),
                'guard_upkeep': guard_slots * NPC_HOLDING_GUARD_UPKEEP_PER_TICK,
                'war_upkeep': active_wars * NPC_ACTIVE_WAR_UPKEEP_PER_TICK,
                'upkeep_per_tick': upkeep_per_tick,
                'net_per_tick': income_per_tick - upkeep_per_tick,
                'reserve_target': operating_reserve(
                    int(row['members'] or 0), guard_slots, active_wars),
                'recovery_stipend_left': (int(row['recovery_ticks_remaining'] or 0)
                                          * NPC_RECOVERY_STIPEND_PER_TICK),
                'liquidity_ceiling': settle_operating_liquidity(
                    int(row['treasury'] or 0), income_per_tick,
                    int(row['members'] or 0), guard_slots, active_wars)['ceiling'],
            },
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
    # A boss at war with this player physically travels to the selected asset.
    # The same deterministic target drives the server's two-phase damage/capture
    # resolution, so the visible order cannot point at an unrelated building.
    for empire in result:
        war = war_rows.get(str(empire['leader_id']))
        if not war or int(empire.get('hospital_until') or 0) > now:
            continue
        pending = pending_by_leader.get(str(empire['leader_id']))
        target = (next((item for item in player_business_targets
                        if pending and str(item['ref']) == str(pending.get('target_ref') or '')), None)
                  if pending else smart_player_targets.get(str(empire['leader_id'])))
        if player_business_targets and target is None and not pending:
            # The server postponed this assault as tactically irrational; do
            # not make the client show a contradictory march to a fake target.
            continue
        activity = _player_war_activity(
            PROFILE_BY_ID[str(empire['leader_id'])], war, target, now)
        if pending:
            # The marker follows the immutable pending session, never a fresh
            # score after guards or income change during reconnect.
            fallback = {'kind': str(pending.get('target_kind') or ''),
                        'holding_id': str(pending.get('holding_id') or '')}
            r, c = _player_business_target_point(target or fallback)
            activity.update({
                'target_id': str(pending.get('holding_id') or ''),
                'target_kind': str(pending.get('target_kind') or ''),
                'target_r': float(r), 'target_c': float(c), 'phase': 'interior',
                'force': int(pending.get('force') or 0),
                'created_at': int(pending.get('started_at') or now),
                'raid_token': str(pending.get('token') or ''),
            })
        empire['activity'] = activity
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
        if str(empire['leader_id']) in war_rows:
            continue
        if int(empire.get('hospital_until') or 0) > now:
            continue
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
    districts = []
    for row in district_rows:
        leader_score = max(0, int(row.get('score') or 0))
        runner_score = max(0, int(row.get('runner_up_score') or 0))
        score_total = leader_score + runner_score
        districts.append({
            **row,
            'name': DISTRICTS.get(str(row['district_id']), str(row['district_id'])),
            'contested': bool(row['contested']),
            'control_percent': (round(leader_score * 100 / score_total)
                                if row.get('leader_id') and score_total else 0),
            'control_state': ('neutral' if not row.get('leader_id') else
                              'contested' if bool(row['contested']) else 'leader'),
        })
    interior_raids = []
    for raid in raid_rows:
        profile = PROFILE_BY_ID.get(str(raid['leader_id']))
        target = next((item for item in player_business_targets
                       if str(item['ref']) == str(raid['target_ref'])), None)
        r, c = _player_business_target_point(target or {
            'kind': raid['target_kind'], 'holding_id': raid['holding_id']})
        defender_ids = [int(value) for value in json.loads(
            str(raid['defender_ids_json'] or '[]'))]
        guard_ids = [int(value) for value in json.loads(
            str(raid['guard_ids_json'] or '[]'))]
        tier = int(raid['tier']); quality = int(raid['quality'])
        attacker_roster = [{
            'slot': slot, 'role': ('breacher' if slot == 0 else
                                   'support' if slot % 3 == 0 else 'assault'),
            'hp': int(raid['hp']), 'accuracy': float(raid['accuracy']),
            'weapon_budget': int(raid['weapon_budget']),
            'tier': tier, 'quality': quality,
        } for slot in range(int(raid['force']))]
        defender_roster = [{
            'member_id': member_id, 'role': 'holding_guard',
            'hp': 100, 'accuracy': round(min(.78, .42 + tier * .07), 3),
            'tier': max(1, tier-1),
        } for member_id in defender_ids]
        guard_roster = [{
            'member_id': member_id, 'role': 'holding_guard',
            'hp': 110, 'accuracy': round(min(.8, .45 + tier * .07), 3),
            'tier': tier,
        } for member_id in guard_ids]
        interior_raids.append({
            'token': str(raid['token']), 'apt_key': str(raid['apt_key']),
            'business_label': str(raid['business_label']),
            'target_id': str(raid['holding_id']),
            'target_kind': str(raid['target_kind']),
            'leader_id': str(raid['leader_id']),
            'leader_name': profile.leader_name if profile else str(raid['leader_id']),
            'gang_name': profile.gang_name if profile else '',
            'target_r': float(r), 'target_c': float(c),
            'force': int(raid['force']), 'quality': int(raid['quality']),
            'tier': int(raid['tier']), 'hp': int(raid['hp']),
            'accuracy': float(raid['accuracy']),
            'weapon_budget': int(raid['weapon_budget']),
            'guard_count': int(raid['guard_count']),
            'defender_count': len(defender_roster),
            'attacker_roster': attacker_roster,
            'defender_roster': defender_roster,
            'guard_roster': guard_roster,
            'started_at': int(raid['started_at']),
            'hold_seconds': int(raid['hold_seconds']),
            'expires_at': int(raid['expires_at']),
        })
    return {'empires': result, 'leaderboard': [e['leader_id'] for e in leaderboard],
            'districts': districts, 'diplomacy': diplomacy_rows, 'events': recent[:60],
            'player_war_events': player_war_events,
            'interior_raids': interior_raids,
            'server_time': now, 'tick_seconds': TICK_SECONDS}


def _apartment_key_building_key(apt_key: str) -> str:
    value = str(apt_key or '')
    try:
        if value.startswith('tile:'):
            r_text, c_text = value[5:].split(',', 1)
            return f'{int(r_text)//10},{int(c_text)//10}'
        br_text, bc_text = value.split(',', 1)
        return f'{int(br_text)},{int(bc_text)}'
    except (TypeError, ValueError):
        return ''


async def npc_building_action(db_path: str, telegram_id: int, leader_id: str,
                              holding_id: str, action: str,
                              now: int | None = None, roll: int | None = None) -> dict:
    """Negotiate for or sabotage one generic NPC-owned business building."""
    now = int(now or time.time())
    leader_id, holding_id = str(leader_id or ''), str(holding_id or '')
    action = str(action or '')
    if leader_id not in PROFILE_BY_ID:
        return {'ok': False, 'error': 'unknown leader'}
    if holding_id not in BUILDING_AREAS:
        return {'ok': False, 'error': 'bad building'}
    if action not in {'purchase', 'sabotage'}:
        return {'ok': False, 'error': 'bad action'}
    await ensure_schema(db_path)
    profile = PROFILE_BY_ID[leader_id]
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        holding = await (await db.execute(
            "SELECT leader_id,income,operation_type,area FROM npc_empire_holdings "
            "WHERE kind='building' AND holding_id=?", (holding_id,)
        )).fetchone()
        if not holding or str(holding['leader_id']) != leader_id:
            await db.rollback()
            return {'ok': False, 'error': 'ownership changed'}
        closure = await (await db.execute(
            "SELECT closed_until FROM npc_empire_building_closures WHERE holding_id=?",
            (holding_id,),
        )).fetchone()
        closed_until = int(closure['closed_until'] or 0) if closure else 0
        if closed_until > now:
            await db.rollback()
            return {'ok': False, 'error': 'closed', 'closed_until': closed_until,
                    'closed_s': closed_until - now}
        if closure:
            await db.execute("DELETE FROM npc_empire_building_closures WHERE holding_id=?", (holding_id,))
        relation = await (await db.execute(
            "SELECT score,pact FROM npc_empire_relations WHERE leader_id=? AND telegram_id=?",
            (leader_id, telegram_id),
        )).fetchone()
        score = clamp_relation(int(relation['score'] if relation else 0))
        pact = str(relation['pact'] if relation else 'none')
        operation_type = str(holding['operation_type'] or '')
        area = max(4, int(holding['area'] or BUILDING_AREAS[holding_id]))
        price = npc_building_sale_price(holding_id, operation_type, area)
        if action == 'purchase':
            char = await (await db.execute(
                "SELECT cash FROM characters WHERE telegram_id=?", (telegram_id,)
            )).fetchone()
            if not char:
                await db.rollback(); return {'ok': False, 'error': 'no character'}
            cash = int(char['cash'] or 0)
            if cash < price:
                await db.rollback()
                return {'ok': False, 'error': 'no cash', 'cash': cash, 'price': price}
            mine = await (await db.execute(
                "SELECT apt_key FROM apartments_owned WHERE telegram_id=?", (telegram_id,)
            )).fetchall()
            if any(_apartment_key_building_key(row['apt_key']) == holding_id for row in mine):
                await db.rollback(); return {'ok': False, 'error': 'already owned'}
            chance = npc_building_sale_chance(score, pact)
            decision_roll = max(1, min(100, int(roll))) if roll is not None else secrets.randbelow(100) + 1
            if chance <= 0 or decision_roll > chance:
                await db.commit()
                return {'ok': True, 'sold': False, 'leader_id': leader_id,
                        'leader_name': profile.leader_name, 'holding_id': holding_id,
                        'relation': score, 'sale_chance': chance, 'price': price,
                        'message': 'Я отказываюсь продавать это заведение.'}
            new_score = clamp_relation(score + 5)
            await db.execute("UPDATE characters SET cash=cash-? WHERE telegram_id=?", (price, telegram_id))
            await db.execute("UPDATE npc_empires SET treasury=treasury+?,version=version+1 WHERE leader_id=?",
                             (price, leader_id))
            await db.execute("DELETE FROM npc_empire_holdings WHERE kind='building' AND holding_id=? AND leader_id=?",
                             (holding_id, leader_id))
            await _clear_holding_guard_assignment(
                db, 'npc', leader_id, f'building:{holding_id}')
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute,last_income_at) "
                "VALUES(?,?,?,?, 'business',?,?,?,?)",
                (telegram_id, holding_id, price, now, operation_type, area,
                 building_operation_income(operation_type, area), now),
            )
            await db.execute(
                "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,?,?,?) "
                "ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=excluded.score,last_action_at=excluded.last_action_at",
                (leader_id, telegram_id, new_score, pact, now),
            )
            await db.execute(
                "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                (leader_id, 'building_sold', str(telegram_id),
                 f'{profile.leader_name} продал игроку заведение {holding_id} за ${price}', now),
            )
            await db.commit()
            return {'ok': True, 'sold': True, 'leader_id': leader_id,
                    'leader_name': profile.leader_name, 'gang_name': profile.gang_name,
                    'holding_id': holding_id, 'apt_key': holding_id,
                    'operation_type': operation_type,
                    'operation_name': BUILDING_OPERATIONS[operation_type]['name'],
                    'operation_icon': BUILDING_OPERATIONS[operation_type]['icon'],
                    'income_per_minute': building_operation_income(operation_type, area),
                    'area': area, 'price': price, 'cash': cash-price,
                    'relation': new_score, 'sale_chance': chance,
                    'message': 'Спасибо за покупку. Заведение теперь твоё.'}
        c4_row = await (await db.execute(
            "SELECT quantity FROM inventory WHERE telegram_id=? AND item_id='c4'",
            (telegram_id,),
        )).fetchone()
        c4_count = max(0, int(c4_row['quantity'] or 0)) if c4_row else 0
        if c4_count < 1:
            await db.rollback()
            return {'ok': False, 'error': 'no c4', 'c4_left': 0}
        if c4_count == 1:
            await db.execute(
                "DELETE FROM inventory WHERE telegram_id=? AND item_id='c4'",
                (telegram_id,),
            )
        else:
            await db.execute(
                "UPDATE inventory SET quantity=quantity-1 WHERE telegram_id=? AND item_id='c4'",
                (telegram_id,),
            )
        relation_loss = 20 + secrets.randbelow(11)
        new_score = clamp_relation(score - relation_loss)
        if pact in {'alliance', 'truce', 'vassal'} and new_score < 0:
            pact = 'none'
        closed_until = now + NPC_BUILDING_SABOTAGE_SECONDS
        await db.execute(
            "INSERT INTO npc_empire_building_closures"
            "(holding_id,leader_id,saboteur_uid,closed_until,created_at) VALUES(?,?,?,?,?) "
            "ON CONFLICT(holding_id) DO UPDATE SET leader_id=excluded.leader_id,"
            "saboteur_uid=excluded.saboteur_uid,closed_until=excluded.closed_until,created_at=excluded.created_at",
            (holding_id, leader_id, telegram_id, closed_until, now),
        )
        await db.execute(
            "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,?,?,?) "
            "ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=excluded.score,pact=excluded.pact,last_action_at=excluded.last_action_at",
            (leader_id, telegram_id, new_score, pact, now),
        )
        await db.execute(
            "INSERT INTO npc_empire_events(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
            (leader_id, 'building_sabotaged', str(telegram_id),
             f'Игрок подорвал заведение {holding_id}; закрыто на 5 минут', now),
        )
        await db.commit()
    return {'ok': True, 'sabotaged': True, 'leader_id': leader_id,
            'leader_name': profile.leader_name, 'holding_id': holding_id,
            'closed_until': closed_until, 'closed_s': NPC_BUILDING_SABOTAGE_SECONDS,
            'fuse_s': 3, 'c4_left': c4_count - 1,
            'relation': new_score, 'relation_delta': -relation_loss, 'pact': pact,
            'message': 'Ты ответишь за это. Заведение закрыто на ремонт.'}


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
                          choice: str, operation_type: str = '',
                          operation_map: dict[str, str] | None = None,
                          now: int | None = None) -> dict:
    """Resolve once: annex businesses, loot the treasury, or vassalize."""
    now = int(now or time.time())
    if choice not in {'annex','loot','vassalize'}:
        return {'ok': False, 'error': 'bad choice'}
    if choice == 'annex' and operation_type and operation_type not in BUILDING_OPERATIONS:
        return {'ok': False, 'error': 'bad operation'}
    raw_operation_map = operation_map or {}
    if not isinstance(raw_operation_map, dict) or len(raw_operation_map) > 64:
        return {'ok': False, 'error': 'bad operation map'}
    if any(not isinstance(key, str) or len(key) > 64 or
           not isinstance(value, str) or len(value) > 32
           for key, value in raw_operation_map.items()):
        return {'ok': False, 'error': 'bad operation map'}
    requested_operations = dict(raw_operation_map)
    if choice == 'annex' and any(
            value not in BUILDING_OPERATIONS for value in requested_operations.values()):
        return {'ok': False, 'error': 'bad operation map'}
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        assault = await (await db.execute("SELECT * FROM npc_empire_assaults WHERE token=? AND telegram_id=?", (token,telegram_id))).fetchone()
        if not assault or assault['status'] != 'active' or int(assault['boss_hp']) > 0:
            await db.rollback(); return {'ok': False, 'error': 'not won'}
        leader_id = str(assault['leader_id']); profile = PROFILE_BY_ID[leader_id]
        if choice == 'annex' and not operation_type:
            operation_type = choose_building_operation(profile, str(token), now)
        empire = await (await db.execute("SELECT * FROM npc_empires WHERE leader_id=?", (leader_id,))).fetchone()
        treasury = int(empire['treasury'] or 0); reward = 0; captured = [];captured_buildings=[];captured_headquarters=None
        if choice == 'vassalize':
            await db.execute("UPDATE npc_empires SET status='vassal',members=MAX(2,members/2),strength=MAX(40,strength/2),treasury=treasury/2,defeated_by=?,version=version+1 WHERE leader_id=?", (telegram_id,leader_id))
            await db.execute("INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?, ?,80,'vassal',?) ON CONFLICT(leader_id,telegram_id) DO UPDATE SET score=80,pact='vassal',last_action_at=excluded.last_action_at", (leader_id,telegram_id,now))
            reward = treasury // 2
        else:
            reward = treasury if choice == 'loot' else treasury // 3
            business_rows = await (await db.execute("SELECT holding_id FROM npc_empire_holdings WHERE leader_id=? AND kind='business'", (leader_id,))).fetchall()
            building_rows = await (await db.execute(
                "SELECT holding_id,area,operation_type FROM npc_empire_holdings "
                "WHERE leader_id=? AND kind='building' ORDER BY holding_id",
                (leader_id,))).fetchall()
            hq_key = str(empire['hq_key'] or '')
            capture_rows = ([{'holding_id': hq_key, 'area': CAPTURED_HQ_AREA,
                              'operation_type': '', 'source_kind': 'hq'}]
                            if hq_key else [])
            capture_rows.extend({**dict(item), 'source_kind': 'building'}
                                for item in building_rows)
            building_ids = {str(item['holding_id']) for item in capture_rows}
            if choice == 'annex' and not set(requested_operations).issubset(building_ids):
                await db.rollback(); return {'ok': False, 'error': 'unknown building'}
            apartments_table = await (await db.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='apartments_owned'"
            )).fetchone()
            if choice == 'annex':
                for item in business_rows:
                    biz_id = str(item['holding_id']); captured.append(biz_id)
                    await db.execute("DELETE FROM player_businesses WHERE biz_id=?", (biz_id,))
                    await db.execute("INSERT INTO player_businesses(telegram_id,biz_id,bought_at,last_collect,status,blocked_until,last_event_at,level,guards,pending_notice) VALUES(?,?,?,?, 'ok',0,0,1,0,?)", (telegram_id,biz_id,now,now,f'Отнят у банды {profile.gang_name}'))
                    await db.execute("INSERT OR REPLACE INTO business_property_owners(biz_id,owner_uid,owner_name,acquired_at,protected_until) VALUES(?,?,?,?,?)", (biz_id,telegram_id,'Победитель штаба',now,now+300))
                for item in capture_rows if apartments_table else ():
                    building_key=str(item['holding_id']);parts=building_key.split(',')
                    if len(parts)!=2: continue
                    try: apt_key=f'tile:{int(parts[0])*10+6},{int(parts[1])*10+6}'
                    except ValueError: continue
                    area=max(4,int(item['area'] or BUILDING_AREAS.get(building_key,CAPTURED_HQ_AREA)))
                    selected_operation=requested_operations.get(building_key,operation_type)
                    if not selected_operation:
                        selected_operation=choose_captured_building_operation(
                            profile,building_key,str(item['operation_type'] or ''),now)
                    income=building_operation_income(selected_operation,area)
                    # A won HQ is a transfer of the physical building, not a
                    # cash purchase. Clear any impossible stale duplicate so
                    # the world has exactly one authoritative owner.
                    await db.execute("DELETE FROM apartments_owned WHERE apt_key=?", (apt_key,))
                    cursor=await db.execute(
                        "INSERT INTO apartments_owned"
                        "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute,last_income_at) "
                        "VALUES(?,?,0,?,'business',?,?,?,?)",
                        (telegram_id,apt_key,now,selected_operation,area,income,now))
                    if int(cursor.rowcount or 0)==1:
                        capture={'building_key':building_key,'apt_key':apt_key,
                                                   'source_kind':str(item.get('source_kind') or 'building'),
                                                   'previous_operation_type':str(item['operation_type'] or ''),
                                                   'operation_type':selected_operation,
                                                   'operation_name':BUILDING_OPERATIONS[selected_operation]['name'],
                                                   'income_per_minute':income,'area':area}
                        captured_buildings.append(capture)
                        if capture['source_kind']=='hq': captured_headquarters=capture
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
            'captured_businesses': captured, 'captured_buildings': captured_buildings,
            'captured_headquarters': captured_headquarters,
            'operation_type': operation_type if choice == 'annex' else '',
            'operation_map': {item['building_key']:item['operation_type']
                              for item in captured_buildings},
            'cash': int(char['cash'] if char else reward)}
