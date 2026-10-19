from pathlib import Path
import hashlib, json
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'service_threat58'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['observer58.gd','observer_base58.gd']:
    p=HERE/name;assert not p.exists();p.write_bytes((OLD/name).read_bytes())
runner=(OLD/'run58.py').read_text(encoding='utf-8-sig')
runner=runner.replace('Exact stage02 candidate58 service-interruption QA; default plan, no game copy.', 'Exact stage02 plus two-file service flee overlay; default plan, no game copy.')
runner=runner.replace("files=[HERE/name for name in ['entry58.gd','observer58.gd','observer_base58.gd','run58.py','prepare58.py']]", """patch=read(HERE/'PATCH.json')
    need(set(patch)=={'scripts/city/runtime/npc_threat_route30.gd','scripts/city/runtime/npc_threat_life30.gd'},'Exact two-file overlay required')
    for rel,entry in patch.items():
        need(expected[rel]==entry['base_sha256'] and sha(HERE/'patch'/rel)==entry['candidate_sha256'],'Patch/base pin mismatch: '+rel)
    files=[HERE/name for name in ['entry58.gd','observer58.gd','observer_base58.gd','run58.py','prepare_fixture58.py','build_patch58.py','PATCH.json','unit58.gd']]+[HERE/'patch'/rel for rel in patch]""")
runner=runner.replace("*files,HERE/'PREPARATION58.json'", "*files,HERE/'PREPARATION58.json'")
runner=runner.replace("choices=['shop','restaurant']", "choices=['shop','restaurant','budget']")
runner=runner.replace("'source_stage':'stage58_02'", "'source_stage':'stage58_02+service_flee58_overlay','overlay_only':True,'patch':read(HERE/'PATCH.json')")
runner=runner.replace("native=read(run/'SERVICE_THREAT58.json')", "native_path=run/('UNIT58.json' if args.case=='budget' else 'SERVICE_THREAT58.json')\n            native=read(native_path)")
runner=runner.replace("sha(run/'SERVICE_THREAT58.json')", "sha(native_path)")
assert runner!=(OLD/'run58.py').read_text(encoding='utf-8-sig')
assert not (HERE/'run58.py').exists()
(HERE/'run58.py').write_text(runner,encoding='utf-8',newline='\n')
(HERE/'PREPARATION58.json').write_text(json.dumps({'baseline_harness_pins':{name:sha(OLD/name) for name in ['run58.py','observer58.gd','observer_base58.gd']},'observer_bytes_unchanged':True,'patch':json.loads((HERE/'PATCH.json').read_text()),'no_production_changes':True,'no_engine_started':True},indent=2)+'\n',encoding='utf-8')
print('Prepared exact copied observers and overlay runner')
