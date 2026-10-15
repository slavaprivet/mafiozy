"""Validate explicit58 evidence plan; --go creates one immutable copy. No engine/F5/Git.

With no --go this only reads inputs. Missing evidence is PENDING, never acceptance.
The plan pins exact entry/checker bytes and role roots; run archives preserve their
tested transitive dependencies even if current diagnostic folders later change.
"""
from pathlib import Path, PurePosixPath
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
import shutil
import sys
import types
import uuid
import zipfile

import validators58 as v
from validators58 import ROOT, HERE, GAME, PREVIOUS, RELEASE, REVISION, TITLE, SCHEDULER_SHA
from validators58 import need, read, sha, save, pins, inside, all_pins, unchanged, one_replace
import spatial58
import perf_compare58

ROLES = ('soak', 'services', 'threat', 'visual', 'shop_interruption', 'restaurant_interruption',
         'perf_baseline', 'perf_candidate')
NON_GAMEPLAY = {'scripts/main.gd', 'data/preview_updates.json'}
TOOL_NAMES = ('freeze58.py', 'startup58.py', 'activate58.py', 'validators58.py',
              'spatial58.py', 'perf_compare58.py', 'RELEASE_PLAN58.example.json')
SPECS = {}
NEWS = [
    'В дверях заведений жители проходят одновременно, сохраняя свои места внутри.',
    'Жители освобождают пространство для створки; стены, двери и игрок сохраняют столкновения.',
    'Магазин, ресторан, банк и больница проверены с физическим входом и выходом.',
    'После реакции на угрозу жители возвращаются к обычным делам.',
    'Активны 10 жителей и 12 сотрудников; следующие партии проверяются отдельно.',
]
INTERRUPTION_CHECKS58 = {
    'initial_full_health', 'initial_affordable_purchase', 'native_service_inside',
    'authentic_native_shot', 'physical_exit', 'claims_released', 'interrupted_purchase_preserved',
    'threat_during_service', 'quiet_releases_at_15s', 'real_flee', 'real_payment_once',
    'actual_energy_restored', 'resumed_purchase_completed', 'conserved_account',
    'normal_native_walk_completed', 'population_preserved', 'other_nine_moved',
    'single_native_miss', 'native_fire_inside_unpaid_service',
}


def repo_path(value):
    need(isinstance(value, str) and value, 'Required repository path is PENDING')
    return inside(ROOT / value)


def relative_name(value):
    need(isinstance(value, str) and value and '\\' not in value,
         'Harness name must be a nonempty POSIX relative path')
    p = PurePosixPath(value)
    need(not p.is_absolute() and '..' not in p.parts and ':' not in value, 'Unsafe harness name')
    return value


def pending(plan):
    missing = []
    for key in ('integration', 'perf_comparison'):
        if not plan.get(key): missing.append(key)
    for role in ROLES:
        spec = plan.get('evidence', {}).get(role, {})
        for key in ('run', 'harness_root', 'entry', 'entry_sha256'):
            if spec.get(key) is None or spec.get(key) == '': missing.append(role + '.' + key)
        if role == 'services':
            for key in ('checker', 'checker_sha256'):
                if not spec.get(key): missing.append(role + '.' + key)
    return missing


def exact_harness(folder, role, command):
    spec = SPECS[role]
    root = repo_path(spec['harness_root'])
    file = relative_name(spec.get('pins_file', 'HARNESS_PINS.json' if role == 'services' else 'HARNESS.json'))
    inventory = read(folder / file)
    archive = folder / relative_name(spec.get('archive', 'HARNESS.zip'))
    need(archive.is_file(), role + ': immutable tested harness archive is required')
    recovered = {}
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        need(len(names) == len(set(names)) and set(names) == set(inventory), role + ': archive inventory mismatch')
        for rel, digest in inventory.items():
            relative_name(rel)
            inside(root / rel).relative_to(root)
            data = z.read(rel)
            need(hashlib.sha256(data).hexdigest() == digest, role + ': archive SHA mismatch: ' + rel)
            recovered[rel] = data
    entry = relative_name(spec['entry'])
    need((root / entry).resolve() == Path(command[command.index('--script') + 1]).resolve(), role + ': exact entry path mismatch')
    need(inventory.get(entry) == spec['entry_sha256'], role + ': approved entry pin mismatch')
    if role == 'soak':
        checker = 'outputs/coordinator31_npc57/proposals/qa58_merged/audit_spatial_liveness31.py'
        need(root == ROOT and inventory.get(checker) == sha(HERE / 'spatial58.py'), 'Soak did not pin the reviewed spatial algorithm')
    if role == 'services':
        checker = relative_name(spec['checker'])
        need(inventory.get(checker) == spec['checker_sha256'], 'Services approved checker pin mismatch')
    return recovered


