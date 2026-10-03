"""Compose pinned C4 fixes into a fresh production candidate; never publish it."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = HERE / 'game'
REVISION = 's01-20261003-c4-release48'
BASE = ROOT / 'outputs/coordinator27_release47a/ASSEMBLY.json'
BASE_SHA = 'b6dc7782a12abf749c5162bbdc5e850e3a6eaaa32693e5a70aef2a7a05eef61d'
PREFIX = 'scripts/destruction/palazzo/'
SOURCES = {
    'scripts/weapons/weapon_aim_camera.gd': ('outputs/coordinator27_camera_reset/runtime_v2/scripts/weapons/weapon_aim_camera.gd', '948a98ebe240990f67ed248009b0c255db49a64085dad9a2d3ff27ddaf8bb00e'),
    PREFIX+'c4_equipment.gd': ('outputs/coordinator27_c4_meta_perf/shape_signal_fix47/patch/scripts/destruction/palazzo/c4_equipment.gd', '86ec658e3c4619eb0f876d9ed3aa3420b79c788e7fdebda6cf428200ced17bb7'),
    PREFIX+'c4_building_blast.gd': ('outputs/buildings4_c4_strength_20261003/runtime/scripts/destruction/palazzo/c4_building_blast.gd', '54a39ca265a692c77456e9f1e243924fc40bf9840509fa7dd6820a1d3adf2888'),
    PREFIX+'palazzo_host.gd': ('outputs/buildings4_strength_foundation_native_20261003/game/scripts/destruction/palazzo/palazzo_host.gd', '1397680ae5de0487f2faedea1e82c96181252b38d8b8035ec117c4f3e8cc4c51'),
    PREFIX+'palazzo_foundation12_site.gd': ('outputs/buildings4_palazzo_foundation12_20261003/runtime/scripts/destruction/palazzo/palazzo_foundation12_site.gd', 'd799c2c57ef62f5249128c13f329c66f408825db05076bb2c7de0a912b208ecb'),
    PREFIX+'palazzo_foundation12_site.tscn': ('outputs/buildings4_palazzo_foundation12_20261003/runtime/scripts/destruction/palazzo/palazzo_foundation12_site.tscn', 'dbdd690e1b7b29a0866004734b060d150573012eb55b1929097ecc8de92a69ae'),
    PREFIX+'blast45_plume.gdshader': ('outputs/buildings4_fire_v3_20261003/runtime/scripts/destruction/palazzo/blast45_plume.gdshader', '45f7184ad51819e06677dc9e7e3f1971cbe063a6526dd278489073931dc63eb4'),
    PREFIX+'blast45_wave.gdshader': ('outputs/buildings4_fire_v3_20261003/runtime/scripts/destruction/palazzo/blast45_wave.gdshader', '5f3c8ea2c68d57ded5abd4abccfd2290c8a36eaddc312d63c1a66bb15b0f2535'),
    PREFIX+'blast_fx45.gd': ('outputs/buildings4_fire_v3_20261003/runtime/scripts/destruction/palazzo/blast_fx45.gd', '88c5b622faf5caad5d530095f5696272bf8e7d70d30e14f7f8ea90f08e8afae3'),
}

def sha(data): return hashlib.sha256(data).hexdigest()
def checked(path, expected):
    data = path.read_bytes()
    if sha(data) != expected: raise RuntimeError('Pinned source changed: '+str(path))
    return data
def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data: raise RuntimeError('Preserve existing different file: '+str(path))
    else:
        with path.open('xb') as stream: stream.write(data)
def encoded(value): return (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8')

def prepare():
    base = json.loads(checked(BASE, BASE_SHA))
    assert len(base['source_pins']) == 484
    data = {rel:checked(Path(base['game'])/rel, pin) for rel,pin in base['source_pins'].items()}
    for rel,(source,pin) in SOURCES.items(): data[rel] = checked(ROOT/source,pin)
    # Merge the reviewed connection fix with the owner's exact strength change.
    equip = data[PREFIX+'c4_equipment.gd']
    old = b'const DAMAGE := 960.0'
    assert equip.count(old)==1
    data[PREFIX+'c4_equipment.gd'] = equip.replace(old,b'const DAMAGE := 1920.0',1)
    main = data['scripts/main.gd']
    before = b'const PREVIEW_RUNTIME_REVISION := "s01-20261003-c4-marks47a"'
    assert main.count(before)==1
    data['scripts/main.gd'] = main.replace(before,('const PREVIEW_RUNTIME_REVISION := "'+REVISION+'"').encode(),1)
    data['data/preview_updates.json'] = encoded({'title':'03.10 · Усиленный C4 · версия48','runtime_revision':REVISION,'items':[
        'Q → C4: наведите на близкую поверхность и держите ЛКМ 3 секунды. Можно установить до 8 зарядов.',
        'Q → пульт: ЛКМ подрывает установленные заряды. Усиленный взрыв разрушает стену и основание Палаццо; через пролом можно пройти.',
        'Новый огонь взрыва; следы попаданий исчезают вместе с разрушенной поверхностью.'
    ]})
    cfg = data['export_presets.cfg'].decode('utf-8-sig')
    additions = [PREFIX+'palazzo_foundation12_site.gd',PREFIX+'palazzo_foundation12_site.tscn']
    match = re.search(r'^export_files=PackedStringArray\((.*)\)$',cfg,re.M)
    assert match and all('res://'+rel not in match.group(1) for rel in additions)
    cfg = cfg[:match.start(1)] + match.group(1) + ', '+', '.join('"res://'+rel+'"' for rel in additions) + cfg[match.end(1):]
    data['export_presets.cfg'] = cfg.encode('utf-8')
    assert len(data)==486
    assert all(not any(part in ('tests','qa','outputs','.godot') for part in Path(rel).parts) for rel in data)
    manifest = {'schema':'mafiozi.release-candidate/v1','revision':REVISION,'game':str(GAME),
                'accepted':False,'performance_accepted':False,'source_count':len(data),
                'source_pins':{rel:sha(content) for rel,content in sorted(data.items())},
                'base_assembly_sha256':BASE_SHA,'overlays':SOURCES,
                'composition_changes':['C4 connection fix merged with damage1920; radius3.2/direct48 unchanged','safe normal camera reset','foundation12 host','Fire3','existing marks47a retained'],
                'prepare_sha256':sha(Path(__file__).read_bytes())}
    return data,manifest

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--stage',action='store_true'); args=parser.parse_args()
    if args.stage:
        spec=importlib.util.spec_from_file_location('scheduler',ROOT/'tools/godot/test_scheduler.py')
        scheduler=importlib.util.module_from_spec(spec); spec.loader.exec_module(scheduler)
        with scheduler.Lease('headless',GAME,access='write',wait_seconds=180):
            assert not GAME.exists(), 'Never overwrite a staged candidate'
            data,manifest=prepare()
            for rel,content in data.items(): save(GAME/rel,content)
            for rel,pin in manifest['source_pins'].items(): checked(GAME/rel,pin)
            save(HERE/'ASSEMBLY.json',encoded(manifest))
    else:
        data,manifest=prepare()
        save(HERE/'PLAN.json',encoded(manifest))
    print(json.dumps({'revision':REVISION,'source_count':len(data),'staged':args.stage,'accepted':False},ensure_ascii=True))

if __name__=='__main__': main()
