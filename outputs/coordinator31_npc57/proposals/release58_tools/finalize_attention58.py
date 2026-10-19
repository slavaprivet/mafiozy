"""Validate completed native58 attention receipts and fill only available plan fields."""
from pathlib import Path
import argparse
import json
import os
import freeze58 as f


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--expected-source', type=Path, required=True)
    p.add_argument('--threat-run', required=True)
    p.add_argument('--visual-run', required=True)
    p.add_argument('--output-name', required=True)
    args = p.parse_args()
    manifest = f.inside(args.expected_source)
    output = f.HERE / f.relative_name(args.output_name)
    f.need(output.parent == f.HERE and not output.exists(), 'Preserve previous acceptance evidence')
    source = f.read(manifest)['source_pins']
    f.need(source == f.pins(f.GAME), 'Only current exact candidate can fill active plan')
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    wanted = sorted(str(row['source_id']) for row in f.read(f.GAME / 'assets/npc_city/session_packet.json')['rows'][:10])
    plan = f.read(f.HERE / 'RELEASE_PLAN58.partial.json')
    f.need(plan['integration'] == manifest.relative_to(f.ROOT).as_posix(), 'Prepare the current source plan first')
    checks = {}; evidence = {}
    for role in ('threat', 'visual'):
        folder = f.repo_path(getattr(args, role + '_run'))
        native_run = f.read(folder / 'RUN.json')
        entry = Path(native_run['command'][native_run['command'].index('--script') + 1]).relative_to(f.ROOT).as_posix()
        spec = dict(run=folder.relative_to(f.ROOT).as_posix(), harness_root='.', entry=entry,
                    entry_sha256=f.read(folder / 'HARNESS.json')[entry], archive='HARNESS.zip', pins_file='HARNESS.json')
        f.SPECS[role] = spec; f.v.ENTRIES[role] = f.ROOT / entry; f.v.tested_harness = f.exact_harness
        run, flags, harness = f.v.validate_receipt(folder, role, source, f.GAME, engine)
        f.v.validate_threat_visual(folder, run, role, wanted)
        f.need(run['exact_staged_source'] is True and run['stage_manifest_sha256'] == f.sha(manifest), 'Stage binding mismatch')
        f.need(run['control_drift'] == [] and run['engine_sha256'] == f.sha(engine) and
               run['scheduler_sha256'] == f.SCHEDULER_SHA, 'Runner control identity mismatch')
        checks[role] = run['checks']
        evidence[role] = dict(run=spec['run'], run_sha256=f.sha(folder / 'RUN.json'), wall_s=run['wall_s'],
                              native_run_sha256=f.sha(folder / 'RUN_NATIVE.json'), harness_sha256=f.sha(folder / 'HARNESS.zip'))
        plan['evidence'][role] = spec
    services = f.ROOT / 'outputs/coordinator31_npc57/proposals/qa58_services'
    plan['evidence']['services'].update(harness_root=services.relative_to(f.ROOT).as_posix(),
        entry='entry_services56.gd', entry_sha256=f.sha(services / 'entry_services56.gd'),
        checker='accept_services56.py', checker_sha256=f.sha(services / 'accept_services56.py'))
    perf_entry = f.ROOT / 'outputs/coordinator31_npc57/proposals/qa31_resume/entry_soak31_v4.gd'
    for role in ('perf_baseline', 'perf_candidate'):
        plan['evidence'][role].update(harness_root='.', entry=perf_entry.relative_to(f.ROOT).as_posix(),
                                     entry_sha256=f.sha(perf_entry))
    f.save(f.HERE / 'RELEASE_PLAN58.partial.json', plan)
    value = dict(passed=True, scope='Native graphical threat and visual only; not release58 acceptance',
        release_accepted=False, performance_accepted=False, source_count=len(source),
        candidate_manifest_sha256=f.sha(manifest), checks=checks, evidence=evidence,
        photographs_manually_inspected=['01_neutral.png', '02_alert_facing.png'],
        visual_observation='Resident visibly turns from a side/back orientation to face the player holding a weapon.',
        no_source_writes=True, pointer_modified=False, pending=f.pending(plan))
    f.save(output, value)
    print(json.dumps({'passed': True, 'threat_checks': len(checks['threat']), 'visual_checks': len(checks['visual']),
                      'release_accepted': False, 'pending': value['pending']}))


if __name__ == '__main__': main()
