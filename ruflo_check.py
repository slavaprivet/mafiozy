"""Проверка установки Ruflo - пишет результат в ruflo_check_result.txt"""
import subprocess, sys, os, datetime

os.chdir(os.path.dirname(os.path.abspath(__file__)))
log = open("ruflo_check_result.txt", "w", encoding="utf-8")

def run(cmd):
    log.write(f"\n>>> {cmd}\n")
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    log.write(r.stdout or "")
    if r.stderr: log.write("STDERR: " + r.stderr)
    log.write(f"[exit code: {r.returncode}]\n")
    return r.returncode == 0

log.write(f"=== Ruflo Check {datetime.datetime.now()} ===\n")

run("node --version")
run("npm --version")
run("npx ruflo@latest --version 2>&1")
run("claude mcp list 2>&1")

# Попытка установить если нет
log.write("\n=== Установка Ruflo ===\n")
run("npx ruflo@latest init --no-wizard 2>&1")
run("claude mcp add ruflo -- npx ruflo@latest mcp start 2>&1")
run("claude mcp list 2>&1")

log.write("\n=== ГОТОВО ===\n")
log.close()
print("Готово! Открой ruflo_check_result.txt")
