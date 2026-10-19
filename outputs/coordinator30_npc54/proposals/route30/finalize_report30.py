"""Read selected immutable run evidence and write the route30 delivery manifest."""
import hashlib, json, pathlib, zipfile

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[3]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def save(name, value): (OUT / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

base = read(OUT / 'BASELINE30.json')
integrated = read(OUT / 'INTEGRATION_BASE30.json')
hospital = read(OUT / 'runs/hospital08/real_hospital30.json')
hospital_pins = read(OUT / 'runs/hospital08/SOURCE.json')
local_pins = read(OUT / 'runs/local09/SOURCE.json')
checks = []
ns = {'__file__': str(OUT / 'apply30.py')}
exec((OUT / 'apply30.py').read_text(encoding='utf-8').split('\np = argparse.ArgumentParser')[0], ns)
with zipfile.ZipFile(OUT / 'INTEGRATION_BASE30.zip') as archive:
    assert sha(OUT / 'INTEGRATION_BASE30.zip') == integrated['zip_sha256']
    for rel, entry in base['files'].items():
        assert sha(OUT / rel) == entry['candidate_sha256']
        pristine = (OUT / 'baseline' / rel).read_text(encoding='utf-8')
        patch = (OUT / (pathlib.Path(rel).stem + '.patch')).read_text(encoding='utf-8')
        candidate = (OUT / rel).read_text(encoding='utf-8')
        assert ns['patch_text'](pristine, patch) == candidate
        sentinel = '# unrelated owner sentinel\n'
        assert ns['patch_text'](sentinel + pristine, patch) == sentinel + candidate
        raw = archive.read(rel) if rel in integrated['changed_sources'] else (ROOT / 'outputs/coordinator29_release53a/game' / rel).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == integrated['source_pins'][rel]
        merged = ns['patch_text'](raw.decode('utf-8').replace('\r\n', '\n'), patch)
        encoded = merged.replace('\n', '\r\n').encode() if b'\r\n' in raw else merged.encode()
        after = hashlib.sha256(encoded).hexdigest()
        assert after == hospital_pins[rel] == local_pins[rel]
        checks.append({'path': rel, 'pristine_apply': True, 'unrelated_edits_preserved': True,
                       'before_sha256': hashlib.sha256(raw).hexdigest(), 'merged_tested_sha256': after})
save('APPLY_CHECK.json', {'passed': True, 'base_snapshot': 'INTEGRATION_BASE30.json', 'checks': checks})

evidence = {}
for name, cases in [('hospital08', ['real_hospital30']), ('local09', ['service_guard30', 'integration_fixture29', 'daily_policy_fixture29'])]:
    directory = OUT / 'runs' / name
    result = read(directory / 'RESULT.json')
    assert result['passed'] and not result['source_drift']
    for case in ['import', *cases]:
        assert (directory / case / 'stderr.log').stat().st_size == 0
    rows = []
    for case in cases:
        data = read(directory / (case + '.json'))
        items = data.get('checks', data.get('cases'))
        assert data['passed'] and all(item['passed'] for item in items)
        rows.append({'name': case, 'checks': len(items), 'passed': True, 'result_sha256': sha(directory / (case + '.json'))})
    evidence[name] = {'cases': rows, 'source_pins_sha256': sha(directory / 'SOURCE.json'),
                      'result_sha256': sha(directory / 'RESULT.json'), 'reconstruction_sha256': sha(directory / 'RECONSTRUCTION.json'),
                      'changed_sources_zip_sha256': sha(directory / 'CHANGED_SOURCES.zip'), 'stderr_bytes': 0, 'drift': []}

soak = [x for x in hospital['samples'] if 'cleanup_second' in x]
live = [x for x in hospital['samples'] if 'ms' in x]
cycle = next(x for x in hospital['checks'] if x['label'] == 'physical_staging_door_heal_and_exit')
payload = {
    'status': 'READY_FOR_SCOPED_APPLY_AND_COMBINED54_QA',
    'files': checks,
    'selected_runs': evidence,
    'hospital': {'initial_room_distance_m': next(x['distance_to_room'] for x in hospital['checks'] if x['label'] == 'far_inner_half_plane_is_not_inside'),
                 'physical_progress_m': cycle['progress_m'], 'elapsed_ms': cycle['elapsed_ms'], 'hp': [live[0]['hp'], live[-1]['hp']],
                 'fixture_extra_bodies': 0, 'relocations_after_medical_begin': 0,
                 'authoritative_staff_service': hospital['evidence']['staff_service'], 'claims_released': True},
    'soak': {'seconds': 12, 'ranges': {k: [min(x[k] for x in soak), max(x[k] for x in soak)] for k in ['nodes','objects','resources','memory_static','resident_count']},
             'native_end': soak[-1]['native'], 'budget_end': soak[-1]['budget'],
             'limit': 'Short functional counters only. Sampling allocates report dictionaries; autonomous resident starts later tasks. Not a heap-leak or FPS acceptance.'},
    'performance_accepted': False, 'production_modified_by_this_agent': False, 'user_processes_closed': False,
    'root54_integration_snapshot': {'pins': len(integrated['source_pins']), 'delta_files': len(integrated['changed_sources']),
                                   'json_sha256': sha(OUT / 'INTEGRATION_BASE30.json'), 'zip_sha256': sha(OUT / 'INTEGRATION_BASE30.zip'),
                                   'contains': ['staff', 'injury attention', 'avoidance', 'revision/news54'], 'ambient_merge_included': False},
    'limitations': [
        'hospital08 is authoritative full physical hospital evidence. city07 plain capsule stops honestly outside the building and is not full hospital acceptance.',
        'hospital08 diagnostic legs array was retained by reference and serializes later exit legs; boolean admission check evaluated the initial four legs. Current fixture uses duplicate() for immutable diagnostic output; production source unchanged.',
        'Root must run import and relevant combined54 functional checks after ambient merge. Current frozen runs do not include subsequent ambient source.',
        'No active-record index included: host loop has cleanup and lifecycle responsibilities requiring separately scoped hooks and death/respawn/transport coverage.',
        'No source count reduction or smaller city used to claim optimization. One requested active resident retained; records287 is inactive catalogue.',
        'Cleanup of own completed caches was rejected twice by automatic approval review (blocked by policy), no deletion performed. Reusable private staging avoids further full copies.'
    ],
    'historical_runs_preserved': {'native01': 'No engine; duplicate staging lease fixed', 'native02': 'QA float equality defect, behavior checks passed',
                                 'native03': 'No checkpoint repair; real long route blocked at native checkpoint', 'city04': 'No engine; legacy mutex acquisition timed out',
                                 'city05': 'Larger guard still hit bad native checkpoint; not selected', 'points06': 'Diagnostic confirmed real Cornice collider blocking native point',
                                 'city07': 'Bounded intermediate repair walked79.302m; plain capsule blocked outside room without portal owner; not full acceptance'},
}
payload['artifact_sha256'] = {p.relative_to(OUT).as_posix(): sha(p) for p in [OUT/'BASELINE30.json', OUT/'APPLY_CHECK.json', OUT/'apply30.py', OUT/'run_native30.py', OUT/'HANDOFF30.md', *sorted((OUT/'qa').glob('*.gd')), *sorted(OUT.glob('*.patch'))]}
save('MANIFEST30.json', payload)
print(json.dumps({'passed': True, 'selected_checks': sum(x['checks'] for r in evidence.values() for x in r['cases']), 'manifest_sha256': sha(OUT / 'MANIFEST30.json')}))
