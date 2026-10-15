"""Scoped main checkpoint for a delivered release57. Dry-run unless --go is supplied."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RELEASE = ROOT / 'outputs/coordinator31_release57'


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, check=True, capture_output=True).stdout


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def index():
    return {entry.split(b'\t', 1)[1].decode('utf-8'): entry.split(b'\t', 1)[0].decode('ascii')
            for entry in git('ls-files', '--stage', '-z').split(b'\0') if entry}


def tree(commit):
    result = {}
    for entry in git('ls-tree', '-r', '--full-tree', '-z', commit).split(b'\0'):
        if not entry:
            continue
        metadata, name = entry.split(b'\t', 1)
        mode, kind, oid = metadata.decode('ascii').split()
        if kind == 'blob':
            result[name.decode('utf-8')] = (mode, oid)
    return result


def collect(folder, exclude_runs=False, recursive=True):
    paths = []
    for path in folder.rglob('*') if recursive else folder.iterdir():
        relative = path.relative_to(folder)
        excluded = {'.godot', '__pycache__', 'native_project', 'checkpoint57'}
        if exclude_runs:
            excluded.add('runs')
        if path.is_file() and not excluded.intersection(relative.parts):
            paths.append(path.relative_to(ROOT).as_posix())
    return paths


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    args = parser.parse_args()
    assert git('branch', '--show-current').decode().strip() == 'main'
    delivery = read(RELEASE / 'DELIVERY.json')
    assert delivery['ordinary_ready'] is True and delivery['resident_count'] == 10
    pointer = ROOT / 'godot/current_version.json'
    assert read(pointer) == read(RELEASE / 'PROPOSED_CURRENT.json')
    assert sha(RELEASE / 'ASSEMBLY.json') == read(pointer)['assembly_sha256']
    assert sha(RELEASE / 'bootstrap_play57.gd') == read(pointer)['bootstrap_sha256']
    paths = ['AGENTS.md', 'docs/ai/COORDINATOR_31_MEMORY.md', 'docs/ai/CURRENT_COORDINATOR.json',
             'godot/current_version.json']
    paths += collect(RELEASE)
    paths += collect(HERE / 'game')
    paths += collect(HERE, recursive=False)
    for name in ('services31_resume', 'attention31_resume', 'qa31_resume', 'services_regression31'):
        paths += collect(HERE / 'proposals' / name, exclude_runs=True)
    # Final receipt archives are inside the release. Preserve the two causal failures too.
    for name in ('attention31_resume/runs/merged_threat_diag03', 'qa31_resume/runs/merged600_01',
                 'qa31_resume/runs/merged57_perf1080_04', 'qa31_resume/runs/baseline56_perf1080_04'):
        paths += collect(HERE / 'proposals' / name)
    paths = sorted(set(paths))
    assert all((ROOT / name).is_file() for name in paths)
    parent = git('rev-parse', 'HEAD').decode().strip()
    source = {name: sha(ROOT / name) for name in paths}
    before = index()
    foreign = {name: item for name, item in before.items() if name not in paths}
    plan = {'verified': True, 'parent': parent, 'scope_count': len(paths),
            'bytes': sum((ROOT / name).stat().st_size for name in paths),
            'accepted_release': '57', 'residents': 10, 'full_city_accepted': False}
    if not args.go:
        print(json.dumps(plan)); raise SystemExit(0)
    output = HERE / 'checkpoint57'
    output.mkdir(exist_ok=False)
    spec = output / 'PATHS.nul'
    spec.write_bytes(b'\0'.join(name.encode('utf-8') for name in paths) + b'\0')
    (output / 'SOURCE.json').write_text(json.dumps(source, indent=2) + '\n', encoding='utf-8')
    git('add', '--force', '--pathspec-from-file=' + str(spec), '--pathspec-file-nul')
    staged = index()
    assert {name: item for name, item in staged.items() if name not in paths} == foreign
    assert git('rev-parse', 'HEAD').decode().strip() == parent
    assert all(sha(ROOT / name) == digest for name, digest in source.items())
    expected_blobs = {}
    for name in paths:
        mode, oid, stage = staged[name].split()
        assert stage == '0'
        expected_blobs[name] = (mode, oid)
    git('commit', '--only', '--pathspec-from-file=' + str(spec), '--pathspec-file-nul', '-m',
        'Release57: fix NPC doorway queues and recovery; verify ten residents')
    commit = git('rev-parse', 'HEAD').decode().strip()
    changed = [name.decode('utf-8') for name in git('diff-tree', '--no-commit-id', '--name-only', '-r', '-z', commit).split(b'\0') if name]
    assert set(changed) <= set(paths)
    assert git('rev-parse', commit + '^').decode().strip() == parent
    committed = tree(commit)
    assert all(committed.get(name) == blob for name, blob in expected_blobs.items())
    assert all(sha(ROOT / name) == digest for name, digest in source.items())
    assert git('branch', '--show-current').decode().strip() == 'main'
    assert {name: item for name, item in index().items() if name not in paths} == foreign
    git('push', 'origin', 'main')
    remote = git('ls-remote', 'origin', 'refs/heads/main').decode().split()[0]
    assert remote == commit
    result = {**plan, 'commit': commit, 'origin_main': remote,
              'foreign_index_preserved': True, 'changed_paths': changed}
    (output / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in result.items() if key != 'changed_paths'}))
