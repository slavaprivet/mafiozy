"""
Лаунчер: поднимает Cloudflare Tunnel на :8080, ловит публичный URL,
экспортит его в COOP_API_BASE и запускает бот.

Зачем: Telegram Mini-App теперь общается с ботом по HTTP (без sendData),
чтобы при найме/увольнении НЕ ЗАКРЫВАЛСЯ. Это работает только если у бота
есть публичный https-адрес.

Cloudflared не требует регистрации и токенов — quick tunnel.
"""

import os
import re
import sys
import time
import json
import base64
import shutil
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

HERE = Path(__file__).resolve().parent
CFD  = HERE / "cloudflared.exe"
BOT  = HERE / "mafiozi_bot.py"

CFD_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
PORT = 8080
URL_RE = re.compile(rb"https://[a-z0-9\-]+\.trycloudflare\.com")


def log(msg, prefix="[tunnel]"):
    print(f"{prefix} {msg}", flush=True)


def download_cloudflared():
    if CFD.exists():
        log(f"cloudflared уже есть: {CFD.name} ({CFD.stat().st_size//1024//1024} МБ)")
        return
    log(f"Качаю cloudflared.exe из GitHub... ({CFD_URL.split('/')[-1]})")
    log("Это разово, ~25 МБ.")
    try:
        with urllib.request.urlopen(CFD_URL, timeout=120) as r, open(CFD, "wb") as f:
            shutil.copyfileobj(r, f)
        log(f"OK, скачано {CFD.stat().st_size//1024//1024} МБ")
    except Exception as e:
        log(f"[!] Не удалось скачать cloudflared: {e}")
        log("    Скачай вручную: " + CFD_URL)
        log(f"    Положи рядом с этим скриптом и назови {CFD.name}")
        sys.exit(2)


def start_tunnel():
    log(f"Стартую Cloudflare-туннель на http://localhost:{PORT} ...")
    log("(используем HTTP/2 — обходим блокировку UDP/QUIC у провайдера)")
    proc = subprocess.Popen(
        [str(CFD), "tunnel", "--url", f"http://localhost:{PORT}",
         "--protocol", "http2",
         "--edge-ip-version", "4",
         "--no-autoupdate", "--logfile", str(HERE / "cloudflared.log")],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
        bufsize=0,
    )

    url = None
    deadline = time.time() + 120
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            if proc.poll() is not None:
                break
            time.sleep(0.1)
            continue
        # print raw output too — для отладки
        try:
            sys.stdout.write(line.decode("utf-8", "replace"))
        except Exception:
            pass
        m = URL_RE.search(line)
        if m:
            url = m.group(0).decode("ascii")
            break

    if not url:
        log("[!] Не удалось получить URL туннеля за 120 секунд.")
        log("    Проверь cloudflared.log. Запускаю бота без туннеля.")
        try:
            proc.terminate()
        except Exception:
            pass
        return None, None

    log("=" * 60)
    log(f"ТУННЕЛЬ ГОТОВ: {url}")
    log("Теперь открой мини-апп в Telegram — найм/увольнение НЕ закроют его.")
    log("=" * 60)
    # Публикуем актуальный URL на GitHub Pages: hub.html у друзей, которые
    # пришли по share-ссылке (там в URL нет ?api=), теперь сможет подтянуть
    # его автоматически через fetch coop_api.json. Без этого «Бот без туннеля».
    try:
        publish_coop_api_json(url)
    except Exception as _e:
        log(f"[!] Публикация coop_api.json упала: {_e}")
        log("    Кооп-инвайты через share-ссылку могут не работать у новых юзеров.")
    return url, proc


