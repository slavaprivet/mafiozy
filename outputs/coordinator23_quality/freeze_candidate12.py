from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2];stage=root/'outputs/coordinator23_quality/candidate12'
manifest=json.loads((stage/'INTEGRATION.json').read_text(encoding='utf8'))
for name in ['preview_weapons.gd','preview_weapon_cargo.gd']:
    path='scripts/weapons/'+name;p=stage/'godot/mafiozi_walk'/path
    proposed=root/'outputs/coordinator23_cargo_return12/invalidation'/name
    assert p.read_text(encoding='utf8')==proposed.read_text(encoding='utf8')
    p.write_bytes(proposed.read_bytes())
    manifest['changes'][path]['after']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest['status']='FROZEN23h cargo/cursor; compiled and GPU acceptance pending'
(stage/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Exact independently reviewed guard bytes frozen')
