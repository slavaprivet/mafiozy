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
import shutil
import subprocess
import urllib.request
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
    return url, proc


def start_bot(api_url):
    env = os.environ.copy()
    if api_url:
        env["COOP_API_BASE"] = api_url
        log(f"COOP_API_BASE = {api_url}")
    log("Запускаю бота...")
    # Передаём управление боту — текущее окно становится консолью бота.
    return subprocess.call([sys.executable, str(BOT)], env=env)


def main():
    if not BOT.exists():
        log(f"[!] Не нашёл {BOT.name} рядом со скриптом.")
        sys.exit(1)
    download_cloudflared()
    api_url, tun_proc = start_tunnel()
    try:
        rc = start_bot(api_url)
    finally:
        if tun_proc and tun_proc.poll() is None:
            log("Гашу туннель...")
            try:
                tun_proc.terminate()
            except Exception:
                pass
    sys.exit(rc)


if __name__ == "__main__":
    main()
