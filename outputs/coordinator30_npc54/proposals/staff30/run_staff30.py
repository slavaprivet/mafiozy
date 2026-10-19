"""Private snapshot native QA; scheduler, immutable source pins, strict semantics."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from apply_staff30 import OUT, ROOT, BASE, STAFF, apply, save, sha

sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

SCHEDULER_SHA = 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
CURRENT_RUN = None

def pins(project):
    return {p.relative_to(project).as_posix(): sha(p.read_bytes()) for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.uid')}

def accept_cycle(data, stdout):
    samples = data.get('samples', [])
    last = samples[-1] if samples else {}
    account = last.get('account', {}).get('account', {})
    receipts = account.get('receipts', [])
    bank = [r for r in receipts if r['kind'] == 'local_bank_grant28']
    food = [r for r in receipts if r['kind'] in ['local_shop_purchase28', 'local_restaurant_purchase28']]
    service = data.get('physical_service_evidence', {})
    gestures = data.get('staff_serving_evidence', {})
    expected = {'hospital', 'bank', 'restaurant' if food and food[0]['kind']=='local_restaurant_purchase28' else 'shop'}
    return {
        'cycle_physically_complete': data.get('reason') == 'cycle_physically_complete',
        'one_resident_twelve_staff': bool(samples) and all(s['resident_count']==1 and s['staff_count']==12 for s in samples),
        'all_services_physically_reached': expected <= service.keys(),
        'all_staff_gestures_from_real_service': expected <= gestures.keys(),
        'no_heal_or_settle_without_service': not data.get('violations', ['missing']),
        'one_bank_one_food': len(bank)==1 and len(food)==1,
        'unique_receipts': len({r['id'] for r in receipts})==len(receipts),
        'settlement_inside_after_dwell': bool(bank+food) and all(r.get('inside') is True and r['dwell_ms']>=2000 for r in bank+food),
        'bank_restores_1000_and_price_preserved': len(bank)==1 and len(food)==1 and bank[0]['cash_after']==1000 and bank[0]['saved_purchase']==food[0]['saved_purchase'] and 5<=food[0]['amount']<=50 and account['cash']==1000-food[0]['amount'] and last['account']['conserved'],
        'hospital_healed_and_physically_exited': 'reason=treated_and_physically_exited' in stdout and last.get('hp')==last.get('max_hp'),
        'bank_and_food_physically_exited': 'kind=bank stage=complete' in stdout and any('kind='+k+' stage=complete' in stdout for k in ['shop','restaurant']),
        'energy_restored': any(s['economy'].get('receipt',{}).get('energy_after')==100.0 for s in samples),
        'released_all_claims': bool(last) and last.get('capacity_claims')==0 and last.get('service_claims')==0,
        'real_roam_resumed': last.get('economy',{}).get('roams',0)>=1,
    }

def main():
    global CURRENT_RUN
    p = argparse.ArgumentParser()
    p.add_argument('name')
    p.add_argument('--source', type=Path, default=BASE)
    p.add_argument('--case', choices=['fixture','cycle'], default='cycle')
    p.add_argument('--duration', type=int, default=240)
    p.add_argument('--wait-seconds', type=int, default=120)
    a = p.parse_args()
    assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
    run = OUT / 'runs' / a.name
    assert not run.exists()
    run.mkdir(parents=True)
    CURRENT_RUN = run
    project = run / 'project'
    source = a.source.resolve()
    scheduler = ROOT / 'tools/godot/test_scheduler.py'
    assert sha(scheduler.read_bytes()) == SCHEDULER_SHA
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock = json.loads((ROOT / 'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8'))
    assert sha(engine.read_bytes()) == lock['editor']['gui']['sha256']
    with Lease(mode='headless', project=source, access='read', wait_seconds=a.wait_seconds) as reader:
        original = pins(source)
        with Lease(mode='headless', project=project, access='write', wait_seconds=a.wait_seconds) as writer:
            for relative in original:
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / relative, target)
            assert pins(source)==original and pins(project)==original, 'source snapshot drift'
            save(run / 'SOURCE_PINS.json', original)
            save(run / 'SOURCE_READ_LEASE.json', reader.request)
            apply(project, run / 'APPLY.json')
            (project / 'qa').mkdir(exist_ok=True)
            shutil.copy2(OUT/'qa/staff_cycle30.gd', project/'qa/staff_cycle30.gd')
            shutil.copy2(STAFF/'qa/staff_world29_fixture.gd', project/'qa/staff_world29_fixture.gd')
            save(run / 'STAGE_WRITE_LEASE.json', writer.request)
    before = pins(project); save(run/'PROJECT_PINS.json', before)
    def native(label, args, timeout, access='read'):
        command = [sys.executable,'-B',str(scheduler),'run','--mode','headless','--project',str(project),'--access',access,'--wait-seconds',str(a.wait_seconds),'--timeout',str(timeout),'--out',str(run/label),'--',str(engine),'--headless','--path',str(project),*args]
        result = subprocess.run(command, cwd=ROOT, capture_output=True)
        (run/(label+'.runner.stdout.log')).write_bytes(result.stdout)
        (run/(label+'.runner.stderr.log')).write_bytes(result.stderr)
        return result.returncode
    imported = native('import', ['--editor','--import','--quit'], 180, 'write')
    ready = pins(project); save(run/'PROJECT_READY_PINS.json', ready)
    import_drift = [k for k in before.keys() | ready.keys() if before.get(k)!=ready.get(k) and not k.endswith('.import')]
    result_path = run / 'NATIVE.json'
    exit_code = None; semantic = {}; checks = {}
    if imported == 0:
        flags = ['--city-qa=1','--city-simple-hospital=1','--city-palazzo-clones=1','--city-clone-step=22','--city-town=1','--city-door-free-entry=1','--city-site-door-physics=1','--city-clone-door-swing=1','--city-shop-release=1','--city-venue-sites29=1','--city-venue-staff29=1','--no-minimap','--qa-out='+str(result_path)]
        if a.case=='cycle':
            flags += ['--city-resident-name=Житель','--city-plaza-support-plate=1','--city-medical-threshold=0.5','--city-energy-drain-per-m=0.05','--city-energy-threshold=0.2','--city-needs=1','--city-nav-pump-budget-us=4000','--city-nav-pump-every=1','--city-daily-slice=286','--city-sim-stride=1','--city-sim-one-per-frame=0','--city-walk-pose=1','--city-pose-far-cap=512','--city-clear-cache=1','--city-timing=0','--city-health-lease','--city-resident-detail=1','--city-hospital-marker=0','--city-energy-start=19','--city-wallet-start=0','--city-sandbox-seed=53','--city-hp=49','--qa-duration='+str(a.duration)]
        fixture = 'staff_cycle30.gd' if a.case=='cycle' else 'staff_world29_fixture.gd'
        save(run/'FLAGS.json',flags)
        exit_code = native('native', ['--script',str(project/'qa'/fixture),'--',*flags], a.duration+120 if a.case=='cycle' else 180)
        if result_path.exists(): semantic = json.loads(result_path.read_text(encoding='utf-8'))
        checks = accept_cycle(semantic,(run/'native/stdout.log').read_text(encoding='utf-8')) if a.case=='cycle' else {'fixture_pass':semantic.get('status')=='PASS'}
    after = pins(project)
    drift = sorted(set(import_drift) | {k for k in ready.keys() | after.keys() if ready.get(k)!=after.get(k)})
    result = {'passed':imported==0 and exit_code==0 and bool(checks) and all(checks.values()) and not drift, 'case':a.case,'import_exit':imported,'native_exit':exit_code,'checks':checks,'source_drift':drift,'semantic_path':str(result_path),'performance_accepted':False,'visual_verified':False,'user_processes_closed':False}
    save(run/'RESULT.json',result)
    print(json.dumps(result,ensure_ascii=True))
    return 0 if result['passed'] else 1

if __name__=='__main__':
    try:
        sys.exit(main())
    except Exception as error:
        if CURRENT_RUN is not None:
            save(CURRENT_RUN/'RESULT.json', {'passed':False,'exception':type(error).__name__,'reason':str(error),'native_launched':(CURRENT_RUN/'native').exists(),'performance_accepted':False,'user_processes_closed':False})
        raise
