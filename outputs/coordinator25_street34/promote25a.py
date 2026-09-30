"""ROOT ONLY: verify, --prepare isolated delivery, or --apply exactly twelve accepted paths."""
from pathlib import Path
import argparse, datetime, difflib, hashlib, json, math, shutil

HERE = Path(__file__).resolve().parent
REPO, OUT = HERE.parents[1], HERE.parent / 'coordinator25_delivery25a'
SHARED = REPO / 'godot/mafiozi_walk'
BASE = REPO / 'outputs/coordinator24_rear_lights31/ASSEMBLY31.json'
BASE_SHA = '3309bf75e46aab302793fab686373e4e8597ed714efb01f631117fdea0f93945'
REVISION = 's01-20260930-quality25a'
EXE_SHA = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
ASSEMBLY, DELIVERY, ACCEPTANCE = (HERE / n for n in ('ASSEMBLY34.json', 'DELIVERY34.json', 'ROOT_ACCEPTANCE34.json'))
EXISTING = ('data/preview_updates.json', 'export_presets.cfg', 'scripts/main.gd',
            'scripts/quick_controls/quick_controls.gd', 'scripts/quick_controls/scene_hook.gd')
NEW = tuple('scripts/quick_controls/' + n + '.gd' for n in ('street_lamps', 'street_lamp_visual', 'street_glass_sound', 'car_dashboard')) + tuple('audio/street_glass_break_%02d.bytes' % n for n in range(1, 4))
SCOPE = tuple(sorted(EXISTING + NEW))
REQUIRED_RUNS = {mode + '_' + suite for mode in ('native', 'packed') for suite in ('lamp', 'rear', 'dashboard')}
EXPORT_DOCS = {'scripts/destruction/modular30/owner/MODULAR_MINIMAL_README.md', 'scripts/destruction/modular30/owner/expansion/modular_buildings/export/MINIMAL_ENTRYPOINT.txt'}
RAW_AUDIO = {'audio/street_glass_break_%02d.bytes' % n for n in range(1, 4)}
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
actual = lambda p: sha(p) if Path(p).is_file() else None
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()

def require(value, message):
    if not value: raise RuntimeError(message)

def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def local(path, root=REPO):
    target = (root / path).resolve()
    require(target.is_relative_to(root.resolve()), 'Path escaped root: ' + str(path))
    return target

def pinned(row):
    path = local(row['path'])
    require(path.is_file() and sha(path) == row['sha256'], 'Evidence changed: ' + str(path))
    return path

def unscoped():
    return {p.relative_to(SHARED).as_posix(): sha(p) for p in SHARED.rglob('*') if p.is_file()
            and not any(x in ('.godot', 'exports') for x in p.relative_to(SHARED).parts)
            and p.relative_to(SHARED).as_posix() not in SCOPE}

