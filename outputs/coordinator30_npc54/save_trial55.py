"""Record the ordinary opened release and prepare an explicit own-files Git path list."""
import datetime,json,pathlib,shutil,subprocess,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[2];OUT=ROOT/'outputs/coordinator30_npc54';REL=ROOT/'outputs/coordinator30_release55'
opened=json.loads((ROOT/'outputs/current_game/OPENED.json').read_text(encoding='utf-8-sig'))
assert opened['ready'] and opened['revision']=='s01-20261015-residents55','Wait for real ordinary startup'
assert opened['bootstrap']['resident_count']>=200
run=pathlib.Path(opened['run_directory']);assert (run/'play.err').stat().st_size==0
shutil.copy2(ROOT/'outputs/current_game/OPENED.json',REL/'OPENED.json')
shutil.copy2(run/'CURRENT_READY.json',REL/'CURRENT_READY.json')
shutil.copy2(run/'opened.png',REL/'opened.png')
manifest=json.loads((REL/'ASSEMBLY.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((REL/'game'/name).read_bytes()).hexdigest()==pin for name,pin in manifest['source_pins'].items())
status=json.loads((REL/'TRIAL_STATUS.json').read_text(encoding='utf-8'));status['status']='OPENED_USER_REQUESTED_MASS_TRIAL';status['actual_residents']=opened['bootstrap']['resident_count'];status['ordinary_ready']=True;status['pending']=['long mass performance/memory','service exit during threat'];status['source_pins_reverified_after_launch']=True
(REL/'TRIAL_STATUS.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
coordinator=ROOT/'docs/ai/CURRENT_COORDINATOR.json';v=json.loads(coordinator.read_text(encoding='utf-8'));v.update(updated_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),current_play_revision=manifest['revision'],current_play_assembly='outputs/coordinator30_release55/ASSEMBLY.json',current_candidate_status='RELEASE55_OPENED_USER_AUTHORIZED_MASS_TRIAL_PERFORMANCE_PENDING',current_play_residents=opened['bootstrap']['resident_count'],last_inventory_note=f'User game55 PID{opened["pid"]} ordinary ready; preserve window, fresh inventory before any later action.');coordinator.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
memory=ROOT/'docs/ai/COORDINATOR_30_MEMORY.md';memory.write_text(memory.read_text(encoding='utf-8')+f'''

## Доставка55 — обычная сцена открыта
Последнее прямое поручение отменило блокировку доставки поFPS: «добавь, потом
исправим баги/нагрузку», затем «запускай сцену» и сохранить эту сборку main/GitHub.
Замороженная outputs/coordinator30_release55/ASSEMBLY.json:1127sourcepins,
SHA bdca155eab7c50689ca52c13aa83dcad3adc0b593286710887ee950938b2ca2a.
F5/current_version обновлён на55, previous53a сохранён вPREVIOUS_CURRENT.json.
Обычный stablelauncher подтвердил ready=true; жители{opened['bootstrap']['resident_count']},
staff12/sites8/actions18, currenttokensсовпали, threat+multi+fullphysical активны.
Пользовательское окноPID{opened['pid']} сохранять, launcher session88813 держитmutex
до его закрытия — не прерывать и не ждать окончания длязавершениячата.
HPcore67/guard43+43 включеныscoped; import_trial55 чистыйPASS. LOSpendingfix
включён, raw_far02PASS64. service-threat иcity03harnessготовы, но новыеengine
пользовательскойдоставкене мешают: всеагентызавершилисвоипроцессы.
СтатусЭКСПЕРИМЕНТАЛЬНАЯМАССОВАЯСБОРКАпо прямомупоручению, performance_accepted=false.
У полиции готовыдвемодели, AI/выездотложен. Следующее — наблюденияпользователя,
нагрузка/routequeries/memory исервисныйвыходприугрозе, безснижениянаселения.
''',encoding='utf-8')
paths={'AGENTS.md','docs/ai/COORDINATOR_30_MEMORY.md','docs/ai/CURRENT_COORDINATOR.json','godot/current_version.json'}
paths.update(p.relative_to(ROOT).as_posix() for p in REL.rglob('*') if p.is_file() and '.godot' not in p.parts)
paths.update(subprocess.check_output(['git','ls-files','outputs/coordinator30_npc54'],cwd=ROOT).decode('utf-8').splitlines())
paths.update(p.relative_to(ROOT).as_posix() for p in OUT.iterdir() if p.is_file() and p.suffix.lower() in ['.py','.json','.md','.zip'])
paths.update(p.relative_to(ROOT).as_posix() for p in (OUT/'qa').glob('*.gd'))
for name in ['medic30','heal_fx30','police_response30','population30','lifecycle30','threat30','diag_perf30','trace30','mass30','service_threat30']:
    package=OUT/'proposals'/name
    for p in package.rglob('*'):
        if not p.is_file():continue
        local=p.relative_to(package).parts
        if any(x in local for x in ['runs','game','native_project','apply_validation','.godot','__pycache__','guards30']):continue
        if 'npc_police_road_plan30' in p.name:continue
        if p.suffix.lower() in ['.gd','.py','.json','.md','.diff','.patch','.txt']:
            paths.add(p.relative_to(ROOT).as_posix())
    if name=='diag_perf30':
        for p in (package/'guards30').iterdir():
            if p.is_file() and p.suffix.lower() in ['.json','.py','.md','.txt','.patch']:paths.add(p.relative_to(ROOT).as_posix())
for evidence in ['threat30/runs/city02','threat30/runs/raw_far02','lifecycle30/runs/multi05','lifecycle30/runs/single02','diag_perf30/runs/hp03','diag_perf30/runs/guards_off02','diag_perf30/runs/guards_on02','heal_fx30/runs/visual03','police_response30/runs/models02']:
    directory=OUT/'proposals'/evidence
    for p in directory.rglob('*.json'):
        if any(x in p.relative_to(directory).parts for x in ['TESTED_SOURCES','project','game','.godot']):continue
        paths.add(p.relative_to(ROOT).as_posix())
assert all((ROOT/p).is_file() for p in paths)
(OUT/'GIT_FILES55.txt').write_text('\n'.join(sorted(paths))+'\n',encoding='utf-8')
print(json.dumps({'resident_count':status['actual_residents'],'ready':True,'scoped_git_paths':len(paths)}))
