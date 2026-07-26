"""
Установщик Ruflo для проекта Мафиози
"""
import subprocess, sys, os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

def run(cmd):
    print(f"\n>>> {cmd}")
    return subprocess.run(cmd, shell=True).returncode == 0

print("=" * 50)
print("  Установка Ruflo для проекта Мафиози")
print("=" * 50)

print("\n[1/3] Проверка Node.js...")
if not run("node --version"):
    print("ОШИБКА: Node.js не найден!")
    input("Enter..."); sys.exit(1)
run("npm --version")

# --yes = автоматически соглашаться с установкой пакета
print("\n[2/3] Установка Ruflo...")
ok = run("npx --yes ruflo@latest init --no-wizard")
if not ok:
    print("Пробую без --no-wizard...")
    run("npx --yes ruflo@latest init")

print("\n[3/3] Регистрация в Claude Code...")
run("claude mcp add ruflo -- npx ruflo@latest mcp start")

print("\n" + "=" * 50)
print("  ГОТОВО! Открой Claude Code в папке Мафиози")
print("  и используй /sparc, /swarm, /memory")
print("=" * 50)
input("\nНажми Enter для выхода...")
