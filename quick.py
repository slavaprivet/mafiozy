# -*- coding: utf-8 -*-
"""
quick.py — ДЕШЁВЫЙ локальный исполнитель ЛЁГКИХ задач по игре «Мафиози».

Идея: сложное делаем на Opus (Claude), а рутину (мелкие правки, справки, объяснения,
черновики) гоняем тут — на дешёвой/бесплатной модели (Groq/DeepSeek/Cerebras), чтобы НЕ
жечь лимиты Opus. Контекст берётся точечно: по карте+графу (graphify.json) находятся
релевантные функции, из локальных world.html / mafiozi_bot.py режутся только их куски —
в модель уходит ~1–3K токенов, а не монолит.

Режимы:
  python quick.py "где логика ограбления банка?"        # ответ/совет (файлы не трогает)
  python quick.py -e "переименуй showToast в showHint"  # предложить правку (показать diff)
  python quick.py -e "..." --yes                          # ... и применить (бэкап + проверка)
  python quick.py "..." --dry                             # не звонить в API, показать запрос+оценку
Опции: --depth N (сколько функций в контекст, деф. 6), --provider/--model/--base (разово),
       --save-key PROVIDER KEY (записать ключ в ai_config.json, он в .gitignore).

Ключ ищется: ai_config.json рядом → env (GROQ_API_KEY / DEEPSEEK_API_KEY / CEREBRAS_API_KEY).
"""
import sys, os, re, json, argparse, urllib.request, urllib.error, datetime

try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass

HERE = os.path.dirname(os.path.abspath(__file__))
GRAPH = os.path.join(HERE, "graphify.json")
CFG   = os.path.join(HERE, "ai_config.json")
SRC_FILE = {"client": os.path.join(HERE, "world.html"), "server": os.path.join(HERE, "mafiozi_bot.py")}

PROVIDERS = {
    "groq":       {"base": "https://api.groq.com/openai/v1", "model": "llama-3.3-70b-versatile", "env": "GROQ_API_KEY"},
    "deepseek":   {"base": "https://api.deepseek.com",       "model": "deepseek-chat",           "env": "DEEPSEEK_API_KEY"},
    "cerebras":   {"base": "https://api.cerebras.ai/v1",     "model": "llama-3.3-70b",           "env": "CEREBRAS_API_KEY"},
    "openrouter": {"base": "https://openrouter.ai/api/v1",   "model": "deepseek/deepseek-chat",  "env": "OPENROUTER_API_KEY"},
}

# Запасной источник ключа: .env твоего game-dev-bot (там уже лежат Groq/DeepSeek/…).
# Так quick.py работает без отдельной настройки и БЕЗ копирования секрета.
BOT_ENV = r"C:\Users\Слава\Desktop\game-dev-bot\.env"

def read_bot_env_key(var):
    try:
        txt = open(BOT_ENV, encoding="utf-8").read()
        m = re.search(r"^\s*" + re.escape(var) + r"\s*=\s*(.*)$", txt, re.M)
        if m:
            return m.group(1).strip().strip('"').strip("'")
    except Exception:
        pass
    return ""

KW2CAT = [
    (["банк","ограбл","сейф","хранилищ","vault","bank","rob","heist"], ["банк"]),
    (["тюрьм","арест","prison","jail","решёт","решет","посад"], ["тюрьма"]),
    (["коп","копы","полиц","розыск","звезд","звёзд","wanted","cop","снитч","свидетел","witness"], ["копы"]),
    (["стрел","выстрел","оруж","пул","урон","убил","смерт","бой","weapon","shoot","fire","damage","kill","здоров","рукопаш","melee"], ["стрельба","бой"]),
    (["машин","авто","тачк","трафик","car","drive","руль","ехать","vehicle"], ["машины"]),
    (["рендер","рисов","экран","спрайт","анимаци","draw","render","камер","cam","изо","iso"], ["рендер"]),
    (["нпс","npc","житель","прохож","охран","толп","ped","civilian"], ["npc"]),
    (["сеть","сетев","снапшот","сервер","вебсокет","websocket","snapshot","синхрон","пакет","sync","input"], ["сеть","снапшот"]),
    (["интерфейс","кнопк","меню","hud","тост","баннер","модал","магазин","shop","overlay"], ["ui"]),
    (["карт","тайл","map","tile","коллиз","проход","passable"], ["карта"]),
    (["игрок","персонаж","player","спавн","респаун","больниц","лечени","heal","профил"], ["игрок"]),
    (["звук","аудио","sound","audio","sfx","музык","haptic"], ["звук"]),
    (["деньг","экономик","бизнес","cash","money","награ","зарплат","price","цена","купить","продать"], ["экономика"]),
    (["территор","захват","банд","gang","territory","участок","lair"], ["территории"]),
    (["событи","ивент","event","миша","michael","босс","boss"], ["события"]),
    (["сохран","баз","sqlite","persist","redis"], ["бд"]),
    (["телеграм","команд","старт","webapp","handler"], ["телеграм"]),
]

