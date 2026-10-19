"""Publish the verified ten-resident release without consuming foreign staged work."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, check=True, capture_output=True).stdout


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def index():
    return {e.split(b'\t', 1)[1].decode('utf-8'): e.split(b'\t', 1)[0].decode('ascii')
            for e in git('ls-files', '--stage', '-z').split(b'\0') if e}


def collect(folder, recursive=True):
    result = []
    for path in folder.rglob('*') if recursive else folder.iterdir():
        rel = path.relative_to(folder)
        if not path.is_file() or any(part in rel.parts for part in ('.godot', '__pycache__', 'native_project')):
            continue
        result.append(path.relative_to(ROOT).as_posix())
    return result


def main():
    assert git('branch', '--show-current').decode().strip() == 'main'
    release = ROOT / 'outputs/coordinator30_release56'
    pointer = ROOT / 'godot/current_version.json'
    delivery = read(release / 'DELIVERY.json')
    assert delivery['ordinary_ready'] is True and delivery['resident_count'] == 10
    assert read(pointer) == read(release / 'PROPOSED_CURRENT.json')
    assert sha(release / 'ASSEMBLY.json') == read(pointer)['assembly_sha256']
    assert read(HERE / 'release_review56/runs/startup01/RUN.json')['passed'] is True
    run = HERE / 'checkpoint_release56'
    run.mkdir(exist_ok=False)
    paths = ['AGENTS.md', 'docs/ai/COORDINATOR_30_MEMORY.md', 'docs/ai/CURRENT_COORDINATOR.json',
             'godot/current_version.json']
    paths += collect(release)
    paths += collect(HERE.parent.parent / 'game')
    paths += collect(HERE, recursive=False)
    paths += collect(HERE / 'release_review56')
    for name in ('threat_order56',):
        paths += collect(HERE.parent / name)
    paths += collect(HERE.parent / 'threat_batch56', recursive=False)
    paths += collect(HERE.parent / 'threat_batch56/runs/actual10_merged04')
    paths += collect(HERE.parent / 'services_city56', recursive=False)
    paths += collect(HERE.parent / 'services_city56/exit_patch56')
    paths += collect(HERE.parent / 'services_city56/exit_door56')
    paths += collect(HERE.parent / 'services_city56/exit_probe56')
    paths += collect(HERE.parent / 'services_city56/runs/actual10_merged_graphical04')
    paths += collect(HERE / 'runs/batch10_final_perf01')
    paths = sorted(set(paths))
    assert all((ROOT / p).is_file() for p in paths)
    source = {p: sha(ROOT / p) for p in paths}
    parent = git('rev-parse', 'HEAD').decode().strip()
    before = index()
    foreign = {p: v for p, v in before.items() if p not in paths}
    spec = run / 'PATHS.nul'
    spec.write_bytes(b'\0'.join(p.encode('utf-8') for p in paths) + b'\0')
    git('add', '--force', '--pathspec-from-file=' + str(spec), '--pathspec-file-nul')
    assert {p: v for p, v in index().items() if p not in paths} == foreign
    assert git('rev-parse', 'HEAD').decode().strip() == parent
    assert all(sha(ROOT / p) == digest for p, digest in source.items())
    git('commit', '--only', '--pathspec-from-file=' + str(spec), '--pathspec-file-nul', '-m',
        'Release56: verify ten residents, physical service exits and panic recovery')
    commit = git('rev-parse', 'HEAD').decode().strip()
    changed = [p.decode('utf-8') for p in git('diff-tree', '--no-commit-id', '--name-only', '-r', '-z', commit).split(b'\0') if p]
    assert set(changed) <= set(paths)
    assert git('rev-parse', commit + '^').decode().strip() == parent
    assert {p: v for p, v in index().items() if p not in paths} == foreign
    git('push', 'origin', 'main')
    remote = git('ls-remote', 'origin', 'refs/heads/main').decode().split()[0]
    assert remote == commit
    result = {'commit': commit, 'parent': parent, 'origin_main': remote, 'scoped_files': len(paths),
              'changed_paths': changed, 'foreign_index_preserved': True,
              'ordinary_release': '56', 'residents': 10, 'next_batch': 20,
              'full_city_performance_accepted': False}
    (run / 'RESULT.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'changed_paths'}))


if __name__ == '__main__':
    main()