def publish_coop_api_json(api_url: str):
    """Записывает coop_api.json в GitHub-репо mafiozi-battle (GitHub Pages).
    Содержимое: {"base": "<api_url>", "ts": <unix>}. hub.html у юзеров
    без api= в URL читает этот файл и использует base как COOP_API_BASE.

    Использует .token (GitHub Personal Access Token) рядом с этим скриптом.
    Если токена нет — тихо скипаем (для деплоев без auto-publish можно
    хардкодить api в URL хаба, как раньше)."""
    token_path = HERE / ".token"
    if not token_path.exists():
        log("[!] .token не найден — coop_api.json не публикуется.")
        log("    У друзей без бот-кнопки лобби работать не будет.")
        return
    token = token_path.read_text(encoding="utf-8").strip()
    if not token.startswith("ghp_"):
        log("[!] .token не похож на GitHub PAT (нет 'ghp_' префикса).")
        return

    repo   = "slavaprivet/mafiozi-battle"
    branch = "main"
    fname  = "coop_api.json"
    body   = {"base": api_url, "ts": int(time.time())}
    content_b64 = base64.b64encode(json.dumps(body, ensure_ascii=False).encode()).decode()

    def gh(method, path, payload=None):
        req = urllib.request.Request(
            "https://api.github.com" + path,
            json.dumps(payload).encode() if payload else None,
            method=method,
        )
        req.add_header("Authorization", "token " + token)
        req.add_header("Accept", "application/vnd.github.v3+json")
        req.add_header("User-Agent", "mafiozi-coop-api-publisher")
        if payload:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read()), r.status
        except urllib.error.HTTPError as e:
            try:
                return json.loads(e.read()), e.code
            except Exception:
                return {"message": str(e)}, e.code

    # 1) Узнаём текущий SHA (нужен GitHub-у для PUT — иначе 422 conflict).
    info, code = gh("GET", f"/repos/{repo}/contents/{fname}?ref={branch}")
    old_sha = info.get("sha") if code == 200 else None

    # 2) PUT новый файл.
    payload = {
        "message": f"coop_api.json update ({api_url})",
        "content": content_b64,
        "branch":  branch,
    }
    if old_sha:
        payload["sha"] = old_sha
    resp, code = gh("PUT", f"/repos/{repo}/contents/{fname}", payload)
    if code in (200, 201):
        log(f"coop_api.json опубликован → https://slavaprivet.github.io/mafiozi-battle/{fname}")
    else:
        log(f"[!] coop_api.json PUT HTTP {code}: {resp}")


def start_bot(api_url):
    env = os.environ.copy()
    if api_url:
        env["COOP_API_BASE"] = api_url
        log(f"COOP_API_BASE = {api_url}")
    log("Запускаю бота...")
    # Передаём управление боту — текущее окно становится консолью бота.
    return subprocess.call([sys.executable, str(BOT)], env=env)


def _hold_window(reason: str):
    """Не даём окну закрыться — иначе при двойном клике юзер не успеет
    прочитать ошибку. Срабатывает на любом неудачном завершении."""
    print()
    print("=" * 60)
    print(f"[!] {reason}")
    print("=" * 60)
    print("Окно НЕ закрывается автоматически — посмотри вывод выше.")
    print("Самые частые причины:")
    print("  1) Нет файла .bot-token рядом со скриптом (скопируй из")
    print("     bot-token-backup.txt с десктопа).")
    print("  2) Не хватает зависимости — поставь:")
    print("     pip install python-telegram-bot aiosqlite aiohttp")
    print("  3) Конфликт getUpdates — другой инстанс бота уже запущен,")
    print("     закрой остальные окна с ботом и попробуй снова.")
    print()
    try:
        input("Нажми Enter чтобы закрыть окно... ")
    except (EOFError, KeyboardInterrupt):
        pass


def main():
    if not BOT.exists():
        log(f"[!] Не нашёл {BOT.name} рядом со скриптом.")
        _hold_window("mafiozi_bot.py не найден в этой папке.")
        sys.exit(1)
    download_cloudflared()
    api_url, tun_proc = start_tunnel()
    rc = 1
    crashed = False
    try:
        rc = start_bot(api_url)
    except Exception as e:
        crashed = True
        log(f"[!] Бот упал с исключением: {e}")
    finally:
        if tun_proc and tun_proc.poll() is None:
            log("Гашу туннель...")
            try:
                tun_proc.terminate()
            except Exception:
                pass
    if rc != 0 or crashed:
        _hold_window(f"Бот завершился с кодом {rc}. Прокрути вверх — там traceback.")
    sys.exit(rc)


if __name__ == "__main__":
    main()