SYS = None  # заполняется после загрузки graph (нужны repo-имена)


def load_graph():
    if not os.path.exists(GRAPH):
        sys.exit("[!] Нет graphify.json — сначала: python gen_graphify.py")
    with open(GRAPH, encoding="utf-8") as f:
        d = json.load(f)
    syms = ([dict(s, side="client") for s in d["client"]["symbols"]]
            + [dict(s, side="server") for s in d["server"]["symbols"]])
    starts = {"client": sorted({s["l"] for s in d["client"]["symbols"]}),
              "server": sorted({s["l"] for s in d["server"]["symbols"]})}
    return d, syms, starts


def end_line(starts, side, l):
    nxt = None
    for x in starts[side]:
        if x > l and (nxt is None or x < nxt):
            nxt = x
    return nxt if nxt else l + 200


def retrieve(question, syms, depth):
    ql = question.lower()
    words = [w for w in re.findall(r"[^\W\d_][\w]*", ql, re.UNICODE) if len(w) >= 3]
    cats = set()
    for kws, cs in KW2CAT:
        if any(any(w == k or w.startswith(k) for w in words) for k in kws):
            cats.update(cs)
    en = [w for w in words if re.fullmatch(r"[a-z0-9_]+", w)]
    scored = []
    for s in syms:
        sc = 0.0
        nl = s["n"].lower()
        for w in en:
            if w in nl:
                sc += 10
        if any(c in s["cat"] for c in cats):
            sc += 4
        sc += min(len(s.get("calledBy", [])), 30) * 0.05
        if sc > 0:
            scored.append((sc, s))
    scored.sort(key=lambda x: -x[0])
    if not scored:
        scored = [(0, s) for s in sorted(syms, key=lambda s: -len(s.get("calledBy", [])))[:min(depth, 4)]]
    return [s for _, s in scored[:depth]]


def build_context(picked, starts, repos, max_chars=14000, max_lines=160):
    cache = {}
    out, total = [], 0
    for s in picked:
        side = s["side"]
        if side not in cache:
            try:
                with open(SRC_FILE[side], encoding="utf-8") as f:
                    cache[side] = f.read().splitlines()
            except Exception as e:
                cache[side] = None
        code = "// (исходник не найден)" if not cache[side] else "\n".join(
            cache[side][s["l"]-1: min(end_line(starts, side, s["l"]), s["l"]+max_lines)-1])
        file = repos["client"]["file"] if side == "client" else repos["server"]["file"]
        head = (f'### {"КЛИЕНТ" if side=="client" else "СЕРВЕР"} {file}:{s["l"]}  [{s["cat"]}]  {s["n"]}\n'
                f'вызывает: {", ".join(s.get("calls", [])[:12]) or "—"}\n'
                f'вызывают: {", ".join(s.get("calledBy", [])[:12]) or "—"}\n')
        block = head + "```\n" + code + "\n```\n"
        if total + len(block) > max_chars:
            block = head + "```\n" + code[:max(0, max_chars-total-len(head)-16)] + "\n…(обрезано)\n```\n"
            out.append(block); break
        out.append(block); total += len(block)
    return "\n".join(out)


def make_sys(repos):
    return (
"Ты — ассистент-разработчик игры «Мафиози» (Telegram WebApp, изометрический онлайн-мир).\n"
"Архитектура:\n"
f"• world.html — КЛИЕНТ (рендер, ввод, локальные NPC, физика), репо {repos['client']['repo']}.\n"
f"• mafiozi_bot.py — СЕРВЕР (Python; авторитет: hp/смерть/тюрьма/wanted/деньги/снапшоты), репо {repos['server']['repo']}.\n"
"• WebSocket: клиент шлёт input/shoot/bank_rob_*/citycop_arrest, сервер шлёт snapshot.\n"
"ГРАБЛИ (не нарушай):\n"
"1) В банк-интерьере player.r/c — ЛОКАЛЬНЫЕ координаты; нельзя слать серверу пока _bankInt.\n"
"2) Серверный снапшот перетирает hp/dead/jail_in; локальная смерть держится _localDeath; _bankShield() гасит серверные воздействия в банке/6с после.\n"
"3) Тюрьма: кламп в квадрат двора ±3 от JAIL_CENTER(76,76).\n"
"4) В банке render() не доходит до мировых drawBullets() — боевые эффекты звать внутри банковского рендера.\n"
"5) Урон охраны банка — только локальный _hurtLocal.\n"
"Тебе дают ТОЛЬКО релевантные функции с кодом и связями. Опирайся на них; если функции нет — назови её имя, не выдумывай.\n"
"Отвечай кратко, по-русски, указывай файл:строку.")


