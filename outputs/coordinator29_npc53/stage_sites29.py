import pathlib,sys,hashlib,json,re,shutil
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
sites=OUT/'proposals/venues29_sites';repair=OUT/'proposals/venues29_sites_repair01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def apply(rel,patch):
    p=GAME/rel;text=p.read_text(encoding='utf-8')
    for section in re.split(r'^@@[^\n]*\n',patch.read_text(encoding='utf-8'),flags=re.M)[1:]:
        lines=section.splitlines(keepends=True)
        old=''.join(line[1:] for line in lines if line.startswith((' ','-')))
        new=''.join(line[1:] for line in lines if line.startswith((' ','+')))
        old=old.replace('scene.get_meta(META, null)','scene.get_meta(META) if scene.has_meta(META) else null')
        assert text.count(old)==1,(rel,old[:150],text.count(old))
        text=text.replace(old,new,1)
    p.write_text(text,encoding='utf-8')
with Lease(mode='headless',project=GAME,access='write',wait_seconds=30):
    manifest=json.loads((sites/'MANIFEST29_SITES.json').read_text(encoding='utf-8'))
    for rel,pin in manifest['files'].items():
        assert sha(sites/rel)==pin,rel
        if rel.startswith(('scripts/','data/')):
            target=GAME/rel;assert not target.exists(),rel
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(sites/rel,target)
    for rel,name in [('scripts/main.gd','main_sites29.patch'),('scripts/venues/npc_venue_registry29.gd','registry_sites29.patch'),('scripts/hospital/npc_restaurant_visit28.gd','restaurant_emergency_exit29.patch')]:apply(rel,sites/name)
    apply('scripts/venues/npc_compact_service_site29.gd',repair/'compact_site29.patch')
print('8 owned compact sites + native-verified entrance/closure repair staged. Activation flag remains explicit.')
