import pathlib,json,hashlib,shutil
OUT=pathlib.Path(__file__).resolve().parent
SOURCE=OUT.parents[1]/'outputs/coordinator29_npc53/proposals/navigation29_avoidance'
DEST=OUT/'proposals/avoidance30'
manifest=json.loads((SOURCE/'SOURCE_CANDIDATE29.json').read_text(encoding='utf-8'))
assert not DEST.exists()
for item in manifest['files']:
    source=SOURCE/item['path']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'], item['path']
for item in manifest['files']:
    source=SOURCE/item['path'];target=DEST/item['path']
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
shutil.copy2(SOURCE/'SOURCE_CANDIDATE29.json',DEST/'UPSTREAM_MANIFEST.json')
runner=DEST/'run_fixtures29.py'
text=runner.read_text(encoding='utf-8').replace("wait_seconds=30", "wait_seconds=120").replace("'--wait-seconds', '30'", "'--wait-seconds', '120'")
runner.write_text(text,encoding='utf-8')
print(json.dumps({'copied':len(manifest['files']),'source_unchanged':True,'destination':str(DEST)}))
