from pathlib import Path
import hashlib,json,zipfile,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3];BASE=ROOT/'outputs/coordinator29_release53a/game'
names=['fixture01','cycle01','cycle02','cycle03']
if '--ambient-failed' in sys.argv:OUT=OUT.parent/'ambient30';names=['candidate01','candidate02','visual_base01']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
base={p.relative_to(BASE).as_posix():sha(p) for p in BASE.rglob('*') if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.uid')}
results=[]
for name in names:
    run=OUT/'runs'/name;game=run/'project'
    if not game.exists():continue
    assert (run/'RESULT.json').exists(),name
    archive=run/'RECONSTRUCTION_DELTA.zip';pins={};changed=[]
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for p in game.rglob('*'):
            if not p.is_file() or '.godot' in p.parts or p.name.endswith('.uid'):continue
            rel=p.relative_to(game).as_posix();digest=sha(p);pins[rel]=digest
            if base.get(rel)!=digest:z.write(p,rel);changed.append(rel)
    with zipfile.ZipFile(archive) as z:
        assert all(hashlib.sha256(z.read(rel)).hexdigest()==pins[rel] for rel in changed)
    recipe={'project':str(game),'base':str(BASE),'base_source_pins':base,'project_pins':pins,'delta_archive':archive.name,'delta_archive_sha256':sha(archive),'delta_files':changed,'generated_exclusions':['.godot','*.uid'],'reconstruction':'Create empty project. Copy only paths in project_pins with matching base_source_pins from base. Extract delta archive. Verify every project_pin. Import to regenerate cache.','completed':True}
    (run/'RECONSTRUCTION.json').write_text(json.dumps(recipe,ensure_ascii=False,indent=2),encoding='utf-8')
    results.append({'project':str(game),'delta_bytes':archive.stat().st_size,'changed_files':len(changed),'all_files':len(pins)})
(OUT/'CLEANUP_READY_PROJECTS.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=False))
