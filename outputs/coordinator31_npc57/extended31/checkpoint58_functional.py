"""Checkpoint candidate58 functional results, including failures; preserve57 and foreign index."""
import argparse
import importlib.util
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
WORK = HERE.parent
spec = importlib.util.spec_from_file_location('checkpoint57', WORK / 'checkpoint57.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
git, sha, read = base.git, base.sha, base.read


def collect(folder, exclude_runs=False):
    blocked = {'.godot', '__pycache__', '.git', 'native_project', 'checkpoint58_functional'}
    if exclude_runs:
        blocked.add('runs')
    return [p.relative_to(ROOT).as_posix() for p in folder.rglob('*')
            if p.is_file() and not blocked.intersection(p.relative_to(folder).parts)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    args = parser.parse_args()
    manifest = read(HERE / 'stage58_03/CANDIDATE58.json')
    soak = WORK / 'proposals/qa58_merged/runs/merged58_1200_02'
    audit = read(soak / 'FINAL_AUDIT58.json')
    assert all(audit['gates'][key] for key in ['exact_candidate_before_after', 'unchanged_controls',
        'no_source_control_harness_drift', 'no_native_errors', 'full1200_native_timeline',
        'valid_native_frame_time', 'full1200_sampled_frame_duration', 'complete_physics_accounting',
        'sixty_native_ticks_per_second', 'complete_1hz_population_observation',
        'bounded_1hz_observation_gaps', 'spatial_recalculation_matches'])
    assert audit['source_manifest_sha256'] == sha(HERE / 'stage58_03/CANDIDATE58.json')
    assert all(sha(WORK / 'game' / rel) == digest for rel, digest in manifest['source_pins'].items())
    assert read(ROOT / 'godot/current_version.json') == read(ROOT / 'outputs/coordinator31_release57/PROPOSED_CURRENT.json')
    assert git('branch', '--show-current').decode().strip() == 'main'
    paths = ['AGENTS.md', 'docs/ai/COORDINATOR_31_MEMORY.md', 'docs/ai/CURRENT_COORDINATOR.json',
             'outputs/coordinator31_npc57/INTEGRATION_flee58_01.json']
    paths += [(WORK / 'game' / rel).relative_to(ROOT).as_posix() for rel in manifest['changes']]
    paths += collect(HERE)
    for name in ['service_threat31_extended', 'service_threat58', 'service_flee58',
                 'service_threat58_final', 'qa58_services', 'qa58_services_final',
                 'qa58_soak_final_review', 'release58_tools']:
        paths += collect(WORK / 'proposals' / name)
    paths += collect(WORK / 'proposals/qa58_merged', exclude_runs=True)
    for name in ['merged58_1200_01', 'merged58_1200_02']:
        paths += collect(WORK / 'proposals/qa58_merged/runs' / name)
    for name in ['merged58_threat01', 'merged58_threat02', 'merged58_visual01', 'merged58_visual02']:
        paths += collect(WORK / 'proposals/attention31_resume/runs' / name)
    paths = sorted(set(paths))
    assert all((ROOT / n).is_file() for n in paths)
    assert all((ROOT / n).stat().st_size < 95 * 1024 * 1024 for n in paths)
    parent = git('rev-parse', 'HEAD').decode().strip()
    source = {n: sha(ROOT / n) for n in paths}
    foreign = {n: v for n, v in base.index().items() if n not in paths}
    plan = dict(parent=parent, scope_count=len(paths), bytes=sum((ROOT / n).stat().st_size for n in paths),
                functional58_passed=audit['passed'], failed_functional_gates=[k for k,v in audit['gates'].items() if not v],
                release58_accepted=False, performance58_accepted=False,
                f5_release='57', first10_complete=False)
    if not args.go:
        print(json.dumps(plan))
        return
    output = HERE / 'checkpoint58_functional'
    output.mkdir(exist_ok=False)
    pathspec = output / 'PATHS.nul'
    pathspec.write_bytes(b'\0'.join(n.encode('utf-8') for n in paths) + b'\0')
    (output / 'SOURCE.json').write_text(json.dumps(source, indent=2) + '\n', encoding='utf-8')
    git('add', '--force', '--pathspec-from-file=' + str(pathspec), '--pathspec-file-nul')
    staged = base.index()
    assert {n: v for n, v in staged.items() if n not in paths} == foreign
    assert git('rev-parse', 'HEAD').decode().strip() == parent
    assert all(sha(ROOT / n) == v for n, v in source.items())
    expected = {}
    for n in paths:
        mode, oid, stage = staged[n].split()
        assert stage == '0'
        expected[n] = (mode, oid)
    git('commit', '--only', '--pathspec-from-file=' + str(pathspec), '--pathspec-file-nul', '-m',
        'NPC58: verify door and service fixes; preserve natural roam-stall evidence')
    commit = git('rev-parse', 'HEAD').decode().strip()
    changed = [n.decode('utf-8') for n in git('diff-tree', '--no-commit-id', '--name-only', '-r', '-z', commit).split(b'\0') if n]
    assert set(changed) <= set(paths) and git('rev-parse', commit + '^').decode().strip() == parent
    committed = base.tree(commit)
    assert all(committed.get(n) == v for n, v in expected.items())
    assert {n: v for n, v in base.index().items() if n not in paths} == foreign
    assert all(sha(ROOT / n) == v for n, v in source.items())
    git('push', 'origin', 'main')
    remote = git('ls-remote', 'origin', 'refs/heads/main').decode().split()[0]
    assert remote == commit
    result = dict(plan, commit=commit, origin_main=remote, foreign_index_preserved=True, changed_paths=changed)
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'changed_paths'}))


if __name__ == '__main__':
    main()