def validate_spatial(folder, run):
    result = read(folder / 'SPATIAL58.json')
    need(result == spatial58.audit(folder / 'SOAK31.json'), 'Spatial postgate no longer matches native samples')
    need(result.get('schema') == 'mafiozi.qa31.spatial-liveness/v1' and result.get('passed') is True,
         'Spatial liveness did not pass')
    need(result.get('window_s') == 30 and result.get('bbox_diagonal_limit_m') == 1.5 and result.get('episodes') == [],
         'Spatial thresholds weakened or confined motion detected')
    need(run.get('spatial_liveness_passed') is True and run.get('spatial_episodes') == [], 'RUN spatial gate missing')
    return result


def validate_interruption(folder, run, role, wanted):
    """Known real FLEE0 defect is a mandatory gate, independently of ordinary soak."""
    case = {'shop_interruption': 'shop', 'restaurant_interruption': 'restaurant'}[role]
    native = read(folder / 'SERVICE_THREAT58.json')
    checks = native.get('checks', {})
    need(run.get('passed') is True and run.get('native_passed') is True and native.get('passed') is True
         and native.get('reason') == 'complete', case + ': actual interruption did not complete PASS')
    need(run.get('case') == native.get('kind') == case, 'Interruption role/kind mismatch')
    need(isinstance(checks, dict) and INTERRUPTION_CHECKS58 <= set(checks) and
         checks == run.get('checks') and all(value is True for value in checks.values()),
         case + ': all19 named interruption checks plus extras must be true')
    need(native.get('violations') == [] and native.get('synthetic_damage') is False
         and all(native.get(key) == 0 for key in ('npc_relocations', 'fixture_settlements', 'fixture_claims')),
         case + ': synthetic service, claim, damage or relocation')
    command = run.get('command', [])
    need(command.count('--qa-service-kind=' + case) == 1 and
         not any('overlay' in arg.split('=', 1)[0].lower() or arg.startswith('--candidate') for arg in command if arg.startswith('--')),
         case + ': missing actual scenario flag or runtime overlay')
    need(not any(run.get(key) for key in ('overlay', 'overlay_only', 'overlay_applied', 'candidate_resource_overlay',
         'runtime_candidate_overlay', 'overlay_not_merged_acceptance')), 'Overlay cannot close final interruption gate')
    need('overlay' not in str(run.get('source_stage', '')).lower(), 'Overlay stage cannot close final interruption gate')
    need(native.get('roster') == wanted and native.get('target') in wanted, case + ': exact first10 roster missing')
    others = native.get('other_nine_distance_m', {})
    need(set(others) == set(wanted) - {native['target']} and all(float(x) > .25 for x in others.values()),
         case + ': remaining nine residents did not move')
    for key in ('flee_m', 'max_flee_speed', 'max_step_m'):
        need(isinstance(native.get(key), (int, float)) and math.isfinite(native[key]), case + ': missing native motion measurement')
    need(native['flee_m'] >= 2.0 and 1.8 < native['max_flee_speed'] < 2.1 and 0 <= native['max_step_m'] <= 1.0,
         case + ': native flee/speed/no-teleport evidence failed')
    setup = native.get('setup', {}); service = native.get('service', {}); fire = native.get('fire_sent58', {})
    price = setup.get('price', 0); cash = setup.get('cash', -1)
    need(setup.get('kind') == case and price > 0 and cash >= price, case + ': affordable native setup missing')
    need(all(service.get(key) is True for key in ('on_floor', 'capacity_owned', 'service_owned', 'staff_serving'))
         and service.get('distance', math.inf) <= .42, case + ': actual service inside venue not proven')
    need(fire.get('service') is True and fire.get('receipt_count') == 0 and fire.get('cash') == cash,
         case + ': native shot did not occur before payment during service')
    rays = fire.get('miss_rays', {})
    need(all(rays.get(key) is True for key in ('camera_misses_actors', 'muzzle_misses_actors', 'muzzle_ok')),
         case + ': native miss calibration missing')
    shots = native.get('shots', []); terminals = native.get('terminals', [])
    need(len(shots) == 1 and shots[0].get('shot_id') and terminals and
         all(row.get('owned') is False and row.get('shot_id') == shots[0]['shot_id'] for row in terminals),
         case + ': real shot/terminal receipt chain missing')
    interruption = native.get('interruption', {})
    need(interruption.get('capacity_released') is True and interruption.get('service_released') is True
         and interruption.get('depth', math.inf) < -1.1 and interruption.get('receipts') == 0
         and interruption.get('cash') == cash and interruption.get('pending', {}).get('kind') == case
         and interruption.get('pending', {}).get('price') == price, case + ': physical unpaid exit/preserved purchase failed')
    payment = native.get('payment', {}); receipt = payment.get('receipt', {})
    need(payment.get('service') is True and payment.get('energy', -1) >= 99.5 and payment.get('cash') == cash - price
         and receipt.get('amount') == receipt.get('planned_amount') == price and receipt.get('inside') is True
         and receipt.get('cash_before') == cash and receipt.get('cash_after') == cash - price,
         case + ': real resumed single payment/energy restoration failed')
    need(run.get('native_sha256') == sha(folder / 'SERVICE_THREAT58.json'), case + ': native receipt SHA mismatch')
    return dict(kind=case, native_sha256=sha(folder / 'SERVICE_THREAT58.json'), checks=checks,
                flee_m=native['flee_m'], max_flee_speed=native['max_flee_speed'])