def validate():
    require(sha(BASE) == BASE_SHA, 'Accepted31 assembly changed')
    base, m, delivery, accept = map(read, (BASE, ASSEMBLY, DELIVERY, ACCEPTANCE))
    assembly_sha, delivery_sha = sha(ASSEMBLY), sha(DELIVERY)
    require(accept.get('schema') == 'mafiozi.root25.acceptance34/v1' and accept.get('accepted') is True, 'Root acceptance absent')
    require(accept['revision'] == m['revision'] == delivery['revision'] == REVISION, 'Revision mismatch')
    require(accept['assembly_sha256'] == delivery['assembly_sha256'] == assembly_sha and accept['delivery_sha256'] == delivery_sha, 'Unaccepted assembly/export')
    bp, ap = base['source_pins'], m['source_pins']
    require(m['base_manifest_sha256'] == BASE_SHA and len(bp) == 272 and len(ap) == m['source_count'] == delivery['source_count'] == 279, 'Wrong closure')
    require(set(bp) <= set(ap) and set(ap) - set(bp) == set(NEW), 'Source removal/unexpected additions')
    require({n for n in ap if ap[n] != bp.get(n)} == set(SCOPE), 'Delta differs from exact twelve paths')
    for manifest in (base, m):
        game = local(manifest['game'], REPO / 'outputs')
        for name, digest in manifest['source_pins'].items(): require(actual(local(name, game)) == digest, 'Frozen source changed: ' + name)
    game = local(m['game'], REPO / 'outputs')
    require(read(game / 'data/preview_updates.json')['runtime_revision'] == REVISION and REVISION in (game / 'scripts/main.gd').read_text(encoding='utf-8-sig'), 'Runtime/notes mismatch')
    changes = {n: {'before': bp.get(n), 'after': ap[n]} for n in SCOPE}
    for name, pins in changes.items():
        local(name, SHARED)
        require(not (SHARED / name).exists() or (SHARED / name).is_file(), 'Non-file shared destination')
        require(actual(SHARED / name) == pins['before'], 'Scoped shared change requires review: ' + name)
    pack, exe, receipt_path = (local(delivery[n]) for n in ('pck', 'exe', 'build_receipt'))
    require(pack.parent == exe.parent == receipt_path.parent and pack.name == 'MafioziPreview.pck' and exe.name == 'MafioziPreview.exe', 'Wrong export paths')
    require(sha(pack) == delivery['pck_sha256'] == accept['pck_sha256'] and sha(exe) == delivery['exe_sha256'] == EXE_SHA, 'Wrong accepted binary')
    require(sha(receipt_path) == delivery['build_receipt_sha256'], 'Export receipt changed')
    receipt = read(receipt_path)
    require(receipt['sourceInputsUnchangedDuringExport'] is True, 'Export changed sources')
    exported = {row['path']: row['sha256'] for row in receipt['inputs']}
    # The frozen export helper inventories scripts/scenes/data/assets only.
    # These exact three raw audio files enter the pack through include_filter;
    # independently prove them below using both actual packaged QA suites.
    require(set(exported) == set(ap) - EXPORT_DOCS - RAW_AUDIO and all(ap[n] == digest for n, digest in exported.items()), 'Export runtime input pins differ from assembly')
    packed_paths = {p.removeprefix('res://') for p in receipt['packInventory']['paths']}
    require(RAW_AUDIO <= packed_paths, 'Exact raw audio files absent from export pack inventory')
    require({row['filename'] for row in receipt['artifacts']} == {'MafioziPreview.exe', 'MafioziPreview.pck'}, 'Unexpected export artifacts')
    for row in receipt['artifacts']:
        path = local(row['filename'], pack.parent)
        require(path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], 'Export artifact changed')
    require(set(accept['runs']) == REQUIRED_RUNS and len(accept['gpu_runs']) > 0, 'Six source/packed suites and actual-PCK GPU required')
    qa = read(HERE / 'QA34.json')
    require(qa['assembly_sha256'] == assembly_sha, 'Prepared QA belongs to another assembly')
    for key, row in list(accept['runs'].items()) + [('gpu_' + str(i), r) for i, r in enumerate(accept['gpu_runs'])]:
        run_path = pinned(row)
        run = read(run_path)
        mode, suite = key.split('_', 1)
        require(run.get('mode') == mode and (mode == 'gpu' or run.get('suite') == suite), 'QA mode/suite mismatch')
        require(run.get('passed') is True and run.get('exit_code') == 0 and not run.get('timeout') and run.get('assembly_sha256') == assembly_sha, 'QA failed or from other assembly')
        require(run.get('native_errors') == [] and run.get('source_changed') == [] and run.get('result_failures') == [] and run.get('result_checks', 0) > 0, 'QA lacks clean functional evidence')
        require(run.get('assembly_unchanged') is True and run.get('qa_unchanged') is True, 'QA guard missing')
        if mode in ('packed', 'gpu'): require(run.get('pck_sha256') == accept['pck_sha256'] and run.get('pack_unchanged') is True and run.get('no_loose_runtime_resources') is True, 'QA did not use exact standalone PCK')
        if key in ('packed_lamp', 'packed_dashboard'):
            filename, hash_key, label = ('test_street34.gd', 'qa_sha256', 'packed_audio_exact:') if suite == 'lamp' else ('test_dashboard34.gd', 'dashboard_qa_sha256', 'dashboard_packed_audio:')
            expected_qa = qa[hash_key]
            frozen_qa = local(filename, run_path.parent)
            require(run.get('qa_sha256') == expected_qa and sha(frozen_qa) == sha(HERE / filename) == expected_qa, 'Packaged audio proof used another QA fixture')
            result = read(local('RESULT.json', run_path.parent))
            minimum = 105 if suite == 'lamp' else qa['dashboard_native_min_checks']
            require(result.get('gpu') is False and result.get('test_sha256') == expected_qa and result.get('checks') == run['result_checks'] and result.get('checks', 0) >= minimum and result.get('failures') == [], 'Actual packaged RESULT does not prove all guarded checks')
            qa_text = frozen_qa.read_text(encoding='utf-8-sig')
            for name in RAW_AUDIO:
                assertion = 'check(FileAccess.get_sha256("res://' + name + '") == "' + ap[name] + '", "' + label + name + '")'
                require(qa_text.count(assertion) == 1, 'Exact packaged audio hash assertion missing: ' + name)
            if suite == 'dashboard':
                require(result.get('report', {}).get('physical_space_supported') is True and run.get('native_physical_space_proven') is True, 'Dashboard packaged proof fell back from actual Space')
                require(sha(run_path.parent / 'dashboard_base34.gd') == sha(HERE / 'dashboard_base34.gd') == qa['dashboard_base_sha256'], 'Dashboard packaged helper changed')
        if mode == 'gpu': require(run.get('exclusive_inventory_endpoints') is True, 'GPU overlap not excluded')
    require(accept.get('visual_reviewed') is True and set(accept['visual_features']) == {'lamp', 'rear', 'dashboard'} and accept['images'], 'Root visual review missing')
    for row in accept['images']: require(pinned(row).suffix.lower() == '.png', 'Visual evidence must be captured PNG')
    perf = accept['performance_review']
    require(perf.get('accepted') is True and len(perf.get('scenario', '')) >= 20 and len(perf.get('conclusion', '')) >= 30 and perf['evidence'], 'Meaningful Root performance review required')
    for key in ('baseline_p95_ms', 'candidate_p95_ms', 'first_impact_max_ms', 'memory_delta_bytes'):
        require(type(perf[key]) in (int, float) and math.isfinite(perf[key]) and (key == 'memory_delta_bytes' or perf[key] > 0), 'Missing measured cost: ' + key)
    for row in perf['evidence']: pinned(row)
    return m, delivery, accept, changes, receipt_path, receipt

