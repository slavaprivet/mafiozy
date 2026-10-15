"""Read-only validation of completed native roles. PENDING never becomes acceptance.

Only an optional new audit file inside this tools directory is written. No engine,
freeze, source change, pointer change or process operation is performed.
"""
from pathlib import Path
import argparse
import json
import os
import types
import freeze58 as f


def audit(plan_path):
    plan = f.read(plan_path)
    f.need(plan.get('schema') == 'mafiozi.release58.plan/v1', 'Unexpected plan schema')
    integration = f.repo_path(plan['integration'])
    merged = f.read(integration)
    source = f.pins(f.GAME)
    baseline = f.pins(f.PREVIOUS / 'game')
    assembly = f.read(f.PREVIOUS / 'ASSEMBLY.json')
    f.need(baseline == assembly['source_pins'], 'Frozen57 source mismatch')
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    engine_sha = f.sha(engine)
    f.need(engine_sha == f.read(f.ROOT / 'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256'], 'Engine lock mismatch')
    f.need(f.sha(f.ROOT / 'tools/godot/test_scheduler.py') == f.SCHEDULER_SHA, 'Scheduler changed')
    f.validate_import_receipt(integration, merged, source, baseline, engine)
    f.validate_integration(source, baseline, merged, stage_verified=True)
    wanted = sorted(str(row['source_id']) for row in f.read(f.GAME / 'assets/npc_city/session_packet.json')['rows'][:10])
    flags = f.v.city_flags([str(engine), '--', *assembly['launch_arguments']])
    f.SPECS = plan['evidence']; f.v.tested_harness = f.exact_harness
    completed = {}
    for role in f.ROLES:
        spec = f.SPECS[role]
        if not spec.get('run'):
            continue
        f.need(not role.startswith('perf_'), 'Perf belongs to the complete paired release validation')
        folder = f.repo_path(spec['run'])
        f.v.ENTRIES[role] = f.repo_path(spec['harness_root']) / f.relative_name(spec['entry'])
        run, tested_flags, harness = f.v.validate_receipt(folder, role, source, f.GAME, engine)
        f.need(tested_flags == flags, role + ': ordinary flags mismatch')
        f.need(run.get('engine_sha256') == engine_sha and run.get('scheduler_sha256') == f.SCHEDULER_SHA,
               role + ': engine/scheduler mismatch')
        f.need(f.read(folder / 'CONTROL_PINS.json') == f.read(folder / 'CONTROL_PINS_AFTER.json')
               and run.get('control_drift') == [], role + ': controls mismatch')
        detail = {}
        if role == 'soak':
            f.v.validate_soak(folder, run, wanted, 1200)
            detail['spatial'] = f.validate_spatial(folder, run)
        elif role == 'services':
            module = types.ModuleType('actual_services58')
            module.__file__ = str(f.repo_path(spec['harness_root']) / spec['checker'])
            exec(compile(harness[spec['checker']].decode('utf-8-sig'), module.__file__, 'exec'), module.__dict__)
            native = f.read(folder / 'SERVICES56.json')
            checks = module.accept(native)
            f.need(checks == run.get('checks') and checks and all(value is True for value in checks.values()), 'Services checks failed')
            f.need(sorted(native['composition']['original_ids']) == wanted and native['expected_residents'] == 10
                   and run.get('mode') == 'graphical', 'Services roster/mode mismatch')
        elif role in ('threat', 'visual'):
            f.v.validate_threat_visual(folder, run, role, wanted)
        else:
            f.validate_interruption_identity(folder, run, integration, engine, harness)
            detail = f.validate_interruption(folder, run, role, wanted)
        completed[role] = dict(passed=True, run=spec['run'], run_sha256=f.sha(folder / 'RUN.json'),
            checks=len(run.get('checks', {})), harness_sha256=f.sha(folder / spec.get('archive', 'HARNESS.zip')),
            source_count=len(source), detail=detail)
    f.need(f.pins(f.GAME) == source and f.pins(f.PREVIOUS / 'game') == baseline, 'Source changed during audit')
    return dict(passed=True, scope='Completed native roles only; not release acceptance',
        release_accepted=False, performance_accepted=False, engine_launched=False,
        plan_sha256=f.sha(plan_path), integration_sha256=f.sha(integration), completed=completed, pending=f.pending(plan))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan', type=Path, default=f.HERE / 'RELEASE_PLAN58.partial.json')
    p.add_argument('--output', help='Optional unique filename in the tools directory')
    args = p.parse_args()
    value = audit(f.inside(args.plan))
    if args.output:
        output = f.HERE / f.relative_name(args.output)
        f.need(output.parent == f.HERE, 'Audit output must stay in tools directory')
        with output.open('x', encoding='utf-8') as stream:
            stream.write(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(value, ensure_ascii=True))


if __name__ == '__main__':
    main()