def validate_interruption_identity(folder, run, integration, engine, harness):
    """The final ordinary adapter must archive every non-engine control byte."""
    need(run.get('source_stage') == 'merged58' and run.get('engine_started') is True
         and run.get('all_non_engine_controls_archived') is True,
         'Final ordinary merged interruption runner required')
    need(Path(run.get('expected_source', '')).resolve() == integration.resolve()
         and run.get('expected_source_sha256') == sha(integration),
         'Interruption expected manifest binding mismatch')
    controls = read(folder / 'CONTROL_PINS.json')
    control_paths = {Path(path).resolve(): digest for path, digest in controls.items()}
    package = ROOT / 'outputs/coordinator31_npc57/proposals/service_threat58_final'
    required = {package / name for name in ('entry58.gd', 'observer58.gd', 'observer_base58.gd',
                 'run58.py', 'prepare_final58.py', 'PREPARATION58.json')}
    required.update((integration.resolve(), PREVIOUS / 'ASSEMBLY.json', ROOT / 'tools/godot/test_scheduler.py',
                     ROOT / 'docs/godot/ENGINE_LOCK.json', ROOT / 'godot/current_version.json', engine.resolve()))
    need(len(control_paths) == len(controls) and set(control_paths) == {path.resolve() for path in required},
         'Interruption must preserve the complete reviewed12 controls; partial inventories are not proof')
    for path, digest in control_paths.items():
        if path == engine.resolve():
            need(digest == sha(engine), 'Interruption engine control mismatch')
            continue
        relative = inside(path).relative_to(ROOT).as_posix()
        need(relative in harness and hashlib.sha256(harness[relative]).hexdigest() == digest,
             'Interruption control not preserved in tested archive: ' + relative)


def validate_integration(source, baseline, merged, stage_verified=False):
    need((merged.get('applied') is True or stage_verified) and merged.get('source_pins') == source,
         'Final cumulative integration must exactly cover current source pins')
    changes = merged.get('changes', {})
    changed = {name for name in set(source) | set(baseline) if source.get(name) != baseline.get(name)}
    need(set(changes) == changed, 'Integration must include complete release57-to-candidate delta, including metadata/import IDs')
    need(all(row.get('base_sha256') == baseline.get(name) and row.get('candidate_sha256') == source.get(name)
             for name, row in changes.items()), 'Cumulative integration SHA mismatch')
    return changed


