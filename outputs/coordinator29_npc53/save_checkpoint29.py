import hashlib,json,pathlib,shutil
OUT=pathlib.Path(__file__).resolve().parent;GAME=OUT/'game';DEST=OUT/'checkpoint01'
assert not DEST.exists()
DEST.mkdir()
rels=['scripts/npc_visual/npc_resident_diag.gd','scripts/npc_visual/npc_resident_focus29.gd','scripts/npc_visual/resident_card29.gdshader',
      'scripts/hospital/npc_physical_route51.gd','scripts/hospital/npc_route_budget29.gd','scripts/hospital/npc_walk_surface28.gd']
tested=json.loads((OUT/'focus_game53_02/SOURCE.json').read_text(encoding='utf-8'))
pins={}
for rel in rels:
    data=(GAME/rel).read_bytes();digest=hashlib.sha256(data).hexdigest();assert tested[rel]==digest,rel
    target=DEST/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);pins[rel]=digest
proofs={'focus_native.json':OUT/'focus53_01/FOCUS29.json','focus_game_native.json':OUT/'focus_game53_02/FOCUS_GAME29.json',
        'death_native.json':OUT/'death53_02/DEATH28.json','economy_native.json':OUT/'economy53_01/BEHAVIOR_ACCEPTANCE29.json',
        'capacity_native.json':OUT/'capacity53_01/CAPACITY29.json','navigation_native.json':OUT/'proposals/navigation29/runs/candidate01/RESULT.json',
        'navigation_physical_queue.json':OUT/'proposals/navigation29/runs/candidate01/physical_queue_fixture29.json'}
for name,path in proofs.items():shutil.copy2(path,DEST/name)
(DEST/'MANIFEST.json').write_text(json.dumps({'scope':'verified partial source checkpoint, not an ordinary-launch assembly','source_pins':pins,
    'accepted_pointer_changed':False,'population':1,'remaining':['canvas text readability','ambient hand clipping and bench','phone action','additional venues','long route budget','combined native and perf acceptance']},indent=2),encoding='utf-8')
print('Frozen verified checkpoint; not a release.')