def load_cfg(args):
    cfg = {}
    if os.path.exists(CFG):
        try:
            with open(CFG, encoding="utf-8") as f: cfg = json.load(f)
        except Exception: cfg = {}
    prov = args.provider or cfg.get("provider") or "groq"
    p = PROVIDERS.get(prov, PROVIDERS["groq"])
    base = args.base or cfg.get("base") or p["base"]
    model = args.model or cfg.get("model") or p["model"]
    key = cfg.get("key") or os.environ.get(p["env"], "") or read_bot_env_key(p["env"])
    return {"provider": prov, "base": base, "model": model, "key": key}


def call_llm(cfg, messages, max_tokens=1400, model=None):
    body = json.dumps({"model": model or cfg["model"], "messages": messages,
                       "temperature": 0.2, "max_tokens": max_tokens, "stream": False}).encode()
    req = urllib.request.Request(cfg["base"].rstrip("/") + "/chat/completions", body, method="POST")
    req.add_header("Authorization", "Bearer " + cfg["key"])
    req.add_header("Content-Type", "application/json")
    if "openrouter" in cfg["base"]:
        req.add_header("HTTP-Referer", "https://slavaprivet.github.io/mafiozi-battle/")
        req.add_header("X-Title", "mafiozi-quick")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            j = json.loads(r.read())
        text = j["choices"][0]["message"].get("content") or ""
        if not text.strip():
            raise RuntimeError("модель вернула пустой ответ — попробую другую")
        return text
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode(errors='replace')[:200]}")


def or_free_models(key):
    """Список бесплатных моделей OpenRouter, сильные для кода — вперёд."""
    try:
        req = urllib.request.Request("https://openrouter.ai/api/v1/models")
        req.add_header("Authorization", "Bearer " + key)
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read())["data"]
    except Exception:
        return []
    skip = {"safety", "guard", "moderat", "classify", "embed", "vision", "image", "audio", "tts"}
    free = [m["id"] for m in data
            if str(m.get("pricing", {}).get("prompt")) in ("0", "0.0")
            and str(m.get("pricing", {}).get("completion")) in ("0", "0.0")
            and not any(k in m["id"].lower() for k in skip)]
    pri = ["deepseek", "qwen", "llama-3.3", "llama-3.1-70b", "mistral", "gemini", "llama"]
    free.sort(key=lambda mid: next((i for i, kw in enumerate(pri) if kw in mid.lower()), 99))
    return free


def robust_call(cfg, messages, max_tokens=1400):
    """Зовёт модель; для OpenRouter при 429/ошибке перебирает живые бесплатные модели."""
    try:
        return call_llm(cfg, messages, max_tokens)
    except Exception as e:
        if cfg["provider"] != "openrouter":
            raise
        sys.stderr.write(f"[i] {cfg['model']} недоступна ({e}); ищу другую бесплатную…\n")
        for mid in or_free_models(cfg["key"]):
            if mid == cfg["model"]:
                continue
            try:
                ans = call_llm(cfg, messages, max_tokens, model=mid)
                sys.stderr.write(f"[i] ответ от {mid}\n")
                return ans
            except Exception:
                continue
        raise RuntimeError("все бесплатные модели OpenRouter сейчас заняты (429) — повтори позже или пополни баланс")