def validate_import_receipt(integration, merged, source, baseline, engine):
    """Accept root's exact successful staging receipt without inventing applied=true."""
    receipt = repo_path(merged.get('import_receipt'))
    need(receipt == integration.parent / 'RESULT.json', 'Stage receipt must be adjacent to its manifest')
    result = read(receipt)
    need(result.get('passed') is True and result.get('exit_code') == 0 and result.get('errors') == []
         and result.get('stderr_bytes') == 0 and not result.get('error'), 'Native stage did not cleanly pass')
    need(result.get('f5_changed') is False and result.get('gameplay_acceptance_pending') is True,
         'Stage import is not gameplay acceptance')
    need(merged.get('baseline') == 'release57' and merged.get('baseline_source_pins') == baseline,
         'Stage baseline pins mismatch')
    need(merged.get('source_count') == result.get('source_count') == len(source), 'Stage source count mismatch')
    need(read(receipt.parent / 'SOURCE_AFTER.json') == source, 'Imported source differs from candidate')
    before = read(receipt.parent / 'SOURCE_BEFORE.json')
    changed = {key for key in set(before) | set(source) if before.get(key) != source.get(key)}
    need(changed == set(result.get('import_source_changes', [])) and all(key.endswith('.gd.uid') for key in changed),
         'Import changed gameplay source or omitted source changes')
    command = result.get('command', [])
    need(command == [str(engine), '--headless', '--editor', '--path', str(GAME), '--quit']
         and result.get('child', {}).get('command') == command, 'Unexpected registered stage import command')
    need((receipt.parent / 'stderr.log').stat().st_size == 0, 'Stage stderr is not empty')
    text = (receipt.parent / 'stdout.log').read_text(encoding='utf-8-sig', errors='replace')
    import re
    need(not re.search(r'(^|\n)(?:SCRIPT ERROR|ERROR:|.*Parse Error:)', text), 'Stage stdout contains errors')
    return receipt.parent


def updated_news58(previous):
    """Keep exact57 news history while presenting only five current58 items."""
    import copy
    news = copy.deepcopy(previous)
    history = news.get('history', [])
    need(isinstance(history, list), 'Unsupported news history schema')
    prior = {key: copy.deepcopy(value) for key, value in previous.items() if key != 'history'}
    news['history'] = [prior, *history]
    news.update(title=TITLE, runtime_revision=REVISION, items=list(NEWS))
    return news


