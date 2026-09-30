from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
old=root/'outputs/coordinator23_cargo_perf13'
new=root/'outputs/coordinator24_cargo_input/perf20tools'
assert not new.exists();new.mkdir()
old_sha='ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e'
base_sha='8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741'
proof=[]
for name in ['capture.gd','run_pair_side.py','compare.py']:
    source=(old/name).read_bytes()
    value=source.decode('utf8').replace(old_sha,base_sha).replace('accepted11','accepted16')
    (new/name).write_bytes(value.encode('utf8'))
    proof.append({'path':name,'source_sha256':hashlib.sha256(source).hexdigest(),'after_sha256':hashlib.sha256(value.encode('utf8')).hexdigest()})
(new/'DERIVATION.json').write_text(json.dumps({'changes':'Only allowed baseline pack pin/label updated 11 to16. Same3NPC/8buildings/377colliders/14cargo/100units, original attached camera, three240frame phases. No native-input proof.','files':proof},indent=2)+'\n',encoding='utf8')
print('Prepared identical pair harness with exact accepted16 baseline')
