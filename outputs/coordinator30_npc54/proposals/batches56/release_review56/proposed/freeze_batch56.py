"""Freeze exactly verified batch10 into one new copy; candidate and current55 stay intact."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
import re
import shutil
import statistics
import sys
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GAME = HERE.parent.parent / 'game'
SCHEDULER_SHA = 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
REVISION = 's01-20261015-residents56'
TITLE = '15.10 · Первая партия: 10 жителей · версия56'
NON_GAMEPLAY = {'scripts/main.gd', 'data/preview_updates.json'}


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(project).parts}


def artifact_pins(folders):
    return {str(p.resolve()): sha(p) for folder in folders for p in folder.rglob('*') if p.is_file()}


def unchanged(files):
    return all(Path(name).is_file() and sha(Path(name)) == digest for name, digest in files.items())


def city_flags(command, role):
    need(isinstance(command, list) and all(isinstance(x, str) for x in command), role + ': missing command')
    need(command.count('--') == 1, role + ': ambiguous user arguments')
    result = {}
    for flag in command[command.index('--') + 1:]:
        key = flag.split('=', 1)[0]
        need('seed' not in key, role + ': deterministic RNG is not ordinary acceptance')
        if flag.startswith('--qa-'):
            continue  # Observer timing/output and documented local QA initialization are not game options.
        need(re.fullmatch(r'--city-[a-z0-9-]+(?:=[^\s\"\';]+)?', flag), role + ': unsupported argument ' + flag)
        need(key not in result, role + ': duplicate city option ' + key)
        need(key not in {'--city-resident-name', '--city-wallet-start', '--city-energy-start',
                         '--city-play-check', '--city-quit-after'}, role + ': global QA initialization is forbidden')
        result[key] = flag
    required = {'--city-qa=10', '--city-hp=100', '--city-venue-staff29=1', '--city-venue-sites29=1',
                '--city-threat30=1', '--city-physical-dispatch30=1', '--city-multi-lifecycle30=1',
                '--city-simple-hospital=1'}
    need(required.issubset(result.values()), role + ': missing ordinary batch10 behavior')
    return result


def require_receipt(folder, role, source, engine):
    receipt = read(folder / 'RUN.json')
    need(receipt.get('passed') is True and receipt.get('exit_code') == 0, role + ': run did not pass')
    need(receipt.get('stderr_bytes') == 0 and receipt.get('errors') == [], role + ': native errors')
    need(receipt.get('source_drift') == receipt.get('harness_drift') == [], role + ': source/harness drift')
    need(read(folder / 'SOURCE.json') == read(folder / 'SOURCE_AFTER.json') == source, role + ': exact before/after source mismatch')
    need(not (folder / 'CANDIDATE_OVERLAY56.json').exists(), role + ': runtime overlay evidence is not merged acceptance')
    for key in ('candidate_resource_overlay', 'overlay_not_merged_acceptance', 'runtime_candidate_overlay'):
        need(not receipt.get(key), role + ': overlay evidence is not merged acceptance')
    command = receipt['command']
    need(Path(command[0]).resolve() == engine.resolve(), role + ': engine path mismatch')
    need(command.count('--path') == 1 and Path(command[command.index('--path') + 1]).resolve() == GAME.resolve(), role + ': wrong project')
    entries = {'perf': HERE / 'entry_batch56.gd', 'services': HERE.parent / 'services_city56/entry_services56.gd',
               'threat': HERE.parent / 'threat_batch56/entry56.gd'}
    need(command.count('--script') == 1 and Path(command[command.index('--script') + 1]).resolve() == entries[role].resolve(), role + ': unexpected entry/overlay')
    need(receipt.get('child', {}).get('command') == command, role + ': missing registered exact child')
    return receipt, city_flags(command, role)


def validate_perf(folder, receipt, wanted, engine, engine_sha):
    need(receipt.get('mode') == 'perf' and receipt.get('perf_environment_clean') is True, 'Perf is not exclusive rendered evidence')
    need(receipt.get('ordinary_rng') is True and receipt.get('requested_residents') == 10, 'Use the current ordinary batch runner')
    need(receipt.get('control_drift') == [] and receipt.get('engine_sha256') == engine_sha
         and receipt.get('scheduler_sha256') == SCHEDULER_SHA, 'Perf binary/control identity mismatch')
    controls = read(folder / 'CONTROL_PINS.json')
    need(controls == read(folder / 'CONTROL_PINS_AFTER.json') and unchanged(controls), 'Perf transitive controls changed')
    need(controls.get(str(engine.resolve())) == engine_sha, 'Perf engine pin missing')
    required_harness = [HERE / 'run_ordinary_batch56.py', HERE / 'entry_batch56.gd',
                        HERE.parent / 'mass30/observer_mass30.gd', HERE.parent / 'perf30/observer_perf30.gd',
                        HERE.parent / 'perf30/perf_pair30.py', ROOT / 'tools/godot/test_scheduler.py',
                        ROOT / 'docs/godot/ENGINE_LOCK.json', ROOT / 'outputs/coordinator30_release55/ASSEMBLY.json']
    harness = read(folder / 'HARNESS.json')
    for path in required_harness:
        need(controls.get(str(path.resolve())) == harness.get(path.relative_to(ROOT).as_posix()) == sha(path), 'Missing/mismatched transitive pin: ' + str(path))
    native = read(folder / 'MASS30.json')
    summary = read(folder / 'PERFORMANCE_SUMMARY.json')
    need(native.get('ok') is True and native.get('errors') == [], 'Native perf observation failed')
    need(native.get('expected_residents') == native.get('moved_residents') == receipt.get('moved_residents') == 10
         and native.get('expected_staff') == 12, 'Require ten moving residents and twelve staff')
    need(native.get('actual_ids') == native.get('wanted_ids') == wanted
         and all(float(native.get('travel_metres', {}).get(key, 0)) > .5 for key in wanted), 'Original ten did not all move')
    need(native.get('npc_or_hp_writes') is False, 'Perf fixture changed NPCs')
    frames = native.get('frame_ms', [])
    need(frames and all(isinstance(x, (int, float)) and math.isfinite(x) and x > 0 for x in frames), 'Invalid frame samples')
    need(native.get('frame_count') == len(frames), 'Frame sample count mismatch')
    mean_fps = 1000 / statistics.mean(frames)
    ordered = sorted(frames)
    p95 = ordered[int((len(ordered) - 1) * .95)]
    need(mean_fps >= 60 and p95 <= 1000 / 60, 'Batch10 FPS/p95 acceptance failed')
    need(summary.get('performance_gate') is True and summary.get('native_pass') is True
         and summary.get('exclusive_clean') is True and summary.get('resident_count') == summary.get('moved_residents') == 10
         and summary.get('staff_count') == 12, 'Performance summary gate did not pass')
    need(math.isclose(summary['mean_fps'], mean_fps, rel_tol=1e-12)
         and math.isclose(summary['frame_ms']['p95'], p95, rel_tol=1e-12)
         and math.isclose(receipt['frame_ms']['p95'], p95, rel_tol=1e-12), 'Summary/receipt metrics differ from native samples')
    need(native.get('camera') == native.get('final_camera') == summary.get('camera'), 'Fixed camera identity mismatch')
    need(native['camera'].get('render_size') == [1280, 720] and native['camera'].get('viewport') == [1280, 720], 'Unexpected performance viewport')
    return {'mean_fps': mean_fps, 'p95_ms': p95, 'moved_residents': 10,
            'measurement_seconds': native['measurement_seconds'], 'camera': native['camera']}


def validate_services(folder, receipt, wanted):
    need(receipt.get('requested_residents') == 10 and receipt.get('checks')
         and all(value is True for value in receipt['checks'].values()), 'Services checks did not all pass')
    checker = HERE.parent / 'services_city56/accept_services56.py'
    need(read(folder / 'HARNESS_PINS.json').get(checker.name) == sha(checker), 'Service acceptance checker changed')
    spec = importlib.util.spec_from_file_location('freeze_services56', checker)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    native = read(folder / 'SERVICES56.json')
    checks = module.accept(native)
    need(checks == receipt['checks'] and all(value is True for value in checks.values()), 'Service native evidence no longer satisfies all checks')
    need(sorted(native['composition']['original_ids']) == wanted and native['expected_residents'] == 10, 'Wrong original service cohort')
    # accept() requires the three named local energy/wallet initializations and forbids route/RNG/movement writes.


def validate_threat(folder, receipt, wanted):
    native = read(folder / 'CITY_THREAT56.json')
    checks = native.get('checks', {})
    need(receipt.get('requested_residents') == 10 and receipt.get('native_passed') is True
         and native.get('passed') is True and native.get('reason') == 'complete', 'Threat cycle incomplete')
    need(checks and checks == receipt.get('checks') and all(value is True for value in checks.values()), 'Threat checks did not all pass')
    composition = native.get('batch_composition', {})
    need(sorted(composition.get('ids', [])) == wanted and composition.get('staff') == 12
         and composition.get('new_sites') == 8, 'Threat cohort/staff mismatch')
    need(all(native.get(key) is False for key in ('synthetic_damage', 'npc_relocated', 'routes_replaced')), 'Threat fixture bypassed ordinary behavior')


def replace_once(text, old, new):
    need(text.count(old) == 1, 'Bootstrap/source template anchor changed: ' + old[:100])
    return text.replace(old, new, 1)


def make_bootstrap(source):
    text = replace_once(source, 's01-20261015-residents55', REVISION)
    text = replace_once(text, '15.10 · Большой город и реакции жителей · версия55', TITLE)
    text = replace_once(text, 'var _out:=""', 'var _out:=""\nvar _expected:=10')
    text = replace_once(text, 'if pop==null or not pop.get("city_ready") or pop.get("daily")==null:',
                        'if pop==null or scene.get("preview_ready")!=true or not pop.get("city_ready") or pop.get("daily")==null or not pop.city_stream_complete():')
    identity = ('\tvar packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))\n'
                '\tvar expected_ids: Array=[]\n'
                '\tfor row: Dictionary in packet.rows:\n'
                '\t\tif expected_ids.size()>=_expected:break\n'
                '\t\texpected_ids.append(str(row.source_id))\n'
                '\texpected_ids.sort()\n'
                '\tvar actual_ids: Array=pop.daily._lives.keys();actual_ids.sort()\n'
                '\tvar exact_ids: bool=actual_ids==expected_ids and packet.rows.size()==287\n')
    text = replace_once(text, '\tvar ready: bool=', identity + '\tvar ready: bool=')
    text = replace_once(text, 'count>=200', 'count==_expected and exact_ids')
    text = replace_once(text, '"requested_residents":287', '"requested_residents":_expected,"actual_ids":actual_ids,"original_catalogue_count":packet.rows.size()')
    text = replace_once(text, '"exact_roster_complete":count==287', '"exact_roster_complete":count==_expected and exact_ids')
    return replace_once(text, '"user_requested_trial_before_performance_acceptance":true,"performance_accepted":false',
                        '"batch_size":10,"performance_accepted_for_requested_batch":true,"full_city_performance_accepted":false')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('perf', 'services', 'threat'):
        parser.add_argument('--' + role, type=Path, required=True)
    args = parser.parse_args()
    evidence = {role: getattr(args, role).resolve() for role in ('perf', 'services', 'threat')}
    for folder in evidence.values():
        folder.relative_to(ROOT)
        need(folder.is_dir(), 'Evidence directory missing: ' + str(folder))
    release = ROOT / 'outputs/coordinator30_release56'
    need(not release.exists(), 'Immutable release already exists; no overwrite')
    scheduler = ROOT / 'tools/godot/test_scheduler.py'
    need(sha(scheduler) == SCHEDULER_SHA, 'Scheduler source changed')
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    pointer = ROOT / 'godot/current_version.json'
    old = read(pointer)
    need(old['revision'] == 's01-20261015-residents55', 'Expected preserved current55 pointer')
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    engine_sha = sha(engine)
    need(engine_sha == old['engine_sha256'] == read(ROOT / 'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256'], 'Engine identity mismatch')
    bootstrap55 = ROOT / 'outputs/coordinator30_release55/bootstrap_play55.gd'
    assembly55 = ROOT / 'outputs/coordinator30_release55/ASSEMBLY.json'
    need(sha(bootstrap55) == old['bootstrap_sha256'] and sha(assembly55) == old['assembly_sha256'], 'Frozen55 control changed')
    control_paths = [pointer, bootstrap55, assembly55, scheduler, ROOT / 'docs/godot/ENGINE_LOCK.json',
                     Path(__file__), HERE.parent / 'services_city56/accept_services56.py']
    control_before = {str(path.resolve()): sha(path) for path in control_paths}
    evidence_before = artifact_pins(evidence.values())
    partial = ROOT / ('outputs/coordinator30_release56.partial_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + uuid.uuid4().hex[:8])
    partial.relative_to(ROOT)
    release.relative_to(ROOT)
    state = {'status': 'UNACCEPTED_PARTIAL', 'final_target': str(release), 'partial': str(partial),
             'pointer_activated': False, 'candidate_modified': False, 'copies_requested': 1,
             'recovery': 'Preserve this partial for inspection. Never activate it; retry uses a new partial directory.'}
    try:
        with Lease('headless', GAME, 'read', 30):
            source_before = pins(GAME)
            packet = read(GAME / 'assets/npc_city/session_packet.json')
            need(len(packet['rows']) == 287, 'Full original catalogue must be retained')
            wanted = sorted(str(row['source_id']) for row in packet['rows'][:10])
            receipts = {}
            flags = {}
            for role, folder in evidence.items():
                receipts[role], flags[role] = require_receipt(folder, role, source_before, engine)
            need(flags['perf'] == flags['services'] == flags['threat'], 'City launch options differ between perf/services/threat')
            metrics = validate_perf(evidence['perf'], receipts['perf'], wanted, engine, engine_sha)
            validate_services(evidence['services'], receipts['services'], wanted)
            validate_threat(evidence['threat'], receipts['threat'], wanted)
            need(artifact_pins(evidence.values()) == evidence_before and unchanged(control_before), 'Evidence/control changed during validation')
            bootstrap = make_bootstrap(bootstrap55.read_text(encoding='utf-8-sig'))
            source_bytes = sum(path.stat().st_size for path in GAME.rglob('*') if path.is_file() and 'shader_cache' not in path.parts)
            need(shutil.disk_usage(release.parent).free > source_bytes + 64 * 1024 * 1024, 'Insufficient free space for one copy plus receipt reserve')
            with Lease('headless', partial / 'game', 'write', 30):
                partial.mkdir()
                save(partial / 'PARTIAL_STATE.json', state)
                shutil.copytree(GAME, partial / 'game', ignore=shutil.ignore_patterns('shader_cache'))
                need(pins(partial / 'game') == source_before == pins(GAME), 'Copy does not match tested sources')
                main_path = partial / 'game/scripts/main.gd'
                original = main_path.read_text(encoding='utf-8-sig')
                main_path.write_text(replace_once(original, 'const PREVIEW_RUNTIME_REVISION := "s01-20261015-residents55"',
                    'const PREVIEW_RUNTIME_REVISION := "' + REVISION + '"'), encoding='utf-8')
                news = {'title': '15.10 · Поэтапное заселение · версия56', 'runtime_revision': REVISION, 'items': [
                    'Первая проверенная партия: 10 жителей. В заведениях работают 12 сотрудников.',
                    'Жители гуляют, выбирают занятия и покупки. При нехватке сил идут поесть, при нехватке денег — в банк.',
                    'При здоровье ниже половины житель идёт в больницу. Розовые плюсы показывают лечение.',
                    'Жители реагируют на оружие и выстрелы. При бегстве скорость выше на 10%; после 15 секунд без новой угрозы они успокаиваются.',
                    'Наведи взгляд на жителя — появится карточка здоровья. Красные числа показывают траты.',
                    'Q — выбрать оружие; E — открыть дверь.'
                ]}
                save(partial / 'game/data/preview_updates.json', news)
                after = pins(partial / 'game')
                need(set(after) == set(source_before) and {key for key in after if after[key] != source_before[key]} == NON_GAMEPLAY, 'Unexpected release source changes')
                need(pins(GAME) == source_before, 'Candidate changed during freeze')
                (partial / 'bootstrap_play56.gd').write_text(bootstrap, encoding='utf-8')
                manifest = {'schema': 'mafiozi.residents-batch56/v1', 'revision': REVISION,
                    'game': str(release / 'game'), 'game_relative': 'outputs/coordinator30_release56/game',
                    'source_count': len(after), 'source_pins': after, 'launch_arguments': list(flags['perf'].values()),
                    'ready_timeout_seconds': 120, 'requested_population': 10, 'staff': 12, 'performance_accepted': True,
                    'performance_scope': '10 original residents +12 staff; fixed camera1280x720; bounded trial. Full287 not accepted.',
                    'full_city_performance_accepted': False, 'ordinary_rng': True, 'police_models_only': True}
                save(partial / 'ASSEMBLY.json', manifest)
                save(partial / 'ACCEPTANCE.json', {'status': 'BATCH10_VERIFIED_PENDING_ORDINARY_START',
                    **{role: folder.relative_to(ROOT).as_posix() for role, folder in evidence.items()},
                    'evidence_file_pins': evidence_before, 'tested_source_pins': source_before, 'release_source_pins': after,
                    'non_gameplay_changes_after_tests': sorted(NON_GAMEPLAY), 'metrics': metrics,
                    'next_batch': 20, 'full_city_performance_accepted': False, 'candidate_modified': False})
                shutil.copy2(pointer, partial / 'PREVIOUS_CURRENT.json')
                save(partial / 'PROPOSED_CURRENT.json', {'schema': 'mafiozi.current-play/v1', 'title': TITLE, 'revision': REVISION,
                    'assembly': 'outputs/coordinator30_release56/ASSEMBLY.json', 'assembly_sha256': sha(partial / 'ASSEMBLY.json'),
                    'bootstrap': 'outputs/coordinator30_release56/bootstrap_play56.gd', 'bootstrap_sha256': sha(partial / 'bootstrap_play56.gd'),
                    'engine_sha256': engine_sha,
                    'scope': 'First verified batch:10 original residents +12 staff. Full287 catalogue retained; further increments only after verification.'})
                need(artifact_pins(evidence.values()) == evidence_before and unchanged(control_before), 'Evidence/control changed during copy')
                state.update(status='VALIDATED_COPY_PENDING_PROMOTION', source_count=len(after), source_bytes=source_bytes)
                save(partial / 'PARTIAL_STATE.json', state)
        # Release both source/copy slots before taking the two promotion locks.
        with Lease('headless', release / 'game', 'write', 30):
            with Lease('headless', partial / 'game', 'write', 30):
                need(not release.exists(), 'Release appeared concurrently; preserved partial is not activated')
                need(pins(partial / 'game') == after, 'Partial source changed before promotion')
                need(artifact_pins(evidence.values()) == evidence_before and unchanged(control_before), 'Evidence/control changed before promotion')
                state.update(status='FROZEN_PENDING_BOOTSTRAP_CHECK', pointer_activated=False)
                save(partial / 'PARTIAL_STATE.json', state)
                # Both resolved targets were checked inside ROOT; this rename never overwrites or removes a tree.
                partial.rename(release)
        print(json.dumps({'release': str(release), 'source_count': len(after), 'pointer_activated': False, 'candidate_modified': False}))
        return 0
    except Exception as error:
        state.update(status='FAILED_UNACCEPTED_PARTIAL', error=str(error))
        if partial.is_dir():
            try:
                save(partial / 'PARTIAL_STATE.json', state)
            except OSError:
                pass  # Initial UNACCEPTED_PARTIAL receipt already describes preservation/recovery.
        print(json.dumps({'passed': False, 'error': str(error), 'partial_preserved': str(partial) if partial.exists() else None,
                          'pointer_activated': False, 'candidate_modified': False}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