def validation(plan_path, reserve_mib):
    need(reserve_mib >= 128, 'At least128MiB copy reserve is required')
    plan = read(plan_path)
    need(plan.get('schema') == 'mafiozi.release58.plan/v1', 'Unexpected plan schema')
    need(plan.get('target_revision') == REVISION and plan.get('baseline_revision') == 's01-20261015-residents57', 'Plan identity mismatch')
    need(not pending(plan), 'Evidence PENDING: ' + ', '.join(pending(plan)))
    need(not RELEASE.exists(), 'Immutable release58 already exists; never overwrite')
    pointer = ROOT / 'godot/current_version.json'
    old = read(pointer)
    need(old.get('revision') == 's01-20261015-residents57', 'Expected current57; do not change user pointer')
    assembly57 = repo_path(old['assembly']); bootstrap57 = repo_path(old['bootstrap'])
    need(assembly57.parent == bootstrap57.parent == PREVIOUS, 'Baseline pointer escaped release57')
    need(sha(assembly57) == old['assembly_sha256'] and sha(bootstrap57) == old['bootstrap_sha256'], 'Baseline control SHA mismatch')
    base = read(assembly57); baseline = pins(PREVIOUS / 'game'); source = pins(GAME)
    need(baseline == base['source_pins'], 'Frozen57 source drift')
    integration = repo_path(plan['integration']); comparison = repo_path(plan['perf_comparison'])
    merged = read(integration)
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    scheduler = ROOT / 'tools/godot/test_scheduler.py'; lock = ROOT / 'docs/godot/ENGINE_LOCK.json'
    engine_sha = sha(engine)
    need(sha(scheduler) == SCHEDULER_SHA and engine_sha == old['engine_sha256'] == read(lock)['editor']['gui']['sha256'], 'Engine/scheduler lock mismatch')
    import_folder = None
    if merged.get('applied') is not True:
        import_folder = validate_import_receipt(integration, merged, source, baseline, engine)
    changed = validate_integration(source, baseline, merged, stage_verified=import_folder is not None)
    evidence = {role: repo_path(plan['evidence'][role]['run']) for role in ROLES}
    global SPECS
    SPECS = plan['evidence']
    v.ENTRIES = {role: repo_path(SPECS[role]['harness_root']) / relative_name(SPECS[role]['entry']) for role in ROLES}
    v.tested_harness = exact_harness
    v.PERF_CHECKER = perf_compare58
    tools = [HERE / name for name in TOOL_NAMES]
    controls = all_pins([], [pointer, assembly57, bootstrap57, scheduler, lock, engine, plan_path, *tools])
    proofs = [plan_path, integration, comparison, *tools, HERE / 'TEMPLATE_ORIGINS.json']
    proof_folders = [*evidence.values(), *([import_folder] if import_folder else [])]
    proof_pins = all_pins(proof_folders, proofs)
    packet = read(GAME / 'assets/npc_city/session_packet.json')
    need(packet == read(PREVIOUS / 'game/assets/npc_city/session_packet.json') and len(packet['rows']) == 287, 'Original287 catalogue changed')
    wanted = sorted(str(row['source_id']) for row in packet['rows'][:10])
    receipts = {}; flags = {}; harnesses = {}
    for role, folder in evidence.items():
        need(folder.is_dir(), 'Missing evidence: ' + role)
        is_base = role == 'perf_baseline'
        receipts[role], flags[role], harnesses[role] = v.validate_receipt(folder, role, baseline if is_base else source,
            PREVIOUS / 'game' if is_base else GAME, engine)
        need(receipts[role].get('engine_sha256') == engine_sha and receipts[role].get('scheduler_sha256') == SCHEDULER_SHA,
             role + ': exact engine/scheduler identities required')
        need(read(folder / 'CONTROL_PINS.json') == read(folder / 'CONTROL_PINS_AFTER.json') and receipts[role].get('control_drift') == [],
             role + ': transitive controls proof missing')
    launch = v.city_flags([str(engine), '--', *base['launch_arguments']])
    need(all(value == launch for value in flags.values()), 'Ordinary gameplay flags differ between evidence/baseline')
    v.validate_soak(evidence['soak'], receipts['soak'], wanted, 1200)
    spatial = validate_spatial(evidence['soak'], receipts['soak'])
    native = read(evidence['services'] / 'SERVICES56.json')
    checker = types.ModuleType('tested_services58')
    checker.__file__ = str(repo_path(SPECS['services']['harness_root']) / SPECS['services']['checker'])
    exec(compile(harnesses['services'][SPECS['services']['checker']].decode('utf-8-sig'), checker.__file__, 'exec'), checker.__dict__)
    checks = checker.accept(native)
    need(checks and checks == receipts['services'].get('checks') and all(x is True for x in checks.values()), 'Four-service native acceptance failed')
    need(sorted(native['composition']['original_ids']) == wanted and native['expected_residents'] == 10, 'Service roster mismatch')
    need(receipts['services'].get('mode') == 'graphical', 'Services require native graphical acceptance')
    for role in ('threat', 'visual'):
        v.validate_threat_visual(evidence[role], receipts[role], role, wanted)
    for role in ('shop_interruption', 'restaurant_interruption'):
        validate_interruption_identity(evidence[role], receipts[role], integration, engine, harnesses[role])
    interruptions = {role: validate_interruption(evidence[role], receipts[role], role, wanted)
                     for role in ('shop_interruption', 'restaurant_interruption')}
    metrics = v.validate_perf(evidence, receipts, comparison, wanted, engine_sha)
    need(pins(GAME) == source and pins(PREVIOUS / 'game') == baseline and unchanged(controls)
         and all_pins(proof_folders, proofs) == proof_pins, 'Inputs changed during validation')
    source_bytes = sum(p.stat().st_size for p in GAME.rglob('*') if p.is_file() and 'shader_cache' not in p.relative_to(GAME).parts)
    proof_bytes = sum(Path(path).stat().st_size for path in proof_pins) + sum(len(data) for files in harnesses.values() for data in files.values())
    reserve = reserve_mib * 1024**2
    need(shutil.disk_usage(RELEASE.parent).free > source_bytes + proof_bytes + reserve, 'Insufficient space for single copy, evidence and reserve')
    return dict(old=old, source=source, baseline=baseline, bootstrap57=bootstrap57, controls=controls, proof_pins=proof_pins,
                harnesses=harnesses, launch=launch, engine_sha=engine_sha, metrics=metrics, spatial=spatial, interruptions=interruptions,
                plan=dict(validated=True, target=str(RELEASE), source_count=len(source), changed_count=len(changed),
                          source_bytes=source_bytes, evidence_bytes=proof_bytes, reserve_bytes=reserve,
                          performance_accepted=True, spatial_liveness_accepted=True, pointer_activated=False,
                          service_interruptions_accepted=True,
                          candidate_modified=False, engine_launched=False))


