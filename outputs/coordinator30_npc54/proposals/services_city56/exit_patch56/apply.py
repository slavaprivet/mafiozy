import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);p.add_argument('--apply',action='store_true');a=p.parse_args()
meta=json.loads((Path(__file__).parent/'PATCH.json').read_text(encoding='utf-8'))
target=a.project.resolve()/meta['path'];raw=target.read_bytes(); sha=hashlib.sha256(raw).hexdigest()
if sha==meta['candidate_sha256']:print('ALREADY_APPLIED');raise SystemExit(0)
assert sha==meta['base_sha256'],'Unexpected source; root must review exact scoped hunks against new source'
s=raw.decode('utf-8').replace('\r\n','\n')
for h in meta['hunks']:
 assert s.count(h['before'])==1
 s=s.replace(h['before'],h['after'])
assert hashlib.sha256(s.encode()).hexdigest()==meta['candidate_sha256']
if a.apply:target.write_bytes(s.encode())
print('APPLIED' if a.apply else 'PREFLIGHT_OK')