def apply_edit(answer):
    """Ищет блок FILE/FIND/REPLACE в ответе, применяет к локальному файлу с бэкапом."""
    m = re.search(r"FILE:\s*(\S+).*?<<<+\s*FIND\s*\n(.*?)\n=+\s*\n(.*?)\n>>>+\s*REPLACE",
                  answer, re.DOTALL)
    if not m:
        print("\n[i] Модель не вернула блок FILE/FIND/REPLACE — применять нечего.")
        return False
    fname, find, repl = m.group(1).strip(), m.group(2), m.group(3)
    path = os.path.join(HERE, os.path.basename(fname))
    if not os.path.exists(path):
        print(f"[!] Файл не найден: {path}"); return False
    with open(path, encoding="utf-8") as f: src = f.read()
    n = src.count(find)
    if n == 0:
        print("[!] FIND-блок не найден в файле (код мог измениться) — НЕ применяю."); return False
    if n > 1:
        print(f"[!] FIND-блок встречается {n} раз — неоднозначно, НЕ применяю."); return False
    bak = path + f".bak-quick-{datetime.datetime.now():%Y%m%d-%H%M%S}"
    with open(bak, "w", encoding="utf-8") as f: f.write(src)
    with open(path, "w", encoding="utf-8") as f: f.write(src.replace(find, repl, 1))
    print(f"[+] Применено к {os.path.basename(path)} (бэкап: {os.path.basename(bak)})")
    # проверка синтаксиса для клиента
    if os.path.basename(path) == "world.html":
        try:
            from check_world import check_html_js
            if check_html_js(path) != 0:
                with open(path, "w", encoding="utf-8") as f: f.write(src)
                print("[!] СИНТАКСИС СЛОМАН — откатил из бэкапа. Правку отдай Opus.")
                return False
            print("[+] Проверка синтаксиса (node) прошла.")
        except ImportError:
            print("[i] check_world.py не найден — пропускаю проверку синтаксиса.")
    return True


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("task", nargs="*", help="задача/вопрос")
    ap.add_argument("-e", "--edit", action="store_true", help="режим правки (предложить diff)")
    ap.add_argument("--yes", action="store_true", help="применить правку без подтверждения")
    ap.add_argument("--depth", type=int, default=6)
    ap.add_argument("--provider"); ap.add_argument("--model"); ap.add_argument("--base")
    ap.add_argument("--dry", action="store_true", help="не звонить в API: показать контекст и оценку")
    ap.add_argument("--save-key", nargs=2, metavar=("PROVIDER", "KEY"))
    args = ap.parse_args()

    if args.save_key:
        prov, key = args.save_key
        p = PROVIDERS.get(prov)
        if not p: sys.exit("[!] провайдер: groq|deepseek|cerebras")
        with open(CFG, "w", encoding="utf-8") as f:
            json.dump({"provider": prov, "base": p["base"], "model": p["model"], "key": key}, f, ensure_ascii=False, indent=1)
        print(f"[+] Ключ сохранён в {CFG} (он в .gitignore). Проверь: python quick.py \"привет\" --dry")
        return

    task = " ".join(args.task).strip()
    if not task:
        sys.exit('Пример: python quick.py "где логика ограбления банка?"')

    d, syms, starts = load_graph()
    picked = retrieve(task, syms, args.depth)
    ctx = build_context(picked, starts, d["repos"])
    sys_prompt = make_sys(d["repos"])

    instr = task
    if args.edit:
        instr = (task + "\n\nЕсли предлагаешь правку — верни ОДИН блок строго в формате:\n"
                 "FILE: <world.html|mafiozi_bot.py>\n<<<<<<< FIND\n<точный существующий код>\n=======\n<новый код>\n>>>>>>> REPLACE\n"
                 "FIND должен ТОЧНО совпадать с куском из контекста (с отступами).")
    user = f"Контекст — только релевантные функции (код + связи):\n\n{ctx}\n\nЗАДАЧА: {instr}"
    messages = [{"role": "system", "content": sys_prompt}, {"role": "user", "content": user}]
    est = (len(sys_prompt) + len(user)) // 4

    print("Контекст:", ", ".join(f'{s["n"]}:{s["l"]}' for s in picked) or "(по архитектуре)")
    print(f"~{est} токенов в запросе  ·  провайдер: {load_cfg(args)['provider']} · {load_cfg(args)['model']}\n")
    if args.dry:
        print("— DRY —\n" + user[:2000] + ("\n…(обрезано)" if len(user) > 2000 else ""))
        return

    cfg = load_cfg(args)
    if not cfg["key"]:
        sys.exit("[!] Нет ключа. Задай: python quick.py --save-key groq ВАШ_КЛЮЧ  (или env GROQ_API_KEY)")

    try:
        answer = robust_call(cfg, messages)
    except Exception as e:
        sys.exit(f"[!] {e}")
    print("─" * 60 + "\n" + (answer or "(пустой ответ)") + "\n" + "─" * 60)

    if args.edit:
        if args.yes:
            apply_edit(answer)
        else:
            print("\n[i] Это предпросмотр. Применить: повтори с --yes  (будет бэкап + проверка синтаксиса).")


if __name__ == "__main__":
    main()