def prepare(m, delivery, accept, changes, receipt_path, receipt):
    require(not any((OUT / n).exists() for n in ('PREPARATION.json', 'PROMOTION.json', 'play', 'after', 'before', 'APPLY_JOURNAL.json')), 'Preserve prior delivery state')
    (OUT / 'play').mkdir(parents=True)
    for row in receipt['artifacts']: shutil.copy2(receipt_path.parent / row['filename'], OUT / 'play' / row['filename'])
    shutil.copy2(receipt_path, OUT / 'build_receipt.json')
    shutil.copy2(ACCEPTANCE, OUT / 'ROOT_ACCEPTANCE34.json')
    chunks = []
    for name, pins in changes.items():
        target = OUT / 'after' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(Path(m['game']) / name, target)
        if name.endswith('.bytes'): chunks.append('Binary addition: ' + name + ' sha256=' + pins['after'] + '\n'); continue
        old = (SHARED / name).read_text(encoding='utf-8-sig').splitlines(True) if pins['before'] else []
        chunks.extend(difflib.unified_diff(old, target.read_text(encoding='utf-8-sig').splitlines(True), fromfile='24f/' + name, tofile='25a/' + name))
    (OUT / 'PROMOTION.patch').write_text(''.join(chunks), encoding='utf-8')
    (OUT / 'RUNTIME_GIT_FILELIST.txt').write_text(''.join('godot/mafiozi_walk/' + n + '\n' for n in SCOPE), encoding='utf-8')
    write(OUT / 'SOURCE_PINS.json', m['source_pins'])
    write(OUT / 'PREPARATION.json', {'status':'PREPARED_NOT_APPLIED_NOT_LAUNCHED', 'created_utc':now(), 'revision':REVISION, 'changes':changes,
          'assembly_sha256':sha(ASSEMBLY), 'delivery_sha256':sha(DELIVERY), 'acceptance_sha256':sha(ACCEPTANCE), 'script_sha256':sha(__file__),
          'launcher_sha256':sha(OUT / 'launch.ps1'), 'build_receipt_sha256':sha(receipt_path), 'pck_sha256':delivery['pck_sha256'], 'exe_sha256':EXE_SHA,
          'review_files':{n:sha(OUT / n) for n in ('PROMOTION.patch', 'RUNTIME_GIT_FILELIST.txt', 'SOURCE_PINS.json')}, 'shared_modified':False})

