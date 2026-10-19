"""Save the final stage07 and continuation instructions at the user budget cutoff."""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK, ROOT = HERE.parent, HERE.parents[2]
spec = importlib.util.spec_from_file_location('checkpoint57', WORK / 'checkpoint57.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
git, sha, read = base.git, base.sha, base.read

def collect(folder, excluded=()):
    blocked = {'.godot', '__pycache__', '.git', 'native_project', *excluded}
    return [p.relative_to(ROOT).as_posix() for p in folder.rglob('*')
            if p.is_file() and not blocked.intersection(p.relative_to(folder).parts)]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    args = parser.parse_args()
    manifest = read(HERE / 'stage58_07/CANDIDATE58.json')
    assert read(HERE / 'stage58_07/RESULT.json')['passed']
    assert '--city-player-shop=1' in manifest['launch_arguments']
    assert all(sha(WORK / 'game' / rel) == digest for rel, digest in manifest['source_pins'].items())
    assert read(ROOT / 'godot/current_version.json') == read(ROOT / 'outputs/coordinator31_release57/PROPOSED_CURRENT.json')
    assert read(WORK / 'proposals/qa58_routines/runs/home_damage02/RUN.json')['passed']
    handoff = read(WORK / 'proposals/logical_routines58/ROOT_HANDOFF.json')
    assert handoff['verification']['benches02']['passed']
    assert git('branch', '--show-current').decode().strip() == 'main'
    git('merge-base', '--is-ancestor', 'e0958ff4e0e2fb350c24a126883ffd78abd64414', 'HEAD')
    paths = ['AGENTS.md', 'docs/ai/COORDINATOR_31_MEMORY.md', 'docs/ai/CURRENT_COORDINATOR.json',
             'outputs/coordinator31_npc57/INTEGRATION_followup58_01.json',
             'outputs/coordinator31_npc57/extended31/stage_combined58.py',
             'outputs/coordinator31_npc57/extended31/checkpoint58_handoff.py', 'docs/ai/COORDINATOR_31_CONTINUE58.md']
    paths += [(WORK / 'game' / rel).relative_to(ROOT).as_posix() for rel in manifest['changes']]
    paths += collect(HERE / 'stage58_07')
    for name in ['player_shop58', 'combined58']:
        paths += collect(WORK / 'proposals' / name)
    logical = WORK / 'proposals/logical_routines58'
    paths += collect(logical, {'runs', 'policy_projects'})
    for run in ['parse01', 'parse02', 'parse03', 'leisure01', 'benches01', 'benches02']:
        folder = logical / 'runs' / run
        assert folder.is_dir(), run
        paths += collect(folder)
    paths += collect(logical / 'policy_projects/policy03')
    for run in ['native_cycle01', 'native_cycle02']:
        paths += collect(WORK / 'proposals/homes58/runs' / run)
    paths += collect(WORK / 'proposals/homes58/audits/native_cycle02')
    for run in ['home_damage01', 'home_damage02']:
        paths += collect(WORK / 'proposals/qa58_routines/runs' / run)
    paths += collect(HERE / 'checkpoint58_combined')
    for name in ['home_approach58', 'player_shop_guard58', 'medical_boundary58', 'medical_hit58', 'player_userflow58', 'player_shop58_qa', 'live_feedback58', 'qa58_routines', 'qa58_merged_v5']:
        paths += collect(WORK / 'proposals' / name)
    paths = sorted(set(paths))
    assert all((ROOT / n).is_file() and (ROOT / n).stat().st_size < 95 * 1024 * 1024 for n in paths)
    parent = git('rev-parse', 'HEAD').decode().strip()
    source = {n: sha(ROOT / n) for n in paths}
    foreign = {n: v for n, v in base.index().items() if n not in paths}
    plan = dict(parent=parent, scope_count=len(paths), bytes=sum((ROOT / n).stat().st_size for n in paths),
                combined_candidate_import_passed=True, source_count=len(manifest['source_pins']),
                player_shop_source_commit='e0958ff4e0e2fb350c24a126883ffd78abd64414',
                all_requested_components_merged=True, release58_accepted=False, gameplay58_accepted=False,
                performance58_accepted=False, f5_release='57', first10_complete=False,
                all_ready_subagent_deltas_integrated=True, medical_threshold_inclusive=True, continuation='docs/ai/COORDINATOR_31_CONTINUE58.md',
                known_pending=['actual TT60to30 and hospital cycle', 'interrupted long V5 needs a new complete run', 'controlled night schedule', 'real E/shop/throw input flow', 'final combined regressions and exclusive FPS'])
    if not args.go:
        print(json.dumps(plan))
        return
    output = HERE / 'checkpoint58_handoff'
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
        'Save unified NPC58, final route/shop/medical fixes and continuation handoff')
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
