import asyncio
import logging
import random
import time
import aiosqlite
import json
import urllib.parse
import os
from typing import Optional
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, LabeledPrice, WebAppInfo, KeyboardButton, ReplyKeyboardMarkup, ReplyKeyboardRemove
from telegram.error import Forbidden, BadRequest
from telegram.ext import (
    Application, ApplicationBuilder, CommandHandler, CallbackQueryHandler,
    MessageHandler, filters, ContextTypes, ConversationHandler,
    PreCheckoutQueryHandler
)

logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# ⬇️ ТОКЕН БОТА читаем из файла .bot-token (он в .gitignore — не попадёт в репозиторий)
import sys as _sys
_HERE = os.path.dirname(os.path.abspath(__file__))
_BOT_TOKEN_FILE = os.path.join(_HERE, ".bot-token")
try:
    with open(_BOT_TOKEN_FILE, "r", encoding="utf-8") as _f:
        BOT_TOKEN = _f.read().strip()
except FileNotFoundError:
    print(f"[!] Файл .bot-token не найден: {_BOT_TOKEN_FILE}")
    print(f"    Создай его и впиши туда токен от @BotFather одной строкой.")
    _sys.exit(1)
if not BOT_TOKEN or ":" not in BOT_TOKEN:
    print(f"[!] .bot-token пустой или не похож на токен Telegram-бота (формат: 12345:AAA...)")
    _sys.exit(1)

DB_PATH = "mafiozi.db"

def md(text: str) -> str:
    """Экранирует спецсимволы Markdown v1 для Telegram."""
    for ch in ('_', '*', '[', '`'):
        text = text.replace(ch, '\\' + ch)
    return text

async def _clear_district_photo(context, chat_id):
    """Удаляет фото района если оно есть."""
    photo_id = context.user_data.pop("district_photo_msg_id", None)
    if photo_id:
        try:
            await context.bot.delete_message(chat_id=chat_id, message_id=photo_id)
        except Exception:
            pass

async def _edit_text(query, text: str, **kwargs):
    """Универсальное редактирование сообщения. Если нельзя редактировать — шлёт новое.
    ReplyKeyboardMarkup нельзя передать через edit_message_text — отправляется отдельным шагом."""
    reply_kb = None
    if isinstance(kwargs.get("reply_markup"), ReplyKeyboardMarkup):
        reply_kb = kwargs.pop("reply_markup")
    try:
        await query.edit_message_text(text, **kwargs)
    except Exception:
        try:
            await query.message.delete()
        except Exception:
            pass
        await query.message._bot.send_message(
            chat_id=query.message.chat_id, text=text, **kwargs
        )
    if reply_kb:
        await query.message._bot.send_message(
            chat_id=query.message.chat_id,
            text="👇",
            reply_markup=reply_kb,
        )



# URL мини-приложения боя (загрузи .html на GitHub Pages и вставь ссылку)
BATTLE_WEBAPP_URL    = "https://slavaprivet.github.io/mafiozi-battle/"
ISO_WEBAPP_URL       = "https://slavaprivet.github.io/mafiozi-battle/demo_isometric.html"
CREATOR_WEBAPP_URL   = "https://slavaprivet.github.io/mafiozi-battle/creator.html"
HUB_WEBAPP_URL       = "https://slavaprivet.github.io/mafiozi-battle/hub.html"

# Co-op API base URL — публичный адрес бота (ngrok / VPS).
# Пример: "https://abc123.ngrok-free.app"
# Оставь пустым — кооператив будет отключён в мини-приложении.
COOP_API_BASE = os.environ.get("COOP_API_BASE", "")

# Имя бота (без @) для построения share-ссылок: t.me/<BOT_USERNAME>?startapp=...
# Заполняется в _post_init из bot.get_me().username.
BOT_USERNAME  = ""
CHOOSING_NAME, CHOOSING_CLASS = range(2)

# ============================================================
# ИГРОВЫЕ ДАННЫЕ
# ============================================================

CLASSES = {
    "killer":   {"name": "🔫 Киллер",   "hp": 110, "mana": 60,  "attack": 30, "defense": 10, "desc": "Хладнокровный профессионал. Смерть — его ремесло."},
    "enforcer": {"name": "🥊 Громила",  "hp": 160, "mana": 40,  "attack": 20, "defense": 18, "desc": "Стена из мышц. Ломает кости без угрызений совести."},
    "fixer":    {"name": "🃏 Решала",   "hp": 120, "mana": 80,  "attack": 24, "defense": 13, "desc": "Решает любые проблемы. Чаще всего — навсегда."},
    "conman":   {"name": "🎩 Аферист",  "hp": 100, "mana": 110, "attack": 22, "defense": 11, "desc": "Слова — его оружие. И иногда перо под ребро."},
}

SKILLS = {
    "killer":   {"name": "🎯 Контрольный выстрел",      "damage_mult": 2.5, "mana_cost": 25},
    "enforcer": {"name": "⛓️ Удар кастетом",             "damage_mult": 2.0, "mana_cost": 20},
    "fixer":    {"name": "🔪 Разборка по понятиям",      "damage_mult": 2.2, "mana_cost": 22},
    "conman":   {"name": "🧠 Психологическое давление",  "damage_mult": 1.8, "mana_cost": 20, "heal": 35},
}

LOCATIONS = {
    "market":  {"name": "🏪 Рынок",           "desc": "Шумный базар, где всё продаётся. Мелкая шпана трётся у ларьков.",              "min_level": 1,  "bosses": ["kosoy", "bychok", "zhigan", "shustryy"]},
    "port":    {"name": "⚓ Порт",             "desc": "Запах рыбы и солярки. Здесь разгружают не только рыбу.",                       "min_level": 5,  "bosses": ["tolsty", "kaban", "bukhgalter", "kontrabas"]},
    "casino":  {"name": "🎰 Казино",           "desc": "Блестящие огни и крупные ставки. За каждым столом — история с кровью.",        "min_level": 10, "bosses": ["legenda", "professor", "artist", "svalshchik"]},
    "factory": {"name": "🏭 Промзона",         "desc": "Заброшенные цеха. Сюда не возвращаются.",                                      "min_level": 15, "bosses": ["buryy", "khirurg", "tigr", "palach"]},
    "mansion": {"name": "🏛️ Резиденция Дона", "desc": "Роскошный особняк. Только лучшие попадают сюда... живыми.",                    "min_level": 20, "bosses": ["sedoy", "prizrak", "don_karlo", "vizir"]},
}

# Картинки районов (положи файлы в папку images/ рядом с ботом)
LOCATION_IMAGES = {
    "market":  "images/market.jpg",
    "port":    "images/port.jpg",
    "casino":  "images/casino.jpg",
    "factory": "images/factory.jpg",
    "mansion": "images/mansion.jpg",
}
# Кэш file_id — чтобы не загружать картинку каждый раз заново
_photo_cache: dict = {}

BOSSES = {
    "kosoy":       {"name": "😈 Косой",      "title": "Мелкий воришка",          "hp": 150,  "attack": 28,  "defense": 10,  "exp": 22,  "cash": 80,   "quote": "Да я тебя знаешь как...",            "drop": None},
    "bychok":      {"name": "🐂 Бычок",      "title": "Рыночный рэкетир",         "hp": 200,  "attack": 34,  "defense": 15,  "exp": 30,  "cash": 110,  "quote": "Чё уставился, баран?",               "drop": None},
    "zhigan":      {"name": "🪒 Жиган",      "title": "Карманник со стажем",      "hp": 338,  "attack": 55,  "defense": 26,  "exp": 52,  "cash": 169,  "quote": "Лоха видно за версту.",              "drop": ("passport", 0.40)},
    "tolsty":      {"name": "🐷 Толстый",    "title": "Смотрящий за портом",      "hp": 380,  "attack": 55,  "defense": 30,  "exp": 65,  "cash": 250,  "quote": "Всё через меня. Всё.",               "drop": None},
    "kaban":       {"name": "🦏 Кабан",      "title": "Бригадир докеров",         "hp": 440,  "attack": 52,  "defense": 36,  "exp": 75,  "cash": 280,  "quote": "Молчи и работай.",                   "drop": None},
    "bukhgalter":  {"name": "🧮 Бухгалтер",  "title": "Финансист группировки",    "hp": 360,  "attack": 65,  "defense": 28,  "exp": 80,  "cash": 350,  "quote": "Деньги счёт любят.",                 "drop": None},
    "legenda":     {"name": "👑 Легенда",    "title": "Живая икона криминала",    "hp": 520,  "attack": 78,  "defense": 42,  "exp": 100, "cash": 450,  "quote": "Меня знают все. Все боятся.",        "drop": None},
    "professor":   {"name": "🎓 Профессор",  "title": "Мастер схем и афер",       "hp": 460,  "attack": 82,  "defense": 35,  "exp": 110, "cash": 500,  "quote": "Ты просто пешка в моей игре.",       "drop": None},
    "artist":      {"name": "🎭 Артист",     "title": "Мошенник высшей пробы",    "hp": 500,  "attack": 88,  "defense": 38,  "exp": 120, "cash": 480,  "quote": "Жизнь — театр. А ты — массовка.",   "drop": None},
    "buryy":       {"name": "🐻 Бурый",      "title": "Авторитет старой закалки", "hp": 680,  "attack": 96,  "defense": 50,  "exp": 145, "cash": 650,  "quote": "Я тут раньше тебя, щенок.",          "drop": None},
    "khirurg":     {"name": "🩺 Хирург",     "title": "Чистильщик группировки",   "hp": 620,  "attack": 105, "defense": 48,  "exp": 155, "cash": 700,  "quote": "Больно не будет. Обещаю.",           "drop": None},
    "tigr":        {"name": "🐯 Тигр",       "title": "Наёмный убийца",           "hp": 750,  "attack": 100, "defense": 55,  "exp": 165, "cash": 720,  "quote": "Я не промахиваюсь.",                 "drop": None},
    "sedoy":       {"name": "👴 Седой",      "title": "Серый кардинал",           "hp": 920,  "attack": 120, "defense": 65,  "exp": 210, "cash": 950,  "quote": "Я видел, как рушились империи.",     "drop": None},
    "prizrak":     {"name": "👻 Призрак",    "title": "Невидимка преступного мира","hp": 860,  "attack": 135, "defense": 60,  "exp": 230, "cash": 1000, "quote": "Меня нет. Я везде.",                 "drop": None},
    "don_karlo":   {"name": "🤵 Дон Карло",  "title": "Крёстный отец",            "hp": 1400, "attack": 155, "defense": 90,  "exp": 420, "cash": 2000, "quote": "Сделаю предложение, от которого не откажешься.", "drop": None},
    "shustryy":    {"name": "🏃 Шустрый",    "title": "Карманник-скороход",       "hp": 300,  "attack": 48,  "defense": 22,  "exp": 45,  "cash": 160,  "quote": "Догони — тогда поговорим.",          "drop": None},
    "kontrabas":   {"name": "📦 Контрабас",   "title": "Портовый контрабандист",   "hp": 420,  "attack": 60,  "defense": 32,  "exp": 70,  "cash": 300,  "quote": "Таможня? Не слышал.",               "drop": None},
    "svalshchik":  {"name": "♟️ Сдатчик",     "title": "Предатель с опытом",       "hp": 480,  "attack": 72,  "defense": 30,  "exp": 90,  "cash": 400,  "quote": "Деловой разговор. Ничего личного.",  "drop": None},
    "palach":      {"name": "🪓 Палач",        "title": "Исполнитель приговоров",   "hp": 700,  "attack": 98,  "defense": 52,  "exp": 150, "cash": 680,  "quote": "Тебя сюда никто не звал.",          "drop": None},
    "vizir":       {"name": "🎯 Визирь",       "title": "Правая рука Дона",         "hp": 1050, "attack": 140, "defense": 78,  "exp": 300, "cash": 1500, "quote": "Дон знает о твоём визите.",         "drop": None},
    # Специальный враг — банда резиденции (при провале подкупа)
    "mansion_gang":{"name": "👥 Охрана Дона", "title": "Вооружённая толпа",        "hp": 600, "attack": 75, "defense": 45, "exp": 50,  "cash": 0,    "quote": "Ты пришёл не туда, приятель.",        "drop": None},
    # Заглушка для рейдовых боёв — реальные статы берутся из context.user_data["active_raid_boss"]
    "raid_boss":   {"name": "🔴 Вражеская банда", "title": "Рейд на район",         "hp": 200, "attack": 35, "defense": 15, "exp": 100, "cash": 500,  "quote": "Ваш район наш!",                     "drop": None},
}

# Главный босс каждого района (цель выслеживания)
LOCATION_MAIN_BOSS = {
    "market":  "zhigan",
    "port":    "bukhgalter",
    "casino":  "artist",
    "factory": "tigr",
    "mansion": "don_karlo",
}

HUNT_COOLDOWN  = 2 * 60   # 2 минуты между боями

# ── Система рейдов на районы ─────────────────────────────────────────────────
RAID_CHECK_INTERVAL = 24 * 3600  # проверка раз в сутки
RAID_EXPIRE_SECONDS = 15 * 60    # 15 минут на ответ владельца
RAID_CHANCE         = 0.20       # 20% шанс рейда за суточную проверку

RAID_GANGS = [
    {"name": "Бригада Клыка",    "emoji": "🗡️",
     "boss_hp": 180, "boss_atk": 28, "boss_def": 12,
     "reward_cash": 300, "reward_exp": 50},
    {"name": "Шайка Горбатого",  "emoji": "🪓",
     "boss_hp": 220, "boss_atk": 35, "boss_def": 15,
     "reward_cash": 400, "reward_exp": 65},
    {"name": "Банда Чёрного",    "emoji": "🔫",
     "boss_hp": 260, "boss_atk": 40, "boss_def": 18,
     "reward_cash": 500, "reward_exp": 80},
    {"name": "Группировка Лиса", "emoji": "🦊",
     "boss_hp": 300, "boss_atk": 45, "boss_def": 20,
     "reward_cash": 600, "reward_exp": 95},
    {"name": "Картель Скорпиона","emoji": "🦂",
     "boss_hp": 350, "boss_atk": 52, "boss_def": 24,
     "reward_cash": 750, "reward_exp": 115},
    {"name": "Синдикат Тени",    "emoji": "👥",
     "boss_hp": 400, "boss_atk": 60, "boss_def": 28,
     "reward_cash": 900, "reward_exp": 140},
]

# ── Активности на районах (уникальные для каждого) ───────────────────────────
GATHER_ACTIONS = {
    "market": {
        "btn":          "🍺 Собирать бутылки",
        "title":        "🍺 Собирал бутылки",
        "cooldown_key": "bottles_last",
        "cooldown":     3600,
        "base_min": 1,  "base_max": 5,   "per_level": 0.5,
        "phrases": [
            "Пошарил по урнам возле ларьков. Нашёл несколько стекляшек.",
            "Обошёл рынок по кругу. Бутылки сдал в приёмку.",
            "Старушки уже разобрали половину. Но тебе что-то досталось.",
            "Полчаса хождения по жаре — и вот результат.",
            "Рынок небогатый. Зато честный заработок.",
        ],
        "wait_msg": "Ты уже прошёлся по рынку. Бутылок больше нет.",
    },
    "port": {
        "btn":          "🐟 Разгрузить улов",
        "title":        "🐟 Разгружал улов",
        "cooldown_key": "gather_port",
        "cooldown":     3600,
        "base_min": 20, "base_max": 60,  "per_level": 3,
        "phrases": [
            "Помог докерам разгрузить траулер. Сунули пару купюр и молча кивнули.",
            "Ящики тяжёлые, но командир порта заплатил без лишних вопросов.",
            "В порту всегда найдётся работёнка для того, кто умеет молчать.",
            "Разгрузил рыбу, получил деньги, забыл, где был.",
            "Здоровяки-докеры уважают тех, кто не болтает. Работа нашлась.",
        ],
        "wait_msg": "В порту ничего нет. Подожди следующего улова.",
    },
    "casino": {
        "btn":          "🃏 Срубить по-лёгкому",
        "title":        "🃏 Срубил по-лёгкому",
        "cooldown_key": "gather_casino",
        "cooldown":     3600,
        "base_min": 60, "base_max": 150, "per_level": 8,
        "phrases": [
            "Пока все пялились на рулетку — ты тихонько подрезал чужой выигрыш.",
            "Навёл лоха на карточный стол. Разделили с дилером.",
            "Старый фокус с крапом сработал снова. Главное — не зарываться.",
            "Местный фраер сам напросился на партию. Жалею его деньги, но не слишком.",
            "Казино — храм, где молятся деньгам. Ты здесь жрец.",
        ],
        "wait_msg": "Крупье тебя запомнил. Лучше выжди немного.",
    },
    "factory": {
        "btn":           "🔧 Сдать металлолом",
        "title":         "🔧 Сдал металлолом",
        "cooldown_key":  "gather_factory",
        "cooldown":      3600,
        "base_min": 100, "base_max": 250, "per_level": 12,
        "phrases": [
            "Скрутил медь со старой подстанции. Приёмщик не задавал вопросов.",
            "Цех давно пустой. Но арматура на месте — и стоит недёшево.",
            "Нашёл схрон прежних хозяев завода. Заначка металла на хорошую сумму.",
            "Охранника уломал поделиться. Честно — пополам.",
            "Промзона — золотое дно для тех, кто не боится темноты.",
        ],
        "wait_msg": "Завод уже чист. Дай время — нарастёт.",
    },
    "mansion": {
        "btn":           "💍 Стрясти должок",
        "title":         "💍 Стряс должок",
        "cooldown_key":  "gather_mansion",
        "cooldown":      3600,
        "base_min": 250, "base_max": 500, "per_level": 20,
        "phrases": [
            "Один звонок — и деньги уже у тебя. Связи решают.",
            "Напомнил должнику о старом долге. Вспомнил сразу.",
            "Пришёл, увидел, получил. Без лишних слов.",
            "Репутация работает на тебя даже когда ты отдыхаешь.",
            "Здесь всё строится на страхе и уважении. У тебя есть и то, и другое.",
        ],
        "wait_msg": "Люди пока не готовы. Зайди позже.",
    },
}

# ── Telegram-канал (обязательная подписка) ───────────────────────────────────
CHANNEL_ID  = "@mafiozigamebot1"        # username канала
CHANNEL_URL = "https://t.me/mafiozigamebot1"

# ── Система розыска (звёзды ⭐) ──────────────────────────────────────────────
WANTED_CHANCE         = 0.12   # 12% шанс звезды после каждой драки
WANTED_UPGRADE_CHANCE = 0.15   # 15% шанс повышения звезды при продолжении драк

# Кулдауны уличных событий (секунды)
STREET_FIND_MONEY_CD  = 2 * 3600   # 2 часа
STREET_GIRL_CD        = 2 * 3600   # 2 часа
STREET_DOG_CD         = 5 * 3600   # 5 часов
STREET_COP_CD         = 1 * 3600   # 1 час
STREET_WITNESS_CD     = 3 * 3600   # 3 часа
STREET_EVENT_CD       = 1 * 3600
STREET_GLOBAL_CD      = 4 * 60    # 4 мин глобальный кулдаун между событиями
WANTED_FINE        = 50     # штраф в $ за сутки при 2 звёздах
JAIL_DURATION      = 60 * 60  # 60 минут тюрьмы (3 звезда)
CAPTIVITY_DURATION = 60 * 60  # 60 минут плена банд (3 звезды банд)
CAPTIVITY_BAIL_DIAMONDS = 2   # 💎 для выкупа из плена банд
JOB_DURATION       = 60 * 60  # 60 минут — длительность 1 контракта работы
JAIL_BAIL_DIAMONDS = 1        # алмазов для выкупа из тюрьмы

# ── Система «Мои связи» ───────────────────────────────────────────────────────
CONTACT_CHANCE      = 0.10   # 10% шанс получить визитку после драки
LAWYER_CASH_COST    = 100    # стоимость услуги адвоката ($)
REALTOR_DISCOUNT    = 0.10   # скидка реалтора (10%)
COMMISSIONER_COST   = 200    # стоимость услуги комиссара ($)

CONTACT_TYPES = {
    "lawyer":      {"emoji": "⚖️", "name": "Адвокат",    "desc": "Выведет из тюрьмы за ${0}".format(LAWYER_CASH_COST)},
    "realtor":     {"emoji": "🏠", "name": "Риелтор",     "desc": "Скидка 10% в магазине (один раз)"},
    "commissioner":{"emoji": "👮", "name": "Комиссар",    "desc": "Снимет одну звезду розыска за ${0}".format(COMMISSIONER_COST)},
}

# Базы имён для случайных контактов
CONTACT_FIRST_NAMES = ["Антон", "Виктор", "Геннадий", "Дмитрий", "Евгений",
                        "Илья", "Кирилл", "Леонид", "Михаил", "Николай",
                        "Олег", "Пётр", "Роман", "Сергей", "Тимур"]
CONTACT_LAST_NAMES  = ["Бровкин", "Власов", "Грибов", "Дронов", "Ефимов",
                        "Жуков", "Зайцев", "Казаков", "Лапин", "Морозов",
                        "Нечаев", "Орлов", "Попов", "Рыбаков", "Стрелков"]

def random_contact_name() -> str:
    return f"{random.choice(CONTACT_FIRST_NAMES)} {random.choice(CONTACT_LAST_NAMES)}"

# ── Имущество и статус ────────────────────────────────────────────────────────
STATUS_ITEMS = {
    "car":        {"name": "🚗 Автомобиль",  "diamonds_price": 50,  "status_pts": 10,
                   "skill_name": "🚗 Стрелять из машины",  "skill_dmg_mult": 3.0},
    "apartment":  {"name": "🏢 Квартира",    "diamonds_price": 80,  "status_pts": 15,
                   "skill_name": None, "gang_bonus": 10},
    "villa":      {"name": "🏡 Вилла",       "diamonds_price": 180, "status_pts": 25,
                   "skill_name": None, "gang_bonus": 30},
    "helicopter": {"name": "🚁 Вертолёт",    "diamonds_price": 200, "status_pts": 30,
                   "skill_name": "🚁 Пальнуть из вертолёта", "skill_dmg_mult": 5.0},
    "mansion":    {"name": "🏛️ Особняк",     "diamonds_price": 350, "status_pts": 50,
                   "skill_name": None},
    "yacht":      {"name": "⛵ Яхта",        "diamonds_price": 600, "status_pts": 80,
                   "skill_name": "⛵ Запустить ракету с яхты", "skill_dmg_mult": 8.0},
}

# Классы наёмников: урон и базовое HP
MERC_CLASSES = {
    "mercenary": {"dmg_min": 15, "dmg_max": 25, "hp_base": 50, "hp_per_lvl": 2},   # Хулиган
    "bruiser":   {"dmg_min": 8,  "dmg_max": 14, "hp_base": 90, "hp_per_lvl": 4},   # Здоровяк
    "sniper":    {"dmg_min": 28, "dmg_max": 40, "hp_base": 28, "hp_per_lvl": 1},   # Отморозок
    "bomber":    {"dmg_min": 35, "dmg_max": 50, "hp_base": 35, "hp_per_lvl": 2},   # Подрывник
    "medic":     {"dmg_min": 5,  "dmg_max": 10, "hp_base": 55, "hp_per_lvl": 2},   # Медик
    "scout":     {"dmg_min": 10, "dmg_max": 18, "hp_base": 40, "hp_per_lvl": 1},   # Разведчик
}
MERC_DMG_MIN   = 15  # fallback
MERC_DMG_MAX   = 25

# Доход с захваченных районов (кулдаун 20 часов)
DISTRICT_INCOME = {
    "market":  {"cash_min": 70,  "cash_max": 100, "exp": 5,  "cooldown": 20 * 3600},
    "port":    {"cash_min": 120, "cash_max": 160, "exp": 10, "cooldown": 20 * 3600},
    "casino":  {"cash_min": 200, "cash_max": 260, "exp": 15, "cooldown": 20 * 3600},
    "factory": {"cash_min": 300, "cash_max": 380, "exp": 20, "cooldown": 20 * 3600},
    "mansion": {"cash_min": 500, "cash_max": 650, "exp": 30, "cooldown": 20 * 3600},
}

# Цены и шансы выслеживания по районам
TRACKING = {
    "market":  {"police_cost": 50,   "gang_cost": 150,  "gang_high_rank": False},
    "port":    {"police_cost": 100,  "gang_cost": 300,  "gang_high_rank": False},
    "casino":  {"police_cost": 200,  "gang_cost": 500,  "gang_high_rank": False},
    "factory": {"police_cost": 350,  "gang_cost": 800,  "gang_high_rank": False},
    "mansion": {"police_cost": 500,  "gang_cost": 1200, "gang_high_rank": True},
}
WITNESS_COST = 20  # фиксированная цена свидетелей

# ============================================================
# РАБОТА
# ============================================================

JOBS = {
    # ============================================================
    # TIER 1 — мелочёвка (ранг 1–5, минимальный риск)
    # 5–10% шанс одной звезды, низкие выплаты
    # ============================================================
    "newspapers": {
        "name": "🗞 Раздавать газеты с компроматом",
        "rank": 1, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 50, "pay_max": 100,
        "cop_star_chance": 0.10, "gang_star_chance": 0.05,
        "passport": False,
        "desc": "Разносишь газету «Криминальный курьер» по подворотням. В каждом выпуске чёрный нал, компромат и адреса. Менты могут заметить.",
    },
    "bikes": {
        "name": "🚲 Угонять велосипеды у школьников",
        "rank": 2, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 70, "pay_max": 130,
        "cop_star_chance": 0.10, "gang_star_chance": 0.05,
        "passport": False,
        "desc": "Ставишь незапертые BMX и складники в подъезд. Мелочь, но капает стабильно. Родители иногда вызывают ментов.",
    },
    "shawarma_runner": {
        "name": "🥡 Развозить шаурму на стрёме",
        "rank": 2, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 90, "pay_max": 160,
        "cop_star_chance": 0.08, "gang_star_chance": 0.07,
        "passport": False,
        "desc": "В курьерской сумке мясо, в подкладке — порошок для клуба. Курьер шаурмы — это маскировка.",
    },
    "lookout": {
        "name": "👀 Стоять на шухере у склада",
        "rank": 3, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 120, "pay_max": 200,
        "cop_star_chance": 0.08, "gang_star_chance": 0.10,
        "passport": False,
        "desc": "Сидишь на ящике у дверей, свистишь если едут менты или чужие. Тихая работа, но кто-то всё равно тебя запомнит.",
    },
    "stall_tax": {
        "name": "💰 Собирать дань с ларьков на районе",
        "rank": 4, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 160, "pay_max": 260,
        "cop_star_chance": 0.10, "gang_star_chance": 0.10,
        "passport": False,
        "desc": "Заходишь к торгашам, забираешь конверт. Кто не платит — у того бьются витрины. Чужая братва может оспорить район.",
    },
    "thimblerig": {
        "name": "🃏 Крутить напёрстки на вокзале",
        "rank": 5, "tier": 1, "duration": JOB_DURATION,
        "pay_min": 200, "pay_max": 320,
        "cop_star_chance": 0.12, "gang_star_chance": 0.08,
        "passport": False,
        "desc": "Трёх стаканчиков и одного шарика хватает, чтобы расходились с пустыми карманами. Менты у вокзала особенно злые.",
    },

    # ============================================================
    # TIER 2 — серьёзка (ранг 6–14, средний риск)
    # 20–35% шанс звезды, средние выплаты
    # ============================================================
    "moonshine": {
        "name": "🍾 Гнать самогон в гараже",
        "rank": 6, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 350, "pay_max": 550,
        "cop_star_chance": 0.25, "gang_star_chance": 0.10,
        "passport": False,
        "desc": "Подпольный завод в боксе у дяди Гены. Дым из вытяжки, две бочки спирта и сахарная брага. Если соседи стуканут — приедут.",
    },
    "car_jacker": {
        "name": "🚗 Угонять тачки на заказ",
        "rank": 8, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 500, "pay_max": 800,
        "cop_star_chance": 0.30, "gang_star_chance": 0.15,
        "passport": False,
        "desc": "По адресу. Открыть, завести, отогнать в отстойник. Час работы — и тачка уже на запчастях. ГАИ работает быстро.",
    },
    "blackmail": {
        "name": "📞 Шантажировать чиновника",
        "rank": 10, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 700, "pay_max": 1100,
        "cop_star_chance": 0.25, "gang_star_chance": 0.10,
        "passport": False,
        "desc": "Фото из бани + телефон. Деньги к четвергу или жена увидит. Чиновники иногда стучат в УБОП.",
    },
    "arson": {
        "name": "🔥 Поджечь магазин конкурентов",
        "rank": 12, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 900, "pay_max": 1400,
        "cop_star_chance": 0.15, "gang_star_chance": 0.40,
        "passport": False,
        "desc": "Канистра бензина, мокрая тряпка в горловине, спичка. Заказ от соседнего барыги. Хозяин магаза свяжется со своими.",
    },
    "smuggling": {
        "name": "📦 Контрабанда стволов из порта",
        "rank": 13, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 1200, "pay_max": 1800,
        "cop_star_chance": 0.30, "gang_star_chance": 0.30,
        "passport": False,
        "desc": "Ящики приходят на сухогрузе, маркированы как «детали». Таможня закрывает глаза за конверт. Чужие крыши — нет.",
    },
    "forger": {
        "name": "📜 Подделка паспортов на потоке",
        "rank": 14, "tier": 2, "duration": JOB_DURATION,
        "pay_min": 1500, "pay_max": 2200,
        "cop_star_chance": 0.30, "gang_star_chance": 0.10,
        "passport": False,
        "desc": "Печать в типографии, фотолаб, ламинатор. По 20$ за паспорт, по 50$ за водительские. ФСБ периодически проверяет типографии.",
    },

    # ============================================================
    # TIER 3 — спецзадания (ранг 15–25, ВЫСОКИЙ риск)
    # 2 звезды разом, шанс не выполнить, ОЧЕНЬ большие выплаты
    # ============================================================
    "boss_car": {
        "name": "🏎 Угнать спорткар Босса",
        "rank": 15, "tier": 3, "duration": JOB_DURATION,
        "pay_min": 4000, "pay_max": 8000,
        "success_chance": 0.50,
        "cop_star_chance": 0.15, "gang_star_chance": 0.95,
        "stars_amount_gang": 2,
        "passport": False,
        "desc": "Феррари красная, стоит у казино, ключи у валета. Босс об этом узнает быстрее чем ты доедешь до гаража. Шанс выполнения — 50/50.",
    },
    "bank_heist": {
        "name": "🏦 Ограбление банка",
        "rank": 18, "tier": 3, "duration": JOB_DURATION,
        "pay_min": 7000, "pay_max": 15000,
        "success_chance": 0.40,
        "cop_star_chance": 0.95, "gang_star_chance": 0.15,
        "stars_amount_cop": 2,
        "passport": False,
        "desc": "Маски, обрезы, фургон. 4 минуты у кассы, 6 минут до милиции. Шанс выполнения — 40%. Если выйдешь — будут искать.",
    },
    "prosecutor_car": {
        "name": "💣 Взорвать машину прокурора",
        "rank": 22, "tier": 3, "duration": JOB_DURATION,
        "pay_min": 12000, "pay_max": 25000,
        "success_chance": 0.30,
        "cop_star_chance": 1.00, "gang_star_chance": 0.10,
        "stars_amount_cop": 3,
        "passport": False,
        "desc": "Растяжка под капотом, провод на стартер. Шанс выполнения 30%. После такого тебя уже не штрафами ищут — а отделом по особо тяжким.",
    },
}
ITEMS = {
    # ── Расходники-метательные ─────────────────────────────────────
    "grenade":       {"name": "💣 Граната",          "type": "throwable", "dmg_min": 80,  "dmg_max": 130, "price": 50,  "desc": "Урон 80-130, без ответки. Кидаешь — враг разлетается."},
    "molotov":       {"name": "🔥 Коктейль Молотова","type": "throwable", "dmg_min": 50,  "dmg_max": 80,  "burn_per_turn": 25, "burn_turns": 2, "price": 130, "desc": "Урон 50-80, плюс горит 2 хода по 25. Без ответки."},
    "medkit_small":  {"name": "🩹 Малая аптечка",    "type": "potion",   "heal": 55,  "price": 25,  "desc": "Восстанавливает 55 HP"},
    "medkit_medium": {"name": "🏥 Аптечка",          "type": "potion",   "heal": 130, "price": 60,  "desc": "Восстанавливает 130 HP"},
    "medkit_large":  {"name": "💉 Большая аптечка",  "type": "potion",   "heal": 280, "price": 120, "desc": "Восстанавливает 280 HP"},
    "energy_drink":  {"name": "⚡ Энергетик",        "type": "potion",   "mana": 55,  "price": 45,  "desc": "Восстанавливает 55 энергии"},
    "zatochka":      {"name": "🔪 Заточка",          "type": "weapon",   "attack_bonus": 6,   "price": 60,   "desc": "+6 к атаке. Заточенный кусок металла."},
    "nagan":         {"name": "🔫 Наган",            "type": "weapon",   "attack_bonus": 8,   "price": 250,  "desc": "+8 к атаке. Старый уличный ствол."},
    "sawn_off":      {"name": "💥 Обрез",            "type": "weapon",   "attack_bonus": 12,  "price": 600,  "desc": "+12 к атаке. Короткий и злой."},
    "uzi":           {"name": "🔫 Узи",              "type": "weapon",   "attack_bonus": 16,  "price": 1500, "desc": "+16 к атаке. Автоматика за копейки."},
    "leather_jacket":{"name": "🧥 Кожанка",          "type": "armor",    "defense_bonus": 12, "price": 180,  "desc": "+12 к защите. Уличная классика."},
    "bulletproof":   {"name": "🦺 Бронежилет",       "type": "armor",    "defense_bonus": 28, "price": 450,  "desc": "+28 к защите. Любительский."},
    # ── 6 новых брони (заполняем промежуток до титанового жилета) ──────────
    "kevlar_vest":   {"name": "🛡️ Кевларовый жилет", "type": "armor",    "defense_bonus": 38, "price": 1200,  "desc": "+38 к защите. Стандарт ЧОПа."},
    "tactical_vest": {"name": "🥋 Тактический жилет","type": "armor",    "defense_bonus": 50, "price": 2500,  "desc": "+50 к защите. С разгрузкой под магазины."},
    "army_armor":    {"name": "🪖 Армейская броня",  "type": "armor",    "defense_bonus": 62, "price": 5000,  "desc": "+62 к защите. Списано со складов."},
    "swat_suit":     {"name": "👮 Костюм спецназа",  "type": "armor",    "defense_bonus": 78, "price": 9000,  "desc": "+78 к защите. Шлем, наколенники, всё дело."},
    "composite_armor":{"name":"🦾 Композитный доспех","type": "armor",   "defense_bonus": 95, "price": 16000, "desc": "+95 к защите. Кевлар + керамика."},
    "exo_armor":     {"name": "⚙️ Экзо-броня",       "type": "armor",    "defense_bonus": 120,"price": 28000, "desc": "+120 к защите. Прототип из лаборатории."},
    "golden_colt":   {"name": "🌟 Золотой Кольт",    "type": "weapon",   "attack_bonus": 65,  "diamonds_price": 100, "desc": "+65 к атаке (премиум)"},
    "titanium_vest": {"name": "⚙️ Титановый жилет",  "type": "armor",    "defense_bonus": 65, "diamonds_price": 100, "desc": "+65 к защите (премиум)"},
    # ── 10 новых стволов (мафия 90-х) ──────────────────────────────────
    "revolver":      {"name": "🔫 Револьвер",        "type": "weapon", "attack_bonus": 20,  "price": 5000,  "desc": "+20 атк. Шесть патронов — хватит на всех."},
    "machete":       {"name": "🗡️ Мачете",           "type": "weapon", "attack_bonus": 28,  "price": 8000,  "desc": "+28 атк. Латинский привет."},
    "katana":        {"name": "⚔️ Катана",           "type": "weapon", "attack_bonus": 38,  "price": 12000, "desc": "+38 атк. Сталь из Японии."},
    "spiked_bat":    {"name": "🏏 Бита с гвоздями",  "type": "weapon", "attack_bonus": 48,  "price": 18000, "desc": "+48 атк. Народное оружие 90-х."},
    "deagle":        {"name": "🦅 Дезерт Игл",       "type": "weapon", "attack_bonus": 58,  "price": 25000, "desc": "+58 атк. Пушка не для слабаков."},
    "sniper":        {"name": "🎯 Снайперка",         "type": "weapon", "attack_bonus": 68,  "price": 32000, "desc": "+68 атк. Один выстрел — один труп."},
    "m16":           {"name": "💥 М-16",              "type": "weapon", "attack_bonus": 80,  "price": 42000, "desc": "+80 атк. Американская классика."},
    "rpg":           {"name": "🚀 Базука",            "type": "weapon", "attack_bonus": 95,  "price": 50000, "desc": "+95 атк. Вопросов нет ни у кого."},
    "golden_uzi":    {"name": "🌟 Золотой Узи",      "type": "weapon", "attack_bonus": 78,  "diamonds_price": 10, "desc": "+78 атк (премиум). Золото и свинец."},
    "tommy_gun":     {"name": "🔥 Томми Ган",        "type": "weapon", "attack_bonus": 100, "diamonds_price": 20, "crit_chance": 0.25, "crit_min": 270, "crit_max": 310, "desc": "+100 атк (премиум). Крит 270-310 с шансом 25%."},
    "passport":      {"name": "📄 Паспорт",          "type": "document", "desc": "Официальный документ. Открывает новые рабочие места."},
    # Эксклюзивное оружие казино (только через рулетку)
    "knuckles":      {"name": "🥊 Кастет",           "type": "weapon",   "attack_bonus": 10,  "desc": "+10 к атаке. Рынок."},
    "chain":         {"name": "⛓️ Цепь",             "type": "weapon",   "attack_bonus": 22,  "desc": "+22 к атаке. Порт."},
    "tt_pistol":     {"name": "🔫 Пистолет ТТ",      "type": "weapon",   "attack_bonus": 36,  "desc": "+36 к атаке. Казино."},
    "shotgun":       {"name": "💣 Дробовик",         "type": "weapon",   "attack_bonus": 52,  "desc": "+52 к атаке. Промзона."},
    "ak74":          {"name": "🎯 АК-74",            "type": "weapon",   "attack_bonus": 72,  "desc": "+72 к атаке. Резиденция."},
}

DIAMOND_PACKAGES = [
    {"stars": 50,  "diamonds": 100,  "label": "💎 100 бриллиантов"},
    {"stars": 200, "diamonds": 500,  "label": "💎 500 бриллиантов"},
    {"stars": 500, "diamonds": 1500, "label": "💎 1500 бриллиантов"},
]

CASH_PACKAGES = [
    {"stars": 25,  "cash": 500,   "label": "💵 500 баксов"},
    {"stars": 75,  "cash": 2000,  "label": "💵 2 000 баксов"},
    {"stars": 175, "cash": 6000,  "label": "💵 6 000 баксов"},
    {"stars": 400, "cash": 20000, "label": "💵 20 000 баксов"},
]

def exp_for_level(level: int) -> int:
    return int(100 * (level ** 1.5))

# ============================================================
# БАЗА ДАННЫХ
# ============================================================

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS characters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                telegram_id INTEGER UNIQUE,
                username TEXT,
                name TEXT,
                class TEXT,
                level INTEGER DEFAULT 1,
                exp INTEGER DEFAULT 0,
                hp INTEGER DEFAULT 100,
                max_hp INTEGER DEFAULT 100,
                mana INTEGER DEFAULT 50,
                max_mana INTEGER DEFAULT 50,
                attack INTEGER DEFAULT 10,
                defense INTEGER DEFAULT 5,
                cash INTEGER DEFAULT 0,
                diamonds INTEGER DEFAULT 0,
                kills INTEGER DEFAULT 0,
                weapon TEXT DEFAULT NULL,
                armor TEXT DEFAULT NULL,
                job TEXT DEFAULT NULL,
                job_started INTEGER DEFAULT NULL,
                job_last_paid INTEGER DEFAULT NULL,
                bottles_last INTEGER DEFAULT 0,
                last_regen INTEGER DEFAULT 0,
                gang_last_encounter INTEGER DEFAULT 0,
                gang_last_collect INTEGER DEFAULT 0,
                gang_discount_until INTEGER DEFAULT 0,
                gang_weapon_discount_until INTEGER DEFAULT 0,
                referred_by INTEGER DEFAULT NULL,
                last_hunt INTEGER DEFAULT 0,
                channel_verified INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        # Миграция для существующих баз
        for col, definition in [
            ("job", "TEXT DEFAULT NULL"),
            ("job_started", "INTEGER DEFAULT NULL"),
            ("job_last_paid", "INTEGER DEFAULT NULL"),
            ("bottles_last", "INTEGER DEFAULT 0"),
            ("last_regen", "INTEGER DEFAULT 0"),
            ("gang_last_encounter", "INTEGER DEFAULT 0"),
            ("hospital_until",      "INTEGER DEFAULT 0"),
            ("gang_last_collect", "INTEGER DEFAULT 0"),
            ("gang_discount_until", "INTEGER DEFAULT 0"),
            ("gang_weapon_discount_until", "INTEGER DEFAULT 0"),
            ("street_find_money_at",  "INTEGER DEFAULT 0"),
            ("street_girl_at",        "INTEGER DEFAULT 0"),
            ("street_dog_at",         "INTEGER DEFAULT 0"),
            ("street_cop_at",         "INTEGER DEFAULT 0"),
            ("street_witness_at",     "INTEGER DEFAULT 0"),
            ("street_event_at",       "INTEGER DEFAULT 0"),
        ("street_last_event_at",  "INTEGER DEFAULT 0"),
            ("referred_by", "INTEGER DEFAULT NULL"),
            ("ref_bonus_given", "INTEGER DEFAULT 0"),
            ("last_hunt", "INTEGER DEFAULT 0"),
            ("channel_verified", "INTEGER DEFAULT 0"),
            ("wanted_stars", "INTEGER DEFAULT 0"),
            ("jail_until", "INTEGER DEFAULT 0"),
            ("jail_count", "INTEGER DEFAULT 0"),
            ("wanted_last_fine", "INTEGER DEFAULT 0"),
            # === Звёзды банд + плен (jobs v2) ===
            ("wanted_gangs",     "INTEGER DEFAULT 0"),
            ("captivity_until",  "INTEGER DEFAULT 0"),
            ("captivity_count",  "INTEGER DEFAULT 0"),
            ("gather_port",    "INTEGER DEFAULT 0"),
            ("gather_casino",  "INTEGER DEFAULT 0"),
            ("gather_factory", "INTEGER DEFAULT 0"),
            ("gather_mansion", "INTEGER DEFAULT 0"),
            # Критические колонки — без них падают shop и character_info
            ("diamonds", "INTEGER DEFAULT 0"),
            ("kills",    "INTEGER DEFAULT 0"),
            ("weapon",   "TEXT DEFAULT NULL"),
            ("armor",    "TEXT DEFAULT NULL"),
            ("max_hp",   "INTEGER DEFAULT 100"),
            ("max_mana", "INTEGER DEFAULT 50"),
            # Внешность персонажа (JSON: skin,body,face,hair,hat)
            ("look_json", "TEXT DEFAULT NULL"),
            # Кулдауны работ: JSON {job_id: until_ts}
            ("job_cooldowns_json", "TEXT DEFAULT NULL"),
            # Кулдаун событий мини-аппа (события по игровому времени)
            ("last_hub_event_at", "INTEGER DEFAULT 0"),
        ]:
            try:
                await db.execute(f"ALTER TABLE characters ADD COLUMN {col} {definition}")
            except Exception:
                pass
        await db.execute("""
            CREATE TABLE IF NOT EXISTS inventory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                telegram_id INTEGER,
                item_id TEXT,
                quantity INTEGER DEFAULT 1
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS active_battles (
                telegram_id INTEGER PRIMARY KEY,
                location TEXT,
                boss_id TEXT,
                boss_hp INTEGER,
                boss_max_hp INTEGER,
                party_json TEXT DEFAULT NULL
            )
        """)
        # Миграция: добавить party_json если отсутствует
        try:
            await db.execute("ALTER TABLE active_battles ADD COLUMN party_json TEXT DEFAULT NULL")
        except Exception:
            pass
        # Миграция: props_used_json для учёта использованного имущества в бою
        try:
            await db.execute("ALTER TABLE active_battles ADD COLUMN props_used_json TEXT DEFAULT NULL")
        except Exception:
            pass
        # Миграция: добавить current_hp в gang_members если отсутствует
        try:
            await db.execute("ALTER TABLE gang_members ADD COLUMN current_hp INTEGER DEFAULT NULL")
        except Exception:
            pass
        # Миграция: host_alive / partner_alive для coop_sessions
        for _col in ("host_alive INTEGER DEFAULT 1", "partner_alive INTEGER DEFAULT 1"):
            try:
                await db.execute(f"ALTER TABLE coop_sessions ADD COLUMN {_col}")
            except Exception:
                pass
        # Миграция: players_json для поддержки до 4 игроков
        try:
            await db.execute("ALTER TABLE coop_sessions ADD COLUMN players_json TEXT DEFAULT NULL")
        except Exception:
            pass
        await db.execute("""
            CREATE TABLE IF NOT EXISTS district_control (
                location_id TEXT PRIMARY KEY,
                telegram_id INTEGER,
                telegram_name TEXT,
                captured_at REAL,
                last_collected REAL DEFAULT 0
            )
        """)
        # Бизнесы игроков (пассивный доход)
        # status: 'ok' | 'blocked' | 'burned'
        await db.execute("""
            CREATE TABLE IF NOT EXISTS player_businesses (
                telegram_id  INTEGER NOT NULL,
                biz_id       TEXT    NOT NULL,
                bought_at    INTEGER NOT NULL,
                last_collect INTEGER NOT NULL,
                status       TEXT    DEFAULT 'ok',
                blocked_until INTEGER DEFAULT 0,
                last_event_at INTEGER DEFAULT 0,
                pending_notice TEXT DEFAULT NULL,
                PRIMARY KEY (telegram_id, biz_id)
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS gang_members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                telegram_id INTEGER,
                member_name TEXT,
                role TEXT,
                role_display TEXT,
                last_collected INTEGER DEFAULT 0,
                current_hp INTEGER DEFAULT NULL
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS friend_collects (
                inviter_id INTEGER,
                friend_id  INTEGER,
                last_collect INTEGER DEFAULT 0,
                PRIMARY KEY (inviter_id, friend_id)
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS contacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                telegram_id INTEGER,
                contact_type TEXT,
                contact_name TEXT,
                received_at INTEGER DEFAULT 0,
                used INTEGER DEFAULT 0
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS property_owned (
                telegram_id INTEGER,
                item_id TEXT,
                bought_at INTEGER DEFAULT 0,
                PRIMARY KEY (telegram_id, item_id)
            )
        """)
        # Миграция: добавить поле district guard / sabotage
        for col, definition in [
            ("guard_json",      "TEXT DEFAULT NULL"),
            ("sabotaged_until", "INTEGER DEFAULT 0"),
        ]:
            try:
                await db.execute(f"ALTER TABLE district_control ADD COLUMN {col} {definition}")
            except Exception:
                pass
        # Таблица рейдов
        await db.execute("""
            CREATE TABLE IF NOT EXISTS raid_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                location_id TEXT,
                owner_id INTEGER,
                gang_name TEXT,
                gang_emoji TEXT,
                boss_hp_max INTEGER,
                boss_hp INTEGER,
                boss_atk INTEGER,
                boss_def INTEGER,
                reward_cash INTEGER,
                reward_exp INTEGER,
                started_at INTEGER,
                expires_at INTEGER,
                status TEXT DEFAULT 'active'
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS coop_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL,
                partner_id INTEGER NOT NULL,
                boss_id TEXT NOT NULL,
                boss_hp INTEGER NOT NULL,
                boss_max_hp INTEGER NOT NULL,
                location TEXT NOT NULL,
                party_json TEXT,
                current_turn INTEGER DEFAULT 0,
                status TEXT DEFAULT 'pending',
                created_at INTEGER NOT NULL
            )
        """)
        # При старте — очищаем все зависшие active/pending co-op сессии
        await db.execute(
            "UPDATE coop_sessions SET status='cancelled' WHERE status IN ('active','pending')"
        )
        # При старте — очищаем все зависшие active_battles (на случай краша)
        await db.execute("DELETE FROM active_battles")
        # Jobs v2 — снимаем старые job-id (janitor/shawarma/etc), их в новом JOBS нет.
        # Если игрок был на старой работе — просто слетит (без выплаты, поскольку
        # автоматический pay был ранее уже начислен).
        await db.execute(
            "UPDATE characters SET job=NULL, job_started=NULL, job_last_paid=NULL "
            "WHERE job IS NOT NULL AND job NOT IN ('newspapers','bikes','shawarma_runner','lookout','stall_tax','thimblerig','moonshine','car_jacker','blackmail','arson','smuggling','forger','boss_car','bank_heist','prosecutor_car')"
        )
        await db.commit()

async def create_raid(location_id: str, owner_id: int, gang: dict) -> int:
    now = int(time.time())
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute(
            "INSERT INTO raid_events (location_id,owner_id,gang_name,gang_emoji,"
            "boss_hp_max,boss_hp,boss_atk,boss_def,reward_cash,reward_exp,"
            "started_at,expires_at,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,'active')",
            (location_id, owner_id, gang["name"], gang["emoji"],
             gang["boss_hp"], gang["boss_hp"], gang["boss_atk"], gang["boss_def"],
             gang["reward_cash"], gang["reward_exp"],
             now, now + RAID_EXPIRE_SECONDS)
        )
        await db.commit()
        return cur.lastrowid

async def get_active_raid(location_id: str) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM raid_events WHERE location_id=? AND status='active' ORDER BY id DESC LIMIT 1",
            (location_id,)
        ) as cur:
            row = await cur.fetchone()
            return dict(row) if row else None

async def get_raid_by_id(raid_id: int) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT * FROM raid_events WHERE id=?", (raid_id,)) as cur:
            row = await cur.fetchone()
            return dict(row) if row else None

async def update_raid_boss_hp(raid_id: int, hp: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE raid_events SET boss_hp=? WHERE id=?", (hp, raid_id))
        await db.commit()

async def close_raid(raid_id: int, status: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE raid_events SET status=? WHERE id=?", (status, raid_id))
        await db.commit()

async def expire_old_raids() -> list:
    """Возвращает список (location_id, owner_id) протухших рейдов и помечает их expired."""
    now = int(time.time())
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM raid_events WHERE status='active' AND expires_at <= ?", (now,)
        ) as cur:
            rows = [dict(r) for r in await cur.fetchall()]
        if rows:
            ids = [r["id"] for r in rows]
            await db.execute(
                f"UPDATE raid_events SET status='expired' WHERE id IN ({','.join('?'*len(ids))})",
                ids
            )
            await db.commit()
        return rows

async def get_character(telegram_id: int) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT * FROM characters WHERE telegram_id=?", (telegram_id,)) as cur:
            row = await cur.fetchone()
            return dict(row) if row else None

async def create_character(telegram_id: int, username: str, name: str, char_class: str):
    cls = CLASSES[char_class]
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO characters (telegram_id,username,name,class,hp,max_hp,mana,max_mana,attack,defense,cash) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (telegram_id, username, name, char_class, cls["hp"], cls["hp"], cls["mana"], cls["mana"], cls["attack"], cls["defense"], 0)
        )
        await db.commit()

async def update_character(telegram_id: int, **kwargs):
    if not kwargs:
        return
    set_clause = ", ".join(f"{k}=?" for k in kwargs)
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(f"UPDATE characters SET {set_clause} WHERE telegram_id=?", [*kwargs.values(), telegram_id])
        await db.commit()

async def get_inventory(telegram_id: int) -> dict:
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT item_id, quantity FROM inventory WHERE telegram_id=?", (telegram_id,)) as cur:
            return {r[0]: r[1] for r in await cur.fetchall()}

async def add_item(telegram_id: int, item_id: str, qty: int = 1):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT quantity FROM inventory WHERE telegram_id=? AND item_id=?", (telegram_id, item_id)) as cur:
            row = await cur.fetchone()
        if row:
            await db.execute("UPDATE inventory SET quantity=quantity+? WHERE telegram_id=? AND item_id=?", (qty, telegram_id, item_id))
        else:
            await db.execute("INSERT INTO inventory (telegram_id,item_id,quantity) VALUES (?,?,?)", (telegram_id, item_id, qty))
        await db.commit()

async def remove_item(telegram_id: int, item_id: str, qty: int = 1) -> bool:
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT quantity FROM inventory WHERE telegram_id=? AND item_id=?", (telegram_id, item_id)) as cur:
            row = await cur.fetchone()
        if not row or row[0] < qty:
            return False
        if row[0] == qty:
            await db.execute("DELETE FROM inventory WHERE telegram_id=? AND item_id=?", (telegram_id, item_id))
        else:
            await db.execute("UPDATE inventory SET quantity=quantity-? WHERE telegram_id=? AND item_id=?", (qty, telegram_id, item_id))
        await db.commit()
        return True

async def get_battle(telegram_id: int) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT * FROM active_battles WHERE telegram_id=?", (telegram_id,)) as cur:
            row = await cur.fetchone()
            if not row:
                return None
            d = dict(row)
            d["party"] = json.loads(d["party_json"]) if d.get("party_json") else []
            return d

def get_prop_skills(owned_props: list, props_used: list) -> list:
    """Returns list of (item_id, button_label) for property skills not yet used this battle."""
    result = []
    for pid in owned_props:
        si = STATUS_ITEMS.get(pid)
        if si and si.get("skill_name") and pid not in props_used:
            result.append((pid, si["skill_name"]))
    return result


def _best_prop_skill(owned_props: list) -> tuple:
    """Возвращает (skill_name, dmg_mult) лучшего имущества или ('', 0.0)."""
    best_name, best_mult = '', 0.0
    for pid in owned_props:
        si = STATUS_ITEMS.get(pid, {})
        if si.get('skill_name') and si.get('skill_dmg_mult', 0) > best_mult:
            best_mult   = si['skill_dmg_mult']
            best_name   = si['skill_name']
    return best_name, best_mult


async def update_battle_party(telegram_id: int, party: list):
    pj = json.dumps(party, ensure_ascii=False)
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE active_battles SET party_json=? WHERE telegram_id=?", (pj, telegram_id))
        await db.commit()

async def start_battle_db(telegram_id: int, location: str, boss_id: str, party: list = None):
    b = BOSSES[boss_id]
    pj = json.dumps(party, ensure_ascii=False) if party else None
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR REPLACE INTO active_battles "
            "(telegram_id, location, boss_id, boss_hp, boss_max_hp, party_json, props_used_json) "
            "VALUES (?,?,?,?,?,?,?)",
            (telegram_id, location, boss_id, b["hp"], b["hp"], pj, None)
        )
        await db.commit()

async def start_raid_battle_db(telegram_id: int, raid_id: int, boss_hp: int, boss_max_hp: int, party: list = None):
    """Стартует бой с рейдовым боссом с кастомным HP (может быть уже частично ранен)."""
    pj = json.dumps(party, ensure_ascii=False) if party else None
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR REPLACE INTO active_battles "
            "(telegram_id, location, boss_id, boss_hp, boss_max_hp, party_json, props_used_json) "
            "VALUES (?,?,?,?,?,?,?)",
            (telegram_id, f"raid_{raid_id}", "raid_boss", boss_hp, boss_max_hp, pj, None)
        )
        await db.commit()

async def start_coop_battle_db(telegram_id: int, location: str, boss_id: str,
                               boss_hp: int, boss_max_hp: int):
    """Стартует бой для участника co-op с текущим HP босса."""
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR REPLACE INTO active_battles "
            "(telegram_id, location, boss_id, boss_hp, boss_max_hp, party_json, props_used_json) "
            "VALUES (?,?,?,?,?,?,?)",
            (telegram_id, location, boss_id, boss_hp, boss_max_hp, None, None)
        )
        await db.commit()


async def end_battle(telegram_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM active_battles WHERE telegram_id=?", (telegram_id,))
        await db.commit()

async def update_battle(telegram_id: int, boss_hp: int, props_used: list = None):
    async with aiosqlite.connect(DB_PATH) as db:
        if props_used is not None:
            import json as _j
            await db.execute(
                "UPDATE active_battles SET boss_hp=?, props_used_json=? WHERE telegram_id=?",
                (boss_hp, _j.dumps(props_used), telegram_id)
            )
        else:
            await db.execute("UPDATE active_battles SET boss_hp=? WHERE telegram_id=?", (boss_hp, telegram_id))
        await db.commit()


# ── Контроль районов ────────────────────────────────────────────────────────

async def get_district_control(loc_id: str) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM district_control WHERE location_id=?", (loc_id,)
        ) as cur:
            row = await cur.fetchone()
            return dict(row) if row else None
async def get_guard_member_ids(telegram_id: int) -> set:
    """Возвращает set id наёмников, стоящих на охране хоть одного района игрока."""
    guard_ids = set()
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT guard_json FROM district_control WHERE telegram_id=?",
            (telegram_id,)
        ) as cur:
            rows = await cur.fetchall()
    for row in rows:
        if row["guard_json"]:
            import json as _json
            guard_ids.update(_json.loads(row["guard_json"]))
    return guard_ids



async def update_district_guard(loc_id: str, guard_ids: list):
    """Сохраняет список охранников района в БД."""
    pj = json.dumps(guard_ids)
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE district_control SET guard_json=? WHERE location_id=?",
            (pj, loc_id)
        )
        await db.commit()


async def capture_district(telegram_id: int, telegram_name: str, loc_id: str):
    now = time.time()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR REPLACE INTO district_control "
            "(location_id, telegram_id, telegram_name, captured_at, last_collected) "
            "VALUES (?,?,?,?,0)",
            (loc_id, telegram_id, telegram_name, now)
        )
        await db.commit()

async def collect_district_income(telegram_id: int, loc_id: str) -> Optional[dict]:
    """Собрать дань с района. Возвращает {cash, exp} или None если рано."""
    ctrl = await get_district_control(loc_id)
    if not ctrl or ctrl["telegram_id"] != telegram_id:
        return None
    income = DISTRICT_INCOME[loc_id]
    now = time.time()
    if now - (ctrl["last_collected"] or 0) < income["cooldown"]:
        return None  # ещё рано
    cash = random.randint(income["cash_min"], income["cash_max"])
    exp  = income["exp"]
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE district_control SET last_collected=? WHERE location_id=?",
            (now, loc_id)
        )
        await db.commit()
    return {"cash": cash, "exp": exp}

async def get_my_districts(telegram_id: int) -> list:
    """Все районы, подконтрольные игроку."""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM district_control WHERE telegram_id=?", (telegram_id,)
        ) as cur:
            return [dict(r) for r in await cur.fetchall()]


async def get_gang(telegram_id: int) -> list:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM gang_members WHERE telegram_id=? ORDER BY id", (telegram_id,)
        ) as cur:
            return [dict(r) for r in await cur.fetchall()]

async def add_gang_member(telegram_id: int, name: str, role: str) -> int:
    async with aiosqlite.connect(DB_PATH) as db:
        role_info = GANG_ROLES[role]
        display = f"{role_info['emoji']} {name} — {role_info['title']}"
        cur = await db.execute(
            "INSERT INTO gang_members (telegram_id,member_name,role,role_display) VALUES (?,?,?,?)",
            (telegram_id, name, role, display)
        )
        await db.commit()
        return cur.lastrowid

async def remove_gang_member(member_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        # Узнаём владельца перед удалением
        cur = await db.execute("SELECT telegram_id FROM gang_members WHERE id=?", (member_id,))
        row = await cur.fetchone()
        owner_id = row["telegram_id"] if row else None

        await db.execute("DELETE FROM gang_members WHERE id=?", (member_id,))

        # Убираем погибшего из guard_json всех районов владельца
        if owner_id:
            cur2 = await db.execute(
                "SELECT loc_id, guard_json FROM district_control WHERE telegram_id=?",
                (owner_id,)
            )
            rows = await cur2.fetchall()
            import json as _json
            for r in rows:
                g_ids = _json.loads(r["guard_json"] or "[]")
                if member_id in g_ids:
                    g_ids.remove(member_id)
                    await db.execute(
                        "UPDATE district_control SET guard_json=? WHERE loc_id=? AND telegram_id=?",
                        (_json.dumps(g_ids), r["loc_id"], owner_id)
                    )

        await db.commit()

async def update_merc_hp(member_id: int, hp: int):
    """Сохраняет текущее HP наёмника в БД."""
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE gang_members SET current_hp=? WHERE id=?", (hp, member_id))
        await db.commit()

# ─── Co-op sessions ───────────────────────────────────────────────────────────

async def create_coop_session(host_id: int, partner_id: int, boss_id: str,
                               boss_hp: int, boss_max_hp: int, location: str,
                               party: list = None) -> int:
    now = int(time.time())
    pj = json.dumps(party, ensure_ascii=False) if party else None
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute(
            "INSERT INTO coop_sessions (host_id,partner_id,boss_id,boss_hp,boss_max_hp,"
            "location,party_json,current_turn,status,created_at) VALUES (?,?,?,?,?,?,?,0,'pending',?)",
            (host_id, partner_id, boss_id, boss_hp, boss_max_hp, location, pj, now)
        )
        await db.commit()
        return cur.lastrowid

async def get_coop_session(session_id: int) -> Optional[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT * FROM coop_sessions WHERE id=?", (session_id,)) as cur:
            row = await cur.fetchone()
            if not row: return None
            d = dict(row)
            d["party"] = json.loads(d.get("party_json") or "[]")
            return d

async def get_coop_by_participant(user_id: int) -> Optional[dict]:
    """Возвращает активную co-op сессию, где user — хост, партнёр или в players_json."""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM coop_sessions WHERE (host_id=? OR partner_id=? OR players_json LIKE ?) "
            "AND status IN ('pending','active') ORDER BY id DESC LIMIT 1",
            (user_id, user_id, f'%"uid": {user_id}%')
        ) as cur:
            row = await cur.fetchone()
            if not row: return None
            d = dict(row)
            d["party"]   = json.loads(d.get("party_json")   or "[]")
            d["players"] = json.loads(d.get("players_json") or "[]")
            return d

async def get_pending_coop_by_host(host_id: int) -> Optional[dict]:
    """Возвращает pending/active/launching co-op сессию от этого хоста."""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM coop_sessions WHERE host_id=? AND status IN ('pending','active','launching') "
            "ORDER BY id DESC LIMIT 1",
            (host_id,)
        ) as cur:
            row = await cur.fetchone()
            if not row: return None
            d = dict(row)
            d["party"]   = json.loads(d.get("party_json")   or "[]")
            d["players"] = json.loads(d.get("players_json") or "[]")
            return d

async def update_coop_session(session_id: int, **kwargs):
    if not kwargs: return
    if "party" in kwargs:
        kwargs["party_json"] = json.dumps(kwargs.pop("party"), ensure_ascii=False)
    set_clause = ", ".join(f"{k}=?" for k in kwargs)
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(f"UPDATE coop_sessions SET {set_clause} WHERE id=?",
                         [*kwargs.values(), session_id])
        await db.commit()

async def close_coop_session(session_id: int, status: str = "finished"):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE coop_sessions SET status=? WHERE id=?", (status, session_id))
        await db.commit()

async def cancel_old_coop_invites(user_id: int):
    """Отменяет старые ожидающие приглашения от этого пользователя."""
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE coop_sessions SET status='cancelled' WHERE host_id=? AND status='pending'",
            (user_id,)
        )
        await db.commit()

async def cancel_all_coop(user_id: int):
    """Отменяет все co-op сессии пользователя (pending и active) — при старте соло-боя."""
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE coop_sessions SET status='cancelled' "
            "WHERE (host_id=? OR partner_id=?) AND status IN ('pending','active')",
            (user_id, user_id)
        )
        await db.commit()

async def get_friends(telegram_id: int) -> list:
    """Возвращает всех игроков, приглашённых этим пользователем."""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT telegram_id, name, level FROM characters WHERE referred_by = ?",
            (telegram_id,)
        ) as cur:
            rows = await cur.fetchall()
    return [dict(r) for r in rows]

async def get_friend_collect(inviter_id: int, friend_id: int) -> int:
    """Возвращает timestamp последнего сбора с этого друга."""
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT last_collect FROM friend_collects WHERE inviter_id=? AND friend_id=?",
            (inviter_id, friend_id)
        ) as cur:
            row = await cur.fetchone()
    return row[0] if row else 0

async def set_friend_collect(inviter_id: int, friend_id: int, ts: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO friend_collects (inviter_id, friend_id, last_collect) VALUES (?,?,?) "
            "ON CONFLICT(inviter_id, friend_id) DO UPDATE SET last_collect=?",
            (inviter_id, friend_id, ts, ts)
        )
        await db.commit()

async def update_member_collected(member_id: int, ts: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE gang_members SET last_collected=? WHERE id=?", (ts, member_id))
        await db.commit()

async def get_top_players(limit: int = 10):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT name, class, level, kills FROM characters ORDER BY level DESC, kills DESC LIMIT ?", (limit,)) as cur:
            return await cur.fetchall()

async def get_leaderboard(mode: str = "rank", limit: int = 10):
    """Возвращает топ игроков. mode='rank' — по рангу, 'status' — по очкам статуса."""
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT telegram_id, name, level, kills FROM characters"
        ) as cur:
            chars = await cur.fetchall()
        async with db.execute(
            "SELECT telegram_id, item_id FROM property_owned"
        ) as cur:
            prop_rows = await cur.fetchall()

    from collections import defaultdict
    prop_by_user: dict = defaultdict(list)
    for tid, item_id in prop_rows:
        prop_by_user[tid].append(item_id)

    players = []
    for tid, name, level, kills in chars:
        status = get_status_points(prop_by_user[tid], kills or 0)
        players.append({"name": name, "level": level, "kills": kills or 0, "status": status})

    if mode == "rank":
        players.sort(key=lambda x: (x["level"], x["kills"]), reverse=True)
    else:
        players.sort(key=lambda x: x["status"], reverse=True)

    return players[:limit]

# ── Контакты ─────────────────────────────────────────────────────────────────

async def get_contacts(telegram_id: int) -> list:
    """Все доступные (неиспользованные) контакты игрока."""
    async with aiosqlite.connect(DB_PATH) as db:
        # На случай если таблица ещё не создана (старая БД)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS contacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                telegram_id INTEGER,
                contact_type TEXT,
                contact_name TEXT,
                received_at INTEGER DEFAULT 0,
                used INTEGER DEFAULT 0
            )
        """)
        await db.commit()
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM contacts WHERE telegram_id=? AND used=0 ORDER BY received_at DESC",
            (telegram_id,)
        ) as cur:
            return [dict(r) for r in await cur.fetchall()]

async def add_contact(telegram_id: int, contact_type: str, contact_name: str):
    now = int(time.time())
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO contacts (telegram_id, contact_type, contact_name, received_at) VALUES (?,?,?,?)",
            (telegram_id, contact_type, contact_name, now)
        )
        await db.commit()

async def use_contact(contact_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE contacts SET used=1 WHERE id=?", (contact_id,))
        await db.commit()

# ── Имущество ─────────────────────────────────────────────────────────────────

async def get_property(telegram_id: int) -> list:
    """Список item_id купленного имущества."""
    async with aiosqlite.connect(DB_PATH) as db:
        # Безопасное создание таблицы для старых БД
        await db.execute("""
            CREATE TABLE IF NOT EXISTS property_owned (
                telegram_id INTEGER,
                item_id TEXT,
                bought_at INTEGER DEFAULT 0,
                PRIMARY KEY (telegram_id, item_id)
            )
        """)
        await db.commit()
        async with db.execute(
            "SELECT item_id FROM property_owned WHERE telegram_id=?", (telegram_id,)
        ) as cur:
            return [r[0] for r in await cur.fetchall()]

async def buy_property_db(telegram_id: int, item_id: str):
    now = int(time.time())
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT OR IGNORE INTO property_owned (telegram_id, item_id, bought_at) VALUES (?,?,?)",
            (telegram_id, item_id, now)
        )
        await db.commit()

async def sell_property_db(telegram_id: int, item_id: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "DELETE FROM property_owned WHERE telegram_id=? AND item_id=?",
            (telegram_id, item_id)
        )
        await db.commit()

def get_status_points(owned_items: list, kills: int = 0) -> int:
    """Статус = очки имущества + 10 за каждую победу в драке."""
    prop_pts = sum(STATUS_ITEMS[i]["status_pts"] for i in owned_items if i in STATUS_ITEMS)
    return prop_pts + kills * 10

# ── Проверка подписки на канал ────────────────────────────────────────────────

async def is_subscribed(bot, user_id: int) -> bool:
    """Проверяет, подписан ли пользователь на CHANNEL_ID.
    Требует чтобы бот был администратором канала — иначе всех пропускает."""
    try:
        member = await bot.get_chat_member(chat_id=CHANNEL_ID, user_id=user_id)
        return member.status in ("member", "administrator", "creator")
    except Exception:
        # Бот не администратор канала или другая ошибка — пропускаем
        return True

def subscription_required_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📢 Подписаться на канал", url=CHANNEL_URL)],
        [InlineKeyboardButton("✅ Я подписался", callback_data="check_sub")],
    ])

# ── Тюрьма ───────────────────────────────────────────────────────────────────

async def apply_wanted_fine(telegram_id: int, char: dict) -> Optional[str]:
    """Начисляет штраф за 2 звезды розыска раз в сутки. Возвращает текст или None."""
    if char.get("wanted_stars", 0) < 2:
        return None
    now = int(time.time())
    last = char.get("wanted_last_fine", 0) or 0
    if now - last < 24 * 3600:
        return None
    fine = min(char["cash"], WANTED_FINE)
    await update_character(telegram_id, cash=char["cash"] - fine, wanted_last_fine=now)
    return f"⚖️ *Расследование продолжается.* Штраф: -{fine}$ за розыск."

def jail_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton(f"⚖️ Нанять адвоката — 1 💎", callback_data="jail_bail")],
        [InlineKeyboardButton("⏳ Ждать (осталось — см. выше)", callback_data="jail_wait")],
    ])

# ============================================================
# ЛОГИКА РАБОТЫ
# ============================================================

def calc_job_pay(job_id: str, seconds: float) -> tuple[int, int, str]:
    """
    [Legacy] Рассчёт почасовой ставки старой модели.
    В v2 не используется (job_collect делает свой бросок), но оставлено
    на случай старого кода.
    """
    job = JOBS.get(job_id)
    if not job:
        return 0, 0, ""
    fraction = seconds / 3600.0  # доля часа

    hourly = random.randint(job["pay_min"], job["pay_max"])
    gross = int(hourly * fraction)

    risk_text = ""
    net = gross

    if gross > 0 and job.get("risk"):
        risk = job["risk"]
        # Один риск-чек на всю сессию (не за каждый час)
        if random.random() < risk["chance"]:
            loss_pct = random.uniform(0.05, risk["loss_max"])
            loss = int(gross * loss_pct)
            net = max(0, gross - loss)
            if job_id == "security":
                risk_text = f"\n🚨 Братва заходила — отжали {int(loss_pct * 100)}% = -{loss}$"
            else:
                risk_text = f"\n🏛️ Налоговая прошлась — удержали {int(loss_pct * 100)}% = -{loss}$"

    return net, gross, risk_text

def format_duration(seconds: int) -> str:
    """Форматирует время в читаемый вид: 1ч 23м"""
    h = seconds // 3600
    m = (seconds % 3600) // 60
    if h > 0 and m > 0:
        return f"{h}ч {m}м"
    elif h > 0:
        return f"{h}ч"
    else:
        return f"{m}м" if m > 0 else "меньше минуты"

async def process_job_autopay(telegram_id: int, char: dict) -> Optional[str]:
    """
    [Jobs v2] Автовыплат больше нет — игрок сам нажимает «Забрать выплату».
    Функция оставлена no-op для совместимости с местами, где её вызывают.
    """
    return None
    # ── СТАРАЯ ЛОГИКА (отключена) ──
    if not char.get("job") or not char.get("job_last_paid"):
        return None

    now = int(time.time())
    elapsed = now - char["job_last_paid"]
    full_hours = elapsed // 3600

    if full_hours < 1:
        return None

    pay_seconds = full_hours * 3600
    earned, gross, risk_text = calc_job_pay(char["job"], pay_seconds)
    new_last_paid = char["job_last_paid"] + pay_seconds

    await update_character(telegram_id,
        cash=char["cash"] + earned,
        job_last_paid=new_last_paid
    )

    job = JOBS[char["job"]]
    pay_line = f"+{gross}${risk_text}\n💰 На руки: *{earned}$*" if risk_text else f"+{earned}$"
    return (
        f"💼 *Зарплата с работы*\n"
        f"_{job['name']}_\n"
        f"⏱ За {full_hours} ч работы: {pay_line}"
    )

async def process_regen(telegram_id: int, char: dict) -> Optional[str]:
    """
    Вызывается при открытии меню.
    +5 HP и +5 энергии каждые 5 минут, пока не полное здоровье.
    Возвращает текст уведомления или None.
    """
    # Уже полное здоровье и энергия — нечего восстанавливать
    if char["hp"] >= char["max_hp"] and char["mana"] >= char["max_mana"]:
        return None

    now = int(time.time())
    last = char.get("last_regen") or 0
    # Если last_regen = 0 — ставим как текущее время без начисления
    if last == 0:
        await update_character(telegram_id, last_regen=now)
        return None

    elapsed = now - last
    intervals = elapsed // 300  # каждые 5 минут
    if intervals < 1:
        return None

    hp_gain   = min(intervals * 5, char["max_hp"]  - char["hp"])
    mana_gain = min(intervals * 5, char["max_mana"] - char["mana"])
    new_hp    = char["hp"]   + hp_gain
    new_mana  = char["mana"] + mana_gain
    new_last_regen = last + intervals * 300

    await update_character(telegram_id, hp=new_hp, mana=new_mana, last_regen=new_last_regen)

    return None  # Регенерация идёт тихо, без уведомлений

# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================

def calc_damage(attack: int, defense: int, mult: float = 1.0) -> int:
    base = max(1, attack - defense // 2)
    return max(1, int(base * random.uniform(0.85, 1.15) * mult))

def hp_bar(current: int, maximum: int, length: int = 10) -> str:
    filled = int((max(0, current) / maximum) * length)
    return "[" + "█" * filled + "░" * (length - filled) + "]"

def level_progress(char: dict) -> str:
    needed = exp_for_level(char["level"])
    filled = int((char["exp"] / needed) * 10)
    return "[" + "█" * filled + "░" * (10 - filled) + f"] {char['exp']}/{needed}"

def get_effective_attack(char: dict) -> int:
    bonus = ITEMS[char["weapon"]].get("attack_bonus", 0) if char.get("weapon") and char["weapon"] in ITEMS else 0
    return char["attack"] + bonus

def get_effective_defense(char: dict) -> int:
    bonus = ITEMS[char["armor"]].get("defense_bonus", 0) if char.get("armor") and char["armor"] in ITEMS else 0
    return char["defense"] + bonus

async def check_level_up(telegram_id: int, char: dict) -> str:
    needed = exp_for_level(char["level"])
    if char["exp"] < needed:
        return ""
    new_level = char["level"] + 1
    await update_character(telegram_id,
        level=new_level, exp=char["exp"] - needed,
        max_hp=char["max_hp"] + 20, hp=char["max_hp"] + 20,
        max_mana=char["max_mana"] + 10, mana=char["max_mana"] + 10,
        attack=char["attack"] + 3, defense=char["defense"] + 2
    )
    return (f"\n\n🎖️ *ПОВЫШЕНИЕ РАНГА!*\n"
            f"Ранг {char['level']} → {new_level}\n"
            f"❤️+20 HP | ⚡+10 энергии | 🔫+3 атаки | 🛡️+2 защиты")

# ============================================================
# КЛАВИАТУРЫ
# ============================================================

def main_menu_kb(hub_url: str = "") -> ReplyKeyboardMarkup:
    url = hub_url or HUB_WEBAPP_URL
    return ReplyKeyboardMarkup(
        [[KeyboardButton("🏠 Главное меню", web_app=WebAppInfo(url=url))]],
        resize_keyboard=True,
        one_time_keyboard=False,
    )

async def build_hub_url(char: dict, contacts_count: int = 0, user_id: int = None) -> str:
    """Build URL for hub.html with all character and appearance params."""
    look: dict = {}
    if char.get("look_json"):
        try:
            look = json.loads(char["look_json"])
        except Exception:
            pass

    gren = 0; mol = 0; med_s = 0; med_m = 0; med_l = 0
    weapon = char.get("weapon") or ""
    prop_str = ""
    gang_str = ""
    if user_id:
        try:
            inv = await get_inventory(user_id)
            gren  = inv.get("grenade", 0)
            mol   = inv.get("molotov", 0)
            med_s = inv.get("medkit_small", 0)
            med_m = inv.get("medkit_medium", 0)
            med_l = inv.get("medkit_large", 0)
            owned = json.loads(char.get("owned_property") or "[]")
            prop_ids = [k for k in owned if STATUS_ITEMS.get(k, {}).get("skill_dmg_mult")]
            prop_str = ",".join(prop_ids)
            # Gang members for co-op
            # Только реальные игроки (по реф-ссылке) — без NPC-наёмников
            friends = await get_friends(user_id)
            gang_parts = []
            for f in friends[:8]:
                fchar    = await get_character(f["telegram_id"])
                if not fchar: continue
                name_enc = urllib.parse.quote(str(f.get("name", "")), safe="")
                emoji    = "👤"
                role     = "friend"
                gang_parts.append(f"{f['telegram_id']}|{name_enc}|{emoji}|{role}")
            gang_str = ",".join(gang_parts)
        except Exception:
            pass

    # Jobs v2: рассчитаем когда контракт можно забирать
    import time as _t
    _now = int(_t.time())
    _job_started = char.get("job_started") or 0
    _job_until   = (_job_started + JOB_DURATION) if (char.get("job") and _job_started) else 0

    params = {
        "name":     str(char.get("name", "")),
        "lvl":      char.get("level", 1),
        "cls":      char.get("class", "fixer"),
        "hp":       char.get("hp", 0),
        "maxhp":    char.get("max_hp", 100),
        "mp":       char.get("mana", 0),
        "maxmp":    char.get("max_mana", 50),
        "cash":     char.get("cash", 0),
        "dia":      char.get("diamonds", 0),
        "kills":    char.get("kills", 0),
        "wanted":   char.get("wanted_stars", 0) or 0,
        "wanted_g": char.get("wanted_gangs", 0) or 0,
        "jail_until": char.get("jail_until", 0) or 0,
        "cap_until":  char.get("captivity_until", 0) or 0,
        "job_until":  _job_until,
        "srv_now":    _now,
        "contacts": contacts_count,
        "job":      char.get("job") or "",
        "gender":   look.get("gender", 0),
        "skin":     look.get("skin", 0),
        "body":     look.get("body", 0),
        "face":     look.get("face", 0),
        "hair":     look.get("hair", 0),
        "hat":      look.get("hat", 0),
        "has_look": 1 if char.get("look_json") else 0,
        "atk":      char.get("attack", 20),
        "def":      char.get("defense", 10),
        "gren":     gren,
        "mol":      mol,
        "med_s":    med_s,
        "med_m":    med_m,
        "med_l":    med_l,
        "weapon":   weapon,
        "prop":     prop_str,
        "gang":     gang_str,
        "api":      COOP_API_BASE,
        "uid":      user_id or 0,   # реальный Telegram-ID — нужен для HTTP-API
        "bot":      BOT_USERNAME,   # имя бота для t.me/<bot>?startapp=... share-ссылок
        "job_cd":   (char.get("job_cooldowns_json") or "")[:600],
        "_v": "17",  # bump when hub.html is updated — breaks Telegram cache
    }
    return HUB_WEBAPP_URL + "?" + urllib.parse.urlencode(params)



async def build_hub_url_coop(user_id: int, session: dict, status: str) -> str:
    """Builds hub URL with co-op battle state encoded in params."""
    char     = await get_character(user_id)
    contacts = await get_contacts(user_id)
    base_url = await build_hub_url(char or {}, len(contacts), user_id)

    players = json.loads(session.get("players_json") or "[]")
    # Encode players as name:hp:maxhp
    def _safe(s): return urllib.parse.quote(str(s)[:20], safe="")
    players_enc = ",".join(
        f"{_safe(p.get('name','?'))}:{int(p.get('hp', p.get('max_hp',100)))}:{int(p.get('max_hp',100))}"
        for p in players
    )

    # Whose turn? current_turn is index into ready players
    ready = [p for p in players if p.get("ready") or (p.get("accepted") and p["uid"] == session["host_id"])]
    turn_idx = int(session.get("current_turn", 0))
    if ready:
        turn_uid  = ready[turn_idx % len(ready)]["uid"]
        turn_name = ready[turn_idx % len(ready)].get("name", "")
    else:
        turn_uid  = session["host_id"]
        turn_name = ""

    extra = {
        "coop_sid":       session["id"],
        "coop_status":    status,
        "coop_my_turn":   1 if turn_uid == user_id else 0,
        "coop_boss_id":   session["boss_id"],
        "coop_boss_hp":   session["boss_hp"],
        "coop_boss_max":  session["boss_max_hp"],
        "coop_players":   players_enc,
        "coop_turn_name": urllib.parse.quote(turn_name[:20], safe=""),
    }
    sep = "&" if "?" in base_url else "?"
    return base_url + sep + urllib.parse.urlencode(extra)


async def _send_coop_hub_update(bot, session: dict, status: str, message: str = ""):
    """Push updated hub URL to all session participants."""
    players = json.loads(session.get("players_json") or "[]")
    ready   = [p for p in players if p.get("ready") or (p.get("accepted") and p["uid"] == session["host_id"])]
    turn_idx = int(session.get("current_turn", 0))
    turn_uid = ready[turn_idx % len(ready)]["uid"] if ready else session["host_id"]

    all_uids = list({session["host_id"]} | {p["uid"] for p in ready})
    for uid in all_uids:
        try:
            url = await build_hub_url_coop(uid, session, status)
            my_turn = (uid == turn_uid) and status == "battle"
            btn_label = "⚔️ Твой ход!" if my_turn else ("🏆 Результат" if status in ("won","lost") else "👁 Смотреть бой")
            text = message or ("🗡 *Твой ход!*" if my_turn else "⏳ Ходит следующий...")
            await bot.send_message(
                chat_id=uid,
                text=text,
                parse_mode="Markdown",
                reply_markup=ReplyKeyboardMarkup(
                    [[KeyboardButton(btn_label, web_app=WebAppInfo(url=url))]],
                    resize_keyboard=True, one_time_keyboard=True
                )
            )
        except Exception as _e:
            logger.warning("coop hub push to %s failed: %s", uid, _e)


async def contacts_kb(user_id: int) -> ReplyKeyboardMarkup:
    """Reply keyboard with hub WebApp button.
    KeyboardButton is required so tg.sendData() works inside the Mini App."""
    char = await get_character(user_id)
    contacts = await get_contacts(user_id)
    hub_url = await build_hub_url(char or {}, len(contacts), user_id)
    return ReplyKeyboardMarkup(
        [[KeyboardButton("🏠 Главное меню", web_app=WebAppInfo(url=hub_url))]],
        resize_keyboard=True,
        one_time_keyboard=False,
    )

def creator_kb() -> ReplyKeyboardMarkup:
    """Reply keyboard with creator WebApp button (sendData works only for KeyboardButton)."""
    return ReplyKeyboardMarkup(
        [[KeyboardButton("🎨 Создать гангстера", web_app=WebAppInfo(url=CREATOR_WEBAPP_URL))]],
        resize_keyboard=True,
        one_time_keyboard=True,
    )


KNIFE_WEAPONS  = {"zatochka"}
GUN_WEAPONS    = {"nagan", "sawn_off", "uzi", "golden_colt", "tt_pistol", "shotgun", "ak74", "revolver", "deagle", "sniper", "m16", "rpg", "golden_uzi", "tommy_gun"}

def attack_label(weapon_id) -> str:
    if weapon_id in GUN_WEAPONS:
        return "🔫 Стрелять"
    if weapon_id in KNIFE_WEAPONS:
        return "🔪 Колоть"
    return "🤜 Бить"

def dmg_range(atk: int, defense: int, mult: float = 1.0) -> str:
    base = max(1, atk - defense // 2)
    lo = max(1, int(base * 0.85 * mult))
    hi = max(1, int(base * 1.15 * mult))
    return f"{lo}–{hi}"

ATTACK_MANA_COST = 5   # стоимость обычной атаки в энергии

def battle_kb(has_mana: bool, has_potions: bool, weapon_id=None,
              eff_atk: int = 0, boss_def: int = 0, skill_mult: float = 1.0,
              skill_name: str = "Приём", cur_mana: int = 999,
              grenades: int = 0, molotovs: int = 0, prop_skills: list = None):
    """prop_skills: list of (item_id, skill_name) for available property abilities."""
    atk_dmg    = dmg_range(eff_atk, boss_def)
    skill_dmg  = dmg_range(eff_atk, boss_def, skill_mult)
    can_attack = cur_mana >= ATTACK_MANA_COST
    atk_btn    = f"{attack_label(weapon_id)} ({atk_dmg}, -{ATTACK_MANA_COST}⚡)" if can_attack else "😮‍💨 Нет энергии"
    skill_btn  = f"💥 {skill_name} ({skill_dmg})" if has_mana else "💥 Мало энергии"
    rows = [
        [InlineKeyboardButton(atk_btn,   callback_data="battle_attack" if can_attack else "battle_no_mana"),
         InlineKeyboardButton(skill_btn, callback_data="battle_skill"  if has_mana  else "battle_no_mana")],
        [InlineKeyboardButton("🩹 Аптечка", callback_data="battle_potion" if has_potions else "battle_no_potion"),
         InlineKeyboardButton("🏃 Валить",  callback_data="battle_flee")],
    ]
    if grenades > 0:
        rows.append([InlineKeyboardButton(f"💣 Граната ×{grenades} (80–130 урона, без ответки)", callback_data="battle_grenade")])
    if molotovs > 0:
        rows.append([InlineKeyboardButton(f"🔥 Молотов ×{molotovs} (100–130 урона + пожар, без ответки)", callback_data="battle_molotov")])
    for (pid, pname) in (prop_skills or []):
        rows.append([InlineKeyboardButton(pname, callback_data=f"battle_prop_{pid}")])
    return InlineKeyboardMarkup(rows)

def build_battle_url(char: dict, battle: dict, boss: dict,
                     log: str = "", has_potions: bool = False, party: list = None,
                     grenades: int = 0, prop_name: str = "", prop_mult: float = 0.0, pp_ok: int = 1,
                     coop_id: str = "", pnum: int = 0, partner: str = "") -> str:
    """Строит URL мини-приложения боя с текущим состоянием."""
    eff_atk  = get_effective_attack(char)
    eff_def  = get_effective_defense(char)
    weapon_id = char.get("weapon")
    if not weapon_id:
        wt = 0
    elif weapon_id in KNIFE_WEAPONS:
        wt = 1
    else:
        wt = 2
    skill    = SKILLS[char["class"]]
    params = {
        "pn":  char["name"][:20],
        "ph":  char["hp"],
        "pmh": char["max_hp"],
        "pm":  char["mana"],
        "pmm": char["max_mana"],
        "pa":  eff_atk,           # новый: атака игрока
        "pd":  eff_def,           # новый: защита игрока
        "wt":  wt,
        "sk":  skill["name"],
        "sc":  skill["mana_cost"],
        "sm":  skill["damage_mult"],   # новый: множитель урона навыка
        "sh":  skill.get("heal", 0),   # новый: лечение от навыка
        "po":  1 if has_potions else 0,
        "en":  boss["name"],
        "et":  boss["title"],
        "eh":  battle["boss_hp"],
        "emh": battle["boss_max_hp"],
        "ea":  boss["attack"],
        "ed":  boss["defense"],
        "wp":  weapon_id or "",        # id оружия для анимаций/звуков (fists если пусто)
    }
    # Отряд (наёмники + друзья)
    alive_party = [m for m in (party or battle.get("party", [])) if m.get("alive", True)]
    if alive_party:
        params["pc"] = len(alive_party)
        for i, m in enumerate(alive_party):
            params[f"p{i}n"] = m["name"][:14]
            params[f"p{i}h"] = m["hp"]
            params[f"p{i}m"] = m["max_hp"]
            params[f"p{i}t"] = "m" if m["type"] == "mercenary" else "f"
            params[f"p{i}r"] = m.get("role", "mercenary") if m["type"] == "mercenary" else "friend"
            if m["type"] == "mercenary":
                cls_m = MERC_CLASSES.get(m.get("role", "mercenary"), MERC_CLASSES["mercenary"])
                params[f"p{i}a"] = f"{cls_m['dmg_min']}-{cls_m['dmg_max']}"
            else:
                fr_d = dmg_range(m.get("attack", 10), boss["defense"])
                params[f"p{i}a"] = str(fr_d)
    params["gr"] = grenades
    if prop_name and prop_mult > 0:
        params["pp_n"]  = prop_name[:18]
        params["pp_m"]  = round(prop_mult, 1)
        params["pp_ok"] = pp_ok
    if coop_id:
        params["coop_id"] = coop_id
        params["pnum"]    = pnum
        if partner:
            params["partner"] = partner[:18]
    return BATTLE_WEBAPP_URL.rstrip("/") + "/?" + urllib.parse.urlencode(params)


def build_iso_url(char: dict, battle: dict, boss_id: str = "",
                  loc_id: str = "", coop_id: str = "",
                  inv: dict | None = None, cash: int | None = None) -> str:
    """Строит URL изометрической боёвки (demo_isometric.html)."""
    bid  = boss_id or (battle.get("boss_id") if battle else "") or "kosoy"
    lid  = loc_id  or (battle.get("location") if battle else "") or "market"
    weapon = char.get("weapon") or "pistol"
    # Боссы, чьи статы зашиты в BOSS_REGISTRY внутри demo_isometric.html.
    # Для прочих (raid_boss, mansion_gang и т.п.) передаём имя/HP/эмодзи в URL.
    boss_in_html = {
        "kosoy","bychok","zhigan","shustryy","tolsty","kaban","bukhgalter",
        "kontrabas","legenda","professor","artist","svalshchik","buryy","khirurg",
        "tigr","palach","sedoy","prizrak","don_karlo","vizir",
    }
    params = {
        # Кеш-бастер для Telegram WebApp: подними при каждом релизе боёвки
        # — иначе TG держит старый HTML в кеше и игроки видят прошлую версию.
        "_v":     "15",
        "name":   urllib.parse.quote(char["name"][:20]),
        "hp":     char["hp"],
        "maxhp":  char["max_hp"],
        "atk":    get_effective_attack(char),
        "def":    get_effective_defense(char),
        "weapon": weapon,
        "boss":   bid,
        "loc":    lid,
    }
    if bid not in boss_in_html:
        b = BOSSES.get(bid, BOSSES["kosoy"])
        import re as _re
        raw = _re.sub(r'^[\U00010000-\U0010ffff☀-⟿\U0001f000-\U0001faff]+\s*', '', b["name"]).strip()
        params["bname"]  = urllib.parse.quote(raw[:18])
        params["bhp"]    = b["hp"]
        params["batk"]   = b["attack"]
        params["bdef"]   = b["defense"]
        emoji_m = _re.match(r'^([\U00010000-\U0010ffff☀-⟿\U0001f000-\U0001faff]+)', b["name"])
        if emoji_m:
            params["bemoji"] = urllib.parse.quote(emoji_m.group(1))
    if coop_id:
        params["coop_id"] = coop_id
    # Передаём бэкап для метательного: при поражении/потере state боёвка
    # вернёт в хаб корректные gren/mol/cash без обнуления.
    if inv is not None:
        params["bgren"] = int(inv.get("grenade", 0) or 0)
        params["bmol"]  = int(inv.get("molotov", 0) or 0)
    if cash is not None:
        params["bcash"] = int(cash or 0)
    return ISO_WEBAPP_URL + "?" + "&".join(f"{k}={v}" for k, v in params.items())


def back_kb(cb: str = "main_menu"):
    return InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data=cb)]])

# ============================================================
# ХЕНДЛЕРЫ — РЕГИСТРАЦИЯ
# ============================================================

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id

    # Проверка подписки на канал
    # Читаем char заранее чтобы проверить сохранённый флаг
    _char_pre = await get_character(user_id)
    if not (_char_pre and _char_pre.get("channel_verified")):
        if not await is_subscribed(context.bot, user_id):
            await update.message.reply_text(
                "📢 *Добро пожаловать в Мафиози!*\n\n"
                "Чтобы играть, подпишись на наш канал — там новости об обновлениях.\n\n"
                "После подписки нажми *«Я подписался»*.",
                parse_mode="Markdown",
                reply_markup=subscription_required_kb()
            )
            return ConversationHandler.END
        # Подписан — сохраняем флаг навсегда если персонаж уже есть
        if _char_pre:
            await update_character(user_id, channel_verified=1)

    # Обработка реферальной ссылки (?start=ref_XXXX)
    ref_id = None
    args = context.args
    if args and args[0].startswith("ref_"):
        try:
            ref_id = int(args[0][4:])
            if ref_id == user_id:
                ref_id = None  # нельзя пригласить самого себя
        except ValueError:
            ref_id = None

    char = await get_character(user_id)
    if char:
        # Если пришёл по реф-ссылке и ещё не привязан — привязываем
        if ref_id and not char.get("referred_by"):
            inviter = await get_character(ref_id)
            if inviter:
                # referred_by ставится только если его не было — гарантирует одноразовость
                await update_character(user_id, referred_by=ref_id)
                await update_character(ref_id, cash=inviter["cash"] + 300)
                try:
                    await context.bot.send_message(
                        chat_id=ref_id,
                        text=f"🤝 *{char['name']}* вступил в твою банду по реферальной ссылке!\n\n"
                             f"💵 Разовый бонус: *+$300* уже у тебя на счёте.",
                        parse_mode="Markdown"
                    )
                except Exception:
                    pass
                await update.message.reply_text(
                    f"🤝 Ты вступил в банду *{inviter['name']}*!\n"
                    f"Теперь он будет получать с тебя доход каждый день.",
                    parse_mode="Markdown"
                )
        pay_note = await process_job_autopay(user_id, char)
        char = await get_character(user_id)
        fine_note = await apply_wanted_fine(user_id, char)
        if fine_note:
            char = await get_character(user_id)

        # Проверка тюрьмы
        now_ts = int(time.time())
        jail_until = char.get("jail_until", 0) or 0
        if jail_until > now_ts:
            mins_left = (jail_until - now_ts + 59) // 60
            stars_str = "⭐" * char.get("wanted_stars", 3)
            await update.message.reply_text(
                f"🚔 *Ты за решёткой!*\n\n"
                f"{stars_str} Розыск: уровень {char.get('wanted_stars', 3)}\n\n"
                f"_Ты слишком много нагрешил. Система правосудия нашла тебя._\n\n"
                f"⏳ До выхода: *{mins_left} мин.*\n\n"
                f"Выкупить себя или ждать?",
                parse_mode="Markdown",
                reply_markup=jail_kb()
            )
            return ConversationHandler.END

        # ── Проверяем, создан ли внешний вид персонажа ──────────────
        if not char.get("look_json"):
            await update.message.reply_text(
                "🎨 *Создай своего гангстера!*\n\n"
                "Прежде чем войти в игру — настрой внешность своего персонажа.\n"
                "Выбери телосложение, лицо, причёску и аксессуары.\n\n"
                "Это займёт меньше минуты 👇",
                parse_mode="Markdown",
                reply_markup=creator_kb()
            )
            return ConversationHandler.END

        wanted_str = ("⭐" * char.get("wanted_stars", 0)) if char.get("wanted_stars", 0) > 0 else ""
        text = f"С возвращением, *{md(char['name'])}*! 🤵\n\nРанг: {char['level']} | ❤️ {char['hp']}/{char['max_hp']} | 💵 {char['cash']}$"
        if wanted_str:
            text += f"\n🔍 Розыск: {wanted_str}"
        if pay_note:
            text += f"\n\n{pay_note}"
        if fine_note:
            text += f"\n\n{fine_note}"
        await update.message.reply_text(text, parse_mode="Markdown", reply_markup=await contacts_kb(user_id))
        return ConversationHandler.END

    # Сохраняем ref_id для регистрации
    if ref_id:
        context.user_data["ref_id"] = ref_id
    await update.message.reply_text(
        "🤵 *Добро пожаловать в Мафиози!*\n\n"
        "Город поделён между семьями. Каждый угол — чья-то территория.\n"
        "Ты начинаешь с нуля — ни денег, ни связей.\n\n"
        "Как тебя зовут в этом городе?",
        parse_mode="Markdown"
    )
    return CHOOSING_NAME

async def choose_name(update: Update, context: ContextTypes.DEFAULT_TYPE):
    name = update.message.text.strip()
    if not (2 <= len(name) <= 20):
        await update.message.reply_text("❌ Погоняло должно быть от 2 до 20 символов. Попробуй ещё раз:")
        return CHOOSING_NAME
    context.user_data["char_name"] = name
    await update.message.reply_text(
        f"Значит, *{name}*. Запомню. 🚬\n\nТеперь выбери специализацию:\n\n"
        "🔫 *Киллер* — 110HP, 30 атаки. Точный и беспощадный.\n"
        "🥊 *Громила* — 160HP, 20 атаки, 18 защиты. Живая стена.\n"
        "🃏 *Решала* — 120HP, 24 атаки. Универсальный боец.\n"
        "🎩 *Аферист* — 100HP, 22 атаки + лечение. Хитрость — его сила.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🔫 Киллер",  callback_data="class_killer"),
             InlineKeyboardButton("🥊 Громила", callback_data="class_enforcer")],
            [InlineKeyboardButton("🃏 Решала",  callback_data="class_fixer"),
             InlineKeyboardButton("🎩 Аферист", callback_data="class_conman")],
        ])
    )
    return CHOOSING_CLASS

async def choose_class(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    char_class = query.data.replace("class_", "")
    name = context.user_data.get("char_name", "Безымянный")
    user = update.effective_user
    await create_character(user.id, user.username or "", name, char_class)
    # Флаг подписки: раз дошёл до регистрации — значит подписан
    await update_character(user.id, channel_verified=1)
    # Привязываем реферала если есть + разовый бонус пригласившему
    ref_id = context.user_data.get("ref_id")
    if ref_id:
        inviter = await get_character(ref_id)
        if inviter:
            # referred_by устанавливается один раз навсегда — защита от злоупотреблений
            await update_character(user.id, referred_by=ref_id)
            await update_character(ref_id, cash=inviter["cash"] + 300)
            try:
                await context.bot.send_message(
                    chat_id=ref_id,
                    text=f"🤝 *{name}* вступил в твою банду по реферальной ссылке!\n\n"
                         f"💵 Разовый бонус: *+$300* уже у тебя на счёте.",
                    parse_mode="Markdown"
                )
            except Exception:
                pass
    cls = CLASSES[char_class]
    await _edit_text(query,
        f"🎖️ *Добро пожаловать в семью, {name}.*\n\n"
        f"Специализация: *{cls['name']}*\n"
        f"_{cls['desc']}_\n\n"
        f"❤️ {cls['hp']} HP | ⚡ {cls['mana']} энергии\n"
        f"🔫 {cls['attack']} атаки | 🛡️ {cls['defense']} защиты\n"
        f"💵 Стартовый капитал: 0$\n\n"
        f"Денег нет. Иди работать — кнопка *Работа* в меню.",
        parse_mode="Markdown", reply_markup=await contacts_kb(user.id)
    )
    # Предлагаем создать внешность сразу — с кнопкой
    try:
        await context.bot.send_message(
            chat_id=update.effective_user.id,
            text=(
                "🎨 *Создай внешность своего гангстера!*\n\n"
                "Причёска, лицо, телосложение, головной убор — "
                "всё в мафиозном стиле.\n\n"
                "Нажми кнопку ниже — займёт меньше минуты 👇"
            ),
            parse_mode="Markdown",
            reply_markup=creator_kb()
        )
    except Exception:
        pass
    return ConversationHandler.END

# ============================================================
# ХЕНДЛЕРЫ — ГЛАВНОЕ МЕНЮ
# ============================================================

async def main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    user_id = update.effective_user.id
    if await try_random_encounter(update, context):
        return
    char = await get_character(user_id)
    if not char:
        await _edit_text(query,"Введи /start чтобы начать.")
        return

    # Проверяем, создан ли внешний вид персонажа
    if not char.get("look_json"):
        await _edit_text(
            query,
            "🎨 *Создай своего гангстера!*\n\n"
            "Прежде чем войти в игру — настрой внешность своего персонажа.\n"
            "Выбери телосложение, лицо, причёску и аксессуары 👇",
            parse_mode="Markdown",
            reply_markup=creator_kb()
        )
        return

    # Проверка тюрьмы
    now_ts = int(time.time())
    jail_until = char.get("jail_until", 0) or 0
    if jail_until > now_ts:
        mins_left = (jail_until - now_ts + 59) // 60
        stars_str = "⭐" * char.get("wanted_stars", 3)
        await _edit_text(query,
            f"🚔 *Ты за решёткой!*\n\n"
            f"{stars_str} Розыск: уровень {char.get('wanted_stars', 3)}\n\n"
            f"_Ты слишком много нагрешил. Система правосудия нашла тебя._\n\n"
            f"⏳ До выхода: *{mins_left} мин.*\n\n"
            f"Выкупить себя или ждать?",
            parse_mode="Markdown",
            reply_markup=jail_kb()
        )
        return

    # Проверка подписки (только если ещё не верифицирован)
    if not char.get("channel_verified"):
        if not await is_subscribed(context.bot, user_id):
            await _edit_text(query,
                "📢 *Для игры нужна подписка на канал.*\n\nПодпишись и нажми «Я подписался».",
                parse_mode="Markdown",
                reply_markup=subscription_required_kb()
            )
            return
        await update_character(user_id, channel_verified=1)

    pay_note = await process_job_autopay(user_id, char)
    char = await get_character(user_id)
    fine_note = await apply_wanted_fine(user_id, char)
    if fine_note:
        char = await get_character(user_id)
    regen_note = await process_regen(user_id, char)
    char = await get_character(user_id)

    job_line = ""
    if char.get("job"):
        job = JOBS[char["job"]]
        worked_sec = int(time.time()) - char["job_started"]
        job_line = f"\n💼 На работе: {job['short']} ({format_duration(worked_sec)})"

    wanted_stars = char.get("wanted_stars", 0) or 0
    stars_str = " " + "⭐" * wanted_stars if wanted_stars > 0 else ""

    text = (
        f"🤵 *Мафиози*{stars_str}\n\n"
        f"👤 {md(char['name'])} | {CLASSES[char['class']]['name']}\n"
        f"🎖️ Ранг {char['level']}\n"
        f"❤️ {char['hp']}/{char['max_hp']} | ⚡ {char['mana']}/{char['max_mana']}\n"
        f"💵 {char['cash']}$ | 💎 {char['diamonds']} бриллиантов"
        f"{job_line}"
    )
    if pay_note:
        text += f"\n\n{pay_note}"
    if fine_note:
        text += f"\n\n{fine_note}"
    if regen_note:
        text += f"\n{regen_note}"

    await _edit_text(query,text, parse_mode="Markdown", reply_markup=await contacts_kb(user_id))

# ============================================================
# ХЕНДЛЕРЫ — РАБОТА (контрактная модель v2)
#
# Игрок берёт ОДИН контракт, ждёт 1 час, нажимает «Забрать выплату».
# При сборе: рандомная сумма + бросок на звезду копов/банд.
# 3 звезды копов → тюрьма (используем существующий jail_until).
# 3 звезды банд → плен (новые поля captivity_until/captivity_count).
# ============================================================

def captivity_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton(f"💰 Выкуп — {CAPTIVITY_BAIL_DIAMONDS} 💎", callback_data="captivity_bail")],
        [InlineKeyboardButton("⏳ Ждать (осталось — см. выше)",         callback_data="captivity_wait")],
    ])


def _job_state(char: dict) -> str:
    """Возвращает состояние игрока для меню работы: captive / jailed / working / idle."""
    now = int(time.time())
    if (char.get("captivity_until") or 0) > now:
        return "captive"
    if (char.get("jail_until") or 0) > now:
        return "jailed"
    if char.get("job") and JOBS.get(char.get("job")):
        return "working"
    return "idle"


def _job_remaining_sec(char: dict, job: dict) -> int:
    """Сколько секунд осталось до возможности забрать выплату."""
    started = char.get("job_started") or 0
    end_ts  = started + job.get("duration", JOB_DURATION)
    return max(0, end_ts - int(time.time()))


async def jobs_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    state = _job_state(char)
    now = int(time.time())

    # === В плену у банд ===
    if state == "captive":
        cap_until = char["captivity_until"]
        mins_left = max(0, (cap_until - now + 59) // 60)
        await _edit_text(query,
            f"👊 *Ты в плену у банды*\n\n"
            f"Тебя поймали с поличным. Сидишь в подвале.\n"
            f"⏳ До освобождения: *{mins_left} мин*\n"
            f"💎 Выкуп: {CAPTIVITY_BAIL_DIAMONDS} 💎 (выйдешь сразу)\n"
            f"Иначе через час напишут «удалось сбежать».",
            parse_mode="Markdown",
            reply_markup=captivity_kb()
        )
        return

    # === В тюрьме (3 звезды копов) — используем уже существующую jail_kb ===
    if state == "jailed":
        mins_left = max(0, (char["jail_until"] - now + 59) // 60)
        await _edit_text(query,
            f"🚔 *Ты в тюрьме*\n\n"
            f"Менты накрыли. Сидишь в КПЗ.\n"
            f"⏳ До освобождения: *{mins_left} мин*\n"
            f"💎 Адвокат: {JAIL_BAIL_DIAMONDS} 💎",
            parse_mode="Markdown",
            reply_markup=jail_kb()
        )
        return

    # === Текущий контракт идёт ===
    if state == "working":
        job = JOBS[char["job"]]
        remaining = _job_remaining_sec(char, job)
        cop_stars  = char.get("wanted_stars", 0) or 0
        gang_stars = char.get("wanted_gangs", 0) or 0
        stars_line = ""
        if cop_stars:  stars_line += f"\n🚓 Звёзды копов: {'⭐'*cop_stars}"
        if gang_stars: stars_line += f"\n👊 Звёзды банд: {'⭐'*gang_stars}"
        if remaining > 0:
            mins = (remaining + 59) // 60
            await _edit_text(query,
                f"🛠 *Идёт работа: {job['name']}*\n\n"
                f"⏳ Осталось: *{mins} мин*\n"
                f"После окончания нажми «💰 Забрать выплату»."
                f"{stars_line}",
                parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup([
                    [InlineKeyboardButton(f"🛠 Работаю... ({mins} мин)", callback_data="jobs")],
                    [InlineKeyboardButton("🚪 Сорвать (без денег)",      callback_data="job_quit_confirm")],
                    [InlineKeyboardButton("⬅️ Назад",                    callback_data="main_menu")],
                ])
            )
        else:
            pay_min = job.get("pay_min", 0); pay_max = job.get("pay_max", 0)
            await _edit_text(query,
                f"💼 *Работа выполнена: {job['name']}*\n\n"
                f"Час истёк. Можно забирать.\n"
                f"💵 Выплата: {pay_min}–{pay_max}$ (случайно)\n"
                f"⚠️ Возможен риск-чек: звёзды копов или банд."
                f"{stars_line}",
                parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup([
                    [InlineKeyboardButton("💰 Забрать выплату", callback_data="job_collect")],
                    [InlineKeyboardButton("⬅️ Назад",          callback_data="main_menu")],
                ])
            )
        return

    # === Свободен — показываем список доступных работ ===
    inv = await get_inventory(user_id)
    has_passport = "passport" in inv
    char_rank = char.get("level", 1) or 1

    rows = []
    locked_rank = []
    for job_id, job in JOBS.items():
        min_rank = job.get("rank", 1)
        if char_rank < min_rank:
            locked_rank.append(f"🔒 {job['name']} — требуется ранг {min_rank}")
            continue
        if job.get("passport") and not has_passport:
            rows.append([InlineKeyboardButton(f"🔒 {job['name']} (нужен паспорт)", callback_data="job_need_passport")])
        else:
            rows.append([InlineKeyboardButton(job["name"], callback_data=f"job_info_{job_id}")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])

    cop_stars  = char.get("wanted_stars", 0) or 0
    gang_stars = char.get("wanted_gangs", 0) or 0
    stars_line = ""
    if cop_stars:  stars_line += f"\n🚓 Звёзды копов: {'⭐'*cop_stars}/3"
    if gang_stars: stars_line += f"\n👊 Звёзды банд: {'⭐'*gang_stars}/3"

    locked_block = ""
    if locked_rank:
        locked_block = "\n\n_Скоро откроется (по рангу):_\n" + "\n".join(locked_rank[:5])

    await _edit_text(query,
        f"💼 *Биржа работ*\n\n"
        f"Берёшь один контракт. Через час нажимаешь «Забрать выплату».\n"
        f"Ранг: *{char_rank}*"
        f"{stars_line}"
        f"{locked_block}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )


async def job_info(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    job_id = query.data.replace("job_info_", "")
    job = JOBS.get(job_id)
    if not job:
        await query.answer("Работа не найдена.", show_alert=True); return

    cop_pct  = int(round(job.get("cop_star_chance",  0) * 100))
    gang_pct = int(round(job.get("gang_star_chance", 0) * 100))
    risk_lines = []
    if cop_pct:  risk_lines.append(f"🚓 Шанс +1 звезды копов: *{cop_pct}%*")
    if gang_pct: risk_lines.append(f"👊 Шанс +1 звезды банд: *{gang_pct}%*")
    risk_block = "\n".join(risk_lines) if risk_lines else "⚠️ Рисков нет"

    await _edit_text(query,
        f"💼 *{job['name']}*\n\n"
        f"_{job['desc']}_\n\n"
        f"💵 Выплата: *{job['pay_min']}–{job['pay_max']}$* (случайно)\n"
        f"⏳ Длительность: 1 час\n"
        f"{risk_block}\n\n"
        f"Берёшь контракт?",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🛠 Приступить", callback_data=f"job_hire_{job_id}")],
            [InlineKeyboardButton("⬅️ Назад",      callback_data="jobs")],
        ])
    )


async def job_hire(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Берём контракт. Не путать со старой 'устроиться на работу' — теперь это разовый контракт."""
    query = update.callback_query
    await query.answer()
    job_id = query.data.replace("job_hire_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)

    # Защита от двойного старта
    state = _job_state(char)
    if state in ("captive", "jailed"):
        await query.answer("Сначала выберись отсюда.", show_alert=True); return
    if state == "working":
        await query.answer("Уже работаешь — закончи или сорви.", show_alert=True); return

    job = JOBS.get(job_id)
    if not job:
        await query.answer("Такой работы нет.", show_alert=True); return

    if (char.get("level", 1) or 1) < job.get("rank", 1):
        await query.answer(f"Нужен ранг {job['rank']}.", show_alert=True); return

    now = int(time.time())
    await update_character(user_id, job=job_id, job_started=now, job_last_paid=now)

    mins = job.get("duration", JOB_DURATION) // 60
    await _edit_text(query,
        f"🛠 *Контракт принят: {job['name']}*\n\n"
        f"⏳ Возвращайся через *{mins} мин* — заберёшь выплату.\n"
        f"Можно сорвать раньше — но денег не получишь.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("⬅️ В меню работ", callback_data="jobs")],
            [InlineKeyboardButton("🏠 Главное меню",  callback_data="main_menu")],
        ])
    )


async def job_collect(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Забрать выплату по завершённому контракту."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)

    if not char.get("job"):
        await query.answer("Контракта нет.", show_alert=True); return
    job = JOBS.get(char["job"])
    if not job:
        # Битый job_id — просто чистим
        await update_character(user_id, job=None, job_started=None, job_last_paid=None)
        await query.answer("Контракт устарел, сброшен.", show_alert=True); return

    if _job_remaining_sec(char, job) > 0:
        mins = (_job_remaining_sec(char, job) + 59) // 60
        await query.answer(f"Ещё рано! Подожди {mins} мин.", show_alert=True); return

    # Рандомная сумма
    pay = random.randint(int(job["pay_min"]), int(job["pay_max"]))
    cop_added  = 1 if random.random() < float(job.get("cop_star_chance",  0)) else 0
    gang_added = 1 if random.random() < float(job.get("gang_star_chance", 0)) else 0

    cop_stars  = (char.get("wanted_stars", 0) or 0) + cop_added
    gang_stars = (char.get("wanted_gangs", 0) or 0) + gang_added

    updates = {
        "cash":          (char.get("cash", 0) or 0) + pay,
        "job":           None,
        "job_started":   None,
        "job_last_paid": None,
        "wanted_stars":  min(3, cop_stars),
        "wanted_gangs":  min(3, gang_stars),
    }

    # Триггер: 3 звезды копов → тюрьма
    jail_triggered = False
    if cop_stars >= 3 and (char.get("jail_until", 0) or 0) <= int(time.time()):
        updates["jail_until"]  = int(time.time()) + JAIL_DURATION
        updates["jail_count"]  = (char.get("jail_count", 0) or 0) + 1
        jail_triggered = True

    # Триггер: 3 звезды банд → плен
    cap_triggered = False
    if gang_stars >= 3 and (char.get("captivity_until", 0) or 0) <= int(time.time()):
        updates["captivity_until"] = int(time.time()) + CAPTIVITY_DURATION
        updates["captivity_count"] = (char.get("captivity_count", 0) or 0) + 1
        cap_triggered = True

    await update_character(user_id, **updates)

    # Текст результата
    lines = [f"💰 *Выплата получена: +{pay}$*"]
    lines.append(f"_{job['name']}_")
    if cop_added:
        lines.append(f"🚓 Менты заметили: *+1 звезда копов* (теперь {min(3,cop_stars)}/3)")
    if gang_added:
        lines.append(f"👊 Банда узнала: *+1 звезда банд* (теперь {min(3,gang_stars)}/3)")
    if jail_triggered:
        lines.append("")
        lines.append(f"🚔 *Тебя взяли копы!* Тюрьма на {JAIL_DURATION//60} мин.")
    if cap_triggered:
        lines.append("")
        lines.append(f"👊 *Тебя поймали братки!* В плену {CAPTIVITY_DURATION//60} мин.")

    # Какое меню показать
    if jail_triggered:
        kb = jail_kb()
    elif cap_triggered:
        kb = captivity_kb()
    else:
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("💼 Новый контракт", callback_data="jobs")],
            [InlineKeyboardButton("🏠 Главное меню",  callback_data="main_menu")],
        ])

    await _edit_text(query,
        "\n".join(lines),
        parse_mode="Markdown",
        reply_markup=kb
    )


async def job_quit_confirm(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """В новой модели — это «сорвать контракт» без выплаты."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if not char.get("job"):
        await _edit_text(query, "Контракта нет.", reply_markup=await contacts_kb(user_id)); return
    job = JOBS.get(char["job"])
    job_name = job["name"] if job else "работа"
    await _edit_text(query,
        f"🚪 *Сорвать контракт?*\n\n"
        f"{job_name}\n"
        f"⚠️ Денег не получишь. Звёзды риска тоже не упадут.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("✅ Да, сорвать", callback_data="job_quit_do")],
            [InlineKeyboardButton("❌ Остаться",    callback_data="jobs")],
        ])
    )


async def job_quit_do(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Сорвать контракт — без денег, без штрафа (звёзды риска не добавляются)."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if not char.get("job"):
        await _edit_text(query, "Контракта нет.", reply_markup=await contacts_kb(user_id)); return
    job = JOBS.get(char["job"])
    job_name = job["name"] if job else "контракт"
    await update_character(user_id, job=None, job_started=None, job_last_paid=None)
    await _edit_text(query,
        f"🚪 *Контракт сорван.*\n\n"
        f"_{job_name}_\n"
        f"Без денег, но и без последствий.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("💼 Новый контракт", callback_data="jobs")],
            [InlineKeyboardButton("🏠 Главное меню",  callback_data="main_menu")],
        ])
    )


async def job_need_passport(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.callback_query.answer(
        "📄 Нужен паспорт! Иди бить 🪒 Жигана на Рынке. Шанс дропа — 40%.",
        show_alert=True
    )


# ── Плен у банд (аналог тюрьмы) ───────────────────────────────────────────

async def captivity_bail(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if (char.get("captivity_until", 0) or 0) <= int(time.time()):
        await query.answer("Ты уже на свободе.", show_alert=True); return
    if (char.get("diamonds", 0) or 0) < CAPTIVITY_BAIL_DIAMONDS:
        await query.answer(
            f"Нужно {CAPTIVITY_BAIL_DIAMONDS} 💎. У тебя {char.get('diamonds',0)}.",
            show_alert=True
        ); return
    new_d = (char["diamonds"] or 0) - CAPTIVITY_BAIL_DIAMONDS
    await update_character(user_id,
        diamonds=new_d, captivity_until=0, wanted_gangs=0,
        hp=char["max_hp"] // 2, mana=char["max_mana"] // 2
    )
    await _edit_text(query,
        f"💰 *Выкупился из плена!*\n\n"
        f"Потрачено: {CAPTIVITY_BAIL_DIAMONDS} 💎\n"
        f"Ты на свободе. Звёзды банд сняты.\n"
        f"❤️ 50% HP | ⚡ 50% Энергии",
        parse_mode="Markdown",
        reply_markup=await contacts_kb(user_id)
    )


async def captivity_wait(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user_id = update.effective_user.id
    char = await get_character(user_id)
    cap_until = char.get("captivity_until", 0) or 0
    mins_left = max(0, (cap_until - int(time.time()) + 59) // 60)
    await query.answer(f"⏳ До побега: {mins_left} мин. Жди.", show_alert=True)

# ============================================================
# ХЕНДЛЕРЫ — РАЙОНЫ
# ============================================================

async def explore(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    char = await get_character(update.effective_user.id)
    rows = []
    for loc_id, loc in LOCATIONS.items():
        ok = char["level"] >= loc["min_level"]
        label = f"{loc['name']} (ранг {loc['min_level']}+)" if ok else f"🔒 {loc['name']} (ранг {loc['min_level']}+)"
        rows.append([InlineKeyboardButton(label, callback_data=f"location_{loc_id}" if ok else "locked")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])
    text = "🗺️ *Выбери район*\n\nКуда едем?"
    keyboard = InlineKeyboardMarkup(rows)
    try:
        await _edit_text(query,text, parse_mode="Markdown", reply_markup=keyboard)
    except Exception:
        try:
            await query.message.delete()
        except Exception:
            pass
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text=text,
            parse_mode="Markdown",
            reply_markup=keyboard
        )

async def try_random_encounter(update, context, loc_id: str = None) -> bool:
    """Проверяет и показывает случайную встречу. Возвращает True если встреча произошла."""
    query = update.callback_query
    user_id = update.effective_user.id
    char = await get_character(user_id)
    now = int(time.time())
    last_enc = char.get("gang_last_encounter") or 0
    if (now - last_enc) < GANG_ENCOUNTER_COOLDOWN:
        return False
    roll = random.random()
    enc_type = None
    if roll < 0.15:
        # Медик и Разведчик редкие (10% от всех встреч)
        enc_type = random.choices(
            ["mercenary", "bruiser", "sniper", "bomber", "medic", "scout"],
            weights=[30, 25, 20, 15, 5, 5], k=1
        )[0]
    if not enc_type:
        return False
    await update_character(user_id, gang_last_encounter=now)
    gang = await get_gang(user_id)
    owned_prop_enc = await get_property(user_id)
    gang_max_enc   = calc_gang_max(owned_prop_enc)
    gang_roles_taken = {m["role"] for m in gang}
    p_role = enc_type

    if not loc_id:
        loc_id = context.user_data.get("last_loc", "market")
    p_name = random.choice(RANDOM_NAMES)
    person = random.choice(EVENT_PEOPLE)
    role_info = GANG_ROLES[p_role]
    context.user_data["encounter"] = {"name": p_name, "role": p_role, "loc": loc_id}
    gang_full = len(gang) >= gang_max_enc
    inv = await get_inventory(user_id)
    has_medkit = "medkit_small" in inv
    role_line = f"{role_info['emoji']} Похоже, это *{role_info['title']}*\n_Может пригодиться: {role_info['reward_desc']}_"
    gang_note = f"\n\n⚠️ _Банда полная ({gang_max_enc}/{gang_max_enc}). Сначала исключи кого-то._" if gang_full else ""
    buttons = [[InlineKeyboardButton(f"💵 Дать ${GANG_HELP_CASH}", callback_data="enc_cash")]]
    if has_medkit:
        buttons.append([InlineKeyboardButton("💊 Дать таблетку", callback_data="enc_pill")])
    buttons.append([InlineKeyboardButton("😤 Пройти мимо", callback_data=f"enc_skip_{loc_id}")])
    await _edit_text(query,
        f"⚡ *Случайная встреча!*\n\n"
        f"{person['emoji']} *{p_name}* — {person['desc']}.\n\n"
        f"{role_line}{gang_note}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(buttons)
    )
    return True



# ═══════════════════════════════════════════════════════════════════════════════
# УЛИЧНЫЕ СЛУЧАЙНЫЕ СОБЫТИЯ
# ═══════════════════════════════════════════════════════════════════════════════

STREET_EVENTS = [
    # ── Негативные ──────────────────────────────────────────────────────────
    {
        "id": "cop_bribe",
        "chance": 0.12, "cd_key": "street_cop_at", "cooldown": "STREET_COP_CD",
        "neg": True,
        "title": "🚔 *Полицейский!*",
        "fn": "cop_bribe",
    },
    {
        "id": "witness",
        "chance": 0.10, "cd_key": "street_witness_at", "cooldown": "STREET_WITNESS_CD",
        "neg": True,
        "title": "📸 *Тебя сфотографировали!*",
        "fn": "witness",
    },
    {
        "id": "dog_bite",
        "chance": 0.10, "cd_key": "street_dog_at", "cooldown": "STREET_DOG_CD",
        "neg": True,
        "title": "🐕 *Собака!*",
        "fn": "dog_bite",
    },
    {
        "id": "pickpocket",
        "chance": 0.10, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🎩 *Тебя обчистили!*",
        "fn": "pickpocket",
    },
    {
        "id": "broken_bottle",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🍾 *Разборка на улице!*",
        "fn": "broken_bottle",
    },
    {
        "id": "debt_collector",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "💼 *Коллектор!*",
        "fn": "debt_collector",
    },
    {
        "id": "frame_up",
        "chance": 0.07, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🗞️ *Тебя подставили!*",
        "fn": "frame_up",
    },
    # ── Позитивные ──────────────────────────────────────────────────────────
    {
        "id": "find_money",
        "chance": 0.15, "cd_key": "street_find_money_at", "cooldown": "STREET_FIND_MONEY_CD",
        "neg": False,
        "title": "💸 *Нашёл бабки!*",
        "fn": "find_money",
    },
    {
        "id": "girl",
        "chance": 0.20, "cd_key": "street_girl_at", "cooldown": "STREET_GIRL_CD",
        "neg": False,
        "title": "💃 *Красотка!*",
        "fn": "girl",
    },
    {
        "id": "lucky_bet",
        "chance": 0.10, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🎲 *Удачная ставка!*",
        "fn": "lucky_bet",
    },
    {
        "id": "old_debt",
        "chance": 0.10, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🤝 *Старый должник!*",
        "fn": "old_debt",
    },
    {
        "id": "drug_dealer",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "💊 *Барыга угощает!*",
        "fn": "drug_dealer",
    },
    {
        "id": "found_weapon_part",
        "chance": 0.07, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🔩 *Находка!*",
        "fn": "found_weapon_part",
    },
    {
        "id": "tip_from_informant",
        "chance": 0.07, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🔍 *Наводка!*",
        "fn": "tip_from_informant",
    },
    # ── Ещё негативные ──────────────────────────────────────────────────
    {
        "id": "tax_audit",
        "chance": 0.05, "cd_key": "street_cop_at", "cooldown": "STREET_COP_CD",
        "neg": True,
        "title": "📋 *Налоговая!*",
        "fn": "tax_audit",
        "require_job": True,
    },
    {
        "id": "shell_game",
        "chance": 0.10, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🎩 *Напёрсточник!*",
        "fn": "shell_game",
    },
    {
        "id": "ambush",
        "chance": 0.09, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🪓 *Засада!*",
        "fn": "ambush",
    },
    {
        "id": "rival_snitch",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "😤 *Конкурент!*",
        "fn": "rival_snitch",
    },
    {
        "id": "fake_deal",
        "chance": 0.09, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🤡 *Кидалово!*",
        "fn": "fake_deal",
    },
    {
        "id": "vandal_attack",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": True,
        "title": "🧱 *Отморозки!*",
        "fn": "vandal_attack",
    },
    # ── Ещё позитивные ──────────────────────────────────────────────────
    {
        "id": "found_stash",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "📦 *Схрон!*",
        "fn": "found_stash",
    },
    {
        "id": "rep_bonus",
        "chance": 0.09, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🏆 *Уважение!*",
        "fn": "rep_bonus",
    },
    {
        "id": "free_ride",
        "chance": 0.10, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🚗 *Подвезли!*",
        "fn": "free_ride",
    },
    {
        "id": "medkit_found",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "🩹 *Аптечка!*",
        "fn": "medkit_found",
    },
    {
        "id": "protection_fee",
        "chance": 0.08, "cd_key": "street_event_at", "cooldown": "STREET_EVENT_CD",
        "neg": False,
        "title": "💰 *Дань!*",
        "fn": "protection_fee",
    },
]


# ═══════════════════════════════════════════════════════════════════════════════
# СОБЫТИЯ МИНИ-АППА (привязаны к игровому времени суток)
# Триггерятся клиентом каждый игровой час (= 1 реальная минута), показываются
# в модальном окне в hub.html. Параллельная система к STREET_EVENTS.
# ═══════════════════════════════════════════════════════════════════════════════

# События в хабе должны реально выпадать, а не теряться в кулдаунах.
# Раньше было 3 минуты + 30% — игрок мог провести полчаса и не увидеть ни одного.
# Теперь: 60 сек кулдаун + 60% шанс → среднее ~1.5–2 мин между событиями,
# что заметно во время прогулок по меню.
HUB_EVENT_COOLDOWN  = 60       # 60 сек реального времени между событиями
HUB_EVENT_CHANCE    = 0.60     # шанс события на тик (если кулдаун прошёл и не в бою)

HUB_EVENTS = [
    # ── УТРО (7) — позитив, восстановление ──────────────────────────────
    {"id": "morn_jog",            "phases": ["morning"], "weight": 10,
     "text": "🏃 Утренняя пробежка по району. Свежий воздух освежает голову.",
     "effects": {"energy": +15}},
    {"id": "morn_coffee",         "phases": ["morning"], "weight": 10,
     "text": "☕ Зашёл за кофе в любимую кофейню — старый знакомый налил со скидкой.",
     "effects": {"energy": +10, "cash": -30}},
    {"id": "morn_diner",          "phases": ["morning"], "weight": 8,
     "text": "🍳 Завтрак в «семейной» забегаловке. Старшие угостили — отказывать нельзя.",
     "effects": {"energy": +20, "hp": +10}},
    {"id": "morn_girl_smile",     "phases": ["morning"], "weight": 8,
     "text": "💃 Красивая девушка улыбнулась тебе на остановке. Хороший знак на день.",
     "effects": {"energy": +15}},
    {"id": "morn_help_grandma",   "phases": ["morning"], "weight": 6,
     "text": "👵 Соседская бабушка попросила донести сумки. Сунула двадцатку «на чай».",
     "effects": {"energy": +5, "cash": +20}},
    {"id": "morn_found_cash",     "phases": ["morning"], "weight": 7,
     "text": "💵 Утром нашёл сотню баксов на парковке. Кто-то обронил — теперь твои.",
     "effects": {"cash": +100}},
    {"id": "morn_friend_call",    "phases": ["morning"], "weight": 6,
     "text": "📞 Старый кореш звонит. Поздравляет, что ты выжил после последнего дела.",
     "effects": {"energy": +10}},

    # ── ДЕНЬ (8) — работа, сделки, бытовуха ─────────────────────────────
    {"id": "day_errand_boss",     "phases": ["day"], "weight": 10,
     "text": "📦 Старший дал поручение — передать «привет» паре парней. Справился чисто.",
     "effects": {"cash": +200, "energy": -10}},
    {"id": "day_sold_car",        "phases": ["day"], "weight": 8,
     "text": "🚗 Удачно толкнул б/у тачку через знакомого барыгу. Старая, но рабочая.",
     "effects": {"cash": +500}},
    {"id": "day_cards_win",       "phases": ["day"], "weight": 9,
     "text": "🃏 Сыграл в карты на районе. Залётный лоханулся — забрал банк.",
     "effects": {"cash": +300}},
    {"id": "day_cards_lose",      "phases": ["day"], "weight": 8,
     "text": "🃏 Сыграл в карты на районе. Проигрался — настроение ниже плинтуса.",
     "effects": {"cash": -200, "energy": -10}},
    {"id": "day_stand_by_boss",   "phases": ["day"], "weight": 9,
     "text": "🤵 Босс позвал на стрелку — постоял рядом с серьёзным лицом. Хватило.",
     "effects": {"cash": +150, "energy": -5}},
    {"id": "day_shawarma",        "phases": ["day"], "weight": 7,
     "text": "🌯 Купил шаурму и газировку в ларьке. Жизнь — простая штука.",
     "effects": {"energy": +5, "cash": -40}},
    {"id": "day_traffic_late",    "phases": ["day"], "weight": 6,
     "text": "🚦 Пробка задержала на сделку — старший высказал тебе всё, что думает.",
     "effects": {"energy": -10}},
    {"id": "day_help_move",       "phases": ["day"], "weight": 7,
     "text": "📦 Помог другу с переездом — заплатил по факту, без лишних разговоров.",
     "effects": {"cash": +250, "energy": -15}},

    # ── ВЕЧЕР (7) — конфликты, мелкая криминальщина, mixed ──────────────
    {"id": "even_thug_attack",    "phases": ["evening"], "weight": 9,
     "text": "🥊 Налетел гопник в подворотне — нанёс пару увечий и скрылся. Не успел догнать.",
     "effects": {"hp": -30}},
    {"id": "even_bar_girl",       "phases": ["evening"], "weight": 8,
     "text": "💋 В кабаке познакомился с девчонкой — провели приятный вечер вдвоём.",
     "effects": {"energy": +20}},
    {"id": "even_market_scam",    "phases": ["evening"], "weight": 7,
     "text": "🤝 На рынке тебя пытались обуть на сдачу — разобрался по-своему.",
     "effects": {"cash": +100}},
    {"id": "even_drunk_fight",    "phases": ["evening"], "weight": 8,
     "text": "🍺 Сцепился с пьяным наезжающим — выпотрошил его кошелёк за труды.",
     "effects": {"hp": -15, "cash": +50}},
    {"id": "even_dark_deal",      "phases": ["evening"], "weight": 7,
     "text": "🤫 Старший подкинул левый заработок — встреча с нужным человеком прошла гладко.",
     "effects": {"cash": +400}},
    {"id": "even_crossfire",      "phases": ["evening"], "weight": 5,
     "text": "💥 Случайно угодил под перестрелку соседних банд. Поймал шальную пулю в плечо.",
     "effects": {"hp": -40}},
    {"id": "even_rooftop",        "phases": ["evening"], "weight": 7,
     "text": "🌃 Спокойный вечер на крыше — почитал газету, выпил холодного пива.",
     "effects": {"energy": +15}},

    # ── НОЧЬ (8) — опасное время, криминальщина, мафия ──────────────────
    {"id": "night_bounty_hunters","phases": ["night"], "weight": 7,
     "text": "🎯 Ночные охотники за головами выследили — пришлось отбиваться. Узнали лицо.",
     "effects": {"hp": -50, "wanted_g": +1}},
    {"id": "night_camera_caught", "phases": ["night"], "weight": 8,
     "text": "📹 Камеры у банка засекли тебя после полночного «дела». Копы зашевелились.",
     "effects": {"wanted": +1}},
    {"id": "night_parking_gang",  "phases": ["night"], "weight": 7,
     "text": "🚙 На ночной парковке нарвался на агрессивную тусовку — еле унёс ноги.",
     "effects": {"hp": -25}},
    {"id": "night_kill_bootlegger","phases": ["night"], "weight": 6,
     "text": "🍸 Помог завалить конкурирующего бутлегера — старшие в восторге, чужая банда — нет.",
     "effects": {"cash": +800, "wanted_g": +1}},
    {"id": "night_found_briefcase","phases": ["night"], "weight": 6,
     "text": "💼 Глубокой ночью нашёл оставленный кейс с деньгами — забрал без вопросов.",
     "effects": {"cash": +500}},
    {"id": "night_mugged",        "phases": ["night"], "weight": 7,
     "text": "🔪 Тебя загнали в подворотню — отняли кэш и пробили голову. Адрес не помнишь.",
     "effects": {"hp": -20, "cash": -300}},
    {"id": "night_safe_sleep",    "phases": ["night"], "weight": 8,
     "text": "🛏 Ночь прошла спокойно — выспался в безопасной квартире у знакомой.",
     "effects": {"energy": +25, "hp": +10}},
    {"id": "night_protection_run","phases": ["night"], "weight": 6,
     "text": "💰 Прошёл «по точкам» — собрал крышу с торговцев. Обычная рутина.",
     "effects": {"cash": +600, "energy": -10}},
]

# ═══════════════════════════════════════════════════════════════════════════════
# БИЗНЕСЫ (пассивный доход, мафиозный стиль)
# ═══════════════════════════════════════════════════════════════════════════════

BIZ_INCOME_PERIOD = 24 * 3600  # сутки = одна полная порция дохода
BIZ_EVENT_CHANCE  = 0.20       # шанс события на бизнес при сборе (если не на кулдауне)
BIZ_EVENT_COOLDOWN = 6 * 3600  # 6 часов между событиями на одном бизнесе

# id, name, emoji, price, daily_min, daily_max, desc
BUSINESSES = [
    {"id": "coffee",     "emoji": "☕", "name": "Кофейня «У Дона»",
     "price":   3000, "daily_min":  150, "daily_max":  200,
     "desc": "Тихая кофейня на углу. Прикрытие для встреч и стабильный кэш."},
    {"id": "carwash",    "emoji": "🚗", "name": "Автомойка",
     "price":   5000, "daily_min":  220, "daily_max":  300,
     "desc": "Удобная схема для отмыва налички. Машины моют, бабки трутся."},
    {"id": "barbershop", "emoji": "💈", "name": "Парикмахерская",
     "price":   7500, "daily_min":  300, "daily_max":  400,
     "desc": "Классика жанра. Здесь все «свои» договариваются."},
    {"id": "pizza",      "emoji": "🍕", "name": "Пиццерия",
     "price":  12000, "daily_min":  450, "daily_max":  600,
     "desc": "Доставка пиццы — отличная легенда для перевозок чего угодно."},
    {"id": "garage",     "emoji": "🔧", "name": "Гараж-СТО",
     "price":  18000, "daily_min":  650, "daily_max":  900,
     "desc": "Ремонтируем тачки, варим номера, шлифуем VIN. Спрос есть."},
    {"id": "bar",        "emoji": "🍸", "name": "Бар «Чёрная вдова»",
     "price":  28000, "daily_min": 1000, "daily_max": 1400,
     "desc": "Ночной бар. Алкоголь, музыка, сделки за столиком в углу."},
    {"id": "club",       "emoji": "🎰", "name": "Подпольный клуб",
     "price":  45000, "daily_min": 1600, "daily_max": 2200,
     "desc": "Карты, рулетка, ставки. Доходно, но налоговая чует."},
    {"id": "warehouse",  "emoji": "📦", "name": "Склад",
     "price":  70000, "daily_min": 2400, "daily_max": 3300,
     "desc": "Большой склад на окраине. Хранение «чувствительного» груза."},
    {"id": "casino",     "emoji": "🎲", "name": "Казино",
     "price": 120000, "daily_min": 4000, "daily_max": 5500,
     "desc": "Своё казино — мечта каждого. Высокий доход, высокий риск."},
    {"id": "port",       "emoji": "🚢", "name": "Доля в порту",
     "price": 200000, "daily_min": 6500, "daily_max": 9000,
     "desc": "Купил долю в порту. Контейнеры идут — деньги капают."},
]

# События по бизнесам — срабатывают редко при сборе дохода
BUSINESS_EVENTS = [
    {"id": "biz_tax_audit",    "weight": 8,
     "text": "📋 Налоговая накрыла бизнес — забрали 20% выручки.",
     "kind": "income_penalty", "value": 0.20},
    {"id": "biz_protection",   "weight": 7,
     "text": "💰 Заехали парни «за крышу» — отстегнул 15% выручки.",
     "kind": "income_penalty", "value": 0.15},
    {"id": "biz_thieves",      "weight": 6,
     "text": "🦹 Воришки залезли ночью — украли часть кассы (10%).",
     "kind": "income_penalty", "value": 0.10},
    {"id": "biz_inspection",   "weight": 5,
     "text": "🚓 Полицейская проверка — бизнес заблокирован на 12 часов.",
     "kind": "block", "hours": 12},
    {"id": "biz_health_dept",  "weight": 4,
     "text": "🥼 Санэпидемстанция нашла нарушения — бизнес закрыт на сутки.",
     "kind": "block", "hours": 24},
    {"id": "biz_arson",        "weight": 2,
     "text": "🔥 Конкуренты подожгли точку! Нужно восстанавливать.",
     "kind": "burn"},
    {"id": "biz_lucky_day",    "weight": 8,
     "text": "✨ Удачный день — поток клиентов, выручка +30%.",
     "kind": "income_bonus", "value": 0.30},
    {"id": "biz_celebrity",    "weight": 6,
     "text": "⭐ Знаменитость зашла — заведение в моде, выручка +20%.",
     "kind": "income_bonus", "value": 0.20},
    {"id": "biz_smooth",       "weight": 5,
     "text": "🤝 Местный авторитет похвалил твой бизнес — все идёт гладко (+10%).",
     "kind": "income_bonus", "value": 0.10},
    {"id": "biz_gang_war",     "weight": 4,
     "text": "💢 Стрельба у твоей точки — клиенты разбежались (-25% выручки).",
     "kind": "income_penalty", "value": 0.25},
]


def get_business(biz_id: str):
    for b in BUSINESSES:
        if b["id"] == biz_id:
            return b
    return None


def pick_business_event():
    pool = BUSINESS_EVENTS
    total = sum(e["weight"] for e in pool)
    r = random.uniform(0, total)
    acc = 0
    for e in pool:
        acc += e["weight"]
        if r <= acc:
            return e
    return pool[-1]


# События после боя — отдельный пул, триггерится при завершении боя
HUB_POST_BATTLE_EVENTS = [
    {"id": "after_cop_check",     "weight": 5,
     "text": "🚓 После шума копы начали проверку района — ты под подозрением.",
     "effects": {"wanted": +1}},
    {"id": "after_gang_complaint","weight": 5,
     "text": "👊 Какой-то парень с татуировками пожаловался на тебя своим. Жди ответа.",
     "effects": {"wanted_g": +1}},
    {"id": "after_witness_seen",  "weight": 3,
     "text": "👁 Свидетели заметили тебя у места происшествия. Пошли слухи.",
     "effects": {"wanted": +1}},
]


def pick_hub_event(phase: str):
    """Выбирает случайное событие из HUB_EVENTS по фазе суток (взвешенно)."""
    pool = [e for e in HUB_EVENTS if phase in e["phases"]]
    if not pool:
        return None
    total = sum(e["weight"] for e in pool)
    r = random.uniform(0, total)
    acc = 0
    for e in pool:
        acc += e["weight"]
        if r <= acc:
            return e
    return pool[-1]


def pick_post_battle_event():
    """Выбирает случайное событие из HUB_POST_BATTLE_EVENTS (взвешенно)."""
    pool = HUB_POST_BATTLE_EVENTS
    total = sum(e["weight"] for e in pool)
    r = random.uniform(0, total)
    acc = 0
    for e in pool:
        acc += e["weight"]
        if r <= acc:
            return e
    return pool[-1]


async def try_street_event(update, context, loc_id: str) -> bool:
    """Проверяет и запускает уличное случайное событие. Возвращает True если событие сработало."""
    query  = update.callback_query
    user_id = update.effective_user.id
    char   = await get_character(user_id)
    now    = int(time.time())

    # Глобальный кулдаун: после любого события ждём 4 минуты
    last_global = char.get("street_last_event_at", 0) or 0
    if (now - last_global) < STREET_GLOBAL_CD:
        return False

    CD_MAP = {
        "STREET_FIND_MONEY_CD": STREET_FIND_MONEY_CD,
        "STREET_GIRL_CD":       STREET_GIRL_CD,
        "STREET_DOG_CD":        STREET_DOG_CD,
        "STREET_COP_CD":        STREET_COP_CD,
        "STREET_WITNESS_CD":    STREET_WITNESS_CD,
        "STREET_EVENT_CD":      STREET_EVENT_CD,
    }

    import random as _rnd
    _rnd.shuffle(STREET_EVENTS)   # перемешиваем каждый раз
    for ev in STREET_EVENTS:
        cd = CD_MAP[ev["cooldown"]]
        last = char.get(ev["cd_key"], 0) or 0
        if (now - last) < cd:
            continue
        if _rnd.random() > ev["chance"]:
            continue
        # Событие сработало
        if ev.get("require_job") and not char.get("job"):
            continue
        await update_character(user_id, street_last_event_at=now)
        await getattr(_StreetEvents, ev["fn"])(query, user_id, char, loc_id, context)
        return True
    return False


class _StreetEvents:
    """Статические методы — логика каждого события."""

    @staticmethod
    async def cop_bribe(query, user_id, char, loc_id, context):
        bribe = random.randint(15, 30)
        new_cash = max(0, char["cash"] - bribe)
        await update_character(user_id, cash=new_cash, street_cop_at=int(time.time()))
        await _edit_text(query,
            "🚔 *Стоп! Полиция!*\n\n"
            "Коп подошёл, обшманал, посмотрел многозначительно...\n"
            f"Пришлось сунуть ему *{bribe}$* чтобы отстал.\n\n"
            f"_Грёбаные копы. Баланс: {new_cash}$_",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def witness(query, user_id, char, loc_id, context):
        current_stars = char.get("wanted_stars", 0) or 0
        new_stars = min(3, current_stars + 1)
        updates = {"street_witness_at": int(time.time()), "wanted_stars": new_stars}
        if new_stars == 3:
            jail_until = int(time.time()) + JAIL_DURATION
            updates["jail_until"] = jail_until
            updates["jail_count"] = (char.get("jail_count", 0) or 0) + 1
        await update_character(user_id, **updates)
        stars_str = "⭐" * new_stars
        extra = (
            "\n\n🚨 *3 звезды розыска — тебя берут под стражу!*\n"
            "Тюрьма на 60 минут."
        ) if new_stars == 3 else ""
        await _edit_text(query,
            "📸 *Свидетели сняли тебя на камеру!*\n\n"
            "Кто-то видел как ты разбирался с очередным чуваком и скинул видео в полицию.\n"
            f"Уровень розыска: {stars_str}{extra}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def dog_bite(query, user_id, char, loc_id, context):
        dmg = random.randint(20, 50)
        new_hp = max(1, char["hp"] - dmg)
        await update_character(user_id, hp=new_hp, street_dog_at=int(time.time()))
        await _edit_text(query,
            "🐕 *Бешеная псина!*\n\n"
            "Из подворотни выскочила собака и цапнула тебя за ногу.\n"
            f"Потерял *{dmg} HP*. ❤️ Осталось: {new_hp}/{char['max_hp']}\n\n"
            "_Надо бы зайти в больницу..._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏥 Больница", callback_data=f"hospital_{loc_id}")],
                [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            ])
        )

    @staticmethod
    async def pickpocket(query, user_id, char, loc_id, context):
        stolen = random.randint(10, 30)
        new_cash = max(0, char["cash"] - stolen)
        await update_character(user_id, cash=new_cash, street_event_at=int(time.time()))
        await _edit_text(query,
            "🎩 *Карманник!*\n\n"
            "Какой-то шустрый пацан срезал твой кошелёк и растворился в толпе.\n"
            f"Потерял *{stolen}$*. Баланс: {new_cash}$\n\n"
            "_Лучше держи бумажник в кармане поглубже._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def broken_bottle(query, user_id, char, loc_id, context):
        dmg = random.randint(15, 35)
        new_hp = max(1, char["hp"] - dmg)
        await update_character(user_id, hp=new_hp, street_event_at=int(time.time()))
        await _edit_text(query,
            "🍾 *Разборка!*\n\n"
            "Два местных быка не поделили угол. Ты попал под раздачу — "
            "бутылкой по плечу.\n"
            f"Потерял *{dmg} HP*. ❤️ Осталось: {new_hp}/{char['max_hp']}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏥 Больница", callback_data=f"hospital_{loc_id}")],
                [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            ])
        )

    @staticmethod
    async def debt_collector(query, user_id, char, loc_id, context):
        loss = random.randint(20, 40)
        new_cash = max(0, char["cash"] - loss)
        await update_character(user_id, cash=new_cash, street_event_at=int(time.time()))
        await _edit_text(query,
            "💼 *Коллектор!*\n\n"
            "Двое в пиджаках вежливо объяснили что ты «кое-что должен».\n"
            "Спорить было неуместно.\n"
            f"Отдал *{loss}$*. Баланс: {new_cash}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def frame_up(query, user_id, char, loc_id, context):
        current_stars = char.get("wanted_stars", 0) or 0
        new_stars = min(3, current_stars + 1)
        updates = {"street_event_at": int(time.time()), "wanted_stars": new_stars}
        if new_stars == 3:
            jail_until = int(time.time()) + JAIL_DURATION
            updates["jail_until"] = jail_until
            updates["jail_count"] = (char.get("jail_count", 0) or 0) + 1
        await update_character(user_id, **updates)
        stars_str = "⭐" * new_stars
        await _edit_text(query,
            "🗞️ *Подстава!*\n\n"
            "Местный стукач слил тебя копам — наплёл что ты продаёшь паль.\n"
            f"Уровень розыска вырос: {stars_str}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    # ── Позитивные ───────────────────────────────────────────────────────────

    @staticmethod
    async def find_money(query, user_id, char, loc_id, context):
        found = random.randint(10, 50)
        await update_character(user_id, cash=char["cash"] + found,
                               street_find_money_at=int(time.time()))
        await _edit_text(query,
            "💸 *Находка!*\n\n"
            "Шёл по улице, смотришь — лежат деньги.\n"
            f"Подобрал *{found}$* — не твоя проблема откуда они.\n\n"
            f"Баланс: {char['cash'] + found}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def girl(query, user_id, char, loc_id, context):
        mana_gain = 60
        new_mana = min(char["max_mana"], char["mana"] + mana_gain)
        await update_character(user_id, mana=new_mana, street_girl_at=int(time.time()))
        await _edit_text(query,
            "💃 *Знакомство на улице!*\n\n"
            "Очаровательная незнакомка подошла сама. Поболтали, посмеялись...\n"
            "Настроение — огонь.\n\n"
            f"⚡ *+{mana_gain} энергии!* ({new_mana}/{char['max_mana']})",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def lucky_bet(query, user_id, char, loc_id, context):
        win = random.randint(20, 50)
        await update_character(user_id, cash=char["cash"] + win,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🎲 *Удачная ставка!*\n\n"
            "Двое у подъезда кидали кости на деньги. Ты ввязался — и сорвал куш.\n"
            f"*+{win}$!*  Баланс: {char['cash'] + win}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def old_debt(query, user_id, char, loc_id, context):
        payback = random.randint(30, 70)
        await update_character(user_id, cash=char["cash"] + payback,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🤝 *Должник объявился!*\n\n"
            "Старый знакомый догнал тебя на улице и вернул долг.\n"
            "_Ты уже забыл что он тебе что-то должен._\n\n"
            f"*+{payback}$!*  Баланс: {char['cash'] + payback}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def drug_dealer(query, user_id, char, loc_id, context):
        mana_gain = 30
        new_mana = min(char["max_mana"], char["mana"] + mana_gain)
        await update_character(user_id, mana=new_mana, street_event_at=int(time.time()))
        await _edit_text(query,
            "💊 *Барыга угощает!*\n\n"
            "Местный толкач узнал тебя и протянул таблетку — за репутацию.\n"
            "_Не спрашивай что это было, но полегчало._\n\n"
            f"⚡ *+{mana_gain} энергии!* ({new_mana}/{char['max_mana']})",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def found_weapon_part(query, user_id, char, loc_id, context):
        bonus = random.randint(15, 40)
        await update_character(user_id, cash=char["cash"] + bonus,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🔩 *Находка в кустах!*\n\n"
            "В кустах у гаража нашёл кое-что интересное. Сдал скупщику.\n"
            f"*+{bonus}$!*  Баланс: {char['cash'] + bonus}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def tip_from_informant(query, user_id, char, loc_id, context):
        bonus = random.randint(25, 60)
        await update_character(user_id, cash=char["cash"] + bonus,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🔍 *Горячая наводка!*\n\n"
            "Незнакомый тип шепнул где лежит «ничьё» — ты не поленился проверить.\n"
            f"*+{bonus}$!* Баланс: {char['cash'] + bonus}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    # ── Налоговая (только при наличии работы) ──────────────────────────

    @staticmethod
    async def tax_audit(query, user_id, char, loc_id, context):
        fine = random.randint(10, 30)
        new_cash = max(0, char["cash"] - fine)
        job_name = JOBS.get(char.get("job", ""), {}).get("name", "работы")
        await update_character(user_id, cash=new_cash, street_cop_at=int(time.time()))
        await _edit_text(query,
            "📋 *Накрыла налоговая!*\n\n"
            f"Инспектор в потёртом пиджаке — по наводке на {job_name}.\n"
            "Долго листал бумаги, кряхтел, в итоге выписал штраф.\n\n"
            f"💸 *−{fine}$* (налог с дохода)\n"
            f"Баланс: {new_cash}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    # ── Новые негативные ────────────────────────────────────────────────

    @staticmethod
    async def shell_game(query, user_id, char, loc_id, context):
        loss = random.randint(15, 40)
        new_cash = max(0, char["cash"] - loss)
        await update_character(user_id, cash=new_cash, street_event_at=int(time.time()))
        await _edit_text(query,
            "🎩 *Напёрсточник!*\n\n"
            "Яркий мужик у метро предложил сыграть — \"всегда побеждают\"...\n"
            f"Проиграл *{loss}$*. Баланс: {new_cash}$\n\n"
            "_В следующий раз — мимо._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def ambush(query, user_id, char, loc_id, context):
        dmg = random.randint(25, 55)
        new_hp = max(1, char["hp"] - dmg)
        await update_character(user_id, hp=new_hp, street_event_at=int(time.time()))
        await _edit_text(query,
            "🪓 *Засада за углом!*\n\n"
            "Трое вышли из темноты. Биты, злоба, незачёт за уклонение.\n"
            f"Потерял *{dmg} HP*. ❤️ Осталось: {new_hp}/{char['max_hp']}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏥 Больница", callback_data=f"hospital_{loc_id}")],
                [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            ])
        )

    @staticmethod
    async def rival_snitch(query, user_id, char, loc_id, context):
        current_stars = char.get("wanted_stars", 0) or 0
        new_stars = min(3, current_stars + 1)
        updates = {"street_event_at": int(time.time()), "wanted_stars": new_stars}
        if new_stars == 3:
            jail_until = int(time.time()) + JAIL_DURATION
            updates["jail_until"] = jail_until
            updates["jail_count"] = (char.get("jail_count", 0) or 0) + 1
        await update_character(user_id, **updates)
        stars_str = "⭐" * new_stars
        await _edit_text(query,
            "😤 *Конкурирующая банда!*\n\n"
            "Чужие ребята натравили на тебя копов — старый счёт, видимо.\n"
            f"Уровень розыска: {stars_str}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def fake_deal(query, user_id, char, loc_id, context):
        loss = random.randint(20, 50)
        new_cash = max(0, char["cash"] - loss)
        await update_character(user_id, cash=new_cash, street_event_at=int(time.time()))
        await _edit_text(query,
            "🤡 *Кидалово!*\n\n"
            "Предложили выгодную сделку прямо на улице.\n"
            "Товар оказался мусором. Продавец испарился.\n"
            f"Потерял *{loss}$*. Баланс: {new_cash}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def vandal_attack(query, user_id, char, loc_id, context):
        dmg  = random.randint(10, 30)
        loss = random.randint(10, 25)
        new_hp   = max(1, char["hp"] - dmg)
        new_cash = max(0, char["cash"] - loss)
        await update_character(user_id, hp=new_hp, cash=new_cash,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🧱 *Отморозки!*\n\n"
            "Малолетние придурки кинули кирпич и выхватили немного налички.\n"
            f"−{dmg} HP, −{loss}$\n"
            f"❤️ {new_hp}/{char['max_hp']}  💵 {new_cash}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏥 Больница", callback_data=f"hospital_{loc_id}")],
                [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            ])
        )

    # ── Новые позитивные ────────────────────────────────────────────────

    @staticmethod
    async def found_stash(query, user_id, char, loc_id, context):
        gain = random.randint(50, 120)
        await update_character(user_id, cash=char["cash"] + gain,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "📦 *Схрон!*\n\n"
            "За старым гаражом заметил кирпич не на месте — под ним пакет.\n"
            "_Кто-то надёжно припрятал, да забыл._\n\n"
            f"*+{gain}$!*  Баланс: {char['cash'] + gain}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def rep_bonus(query, user_id, char, loc_id, context):
        gain = random.randint(20, 45)
        await update_character(user_id, cash=char["cash"] + gain,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🏆 *Тебя здесь знают!*\n\n"
            "Местный авторитет кивнул тебе и передал конверт — \"за порядок в районе\".\n\n"
            f"*+{gain}$!*  Баланс: {char['cash'] + gain}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def free_ride(query, user_id, char, loc_id, context):
        mana_gain = 40
        new_mana = min(char["max_mana"], char["mana"] + mana_gain)
        await update_character(user_id, mana=new_mana,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "🚗 *Подвезли!*\n\n"
            "Знакомый на бумере тормознул рядом и закинул куда надо.\n"
            "Сэкономил время и нервы.\n\n"
            f"⚡ *+{mana_gain} энергии!* ({new_mana}/{char['max_mana']})",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def medkit_found(query, user_id, char, loc_id, context):
        await add_item(user_id, "medkit_small")
        await update_character(user_id, street_event_at=int(time.time()))
        await _edit_text(query,
            "🩹 *Аптечка в мусорке!*\n\n"
            "Пустая коробка у аптеки, а внутри — нетронутая малая аптечка.\n"
            "_Медицина для бедных, но сгодится._\n\n"
            "🩹 *+1 малая аптечка* добавлена в инвентарь",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

    @staticmethod
    async def protection_fee(query, user_id, char, loc_id, context):
        gain = random.randint(30, 80)
        await update_character(user_id, cash=char["cash"] + gain,
                               street_event_at=int(time.time()))
        await _edit_text(query,
            "💰 *Дань с торгаша!*\n\n"
            "Ларёчник у перекрёстка сам подошёл и сунул деньги.\n"
            "_Слух о тебе дошёл до нужных людей._\n\n"
            f"*+{gain}$!*  Баланс: {char['cash'] + gain}$",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")
            ]])
        )

async def show_location(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    loc_id = query.data.replace("location_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    now = int(time.time())

    # Случайная встреча — используем хелпер
    context.user_data["last_loc"] = loc_id
    if await try_random_encounter(update, context, loc_id):
        return
    # Уличные случайные события
    if await try_street_event(update, context, loc_id):
        return

    loc = LOCATIONS[loc_id]
    bosses_list = " | ".join(BOSSES[b]["name"] for b in loc["bosses"])

    # Статус контроля района
    ctrl = await get_district_control(loc_id)
    now = time.time()
    if ctrl:
        if ctrl["telegram_id"] == user_id:
            income = DISTRICT_INCOME[loc_id]
            remaining = income["cooldown"] - (now - (ctrl["last_collected"] or 0))
            if remaining <= 0:
                control_line = f"\n\n🏴 *Район твой* — дань готова к сбору!"
            else:
                hrs  = int(remaining // 3600)
                mins = int((remaining % 3600) // 60)
                control_line = f"\n\n🏴 *Район твой* — следующий сбор через {hrs}ч {mins}м"
        else:
            control_line = f"\n\n👑 Контролирует: *{md(ctrl['telegram_name'])}*"
    else:
        main_boss = BOSSES[LOCATION_MAIN_BOSS[loc_id]]
        control_line = f"\n\n⚔️ Район свободен — убей {main_boss['name']} чтобы захватить"

    # Проверка активного рейда
    raid = await get_active_raid(loc_id)
    raid_line = ""
    raid_buttons = []
    if raid:
        time_left = max(0, raid["expires_at"] - int(time.time()))
        tl_min = time_left // 60
        tl_sec = time_left % 60
        raid_line = (
            f"\n\n🚨 *РЕЙД!* {raid['gang_emoji']} *{raid['gang_name']}* атакует район!\n"
            f"⏰ До конца: {tl_min}м {tl_sec}с"
        )
        if ctrl and ctrl["telegram_id"] == user_id:
            hp_bar = "❤️" * min(10, max(1, raid["boss_hp"] * 10 // raid["boss_hp_max"]))
            raid_line += f"\n👊 HP врага: {hp_bar} {raid['boss_hp']}/{raid['boss_hp_max']}"
            raid_buttons = [[InlineKeyboardButton(
                f"⚔️ Защищать район! (ID:{raid['id']})",
                callback_data=f"raid_defend_{raid['id']}"
            )]]

    caption = (
        f"{loc['name']}\n\n_{loc['desc']}_\n\n"
        f"👥 Фигуранты: {bosses_list}"
        f"{control_line}{raid_line}"
    )
    keyboard = InlineKeyboardMarkup([
        *raid_buttons,
        *([[InlineKeyboardButton(
            f"💰 Собрать дань ({DISTRICT_INCOME[loc_id]['cash_min']}–{DISTRICT_INCOME[loc_id]['cash_max']}$)",
            callback_data=f"collect_district_{loc_id}"
        )]] if ctrl and ctrl["telegram_id"] == user_id and (now - (ctrl["last_collected"] or 0)) >= DISTRICT_INCOME[loc_id]["cooldown"] else []),
        *([[InlineKeyboardButton(
            f"🛡️ Охрана района ({len(json.loads(ctrl['guard_json'] or '[]'))} чел.)",
            callback_data=f"district_guard_{loc_id}"
        )]] if ctrl and ctrl["telegram_id"] == user_id else []),
        [InlineKeyboardButton("🔫 Разобраться с кем-нибудь", callback_data=f"hunt_{loc_id}")],
        [InlineKeyboardButton("🕵️ Выследить босса",           callback_data=f"track_{loc_id}")],
        [InlineKeyboardButton(GATHER_ACTIONS[loc_id]["btn"], callback_data=f"gather_{loc_id}")],
        [InlineKeyboardButton(f"🎰 {CASINO_DATA[loc_id]['name']}", callback_data=f"casino_{loc_id}")],
        [InlineKeyboardButton("🏥 Больница",                  callback_data=f"hospital_{loc_id}")],
        [InlineKeyboardButton("⬅️ Назад",                     callback_data="explore")],
    ])

    chat_id = query.message.chat_id

    # Удаляем старое фото района если осталось
    old_photo_id = context.user_data.pop("district_photo_msg_id", None)
    if old_photo_id:
        try:
            await context.bot.delete_message(chat_id=chat_id, message_id=old_photo_id)
        except Exception:
            pass

    photo_path = LOCATION_IMAGES.get(loc_id)
    if photo_path and os.path.exists(photo_path):
        # Удаляем текущее сообщение чтобы фото шло первым
        try:
            await query.message.delete()
        except Exception:
            pass
        # Одно сообщение: фото + подпись + кнопки (фото всегда сверху)
        if loc_id in _photo_cache:
            photo_msg = await context.bot.send_photo(
                chat_id=chat_id, photo=_photo_cache[loc_id],
                caption=caption, parse_mode="Markdown", reply_markup=keyboard
            )
        else:
            with open(photo_path, "rb") as f:
                photo_msg = await context.bot.send_photo(
                    chat_id=chat_id, photo=f,
                    caption=caption, parse_mode="Markdown", reply_markup=keyboard
                )
            _photo_cache[loc_id] = photo_msg.photo[-1].file_id
        context.user_data["district_photo_msg_id"] = photo_msg.message_id
    else:
        # Нет фото — просто редактируем текущее сообщение
        await query.edit_message_text(caption, parse_mode="Markdown", reply_markup=keyboard)

async def gather(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    loc_id = query.data.replace("gather_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    now = int(time.time())

    ga = GATHER_ACTIONS.get(loc_id)
    if not ga:
        await query.answer("Неизвестный район.", show_alert=True)
        return

    cd_key = ga["cooldown_key"]
    last_time = char.get(cd_key) or 0
    elapsed = now - last_time
    cooldown = ga["cooldown"]

    if elapsed < cooldown:
        remaining = cooldown - elapsed
        mins = remaining // 60
        secs = remaining % 60
        await _edit_text(query,
            f"{ga['title']}\n\n"
            f"_{ga['wait_msg']}_\n\n"
            f"⏰ Ещё через: *{mins} мин {secs} сек*",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            ])
        )
        return

    # Расчёт дохода: базовая вилка + бонус за ранг
    lvl = char.get("level", 1)
    bonus = int(lvl * ga["per_level"])
    cash = random.randint(ga["base_min"] + bonus, ga["base_max"] + bonus)

    # Обновляем кулдаун через динамический kwarg
    await update_character(user_id, cash=char["cash"] + cash, **{cd_key: now})

    phrase = random.choice(ga["phrases"])
    rank_bonus_line = f"\n_+{bonus}$ бонус за {lvl} ранг_" if bonus > 0 else ""
    await _edit_text(query,
        f"{ga['title']}\n\n"
        f"_{phrase}_\n\n"
        f"💵 Заработано: *{cash}$*{rank_bonus_line}\n"
        f"Итого: {char['cash'] + cash}$\n\n"
        f"_Следующий раз — через 1 час._",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
        ])
    )


HOSPITAL_DURATION = 30 * 60  # 30 минут в больнице

async def is_in_hospital(char: dict) -> int:
    """Возвращает секунды до выхода из больницы, или 0 если свободен."""
    until = char.get("hospital_until") or 0
    remaining = until - int(time.time())
    return max(0, remaining)

async def leave_hospital_cb(update, context):
    """Выпить секретный отвар — выйти из больницы за 1 кристал."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if char.get("diamonds", 0) < 1:
        await _edit_text(query,
            "💎 *Недостаточно кристаллов*\n\nНужен 1 💎 чтобы выпить секретный отвар.\n\n"
            "_Кристаллы можно купить в разделе 💎 Бриллианты._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("💎 Купить кристаллы", callback_data="diamonds"),
                InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")
            ]])
        )
        return
    await update_character(user_id, diamonds=char["diamonds"] - 1, hospital_until=0)
    await _edit_text(query,
        "🍶 *Секретный отвар выпит!*\n\n"
        "Мутная жидкость мгновенно поставила тебя на ноги.\n"
        "Ты снова в строю — минус 1 💎.",
        parse_mode="Markdown",
        reply_markup=await contacts_kb(user_id)
    )

async def hunt(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    loc_id = query.data.replace("hunt_", "")
    user_id = update.effective_user.id
    existing = await get_battle(user_id)
    if existing:
        await query.answer()
        char = await get_character(user_id)
        boss = BOSSES[existing["boss_id"]]
        inv = await get_inventory(user_id)
        has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
        _opr = await get_property(user_id)
        _pn, _pm = _best_prop_skill(_opr)
        url = build_iso_url(char, existing)
        await _edit_text(query,
            f"⚔️ *Бой ещё не закончен!*\n\n"
            f"Противник: *{boss['name']}* — ❤️ {existing['boss_hp']} HP\n\n"
            f"_Продолжи или брось — третьего не дано._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏳️ Бросить и слинять", callback_data="abandon_battle")]
            ])
        )
        await context.bot.send_message(
            chat_id=update.effective_chat.id,
            text="👇",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("⚔️ Продолжить бой", web_app=WebAppInfo(url=url))]],
                resize_keyboard=True, one_time_keyboard=True
            )
        )
        return
    char = await get_character(user_id)
    now_ts = int(time.time())
    # Проверка: игрок в больнице
    hosp_left = await is_in_hospital(char)
    if hosp_left > 0:
        hosp_min = hosp_left // 60
        hosp_sec = hosp_left % 60
        await query.answer()
        await _edit_text(query,
            f"🏥 *Ты в больнице*\n\n"
            f"Тебя подлатали после последнего боя. Нельзя драться ещё *{hosp_min}м {hosp_sec}с*.\n\n"
            f"💎 Выпить секретный отвар — выйти прямо сейчас за *1 кристалл*.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🍶 Выпить отвар (1 💎)", callback_data="leave_hospital")],
                [InlineKeyboardButton("⬅️ Назад", callback_data=f"location_{loc_id}")],
            ])
        )
        return
    last_hunt = char.get("last_hunt") or 0
    cooldown_left = HUNT_COOLDOWN - (now_ts - last_hunt)
    if cooldown_left > 0:
        mins = int(cooldown_left // 60)
        secs = int(cooldown_left % 60)
        await query.answer(
            f"🩹 Залечиваешь раны... Следующий бой через {mins}м {secs}с",
            show_alert=True
        )
        return
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    boss_id = random.choice(LOCATIONS[loc_id]["bosses"])
    # Сохраняем состояние подготовки (boss выбран, но бой ещё не создан)
    context.user_data["hunt_prep"] = {"loc_id": loc_id, "boss_id": boss_id, "party": []}
    await _show_hunt_prep(query, context, user_id)

# ============================================================
# ПОДГОТОВКА К БОЮ (выбор отряда)
# ============================================================

async def _show_hunt_prep(query, context, user_id: int):
    """Отображает экран подготовки к бою: выбор отряда перед стартом."""
    prep  = context.user_data.get("hunt_prep", {})
    loc_id  = prep.get("loc_id", "market")
    boss_id = prep.get("boss_id", "kosoy")
    party   = prep.get("party", [])
    boss    = BOSSES[boss_id]

    gang    = await get_gang(user_id)
    mercs   = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    # Только друзья из банды (пришли по реф-ссылке)
    friends = await get_friends(user_id)

    party_lines = ""
    if party:
        party_lines = "\n\n👥 *Отряд:*\n"
        for p in party:
            if p["type"] == "mercenary":
                party_lines += f"🔫 {p['name']} ❤️{p.get('hp', '?')}\n"
            else:
                status = "⏳ ждёт" if p.get("pending") else "✅ готов"
                party_lines += f"👤 {p['name']} — {status}\n"

    rows = []
    mercs_in_party = [p for p in party if p["type"] == "mercenary"]
    if mercs and not mercs_in_party:
        on_guard_ids = await get_guard_member_ids(user_id)
        guarding = sum(1 for m in mercs if m["id"] in on_guard_ids)
        free     = len(mercs) - guarding
        if free > 0:
            label = f"🔫 Взять наёмников ({free})"
            if guarding:
                label += f" | 🛡 {guarding} на охране"
        else:
            label = f"🛡 Все наёмники на охране района ({guarding})"
        rows.append([InlineKeyboardButton(label, callback_data="hunt_add_mercs")])

    # Кнопка «папка друзей» если есть хоть один друг
    invited_ids = {p["telegram_id"] for p in party if p["type"] == "friend"}
    pending_ids = {p["telegram_id"] for p in party if p["type"] == "friend" and p.get("pending")}
    if friends:
        pending_count = len(pending_ids)
        if pending_count:
            rows.append([InlineKeyboardButton(
                f"👥 Друзья из банды ({len(friends)}) — ⏳ ждём ответа...",
                callback_data="hunt_friends_list"
            )])
        else:
            rows.append([InlineKeyboardButton(
                f"👥 Позвать друзей из банды ({len(friends)})",
                callback_data="hunt_friends_list"
            )])

    rows.append([InlineKeyboardButton("⚔️ Начать бой!", callback_data="hunt_start")])
    rows.append([InlineKeyboardButton("⬅️ Отмена",      callback_data=f"location_{loc_id}")])

    await _edit_text(query,
        f"💥 *Встречает: {boss['name']}*\n"
        f"_{boss['title']}_\n"
        f"«_{boss['quote']}_»\n\n"
        f"❤️ {boss['hp']} HP | ⚔️ {boss['attack']} | 🛡 {boss['defense']}"
        f"{party_lines}\n\n"
        f"_Возьмёшь кого-нибудь с собой?_",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )



async def hunt_friends_list(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Экран выбора друга для совместного боя — все друзья из банды."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    prep    = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели. Зайди в район снова.", show_alert=True); return

    friends = await get_friends(user_id)
    if not friends:
        await query.answer("В твоей банде пока нет игроков.", show_alert=True); return

    party      = prep.get("party", [])
    invited_ids = {p["telegram_id"] for p in party if p["type"] == "friend"}
    pending_ids = {p["telegram_id"] for p in party if p["type"] == "friend" and p.get("pending")}
    boss    = BOSSES.get(prep.get("boss_id", "kosoy"), BOSSES["kosoy"])
    loc_id  = prep.get("loc_id", "market")
    max_friends = 4
    slots_left  = max_friends - len(invited_ids)

    rows = []
    if slots_left == 0 and not pending_ids:
        rows.append([InlineKeyboardButton("✅ Все 4 места заняты", callback_data="gang_nocollect")])
    for f in friends:
        if f["telegram_id"] in pending_ids:
            rows.append([InlineKeyboardButton(
                f"⏳ {f['name']} (ур.{f['level']}) — ожидает ответа...",
                callback_data="gang_nocollect"
            )])
        elif f["telegram_id"] in invited_ids:
            rows.append([InlineKeyboardButton(
                f"✅ {f['name']} (ур.{f['level']}) — принял",
                callback_data="gang_nocollect"
            )])
        elif slots_left > 0:
            rows.append([InlineKeyboardButton(
                f"📨 Позвать {f['name']} (ур.{f['level']}) в бой",
                callback_data=f"hunt_invite_friend_{f['telegram_id']}"
            )])
        else:
            rows.append([InlineKeyboardButton(
                f"🔒 {f['name']} (мест нет)",
                callback_data="gang_nocollect"
            )])

    # Берём актуальные данные сессии из БД
    live_session = await get_pending_coop_by_host(user_id)
    live_players = live_session["players"] if live_session else []
    accepted_live = [p for p in live_players if p.get("accepted") and p["uid"] != user_id]
    pending_live  = [p for p in live_players if not p.get("accepted")]
    total_in_session = len(live_players)  # включая хоста
    slots_available = 4 - total_in_session

    # Строки статуса
    status_lines = []
    if accepted_live:
        status_lines.append("✅ Зашли: " + ", ".join(p["name"] for p in accepted_live))
    if pending_live:
        status_lines.append("⏳ Ожидают: " + ", ".join(p["name"] for p in pending_live))
    status_block = ("\n" + "\n".join(status_lines) + "\n") if status_lines else ""

    slots_bar = "🟢" * total_in_session + "⬜" * max(0, 4 - total_in_session)

    # Кнопка «Стартовать» — если есть хоть один принятый (помимо хоста)
    if accepted_live and live_session:
        rows.insert(0, [InlineKeyboardButton(
            f"🚀 Стартовать бой ({total_in_session} игрок(ов))",
            callback_data=f"hunt_start_now_{live_session['id']}"
        )])
    rows.append([InlineKeyboardButton("⬅️ Назад к подготовке", callback_data="hunt_back_prep")])

    text = (
        "👥 *Друзья из банды*\n\n"
        f"Враг: *{boss['name']}* — ❤️ {boss['hp']} HP\n\n"
        f"Сессия: {slots_bar} {total_in_session}/4 игроков{status_block}\n"
        f"Свободных мест: *{slots_available}*\n\n"
        "Нажми на друга чтобы пригласить:"
    )
    await _edit_text(query,
        text, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )


async def hunt_back_prep(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Возврат к экрану подготовки к бою."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    await _show_hunt_prep(query, context, user_id)

async def hunt_add_mercs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Экран выбора наёмников — каждого добавляешь сам."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    prep    = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели. Зайди в район снова.", show_alert=True); return
    await _show_merc_select(query, context, user_id)


async def _show_merc_select(query, context, user_id: int):
    """Показывает экран выбора наёмников с фильтром свободные/все."""
    prep       = context.user_data.get("hunt_prep", {})
    gang       = await get_gang(user_id)
    mercs      = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    on_guard   = await get_guard_member_ids(user_id)
    char       = await get_character(user_id)
    in_party   = {p["gang_id"] for p in prep.get("party", []) if p.get("type") == "mercenary"}
    # Режим фильтра: "free" — только свободные, "all" — все
    show_all   = context.user_data.get("hunt_merc_filter", "free") == "all"

    free_mercs  = [m for m in mercs if m["id"] not in on_guard]
    guard_mercs = [m for m in mercs if m["id"] in on_guard]

    def merc_row(m):
        ri     = GANG_ROLES[m["role"]]
        cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
        max_hp = cls["hp_base"] + char["level"] * cls["hp_per_lvl"]
        cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
        cur_hp = max(0, min(cur_hp, max_hp))
        hp_pct = int(cur_hp / max_hp * 100) if max_hp else 0
        if m["id"] in in_party:
            label = f"✅ {ri['emoji']} {m['member_name']} ({ri['title']}) HP:{hp_pct}%"
        else:
            label = f"☐ {ri['emoji']} {m['member_name']} ({ri['title']}) HP:{hp_pct}%"
        return [InlineKeyboardButton(label, callback_data=f"hunt_merc_toggle_{m['id']}")]

    rows = []

    # ── Кнопка переключения фильтра ──────────────────────────────
    if show_all:
        rows.append([InlineKeyboardButton(
            f"👁 Показать только свободных ({len(free_mercs)})",
            callback_data="hunt_merc_filter_free"
        )])
    else:
        rows.append([InlineKeyboardButton(
            f"👁 Показать всех ({len(mercs)}) включая охрану",
            callback_data="hunt_merc_filter_all"
        )])

    # ── Свободные бойцы ──────────────────────────────────────────
    if free_mercs:
        for m in free_mercs:
            rows.append(merc_row(m))
    else:
        rows.append([InlineKeyboardButton("— Свободных нет —", callback_data="gang_nocollect")])

    # ── Охранники (только в режиме "все") ────────────────────────
    if show_all and guard_mercs:
        rows.append([InlineKeyboardButton(
            f"── 🔒 На охране района ({len(guard_mercs)}) ──",
            callback_data="gang_nocollect"
        )])
        for m in guard_mercs:
            ri    = GANG_ROLES[m["role"]]
            label = f"🔒 {ri['emoji']} {m['member_name']} ({ri['title']}) — на охране"
            rows.append([InlineKeyboardButton(label, callback_data="hunt_merc_guard_hint")])

    selected_count = len(in_party)
    rows.append([InlineKeyboardButton(
        f"✅ Подтвердить ({selected_count} выбрано)" if selected_count else "⬅️ Назад без наёмников",
        callback_data="hunt_back_prep"
    )])

    guard_note = f" | 🔒 на охране: {len(guard_mercs)}" if guard_mercs else ""
    mode_label = "все" if show_all else "свободные"
    await _edit_text(query,
        f"🔫 *Выбор наёмников* (показаны: {mode_label})\n\n"
        f"Свободных: *{len(free_mercs)}*{guard_note}\n"
        f"Выбрано в отряд: *{selected_count}*\n\n"
        f"Нажми на бойца чтобы взять/убрать.\n"
        f"🔒 — на охране района, сначала сними в меню.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )


async def hunt_merc_toggle(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Добавляет или убирает наёмника из отряда."""
    query   = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    member_id = int(query.data.replace("hunt_merc_toggle_", ""))
    prep      = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели.", show_alert=True); return

    party = prep.get("party", [])
    already = next((i for i, p in enumerate(party) if p.get("type") == "mercenary" and p.get("gang_id") == member_id), None)

    if already is not None:
        party.pop(already)
    else:
        gang = await get_gang(user_id)
        char = await get_character(user_id)
        m    = next((x for x in gang if x["id"] == member_id), None)
        if not m:
            await query.answer("Боец не найден.", show_alert=True); return
        on_guard = await get_guard_member_ids(user_id)
        if member_id in on_guard:
            await query.answer("🔒 Сначала сними с охраны района!", show_alert=True); return
        cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
        max_hp = cls["hp_base"] + char["level"] * cls["hp_per_lvl"]
        cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
        cur_hp = max(1, min(cur_hp, max_hp))
        party.append({
            "type":    "mercenary",
            "gang_id": m["id"],
            "name":    m["member_name"],
            "role":    m["role"],
            "hp":      cur_hp,
            "max_hp":  max_hp,
            "alive":   True,
        })

    prep["party"] = party
    context.user_data["hunt_prep"] = prep
    await _show_merc_select(query, context, user_id)


async def hunt_merc_filter(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Переключает фильтр отображения наёмников (свободные / все)."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    mode    = "all" if "filter_all" in query.data else "free"
    context.user_data["hunt_merc_filter"] = mode
    await _show_merc_select(query, context, user_id)


async def hunt_add_friend(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Добавляет одного друга из банды в отряд."""
    query   = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    friend_id = int(query.data.replace("hunt_add_friend_", ""))
    prep      = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели. Зайди в район снова.", show_alert=True); return

    # Проверяем что друг действительно в банде (реф-ссылка)
    friends = await get_friends(user_id)
    friend  = next((f for f in friends if f["telegram_id"] == friend_id), None)
    if not friend:
        await query.answer("Этот игрок не в твоей банде.", show_alert=True); return

    # Получаем реальный персонаж друга для расчёта урона
    friend_char = await get_character(friend_id)
    if not friend_char:
        await query.answer("Персонаж друга не найден.", show_alert=True); return

    prep["party"].append({
        "type":        "friend",
        "telegram_id": friend_id,
        "name":        friend_char["name"][:14],
        "hp":          friend_char["hp"],
        "max_hp":      friend_char["max_hp"],
        "attack":      get_effective_attack(friend_char),
        "defense":     get_effective_defense(friend_char),
        "alive":       True,
    })
    context.user_data["hunt_prep"] = prep
    await _show_hunt_prep(query, context, user_id)


# ═══════════════════════════════════════════════════════════════════════
#  CO-OP BATTLE SYSTEM — приглашение друга в совместный бой
# ═══════════════════════════════════════════════════════════════════════

async def _coop_boss_for_session(session: dict) -> dict:
    """Возвращает словарь-босс для co-op сессии."""
    boss_id = session["boss_id"]
    if boss_id == "raid_boss":
        return {
            "name": "🔴 Вражеская банда", "title": "Рейд", "quote": "",
            "hp": session["boss_max_hp"], "attack": 35, "defense": 15,
            "exp": 80, "cash": 300, "drop": None,
        }
    return BOSSES.get(boss_id, BOSSES["kosoy"])


async def _send_coop_turn(bot, session: dict):
    """Отправляет сообщение «Твой ход» нужному игроку."""
    session_id = session["id"]
    boss_hp    = session["boss_hp"]
    boss       = await _coop_boss_for_session(session)
    player_id  = session["host_id"] if session["current_turn"] == 0 else session["partner_id"]
    char       = await get_character(player_id)

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("⚔️ Атаковать (-5⚡)",   callback_data=f"coop_atk_{session_id}"),
         InlineKeyboardButton("💥 Приём (-15⚡)",       callback_data=f"coop_skill_{session_id}")],
        [InlineKeyboardButton("🩹 Аптечка",             callback_data=f"coop_pot_{session_id}"),
         InlineKeyboardButton("🏃 Сбежать",             callback_data=f"coop_flee_{session_id}")],
    ])
    turn_label = "🟢 Твой ход!" if session["current_turn"] == 0 else "🔵 Твой ход!"
    await bot.send_message(
        chat_id=player_id,
        text=f"{turn_label}\n\n"
             f"👊 *{boss['name']}* — ❤️ {boss_hp}/{session['boss_max_hp']} HP\n"
             f"❤️ Твоё HP: *{char['hp']}/{char['max_hp']}* | ⚡ {char['mana']}/{char['max_mana']}",
        parse_mode="Markdown",
        reply_markup=kb
    )


async def hunt_invite_friend(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игрок зовёт друга в совместный бой (обычная охота)."""
    query     = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    friend_id = int(query.data.replace("hunt_invite_friend_", ""))
    prep      = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели. Зайди в район снова.", show_alert=True); return

    friends = await get_friends(user_id)
    friend  = next((f for f in friends if f["telegram_id"] == friend_id), None)
    if not friend:
        await query.answer("Этот игрок не в твоей банде.", show_alert=True); return

    char    = await get_character(user_id)
    boss_id = prep.get("boss_id", "kosoy")
    boss    = BOSSES.get(boss_id, BOSSES["kosoy"])

    # Отмечаем как «отправлено приглашение»
    invited_count = sum(1 for p in prep["party"] if p["type"] == "friend")
    if invited_count >= 4:
        await query.answer("❌ Максимум 4 друга в бою!", show_alert=True); return
    if not any(p["telegram_id"] == friend_id for p in prep["party"] if p["type"] == "friend"):
        prep["party"].append({"type": "friend", "telegram_id": friend_id,
                               "name": friend["name"], "pending": True})
    context.user_data["hunt_prep"] = prep

    # Ищем существующую сессию от этого хоста (или создаём новую)
    existing = await get_pending_coop_by_host(user_id)
    if existing and existing["boss_id"] == boss_id:
        session_id = existing["id"]
        players = existing["players"]
        # Проверяем лимит
        if len(players) >= 4:
            await query.answer("❌ Максимум 4 игрока в бою!", show_alert=True); return
        if any(p["uid"] == friend_id for p in players):
            await query.answer("Этот игрок уже приглашён.", show_alert=True); return
        pnum = len(players) + 1
        players.append({"uid": friend_id, "pnum": pnum, "name": friend["name"], "accepted": False})
        await update_coop_session(session_id, players_json=json.dumps(players, ensure_ascii=False))
    else:
        # Создаём новую сессию
        await cancel_old_coop_invites(user_id)
        session_id = await create_coop_session(
            host_id=user_id, partner_id=friend_id,
            boss_id=boss_id,
            boss_hp=boss["hp"], boss_max_hp=boss["hp"],
            location=prep.get("loc_id", "market"),
            party=[]
        )
        players = [
            {"uid": user_id,   "pnum": 1, "name": char["name"],   "accepted": True},
            {"uid": friend_id, "pnum": 2, "name": friend["name"], "accepted": False},
        ]
        await update_coop_session(session_id, players_json=json.dumps(players, ensure_ascii=False))

    context.user_data[f"pending_coop_{friend_id}"] = session_id

    try:
        accepted_names = [p["name"] for p in players if p["accepted"] and p["uid"] != user_id]
        others_line = f"\n👥 Уже в сессии: {', '.join(p['name'] for p in players if p['uid'] != user_id and p['uid'] != friend_id)}" if len(players) > 2 else ""
        await context.bot.send_message(
            chat_id=friend_id,
            text=f"⚔️ *{md(char['name'])}* зовёт тебя в совместный бой!\n\n"
                 f"Враг: *{boss['name']}* — ❤️ {boss['hp']} HP | ⚔️ {boss['attack']}\n"
                 f"Игроков в сессии: {len(players)}/4{others_line}\n\n"
                 f"Принять приглашение?",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("✅ Принять", callback_data=f"coop_accept_{session_id}"),
                 InlineKeyboardButton("❌ Отказать", callback_data=f"coop_decline_{session_id}")],
            ])
        )
    except Exception:
        await query.answer("Не удалось отправить приглашение другу.", show_alert=True)
        return

    # Планируем автостарт через 60 секунд (asyncio task — без APScheduler)
    old_task = _coop_auto_tasks.pop(session_id, None)
    if old_task and not old_task.done():
        old_task.cancel()
    task = asyncio.create_task(
        _coop_auto_start_task(session_id, user_id, prep, context.bot)
    )
    _coop_auto_tasks[session_id] = task
    context.user_data["coop_auto_start_sid"] = session_id

    invited_names   = [p["name"] for p in players if p["uid"] != user_id]
    accepted_names  = [p["name"] for p in players if p.get("accepted") and p["uid"] != user_id]
    accepted_line   = ("✅ Уже в бою: " + ", ".join(accepted_names) + "\n") if accepted_names else ""
    await _edit_text(query,
        f"✅ *Приглашение отправлено {md(friend['name'])}!*\n\n"
        f"👥 Приглашены: {', '.join(invited_names)}\n"
        f"{accepted_line}\n"
        f"⏳ Бой автоматически начнётся через *{COOP_WAIT_SECONDS} сек.*\n"
        f"Кто не успел принять — не войдёт в бой.\n\n"
        f"Или нажми «Стартовать» прямо сейчас:",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"🚀 Стартовать бой", callback_data=f"hunt_start_now_{session_id}")],
            [InlineKeyboardButton("👥 Список игроков / позвать ещё", callback_data="hunt_friends_list")],
            [InlineKeyboardButton("❌ Отменить бой", callback_data=f"coop_cancel_auto_{session_id}")],
        ])
    )


async def raid_invite_friend(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игрок зовёт друга в совместную защиту рейда."""
    query     = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    friend_id = int(query.data.replace("raid_invite_friend_", ""))
    prep      = context.user_data.get("raid_prep")
    if not prep:
        await query.answer("Данные устарели.", show_alert=True); return

    raid = await get_raid_by_id(prep["raid_id"])
    if not raid or raid["status"] != "active":
        await query.answer("Рейд уже завершён.", show_alert=True); return

    friends = await get_friends(user_id)
    friend  = next((f for f in friends if f["telegram_id"] == friend_id), None)
    if not friend:
        await query.answer("Этот игрок не в твоей банде.", show_alert=True); return

    char = await get_character(user_id)

    if not any(p["telegram_id"] == friend_id for p in prep["party"] if p["type"] == "friend"):
        prep["party"].append({"type": "friend", "telegram_id": friend_id,
                               "name": friend["name"], "pending": True})
    context.user_data["raid_prep"] = prep

    await cancel_old_coop_invites(user_id)
    session_id = await create_coop_session(
        host_id=user_id, partner_id=friend_id,
        boss_id="raid_boss",
        boss_hp=raid["boss_hp"], boss_max_hp=raid["boss_hp_max"],
        location=f"raid_{raid['id']}",
        party=[]
    )
    context.user_data[f"pending_coop_{friend_id}"] = session_id

    try:
        await context.bot.send_message(
            chat_id=friend_id,
            text=f"🚨 *{md(char['name'])}* зовёт тебя защищать район от рейда!\n\n"
                 f"{raid['gang_emoji']} *{raid['gang_name']}* атакует!\n"
                 f"❤️ {raid['boss_hp']} HP | ⚔️ {raid['boss_atk']} | 🛡 {raid['boss_def']}\n\n"
                 f"Принять участие?",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("✅ Принять", callback_data=f"coop_accept_{session_id}"),
                 InlineKeyboardButton("❌ Отказать", callback_data=f"coop_decline_{session_id}")],
            ])
        )
    except Exception:
        await query.answer("Не удалось отправить приглашение другу.", show_alert=True)
        return

    await _edit_text(query,
        f"✅ Приглашение отправлено *{md(friend['name'])}*!\n\nОжидаем ответ...\n\n"
        f"_Можешь отменить и пригласить другого._",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([[
            InlineKeyboardButton("❌ Отменить приглашение", callback_data=f"coop_cancel_{session_id}")
        ]])
    )


async def coop_accept(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Друг принимает приглашение в совместный бой."""
    query      = update.callback_query
    await query.answer("✅ Ты принял приглашение!")
    user_id    = update.effective_user.id
    session_id = int(query.data.replace("coop_accept_", ""))
    session    = await get_coop_session(session_id)

    if not session:
        await _edit_text(query,"⚠️ Приглашение не найдено.")
        return
    if session["status"] not in ("pending", "active"):
        await _edit_text(query,"⚠️ Приглашение уже недействительно.")
        return

    # Проверяем что игрок в списке (partner_id или players_json)
    players = json.loads(session.get("players_json") or "[]")
    in_players_json = any(p["uid"] == user_id for p in players)
    if session["partner_id"] != user_id and not in_players_json:
        await query.answer("Это приглашение не для тебя.", show_alert=True); return

    # Обновляем players_json — ставим accepted=True для этого игрока
    for p in players:
        if p["uid"] == user_id:
            p["accepted"] = True
    accepted_count = sum(1 for p in players if p["accepted"])
    total_count    = len(players)
    await update_coop_session(session_id, status="active", current_turn=0,
                               players_json=json.dumps(players, ensure_ascii=False))

    # Уведомляем хоста
    host_char    = await get_character(session["host_id"])
    partner_char = await get_character(user_id)
    boss         = await _coop_boss_for_session(session)
    pending_names = [p["name"] for p in players if not p["accepted"]]
    try:
        await context.bot.send_message(
            chat_id=session["host_id"],
            text=f"✅ *{md(partner_char['name'])}* принял приглашение! "
                 f"({accepted_count}/{total_count} готовы)\n\n"
                 + (f"⏳ Ещё ждём: {', '.join(pending_names)}\n\n" if pending_names else "")
                 + "Нажми «В бой!» когда готовы!",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("⚔️ В бой!", callback_data="hunt_start")
            ]])
        )
    except Exception:
        pass

    accepted_names = [p["name"] for p in players if p["accepted"] and p["uid"] != user_id]
    await _edit_text(query,
        f"✅ Ты принял вызов!\n\n"
        f"⚔️ Бой против *{boss['name']}* — ❤️ {session['boss_hp']} HP\n"
        f"👥 Команда: {', '.join(p['name'] for p in players)}\n\n"
        f"Ждём пока *{md(host_char['name'])}* начнёт бой...",
        parse_mode="Markdown"
    )
    # Open hub in waitroom mode for the joining player
    try:
        hub_wait_url = await build_hub_url_coop(user_id, session, "waiting")
        await context.bot.send_message(
            chat_id=user_id,
            text=f"🕐 Ты в лобби! Нажми *Готов* когда будешь готов к бою.",
            parse_mode="Markdown",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("🕐 Лобби", web_app=WebAppInfo(url=hub_wait_url))]],
                resize_keyboard=True, one_time_keyboard=True
            )
        )
    except Exception as _e:
        logger.warning("coop_accept hub send failed: %s", _e)


async def coop_decline(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Друг отклоняет приглашение."""
    query      = update.callback_query
    await query.answer("❌ Отказался")
    user_id    = update.effective_user.id
    session_id = int(query.data.replace("coop_decline_", ""))
    session    = await get_coop_session(session_id)

    if not session:
        await _edit_text(query,"Сессия не найдена.")
        return
    if session["partner_id"] != user_id:
        await query.answer("Это приглашение не для тебя.", show_alert=True); return

    await close_coop_session(session_id, "declined")

    partner_char = await get_character(user_id)
    try:
        await context.bot.send_message(
            chat_id=session["host_id"],
            text=f"❌ *{md(partner_char['name'])}* отказался от совместного боя.\n"
                 f"Можешь начать бой в одиночку.",
            parse_mode="Markdown"
        )
    except Exception:
        pass

    await _edit_text(query,"❌ Ты отказался от участия в бою.")


async def _process_coop_turn(update_or_query, context, session_id: int,
                              action: str, extra_data: dict = None):
    """Обрабатывает один ход в co-op бою."""
    query   = update_or_query.callback_query if hasattr(update_or_query, "callback_query") else update_or_query
    user_id = query.from_user.id
    session = await get_coop_session(session_id)
    if not session or session["status"] != "active":
        await query.answer("Бой уже завершён.", show_alert=True)
        await _edit_text(query, "🏆 Бой завершён!",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
            ]]))
        return

    # Проверяем что ход принадлежит этому игроку
    expected = session["host_id"] if session["current_turn"] == 0 else session["partner_id"]
    if user_id != expected:
        await query.answer("Сейчас не твой ход!", show_alert=True); return

    char    = await get_character(user_id)
    boss    = await _coop_boss_for_session(session)
    boss_hp = session["boss_hp"]
    char_hp = char["hp"]
    char_mana = char["mana"]
    result_lines = []

    if action == "attack":
        cost = 5
        if char_mana < cost:
            await query.answer("❌ Нет энергии!", show_alert=True); return
        dmg = calc_damage(get_effective_attack(char), boss["defense"])
        boss_hp -= dmg
        char_mana -= cost
        result_lines.append(f"⚔️ *{md(char['name'])}* атакует: *{dmg} урона!*")

    elif action == "skill":
        skill = SKILLS[char["class"]]
        if char_mana < skill["mana_cost"]:
            await query.answer("❌ Мало энергии!", show_alert=True); return
        dmg = calc_damage(get_effective_attack(char), boss["defense"], skill["damage_mult"])
        boss_hp -= dmg
        char_mana -= skill["mana_cost"]
        result_lines.append(f"💥 *{skill['name']}* — *{dmg} урона!*")
        if "heal" in skill:
            char_hp = min(char["max_hp"], char_hp + skill["heal"])
            result_lines.append(f"💚 +{skill['heal']} HP")

    elif action == "potion":
        inv = await get_inventory(user_id)
        pot = next((i for i, q in inv.items()
                    if ITEMS.get(i, {}).get("type") == "potion" and q > 0), None)
        if not pot:
            await query.answer("❌ Аптечек нет!", show_alert=True); return
        await remove_item(user_id, pot)
        item = ITEMS[pot]
        if "heal" in item:
            char_hp = min(char["max_hp"], char_hp + item["heal"])
            result_lines.append(f"🩹 +{item['heal']} HP")
        elif "mana" in item:
            char_mana = min(char["max_mana"], char_mana + item["mana"])
            result_lines.append(f"⚡ +{item['mana']} энергии")

    elif action == "flee":
        if random.random() < 0.5:
            await close_coop_session(session_id, "fled")
            await update_character(user_id, hp=char_hp, mana=char_mana)
            await _edit_text(query,f"🏃 *{md(char['name'])}* покинул бой.")
            other_id = session["partner_id"] if user_id == session["host_id"] else session["host_id"]
            try:
                await context.bot.send_message(
                    chat_id=other_id,
                    text=f"🏃 *{md(char['name'])}* сбежал — совместный бой завершён.",
                    parse_mode="Markdown"
                )
            except Exception: pass
            return
        else:
            result_lines.append("❌ Не дали уйти!")

    await update_character(user_id, hp=char_hp, mana=char_mana)

    # ── Победа — оба получают награду (даже если один наблюдал) ────────
    if boss_hp <= 0:
        await close_coop_session(session_id, "won")
        reward_cash = boss.get("cash", 200)
        reward_exp  = boss.get("exp",  50)
        for pid in [session["host_id"], session["partner_id"]]:
            pc = await get_character(pid)
            await update_character(pid, cash=pc["cash"] + reward_cash,
                                   exp=pc["exp"] + reward_exp, kills=pc["kills"] + 1)
        win_text = (
            "\n".join(result_lines) + "\n\n"
            f"🏆 *Победа!* *{boss['name']}* уничтожен!\n"
            f"💵 +${reward_cash} | ⭐ +{reward_exp} опыта"
        )
        other_id = session["partner_id"] if user_id == session["host_id"] else session["host_id"]
        menu_kb = InlineKeyboardMarkup([[
            InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
        ]])
        await _edit_text(query, win_text, parse_mode="Markdown", reply_markup=menu_kb)
        try:
            await context.bot.send_message(
                chat_id=other_id, text=win_text, parse_mode="Markdown",
                reply_markup=menu_kb
            )
        except Exception:
            pass
        await context.bot.send_message(
            chat_id=user_id, text="В меню:", reply_markup=await contacts_kb(user_id)
        )
        return

    # ── Ход босса (после хода партнёра — последнего в паре) ─────────────
    session_upd = await get_coop_session(session_id)
    next_turn   = 1 - session["current_turn"]  # 0→1, 1→0

    if session["current_turn"] == 1:
        # После хода партнёра — босс атакует живого игрока
        host_alive    = session.get("host_alive", 1)
        partner_alive = session.get("partner_alive", 1)
        alive_targets = []
        if host_alive:    alive_targets.append(session["host_id"])
        if partner_alive: alive_targets.append(session["partner_id"])
        boss_dmg_target = random.choice(alive_targets) if alive_targets else session["host_id"]

        target_char  = await get_character(boss_dmg_target)
        raw_boss_dmg = random.randint(boss["attack"] - 5, boss["attack"] + 5)
        actual_dmg   = max(1, raw_boss_dmg - get_effective_defense(target_char))
        new_hp       = max(0, target_char["hp"] - actual_dmg)
        await update_character(boss_dmg_target, hp=new_hp)
        target_name  = target_char["name"]
        result_lines.append(f"\n👊 *{boss['name']}* бьёт *{md(target_name)}*: {actual_dmg} урона!")

        # Проверяем смерть
        if new_hp <= 0:
            is_host = (boss_dmg_target == session["host_id"])
            if is_host:
                host_alive = 0
                await update_coop_session(session_id, host_alive=0)
            else:
                partner_alive = 0
                await update_coop_session(session_id, partner_alive=0)

            dead_id    = boss_dmg_target
            other_id   = session["partner_id"] if is_host else session["host_id"]
            other_alive = partner_alive if is_host else host_alive

            # Сообщаем погибшему — он наблюдатель
            dead_text = (
                "\n".join(result_lines) +
                f"\n\n💀 *{md(target_name)}* выбыл из боя!\n"
                "_Наблюдай — если друг победит, вы оба получите награду._"
            )
            try:
                await context.bot.send_message(
                    chat_id=dead_id, text=dead_text, parse_mode="Markdown"
                )
            except Exception: pass

            if not other_alive:
                # Оба мертвы — проигрыш
                await close_coop_session(session_id, "lost")
                lose_text = "\n".join(result_lines) + "\n\n💀 Оба выбыли. Бой проигран."
                menu_kb = InlineKeyboardMarkup([[
                    InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
                ]])
                await _edit_text(query, lose_text, parse_mode="Markdown", reply_markup=menu_kb)
                try:
                    await context.bot.send_message(
                        chat_id=other_id, text=lose_text, parse_mode="Markdown",
                        reply_markup=menu_kb
                    )
                except Exception:
                    pass
                await context.bot.send_message(
                    chat_id=user_id, text="В меню:", reply_markup=await contacts_kb(user_id)
                )
                return
            # Иначе — живой продолжает, не прерываемся

    # Определяем следующий ход — пропускаем мёртвых
    sess_now = await get_coop_session(session_id)
    h_alive  = sess_now.get("host_alive", 1) if sess_now else 1
    p_alive  = sess_now.get("partner_alive", 1) if sess_now else 1
    if h_alive and p_alive:
        next_turn = 1 - session["current_turn"]
    elif h_alive:
        next_turn = 0   # только хост жив
    else:
        next_turn = 1   # только партнёр жив

    # Обновляем сессию
    await update_coop_session(session_id, boss_hp=max(0, boss_hp), current_turn=next_turn)
    session = await get_coop_session(session_id)

    # Показываем результат текущему игроку
    await _edit_text(query,
        "\n".join(result_lines) + f"\n\n❤️ Враг: {boss_hp}/{session['boss_max_hp']} HP",
        parse_mode="Markdown"
    )

    # Передаём ход следующему
    await _send_coop_turn(context.bot, session)


async def coop_attack(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sid = int(query.data.replace("coop_atk_", ""))
    await _process_coop_turn(query, context, sid, "attack")

async def coop_skill(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sid = int(query.data.replace("coop_skill_", ""))
    await _process_coop_turn(query, context, sid, "skill")

async def coop_potion(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sid = int(query.data.replace("coop_pot_", ""))
    await _process_coop_turn(query, context, sid, "potion")

async def coop_flee_action(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sid = int(query.data.replace("coop_flee_", ""))
    await _process_coop_turn(query, context, sid, "flee")



async def coop_cancel_invite(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Хост отменяет отправленное приглашение и возвращается к подготовке."""
    query      = update.callback_query
    await query.answer("Приглашение отменено.")
    user_id    = update.effective_user.id

    try:
        session_id = int(query.data.replace("coop_cancel_", ""))
    except (ValueError, AttributeError):
        session_id = None

    session = await get_coop_session(session_id) if session_id else None

    if session and session["status"] in ("pending", "active"):
        # Отменяем asyncio-задачу автостарта если есть
        old_task = _coop_auto_tasks.pop(session_id, None)
        if old_task and not old_task.done():
            old_task.cancel()
        await close_coop_session(session_id, "cancelled")
        # Убираем этого друга из party (он не принял)
        prep = context.user_data.get("hunt_prep") or context.user_data.get("raid_prep")
        if prep:
            partner_id = session["partner_id"]
            prep["party"] = [p for p in prep.get("party", [])
                              if not (p["type"] == "friend" and p["telegram_id"] == partner_id)]
            if "hunt_prep" in context.user_data:
                context.user_data["hunt_prep"] = prep
            else:
                context.user_data["raid_prep"] = prep
        # Уведомляем друга
        try:
            await context.bot.send_message(
                chat_id=session["partner_id"],
                text="❌ Приглашение в совместный бой было отозвано."
            )
        except Exception:
            pass

    # Возвращаемся к подготовке
    loc_id = session["location"] if session else None
    try:
        if loc_id and loc_id.startswith("raid_"):
            prep = context.user_data.get("raid_prep")
            raid = await get_raid_by_id(prep["raid_id"]) if prep else None
            if raid and raid["status"] == "active":
                await _show_raid_prep(query, context, user_id, raid)
                return
        else:
            prep = context.user_data.get("hunt_prep")
            if prep:
                await _show_hunt_prep(query, context, user_id)
                return
    except Exception as e:
        logger.error("coop_cancel return error: %s", e)

    # Fallback
    await _edit_text(query,
        "Приглашение отменено.",
        reply_markup=InlineKeyboardMarkup([[
            InlineKeyboardButton("🏠 В меню", callback_data="main_menu")
        ]])
    )

COOP_WAIT_SECONDS = 60  # Таймер ожидания принятия приглашений
_coop_auto_tasks: dict = {}  # session_id → asyncio.Task


async def _start_coop_battle_for_all(bot, session_id: int, host_id: int, prep: dict) -> bool:
    """Запускает совместный бой для всех принятых игроков. Возвращает True если стартовало."""
    session = await get_coop_session(session_id)
    if not session or session["status"] not in ("pending", "active"):
        return False
    # Помечаем как launching чтобы не стартовало дважды
    await update_coop_session(session_id, status="launching")
    session = await get_coop_session(session_id)
    if not session or session["status"] != "launching":
        return False  # Кто-то успел раньше

    boss_id = session.get("boss_id") or prep.get("boss_id", "kosoy")
    boss    = BOSSES.get(boss_id, BOSSES["kosoy"])
    loc_id  = session.get("location") or prep.get("loc_id", "market")

    all_players = json.loads(session.get("players_json") or "[]")
    accepted    = [p for p in all_players if p.get("accepted")]
    if not accepted:
        await update_coop_session(session_id, status="cancelled")
        return False

    await update_coop_session(session_id,
        boss_id=boss_id, boss_hp=boss["hp"], boss_max_hp=boss["hp"],
        location=loc_id, current_turn=0)

    for ap in accepted:
        await start_coop_battle_db(ap["uid"], loc_id, boss_id, boss["hp"], boss["hp"])

    for ap in accepted:
        try:
            ap_char  = await get_character(ap["uid"])
            ap_battle= await get_battle(ap["uid"])
            ap_inv   = await get_inventory(ap["uid"])
            has_pot  = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in ap_inv.items())
            _opr     = await get_property(ap["uid"])
            _pn, _pm = _best_prop_skill(_opr)
            others   = [p["name"] for p in accepted if p["uid"] != ap["uid"]]
            url      = build_iso_url(ap_char, ap_battle, coop_id=str(session_id))
            others_line = " | ".join(f"👥{n}" for n in others) if others else "только ты"
            await bot.send_message(
                chat_id=ap["uid"],
                text=f"🟢 *Совместный бой! ({len(accepted)} чел.)*\n\n"
                     f"👊 *{boss['name']}* — ❤️ {boss['hp']} HP\n"
                     f"Команда: {others_line}\n"
                     f"❤️ Ты: *{ap_char['hp']}/{ap_char['max_hp']}* | ⚡ {ap_char['mana']}/{ap_char['max_mana']}",
                parse_mode="Markdown",
                reply_markup=ReplyKeyboardMarkup(
                    [[KeyboardButton("⚔️ В бой!", web_app=WebAppInfo(url=url))]],
                    resize_keyboard=True, one_time_keyboard=True
                )
            )
        except Exception:
            pass

    return True


COOP_PRESTART_SECONDS = 15  # Предупреждение перед стартом


async def _coop_auto_start_task(session_id: int, host_id: int, prep: dict, bot):
    """Asyncio-задача: ждёт COOP_WAIT_SECONDS, предупреждает, ждёт ещё 15 сек, стартует."""
    try:
        await asyncio.sleep(COOP_WAIT_SECONDS)
    except asyncio.CancelledError:
        return  # Отменён хостом

    session = await get_coop_session(session_id)
    if not session or session["status"] not in ("pending", "active"):
        _coop_auto_tasks.pop(session_id, None)
        return

    all_players = json.loads(session.get("players_json") or "[]")
    accepted    = [p for p in all_players if p.get("accepted")]

    if not accepted:
        _coop_auto_tasks.pop(session_id, None)
        await update_coop_session(session_id, status="cancelled")
        try:
            await bot.send_message(
                chat_id=host_id,
                text="⏰ Время вышло. Никто не принял приглашение — бой отменён."
            )
        except Exception:
            pass
        return

    # ── Предупреждение: бой через 15 секунд ─────────────────────
    warn_msg = None
    try:
        warn_msg = await bot.send_message(
            chat_id=host_id,
            text=f"⚠️ *Бой начнётся через {COOP_PRESTART_SECONDS} секунд!*\n\n"
                 f"Игроков в бою: {len(accepted)}\n"
                 f"Нажми «Отменить бой» чтобы остановить.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("❌ Отменить бой", callback_data=f"coop_cancel_auto_{session_id}")
            ]])
        )
    except Exception:
        pass

    try:
        await asyncio.sleep(COOP_PRESTART_SECONDS)
    except asyncio.CancelledError:
        # Отменён в период предупреждения — убираем сообщение
        if warn_msg:
            try:
                await bot.edit_message_text(
                    chat_id=host_id, message_id=warn_msg.message_id,
                    text="❌ Бой отменён."
                )
            except Exception:
                pass
        return

    _coop_auto_tasks.pop(session_id, None)

    # Убираем кнопку из предупреждающего сообщения
    if warn_msg:
        try:
            await bot.edit_message_reply_markup(
                chat_id=host_id, message_id=warn_msg.message_id,
                reply_markup=None
            )
        except Exception:
            pass

    # Финальная проверка — мог отменить пока шёл sleep
    session = await get_coop_session(session_id)
    if not session or session["status"] not in ("pending", "active"):
        return

    started = await _start_coop_battle_for_all(bot, session_id, host_id, prep)
    if started:
        try:
            await bot.send_message(
                chat_id=host_id,
                text=f"⏰ Бой начат автоматически — {len(accepted)} игрок(ов) в команде.\n"
                     f"Нажми «⚔️ В бой!» ниже 👇"
            )
        except Exception:
            pass


# ─── Когда хост нажимает «В бой!» — проверяем наличие активной co-op сессии ──

async def _check_and_start_coop(user_id: int, context) -> Optional[int]:
    """Возвращает session_id если есть активная co-op сессия, иначе None."""
    session = await get_coop_by_participant(user_id)
    if session and session["host_id"] == user_id and session["status"] == "active":
        return session["id"]
    return None


async def hunt_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Стартует бой с выбранным отрядом. Если есть активный co-op — запускает совместный бой."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    prep    = context.user_data.get("hunt_prep")
    if not prep:
        await query.answer("Данные устарели. Зайди в район снова.", show_alert=True); return

    loc_id  = prep["loc_id"]
    boss_id = prep["boss_id"]
    party   = prep.get("party", []) or []
    boss    = BOSSES[boss_id]
    char    = await get_character(user_id)

    # ── Проверяем co-op сессию ──────────────────────────────────────────
    coop_sid = await _check_and_start_coop(user_id, context)
    if coop_sid:
        session = await get_coop_session(coop_sid)
        if session and session["status"] == "active":
            # Обновляем boss_hp в сессии под текущего босса
            await update_coop_session(coop_sid,
                boss_id=boss_id, boss_hp=boss["hp"], boss_max_hp=boss["hp"],
                location=loc_id, current_turn=0)
            session = await get_coop_session(coop_sid)
            await update_character(user_id, last_hunt=int(time.time()))
            partner_char = await get_character(session["partner_id"])
            await _edit_text(query,
                f"⚔️ *СОВМЕСТНЫЙ БОЙ!*\n\n"
                f"👊 *{boss['name']}* — ❤️ {boss['hp']} HP | ⚔️ {boss['attack']} | 🛡 {boss['defense']}\n\n"
                f"👥 *{md(char['name'])}* + *{md(partner_char['name'])}*\n\n"
                f"Ходите по очереди. Первый ход — твой!",
                parse_mode="Markdown"
            )
            # Список всех принятых игроков из players_json
            all_players = json.loads(session.get("players_json") or "[]")
            accepted_players = [p for p in all_players if p["accepted"] and p["uid"] != user_id]
            if not accepted_players:
                accepted_players = [{"uid": session["partner_id"], "pnum": 2,
                                      "name": partner_char["name"], "accepted": True}]

            # Инициализируем бой для всех принятых участников
            for ap in accepted_players:
                await start_coop_battle_db(ap["uid"], loc_id, boss_id, boss["hp"], boss["hp"])
            await start_coop_battle_db(user_id, loc_id, boss_id, boss["hp"], boss["hp"])

            team_names = [p["name"] for p in accepted_players]

            # URL для хоста (pnum=1)
            battle_data_coop = await get_battle(user_id)
            inv_coop = await get_inventory(user_id)
            has_potions_coop = any(ITEMS.get(i,{}).get("type")=="potion" and q>0 for i,q in inv_coop.items())
            _opr_c = await get_property(user_id)
            _pn_c, _pm_c = _best_prop_skill(_opr_c)
            url_host = build_iso_url(char, battle_data_coop, coop_id=str(coop_sid))

            team_line = " | ".join(f"👥{n}" for n in team_names)
            await context.bot.send_message(
                chat_id=user_id,
                text=f"🟢 *Совместный бой! ({1 + len(accepted_players)} чел.)*\n\n"
                     f"👊 *{boss['name']}* — ❤️ {boss['hp']}/{boss['hp']} HP\n"
                     f"Команда: 👤{char['name']} | {team_line}\n"
                     f"❤️ Ты: *{char['hp']}/{char['max_hp']}* | ⚡ {char['mana']}/{char['max_mana']}",
                parse_mode="Markdown",
                reply_markup=ReplyKeyboardMarkup(
                    [[KeyboardButton("⚔️ В бой!", web_app=WebAppInfo(url=url_host))]],
                    resize_keyboard=True, one_time_keyboard=True
                )
            )

            # URL и сообщение каждому принятому игроку
            for ap in accepted_players:
                try:
                    ap_char = await get_character(ap["uid"])
                    ap_battle = await get_battle(ap["uid"])
                    ap_inv = await get_inventory(ap["uid"])
                    has_pot_ap = any(ITEMS.get(i,{}).get("type")=="potion" and q>0 for i,q in ap_inv.items())
                    _opr_ap = await get_property(ap["uid"])
                    _pn_ap, _pm_ap = _best_prop_skill(_opr_ap)
                    others_names = [char["name"]] + [p["name"] for p in accepted_players if p["uid"] != ap["uid"]]
                    url_ap = build_iso_url(ap_char, ap_battle, coop_id=str(coop_sid))
                    others_line = " | ".join(f"👥{n}" for n in others_names)
                    await context.bot.send_message(
                        chat_id=ap["uid"],
                        text=f"🟢 *Совместный бой! ({1 + len(accepted_players)} чел.)*\n\n"
                             f"👊 *{boss['name']}* — ❤️ {boss['hp']}/{boss['hp']} HP\n"
                             f"Команда: {others_line}\n"
                             f"❤️ Ты: *{ap_char['hp']}/{ap_char['max_hp']}* | ⚡ {ap_char['mana']}/{ap_char['max_mana']}",
                        parse_mode="Markdown",
                        reply_markup=ReplyKeyboardMarkup(
                            [[KeyboardButton("⚔️ В бой!", web_app=WebAppInfo(url=url_ap))]],
                            resize_keyboard=True, one_time_keyboard=True
                        )
                    )
                except Exception:
                    pass
            return

    # ── Обычный соло-бой (WebApp) ───────────────────────────────────────
    # Отменяем все co-op сессии (pending И active) — соло-бой без партнёра
    await cancel_all_coop(user_id)
    inv = await get_inventory(user_id)
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
    # Фильтруем партию — убираем "pending" (непринятые приглашения)
    real_party = [p for p in party if not p.get("pending")]

    await update_character(user_id, last_hunt=int(time.time()))
    await start_battle_db(user_id, loc_id, boss_id, real_party if real_party else None)
    battle_data = await get_battle(user_id)
    _opr = await get_property(user_id)
    _pn, _pm = _best_prop_skill(_opr)
    url = build_iso_url(char, battle_data)

    party_line = ""
    if real_party:
        names = ", ".join(p["name"] for p in real_party)
        party_line = f"\n👥 *Отряд:* {names}"

    await _edit_text(query,
        f"💥 *РАЗБОРКА НАЧАЛАСЬ!*\n\n"
        f"На пути встаёт {boss['name']} — _{boss['title']}_\n"
        f"«_{boss['quote']}_»\n\n"
        f"😤 *{boss['name']}* — ❤️ {boss['hp']} HP | ⚔️ {boss['attack']} | 🛡 {boss['defense']}\n"
        f"🤵 *{md(char['name'])}* — ❤️ {char['hp']}/{char['max_hp']} | ⚡ {char['mana']}/{char['max_mana']}"
        f"{party_line}\n\n_Нажми кнопку ниже чтобы открыть экран боя_ 👇",
        parse_mode="Markdown",
    )
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="👇",
        reply_markup=ReplyKeyboardMarkup(
            [[KeyboardButton("⚔️ Открыть бой", web_app=WebAppInfo(url=url))]],
            resize_keyboard=True, one_time_keyboard=True
        )
    )

async def hunt_start_now(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Хост досрочно стартует со-op бой, не ожидая таймера."""
    query      = update.callback_query
    await query.answer()
    user_id    = update.effective_user.id
    session_id = int(query.data.replace("hunt_start_now_", ""))

    # Отменяем отложенный автостарт
    sid = context.user_data.pop("coop_auto_start_sid", session_id)
    old_task = _coop_auto_tasks.pop(sid, None)
    if old_task and not old_task.done():
        old_task.cancel()

    session = await get_coop_session(session_id)
    if not session or session["status"] not in ("pending", "active", "launching"):
        await query.answer("Сессия уже неактивна.", show_alert=True)
        return

    prep = context.user_data.get("hunt_prep", {})
    started = await _start_coop_battle_for_all(context.bot, session_id, user_id, prep)
    if not started:
        await query.answer("Не удалось стартовать — никто не принял приглашение.", show_alert=True)
        return

    session = await get_coop_session(session_id)
    all_players = json.loads(session.get("players_json") or "[]")
    accepted    = [p for p in all_players if p.get("accepted")]
    await _edit_text(query,
        f"🚀 *Бой начат!* {len(accepted)} игрок(ов) в команде.\n\n"
        f"Кнопка «⚔️ В бой!» уже отправлена ниже 👇",
        parse_mode="Markdown"
    )


async def coop_cancel_auto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Хост отменяет бой из предупреждающего сообщения (за 15 сек до автостарта)."""
    query      = update.callback_query
    await query.answer("❌ Бой отменён!")
    user_id    = update.effective_user.id
    session_id = int(query.data.replace("coop_cancel_auto_", ""))

    # Отменяем asyncio-задачу
    task = _coop_auto_tasks.pop(session_id, None)
    if task and not task.done():
        task.cancel()

    # Также снимаем по user_data
    sid = context.user_data.pop("coop_auto_start_sid", None)
    if sid and sid != session_id:
        old = _coop_auto_tasks.pop(sid, None)
        if old and not old.done():
            old.cancel()

    # Помечаем сессию отменённой
    session = await get_coop_session(session_id)
    if session and session["status"] in ("pending", "active"):
        await close_coop_session(session_id, "cancelled")

    await _edit_text(query,
        "❌ *Бой отменён.*\n\nВернись к подготовке и начни заново когда будешь готов.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([[
            InlineKeyboardButton("⬅️ К подготовке", callback_data="hunt_back_prep")
        ]])
    )


# ============================================================
# ХЕНДЛЕРЫ — РАЗБОРКА (БОЙ)
# ============================================================

async def battle_action(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    action = query.data
    user_id = update.effective_user.id

    if action == "battle_no_mana":
        await query.answer("❌ Не хватает энергии!", show_alert=True); return
    if action == "battle_no_potion":
        await query.answer("❌ Аптечек нет!", show_alert=True); return

    await query.answer()
    char = await get_character(user_id)
    battle = await get_battle(user_id)
    if not battle:
        await _edit_text(query,"Разборка уже закончена.", reply_markup=await contacts_kb(user_id)); return

    boss = BOSSES[battle["boss_id"]]
    boss_hp = battle["boss_hp"]
    eff_atk = get_effective_attack(char)
    eff_def = get_effective_defense(char)
    char_hp, char_mana = char["hp"], char["mana"]
    result_text = ""

    ATTACK_MANA_COST = 5
    if action == "battle_attack":
        if char_mana < ATTACK_MANA_COST:
            await query.answer("❌ Не хватает энергии для атаки!", show_alert=True); return
        dmg = calc_damage(eff_atk, boss["defense"])
        boss_hp -= dmg
        char_mana -= ATTACK_MANA_COST
        weapon_id = char.get("weapon")
        # Критический удар Томми Гана
        weapon_item = ITEMS.get(weapon_id or "", {})
        if weapon_item.get("crit_chance") and random.random() < weapon_item["crit_chance"]:
            dmg = random.randint(weapon_item["crit_min"], weapon_item["crit_max"])
            boss_hp = battle["boss_hp"] - dmg  # пересчитываем с новым уроном
            boss_hp = max(0, boss_hp)
            result_text = f"🔥 *КРИТ! Томми Ган!* — *{dmg} урона!* (-{ATTACK_MANA_COST}⚡)\n"
        else:
            if not weapon_id:
                shots = ["🤜 Кулаком в зубы", "🤜 Хук слева", "🤜 Удар в солнечное сплетение", "🤜 Прямой в нос", "🤜 Апперкот"]
            elif weapon_id == "zatochka":
                shots = ["🔪 Полоснул заточкой", "🔪 Ткнул в бок", "🔪 Порезал руку", "🔪 Удар заточкой", "🔪 Чиркнул по ребру"]
            else:
                shots = ["🔫 Выстрел в упор", "🔫 Точный выстрел", "🔫 Прицельный выстрел", "🔫 В точку"]
            result_text = f"{random.choice(shots)}: *{dmg} урона!* (-{ATTACK_MANA_COST}⚡)\n"

    elif action == "battle_skill":
        skill = SKILLS[char["class"]]
        dmg = calc_damage(eff_atk, boss["defense"], skill["damage_mult"])
        boss_hp -= dmg
        char_mana -= skill["mana_cost"]
        result_text = f"💥 *{skill['name']}* — *{dmg} урона!* (-{skill['mana_cost']} энергии)\n"
        if "heal" in skill:
            char_hp = min(char["max_hp"], char_hp + skill["heal"])
            result_text += f"💚 Восстановлено *{skill['heal']} HP*\n"

    elif action == "battle_potion":
        inv = await get_inventory(user_id)
        potion_id = next((i for i, q in inv.items() if ITEMS.get(i, {}).get("type") == "potion" and q > 0), None)
        if not potion_id:
            await query.answer("❌ Аптечек нет!", show_alert=True); return
        await remove_item(user_id, potion_id)
        item = ITEMS[potion_id]
        if "heal" in item:
            char_hp = min(char["max_hp"], char_hp + item["heal"])
            result_text = f"🩹 {item['name']}: +{item['heal']} HP\n"
        elif "mana" in item:
            char_mana = min(char["max_mana"], char_mana + item["mana"])
            result_text = f"⚡ {item['name']}: +{item['mana']} энергии\n"

    elif action == "battle_flee":
        if random.random() < 0.5:
            await end_battle(user_id)
            # Наёмник погибает при побеге
            mercs = [m for m in await get_gang(user_id) if GANG_ROLES.get(m["role"], {}).get("is_merc")]
            merc_text = ""
            if mercs:
                fallen = random.choice(mercs)
                await remove_gang_member(fallen["id"])
                merc_text = f"\n💀 _{fallen['member_name']} прикрыл отход и не вернулся._"
            await _edit_text(query,
                f"🏃 *Ушёл по-английски.*\n\nЖить захочешь — ещё не так разбежишься.{merc_text}",
                parse_mode="Markdown", reply_markup=await contacts_kb(user_id)); return
        result_text = "❌ *Не дали уйти!*\n"

    elif action == "battle_molotov":
        inv = await get_inventory(user_id)
        if not inv.get("molotov", 0):
            await query.answer("❌ Молотовов нет!", show_alert=True); return
        await remove_item(user_id, "molotov")
        mol_item = ITEMS["molotov"]
        impact = random.randint(mol_item["dmg_min"], mol_item["dmg_max"])
        burn   = mol_item.get("burn_per_turn", 25) * mol_item.get("burn_turns", 2)
        mol_dmg = impact + burn
        boss_hp -= mol_dmg
        result_text = f"🔥 *Коктейль Молотова!* — удар *{impact}* + пожар *{burn}* = *{mol_dmg} урона!* (ответки нет)\n"
        await update_character(user_id, hp=char_hp, mana=char_mana)
        await update_battle(user_id, max(0, boss_hp))
        inv2 = await get_inventory(user_id)
        has_potions2 = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv2.items())
        has_mana2 = char_mana >= SKILLS[char["class"]]["mana_cost"]
        grenades2 = inv2.get("grenade", 0)
        molotovs2 = inv2.get("molotov", 0)
        props_used2 = json.loads(battle.get("props_used_json") or "[]")
        owned_prop2 = json.loads(char.get("owned_property") or "[]")
        prop_skills2 = get_prop_skills(owned_prop2, props_used2)
        weapon_id2 = char.get("weapon")
        if boss_hp <= 0:
            pass  # обработка победы ниже общая
        else:
            await _edit_text(query,
                f"🔥 *ВРАГ ГОРИТ!*\n\n{result_text}"
                f"😤 *{boss['name']}*\n❤️ {boss_hp}/{battle['boss_max_hp']} {hp_bar(boss_hp, battle['boss_max_hp'])}\n\n"
                f"🤵 *{md(char['name'])}*\n"
                f"❤️ {char_hp}/{char['max_hp']} {hp_bar(char_hp, char['max_hp'])}\n"
                f"⚡ {char_mana}/{char['max_mana']}\n\nЧто делаем?",
                parse_mode="Markdown",
                reply_markup=battle_kb(
                    has_mana2, has_potions2, weapon_id2,
                    eff_atk=eff_atk, boss_def=boss["defense"],
                    skill_mult=SKILLS[char["class"]]["damage_mult"],
                    skill_name=SKILLS[char["class"]]["name"],
                    cur_mana=char_mana,
                    grenades=grenades2, molotovs=molotovs2,
                    prop_skills=prop_skills2
                )
            )
            return

    elif action == "battle_grenade":
        inv = await get_inventory(user_id)
        if not inv.get("grenade", 0):
            await query.answer("❌ Гранат нет!", show_alert=True); return
        await remove_item(user_id, "grenade")
        nade_dmg = random.randint(ITEMS["grenade"]["dmg_min"], ITEMS["grenade"]["dmg_max"])
        boss_hp -= nade_dmg
        result_text = f"💣 *Граната!* — *{nade_dmg} урона!* (ответки нет)\n"
        # Без ответного удара босса — сразу обновляем и показываем клавиатуру
        await update_character(user_id, hp=char_hp, mana=char_mana)
        await update_battle(user_id, max(0, boss_hp))
        inv2 = await get_inventory(user_id)
        has_potions2 = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv2.items())
        has_mana2 = char_mana >= SKILLS[char["class"]]["mana_cost"]
        grenades2 = inv2.get("grenade", 0)
        props_used2 = json.loads(battle.get("props_used_json") or "[]")
        owned_prop2 = json.loads(char.get("owned_property") or "[]")
        prop_skills2 = get_prop_skills(owned_prop2, props_used2)
        weapon_id2 = char.get("weapon")
        if boss_hp <= 0:
            pass  # handled below in victory block
        else:
            await _edit_text(query,
                f"💣 *РАЗБОРКА ПРОДОЛЖАЕТСЯ*\n\n{result_text}"
                f"😤 *{boss['name']}*\n❤️ {boss_hp}/{battle['boss_max_hp']} {hp_bar(boss_hp, battle['boss_max_hp'])}\n\n"
                f"🤵 *{md(char['name'])}*\n"
                f"❤️ {char_hp}/{char['max_hp']} {hp_bar(char_hp, char['max_hp'])}\n"
                f"⚡ {char_mana}/{char['max_mana']}\n\nЧто делаем?",
                parse_mode="Markdown",
                reply_markup=battle_kb(
                    has_mana2, has_potions2, weapon_id2,
                    eff_atk=eff_atk, boss_def=boss["defense"],
                    skill_mult=SKILLS[char["class"]]["damage_mult"],
                    skill_name=SKILLS[char["class"]]["name"],
                    cur_mana=char_mana,
                    grenades=grenades2,
                    molotovs=inv2.get("molotov", 0),
                    prop_skills=prop_skills2
                )
            )
            return

    elif action.startswith("battle_prop_"):
        prop_id = action.replace("battle_prop_", "")
        si = STATUS_ITEMS.get(prop_id)
        owned_prop = json.loads(char.get("owned_property") or "[]")
        if not si or prop_id not in owned_prop:
            await query.answer("❌ Имущество недоступно!", show_alert=True); return
        # Проверяем — только создатель боя (хост) может использовать имущество
        session = await get_coop_session_for_user(user_id) if False else None
        props_used = json.loads(battle.get("props_used_json") or "[]")
        if prop_id in props_used:
            await query.answer("❌ Уже использовано в этом бою!", show_alert=True); return
        mult = si.get("skill_dmg_mult", 1.0)
        dmg = int(calc_damage(eff_atk, boss["defense"], mult))
        boss_hp -= dmg
        props_used.append(prop_id)
        await update_battle(user_id, max(0, boss_hp), props_used=props_used)
        result_text = f"{si['skill_name']}: *{dmg} урона!*\n"

    # Победа
    if boss_hp <= 0:
        await end_battle(user_id)
        exp_gain  = boss["exp"]
        cash_gain = boss["cash"] + random.randint(0, boss["cash"] // 3)
        await update_character(user_id, hp=char_hp, mana=char_mana,
            exp=char["exp"] + exp_gain, cash=char["cash"] + cash_gain, kills=char["kills"] + 1)
        updated = await get_character(user_id)
        lvl_text = await check_level_up(user_id, updated)

        # Дроп лута
        loot_text = ""
        inv = await get_inventory(user_id)
        drop = boss.get("drop")
        if drop:
            drop_item, drop_chance = drop
            if drop_item == "passport" and "passport" in inv:
                loot_text = "\n📄 Паспорт уже есть у тебя."
            elif random.random() < drop_chance:
                await add_item(user_id, drop_item)
                loot_text = f"\n🎁 Дроп: {ITEMS[drop_item]['name']}!"
            else:
                loot_text = f"\n💭 _Паспорта при нём не оказалось..._"
        elif random.random() < 0.3:
            loot = random.choice(["medkit_small", "energy_drink"])
            await add_item(user_id, loot)
            loot_text = f"\n🎁 Трофей: {ITEMS[loot]['name']}"

        win_phrases = [
            f"{boss['name']} ляжет без почестей.",
            f"Больше {boss['name']} никто не увидит.",
            f"{boss['name']} переоценил свои силы.",
            f"Город запомнит этот день.",
        ]
        # Проверяем — это главный босс района?
        loc_id = battle["location"]
        is_main_boss = (battle["boss_id"] == LOCATION_MAIN_BOSS.get(loc_id))
        capture_btn = []
        if is_main_boss:
            ctrl = await get_district_control(loc_id)
            if ctrl and ctrl["telegram_id"] == user_id:
                capture_btn = [[InlineKeyboardButton("✅ Район уже твой", callback_data=f"location_{loc_id}")]]
            else:
                capture_btn = [[InlineKeyboardButton(f"🏴 Захватить {LOCATIONS[loc_id]['name']}", callback_data=f"capture_district_{loc_id}")]]

        # ── Случайные события после победы ──────────────────────────────────
        post_event_text = ""
        char_after = await get_character(user_id)

        # 5% шанс — полиция заинтересовалась
        if random.random() < WANTED_CHANCE:
            current_stars = char_after.get("wanted_stars", 0) or 0
            if current_stars == 0:
                await update_character(user_id, wanted_stars=1)
                post_event_text += (
                    "\n\n🚔 *Свидетели донесли в полицию!*\n"
                    "_Тебя занесли в базу — 1 звезда розыска ⭐._\n"
                    "Продолжишь драться — станет хуже."
                )
            elif current_stars == 1:
                if random.random() < WANTED_UPGRADE_CHANCE:
                    await update_character(user_id, wanted_stars=2)
                    post_event_text += (
                        "\n\n🚔 *Расследование открыто!*\n"
                        "_2 звезды розыска ⭐⭐. Начаты официальные проверки._\n"
                        "Каждые сутки будут штрафовать на ${0}$.".format(WANTED_FINE)
                    )
            elif current_stars == 2:
                if random.random() < WANTED_UPGRADE_CHANCE:
                    # Сажают в тюрьму!
                    jail_until_ts = int(time.time()) + JAIL_DURATION
                    jail_count = (char_after.get("jail_count", 0) or 0) + 1
                    await update_character(user_id, wanted_stars=3, jail_until=jail_until_ts,
                                           jail_count=jail_count,
                                           hp=max(1, char_after["max_hp"] // 2),
                                           mana=char_after["max_mana"] // 2)
                    post_event_text += (
                        "\n\n🚨 *АРЕСТ! Тебя взяли!*\n"
                        "_3 звезды розыска ⭐⭐⭐. Полиция тебя повязала._\n"
                        f"Тюрьма на 60 минут. Открой меню чтобы выкупиться."
                    )

        # 10% шанс — получить визитку (только если не сработала полиция)
        # Каждый тип визитки можно держать только 1 штуку — если уже есть, не выпадает
        elif random.random() < CONTACT_CHANCE:
            existing_contacts = await get_contacts(user_id)
            existing_types = {c["contact_type"] for c in existing_contacts}
            available_types = [t for t in CONTACT_TYPES.keys() if t not in existing_types]
            if not available_types:
                pass  # все типы уже есть — ничего не даём
            else:
                contact_type = random.choice(available_types)
                contact_name = random_contact_name()
                await add_contact(user_id, contact_type, contact_name)
                ct = CONTACT_TYPES[contact_type]
                post_event_text += (
                    f"\n\n{ct['emoji']} *Тебе оставили визитку!*\n"
                    f"_{contact_name}_ — {ct['name']}\n"
                    f"_{ct['desc']}_\n"
                    f"Открой *«Мои связи»* в главном меню."
                )
                # Отдельное громкое уведомление чтобы не потерялось
                try:
                    await context.bot.send_message(
                        chat_id=user_id,
                        text=(
                            f"{ct['emoji']} *Новый контакт!*\n\n"
                            f"*{contact_name}* — {ct['name']}\n"
                            f"_{ct['desc']}_\n\n"
                            f"Открой *«Мои связи»* в главном меню чтобы воспользоваться."
                        ),
                        parse_mode="Markdown",
                        reply_markup=InlineKeyboardMarkup([[
                            InlineKeyboardButton("🤝 Открыть Мои связи", callback_data="my_contacts")
                        ]])
                    )
                except Exception:
                    pass

        await _edit_text(query,
            f"🏆 *РАЗБОРКА ЗАКОНЧЕНА*\n\n{result_text}"
            f"💀 {random.choice(win_phrases)}\n\n"
            f"⭐ +{exp_gain} опыта | 💵 +{cash_gain}${loot_text}{lvl_text}{post_event_text}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(
                capture_btn + [
                    [InlineKeyboardButton("🔫 Снова в дело", callback_data=f"hunt_{loc_id}")],
                    [InlineKeyboardButton("🏠 В меню",       callback_data="main_menu")],
                ]
            )
        )
        return

    # Босс контратакует
    boss_dmg = calc_damage(boss["attack"], eff_def)
    char_hp -= boss_dmg

    if char_hp <= 0:
        await end_battle(user_id)
        respawn_hp = char["max_hp"] // 3
        hosp_until = int(time.time()) + HOSPITAL_DURATION
        await update_character(user_id, hp=respawn_hp, mana=char["max_mana"], hospital_until=hosp_until)
        # Наёмник погибает при поражении
        mercs = [m for m in await get_gang(user_id) if GANG_ROLES.get(m["role"], {}).get("is_merc")]
        merc_text = ""
        if mercs:
            fallen = random.choice(mercs)
            await remove_gang_member(fallen["id"])
            merc_text = f"\n💀 _{fallen['member_name']} погиб в бою._"
        lose_phrases = ["Ребята еле вытащили. Очнулся под капельницей.", "Врач сказал — повезло. Ещё чуть-чуть и всё.", "Отлежался. Тело болит, но живой."]
        await _edit_text(query,
            f"💀 *ЛЁГ В БОЮ*\n\n{result_text}"
            f"😤 {boss['name']} бьёт в ответ: *{boss_dmg} урона!*\n\n"
            f"🏥 _{random.choice(lose_phrases)}_\n"
            f"❤️ Восстановлено {respawn_hp} HP.{merc_text}\n\n"
            f"⏰ *Нельзя драться 30 минут.* Выйти раньше — 1 💎.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🍶 Выпить отвар (1 💎)", callback_data="leave_hospital")],
                [InlineKeyboardButton("🏠 Главное меню", callback_data="main_menu")],
            ])
        )
        return

    await update_character(user_id, hp=char_hp, mana=char_mana)
    await update_battle(user_id, boss_hp)
    inv = await get_inventory(user_id)
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
    has_mana = char_mana >= SKILLS[char["class"]]["mana_cost"]
    weapon_id = char.get("weapon")
    weapon_line2 = "🤜 Кулаки" if not weapon_id else ITEMS[weapon_id]["name"]
    await _edit_text(query,
        f"💥 *РАЗБОРКА ПРОДОЛЖАЕТСЯ*\n\n{result_text}"
        f"😤 {boss['name']} бьёт в ответ: *{boss_dmg} урона!*\n\n"
        f"😤 *{boss['name']}*\n❤️ {boss_hp}/{battle['boss_max_hp']} {hp_bar(boss_hp, battle['boss_max_hp'])}\n\n"
        f"🤵 *{md(char['name'])}*\n"
        f"❤️ {char_hp}/{char['max_hp']} {hp_bar(char_hp, char['max_hp'])}\n"
        f"⚡ {char_mana}/{char['max_mana']} | ⚔️ {eff_atk} атк | {weapon_line2}\n\nЧто делаем?",
        parse_mode="Markdown", reply_markup=battle_kb(
            has_mana, has_potions, weapon_id,
            eff_atk=eff_atk, boss_def=boss["defense"],
            skill_mult=SKILLS[char["class"]]["damage_mult"],
            skill_name=SKILLS[char["class"]]["name"],
            cur_mana=char_mana,
            grenades=inv.get("grenade", 0),
            molotovs=inv.get("molotov", 0),
            prop_skills=get_prop_skills(
                json.loads(char.get("owned_property") or "[]"),
                json.loads(battle.get("props_used_json") or "[]")
            )
        )
    )


# ============================================================
# ХЕНДЛЕРЫ — КОНТРОЛЬ РАЙОНОВ
# ============================================================

async def capture_district_cb(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игрок захватывает район после убийства главного босса."""
    query = update.callback_query
    await query.answer()
    user_id  = update.effective_user.id
    loc_id   = query.data.replace("capture_district_", "")
    user_name = update.effective_user.first_name or "Неизвестный"
    loc      = LOCATIONS[loc_id]
    income   = DISTRICT_INCOME[loc_id]

    await capture_district(user_id, user_name, loc_id)

    await _edit_text(query,
        f"🏴 *{loc['name']} теперь твой!*\n\n"
        f"Каждые 20 часов с района капает:\n"
        f"💵 {income['cash_min']}–{income['cash_max']}$ | ⭐ {income['exp']} опыта\n\n"
        f"⚠️ *Внимание!* На захваченные районы возможны рейды.\n"
        f"Вражеская банда может атаковать {loc['name']} в любой момент.\n"
        f"Ты получишь уведомление — у тебя будет 15 минут чтобы защититься.\n"
        f"Поставь охранников через 🛡️ *Охрана района* — они бьют врага вместе с тобой.\n\n"
        f"_Заходи в район и жми «Собрать дань»._",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"🛡️ Настроить охрану", callback_data=f"district_guard_{loc_id}")],
            [InlineKeyboardButton(f"📍 В {loc['name']}",  callback_data=f"location_{loc_id}")],
            [InlineKeyboardButton("🏠 В меню",            callback_data="main_menu")],
        ])
    )

async def collect_district_cb(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Собрать ежедневный доход с района."""
    query   = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    user_id = update.effective_user.id
    loc_id  = query.data.replace("collect_district_", "")
    loc     = LOCATIONS[loc_id]

    result = await collect_district_income(user_id, loc_id)
    if result is None:
        await query.answer("⏳ Ещё рано. Приходи позже.", show_alert=True)
        return

    char = await get_character(user_id)
    await update_character(user_id,
        cash=char["cash"] + result["cash"],
        exp=char["exp"] + result["exp"]
    )
    updated = await get_character(user_id)
    lvl_text = await check_level_up(user_id, updated)

    await _edit_text(query,
        f"💰 *Собрал дань с {loc['name']}*\n\n"
        f"💵 +{result['cash']}$ | ⭐ +{result['exp']} опыта{lvl_text}\n\n"
        f"_Следующий сбор через 20 часов._",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"📍 В {loc['name']}", callback_data=f"location_{loc_id}")],
            [InlineKeyboardButton("🏠 В меню",           callback_data="main_menu")],
        ])
    )

# ============================================================
# ХЕНДЛЕР — БРОСИТЬ ЗАВИСШИЙ БОЙ
# ============================================================

async def abandon_battle(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игрок бросает зависший бой без штрафа."""
    query = update.callback_query
    user_id = update.effective_user.id
    await end_battle(user_id)
    await query.answer("Бой брошен.")
    await _edit_text(query,
        "🏳️ *Слился.* Бой сброшен — можешь начинать заново.",
        parse_mode="Markdown"
    )
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="В меню:",
        reply_markup=ReplyKeyboardRemove()
    )
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Что дальше?",
        reply_markup=await contacts_kb(user_id)
    )

# ============================================================
# ХЕНДЛЕР — ДЕЙСТВИЕ ИЗ МИНИ-ПРИЛОЖЕНИЯ РАЗБОРКИ
# ============================================================

async def battle_grenade_webapp(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Граната во WebApp бою — урон без контратаки."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    battle = await get_battle(user_id)
    if not battle:
        await _edit_text(query,"Бой уже закончен.")
        return
    inv = await get_inventory(user_id)
    if not inv.get("grenade", 0):
        await _edit_text(query,"💣 Гранаты закончились.")
        return
    char = await get_character(user_id)
    bid = battle["boss_id"]
    boss = BOSSES[bid] if bid != "raid_boss" else context.user_data.get("active_raid_boss", BOSSES["raid_boss"])
    boss_hp   = battle["boss_hp"]
    nade_dmg  = random.randint(ITEMS["grenade"]["dmg_min"], ITEMS["grenade"]["dmg_max"])
    boss_hp  -= nade_dmg
    await remove_item(user_id, "grenade")
    await update_battle(user_id, max(0, boss_hp))
    grenades_left = (await get_inventory(user_id)).get("grenade", 0)
    if boss_hp <= 0:
        exp_gain  = boss["exp"]
        cash_gain = boss["cash"] + random.randint(0, boss["cash"] // 3)
        await end_battle(user_id)
        await update_character(user_id, exp=char["exp"] + exp_gain,
            cash=char["cash"] + cash_gain, kills=char["kills"] + 1)
        updated = await get_character(user_id)
        lvl_text = await check_level_up(user_id, updated)
        await _edit_text(query,
            f"💣 *ГРАНАТА РЕШИЛА ВСЁ!*\n\nВзрыв — *{nade_dmg} урона!*\n\n"
            f"🏆 *ПОБЕДА!*\n⭐ +{exp_gain} опыта | 💵 +{cash_gain}${lvl_text}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🏠 В меню", callback_data="main_menu")
            ]])
        )
        return
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
    battle_upd = await get_battle(user_id)
    url = build_iso_url(char, battle_upd)
    gren_btn = [[InlineKeyboardButton(f"💣 Ещё гранату ×{grenades_left}", callback_data="battle_grenade_webapp")]] if grenades_left > 0 else []
    await _edit_text(query,
        f"💣 *Граната!* Взрыв — *{nade_dmg} урона!* (контратаки нет)\n"
        f"😤 *{boss['name']}*: ❤️ {boss_hp}/{battle['boss_max_hp']}\n"
        f"Теперь нажми кнопку боя!",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(gren_btn if gren_btn else [[]])
    )



async def _hub_send_section(chat_id: int, user_id: int, dest: str, context) -> None:
    """Send a section's opening screen as a new message (called from hub_nav)."""
    char = await get_character(user_id)
    if not char:
        await context.bot.send_message(chat_id=chat_id, text="Введи /start чтобы начать игру.")
        return

    back_btn = [[InlineKeyboardButton("⬅️ Меню", callback_data="main_menu")]]

    if dest == "explore":
        rows = []
        for loc_id, loc in LOCATIONS.items():
            ok = char["level"] >= loc["min_level"]
            label = (f"{loc['name']} (ранг {loc['min_level']}+)" if ok
                     else f"🔒 {loc['name']} (ранг {loc['min_level']}+)")
            rows.append([InlineKeyboardButton(label,
                callback_data=f"location_{loc_id}" if ok else "locked")])
        rows += back_btn
        await context.bot.send_message(chat_id=chat_id,
            text="🗺️ *Выбери район*\n\nКуда едем?",
            parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

    elif dest == "character":
        cls = CLASSES[char["class"]]
        weapon_text = (ITEMS[char["weapon"]]["name"]
                       if char.get("weapon") and char["weapon"] in ITEMS else "Голые руки")
        armor_text  = (ITEMS[char["armor"]]["name"]
                       if char.get("armor")  and char["armor"]  in ITEMS else "Нет")
        ranks = ["Новобранец","Шестёрка","Бандит","Боевик","Капо",
                 "Смотрящий","Авторитет","Положенец","Вор в законе","Крёстный отец"]
        rank_title = ranks[min(char["level"] - 1, len(ranks) - 1)]
        job_line    = (f"\n💼 Работа: {JOBS[char['job']]['name']}"
                       if char.get("job") else "")
        wanted_stars = char.get("wanted_stars", 0) or 0
        wanted_line  = (f"\n🔍 Розыск: {'⭐' * wanted_stars} ({wanted_stars} ур.)"
                        if wanted_stars > 0 else "\n🔍 Розыск: нет")
        kills      = char.get("kills", 0) or 0
        safe_name  = md(char["name"])
        await context.bot.send_message(
            chat_id=chat_id,
            text=(f"📁 *ДОСЬЕ: {safe_name}*\n_{rank_title}_\n\n"
                  f"🎖️ Ранг: {char['level']}\n"
                  f"⭐ Опыт: {level_progress(char)}\n"
                  f"❤️ HP: {char['hp']}/{char['max_hp']}\n"
                  f"⚡ Энергия: {char['mana']}/{char['max_mana']}\n"
                  f"🔫 Атака: {get_effective_attack(char)}\n"
                  f"🛡️ Защита: {get_effective_defense(char)}\n\n"
                  f"🔫 Ствол: {weapon_text}\n"
                  f"🦺 Броня: {armor_text}\n\n"
                  f"💵 Нал: {char['cash']}$\n"
                  f"💎 Бриллианты: {char['diamonds']}\n"
                  f"💀 Устранено: {kills}"
                  f"{wanted_line}{job_line}"),
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🏙️ Моё имущество", callback_data="my_property")]]
                + back_btn))

    elif dest == "inventory":
        inv = await get_inventory(user_id)
        if not inv:
            await context.bot.send_message(chat_id=chat_id,
                text="🎒 *Барахло*\n\nПусто.",
                parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(back_btn))
            return
        text = "🎒 *Барахло:*\n\n"
        rows = []
        for item_id, qty in inv.items():
            item = ITEMS.get(item_id)
            if not item:
                continue
            equipped = " ✅" if (char.get("weapon") == item_id
                                  or char.get("armor") == item_id) else ""
            text += f"{item['name']}{equipped} ×{qty}\n_{item['desc']}_\n\n"
            if item["type"] == "potion":
                rows.append([InlineKeyboardButton(
                    f"Использовать {item['name']}", callback_data=f"use_{item_id}")])
            elif item["type"] in ("weapon", "armor"):
                if equipped:
                    rows.append([InlineKeyboardButton(
                        f"Снять {item['name']}", callback_data=f"unequip_{item_id}")])
                else:
                    rows.append([InlineKeyboardButton(
                        f"Взять {item['name']}", callback_data=f"equip_{item_id}")])
        rows += back_btn
        await context.bot.send_message(chat_id=chat_id, text=text,
            parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

    elif dest == "shop":
        await context.bot.send_message(
            chat_id=chat_id,
            text=(f"🏪 *Чёрный рынок*\n\n"
                  f"💵 Нал: {char['cash']}$ | 💎 Бриллианты: {char['diamonds']}\n\nЧто нужно?"),
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🩹 Аптечки",         callback_data="shop_potions")],
                [InlineKeyboardButton("🔫 Стволы и броня",  callback_data="shop_equipment")],
                [InlineKeyboardButton("✨ Элитное",          callback_data="shop_premium")],
                [InlineKeyboardButton("🏙️ Имущество",       callback_data="shop_property")],
                [InlineKeyboardButton(f"🔫 Нанять наёмника — ${MERCENARY_BUY_COST}",
                                      callback_data="gang_buy_merc")],
            ] + back_btn))

    elif dest == "jobs":
        inv = await get_inventory(user_id)
        has_passport = "passport" in inv
        if char.get("job"):
            job = JOBS[char["job"]]
            now = int(time.time())
            worked_sec = now - char["job_started"]
            preview_pay, _g, _ = calc_job_pay(char["job"], worked_sec)
            await context.bot.send_message(
                chat_id=chat_id,
                text=(f"💼 *Ты сейчас работаешь*\n\n"
                      f"Должность: *{job['name']}*\n"
                      f"⏱ Отработано: {format_duration(worked_sec)}\n"
                      f"💵 Заработано сейчас: ~{preview_pay}$"),
                parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup(
                    [[InlineKeyboardButton("🚪 Уволиться", callback_data="job_quit_confirm")]]
                    + back_btn))
        else:
            rows = []
            for job_id, job in JOBS.items():
                if job["passport"] and not has_passport:
                    rows.append([InlineKeyboardButton(
                        f"🔒 {job['name']} (нужен паспорт)", callback_data="job_need_passport")])
                else:
                    rows.append([InlineKeyboardButton(
                        job["name"], callback_data=f"job_info_{job_id}")])
            rows += back_btn
            await context.bot.send_message(chat_id=chat_id,
                text="💼 *Биржа труда*\n\nВыбери вакансию. Деньги капают раз в час.",
                parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

    elif dest == "gang_menu":
        gang = await get_gang(user_id)
        owned_prop_gm = await get_property(user_id)
        gang_max_gm   = calc_gang_max(owned_prop_gm)
        base_rows = [
            [InlineKeyboardButton("🏴 Мои районы",      callback_data="my_districts")],
            [InlineKeyboardButton("👥 Друзья в банде",   callback_data="gang_friends")],
        ]
        if not gang:
            text = ("👥 *Моя банда*\n\n"
                    "_Пока один. Ходи по районам — встречаются нужные люди._\n\n"
                    "🔫 Наёмника можно купить на Чёрном рынке за $100")
        else:
            text = f"👥 *Моя банда* — {len(gang)}/{gang_max_gm}\n\n"
            for m in gang[:10]:
                role_info = GANG_ROLES.get(m.get("role"), {})
                text += f"  {role_info.get('emoji','👤')} {m.get('name','?')} — {role_info.get('name','Боец')}\n"
            base_rows.insert(0, [InlineKeyboardButton("👁 Посмотреть банду", callback_data="gang_mercs_screen")])
        await context.bot.send_message(chat_id=chat_id, text=text,
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(base_rows + back_btn))

    elif dest == "diamonds":
        rows = [[InlineKeyboardButton(f"{p['label']} — ⭐{p['stars']}",
                                       callback_data=f"buystars_{i}")]
                for i, p in enumerate(DIAMOND_PACKAGES)]
        rows += back_btn
        await context.bot.send_message(chat_id=chat_id,
            text=("💎 *Бриллианты*\n\n"
                  "Для покупки элитного снаряжения.\nОплата через Telegram Stars.\n\nВыбери пакет:"),
            parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

    elif dest == "my_contacts":
        contacts = await get_contacts(user_id)
        text = "🤝 *Мои связи*\n\n"
        if not contacts:
            text += ("😶 _Пока ты никого не встретил на пути._\n\n"
                     "Побеждай в боях — с каждой победой есть шанс, "
                     "что кто-то оставит визитку.")
            await context.bot.send_message(chat_id=chat_id, text=text,
                parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(back_btn))
        else:
            rows = []
            for c in contacts:
                ct = CONTACT_TYPES[c["contact_type"]]
                text += f"{ct['emoji']} *{c['contact_name']}* — {ct['name']}\n_{ct['desc']}_\n\n"
                rows.append([InlineKeyboardButton(
                    f"{ct['emoji']} {c['contact_name']}",
                    callback_data=f"use_contact_{c['id']}")])
            rows += back_btn
            await context.bot.send_message(chat_id=chat_id, text=text,
                parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

    else:
        # Unknown dest — just show hub button
        await context.bot.send_message(chat_id=chat_id, text="Выбери раздел:",
            reply_markup=await contacts_kb(user_id))

async def battle_webapp_action(update: Update, context: ContextTypes.DEFAULT_TYPE):

    """Принимает выбор игрока из Mini App боя."""
    try:
        data   = json.loads(update.message.web_app_data.data)
        action = data.get("a", "")
    except Exception:
        return

    # ── Сохранение внешности персонажа из редактора ───────────────
    if action == "set_look":
        user_id = update.effective_user.id
        change_look = bool(data.get("change_look", False))
        look = {
            "gender": int(data.get("gender", 0)),
            "skin":   int(data.get("skin",   0)),
            "body":   int(data.get("body",   0)),
            "face":   int(data.get("face",   0)),
            "hair":   int(data.get("hair",   0)),
            "hat":    int(data.get("hat",    0)),
        }
        if change_look:
            char = await get_character(user_id)
            if not char or char.get("diamonds", 0) < 5:
                await update.message.reply_text(
                    "❌ Недостаточно бриллиантов! Нужно 5 💎 для смены образа.",
                    reply_markup=await contacts_kb(user_id)
                )
                return
            await update_character(user_id, diamonds=char["diamonds"] - 5, look_json=json.dumps(look))
            reply_text = "✏️ *Образ обновлён!* Потрачено 5 💎\n\nОткрой главное меню — удачи на улицах! 🔫"
        else:
            await update_character(user_id, look_json=json.dumps(look))
            reply_text = "🎨 *Твой гангстер готов!* Образ сохранён. 🤵\n\nОткрой главное меню и выбирай раздел — удачи на улицах! 🔫"
        await update.message.reply_text(
            reply_text,
            parse_mode="Markdown",
            reply_markup=await contacts_kb(user_id)
        )
        return

    # ── Навигация из Hub WebApp ──────────────────────────────────
    if action == "hub_nav":
        user_id = update.effective_user.id
        dest    = data.get("to", "")
        chat_id = update.effective_chat.id
        await _hub_send_section(chat_id, user_id, dest, context)
        return
    # ── Работа: взять контракт из mini-app ───────────────────────
    # ПОЛНОСТЬЮ ТИХО — никаких сообщений в чат. Все ошибки/успех
    # отображаются внутри самого мини-приложения (optimistic UI).
    # Дополнительно: HTTP-эндпоинт /job/{uid}/take умеет вернуть
    # ответ прямо в открытую WebApp без закрытия.
    if action == "job_take":
        user_id = update.effective_user.id
        char = await get_character(user_id)
        if not char:
            return
        now = int(time.time())
        # Серверная валидация (без сообщений в чат)
        if (char.get("captivity_until") or 0) > now: return
        if (char.get("jail_until")      or 0) > now: return
        if char.get("job"):                          return
        job_id = data.get("id", "")
        job = JOBS.get(job_id)
        if not job:                                  return
        if (char.get("level", 1) or 1) < job.get("rank", 1): return
        await update_character(user_id, job=job_id, job_started=now, job_last_paid=now)
        # Молча. Никаких reply_text — никаких сообщений в чат.
        return

    # ── Работа: забрать выплату из mini-app ──────────────────────
    if action == "job_collect":
        user_id = update.effective_user.id
        char = await get_character(user_id)
        if not char or not char.get("job"):
            await update.message.reply_text("Контракта нет.", reply_markup=await contacts_kb(user_id))
            return
        job = JOBS.get(char["job"])
        if not job:
            await update_character(user_id, job=None, job_started=None, job_last_paid=None)
            await update.message.reply_text("Контракт устарел — сброшен.", reply_markup=await contacts_kb(user_id))
            return
        now = int(time.time())
        end_ts = (char.get("job_started") or 0) + job.get("duration", JOB_DURATION)
        if now < end_ts:
            mins = (end_ts - now + 59) // 60
            await update.message.reply_text(f"⏳ Ещё рано — {mins} мин.", reply_markup=await contacts_kb(user_id))
            return

        # Бросок: успех/провал для спецзаданий
        success_chance = float(job.get("success_chance", 1.0))
        success = random.random() < success_chance

        # Бросок звёзд (только при успехе)
        cop_chance  = float(job.get("cop_star_chance",  0))
        gang_chance = float(job.get("gang_star_chance", 0))
        cop_n   = int(job.get("stars_amount_cop", 1))
        gang_n  = int(job.get("stars_amount_gang", 1))
        cop_added  = cop_n  if random.random() < cop_chance  else 0
        gang_added = gang_n if random.random() < gang_chance else 0

        pay = random.randint(int(job["pay_min"]), int(job["pay_max"])) if success else 0

        cur_cop  = char.get("wanted_stars", 0) or 0
        cur_gang = char.get("wanted_gangs", 0) or 0
        new_cop  = min(3, cur_cop  + cop_added)
        new_gang = min(3, cur_gang + gang_added)

        updates = {
            "cash":          (char.get("cash", 0) or 0) + pay,
            "job":           None,
            "job_started":   None,
            "job_last_paid": None,
            "wanted_stars":  new_cop,
            "wanted_gangs":  new_gang,
        }
        jail_triggered = False
        if new_cop >= 3 and (char.get("jail_until", 0) or 0) <= now:
            updates["jail_until"] = now + JAIL_DURATION
            updates["jail_count"] = (char.get("jail_count", 0) or 0) + 1
            jail_triggered = True
        cap_triggered = False
        if new_gang >= 3 and (char.get("captivity_until", 0) or 0) <= now:
            updates["captivity_until"] = now + CAPTIVITY_DURATION
            updates["captivity_count"] = (char.get("captivity_count", 0) or 0) + 1
            cap_triggered = True
        await update_character(user_id, **updates)

        lines = []
        if success:
            lines.append(f"💰 *Выплата получена: +{pay}$*")
        else:
            lines.append(f"💥 *Провал!* «{job['name']}» сорвался.")
        lines.append(f"_{job['name']}_")
        if cop_added:
            lines.append(f"🚓 Менты заметили: *+{cop_added} звезды копов* ({new_cop}/3)")
        if gang_added:
            lines.append(f"👊 Банда узнала: *+{gang_added} звезды банд* ({new_gang}/3)")
        if jail_triggered:
            lines.append("")
            lines.append(f"🚔 *Тебя взяли копы!* Тюрьма на {JAIL_DURATION//60} мин.")
        if cap_triggered:
            lines.append("")
            lines.append(f"👊 *Тебя поймали братки!* Плен на {CAPTIVITY_DURATION//60} мин.")
        await update.message.reply_text(
            "\n".join(lines),
            parse_mode="Markdown",
            reply_markup=await contacts_kb(update.effective_user.id)
        )
        return

    # ── Работа: сорвать контракт из mini-app ─────────────────────
    # ПОЛНОСТЬЮ ТИХО — увольнение происходит в мини-приложении.
    if action == "job_abandon":
        user_id = update.effective_user.id
        char = await get_character(user_id)
        if not char or not char.get("job"):
            return
        await update_character(user_id, job=None, job_started=None, job_last_paid=None)
        # Молча. Никаких сообщений в чат.
        return

    # ── Выкуп из плена банд из mini-app ──────────────────────────
    if action == "captivity_bail_wa":
        user_id = update.effective_user.id
        char = await get_character(user_id)
        if not char:
            return
        now = int(time.time())
        if (char.get("captivity_until", 0) or 0) <= now:
            await update.message.reply_text("Ты уже на свободе.", reply_markup=await contacts_kb(user_id))
            return
        if (char.get("diamonds", 0) or 0) < CAPTIVITY_BAIL_DIAMONDS:
            await update.message.reply_text(
                f"Нужно {CAPTIVITY_BAIL_DIAMONDS} 💎. У тебя {char.get('diamonds',0)}.",
                reply_markup=await contacts_kb(user_id))
            return
        await update_character(user_id,
            diamonds=(char["diamonds"] or 0) - CAPTIVITY_BAIL_DIAMONDS,
            captivity_until=0, wanted_gangs=0,
            hp=char["max_hp"]//2, mana=char["max_mana"]//2)
        await update.message.reply_text(
            f"💰 *Выкупился из плена!* -{CAPTIVITY_BAIL_DIAMONDS} 💎\nЗвёзды банд сняты, HP/⚡ 50%.",
            parse_mode="Markdown",
            reply_markup=await contacts_kb(user_id))
        return


    # ── Результаты боёв из Hub mini-app (без закрытия чата) ───────
    if action == "hub_battles":
        user_id = update.effective_user.id
        char    = await get_character(user_id)
        if not char:
            return
        wins    = data.get("wins", [])      # [{boss_id, loc_id, exp, cash}]
        gathers = data.get("gathers", [])   # [{loc_id, cash}]
        heals   = data.get("heals",   [])   # [{loc_id, cost}]
        final_hp = int(data.get("final_hp", char["hp"]))
        final_mp = int(data.get("final_mp", char["mana"]))
        total_exp  = sum(int(w.get("exp", 0))  for w in wins)
        total_cash = sum(int(w.get("cash", 0)) for w in wins)
        total_cash += sum(int(g.get("cash", 0)) for g in gathers)
        total_cash -= sum(int(h.get("cost", 0)) for h in heals)  # hospital costs
        total_kills = len(wins)
        await update_character(user_id,
            hp   = max(1, final_hp),
            mana = max(0, final_mp),
            exp  = char["exp"] + total_exp,
            cash = char["cash"] + total_cash,
            kills= char["kills"] + total_kills,
        )
        updated = await get_character(user_id)
        lvl_text = await check_level_up(user_id, updated)
        # Всегда обновляем кнопку хаба — иначе HP/деньги не обновятся в мини-приложении
        parts = []
        if total_kills > 0:
            parts.append(f"💀 {total_kills} {'победа' if total_kills==1 else 'побед'}")
        if total_exp > 0:
            parts.append(f"+{total_exp} опыта")
        if total_cash > 0:
            parts.append(f"+{total_cash}$")
        if heals:
            parts.append(f"🏥 HP восстановлено")
        summary = " · ".join(parts) if parts else "✅ Сохранено"
        await update.message.reply_text(
            f"{summary}{lvl_text}",
            reply_markup=await contacts_kb(user_id),
            parse_mode="Markdown"
        )
        return

    # ══ CO-OP HUB ACTIONS ═══════════════════════════════════════════════

    if action == "coop_create_hub":
        boss_id     = data.get("boss_id", "kosoy")
        loc_id      = data.get("loc_id", "market")
        invite_uids = [int(x) for x in data.get("invite_uids", []) if str(x).isdigit()][:3]
        boss        = BOSSES.get(boss_id, BOSSES["kosoy"])
        char        = await get_character(user_id)
        if not char: return

        # Build players list: host always first, invited gang members after
        players = [{"uid": user_id, "name": char["name"],
                    "hp": char["hp"], "max_hp": char["max_hp"],
                    "accepted": True, "ready": False}]
        for iuid in invite_uids:
            ic = await get_character(iuid)
            if ic:
                players.append({"uid": iuid, "name": ic["name"],
                                 "hp": ic["hp"], "max_hp": ic["max_hp"],
                                 "accepted": False, "ready": False})

        partner_id = invite_uids[0] if invite_uids else user_id
        sid = await create_coop_session(
            host_id=user_id, partner_id=partner_id,
            boss_id=boss_id, boss_hp=boss["hp"], boss_max_hp=boss["hp"],
            location=loc_id,
            party=players,
        )
        # Persist players_json
        await update_coop_session(sid, players_json=json.dumps(players, ensure_ascii=False))

        # Send Telegram invites
        for iuid in invite_uids:
            ic = await get_character(iuid)
            if not ic: continue
            try:
                await context.bot.send_message(
                    chat_id=iuid,
                    text=(f"⚔️ *{md(char['name'])}* зовёт в совместный бой!\n\n"
                          f"👊 *{boss['name']}* — ❤️ {boss['hp']} HP\n"
                          f"Ты в банде — присоединяйся!"),
                    parse_mode="Markdown",
                    reply_markup=InlineKeyboardMarkup([[
                        InlineKeyboardButton("✅ Вступить", callback_data=f"coop_accept_{sid}"),
                        InlineKeyboardButton("❌ Отказать", callback_data=f"coop_decline_{sid}"),
                    ]])
                )
            except Exception: pass

        session = await get_coop_session(sid)
        url = await build_hub_url_coop(user_id, session, "waiting")
        invited_str = f"{len(invite_uids)} игрок(а)" if invite_uids else "никого не приглашено"
        await update.message.reply_text(
            f"✅ Сессия *#{sid}* создана!\nПриглашения: {invited_str}.\nЖди пока все примут, затем жми «Начать».",
            parse_mode="Markdown",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("🕐 Лобби", web_app=WebAppInfo(url=url))]],
                resize_keyboard=True, one_time_keyboard=True
            )
        )
        return

    if action == "coop_ready_hub":
        sid     = int(data.get("sid", 0))
        session = await get_coop_session(sid)
        if not session: return
        players = json.loads(session.get("players_json") or "[]")
        for p in players:
            if p["uid"] == user_id:
                p["ready"] = True
        await update_coop_session(sid, players_json=json.dumps(players, ensure_ascii=False))
        session = await get_coop_session(sid)
        char    = await get_character(user_id)
        ready_n = sum(1 for p in players if p.get("ready"))
        try:
            await context.bot.send_message(
                chat_id=session["host_id"],
                text=f"✅ *{md(char['name'] if char else str(user_id))}* готов! ({ready_n} готовы)",
                parse_mode="Markdown"
            )
        except Exception: pass
        url = await build_hub_url_coop(user_id, session, "waiting")
        await update.message.reply_text(
            "✅ Ты готов! Ждём хоста...",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("🕐 Ждать", web_app=WebAppInfo(url=url))]],
                resize_keyboard=True, one_time_keyboard=True
            )
        )
        return

    if action == "coop_start_hub":
        sid     = int(data.get("sid", 0))
        session = await get_coop_session(sid)
        if not session or session["host_id"] != user_id: return
        players = json.loads(session.get("players_json") or "[]")
        # Mark host as ready
        for p in players:
            if p["uid"] == user_id:
                p["ready"] = True
        await update_coop_session(sid, status="active", current_turn=0,
                                   players_json=json.dumps(players, ensure_ascii=False))
        session = await get_coop_session(sid)
        boss    = await _coop_boss_for_session(session)
        ready   = [p for p in players if p.get("ready")]
        await _send_coop_hub_update(
            context.bot, session, "battle",
            f"⚔️ *Кооп-бой начался!*\n👊 {boss['name']} — ❤️ {session['boss_hp']} HP"
        )
        return

    if action == "coop_turn_hub":
        sid        = int(data.get("sid", 0))
        turn_act   = data.get("turn", "attack")
        session    = await get_coop_session(sid)
        if not session or session["status"] != "active": return
        players    = json.loads(session.get("players_json") or "[]")
        ready      = [p for p in players if p.get("ready")]
        if not ready: return
        turn_idx   = int(session.get("current_turn", 0))
        current_pl = ready[turn_idx % len(ready)]
        if current_pl["uid"] != user_id: return   # not your turn

        char = await get_character(user_id)
        boss = await _coop_boss_for_session(session)

        if turn_act == "flee":
            await close_coop_session(sid, "fled")
            char_name = char["name"] if char else str(user_id)
            for p in ready:
                try:
                    await context.bot.send_message(
                        chat_id=p["uid"],
                        text=f"🏃 *{md(char_name)}* сбежал. Бой окончен.",
                        parse_mode="Markdown"
                    )
                except Exception: pass
            return

        # Player attacks boss
        dmg     = calc_damage(get_effective_attack(char), boss["defense"])
        boss_hp = max(0, session["boss_hp"] - dmg)

        # Boss counter-attacks random ready player
        import random as _r
        tgt_pl   = _r.choice(ready)
        tgt_char = await get_character(tgt_pl["uid"])
        bdmg     = calc_damage(boss["attack"], tgt_char["defense"] if tgt_char else 10)
        new_hp   = max(0, (tgt_char["hp"] if tgt_char else 1) - bdmg)
        if tgt_char:
            await update_character(tgt_pl["uid"], hp=new_hp)
        for p in players:
            if p["uid"] == tgt_pl["uid"]:
                p["hp"] = new_hp

        next_turn = (turn_idx + 1) % len(ready)
        await update_coop_session(sid, boss_hp=boss_hp, current_turn=next_turn,
                                   players_json=json.dumps(players, ensure_ascii=False))
        session = await get_coop_session(sid)
        char_name = char["name"] if char else str(user_id)
        tgt_name  = tgt_pl.get("name", "")
        log_line  = (f"⚔️ {char_name} → {boss['name']}: *{dmg} урона*\n"
                     f"💀 {boss['name']} → {tgt_name}: *{bdmg} урона*")

        if boss_hp <= 0:
            await close_coop_session(sid, "won")
            reward_cash = boss.get("cash", 200)
            reward_exp  = boss.get("exp", 50)
            for p in ready:
                pc = await get_character(p["uid"])
                if pc:
                    await update_character(p["uid"],
                        cash=pc["cash"]+reward_cash, exp=pc["exp"]+reward_exp, kills=pc["kills"]+1)
            await _send_coop_hub_update(context.bot, session, "won",
                f"🏆 *ПОБЕДА!*\n{log_line}\n\n+${reward_cash} | +{reward_exp} опыта каждому!")
            return

        all_dead = all(p.get("hp", 1) <= 0 for p in ready)
        if all_dead:
            await close_coop_session(sid, "lost")
            await _send_coop_hub_update(context.bot, session, "lost",
                f"💀 *ПОРАЖЕНИЕ.*\n{log_line}")
            return

        await _send_coop_hub_update(context.bot, session, "battle", log_line)
        return


    if action == "buy_cash_hub":
        idx  = int(data.get("idx", 0))
        if idx < 0 or idx >= len(CASH_PACKAGES):
            return
        pkg  = CASH_PACKAGES[idx]
        uid  = update.effective_user.id
        await context.bot.send_invoice(
            chat_id     = uid,
            title       = pkg["label"],
            description = f"{pkg['cash']} баксов для игры Мафиози",
            payload     = f"cash_{idx}_{uid}",
            currency    = "XTR",
            prices      = [LabeledPrice(label=pkg["label"], amount=pkg["stars"])],
        )
        await update.message.reply_text(
            f"💵 Окно оплаты отправлено выше 👆\n\n"
            f"После оплаты *{pkg['cash']} баксов* зачислятся автоматически.",
            parse_mode="Markdown"
        )
        return

    if action == "buy_dia_hub":
        idx  = int(data.get("idx", 0))
        if idx < 0 or idx >= len(DIAMOND_PACKAGES):
            return
        pkg  = DIAMOND_PACKAGES[idx]
        uid  = update.effective_user.id
        await context.bot.send_invoice(
            chat_id     = uid,
            title       = pkg["label"],
            description = f"{pkg['diamonds']} бриллиантов для игры Мафиози",
            payload     = f"diamonds_{idx}_{uid}",
            currency    = "XTR",
            prices      = [LabeledPrice(label=pkg["label"], amount=pkg["stars"])],
        )
        await update.message.reply_text(
            f"💎 Окно оплаты отправлено выше 👆\n\n"
            f"После оплаты *{pkg['diamonds']} бриллиантов* зачислятся автоматически.",
            parse_mode="Markdown"
        )
        return


    # ── Новые финальные результаты от WebApp ──────────────────────
    if action in ("battle_won", "battle_lost", "battle_fled"):
        user_id = update.effective_user.id
        char    = await get_character(user_id)
        battle  = await get_battle(user_id)
        if not battle:
            return
        if battle["boss_id"] == "raid_boss":
            boss = context.user_data.get("active_raid_boss", BOSSES["raid_boss"])
        else:
            boss = BOSSES.get(battle["boss_id"], BOSSES["kosoy"])

        if action == "battle_won":
            php = int(data.get("php", char["hp"]))
            pmp = int(data.get("pmp", char["mana"]))
            gren_used = int(data.get("gu", 0))
            mol_used  = int(data.get("mu", 0))
            # Лимит подняли до 50, чтоб с 100+ гранат от @deadblog1 ничего
            # не «съедалось обратно». Защита от подмены URL через max.
            for _ in range(min(gren_used, 50)):
                await remove_item(user_id, "grenade")
            for _ in range(min(mol_used, 50)):
                await remove_item(user_id, "molotov")
            # Множитель района: ×1.0 (рынок, min_level=1) → ×2.9 (резиденция, min_level=20).
            # Та же формула в demo_isometric.html (LOC_REWARD_MUL), числа сходятся.
            loc_id_for_mul = battle.get("location") or ""
            loc_min_lvl    = LOCATIONS.get(loc_id_for_mul, {}).get("min_level", 1)
            loc_mul        = 1 + 0.10 * max(0, loc_min_lvl - 1)
            # Если WebApp прислал свои значения (xp/cash) — доверяем им, но кэпим, чтобы
            # не словить читы через подмену URL. Иначе считаем сами по той же формуле.
            xp_payload   = int(data.get("xp",   0) or 0)
            cash_payload = int(data.get("cash", 0) or 0)
            base_exp     = round(boss["exp"]  * loc_mul)
            base_cash    = round(boss["cash"] * loc_mul)
            if xp_payload > 0:
                exp_gain = min(xp_payload, base_exp * 3)
            else:
                exp_gain = base_exp
            if cash_payload > 0:
                cash_gain = min(cash_payload, base_cash * 3)
            else:
                cash_gain = base_cash
            await end_battle(user_id)
            await update_character(user_id,
                hp=max(1, php), mana=max(0, pmp),
                exp=char["exp"] + exp_gain,
                cash=char["cash"] + cash_gain,
                kills=char["kills"] + 1)
            updated  = await get_character(user_id)
            lvl_text = await check_level_up(user_id, updated)
            # Лут
            loot_text = ""
            drop = boss.get("drop")
            if drop:
                drop_item, drop_chance = drop
                inv = await get_inventory(user_id)
                if drop_item == "passport" and "passport" in inv:
                    loot_text = "\n📄 Паспорт уже есть."
                elif random.random() < drop_chance:
                    await add_item(user_id, drop_item)
                    loot_text = f"\n🎁 Дроп: {ITEMS[drop_item]['name']}!"
                else:
                    loot_text = "\n💭 _Паспорта при нём не оказалось..._"
            elif random.random() < 0.3:
                loot = random.choice(["medkit_small", "energy_drink"])
                await add_item(user_id, loot)
                loot_text = f"\n🎁 Трофей: {ITEMS[loot]['name']}"
            loc_id = battle["location"]
            is_main_boss = (battle["boss_id"] == LOCATION_MAIN_BOSS.get(loc_id))
            capture_btn = []
            if is_main_boss:
                ctrl = await get_district_control(loc_id)
                if ctrl and ctrl["telegram_id"] == user_id:
                    capture_btn = [[InlineKeyboardButton("✅ Район уже твой", callback_data=f"location_{loc_id}")]]
                else:
                    capture_btn = [[InlineKeyboardButton(f"🏴 Захватить {LOCATIONS.get(loc_id,{}).get('name','район')}", callback_data=f"capture_district_{loc_id}")]]
            await update.message.reply_text(
                f"🏆 *ПОБЕДА!*\n\n💀 {boss['name']} повержен!\n\n"
                f"⭐ +{exp_gain} опыта | 💵 +{cash_gain}${loot_text}{lvl_text}",
                parse_mode="Markdown", reply_markup=ReplyKeyboardRemove())
            await context.bot.send_message(
                chat_id=update.effective_chat.id, text="Что дальше?",
                reply_markup=InlineKeyboardMarkup(
                    capture_btn + [
                        [InlineKeyboardButton("🔫 Снова в дело", callback_data=f"hunt_{loc_id}")],
                        [InlineKeyboardButton("🏠 В меню", callback_data="main_menu")],
                    ]
                ))
            # Уведомляем всех партнёров по co-op
            coop_s = await get_coop_by_participant(user_id)
            if coop_s and coop_s["status"] == "active" and coop_s.get("boss_id") == battle["boss_id"]:
                all_coop_players = json.loads(coop_s.get("players_json") or "[]")
                notified = set()
                # Если players_json пуст — старый формат, берём host+partner
                if not all_coop_players:
                    other_id = coop_s["partner_id"] if coop_s["host_id"] == user_id else coop_s["host_id"]
                    all_coop_players = [{"uid": other_id, "accepted": True}]
                for cp in all_coop_players:
                    cp_uid = cp["uid"]
                    if cp_uid == user_id or not cp.get("accepted", True): continue
                    if cp_uid in notified: continue
                    notified.add(cp_uid)
                    cp_char = await get_character(cp_uid)
                    if not cp_char: continue
                    await update_character(cp_uid,
                        exp=cp_char["exp"] + exp_gain,
                        cash=cp_char["cash"] + cash_gain,
                        kills=cp_char["kills"] + 1)
                    try:
                        await context.bot.send_message(
                            chat_id=cp_uid,
                            text=f"🏆 *Совместная победа!*\n\n"
                                 f"💀 *{md(char['name'])}* добил *{boss['name']}*!\n\n"
                                 f"⭐ +{exp_gain} опыта | 💵 +{cash_gain}$ — твоя доля",
                            parse_mode="Markdown",
                            reply_markup=InlineKeyboardMarkup([[
                                InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
                            ]])
                        )
                    except Exception:
                        pass
                await close_coop_session(coop_s["id"], "won")

        elif action == "battle_lost":
            await end_battle(user_id)
            await update_character(user_id, hp=1, mana=0)
            await update.message.reply_text(
                f"💀 *ПОРАЖЕНИЕ!*\n\n{boss['name']} оказался сильнее.\nHP: 1 | Энергия: 0",
                parse_mode="Markdown", reply_markup=ReplyKeyboardRemove())
            await context.bot.send_message(
                chat_id=update.effective_chat.id, text="В меню:",
                reply_markup=await contacts_kb(user_id))
            # Уведомляем партнёра по co-op только если сессия реально для этого боя
            coop_s = await get_coop_by_participant(user_id)
            if coop_s and coop_s["status"] == "active" and coop_s.get("boss_id") == battle["boss_id"]:
                partner_id = coop_s["partner_id"] if coop_s["host_id"] == user_id else coop_s["host_id"]
                await close_coop_session(coop_s["id"], "lost")
                try:
                    await context.bot.send_message(
                        chat_id=partner_id,
                        text=f"💀 *Совместное поражение*\n\n"
                             f"*{boss['name']}* оказался сильнее. Не в этот раз...",
                        parse_mode="Markdown",
                        reply_markup=InlineKeyboardMarkup([[
                            InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
                        ]])
                    )
                except Exception:
                    pass

        elif action == "battle_fled":
            await end_battle(user_id)
            await update.message.reply_text(
                "🏃 *Слился.* Ушёл живым — и то хорошо.",
                parse_mode="Markdown", reply_markup=ReplyKeyboardRemove())
            await context.bot.send_message(
                chat_id=update.effective_chat.id, text="В меню:",
                reply_markup=await contacts_kb(user_id))
            # Уведомляем партнёра по co-op только если сессия реально для этого боя
            coop_s = await get_coop_by_participant(user_id)
            if coop_s and coop_s["status"] == "active" and coop_s.get("boss_id") == battle["boss_id"]:
                partner_id = coop_s["partner_id"] if coop_s["host_id"] == user_id else coop_s["host_id"]
                await close_coop_session(coop_s["id"], "fled")
                try:
                    await context.bot.send_message(
                        chat_id=partner_id,
                        text=f"🏃 *Партнёр сбежал из боя*\n\n"
                             f"*{md(char['name'])}* покинул схватку с *{boss['name']}*.",
                        parse_mode="Markdown",
                        reply_markup=InlineKeyboardMarkup([[
                            InlineKeyboardButton("🏠 В главное меню", callback_data="main_menu")
                        ]])
                    )
                except Exception:
                    pass
        return

    action_map = {
        "attack":        "battle_attack",
        "skill":         "battle_skill",
        "potion":        "battle_potion",
        "flee":          "battle_flee",
        "party_attack":  "battle_party_attack",
    }
    raw_action = action
    action = action_map.get(action)
    if not action:
        return

    user_id = update.effective_user.id
    char    = await get_character(user_id)
    battle  = await get_battle(user_id)
    if not battle:
        await update.message.reply_text("Разборка уже закончена.", reply_markup=await contacts_kb(user_id))
        return

    # Для рейдовых боёв статы берутся из user_data, иначе из BOSSES
    if battle["boss_id"] == "raid_boss":
        boss = context.user_data.get("active_raid_boss", BOSSES["raid_boss"])
    else:
        boss = BOSSES[battle["boss_id"]]
    boss_hp   = battle["boss_hp"]
    eff_atk   = get_effective_attack(char)
    eff_def   = get_effective_defense(char)
    char_hp   = char["hp"]
    char_mana = char["mana"]
    party     = battle.get("party", [])
    result_text = ""

    ATTACK_MANA_COST_WA = 5

    if action == "battle_attack":
        if char_mana < ATTACK_MANA_COST_WA:
            await update.message.reply_text("❌ Нет энергии для атаки!")
            return
        dmg = calc_damage(eff_atk, boss["defense"])
        boss_hp -= dmg
        char_mana -= ATTACK_MANA_COST_WA
        weapon_id = char.get("weapon")
        if not weapon_id:
            shots = ["🤜 Кулаком в зубы", "🤜 Хук слева", "🤜 Апперкот"]
        elif weapon_id in KNIFE_WEAPONS:
            shots = ["🔪 Полоснул заточкой", "🔪 Ткнул в бок", "🔪 Порезал руку"]
        else:
            shots = ["🔫 Выстрел в упор", "🔫 Точный выстрел", "🔫 Прицельный выстрел"]
        result_text = f"{random.choice(shots)}: *{dmg} урона!* (-{ATTACK_MANA_COST_WA}⚡)\n"

    elif action == "battle_skill":
        skill = SKILLS[char["class"]]
        if char_mana < skill["mana_cost"]:
            await update.message.reply_text("❌ Мало энергии для приёма!")
            return
        dmg = calc_damage(eff_atk, boss["defense"], skill["damage_mult"])
        boss_hp -= dmg
        char_mana -= skill["mana_cost"]
        result_text = f"💥 *{skill['name']}* — *{dmg} урона!* (-{skill['mana_cost']}⚡)\n"
        if "heal" in skill:
            char_hp = min(char["max_hp"], char_hp + skill["heal"])
            result_text += f"💚 Восстановлено *{skill['heal']} HP*\n"

    elif action == "battle_potion":
        inv = await get_inventory(user_id)
        potion_id = next((i for i, q in inv.items()
                          if ITEMS.get(i, {}).get("type") == "potion" and q > 0), None)
        if not potion_id:
            await update.message.reply_text("❌ Аптечек нет!")
            return
        await remove_item(user_id, potion_id)
        item = ITEMS[potion_id]
        if "heal" in item:
            char_hp = min(char["max_hp"], char_hp + item["heal"])
            result_text = f"🩹 {item['name']}: *+{item['heal']} HP*\n"
        elif "mana" in item:
            char_mana = min(char["max_mana"], char_mana + item["mana"])
            result_text = f"⚡ {item['name']}: *+{item['mana']} энергии*\n"

    elif action == "battle_flee":
        if random.random() < 0.5:
            await end_battle(user_id)
            mercs = [m for m in await get_gang(user_id) if GANG_ROLES.get(m["role"], {}).get("is_merc")]
            merc_text = ""
            if mercs:
                fallen = random.choice(mercs)
                await remove_gang_member(fallen["id"])
                merc_text = f"\n💀 _{fallen['member_name']} прикрыл отход и не вернулся._"
            await update.message.reply_text(
                f"🏃 *Ушёл по-английски.*\n\nЖить захочешь — ещё не так разбежишься.{merc_text}",
                parse_mode="Markdown", reply_markup=ReplyKeyboardRemove())
            await context.bot.send_message(
                chat_id=update.effective_chat.id,
                text="В меню:",
                reply_markup=await contacts_kb(user_id)
            )
            return
        result_text = "❌ *Не дали уйти!*\n"

    elif action == "battle_party_attack":
        idx = data.get("idx", 0)
        if idx < 0 or idx >= len(party) or not party[idx].get("alive", True):
            await update.message.reply_text("❌ Этот боец не может атаковать!")
            return
        member = party[idx]
        if member["type"] == "mercenary":
            cls = MERC_CLASSES.get(member.get("role", "mercenary"), MERC_CLASSES["mercenary"])
            dmg = random.randint(cls["dmg_min"], cls["dmg_max"])
            role_info = GANG_ROLES.get(member.get("role", "mercenary"), GANG_ROLES["mercenary"])
            emoji = role_info["emoji"]
            result_text = f"{emoji} *{member['name']}* атакует: *{dmg} урона!*\n"
        else:
            # Друг — урон по его атаке
            atk = member.get("attack", 10)
            dmg = calc_damage(atk, boss["defense"])
            result_text = f"👤 *{member['name']}* атакует: *{dmg} урона!*\n"
        boss_hp -= dmg

    # ── Победа ─────────────────────────────────────────────────────────────
    if boss_hp <= 0:
        await end_battle(user_id)

        # ── Рейд отбит ─────────────────────────────────────────────────────
        if battle["location"].startswith("raid_"):
            raid_id = int(battle["location"].replace("raid_", ""))
            raid = await get_raid_by_id(raid_id)
            if raid and raid["status"] == "active":
                await close_raid(raid_id, "defended")
                await update_character(user_id,
                    hp=char_hp, mana=char_mana,
                    cash=char["cash"] + raid["reward_cash"],
                    exp=char["exp"] + raid["reward_exp"],
                    kills=char["kills"] + 1)
                updated = await get_character(user_id)
                lvl_text = await check_level_up(user_id, updated)
                loc_name = LOCATIONS.get(raid["location_id"], {}).get("name", "район")
                await update.message.reply_text(
                    f"🏆 *РЕЙД ОТБИТ!*\n\n{result_text}"
                    f"💀 {raid['gang_emoji']} *{raid['gang_name']}* разгромлены!\n\n"
                    f"💵 +{raid['reward_cash']}$ | ⭐ +{raid['reward_exp']} опыта{lvl_text}",
                    parse_mode="Markdown", reply_markup=ReplyKeyboardRemove()
                )
                await context.bot.send_message(
                    chat_id=update.effective_chat.id, text="Что дальше?",
                    reply_markup=InlineKeyboardMarkup([
                        [InlineKeyboardButton(f"🏙️ {loc_name}", callback_data=f"location_{raid['location_id']}")],
                        [InlineKeyboardButton("🏠 В меню", callback_data="main_menu")],
                    ])
                )
            else:
                await update.message.reply_text("Рейд уже завершён.", reply_markup=ReplyKeyboardRemove())
                await context.bot.send_message(chat_id=update.effective_chat.id, text="В меню:", reply_markup=await contacts_kb(user_id))
            return

        exp_gain  = boss["exp"]
        cash_gain = boss["cash"] + random.randint(0, boss["cash"] // 3)
        await update_character(user_id, hp=char_hp, mana=char_mana,
            exp=char["exp"] + exp_gain, cash=char["cash"] + cash_gain,
            kills=char["kills"] + 1)
        updated = await get_character(user_id)
        lvl_text = await check_level_up(user_id, updated)
        loot_text = ""
        inv = await get_inventory(user_id)
        drop = boss.get("drop")
        if drop:
            drop_item, drop_chance = drop
            if drop_item == "passport" and "passport" in inv:
                loot_text = "\n📄 Паспорт уже есть у тебя."
            elif random.random() < drop_chance:
                await add_item(user_id, drop_item)
                loot_text = f"\n🎁 Дроп: {ITEMS[drop_item]['name']}!"
            else:
                loot_text = "\n💭 _Паспорта при нём не оказалось..._"
        elif random.random() < 0.3:
            loot = random.choice(["medkit_small", "energy_drink"])
            await add_item(user_id, loot)
            loot_text = f"\n🎁 Трофей: {ITEMS[loot]['name']}"
        win_phrases = [
            f"{boss['name']} ляжет без почестей.",
            f"Больше {boss['name']} никто не увидит.",
            f"{boss['name']} переоценил свои силы.",
            "Город запомнит этот день.",
        ]
        # Проверяем — это главный босс района?
        loc_id = battle["location"]
        is_main_boss = (battle["boss_id"] == LOCATION_MAIN_BOSS.get(loc_id))
        capture_btn = []
        if is_main_boss:
            ctrl = await get_district_control(loc_id)
            if ctrl and ctrl["telegram_id"] == user_id:
                capture_btn = [[InlineKeyboardButton("✅ Район уже твой", callback_data=f"location_{loc_id}")]]
            else:
                capture_btn = [[InlineKeyboardButton(f"🏴 Захватить {LOCATIONS[loc_id]['name']}", callback_data=f"capture_district_{loc_id}")]]
        await update.message.reply_text(
            f"🏆 *ПОБЕДА!*\n\n{result_text}"
            f"💀 {random.choice(win_phrases)}\n\n"
            f"⭐ +{exp_gain} опыта | 💵 +{cash_gain}${loot_text}{lvl_text}",
            parse_mode="Markdown",
            reply_markup=ReplyKeyboardRemove()
        )
        await context.bot.send_message(
            chat_id=update.effective_chat.id,
            text="Что дальше?",
            reply_markup=InlineKeyboardMarkup(
                capture_btn + [
                    [InlineKeyboardButton("🔫 Снова в дело", callback_data=f"hunt_{loc_id}")],
                    [InlineKeyboardButton("🏠 В меню",       callback_data="main_menu")],
                ]
            )
        )
        return

    # ── Босс контратакует ──────────────────────────────────────────────────
    # Выбираем случайного живого цель: игрок или участник отряда
    # Враг бьёт главного героя (70%) или живого члена отряда (30%)
    alive_party_idx = [i for i, m in enumerate(party) if m.get("alive", True)]
    if alive_party_idx and random.random() < 0.30:
        target = random.choice(alive_party_idx)
    else:
        target = "player"

    boss_counter_text = ""
    if target == "player":
        boss_dmg = calc_damage(boss["attack"], eff_def)
        char_hp -= boss_dmg
        boss_counter_text = f"😤 {boss['name']} бьёт *тебя*: *{boss_dmg} урона!*"
    else:
        m = party[target]
        boss_dmg = calc_damage(boss["attack"], m.get("defense", 0))
        m["hp"]  = max(0, m["hp"] - boss_dmg)
        if m["hp"] <= 0:
            m["alive"] = False
            if m["type"] == "mercenary":
                await remove_gang_member(m["gang_id"])
                boss_counter_text = (f"😤 {boss['name']} бьёт *{m['name']}*: *{boss_dmg} урона!*\n"
                                     f"💀 _{m['name']} погиб. Удалён из банды._")
            else:
                boss_counter_text = (f"😤 {boss['name']} бьёт *{m['name']}*: *{boss_dmg} урона!*\n"
                                     f"💀 _{m['name']} выбыл из боя._")
        else:
            boss_counter_text = f"😤 {boss['name']} бьёт *{m['name']}*: *{boss_dmg} урона!* ❤️{m['hp']}"
        party[target] = m

    if char_hp <= 0:
        await end_battle(user_id)
        respawn_hp = char["max_hp"] // 3
        hosp_until = int(time.time()) + HOSPITAL_DURATION
        await update_character(user_id, hp=respawn_hp, mana=char["max_mana"], hospital_until=hosp_until)

        # ── Поражение в рейде ───────────────────────────────────────────────
        if battle["location"].startswith("raid_"):
            raid_id = int(battle["location"].replace("raid_", ""))
            raid = await get_raid_by_id(raid_id)
            if raid and raid["status"] == "active":
                await close_raid(raid_id, "lost")
                await _apply_raid_loss(raid)
            loc_name = LOCATIONS.get(raid["location_id"], {}).get("name", "район") if raid else "район"
            await update.message.reply_text(
                f"💀 *РАЙОН ПАЛ!*\n\n{result_text}"
                f"{boss_counter_text}\n\n"
                f"🏥 Тебя еле вытащили. Доход с *{loc_name}* заблокирован на 6 часов.\n\n"
                f"⏰ *Нельзя драться 30 минут.* Выйти раньше — 1 💎.",
                parse_mode="Markdown", reply_markup=ReplyKeyboardRemove()
            )
            await context.bot.send_message(
                chat_id=update.effective_chat.id, text="В меню:",
                reply_markup=InlineKeyboardMarkup([
                    [InlineKeyboardButton("🍶 Выпить отвар (1 💎)", callback_data="leave_hospital")],
                    [InlineKeyboardButton("🏠 Главное меню", callback_data="main_menu")],
                ])
            )
            return

        lose_phrases = ["Ребята еле вытащили. Очнулся под капельницей.", "Врач сказал — повезло. Ещё чуть-чуть и всё.", "Отлежался. Тело болит, но живой."]
        await update.message.reply_text(
            f"💀 *ЛЁГ В БОЮ*\n\n{result_text}"
            f"{boss_counter_text}\n\n"
            f"🏥 _{random.choice(lose_phrases)}_\n❤️ Восстановлено {respawn_hp} HP.\n\n"
            f"⏰ *Нельзя драться 30 минут.* Выйти раньше — 1 💎.",
            parse_mode="Markdown", reply_markup=ReplyKeyboardRemove()
        )
        await context.bot.send_message(
            chat_id=update.effective_chat.id, text="В меню:",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🍶 Выпить отвар (1 💎)", callback_data="leave_hospital")],
                [InlineKeyboardButton("🏠 Главное меню", callback_data="main_menu")],
            ])
        )
        return

    # ── Бой продолжается ──────────────────────────────────────────────────
    await update_character(user_id, hp=char_hp, mana=char_mana)
    await update_battle(user_id, boss_hp)
    if party:
        await update_battle_party(user_id, party)
        # Сохраняем текущий HP каждого живого наёмника в БД
        for pm in party:
            if pm.get("type") == "mercenary" and pm.get("alive", True) and pm.get("gang_id"):
                await update_merc_hp(pm["gang_id"], pm["hp"])
    inv = await get_inventory(user_id)
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())

    char_upd   = dict(char);   char_upd["hp"] = char_hp; char_upd["mana"] = char_mana
    battle_upd = dict(battle); battle_upd["boss_hp"] = boss_hp; battle_upd["party"] = party

    log_str = result_text.strip().replace("*", "") + "\n" + boss_counter_text.replace("*", "")
    url = build_iso_url(char_upd, battle_upd)

    # ── Проверяем co-op сессию ──────────────────────────────────────────
    coop_session = await get_coop_by_participant(user_id)
    if coop_session and coop_session["status"] == "active":
        coop_id = coop_session["id"]
        # Обновляем HP босса в общей сессии
        await update_coop_session(coop_id, boss_hp=boss_hp)
        # Определяем следующего игрока
        if coop_session["host_id"] == user_id:
            next_player_id = coop_session["partner_id"]
            next_turn = 1
        else:
            next_player_id = coop_session["host_id"]
            next_turn = 0
        await update_coop_session(coop_id, current_turn=next_turn)
        # Стартуем бой для следующего игрока с текущим HP босса
        await start_coop_battle_db(
            next_player_id, coop_session["location"],
            coop_session["boss_id"], boss_hp, coop_session["boss_max_hp"]
        )
        next_char = await get_character(next_player_id)
        next_battle = await get_battle(next_player_id)
        next_inv = await get_inventory(next_player_id)
        next_has_potions = any(
            ITEMS.get(i, {}).get("type") == "potion" and q > 0
            for i, q in next_inv.items()
        )
        _next_opr = await get_property(next_player_id)
        _next_pn, _next_pm = _best_prop_skill(_next_opr)
        _next_pp_ok = 1 if coop_session["host_id"] == next_player_id else 0
        next_url = build_iso_url(next_char, next_battle)
        next_name = next_char["name"] if next_char else "партнёр"
        # Отправляем ход следующему игроку
        try:
            await context.bot.send_message(
                chat_id=next_player_id,
                text=f"🔵 *Твой ход!*\n\n"
                     f"👊 *{boss['name']}* — ❤️ {boss_hp}/{coop_session['boss_max_hp']} HP\n"
                     f"❤️ Ты: *{next_char['hp']}/{next_char['max_hp']}* | ⚡ {next_char['mana']}/{next_char['max_mana']}",
                parse_mode="Markdown",
                reply_markup=ReplyKeyboardMarkup(
                    [[KeyboardButton("⚔️ Твой ход!", web_app=WebAppInfo(url=next_url))]],
                    resize_keyboard=True, one_time_keyboard=True
                )
            )
        except Exception:
            pass
        # Текущему игроку — "ход друга", без WebApp-кнопки
        await update.message.reply_text(
            f"⚔️ *Раунд*\n\n{result_text}"
            f"{boss_counter_text}\n\n"
            f"❤️ Ты: *{char_hp}/{char['max_hp']}* | {boss['name']}: *{boss_hp}/{battle['boss_max_hp']}*\n\n"
            f"⏳ Ход *{md(next_name)}*...",
            parse_mode="Markdown",
            reply_markup=ReplyKeyboardRemove()
        )
        return

    # ── Соло-бой продолжается ───────────────────────────────────────────
    grenades_after = inv.get("grenade", 0)
    await update.message.reply_text(
        f"⚔️ *Раунд*\n\n{result_text}"
        f"{boss_counter_text}\n\n"
        f"❤️ Ты: *{char_hp}/{char['max_hp']}* | {boss['name']}: *{boss_hp}/{battle['boss_max_hp']}*",
        parse_mode="Markdown",
        reply_markup=ReplyKeyboardMarkup(
            [[KeyboardButton("⚔️ Продолжить бой", web_app=WebAppInfo(url=url))]],
            resize_keyboard=True, one_time_keyboard=True
        )
    )
    if grenades_after > 0:
        await context.bot.send_message(
            chat_id=update.effective_chat.id,
            text=f"💣 Гранаты: ×{grenades_after} — кинь ДО хода (контратаки нет)",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton(f"💣 Кинуть гранату ×{grenades_after}", callback_data="battle_grenade_webapp")
            ]])
        )


# ============================================================
# ХЕНДЛЕРЫ — ДОСЬЕ
# ============================================================

async def character_info(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if not char:
        await _edit_text(query,"Введи /start чтобы начать игру.")
        return
    cls = CLASSES[char["class"]]
    weapon_text = ITEMS[char["weapon"]]["name"] if char.get("weapon") and char["weapon"] in ITEMS else "Голые руки"
    armor_text  = ITEMS[char["armor"]]["name"]  if char.get("armor")  and char["armor"]  in ITEMS else "Нет"
    ranks = ["Новобранец","Шестёрка","Бандит","Боевик","Капо","Смотрящий","Авторитет","Положенец","Вор в законе","Крёстный отец"]
    rank_title = ranks[min(char["level"] - 1, len(ranks) - 1)]
    job_line = f"\n💼 Работа: {JOBS[char['job']]['name']}" if char.get("job") else ""
    wanted_stars = char.get("wanted_stars", 0) or 0
    jail_count   = char.get("jail_count", 0) or 0
    wanted_line  = f"\n🔍 Розыск: {'⭐' * wanted_stars} ({wanted_stars} ур.)" if wanted_stars > 0 else "\n🔍 Розыск: нет"
    jail_line    = f"\n🚔 Ходок в тюрьме: {jail_count}"

    # Имущество и статус
    owned_prop = await get_property(user_id)
    kills = char.get("kills", 0) or 0
    status_pts  = get_status_points(owned_prop, kills)
    prop_lines  = ""
    if owned_prop:
        prop_lines = "\n\n🏙️ *Имущество:*\n" + "\n".join(f"  {STATUS_ITEMS[i]['name']}" for i in owned_prop if i in STATUS_ITEMS)

    # Уровень статуса
    STATUS_LEVELS = [
        "Бомж",              "Нищий",             "Малоимущий",        "Шантрапа",          "Лох",
        "Фраер",             "Гопник",             "Шпана",             "Хулиган",           "Шкет",
        "Пацан",             "Урка",               "Жулик",             "Мошенник",          "Щипач",
        "Карманник",         "Форточник",          "Медвежатник",       "Громила",           "Бандит",
        "Уркаган",           "Братан",             "Бык",               "Торпеда",           "Боец",
        "Беспредельщик",     "Рэкетир",            "Налётчик",          "Грабитель",         "Лихой",
        "Отморозок",         "Отвязный",           "Браток",            "Шестёрка",          "Приблатнённый",
        "Тёртый",            "Правильный пацан",   "Свой",              "Проверенный",       "Деловой",
        "Серьёзный",         "Крутой",             "Бывалый",           "Матёрый",           "Тёмный",
        "Лютый",             "Злой",               "Дерзкий",           "Зверь",             "Волк",
        "Волчара",           "Медведь",            "Акула",             "Тигр",              "Лев",
        "Дракон",            "Хищник",             "Опасный",           "Грозный",           "Беспощадный",
        "Смотрящий",         "Положенец",          "Авторитет",         "Вор",               "Старший",
        "Уважаемый",         "Человек",            "Деятель",           "Влиятельный",       "Нужный человек",
        "Решала",            "Вершитель",          "Хозяин",            "Пахан",             "Смотрящий за городом",
        "Вор в законе",      "Чёрный",             "Крёстный",          "Дон",               "Мафиози",
        "Капо",              "Консильере",         "Семья",             "Босс",              "Падрино",
        "Теневой",           "Неприкасаемый",      "Хранитель",         "Легенда района",    "Легенда города",
        "Серый кардинал",    "Теневой правитель",  "Господин",          "Владыка",           "Царь",
        "Тёмный властелин",  "Правитель теней",    "Бессмертный",       "Нетронутый",        "Легенда",
    ]
    status_lvl = min(status_pts // 100, 100)
    status_title = STATUS_LEVELS[status_lvl - 1] if status_lvl > 0 else "Никто"
    status_line = (f"\n\n👑 *Статус: {status_pts} оч.* | Ур.{status_lvl} — _{status_title}_\n"
                   f"  📦 Имущество: {get_status_points(owned_prop)} | 💀 Победы: {kills * 10}")

    # Экранируем имя от символов Markdown
    safe_name = md(char['name'])

    await _edit_text(query,
        f"📁 *ДОСЬЕ: {safe_name}*\n_{rank_title}_\n\n"
        f"🎖️ Ранг: {char['level']}\n"
        f"⭐ Опыт: {level_progress(char)}\n"
        f"❤️ HP: {char['hp']}/{char['max_hp']}\n"
        f"⚡ Энергия: {char['mana']}/{char['max_mana']}\n"
        f"🔫 Атака: {get_effective_attack(char)} (база: {char['attack']})\n"
        f"🛡️ Защита: {get_effective_defense(char)} (база: {char['defense']})\n\n"
        f"🔫 Ствол: {weapon_text}\n"
        f"🦺 Защита: {armor_text}\n\n"
        f"💵 Нал: {char['cash']}$\n"
        f"💎 Бриллианты: {char['diamonds']}\n"
        f"💀 Устранено: {kills}"
        f"{wanted_line}{jail_line}{status_line}{prop_lines}{job_line}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🏙️ Моё имущество", callback_data="my_property")],
            [InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")],
        ])
    )

# ============================================================
# ХЕНДЛЕРЫ — БАРАХЛО
# ============================================================

async def inventory_view(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    inv = await get_inventory(user_id)
    char = await get_character(user_id)
    if not inv:
        await _edit_text(query,"🎒 *Барахло*\n\nПусто.", parse_mode="Markdown", reply_markup=back_kb("main_menu")); return
    text = "🎒 *Барахло:*\n\n"
    rows = []
    for item_id, qty in inv.items():
        item = ITEMS.get(item_id)
        if not item: continue
        equipped = " ✅" if char.get("weapon") == item_id or char.get("armor") == item_id else ""
        text += f"{item['name']}{equipped} ×{qty}\n_{item['desc']}_\n\n"
        if item["type"] == "potion":
            rows.append([InlineKeyboardButton(f"Использовать {item['name']}", callback_data=f"use_{item_id}")])
        elif item["type"] == "grenade":
            rows.append([InlineKeyboardButton(f"💣 {item['name']} ×{qty} — используй в бою", callback_data="inventory_grenade_hint")])
        elif item["type"] in ("weapon", "armor"):
            if equipped:
                rows.append([InlineKeyboardButton(f"Снять {item['name']}", callback_data=f"unequip_{item_id}")])
            else:
                rows.append([InlineKeyboardButton(f"Взять {item['name']}", callback_data=f"equip_{item_id}")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

async def use_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    item_id = query.data.replace("use_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    item = ITEMS.get(item_id)
    if not item or not await remove_item(user_id, item_id):
        await query.answer("❌ Нет такого!", show_alert=True); return
    if "heal" in item:
        await update_character(user_id, hp=min(char["max_hp"], char["hp"] + item["heal"]))
        await query.answer(f"✅ +{item['heal']} HP", show_alert=True)
    elif "mana" in item:
        await update_character(user_id, mana=min(char["max_mana"], char["mana"] + item["mana"]))
        await query.answer(f"✅ +{item['mana']} энергии", show_alert=True)
    await inventory_view(update, context)

async def equip_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    item_id = query.data.replace("equip_", "")
    item = ITEMS.get(item_id)
    field = "weapon" if item["type"] == "weapon" else "armor"
    await update_character(update.effective_user.id, **{field: item_id})
    await query.answer(f"✅ {item['name']} в деле!", show_alert=True)
    await inventory_view(update, context)

async def unequip_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    item_id = query.data.replace("unequip_", "")
    item = ITEMS.get(item_id)
    field = "weapon" if item["type"] == "weapon" else "armor"
    await update_character(update.effective_user.id, **{field: None})
    await query.answer(f"✅ {item['name']} убрал.", show_alert=True)
    await inventory_view(update, context)

# ============================================================
# ХЕНДЛЕРЫ — ЧЁРНЫЙ РЫНОК
# ============================================================

async def shop(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    char = await get_character(update.effective_user.id)
    if not char:
        await _edit_text(query,"Введи /start чтобы начать игру.")
        return
    await _edit_text(query,
        f"🏪 *Чёрный рынок*\n\n💵 Нал: {char['cash']}$ | 💎 Бриллианты: {char['diamonds']}\n\nЧто нужно?",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🩹 Аптечки",        callback_data="shop_potions")],
            [InlineKeyboardButton("🔫 Стволы и броня", callback_data="shop_equipment")],
            [InlineKeyboardButton("✨ Элитное",         callback_data="shop_premium")],
            [InlineKeyboardButton("🏙️ Имущество",      callback_data="shop_property")],
            [InlineKeyboardButton(f"🔫 Нанять наёмника — ${MERCENARY_BUY_COST}", callback_data="gang_buy_merc")],
            [InlineKeyboardButton("⬅️ Назад",           callback_data="main_menu")],
        ])
    )

async def shop_potions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    char = await get_character(update.effective_user.id)
    items = {k: v for k, v in ITEMS.items() if v["type"] == "potion" and "price" in v}
    rows = [[InlineKeyboardButton(f"{v['name']} — {v['price']}$", callback_data=f"buy_{k}")] for k, v in items.items()]
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="shop")])
    await _edit_text(query,f"🩹 *Аптечки*\n\n💵 Нал: {char['cash']}$", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

async def shop_equipment(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    char = await get_character(update.effective_user.id)
    items = {k: v for k, v in ITEMS.items() if v["type"] in ("weapon","armor") and "price" in v}
    rows = [[InlineKeyboardButton(f"{v['name']} — {v['price']}$ ({v['desc']})", callback_data=f"buy_{k}")] for k, v in items.items()]
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="shop")])
    await _edit_text(query,f"🔫 *Стволы и броня*\n\n💵 Нал: {char['cash']}$", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

async def shop_premium(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    char = await get_character(update.effective_user.id)
    items = {k: v for k, v in ITEMS.items() if "diamonds_price" in v}
    rows = [[InlineKeyboardButton(f"{v['name']} — {v['diamonds_price']}💎 ({v['desc']})", callback_data=f"buyc_{k}")] for k, v in items.items()]
    rows.append([InlineKeyboardButton("💎 Купить бриллианты", callback_data="diamonds")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="shop")])
    await _edit_text(query,f"✨ *Элитное снаряжение*\n\n💎 Бриллианты: {char['diamonds']}", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

async def buy_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    item_id = query.data.replace("buy_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    item = ITEMS.get(item_id)
    if not item or "price" not in item:
        await query.answer("❌ Товар не найден!", show_alert=True); return
    now_ts = int(time.time())
    disc = char.get("gang_discount_until", 0) or 0
    if now_ts < disc:
        price = int(item["price"] * 0.95)
        disc_note = " (скидка 5% 🛒)"
    else:
        price = item["price"]
        disc_note = ""
    if char["cash"] < price:
        await query.answer(f"❌ Нужно {price}$, у тебя {char['cash']}$!", show_alert=True); return
    await update_character(user_id, cash=char["cash"] - price)
    await add_item(user_id, item_id)
    await query.answer(f"✅ Взял: {item['name']}! Заплачено: {price}${disc_note}", show_alert=True)

async def buy_crystal_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    item_id = query.data.replace("buyc_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    item = ITEMS.get(item_id)
    if not item or "diamonds_price" not in item:
        await query.answer("❌ Товар не найден!", show_alert=True); return
    if char["diamonds"] < item["diamonds_price"]:
        await query.answer(f"❌ Нужно {item['diamonds_price']}💎!", show_alert=True); return
    await update_character(user_id, diamonds=char["diamonds"] - item["diamonds_price"])
    await add_item(user_id, item_id)
    await query.answer(f"✅ Взял: {item['name']}!", show_alert=True)

# ============================================================
# ХЕНДЛЕРЫ — АВТОРИТЕТЫ И БРИЛЛИАНТЫ
# ============================================================

async def top_players(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    top = await get_top_players(10)
    medals = ["🥇", "🥈", "🥉"]
    ranks = ["Новобранец","Шестёрка","Бандит","Боевик","Капо","Смотрящий","Авторитет","Положенец","Вор в законе","Крёстный отец"]
    text = "🏆 *Авторитеты города*\n\n"
    for i, (name, cls, level, kills) in enumerate(top):
        m = medals[i] if i < 3 else f"{i+1}."
        rank_title = ranks[min(level - 1, len(ranks) - 1)]
        text += f"{m} *{name}* — {rank_title} | 💀{kills}\n"
    if not top:
        text += "Пусто. Стань первым."
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=back_kb("main_menu"))

async def diamonds_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if query:
        await query.answer()
    rows = [[InlineKeyboardButton(f"{p['label']} — ⭐{p['stars']}", callback_data=f"buystars_{i}")] for i, p in enumerate(DIAMOND_PACKAGES)]
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])
    text = "💎 *Бриллианты*\n\nДля покупки элитного снаряжения.\nОплата через Telegram Stars.\n\nВыбери пакет:"
    if query:
        await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))
    else:
        await update.message.reply_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))

async def buy_stars(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    idx = int(query.data.replace("buystars_", ""))
    pkg = DIAMOND_PACKAGES[idx]
    stars    = pkg["stars"]
    diamonds = pkg["diamonds"]
    label    = pkg["label"]
    text = "💎 *Подтверди покупку*\n\n" + label + "\n" + f"Стоимость: ⭐ {stars} Telegram Stars\n" + f"Получишь: 💎 {diamonds} бриллиантов\n\nПосле нажатия «Купить» откроется окно оплаты Telegram."
    await _edit_text(query,
        text,
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"💳 Купить — ⭐{stars}", callback_data=f"confirm_stars_{idx}")],
            [InlineKeyboardButton("❌ Отменить", callback_data="diamonds")],
        ])
    )

async def confirm_stars(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    idx = int(query.data.replace("confirm_stars_", ""))
    pkg = DIAMOND_PACKAGES[idx]
    stars    = pkg["stars"]
    diamonds = pkg["diamonds"]
    label    = pkg["label"]
    await context.bot.send_invoice(
        chat_id=update.effective_user.id,
        title=label,
        description=f"{diamonds} бриллиантов для игры Мафиози",
        payload=f"diamonds_{idx}_{update.effective_user.id}",
        currency="XTR",
        prices=[LabeledPrice(label=label, amount=stars)],
    )
    rows = []
    for i, p in enumerate(DIAMOND_PACKAGES):
        lbl = p['label']; sts = p['stars']
        rows.append([InlineKeyboardButton(f"{lbl} — ⭐{sts}", callback_data=f"buystars_{i}")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])
    await _edit_text(query,"💎 *Бриллианты*\n\nОкно оплаты отправлено выше 👆\n\nВыбери пакет:", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))
async def cancel_invoice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Удаляет сообщение с инвойсом (отмена покупки)."""
    query = update.callback_query
    await query.answer("Покупка отменена.")
    try:
        await query.message.delete()
    except Exception:
        pass

async def precheckout(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.pre_checkout_query.answer(ok=True)

async def successful_payment(update: Update, context: ContextTypes.DEFAULT_TYPE):
    payload = update.message.successful_payment.invoice_payload
    parts   = payload.split("_")
    kind    = parts[0]   # "diamonds" or "cash"
    idx     = int(parts[1])
    user_id = update.effective_user.id
    char    = await get_character(user_id)
    kb      = await contacts_kb(user_id)
    if kind == "cash":
        pkg   = CASH_PACKAGES[idx]
        new_c = char["cash"] + pkg["cash"]
        await update_character(user_id, cash=new_c)
        await update.message.reply_text(
            f"💵 *Сделка прошла.*\n\n+{pkg['cash']} баксов!\nИтого: {new_c} 💵",
            parse_mode="Markdown", reply_markup=kb
        )
    else:
        pkg   = DIAMOND_PACKAGES[idx]
        new_d = char["diamonds"] + pkg["diamonds"]
        await update_character(user_id, diamonds=new_d)
        await update.message.reply_text(
            f"💎 *Сделка прошла.*\n\n+{pkg['diamonds']} бриллиантов!\nИтого: {new_d} 💎",
            parse_mode="Markdown", reply_markup=kb
        )

CASINO_DATA = {
    "market":  {
        "name": "🎰 Подвальный зал",
        "desc": "Мутные личности, грязные карты, табачный дым. Можно разбогатеть. Или уйти ни с чем.",
        "weapon": "knuckles",
    },
    "port":    {
        "name": "🎰 Портовый притон",
        "desc": "Прямо в трюме старого сухогруза. Крупье — бывший боцман. Ставки принимает молча.",
        "weapon": "chain",
    },
    "casino":  {
        "name": "🎰 Казино «Золотой Туз»",
        "desc": "Хрустальные люстры, живая музыка и рулетка под охраной. Это уже серьёзно.",
        "weapon": "tt_pistol",
    },
    "factory": {
        "name": "🎰 Подпольный тотализатор",
        "desc": "В заброшенном цехе. Охраны нет — сам смотри за карманами.",
        "weapon": "shotgun",
    },
    "mansion": {
        "name": "🎰 Частный игорный клуб",
        "desc": "Только для своих. Ставки высокие, призы — серьёзные.",
        "weapon": "ak74",
    },
}

ROULETTE_BET = 50  # фиксированная ставка

# ============================================================
# БАНДА
# ============================================================

GANG_MAX               = 100
GANG_ENCOUNTER_COOLDOWN = 240     # 4 минуты между случайными встречами

def calc_gang_max(owned_prop: list) -> int:
    """Максимальный размер банды с учётом купленного имущества."""
    bonus = sum(STATUS_ITEMS.get(i, {}).get("gang_bonus", 0) for i in owned_prop)
    return GANG_MAX + bonus
GANG_JOIN_CHANCE        = 0.20    # 20% шанс вступить за деньги
GANG_JOIN_CHANCE_PILL   = 0.25    # 25% шанс вступить за аптечку
GANG_COLLECT_COOLDOWN   = 86400   # 24 часа (один сбор в сутки)
GANG_HELP_CASH          = 15      # стоимость помощи деньгами
MERCENARY_BUY_COST      = 100     # цена найма наёмника на чёрном рынке
FRIEND_COLLECT_COOLDOWN = 86400   # 24ч между сборами с одного друга

RANKS = ["Новобранец","Шестёрка","Бандит","Боевик","Капо",
         "Смотрящий","Авторитет","Положенец","Вор в законе","Крёстный отец"]

def friend_daily_income(level: int) -> int:
    """Доход в день от друга в зависимости от его уровня.
    Ур.1 = $100, каждый следующий +50$. Ур.10 = $550.
    """
    return 100 + (min(level, 10) - 1) * 50


RANDOM_NAMES = [
    "Витёк","Серёга","Колян","Димон","Пашка","Вася","Женёк",
    "Толян","Гришка","Петруха","Санёк","Лёха","Борян","Михась",
    "Фёдор","Рустам","Тимур","Жека","Степан","Андрюха","Ильяс",
    "Стас","Марат","Валера","Костя","Руслан","Борис","Давид",
]

# max_count: сколько таких можно в банде (999 = неограниченно)
# is_merc: гибнет при побеге/поражении
# unique: только один в банде
GANG_ROLES = {
    "mercenary": {
        "emoji": "🔫", "title": "Хулиган", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "боец-расходник, гибнет в бою",
        "battle_passive": "🔄 Авто-контратакует после каждого удара босса",
        "battle_active":  "⚔️ Удар — атака без ответки врага (кд: 1 ход)",
    },
    "bruiser": {
        "emoji": "💪", "title": "Здоровяк", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "много HP, меньше урон — идеальный щит",
        "battle_passive": "🛡 Снижает урон босса на 8% пока жив (несколько = суммируется)",
        "battle_active":  "🛡 Прикрыть — берёт следующий удар босса на себя (кд: 3 хода)",
    },
    "sniper": {
        "emoji": "🔪", "title": "Отморозок", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "жёсткий урон, мало HP — бьёт первым",
        "battle_passive": "— (только активная способность)",
        "battle_active":  "🎯 Прицел — x2.5 урона одним выстрелом (кд: 3 хода)",
    },
    "bomber": {
        "emoji": "💣", "title": "Подрывник", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "граната — огромный урон за 1 ход",
        "battle_passive": "— (только активная способность)",
        "battle_active":  "💥 ВЗРЫВ! — гибнет, наносит 60-80% HP босса (одноразово)",
    },
    "medic": {
        "emoji": "🏥", "title": "Медик", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "восстанавливает HP союзников в бою",
        "battle_passive": "💊 Авто-лечит тебя на 10-15 HP каждые 3 хода",
        "battle_active":  "🩹 Лечить — восстанавливает 20-30 HP (кд: 2 хода)",
    },
    "scout": {
        "emoji": "🕵️", "title": "Разведчик", "max_count": 999, "is_merc": True, "reward_item": None,
        "reward_desc": "снижает точность врага",
        "battle_passive": "👁 15% шанс что босс промахнётся пока Разведчик жив",
        "battle_active":  "💨 Дымовуха — 40% шанс пропустить следующий удар (кд: 3 хода)",
    },
}

# Только наёмники
SPECIALIST_ROLES = []

EVENT_PEOPLE = [
    {"type": "wounded", "emoji": "🤕", "desc": "раненый мужик лежит у стены"},
    {"type": "drunk",   "emoji": "🍺", "desc": "пьяный бродяга спит на лавке"},
    {"type": "strange", "emoji": "🤔", "desc": "странный тип жмётся в тени"},
]

# Таблица призов рулетки: (тип, значение, шанс, текст выигрыша)
ROULETTE_PRIZES = [
    ("cash",   10,               12.0, "💵 Кейс с деньгами: *+10$*"),
    ("cash",   20,                8.0, "💵 Кейс с деньгами: *+20$*"),
    ("cash",   30,                6.0, "💵 Кейс с деньгами: *+30$*"),
    ("cash",   40,                5.0, "💵 Кейс с деньгами: *+40$*"),
    ("cash",   50,                4.0, "💵 Кейс с деньгами: *+50$*"),
    ("cash",   60,                3.0, "💵 Кейс с деньгами: *+60$*"),
    ("cash",   70,                2.5, "💵 Кейс с деньгами: *+70$*"),
    ("cash",   80,                2.0, "💵 Кейс с деньгами: *+80$*"),
    ("cash",   90,                1.5, "💵 Кейс с деньгами: *+90$*"),
    ("cash",  100,                1.0, "💵 Кейс с деньгами: *+100$*"),
    ("item",  "medkit_small",     4.0, "🩹 Малая аптечка!"),
    ("item",  "energy_drink",     3.0, "⚡ Энергетик!"),
    ("item",  "medkit_medium",    2.0, "🏥 Аптечка!"),
    ("item",  "leather_jacket",   1.0, "🧥 Кожанка!"),
    ("item",  "bulletproof",      0.5, "🦺 Бронежилет!"),
    ("weapon", None,              2.0, None),   # оружие района — подставляем динамически
    ("nothing", None,            42.5, "😶 Ничего. Колесо не в твою сторону."),
]

HOSPITAL_NAMES = {
    "market":  ("🏥 Фельдшерский пункт", "Старый фельдшер Семёныч"),
    "port":    ("🏥 Портовый медпункт",   "Доктор Якорь"),
    "casino":  ("🏥 Частная клиника",     "Доктор Рубин"),
    "factory": ("🏥 Заводской санитар",   "Санитар Петрович"),
    "mansion": ("🏥 Личный врач Дона",    "Профессор Морелли"),
}

async def hospital(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    loc_id = query.data.replace("hospital_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)

    hosp_name, doc_name = HOSPITAL_NAMES.get(loc_id, ("🏥 Больница", "Доктор"))
    heal_cost = 100

    full_hp   = char["hp"] >= char["max_hp"]
    full_mana = char["mana"] >= char["max_mana"]

    if full_hp and full_mana:
        await _edit_text(query,
            f"{hosp_name}\n\n"
            f"_{doc_name} смотрит на тебя с прищуром._\n"
            f"_«Здоров как бык. Нечего тут делать.»_\n\n"
            f"❤️ {char['hp']}/{char['max_hp']} | ⚡ {char['mana']}/{char['max_mana']}",
            parse_mode="Markdown",
            reply_markup=back_kb(f"location_{loc_id}")
        )
        return

    hp_missing   = char["max_hp"]   - char["hp"]
    mana_missing = char["max_mana"] - char["mana"]

    await _edit_text(query,
        f"{hosp_name}\n\n"
        f"_{doc_name} принимает всех. Без лишних вопросов._\n\n"
        f"❤️ HP: {char['hp']}/{char['max_hp']} (не хватает {hp_missing})\n"
        f"⚡ Энергия: {char['mana']}/{char['max_mana']} (не хватает {mana_missing})\n\n"
        f"💵 Полное восстановление: *{heal_cost}$*\n"
        f"У тебя: {char['cash']}$",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"💊 Лечиться за {heal_cost}$", callback_data=f"hospital_heal_{loc_id}")],
            [InlineKeyboardButton("⬅️ Назад", callback_data=f"location_{loc_id}")],
        ])
    )

async def hospital_heal(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    loc_id = query.data.replace("hospital_heal_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    heal_cost = 100

    if char["hp"] >= char["max_hp"] and char["mana"] >= char["max_mana"]:
        await query.answer("Ты уже в норме!", show_alert=True)
        return

    if char["cash"] < heal_cost:
        await query.answer(f"❌ Нет денег! Нужно {heal_cost}$, у тебя {char['cash']}$", show_alert=True)
        return

    _, doc_name = HOSPITAL_NAMES.get(loc_id, ("🏥 Больница", "Доктор"))

    await update_character(user_id,
        hp=char["max_hp"],
        mana=char["max_mana"],
        cash=char["cash"] - heal_cost
    )

    heal_phrases = [
        "Молча поставил капельницу. Через час ты как новый.",
        "«Не спрашиваю откуда синяки» — и взял деньги.",
        "Укол, перевязка, таблетки. Медицина творит чудеса за наличные.",
        "Зашил что надо и не задал ни одного вопроса.",
    ]

    await _edit_text(query,
        f"🏥 *Выписан*\n\n"
        f"_{doc_name}: {random.choice(heal_phrases)}_\n\n"
        f"❤️ {char['max_hp']}/{char['max_hp']} ✅\n"
        f"⚡ {char['max_mana']}/{char['max_mana']} ✅\n\n"
        f"💵 Заплачено: {heal_cost}$ | Остаток: {char['cash'] - heal_cost}$",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
            [InlineKeyboardButton("🏠 В меню",   callback_data="main_menu")],
        ])
    )

# ============================================================
# ХЕНДЛЕРЫ — КАЗИНО
# ============================================================

async def casino_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    loc_id = query.data.replace("casino_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    casino = CASINO_DATA[loc_id]
    weapon = ITEMS[casino["weapon"]]

    await _edit_text(query,
        f"{casino['name']}\n\n"
        f"_{casino['desc']}_\n\n"
        f"🎯 *Джекпот района:* {weapon['name']} ({weapon['desc']})\n\n"
        f"🎰 Ставка: *{ROULETTE_BET}$*\n"
        f"Можно выбить: оружие, аптечки, броню, энергетики или кейс с рублями.\n"
        f"Шанс остаться ни с чем — тоже есть.\n\n"
        f"💵 У тебя: {char['cash']}$",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"🎰 Крутить рулетку — {ROULETTE_BET}$", callback_data=f"roulette_{loc_id}")],
            [InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")],
        ])
    )

async def casino_spin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    loc_id = query.data.replace("roulette_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    casino = CASINO_DATA[loc_id]

    if char["cash"] < ROULETTE_BET:
        await query.answer(f"❌ Нужно {ROULETTE_BET}$, у тебя {char['cash']}$", show_alert=True)
        return

    new_cash = char["cash"] - ROULETTE_BET
    await update_character(user_id, cash=new_cash)

    # Крутим рулетку
    total_weight = sum(p[2] for p in ROULETTE_PRIZES)
    roll = random.uniform(0, total_weight)
    cumulative = 0.0
    result = ROULETTE_PRIZES[-1]
    for prize in ROULETTE_PRIZES:
        cumulative += prize[2]
        if roll <= cumulative:
            result = prize
            break

    prize_type, prize_val, _, prize_text = result

    spin_anim = random.choice([
        "🎰 _Колесо крутится..._",
        "🎰 _Барабаны вращаются..._",
        "🎰 _Замедляется..._",
    ])

    back_kb_casino = InlineKeyboardMarkup([
        [InlineKeyboardButton(f"🎰 Ещё раз — {ROULETTE_BET}$", callback_data=f"roulette_{loc_id}")],
        [InlineKeyboardButton("⬅️ К казино", callback_data=f"casino_{loc_id}")],
    ])

    if prize_type == "nothing":
        lose_msg = random.choice([
            "Колесо остановилось. Пусто.",
            "Не повезло. Может, в следующий раз.",
            "Крупье равнодушно смотрит как ты уходишь.",
            "Ничего. Казино всегда в плюсе.",
            "Выигрыша нет. Такое бывает.",
        ])
        await _edit_text(query,
            f"{casino['name']}\n\n{spin_anim}\n\n"
            f"😶 *{lose_msg}*\n\n"
            f"💸 Потрачено: {ROULETTE_BET}$ | 💵 Остаток: {new_cash}$",
            parse_mode="Markdown",
            reply_markup=back_kb_casino
        )
        return

    win_msg = random.choice([
        "Фортуна сегодня на твоей стороне.",
        "Колесо крутанулось в твою пользу.",
        "Повезло. Не зарывайся.",
    ])

    if prize_type == "cash":
        final_cash = new_cash + prize_val
        await update_character(user_id, cash=final_cash)
        net = prize_val - ROULETTE_BET
        net_text = f"(+{net}$ чистыми)" if net >= 0 else f"({net}$ чистыми)"
        result_line = f"💵 *Кейс с деньгами! +{prize_val}$* {net_text}"

    elif prize_type == "item":
        await add_item(user_id, prize_val)
        item = ITEMS[prize_val]
        result_line = f"🎁 *Выпало: {item['name']}!*\n_{item['desc']}_"
        final_cash = new_cash

    elif prize_type == "weapon":
        weapon_id = casino["weapon"]
        inv = await get_inventory(user_id)
        if weapon_id in inv:
            bonus = 150
            final_cash = new_cash + bonus
            await update_character(user_id, cash=final_cash)
            result_line = (f"🎯 *Джекпот! Но {ITEMS[weapon_id]['name']} уже есть.*\n"
                           f"Казино компенсирует: +{bonus}$")
        else:
            await add_item(user_id, weapon_id)
            w = ITEMS[weapon_id]
            result_line = (f"🏆 *ДЖЕКПОТ! {w['name']}!*\n"
                           f"_{w['desc']}_\n\nКрупье аплодирует.")
            final_cash = new_cash

    await _edit_text(query,
        f"{casino['name']}\n\n{spin_anim}\n\n"
        f"✨ *{win_msg}*\n\n"
        f"{result_line}\n\n"
        f"💰 Остаток: {final_cash}$",
        parse_mode="Markdown",
        reply_markup=back_kb_casino
    )

async def locked_cb(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.callback_query.answer("🔒 Район закрыт. Повысь ранг.", show_alert=True)

async def track_cb(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Выследить босса — пока в разработке, показываем заглушку."""
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    loc_id = query.data.replace("track_", "")
    loc = LOCATIONS.get(loc_id, {})
    boss_id = LOCATION_MAIN_BOSS.get(loc_id)
    boss = BOSSES.get(boss_id, {})
    await _edit_text(query,
        f"🕵️ *Слежка — {loc.get('name', loc_id)}*\n\n"
        f"Цель: *{boss.get('name', '?')}* — {boss.get('title', '')}\n\n"
        f"_Следопыты изучают маршруты. Функция скоро будет доступна._\n\n"
        f"Используй *Информатора* в банде — он найдёт босса с 5% шансом каждый день.",
        parse_mode="Markdown",
        reply_markup=back_kb(f"location_{loc_id}")
    )

# ============================================================
# ХЕНДЛЕРЫ — СЛУЧАЙНЫЕ ВСТРЕЧИ
# ============================================================

async def encounter_action(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    action = query.data
    user_id = update.effective_user.id
    char = await get_character(user_id)

    if action.startswith("enc_skip_"):
        loc_id = action.replace("enc_skip_", "")
        context.user_data.pop("encounter", None)
        await _edit_text(query,
            "😤 Ты прошёл мимо. Может, зря.\n\n_Он смотрел тебе вслед._",
            parse_mode="Markdown",
            reply_markup=back_kb(f"location_{loc_id}")
        )
        return

    enc = context.user_data.get("encounter")
    if not enc:
        await _edit_text(query,"Встреча уже позади.", reply_markup=await contacts_kb(user_id))
        return

    loc_id = enc["loc"]
    p_name = enc["name"]
    p_role = enc["role"]
    role_info = GANG_ROLES[p_role]

    if action == "enc_cash":
        if char["cash"] < GANG_HELP_CASH:
            await _edit_text(query,
                f"❌ Недостаточно денег!\n\nНужно: *${GANG_HELP_CASH}*, у тебя: *${char['cash']}*",
                parse_mode="Markdown",
                reply_markup=back_kb(f"location_{loc_id}")
            )
            return
        await update_character(user_id, cash=char["cash"] - GANG_HELP_CASH)
        char = await get_character(user_id)
        help_text = f"Ты дал {p_name} ${GANG_HELP_CASH}."
    else:  # enc_pill
        inv = await get_inventory(user_id)
        if "medkit_small" not in inv:
            await _edit_text(query,
                "❌ Аптечек нет! Купи аптечку на чёрном рынке.",
                reply_markup=back_kb(f"location_{loc_id}")
            )
            return
        await remove_item(user_id, "medkit_small")
        char = await get_character(user_id)
        help_text = f"Ты дал {p_name} таблетку."

    context.user_data.pop("encounter", None)
    gang = await get_gang(user_id)
    owned_prop_ea = await get_property(user_id)
    gang_max_ea   = calc_gang_max(owned_prop_ea)

    # Проверяем уникальность роли
    roles_taken = {m["role"] for m in gang}
    role_limit = role_info["max_count"]
    role_count = sum(1 for m in gang if m["role"] == p_role)
    can_join = (len(gang) < gang_max_ea) and (role_count < role_limit)

    join_chance = GANG_JOIN_CHANCE_PILL if action == "enc_pill" else GANG_JOIN_CHANCE
    if can_join and random.random() < join_chance:
        await add_gang_member(user_id, p_name, p_role)
        join_phrases = [
            f"«Слушай… ты нормальный. Я с тобой.»",
            f"«Не забуду этого. Считай — я твой.»",
            f"«Долг платежом красен. Я в деле.»",
        ]
        merc_note = "\n\n⚠️ _Наёмник — расходник. Гибнет при побеге или поражении в бою._" if GANG_ROLES.get(p_role, {}).get("is_merc") else ""
        await _edit_text(query,
            f"🤝 *{p_name} вступил в банду!*\n\n"
            f"{help_text}\n\n"
            f"_{random.choice(join_phrases)}_\n\n"
            f"{role_info['emoji']} Роль: *{role_info['title']}*\n"
            f"📦 Умение: {role_info['reward_desc']}\n"
            f"👥 В банде: {len(gang)+1}/{gang_max_ea}{merc_note}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("👥 Посмотреть банду", callback_data="gang_menu")],
                [InlineKeyboardButton("⬅️ К району",         callback_data=f"location_{loc_id}")],
            ])
        )
    else:
        reason = ""
        if not can_join and len(gang) >= gang_max_ea:
            reason = "\n_Банда полная — нет места._"
        elif not can_join and role_count >= role_limit:
            reason = f"\n_{role_info['title']} уже есть в банде._"
        no_join = [
            "Он поблагодарил и растворился в толпе.",
            "Кивнул, пробормотал «спасибо» и ушёл.",
            "Взял помощь и исчез за углом.",
        ]
        await _edit_text(query,
            f"🤷 *Не вышло*\n\n{help_text}\n\n_{random.choice(no_join)}_{reason}",
            parse_mode="Markdown",
            reply_markup=back_kb(f"location_{loc_id}")
        )

# ============================================================
# ХЕНДЛЕРЫ — БАНДА
# ============================================================

async def gang_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    if await try_random_encounter(update, context):
        return
    gang = await get_gang(user_id)
    char = await get_character(user_id)
    friends = await get_friends(user_id)
    owned_prop_gm = await get_property(user_id)
    gang_max_gm   = calc_gang_max(owned_prop_gm)
    now = int(time.time())

    # Подсчёт доступных наград от друзей
    friends_ready = 0
    for f in friends:
        last_c = await get_friend_collect(user_id, f["telegram_id"])
        if (now - last_c) >= FRIEND_COLLECT_COOLDOWN:
            friends_ready += friend_daily_income(f["level"])

    friend_line = ""
    if friends:
        friend_line = f"\n👥 Друзей в банде: *{len(friends)}*"
        if friends_ready > 0:
            friend_line += f" | 💰 К сбору: *${friends_ready}*"

    if not gang:
        await _edit_text(query,
            "👥 *Моя банда*\n\n"
            "_Пока один. Ходи по районам — иногда встречаются нужные люди._\n\n"
            "🔫 *Наёмника* можно купить на Чёрном рынке за $100\n"
            "⏰ Случайные встречи раз в 6 часов: наёмник (15%)\n\n"
            "👥 *Приглашай друзей* — получай с каждого до $550/день!\n"
            "Нажми «Друзья» чтобы получить реф-ссылку." + friend_line,
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("🏴 Мои районы",     callback_data="my_districts")],
                [InlineKeyboardButton("👥 Друзья в банде", callback_data="gang_friends")],
                [InlineKeyboardButton("📖 Роли банды",     callback_data="gang_roles_info")],
                [InlineKeyboardButton("⬅️ Назад",          callback_data="main_menu")],
            ])
        )
        return

    mercs = [m for m in gang if GANG_ROLES.get(m.get("role"), {}).get("is_merc") or m.get("type") == "mercenary"]

    text = f"👥 *Моя банда* — {len(gang)}/{gang_max_gm}{friend_line}\n\n"

    if mercs:
        char_for_hp = await get_character(user_id)
        text += f"⚔️ *Наёмники ({len(mercs)}) — участвуют в боях:*\n"
        for m in mercs:
            ri     = GANG_ROLES[m["role"]]
            cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
            max_hp = cls["hp_base"] + char_for_hp["level"] * cls["hp_per_lvl"]
            cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
            cur_hp = max(0, min(cur_hp, max_hp))
            hp_bar = "❤️" if cur_hp >= max_hp * 0.6 else ("🟡" if cur_hp >= max_hp * 0.3 else "🔴")
            text += f"{ri['emoji']} {m['member_name']} — *{ri['title']}* {hp_bar} {cur_hp}/{max_hp} HP\n"

    rows = []

    # Кнопка «Наёмники» — отдельный экран
    if mercs:
        inv_gm = await get_inventory(user_id)
        has_medkit_badge = (inv_gm.get("medkit_small", 0) or 0) > 0
        # Показываем кол-во раненых
        char_for_badge = await get_character(user_id)
        wounded = sum(
            1 for m in mercs
            if (m.get("current_hp") or (MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])["hp_base"] + char_for_badge["level"] * MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])["hp_per_lvl"]))
            < (MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])["hp_base"] + char_for_badge["level"] * MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])["hp_per_lvl"])
        )
        badge = f" 🩹{wounded} ранен." if wounded and has_medkit_badge else ""
        rows.append([InlineKeyboardButton(
            f"⚔️ Наёмники ({len(mercs)}){badge}", callback_data="gang_mercs_screen"
        )])

    rows.append([InlineKeyboardButton("🏴 Мои районы",     callback_data="my_districts")])
    rows.append([InlineKeyboardButton("👥 Друзья в банде" + (f" (💰 ${friends_ready})" if friends_ready else ""),
                                       callback_data="gang_friends")])
    rows.append([InlineKeyboardButton("📖 Что делают бойцы?", callback_data="gang_roles_info")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def gang_mercs_screen(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Экран «Наёмники» — список наёмников с HP и кнопкой лечить."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id

    gang = await get_gang(user_id)
    char = await get_character(user_id)
    inv  = await get_inventory(user_id)
    has_medkit = (inv.get("medkit_small", 0) or 0) > 0

    def _is_merc(m):
        return (GANG_ROLES.get(m.get("role"), {}).get("is_merc")
                or m.get("type") == "mercenary")
    mercs = [m for m in gang if _is_merc(m)]

    if not mercs:
        await _edit_text(query,
            "⚔️ *Наёмники*\n\n_Наёмников нет. Купи на Чёрном рынке за $100._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data="gang_menu")]])
        )
        return

    # Охрана районов
    guard_map = {}
    for loc_id_g, loc_data in LOCATIONS.items():
        ctrl_g = await get_district_control(loc_id_g)
        if ctrl_g and ctrl_g.get("telegram_id") == user_id:
            g_ids = json.loads(ctrl_g.get("guard_json") or "[]")
            for gid in g_ids:
                guard_map[gid] = loc_data["name"]

    text = "⚔️ *Наёмники*\n\n"
    rows = []
    for m in mercs:
        ri     = GANG_ROLES[m["role"]]
        cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
        max_hp = cls["hp_base"] + char["level"] * cls["hp_per_lvl"]
        cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
        cur_hp = max(0, min(cur_hp, max_hp))
        guard_label = f" 🛡 {guard_map[m['id']]}" if m["id"] in guard_map else ""
        hp_icon = "❤️" if cur_hp >= max_hp else ("🟡" if cur_hp > max_hp * 0.3 else ("🔴" if cur_hp > 0 else "💀"))
        text += f"{ri['emoji']} *{m['member_name']}* — {ri['title']} {hp_icon} {cur_hp}/{max_hp} HP{guard_label}\n"
        row = [InlineKeyboardButton(
            f"{ri['emoji']} {m['member_name']} {hp_icon} {cur_hp}/{max_hp}",
            callback_data=f"gang_view_{m['id']}"
        )]
        if cur_hp < max_hp and has_medkit:
            row.append(InlineKeyboardButton("🩹 Лечить", callback_data=f"merc_heal_{m['id']}"))
        rows.append(row)

    if not has_medkit:
        text += "\n_Нет аптечек для лечения. Купи малую аптечку в магазине._"
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="gang_menu")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def my_districts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Экран «Мои районы» — список подконтрольных территорий и сбор дохода."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    districts = await get_my_districts(user_id)
    now = time.time()

    if not districts:
        await _edit_text(query,
            "🏴 *Мои районы*\n\n"
            "_Пока ни одного. Убей главного босса района чтобы захватить его._\n\n"
            "Главные боссы:\n"
            + "\n".join(
                f"• {LOCATIONS[loc]['name']} — {BOSSES[LOCATION_MAIN_BOSS[loc]]['name']}"
                for loc in LOCATIONS
            ),
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("⬅️ Назад", callback_data="gang_menu")]
            ])
        )
        return

    text = "🏴 *Мои районы*\n\n"
    rows = []
    total_ready = 0

    for d in sorted(districts, key=lambda x: list(LOCATIONS.keys()).index(x["location_id"])):
        loc_id   = d["location_id"]
        loc      = LOCATIONS[loc_id]
        income   = DISTRICT_INCOME[loc_id]
        remaining = income["cooldown"] - (now - (d["last_collected"] or 0))
        if remaining <= 0:
            status = "💰 Готово к сбору!"
            total_ready += income["cash_max"]
            rows.append([InlineKeyboardButton(
                f"💰 {loc['name']} — забрать {income['cash_min']}–{income['cash_max']}$",
                callback_data=f"collect_district_{loc_id}"
            )])
        else:
            hrs  = int(remaining // 3600)
            mins = int((remaining % 3600) // 60)
            status = f"⏳ через {hrs}ч {mins}м"
        text += f"{loc['name']} | {income['cash_min']}–{income['cash_max']}$/день | {status}\n"

    if total_ready:
        text += f"\n💵 *Доступно к сбору: ~${total_ready}*"
    else:
        text += "\n_Все доходы уже собраны. Заходи позже._"

    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="gang_menu")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def gang_view(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    member_id = int(query.data.replace("gang_view_", ""))
    user_id = update.effective_user.id
    char = await get_character(user_id)
    now = int(time.time())

    gang = await get_gang(user_id)
    member = next((m for m in gang if m["id"] == member_id), None)
    if not member:
        await _edit_text(query,"Такого в банде уже нет.", reply_markup=back_kb("gang_menu"))
        return

    ri = GANG_ROLES[member["role"]]

    btns = []
    btns.append([InlineKeyboardButton("🚪 Исключить", callback_data=f"gang_kick_{member_id}")])
    btns.append([InlineKeyboardButton("⬅️ К банде", callback_data="gang_menu")])

    await _edit_text(query,
        f"{ri['emoji']} *{member['member_name']}* — {ri['title']}\n"
        f"_{ri['reward_desc']}_\n\n⚠️ _Гибнет при побеге или поражении_",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(btns)
    )


async def intel_attack(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Атака на босса по наводке информатора."""
    query = update.callback_query
    await query.answer()
    loc_id = query.data.replace("intel_attack_", "")
    user_id = update.effective_user.id
    char = await get_character(user_id)
    await _start_tracked_boss_fight(query, user_id, loc_id, char)

async def gang_kick(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    member_id = int(query.data.replace("gang_kick_", ""))
    user_id = update.effective_user.id
    gang = await get_gang(user_id)
    member = next((m for m in gang if m["id"] == member_id), None)
    if not member:
        await _edit_text(query,"Такого в банде уже нет.", reply_markup=back_kb("gang_menu"))
        return
    ri = GANG_ROLES[member["role"]]
    await _edit_text(query,
        f"🚪 Исключить *{member['member_name']}* ({ri['title']})?\n\nЭто нельзя отменить.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("✅ Да", callback_data=f"gang_kick_do_{member_id}")],
            [InlineKeyboardButton("❌ Отмена", callback_data=f"gang_view_{member_id}")],
        ])
    )

async def gang_kick_do(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    member_id = int(query.data.replace("gang_kick_do_", ""))
    gang = await get_gang(update.effective_user.id)
    member = next((m for m in gang if m["id"] == member_id), None)
    name = member["member_name"] if member else "?"
    await remove_gang_member(member_id)
    await _edit_text(query,
        f"🚪 *{name} исключён.*\n\n_Ушёл не попрощавшись._",
        parse_mode="Markdown",
        reply_markup=back_kb("gang_menu")
    )

async def gang_nocollect(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.callback_query.answer("Сегодня уже собирал. Приходи завтра.", show_alert=True)

async def gang_buy_merc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Купить наёмника на чёрном рынке."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    gang = await get_gang(user_id)
    owned_prop_bm = await get_property(user_id)
    gang_max_bm   = calc_gang_max(owned_prop_bm)

    if len(gang) >= gang_max_bm:
        await query.answer("❌ Банда полная! Сначала исключи кого-то.", show_alert=True)
        return
    if char["cash"] < MERCENARY_BUY_COST:
        await query.answer(f"❌ Нужно ${MERCENARY_BUY_COST}, у тебя ${char['cash']}", show_alert=True)
        return

    name = random.choice(RANDOM_NAMES)
    merc_role = random.choice(list(MERC_CLASSES.keys()))
    role_info = GANG_ROLES[merc_role]
    await update_character(user_id, cash=char["cash"] - MERCENARY_BUY_COST)
    await add_gang_member(user_id, name, merc_role)
    gang = await get_gang(user_id)
    await _edit_text(query,
        f"{role_info['emoji']} *{name} нанят как {role_info['title']}!*\n\n"
        f"_Деньги взял. Вопросов не задавал._\n\n"
        f"📋 {role_info['reward_desc']}\n"
        f"⚠️ Расходник — гибнет при побеге или поражении в бою.\n"
        f"💵 Заплачено: ${MERCENARY_BUY_COST} | Остаток: ${char['cash'] - MERCENARY_BUY_COST}\n"
        f"👥 В банде: {len(gang)}/{gang_max_bm}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("👥 Моя банда", callback_data="gang_menu")],
            [InlineKeyboardButton("⬅️ В магазин", callback_data="shop")],
        ])
    )


# ============================================================
# ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ — БОЙ С ГЛАВНЫМ БОССОМ
# ============================================================

async def _start_tracked_boss_fight(query, user_id: int, loc_id: str, char: dict):
    """Запустить бой с главным боссом района (используется informant intel_attack)."""
    if await get_battle(user_id):
        await query.answer("У тебя уже идёт разборка!", show_alert=True)
        return
    boss_id = LOCATION_MAIN_BOSS[loc_id]
    boss = BOSSES[boss_id]
    await start_battle_db(user_id, loc_id, boss_id)
    eff_atk = get_effective_attack(char)
    eff_def = get_effective_defense(char)
    inv = await get_inventory(user_id)
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
    has_mana = char["mana"] >= SKILLS[char["class"]]["mana_cost"]
    weapon_id = char.get("weapon")
    weapon_line = "🤜 Оружие: Голые кулаки" if not weapon_id else \
        f"Оружие: {ITEMS[weapon_id]['name']} (+{ITEMS[weapon_id].get('attack_bonus', 0)} атака)"
    await _edit_text(query,
        f"🔍 *НАВОДКА СРАБОТАЛА!*\n\n"
        f"💥 *РАЗБОРКА НАЧАЛАСЬ!*\n\n"
        f"На пути встаёт {boss['name']} — _{boss['title']}_\n"
        f"«_{boss['quote']}_»\n\n"
        f"😤 *{boss['name']}*\n"
        f"❤️ {boss['hp']}/{boss['hp']} {hp_bar(boss['hp'], boss['hp'])}\n"
        f"⚔️ Атака босса: {boss['attack']} | 🛡 Защита: {boss['defense']}\n\n"
        f"🤵 *{md(char['name'])}*\n"
        f"❤️ {char['hp']}/{char['max_hp']} {hp_bar(char['hp'], char['max_hp'])}\n"
        f"⚡ {char['mana']}/{char['max_mana']}\n"
        f"⚔️ Твоя атака: {eff_atk} | 🛡 Защита: {eff_def}\n"
        f"{weapon_line}\n\nЧто делаем?",
        parse_mode="Markdown", reply_markup=battle_kb(
            has_mana, has_potions, weapon_id,
            eff_atk=eff_atk, boss_def=boss["defense"],
            skill_mult=SKILLS[char["class"]]["damage_mult"],
            skill_name=SKILLS[char["class"]]["name"],
            cur_mana=char["mana"],
            grenades=(await get_inventory(user_id)).get("grenade", 0),
            molotovs=(await get_inventory(user_id)).get("molotov", 0),
            prop_skills=get_prop_skills(
                json.loads(char.get("owned_property") or "[]"),
                []
            )
        )
    )



# ============================================================
# ХЕНДЛЕРЫ — ДРУЗЬЯ В БАНДЕ
# ============================================================

ROLE_DESCRIPTIONS = {
        "mercenary": (
        "🔫 *Хулиган*\n"
        "Воюет за деньги. Верности ноль, пуля точная.\n\n"
        "⚠️ *Расходник:* погибает при побеге или поражении в бою\n"
        "💰 Найм: $100 на Чёрном рынке или 15% шанс встретить в районе\n"
        "👉 Бери несколько перед серьёзной разборкой."
    ),
    "bruiser": (
        "💪 *Здоровяк*\n"
        "Стена из мышц. Принимает удары вместо тебя.\n\n"
        "⚠️ *Расходник:* погибает при побеге или поражении в бою\n"
        "💪 Много HP, меньше урон."
    ),
    "sniper": (
        "🔪 *Отморозок*\n"
        "Бьёт первым и больно. Но хлипкий.\n\n"
        "⚠️ *Расходник:* погибает при побеге или поражении в бою\n"
        "🎯 Высокий урон, мало HP."
    ),
    "bomber": (
        "💣 *Подрывник*\n"
        "Граната — его аргумент. Один взрыв — огромный урон.\n\n"
        "⚠️ *Расходник:* погибает при побеге или поражении в бою\n"
        "💥 Максимальный урон за ход."
    ),
}


async def gang_roles_info(update, context):
    """Справка по ролям наёмников с боевыми способностями."""
    query = update.callback_query
    await query.answer()

    merc_roles = ["mercenary", "bruiser", "sniper", "bomber", "medic", "scout"]
    lines = ["⚔️ *Бойцы в бою — кто что делает:*\n"]
    for role in merc_roles:
        ri = GANG_ROLES.get(role, {})
        if not ri:
            continue
        lines.append(f"{ri['emoji']} *{ri['title']}*")
        lines.append(f"   🎯 Актив: {ri['battle_active']}")
        lines.append(f"   ✨ Пассив: {ri['battle_passive']}")
        lines.append("")

    lines.append("_🔫 Хулиган, 💪 Здоровяк, 🔪 Отморозок, 💣 Подрывник — на Чёрном рынке $100_")
    lines.append("_🏥 Медик, 🕵️ Разведчик — редкие, встречаются в районах_")

    rows = [[InlineKeyboardButton("⬅️ К банде", callback_data="gang_menu")]]
    await _edit_text(query, "\n".join(lines), parse_mode="Markdown",
                     reply_markup=InlineKeyboardMarkup(rows))


async def gang_friends_menu(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    friends = await get_friends(user_id)
    now = int(time.time())

    bot_username = (await context.bot.get_me()).username
    invite_link = f"https://t.me/{bot_username}?start=ref_{user_id}"

    if not friends:
        await _edit_text(query,
            "👥 *Друзья в банде*\n\n"
            "_Ты ещё никого не пригласил._\n\n"
            "За каждого приглашённого друга ты получаешь:\n"
            "💵 *+$300 разово* — когда друг вступает\n"
            "💰 Ежедневный доход по рангу друга:\n\n"
            "🥉 Уровень 1 (Новобранец) — *$100/день*\n"
            "🥈 Уровень 2 (Шестёрка) — *$150/день*\n"
            "🥇 Уровень 3+ (Бандит и выше) — *$200–$550/день*\n\n"
            "⚔️ *Друзья могут участвовать в боях!*\n"
            "_Перед разборкой ты можешь пригласить друзей из банды в отряд._",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("📨 Пригласить друга", url=f"https://t.me/share/url?url={invite_link}&text=Вступай%20в%20мою%20банду%20в%20Мафиози!")],
                [InlineKeyboardButton("🔗 Скопировать ссылку", url=invite_link)],
                [InlineKeyboardButton("⬅️ Назад", callback_data="gang_menu")]
            ])
        )
        return

    text = ("👥 *Друзья в банде*\n\n"
            "⚔️ _Друзей можно брать в бой._\n\n")
    rows = []
    total_ready = 0
    for f in friends:
        last_c  = await get_friend_collect(user_id, f["telegram_id"])
        income  = friend_daily_income(f["level"])
        rank    = RANKS[min(f["level"] - 1, len(RANKS) - 1)]
        ready   = (now - last_c) >= FRIEND_COLLECT_COOLDOWN
        if ready:
            total_ready += income
        status = "✅ Можно собрать" if ready else "⏰ Уже собрал"
        text += f"👤 *{f['name']}* — {rank} (ур.{f['level']}) | ${income}/день | {status}\n"
        if ready:
            rows.append([InlineKeyboardButton(
                f"💵 Забрать с {f['name']} (${income})",
                callback_data=f"gfc_{f['telegram_id']}"
            )])

    if total_ready > 0:
        text += f"\n💰 *Доступно к сбору: ${total_ready}*"
    text += f"\n\n💵 За нового друга: *+$300 разово* + ежедневный доход"

    rows.append([InlineKeyboardButton("📨 Пригласить друга", url=f"https://t.me/share/url?url={invite_link}&text=Вступай%20в%20мою%20банду%20в%20Мафиози!")])
    rows.append([InlineKeyboardButton("🔗 Скопировать ссылку", url=invite_link)])
    rows.append([InlineKeyboardButton("⬅️ К банде", callback_data="gang_menu")])
    await _edit_text(query,
        text, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )


async def gang_friend_collect(update, context):
    query = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    friend_id = int(query.data.replace("gfc_", ""))
    now       = int(time.time())

    last_c = await get_friend_collect(user_id, friend_id)
    if (now - last_c) < FRIEND_COLLECT_COOLDOWN:
        await query.answer("Уже собирал с этого друга сегодня!", show_alert=True)
        return

    friend = await get_character(friend_id)
    if not friend:
        await query.answer("Игрок не найден.", show_alert=True)
        return

    income = friend_daily_income(friend["level"])
    char   = await get_character(user_id)
    await update_character(user_id, cash=char["cash"] + income)
    await set_friend_collect(user_id, friend_id, now)

    rank = RANKS[min(friend["level"] - 1, len(RANKS) - 1)]
    await query.answer(f"💵 +${income} с {friend['name']} ({rank})", show_alert=True)
    await gang_friends_menu(update, context)


async def gang_role_info(update, context):
    query = update.callback_query
    await query.answer()
    role = query.data.replace("gang_role_", "")
    ri   = GANG_ROLES.get(role, {})
    desc = ROLE_DESCRIPTIONS.get(role, "_Описание не найдено._")
    await _edit_text(query,
        desc, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("⬅️ Все роли", callback_data="gang_roles_info")],
            [InlineKeyboardButton("👥 К банде",  callback_data="gang_menu")],
        ])
    )


# ============================================================
# ХЕНДЛЕРЫ — ПОДПИСКА НА КАНАЛ
# ============================================================

async def check_sub(update, context):
    """Кнопка «Я подписался» — повторная проверка подписки."""
    query = update.callback_query
    user_id = update.effective_user.id
    if await is_subscribed(context.bot, user_id):
        await query.answer("✅ Подписка подтверждена!", show_alert=True)
        char = await get_character(user_id)
        if char:
            # Сохраняем флаг — больше не нужно проверять через API
            await update_character(user_id, channel_verified=1)
            await _edit_text(query,
                f"✅ Добро пожаловать, *{md(char['name'])}*!",
                parse_mode="Markdown",
                reply_markup=await contacts_kb(user_id)
            )
        else:
            await _edit_text(query,
                "✅ Подписка подтверждена! Введи /start чтобы начать игру."
            )
    else:
        await query.answer("❌ Ты ещё не подписан на канал!", show_alert=True)


# ============================================================
# ХЕНДЛЕРЫ — ТЮРЬМА
# ============================================================

async def jail_bail(update, context):
    """Выйти из тюрьмы за 1 бриллиант."""
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    if char.get("diamonds", 0) < JAIL_BAIL_DIAMONDS:
        await query.answer(
            f"❌ Нужен {JAIL_BAIL_DIAMONDS} 💎. У тебя {char.get('diamonds',0)}.\n"
            "Купи бриллианты в разделе «Бриллианты».",
            show_alert=True
        )
        return
    new_d = char["diamonds"] - JAIL_BAIL_DIAMONDS
    await update_character(user_id, diamonds=new_d, jail_until=0, wanted_stars=0,
                            hp=char["max_hp"] // 2, mana=char["max_mana"] // 2)
    await _edit_text(query,
        "⚖️ *Адвокат выбил тебя под залог!*\n\n"
        f"Потрачено: {JAIL_BAIL_DIAMONDS} 💎\n"
        "Ты на свободе. Звёзды розыска сняты.\n"
        "❤️ 50% HP | ⚡ 50% Энергии",
        parse_mode="Markdown",
        reply_markup=await contacts_kb(user_id)
    )


async def jail_wait(update, context):
    """Кнопка «ждать» — показывает сколько осталось."""
    query = update.callback_query
    user_id = update.effective_user.id
    char = await get_character(user_id)
    now_ts = int(time.time())
    jail_until = char.get("jail_until", 0) or 0
    mins_left = max(0, (jail_until - now_ts + 59) // 60)
    await query.answer(f"⏳ До выхода: {mins_left} мин. Терпи.", show_alert=True)


# ============================================================
# ХЕНДЛЕРЫ — МОИ СВЯЗИ
# ============================================================

async def my_contacts(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    contacts = await get_contacts(user_id)

    text = "🤝 *Мои связи*\n\n"
    if not contacts:
        text += (
            "😶 _Пока ты никого не встретил на пути._\n\n"
            "Улица молчит. Нужные люди ещё не знают о тебе.\n\n"
            "💡 *Как найти связи?*\n"
            "Побеждай в уличных драках — с каждой победой есть шанс, "
            "что кто-то оставит тебе визитку.\n\n"
            "Кто может выйти на связь:\n"
            "⚖️ *Адвокат* — вытащит из тюрьмы\n"
            "🏠 *Риелтор* — скидка в магазине\n"
            "👮 *Комиссар* — уберёт звезду розыска"
        )
        rows = [[InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")]]
    else:
        text += f"Доступные контакты ({len(contacts)}):\n\n"
        rows = []
        for c in contacts:
            ct = CONTACT_TYPES[c["contact_type"]]
            text += f"{ct['emoji']} *{c['contact_name']}* — {ct['name']}\n_{ct['desc']}_\n\n"
            rows.append([InlineKeyboardButton(
                f"{ct['emoji']} {c['contact_name']}",
                callback_data=f"use_contact_{c['id']}"
            )])
        rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="main_menu")])

    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def _update_contact_used(contact_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE contacts SET used=1 WHERE id=?", (contact_id,))
        await db.commit()


async def use_contact_cb(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    contact_id = int(query.data.replace("use_contact_", ""))

    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM contacts WHERE id=? AND telegram_id=? AND used=0",
            (contact_id, user_id)
        ) as cur:
            row = await cur.fetchone()
    if not row:
        await query.answer("❌ Контакт не найден или уже использован.", show_alert=True)
        return
    contact = dict(row)
    ct_type = contact["contact_type"]
    char = await get_character(user_id)

    if ct_type == "lawyer":
        jail_until = char.get("jail_until", 0) or 0
        if jail_until <= int(time.time()):
            await query.answer("Ты и так на свободе.", show_alert=True); return
        if char["cash"] < LAWYER_CASH_COST:
            await query.answer(f"❌ Нужно ${LAWYER_CASH_COST}.", show_alert=True); return
        await _update_contact_used(contact_id)
        await update_character(user_id, cash=char["cash"] - LAWYER_CASH_COST,
                                jail_until=0, wanted_stars=0,
                                hp=char["max_hp"] // 2, mana=char["max_mana"] // 2)
        await _edit_text(query,
            f"⚖️ *{contact['contact_name']} вытащил тебя!*\n\n"
            f"Потрачено: ${LAWYER_CASH_COST}. Ты свободен.",
            parse_mode="Markdown", reply_markup=await contacts_kb(user_id)
        )

    elif ct_type == "realtor":
        discount_until = int(time.time()) + 24 * 3600
        await _update_contact_used(contact_id)
        await update_character(user_id, gang_discount_until=discount_until)
        await _edit_text(query,
            f"🏠 *{contact['contact_name']} устроил спецпредложение!*\n\n"
            "Скидка *10%* в магазине на *24 часа*.",
            parse_mode="Markdown", reply_markup=await contacts_kb(user_id)
        )

    elif ct_type == "commissioner":
        wanted = char.get("wanted_stars", 0) or 0
        if wanted == 0:
            await query.answer("Звёзд розыска нет.", show_alert=True); return
        if char["cash"] < COMMISSIONER_COST:
            await query.answer(f"❌ Нужно ${COMMISSIONER_COST}.", show_alert=True); return
        await _update_contact_used(contact_id)
        new_stars = max(0, wanted - 1)
        await update_character(user_id, cash=char["cash"] - COMMISSIONER_COST, wanted_stars=new_stars)
        stars_after = "⭐" * new_stars if new_stars > 0 else "нет"
        await _edit_text(query,
            f"👮 *{contact['contact_name']} решил вопрос.*\n\n"
            f"Потрачено: ${COMMISSIONER_COST}\n"
            f"Розыск: {'⭐'*wanted} → {stars_after}",
            parse_mode="Markdown", reply_markup=await contacts_kb(user_id)
        )


# ============================================================
# ХЕНДЛЕРЫ — ИМУЩЕСТВО И СТАТУС
# ============================================================

async def my_property(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    owned = await get_property(user_id)
    status_pts = get_status_points(owned)

    text = f"🏙️ *Моё имущество*\n\n👑 Статус: *{status_pts} очков*\n\n"
    rows = []
    if owned:
        for item_id in owned:
            si = STATUS_ITEMS.get(item_id)
            if not si: continue
            skill_info = f"  🎯 {si['skill_name']}" if si.get("skill_name") else "  _Нет спецатаки_"
            text += f"{si['name']} (+{si['status_pts']} статуса)\n{skill_info}\n\n"
    else:
        text += "_Ничего нет. Купи на чёрном рынке._\n\n"
    text += "💡 Имущество даёт статус и спецатаки в бою (1 раз за бой)."
    rows.append([InlineKeyboardButton("🛒 Купить", callback_data="shop_property")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="character")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def shop_property(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    char = await get_character(user_id)
    owned = await get_property(user_id)

    PROP_DESC = {
        "car":        "Статус +10 | В бою: 🎯 Стрелять из машины (урон ×3) — применяется 1 раз за бой",
        "apartment":  "Статус +15 | Штаб-квартира: ускоряет восстановление HP и маны | 👥 Размер банды +10 (до 110 чел.)",
        "villa":      "Статус +25 | Представительская резиденция | 👥 Размер банды +30 (до 130 чел.)",
        "helicopter": "Статус +30 | В бою: 🎯 Пальнуть из вертолёта (урон ×5) — применяется 1 раз за бой",
        "mansion":    "Статус +50 | Резиденция: +20% к доходу с захваченных районов",
        "yacht":      "Статус +80 | В бою: 🎯 Запустить ракету с яхты (урон ×8) — применяется 1 раз за бой",
    }
    text = (
        "🏙️ *Имущество* — только за 💎\n\n"
        "💎 Бриллианты: {diamonds}\n\n"
        "Имущество даёт очки статуса и уникальные спецатаки в бою.\n"
        "_Спецатаку можно применить 1 раз за бой — она наносит огромный урон!_\n\n"
    ).format(diamonds=char['diamonds'])
    rows = []
    for item_id, si in STATUS_ITEMS.items():
        dp = si["diamonds_price"]
        desc = PROP_DESC.get(item_id, "")
        if item_id in owned:
            text += f"✅ {si['name']}\n_{desc}_\n\n"
        else:
            text += f"{si['name']} — *{dp} 💎*\n_{desc}_\n\n"
            rows.append([InlineKeyboardButton(
                f"Купить {si['name']} — {dp} 💎",
                callback_data=f"buy_prop_{item_id}"
            )])
    rows.append([InlineKeyboardButton("💎 Пополнить бриллианты", callback_data="diamonds")])
    rows.append([InlineKeyboardButton("⬅️ Назад", callback_data="shop")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def buy_prop(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    item_id = query.data.replace("buy_prop_", "")
    si = STATUS_ITEMS.get(item_id)
    if not si:
        await query.answer("❌ Не найдено.", show_alert=True); return
    owned = await get_property(user_id)
    if item_id in owned:
        await query.answer("Уже куплено!", show_alert=True); return
    char = await get_character(user_id)
    dp = si["diamonds_price"]
    if char["diamonds"] < dp:
        await query.answer(f"❌ Нужно {dp} 💎. У тебя {char['diamonds']}.", show_alert=True); return
    await update_character(user_id, diamonds=char["diamonds"] - dp)
    await buy_property_db(user_id, item_id)
    await query.answer(f"✅ {si['name']} куплено!", show_alert=True)
    await shop_property(update, context)


async def sell_prop(update, context):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    item_id = query.data.replace("sell_prop_", "")
    si = STATUS_ITEMS.get(item_id)
    if not si:
        await query.answer("❌ Не найдено.", show_alert=True); return
    owned = await get_property(user_id)
    if item_id not in owned:
        await query.answer("У тебя этого нет.", show_alert=True); return
    refund = si["diamonds_price"] // 2
    char = await get_character(user_id)
    await sell_property_db(user_id, item_id)
    await update_character(user_id, diamonds=char["diamonds"] + refund)
    await query.answer(f"💸 Продано. Возврат: {refund} 💎", show_alert=True)
    await my_property(update, context)


# ============================================================
# ХЕНДЛЕРЫ — ОХРАНА РАЙОНОВ
# ============================================================

async def district_guard_menu(update, context, _loc_id: str = None):
    query = update.callback_query
    await query.answer()
    await _clear_district_photo(context, query.message.chat_id)
    user_id = update.effective_user.id
    loc_id = _loc_id or query.data.replace("district_guard_", "")
    ctrl = await get_district_control(loc_id)
    if not ctrl or ctrl["telegram_id"] != user_id:
        await query.answer("Это не твой район.", show_alert=True); return

    gang = await get_gang(user_id)
    mercs = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    live_ids = {m["id"] for m in mercs}

    # Чистим мёртвых из guard_json
    raw_guard = json.loads(ctrl.get("guard_json") or "[]")
    guard_ids = [gid for gid in raw_guard if gid in live_ids]
    if len(guard_ids) != len(raw_guard):
        await update_district_guard(loc_id, guard_ids)

    loc_name = LOCATIONS[loc_id]["name"]
    guard_count = len(guard_ids)
    text_parts = [
        f"\U0001f3f0 *Охрана: {loc_name}*",
        "",
        f"Охранников: {guard_count}/10",
        "",
        "Нажми на наёмника чтобы поставить/снять с охраны:",
    ]
    text = "\n".join(text_parts)

    rows = []
    for m in mercs:
        ri = GANG_ROLES[m["role"]]
        on_guard = m["id"] in guard_ids
        status = "🛡️" if on_guard else "  "
        rows.append([InlineKeyboardButton(
            f"{status}{ri['emoji']} {m['member_name']} — {ri['title']}",
            callback_data=f"guard_toggle_{loc_id}_{m['id']}"
        )])
    if not mercs:
        text += "_Нет наёмников. Найми их на Чёрном рынке._"
    rows.append([InlineKeyboardButton("⬅️ К району", callback_data=f"location_{loc_id}")])
    await _edit_text(query,text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(rows))


async def guard_toggle(update, context):
    query = update.callback_query
    user_id = update.effective_user.id
    # callback: guard_toggle_{loc_id}_{member_id}
    # rsplit гарантирует правильное разбиение даже если loc_id содержал бы "_"
    without_prefix = query.data.replace("guard_toggle_", "")
    loc_id, member_id_str = without_prefix.rsplit("_", 1)
    member_id = int(member_id_str)

    ctrl = await get_district_control(loc_id)
    if not ctrl or ctrl["telegram_id"] != user_id:
        await query.answer("Это не твой район.", show_alert=True); return

    # Только живые бойцы могут охранять
    gang     = await get_gang(user_id)
    mercs    = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    live_ids = {m["id"] for m in mercs}

    if member_id not in live_ids:
        await query.answer("❌ Этот боец мёртв!", show_alert=True)
        await district_guard_menu(update, context, _loc_id=loc_id)
        return

    # Чистим мёртвых и обновляем
    guard_ids = [gid for gid in json.loads(ctrl.get("guard_json") or "[]") if gid in live_ids]
    if member_id in guard_ids:
        guard_ids.remove(member_id)
        msg = "✅ Снят с охраны"
    else:
        if len(guard_ids) >= 10:
            await query.answer("❌ Максимум 10 охранников.", show_alert=True); return
        guard_ids.append(member_id)
        msg = "🛡 Поставлен на охрану"

    await update_district_guard(loc_id, guard_ids)
    await query.answer(msg)
    await district_guard_menu(update, context, _loc_id=loc_id)


# ============================================================
# RAID DEFEND + MERC HEAL (восстановленные функции)
# ============================================================

async def _show_raid_prep(query, context, user_id: int, raid: dict):
    """Экран подготовки к рейдовому бою."""
    prep   = context.user_data.get("raid_prep", {})
    party  = prep.get("party", [])
    raid_id = prep.get("raid_id", raid["id"])
    gang    = await get_gang(user_id)
    mercs   = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    friends = await get_friends(user_id)
    char    = await get_character(user_id)

    hp_frac  = raid["boss_hp"] / max(1, raid["boss_hp_max"])
    filled   = max(1, int(hp_frac * 10))
    hp_bar   = "🟥" * filled + "⬛" * (10 - filled)
    time_left = max(0, raid["expires_at"] - int(time.time()))
    loc_name  = LOCATIONS.get(raid["location_id"], {}).get("name", raid["location_id"])

    ctrl      = await get_district_control(raid["location_id"])
    guard_ids = json.loads(ctrl.get("guard_json") or "[]") if ctrl else []
    guard_line = f"\n🛡 Охранников района: {len(guard_ids)}" if guard_ids else ""

    party_lines = ""
    if party:
        party_lines = "\n\n👥 *Отряд:*\n"
        for p in party:
            icon = "🔫" if p["type"] == "mercenary" else "👤"
            party_lines += f"{icon} {p['name']} ❤️{p['hp']}\n"

    rows = []
    mercs_in_party = [p for p in party if p["type"] == "mercenary"]
    if mercs and not mercs_in_party:
        rows.append([InlineKeyboardButton(
            f"🔫 Взять наёмников ({len(mercs)})", callback_data="raid_add_mercs"
        )])

    invited_ids = {p["telegram_id"] for p in party if p["type"] == "friend"}
    for f in friends[:5]:
        if f["telegram_id"] not in invited_ids:
            rows.append([InlineKeyboardButton(
                f"📨 Позвать {f['name']} (ур.{f['level']}) на защиту",
                callback_data=f"raid_invite_friend_{f['telegram_id']}"
            )])
        else:
            rows.append([InlineKeyboardButton(
                f"⏳ {f['name']} — ожидает ответа...", callback_data="gang_nocollect"
            )])

    rows.append([InlineKeyboardButton("⚔️ В бой!", callback_data="raid_battle_start")])
    rows.append([InlineKeyboardButton("🏳️ Отступить", callback_data=f"raid_flee_{raid_id}")])

    await _edit_text(query,
        f"🚨 *РЕЙД!* — {loc_name}\n\n"
        f"{raid['gang_emoji']} *{raid['gang_name']}* атакует!\n\n"
        f"👊 HP врага: {hp_bar} {raid['boss_hp']}/{raid['boss_hp_max']}\n"
        f"⚔️ Атака: {raid['boss_atk']} | 🛡 Защита: {raid['boss_def']}\n"
        f"❤️ Твоё HP: {char['hp']}/{char['max_hp']}{guard_line}\n"
        f"⏰ Осталось: {time_left // 60}м {time_left % 60}с\n\n"
        f"_Возьмёшь кого-нибудь с собой?_{party_lines}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(rows)
    )


async def raid_defend(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Начало защиты района от рейда."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    raid_id = int(query.data.replace("raid_defend_", ""))

    raid = await get_raid_by_id(raid_id)
    if not raid or raid["status"] != "active":
        await _edit_text(query,
            "Рейд уже завершён.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data="explore")]])
        )
        return
    if raid["expires_at"] < int(time.time()):
        await close_raid(raid_id, "expired")
        await _apply_raid_loss(raid)
        await _edit_text(query,
            "⏰ Время вышло — район разграблен.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data="explore")]])
        )
        return

    raid_boss = {
        "name":    f"{raid['gang_emoji']} {raid['gang_name']}",
        "title":   "Рейд на район",
        "quote":   "Ваш район наш!",
        "hp":      raid["boss_hp_max"],
        "attack":  raid["boss_atk"],
        "defense": raid["boss_def"],
        "exp":     raid["reward_exp"],
        "cash":    raid["reward_cash"],
        "drop":    None,
    }
    context.user_data["active_raid_boss"] = raid_boss
    context.user_data["raid_prep"] = {"raid_id": raid_id, "party": []}
    await _show_raid_prep(query, context, user_id, raid)


async def raid_add_mercs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Добавляет всех живых наёмников в отряд рейдовой защиты."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    prep    = context.user_data.get("raid_prep")
    if not prep:
        await query.answer("Данные устарели. Нажми на уведомление о рейде снова.", show_alert=True); return

    raid = await get_raid_by_id(prep["raid_id"])
    if not raid or raid["status"] != "active":
        await query.answer("Рейд уже завершён.", show_alert=True); return

    gang  = await get_gang(user_id)
    mercs = [m for m in gang if GANG_ROLES.get(m["role"], {}).get("is_merc")]
    char  = await get_character(user_id)

    on_guard = await get_guard_member_ids(user_id)
    skipped  = []
    for m in mercs:
        if m["id"] in on_guard:
            skipped.append(m["member_name"])
            continue
        cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
        max_hp = cls["hp_base"] + char["level"] * cls["hp_per_lvl"]
        cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
        cur_hp = max(1, min(cur_hp, max_hp))
        prep["party"].append({
            "type":    "mercenary",
            "gang_id": m["id"],
            "name":    m["member_name"],
            "role":    m["role"],
            "hp":      cur_hp,
            "max_hp":  max_hp,
            "alive":   True,
        })
    if skipped:
        names = ", ".join(skipped)
        await query.answer(
            f"⚠️ {names} — на охране района, не взяты в бой.",
            show_alert=True
        )
    context.user_data["raid_prep"] = prep
    await _show_raid_prep(query, context, user_id, raid)


async def raid_battle_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Запускает WebApp-бой для защиты от рейда."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    prep    = context.user_data.get("raid_prep")
    if not prep:
        await query.answer("Данные устарели. Нажми на уведомление о рейде снова.", show_alert=True); return

    raid = await get_raid_by_id(prep["raid_id"])
    if not raid or raid["status"] != "active":
        await _edit_text(query,
            "Рейд уже завершён.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data="explore")]])
        )
        return
    if raid["expires_at"] < int(time.time()):
        await close_raid(raid["id"], "expired")
        await _apply_raid_loss(raid)
        await _edit_text(query,
            "⏰ Время вышло — район разграблен.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Назад", callback_data="explore")]])
        )
        return

    char    = await get_character(user_id)
    if not char:
        await query.answer("Персонаж не найден.", show_alert=True); return

    raid_boss = context.user_data.get("active_raid_boss") or {
        "name":    f"{raid['gang_emoji']} {raid['gang_name']}",
        "title":   "Рейд на район",
        "quote":   "Ваш район наш!",
        "hp":      raid["boss_hp_max"],
        "attack":  raid["boss_atk"],
        "defense": raid["boss_def"],
        "exp":     raid["reward_exp"],
        "cash":    raid["reward_cash"],
        "drop":    None,
    }
    context.user_data["active_raid_boss"] = raid_boss

    party = prep.get("party", []) or []

    # ── Проверяем co-op сессию ──────────────────────────────────────────
    coop_sid = await _check_and_start_coop(user_id, context)
    if coop_sid:
        session = await get_coop_session(coop_sid)
        if session and session["status"] == "active":
            await update_coop_session(coop_sid,
                boss_id="raid_boss",
                boss_hp=raid["boss_hp"], boss_max_hp=raid["boss_hp_max"],
                location=f"raid_{raid['id']}", current_turn=0)
            session = await get_coop_session(coop_sid)
            await update_character(user_id, last_hunt=int(time.time()))
            partner_char = await get_character(session["partner_id"])
            await start_coop_battle_db(user_id, f"raid_{raid['id']}", "raid_boss",
                                        raid["boss_hp"], raid["boss_hp_max"])
            battle_data_coop = await get_battle(user_id)
            inv_coop = await get_inventory(user_id)
            has_potions_coop = any(
                ITEMS.get(i, {}).get("type") == "potion" and q > 0
                for i, q in inv_coop.items()
            )
            url_coop = build_iso_url(char, battle_data_coop)
            await _edit_text(query,
                f"⚔️ *СОВМЕСТНАЯ ЗАЩИТА!*\n\n"
                f"👊 *{raid_boss['name']}* — ❤️ {raid['boss_hp']}/{raid['boss_hp_max']} HP\n\n"
                f"👥 *{md(char['name'])}* + *{md(partner_char['name'])}*\n\n"
                f"Ходите по очереди. Первый ход — твой!",
                parse_mode="Markdown"
            )
            await context.bot.send_message(
                chat_id=user_id,
                text=f"🟢 *Твой первый ход!*\n\n"
                     f"👊 *{raid_boss['name']}* — ❤️ {raid['boss_hp']}/{raid['boss_hp_max']} HP\n"
                     f"❤️ Ты: *{char['hp']}/{char['max_hp']}* | ⚡ {char['mana']}/{char['max_mana']}",
                parse_mode="Markdown",
                reply_markup=ReplyKeyboardMarkup(
                    [[KeyboardButton("⚔️ Твой ход!", web_app=WebAppInfo(url=url_coop))]],
                    resize_keyboard=True, one_time_keyboard=True
                )
            )
            try:
                await context.bot.send_message(
                    chat_id=session["partner_id"],
                    text=f"⚔️ *Совместная защита началась!*\n\n"
                         f"Враг: *{raid_boss['name']}* — ❤️ {raid['boss_hp']} HP\n\n"
                         f"⏳ Ход *{md(char['name'])}*... Ожидай своего хода.",
                    parse_mode="Markdown"
                )
            except Exception:
                pass
            return

    # ── Обычная защита (WebApp) ─────────────────────────────────────────
    real_party = [p for p in party if not p.get("pending")]
    await update_character(user_id, last_hunt=int(time.time()))
    await start_raid_battle_db(user_id, raid["id"], raid["boss_hp"], raid["boss_hp_max"],
                                real_party if real_party else None)
    battle_data = await get_battle(user_id)
    inv = await get_inventory(user_id)
    has_potions = any(ITEMS.get(i, {}).get("type") == "potion" and q > 0 for i, q in inv.items())
    url = build_iso_url(char, battle_data)

    loc_name = LOCATIONS.get(raid["location_id"], {}).get("name", raid["location_id"])
    await _edit_text(query,
        f"🚨 *ЗАЩИТА РАЙОНА!*\n\n"
        f"*{loc_name}* атакуют {raid['gang_emoji']} *{raid['gang_name']}*!\n\n"
        f"😤 *{raid_boss['name']}* — ❤️ {raid['boss_hp']} HP | ⚔️ {raid['boss_atk']} | 🛡 {raid['boss_def']}\n"
        f"🤵 *{md(char['name'])}* — ❤️ {char['hp']}/{char['max_hp']} | ⚡ {char['mana']}/{char['max_mana']}\n\n"
        f"_Нажми кнопку ниже чтобы открыть экран боя_ 👇",
        parse_mode="Markdown",
    )
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="👇",
        reply_markup=ReplyKeyboardMarkup(
            [[KeyboardButton("⚔️ Открыть бой", web_app=WebAppInfo(url=url))]],
            resize_keyboard=True, one_time_keyboard=True
        )
    )


# ============================================================
# ЗАПУСК БОТА
# ============================================================


# ─────────────────────────────────────────────────────────────
#  ЛЕЧЕНИЕ НАЁМНИКА
# ─────────────────────────────────────────────────────────────
async def merc_heal(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Лечит наёмника малой аптечкой (кнопка в экране Наёмники)."""
    query     = update.callback_query
    await query.answer()
    user_id   = update.effective_user.id
    member_id = int(query.data.replace("merc_heal_", ""))

    inv = await get_inventory(user_id)
    if not (inv.get("medkit_small") or 0):
        await query.answer("🩹 Нет малых аптечек!", show_alert=True)
        return

    char = await get_character(user_id)
    gang = await get_gang(user_id)
    m    = next((x for x in gang if x["id"] == member_id), None)
    if not m:
        await query.answer("Боец не найден.", show_alert=True)
        return

    cls    = MERC_CLASSES.get(m["role"], MERC_CLASSES["mercenary"])
    max_hp = cls["hp_base"] + char["level"] * cls["hp_per_lvl"]
    cur_hp = m.get("current_hp") if m.get("current_hp") is not None else max_hp
    cur_hp = max(0, min(cur_hp, max_hp))

    if cur_hp >= max_hp:
        await query.answer("❤️ Боец уже здоров!", show_alert=True)
        return

    heal   = ITEMS["medkit_small"]["heal"]
    new_hp = min(max_hp, cur_hp + heal)
    await remove_item(user_id, "medkit_small")
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE gang_members SET current_hp=? WHERE id=?",
            (new_hp, member_id)
        )
        await db.commit()

    await query.answer(
        f"🩹 {m['member_name']} восстановил {new_hp - cur_hp} HP!",
        show_alert=True
    )
    await gang_mercs_screen(update, context)


# ─────────────────────────────────────────────────────────────
#  ОТСТУПЛЕНИЕ ОТ РЕЙДА
# ─────────────────────────────────────────────────────────────
async def raid_flee(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игрок отступает — рейд остаётся активным для других."""
    query   = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    context.user_data.pop("raid_prep", None)
    context.user_data.pop("active_raid_boss", None)
    await _edit_text(query,
        "🏳️ *Отступил из рейда.*\n\nТы покинул защиту района. Рейд продолжается без тебя.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🗺 Районы",         callback_data="explore")],
            [InlineKeyboardButton("🏠 Главное меню",   callback_data="main_menu")],
        ])
    )


# ══════════════════════════════════════════════════════════════════
# CO-OP HTTP API  (aiohttp, порт 8080)
# Запускается только если COOP_API_BASE != ""
# ══════════════════════════════════════════════════════════════════

import string as _string

_coop_sessions: dict = {}   # sid -> session dict


def _coop_gen_sid() -> str:
    import random as _r
    chars = _string.ascii_uppercase + _string.digits
    while True:
        sid = ''.join(_r.choices(chars, k=6))
        if sid not in _coop_sessions:
            return sid


_COOP_BOSS_HP = {
    'kosoy':150,'bychok':200,'zhigan':338,'shustryy':300,'tolsty':380,'kaban':440,
    'bukhgalter':360,'kontrabas':420,'legenda':520,'professor':460,'artist':500,
    'svalshchik':480,'buryy':680,'khirurg':620,'tigr':750,'palach':700,
    'sedoy':920,'prizrak':860,'don_karlo':1400,'vizir':1050,
}
_COOP_BOSS_ATK = {
    'kosoy':28,'bychok':34,'zhigan':55,'shustryy':48,'tolsty':55,'kaban':52,
    'bukhgalter':65,'kontrabas':60,'legenda':78,'professor':82,'artist':88,
    'svalshchik':72,'buryy':96,'khirurg':105,'tigr':100,'palach':98,
    'sedoy':120,'prizrak':135,'don_karlo':155,'vizir':140,
}
_COOP_BOSS_DEF = {
    'kosoy':10,'bychok':15,'zhigan':26,'shustryy':22,'tolsty':30,'kaban':36,
    'bukhgalter':28,'kontrabas':32,'legenda':42,'professor':35,'artist':38,
    'svalshchik':30,'buryy':50,'khirurg':48,'tigr':55,'palach':52,
    'sedoy':65,'prizrak':60,'don_karlo':90,'vizir':78,
}


def _coop_calc_dmg(atk: int, def_: int) -> int:
    import random as _r
    base = max(1, atk - def_ // 2)
    return max(1, round(base * (0.85 + _r.random() * 0.30)))


def _coop_add_log(sess: dict, text: str, typ: str = ''):
    sess['log'].append({'text': text, 'type': typ})
    if len(sess['log']) > 80:
        sess['log'] = sess['log'][-80:]


def _coop_next_turn(sess: dict):
    alive = [p['uid'] for p in sess['players'] if p['hp'] > 0]
    if not alive:
        return
    cur = sess.get('turn_uid')
    if cur in alive:
        idx = (alive.index(cur) + 1) % len(alive)
    else:
        idx = 0
    sess['turn_uid'] = alive[idx]


# ── Лобби: готовность, автостарт, таймаут ────────────────────────────────
# Параметры лобби. Когда все ≥2 игроков нажали «Готов» — старт через
# COOP_READY_AUTOSTART сек. Первое нажатие открывает окно готовности
# COOP_READY_WINDOW сек — если кто-то не нажмёт за это время, сессия
# отменяется автоматически.
COOP_READY_AUTOSTART = 5    # сек до автостарта когда все готовы
COOP_READY_WINDOW    = 30   # сек на нажатие «Готов» всеми


def _coop_evaluate_lobby(sess: dict, now: float = None) -> None:
    """Проверка состояния лобби — автостарт или таймаут. Вызывается на каждый
    GET/ready, чтобы поллинг с фронта сам двигал состояние без отдельного
    таймера (одной задачи поверх aiohttp нам не нужно)."""
    if sess.get('state') != 'waiting':
        return
    if now is None:
        now = time.time()
    players = sess.get('players') or []
    ready_uids = [p['uid'] for p in players if p.get('ready')]

    # Таймаут готовности: после первого «Готов» даём COOP_READY_WINDOW сек —
    # если не все нажали, отменяем. Если ни один не нажал — таймер не идёт.
    first_ready_at = sess.get('first_ready_at') or 0
    if first_ready_at and len(ready_uids) < len(players):
        if now - first_ready_at > COOP_READY_WINDOW:
            sess['state'] = 'cancelled'
            sess['cancel_reason'] = 'ready_timeout'
            _coop_add_log(sess, "⏱ Кто-то не подтвердил готовность. Сессия отменена.", 'sys')
            return

    # Автостарт: все готовы, минимум 2 игрока → отсчёт COOP_READY_AUTOSTART сек.
    if len(players) >= 2 and ready_uids and len(ready_uids) == len(players):
        if not sess.get('autostart_at'):
            sess['autostart_at'] = now + COOP_READY_AUTOSTART
            _coop_add_log(sess, f"✅ Все готовы. Старт через {COOP_READY_AUTOSTART} сек!", 'sys')
        if now >= sess['autostart_at']:
            sess['state'] = 'battle'
            sess['autostart_at'] = 0
            _coop_add_log(sess, "Бой начался!", 'sys')
    else:
        # Если кто-то «отжался» от готовности — гасим автостарт.
        sess['autostart_at'] = 0


async def _coop_fetch_char_stats(uid_str: str) -> dict:
    """Подтянуть актуальные характеристики из БД по telegram_id.
    Нужно, когда игрок открыл WebApp напрямую через startapp deep-link и
    в URL нет hp/atk/def — тогда мы заполняем join по данным из БД."""
    try:
        uid_int = int(uid_str)
    except Exception:
        return {}
    char = await get_character(uid_int)
    if not char:
        return {}
    return {
        'name':  str(char.get('name') or 'Игрок')[:32],
        'atk':   int(char.get('attack')   or 20),
        'def':   int(char.get('defense')  or 10),
        'hp':    int(char.get('hp')       or 100),
        'maxhp': int(char.get('max_hp')   or 100),
    }


async def _coop_http_app():
    try:
        from aiohttp import web
    except ImportError:
        logger.warning("aiohttp not installed — co-op API disabled. pip install aiohttp")
        return

    async def _cors(resp):
        resp.headers['Access-Control-Allow-Origin']  = '*'
        resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        return resp

    async def h_options(req):
        return await _cors(web.Response(status=204))

    async def h_create(req):
        try:
            b = await req.json()
        except Exception:
            return await _cors(web.json_response({'error': 'bad json'}, status=400))
        uid   = str(b.get('uid', ''))
        name  = str(b.get('name', 'Игрок'))[:32]
        atk   = int(b.get('atk', 20))
        def_  = int(b.get('def', 10))
        hp    = int(b.get('hp', 100))
        maxhp = int(b.get('maxhp', 100))
        boss_id = str(b.get('boss_id', 'kosoy'))
        loc_id  = str(b.get('loc_id', 'market'))
        bhp = _COOP_BOSS_HP.get(boss_id, 300)
        sid = _coop_gen_sid()
        # Создатель сразу помечается ready — в лобби лишний клик не нужен.
        sess = {
            'sid': sid, 'state': 'waiting',
            'boss_id': boss_id, 'loc_id': loc_id,
            'boss_hp': bhp, 'boss_max_hp': bhp,
            'boss_atk': _COOP_BOSS_ATK.get(boss_id, 50),
            'boss_def': _COOP_BOSS_DEF.get(boss_id, 25),
            'turn_uid': uid, 'log': [],
            'players': [{'uid': uid, 'name': name, 'atk': atk, 'def': def_,
                         'hp': hp, 'max_hp': maxhp, 'ready': True}],
            'created_at':     time.time(),
            'host_uid':       uid,
            'first_ready_at': time.time(),
            'autostart_at':   0,
        }
        _coop_sessions[sid] = sess
        # share-ссылка через startapp — открывает WebApp у получателя сразу
        # на нужной сессии. Если бот username неизвестен, отдаём пустую строку.
        share_link = (f"https://t.me/{BOT_USERNAME}?startapp=coop_{sid}"
                      if BOT_USERNAME else "")
        logger.info("Coop session %s created by %s", sid, uid)
        return await _cors(web.json_response({**sess, 'share_link': share_link}))

    async def h_join(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'error': 'Not found'}, status=404))
        sess = _coop_sessions[sid]
        if sess['state'] not in ('waiting', 'battle'):
            return await _cors(web.json_response({'error': 'Closed'}, status=410))
        if len(sess['players']) >= 4:
            return await _cors(web.json_response({'error': 'Full'}, status=409))
        try:
            b = await req.json()
        except Exception:
            b = {}
        uid   = str(b.get('uid', ''))
        if not uid:
            return await _cors(web.json_response({'error': 'no uid'}, status=400))
        # Если игрок пришёл через startapp-инвайт, в URL нет hp/atk/def —
        # подтянем актуальные стартовые характеристики из БД.
        fallback = await _coop_fetch_char_stats(uid) if uid else {}
        name  = str(b.get('name')  or fallback.get('name')  or 'Игрок')[:32]
        atk   = int(b.get('atk')   or fallback.get('atk')   or 20)
        def_  = int(b.get('def')   or fallback.get('def')   or 10)
        hp    = int(b.get('hp')    or fallback.get('hp')    or 100)
        maxhp = int(b.get('maxhp') or fallback.get('maxhp') or 100)
        if not any(p['uid'] == uid for p in sess['players']):
            sess['players'].append({'uid': uid, 'name': name, 'atk': atk, 'def': def_,
                                    'hp': hp, 'max_hp': maxhp, 'ready': False})
            _coop_add_log(sess, f"{name} зашёл в лобби.", 'sys')
        _coop_evaluate_lobby(sess)
        share_link = (f"https://t.me/{BOT_USERNAME}?startapp=coop_{sid}"
                      if BOT_USERNAME else "")
        return await _cors(web.json_response({**sess, 'share_link': share_link}))

    async def h_get(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'error': 'Not found'}, status=404))
        sess = _coop_sessions[sid]
        # Каждый GET двигает состояние лобби — это удобно: поллинг с фронта
        # сам по себе обеспечивает автостарт и таймауты.
        _coop_evaluate_lobby(sess)
        share_link = (f"https://t.me/{BOT_USERNAME}?startapp=coop_{sid}"
                      if BOT_USERNAME else "")
        return await _cors(web.json_response({**sess, 'share_link': share_link}))

    async def h_ready(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'error': 'Not found'}, status=404))
        sess = _coop_sessions[sid]
        if sess['state'] != 'waiting':
            return await _cors(web.json_response({'error': 'Not waiting'}, status=409))
        try:
            b = await req.json()
        except Exception:
            b = {}
        uid   = str(b.get('uid', ''))
        ready = bool(b.get('ready', True))
        pl = next((p for p in sess['players'] if p['uid'] == uid), None)
        if not pl:
            return await _cors(web.json_response({'error': 'not in session'}, status=404))
        pl['ready'] = ready
        if ready and not sess.get('first_ready_at'):
            sess['first_ready_at'] = time.time()
        _coop_evaluate_lobby(sess)
        return await _cors(web.json_response(sess))

    async def h_start(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'error': 'Not found'}, status=404))
        sess = _coop_sessions[sid]
        if sess['state'] == 'waiting':
            sess['state'] = 'battle'
            _coop_add_log(sess, "Бой начался!", 'sys')
        return await _cors(web.json_response(sess))

    async def h_attack(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'error': 'Not found'}, status=404))
        sess = _coop_sessions[sid]
        if sess['state'] != 'battle':
            return await _cors(web.json_response({'error': 'Not in battle'}, status=409))
        try:
            b = await req.json()
            uid = str(b.get('uid', ''))
        except Exception:
            return await _cors(web.json_response({'error': 'bad json'}, status=400))
        if sess['turn_uid'] != uid:
            return await _cors(web.json_response({'error': 'Not your turn'}, status=409))
        pl = next((p for p in sess['players'] if p['uid'] == uid), None)
        if not pl or pl['hp'] <= 0:
            return await _cors(web.json_response({'error': 'Dead'}, status=409))
        # Player hits boss
        dmg = _coop_calc_dmg(pl['atk'], sess['boss_def'])
        sess['boss_hp'] = max(0, sess['boss_hp'] - dmg)
        _coop_add_log(sess, f"⚔️ {pl['name']} — {dmg} урона боссу!", 'hit-boss')
        if sess['boss_hp'] <= 0:
            sess['state'] = 'won'
            _coop_add_log(sess, "🏆 Победа! Босс повержен!", 'sys')
            return await _cors(web.json_response(sess))
        # Boss hits random living player
        import random as _r
        targets = [p for p in sess['players'] if p['hp'] > 0]
        tgt = _r.choice(targets)
        bdmg = _coop_calc_dmg(sess['boss_atk'], tgt['def'])
        tgt['hp'] = max(0, tgt['hp'] - bdmg)
        _coop_add_log(sess, f"💀 Босс бьёт {tgt['name']} — {bdmg} урона!", 'boss-hits')
        if all(p['hp'] <= 0 for p in sess['players']):
            sess['state'] = 'lost'
            _coop_add_log(sess, "💀 Все пали. Поражение.", 'sys')
            return await _cors(web.json_response(sess))
        _coop_next_turn(sess)
        return await _cors(web.json_response(sess))

    async def h_cancel(req):
        sid = req.match_info['sid'].upper()
        if sid in _coop_sessions:
            _coop_sessions[sid]['state'] = 'cancelled'
        return await _cors(web.json_response({'ok': True}))

    async def h_leave(req):
        sid = req.match_info['sid'].upper()
        if sid not in _coop_sessions:
            return await _cors(web.json_response({'ok': True}))
        try:
            b = await req.json()
            uid = str(b.get('uid', ''))
        except Exception:
            uid = ''
        sess = _coop_sessions[sid]
        sess['players'] = [p for p in sess['players'] if p['uid'] != uid]
        if not sess['players']:
            sess['state'] = 'cancelled'
        else:
            _coop_next_turn(sess)
        return await _cors(web.json_response({'ok': True}))

    # ── Работа: найм/увольнение БЕЗ закрытия мини-аппа ──────────
    async def h_job_take(req):
        try:
            uid = int(req.match_info['uid'])
            b   = await req.json()
            job_id = str(b.get('id', ''))
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad request'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        now = int(time.time())
        if (char.get("captivity_until") or 0) > now:
            return await _cors(web.json_response({'ok': False, 'error': 'captive'}))
        if (char.get("jail_until") or 0) > now:
            return await _cors(web.json_response({'ok': False, 'error': 'jailed'}))
        if char.get("job"):
            return await _cors(web.json_response({'ok': False, 'error': 'already working'}))
        job = JOBS.get(job_id)
        if not job:
            return await _cors(web.json_response({'ok': False, 'error': 'no job'}))
        if (char.get("level", 1) or 1) < job.get("rank", 1):
            return await _cors(web.json_response({'ok': False, 'error': 'low rank', 'need_rank': job.get('rank', 1)}))
        import json as _json
        try:
            _cds = _json.loads(char.get('job_cooldowns_json') or '{}')
        except Exception:
            _cds = {}
        _cd_until = int(_cds.get(job_id, 0) or 0)
        if _cd_until > now:
            return await _cors(web.json_response({
                'ok': False, 'error': 'cooldown',
                'cooldown_until': _cd_until,
                'remaining_sec': int(_cd_until - now),
            }))
        await update_character(uid, job=job_id, job_started=now, job_last_paid=now)
        return await _cors(web.json_response({
            'ok': True, 'job': job_id,
            'job_started': now,
            'duration': int(job.get('duration', JOB_DURATION)),
        }))

    async def h_job_state(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        import json as _json
        try:
            _cds = _json.loads(char.get('job_cooldowns_json') or '{}')
        except Exception:
            _cds = {}
        _now = int(time.time())
        _cds = {k: int(v) for k, v in _cds.items() if int(v or 0) > _now}
        return await _cors(web.json_response({
            'ok': True,
            'job': char.get('job') or '',
            'job_started': char.get('job_started') or 0,
            'job_last_paid': char.get('job_last_paid') or 0,
            'cooldowns': _cds,
        }))

    async def h_job_complete(req):
        # Мини-игра пройдена. Если count > 0 — мотаем job_started так, чтобы
        # выплата уже стала доступна. Если count == 0 — ничего не делаем,
        # игрок может попробовать снова, увольнения не происходит.
        try:
            uid = int(req.match_info['uid'])
            body = {}
            try:
                body = await req.json()
            except Exception:
                pass
            count = int(body.get('count', 1))
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        job_id = char.get('job') or ''
        if not job_id:
            return await _cors(web.json_response({'ok': False, 'error': 'no job'}))
        job = JOBS.get(job_id)
        if not job:
            return await _cors(web.json_response({'ok': False, 'error': 'unknown job'}))
        if count <= 0:
            # 0 газет — ни денег, ни увольнения. Можно попробовать снова.
            return await _cors(web.json_response({'ok': True, 'completed': False, 'count': 0}))
        now = int(time.time())
        dur = int(job.get('duration', JOB_DURATION))
        await update_character(uid, job_started=now - dur)
        return await _cors(web.json_response({'ok': True, 'completed': True, 'count': count}))

    async def h_job_collect(req):
        # HTTP-сбор выплаты — аналог action == job_collect, но без чата.
        # Принимает опциональный count (из мини-игры) — больше газет = больше денег.
        try:
            uid = int(req.match_info['uid'])
            body = {}
            try: body = await req.json()
            except Exception: pass
            count = int(body.get('count', 0))
        except Exception as _e:
            logger.warning("h_job_collect bad uid: %r", _e)
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            char = await get_character(uid)
            if not char or not char.get('job'):
                return await _cors(web.json_response({'ok': False, 'error': 'no job'}))
            job = JOBS.get(char['job'])
            if not job:
                await update_character(uid, job=None, job_started=None, job_last_paid=None)
                return await _cors(web.json_response({'ok': False, 'error': 'stale job'}))
            import random as _r
            now = int(time.time())
            end_ts = (char.get('job_started') or 0) + int(job.get('duration', JOB_DURATION))
            # Grace-period 30 сек: компенсируем рассинхрон часов клиент/сервер
            # и задержку между h_job_complete и actCollect (мини-игра только что
            # перевела job_started в "истёкший", но из-за RTT now тут может быть
            # на пару секунд раньше end_ts).
            if now + 30 < end_ts:
                return await _cors(web.json_response({'ok': False, 'error': 'too early',
                                                       'remaining': int(end_ts - now)}))
            success_chance = float(job.get('success_chance', 1.0))
            success = _r.random() < success_chance
            cop_chance  = float(job.get('cop_star_chance',  0))
            gang_chance = float(job.get('gang_star_chance', 0))
            cop_n   = int(job.get('stars_amount_cop', 1))
            gang_n  = int(job.get('stars_amount_gang', 1))
            cop_added  = cop_n  if _r.random() < cop_chance  else 0
            gang_added = gang_n if _r.random() < gang_chance else 0
            # Выплата: count = число розданных газет в мини-игре.
            # 0  → обычная случайная выплата pay_min..pay_max
            # 1..10 → нижняя граница ползёт вверх (1 = +10%, 10 = +100% диапазона)
            # 10+ → почти всегда около pay_max
            pmin = int(job['pay_min']); pmax = int(job['pay_max'])
            if success:
                if count <= 0:
                    pay = _r.randint(pmin, pmax)
                else:
                    k = min(count, 10) / 10.0
                    shifted_min = pmin + int((pmax - pmin) * k * 0.7)
                    pay = _r.randint(shifted_min, pmax)
                    if count > 10:
                        pay += min(count - 10, 30) * 5
            else:
                pay = 0
            cur_cop  = char.get('wanted_stars', 0) or 0
            cur_gang = char.get('wanted_gangs', 0) or 0
            new_cop  = min(3, cur_cop  + cop_added)
            new_gang = min(3, cur_gang + gang_added)
            _job_id_now = char.get('job')  # сохраняем ДО затирания
            updates = {
                'cash':          (char.get('cash', 0) or 0) + pay,
                'job':           None,
                'job_started':   None,
                'job_last_paid': None,
                'wanted_stars':  new_cop,
                'wanted_gangs':  new_gang,
            }
            jail = False; cap = False
            if new_cop >= 3 and (char.get('jail_until', 0) or 0) <= now:
                updates['jail_until'] = now + JAIL_DURATION
                updates['jail_count'] = (char.get('jail_count', 0) or 0) + 1
                jail = True
            if new_gang >= 3 and (char.get('captivity_until', 0) or 0) <= now:
                updates['captivity_until'] = now + CAPTIVITY_DURATION
                updates['captivity_count'] = (char.get('captivity_count', 0) or 0) + 1
                cap = True
            import json as _json
            try:
                _cds = _json.loads(char.get('job_cooldowns_json') or '{}')
            except Exception:
                _cds = {}
            _cd_secs = 3600
            if _job_id_now:
                _cds[_job_id_now] = now + _cd_secs
            updates['job_cooldowns_json'] = _json.dumps(_cds, ensure_ascii=False)
            await update_character(uid, **updates)
            return await _cors(web.json_response({
                'ok': True, 'success': success, 'pay': pay,
                'cop_added': cop_added, 'gang_added': gang_added,
                'jail': jail, 'captivity': cap,
                'wanted_stars': new_cop, 'wanted_gangs': new_gang,
                'cooldown_until': now + _cd_secs,
                'cooldown_job': _job_id_now,
            }))
        except Exception as _e:
            logger.exception("h_job_collect crashed for uid=%s count=%s: %r", uid, count, _e)
            return await _cors(web.json_response(
                {'ok': False, 'error': 'server error: ' + str(_e)[:120]}, status=500
            ))

    async def h_job_abandon(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        if not char.get("job"):
            return await _cors(web.json_response({'ok': False, 'error': 'no job'}))
        await update_character(uid, job=None, job_started=None, job_last_paid=None)
        return await _cors(web.json_response({'ok': True}))

    # ── BUSINESSES (мой бизнес) ──────────────────────────────────────────
    def _biz_pending_income(row, now: int):
        """Считает накопленный доход бизнеса с момента last_collect."""
        biz = get_business(row['biz_id'])
        if not biz:
            return 0
        if row['status'] != 'ok':
            return 0
        # Если блокирован — доход начисляется только до момента блокировки... упрощаем:
        # просто пока статус == 'ok' доход накапливается
        if (row.get('blocked_until') or 0) > now:
            return 0
        elapsed = max(0, now - (row.get('last_collect') or now))
        avg_per_day = (biz['daily_min'] + biz['daily_max']) / 2.0
        per_sec = avg_per_day / 86400.0
        return int(elapsed * per_sec)

    async def h_biz_list(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        now = int(time.time())
        owned = {}
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute(
                "SELECT * FROM player_businesses WHERE telegram_id=?", (uid,)
            ) as cur:
                rows = await cur.fetchall()
        for r in rows:
            d = dict(r)
            d['pending'] = _biz_pending_income(d, now)
            owned[d['biz_id']] = d
        catalog = []
        for b in BUSINESSES:
            entry = dict(b)
            entry['owned'] = b['id'] in owned
            if entry['owned']:
                o = owned[b['id']]
                entry['status']        = o['status']
                entry['blocked_until'] = o.get('blocked_until') or 0
                entry['pending']       = o.get('pending') or 0
                entry['notice']        = o.get('pending_notice')
            catalog.append(entry)
        return await _cors(web.json_response({
            'ok': True,
            'businesses': catalog,
            'cash':       char.get('cash') or 0,
        }))

    async def h_biz_buy(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        biz_id = str(b.get('biz_id', ''))
        biz = get_business(biz_id)
        if not biz:
            return await _cors(web.json_response({'ok': False, 'error': 'unknown biz'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        cash = char.get('cash') or 0
        if cash < biz['price']:
            return await _cors(web.json_response({'ok': False, 'error': 'no cash'}))
        now = int(time.time())
        async with aiosqlite.connect(DB_PATH) as db:
            async with db.execute(
                "SELECT 1 FROM player_businesses WHERE telegram_id=? AND biz_id=?", (uid, biz_id)
            ) as cur:
                already = await cur.fetchone()
            if already:
                return await _cors(web.json_response({'ok': False, 'error': 'already owned'}))
            await db.execute(
                "INSERT INTO player_businesses (telegram_id, biz_id, bought_at, last_collect, status, blocked_until, last_event_at) "
                "VALUES (?, ?, ?, ?, 'ok', 0, 0)",
                (uid, biz_id, now, now)
            )
            await db.commit()
        await update_character(uid, cash=cash - biz['price'])
        return await _cors(web.json_response({'ok': True, 'cash': cash - biz['price']}))

    async def h_biz_collect(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        biz_id_filter = str(b.get('biz_id', '')).strip() or None
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        now = int(time.time())
        total = 0
        events_fired = []
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            q = "SELECT * FROM player_businesses WHERE telegram_id=?"
            args = [uid]
            if biz_id_filter:
                q += " AND biz_id=?"
                args.append(biz_id_filter)
            async with db.execute(q, tuple(args)) as cur:
                rows = await cur.fetchall()
            for r in rows:
                row = dict(r)
                biz = get_business(row['biz_id'])
                if not biz:
                    continue
                if row['status'] != 'ok' or (row.get('blocked_until') or 0) > now:
                    continue
                pend = _biz_pending_income(row, now)
                if pend <= 0:
                    continue
                # Шанс события
                event = None
                last_ev = row.get('last_event_at') or 0
                if (now - last_ev) >= BIZ_EVENT_COOLDOWN and random.random() < BIZ_EVENT_CHANCE:
                    event = pick_business_event()
                # Применяем эффект события
                pay = pend
                new_status = row['status']
                new_blocked_until = row.get('blocked_until') or 0
                if event:
                    kind = event['kind']
                    if kind == 'income_penalty':
                        pay = int(pay * (1.0 - float(event['value'])))
                    elif kind == 'income_bonus':
                        pay = int(pay * (1.0 + float(event['value'])))
                    elif kind == 'block':
                        new_status = 'blocked'
                        new_blocked_until = now + int(event['hours']) * 3600
                    elif kind == 'burn':
                        new_status = 'burned'
                        new_blocked_until = 0
                    events_fired.append({
                        'biz_id':   row['biz_id'],
                        'biz_name': biz['name'],
                        'biz_emoji': biz['emoji'],
                        'text':     event['text'],
                        'kind':     kind,
                    })
                total += max(0, pay)
                await db.execute(
                    "UPDATE player_businesses SET last_collect=?, status=?, blocked_until=?, "
                    "last_event_at=?, pending_notice=NULL "
                    "WHERE telegram_id=? AND biz_id=?",
                    (now, new_status, new_blocked_until,
                     now if event else last_ev,
                     uid, row['biz_id'])
                )
            await db.commit()
        if total > 0:
            cur_cash = (char.get('cash') or 0) + total
            await update_character(uid, cash=cur_cash)
        else:
            cur_cash = char.get('cash') or 0
        return await _cors(web.json_response({
            'ok':         True,
            'collected':  total,
            'cash':       cur_cash,
            'events':     events_fired,
        }))

    async def h_biz_restore(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        biz_id = str(b.get('biz_id', ''))
        biz = get_business(biz_id)
        if not biz:
            return await _cors(web.json_response({'ok': False, 'error': 'unknown biz'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        cost = int(biz['price'] * 0.12)  # 12% от стоимости
        cash = char.get('cash') or 0
        if cash < cost:
            return await _cors(web.json_response({'ok': False, 'error': 'no cash', 'cost': cost}))
        now = int(time.time())
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute(
                "SELECT * FROM player_businesses WHERE telegram_id=? AND biz_id=?",
                (uid, biz_id)
            ) as cur:
                row = await cur.fetchone()
            if not row:
                return await _cors(web.json_response({'ok': False, 'error': 'not owned'}))
            row = dict(row)
            if row['status'] != 'burned':
                return await _cors(web.json_response({'ok': False, 'error': 'not burned'}))
            # Шанс восстановления (≈55%) — чтобы было «не каждый день получалось с первого раза»
            success = random.random() < 0.55
            if success:
                await db.execute(
                    "UPDATE player_businesses SET status='ok', blocked_until=0, last_collect=?, last_event_at=? "
                    "WHERE telegram_id=? AND biz_id=?",
                    (now, now, uid, biz_id)
                )
                await db.commit()
            await update_character(uid, cash=cash - cost)
        return await _cors(web.json_response({
            'ok':       True,
            'success':  success,
            'cost':     cost,
            'cash':     cash - cost,
        }))

    # ── ЧЁРНЫЙ РЫНОК и ИНВЕНТАРЬ (всё внутри мини-аппа) ──────────────────
    async def h_shop_list(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        # Магазин: ближний бой убран из игры (механика melee удалена),
        # 'nagan' — базовый ствол персонажа, выдаётся при создании.
        # Эти id остаются в ITEMS для бэк-совместимости со старыми
        # сохранениями, но в каталог магазина не попадают.
        _HIDE_FROM_SHOP = {'zatochka', 'machete', 'katana', 'spiked_bat', 'nagan'}
        items = []
        for iid, it in ITEMS.items():
            t = it.get('type')
            if t not in ('weapon', 'armor', 'potion', 'throwable'):
                continue
            if iid in _HIDE_FROM_SHOP:
                continue
            items.append({
                'id':              iid,
                'name':            it.get('name'),
                'type':            t,
                'desc':            it.get('desc', ''),
                'price':           it.get('price'),
                'diamonds_price':  it.get('diamonds_price'),
                'attack_bonus':    it.get('attack_bonus'),
                'defense_bonus':   it.get('defense_bonus'),
                'heal':            it.get('heal'),
                'mana':            it.get('mana'),
                'dmg_min':         it.get('dmg_min'),
                'dmg_max':         it.get('dmg_max'),
                'burn_per_turn':   it.get('burn_per_turn'),
                'burn_turns':      it.get('burn_turns'),
            })
        return await _cors(web.json_response({
            'ok':       True,
            'items':    items,
            'cash':     char.get('cash')     or 0,
            'diamonds': char.get('diamonds') or 0,
        }))

    async def h_shop_buy(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        item_id = str(b.get('item_id', ''))
        qty     = max(1, int(b.get('qty', 1)))
        it      = ITEMS.get(item_id)
        if not it:
            return await _cors(web.json_response({'ok': False, 'error': 'unknown item'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        cash     = char.get('cash')     or 0
        diamonds = char.get('diamonds') or 0
        price_c  = it.get('price')
        price_d  = it.get('diamonds_price')
        # Оружие/броню больше 1 не покупаем
        if it.get('type') in ('weapon', 'armor'):
            qty = 1
        if price_d:
            cost = price_d * qty
            if diamonds < cost:
                return await _cors(web.json_response({'ok': False, 'error': 'no diamonds'}))
            await update_character(uid, diamonds=diamonds - cost)
        elif price_c:
            cost = price_c * qty
            if cash < cost:
                return await _cors(web.json_response({'ok': False, 'error': 'no cash'}))
            await update_character(uid, cash=cash - cost)
        else:
            return await _cors(web.json_response({'ok': False, 'error': 'not for sale'}))
        for _ in range(qty):
            await add_item(uid, item_id)
        # Обновлённый игрок
        char2 = await get_character(uid)
        return await _cors(web.json_response({
            'ok':       True,
            'cash':     char2.get('cash')     or 0,
            'diamonds': char2.get('diamonds') or 0,
        }))

    async def h_inv_list(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        inv = await get_inventory(uid)
        out = []
        for iid, qty in (inv or {}).items():
            it = ITEMS.get(iid)
            if not it:
                continue
            out.append({
                'id':            iid,
                'name':          it.get('name'),
                'type':          it.get('type'),
                'qty':           qty,
                'desc':          it.get('desc', ''),
                'attack_bonus':  it.get('attack_bonus'),
                'defense_bonus': it.get('defense_bonus'),
                'heal':          it.get('heal'),
                'mana':          it.get('mana'),
            })
        return await _cors(web.json_response({
            'ok':            True,
            'items':         out,
            'equipped_weapon': char.get('weapon'),
            'equipped_armor':  char.get('armor'),
            'cash':            char.get('cash')     or 0,
            'diamonds':        char.get('diamonds') or 0,
        }))

    async def h_inv_equip(req):
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        item_id = str(b.get('item_id', '')) or None
        slot    = str(b.get('slot', '')).strip()  # 'weapon' | 'armor' | '' (auto)
        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))
        if item_id:
            it = ITEMS.get(item_id)
            if not it or it.get('type') not in ('weapon', 'armor'):
                return await _cors(web.json_response({'ok': False, 'error': 'not equipable'}, status=400))
            inv = await get_inventory(uid)
            if not inv or (inv.get(item_id) or 0) <= 0:
                return await _cors(web.json_response({'ok': False, 'error': 'not in inventory'}))
            slot = it.get('type')  # weapon or armor
            await update_character(uid, **{slot: item_id})
        else:
            # Снятие
            if slot not in ('weapon', 'armor'):
                return await _cors(web.json_response({'ok': False, 'error': 'bad slot'}, status=400))
            await update_character(uid, **{slot: None})
        char2 = await get_character(uid)
        return await _cors(web.json_response({
            'ok':              True,
            'equipped_weapon': char2.get('weapon'),
            'equipped_armor':  char2.get('armor'),
        }))

    async def h_event_tick(req):
        """Тик игрового времени из мини-аппа. Возможно тригерит случайное событие."""
        try:
            uid = int(req.match_info['uid'])
        except Exception:
            return await _cors(web.json_response({'ok': False, 'error': 'bad uid'}, status=400))
        try:
            b = await req.json()
        except Exception:
            b = {}
        phase = str(b.get('phase', 'day'))
        if phase not in ('morning', 'day', 'evening', 'night'):
            phase = 'day'
        post_battle = bool(b.get('post_battle', False))

        char = await get_character(uid)
        if not char:
            return await _cors(web.json_response({'ok': False, 'error': 'no character'}, status=404))

        now = int(time.time())

        # В бою — не тригерим (исключение: post_battle вызов сразу после боя)
        if not post_battle:
            async with aiosqlite.connect(DB_PATH) as db:
                async with db.execute(
                    "SELECT 1 FROM active_battles WHERE telegram_id=?", (uid,)
                ) as cur:
                    in_battle = await cur.fetchone()
            if in_battle:
                return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'in_battle'}))

        # В тюрьме / плену — не тригерим
        if (char.get('jail_until') or 0) > now:
            return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'in_jail'}))
        if (char.get('captivity_until') or 0) > now:
            return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'in_captivity'}))

        # Кулдаун между событиями (обычные)
        if not post_battle:
            last_at = char.get('last_hub_event_at') or 0
            if now - last_at < HUB_EVENT_COOLDOWN:
                return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'cooldown'}))
            # Кубик шанса
            if random.random() > HUB_EVENT_CHANCE:
                return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'no_roll'}))
            ev = pick_hub_event(phase)
        else:
            # После боя — отдельный шанс срабатывания и отдельный пул
            if random.random() > 0.35:
                return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'post_battle_no_roll'}))
            ev = pick_post_battle_event()

        if not ev:
            return await _cors(web.json_response({'ok': True, 'event': None, 'reason': 'no_event'}))

        # Применяем эффекты
        effects    = ev.get('effects', {})
        cur_hp     = max(0, char.get('hp')           or 0)
        max_hp     = char.get('max_hp')              or 100
        cur_mp     = max(0, char.get('mana')         or 0)
        max_mp     = char.get('max_mana')            or 50
        cur_cash   = char.get('cash')                or 0
        cur_w_cop  = char.get('wanted_stars')        or 0
        cur_w_gang = char.get('wanted_gangs')        or 0

        d_hp    = int(effects.get('hp',       0))
        d_en    = int(effects.get('energy',   0))
        d_cash  = int(effects.get('cash',     0))
        d_w_c   = int(effects.get('wanted',   0))
        d_w_g   = int(effects.get('wanted_g', 0))

        new_hp   = max(1 if cur_hp > 0 and d_hp < 0 else 0,
                       min(max_hp, cur_hp + d_hp))
        # если игрок и так был мертв (hp=0), не трогаем; иначе минимум 1
        if cur_hp <= 0:
            new_hp = cur_hp
        new_mp   = max(0, min(max_mp, cur_mp + d_en))
        new_cash = max(0, cur_cash + d_cash)
        new_w_c  = max(0, min(3, cur_w_cop  + d_w_c))
        new_w_g  = max(0, min(3, cur_w_gang + d_w_g))

        updates = {
            'last_hub_event_at': now,
            'hp':                new_hp,
            'mana':              new_mp,
            'cash':              new_cash,
            'wanted_stars':      new_w_c,
            'wanted_gangs':      new_w_g,
        }

        jailed   = False
        captured = False

        # 3 звезды копов → тюрьма (если стало 3 от события)
        if new_w_c >= 3 and cur_w_cop < 3:
            updates['jail_until'] = now + JAIL_DURATION
            updates['jail_count'] = (char.get('jail_count') or 0) + 1
            jailed = True
        # 3 кулака банд → плен (если стало 3 от события)
        if new_w_g >= 3 and cur_w_gang < 3:
            updates['captivity_until'] = now + CAPTIVITY_DURATION
            updates['captivity_count'] = (char.get('captivity_count') or 0) + 1
            captured = True

        await update_character(uid, **updates)

        return await _cors(web.json_response({
            'ok': True,
            'event': {
                'id':      ev['id'],
                'text':    ev['text'],
                'effects': {'hp': d_hp, 'energy': d_en, 'cash': d_cash,
                            'wanted': d_w_c, 'wanted_g': d_w_g},
            },
            'state': {
                'hp':       new_hp, 'mana':    new_mp, 'cash':    new_cash,
                'wanted':   new_w_c, 'wanted_g': new_w_g,
            },
            'jailed':   jailed,
            'captured': captured,
        }))

    # === HTTP: результат боя из demo_isometric.html ===
    # Закрывает запись битвы, начисляет опыт/деньги/убийства, обновляет HP
    # и возвращает свежее состояние персонажа в JSON. В чат бот ничего не
    # шлёт — мини-апп остаётся открытым и сразу переезжает в hub.html.
    async def h_battle_result(request):
        try:
            uid = int(request.match_info.get('uid', '0'))
        except Exception:
            return web.json_response({'error': 'bad uid'}, status=400)
        try:
            data = await request.json()
        except Exception:
            data = {}
        action = data.get('a') or ''
        if action not in ('battle_won', 'battle_lost'):
            return web.json_response({'error': 'bad action'}, status=400)
        char = await get_character(uid)
        if not char:
            return web.json_response({'error': 'no char'}, status=404)
        battle = await get_battle(uid)
        # boss_id — приоритет из payload, fallback на запись битвы
        boss_id = data.get('boss') or (battle.get('boss_id') if battle else '') or 'kosoy'
        boss = BOSSES.get(boss_id, BOSSES['kosoy'])
        loc_id = data.get('loc') or (battle.get('location') if battle else '') or 'market'
        loc_min_lvl = LOCATIONS.get(loc_id, {}).get('min_level', 1)
        loc_mul     = 1 + 0.10 * max(0, loc_min_lvl - 1)
        if action == 'battle_won':
            php = int(data.get('php', char['hp']) or 0)
            gren_used = int(data.get('gu', 0) or 0)
            mol_used  = int(data.get('mu', 0) or 0)
            # Кэп на 50 штук сразу — иначе подменой URL можно «съесть» весь инвентарь.
            for _ in range(min(gren_used, 50)):
                await remove_item(uid, 'grenade')
            for _ in range(min(mol_used, 50)):
                await remove_item(uid, 'molotov')
            # Доверяем числам WebApp, но кэпим x3 от базовой формулы.
            xp_payload   = int(data.get('xp',   0) or 0)
            cash_payload = int(data.get('cash', 0) or 0)
            base_exp  = round(boss['exp']  * loc_mul)
            base_cash = round(boss['cash'] * loc_mul)
            exp_gain  = min(xp_payload,   base_exp  * 3) if xp_payload  > 0 else base_exp
            cash_gain = min(cash_payload, base_cash * 3) if cash_payload > 0 else base_cash
            if battle:
                await end_battle(uid)
            await update_character(uid,
                hp=max(1, php), mana=char.get('mana', 0),
                exp=char['exp'] + exp_gain,
                cash=char['cash'] + cash_gain,
                kills=char['kills'] + 1)
            updated = await get_character(uid)
            try:
                await check_level_up(uid, updated)
                updated = await get_character(uid)
            except Exception:
                pass
            return web.json_response({
                'ok': True,
                'result': 'won',
                'rewards': {'exp': exp_gain, 'cash': cash_gain},
                'state': {
                    'hp':    updated['hp'],
                    'maxhp': updated['max_hp'],
                    'mp':    updated.get('mana', 0),
                    'maxmp': updated.get('max_mana', 0),
                    'cash':  updated['cash'],
                    'exp':   updated['exp'],
                    'lvl':   updated.get('level', 1),
                    'atk':   updated.get('attack', 20),
                    'def':   updated.get('defense', 10),
                    'kills': updated['kills'],
                },
            })
        else:  # battle_lost
            if battle:
                await end_battle(uid)
            await update_character(uid, hp=1, mana=0)
            updated = await get_character(uid)
            return web.json_response({
                'ok': True,
                'result': 'lost',
                'rewards': {'exp': 0, 'cash': 0},
                'state': {
                    'hp':    updated['hp'],
                    'maxhp': updated['max_hp'],
                    'mp':    updated.get('mana', 0),
                    'maxmp': updated.get('max_mana', 0),
                    'cash':  updated['cash'],
                    'exp':   updated['exp'],
                    'lvl':   updated.get('level', 1),
                    'atk':   updated.get('attack', 20),
                    'def':   updated.get('defense', 10),
                    'kills': updated['kills'],
                },
            })

    aio_app = web.Application()
    aio_app.router.add_route('OPTIONS', '/{path_info:.*}', h_options)
    aio_app.router.add_post('/coop/create',       h_create)
    aio_app.router.add_post('/coop/{sid}/join',   h_join)
    aio_app.router.add_get ('/coop/{sid}',        h_get)
    aio_app.router.add_post('/coop/{sid}/ready',  h_ready)
    aio_app.router.add_post('/coop/{sid}/start',  h_start)
    aio_app.router.add_post('/coop/{sid}/attack', h_attack)
    aio_app.router.add_post('/coop/{sid}/cancel', h_cancel)
    aio_app.router.add_post('/coop/{sid}/leave',  h_leave)
    aio_app.router.add_post('/job/{uid}/take',     h_job_take)
    aio_app.router.add_post('/job/{uid}/abandon',  h_job_abandon)
    aio_app.router.add_post('/job/{uid}/complete', h_job_complete)
    aio_app.router.add_post('/job/{uid}/collect',  h_job_collect)
    aio_app.router.add_get ('/job/{uid}/state',    h_job_state)
    aio_app.router.add_post('/event/{uid}/tick',   h_event_tick)
    aio_app.router.add_get ('/biz/{uid}/list',     h_biz_list)
    aio_app.router.add_post('/biz/{uid}/buy',      h_biz_buy)
    aio_app.router.add_post('/biz/{uid}/collect',  h_biz_collect)
    aio_app.router.add_post('/biz/{uid}/restore',  h_biz_restore)
    aio_app.router.add_get ('/shop/{uid}/list',    h_shop_list)
    aio_app.router.add_post('/shop/{uid}/buy',     h_shop_buy)
    aio_app.router.add_get ('/inv/{uid}/list',     h_inv_list)
    aio_app.router.add_post('/inv/{uid}/equip',    h_inv_equip)
    aio_app.router.add_post('/battle/{uid}/result', h_battle_result)

    from aiohttp import web as _web
    runner = _web.AppRunner(aio_app)
    await runner.setup()
    site = _web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    logger.info("Co-op HTTP API listening on :8080")


def main():
    async def _post_init(application):
        # Инициализация БД + миграции (ALTER TABLE на новые колонки).
        # Без этого вызова старые БД не получают колонки типа job_cooldowns_json.
        try:
            await init_db()
            logger.info("init_db() выполнен (миграции применены)")
        except Exception as _e:
            logger.exception("init_db() упал: %s", _e)
        # Запоминаем username бота для share-ссылок кооператива.
        try:
            global BOT_USERNAME
            BOT_USERNAME = (await application.bot.get_me()).username or ""
            logger.info("BOT_USERNAME = %s", BOT_USERNAME)
        except Exception as _e:
            logger.warning("Не удалось получить username бота: %s", _e)
        # Запускаем HTTP API (co-op + найм/увольнение) на :8080 в фоне
        # ВНУТРИ работающего event-loop’а, иначе get_event_loop() падает.
        try:
            asyncio.create_task(_coop_http_app())
            logger.info("HTTP API task scheduled (listening on :8080)")
        except Exception as _e:
            logger.warning("HTTP API не запустился: %s", _e)

    app = Application.builder().token(BOT_TOKEN).post_init(_post_init).build()

    conv = ConversationHandler(
        entry_points=[CommandHandler("start", cmd_start)],
        states={
            CHOOSING_CLASS: [CallbackQueryHandler(choose_class, pattern="^class_")],
        },
        fallbacks=[CommandHandler("start", cmd_start)],
    )
    app.add_handler(conv)
    app.add_handler(CommandHandler("diamonds", diamonds_menu))
    app.add_handler(PreCheckoutQueryHandler(precheckout))
    app.add_handler(MessageHandler(filters.SUCCESSFUL_PAYMENT, successful_payment))
    app.add_handler(MessageHandler(filters.StatusUpdate.WEB_APP_DATA, battle_webapp_action))

    # Навигация
    app.add_handler(CallbackQueryHandler(main_menu,             pattern="^main_menu$"))
    app.add_handler(CallbackQueryHandler(explore,               pattern="^explore$"))
    app.add_handler(CallbackQueryHandler(show_location,         pattern="^location_"))
    app.add_handler(CallbackQueryHandler(hunt_friends_list,     pattern="^hunt_friends_list$"))
    app.add_handler(CallbackQueryHandler(hunt_back_prep,        pattern="^hunt_back_prep$"))
    app.add_handler(CallbackQueryHandler(hunt_invite_friend,    pattern="^hunt_invite_friend_"))
    app.add_handler(CallbackQueryHandler(hunt_start,            pattern="^hunt_start$"))
    app.add_handler(CallbackQueryHandler(hunt_start_now,        pattern="^hunt_start_now_"))
    app.add_handler(CallbackQueryHandler(coop_cancel_auto,      pattern="^coop_cancel_auto_"))
    app.add_handler(CallbackQueryHandler(hunt_add_mercs,        pattern="^hunt_add_mercs$"))
    app.add_handler(CallbackQueryHandler(hunt_merc_toggle,      pattern="^hunt_merc_toggle_"))
    app.add_handler(CallbackQueryHandler(hunt_merc_filter,      pattern="^hunt_merc_filter_"))
    app.add_handler(CallbackQueryHandler(
        lambda u, c: u.callback_query.answer("🔒 Сними с охраны района сначала!", show_alert=True),
        pattern="^hunt_merc_guard_hint$"
    ))
    app.add_handler(CallbackQueryHandler(hunt,                  pattern="^hunt_(market|port|casino|factory|mansion)"))
    app.add_handler(CallbackQueryHandler(gather,                pattern="^gather_"))
    app.add_handler(CallbackQueryHandler(locked_cb,             pattern="^locked$"))
    app.add_handler(CallbackQueryHandler(character_info,        pattern="^character$"))
    app.add_handler(CallbackQueryHandler(battle_grenade_webapp, pattern="^battle_grenade_webapp$"))
    app.add_handler(CallbackQueryHandler(lambda u,c: u.callback_query.answer("💣 Бросай гранату прямо в бою!", show_alert=True), pattern="^inventory_grenade_hint$"))
    app.add_handler(CallbackQueryHandler(inventory_view,        pattern="^inventory$"))
    app.add_handler(CallbackQueryHandler(use_item,              pattern="^use_"))
    app.add_handler(CallbackQueryHandler(equip_item,            pattern="^equip_"))
    app.add_handler(CallbackQueryHandler(unequip_item,          pattern="^unequip_"))
    app.add_handler(CallbackQueryHandler(shop,                  pattern="^shop$"))
    app.add_handler(CallbackQueryHandler(shop_potions,          pattern="^shop_potions$"))
    app.add_handler(CallbackQueryHandler(shop_equipment,        pattern="^shop_equipment$"))
    app.add_handler(CallbackQueryHandler(shop_premium,          pattern="^shop_premium$"))
    app.add_handler(CallbackQueryHandler(buy_item,              pattern="^buy_(?!prop_|c|s)"))
    app.add_handler(CallbackQueryHandler(buy_crystal_item,      pattern="^buyc_"))
    app.add_handler(CallbackQueryHandler(top_players,           pattern="^top$"))
    app.add_handler(CallbackQueryHandler(diamonds_menu,         pattern="^diamonds$"))
    app.add_handler(CallbackQueryHandler(buy_stars,             pattern="^buystars_"))
    app.add_handler(CallbackQueryHandler(confirm_stars,          pattern="^confirm_stars_"))
    app.add_handler(CallbackQueryHandler(cancel_invoice,         pattern="^cancel_invoice$"))
    app.add_handler(CallbackQueryHandler(battle_action,         pattern="^battle_(?!prop_)"))
    app.add_handler(CallbackQueryHandler(battle_action,         pattern="^battle_prop_"))
    # Работа
    app.add_handler(CallbackQueryHandler(jobs_menu,             pattern="^jobs$"))
    app.add_handler(CallbackQueryHandler(job_info,              pattern="^job_info_"))
    app.add_handler(CallbackQueryHandler(job_hire,              pattern="^job_hire_"))
    app.add_handler(CallbackQueryHandler(job_quit_confirm,      pattern="^job_quit_confirm$"))
    app.add_handler(CallbackQueryHandler(job_quit_do,           pattern="^job_quit_do$"))
    app.add_handler(CallbackQueryHandler(job_need_passport,     pattern="^job_need_passport$"))
    app.add_handler(CallbackQueryHandler(job_collect,           pattern="^job_collect$"))
    app.add_handler(CallbackQueryHandler(captivity_bail,        pattern="^captivity_bail$"))
    app.add_handler(CallbackQueryHandler(captivity_wait,        pattern="^captivity_wait$"))
    # Бой
    app.add_handler(CallbackQueryHandler(capture_district_cb,   pattern="^capture_district_"))
    app.add_handler(CallbackQueryHandler(collect_district_cb,   pattern="^collect_district_"))
    app.add_handler(CallbackQueryHandler(abandon_battle,        pattern="^abandon_battle$"))
    # Co-op бой
    app.add_handler(CallbackQueryHandler(coop_cancel_invite,    pattern="^coop_cancel_"))

    app.add_handler(CallbackQueryHandler(coop_accept,           pattern="^coop_accept_"))
    app.add_handler(CallbackQueryHandler(coop_decline,          pattern="^coop_decline_"))
    app.add_handler(CallbackQueryHandler(coop_attack,           pattern="^coop_atk_"))
    app.add_handler(CallbackQueryHandler(coop_skill,            pattern="^coop_skill_"))
    app.add_handler(CallbackQueryHandler(coop_potion,           pattern="^coop_pot_"))
    app.add_handler(CallbackQueryHandler(coop_flee_action,      pattern="^coop_flee_"))
    # Рейды
    app.add_handler(CallbackQueryHandler(raid_defend,           pattern="^raid_defend_"))
    app.add_handler(CallbackQueryHandler(raid_add_mercs,        pattern="^raid_add_mercs$"))
    app.add_handler(CallbackQueryHandler(raid_invite_friend,    pattern="^raid_invite_friend_"))
    app.add_handler(CallbackQueryHandler(raid_battle_start,     pattern="^raid_battle_start$"))
    # Банда
    app.add_handler(CallbackQueryHandler(gang_menu,             pattern="^gang_menu$"))
    app.add_handler(CallbackQueryHandler(gang_menu,             pattern="^gang$"))
    app.add_handler(CallbackQueryHandler(gang_mercs_screen,     pattern="^gang_mercs_screen$"))
    app.add_handler(CallbackQueryHandler(my_districts,          pattern="^my_districts$"))
    app.add_handler(CallbackQueryHandler(gang_view,             pattern="^gang_view_"))
    app.add_handler(CallbackQueryHandler(intel_attack,          pattern="^intel_attack_"))
    app.add_handler(CallbackQueryHandler(gang_kick,             pattern="^gang_kick_"))
    app.add_handler(CallbackQueryHandler(gang_kick_do,          pattern="^gang_kick_do_"))
    app.add_handler(CallbackQueryHandler(gang_nocollect,        pattern="^gang_nocollect$"))
    app.add_handler(CallbackQueryHandler(gang_buy_merc,         pattern="^gang_buy_merc$"))
    app.add_handler(CallbackQueryHandler(gang_roles_info,       pattern="^gang_roles_info$"))
    app.add_handler(CallbackQueryHandler(gang_friends_menu,     pattern="^gang_friends$"))
    app.add_handler(CallbackQueryHandler(gang_friend_collect,   pattern="^gang_friend_collect_"))
    app.add_handler(CallbackQueryHandler(gang_role_info,        pattern="^gang_role_"))
    # Тюрьма / больница
    app.add_handler(CallbackQueryHandler(check_sub,             pattern="^check_sub$"))
    app.add_handler(CallbackQueryHandler(jail_bail,             pattern="^jail_bail$"))
    app.add_handler(CallbackQueryHandler(jail_wait,             pattern="^jail_wait$"))
    app.add_handler(CallbackQueryHandler(hospital,              pattern="^hospital_(?!heal)"))
    app.add_handler(CallbackQueryHandler(hospital_heal,         pattern="^hospital_heal_"))
    app.add_handler(CallbackQueryHandler(leave_hospital_cb,     pattern="^leave_hospital$"))
    # Связи / имущество / охрана
    app.add_handler(CallbackQueryHandler(my_contacts,           pattern="^my_contacts$"))
    app.add_handler(CallbackQueryHandler(use_contact_cb,        pattern="^use_contact_"))
    app.add_handler(CallbackQueryHandler(my_property,           pattern="^my_property$"))
    app.add_handler(CallbackQueryHandler(shop_property,         pattern="^shop_property$"))
    app.add_handler(CallbackQueryHandler(buy_prop,              pattern="^buy_prop_"))
    app.add_handler(CallbackQueryHandler(sell_prop,             pattern="^sell_prop_"))
    app.add_handler(CallbackQueryHandler(district_guard_menu,   pattern="^district_guard_"))
    app.add_handler(CallbackQueryHandler(guard_toggle,          pattern="^guard_toggle_"))
    # Казино / треки / встречи
    app.add_handler(CallbackQueryHandler(casino_menu,           pattern="^casino_(?!spin$)"))
    app.add_handler(CallbackQueryHandler(casino_spin,           pattern="^roulette_"))
    app.add_handler(CallbackQueryHandler(track_cb,              pattern="^track_"))
    app.add_handler(CallbackQueryHandler(encounter_action,      pattern="^enc_"))
    app.add_handler(CallbackQueryHandler(merc_heal,             pattern="^merc_heal_"))
    app.add_handler(CallbackQueryHandler(raid_flee,             pattern="^raid_flee_"))

    # Сборщик с друга (короткий callback gfc_<id> для длинных списков)
    app.add_handler(CallbackQueryHandler(gang_friend_collect,   pattern="^gfc_"))
    # Друг в отряд на охоту
    app.add_handler(CallbackQueryHandler(hunt_add_friend,       pattern="^hunt_add_friend_"))

    async def _error_handler(update, context):
        ignored = (
            "Query is too old",
            "query id is invalid",
            "CONNECTION_NOT_INITED",
            "Message is not modified",
            "Message to edit not found",
        )
        err = repr(getattr(context, "error", ""))
        if any(s in err for s in ignored):
            return
        try:
            logger.exception("Unhandled error: %s", context.error)
        except Exception:
            pass

    app.add_error_handler(_error_handler)

    logger.info("Bot starting (polling)...")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
