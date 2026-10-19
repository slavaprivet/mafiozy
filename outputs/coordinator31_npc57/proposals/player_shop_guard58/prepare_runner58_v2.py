from pathlib import Path
HERE=Path(__file__).resolve().parent
source=(HERE/'run_guard58.py').read_text(encoding='utf-8')
start=source.index('after=pins();after_patch=');end=source.index("save(run/'SOURCE.json'",start)
source=source[:start]+'after=pins();after_cp={str(p):sha(p) for p in controls}\n'+source[end:]
source=source.replace("HERE/'prepare_runner58.py'","HERE/'prepare_runner58_v2.py',HERE/'prepare_runner58.py'")
target=HERE/'run_guard58_v2.py';assert not target.exists();target.write_text(source,encoding='utf-8')
