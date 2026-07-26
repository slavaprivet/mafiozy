"""Ищет claude.exe и регистрирует Ruflo MCP"""
import subprocess, os, glob

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Ищем claude в типичных местах
candidates = [
    r"C:\Users\Слава\AppData\Local\Programs\claude\claude.exe",
    r"C:\Users\Слава\AppData\Roaming\npm\claude.cmd",
    r"C:\Users\Слава\AppData\Roaming\npm\claude",
    r"C:\Program Files\claude\claude.exe",
]

# Также ищем через where
r = subprocess.run("where claude 2>nul", shell=True, capture_output=True, text=True)
if r.stdout.strip():
    candidates.insert(0, r.stdout.strip().split('\n')[0].strip())

r2 = subprocess.run("where npx 2>nul", shell=True, capture_output=True, text=True)
npx_path = r2.stdout.strip().split('\n')[0].strip() if r2.stdout.strip() else "npx"

print(f"npx: {npx_path}")

claude_path = None
for c in candidates:
    if os.path.exists(c):
        claude_path = c
        print(f"Найден claude: {c}")
        break

if not claude_path:
    # Попробуем найти через glob
    for pattern in [
        r"C:\Users\Слава\AppData\Local\**\claude.exe",
        r"C:\Users\Слава\AppData\Roaming\**\claude.cmd",
    ]:
        found = glob.glob(pattern, recursive=True)
        if found:
            claude_path = found[0]
            print(f"Найден claude (glob): {claude_path}")
            break

if claude_path:
    cmd = f'"{claude_path}" mcp add ruflo -- npx ruflo@latest mcp start'
    print(f"\n>>> {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(result.stdout)
    if result.stderr: print("STDERR:", result.stderr)
    print(f"Exit: {result.returncode}")
else:
    print("\nclaude не найден. Пробуем через npx напрямую...")
    # claude-flow может работать и без регистрации через claude mcp
    # Проверим что ruflo уже работает
    r3 = subprocess.run("npx --yes ruflo@latest --version", shell=True, capture_output=True, text=True)
    print("ruflo version:", r3.stdout.strip() or r3.stderr.strip())

    print("\n--- claude не установлен как CLI-команда ---")
    print("Ruflo V3 Runtime уже работает через хуки в settings.json.")
    print("Команды /sparc /swarm /memory доступны в Claude Code.")

input("\nНажми Enter для выхода...")