def verify(changes, delivery, receipt):
    prep = read(OUT / 'PREPARATION.json')
    require(prep['status'] == 'PREPARED_NOT_APPLIED_NOT_LAUNCHED' and prep['changes'] == changes and not (OUT / 'PROMOTION.json').exists(), 'Preparation/promotion state mismatch')
    for key, path in {'assembly_sha256':ASSEMBLY, 'delivery_sha256':DELIVERY, 'acceptance_sha256':ACCEPTANCE, 'script_sha256':Path(__file__), 'launcher_sha256':OUT / 'launch.ps1', 'build_receipt_sha256':OUT / 'build_receipt.json'}.items(): require(prep[key] == sha(path), 'Prepared pin changed: ' + key)
    require(sha(OUT / 'ROOT_ACCEPTANCE34.json') == prep['acceptance_sha256'], 'Copied acceptance changed')
    for name, digest in prep['review_files'].items(): require(sha(OUT / name) == digest, 'Review artifact changed')
    for name, pins in changes.items(): require(sha(OUT / 'after' / name) == pins['after'], 'Prepared source changed')
    for row in receipt['artifacts']: require(sha(OUT / 'play' / row['filename']) == row['sha256'], 'Prepared binary changed')

def apply(changes, delivery):
    require(not (OUT / 'APPLY_JOURNAL.json').exists(), 'Preserve prior apply journal; manual recovery required')
    untouched = unscoped()
    write(OUT / 'UNSCOPED_BEFORE.json', untouched)
    for name, pins in changes.items(): require(actual(SHARED / name) == pins['before'], 'Concurrent scoped edit before backup')
    for name, pins in changes.items():
        if pins['before']:
            backup = OUT / 'before' / name
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SHARED / name, backup)
            require(sha(backup) == pins['before'], 'Backup mismatch')
    journal = {'status':'APPLYING', 'changes':changes, 'written':[], 'started_utc':now()}
    write(OUT / 'APPLY_JOURNAL.json', journal)
    try:
        for name, pins in changes.items():
            require(actual(SHARED / name) == pins['before'], 'Concurrent scoped edit: ' + name)
            source, dest = OUT / 'after' / name, SHARED / name
            require(sha(source) == pins['after'], 'Prepared source changed: ' + name)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            require(sha(dest) == pins['after'], 'Promoted bytes differ: ' + name)
            journal['written'].append(name); write(OUT / 'APPLY_JOURNAL.json', journal)
        require(unscoped() == untouched, 'Concurrent unscoped edits detected; preserved, inspect journal')
    except Exception as error:
        journal.update(status='INTERRUPTED_REVIEW_REQUIRED', error=str(error)); write(OUT / 'APPLY_JOURNAL.json', journal); raise
    journal['status'] = 'APPLIED'; write(OUT / 'APPLY_JOURNAL.json', journal)
    write(OUT / 'PROMOTION.json', {'status':'APPLIED_NOT_LAUNCHED', 'revision':REVISION, 'created_utc':now(), 'changes':changes,
          'assembly_sha256':sha(ASSEMBLY), 'acceptance_sha256':sha(ACCEPTANCE), 'prepared_receipt_sha256':sha(OUT / 'PREPARATION.json'),
          'launcher_sha256':sha(OUT / 'launch.ps1'), 'pack_sha256':delivery['pck_sha256'], 'exe_sha256':EXE_SHA,
          'unscoped_snapshot_sha256':sha(OUT / 'UNSCOPED_BEFORE.json'), 'unscoped_preserved_count':len(untouched), 'git_changed':False, 'processes_changed':False})

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--prepare', action='store_true'); modes.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    m, delivery, accept, changes, receipt_path, receipt = validate()
    if args.prepare: prepare(m, delivery, accept, changes, receipt_path, receipt)
    verify(changes, delivery, receipt)
    if args.apply: apply(changes, delivery)
    print(json.dumps({'status':'APPLIED_NOT_LAUNCHED' if args.apply else 'PREPARED_VERIFIED_NOT_APPLIED', 'revision':REVISION, 'paths':len(changes)}))
