from pathlib import Path
HERE=Path(__file__).resolve().parent
source=(HERE/'run_parse58.py').read_text(encoding='utf-8')
source=source.replace("entry_parse58.gd","entry_parse58_v2.gd")
source=source.replace("controls=[HERE/'PATCH.json'", "controls=[HERE/'NEW_RESOURCES58.zip',HERE/'prepare_parse_v2.py',HERE/'PATCH.json'")
source=source.replace("cp={str(p):sha(p) for p in controls}", "with zipfile.ZipFile(HERE/'NEW_RESOURCES58.zip','w',zipfile.ZIP_DEFLATED) as z:\n    for row in patch['files']:\n        if row['base_sha256'] is None:z.write(HERE/'patch'/row['path'],row['path'])\ncp={str(p):sha(p) for p in controls}", 1)
target=HERE/'run_parse58_v2.py'
assert not target.exists()
target.write_text(source,encoding='utf-8')
