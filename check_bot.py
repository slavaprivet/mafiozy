import ast, sys
with open('mafiozi_bot.py', 'r', encoding='utf-8') as f:
    src = f.read()
lines = src.splitlines()
last = lines[-1].strip() if lines else ''
if not src.strip().endswith('main()'):
    print(f'[!] ФАЙЛ ПОВРЕЖДЁН — последняя строка: {repr(last[:60])}')
    sys.exit(1)
try:
    ast.parse(src)
    print(f'[OK] Файл бота в порядке ({len(lines)} строк)')
except SyntaxError as e:
    print(f'[!] Синтаксическая ошибка в строке {e.lineno}: {e.text}')
    sys.exit(1)
