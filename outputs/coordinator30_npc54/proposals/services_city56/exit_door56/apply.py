"""Strict two-file preflight; --apply uses the shared scheduler's writer lease."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check(project, files):
    rows = []
    for row in files:
        target = project / row['path']
        candidate = (OUT / row['candidate_file']).read_bytes()
        before = target.read_bytes()
        assert sha(candidate) == row['candidate_sha256'], 'Candidate bytes changed'
        assert sha(before) in (row['base_sha256'], row['candidate_sha256']), (
            'Shared source changed; review scoped diff: ' + row['path'])
        rows.append((target, before, candidate))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    project = args.project.resolve()
    files = json.loads((OUT / 'PATCH.json').read_text(encoding='utf-8'))['files']
    rows = check(project, files)
    if all(before == candidate for _, before, candidate in rows):
        print('ALREADY_APPLIED')
        return
    if not args.apply:
        print('PREFLIGHT_OK')
        return
    assert sha((ROOT / 'tools/godot/test_scheduler.py').read_bytes()) == 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    with Lease('headless', project, 'write', 30):
        rows = check(project, files)
        written = []
        try:
            for target, before, candidate in rows:
                if before == candidate:
                    continue
                target.write_bytes(candidate)
                written.append((target, before))
            assert all(target.read_bytes() == candidate for target, _, candidate in rows)
        except Exception:
            for target, before in reversed(written):
                target.write_bytes(before)
            raise
    print('APPLIED_TWO_SCOPED_FILES')


if __name__ == '__main__':
    main()
