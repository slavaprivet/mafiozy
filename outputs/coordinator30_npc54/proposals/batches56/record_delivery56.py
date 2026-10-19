"""Record the already opened ordinary56 and its bounded acceptance scope."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


release = ROOT / 'outputs/coordinator30_release56'
pointer = read(ROOT / 'godot/current_version.json')
opened_path = ROOT / 'outputs/current_game/OPENED.json'
opened = read(opened_path)
assert opened['ready'] is True
assert opened['revision'] == pointer['revision'] == 's01-20261015-residents56'
assert opened['assembly_sha256'] == pointer['assembly_sha256'] == sha(release/'ASSEMBLY.json')
ready = opened['bootstrap']
assert ready['ok'] and ready['resident_count'] == ready['current_resident_count'] == 10
assert ready['staff_count'] == 12 and ready['exact_roster_complete']
run = Path(opened['run_directory']).resolve()
run.relative_to(ROOT / 'outputs/current_game/interactive')
assert (run/'play.err').stat().st_size == 0
manifest = read(release/'ASSEMBLY.json')
assert all(sha(release/'game'/name) == digest for name, digest in manifest['source_pins'].items())
evidence = release/'ordinary_delivery'
evidence.mkdir(exist_ok=False)
for name in ['CURRENT_READY.json','OPENED.json','RELEASE.json','STARTED.json','opened.png','play.err']:
    shutil.copy2(run/name, evidence/name)
perf = read(HERE/'runs/batch10_final_perf01/PERFORMANCE_SUMMARY.json')
assert perf['performance_gate']
delivery = {'ordinary_ready': True, 'revision': opened['revision'], 'resident_count': 10,
            'staff_count': 12, 'window_pid_at_delivery': opened['pid'],
            'assembly_sha256': pointer['assembly_sha256'], 'ordinary_run': str(run.relative_to(ROOT)),
            'recorded_at': datetime.now(timezone.utc).isoformat(), 'mean_fps': perf['mean_fps'],
            'p95_ms': perf['frame_ms']['p95'], 'measurement_seconds': 90,
            'render_size': [1280,720], 'all_ten_moved': True,
            'services_pass': True, 'threat_pass': True, 'next_batch': 20,
            'full_city_performance_accepted': False,
            'building_policy': 'Current ordinary buildings temporarily allowed for testing; future permanent buildings only destructible like Palazzo',
            'publication': 'Scoped main commit and push follows this delivery record; final SHA in checkpoint_release56/RESULT.json'}
save(release/'DELIVERY.json', delivery)
acceptance = read(release/'ACCEPTANCE.json')
acceptance['status'] = 'BATCH10_VERIFIED_ORDINARY_DELIVERED'
acceptance['ordinary_delivery'] = 'ordinary_delivery/OPENED.json'
save(release/'ACCEPTANCE.json', acceptance)
coord_path = ROOT/'docs/ai/CURRENT_COORDINATOR.json'
coord = read(coord_path)
coord.update(updated_at=delivery['recorded_at'], current_candidate_status='BATCH10_VERIFIED_ORDINARY56_DELIVERED',
             current_play_revision=opened['revision'], current_play_assembly=pointer['assembly'],
             current_play_residents=10, initial_batch_target=10, next_batch_target=20,
             full_city_performance_accepted=False, building_policy=delivery['building_policy'],
             publication_commit_pending_reason='Verified release56 delivery checkpoint being committed and pushed',
             last_inventory_note='Ordinary56 is open; preserve user game. Always obtain fresh process identity before any process action.')
save(coord_path, coord)
print(json.dumps(delivery, ensure_ascii=True))
