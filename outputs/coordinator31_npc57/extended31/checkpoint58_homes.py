"""Checkpoint verified route recovery and destructible home components; sleep/daily/FPS pending."""
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
    blocked = {'.godot', '__pycache__', '.git', 'native_project', 'checkpoint58_homes'}
    if exclude_runs:
        blocked.add('runs')
    return [p.relative_to(ROOT).as_posix() for p in folder.rglob('*')
            if p.is_file() and not blocked.intersection(p.relative_to(folder).parts)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    args = parser.parse_args()
    manifest = read(HERE / 'stage58_05/CANDIDATE58.json')
    audit = read(WORK / 'proposals/roam_stall58/NATIVE_COMPARISON58.json')
    houses = read(WORK / 'proposals/qa58_routines/AUDIT_GEOMETRY_C4_03.json')
    assert audit['passed'] and all(audit['checks'].values())
    assert houses['passed'] and all(row['ok'] for row in houses['checks'])
    native = WORK / 'proposals/qa58_routines/runs/geometry_c4_03'
    assert all(sha(native / rel) == digest for rel, digest in houses['inputs'].items())
    assert all(sha(WORK / 'game' / rel) == digest for rel, digest in manifest['source_pins'].items())
    assert read(ROOT / 'godot/current_version.json') == read(ROOT / 'outputs/coordinator31_release57/PROPOSED_CURRENT.json')
    assert git('branch', '--show-current').decode().strip() == 'main'
    paths = ['AGENTS.md', 'docs/ai/COORDINATOR_31_MEMORY.md', 'docs/ai/CURRENT_COORDINATOR.json',
             'outputs/coordinator31_npc57/INTEGRATION_roam58_01.json', 'outputs/coordinator31_npc57/INTEGRATION_homes58_01.json']
    paths += [(WORK / 'game' / rel).relative_to(ROOT).as_posix() for rel in manifest['changes']]
    paths += collect(HERE)
    for name in ['roam_recovery58', 'roam_stall58', 'housing_geometry58']:
        paths += collect(WORK / 'proposals' / name)
    paths += collect(WORK / 'proposals/homes58/patch')
    for rel in ['PATCH.json', 'PROPOSAL.json', 'HOOKS.diff', 'READ_ONLY_MAP58.md', 'build_hooks58.py']:
        paths.append((WORK / 'proposals/homes58' / rel).relative_to(ROOT).as_posix())
    for name in ['parse01', 'parse02', 'parse03']:
        paths += collect(WORK / 'proposals/homes58/runs' / name)
    for rel in ['AUDIT_GEOMETRY_C4_03.json', 'QA_MATRIX58.json', 'CLOCK_HOOK_REVIEW58.json', 'homes58.json', 'plan_homes58.py']:
        paths.append((WORK / 'proposals/qa58_routines' / rel).relative_to(ROOT).as_posix())
    for name in ['geometry01', 'geometry02', 'geometry_c4_03']:
        paths += collect(WORK / 'proposals/qa58_routines/runs' / name)
    paths += collect(WORK / 'proposals/qa58_merged_v4')
    paths = sorted(set(paths))
    assert all((ROOT / n).is_file() for n in paths)
    assert all((ROOT / n).stat().st_size < 95 * 1024 * 1024 for n in paths)
    parent = git('rev-parse', 'HEAD').decode().strip()
    source = {n: sha(ROOT / n) for n in paths}
    foreign = {n: v for n, v in base.index().items() if n not in paths}
    plan = dict(parent=parent, scope_count=len(paths), bytes=sum((ROOT / n).stat().st_size for n in paths),
                functional58_passed=False, route_recovery_component_passed=True, home_geometry_c4_component_passed=True, home_sleep_cycle_accepted=False, routines_accepted=False,
                release58_accepted=False, performance58_accepted=False,
                f5_release='57', first10_complete=False)
    if not args.go:
        print(json.dumps(plan))
        return
    output = HERE / 'checkpoint58_homes'
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
        'NPC58: add destructible shared homes and verify route recovery')
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
