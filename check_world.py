# -*- coding: utf-8 -*-
"""
Проверка синтаксиса JS внутри world.html (или любого .html) через `node --check`.

Зачем: world.html — монолит на 30k строк. Опечатка/незакрытая скобка → белый
экран в игре, причём заливка прошла бы «успешно». Этот скрипт извлекает <script>
и прогоняет node --check ДО заливки. Используется github_upload_world.py и можно
запускать вручную:  python check_world.py [путь/к/world.html]

Возврат: exit 0 — синтаксис ок; exit 1 — ошибка (печатает строку/колонку).
Если node не установлен — печатает предупреждение и возвращает 0 (не блокирует).
"""
import re, sys, os, subprocess, tempfile

def check_html_js(path):
    if not os.path.exists(path):
        print(f"[check] файл не найден: {path}")
        return 1
    with open(path, encoding="utf-8") as f:
        html = f.read()

    # Берём содержимое всех инлайн-<script> без src= и без type=модуль/json/etc.
    blocks = []
    for m in re.finditer(r"<script\b([^>]*)>(.*?)</script>", html, re.S | re.I):
        attrs, body = m.group(1), m.group(2)
        if re.search(r"\bsrc\s*=", attrs, re.I):
            continue  # внешний скрипт — нечего проверять
        mt = re.search(r'type\s*=\s*["\']([^"\']+)["\']', attrs, re.I)
        if mt and mt.group(1).lower() not in ("text/javascript", "application/javascript", "module"):
            continue  # не-JS (напр. application/json) — пропускаем
        # смещение начала body в файле → для корректных номеров строк
        start_line = html[:m.start(2)].count("\n") + 1
        blocks.append((start_line, body))

    if not blocks:
        print("[check] инлайн-JS не найден — пропускаю")
        return 0

    # node доступен?
    try:
        subprocess.run(["node", "--version"], capture_output=True, check=True)
    except Exception:
        print("[check] node не найден — пропускаю проверку синтаксиса (не блокирую)")
        return 0

    rc_total = 0
    for idx, (start_line, body) in enumerate(blocks):
        # Сдвигаем тело вниз пустыми строками, чтобы номер строки в ошибке node
        # совпал с номером строки в world.html.
        padded = ("\n" * (start_line - 1)) + body
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as tf:
            tf.write(padded)
            tmp = tf.name
        try:
            r = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)
            if r.returncode != 0:
                rc_total = 1
                print(f"[check] [FAIL] СИНТАКСИЧЕСКАЯ ОШИБКА в <script> #{idx+1} ({os.path.basename(path)}):")
                # node печатает путь tmp — заменяем на имя html для ясности
                msg = (r.stderr or r.stdout).replace(tmp, os.path.basename(path))
                print(msg.strip())
            else:
                print(f"[check] [OK] <script> #{idx+1}: синтаксис OK ({body.count(chr(10))+1} строк)")
        finally:
            try: os.unlink(tmp)
            except OSError: pass
    return rc_total

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "world.html")
    sys.exit(check_html_js(target))
