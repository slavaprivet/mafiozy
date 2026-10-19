"""CPU-only negative/contract checks. Never calls freeze/startup/activate main."""
from pathlib import Path
import ast
import copy
import hashlib
import json
import tempfile
import zipfile

import freeze58 as f
import validators58 as v


def rejected(call):
    try: call()
    except (RuntimeError, KeyError, ValueError, FileNotFoundError): return True
    return False


def main():
    checks = {}
    for path in f.HERE.glob('*.py'):
        ast.parse(path.read_text(encoding='utf-8'))
        checks['syntax_' + path.name] = True
    checks['repo_root_exact'] = f.ROOT == Path.cwd().resolve() and (f.ROOT / 'AGENTS.md').is_file()
    checks['separate57_baseline58_target'] = f.PREVIOUS.name == 'coordinator31_release57' and f.RELEASE.name == 'coordinator31_release58'
    plan = f.read(f.HERE / 'RELEASE_PLAN58.example.json')
    checks['template_pending_not_acceptance'] = bool(f.pending(plan))
    checks['pending_plan_rejected_before_mutation'] = rejected(lambda: f.validation(f.HERE / 'RELEASE_PLAN58.example.json', 128))
    checks['copy_reserve_cannot_be_weakened'] = rejected(lambda: f.validation(f.HERE / 'RELEASE_PLAN58.example.json', 0))
    baseline = {'main': 'a', 'door': 'b'}; source = {'main': 'c', 'door': 'd', 'helper': 'e'}
    changes = {key: {'base_sha256': baseline.get(key), 'candidate_sha256': source.get(key)} for key in source}
    merged = {'applied': True, 'source_pins': source, 'changes': changes}
    checks['complete_addition_delta_accepted'] = f.validate_integration(source, baseline, merged) == set(source)
    wrong = copy.deepcopy(merged); del wrong['changes']['main']
    checks['metadata_delta_omission_rejected'] = rejected(lambda: f.validate_integration(source, baseline, wrong))
    wrong = copy.deepcopy(merged); wrong['changes']['door']['base_sha256'] = 'wrong'
    checks['wrong_baseline_sha_rejected'] = rejected(lambda: f.validate_integration(source, baseline, wrong))
    checks['later_source_drift_rejected'] = rejected(lambda: f.validate_integration(dict(source, unexpected='x'), baseline, merged))
    without_applied = dict(merged); without_applied.pop('applied')
    checks['missing_applied_without_stage_proof_rejected'] = rejected(lambda: f.validate_integration(source, baseline, without_applied))
    checks['verified_native_stage_can_substitute_applied'] = f.validate_integration(source, baseline, without_applied, stage_verified=True) == set(source)
    previous_news = f.read(f.PREVIOUS / 'game/data/preview_updates.json')
    next_news = f.updated_news58(previous_news)
    checks['exact57_news_history_preserved'] = next_news['history'][0] == previous_news
    checks['only_five_current58_items'] = next_news['runtime_revision'] == f.REVISION and len(next_news['items']) == 5
    checks['news_transform_does_not_mutate_baseline'] = previous_news == f.read(f.PREVIOUS / 'game/data/preview_updates.json')
    for name in ('../escape', '/absolute', 'C:/absolute', 'a\\b'):
        checks['unsafe_archive_name_rejected_' + name] = rejected(lambda name=name: f.relative_name(name))
    with tempfile.TemporaryDirectory(prefix='cpu58_', dir=f.HERE) as temporary:
        # Confirm deletion scope before TemporaryDirectory's recursive cleanup.
        t = Path(temporary).resolve(); t.relative_to(f.HERE.resolve())
        run = t / 'run'; root = t / 'harness'; run.mkdir(); root.mkdir()
        original = b'extends SceneTree\n'; digest = hashlib.sha256(original).hexdigest()
        (root / 'entry.gd').write_bytes(b'later current diagnostic edits\n')
        f.SPECS['threat'] = dict(harness_root=root.relative_to(f.ROOT).as_posix(), entry='entry.gd', entry_sha256=digest)
        f.save(run / 'HARNESS.json', {'entry.gd': digest})
        with zipfile.ZipFile(run / 'HARNESS.zip', 'x') as z: z.writestr('entry.gd', original)
        command = ['engine', '--script', str(root / 'entry.gd')]
        checks['archive_preserves_tested_bytes_after_diagnostic_edits'] = f.exact_harness(run, 'threat', command) == {'entry.gd': original}
        f.SPECS['threat']['entry_sha256'] = '0' * 64
        checks['unreviewed_entry_pin_rejected'] = rejected(lambda: f.exact_harness(run, 'threat', command))
        f.SPECS['threat']['entry_sha256'] = digest
        f.save(run / 'HARNESS.json', {'entry.gd': '0' * 64})
        checks['archive_byte_tampering_rejected'] = rejected(lambda: f.exact_harness(run, 'threat', command))
        f.save(run / 'HARNESS.json', {'entry.gd': digest, 'extra.gd': digest})
        checks['incomplete_archive_rejected'] = rejected(lambda: f.exact_harness(run, 'threat', command))
        f.SPECS['threat']['archive'] = 'missing.zip'
        checks['no_mutable_fallback_for_missing_archive'] = rejected(lambda: f.exact_harness(run, 'threat', command))
        samples = []
        for second in range(65):
            samples.append({'measure_ms': second * 1000, 'count': 1, 'actors': [dict(id='r', generation=1,
                required_motion=True, attention=False, position=[second * .3, 0, 0], completed={'walk': 0})]})
        f.save(run / 'SOAK31.json', {'samples': samples})
        spatial = f.spatial58.audit(run / 'SOAK31.json'); f.save(run / 'SPATIAL58.json', spatial)
        receipt = dict(spatial_liveness_passed=True, spatial_episodes=[])
        checks['real_displacement_spatial_pass'] = f.validate_spatial(run, receipt)['passed']
        wrong = dict(spatial, window_s=60); f.save(run / 'SPATIAL58.json', wrong)
        checks['weakened_spatial_window_rejected'] = rejected(lambda: f.validate_spatial(run, receipt))
        for second, row in enumerate(samples): row['actors'][0]['position'] = [(second % 2) * .5, 0, 0]
        f.save(run / 'SOAK31.json', {'samples': samples})
        confined = f.spatial58.audit(run / 'SOAK31.json')
        checks['moving_in_small_loop_is_detected'] = confined['passed'] is False and bool(confined['episodes'])
        f.save(run / 'SPATIAL58.json', spatial)
        checks['old_spatial_pass_cannot_cover_changed_samples'] = rejected(lambda: f.validate_spatial(run, receipt))
        f.save(run / 'SPATIAL58.json', confined)
        checks['real_confined_episode_rejects_release'] = rejected(lambda: f.validate_spatial(run, receipt))
        # A preserved real FAIL is the negative control. The successful form below
        # is a synthetic validator fixture only, immediately removed with this temp.
        failed = f.ROOT / 'outputs/coordinator31_npc57/proposals/service_threat58/runs/shop_calibration01'
        original = f.read(failed / 'SERVICE_THREAT58.json')
        original_run = f.read(failed / 'RUN.json')
        checks['known_real_service_flee0_failure_rejected'] = rejected(lambda:
            f.validate_interruption(failed, original_run, 'shop_interruption', original['roster']))
        fixture = t / 'interruption'; fixture.mkdir()
        native = copy.deepcopy(original); native['passed'] = True
        native['checks'] = {key: True for key in f.INTERRUPTION_CHECKS58}
        candidate_run = dict(original_run, passed=True, native_passed=True, checks=native['checks'])
        def call_interruption(value=native, record=candidate_run, role='shop_interruption'):
            f.save(fixture / 'SERVICE_THREAT58.json', value)
            return f.validate_interruption(fixture, dict(record, native_sha256=f.sha(fixture / 'SERVICE_THREAT58.json')), role, original['roster'])
        checks['forged_booleans_cannot_hide_zero_native_flee'] = rejected(call_interruption)
        native['flee_m'] = 3.0; native['max_flee_speed'] = 1.98
        checks['complete_synthetic_validator_contract_accepts'] = bool(call_interruption())
        wrong = copy.deepcopy(native); wrong['checks'].pop('authentic_native_shot')
        checks['missing_named_interruption_check_rejected'] = rejected(lambda: call_interruption(wrong, dict(candidate_run, checks=wrong['checks'])))
        wrong = copy.deepcopy(native); wrong['fire_sent58']['receipt_count'] = 1
        checks['postpayment_shot_cannot_replace_unpaid_interruption'] = rejected(lambda: call_interruption(wrong))
        wrong = copy.deepcopy(native); wrong['interruption']['capacity_released'] = False
        checks['capacity_claim_not_physically_released_rejected'] = rejected(lambda: call_interruption(wrong))
        wrong = copy.deepcopy(native); wrong['payment']['cash'] -= 50
        checks['double_payment_raw_receipt_rejected'] = rejected(lambda: call_interruption(wrong))
        checks['shop_receipt_cannot_fill_restaurant_role'] = rejected(lambda: call_interruption(role='restaurant_interruption'))
        checks['isolated_overlay_marker_rejected'] = rejected(lambda: call_interruption(record=dict(candidate_run, overlay_only=True)))
        checks['runtime_overlay_flag_rejected'] = rejected(lambda: call_interruption(record=dict(candidate_run, command=candidate_run['command'] + ['--qa-overlay=1'])))
        identity_manifest = t / 'manifest.json'; identity_manifest.write_bytes(b'{"test_only":true}')
        identity_engine = t / 'engine.test'; identity_engine.write_bytes(b'not executable')
        manifest_name = identity_manifest.relative_to(f.ROOT).as_posix()
        package = f.ROOT / 'outputs/coordinator31_npc57/proposals/service_threat58_final'
        control_files = [package/name for name in ('entry58.gd', 'observer58.gd', 'observer_base58.gd',
                         'run58.py', 'prepare_final58.py', 'PREPARATION58.json')]
        control_files += [identity_manifest, identity_engine, f.PREVIOUS/'ASSEMBLY.json',
                          f.ROOT/'tools/godot/test_scheduler.py', f.ROOT/'docs/godot/ENGINE_LOCK.json',
                          f.ROOT/'godot/current_version.json']
        identity_harness = {path.relative_to(f.ROOT).as_posix(): path.read_bytes() for path in control_files if path != identity_engine}
        identity_controls = {str(path): f.sha(path) for path in control_files}
        f.save(fixture / 'CONTROL_PINS.json', identity_controls)
        identity_run = dict(source_stage='merged58', engine_started=True, all_non_engine_controls_archived=True,
                            expected_source=str(identity_manifest), expected_source_sha256=f.sha(identity_manifest))
        f.validate_interruption_identity(fixture, identity_run, identity_manifest, identity_engine, identity_harness)
        checks['final_interruption_manifest_controls_contract_accepts'] = True
        checks['final_interruption_wrong_manifest_sha_rejected'] = rejected(lambda: f.validate_interruption_identity(
            fixture, dict(identity_run, expected_source_sha256='0'*64), identity_manifest, identity_engine, identity_harness))
        checks['final_interruption_control_missing_from_archive_rejected'] = rejected(lambda: f.validate_interruption_identity(
            fixture, identity_run, identity_manifest, identity_engine, {}))
        checks['final_interruption_archived_control_tampering_rejected'] = rejected(lambda: f.validate_interruption_identity(
            fixture, identity_run, identity_manifest, identity_engine, dict(identity_harness, **{manifest_name: b'wrong'})))
        f.save(fixture / 'CONTROL_PINS.json', {})
        checks['final_interruption_empty_control_inventory_rejected'] = rejected(lambda: f.validate_interruption_identity(
            fixture, identity_run, identity_manifest, identity_engine, identity_harness))
        incomplete_controls = dict(identity_controls); incomplete_controls.pop(str(package/'observer58.gd'))
        incomplete_harness = dict(identity_harness); incomplete_harness.pop((package/'observer58.gd').relative_to(f.ROOT).as_posix())
        f.save(fixture / 'CONTROL_PINS.json', incomplete_controls)
        checks['final_interruption_observer_omitted_from_both_inventories_rejected'] = rejected(lambda: f.validate_interruption_identity(
            fixture, identity_run, identity_manifest, identity_engine, incomplete_harness))
    state = {key: [1920, 1080] for key in ('window_size', 'display_window_size', 'root_texture', 'viewport_visible', 'content_scale_size')}
    state['content_scale_factor'] = 1.0
    window = dict(schema='mafiozi.qa31.window/v1', qa_only=True, npc_or_source_mutations=False,
                  ready=True, requested=[1920, 1080], after=state, final=copy.deepcopy(state))
    camera = dict(render_size=[1920, 1080], viewport=[1920, 1080], window_protocol=state)
    native = dict(camera=camera, final_camera=copy.deepcopy(camera))
    run = dict(requested_resolution='1920x1080', resolution_ok=True, window_protocol=window,
               command=['engine', '--resolution', '1920x1080', '--', '--qa-render-resolution=1920x1080'])
    v.validate_window_protocol(run, native, window, 'CPU')
    checks['matched_physical_logical_1080p_accepts'] = True
    for key in ('render_size', 'viewport'):
        wrong = copy.deepcopy(native); wrong['camera'][key] = [1280, 720]
        checks['wrong_' + key + '_rejected'] = rejected(lambda: v.validate_window_protocol(run, wrong, window, 'CPU'))
    wrong = dict(run, command=run['command'] + ['--headless'])
    checks['headless_not_fps_acceptance'] = rejected(lambda: v.validate_window_protocol(wrong, native, window, 'CPU'))
    checks['five_short_news_items'] = len(f.NEWS) == 5 and all(len(item) < 140 for item in f.NEWS)
    result = dict(passed=all(checks.values()), checks=checks, engine_launched=False,
                  freeze_executed=False, pointer_modified=False, release_accepted=False,
                  tool_pins={path.name: f.sha(path) for path in sorted(f.HERE.glob('*.py'))})
    f.save(f.HERE / 'CPU_CHECKS58.json', result)
    print(json.dumps({'passed': result['passed'], 'checks': len(checks),
                      'failed': [key for key, value in checks.items() if not value],
                      'engine_launched': False, 'release_accepted': False}))
    return 0 if result['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
