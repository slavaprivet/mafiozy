from pathlib import Path
import hashlib, json, sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease
from apply_medic30 import apply

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def save(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

base = read(OUT/'runs/inspect02/observed/MEDIC30.json')
candidate = read(OUT/'runs/candidate02/observed/MEDIC30.json')
contracts = read(OUT/'runs/contracts01/observed/STAFF_CONTRACTS30.json')
pins = read(OUT/'BASE_MEDIC30.json')
for run in ['inspect02', 'candidate02', 'contracts01']:
    result = read(OUT/'runs'/run/'RESULT.json')
    assert result['passed'] and result['drift'] == [] and result['native_exit'] == 0
assert contracts['status'] == 'PASS' and contracts['checks'] == 637 and not contracts['failures']
assert base['staff_count'] == candidate['staff_count'] == 12
medics, cashiers = [], []
for before, after in zip(base['actors'], candidate['actors']):
    assert before['role'] == after['role']
    assert before['snapshot']['position'] == after['snapshot']['position']
    assert after['stats']['bones'] == 28 and after['stats']['colliders'] == 1
    assert after['snapshot']['available'] and not after['snapshot']['resident_host']
    if after['role'] == 'medic':
        assert after['style']['ok'] and after['style']['recolored_vertices'] == 1648
        assert after['style']['native_vertex_buffers_preserved']
        assert after['style']['hidden_hair_meshes'] == 5
        medics.append(after)
    else:
        assert before['stats'] == after['stats'] and not after['style']
        cashiers.append(after)
assert len(medics) == 3 and len(cashiers) == 9
for run in ['candidate02', 'contracts01']:
    tested = read(OUT/'runs'/run/'PROJECT_READY_PINS.json')
    for rel, pin in pins.items():
        assert sha(OUT/rel) == pin['proposed_sha256'] == tested[rel]

# Small source-only copy: verify the exact guarded apply, no engine/project clone.
validation = OUT/'apply_validation'
validation.mkdir(exist_ok=False)
source = ROOT/'outputs/coordinator30_npc54/game'
with Lease(mode='headless', project=source, access='read', wait_seconds=180):
    for rel, pin in pins.items():
        if pin['base_sha256'] is None:
            assert not (source/rel).exists()
            continue
        assert sha(source/rel) == pin['base_sha256']
        dst=validation/rel; dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes((source/rel).read_bytes())
with Lease(mode='headless', project=validation, access='write', wait_seconds=180):
    first=apply(validation, validation/'FIRST.json')
    second=apply(validation, validation/'IDEMPOTENT.json')
    assert all(row['changed'] for row in first['files'])
    assert not any(row['changed'] for row in second['files'])
    conflict=validation/'conflict'
    for rel,pin in pins.items():
        if pin['base_sha256'] is None: continue
        dst=conflict/rel; dst.parent.mkdir(parents=True,exist_ok=True)
        dst.write_bytes((source/rel).read_bytes())
    bad=conflict/'scripts/venues/npc_venue_staff_host29.gd'
    bad.write_bytes(bad.read_bytes()+b'\n# intentional conflict fixture\n')
    before={p.relative_to(conflict).as_posix():sha(p) for p in conflict.rglob('*') if p.is_file()}
    try:
        apply(conflict, validation/'UNEXPECTED.json')
        raise RuntimeError('conflicting apply unexpectedly accepted')
    except AssertionError as error:
        assert 'destination conflict' in str(error)
    after={p.relative_to(conflict).as_posix():sha(p) for p in conflict.rglob('*') if p.is_file()}
    assert before == after
    save(validation/'CONFLICT.json', {'rejected':True, 'no_partial_mutation':before == after})

def delta(a,b): return {k:b[k]-a[k] for k in a if isinstance(a[k],int)}
actor_before=base['actors'][0]['stats']; actor_after=candidate['actors'][0]['stats']
counter_before=base['counter_stats']; counter_after=candidate['counter_stats']
actor_delta=delta(actor_before,actor_after); counter_delta=delta(counter_before,counter_after)
review={
 'status':'READY_SCOPED_NATIVE_AND_RENDERED',
 'runtime_files':pins, 'actual_city':True, 'medics':3,'cashiers_unchanged':9,
 'canonical_bones_each':28,'actor_colliders_each':1,'staff_checks':637,
 'non_color_native_buffers_preserved':True,'recolored_vertices_per_medic':1648,
 'per_medic':{'before':actor_before,'after':actor_after,'delta':actor_delta},
 'first_hospital_counter_subtree':{'before':counter_before,'after':counter_after,'delta':counter_delta},
 'all_three_hospitals_delta':{k:3*(actor_delta[k]+counter_delta[k]) for k in actor_delta},
 'cost_scope':'Native geometry accounting; visible means MeshInstance3D.visible, before unchanged range/occlusion culling. This is not a measured draw-call/FPS claim. First counter subtree includes its pre-existing hidden foundation mesh.',
 'case_alone':{'new_meshes':1,'new_vertices':528,'new_triangles':264,'old_meshes':3,'old_vertices':72,'old_triangles':36},
 'apply':{'first_apply_pass':True,'second_apply_no_writes':True,'conflict_rejected_before_any_write':True},
 'shared_game_modified':False,'performance_accepted':False,
 'remaining':'Root integrates three exact files and performs final shared scene/performance acceptance.'
}
save(OUT/'REVIEW_MEDIC30.json',review)
save(OUT/'VISUAL_REVIEW_MEDIC30.json',{
 'status':'PASS','run':'candidate02','source':'native main_city scene, real placed staff/counter, ordinary perspective camera',
 'reviewed_images':['medic_front.png','medic_side.png','medic_case.png'],
 'findings':[
  'Front: white upper coat, lapels and case read at ordinary staff interaction distance; existing floating venue labels overlap the cap from this exact angle.',
  'Side: white knee-length coat panels, pockets, cap and retained dark trousers/shoes are distinct; no visible body breakthrough in inspected standing pose.',
  'Close case: U-shaped handle, lid rim, latches/notches, feet and red cross are visible; rear hinges are in geometry but not shown by these angles.',
  'Canonical staff animation and 20 Hz update remain unchanged; source helper adds no callback, collider or pose write.'
 ],'scope':'Three native rendered standing views plus functional service fixture; not exhaustive animation/performance acceptance.'
})
print(json.dumps(review,ensure_ascii=False,indent=2))