def freeze(value):
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    partial = inside(ROOT / ('outputs/coordinator31_release58.partial_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + uuid.uuid4().hex[:8]))
    state = {'status': 'UNACCEPTED_PARTIAL', 'target': str(RELEASE), 'pointer_activated': False,
             'recovery': 'Preserve incomplete copy. Never activate it; a retry uses a new partial directory.'}
    source = value['source']; controls = value['controls']; proof_pins = value['proof_pins']
    try:
        with Lease('headless', GAME, 'read', 30), Lease('headless', partial / 'game', 'write', 30):
            need(pins(GAME) == source and pins(PREVIOUS / 'game') == value['baseline']
                 and unchanged(controls) and unchanged(proof_pins), 'Inputs changed before freeze')
            plan = value['plan']
            need(shutil.disk_usage(RELEASE.parent).free > plan['source_bytes'] + plan['evidence_bytes'] + plan['reserve_bytes'], 'Copy reserve no longer available')
            partial.mkdir(); save(partial / 'PARTIAL_STATE.json', state)
            shutil.copytree(GAME, partial / 'game', ignore=shutil.ignore_patterns('shader_cache'))
            need(pins(partial / 'game') == source == pins(GAME), 'Copied source mismatch')
            main = partial / 'game/scripts/main.gd'
            text = main.read_text(encoding='utf-8-sig')
            # Current candidate still carries56 presentation. Read that exact anchor;
            # no broad replacement can conceal gameplay edits in main.gd.
            import re
            matches = re.findall(r'const PREVIEW_RUNTIME_REVISION := "s01-20261015-residents(?:56|57)"', text)
            need(len(matches) == 1, 'Unsupported candidate revision anchor')
            main.write_text(one_replace(text, matches[0], 'const PREVIEW_RUNTIME_REVISION := "' + REVISION + '"'), encoding='utf-8')
            news = updated_news58(read(PREVIOUS / 'game/data/preview_updates.json'))
            save(partial / 'game/data/preview_updates.json', news)
            after = pins(partial / 'game')
            need(set(after) == set(source) and {k for k in source if after[k] != source[k]} == NON_GAMEPLAY, 'Unexpected post-test source delta')
            bootstrap = one_replace(value['bootstrap57'].read_text(encoding='utf-8-sig'), 'var _revision:="s01-20261015-residents57"', 'var _revision:="' + REVISION + '"')
            bootstrap = one_replace(bootstrap, 'var _title:="15.10 · Проходы и реакции жителей · версия57"', 'var _title:="' + TITLE + '"')
            (partial / 'bootstrap_play58.gd').write_text(bootstrap, encoding='utf-8')
            archived = {}
            with zipfile.ZipFile(partial / 'EVIDENCE.zip', 'x', zipfile.ZIP_DEFLATED) as z:
                for absolute, digest in proof_pins.items():
                    path = Path(absolute); name = path.relative_to(ROOT).as_posix()
                    need(sha(path) == digest, 'Evidence drift before archive')
                    z.write(path, name); archived[name] = digest
                for role, files in value['harnesses'].items():
                    for rel, data in files.items():
                        name = 'tested_harness/' + role + '/' + rel
                        z.writestr(name, data); archived[name] = hashlib.sha256(data).hexdigest()
            with zipfile.ZipFile(partial / 'EVIDENCE.zip') as z:
                need(len(z.namelist()) == len(archived) and set(z.namelist()) == set(archived), 'Evidence archive inventory mismatch')
                need(all(hashlib.sha256(z.read(name)).hexdigest() == digest for name, digest in archived.items()), 'Evidence archive SHA mismatch')
            save(partial / 'EVIDENCE_PINS.json', archived)
            save(partial / 'ASSEMBLY.json', {'schema': 'mafiozi.residents-batch58/v1', 'revision': REVISION,
                'game': str(RELEASE / 'game'), 'game_relative': 'outputs/coordinator31_release58/game',
                'source_count': len(after), 'source_pins': after, 'launch_arguments': list(value['launch'].values()),
                'ready_timeout_seconds': 120, 'requested_population': 10, 'staff': 12, 'catalogue_count': 287,
                'performance_accepted': True, 'full_city_performance_accepted': False,
                'performance_scope': 'Exact10+12 matched1920x1080 bounded trial; all287 unaccepted.',
                'ordinary_rng': True, 'police_models_only': True})
            save(partial / 'ACCEPTANCE.json', {'status': 'BATCH10_VERIFIED_PENDING_ORDINARY_START',
                'tested_source_pins': source, 'release_source_pins': after,
                'non_gameplay_changes_after_tests': sorted(NON_GAMEPLAY), 'metrics': value['metrics'],
                'spatial_liveness_accepted': True, 'spatial_gate': value['spatial'],
                'service_interruptions_accepted': True, 'service_interruption_gates': value['interruptions'],
                'evidence_file_pins': proof_pins, 'evidence_archive_sha256': sha(partial / 'EVIDENCE.zip'),
                'controls': controls, 'candidate_unchanged': True, 'full_city_performance_accepted': False,
                'limitations': 'Finite behavior and performance observations; no perpetual liveness or memory guarantee.'})
            save(partial / 'PREVIOUS_CURRENT.json', value['old'])
            save(partial / 'PROPOSED_CURRENT.json', {'schema': 'mafiozi.current-play/v1', 'title': TITLE, 'revision': REVISION,
                'assembly': 'outputs/coordinator31_release58/ASSEMBLY.json', 'assembly_sha256': sha(partial / 'ASSEMBLY.json'),
                'bootstrap': 'outputs/coordinator31_release58/bootstrap_play58.gd', 'bootstrap_sha256': sha(partial / 'bootstrap_play58.gd'),
                'engine_sha256': value['engine_sha'], 'scope': 'Verified10+12; root activates only after exact startup58 passes.'})
            need(pins(GAME) == source and pins(PREVIOUS / 'game') == value['baseline']
                 and unchanged(controls) and unchanged(proof_pins), 'Inputs changed during freeze')
        with Lease('headless', RELEASE / 'game', 'write', 30), Lease('headless', partial / 'game', 'write', 30):
            need(not RELEASE.exists() and pins(partial / 'game') == after, 'Promotion target appeared or copy drift')
            need(pins(PREVIOUS / 'game') == value['baseline'] and unchanged(controls)
                 and unchanged(proof_pins), 'Baseline/evidence/control drift before promotion')
            state['status'] = 'FROZEN_PENDING_BOOTSTRAP_CHECK'; save(partial / 'PARTIAL_STATE.json', state)
            partial.rename(RELEASE)
    except Exception as error:
        state.update(status='FAILED_UNACCEPTED_PARTIAL', error=str(error))
        if partial.is_dir(): save(partial / 'PARTIAL_STATE.json', state)
        raise


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan', type=Path, required=True)
    p.add_argument('--reserve-mib', type=int, default=128)
    p.add_argument('--inspect', action='store_true', help='Report pending input fields only; never produce acceptance')
    p.add_argument('--go', action='store_true', help='Root only: freeze after all exact receipts pass; no F5/launch')
    args = p.parse_args(); path = inside(args.plan)
    need(not (args.inspect and args.go), '--inspect cannot freeze')
    if args.inspect:
        value = read(path)
        print(json.dumps({'status': 'PREPARED_NOT_ACCEPTED', 'pending': pending(value), 'release_accepted': False,
                          'engine_launched': False, 'freeze_executed': False, 'pointer_activated': False}))
        return 0
    result = validation(path, args.reserve_mib)
    if args.go: freeze(result)
    print(json.dumps({**result['plan'], 'frozen': args.go}, ensure_ascii=True))
    return 0


if __name__ == '__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'passed': False, 'error': str(error), 'engine_launched': False,
                          'pointer_activated': False, 'candidate_modified': False})); raise SystemExit(1)
